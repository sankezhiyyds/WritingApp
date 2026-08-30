import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager, Chapter, Conversation, WorkVersion } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { aiService } from '../model/AIService';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

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
  @State conversationHistory: string[] = [];
  @State currentPrompt: string = '';
  @State work: WorkItem | null = null;
  @State showChapterList: boolean = false;
  @State currentChapter: Chapter | null = null;
  @State promptText: string = '';
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

  aboutToAppear() {
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
        }
      }
    }

    // 初始化断点
    this.currentBreakpoint = responsiveManager.getBreakpoint();
    responsiveManager.onBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });
  }

  aboutToDisappear() {
    responsiveManager.offBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor('#FF2D55')
          .onClick(() => {
            router.back();
          })
          .padding({ left: 16, right: 12 })

        Text(this.getTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.mode !== 'prompt_edit') {
          Text('AI')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(4)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              this.isAiMode = !this.isAiMode;
            })
            .padding({ right: 16 })
        } else {
          Blank().width(48)
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      if (this.mode === 'prompt_edit') {
        this.PromptEditView()
      } else if (this.isAiMode) {
        this.AiChatView()
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
            .fontSize(12)
            .fontColor('#9CA3AF')

          Blank()

          if (this.work) {
            if (this.work.chapters && this.work.chapters.length > 0) {
              Button('章节')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FF2D55')
                .backgroundColor('#FFFFFF')
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
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#3B82F6')
                .backgroundColor('#FFFFFF')
                .borderRadius(20)
                .height(36)
                .padding({ left: 16, right: 16 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.showVersionHistory = true;
                })
            }
          }

          Button('保存')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(20)
            .height(36)
            .padding({ left: 24, right: 24 })
            .onClick(() => this.saveWork())

          if (!this.isAiMode) {
            Button('AI生成')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('#10B981')
              .borderRadius(20)
              .height(36)
              .padding({ left: 24, right: 24 })
              .margin({ left: 12 })
              .onClick(() => this.generateWithAi())
          }

          // 小艺助手按钮
          Button('小艺')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#007DFF')
            .borderRadius(20)
            .height(36)
            .padding({ left: 16, right: 16 })
            .margin({ left: 12 })
            .onClick(() => this.openXiaoyi())
        }
        .width('100%')
        .height(56)
        .backgroundColor('#FFFFFF')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
    .constraintSize({ maxWidth: this.contentMaxWidth })
  }

  @Builder
  PromptEditView() {
    Column() {
      Text('自定义AI提示词')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A2E')
        .margin({ left: 16, top: 16, bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Text('这个提示词将作为AI的系统指令，指导AI的写作风格和行为')
        .fontSize(13)
        .fontColor('#9CA3AF')
        .margin({ left: 16, right: 16, bottom: 12 })

      TextArea({ placeholder: '请输入自定义提示词...', text: this.promptText })
        .width('90%')
        .layoutWeight(1)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => {
          this.promptText = value;
        })

      Button('保存提示词')
        .width('90%')
        .height(48)
        .fontSize(16)
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
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#FFFFFF')
            .padding({ left: 16, right: 16 })
            .margin({ top: 12 })
            .onChange((value: string) => {
              this.title = value;
            })
        }

        // 提示信息
        if (this.template) {
          Column() {
            Text('写作提示')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF6B35')
              .margin({ left: 16, top: 12, bottom: 8 })
              .alignSelf(ItemAlign.Start)

            ForEach(this.template.tips, (tip: string, index: number) => {
              Row() {
                Text('•')
                  .fontSize(14)
                  .fontColor('#FF6B35')
                  .margin({ right: 8 })
                Text(tip)
                  .fontSize(13)
                  .fontColor('#6B7280')
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }, (tip: string, index: number) => index.toString())
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .margin({ top: 8 })
        }

        // 表单字段
        if (this.template) {
          Column() {
            ForEach(this.template.fields, (field: TemplateField) => {
              Column() {
                Text(field.label + (field.required ? ' *' : ''))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A2E')
                  .margin({ bottom: 8 })

                if (field.type === 'textarea') {
                  TextArea({
                    placeholder: field.placeholder
                  })
                    .width('100%')
                    .height(100)
                    .fontSize(14)
                    .backgroundColor('#F9FAFB')
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
                        .fontSize(12)
                        .fontColor(this.fieldValues[field.key] === option ? '#FFFFFF' : '#6B7280')
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
                    .fontSize(14)
                    .backgroundColor('#F9FAFB')
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
                    .fontSize(14)
                    .backgroundColor('#F9FAFB')
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
          .backgroundColor('#FFFFFF')
          .margin({ top: 8 })
        }

        // 生成内容预览
        if (this.generatedContent.length > 0) {
          Column() {
            Text('生成内容预览')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A2E')
              .margin({ left: 16, bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text(this.getHighlightedContent())
              .fontSize(13)
              .fontColor('#374151')
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .margin({ top: 8 })
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .backgroundColor('#F5F6FA')
  }

  @Builder
  AiChatView() {
    Column() {
      // 对话历史
      List() {
        ForEach(this.conversationHistory, (msg: string, index: number) => {
          ListItem() {
            Column() {
              Text(index % 2 === 0 ? '用户' : 'AI')
                .fontSize(12)
                .fontColor('#9CA3AF')
                .margin({ bottom: 4 })
              Text(msg)
                .fontSize(14)
                .fontColor('#1A1A2E')
                .lineHeight(20)
            }
            .width('90%')
            .padding(12)
            .backgroundColor(index % 2 === 0 ? '#E5E7EB' : '#FFFFFF')
            .borderRadius(8)
            .alignSelf(index % 2 === 0 ? ItemAlign.End : ItemAlign.Start)
          }
        }, (msg: string, index: number) => index.toString())
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 12 })

      // 保存按钮
      if (this.conversationHistory.length > 0) {
        Row() {
          Button('保存思维链路')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#3B82F6')
            .borderRadius(20)
            .height(36)
            .padding({ left: 16, right: 16 })
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => this.saveThoughtChain())

          Button('保存最终方案')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#10B981')
            .borderRadius(20)
            .height(36)
            .padding({ left: 16, right: 16 })
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => this.saveFinalPlan())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }

      // 输入框
      Row() {
        TextInput({ placeholder: '输入消息...', text: this.currentPrompt })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor('#F9FAFB')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.currentPrompt = value;
          })

        Button(this.isGenerating ? '...' : '发送')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isGenerating ? '#9CA3AF' : '#FF2D55')
          .borderRadius(20)
          .height(40)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8 })
          .enabled(!this.isGenerating)
          .onClick(() => this.sendAiMessage())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
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
      const placeholder = '{' + key + '}';
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
      workManager.createWork(this.template, finalTitle, this.generatedContent);
      this.previousContent = this.generatedContent;
      promptAction.showToast({ message: '作品已保存', duration: 2000 });
    }

    router.back();
  }

  async openXiaoyi() {
    // 构建提示词
    let prompt = this.generatedContent;
    if (this.template) {
      prompt = `请根据以下模板信息生成内容：\n模板：${this.template.name}\n\n${this.generatedContent}`;
    }
    if (!prompt) {
      prompt = this.title || '请帮我创作内容';
    }

    const success = await aiService.openXiaoyiAssistant(prompt);
    if (!success) {
      promptAction.showToast({ message: '无法启动小艺助手，请确认设备支持', duration: 2000 });
    }
  }

  async generateWithAi() {
    if (!settingsManager.settings.apiKey) {
      promptAction.showToast({ message: '请先在设置中配置API Key', duration: 2000 });
      return;
    }

    this.isGenerating = true;
    promptAction.showToast({ message: 'AI生成中...', duration: 2000 });

    // 构建提示词
    let prompt = this.generatedContent;
    if (this.template) {
      prompt = `请根据以下模板信息生成内容：\n模板：${this.template.name}\n\n${this.generatedContent}`;
    }

    const response = await aiService.callAI(prompt);
    this.isGenerating = false;

    if (response.success) {
      this.generatedContent = response.content;
      promptAction.showToast({ message: 'AI生成完成', duration: 2000 });
    } else {
      promptAction.showToast({ message: response.error || 'AI生成失败', duration: 2000 });
    }
  }

  async sendAiMessage() {
    if (this.currentPrompt.trim().length === 0) return;
    if (!settingsManager.settings.apiKey) {
      promptAction.showToast({ message: '请先在设置中配置API Key', duration: 2000 });
      return;
    }

    this.isGenerating = true;
    this.conversationHistory.push(this.currentPrompt);
    const userMessage = this.currentPrompt;
    this.currentPrompt = '';

    // 构建上下文
    let context = '';
    if (this.work) {
      context = `当前作品：${this.work.title}\n内容：${this.work.content.substring(0, 500)}`;
    }

    const response = await aiService.callAI(userMessage, context);
    this.isGenerating = false;

    if (response.success) {
      this.conversationHistory.push(response.content);

      // 保存对话记录
      if (this.work) {
        workManager.addConversation(this.work.id, userMessage, response.content);
      }
    } else {
      this.conversationHistory.push('错误：' + (response.error || 'AI回复失败'));
    }
  }

  saveThoughtChain() {
    if (!this.work || this.conversationHistory.length === 0) return;

    // 获取最后一条AI回复
    const lastAiResponse = this.conversationHistory[this.conversationHistory.length - 1];
    const lastUserMessage = this.conversationHistory[this.conversationHistory.length - 2] || '';

    // 保存为思维链路段落
    const content = `用户提问：${lastUserMessage}\n\nAI思考过程：\n${lastAiResponse}`;
    workManager.addChapter(this.work.id, '思维链路_' + new Date().getTime(), '思维链路', content);

    promptAction.showToast({ message: '思维链路已保存', duration: 2000 });
  }

  saveFinalPlan() {
    if (!this.work || this.conversationHistory.length === 0) return;

    // 整合所有对话内容
    let content = '最终方案：\n\n';
    for (let i = 0; i < this.conversationHistory.length; i += 2) {
      if (i + 1 < this.conversationHistory.length) {
        content += `【对话 ${Math.floor(i / 2) + 1}】\n`;
        content += `用户：${this.conversationHistory[i]}\n`;
        content += `AI：${this.conversationHistory[i + 1]}\n\n`;
      }
    }

    workManager.addChapter(this.work.id, '最终方案_' + new Date().getTime(), '最终方案', content);
    promptAction.showToast({ message: '最终方案已保存', duration: 2000 });
  }

  @Builder
  ChapterListView() {
    Column() {
      // 标题栏
      Row() {
        Text('章节管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
        Blank()
        Text('+')
          .fontSize(24)
          .fontColor('#FF2D55')
          .margin({ right: 16 })
          .onClick(() => {
            this.showCreateChapterDialog = true;
          })
        Text('×')
          .fontSize(24)
          .fontColor('#9CA3AF')
          .onClick(() => {
            this.showChapterList = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // 分类标签
      Scroll() {
        Row() {
          ForEach(['全部', '大纲', '人设', '思维链路', '最终方案'], (category: string) => {
            Button(category)
              .fontSize(13)
              .fontColor('#6B7280')
              .backgroundColor('#F3F4F6')
              .borderRadius(16)
              .height(32)
              .padding({ left: 12, right: 12 })
              .margin({ right: 8 })
          }, (category: string) => category)
        }
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height(48)
      .backgroundColor('#FFFFFF')

      // 章节列表
      List() {
        if (this.work && this.work.chapters) {
          ForEach(this.work.chapters, (chapter: Chapter) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(chapter.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A2E')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(chapter.category)
                      .fontSize(12)
                      .fontColor('#FF2D55')
                      .margin({ top: 4 })
                    Text(chapter.updateTime)
                      .fontSize(11)
                      .fontColor('#9CA3AF')
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Row() {
                    Text('查看')
                      .fontSize(13)
                      .fontColor('#FF2D55')
                      .onClick(() => {
                        this.currentChapter = chapter;
                        this.generatedContent = chapter.content;
                        this.showChapterList = false;
                        promptAction.showToast({ message: '已加载章节内容', duration: 2000 });
                      })
                    Text('编辑')
                      .fontSize(13)
                      .fontColor('#3B82F6')
                      .margin({ left: 12 })
                      .onClick(() => {
                        this.editingChapter = chapter;
                        this.editingChapterContent = chapter.content;
                        this.showEditChapterDialog = true;
                      })
                    Text('删除')
                      .fontSize(13)
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
              .backgroundColor('#FFFFFF')
            }
          }, (chapter: Chapter) => chapter.id)
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F6FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
    .position({ x: 0, y: 0 })
  }

  @Builder
  CreateChapterDialog() {
    Column() {
      Column() {
        Text('创建章节')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .margin({ bottom: 16 })

        Text('章节标题')
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ bottom: 8 })
        TextInput({ placeholder: '请输入章节标题' })
          .fontSize(14)
          .height(40)
          .backgroundColor('#F5F6FA')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newChapterTitle = value;
          })

        Text('章节分类')
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16, bottom: 8 })
        Row() {
          ForEach(['大纲', '人设', '思维链路', '最终方案'], (category: string) => {
            Button(category)
              .fontSize(13)
              .fontColor(this.newChapterCategory === category ? '#FFFFFF' : '#6B7280')
              .backgroundColor(this.newChapterCategory === category ? '#FF2D55' : '#F5F6FA')
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
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16, bottom: 8 })
        TextArea({ placeholder: '请输入章节内容（可选）' })
          .fontSize(14)
          .height(150)
          .backgroundColor('#F5F6FA')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newChapterContent = value;
          })

        Row() {
          Button('取消')
            .fontSize(14)
            .fontColor('#6B7280')
            .backgroundColor('#F5F6FA')
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
            .fontSize(14)
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
      .backgroundColor('#FFFFFF')
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
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .margin({ bottom: 8 })

        if (this.editingChapter) {
          Text(this.editingChapter.title)
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 16 })
        }

        TextArea({ placeholder: '请输入章节内容', text: this.editingChapterContent })
          .fontSize(14)
          .height(300)
          .backgroundColor('#F5F6FA')
          .borderRadius(8)
          .onChange((value: string) => {
            this.editingChapterContent = value;
          })

        Row() {
          Button('取消')
            .fontSize(14)
            .fontColor('#6B7280')
            .backgroundColor('#F5F6FA')
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
            .fontSize(14)
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
      .backgroundColor('#FFFFFF')
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
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
        Blank()
        Text('×')
          .fontSize(24)
          .fontColor('#9CA3AF')
          .onClick(() => {
            this.showVersionHistory = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // 版本列表
      List() {
        if (this.work && this.work.versions) {
          ForEach(this.work.versions, (version: WorkVersion, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text('版本 ' + (this.work!.versions!.length - index))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A2E')
                    Text(version.timestamp)
                      .fontSize(11)
                      .fontColor('#9CA3AF')
                      .margin({ top: 4 })
                    if (version.changeNote) {
                      Text(version.changeNote)
                        .fontSize(12)
                        .fontColor('#6B7280')
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column() {
                    Text('预览')
                      .fontSize(13)
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
                        .fontSize(13)
                        .fontColor('#10B981')
                        .margin({ top: 8 })
                        .onClick(() => {
                          this.selectedVersion = -1;
                          promptAction.showToast({ message: '已恢复到此版本', duration: 2000 });
                        })
                    }
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor(this.selectedVersion === index ? '#FFF5F5' : '#FFFFFF')
            }
          }, (version: WorkVersion, index: number) => version.id)
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F6FA')

      // 底部提示
      Text('提示：点击预览可查看历史版本内容，点击恢复可回退到该版本')
        .fontSize(12)
        .fontColor('#9CA3AF')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .width('100%')
        .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
    .position({ x: 0, y: 0 })
  }
}
