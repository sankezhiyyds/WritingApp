import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isDarkMode: boolean = false;
  private controller: TabsController = new TabsController();

  get bgColor(): string {
    return this.isDarkMode ? '#1A1A2E' : '#F5F6FA';
  }

  get cardBg(): string {
    return this.isDarkMode ? '#2D2D3A' : '#FFFFFF';
  }

  get textColor(): string {
    return this.isDarkMode ? '#FFFFFF' : '#1A1A2E';
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('文字创意工坊')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        // AI标识
        Text('🤖')
          .fontSize(20)
        Text('AI')
          .fontSize(10)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(4)
          .padding({ left: 4, right: 4 })
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      // Tab内容
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColoir })
        }
        .tabBar(this.TabBuilder('短剧', '🎬', 0))

        TabContent() {
          NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor })
        }
        .tabBar(this.TabBuilder('中长篇', '📚', 1))

        TabContent() {
          SettingsTab({ isDarkMode: this.isDarkMode, onDarkModeChange: (v) => { this.isDarkMode = v; } })
        }
        .tabBar(this.TabBuilder('设置', '⚙️', 2))
      }
      .barHeight(56)
      .barBackgroundColor(this.cardBg)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
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

// ========== 短剧工作台 ==========
@Component
struct ShortDramaTab {
  @Prop isDarkMode: boolean;
  @Prop cardBg: string;
  @Prop textColor: string;
  @State templates: TemplateInfo[] = templateList.filter(t => t.category === '短剧类' || t.id === 'short_drama' || t.id === 'manzai' || t.id === 'sketch' || t.id === 'short_video' || t.id === 'script_murder' || t.id === 'monologue' || t.id === 'absurdist' || t.id === 'sitcom');
  @State works: WorkItem[] = [];

  aboutToAppear() {
    this.works = workManager.getAllWorks().filter(w => this.templates.some(t => t.id === w.templateId));
  }

  build() {
    Column() {
      // 头部操作栏
      Row() {
        Text('短剧工作台')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'short_drama' } });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      // 模板选择区
      Column() {
        Text('选择模板开始创作')
          .fontSize(14)
          .fontColor('#9CA3AF')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, top: 12, bottom: 8 })

        Grid() {
          ForEach(this.templates, (item: TemplateInfo) => {
            GridItem() {
              this.TemplateCard(item)
            }
          }, (item: TemplateInfo) => item.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(12)
        .columnsGap(12)
        .padding({ left: 16, right: 16 })
        .layoutWeight(1)
      }
      .layoutWeight(1)

      // 作品列表
      if (this.works.length > 0) {
        Column() {
          Text('最近作品')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .alignSelf(ItemAlign.Start)
            .margin({ left: 16, top: 12, bottom: 8 })

          List() {
            ForEach(this.works.slice(0, 5), (work: WorkItem) => {
              ListItem() {
                this.WorkCard(work)
              }
            }, (work: WorkItem) => work.id)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  @Builder
  TemplateCard(template: TemplateInfo) {
    Column() {
      Stack() {
        Circle()
          .width(40)
          .height(40)
          .fill(template.color)
        Text(template.icon)
          .fontSize(18)
          .fontColor('#FFFFFF')
      }
      .alignContent(Alignment.Center)

      Text(template.name)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(template.desc)
        .fontSize(10)
        .fontColor('#9CA3AF')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('90%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/PromptEditorPage',
        params: { templateId: template.id, mode: 'short_drama' }
      });
    })
  }

  @Builder
  WorkCard(work: WorkItem) {
    Row() {
      Column() {
        Text(work.title || '未命名作品')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
        Text(work.templateName)
          .fontSize(11)
          .fontColor('#FF2D55')
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(10)
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('>')
        .fontSize(16)
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .height(60)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 8 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/WorkEditorPage',
        params: { workId: work.id, mode: 'short_drama' }
      });
    })
  }
}

// ========== 中长篇工作台 ==========
@Component
struct NovelTab {
  @Prop isDarkMode: boolean;
  @Prop cardBg: string;
  @Prop textColor: string;
  @State templates: TemplateInfo[] = templateList.filter(t => t.category === '中长篇类' || t.id === 'hero_journey' || t.id === 'emotional_tension' || t.id === 'mystery' || t.id === 'story_nucleus' || t.id === 'viral_formula' || t.id === 'three_act' || t.id === 'five_act');
  @State works: WorkItem[] = [];

  aboutToAppear() {
    this.works = workManager.getAllWorks().filter(w => this.templates.some(t => t.id === w.templateId));
  }

