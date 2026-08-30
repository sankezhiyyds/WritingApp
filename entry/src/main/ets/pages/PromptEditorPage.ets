import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

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

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.mode = params['mode'] || 'short_drama';
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
        const work = workManager.getWork(params['workId']);
        if (work) {
          this.title = work.title;
          this.generatedContent = work.content;
          this.conversationHistory = ['original'];
        }
      }
    }
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

        Text(this.template ? this.template.name : '提示词编辑器')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.template) {
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
          Blank()
            .width(48)
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      if (this.isAiMode) {
        // AI对话模式
        this.AiChatView()
      } else {
        // 表单模式
        this.FormView()
      }

      // 底部操作栏
      Row() {
        Text(this.generatedContent.length + ' 字')
          .fontSize(12)
          .fontColor('#9CA3AF')

        Blank()

        Button('保存')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(20)
          .height(36)
          .padding({ left: 24, right: 24 })
          .onClick(() => this.saveWork())

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
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  @Builder
  FormView() {
    Scroll() {
      Column() {
        // 标题输入
        if (!this.template) {
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
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16, top: 12 })

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
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16 })

            Text(this.generatedContent)
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

        Button('发送')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(20)
          .height(40)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8 })
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
    this.generatedContent = content;
  }

  saveWork() {
    if (this.generatedContent.trim().length === 0) {
      promptAction.showToast({
        message: '内容不能为空',
        duration: 2000
      });
      return;
    }

    const finalTitle = this.title.trim().length > 0 ? this.title : (this.template ? this.template.name : '未命名作品');

    if (this.template) {
      const work = workManager.createWork(this.template, finalTitle, this.generatedContent);
      promptAction.showToast({
        message: '作品已保存',
        duration: 2000
      });
    }

    router.back();
  }

  generateWithAi() {
    if (!settingsManager.settings.apiKey) {
      promptAction.showToast({
        message: '请先在设置中配置API Key',
        duration: 2000
      });
      router.pushUrl({ url: 'pages/Index' });
      return;
    }

    // 模拟AI生成
    promptAction.showToast({
      message: 'AI生成中...',
      duration: 2000
    });

    // 实际项目中这里应该调用AI API
    setTimeout(() => {
      this.generatedContent += '\n\n[AI生成的内容将显示在这里]';
      this.updateGeneratedContent();
    }, 1000);
  }

  sendAiMessage() {
    if (this.currentPrompt.trim().length === 0) return;

    this.conversationHistory.push(this.currentPrompt);
    this.generatedContent += '\n\n用户: ' + this.currentPrompt;

    // 模拟AI回复
    setTimeout(() => {
      const reply = '这是AI的回复：' + this.currentPrompt;
      this.conversationHistory.push(reply);
      this.generatedContent += '\n\nAI: ' + reply;
    }, 1000);

    this.currentPrompt = '';
  }
}
