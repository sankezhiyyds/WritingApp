/**
 * Global type declaration for libgguf.so NAPI module.
 * This file makes the native module importable in ArkTS.
 */

declare module 'libgguf.so' {
  export const loadModel: (
    modelPath: string,
    contextLength?: number,
    threads?: number
  ) => boolean;

  export const generate: (
    prompt: string,
    maxTokens?: number,
    temperature?: number,
    topP?: number,
    onToken?: (token: string) => void
  ) => string;

  export const unloadModel: () => void;
  export const isModelLoaded: () => boolean;
  export const getModelInfo: () => string;
  export const abort: () => void;
}
