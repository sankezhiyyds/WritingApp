import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager, Chapter, Conversation, WorkVersion } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { aiService } from '../model/AIService';
import { ggufService } from '../model/GGUFService';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';

interface TextRange {
  start: number;
  end: number;
}

@Entry
@Component
struct PromptEditorPage {
  @State template: TemplateInfo | null = null;
  @State fieldValues: Record<string, string> = {};
  @State generatedContent: string = '';
  @State title: string = '';
  @State mode: string = 'short_drama';
  @State isAiMode: boolean = false;
  @State engineWarning: string = '';
  @State currentPrompt: string = '';
  @State work: WorkItem | null = null;
  @State showChapterList: boolean = false;
  @State currentChapter: Chapter | null = null;
  @State promptText: string = '';
  @State aiConversation: string = '';  // AI对话独立显示文本（不污染工作区内容）
  @State isGenerating: boolean = false;
  @State currentBreakpoint: BreakpointType = 'sm';
  @State showVersionHistory: boolean = false;
  @State selectedVersion: number = -1;
  @State originalContent: string = '';
  @State modifiedRanges: Array<TextRange> = [];
  @State previousContent: string = '';
  @State showCreateChapterDialog: boolean = false;
  @State showEditChapterDialog: boolean = false;
  @State newChapterTitle: string = '';
  @State newChapterCategory: string = '大纲';
  @State newChapterContent: string = '';
  @State editingChapter: Chapter | null = null;
  @State editingChapterContent: string = '';
  @State selectedCategory: string = '全部';
  @State autoSaveTimer: number = 0;
  @State isDarkMode: boolean = false;
  @State bgTheme: string = 'default';
  @StorageProp('appFontSize') fontSize: number = 14;

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }

  get isWide(): boolean {
    return this.currentBreakpoint === 'md' || this.currentBreakpoint === 'lg';
  }

  get contentMaxWidth(): number {
    if (this.currentBreakpoint === 'lg') {
      return 1200;
    } else if (this.currentBreakpoint === 'md') {
      return 840;
    }
    return 10000;
  }


  get bgColor(): string {
    return this.isDarkMode ? '#1A1A2E' : '#F5F5F5';
  }

  get cardBg(): string {
    return this.isDarkMode ? '#2D2D44' : '#FFFFFF';
  }

  get textColor(): string {
    return this.isDarkMode ? '#E0E0E0' : '#1A1A2E';
  }

  get subTextColor(): string {
    return this.isDarkMode ? '#9CA3AF' : '#6B7280';
  }

  get themeBgColor(): string {
    if (this.isDarkMode) {
      switch (this.bgTheme) {
        case 'warm': return '#2D2418';
        case 'cool': return '#1A2D3D';
        case 'parchment': return '#2D2418';
        default: return '#1A1A2E';
      }
    }
    switch (this.bgTheme) {
      case 'warm': return '#FFF8F0';
      case 'cool': return '#F0F8FF';
      case 'parchment': return '#F5E6D3';
      default: return '#F5F5F5';
    }
  }

  aboutToAppear() {
    this.isDarkMode = settingsManager.settings.isDarkMode;
    AppStorage.setOrCreate('appFontSize', settingsManager.settings.fontSize || 14);
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.mode = params['mode'] || 'short_drama';

      // 提示词编辑模式
      if (this.mode === 'prompt_edit') {
        this.promptText = settingsManager.settings.customPrompt;
        return;
      }

      if (params['templateId']) {
        const templateId = params['templateId'];
        this.template = templateList.find(t => t.id === templateId) || null;
        if (this.template) {
          const values: Record<string, string> = {};
          for (let i = 0; i < this.template.fields.length; i++) {
            values[this.template.fields[i].key] = '';
          }
          this.fieldValues = values;
        }
      }
      if (params['workId']) {
        this.work = workManager.getWork(params['workId']);
        if (this.work) {
          this.title = this.work.title;
          this.generatedContent = this.work.content;
          this.previousContent = this.work.content;
          this.template = templateList.find(t => t.id === this.work!.templateId) || null;
          this.bgTheme = this.work.bgTheme || 'default';
        }
      }
    }

    // 初始化断点
    this.currentBreakpoint = responsiveManager.getBreakpoint();
    responsiveManager.onBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });

    // 启动自动保存定时器
    this.startAutoSave();
  }

  startAutoSave() {
    // 自动保存间隔：最多30秒
    const interval = Math.min(settingsManager.settings.autoSaveInterval * 60 * 1000, 30000);
    this.autoSaveTimer = setInterval(() => {
      this.autoSave();
    }, interval);
  }

  autoSave() {
    if (this.generatedContent.trim().length === 0 && this.aiConversation.trim().length === 0) {
      return;
    }
    if (this.work) {
      // 更新现有作品内容和标题
      workManager.updateWork(this.work.id, this.generatedContent, false);
      if (this.title.trim().length > 0) {
        workManager.updateTitle(this.work.id, this.title);
      }
    } else {
      // 新作品自动创建草稿，防止闪退丢失
      const draftTitle = this.title.trim().length > 0 ? this.title : '未命名草稿';
      if (this.template) {
        this.work = workManager.createWork(this.template, draftTitle, this.generatedContent);
      } else {
        this.work = workManager.createFreeWork(draftTitle, this.generatedContent, this.mode);
      }
    }
  }

  saveBgTheme() {
    if (this.work) {
      this.work.bgTheme = this.bgTheme;
      workManager.updateWork(this.work.id, this.generatedContent, false);
    }
  }

  aboutToDisappear() {
    // 离开页面前自动保存，防止闪退丢失
    if (this.mode !== 'prompt_edit') {
      this.autoSave();
    }
    responsiveManager.offBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });
    // 清理自动保存定时器
    if (this.autoSaveTimer > 0) {
      clearInterval(this.autoSaveTimer);
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(this.sf(20))
          .fontColor('#FF2D55')
          .onClick(() => {
            router.back();
          })
          .padding({ left: 16, right: 12 })

        Text(this.getTitle())
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank().width(48)
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.cardBg)

      if (this.mode === 'prompt_edit') {
        this.PromptEditView()
      } else {
        this.FormView()
      }

      // 章节列表面板
      if (this.showChapterList) {
        this.ChapterListView()
      }

      // 创建章节对话框
      if (this.showCreateChapterDialog) {
        this.CreateChapterDialog()
      }

      // 编辑章节对话框
      if (this.showEditChapterDialog) {
        this.EditChapterDialog()
      }

      // 版本历史面板
      if (this.showVersionHistory) {
        this.VersionHistoryView()
      }

      // 底部操作栏
      if (this.mode !== 'prompt_edit') {
        Row() {
          Text(this.generatedContent.length + ' 字')
            .fontSize(this.sf(12))
            .fontColor(this.subTextColor)

          Blank()

          if (this.work) {
            if (this.work.chapters && this.work.chapters.length > 0) {
              Button('章节')
                .fontSize(this.sf(14))
                .fontWeight(FontWeight.Medium)
                .fontColor('#FF2D55')
                .backgroundColor(this.cardBg)
                .borderRadius(20)
                .height(36)
                .padding({ left: 16, right: 16 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.showChapterList = true;
                })
            }

            if (this.work.versions && this.work.versions.length > 0) {
              Button('历史')
                .fontSize(this.sf(14))
                .fontWeight(FontWeight.Medium)
                .fontColor('#3B82F6')
                .backgroundColor(this.cardBg)
                .borderRadius(20)
                .height(36)
                .padding({ left: 16, right: 16 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.showVersionHistory = true;
                })
            }

            Button('导出')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Medium)
              .fontColor('#10B981')
              .backgroundColor(this.cardBg)
              .borderRadius(20)
              .height(36)
              .padding({ left: 16, right: 16 })
              .margin({ right: 8 })
              .onClick(() => {
                this.exportWork();
              })
          }

          Button('保存')
            .fontSize(this.sf(14))
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(20)
            .height(36)
            .padding({ left: 24, right: 24 })
            .onClick(() => this.saveWork())

          Button(this.isAiMode ? '退出AI' : 'AI对话')
            .fontSize(this.sf(14))
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(this.isAiMode ? '#6B7280' : '#10B981')
            .borderRadius(20)
            .height(36)
            .padding({ left: 16, right: 16 })
            .margin({ left: 12 })
            .onClick(() => {
              this.isAiMode = !this.isAiMode;
              if (this.isAiMode) {
                this.updateEngineWarning();
              }
            })
        }
        .width('100%')
        .height(56)
        .backgroundColor(this.cardBg)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBgColor)
    .constraintSize({ maxWidth: this.contentMaxWidth })
  }

  @Builder
  PromptEditView() {
    Column() {
      Text('自定义AI提示词')
        .fontSize(this.sf(16))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ left: 16, top: 16, bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Text('这个提示词将作为AI的系统指令，指导AI的写作风格和行为')
        .fontSize(this.sf(13))
        .fontColor(this.subTextColor)
        .margin({ left: 16, right: 16, bottom: 12 })

      TextArea({ placeholder: '请输入自定义提示词...', text: this.promptText })
        .width('90%')
        .layoutWeight(1)
        .fontSize(this.fontSize)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => {
          this.promptText = value;
        })

      Button('保存提示词')
        .width('90%')
        .height(48)
        .fontSize(this.sf(16))
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#FF2D55')
        .borderRadius(24)
        .margin({ top: 16, bottom: 24 })
        .onClick(() => {
          settingsManager.settings.customPrompt = this.promptText;
          settingsManager.save();
          promptAction.showToast({ message: '提示词已保存', duration: 2000 });
          router.back();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FormView() {
    Scroll() {
      Column() {
        // 标题输入
        if (!this.template && !this.work) {
          TextInput({ placeholder: '请输入作品标题', text: this.title })
            .width('90%')
            .height(48)
            .fontSize(this.fontSize)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.cardBg)
            .padding({ left: 16, right: 16 })
            .margin({ top: 12 })
            .onChange((value: string) => {
              this.title = value;
            })

          // 自由创作内容输入区
          Column() {
            Text('自由创作')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textColor)
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)
            TextArea({ placeholder: '直接输入创作内容，或点击右上角AI进入对话模式生成...', text: this.generatedContent })
              .width('100%')
              .height(240)
              .fontSize(this.fontSize)
              .backgroundColor(this.bgColor)
              .borderRadius(8)
              .padding(12)
              .onChange((value: string) => {
                this.generatedContent = value;
              })
          }
          .width('90%')
          .padding(16)
          .backgroundColor(this.cardBg)
          .margin({ top: 8 })
        }

        // 提示信息
        if (this.template) {
          Column() {
            Text('写作提示')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF6B35')
              .margin({ left: 16, top: 12, bottom: 8 })
              .alignSelf(ItemAlign.Start)

            ForEach(this.template.tips, (tip: string, index: number) => {
              Row() {
                Text('•')
                  .fontSize(this.sf(14))
                  .fontColor('#FF6B35')
                  .margin({ right: 8 })
                Text(tip)
                  .fontSize(this.sf(13))
                  .fontColor(this.subTextColor)
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }, (tip: string, index: number) => index.toString())
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.cardBg)
          .margin({ top: 8 })
        }

        // 表单字段
        if (this.template) {
          Column() {
            ForEach(this.template.fields, (field: TemplateField) => {
              Column() {
                Text(field.label + (field.required ? ' *' : ''))
                  .fontSize(this.sf(14))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.textColor)
                  .margin({ bottom: 8 })

                if (field.type === 'textarea') {
                  TextArea({
                    placeholder: field.placeholder
                  })
                    .width('100%')
                    .height(100)
                    .fontSize(this.fontSize)
                    .backgroundColor(this.bgColor)
                    .borderRadius(8)
                    .padding(12)
                    .onChange((value: string) => {
                      this.fieldValues[field.key] = value;
                      this.updateGeneratedContent();
                    })
                } else if (field.type === 'select') {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(field.options || [], (option: string) => {
                      Button(option)
                        .fontSize(this.sf(12))
                        .fontColor(this.fieldValues[field.key] === option ? '#FFFFFF' : this.subTextColor)
                        .backgroundColor(this.fieldValues[field.key] === option ? '#FF2D55' : '#E5E7EB')
                        .borderRadius(16)
                        .height(32)
                        .padding({ left: 12, right: 12 })
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.fieldValues[field.key] = option;
                          this.updateGeneratedContent();
                        })
                    }, (option: string) => option)
                  }
                  .width('100%')
                } else if (field.type === 'number') {
                  TextInput({ placeholder: field.placeholder })
                    .type(InputType.Number)
                    .width('100%')
                    .height(44)
                    .fontSize(this.fontSize)
                    .backgroundColor(this.bgColor)
                    .borderRadius(8)
                    .padding({ left: 12, right: 12 })
                    .onChange((value: string) => {
                      this.fieldValues[field.key] = value;
                      this.updateGeneratedContent();
                    })
                } else {
                  TextInput({ placeholder: field.placeholder })
                    .width('100%')
                    .height(44)
                    .fontSize(this.fontSize)
                    .backgroundColor(this.bgColor)
                    .borderRadius(8)
                    .padding({ left: 12, right: 12 })
                    .onChange((value: string) => {
                      this.fieldValues[field.key] = value;
                      this.updateGeneratedContent();
                    })
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider().color('#F3F4F6').strokeWidth(0.5).margin({ left: 16, right: 16 })
            }, (field: TemplateField) => field.key)
          }
          .width('100%')
          .backgroundColor(this.cardBg)
          .margin({ top: 8 })
        }

        // AI模式：显示AI对话窗口；非AI模式：显示工作区输出窗口
        if (this.isAiMode) {
          // AI对话窗口（独立于工作区）
          Column() {
            Row() {
              Text('AI对话')
                .fontSize(this.sf(14))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.textColor)

              Blank()

              if (this.aiConversation.length > 0) {
                Button('清空')
                  .fontSize(this.sf(12))
                  .fontColor('#6B7280')
                  .height(28)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('transparent')
                  .borderRadius(14)
                  .border({ width: 1, color: '#D1D5DB' })
                  .onClick(() => {
                    this.aiConversation = '';
                  })
              }
            }
            .width('100%')
            .margin({ left: 16, right: 16, bottom: 8 })

            if (this.aiConversation.length > 0) {
              Text(this.aiConversation)
                .fontSize(this.fontSize)
                .fontColor('#374151')
                .lineHeight(22)
                .width('100%')
                .padding(16)
                .backgroundColor(this.bgColor)
                .borderRadius(12)

              // 插入到输出按钮
              Button('插入到输出')
                .fontSize(this.sf(12))
                .fontColor('#10B981')
                .height(32)
                .padding({ left: 16, right: 16 })
                .backgroundColor('transparent')
                .borderRadius(16)
                .border({ width: 1, color: '#10B981' })
                .margin({ top: 8 })
                .onClick(() => this.insertLastAiResponseToOutput())
            } else {
              Text('在下方输入框输入消息，AI将在此显示回复。\n\n提示：AI回复可通过"插入到输出"复制到工作区。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .lineHeight(20)
                .width('100%')
                .padding(16)
                .backgroundColor(this.bgColor)
                .borderRadius(12)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.cardBg)
          .margin({ top: 8 })
        } else {
          // 工作区输出窗口
          Column() {
            Row() {
              Text('输出窗口')
                .fontSize(this.sf(14))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.textColor)

              Blank()

              Text(this.generatedContent.length + ' 字')
                .fontSize(this.sf(12))
                .fontColor(this.subTextColor)
            }
            .width('100%')
            .margin({ left: 16, right: 16, bottom: 8 })

            if (this.generatedContent.length > 0) {
              Text(this.getHighlightedContent())
              .fontSize(this.fontSize)
              .fontColor('#374151')
              .lineHeight(20)
              .width('100%')
          } else {
            Column() {
              Text('📝 填写上方模板字段后，点击底部的 AI 生成或小艺按钮')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 4 })
              Text('生成的内容将自动显示在此处，支持直接编辑与复制')
                .fontSize(this.sf(12))
                .fontColor('#B0B7C3')
            }
            .width('100%')
            .height(100)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.cardBg)
        .margin({ top: 8 })
        }

        // AI对话输入栏（在AI模式下显示）
        if (this.isAiMode) {
          if (this.engineWarning.length > 0) {
            Text(this.engineWarning)
              .fontSize(this.sf(12))
              .fontColor('#F59E0B')
              .backgroundColor(this.isDarkMode ? 'rgba(245,158,11,0.1)' : 'rgba(245,158,11,0.08)')
              .borderRadius(8)
              .padding(10)
              .width('100%')
              .margin({ top: 8 })
          }

          Row() {
            TextArea({ placeholder: '输入消息...', text: this.currentPrompt })
              .layoutWeight(1)
              .maxLines(this.isWide ? 6 : 4)
              .constraintSize({ minHeight: 40, maxHeight: 120 })
              .fontSize(this.fontSize)
              .backgroundColor(this.bgColor)
              .borderRadius(20)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .onChange((value: string) => {
                this.currentPrompt = value;
              })

            Button(this.isGenerating ? '...' : '发送')
              .fontSize(this.sf(14))
              .fontColor('#FFFFFF')
              .backgroundColor(this.isGenerating ? '#9CA3AF' : '#10B981')
              .borderRadius(20)
              .height(40)
              .padding({ left: 16, right: 16 })
              .margin({ left: 8 })
              .enabled(!this.isGenerating)
              .onClick(() => this.sendAiMessage())
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(this.cardBg)
          .margin({ top: 8 })
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .backgroundColor(this.bgColor)
  }

  getTitle(): string {
    if (this.mode === 'prompt_edit') return '编辑提示词';
    if (this.template) return this.template.name;
    if (this.work) return this.work.title;
    return '编辑器';
  }

  updateGeneratedContent() {
    if (!this.template) return;

    let content = this.template.format;
    const keys = Object.keys(this.fieldValues);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = this.fieldValues[key] || '';
      // 兼容 {key} 和 {{key}} 两种占位符格式
      const placeholder = '{' + key + '}';
      const doublePlaceholder = '{{' + key + '}}';
      while (content.indexOf(doublePlaceholder) !== -1) {
        content = content.replace(doublePlaceholder, value);
      }
      while (content.indexOf(placeholder) !== -1) {
        content = content.replace(placeholder, value);
      }
    }
    
    // 检测修改内容并高亮
    if (this.previousContent && content !== this.previousContent) {
      this.modifiedRanges = this.detectChanges(this.previousContent, content);
    }
    
    this.generatedContent = content;
  }

  detectChanges(oldContent: string, newContent: string): Array<TextRange> {
    const ranges: Array<TextRange> = [];
    
    // 简单的差异检测：找出新增的内容
    if (newContent.length > oldContent.length) {
      // 找到第一个不同的位置
      let diffStart = 0;
      while (diffStart < oldContent.length && oldContent[diffStart] === newContent[diffStart]) {
        diffStart++;
      }
      
      // 找到最后一个不同的位置
      let oldEnd = oldContent.length;
      let newEnd = newContent.length;
      while (oldEnd > diffStart && newEnd > diffStart && 
             oldContent[oldEnd - 1] === newContent[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      
      // 记录修改范围
      if (newEnd > diffStart) {
        const range: TextRange = { start: diffStart, end: newEnd };
        ranges.push(range);
      }
    }
    
    return ranges;
  }

  getHighlightedContent(): string {
    if (this.modifiedRanges.length === 0) {
      return this.generatedContent;
    }
    
    let result = '';
    let lastIndex = 0;
    
    for (let i = 0; i < this.modifiedRanges.length; i++) {
      const range = this.modifiedRanges[i];
      // 添加修改前的内容
      result += this.generatedContent.substring(lastIndex, range.start);
      // 添加高亮的修改内容
      result += '【' + this.generatedContent.substring(range.start, range.end) + '】';
      lastIndex = range.end;
    }
    
    // 添加剩余内容
    result += this.generatedContent.substring(lastIndex);
    
    return result;
  }

  createChapter() {
    if (!this.work) {
      promptAction.showToast({ message: '请先保存作品', duration: 2000 });
      return;
    }
    if (!this.newChapterTitle.trim()) {
      promptAction.showToast({ message: '请输入章节标题', duration: 2000 });
      return;
    }
    const chapter = workManager.addChapter(
      this.work.id,
      this.newChapterTitle,
      this.newChapterCategory,
      this.newChapterContent
    );
    if (chapter) {
      promptAction.showToast({ message: '章节创建成功', duration: 2000 });
      this.showCreateChapterDialog = false;
      this.newChapterTitle = '';
      this.newChapterCategory = '大纲';
      this.newChapterContent = '';
      // 刷新章节列表
      this.work = workManager.getWork(this.work.id);
    }
  }

  editChapter() {
    if (!this.work || !this.editingChapter) {
      return;
    }
    workManager.updateChapter(this.work.id, this.editingChapter.id, this.editingChapterContent);
    promptAction.showToast({ message: '章节已保存', duration: 2000 });
    this.showEditChapterDialog = false;
    this.editingChapter = null;
    this.editingChapterContent = '';
    // 刷新作品数据
    this.work = workManager.getWork(this.work.id);
  }

  deleteChapter(chapter: Chapter) {
    if (!this.work) {
      return;
    }
    workManager.deleteChapter(this.work.id, chapter.id);
    promptAction.showToast({ message: '章节已删除', duration: 2000 });
    // 刷新章节列表
    this.work = workManager.getWork(this.work.id);
  }

  getFilteredChapters(): Chapter[] {
    if (!this.work || !this.work.chapters) {
      return [];
    }
    if (this.selectedCategory === '全部') {
      return this.work.chapters;
    }
    return this.work.chapters.filter(chapter => chapter.category === this.selectedCategory);
  }

  async saveWork() {
    if (this.generatedContent.trim().length === 0) {
      promptAction.showToast({ message: '内容不能为空', duration: 2000 });
      return;
    }

    const finalTitle = this.title.trim().length > 0 ? this.title : (this.template ? this.template.name : '未命名作品');

    if (this.work) {
      // 更新现有作品（自动归档旧版本）
      workManager.updateWork(this.work.id, this.generatedContent, true);
      // 更新previousContent为当前内容
      this.previousContent = this.generatedContent;
      this.modifiedRanges = [];
      promptAction.showToast({ message: '作品已更新（旧版本已归档）', duration: 2000 });
    } else if (this.template) {
      // 创建新作品
      this.work = workManager.createWork(this.template, finalTitle, this.generatedContent);
      this.previousContent = this.generatedContent;
      promptAction.showToast({ message: '作品已保存', duration: 2000 });
    } else {
      // 自由创作（无模板），归属当前工作台
      this.work = workManager.createFreeWork(finalTitle, this.generatedContent, this.mode);
      this.previousContent = this.generatedContent;
      promptAction.showToast({ message: '作品已保存', duration: 2000 });
    }

    router.back();
  }

  async generateWithAi() {
    if (!settingsManager.settings.localModelPath) {
      promptAction.showToast({ message: '请先在设置中选择 GGUF 模型文件', duration: 2000 });
      return;
    }

    this.isGenerating = true;
    promptAction.showToast({ message: 'AI生成中...', duration: 2000 });

    // 构建提示词
    let prompt = this.generatedContent;
    if (this.template) {
      prompt = `请根据以下模板信息生成内容：\n模板：${this.template.name}\n\n${this.generatedContent}`;
    }

    try {
      const response = await aiService.callAI(prompt);

      if (response.success) {
        this.generatedContent = response.content;
        promptAction.showToast({ message: 'AI生成完成', duration: 2000 });
      } else {
        promptAction.showToast({ message: response.error || 'AI生成失败', duration: 2000 });
      }
    } catch (e) {
      const errMsg = (e as Record<string, Object>).message as string || JSON.stringify(e);
      console.error('[generateWithAi] 异常: ' + errMsg);
      promptAction.showToast({ message: 'AI生成异常: ' + errMsg.substring(0, 80), duration: 3000 });
    } finally {
      this.isGenerating = false;
    }
  }

  updateEngineWarning() {
    const settings = settingsManager.settings;
    if (!settings.localModelPath) {
      this.engineWarning = '⚠️ 未选择GGUF模型文件，请在设置中选择模型文件后使用AI功能。';
    } else if (ggufService.isStubMode()) {
      this.engineWarning = '⚠️ 当前为占位模式（llama.cpp 未编译），无法执行AI推理。';
    } else {
      this.engineWarning = '';
    }
  }

  async sendAiMessage() {
    if (this.currentPrompt.trim().length === 0) return;
    if (!settingsManager.settings.localModelPath) {
      promptAction.showToast({ message: '请先在设置中选择 GGUF 模型文件', duration: 2000 });
      return;
    }

    this.isGenerating = true;
    const userMessage = this.currentPrompt;
    this.currentPrompt = '';

    // 追加用户消息到AI对话窗口（不污染工作区内容）
    this.aiConversation += (this.aiConversation.length > 0 ? '\n\n' : '') + '【用户】' + userMessage + '\n';

    // 构建上下文
    let context = '';
    if (this.work) {
      context = `当前作品：${this.work.title}\n内容：${this.generatedContent.substring(0, 500)}`;
    }

    try {
      const response = await aiService.callAI(userMessage, context);

      if (response.success) {
        if (response.content.length > 0) {
          this.aiConversation += '\n【AI】' + response.content + '\n\n';

          // 保存对话记录
          if (this.work) {
            const conversation = workManager.addConversation(this.work.id, userMessage, response.content);
            if (!conversation) {
              console.warn('[sendAiMessage] 保存对话记录失败');
              promptAction.showToast({ message: '保存对话记录失败', duration: 2000 });
            }
          }
        } else {
          console.warn('[sendAiMessage] AI返回了空内容');
          promptAction.showToast({ message: 'AI模型未响应，请检查模型文件是否正确加载', duration: 3000 });
        }
      } else {
        promptAction.showToast({ message: response.error || 'AI回复失败', duration: 3000 });
      }
    } catch (e) {
      const errMsg = (e as Record<string, Object>).message as string || JSON.stringify(e);
      console.error('[sendAiMessage] 异常: ' + errMsg);
      promptAction.showToast({ message: 'AI调用异常: ' + errMsg.substring(0, 80), duration: 3000 });
    } finally {
      this.isGenerating = false;
    }
  }

  /** 将最后一条AI回复插入到工作区输出窗口 */
  insertLastAiResponseToOutput() {
    // 从aiConversation中提取最后一条【AI】回复
    const aiMarker = '\n【AI】';
    const lastIdx = this.aiConversation.lastIndexOf(aiMarker);
    if (lastIdx < 0) return;

    const afterMarker = this.aiConversation.substring(lastIdx + aiMarker.length);
    // 提取到下一个【用户】或末尾
    const nextUserMarker = afterMarker.indexOf('\n【用户】');
    const aiResponse = nextUserMarker > 0 ? afterMarker.substring(0, nextUserMarker).trim() : afterMarker.trim();

    if (aiResponse.length > 0) {
      this.generatedContent += (this.generatedContent.length > 0 ? '\n\n' : '') + aiResponse;
      promptAction.showToast({ message: '已插入到输出窗口', duration: 1500 });
    }
  }

  saveThoughtChain() {
    if (!this.work || !this.work.conversations || this.work.conversations.length === 0) return;

    // 获取最后一条对话
    const lastConv = this.work.conversations[this.work.conversations.length - 1];
    const lastUserMessage = lastConv.userMessage;
    const lastAiResponse = lastConv.aiResponse;

    // 保存为思维链路段落
    const content = `用户提问：${lastUserMessage}\n\nAI思考过程：\n${lastAiResponse}`;
    workManager.addChapter(this.work.id, '思维链路_' + new Date().getTime(), '思维链路', content);

    promptAction.showToast({ message: '思维链路已保存', duration: 2000 });
  }

  saveFinalPlan() {
    if (!this.work || !this.work.conversations || this.work.conversations.length === 0) return;

    // 整合所有对话内容
    let content = '最终方案：\n\n';
    for (let i = 0; i < this.work.conversations.length; i++) {
      const conv = this.work.conversations[i];
      content += `【对话 ${i + 1}】\n`;
      content += `用户：${conv.userMessage}\n`;
      content += `AI：${conv.aiResponse}\n\n`;
    }

    workManager.addChapter(this.work.id, '最终方案_' + new Date().getTime(), '最终方案', content);
    promptAction.showToast({ message: '最终方案已保存', duration: 2000 });
  }

  exportWork() {
    if (!this.work) return;

    // 汇总所有内容
    let exportText = `《${this.work.title}》\n`;
    exportText += `模板：${this.work.templateName}\n`;
    exportText += `导出时间：${new Date().toLocaleString()}\n`;
    exportText += `${'='.repeat(40)}\n\n`;

    // 添加生成内容
    if (this.generatedContent) {
      exportText += `【生成内容】\n${this.generatedContent}\n\n`;
    }

    // 添加所有章节
    if (this.work.chapters && this.work.chapters.length > 0) {
      exportText += `${'='.repeat(40)}\n【章节内容】\n\n`;
      for (const chapter of this.work.chapters) {
        exportText += `--- ${chapter.category} | ${chapter.title} ---\n`;
        exportText += `${chapter.content}\n\n`;
      }
    }

    // 复制到剪贴板
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, exportText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: `已导出 ${exportText.length} 字到剪贴板`, duration: 3000 });
    } catch (e) {
      // 降级方案：显示内容供手动复制
      this.getUIContext().getPromptAction().showDialog({
        title: '导出内容',
        message: `共 ${exportText.length} 字，复制到剪贴板失败，请手动保存`,
        buttons: [{ text: '确定', color: '#FF6B35' }]
      });
    }
  }

  @Builder
  ChapterListView() {
    Column() {
      // 标题栏
      Row() {
        Text('章节管理')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Text('+')
          .fontSize(this.sf(24))
          .fontColor('#FF2D55')
          .margin({ right: 16 })
          .onClick(() => {
            this.showCreateChapterDialog = true;
          })
        Text('×')
          .fontSize(this.sf(24))
          .fontColor(this.subTextColor)
          .onClick(() => {
            this.showChapterList = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      // 分类标签
      Scroll() {
        Row() {
          ForEach(['全部', '大纲', '人设', '场景', '章节', '时间线', '世界观', '思维链路', '最终方案'], (category: string) => {
            Button(category)
              .fontSize(this.sf(13))
              .fontColor(this.selectedCategory === category ? '#FFFFFF' : this.subTextColor)
              .backgroundColor(this.selectedCategory === category ? '#FF2D55' : '#F3F4F6')
              .borderRadius(16)
              .height(32)
              .padding({ left: 12, right: 12 })
              .margin({ right: 8 })
              .onClick(() => {
                this.selectedCategory = category;
              })
          }, (category: string) => category)
        }
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height(48)
      .backgroundColor(this.cardBg)

      // 章节列表
      List() {
        if (this.work && this.work.chapters) {
          ForEach(this.getFilteredChapters(), (chapter: Chapter) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(chapter.title)
                      .fontSize(this.sf(15))
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.textColor)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(chapter.category)
                      .fontSize(this.sf(12))
                      .fontColor('#FF2D55')
                      .margin({ top: 4 })
                    Text(chapter.updateTime)
                      .fontSize(this.sf(11))
                      .fontColor(this.subTextColor)
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Row() {
                    Text('查看')
                      .fontSize(this.sf(13))
                      .fontColor('#FF2D55')
                      .onClick(() => {
                        this.currentChapter = chapter;
                        this.generatedContent = chapter.content;
                        this.showChapterList = false;
                        promptAction.showToast({ message: '已加载章节内容', duration: 2000 });
                      })
                    Text('编辑')
                      .fontSize(this.sf(13))
                      .fontColor('#3B82F6')
                      .margin({ left: 12 })
                      .onClick(() => {
                        this.editingChapter = chapter;
                        this.editingChapterContent = chapter.content;
                        this.showEditChapterDialog = true;
                      })
                    Text('删除')
                      .fontSize(this.sf(13))
                      .fontColor('#EF4444')
                      .margin({ left: 12 })
                      .onClick(() => {
                        this.deleteChapter(chapter);
                      })
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor(this.cardBg)
            }
          }, (chapter: Chapter) => chapter.id)
        }
      }
      .layoutWeight(1)
      .backgroundColor(this.bgColor)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    .position({ x: 0, y: 0 })
  }

  @Builder
  CreateChapterDialog() {
    Column() {
      Column() {
        Text('创建章节')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        Text('章节标题')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .margin({ bottom: 8 })
        TextInput({ placeholder: '请输入章节标题' })
          .fontSize(this.fontSize)
          .height(40)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .onChange((value: string) => {
            this.newChapterTitle = value;
          })

        Text('章节分类')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .margin({ top: 16, bottom: 8 })
        Row() {
          ForEach(['大纲', '人设', '场景', '章节', '时间线', '世界观', '思维链路', '最终方案'], (category: string) => {
            Button(category)
              .fontSize(this.sf(13))
              .fontColor(this.newChapterCategory === category ? '#FFFFFF' : this.subTextColor)
              .backgroundColor(this.newChapterCategory === category ? '#FF2D55' : this.bgColor)
              .borderRadius(16)
              .height(32)
              .padding({ left: 12, right: 12 })
              .margin({ right: 8 })
              .onClick(() => {
                this.newChapterCategory = category;
              })
          }, (category: string) => category)
        }

        Text('章节内容')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .margin({ top: 16, bottom: 8 })
        TextArea({ placeholder: '请输入章节内容（可选）' })
          .fontSize(this.fontSize)
          .height(150)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .onChange((value: string) => {
            this.newChapterContent = value;
          })

        Row() {
          Button('取消')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .backgroundColor(this.bgColor)
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              this.showCreateChapterDialog = false;
              this.newChapterTitle = '';
              this.newChapterCategory = '大纲';
              this.newChapterContent = '';
            })
          Button('创建')
            .fontSize(this.sf(14))
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => {
              this.createChapter();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('90%')
      .padding(20)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  @Builder
  EditChapterDialog() {
    Column() {
      Column() {
        Text('编辑章节')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 8 })

        if (this.editingChapter) {
          Text(this.editingChapter.title)
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 16 })
        }

        TextArea({ placeholder: '请输入章节内容', text: this.editingChapterContent })
          .fontSize(this.fontSize)
          .height(300)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .onChange((value: string) => {
            this.editingChapterContent = value;
          })

        Row() {
          Button('取消')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .backgroundColor(this.bgColor)
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              this.showEditChapterDialog = false;
              this.editingChapter = null;
              this.editingChapterContent = '';
            })
          Button('保存')
            .fontSize(this.sf(14))
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => {
              this.editChapter();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('90%')
      .padding(20)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
  }

  @Builder
  VersionHistoryView() {
    Column() {
      // 标题栏
      Row() {
        Text('版本历史')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Text('×')
          .fontSize(this.sf(24))
          .fontColor(this.subTextColor)
          .onClick(() => {
            this.showVersionHistory = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      // 版本列表
      List() {
        if (this.work && this.work.versions) {
          ForEach(this.work.versions, (version: WorkVersion, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text('版本 ' + (this.work!.versions!.length - index))
                      .fontSize(this.sf(15))
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.textColor)
                    Text(version.timestamp)
                      .fontSize(this.sf(11))
                      .fontColor(this.subTextColor)
                      .margin({ top: 4 })
                    if (version.changeNote) {
                      Text(version.changeNote)
                        .fontSize(this.sf(12))
                        .fontColor(this.subTextColor)
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column() {
                    Text('预览')
                      .fontSize(this.sf(13))
                      .fontColor('#FF2D55')
                      .onClick(() => {
                        this.selectedVersion = index;
                        this.originalContent = this.generatedContent;
                        this.generatedContent = version.content;
                        this.showVersionHistory = false;
                        promptAction.showToast({ message: '已加载历史版本，可对比查看', duration: 2000 });
                      })
                    if (this.selectedVersion === index) {
                      Text('恢复')
                        .fontSize(this.sf(13))
                        .fontColor('#10B981')
                        .margin({ top: 8 })
                        .onClick(() => {
                          if (this.work) {
                            const ok = workManager.restoreVersion(this.work.id, version.id);
                            if (ok) {
                              const updated = workManager.getWork(this.work!.id);
                              if (updated) {
                                this.work = updated;
                                this.generatedContent = updated.content;
                                this.previousContent = updated.content;
                              }
                              this.selectedVersion = -1;
                              this.showVersionHistory = false;
                              promptAction.showToast({ message: '已恢复到此版本', duration: 2000 });
                            } else {
                              promptAction.showToast({ message: '恢复失败，请重试', duration: 2000 });
                            }
                          }
                        })
                    }
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor(this.selectedVersion === index ? '#FFF5F5' : this.cardBg)
            }
          }, (version: WorkVersion, index: number) => version.id)
        }
      }
      .layoutWeight(1)
      .backgroundColor(this.bgColor)

      // 底部提示
      Text('提示：点击预览可查看历史版本内容，点击恢复可回退到该版本')
        .fontSize(this.sf(12))
        .fontColor(this.subTextColor)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .width('100%')
        .backgroundColor(this.cardBg)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    .position({ x: 0, y: 0 })
  }
}
