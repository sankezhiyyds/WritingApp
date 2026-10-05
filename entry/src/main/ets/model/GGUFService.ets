import { settingsManager } from './SettingsManager';
import fileIo from '@ohos.file.fs';
import { systemResourceMonitor } from './SystemResourceMonitor';
import { loadModel as nativeLoadModel, generate as nativeGenerate,
  unloadModel as nativeUnloadModel, isModelLoaded as nativeIsModelLoaded,
  getModelInfo as nativeGetModelInfo,
  abort as nativeAbort } from 'libgguf.so';

/**
 * GGUFService - ArkTS service layer for local GGUF model inference.
 *
 * Architecture (native):
 *   ArkTS (GGUFService) → NAPI (libgguf.so) → C++ (llama_runner) → llama.cpp
 *
 * When libgguf.so / llama.cpp is not compiled, the service falls back to a
 * built-in **preview stub** that simulates model loading and text generation.
 * This allows the front-end to function end-to-end for UI development and
 * demonstration purposes.
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

/**
 * 预览模式下的模拟响应池 — 根据 prompt 关键词返回对应的创作内容
 */
function getStubResponse(prompt: string): string {
  const p = prompt.toLowerCase();
  let response = '';

  if (p.includes('改写') || p.includes('重写') || p.includes('修改')) {
    response = '以下是根据您的要求改写后的版本：\n\n'
      + '暮色四合，天边最后一抹霞光也沉入地平线。街道两旁的梧桐在晚风中低语，'
      + '叶片摩挲出沙沙的声响，像是在交换着属于这个黄昏的秘密。路灯次第亮起，'
      + '橘黄色的光晕洒在青石板路上，拉长了行人匆匆的身影。';
  } else if (p.includes('润色') || p.includes('美化') || p.includes('优化')) {
    response = '润色后的版本如下：\n\n'
      + '那些被岁月打磨过的细节，在记忆里愈发清晰。她的指尖轻轻划过书页的边缘，'
      + '像是在触碰一段被时光封存的往事。窗外的阳光斜斜地照进来，在地板上投下斑驳的光影，'
      + '将整个房间渲染成一幅泛黄的老照片。';
  } else if (p.includes('续写') || p.includes('继续') || p.includes('写下去')) {
    response = '续写内容：\n\n'
      + '他站在原地，久久没有动。风从远处吹来，带着河水的潮湿气息和野花的淡淡香味。'
      + '那些曾经以为永远不会忘记的画面，此刻竟变得模糊起来，像是隔着一层水雾观望。'
      + '他知道，有些路一旦走过，就再也回不了头了。';
  } else if (p.includes('总结') || p.includes('摘要') || p.includes('概括')) {
    response = '根据您提供的文本，核心要点如下：\n\n'
      + '1. 故事围绕主人公的内心成长展开，通过外部事件的推进反映内在变化。\n'
      + '2. 环境描写在叙事中起到重要的氛围渲染作用，与人物情绪高度契合。\n'
      + '3. 对话设计富有层次感，既推进剧情又展现人物性格的多样性。\n'
      + '4. 结尾留有开放性，给予读者足够的想象空间。';
  } else if (p.includes('大纲') || p.includes('规划') || p.includes('结构')) {
    response = '以下是为您规划的作品大纲：\n\n'
      + '第一章 · 序曲：交代背景，引入主要人物，埋下核心矛盾的伏笔。\n'
      + '第二章 · 冲突：主要矛盾浮出水面，角色之间的关系开始发生变化。\n'
      + '第三章 · 转折：关键事件发生，主角面临重要抉择，故事走向改变。\n'
      + '第四章 · 高潮：冲突全面爆发，各条线索在此汇聚，张力达到顶点。\n'
      + '第五章 · 回响：余波渐平，角色获得新的认知，故事在回响中落幕。';
  } else if (p.includes('角色') || p.includes('人物') || p.includes('人设')) {
    response = '角色设定建议：\n\n'
      + '【姓名】待定\n'
      + '【年龄】可根据故事需要设定\n'
      + '【性格特征】内向细腻，善于观察，内心世界丰富。表面沉默寡言，'
      + '实则对周围的事物有着敏锐的感知力。在关键时刻能展现出超乎常人的勇气和决断力。\n'
      + '【成长弧线】从逃避→面对→接受→超越，完成从被动到主动的蜕变。';
  } else if (p.includes('世界观') || p.includes('设定') || p.includes('背景')) {
    response = '世界观设定建议：\n\n'
      + '这是一个介于现实与幻想之间的世界。表面上与现代社会无异，但在某些不为人知的角落，'
      + '存在着古老的法则和神秘的力量。普通人与"知情人"共同生活在这片土地上，'
      + '彼此间的界限时而清晰，时而模糊。\n\n'
      + '力量体系遵循"等价交换"原则——获得多少，就必须付出同等代价。'
      + '这一法则贯穿整个世界的运行逻辑，也决定了故事的走向和角色的命运。';
  } else {
    response = '收到您的创作请求。根据当前上下文，我建议从以下几个角度展开：\n\n'
      + '一、从场景氛围入手，通过环境描写烘托人物心理。细腻的环境刻画能让读者身临其境，与角色产生情感共鸣。\n\n'
      + '二、对话推进节奏，让角色间的对白自然流露性格与冲突。好的对话不仅传递信息，更能推动情节发展。\n\n'
      + '三、留白与暗示，给读者想象空间。克制比铺陈更有力量，恰到好处的留白能增强作品的文学质感。';
  }

  // 如果 prompt 包含工作台上下文，在回复中融入
  const ctxMatch = prompt.match(/工作台内容：(.+?)(?:\n|$)/);
  if (ctxMatch) {
    const contextSnippet = ctxMatch[1].substring(0, 50);
    response = `基于您当前的工作台内容「${contextSnippet}…」，我为您提供以下建议：\n\n${response}`;
  }

  return response;
}

