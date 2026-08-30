import { settingsManager } from './SettingsManager';
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
    const settings = settingsManager.settings;

    // 小艺助手不需要API Key，使用系统内置能力
    if (settings.selectedModel === 'xiaoyi') {
      return await this.callXiaoyi(prompt, context);
    }

    if (!settings.apiKey) {
      return {
        content: '',
        success: false,
        error: '请先在设置中配置API Key'
      };
    }

    try {
      // 根据选择的模型调用不同的API
      switch (settings.selectedModel) {
        case 'deepseek':
          return await this.callDeepSeek(prompt, context);
        case 'glm':
          return await this.callGLM(prompt, context);
        case 'baidu':
          return await this.callBaidu(prompt, context);
        case 'xiaoyi':
          return await this.callXiaoyi(prompt, context);
        case 'gguf':
          return await this.callLocalGGUF(prompt, context);
        case 'custom':
          return await this.callCustomAPI(prompt, context);
        default:
          return await this.callDeepSeek(prompt, context);
      }
    } catch (e) {
      return {
        content: '',
        success: false,
        error: 'AI调用失败: ' + JSON.stringify(e)
      };
    }
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
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${settings.apiKey}`
        },
        extraData: JSON.stringify(requestBody)
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
        })
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
      const response = await httpRequest.request(url + `?access_token=${settings.apiKey}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ messages: messages })
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

  private async callXiaoyi(prompt: string, context?: string): Promise<AIResponse> {
    if (!this.context) {
      return {
        content: '',
        success: false,
        error: '小艺助手未初始化，请重启应用'
      };
    }

    try {
      // 通过Want拉起系统小艺助手，传入提示词
      const params: Record<string, string> = { 'query': prompt, 'type': 'text' };
      const wantParam: Want = {
        action: 'ohos.want.action.voiceAssistant',
        parameters: params
      };
      await this.context.startAbility(wantParam);
      return {
        content: '已打开系统小艺助手，请在小艺中查看生成结果，\n完成后可复制内容回到本应用。',
        success: true
      };
    } catch (e) {
      // 部分设备可能不支持voiceAssistant action，尝试备用方案
      try {
        const fallbackParams: Record<string, string> = { 'query': prompt };
        const fallbackWant: Want = {
          action: 'ohos.want.action.home',
          parameters: fallbackParams
        };
        await this.context.startAbility(fallbackWant);
        return {
          content: '已尝试打开系统助手，请手动输入提示词。',
          success: true
        };
      } catch (e2) {
        return {
          content: '',
          success: false,
          error: '无法启动小艺助手，请确认设备支持该功能'
        };
      }
    }
  }

  /**
   * 直接打开系统小艺助手（公开方法，供UI调用）
   */
  async openXiaoyiAssistant(prompt?: string): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    try {
      const params: Record<string, string> = prompt ? { 'query': prompt, 'type': 'text' } : {};
      const wantParam: Want = {
        action: 'ohos.want.action.voiceAssistant',
        parameters: params
      };
      await this.context.startAbility(wantParam);
      return true;
    } catch (e) {
      return false;
    }
  }

  private async callLocalGGUF(prompt: string, context?: string): Promise<AIResponse> {
    // 本地GGUF模型调用（示例）
    return {
      content: '[本地GGUF模型需要配置本地服务]\n\n当前提示: ' + prompt,
      success: true
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
    for (const marker of thoughtMarkers) {
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
