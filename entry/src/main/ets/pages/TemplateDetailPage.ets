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
    const params = router.getParams() as Record<string, string>;
    if (params && params['templateId']) {
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
  }

  build() {
    Column() {
      if (!this.template) {
        Text('模板未找到')
          .fontSize(16)
          .fontColor('#6B7280')
      } else {
        // 顶部导航
        Row() {
          Text('←')
            .fontSize(20)
            .fontColor('#FF2D55')
            .onClick(() => {
              router.back();
            })
            .padding({ left: 16, right: 12 })

          Text(this.template.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank()
            .width(48)
        }
        .width('100%')
        .height(56)
        .backgroundColor('#FFFFFF')

        // 内容滚动区域
        Scroll() {
          Column() {
            // 提示信息
            Column() {
              Text('写作提示')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FF6B35')
                .margin({ bottom: 8 })
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
            .margin({ bottom: 8 })

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

            // 生成内容预览
            if (this.generatedContent.length > 0) {
              Column() {
                Text('生成内容预览')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A2E')
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)

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

            // 保存按钮
            Button('保存为作品')
              .width('90%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(24)
              .margin({ top: 16, bottom: 24 })
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
    if (!this.template) return;

    // 验证必填字段
    for (let i = 0; i < this.template.fields.length; i++) {
      const field = this.template.fields[i];
      if (field.required) {
        const val = this.fieldValues[field.key];
        if (!val || val.trim().length === 0) {
          promptAction.showToast({
            message: '请填写' + field.label,
            duration: 2000
          });
          return;
        }
      }
    }

    // 生成作品标题
    const titleVal = this.fieldValues['title'];
    const title = (titleVal && titleVal.trim().length > 0) ? titleVal : this.template.name;

    // 保存作品
    const work = workManager.createWork(this.template, title, this.generatedContent);

    promptAction.showToast({
      message: '作品已保存',
      duration: 2000
    });

    router.back();
  }
}
