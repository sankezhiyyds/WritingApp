#include "llama_runner.h"
#include <hilog/log.h>
#include <vector>
#include <cstring>
#include <cstdio>
#include <cinttypes>
#include <thread>
#include <chrono>
#include <unistd.h>  // sysconf
#include <sys/resource.h>  // setpriority, PRIO_PROCESS

#ifdef LOG_TAG
#undef LOG_TAG
#endif
#define LOG_TAG "GGUF_NAPI"
#define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)

// llama.cpp C API — use real headers if available, stub otherwise
#if __has_include("llama.h")
  #include "llama.h"
  #define LLAMA_AVAILABLE 1
#else
  #include "llama_stub.h"
  #define LLAMA_AVAILABLE 0
#endif

LlamaRunner::LlamaRunner()
    : model_(nullptr), context_(nullptr),
      contextLength_(2048), threads_(4), loaded_(false), abortFlag_(false) {}

LlamaRunner::~LlamaRunner() {
    unloadModel();
}

bool LlamaRunner::loadModel(const std::string& modelPath, int contextLength, int threads) {
    [[maybe_unused]] std::lock_guard<std::mutex> lock(mutex_);
    LOGI("loadModel begin: path=%{public}s ctx=%{public}d threads=%{public}d", modelPath.c_str(), contextLength, threads);

    if (loaded_) {
        unloadModel();
    }

    // HarmonyOS 未提供 CPU 特性 API，用 sysconf 获取在线核心数
    // 线程数策略：取在线核心数的 50%，避免占满全部核心导致系统卡顿
    // 用户传入 threads <= 0 时自动检测，> 0 时尊重用户设置
    int effectiveThreads = threads;
    if (threads <= 0) {
        long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
        if (nprocs > 0) {
            effectiveThreads = (int)(nprocs / 2);
            if (effectiveThreads < 1) effectiveThreads = 1;
        } else {
            effectiveThreads = 2;  // fallback
        }
    }
    LOGI("Loading model: %{public}s, ctx=%{public}d, threads=%{public}d (effective=%{public}d)",
         modelPath.c_str(), contextLength, threads, effectiveThreads);

    // Initialize llama backend
    llama_backend_init();

    // Load model from file
    llama_model_params modelParams = llama_model_default_params();
    modelParams.n_gpu_layers = 0;  // CPU-only for HarmonyOS
    modelParams.load_mode = LLAMA_LOAD_MODE_MMAP;  // Memory-mapped loading to reduce RAM usage for mobile

    model_ = llama_model_load_from_file(modelPath.c_str(), modelParams);
    if (!model_) {
        LOGE("Failed to load model: %{public}s", modelPath.c_str());
        return false;
    }

    // Create inference context
    llama_context_params ctxParams = llama_context_default_params();
    // 对齐 GGUF 元数据：读取模型训练时的上下文长度
    uint32_t nCtxTrain = llama_model_n_ctx_train(static_cast<llama_model*>(model_));
    LOGI("Model training context length: %{public}u", nCtxTrain);

    int effectiveCtxLen = contextLength;
    if (contextLength <= 0) {
        effectiveCtxLen = (int)nCtxTrain > 0 ? (int)nCtxTrain : 2048;
        if (effectiveCtxLen > 4096) effectiveCtxLen = 4096;
        LOGI("Using model training ctx: %{public}d", effectiveCtxLen);
    } else if (contextLength > (int)nCtxTrain && nCtxTrain > 0) {
        LOGI("Requested ctx %{public}d > training ctx %{public}u, will use YaRN RoPE scaling",
             contextLength, nCtxTrain);
    }
    contextLength_ = effectiveCtxLen;

    ctxParams.n_ctx = effectiveCtxLen;
    // n_batch 必须等于 n_ctx，否则 llama_decode 在 prefill 阶段卡死（已多次验证）
    ctxParams.n_batch = effectiveCtxLen;
    ctxParams.n_threads = effectiveThreads;
    ctxParams.n_threads_batch = effectiveThreads;  // prefill 与 decode 使用相同线程数，由系统调度器分配核心
    // Flash Attention: DISABLED — 实测 AUTO 导致 prefill 卡死，回退
    ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED;

    // RoPE scaling: 当 n_ctx > nCtxTrain 时启用 YaRN 扩展上下文
    if (effectiveCtxLen > (int)nCtxTrain && nCtxTrain > 0) {
        float yarnScale = (float)effectiveCtxLen / (float)nCtxTrain;
        ctxParams.rope_scaling_type = LLAMA_ROPE_SCALING_TYPE_YARN;
        ctxParams.rope_freq_scale = 1.0f / yarnScale;
        LOGI("YaRN RoPE scaling enabled: scale=%{public}f", yarnScale);
    }

    context_ = llama_init_from_model(
        static_cast<llama_model*>(model_), ctxParams);
    if (!context_) {
        LOGE("Failed to create context for ctx=%{public}d, training ctx=%{public}u", effectiveCtxLen, nCtxTrain);
        llama_model_free(static_cast<llama_model*>(model_));
        model_ = nullptr;
        return false;
    }

    LOGI("Context created successfully, n_ctx=%{public}d, n_batch=%{public}d, threads=%{public}d",
         effectiveCtxLen, ctxParams.n_batch, effectiveThreads);
    contextLength_ = effectiveCtxLen;
    threads_ = effectiveThreads;

    // ── QoS 优先级提升：让系统调度器优先将推理线程分配到大核 ──
    // HarmonyOS 提供 FFRT QoS API（ffrt_this_task_update_qos），
    // 但该 API 需在 FFRT 线程上下文中调用。此处用 nice() 降 nice 值提升优先级，
    // 配合系统调度器决策，不强制绑核（避免干扰系统负载均衡）。
    if (setpriority(PRIO_PROCESS, 0, -5) == 0) {
        LOGI("Inference thread priority raised (nice=-5)");
    } else {
        LOGI("setpriority failed (errno=%{public}d), using default priority", errno);
    }

    loaded_ = true;

    LOGI("Model loaded successfully");
    return true;
}

