import { WorkItem, workManager } from '../model/WorkManager';
import { TemplateInfo, templateList } from '../model/TemplateModel';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct WorkEditorPage {
  @State work: WorkItem | null = null;
  @State content: string = '';
  @State title: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['workId']) {
      this.work = workManager.getWork(params['workId']);
      if (this.work) {
        this.content = this.work.content;
        this.title = this.work.title;
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

        Text(this.work ? '编辑作品' : '新建作品')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.work) {
          Text('删除')
            .fontSize(14)
            .fontColor('#EF4444')
            .onClick(() => this.deleteWork())
            .padding({ left: 12, right: 16 })
        } else {
          Blank()
            .width(48)
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 标题输入（仅新建时显示）
      if (!this.work) {
        TextInput({ placeholder: '请输入作品标题', text: this.title })
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#FFFFFF')
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.title = value;
          })
      }

      // 内容编辑区域
      TextArea({ placeholder: '开始创作...', text: this.content })
        .width('100%')
        .layoutWeight(1)
        .fontSize(15)
        .lineHeight(24)
        .backgroundColor('#FFFFFF')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .onChange((value: string) => {
          this.content = value;
        })

      // 底部保存栏
      Row() {
        Text(this.content.length + ' 字')
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
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  saveWork() {
    if (this.content.trim().length === 0) {
      promptAction.showToast({
        message: '内容不能为空',
        duration: 2000
      });
      return;
    }

    if (this.work) {
      workManager.updateWork(this.work.id, this.content);
      promptAction.showToast({
        message: '作品已更新',
        duration: 2000
      });
    } else {
      const finalTitle = this.title.trim().length > 0 ? this.title : '未命名作品';
      const params = router.getParams() as Record<string, string>;
      let template: TemplateInfo | null = null;
      if (params && params['templateId']) {
        template = templateList.find(t => t.id === params['templateId']) || null;
      }

      if (template) {
        workManager.createWork(template, finalTitle, this.content);
      } else {
        // 无模板时使用默认模板信息
        const defaultTemplate: TemplateInfo = templateList[0];
        workManager.createWork(defaultTemplate, finalTitle, this.content);
      }
      promptAction.showToast({
        message: '作品已保存',
        duration: 2000
      });
    }

    router.back();
  }

  deleteWork() {
    if (!this.work) return;
    const workId = this.work.id;

    promptAction.showDialog({
      title: '删除作品',
      message: '确定要删除这个作品吗？此操作不可恢复。',
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '删除', color: '#EF4444' }
      ]
    }).then((result) => {
      if (result.index === 1) {
        workManager.deleteWork(workId);
        promptAction.showToast({
          message: '作品已删除',
          duration: 2000
        });
        router.back();
      }
    });
  }
}
