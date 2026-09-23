#include "llama_runner.h"
#include <hilog/log.h>
#include <vector>
#include <cstring>
#include <cstdio>
#include <thread>
#include <chrono>

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
    std::lock_guard<std::mutex> lock(mutex_);

    if (loaded_) {
        unloadModel();
    }

    LOGI("Loading model: %{public}s, ctx=%{public}d, threads=%{public}d",
         modelPath.c_str(), contextLength, threads);

    // Initialize llama backend
    llama_backend_init();

    // Load model from file
    llama_model_params modelParams = llama_model_default_params();
    modelParams.n_gpu_layers = 0;  // CPU-only for HarmonyOS
    modelParams.load_mode = LLAMA_LOAD_MODE_MMAP;  // Memory-mapped loading to reduce RAM usageor mobile

    model_ = llama_model_load_from_file(modelPath.c_str(), modelParams);
    if (!model_) {
        LOGE("Failed to load model: %{public}s", modelPath.c_str());
        return false;
    }

    // Create inference context
    llama_context_params ctxParams = llama_context_default_params();
    ctxParams.n_ctx = contextLength;
    ctxParams.n_batch = 256;  // Reduced from 512 to limit memory spikes
    ctxParams.n_threads = threads;
    ctxParams.n_threads_batch = threads;
    ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED; // Disable flash attention

    context_ = llama_new_context_with_model(
        static_cast<llama_model*>(model_), ctxParams);
    if (!context_) {
        LOGE("Failed to create context");
        llama_model_free(static_cast<llama_model*>(model_));
        model_ = nullptr;
        return false;
    }

    contextLength_ = contextLength;
    threads_ = threads;
    loaded_ = true;

    LOGI("Model loaded successfully");
    return true;
}

bool LlamaRunner::tokenizePrompt(const std::string& prompt, int32_t*& tokens, int& count) {
    auto* model = static_cast<llama_model*>(model_);
    auto* ctx = static_cast<llama_context*>(context_);

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

    std::lock_guard<std::mutex> lock(mutex_);
    abortFlag_ = false;

    // 每次生成按传入的 temperature / top-p 重建采样链，确保参数真正生效
    // 采样链顺序: temp -> top_k -> top_p -> dist (必须有 dist 才能选出 token)
    float clampedTemp = temperature < 0.01f ? 0.01f : temperature;
    uint32_t seed = (uint32_t)std::chrono::steady_clock::now().time_since_epoch().count();

    auto* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(clampedTemp));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));
    if (topP > 0.0f && topP < 1.0f) {
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1));
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed));

    // Tokenize prompt
    int32_t* promptTokens = nullptr;
    int promptLen = 0;
    if (!tokenizePrompt(prompt, promptTokens, promptLen)) {
        llama_sampler_free(sampler);
        return "";
    }

    auto* model = static_cast<llama_model*>(model_);
    auto* ctx = static_cast<llama_context*>(context_);
    const auto* vocab = llama_model_get_vocab(model);

    // Feed prompt tokens into context (batched)
    llama_batch batch = llama_batch_get_one(promptTokens, promptLen);
    if (llama_decode(ctx, batch) != 0) {
        LOGE("Failed to decode prompt");
        delete[] promptTokens;
        llama_sampler_free(sampler);
        return "";
    }

    std::string result;
    int nCur = promptLen;

    // Generation loop
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

    int nParams = llama_model_n_params(model);
    int nCtx = llama_n_ctx(static_cast<llama_context*>(context_));

    snprintf(buf, sizeof(buf),
        "{\"name\":\"%s\",\"params\":%d,\"context\":%d,\"threads\":%d}",
        name.c_str(), nParams, nCtx, threads_);
    return std::string(buf);
}
