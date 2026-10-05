import { settingsManager } from './SettingsManager';
import { ggufService } from './GGUFService';
import { GGUFGenerateResult } from './GGUFService';

export interface AIResponse {
  content: string;
  success: boolean;
  error?: string;
}

export class AIService {
  private static instance: AIService | null = null;

  static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  /** 是否为桩模式（预览模式），无需真实模型即可生成模拟回复 */
  isStubMode(): boolean {
    return ggufService.isStubMode();
  }

  /**
   * 本地 GGUF 大模型推理（唯一 AI 后端，无需云端 API / Key）
   * @param onToken 可选的流式回调：每生成若干 token 时被调用，用于实时刷新 UI（效果最佳）
   */
  async callAI(prompt: string, context?: string, onToken?: (token: string) => void): Promise<AIResponse> {
    return await this.callLocalGGUF(prompt, context, onToken);
  }

  private async callLocalGGUF(prompt: string, context?: string, onToken?: (token: string) => void): Promise<AIResponse> {
    const settings = settingsManager.settings;
    console.info('[AIService] callLocalGGUF 开始, prompt长度=' + prompt.length);

    // 桩模式（预览模式）下无需真实 GGUF 模型文件即可对话
    if (!settings.localModelPath && !ggufService.isStubMode()) {
      console.warn('[AIService] localModelPath 为空');
      return { content: '', success: false, error: '请先在设置中选择 GGUF 模型文件' };
    }

    // 预览模式提示（桩引擎仍可生成模拟回复，不影响流程）
    if (ggufService.isStubMode()) {
      console.info('[AIService] 预览模式（桩引擎）：llama.cpp 未编译，将使用模拟推理');
    }

    // 桩模式（预览模式/llama.cpp未编译）下无需加载真实模型即可生成模拟回复
    if (!ggufService.isLoaded() && !ggufService.isStubMode()) {
      console.info('[AIService] 模型未加载，尝试加载: ' + settings.localModelPath);
      let loaded = false;
      try {
        loaded = await ggufService.loadModel({
          modelPath: settings.localModelPath,
          contextLength: settings.ggufContextLength ?? 2048,
          threads: settings.ggufThreads ?? 4
        });
      } catch (e) {
        // 兜底：模型文件损坏/格式错误时 NAPI 可能抛异常，避免未捕获 rejection
        console.error('[AIService] 模型加载异常: ' + e);
        return { content: '', success: false, error: '模型加载失败：' + e + '\n\n路径: ' + settings.localModelPath };
      }
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

    let result: GGUFGenerateResult;
    try {
      result = await ggufService.generate({
        prompt: fullPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        onToken: onToken
      });
    } catch (e) {
      // 兜底：NAPI 调用偶发异常不应导致未捕获 rejection，转为结构化失败返回
      console.error('[AIService] generate 调用异常: ' + e);
      return { content: '', success: false, error: 'AI 推理调用异常: ' + e };
    }

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