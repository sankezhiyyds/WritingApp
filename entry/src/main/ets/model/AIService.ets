import { settingsManager } from './SettingsManager';
import { ggufService } from './GGUFService';
import common from '@ohos.app.ability.common';

export interface AIResponse {
  content: string;
  success: boolean;
  error?: string;
}

export class AIService {
  private static instance: AIService | null = null;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /** 本地 GGUF 大模型推理（唯一 AI 后端，无需云端 API / Key） */
  async callAI(prompt: string, context?: string): Promise<AIResponse> {
    return await this.callLocalGGUF(prompt, context);
  }

  private async callLocalGGUF(prompt: string, context?: string): Promise<AIResponse> {
    const settings = settingsManager.settings;
    console.info('[AIService] callLocalGGUF 开始, prompt长度=' + prompt.length);

    if (!settings.localModelPath) {
      console.warn('[AIService] localModelPath 为空');
      return { content: '', success: false, error: '请先在设置中选择 GGUF 模型文件' };
    }

    if (!ggufService.isNativeAvailable()) {
      console.warn('[AIService] 原生模块不可用');
      return {
        content: '',
        success: false,
        error: '本地推理引擎未安装。\n\n请将 llama.cpp 源码放入 entry/src/main/cpp/third_party/llama.cpp 并重新构建。'
      };
    }

    if (ggufService.isStubMode()) {
      console.warn('[AIService] 占位模式，llama.cpp未编译');
      return {
        content: '',
        success: false,
        error: '本地推理引擎为占位模式（llama.cpp 未编译）。\n\n当前无法执行真正的AI推理。请编译 llama.cpp 后重新构建应用。\n\n您仍可使用写作模板、手动编辑等功能。'
      };
    }

    if (!ggufService.isLoaded()) {
      console.info('[AIService] 模型未加载，尝试加载: ' + settings.localModelPath);
      const loaded = await ggufService.loadModel({
        modelPath: settings.localModelPath,
        contextLength: settings.ggufContextLength ?? 2048,
        threads: settings.ggufThreads ?? 4
      });
      if (!loaded) {
        console.error('[AIService] 模型加载失败');
        return { content: '', success: false, error: '模型加载失败，请检查文件路径和格式。\n\n路径: ' + settings.localModelPath };
      }
      console.info('[AIService] 模型加载成功');
    }

    // 组装 system prompt（自定义提示词）+ 上下文 + 用户输入
    const systemPrompt = (settings.customPrompt || '').trim();
    const parts: string[] = [];
    if (systemPrompt) {
      parts.push('系统指令：' + systemPrompt);
    }
    if (context) {
      parts.push(context);
    }
    parts.push(prompt);
    const fullPrompt = parts.join('\n\n');
    const maxTokens = settings.ggufMaxTokens ?? 512;
    const temperature = settings.ggufTemperature ?? 0.8;
    console.info(`[AIService] 调用generate, fullPrompt长度=${fullPrompt.length}, maxTokens=${maxTokens}, temp=${temperature}`);

    const result = await ggufService.generate({
      prompt: fullPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: 0.9
    });

    console.info(`[AIService] generate返回: success=${result.success}, text长度=${result.text.length}, error=${result.error || '无'}`);

    if (result.success && result.text.length === 0) {
      console.warn('[AIService] 推理成功但输出为空');
      return { content: '', success: false, error: 'AI模型返回了空内容，请尝试更换提示词或增大maxTokens设置。' };
    }

    return {
      content: result.text,
      success: result.success,
      error: result.error
    };
  }
}

export const aiService = AIService.getInstance();