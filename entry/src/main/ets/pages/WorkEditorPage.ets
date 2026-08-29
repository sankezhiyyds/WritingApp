import { workManager, WorkItem } from '../model/WorkManager';
import { templateList } from '../model/TemplateModel';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct WorkEditorPage {
  @State work: WorkItem | null = null;
  @State content: string = '';
  @State title: string = '';

  aboutToAppear() {
    const params = router.getParams() as { workId?: string };
    if (params.workId) {
      this.work = workManager.getWork(params.workId);
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
        Button('←')
          .fontSize(16)
          .fontColor('#FF2D55')
          .backgroundColor('transparent')
          .onClick(() => {
            router.back();
          })
        
        Text(this.work ? '编辑作品' : '新建作品')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        if (this.work) {
          Button('删除')
            .fontSize(14)
            .fontColor('#EF4444')
            .backgroundColor('transparent')
            .onClick(() => this.deleteWork())
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 标题输入
      if (!this.work) {
        Column() {
          TextInput({ placeholder: '请输入作品标题' })
            .width('calc(100% - 32px)')
            .height(44)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#FFFFFF')
            .border({ width: 0 })
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.title = value;
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#F3F4F6' })
      }

      // 内容编辑区域
      Stack() {
        TextArea({
          value: this.content,
          placeholder: '开始创作...'
        })
        .width('100%')
        .height('100%')
        .fontSize(15)
        .lineHeight(24)
        .backgroundColor('#FFFFFF')
        .padding({ left: 16, right: 16, top: 16, bottom: 80 })
        .onChange((value: string) => {
          this.content = value;
        })

        // 底部保存栏
        Row() {
          Text(`${this.content.length} 字`)
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ right: 16 })
          
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
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.End)
        .padding({ right: 16 })
        .position({ x: 0, y: 'calc(100% - 56px)' })
        .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: -2 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  saveWork() {
    if (!this.content.trim()) {
      promptAction.showToast({
        message: '内容不能为空',
        duration: 2000
      });
      return;
    }

    const finalTitle = this.work?.title || this.title || '未命名作品';
    
    if (this.work) {
      workManager.updateWork(this.work.id, this.content);
      promptAction.showToast({
        message: '作品已更新',
        duration: 2000
      });
    } else {
      // 创建新作品
      const params = router.getParams() as { templateId?: string };
      const template = params.templateId 
        ? templateList.find(t => t.id === params.templateId)
        : null;
      
      if (template) {
        workManager.createWork(template, finalTitle, this.content);
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

    promptAction.showDialog({
      title: '删除作品',
      message: '确定要删除这个作品吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          workManager.deleteWork(this.work!.id);
          promptAction.showToast({
            message: '作品已删除',
            duration: 2000
          });
          router.back();
        }
      }
    });
  }
}
