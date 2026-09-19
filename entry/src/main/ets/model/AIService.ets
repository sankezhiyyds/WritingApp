import { settingsManager } from './SettingsManager';
import { ggufService } from './GGUFService';
import http from '@ohos.net.http';
import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';

export interface AIResponse {
  content: string;
  thoughtChain?: string;
  success: boolean;
  error?: string;
}

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  max_tokens?: number;
}

interface ChatChoice {
  message: ChatMessage;
}

interface ChatResponseData {
  choices: ChatChoice[];
}

interface BaiduResponseData {
  result: string;
}

interface CustomResponseData {
  content?: string;
  response?: string;
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

  async callAI(prompt: string, context?: string): Promise<AIResponse> {
    // 全面使用本地GGUF大模型，无需API Key
    return await this.callLocalGGUF(prompt, context);
  }

  private async callDeepSeek(prompt: string, context?: string): Promise<AIResponse> {
    const settings = settingsManager.settings;
    const url = settings.customUrl || 'https://api.deepseek.com/v1/chat/completions';

    const messages: ChatMessage[] = [
      {
        role: 'system',
        content: this.buildSystemPrompt()
      }
    ];

    if (context) {
      messages.push({
        role: 'user',
        content: context
      });
    }

    messages.push({
      role: 'user',
      content: prompt
    });

    const requestBody: ChatRequestBody = {
      model: 'deepseek-chat',
      messages: messages,
      temperature: 0.7,
      max_tokens: 2000
    };

    try {
      const httpRequest = http.createHttp();
      const timeout = settings.aiTimeout * 1000; // 转换为毫秒
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${settings.apiKey}`
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: timeout,
        readTimeout: timeout
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as ChatResponseData;
        const content: string = data.choices[0].message.content;

        // 提取思维链路（如果有的话）
        const thoughtChain = this.extractThoughtChain(content);

        return {
          content: content,
          thoughtChain: thoughtChain,
          success: true
        };
      } else {
        return {
          content: '',
          success: false,
          error: `API返回错误: ${response.responseCode}`
        };
      }
    } catch (e) {
      return {
        content: '',
        success: false,
        error: '请求失败: ' + JSON.stringify(e)
      };
    }
  }

  private async callGLM(prompt: string, context?: string): Promise<AIResponse> {
    // 智谱GLM API实现
    const settings = settingsManager.settings;
    const url = settings.customUrl || 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

    const messages: ChatMessage[] = [
      { role: 'system', content: this.buildSystemPrompt() }
    ];

    if (context) {
      messages.push({ role: 'user', content: context });
    }
    messages.push({ role: 'user', content: prompt });

    try {
      const httpRequest = http.createHttp();
      const timeout = settings.aiTimeout * 1000;
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${settings.apiKey}`
        },
        extraData: JSON.stringify({
          model: 'glm-4',
          messages: messages,
          temperature: 0.7
        }),
        connectTimeout: timeout,
        readTimeout: timeout
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as ChatResponseData;
        return {
          content: data.choices[0].message.content,
          thoughtChain: this.extractThoughtChain(data.choices[0].message.content),
          success: true
        };
      }
      return { content: '', success: false, error: `API错误: ${response.responseCode}` };
    } catch (e) {
      return { content: '', success: false, error: '请求失败: ' + JSON.stringify(e) };
    }
  }

  private async callBaidu(prompt: string, context?: string): Promise<AIResponse> {
    // 百度文心API实现
    const settings = settingsManager.settings;
    const url = settings.customUrl || 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions_pro';

    const messages: ChatMessage[] = [
      { role: 'user', content: context ? `${context}\n\n${prompt}` : prompt }
    ];

    try {
      const httpRequest = http.createHttp();
      const timeout = settings.aiTimeout * 1000;
      const response = await httpRequest.request(url + `?access_token=${settings.apiKey}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ messages: messages }),
        connectTimeout: timeout,
        readTimeout: timeout
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as BaiduResponseData;
        return {
          content: data.result,
          thoughtChain: this.extractThoughtChain(data.result),
          success: true
        };
      }
      return { content: '', success: false, error: `API错误: ${response.responseCode}` };
    } catch (e) {
      return { content: '', success: false, error: '请求失败: ' + JSON.stringify(e) };
    }
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
      const loaded = ggufService.loadModel({
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

    const fullPrompt = context ? `${context}\n\n${prompt}` : prompt;
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

  private async callCustomAPI(prompt: string, context?: string): Promise<AIResponse> {
    // 自定义API实现
    const settings = settingsManager.settings;
    if (!settings.customUrl) {
      return { content: '', success: false, error: '请先配置自定义API地址' };
    }

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(settings.customUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${settings.apiKey}`
        },
        extraData: JSON.stringify({
          prompt: context ? `${context}\n\n${prompt}` : prompt
        })
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as CustomResponseData;
        return {
          content: data.content || data.response || JSON.stringify(data),
          thoughtChain: this.extractThoughtChain(data.content || data.response || ''),
          success: true
        };
      }
      return { content: '', success: false, error: `API错误: ${response.responseCode}` };
    } catch (e) {
      return { content: '', success: false, error: '请求失败: ' + JSON.stringify(e) };
    }
  }

  private buildSystemPrompt(): string {
    const customPrompt = settingsManager.settings.customPrompt;
    if (customPrompt && customPrompt.trim().length > 0) {
      return customPrompt;
    }

    // 默认写作助手提示词
    return `你是一个专业的写作助手，擅长帮助用户创作各种类型的文字内容。

核心能力：
1. 根据用户提供的模板和要求，生成高质量的文本内容
2. 保持内容的连贯性和逻辑性
3. 用具体、生动的描述代替空洞的表述
4. 注重细节和情感表达

写作原则：
- 用42字写5个有效信息（信息密度高）
- 多写具体行为，少写空洞情绪词
- 用画面感强的描述代替抽象概念
- 保持节奏感，避免冗长

请根据用户的具体需求，提供专业、有创意的写作建议和内容。`;
  }

  private extractThoughtChain(content: string): string | undefined {
    // 尝试从AI回复中提取思维链路
    const thoughtMarkers = ['思考过程', '分析', '思路', '推理', '让我思考'];
    for (let i = 0; i < thoughtMarkers.length; i++) {
      const marker = thoughtMarkers[i];
      if (content.includes(marker)) {
        const index = content.indexOf(marker);
        const endIndex = content.indexOf('\n\n', index);
        if (endIndex !== -1) {
          return content.substring(index, endIndex);
        }
      }
    }
    return undefined;
  }
}

export const aiService = AIService.getInstance();
