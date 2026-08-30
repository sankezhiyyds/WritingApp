import { settingsManager } from './SettingsManager';
import http from '@ohos.net.http';

export interface AIResponse {
  content: string;
  thoughtChain?: string;
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

  async callAI(prompt: string, context?: string): Promise<AIResponse> {
    const settings = settingsManager.settings;

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

    const messages = [
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

    const requestBody = {
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
        const data = JSON.parse(response.result as string);
        const content = data.choices[0].message.content;

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

    const messages = [
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
        const data = JSON.parse(response.result as string);
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

    const messages = [
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
        const data = JSON.parse(response.result as string);
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
    // 小艺Agent API实现（示例）
    return {
      content: '[小艺Agent接口需要配置]\n\n当前提示: ' + prompt,
      success: true
    };
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
        const data = JSON.parse(response.result as string);
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
