#include "napi/native_api.h"
#include "llama_runner.h"
#include <hilog/log.h>
#include <string>
#include <memory>
#include <cstring>

// Detect if real llama.cpp is available (same logic as llama_runner.cpp)
#if __has_include("llama.h")
  #include "llama.h"
  #define LLAMA_AVAILABLE 1
#else
  #include "llama_stub.h"
  #define LLAMA_AVAILABLE 0
#endif

#define LOG_TAG "GGUF_NAPI"
#define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)

static std::unique_ptr<LlamaRunner> g_runner;

// ─── Async generate data ───
struct AsyncGenerateData {
    napi_async_work work;
    napi_env env;
    napi_deferred deferred;
    napi_threadsafe_function tsfn;
    std::string prompt;
    int32_t maxTokens;
    float temperature;
    float topP;
    std::string result;
    std::string error;
    bool success;
};

// ─── loadModel(modelPath: string, contextLength: number, threads: number): boolean ───
static napi_value LoadModel(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char modelPath[512] = {0};
    size_t pathLen = 0;
    napi_get_value_string_utf8(env, args[0], modelPath, sizeof(modelPath), &pathLen);

    int32_t contextLength = 2048;
    napi_get_value_int32(env, args[1], &contextLength);

    int32_t threads = 4;
    napi_get_value_int32(env, args[2], &threads);

    if (!g_runner) {
        g_runner = std::make_unique<LlamaRunner>();
    }

    bool success = g_runner->loadModel(modelPath, contextLength, threads);
    LOGI("LoadModel result: %{public}d", success);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

// ─── generate(prompt, maxTokens, temperature, topP, callback): Promise<string> ───
// Returns a Promise that resolves with the full generated text.
// Inference runs on a background thread (via napi_create_async_work) to avoid
// blocking the ArkTS main thread, preventing ANR / watchdog crash.
static napi_value Generate(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char prompt[8192] = {0};
    size_t promptLen = 0;
    napi_get_value_string_utf8(env, args[0], prompt, sizeof(prompt), &promptLen);

    int32_t maxTokens = 512;
    napi_get_value_int32(env, args[1], &maxTokens);

    double temperature = 0.8;
    napi_get_value_double(env, args[2], &temperature);

    double topP = 0.9;
    napi_get_value_double(env, args[3], &topP);

    napi_value callback = args[4];

    if (!g_runner || !g_runner->isLoaded()) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    // ── Create Promise ──
    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);

    // ── Threadsafe function for streaming tokens ──
    napi_value resourceName;
    napi_create_string_utf8(env, "ggufCallback", NAPI_AUTO_LENGTH, &resourceName);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(
        env, callback, nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr,
        [](napi_env env, napi_value cb, void* context, void* data) {
            // Runs on main thread — forward token to ArkTS callback
            const char* token = static_cast<const char*>(data);
            if (token) {
                if (cb) {
                    napi_value tokenStr;
                    napi_create_string_utf8(env, token, NAPI_AUTO_LENGTH, &tokenStr);
                    napi_value undefined;
                    napi_get_undefined(env, &undefined);
                    napi_call_function(env, undefined, cb, 1, &tokenStr, nullptr);
                }
                delete[] token;
            }
        },
        &tsfn
    );

    // ── Async work data ──
    auto* data = new AsyncGenerateData();
    data->env = env;
    data->deferred = deferred;
    data->tsfn = tsfn;
    data->prompt = prompt;
    data->maxTokens = maxTokens;
    data->temperature = (float)temperature;
    data->topP = (float)topP;
    data->success = true;

    napi_value workName;
    napi_create_string_utf8(env, "ggufGenerate", NAPI_AUTO_LENGTH, &workName);

    napi_create_async_work(env, nullptr, workName,
        // Execute on background thread (libuv thread pool)
        [](napi_env env, void* rawData) {
            auto* d = static_cast<AsyncGenerateData*>(rawData);
            d->result = g_runner->generate(
                d->prompt, d->maxTokens, d->temperature, d->topP,
                [tsfn = d->tsfn](const std::string& token) {
                    char* heapToken = new char[token.size() + 1];
                    memcpy(heapToken, token.c_str(), token.size() + 1);
                    napi_call_threadsafe_function(tsfn, heapToken, napi_tsfn_nonblocking);
                }
            );
        },
        // Complete on main thread — resolve the Promise
        [](napi_env env, napi_status status, void* rawData) {
            auto* d = static_cast<AsyncGenerateData*>(rawData);

            // Release threadsafe function
            napi_release_threadsafe_function(d->tsfn, napi_tsfn_release);

            // Build result string
            napi_value resultStr;
            napi_create_string_utf8(env, d->result.c_str(), d->result.size(), &resultStr);

            // Resolve the Promise
            napi_resolve_deferred(env, d->deferred, resultStr);

            // Cleanup
            napi_delete_async_work(env, d->work);
            delete d;
        },
        data, &data->work
    );

    napi_queue_async_work(env, data->work);

    return promise;
}

// ─── unloadModel(): void ───
static napi_value UnloadModel(napi_env env, napi_callback_info info) {
    if (g_runner) {
        g_runner->unloadModel();
        LOGI("Model unloaded");
    }
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

// ─── isModelLoaded(): boolean ───
static napi_value IsModelLoaded(napi_env env, napi_callback_info info) {
    bool loaded = g_runner && g_runner->isLoaded();
    napi_value result;
    napi_get_boolean(env, loaded, &result);
    return result;
}

// ─── getModelInfo(): string (JSON) ───
static napi_value GetModelInfo(napi_env env, napi_callback_info info) {
    std::string jsonInfo = g_runner ? g_runner->getModelInfo() : "{}";
    napi_value result;
    napi_create_string_utf8(env, jsonInfo.c_str(), jsonInfo.size(), &result);
    return result;
}

// ─── abort(): void ───
static napi_value Abort(napi_env env, napi_callback_info info) {
    if (g_runner) {
        g_runner->abort();
    }
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

// ─── isStubMode(): boolean — true if llama.cpp not compiled ───
static napi_value IsStubMode(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_get_boolean(env, LLAMA_AVAILABLE == 0, &result);
    return result;
}

// ─── Module Init ───
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"loadModel", nullptr, LoadModel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"generate", nullptr, Generate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"unloadModel", nullptr, UnloadModel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isModelLoaded", nullptr, IsModelLoaded, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getModelInfo", nullptr, GetModelInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"abort", nullptr, Abort, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isStubMode", nullptr, IsStubMode, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    LOGI("GGUF NAPI init — LLAMA_AVAILABLE=%{public}d", LLAMA_AVAILABLE);
    return exports;
}
EXTERN_C_END

static napi_module ggufModule = {
    .nm_version = 1,
    .nm_flags = 1,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "gguf",
    .nm_priv = nullptr,
    {0},
};

extern "C" __attribute__((constructor)) void RegisterGgufModule(void) {
    napi_module_register(&ggufModule);
}
