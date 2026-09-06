/**
 * Stub llama.h - Fallback when llama.cpp source is not available.
 * Provides empty type definitions so the NAPI module compiles.
 * All functions return failure; real inference requires llama.cpp.
 */
#ifndef LLAMA_STUB_H
#define LLAMA_STUB_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>

// Stub types
typedef struct llama_model llama_model;
typedef struct llama_context llama_context;
typedef struct llama_sampler llama_sampler;
typedef struct llama_vocab llama_vocab;

typedef struct {
    int32_t n_gpu_layers;
    int32_t n_ctx;
    int32_t n_batch;
    int32_t n_threads;
    int32_t n_threads_batch;
} llama_model_params;

typedef struct {
    int32_t n_ctx;
    int32_t n_batch;
    int32_t n_threads;
    int32_t n_threads_batch;
} llama_context_params;

typedef struct {
    void *no_unused;
} llama_sampler_chain_params;

typedef int32_t llama_token;

typedef struct {
    int32_t n_tokens;
    int32_t *token;
    float *embd;
    int32_t n_embd;
} llama_batch;

// Inline stub implementations
static inline void llama_backend_init(void) {}
static inline void llama_backend_free(void) {}

static inline llama_model_params llama_model_default_params(void) {
    llama_model_params p; memset(&p, 0, sizeof(p)); return p;
}
static inline llama_context_params llama_context_default_params(void) {
    llama_context_params p; memset(&p, 0, sizeof(p)); return p;
}
static inline llama_sampler_chain_params llama_sampler_chain_default_params(void) {
    llama_sampler_chain_params p; memset(&p, 0, sizeof(p)); return p;
}

static inline llama_model *llama_model_load_from_file(const char *, llama_model_params) { return nullptr; }
static inline void llama_model_free(llama_model *) {}
static inline llama_context *llama_new_context_with_model(llama_model *, llama_context_params) { return nullptr; }
static inline void llama_free(llama_context *) {}

static inline llama_sampler *llama_sampler_chain_init(llama_sampler_chain_params) { return nullptr; }
static inline void llama_sampler_chain_add(llama_sampler *, llama_sampler *) {}
static inline llama_sampler *llama_sampler_init_min_p(float, int32_t) { return nullptr; }
static inline llama_sampler *llama_sampler_init_temp(float) { return nullptr; }
static inline void llama_sampler_reset(llama_sampler *) {}
static inline void llama_sampler_free(llama_sampler *) {}
static inline llama_token llama_sampler_sample(llama_sampler *, llama_context *, int32_t) { return -1; }

static inline int llama_tokenize(const llama_model *, const char *, int32_t, llama_token *, int32_t, bool, bool) { return -1; }
static inline int llama_token_to_piece(const llama_model *, llama_token, char *, int32_t, int32_t, bool) { return 0; }
static inline bool llama_token_is_eog(const llama_model *, llama_token) { return true; }

static inline llama_batch llama_batch_get_one(llama_token *t, int32_t n) {
    llama_batch b; b.n_tokens = n; b.token = t; b.embd = nullptr; b.n_embd = 0; return b;
}
static inline int32_t llama_decode(llama_context *, llama_batch) { return -1; }

static inline int llama_model_meta_val_str(const llama_model *, const char *, char *, int32_t) { return -1; }
static inline int64_t llama_model_n_params(const llama_model *) { return 0; }
static inline int32_t llama_n_ctx(const llama_context *) { return 0; }

#endif // LLAMA_STUB_H