  build() {
    Column() {
      Row() {
        Text('中长篇工作台')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'novel' } });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      Column() {
        Text('选择模板开始创作')
          .fontSize(14)
          .fontColor('#9CA3AF')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, top: 12, bottom: 8 })

        Grid() {
          ForEach(this.templates, (item: TemplateInfo) => {
            GridItem() {
              this.TemplateCard(item)
            }
          }, (item: TemplateInfo) => item.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(12)
        .columnsGap(12)
        .padding({ left: 16, right: 16 })
        .layoutWeight(1)
      }
      .layoutWeight(1)

      if (this.works.length > 0) {
        Column() {
          Text('最近作品')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .alignSelf(ItemAlign.Start)
            .margin({ left: 16, top: 12, bottom: 8 })

          List() {
            ForEach(this.works.slice(0, 5), (work: WorkItem) => {
              ListItem() {
                this.WorkCard(work)
              }
            }, (work: WorkItem) => work.id)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  @Builder
  TemplateCard(template: TemplateInfo) {
    Column() {
      Stack() {
        Circle()
          .width(40)
          .height(40)
          .fill(template.color)
        Text(template.icon)
          .fontSize(18)
          .fontColor('#FFFFFF')
      }
      .alignContent(Alignment.Center)

      Text(template.name)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(template.desc)
        .fontSize(10)
        .fontColor('#9CA3AF')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('90%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/PromptEditorPage',
        params: { templateId: template.id, mode: 'novel' }
      });
    })
  }

  @Builder
  WorkCard(work: WorkItem) {
    Row() {
      Column() {
        Text(work.title || '未命名作品')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
        Text(work.templateName)
          .fontSize(11)
          .fontColor('#FF2D55')
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(10)
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('>')
        .fontSize(16)
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .height(60)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 8 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/WorkEditorPage',
        params: { workId: work.id, mode: 'novel' }
      });
    })
  }
}

// ========== 设置Tab ==========
@Component
struct SettingsTab {
  @Prop isDarkMode: boolean;
  @Prop onDarkModeChange: (value: boolean) => void;
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State showApiKeyInput: boolean = false;
  @State apiKeyInput: string = '';

  aboutToAppear() {
    this.loadSettings();
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 16, top: 16, bottom: 12 })

      List() {
        // AI模型配置
        ListItem() {
          this.SettingRow('AI模型配置', this.getModelName(), true)
        }
        .onClick(() => this.showModelPicker())

        ListItem() {
          this.SettingRow('API Key', this.apiKey ? '已配置' : '未配置', true)
        }
        .onClick(() => {
          this.apiKeyInput = this.apiKey;
          this.showApiKeyInput = true;
        })

        // 外观设置
        ListItem() {
          this.SettingRow('深色模式', this.isDarkMode ? '开' : '关', false)
        }
        .onClick(() => {
          this.isDarkMode = !this.isDarkMode;
          this.onDarkModeChange(this.isDarkMode);
        })

        ListItem() {
          this.SettingRow('跟随系统', this.isDarkMode ? '是' : '否', false)
        }
        .onClick(() => {
          // 实际项目中可读取系统主题设置
          this.isDarkMode = !this.isDarkMode;
          this.onDarkModeChange(this.isDarkMode);
        })

        // 功能设置
        ListItem() {
          this.SettingRow('写作提示词', '编辑AI提示词', true)
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/PromptEditorPage' });
        })

        ListItem() {
          this.SettingRow('用户协议', '', true)
        }
        .onClick(() => {
          promptAction.showToast({ message: '用户协议页面开发中', duration: 2000 });
        })

        ListItem() {
          this.SettingRow('隐私政策', '', true)
        }
        .onClick(() => {
          promptAction.showToast({ message: '隐私政策页面开发中', duration: 2000 });
        })

        // 关于
        ListItem() {
          this.SettingRow('应用评分', '⭐⭐⭐⭐⭐', false)
        }
        .onClick(() => {
          promptAction.showToast({ message: '感谢您的五星好评！', duration: 2000 });
        })

        ListItem() {
          this.SettingRow('关于', 'v1.1.0', false)
        }
        .onClick(() => {
          promptAction.showToast({ message: '文字创意工坊 v1.1.0\nAI驱动的写作助手', duration: 3000 });
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#1A1A2E' : '#F5F6FA')
  }

  @Builder
  SettingRow(title: string, subtitle: string, hasArrow: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
        if (subtitle) {
          Text(subtitle)
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (hasArrow) {
        Text('›')
          .fontSize(20)
          .fontColor('#D1D5DB')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
  }

  getModelName(): string {
    switch (this.selectedModel) {
      case 'deepseek': return 'DeepSeek';
      case 'glm': return '智谱 GLM';
      case 'baidu': return '百度文心';
      case 'xiaoyi': return '小艺 Agent';
      case 'gguf': return '本地 GGUF';
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
        { text: '小艺 Agent', color: '#1A1A2E' },
        { text: '本地 GGUF', color: '#1A1A2E' },
        { text: '自定义接口', color: '#1A1A2E' }
      ]
    }).then((result) => {
      const models = ['deepseek', 'glm', 'baidu', 'xiaoyi', 'gguf', 'custom'];
      if (result.index >= 0 && result.index < models.length) {
        this.selectedModel = models[result.index];
        this.saveSettings();
      }
    });
  }

  loadSettings() {
    this.apiKey = settingsManager.settings.apiKey;
    this.selectedModel = settingsManager.settings.selectedModel;
  }

  saveSettings() {
    settingsManager.settings.apiKey = this.apiKey;
    settingsManager.settings.selectedModel = this.selectedModel;
    settingsManager.save();
  }
}
