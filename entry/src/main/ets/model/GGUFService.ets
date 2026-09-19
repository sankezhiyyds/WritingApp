import { settingsManager } from './SettingsManager';
import * as gguf from 'libgguf.so';

/**
 * GGUFService - ArkTS service layer for local GGUF model inference.
 *
 * Architecture:
 *   ArkTS (GGUFService) → NAPI (libgguf.so) → C++ (llama_runner) → llama.cpp
 *
 * Provides Promise-based interface for model loading, streaming generation,
 * and lifecycle management. Falls back gracefully when native module is
 * unavailable (e.g. llama.cpp not compiled).
 */

/** Model metadata */
export interface GGUFModelInfo {
  name: string;
  params: number;
  context: number;
  threads: number;
}

/** Generation result */
export interface GGUFGenerateResult {
  text: string;
  success: boolean;
  error?: string;
  tokensGenerated?: number;
}

/** Generation parameters */
export interface GGUFGenerateParams {
  prompt: string;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  onToken?: (token: string) => void;
}

/** Model load parameters */
export interface GGUFLoadParams {
  modelPath: string;
  contextLength?: number;
  threads?: number;
}

class GGUFServiceClass {
  private loaded: boolean = false;
  private currentModelPath: string = '';
  private nativeAvailable: boolean = false;

  constructor() {
    try {
      const loaded = gguf.isModelLoaded();
      this.nativeAvailable = (loaded === true || loaded === false);
    } catch (e) {
      this.nativeAvailable = false;
    }
  }

  /** Check if the native GGUF inference module is available. */
  isNativeAvailable(): boolean {
    return this.nativeAvailable;
  }

  /** Check if the native module is a stub (llama.cpp not compiled). */
  isStubMode(): boolean {
    if (!this.nativeAvailable) {
      return true;
    }
    try {
      return gguf.isStubMode();
    } catch (e) {
      return true;
    }
  }

  /** Load a GGUF model from the device filesystem (async, runs on background thread). */
  async loadModel(params: GGUFLoadParams): Promise<boolean> {
    if (!this.nativeAvailable) {
      console.warn('[GGUFService] Native module not available. Please compile llama.cpp.');
      return false;
    }

    if (!params.modelPath) {
      console.error('[GGUFService] Model path is empty');
      return false;
    }

    const contextLength = params.contextLength ?? 2048;
    const threads = params.threads ?? 4;

    try {
      const success = await gguf.loadModel(params.modelPath, contextLength, threads);
      if (success) {
        this.loaded = true;
        this.currentModelPath = params.modelPath;
        console.info(`[GGUFService] Model loaded: ${params.modelPath}`);
      }
      return success;
    } catch (e) {
      console.error(`[GGUFService] Load failed: ${e}`);
      return false;
    }
  }

  /** Generate text with optional streaming callback. */
  async generate(params: GGUFGenerateParams): Promise<GGUFGenerateResult> {
    if (!this.nativeAvailable) {
      return {
        text: '',
        success: false,
        error: '本地推理引擎未安装。请编译 llama.cpp 并构建 libgguf.so。'
      };
    }

    if (!this.loaded) {
      return {
        text: '',
        success: false,
        error: '未加载模型。请先在设置中选择 GGUF 模型文件。'
      };
    }

    const maxTokens = params.maxTokens ?? 512;
    const temperature = params.temperature ?? 0.8;
    const topP = params.topP ?? 0.9;
    const onToken = params.onToken ?? null;

    try {
      // 让步事件循环，确保UI能先渲染isGenerating状态
      await new Promise<void>(resolve => setTimeout(resolve, 0));

      console.info(`[GGUFService] 开始推理, prompt长度=${params.prompt.length}, maxTokens=${maxTokens}`);
      const text = await gguf.generate(
        params.prompt,
        maxTokens,
        temperature,
        topP,
        onToken
      );
      const resultText = text as string;
      console.info(`[GGUFService] 推理完成, 输出长度=${resultText.length}`);
      return {
        text: resultText,
        success: true,
        tokensGenerated: resultText.length
      };
    } catch (e) {
      const errMsg = `生成失败: ${e}`;
      console.error(`[GGUFService] ${errMsg}`);
      return {
        text: '',
        success: false,
        error: errMsg
      };
    }
  }

  /** Unload the current model and free resources. */
  unloadModel(): void {
    if (this.nativeAvailable && this.loaded) {
      try {
        gguf.unloadModel();
      } catch (e) {
        console.error(`[GGUFService] Unload failed: ${e}`);
      }
    }
    this.loaded = false;
    this.currentModelPath = '';
  }

  /** Check if a model is currently loaded. */
  isLoaded(): boolean {
    if (!this.nativeAvailable) return false;
    try {
      return gguf.isModelLoaded();
    } catch (e) {
      return false;
    }
  }

  /** Get current model metadata. */
  getModelInfo(): GGUFModelInfo | null {
    if (!this.nativeAvailable || !this.loaded) return null;
    try {
      const jsonStr = gguf.getModelInfo();
      return JSON.parse(jsonStr) as GGUFModelInfo;
    } catch (e) {
      return null;
    }
  }

  /** Abort current generation. */
  abort(): void {
    if (this.nativeAvailable) {
      try {
        gguf.abort();
      } catch (e) {
        // ignore
      }
    }
  }

  /** Get current model file path. */
  getCurrentModelPath(): string {
    return this.currentModelPath;
  }

  /**
   * Ensure model is loaded from settings. Auto-loads if path is configured
   * but model isn't loaded yet.
   */
  async ensureModelLoaded(): Promise<boolean> {
    if (this.isLoaded()) return true;

    const settings = settingsManager.settings;
    if (!settings.localModelPath) {
      return false;
    }

    const contextLength = settings.ggufContextLength ?? 2048;
    const threads = settings.ggufThreads ?? 4;
    return await this.loadModel({
      modelPath: settings.localModelPath,
      contextLength: contextLength,
      threads: threads
    });
  }
}

export const ggufService = new GGUFServiceClass();
