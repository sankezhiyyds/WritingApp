import { aiService } from '../model/AIService';
import { settingsManager } from '../model/SettingsManager';
import { workManager } from '../model/WorkManager';
import { BreakpointType } from '../model/ResponsiveManager';
import { TemplateField } from '../model/TemplateModel';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';

/** 一轮对话（用户→AI） */
export interface ConversationRound {
  userMessage: string;
  aiResponse: string;
}

/**
 * 伴随式AI侧栏组件
 * 从工作台框架中独立出来，作为右侧伴随式侧栏展示
 * 支持多设备自适应：直板/折叠态/折叠展开/平板/PC
 * AI按钮为开启按钮，侧栏独立列展示
 */
@Component
export struct AiSidebar {
  /** 工作台内容（AI可读取用于辅助创作） */
  @Prop workbenchContent: string = '';
  /** 工作台标题 */
  @Prop workTitle: string = '';
  /** 工作ID（用于保存对话记录） */
  @Prop @Watch('onWorkIdChange') workId: string = '';
  /** 当前断点 */
  @Prop currentBreakpoint: BreakpointType = 'sm';
  /** 深色模式 */
  @Prop isDarkMode: boolean = false;
  /** 侧栏是否可见 */
  @Link isVisible: boolean;
  /** 模板ID（工作流任务隔离：不同模板区域视为不同任务） */
  @Prop templateId: string = '';
  /** 当前活跃的模板字段key（任务标识，切换时自动保存旧任务/加载新任务） */
  @Watch('onFieldKeyChange')
  @Link activeFieldKey: string;
  /** 模板字段列表（用于任务切换选择器） */
  @Prop templateFields: TemplateField[] = [];

  /** AI对话内容 */
  @State @Watch('rebuildRounds') aiConversation: string = '';
  /** 缓存解析后的对话轮次，避免每帧重复解析 */
  @State cachedRounds: ConversationRound[] = [];
  /** 当前输入 */
  @State currentPrompt: string = '';
  /** 是否正在生成 */
  @State isGenerating: boolean = false;
  /** 引擎警告 */
  @State engineWarning: string = '';
  /** 是否显示查找替换 */
  @State showFindReplace: boolean = false;
  /** App 进入后台时间戳（由 EntryAbility.onBackground 触发），用于即时保存对话缓存 */
  @Watch('onAppBackground')
  @StorageLink('appBackgroundSave') appBackgroundSaveTimestamp: number = 0;
  /** 流式输出 token 计数器，用于每 N 个 token 自动保存 */
  @State private tokenCount: number = 0;

  /** 缓存偏好实例 */
  private prefs: preferences.Preferences | null = null;
  /** 自动保存定时器ID */
  private autoSaveTimer: number = 0;
  /** 上一次 workId，用于检测作品切换 */
  private previousWorkId: string = '';
  /** 上一次 fieldKey，用于检测任务切换 */
  private previousFieldKey: string = '';
  /** 按任务隔离的对话映射表（key=taskId → conversation），切换任务时暂存当前对话 */
  private taskConversations: Map<string, string> = new Map();
  /** 按任务隔离的 prompt 映射表 */
  private taskPrompts: Map<string, string> = new Map();
  /** 按任务隔离的缓存key，避免不同模板区域/不同作品共享对话 */
  private get taskId(): string {
    if (this.templateId && this.activeFieldKey) {
      return `ai_task_${this.workId}_${this.templateId}_${this.activeFieldKey}`;
    }
    return `ai_task_${this.workId}`;
  }

  /** 字体缩放 */
  sf(size: number): number {
    const appFontSize = AppStorage.get<number>('appFontSize') || 14;
    return size * (appFontSize / 14);
  }

  /** 主题色 */
  get textColor(): string {
    return this.isDarkMode ? '#E5E7EB' : '#1A1A2E';
  }
  get subTextColor(): string {
    return this.isDarkMode ? '#9CA3AF' : '#6B7280';
  }
  get bgColor(): string {
    return this.isDarkMode ? '#1A1A2E' : '#F5F5F5';
  }
  get cardBg(): string {
    return this.isDarkMode ? '#252535' : '#FFFFFF';
  }
  get dividerColor(): string {
    return this.isDarkMode ? '#3A3A4E' : '#E5E7EB';
  }

