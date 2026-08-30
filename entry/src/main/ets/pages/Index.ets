import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import Configuration from '@ohos.app.ability.Configuration';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isDarkMode: boolean = false;
  @State showOnboarding: boolean = false;
  @State currentBreakpoint: BreakpointType = 'sm';
  private controller: TabsController = new TabsController();

  get isWide(): boolean {
    return this.currentBreakpoint === 'md' || this.currentBreakpoint === 'lg';
  }

  get templateColumns(): string {
    if (this.currentBreakpoint === 'lg') {
      return '1fr 1fr 1fr 1fr';
    } else if (this.currentBreakpoint === 'md') {
      return '1fr 1fr 1fr';
    }
    return '1fr 1fr 1fr';
  }

  get navWidth(): number {
    return this.currentBreakpoint === 'lg' ? 240 : 200;
  }

  get contentMaxWidth(): number {
    if (this.currentBreakpoint === 'lg') {
      return 1200;
    } else if (this.currentBreakpoint === 'md') {
      return 840;
    }
    return 10000;
  }

  get bgColor(): string {
    return this.isDarkMode ? '#1A1A2E' : '#F5F6FA';
  }

  get cardBg(): string {
    return this.isDarkMode ? '#2D2D3A' : '#FFFFFF';
  }

  get textColor(): string {
    return this.isDarkMode ? '#FFFFFF' : '#1A1A2E';
  }

  aboutToAppear() {
    // 检查是否首次启动
    if (settingsManager.settings.isFirstLaunch) {
      this.showOnboarding = true;
    }
    // 初始化断点
    this.currentBreakpoint = responsiveManager.getBreakpoint();
    responsiveManager.onBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });
    // 初始化深色模式
    this.updateDarkMode();
  }

  updateDarkMode() {
    if (settingsManager.settings.followSystemDark) {
      // 获取系统配置
      const context = getContext(this) as Context;
      const config = context.config;
      if (config && config.colorMode !== undefined) {
        this.isDarkMode = config.colorMode === Configuration.ColorMode.COLOR_MODE_DARK;
      }
    } else {
      // 使用用户手动设置
      this.isDarkMode = settingsManager.settings.isDarkMode;
    }
  }

  aboutToDisappear() {
    responsiveManager.offBreakpointChange((bp: BreakpointType) => {
      this.currentBreakpoint = bp;
    });
  }

  build() {
    Stack() {
      if (this.isWide) {
        // 宽屏布局：侧边导航 + 内容区
        Row() {
          // 侧边导航栏
          Column() {
            Text('创意写作')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .margin({ top: 20, bottom: 24 })
            Text('🤖')
              .fontSize(16)
              .margin({ bottom: 20 })

            this.SideNavItem('短剧', '🎬', 0)
            this.SideNavItem('中长篇', '📚', 1)
            this.SideNavItem('设置', '⚙️', 2)

            Blank()
            Text('AI')
              .fontSize(10)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ bottom: 16 })
          }
          .width(this.navWidth)
          .height('100%')
          .backgroundColor(this.cardBg)
          .justifyContent(FlexAlign.Start)

          // 内容区
          Column() {
            if (this.currentIndex === 0) {
              ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
            } else if (this.currentIndex === 1) {
              NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
            } else {
              SettingsTab({ isDarkMode: this.isDarkMode, onDarkModeChange: (v) => { this.isDarkMode = v; } })
            }
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor(this.bgColor)
        }
        .width('100%')
        .height('100%')
      } else {
        // 窄屏布局：底部Tab导航（手机/折叠屏折叠态）
        Column() {
          // 顶部栏
          Row() {
            Text('创意写作')
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
              ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
            }
            .tabBar(this.TabBuilder('短剧', '🎬', 0))

            TabContent() {
              NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
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

      // 首次启动引导弹窗
      if (this.showOnboarding) {
        this.OnboardingDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SideNavItem(label: string, icon: string, index: number) {
    Row() {
      Text(icon)
        .fontSize(20)
        .margin({ right: 12 })
      Text(label)
        .fontSize(15)
        .fontColor(this.currentIndex === index ? '#FF6B35' : this.textColor)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20 })
    .backgroundColor(this.currentIndex === index ? (this.isDarkMode ? '#3D3D4A' : '#FFF0E5') : 'transparent')
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  @Builder
  OnboardingDialog() {
    Column() {
      Column() {
        Text('欢迎使用创意写作')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .margin({ bottom: 16 })

        Text('🤖 AI驱动的写作助手')
          .fontSize(16)
          .fontColor('#FF2D55')
          .margin({ bottom: 12 })

        Text('核心功能：')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('• 短剧/中长篇双工作台，独立管理')
          .fontSize(13)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('• AI对话生成，一键保存思维链路')
          .fontSize(13)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('• 自动版本归档，修改历史可追溯')
          .fontSize(13)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('• 支持多种AI模型：DeepSeek、智谱GLM、百度文心、小艺助手、本地GGUF')
          .fontSize(13)
          .fontColor('#6B7280')
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        Text('隐私声明：')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('• 您的API Key仅存储在本地，不会上传到任何服务器')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('• 作品数据完全保存在您的设备上')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .margin({ bottom: 16 })
          .alignSelf(ItemAlign.Start)

        Row() {
          Button('查看用户协议')
            .fontSize(13)
            .fontColor('#6B7280')
            .backgroundColor('#F3F4F6')
            .borderRadius(20)
            .height(36)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              promptAction.showToast({ message: '用户协议页面开发中', duration: 2000 });
            })

          Button('同意并继续')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(20)
            .height(36)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => {
              settingsManager.settings.isFirstLaunch = false;
              settingsManager.settings.hasAgreedToTerms = true;
              settingsManager.save();
              this.showOnboarding = false;
              promptAction.showToast({ message: '欢迎开始创作！', duration: 2000 });
            })
        }
        .width('100%')
      }
      .width('90%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
  @Prop bgColor: string;
  @State templates: TemplateInfo[] = [];
  @State works: WorkItem[] = [];

  get templateColumns(): string {
    const cols = responsiveManager.getTemplateColumns();
    let result = '';
    for (let i = 0; i < cols; i++) {
      result += '1fr ';
    }
    return result.trim();
  }

  aboutToAppear() {
    this.templates = templateList.filter(t => t.category === '剧本类' || t.category === '喜剧类' || t.category === '灵感类' || t.category === '广告类');
    this.works = workManager.getAllWorks().filter(w => this.templates.some(t => t.id === w.templateId));
  }

  build() {
    Column() {
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
        .columnsTemplate(this.templateColumns)
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
        url: 'pages/PromptEditorPage',
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
  @Prop bgColor: string;
  @State templates: TemplateInfo[] = [];
  @State works: WorkItem[] = [];

  get templateColumns(): string {
    const cols = responsiveManager.getTemplateColumns();
    let result = '';
    for (let i = 0; i < cols; i++) {
      result += '1fr ';
    }
    return result.trim();
  }

  aboutToAppear() {
    this.templates = templateList.filter(t => t.category === '叙事类' || t.category === '互动类');
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
        .columnsTemplate(this.templateColumns)
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
        url: 'pages/PromptEditorPage',
        params: { workId: work.id, mode: 'novel' }
      });
    })
  }
}

// ========== 设置Tab ==========
@Component
struct SettingsTab {
  @Prop isDarkMode: boolean;
  onDarkModeChange: (value: boolean) => void = (value: boolean) => {};
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State showApiKeyInput: boolean = false;
  @State apiKeyInput: string = '';
  @State customUrl: string = '';
  @State showCustomUrlInput: boolean = false;
  @State customUrlInput: string = '';
  @State followSystemDark: boolean = false;

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

        ListItem() {
          this.SettingRow('自定义接口地址', this.customUrl ? '已配置' : '未配置', true)
        }
        .onClick(() => {
          this.customUrlInput = this.customUrl;
          this.showCustomUrlInput = true;
        })

        ListItem() {
          this.SettingRow('自定义提示词', '编辑AI写作指令', true)
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'prompt_edit' } });
        })

        ListItem() {
          this.SettingRow('深色模式', this.isDarkMode ? '开' : '关', false)
        }
        .onClick(() => {
          this.isDarkMode = !this.isDarkMode;
          this.onDarkModeChange(this.isDarkMode);
        })

        ListItem() {
          this.SettingRow('跟随系统深色模式', this.followSystemDark ? '开' : '关', false)
        }
        .onClick(() => {
          this.followSystemDark = !this.followSystemDark;
          settingsManager.settings.followSystemDark = this.followSystemDark;
          settingsManager.save();
          // 通知父组件更新深色模式
          if (this.followSystemDark) {
            // 获取系统配置
            const context = getContext(this) as Context;
            const config = context.config;
            if (config && config.colorMode !== undefined) {
              const systemDark = config.colorMode === Configuration.ColorMode.COLOR_MODE_DARK;
              this.isDarkMode = systemDark;
              this.onDarkModeChange(systemDark);
            }
          }
          promptAction.showToast({ message: this.followSystemDark ? '已启用跟随系统深色模式' : '已关闭跟随系统深色模式', duration: 2000 });
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

        ListItem() {
          this.SettingRow('应用评分', '⭐⭐⭐⭐⭐', false)
        }
        .onClick(() => {
          promptAction.showToast({ message: '感谢您的五星好评！', duration: 2000 });
        })

        ListItem() {
          this.SettingRow('关于', 'v1.2.0', false)
        }
        .onClick(() => {
          promptAction.showToast({ message: '创意写作 v1.2.0\nAI驱动的写作助手', duration: 3000 });
        })
      }
      .layoutWeight(1)

      // API Key输入弹层
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

      // 自定义URL输入弹层
      if (this.showCustomUrlInput) {
        Column() {
          Column() {
            Text('设置自定义接口地址')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
            Text('用于自定义AI模型API端点')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextInput({ placeholder: '请输入 API 地址', text: this.customUrlInput })
              .width('100%')
              .height(44)
              .fontSize(14)
              .backgroundColor('#F9FAFB')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.customUrlInput = value;
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
                  this.showCustomUrlInput = false;
                })
              Button('保存')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF2D55')
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.customUrl = this.customUrlInput.trim();
                  this.saveSettings();
                  this.showCustomUrlInput = false;
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
          this.showCustomUrlInput = false;
        })
      }
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
      case 'xiaoyi': return '小艺助手';
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
        { text: '小艺助手', color: '#1A1A2E' },
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
    this.customUrl = settingsManager.settings.customUrl;
  }

  saveSettings() {
    settingsManager.settings.apiKey = this.apiKey;
    settingsManager.settings.selectedModel = this.selectedModel;
    settingsManager.settings.customUrl = this.customUrl;
    settingsManager.save();
  }
}
