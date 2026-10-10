#ifndef LLAMA_RUNNER_H
#define LLAMA_RUNNER_H

#include <string>
#include <functional>
#include <atomic>
#include <mutex>
#include <vector>

/**
 * Chat message structure for multi-turn conversations.
 * Matches llama.cpp's llama_chat_message: {role, content}.
 */
struct ChatMessage {
    std::string role;    // "system", "user", "assistant"
    std::string content;
};

/**
 * LlamaRunner - C++ wrapper around llama.cpp for GGUF model inference.
 * 
 * Lifecycle:
 *   1. loadModel(path, contextLen, threads) -> bool
 *   2. generateChat(messages, maxTokens, temp, topP, callback) -> string
 *   3. unloadModel()
 */
class LlamaRunner {
public:
    LlamaRunner();
    ~LlamaRunner();

    /**
     * Load a GGUF model from file path.
     * @param modelPath Absolute path to .gguf file
     * @param contextLength Max context window (e.g. 2048)
     * @param threads Number of CPU threads for inference
     * @return true on success
     */
    bool loadModel(const std::string& modelPath, int contextLength, int threads);

    /**
     * Run text generation with streaming callback using chat template.
     * Automatically applies the model's built-in chat template via llama_chat_apply_template.
     * @param messages Chat message list (system/user/assistant roles)
     * @param maxTokens Maximum tokens to generate
     * @param temperature Sampling temperature (0.0 - 2.0)
     * @param topP Nucleus sampling threshold (0.0 - 1.0)
     * @param onToken Callback invoked for each generated token (UTF-8 text)
     * @return Full generated text
     */
    std::string generateChat(
        const std::vector<ChatMessage>& messages,
        int maxTokens,
        float temperature,
        float topP,
        std::function<void(const std::string&)> onToken
    );

    /**
     * Run text generation with raw prompt (no chat template).
     * Kept for backward compatibility / non-chat use cases.
     */
    std::string generate(
        const std::string& prompt,
        int maxTokens,
        float temperature,
        float topP,
        std::function<void(const std::string&)> onToken
    );

    /** Unload model and free all resources. */
    void unloadModel();

    /** Check if a model is currently loaded. */
    bool isLoaded() const;

    /** Get model metadata: name, context length, parameter count, quantization. */
    std::string getModelInfo() const;

    /** Request abort of current generation. */
    void abort();

private:
    void* model_;        // llama_model*
    void* context_;      // llama_context*
    int contextLength_;
    int threads_;
    std::atomic<bool> loaded_;
    std::atomic<bool> abortFlag_;
    std::mutex mutex_;

    bool tokenizePrompt(const std::string& prompt, int32_t*& tokens, int& count);
    std::string tokenToText(int32_t tokenId);
};

#endif // LLAMA_RUNNER_H