  /** 侧栏宽度 - 根据断点自适应，窄屏使用独立列但不侵占编辑器 */
  get sidebarWidth(): string {
    switch (this.currentBreakpoint) {
      case 'sm': return '360vp'; // 直板手机：独立列，不覆盖编辑器
      case 'md': return '320vp'; // 折叠态/小平板
      case 'lg': return '300vp'; // 折叠展开/平板/PC
      default: return '360vp';
    }
  }

  /** 是否为宽屏（固定列模式） */
  get isWideLayout(): boolean {
    return this.currentBreakpoint === 'lg';
  }

  aboutToAppear() {
    this.initCache().catch((e: Error) => console.warn('[AiSidebar] initCache失败: ' + e));
    this.checkEngineStatus();
    this.previousWorkId = this.workId;
    this.previousFieldKey = this.activeFieldKey;
    this.startAutoSave();
  }

  aboutToDisappear() {
    this.stopAutoSave();
    // 离开前保存当前对话（异步完成后通过 then 确保追踪）
    this.saveCache().then(() => {
      console.info('[AiSidebar] 离开页面缓存保存完成');
    }).catch((e: Error) => {
      console.error('[AiSidebar] 离开页面缓存保存失败: ' + e);
    });
  }

  /** 初始化缓存：优先从 WorkManager 作品数据（aiContent）恢复，其次偏好缓存 */
  async initCache() {
    try {
      // 1. 从 WorkManager 作品数据加载已持久化的完整对话（"暂存"保存到此）
      if (this.workId.length > 0) {
        const work = workManager.getWork(this.workId);
        if (work && work.aiContent && (work.aiContent as string).length > 0) {
          console.info('[AiSidebar] 从作品数据恢复AI对话，workId=' + this.workId);
          this.aiConversation = work.aiContent as string;
          this.taskConversations.set(this.taskId, work.aiContent as string);
        }
      }

      // 2. 从偏好缓存加载（仅当 WorkManager 无数据时，作为补充）
      if (this.aiConversation.length === 0) {
        const context = AppStorage.get<common.UIAbilityContext>('appContext');
        if (context) {
          this.prefs = await preferences.getPreferences(context, 'writing_app_prefs');
          const cachedConversation = await this.prefs.get(this.taskId + '_conversation', '');
          const cachedPrompt = await this.prefs.get(this.taskId + '_prompt', '');
          if (cachedConversation && (cachedConversation as string).length > 0) {
            this.aiConversation = cachedConversation as string;
            // 同步写入内存映射表，供后续任务切换直接使用
            this.taskConversations.set(this.taskId, cachedConversation as string);
          }
          if (cachedPrompt && (cachedPrompt as string).length > 0) {
            this.currentPrompt = cachedPrompt as string;
            this.taskPrompts.set(this.taskId, cachedPrompt as string);
          }
          // 恢复上次活跃的工作流任务（模板字段选择）
          if (this.workId.length > 0 && this.templateId.length > 0) {
            const savedFieldKey = await this.prefs.get('ai_workflow_' + this.workId + '_activeFieldKey', '');
            if (savedFieldKey && savedFieldKey !== this.activeFieldKey) {
              // 先加载目标字段任务的对话缓存
              const targetTaskId = `ai_task_${this.workId}_${this.templateId}_${savedFieldKey}`;
              const targetConv = await this.prefs.get(targetTaskId + '_conversation', '');
              const targetPrompt = await this.prefs.get(targetTaskId + '_prompt', '');
              // 将目标任务的对话存入内存映射表
              if (targetConv && (targetConv as string).length > 0) {
                this.taskConversations.set(targetTaskId, targetConv as string);
              }
              if (targetPrompt && (targetPrompt as string).length > 0) {
                this.taskPrompts.set(targetTaskId, targetPrompt as string);
              }
              // 设置 activeFieldKey 恢复任务选择状态
              this.activeFieldKey = savedFieldKey as string;
              // 如果内存映射表中有对话，立即恢复
              const memConv = this.taskConversations.get(targetTaskId);
              if (memConv !== undefined) {
                this.aiConversation = memConv;
                this.currentPrompt = this.taskPrompts.get(targetTaskId) || '';
              }
            }
          }
          // 同步 previousFieldKey 以确保后续 onFieldKeyChange 可正常触发任务保存/切换
          this.previousFieldKey = this.activeFieldKey;
        }
      }
    } catch (e) {
      console.warn('[AiSidebar] 初始化缓存失败: ' + e);
    }
  }