class GGUFServiceClass {
  private loaded: boolean = false;
  private currentModelPath: string = '';
  private nativeAvailable: boolean = false;
  private aborted: boolean = false;
  /** 模型加载冷却：文件不存在或损坏时禁止频繁重试 */
  private lastModelLoadError: number = 0;
  private readonly MODEL_LOAD_COOLDOWN_MS: number = 30000; // 30秒
  /** 单飞守卫：llama context 为全局单例且非线程安全，同一时刻只允许一个推理任务 */
  private generateInFlight: boolean = false;

  constructor() {
    try {
      const loaded = nativeIsModelLoaded();
      this.nativeAvailable = (loaded === true || loaded === false);
    } catch (e) {
      console.info('[GGUFService] 原生模块不可用，启用预览模式（桩引擎）。');
      this.nativeAvailable = false;
    }
  }

  /** Check if the native GGUF inference module is available. */
  isNativeAvailable(): boolean {
    return this.nativeAvailable;
  }

  /** Check if running in stub/preview mode (llama.cpp not compiled). */
  isStubMode(): boolean {
    return !this.nativeAvailable;
  }

  /** Load a GGUF model from the device filesystem. */
  async loadModel(params: GGUFLoadParams): Promise<boolean> {
    if (!params.modelPath) {
      console.error('[GGUFService] Model path is empty');
      return false;
    }

    // 冷却检查：上次加载失败后 30 秒内不再重试，避免主线程阻塞
    const now = Date.now();
    if (now - this.lastModelLoadError < this.MODEL_LOAD_COOLDOWN_MS) {
      console.warn('[GGUFService] 跳过模型加载（冷却期内，距上次错误=' +
        Math.round((now - this.lastModelLoadError) / 1000) + 's）');
      return false;
    }

    if (this.nativeAvailable) {
      try {
        // eslint-disable-next-line @typescript-eslint/await-thenable
        const success = await nativeLoadModel(params.modelPath,
          params.contextLength ?? 1024, params.threads ?? 2);
        if (success) {
          this.loaded = true;
          this.currentModelPath = params.modelPath;
          console.info(`[GGUFService] Native model loaded: ${params.modelPath}`);
        }
        return success;
      } catch (e) {
        console.error(`[GGUFService] Native load failed: ${e}`);
        this.lastModelLoadError = Date.now(); // 设置冷却
        return false;
      }
    }

    // 预览模式：校验文件存在即可（模拟加载）
    try {
      const stat = fileIo.statSync(params.modelPath);
      console.info(`[GGUFService] 预览模式：模型文件已确认 (${Math.round(stat.size / 1024 / 1024)} MB)`);
      await new Promise<void>(resolve => setTimeout(resolve, 500));
      this.loaded = true;
      this.currentModelPath = params.modelPath;
      console.info(`[GGUFService] 预览模式：模型已加载 (桩)`);
      return true;
    } catch (e) {
      console.error(`[GGUFService] 预览模式：无法读取模型文件: ${e}`);
      return false;
    }
  }

