import { templateList, TemplateInfo, TemplateField } from '../model/TemplateModel';
import { workManager, WorkItem } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          TemplateListTab()
        }
        .tabBar(this.TabBuilder('模板库', '📚', 0))

        TabContent() {
          WorkManagerTab()
        }
        .tabBar(this.TabBuilder('我的作品', '📝', 1))

        TabContent() {
          SettingsTab()
        }
        .tabBar(this.TabBuilder('设置', '⚙️', 2))
      }
      .barHeight(56)
      .barBackgroundColor('#FFFFFF')
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  @Builder
  TabBuilder(title: string, icon: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(20)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? '#FF2D55' : '#9CA3AF')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// ========== 模板库 Tab ==========
@Component
struct TemplateListTab {
  @State templates: TemplateInfo[] = templateList;
  @State activeCategory: string = '全部';
  @State filteredTemplates: TemplateInfo[] = templateList;

  aboutToAppear() {
    this.filterTemplates('全部');
  }

  build() {
    Column() {
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

      Row() {
        this.CategoryChip('全部')
        this.CategoryChip('剧本类')
        this.CategoryChip('叙事类')
        this.CategoryChip('喜剧类')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

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

  @Builder
  CategoryChip(text: string) {
    Button(text)
      .fontSize(12)
      .fontColor(this.activeCategory === text ? '#FFFFFF' : '#6B7280')
      .backgroundColor(this.activeCategory === text ? '#FF2D55' : '#E5E7EB')
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

// ========== 我的作品 Tab ==========
@Component
struct WorkManagerTab {
  @State works: WorkItem[] = [];
  @State activeFilter: number = 0;

  aboutToAppear() {
    this.loadWorks();
  }

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

      Row() {
        this.FilterChip('全部', 0)
        this.FilterChip('今日', 1)
        this.FilterChip('本周', 2)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

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

  @Builder
  FilterChip(text: string, index: number) {
    Button(text)
      .fontSize(12)
      .fontColor(this.activeFilter === index ? '#FFFFFF' : '#6B7280')
      .backgroundColor(this.activeFilter === index ? '#FF2D55' : '#E5E7EB')
      .borderRadius(12)
      .height(28)
      .padding({ left: 12, right: 12 })
      .margin({ right: 8 })
      .onClick(() => {
        this.activeFilter = index;
        this.loadWorks();
      })
  }

  loadWorks() {
    let allWorks = workManager.getAllWorks();
    if (this.activeFilter === 1) {
      const today = this.formatToday();
      allWorks = allWorks.filter(w => w.createTime.startsWith(today));
    } else if (this.activeFilter === 2) {
      const weekAgo = this.formatWeekAgo();
      allWorks = allWorks.filter(w => w.createTime >= weekAgo);
    }
    this.works = allWorks;
  }

  private formatToday(): string {
    const now = new Date();
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  }

  private formatWeekAgo(): string {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${weekAgo.getFullYear()}-${pad(weekAgo.getMonth() + 1)}-${pad(weekAgo.getDate())}`;
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

// ========== 设置 Tab ==========
@Component
struct SettingsTab {
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State customUrl: string = '';
  @State showApiKeyInput: boolean = false;
  @State apiKeyInput: string = '';

  aboutToAppear() {
    this.loadSettings();
  }

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
          this.SettingSection('AI 模型配置', [
            { label: 'API Key', value: this.apiKey ? '已配置' : '未配置', editable: true }
          ])
        }
        .onClick(() => {
          this.apiKeyInput = this.apiKey;
          this.showApiKeyInput = true;
        })

        ListItem() {
          this.SettingSection('模型选择', [
            { label: '当前模型', value: this.getModelName(), editable: true }
          ])
        }
        .onClick(() => this.showModelPicker())

        ListItem() {
          this.SettingSection('写作技巧', [
            { label: 'Token压缩', value: '用42字写5个有效信息', editable: false },
            { label: '行为锚定', value: '多写具体行为，少写空洞情绪词', editable: false },
            { label: '视觉化描述', value: '用画面代替抽象概念', editable: false }
          ])
        }

        ListItem() {
          this.SettingSection('关于', [
            { label: '版本', value: '1.0.0', editable: false },
            { label: '开发者', value: '个人开发者', editable: false }
          ])
        }
      }
      .layoutWeight(1)
      .padding({ top: 8 })

      // API Key 输入弹层
      if (this.showApiKeyInput) {
        Column() {
          Column() {
            Text('设置 API Key')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
            Text('仅本地存储，不会上传到任何服务器')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextInput({ placeholder: '请输入 API Key', text: this.apiKeyInput })
              .width('100%')
              .height(44)
              .fontSize(14)
              .backgroundColor('#F9FAFB')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.apiKeyInput = value;
              })
            Row() {
              Button('取消')
                .fontSize(14)
                .fontColor('#6B7280')
                .backgroundColor('#F3F4F6')
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .margin({ right: 12 })
                .onClick(() => {
                  this.showApiKeyInput = false;
                })
              Button('保存')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF2D55')
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.apiKey = this.apiKeyInput.trim();
                  this.saveSettings();
                  this.showApiKeyInput = false;
                  promptAction.showToast({ message: '已保存', duration: 2000 });
                })
            }
            .width('100%')
            .margin({ top: 16 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showApiKeyInput = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  @Builder
  SettingSection(title: string, items: SettingItemData[]) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .padding({ left: 16, bottom: 8 })

      ForEach(items, (item: SettingItemData) => {
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

          if (item.editable) {
            Text('>')
              .fontSize(16)
              .fontColor('#D1D5DB')
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

  getModelName(): string {
    switch (this.selectedModel) {
      case 'deepseek': return 'DeepSeek';
      case 'glm': return '智谱 GLM';
      case 'baidu': return '百度文心';
      case 'custom': return '自定义接口';
      default: return 'DeepSeek';
    }
  }

  showModelPicker() {
    promptAction.showActionMenu({
      title: '选择模型',
      buttons: [
        { text: 'DeepSeek', color: '#1A1A2E' },
        { text: '智谱 GLM', color: '#1A1A2E' },
        { text: '百度文心', color: '#1A1A2E' },
        { text: '自定义接口', color: '#1A1A2E' }
      ]
    }).then((result) => {
      const models = ['deepseek', 'glm', 'baidu', 'custom'];
      if (result.index >= 0 && result.index < models.length) {
        this.selectedModel = models[result.index];
        this.saveSettings();
      }
    });
  }

  loadSettings() {
    this.apiKey = settingsManager.settings.apiKey;
    this.selectedModel = settingsManager.settings.selectedModel;
    this.customUrl = settingsManager.settings.customUrl;
  }

  saveSettings() {
    settingsManager.settings.apiKey = this.apiKey;
    settingsManager.settings.selectedModel = this.selectedModel;
    settingsManager.settings.customUrl = this.customUrl;
    settingsManager.save();
  }
}

interface SettingItemData {
  label: string;
  value: string;
  editable: boolean;
}
