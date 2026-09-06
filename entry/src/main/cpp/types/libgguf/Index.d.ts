/**
 * GGUF Native Module - TypeScript type declarations
 * Exposes llama.cpp inference functions to ArkTS via NAPI
 */

/** Load a GGUF model from file. Returns true on success. */
export const loadModel: (
  modelPath: string,
  contextLength?: number,
  threads?: number
) => boolean;

/**
 * Run text generation with optional streaming callback.
 * Returns the full generated text.
 */
export const generate: (
  prompt: string,
  maxTokens?: number,
  temperature?: number,
  topP?: number,
  onToken?: (token: string) => void
) => string;

/** Unload model and free all resources. */
export const unloadModel: () => void;

/** Check if a model is currently loaded. */
export const isModelLoaded: () => boolean;

/** Get model metadata as JSON string. */
export const getModelInfo: () => string;

/** Abort current generation. */
export const abort: () => void;