bool LlamaRunner::tokenizePrompt(const std::string& prompt, int32_t*& tokens, int& count) {
    auto* model = static_cast<llama_model*>(model_);

    // Tokenize with BOS token
    std::vector<llama_token> buf(prompt.size() + 1);
    const auto* vocab = llama_model_get_vocab(model);
    int n = llama_tokenize(
        vocab, prompt.c_str(), prompt.size(), buf.data(), buf.size(), true, true);
    if (n < 0) {
        buf.resize(-n);
        n = llama_tokenize(
            vocab, prompt.c_str(), prompt.size(), buf.data(), buf.size(), true, true);
    }
    if (n < 0) {
        LOGE("Tokenization failed");
        return false;
    }

    tokens = new int32_t[n];
    memcpy(tokens, buf.data(), n * sizeof(int32_t));
    count = n;
    return true;
}

std::string LlamaRunner::tokenToText(int32_t tokenId) {
    auto* model = static_cast<llama_model*>(model_);
    const auto* vocab = llama_model_get_vocab(model);
    char buf[256];
    int len = llama_token_to_piece(vocab, tokenId, buf, sizeof(buf), 0, true);
    if (len < 0) return "";
    return std::string(buf, len);
}

// ─── generateChat: 使用模型内嵌 chat template 格式化消息 ───
std::string LlamaRunner::generateChat(
    const std::vector<ChatMessage>& messages,
    int maxTokens,
    float temperature,
    float topP,
    std::function<void(const std::string&)> onToken
) {
    if (!loaded_ || !model_ || !context_) {
        LOGE("generateChat: model not loaded (loaded=%{public}d, model=%{public}d, context=%{public}d)",
             loaded_ ? 1 : 0, model_ ? 1 : 0, context_ ? 1 : 0);
        return "model not loaded";
    }

    [[maybe_unused]] std::lock_guard<std::mutex> _lock(mutex_);
    abortFlag_ = false;

    auto* model = static_cast<llama_model*>(model_);
    auto* ctx = static_cast<llama_context*>(context_);
    const auto* vocab = llama_model_get_vocab(model);

    // 0. 清除上一轮推理的 KV cache，否则 prefill 会因 context 已满而失败
    llama_memory_t mem = llama_get_memory(ctx);
    if (mem) {
        llama_memory_clear(mem, true);
        LOGI("KV cache cleared before generateChat");
    }

    // 1. 获取模型内嵌的 chat template
    const char* tmpl = llama_model_chat_template(model, nullptr);
    if (!tmpl) {
        LOGE("No chat template found in model, falling back to raw prompt");
        std::string rawPrompt;
        for (const auto& msg : messages) {
            rawPrompt += msg.content + "\n";
        }
        return generate(rawPrompt, maxTokens, temperature, topP, onToken);
    }
    LOGI("Chat template found, applying to %{public}zu messages", messages.size());

    // 2. 将 ChatMessage 转为 llama_chat_message 并应用模板
    std::vector<llama_chat_message> chatMsgs;
    chatMsgs.reserve(messages.size());
    for (const auto& msg : messages) {
        chatMsgs.push_back({msg.role.c_str(), msg.content.c_str()});
    }

    // add_ass=true: 在末尾添加 assistant 角色标记，引导模型生成回复
    int bufLen = 1024;
    std::vector<char> formatted(bufLen);
    int needed = llama_chat_apply_template(
        tmpl, chatMsgs.data(), chatMsgs.size(), true,
        formatted.data(), formatted.size());
    if (needed > (int)formatted.size()) {
        formatted.resize(needed);
        needed = llama_chat_apply_template(
            tmpl, chatMsgs.data(), chatMsgs.size(), true,
            formatted.data(), formatted.size());
    }
    if (needed < 0) {
        LOGE("Failed to apply chat template");
        return "";
    }
    std::string promptStr(formatted.data(), needed);
    LOGI("Formatted prompt length: %{public}d chars", (int)promptStr.size());

    // 3. Tokenize the formatted prompt
    int32_t* promptTokens = nullptr;
    int promptLen = 0;
    if (!tokenizePrompt(promptStr, promptTokens, promptLen)) {
        LOGE("Failed to tokenize formatted prompt");
        return "";
    }
    LOGI("Prompt tokens: %{public}d", promptLen);

    // 4. Prompt 长度保护
    uint32_t nCtx = llama_n_ctx(ctx);
    int maxPromptTokens = (int)nCtx - maxTokens - 4;
    if (maxPromptTokens < 64) maxPromptTokens = 64;
    if (promptLen > maxPromptTokens) {
        LOGE("Prompt too long: %d tokens > n_ctx %d - maxTokens %d, truncating to %d",
             promptLen, nCtx, maxTokens, maxPromptTokens);
        promptLen = maxPromptTokens;
        LOGI("Prompt truncation applied, retry prefill with clipped token count");
    }

    // 5. Prefill（一次性喂入全部 prompt tokens，n_batch=n_ctx 无需分批）
    LOGI("Prefill start: %{public}d tokens, n_batch=%{public}d", promptLen, llama_n_batch(ctx));
    auto prefillStart = std::chrono::steady_clock::now();

    llama_batch promptBatch = llama_batch_get_one(promptTokens, promptLen);
    if (llama_decode(ctx, promptBatch) != 0) {
        LOGE("Prefill decode failed, promptLen=%{public}d", promptLen);
        delete[] promptTokens;
        return "";
    }
    auto prefillEnd = std::chrono::steady_clock::now();
    int prefillMs = (int)std::chrono::duration_cast<std::chrono::milliseconds>(prefillEnd - prefillStart).count();
    LOGI("Prefill done in %{public}dms, tokens=%{public}d", prefillMs, promptLen);
    LOGI("Prefill transition: promptLen=%{public}d, nCtx=%{public}u",
         promptLen, llama_n_ctx(ctx));

    // 5.5 清除空闲超时设置的 abortFlag_，让生成循环正常启动
    // （空闲超时可能在 prefill 期间触发并设置 abortFlag_，但 prefill 已完成）
    abortFlag_.store(false);
    LOGI("Abort flag cleared after prefill, entering generation loop");

    // 6. 采样链（顺序遵循 llama.cpp 官方推荐：min_p -> top_k -> top_p -> temp -> dist）
    float clampedTemp = temperature < 0.01f ? 0.01f : temperature;
    uint32_t seed = (uint32_t)std::chrono::steady_clock::now().time_since_epoch().count();

    auto* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    if (!sampler) {
        LOGE("Prefill transition: sampler init failed, abort before generation loop");
        delete[] promptTokens;
        return "";
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(clampedTemp));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed));

    // 7. Generation loop
    std::string result;
    int nCur = promptLen;
    llama_batch genBatch = llama_batch_get_one(nullptr, 0);
    LOGI("Prefill transition: prefill batch.n_tokens=%{public}d, genBatch.n_tokens=%{public}d",
         genBatch.n_tokens, genBatch.n_tokens);

    LOGI("Generation loop start, maxTokens=%{public}d", maxTokens);

    for (int i = 0; i < maxTokens; i++) {
        if (abortFlag_.load()) {
            LOGI("Generation aborted at token %{public}d", i);
            break;
        }

        if (i > 0 && i % 8 == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        llama_token newToken = llama_sampler_sample(sampler, ctx, -1);
        if (i == 0) {
            LOGI("First token sampled: id=%{public}d", (int)newToken);
        }

        if (llama_vocab_is_eog(vocab, newToken)) {
            LOGI("EOS token at step %{public}d", i);
            break;
        }

        std::string piece = tokenToText(newToken);
        result += piece;

        if (onToken) {
            onToken(piece);
        }
        if (i < 3 || i % 50 == 0) {
            LOGI("Generated token %{public}d: piece_len=%{public}d, result_len=%{public}d", i, (int)piece.size(), (int)result.size());
        }

        genBatch = llama_batch_get_one(&newToken, 1);
        if (llama_decode(ctx, genBatch) != 0) {
            LOGE("Failed to decode token at step %{public}d", i);
            break;
        }
        nCur++;
    }

    delete[] promptTokens;
    llama_sampler_free(sampler);

    LOGI("Generation complete: %{public}d tokens generated, %{public}d chars", nCur - promptLen, (int)result.size());
    return result;
}