  /** 保存缓存到 preferences 和 WorkManager（持久化） */
  async saveCache() {
    try {
      // 1. 保存到 preferences（快速恢复缓存）
      if (!this.prefs) {
        const context = AppStorage.get<common.UIAbilityContext>('appContext');
        if (context) {
          this.prefs = await preferences.getPreferences(context, 'writing_app_prefs');
        }
      }
      if (this.prefs) {
        await this.prefs.put(this.taskId + '_conversation', this.aiConversation);
        await this.prefs.put(this.taskId + '_prompt', this.currentPrompt);
        // 记住当前活跃的工作流任务，以便重新打开时恢复
        if (this.workId.length > 0 && this.templateId.length > 0) {
          await this.prefs.put('ai_workflow_' + this.workId + '_activeFieldKey', this.activeFieldKey);
        }
        await this.prefs.flush();
      }

      // 2. 同步保存到 WorkManager（持久化到作品数据，确保保存后打开不丢失）
      if (this.workId.length > 0 && this.aiConversation.length > 0) {
        workManager.updateAiContent(this.workId, this.aiConversation);
      }
    } catch (e) {
      console.warn('[AiSidebar] 保存缓存失败: ' + e);
    }
  }

  /** 启动自动保存定时器（每30秒），类似 PromptEditorPage 的自动保存模式 */
  private startAutoSave(): void {
    this.stopAutoSave();
    this.autoSaveTimer = setInterval(() => {
      this.saveCache().then(() => {
        console.info('[AiSidebar] 自动保存对话缓存完成');
      }).catch((e: Error) => {
        console.warn('[AiSidebar] 自动保存对话缓存失败: ' + e);
      });
    }, 30000);
    console.info('[AiSidebar] 自动保存定时器已启动（30秒间隔）');
  }

