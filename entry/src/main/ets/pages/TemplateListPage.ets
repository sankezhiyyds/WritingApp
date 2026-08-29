import { templateList, TemplateInfo } from '../model/TemplateModel';
import router from '@ohos.router';

@Entry
@Component
struct TemplateListPage {
  @State templates: TemplateInfo[] = templateList;
  @State activeCategory: string = '全部';
  @State filteredTemplates: TemplateInfo[] = templateList;

  aboutToAppear() {
    this.filterTemplates('全部');
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('写书助手')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
        Blank()
        Text('+ 新建作品')
          .fontSize(14)
          .fontColor('#FF2D55')
          .onClick(() => {
            router.pushUrl({ url: 'pages/WorkEditorPage' });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // 分类筛选
      Row() {
        this.CategoryChip('全部', true)
        this.CategoryChip('剧本类', false)
        this.CategoryChip('叙事类', false)
        this.CategoryChip('喜剧类', false)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 模板网格
      Grid() {
        ForEach(this.filteredTemplates, (item: TemplateInfo) => {
          GridItem() {
            TemplateCard({ template: item })
          }
        }, (item: TemplateInfo) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(12)
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  CategoryChip(text: string, active: boolean): Button {
    Button(text)
      .fontSize(12)
      .fontColor(active ? '#FFFFFF' : '#6B7280')
      .backgroundColor(active ? '#FF2D55' : '#E5E7EB')
      .borderRadius(12)
      .height(28)
      .padding({ left: 12, right: 12 })
      .margin({ right: 8 })
      .onClick(() => {
        this.activeCategory = text;
        this.filterTemplates(text);
      })
  }

  filterTemplates(category: string) {
    if (category === '全部') {
      this.filteredTemplates = this.templates;
    } else {
      this.filteredTemplates = this.templates.filter(t => t.category === category);
    }
  }
}

@Component
struct TemplateCard {
  @Prop template: TemplateInfo;

  build() {
    Column() {
      Stack() {
        Circle()
          .width(44)
          .height(44)
          .fill(this.template.color)
        Text(this.template.icon)
          .fontSize(20)
          .fontColor('#FFFFFF')
      }
      .alignContent(Alignment.Center)
      .margin({ top: 12 })

      Text(this.template.name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A2E')
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.template.desc)
        .fontSize(10)
        .fontColor('#9CA3AF')
        .margin({ top: 4 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('90%')
    }
    .width('100%')
    .height(110)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(12)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/TemplateDetailPage',
        params: { templateId: this.template.id }
      });
    })
  }
}