  /** Generate text with optional streaming callback. */
  async generate(params: GGUFGenerateParams): Promise<GGUFGenerateResult> {
    // 惰性分配原则（借鉴 Kestrel 引擎）：极低电量时跳过 AI 推理
    if (systemResourceMonitor.shouldSkipAI()) {
      return {
        text: '',
        success: false,
        error: '电量过低，AI 推理已暂停。请连接充电器后再试。'
      };
    }

    if (!this.loaded) {
      return {
        text: '',
        success: false,
        error: '未加载模型。请先在设置中选择 GGUF 模型文件。'
      };
    }

    // 单飞守卫：llama context 全局单例且非线程安全，已有推理在跑时直接拒绝并发
    if (this.generateInFlight) {
      console.warn('[GGUFService] 已有推理任务在执行，忽略本次并发请求（单飞守卫）');
      return {
        text: '',
        success: false,
        error: 'AI 正在生成中，请稍候再试'
      };
    }
    this.generateInFlight = true;

    try {
      return await this.generateInner(params);
    } finally {
      this.generateInFlight = false;
    }
  }

  /** generate() 的实际执行体，由外层单飞守卫保护 */
  private async generateInner(params: GGUFGenerateParams): Promise<GGUFGenerateResult> {
    if (this.nativeAvailable) {
      const maxTokens = params.maxTokens ?? 256;
      const temperature = params.temperature ?? 0.8;
      const topP = params.topP ?? 0.9;
      const onToken = params.onToken ?? undefined;

      try {
        // 空闲看门狗：只要 token 持续产出就重置计时器，仅"长时间无任何token"才判定超时。
        // 注意：prefill 阶段（喂入整个 prompt，含上下文/历史对话）onToken 不触发，
        // CPU 推理 7B 级别模型 prefill 2000+ tokens 可能耗时数分钟，故阈值需足够大。
        const idleTimeoutMs = 60000;  // 空闲阈值 60s，覆盖 prefill + 首token
        const totalTimeoutMs = 120000; // 总兜底上限 120s，防真正死锁永久挂起
        let idleTimer: number = 0;
        let totalTimer: number = 0;
        const clearTimers = () => {
          if (idleTimer !== 0) {
            clearTimeout(idleTimer);
            idleTimer = 0;
          }
          if (totalTimer !== 0) {
            clearTimeout(totalTimer);
            totalTimer = 0;
          }
        };
        const armIdleTimer = () => {
          if (idleTimer !== 0) {
            clearTimeout(idleTimer);
          }
          idleTimer = setTimeout(() => {
            idleTimer = 0;
            nativeAbort();
          }, idleTimeoutMs);
        };
        armIdleTimer();
        totalTimer = setTimeout(() => {
          totalTimer = 0;
          if (idleTimer !== 0) {
            clearTimeout(idleTimer);
            idleTimer = 0;
          }
          nativeAbort();
        }, totalTimeoutMs);

        // 包装 onToken：每收到 token 即重置空闲计时器
        const wrappedOnToken = (token: string) => {
          armIdleTimer();
          if (onToken) {
            onToken(token);
          }
        };

        // eslint-disable-next-line @typescript-eslint/await-thenable
        const text = await nativeGenerate(params.prompt, maxTokens, temperature, topP, wrappedOnToken);
        clearTimers();
        const resultText = (text != null && text != undefined) ? String(text) : '';
        console.info(`[GGUFService] Native inference done, output=${resultText.length}chars`);
        return { text: resultText, success: true, tokensGenerated: resultText.length };
      } catch (e) {
        const errMsg = `生成失败: ${e}`;
        console.error(`[GGUFService] ${errMsg}`);
        return { text: '', success: false, error: errMsg };
      }
    }

    // ========== 预览模式（桩引擎） ==========
    const maxTokens = params.maxTokens ?? 256;
    const onToken = params.onToken ?? undefined;
    this.aborted = false;

    console.info(`[GGUFService] 预览模式：开始模拟推理, prompt=${params.prompt.length}chars, maxTokens=${maxTokens}`);

    // 生成模拟回复
    let response = getStubResponse(params.prompt);

    // 按 maxTokens 截断
    if (response.length > maxTokens * 2) {
      response = response.substring(0, maxTokens * 2) + '\n\n……（预览模式已截断）';
    }

    // 添加预览模式标识
    response += '\n\n[⚡ 预览模式 · 如需完整推理请编译 llama.cpp]';

    // 模拟流式输出
    if (onToken) {
      let emitted = 0;
      const chars = response.split('');
      const chunkSize = Math.max(1, Math.floor(chars.length / 20));

      for (let i = 0; i < chars.length && !this.aborted; i += chunkSize) {
        const chunk = chars.slice(i, Math.min(i + chunkSize, chars.length)).join('');
        onToken(chunk);
        emitted += chunk.length;
        await new Promise<void>(resolve => setTimeout(resolve, 30 + Math.random() * 30));
      }

      this.aborted = false;
      console.info(`[GGUFService] 预览模式：模拟推理完成, 输出=${emitted}chars`);
      return { text: response, success: true, tokensGenerated: emitted };
    }

    // 非流式：直接返回
    await new Promise<void>(resolve => setTimeout(resolve, 300 + Math.random() * 400));
    console.info(`[GGUFService] 预览模式：模拟推理完成 (非流式)`);
    return { text: response, success: true, tokensGenerated: response.length };
  }

