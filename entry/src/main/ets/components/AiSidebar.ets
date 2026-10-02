import { aiService } from '../model/AIService';
import { settingsManager } from '../model/SettingsManager';
import { workManager, Conversation } from '../model/WorkManager';
import { BreakpointType } from '../model/ResponsiveManager';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import pasteboard from '@ohos.pasteboard';

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
  @Prop workId: string = '';
  /** 当前断点 */
  @Prop currentBreakpoint: BreakpointType = 'sm';
  /** 深色模式 */
  @Prop isDarkMode: boolean = false;
  /** 侧栏是否可见 */
  @Link isVisible: boolean;

  /** AI对话内容 */
  @State @Watch('rebuildRounds') aiConversation: string = '';
  /** 缓存解析后的对话轮次，避免每帧重复解析 */
  private cachedRounds: ConversationRound[] = [];
  /** 当前输入 */
  @State currentPrompt: string = '';
  /** 是否正在生成 */
  @State isGenerating: boolean = false;
  /** 引擎警告 */
  @State engineWarning: string = '';
  /** 是否显示查找替换 */
  @State showFindReplace: boolean = false;

  /** 缓存偏好实例 */
  private prefs: preferences.Preferences | null = null;
  /** 按workId隔离的缓存key，避免不同作品共享同一对话缓存 */
  private get cacheKey(): string {
    return `ai_sidebar_cache_${this.workId}`;
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
    this.initCache();
    this.checkEngineStatus();
  }

  aboutToDisappear() {
    this.saveCache();
  }

  /** 初始化缓存 */
  async initCache() {
    try {
      const context = AppStorage.get<common.UIAbilityContext>('appContext');
      if (context) {
        this.prefs = await preferences.getPreferences(context, 'writing_app_prefs');
        const cachedConversation = await this.prefs.get(this.cacheKey + '_conversation', '');
        const cachedPrompt = await this.prefs.get(this.cacheKey + '_prompt', '');
        if (cachedConversation && (cachedConversation as string).length > 0) {
          this.aiConversation = cachedConversation as string;
        }
        if (cachedPrompt && (cachedPrompt as string).length > 0) {
          this.currentPrompt = cachedPrompt as string;
        }
      }
    } catch (e) {
      console.warn('[AiSidebar] 初始化缓存失败: ' + e);
    }
  }

  /** 保存缓存 */
  async saveCache() {
    try {
      if (this.prefs) {
        await this.prefs.put(this.cacheKey + '_conversation', this.aiConversation);
        await this.prefs.put(this.cacheKey + '_prompt', this.currentPrompt);
        await this.prefs.flush();
      }
    } catch (e) {
      console.warn('[AiSidebar] 保存缓存失败: ' + e);
    }
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
    this.cachedRounds = this.parseConversationRounds();
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
        const userMsg = trimmed.substring(userIdx + 5, aiIdx).trim();
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
      systemPasteboard.setData(pasteData);
      this.safeToast('已复制到剪贴板');
    } catch (e) {
      console.error('[AiSidebar] copyToClipboard failed: ' + JSON.stringify(e));
      this.safeToast('复制失败');
    }
  }

  /** 发送AI消息 */
  async sendAiMessage() {
    if (this.currentPrompt.trim().length === 0) return;
    if (!settingsManager.settings.localModelPath) {
      this.safeToast('请先在设置中选择GGUF模型文件');
      return;
    }

    this.isGenerating = true;
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
      // 流式模式：实时占位并逐 token 刷新，生成完成时再规范化并落库
      // 用户消息已以单换行结尾，AI占位紧跟其后（同轮次内单换行分隔，轮次间双换行）
      this.aiConversation += '【AI】';
      const response = await aiService.callAI(userMessage, context, (token: string) => {
        this.aiConversation += token;
      });

      if (response.success) {
        if (response.content.length > 0) {
          // 去除占位的【AI】后整体规范化，避免流式拼接残留
          const lastMarkerIndex = this.aiConversation.lastIndexOf('【AI】');
          if (lastMarkerIndex >= 0) {
            this.aiConversation = this.aiConversation.substring(0, lastMarkerIndex) + '【AI】' + response.content + '\n\n';
          } else {
            this.aiConversation += '\n\n';
          }

          // 保存对话记录到WorkManager
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
      this.saveCache();
    }
  }

  /** 清空对话 */
  clearConversation() {
    this.aiConversation = '';
    this.saveCache();
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
          .fontColor('#FFFFFF')
          .backgroundColor('#10B981')
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
            .fontColor('#F59E0B')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.isDarkMode ? 'rgba(245,158,11,0.1)' : 'rgba(245,158,11,0.08)')
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
                  .fontColor('#10B981')
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(24)
            .justifyContent(FlexAlign.Center)
          } else {
            // 对话内容（按轮次渲染，每轮支持一键复制）
            ForEach(this.cachedRounds, (round: ConversationRound, index: number) => {
              Column() {
                // 用户消息
                Row() {
                  Text('👤 ')
                    .fontSize(this.sf(12))
                  Text(round.userMessage)
                    .fontSize(this.sf(13))
                    .fontColor(this.sidebarTextColor)
                    .lineHeight(20)
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })

                // AI回复（含复制按钮）
                Row() {
                  Text('AI ')
                    .fontSize(this.sf(12))
                  Text(round.aiResponse)
                    .fontSize(this.sf(13))
                    .fontColor('#10B981')
                    .lineHeight(20)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Start)

                  Blank()

                  Button('📋')
                    .fontSize(this.sf(12))
                    .backgroundColor(Color.Transparent)
                    .fontColor(this.sidebarSubTextColor)
                    .width(28)
                    .height(28)
                    .padding(0)
                    .onClick(() => {
                      this.copyToClipboard(round.aiResponse);
                    })
                }
                .width('100%')
                .padding({ top: 4, bottom: 8 })

                // 轮次分隔线
                if (index < this.cachedRounds.length - 1) {
                  Divider()
                    .height(0.5)
                    .color(this.isDarkMode ? '#3A3A4E' : '#E0E0E0')
                    .margin({ top: 4, bottom: 4 })
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
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
            .maxLines(this.isWideLayout ? 6 : 4)
            .constraintSize({ minHeight: 40, maxHeight: 120 })
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
            .fontColor('#FFFFFF')
            .backgroundColor(this.isGenerating ? '#9CA3AF' : '#10B981')
            .borderRadius(8)
            .height(40)
            .margin({ left: 8 })
            .enabled(!this.isGenerating)
            .onClick(() => this.sendAiMessage())
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
