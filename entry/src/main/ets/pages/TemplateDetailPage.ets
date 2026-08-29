import { templateList, TemplateInfo, TemplateField } from '../model/TemplateModel';
import { workManager, WorkItem } from '../model/WorkManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct TemplateDetailPage {
  @State template: TemplateInfo | null = null;
  @State fieldValues: Record<string, string> = {};
  @State generatedContent: string = '';

  aboutToAppear() {
    const params = router.getParams() as { templateId: string };
    const templateId = params.templateId;
    this.template = templateList.find(t => t.id === templateId) || null;
    
    if (this.template) {
      // 初始化字段值
      for (const field of this.template.fields) {
        this.fieldValues[field.key] = '';
      }
    }
  }

  build() {
    Column() {
      if (!this.template) {
        Text('模板未找到')
          .fontSize(16)
          .fontColor('#6B7280')
      } else {
        // 顶部导航
        NavBar({ template: this.template })

        // 内容滚动区域
        Scroll() {
          Column() {
            // 提示信息
            this.TipSection(this.template.tips)

            // 表单字段
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
                      value: this.fieldValues[field.key] || '',
                      placeholder: field.placeholder,
                      onChange: (value: string) => {
                        this.fieldValues[field.key] = value;
                        this.updateGeneratedContent();
                      }
                    })
                    .width('100%')
                    .height(100)
                    .fontSize(14)
                    .backgroundColor('#F9FAFB')
                    .borderRadius(8)
                    .padding(12)
                  } else if (field.type === 'select') {
                    Row() {
                      ForEach(field.options || [], (option: string) => {
                        Button(option)
                          .fontSize(12)
                          .fontColor(this.fieldValues[field.key] === option ? '#FFFFFF' : '#6B7280')
                          .backgroundColor(this.fieldValues[field.key] === option ? '#FF2D55' : '#E5E7EB')
                          .borderRadius(16)
                          .height(32)
                          .padding({ left: 12, right: 12 })
                          .margin({ right: 8 })
                          .onClick(() => {
                            this.fieldValues[field.key] = option;
                            this.updateGeneratedContent();
                          })
                      })
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
                .backgroundColor('#FFFFFF')
                
                Divider().color('#F3F4F6').strokeWidth(0.5).margin({ left: 16, right: 16 })
              }, (field: TemplateField) => field.key)
            }
            .width('100%')
            .backgroundColor('#FFFFFF')

            // 生成内容预览
            if (this.generatedContent) {
              Column() {
                Text('生成内容预览')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A2E')
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                  .padding({ left: 16 })
                
                Text(this.generatedContent)
                  .fontSize(13)
                  .fontColor('#374151')
                  .lineHeight(20)
                  .padding(16)
                  .width('100%')
                  .backgroundColor('#F9FAFB')
                  .borderRadius(8)
              }
              .width('100%')
              .margin({ top: 8 })
              .padding({ left: 16, right: 16, bottom: 16 })
            }

            // 保存按钮
            Button('保存为作品')
              .width('calc(100% - 32px)')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(24)
              .margin({ top: 8, bottom: 24 })
              .alignSelf(ItemAlign.Center)
              .onClick(() => this.saveWork())
          }
          .width('100%')
        }
        .layoutWeight(1)
        .backgroundColor('#F5F6FA')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  NavBar(template: TemplateInfo) {
    Row() {
      Button('←')
        .fontSize(16)
        .fontColor('#FF2D55')
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })
      
      Text(template.name)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      
      Blank()
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
  }

  TipSection(tips: string[]) {
    Column() {
      Text('💡 写作提示')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FF6B35')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)
        .padding({ left: 16 })
      
      ForEach(tips, (tip: string, index: number) => {
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
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }, (tip: string, index: number) => index.toString())
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .margin({ bottom: 8 })
  }

  updateGeneratedContent() {
    if (!this.template) return;
    
    let content = this.template.format;
    for (const [key, value] of Object.entries(this.fieldValues)) {
      content = content.replace(new RegExp(`\\{${key}\\}`, 'g'), value || '');
    }
    this.generatedContent = content;
  }

  saveWork() {
    if (!this.template) return;
    
    // 验证必填字段
    const requiredFields = this.template.fields.filter(f => f.required);
    for (const field of requiredFields) {
      if (!this.fieldValues[field.key]?.trim()) {
        promptAction.showToast({
          message: `请填写${field.label}`,
          duration: 2000
        });
        return;
      }
    }

    // 生成作品标题
    const title = this.fieldValues['title'] || this.template.name;
    
    // 保存作品
    const work = workManager.createWork(this.template, title, this.generatedContent);
    
    promptAction.showToast({
      message: '作品已保存',
      duration: 2000
    });

    // 跳转到作品编辑器
    router.pushUrl({
      url: 'pages/WorkEditorPage',
      params: { workId: work.id }
    });
  }
}