  /** Unload the current model and free resources. */
  unloadModel(): void {
    if (this.nativeAvailable && this.loaded) {
      try {
        nativeUnloadModel();
      } catch (e) {
        console.error(`[GGUFService] Native unload failed: ${e}`);
      }
    }
    this.loaded = false;
    this.currentModelPath = '';
    console.info('[GGUFService] Model unloaded');
  }

  /** Check if a model is currently loaded. */
  isLoaded(): boolean {
    return this.loaded;
  }

  /** Get current model metadata. */
  getModelInfo(): GGUFModelInfo | null {
    if (!this.loaded) return null;

    if (this.nativeAvailable) {
      try {
        const jsonStr = nativeGetModelInfo();
        return JSON.parse(jsonStr) as GGUFModelInfo;
      } catch (e) {
        return null;
      }
    }

    return {
      name: this.currentModelPath.split('/').pop()?.split('\\').pop() || 'Local GGUF Model',
      params: 0,
      context: 2048,
      threads: 4,
    };
  }

  /** Abort current generation. */
  abort(): void {
    this.aborted = true;
    if (this.nativeAvailable) {
      try {
        nativeAbort();
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

    const contextLength = settings.ggufContextLength ?? 1024;
    const threads = settings.ggufThreads ?? 2;
    return await this.loadModel({
      modelPath: settings.localModelPath,
      contextLength: contextLength,
      threads: threads
    });
  }
}

export const ggufService = new GGUFServiceClass();