  /** 停止自动保存定时器 */
  private stopAutoSave(): void {
    if (this.autoSaveTimer > 0) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = 0;
      console.info('[AiSidebar] 自动保存定时器已停止');
    }
  }

  /** workId 变化时自动保存旧作品对话 + 加载新作品对话 */
  onWorkIdChange(newWorkId: string): void {
    if (this.previousWorkId && this.previousWorkId !== newWorkId) {
      // 保存当前对话到内存中的任务映射表
      const oldTaskId = this.templateId && this.activeFieldKey
        ? `ai_task_${this.previousWorkId}_${this.templateId}_${this.activeFieldKey}`
        : `ai_task_${this.previousWorkId}`;
      if (this.aiConversation.length > 0) {
        this.taskConversations.set(oldTaskId, this.aiConversation);
        this.taskPrompts.set(oldTaskId, this.currentPrompt);
      }
      // 持久化到 preferences
      this.saveCacheForWorkId(this.previousWorkId).then(() => {
        console.info(`[AiSidebar] 旧作品(${this.previousWorkId})对话已保存`);
      }).catch((e: Error) => {
        console.warn('[AiSidebar] 旧作品对话保存失败: ' + e);
      });
    }

    // ★ 修复：新建作品时 workId 从 '' → 'realId'，将对话迁移保存到新 workId
    if ((!this.previousWorkId || this.previousWorkId.length === 0) && newWorkId.length > 0 && this.aiConversation.length > 0) {
      const newTaskId = this.templateId && this.activeFieldKey
        ? `ai_task_${newWorkId}_${this.templateId}_${this.activeFieldKey}`
        : `ai_task_${newWorkId}`;
      // 保存到 preferences（新 key）
      try {
        if (this.prefs) {
          this.prefs.put(newTaskId + '_conversation', this.aiConversation).catch((e: Error) => {
            console.warn('[AiSidebar] 保存对话到preferences失败: ' + e);
          });
          this.prefs.flush().catch((e: Error) => {
            console.warn('[AiSidebar] flush失败: ' + e);
          });
        }
        // 保存到 WorkManager（持久化到作品数据）
        workManager.updateAiContent(newWorkId, this.aiConversation);
        console.info('[AiSidebar] 新建作品对话已迁移保存，newWorkId=' + newWorkId);
      } catch (e) {
        console.warn('[AiSidebar] 新建作品对话迁移保存失败: ' + e);
      }
    }

    this.previousWorkId = newWorkId;
    // 重置对话为空白（新作品无对话历史），由 initCache 从缓存中恢复
    this.aiConversation = '';
    this.currentPrompt = '';
    this.cachedRounds = [];
    this.initCache().catch((e: Error) => console.warn('[AiSidebar] initCache失败: ' + e));
  }

  /** 为指定 workId 保存对话缓存（使用 taskId 格式） */
  private async saveCacheForWorkId(targetWorkId: string): Promise<void> {
    try {
      if (this.prefs) {
        // 保存该 workId 下所有任务对话
        const tasksToSave: Map<string, string> = new Map();
        this.taskConversations.forEach((conv: string, taskId: string) => {
          if (taskId.includes(targetWorkId)) {
            tasksToSave.set(taskId, conv);
          }
        });
        // 如果有当前任务的对话未存入 map，也一起保存
        const currentTaskId = this.templateId && this.activeFieldKey
          ? `ai_task_${targetWorkId}_${this.templateId}_${this.activeFieldKey}`
          : `ai_task_${targetWorkId}`;
        if (!tasksToSave.has(currentTaskId) && this.aiConversation.length > 0) {
          tasksToSave.set(currentTaskId, this.aiConversation);
        }
        tasksToSave.forEach((conv: string, taskId: string) => {
          this.prefs?.put(taskId + '_conversation', conv).catch((e: Error) => {
            console.warn('[AiSidebar] 保存任务对话失败: ' + e);
          });
        });
        await this.prefs.flush();
      }
    } catch (e) {
      console.warn(`[AiSidebar] 保存缓存(${targetWorkId})失败: ` + e);
    }
  }

  /** fieldKey 变化时切换工作流任务：保存当前任务对话，加载新任务对话 */
  onFieldKeyChange(newFieldKey: string): void {
    if (this.previousFieldKey === newFieldKey) return;

    // 保存当前任务对话到内存映射表（仅当已有有效 fieldKey 时）
    if (this.previousFieldKey.length > 0) {
      const oldTaskId = `ai_task_${this.workId}_${this.templateId}_${this.previousFieldKey}`;
      this.taskConversations.set(oldTaskId, this.aiConversation);
      this.taskPrompts.set(oldTaskId, this.currentPrompt);
      console.info(`[AiSidebar] 任务切换: ${this.previousFieldKey} → ${newFieldKey}，已暂存旧任务对话`);
    }

    this.previousFieldKey = newFieldKey;

    // 加载新任务对话（优先从内存映射表获取，否则从缓存加载）
    const newTaskId = `ai_task_${this.workId}_${this.templateId}_${newFieldKey}`;
    const cachedConv = this.taskConversations.get(newTaskId);
    if (cachedConv !== undefined) {
      this.aiConversation = cachedConv;
      this.currentPrompt = this.taskPrompts.get(newTaskId) || '';
      console.info(`[AiSidebar] 已从内存恢复任务(${newFieldKey})对话`);
    } else {
      this.aiConversation = '';
      this.currentPrompt = '';
      this.cachedRounds = [];
      this.initCache().catch((e: Error) => console.warn('[AiSidebar] initCache失败: ' + e));
    }
  }

  /** App 进入后台时由 @Watch 触发，立即保存对话缓存 */
  onAppBackground(): void {
    console.info('[AiSidebar] App进入后台，立即保存对话缓存');
    this.saveCache().then(() => {
      console.info('[AiSidebar] App后台缓存保存完成');
    }).catch((e: Error) => {
      console.warn('[AiSidebar] App后台缓存保存失败: ' + e);
    });
  }

  /** 检查AI引擎状态 */
  checkEngineStatus() {
    if (!settingsManager.settings.localModelPath) {
      this.engineWarning = '未配置本地模型，请在设置中选择GGUF模型文件';
    } else {
      this.engineWarning = '';
    }
  }

  /** 获取主题色 */
  get sidebarBgColor(): string {
    return this.isDarkMode ? '#1F2033' : '#F8F9FA';
  }

  get sidebarTextColor(): string {
    return this.isDarkMode ? '#F5F5FA' : '#1A1A2E';
  }

  get sidebarSubTextColor(): string {
    return this.isDarkMode ? '#C4C6D3' : '#6B7280';
  }

  get sidebarCardBg(): string {
    return this.isDarkMode ? '#2B2C42' : '#FFFFFF';
  }

  get sidebarInputBg(): string {
    return this.isDarkMode ? '#2B2C42' : '#FFFFFF';
  }

  get sidebarButtonBg(): string {
    return '#FF2D55';
  }

  get buttonTextColor(): string {
    return '#FFFFFF';
  }

  get successColor(): string {
    return '#10B981';
  }

  get warningColor(): string {
    return '#F59E0B';
  }

  /** 安全弹出 Toast */
  safeToast(message: string, duration: number = 2000): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration });
    } catch (e) {
      console.error('[AiSidebar] showToast failed: ' + JSON.stringify(e));
    }
  }

  /** @Watch 回调：对话变更时刷新缓存 */
  rebuildRounds(): void {
    try {
      this.cachedRounds = this.parseConversationRounds();
    } catch (e) {
      console.error('[AiSidebar] rebuildRounds异常: ' + e);
      this.cachedRounds = [];
    }
  }

  /** 解析对话字符串为轮次列表 */
  parseConversationRounds(): ConversationRound[] {
    const rounds: ConversationRound[] = [];
    const parts = this.aiConversation.split('\n\n');
    for (const part of parts) {
      const trimmed = part.trim();
      if (!trimmed) continue;
      const userIdx = trimmed.indexOf('【用户】');
      const aiIdx = trimmed.indexOf('【AI】');
      if (userIdx >= 0 && aiIdx >= 0 && aiIdx > userIdx) {
        const userMsg = trimmed.substring(userIdx + 4, aiIdx).trim();
        const aiResp = trimmed.substring(aiIdx + 4).trim();
        if (userMsg.length > 0 || aiResp.length > 0) {
          rounds.push({ userMessage: userMsg, aiResponse: aiResp });
        }
      }
    }
    return rounds;
  }

  /** 复制文本到系统剪贴板 */
  copyToClipboard(text: string): void {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData).catch((e: Error) => {
        console.error('[AiSidebar] setData失败: ' + e);
      });
      this.safeToast('已复制到剪贴板');
    } catch (e) {
      console.error('[AiSidebar] copyToClipboard failed: ' + JSON.stringify(e));
      this.safeToast('复制失败');
    }
  }

  /** 发送AI消息 */
  async sendAiMessage() {
    if (this.currentPrompt.trim().length === 0) return;

    // 桩模式（预览模式）下无需真实 GGUF 模型文件即可对话
    if (!settingsManager.settings.localModelPath && !aiService.isStubMode()) {
      this.safeToast('请先在设置中选择GGUF模型文件');
      return;
    }

    this.isGenerating = true;
    this.tokenCount = 0;
    const userMessage = this.currentPrompt;
    this.currentPrompt = '';

    // 构建上下文：工作台内容 + 工作标题
    let context = '';
    if (this.workTitle.length > 0) {
      context += `当前作品：${this.workTitle}\n`;
    }
    if (this.workbenchContent.length > 0) {
      // 传递工作台内容作为上下文（最多2000字）
      context += `工作台内容：${this.workbenchContent.substring(0, 2000)}`;
    }

    // 追加用户消息到AI对话窗口
    this.aiConversation += (this.aiConversation.length > 0 ? '\n\n' : '') + '【用户】' + userMessage + '\n';

    try {
      // 流式模式：实时占位并逐 token 刷新
      this.aiConversation += '【AI】';

      // 首token超时：90s无首个token则判定超时并中断生成
      // 注意：超时后仅设置UI状态，不调用 ggufService.abort()
      // （native abort 在 decode 中调用会导致 SIGABRT 闪退，由 GGUFService 内部超时自行处理）
      let firstTokenReceived = false;
      const firstTokenTimeoutId = setTimeout(() => {
        if (!firstTokenReceived && this.isGenerating) {
          console.warn('[AiSidebar] 首token超时(90s)，重置生成状态，等待GGUFService内部超时');
          this.aiConversation += '\n\n（AI回复超时，请重试）\n\n';
          this.isGenerating = false;
          this.saveCache().catch((e: Error) => console.warn('[AiSidebar] saveCache失败: ' + e));
        }
      }, 90000);

      const response = await aiService.callAI(userMessage, context, (token: string) => {
        if (!firstTokenReceived) {
          firstTokenReceived = true;
          clearTimeout(firstTokenTimeoutId);
        }
        this.aiConversation += token;
        this.tokenCount++;
        // 每 30 个 token 自动保存一次，防止流式输出中闪退丢失
        if (this.tokenCount % 30 === 0) {
          this.saveCache().catch((e: Error) => console.warn('[AiSidebar] saveCache失败: ' + e));
        }
      });

      // 若超时已触发（isGenerating已被设为false），跳过后续处理
      if (!this.isGenerating) return;
      clearTimeout(firstTokenTimeoutId);

      if (response.success) {
        if (response.content.length > 0) {
          // 流式文本已通过 onToken 完整累积，仅追加双换行结束本轮
          this.aiConversation += '\n\n';

          // 保存对话记录到 WorkManager
          if (this.workId.length > 0) {
            const conversation = workManager.addConversation(this.workId, userMessage, response.content);
            if (!conversation) {
              console.warn('[AiSidebar] 保存对话记录失败');
            }
          }
        } else {
          this.aiConversation += '（无内容）\n\n';
        }
      } else {
        this.aiConversation += '生成失败：' + (response.error || '未知错误') + '\n\n';
      }
    } catch (e) {
      this.aiConversation += '发生异常：' + e + '\n\n';
    } finally {
      this.isGenerating = false;
      this.saveCache().catch((e: Error) => console.warn('[AiSidebar] saveCache失败: ' + e));
    }
  }

  /** 清空对话 */
  clearConversation() {
    this.aiConversation = '';
    this.saveCache().catch((e: Error) => console.warn('[AiSidebar] saveCache失败: ' + e));
  }

  /** 将AI输出插入工作台（只插入最后一条AI回复，不含用户消息和前缀） */
  insertToWorkbench() {
    if (this.aiConversation.length === 0) {
      this.safeToast('没有可插入的内容');
      return;
    }
    // 提取最后一条【AI】回复，去除前缀标记
    let insertContent = '';
    const aiMarker = '【AI】';
    const lastAiIndex = this.aiConversation.lastIndexOf(aiMarker);
    if (lastAiIndex >= 0) {
      // 取最后一条AI回复内容
      let raw = this.aiConversation.substring(lastAiIndex + aiMarker.length);
      // 去除末尾的多余换行
      insertContent = raw.replace(/\n+$/, '').trim();
    } else {
      // 没有AI标记时，直接使用全部内容
      insertContent = this.aiConversation.trim();
    }
    if (insertContent.length === 0) {
      this.safeToast('没有可插入的内容');
      return;
    }
    // 通过AppStorage传递AI内容到工作台
    AppStorage.setOrCreate('aiInsertContent', insertContent);
    this.safeToast('已插入到正文');
  }

  build() {
    // 侧栏容器 - 伴随式独立列模式（所有设备统一）
    if (this.isVisible) {
      Column() {
        this.SidebarContent()
      }
      .width(this.sidebarWidth)
      .height('100%')
      .backgroundColor(this.sidebarCardBg)
    }
  }

  @Builder
  SidebarContent() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('✨ AI助手')
          .fontSize(this.sf(16))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.sidebarTextColor)

        Blank()

        // 将最后一条 AI 建议暂存到书架（含模板+全部对话）
        Button('暂存')
          .fontSize(this.sf(12))
          .fontColor(this.buttonTextColor)
          .backgroundColor(this.successColor)
          .borderRadius(12)
          .height(28)
          .padding({ left: 12, right: 12 })
          .margin({ right: 8 })
          .onClick(() => {
            AppStorage.setOrCreate('aiAdoptSuggestion', this.aiConversation);
          })

        // 关闭按钮
        Text('×')
          .fontSize(this.sf(22))
          .fontColor(this.sidebarSubTextColor)
          .onClick(() => {
            this.isVisible = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.sidebarBgColor)

      // 引擎警告
      if (this.engineWarning.length > 0) {
        Row() {
          Text('⚠️ ' + this.engineWarning)
            .fontSize(this.sf(11))
            .fontColor(this.warningColor)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.isDarkMode ? 'rgba(245,158,11,0.1)' : 'rgba(245,158,11,0.08)')
      }

      // 工作流任务选择器（按模板字段切换任务）
      if (this.templateFields.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.templateFields, (field: TemplateField) => {
              Text(field.label)
                .fontSize(this.sf(12))
                .fontColor(field.key === this.activeFieldKey ? '#FFFFFF' : this.sidebarSubTextColor)
                .backgroundColor(field.key === this.activeFieldKey ? '#FF2D55' : 'transparent')
                .borderRadius(12)
                .height(28)
                .padding({ left: 12, right: 12 })
                .margin({ right: 6 })
                .flexShrink(0)
                .onClick(() => {
                  if (field.key !== this.activeFieldKey) {
                    this.activeFieldKey = field.key;
                  }
                })
            }, (field: TemplateField) => field.key)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        }
        .width('100%')
        .height(44)
        .scrollBar(BarState.Off)
      }

      // 对话内容区域
      Scroll() {
        Column() {
          if (this.aiConversation.length === 0) {
            // 空状态提示
            Column() {
              Text('📓 AI助手已就绪')
                .fontSize(this.sf(14))
                .fontColor(this.sidebarSubTextColor)
                .margin({ bottom: 8 })

              Text('输入问题，AI将基于工作台内容辅助创作')
                .fontSize(this.sf(12))
                .fontColor(this.sidebarSubTextColor)
                .textAlign(TextAlign.Center)

              // 显示工作台内容预览
              if (this.workbenchContent.length > 0) {
                Text(`已读取工作台内容（${this.workbenchContent.length}字）`)
                  .fontSize(this.sf(11))
                  .fontColor(this.successColor)
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(24)
            .justifyContent(FlexAlign.Center)
          } else {
            // 对话内容（气泡对话样式：用户左、AI右，均带复制按钮）
            ForEach(this.cachedRounds, (round: ConversationRound, index: number) => {
              Column() {
                // ===== 用户消息（左侧气泡） =====
                Row() {
                  // 用户头像（无 emoji，使用蓝色圆形+U文字）
                  Text('U')
                    .width(28)
                    .height(28)
                    .borderRadius(14)
                    .backgroundColor(this.isDarkMode ? '#455A64' : '#1565C0')
                    .textAlign(TextAlign.Center)
                    .fontColor(this.buttonTextColor)
                    .fontSize(this.sf(11))
                    .fontWeight(FontWeight.Bold)
                    .flexShrink(0)

                  // 用户气泡
                  Text(round.userMessage)
                    .fontSize(this.sf(13))
                    .fontColor(this.isDarkMode ? '#E0E0E0' : '#1A1A2E')
                    .lineHeight(20)
                    .backgroundColor(this.isDarkMode ? '#37474F' : '#E8F0FE')
                    .borderRadius(12)
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .maxLines(20)
                    .layoutWeight(1)
                    .margin({ left: 6, right: 6 })

                  // 复制按钮
                  Button() {
                    Text('📋')
                      .fontSize(this.sf(11))
                  }
                  .backgroundColor(Color.Transparent)
                  .width(24)
                  .height(24)
                  .padding(0)
                  .flexShrink(0)
                  .onClick(() => {
                    this.copyToClipboard(round.userMessage);
                  })
                }
                .width('100%')
                .padding({ top: 4, bottom: 4 })
                .justifyContent(FlexAlign.Start)

                // ===== AI回复（右侧气泡） =====
                Row() {
                  // 复制按钮
                  Button() {
                    Text('📋')
                      .fontSize(this.sf(11))
                  }
                  .backgroundColor(Color.Transparent)
                  .width(24)
                  .height(24)
                  .padding(0)
                  .flexShrink(0)
                  .onClick(() => {
                    this.copyToClipboard(round.aiResponse);
                  })

                  // AI气泡
                  if (round.aiResponse.length > 0) {
                    Text(round.aiResponse)
                      .fontSize(this.sf(13))
                      .fontColor(this.isDarkMode ? '#E0E0E0' : '#1A1A2E')
                      .lineHeight(20)
                      .backgroundColor(this.isDarkMode ? '#2E4A3A' : '#E8F5E9')
                      .borderRadius(12)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .maxLines(20)
                      .layoutWeight(1)
                      .margin({ left: 6, right: 6 })
                  } else if (this.isGenerating) {
                    Row() {
                      if (this.tokenCount === 0) {
                        Text('模型推理中...')
                          .fontSize(this.sf(13))
                          .fontColor(this.sidebarSubTextColor)
                          .lineHeight(20)
                      } else {
                        Text('思考中...')
                          .fontSize(this.sf(13))
                          .fontColor(this.sidebarSubTextColor)
                          .lineHeight(20)
                        Text('(' + this.tokenCount + ' tokens)')
                          .fontSize(this.sf(11))
                          .fontColor(this.sidebarSubTextColor)
                          .margin({ left: 6 })
                      }
                    }
                      .backgroundColor(this.isDarkMode ? '#2E4A3A' : '#E8F5E9')
                      .borderRadius(12)
                      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .layoutWeight(1)
                      .margin({ left: 6, right: 6 })
                  }

                  // AI头像（无 emoji，使用绿色圆形+AI文字）
                  Text('AI')
                    .width(28)
                    .height(28)
                    .borderRadius(14)
                    .backgroundColor(this.isDarkMode ? '#2E4A3A' : '#4CAF50')
                    .textAlign(TextAlign.Center)
                    .fontColor(this.buttonTextColor)
                    .fontSize(this.sf(10))
                    .fontWeight(FontWeight.Bold)
                    .flexShrink(0)
                }
                .width('100%')
                .padding({ top: 4, bottom: 4 })
                .justifyContent(FlexAlign.End)

                // 轮次分隔线
                if (index < this.cachedRounds.length - 1) {
                  Divider()
                    .height(0.5)
                    .color(this.isDarkMode ? '#3A3A4E' : '#E0E0E0')
                    .margin({ top: 4, bottom: 4 })
                }
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            }, (round: ConversationRound, index: number) => round.userMessage + round.aiResponse + index)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      // 底部输入区域
      Column() {
        // 清空按钮
        if (this.aiConversation.length > 0) {
          Row() {
            Blank()
            Button('清空对话')
              .fontSize(this.sf(11))
              .fontColor(this.sidebarSubTextColor)
              .backgroundColor(this.sidebarInputBg)
              .borderRadius(12)
              .height(24)
              .padding({ left: 10, right: 10 })
              .onClick(() => this.clearConversation())
          }
          .width('100%')
          .margin({ bottom: 4 })
        }

        // 输入框和发送按钮
        Row() {
          TextArea({ placeholder: '输入消息...', text: this.currentPrompt })
            .layoutWeight(1)
            .maxLines(8)
            .constraintSize({ minHeight: 40, maxHeight: 200 })
            .fontSize(this.sf(13))
            .fontColor(this.sidebarTextColor)
            .backgroundColor(this.sidebarInputBg)
            .borderRadius(8)
            .padding(8)
            .onChange((value: string) => {
              this.currentPrompt = value;
            })

          Button(this.isGenerating ? '...' : '发送')
            .fontSize(this.sf(13))
            .fontColor(this.buttonTextColor)
            .backgroundColor(this.isGenerating ? '#9CA3AF' : '#10B981')
            .borderRadius(8)
            .height(40)
            .margin({ left: 8 })
            .enabled(!this.isGenerating)
            .onClick(() => this.sendAiMessage().catch((e: Error) => console.error('[AiSidebar] sendAiMessage异常: ' + e)))
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor(this.sidebarBgColor)
    }
    .width('100%')
    .height('100%')
  }
}