std::string LlamaRunner::generate(
    const std::string& prompt,
    int maxTokens,
    float temperature,
    float topP,
    std::function<void(const std::string&)> onToken
) {
    if (!loaded_ || !context_) {
        LOGE("Model not loaded");
        return "";
    }

    [[maybe_unused]] std::lock_guard<std::mutex> _lock(mutex_);
    abortFlag_ = false;

    auto* model = static_cast<llama_model*>(model_);
    auto* ctx = static_cast<llama_context*>(context_);
    const auto* vocab = llama_model_get_vocab(model);

    // 清除上一轮推理的 KV cache
    llama_memory_t mem = llama_get_memory(ctx);
    if (mem) {
        llama_memory_clear(mem, true);
    }

    // 采样链顺序遵循 llama.cpp 官方推荐：min_p -> top_k -> top_p -> temp -> dist
    float clampedTemp = temperature < 0.01f ? 0.01f : temperature;
    uint32_t seed = (uint32_t)std::chrono::steady_clock::now().time_since_epoch().count();

    auto* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));
    if (topP > 0.0f && topP < 1.0f) {
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1));
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(clampedTemp));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed));

    // Tokenize prompt
    int32_t* promptTokens = nullptr;
    int promptLen = 0;
    if (!tokenizePrompt(prompt, promptTokens, promptLen)) {
        llama_sampler_free(sampler);
        return "";
    }

    // 安全保护：prompt token 数不能超过 n_ctx - maxTokens（预留生成空间）
    // 否则 llama_decode 会调用 ggml_abort → SIGABRT 闪退
    int nCtx = contextLength_;
    int maxPromptTokens = nCtx - maxTokens - 4;  // 留 4 token 余量
    if (maxPromptTokens < 64) maxPromptTokens = 64;  // 下限保护
    if (promptLen > maxPromptTokens) {
        LOGE("Prompt too long: %d tokens > n_ctx %d - maxTokens %d, truncating to %d",
             promptLen, nCtx, maxTokens, maxPromptTokens);
        promptLen = maxPromptTokens;
    }

    // 一次性喂入全部 prompt tokens（n_batch=n_ctx，无需分批）
    // 之前 batchSize=224 是 n_batch=256 时的遗留，现在 n_batch=n_ctx=2048
    // 分批 decode 效率极低：每批都需重新计算 KV cache
    const int batchSize = promptLen;  // 一次性喂入
    LOGI("Prefill start: %{public}d prompt tokens, batchSize=%{public}d", promptLen, batchSize);
    auto prefillStart = std::chrono::steady_clock::now();
    for (int off = 0; off < promptLen; off += batchSize) {
        int chunkLen = (off + batchSize < promptLen) ? batchSize : (promptLen - off);
        llama_batch promptBatch = llama_batch_get_one(promptTokens + off, chunkLen);
        if (llama_decode(ctx, promptBatch) != 0) {
            LOGE("Failed to decode prompt batch at offset %d", off);
            delete[] promptTokens;
            llama_sampler_free(sampler);
            return "";
        }
    }
    auto prefillEnd = std::chrono::steady_clock::now();
    int prefillMs = (int)std::chrono::duration_cast<std::chrono::milliseconds>(prefillEnd - prefillStart).count();
    LOGI("Prefill done in %{public}dms", prefillMs);

    std::string result;
    int nCur = promptLen;
    llama_batch batch;  // 复用于生成循环中逐 token 喂入

    // Generation loop
    LOGI("Generation loop start, maxTokens=%{public}d", maxTokens);
    for (int i = 0; i < maxTokens && !abortFlag_; i++) {
        // Yield CPU every 8 tokens to prevent device freeze/restart
        if (i > 0 && i % 8 == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        // Sample next token
        llama_token newToken = llama_sampler_sample(sampler, ctx, -1);

        // Check for EOS
        if (llama_vocab_is_eog(vocab, newToken)) {
            break;
        }

        // Convert token to text
        std::string piece = tokenToText(newToken);
        result += piece;

        // Stream callback
        if (onToken) {
            onToken(piece);
        }
        if (i < 3 || i % 50 == 0) {
            LOGI("Generated token %{public}d: piece_len=%{public}d, result_len=%{public}d", i, (int)piece.size(), (int)result.size());
        }

        // Feed token back into context
        batch = llama_batch_get_one(&newToken, 1);
        if (llama_decode(ctx, batch) != 0) {
            LOGE("Failed to decode token");
            break;
        }
        nCur++;
    }

    delete[] promptTokens;
    llama_sampler_free(sampler);
    LOGI("Generation complete: %{public}d tokens", nCur - promptLen);
    return result;
}

void LlamaRunner::unloadModel() {
    if (context_) {
        llama_free(static_cast<llama_context*>(context_));
        context_ = nullptr;
    }
    if (model_) {
        llama_model_free(static_cast<llama_model*>(model_));
        model_ = nullptr;
    }
    loaded_ = false;
}

bool LlamaRunner::isLoaded() const {
    return loaded_;
}

void LlamaRunner::abort() {
    abortFlag_ = true;
}

std::string LlamaRunner::getModelInfo() const {
    if (!loaded_ || !model_) return "{}";

    auto* model = static_cast<llama_model*>(model_);
    char buf[1024];
    int len = llama_model_meta_val_str(model, "general.name", buf, sizeof(buf));
    std::string name = (len > 0) ? std::string(buf, len) : "unknown";

    uint64_t nParams = llama_model_n_params(model);
    uint32_t nCtx = llama_n_ctx(static_cast<llama_context*>(context_));

    snprintf(buf, sizeof(buf),
        "{\"name\":\"%s\",\"params\":%" PRIu64 ",\"context\":%u,\"threads\":%d}",
        name.c_str(), nParams, nCtx, threads_);
    return std::string(buf);
}
