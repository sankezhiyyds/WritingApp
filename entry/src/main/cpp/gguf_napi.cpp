#include "napi/native_api.h"
#include "llama_runner.h"
#include <hilog/log.h>
#include <string>
#include <memory>

#define LOG_TAG "GGUF_NAPI"
#define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)

static std::unique_ptr<LlamaRunner> g_runner;
static napi_threadsafe_function g_tsfn = nullptr;

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

// ─── generate(prompt, maxTokens, temperature, topP, callback): string ───
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

    // Create threadsafe function for streaming callback
    napi_value resourceName;
    napi_create_string_utf8(env, "ggufCallback", NAPI_AUTO_LENGTH, &resourceName);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(
        env, callback, nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr,
        [](napi_env env, napi_value cb, void* context, void* data) {
            // Called on main thread with each token
            const char* token = static_cast<const char*>(data);
            napi_value tokenStr;
            napi_create_string_utf8(env, token, NAPI_AUTO_LENGTH, &tokenStr);
            napi_value undefined;
            napi_get_undefined(env, &undefined);
            napi_call_function(env, undefined, cb, 1, &tokenStr, nullptr);
        },
        &tsfn
    );

    // Run generation (blocking call)
    std::string result = g_runner->generate(
        prompt, maxTokens, (float)temperature, (float)topP,
        [&tsfn](const std::string& token) {
            // Send token to main thread via threadsafe function
            char* heapToken = new char[token.size() + 1];
            memcpy(heapToken, token.c_str(), token.size() + 1);
            napi_call_threadsafe_function(tsfn, heapToken, napi_tsfn_nonblocking);
        }
    );

    // Release threadsafe function
    napi_release_threadsafe_function(tsfn, napi_tsfn_release);

    napi_value resultStr;
    napi_create_string_utf8(env, result.c_str(), result.size(), &resultStr);
    return resultStr;
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
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
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
