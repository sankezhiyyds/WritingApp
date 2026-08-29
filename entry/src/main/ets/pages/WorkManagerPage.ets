import { templateList } from '../model/TemplateModel';
import { workManager } from '../model/WorkManager';
import router from '@ohos.router';

@Entry
@Component
struct WorkManagerPage {
  @State works: WorkItem[] = [];
  @State activeTab: number = 0;

  aboutToAppear() {
    this.loadWorks();
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('我的作品')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
        Blank()
        Button('+ 新建')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/WorkEditorPage' });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // 分类标签
      Row() {
        this.TabChip('全部', this.activeTab === 0)
        this.TabChip('今日', this.activeTab === 1)
        this.TabChip('本周', this.activeTab === 2)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // 作品列表
      if (this.works.length === 0) {
        Column() {
          Text('📝')
            .fontSize(48)
          Text('还没有作品')
            .fontSize(16)
            .fontColor('#6B7280')
            .margin({ top: 8 })
          Text('点击上方按钮开始创作')
            .fontSize(13)
            .fontColor('#9CA3AF')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.works, (work: WorkItem) => {
            ListItem() {
              WorkCard({ work: work })
            }
          }, (work: WorkItem) => work.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  TabChip(text: string, active: boolean): Button {
    Button(text)
      .fontSize(12)
      .fontColor(active ? '#FFFFFF' : '#6B7280')
      .backgroundColor(active ? '#FF2D55' : '#E5E7EB')
      .borderRadius(12)
      .height(28)
      .padding({ left: 12, right: 12 })
      .margin({ right: 8 })
      .onClick(() => {
        this.activeTab = text === '全部' ? 0 : text === '今日' ? 1 : 2;
        this.filterWorks();
      })
  }

  loadWorks() {
    this.works = workManager.getAllWorks();
  }

  filterWorks() {
    // 根据 activeTab 过滤作品
    const now = new Date();
    if (this.activeTab === 1) {
      // 今日
      this.works = this.works.filter(w => {
        const date = new Date(w.createTime);
        return date.toDateString() === now.toDateString();
      });
    } else if (this.activeTab === 2) {
      // 本周
      this.works = this.works.filter(w => {
        const date = new Date(w.createTime);
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        return date >= weekAgo;
      });
    }
  }
}

@Component
struct WorkCard {
  @Prop work: WorkItem;

  build() {
    Row() {
      Column() {
        Text(this.work.title || '未命名作品')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
        Text(this.work.templateName)
          .fontSize(12)
          .fontColor('#FF2D55')
          .margin({ top: 4 })
        Text(this.work.updateTime)
          .fontSize(11)
          .fontColor('#9CA3AF')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      Text('>')
        .fontSize(18)
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .height(72)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding({ left: 16, right: 12 })
    .margin({ bottom: 8 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/WorkEditorPage',
        params: { workId: this.work.id }
      });
    })
  }
}

interface WorkItem {
  id: string;
  title: string;
  templateId: string;
  templateName: string;
  content: string;
  createTime: string;
  updateTime: string;
}
