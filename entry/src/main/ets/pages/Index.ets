import { templateList } from '../model/TemplateModel';
import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State activeTab: number = 0;

  build() {
    Column() {
      NavDestination() {
        Stack() {
          TabRow({ activeIndex: this.activeTab, barWidth: '100%' }) {
            TabContent() {
              TemplateListPage()
            }
            TabContent() {
              WorkManagerPage()
            }
            TabContent() {
              SettingsPage()
            }
          }
          .barHeight(56)
          .barBackgroundColor('#FFFFFF')
          .barShadow('0px 2px 8px rgba(0,0,0,0.08)')
          .selectedIndex(this.activeTab)
          .onChange((index: number) => {
            this.activeTab = index;
          })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }
}

@Component
struct TemplateListPage {
  @State templates: TemplateInfo[] = templateList;
  @State searchText: string = '';

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
        ForEach(this.templates, (item: TemplateInfo) => {
          GridItem() {
            TemplateCard({ template: item })
          }
        }, (item: TemplateInfo) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(12)
      .padding({ left: 16, right: 16, top: 8 })
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

@Component
struct WorkManagerPage {
  @State works: WorkItem[] = [];

  build() {
    Column() {
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
}

@Component
struct WorkCard {
  @Prop work: WorkItem;

  build() {
    Row() {
      Column() {
        Text(this.work.title)
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

@Component
struct SettingsPage {
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State customUrl: string = '';

  build() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      List() {
        ListItem() {
          SettingSection(title: 'AI 模型配置', items: [
            SettingItem(label: 'API Key', value: this.apiKey ? '已配置' : '未配置',
              action: () => this.showApiKeyDialog())
          ])
        }
        
        ListItem() {
          SettingSection(title: '模型选择', items: [
            SettingItem(label: '当前模型', value: this.getModelName(),
              action: () => this.showModelPicker())
          ])
        }

        ListItem() {
          SettingSection(title: '使用提示', items: [
            SettingItem(label: 'Token压缩', value: '用42字写5个有效信息', editable: false),
            SettingItem(label: '行为锚定', value: '多写具体行为，少写空洞情绪词', editable: false),
            SettingItem(label: '视觉化描述', value: '用画面代替抽象概念', editable: false)
          ])
        }
      }
      .layoutWeight(1)
      .padding({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  getModelName(): string {
    switch (this.selectedModel) {
      case 'deepseek': return 'DeepSeek';
      case 'glm': return '智谱 GLM';
      case 'baidu': return '百度文心';
      case 'custom': return '自定义接口';
      default: return 'DeepSeek';
    }
  }

  showApiKeyDialog() {
    promptAction.showDialog({
      title: '设置 API Key',
      message: '请输入您的 API Key（仅本地存储，不会上传）',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '保存',
        action: () => {
          // 实际项目中应保存到 LocalStorage
          promptAction.showToast({ message: '已保存', duration: 2000 });
        }
      }
    });
  }

  showModelPicker() {
    promptAction.showActionSheet({
      menu: ['DeepSeek', '智谱 GLM', '百度文心', '自定义接口']
    }).then((value) => {
      const models = ['deepseek', 'glm', 'baidu', 'custom'];
      const index = value.index;
      if (index >= 0 && index < models.length) {
        this.selectedModel = models[index];
      }
    });
  }
}

@Component
struct SettingSection {
  @Param title: string;
  @Param items: SettingItemData[];

  build() {
    Column() {
      Text(this.title)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .padding({ left: 16, bottom: 8 })
      
      ForEach(this.items, (item: SettingItemData) => {
        Row() {
          Column() {
            Text(item.label)
              .fontSize(14)
              .fontColor('#1A1A2E')
            Text(item.value)
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          
          if (item.action) {
            Text('>')
              .fontSize(16)
              .fontColor('#D1D5DB')
              .onClick(item.action)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        
        Divider().color('#F3F4F6').strokeWidth(0.5).margin({ left: 16, right: 16 })
      }, (item: SettingItemData) => item.label)
    }
    .backgroundColor('#FFFFFF')
  }
}

interface SettingItemData {
  label: string;
  value: string;
  action?: () => void;
  editable: boolean;
}

@Component
struct SettingItem {
  @Param label: string;
  @Param value: string;
  @Param action: () => void;
  @Param editable: boolean = true;

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontColor('#1A1A2E')
        .layoutWeight(1)
      
      Text(this.value)
        .fontSize(13)
        .fontColor('#6B7280')
    }
    .width('100%')
    .padding(16)
  }
}

// ========== 数据模型 ==========

interface TemplateInfo {
  id: string;
  name: string;
  icon: string;
  desc: string;
  category: string;
  color: string;
  fields: TemplateField[];
  format: string;
  tips: string[];
}

interface TemplateField {
  key: string;
  label: string;
  type: 'text' | 'textarea' | 'select' | 'number';
  required: boolean;
  placeholder: string;
  options?: string[];
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
