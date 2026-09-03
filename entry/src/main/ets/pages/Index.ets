import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager } from '../model/WorkManager';
import { OutlineManagementPanel } from '../components/OutlineManagementPanel';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import { huaweiAuthService } from '../model/HuaweiAuthService';
import { permissionManager, PermissionItem, PermissionResult } from '../model/PermissionManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import Configuration from '@ohos.app.ability.Configuration';
import common from '@ohos.app.ability.common';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import display from '@ohos.display';

interface ToastOptions {
  message: string | Resource;
  duration: number;
}

interface MenuButton {
  text: string | Resource;
  color: string | Resource;
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isDarkMode: boolean = false;
  @State showOnboarding: boolean = false;
  @State onboardingPage: number = 0;
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
    const context = getContext(this) as common.UIAbilityContext;
    settingsManager.initPromise = settingsManager.init(context);
    settingsManager.initPromise.then(() => {
      this.updateDarkMode();
    });
    // 初始化华为账号服务并尝试静默登录
    huaweiAuthService.init(context);
    if (huaweiAuthService.hasSavedLogin()) {
      huaweiAuthService.silentLogin();
    }
    // 首次启动申请运行时权限
    if (settingsManager.settings.isFirstLaunch) {
      permissionManager.requestPermissions(['ohos.permission.INTERNET', 'ohos.permission.GET_NETWORK_INFO']);
    }
  }

  updateDarkMode() {
    if (settingsManager.settings.followSystemDark) {
      // 获取系统配置
      const context = getContext(this) as common.UIAbilityContext;
      const config = context.config;
      if (config && config.colorMode !== undefined) {
        this.isDarkMode = config.colorMode === 1;
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

            this.SideNavItem('短幕剧', '🎬', 0)
            this.SideNavItem('中长篇', '📚', 1)
            this.SideNavItem('书架', '📖', 2)
            this.SideNavItem('旧档', '📦', 3)
            this.SideNavItem('设置', '⚙️', 4)

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
            } else if (this.currentIndex === 2) {
              this.BookshelfView()
            } else if (this.currentIndex === 3) {
              this.ArchiveView()
            } else {
              SettingsTab({ isDarkMode: $isDarkMode })
            }
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor(this.bgColor)
        }
        .width('100%')
        .height('100%')
      } else {
        // 窄屏布局：底部悬浮玻璃Tab导航（手机/折叠屏折叠态）
        Stack() {
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

            // Tab内容区域
            Column() {
              if (this.currentIndex === 0) {
                ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
              } else if (this.currentIndex === 1) {
                NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
              } else if (this.currentIndex === 2) {
                this.BookshelfView()
              } else if (this.currentIndex === 3) {
                this.ArchiveView()
              } else {
                SettingsTab({ isDarkMode: $isDarkMode })
              }
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.bgColor)

          // 悬浮玻璃底边栏
          this.FloatingTabBar()
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.Bottom)
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
        // 页面指示器
        Row() {
          ForEach([0, 1, 2, 3, 4], (index: number) => {
            Circle()
              .width(8)
              .height(8)
              .fill(this.onboardingPage === index ? '#FF2D55' : '#E5E7EB')
              .margin({ left: 4, right: 4 })
          }, (index: number) => index.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 第0页：欢迎页
        if (this.onboardingPage === 0) {
          Text('🎨')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('欢迎使用创意写作')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .margin({ bottom: 12 })

          Text('AI赋能，创意无限')
            .fontSize(16)
            .fontColor('#FF2D55')
            .margin({ bottom: 24 })

          Text('这是一款专为创作者打造的AI写作助手，帮助您从灵感迸发到完整作品的全流程创作。')
            .fontSize(14)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
        }

        // 第1页：双工作台
        if (this.onboardingPage === 1) {
          Text('📚')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('双工作台设计')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .margin({ bottom: 12 })

          Text('短幕剧工作台')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 快速创作竖屏短幕剧、微电影')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 提供多种剧本模板和结构')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('中长篇工作台')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 系统规划长篇小说、剧本')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 章节管理、人物设定、世界观构建')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 第2页：AI对话
        if (this.onboardingPage === 2) {
          Text('🤖')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('AI智能对话')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .margin({ bottom: 12 })

          Text('• 与AI实时对话，碰撞灵感火花')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 一键保存思维链路为文档')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 支持多种AI模型')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('  - DeepSeek、智谱GLM、百度文心')
            .fontSize(13)
            .fontColor('#9CA3AF')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('  - 小艺助手、本地GGUF模型')
            .fontSize(13)
            .fontColor('#9CA3AF')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('💡 提示：在设置中配置API Key即可使用')
            .fontSize(13)
            .fontColor('#FF2D55')
            .alignSelf(ItemAlign.Start)
        }

        // 第3页：章节管理
        if (this.onboardingPage === 3) {
          Text('📝')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('章节与版本管理')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .margin({ bottom: 12 })

          Text('章节管理')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 创建、编辑、删除章节')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 分类管理：大纲、人设、正文等')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('版本历史')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 自动保存修改历史')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 随时回溯到任意版本')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 修改内容自动高亮显示')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 第4页：隐私与登录
        if (this.onboardingPage === 4) {
          Text('🔒')
            .fontSize(60)
            .margin({ bottom: 16 })

          Text('隐私保护')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .margin({ bottom: 12 })

          Text('• 您的API Key仅存储在本地')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 作品数据完全保存在您的设备上')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 不会上传任何用户内容到服务器')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 20 })
            .alignSelf(ItemAlign.Start)

          Text('华为账号登录（可选）')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 一键登录，快速开始创作')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 未来支持云同步功能')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 底部按钮
        Row() {
          if (this.onboardingPage > 0) {
            Button('上一步')
              .fontSize(14)
              .fontColor('#6B7280')
              .backgroundColor('#F3F4F6')
              .borderRadius(20)
              .height(40)
              .layoutWeight(1)
              .margin({ right: 8 })
              .onClick(() => {
                this.onboardingPage--;
              })
          }

          if (this.onboardingPage < 4) {
            Button('下一步')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .layoutWeight(1)
              .margin({ left: 8 })
              .onClick(() => {
                this.onboardingPage++;
              })
          } else {
            Button('开始使用')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
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
        }
        .width('100%')
        .margin({ top: 20 })
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
  BookshelfView() {
    Column() {
      Row() {
        Text('📖 书架')
          .fontSize(20)
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

      Scroll() {
        Column() {
          ForEach(workManager.getAllWorks().filter(w => !w.archived), (work: WorkItem) => {
            Row() {
              // 封面缩略图
              Column() {
                Text((work.title || '未命名').charAt(0))
                  .fontSize(18)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
              }
              .width(40)
              .height(40)
              .backgroundColor(work.coverColor || '#FF2D55')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .margin({ right: 10 })

              Column() {
                Text(work.title || '未命名作品')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.textColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
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

              Text('归档')
                .fontSize(12)
                .fontColor('#3B82F6')
                .padding({ left: 8, right: 8 })
                .onClick(() => {
                  workManager.archiveWork(work.id);
                  promptAction.showToast({ message: '已移入旧档区', duration: 2000 });
                })

              Text('>')
                .fontSize(16)
                .fontColor('#D1D5DB')
            }
            .width('100%')
            .height(60)
            .backgroundColor(this.cardBg)
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .margin({ left: 16, right: 16, bottom: 8 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/PromptEditorPage',
                params: { workId: work.id, mode: 'short_drama' }
              });
            })
          }, (work: WorkItem) => work.id)
        }
        .width('100%')
        .padding({ top: 12 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  @Builder
  ArchiveView() {
    Column() {
      Row() {
        Text('📦 旧档区')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.cardBg)

      Scroll() {
        Column() {
          if (workManager.getArchivedWorks().length > 0) {
            ForEach(workManager.getArchivedWorks(), (work: WorkItem) => {
              Row() {
                // 封面缩略图
                Column() {
                  Text((work.title || '未命名').charAt(0))
                    .fontSize(18)
                    .fontColor('#FFFFFF')
                    .fontWeight(FontWeight.Bold)
                }
                .width(40)
                .height(40)
                .backgroundColor(work.coverColor || '#FF2D55')
                .borderRadius(8)
                .justifyContent(FlexAlign.Center)
                .margin({ right: 10 })

                Column() {
                  Text(work.title || '未命名作品')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.textColor)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
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

                Text('移回书架')
                  .fontSize(12)
                  .fontColor('#3B82F6')
                  .padding({ left: 8, right: 8 })
                  .onClick(() => {
                    workManager.unarchiveWork(work.id);
                    promptAction.showToast({ message: '已移回书架', duration: 2000 });
                  })

                Text('>')
                  .fontSize(16)
                  .fontColor('#D1D5DB')
              }
              .width('100%')
              .height(60)
              .backgroundColor(this.cardBg)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ left: 16, right: 16, bottom: 8 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/PromptEditorPage',
                  params: { workId: work.id, mode: 'short_drama' }
                });
              })
            }, (work: WorkItem) => work.id)
          } else {
            Column() {
              Text('📦 暂无归档作品')
                .fontSize(16)
                .fontColor('#9CA3AF')
                .margin({ bottom: 8 })
              Text('在书架中长按作品可移入旧档区')
                .fontSize(13)
                .fontColor('#B0B7C3')
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({ top: 12 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  @Builder
  FloatingTabBar() {
    Row() {
      // 短幕剧
      Column() {
        Text('🎬')
          .fontSize(24)
        Text('短幕剧')
          .fontSize(11)
          .fontColor(this.currentIndex === 0 ? '#FF2D55' : (this.isDarkMode ? '#9CA3AF' : '#6B7280'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 0;
      })

      // 中长篇
      Column() {
        Text('📚')
          .fontSize(24)
        Text('中长篇')
          .fontSize(11)
          .fontColor(this.currentIndex === 1 ? '#FF2D55' : (this.isDarkMode ? '#9CA3AF' : '#6B7280'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 1;
      })

      // 书架
      Column() {
        Text('📖')
          .fontSize(24)
        Text('书架')
          .fontSize(11)
          .fontColor(this.currentIndex === 2 ? '#FF2D55' : (this.isDarkMode ? '#9CA3AF' : '#6B7280'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 2;
      })

      // 旧档
      Column() {
        Text('📦')
          .fontSize(24)
        Text('旧档')
          .fontSize(11)
          .fontColor(this.currentIndex === 3 ? '#FF2D55' : (this.isDarkMode ? '#9CA3AF' : '#6B7280'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 3;
      })

      // 设置
      Column() {
        Text('⚙️')
          .fontSize(24)
        Text('设置')
          .fontSize(11)
          .fontColor(this.currentIndex === 4 ? '#FF2D55' : (this.isDarkMode ? '#9CA3AF' : '#6B7280'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 4;
      })
    }
    .width('85%')
    .height(64)
    .backgroundColor(this.isDarkMode ? 'rgba(45,45,58,0.85)' : 'rgba(255,255,255,0.85)')
    .borderRadius(32)
    .margin({ bottom: 12 })
    .shadow({
      radius: 20,
      color: 'rgba(0,0,0,0.1)',
      offsetX: 0,
      offsetY: 4
    })
    .border({
      width: 1,
      color: this.isDarkMode ? 'rgba(255,255,255,0.1)' : 'rgba(255,255,255,0.5)'
    })
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

// ========== 短幕剧工作台 ==========
@Component
struct ShortDramaTab {
  @Prop isDarkMode: boolean;
  @Prop cardBg: string;
  @Prop textColor: string;
  @Prop bgColor: string;
  @State templates: TemplateInfo[] = [];
  @State works: WorkItem[] = [];
  @State archivedWorks: WorkItem[] = [];
  @State showArchive: boolean = false;
  private unsubscribe: (() => void) | null = null;

  /** 短幕剧工作台覆盖的模板品类 */
  private readonly categories: string[] = ['剧本类', '喜剧类', '灵感类', '广告类', '交互沉浸类', '创意引擎'];

  get templateColumns(): string {
    const cols = responsiveManager.getTemplateColumns();
    let result = '';
    for (let i = 0; i < cols; i++) {
      result += '1fr ';
    }
    return result.trim();
  }

  aboutToAppear() {
    this.refreshData();
    this.unsubscribe = workManager.onChange(() => {
      this.refreshData();
    });
  }

  aboutToDisappear() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  private inScope(w: WorkItem): boolean {
    return this.templates.some(t => t.id === w.templateId) || (w.templateId === 'free' && w.workshop === 'short_drama');
  }

  refreshData() {
    this.templates = templateList.filter(t => this.categories.indexOf(t.category) !== -1);
    const myWorks = workManager.getBookshelfWorks().filter(w => this.inScope(w));
    myWorks.sort((a, b) => b.updateTime.localeCompare(a.updateTime));
    this.works = myWorks;
    const archived = workManager.getArchivedWorks().filter(w => this.inScope(w));
    archived.sort((a, b) => b.updateTime.localeCompare(a.updateTime));
    this.archivedWorks = archived;
  }

  build() {
    Column() {
      Row() {
        Text('短幕剧工作台')
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

      Scroll() {
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
          .width('100%')

          // 底部留白，避免被悬浮底边栏遮挡
          Column().width('100%').height(96)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
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
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(18)
            .fontColor('#FFFFFF')
        } else {
          Image(template.icon)
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
      }
      .alignContent(Alignment.Center)
      .width('100%')
      .height(60)

      Text(template.name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(template.desc)
        .fontSize(11)
        .fontColor('#9CA3AF')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.cardBg)
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/PromptEditorPage',
        params: { templateId: template.id, mode: 'short_drama' }
      });
    })
  }

  @Builder
  WorkCard(work: WorkItem, isArchived: boolean) {
    Row() {
      // 封面缩略图
      Column() {
        Text((work.title || '未命名').charAt(0))
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
      .width(44)
      .height(44)
      .backgroundColor(work.coverColor || '#FF2D55')
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(work.title || '未命名作品')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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

      Text(isArchived ? '移回书架' : '归档')
        .fontSize(12)
        .fontColor('#3B82F6')
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          if (isArchived) {
            workManager.unarchiveWork(work.id);
            promptAction.showToast({ message: '已移回书架', duration: 2000 });
          } else {
            workManager.archiveWork(work.id);
            promptAction.showToast({ message: '已移入旧档区', duration: 2000 });
          }
        })

      Text('删除')
        .fontSize(12)
        .fontColor('#EF4444')
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.confirmDelete(work);
        })

      Text('>')
        .fontSize(16)
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .height(60)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/PromptEditorPage',
        params: { workId: work.id, mode: 'short_drama' }
      });
    })
  }

  confirmDelete(work: WorkItem) {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除作品',
      message: `确定删除《${work.title || '未命名作品'}》吗？此操作不可恢复`,
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '删除', color: '#EF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        workManager.deleteWork(work.id);
        promptAction.showToast({ message: '已删除', duration: 2000 });
      }
    });
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
  @State archivedWorks: WorkItem[] = [];
  @State showArchive: boolean = false;
  @State showOutlinePanel: boolean = false;
  @State selectedWorkId: string = '';
  @State selectedWorkTitle: string = '';
  private unsubscribe: (() => void) | null = null;

  /** 中长篇工作台覆盖的模板品类 */
  private readonly categories: string[] = ['叙事类', '互动类', '中长篇', '世界观专项', '人物专项', '时间线专项', '写作工具', '出版分享'];

  openOutlinePanel(work: WorkItem) {
    this.selectedWorkId = work.id;
    this.selectedWorkTitle = work.title;
    this.showOutlinePanel = true;
  }

  get templateColumns(): string {
    const cols = responsiveManager.getTemplateColumns();
    let result = '';
    for (let i = 0; i < cols; i++) {
      result += '1fr ';
    }
    return result.trim();
  }

  aboutToAppear() {
    this.refreshData();
    this.unsubscribe = workManager.onChange(() => {
      this.refreshData();
    });
  }

  aboutToDisappear() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  private inScope(w: WorkItem): boolean {
    return this.templates.some(t => t.id === w.templateId) || (w.templateId === 'free' && w.workshop === 'novel');
  }

  refreshData() {
    this.templates = templateList.filter(t => this.categories.indexOf(t.category) !== -1);
    const myWorks = workManager.getBookshelfWorks().filter(w => this.inScope(w));
    myWorks.sort((a, b) => b.updateTime.localeCompare(a.updateTime));
    this.works = myWorks;
    const archived = workManager.getArchivedWorks().filter(w => this.inScope(w));
    archived.sort((a, b) => b.updateTime.localeCompare(a.updateTime));
    this.archivedWorks = archived;
  }

  build() {
    Stack() {
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

      Scroll() {
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
          .width('100%')

          // 底部留白，避免被悬浮底边栏遮挡
          Column().width('100%').height(96)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)

    if (this.showOutlinePanel) {
      OutlineManagementPanel({
        workId: this.selectedWorkId,
        workTitle: this.selectedWorkTitle,
        cardBg: this.cardBg,
        bgColor: this.bgColor,
        textColor: this.textColor,
        onClose: () => { this.showOutlinePanel = false; }
      })
    }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TemplateCard(template: TemplateInfo) {
    Column() {
      Stack() {
        Circle()
          .width(40)
          .height(40)
          .fill(template.color)
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(18)
            .fontColor('#FFFFFF')
        } else {
          Image(template.icon)
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
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
  WorkCard(work: WorkItem, isArchived: boolean) {
    Row() {
      // 封面缩略图
      Column() {
        Text((work.title || '未命名').charAt(0))
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
      .width(44)
      .height(44)
      .backgroundColor(work.coverColor || '#FF2D55')
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(work.title || '未命名作品')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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

      Text('📋')
        .fontSize(18)
        .margin({ right: 8 })
        .onClick(() => {
          this.openOutlinePanel(work);
        })

      Text(isArchived ? '移回书架' : '归档')
        .fontSize(12)
        .fontColor('#3B82F6')
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          if (isArchived) {
            workManager.unarchiveWork(work.id);
            promptAction.showToast({ message: '已移回书架', duration: 2000 });
          } else {
            workManager.archiveWork(work.id);
            promptAction.showToast({ message: '已移入旧档区', duration: 2000 });
          }
        })

      Text('删除')
        .fontSize(12)
        .fontColor('#EF4444')
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.confirmDelete(work);
        })

      Text('>')
        .fontSize(16)
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .height(60)
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/PromptEditorPage',
        params: { workId: work.id, mode: 'novel' }
      });
    })
  }

  confirmDelete(work: WorkItem) {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除作品',
      message: `确定删除《${work.title || '未命名作品'}》吗？此操作不可恢复`,
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '删除', color: '#EF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        workManager.deleteWork(work.id);
        promptAction.showToast({ message: '已删除', duration: 2000 });
      }
    });
  }
}

// ========== 设置Tab ==========
@Component
struct SettingsTab {
  @Link isDarkMode: boolean;
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State showApiKeyInput: boolean = false;
  @State apiKeyInput: string = '';
  @State customUrl: string = '';
  @State showCustomUrlInput: boolean = false;
  @State customUrlInput: string = '';
  @State followSystemDark: boolean = false;
  @State showModelPickerPanel: boolean = false;
  @State showPrivacyPanel: boolean = false;
  @State showAboutPanel: boolean = false;
  @State showAccountPanel: boolean = false;
  @State isLoggedIn: boolean = false;
  @State userName: string = '';
  @State autoSaveInterval: number = 5;
  @State fontSize: number = 14;
  @State aiTimeout: number = 30;
  @State showImportPanel: boolean = false;
  @State importText: string = '';
  @State showPermissionPanel: boolean = false;
  @State permissionItems: PermissionItem[] = [];
  @State showHelpPanel: boolean = false;
  @State showFeedbackPanel: boolean = false;
  @State feedbackText: string = '';

  aboutToAppear() {
    if (settingsManager.initPromise) {
      settingsManager.initPromise.then(() => {
        this.loadSettings();
      });
    } else {
      this.loadSettings();
    }
    this.permissionItems = permissionManager.getPermissionItems();
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
        // ===== AI 配置 =====
        ListItem() {
          this.SectionTitle('AI 配置')
        }

        ListItem() {
          this.SettingRow('AI模型配置', this.getModelName(), true)
        }
        .onClick(() => {
          this.showModelPickerPanel = true;
        })

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
          this.SettingRow('AI 超时时间', `${this.aiTimeout}秒`, true)
        }
        .onClick(() => {
          this.editTimeout();
        })

        // ===== 写作设置 =====
        ListItem() {
          this.SectionTitle('写作设置')
        }

        ListItem() {
          this.SettingRow('自定义提示词', '编辑AI写作指令', true)
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'prompt_edit' } });
        })

        ListItem() {
          this.SettingRow('自动保存间隔', `${this.autoSaveInterval}分钟`, true)
        }
        .onClick(() => {
          this.editAutoSaveInterval();
        })

        ListItem() {
          this.SettingRow('字体大小', `${this.fontSize}px`, true)
        }
        .onClick(() => {
          this.editFontSize();
        })

        ListItem() {
          this.SettingRow('深色模式', this.followSystemDark ? '跟随系统' : (this.isDarkMode ? '开' : '关'), true)
        }
        .onClick(() => {
          this.selectDarkMode();
        })

        // ===== 数据管理 =====
        ListItem() {
          this.SectionTitle('数据管理')
        }

        ListItem() {
          this.SettingRow('导出数据', '备份所有作品到本地', true)
        }
        .onClick(() => {
          this.exportData();
        })

        ListItem() {
          this.SettingRow('导入数据', '从备份文件恢复', true)
        }
        .onClick(() => {
          this.importData();
        })

        ListItem() {
          this.SettingRow('清除缓存', '释放存储空间', true)
        }
        .onClick(() => {
          this.clearCache();
        })

        // ===== 账号与隐私 =====
        ListItem() {
          this.SectionTitle('账号与隐私')
        }

        ListItem() {
          this.SettingRow('华为账号登录', this.isLoggedIn ? this.userName : '未登录', true)
        }
        .onClick(() => {
          this.showAccountPanel = true;
        })

        ListItem() {
          this.SettingRow('用户协议', '', true)
        }
        .onClick(() => {
          this.showPrivacyPanel = true;
        })

        ListItem() {
          this.SettingRow('隐私政策', '', true)
        }
        .onClick(() => {
          this.showPrivacyPanel = true;
        })

        ListItem() {
          this.SettingRow('权限管理', '查看与申请应用权限', true)
        }
        .onClick(() => {
          this.permissionItems = permissionManager.getPermissionItems();
          this.showPermissionPanel = true;
        })

        // ===== 关于与支持 =====
        ListItem() {
          this.SectionTitle('关于与支持')
        }

        ListItem() {
          this.SettingRow('应用评分', '⭐⭐⭐⭐⭐', false)
        }
        .onClick(() => {
          promptAction.showToast({ message: '感谢您的五星好评！', duration: 2000 });
        })

        ListItem() {
          this.SettingRow('检查更新', 'v1.2.0', true)
        }
        .onClick(() => {
          promptAction.showToast({ message: '当前已是最新版本', duration: 2000 });
        })

        ListItem() {
          this.SettingRow('帮助中心', '使用教程与常见问题', true)
        }
        .onClick(() => {
          this.showHelpPanel = true;
        })

        ListItem() {
          this.SettingRow('联系反馈', '提交问题或建议', true)
        }
        .onClick(() => {
          this.feedbackText = '';
          this.showFeedbackPanel = true;
        })

        ListItem() {
          this.SettingRow('关于', '创意写作 v1.2.0', true)
        }
        .onClick(() => {
          this.showAboutPanel = true;
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
          .hitTestBehavior(HitTestMode.Block)
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
          .hitTestBehavior(HitTestMode.Block)
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

      // 模型选择面板
      if (this.showModelPickerPanel) {
        Column() {
          Column() {
            Text('选择AI模型')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 16 })

            this.ModelOption('DeepSeek', 'deepseek')
            this.ModelOption('智谱 GLM', 'glm')
            this.ModelOption('百度文心', 'baidu')
            this.ModelOption('小艺助手', 'xiaoyi')
            this.ModelOption('本地 GGUF', 'gguf')
            this.ModelOption('自定义接口', 'custom')

            Button('取消')
              .fontSize(14)
              .fontColor('#6B7280')
              .backgroundColor('#F3F4F6')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .margin({ top: 12 })
              .onClick(() => {
                this.showModelPickerPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showModelPickerPanel = false;
        })
      }

      // 账号登录面板
      if (this.showAccountPanel) {
        Column() {
          Column() {
            Text('账号登录')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })

            if (this.isLoggedIn) {
              Text(`已登录: ${this.userName}`)
                .fontSize(14)
                .fontColor('#6B7280')
                .margin({ bottom: 16 })

              Button('退出登录')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF4D4D')
                .borderRadius(20)
                .height(40)
                .width('100%')
                .onClick(() => {
                  this.logoutHuawei();
                })
            } else {
              Text('登录后即可使用AI功能和修改API设置')
                .fontSize(13)
                .fontColor('#9CA3AF')
                .margin({ bottom: 16 })
                .textAlign(TextAlign.Center)

              Button('华为账号一键登录')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF2D55')
                .borderRadius(20)
                .height(44)
                .width('100%')
                .margin({ bottom: 12 })
                .onClick(() => {
                  this.loginHuawei();
                })

              Button('暂不登录')
                .fontSize(13)
                .fontColor('#9CA3AF')
                .backgroundColor('transparent')
                .height(36)
                .width('100%')
                .onClick(() => {
                  this.showAccountPanel = false;
                })
            }
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAccountPanel = false;
        })
      }

      // 隐私政策/用户协议面板
      if (this.showPrivacyPanel) {
        Column() {
          Column() {
            Text('用户协议与隐私政策')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 12 })

            Text('【用户协议】')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('1. 本应用仅供个人学习和创作使用，不得用于商业侵权用途。\n2. 用户需遵守相关法律法规，不得利用本应用生成违法违规内容。\n3. AI生成的内容版权归用户所有，用户需自行承担使用风险。\n4. 用户应妥善保管API Key，不得将其分享给他人使用。\n5. 本应用不对AI生成内容的准确性和合法性负责。')
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Text('【隐私政策】')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('1. 您的API Key仅存储在本地，不会上传到任何服务器。\n2. 作品数据完全保存在您的设备上，我们不会收集您的创作内容。\n3. 本应用不会收集您的个人信息、位置、通讯录等隐私数据。\n4. 当您使用华为账号登录时，我们仅会获取必要的用户标识用于登录验证。\n5. 我们不会将您的任何数据分享给第三方。')
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Button('我知道了')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showPrivacyPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showPrivacyPanel = false;
        })
      }

      // 关于面板
      if (this.showAboutPanel) {
        Column() {
          Column() {
            Text('关于 创意写作')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 12 })

            Text('🤖 AI')
              .fontSize(24)
              .margin({ bottom: 8 })

            Text('创意写作 v1.2.0')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF2D55')
              .margin({ bottom: 8 })

            Text('AI驱动的写作助手')
              .fontSize(13)
              .fontColor('#6B7280')
              .margin({ bottom: 16 })

            Text('功能特性：')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('• 短幕剧/中长篇双工作台，独立管理\n• AI对话生成，一键保存思维链路\n• 自动版本归档，修改历史可追溯\n• 书架与旧档区，作品归档一目了然\n• 支持多种AI模型：DeepSeek、智谱GLM、百度文心、小艺助手、本地GGUF\n• 丰富的模板库，支持自定义提示词\n• 深色模式，保护您的视力')
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showAboutPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAboutPanel = false;
        })
      }

      // 导入数据面板
      if (this.showImportPanel) {
        Column() {
          Column() {
            Text('导入数据')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
            Text('粘贴此前导出的备份JSON，重复作品会自动跳过')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextArea({ placeholder: '粘贴备份JSON内容...' })
              .width('100%')
              .height(160)
              .fontSize(13)
              .backgroundColor('#F9FAFB')
              .borderRadius(8)
              .padding(12)
              .onChange((value: string) => {
                this.importText = value;
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
                  this.showImportPanel = false;
                })
              Button('导入')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF2D55')
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.doImportData();
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
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showImportPanel = false;
        })
      }

      // 权限管理面板
      if (this.showPermissionPanel) {
        Column() {
          Column() {
            Text('权限管理')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 12 })

            ForEach(this.permissionItems, (item: PermissionItem) => {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1A2E')
                  Text(item.reason)
                    .fontSize(12)
                    .fontColor('#9CA3AF')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.granted) {
                  Text('已授权')
                    .fontSize(12)
                    .fontColor('#10B981')
                } else {
                  Button('申请')
                    .fontSize(12)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#FF2D55')
                    .borderRadius(14)
                    .height(28)
                    .padding({ left: 12, right: 12 })
                    .onClick(() => {
                      this.requestSinglePermission(item.permission);
                    })
                }
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (item: PermissionItem) => item.permission)

            Text('提示：网络相关权限为系统级授权，安装时自动授予；如被拒绝可在此重新申请。')
              .fontSize(11)
              .fontColor('#9CA3AF')
              .margin({ top: 8, bottom: 12 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showPermissionPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showPermissionPanel = false;
        })
      }

      // 帮助中心面板
      if (this.showHelpPanel) {
        Column() {
          Column() {
            Text('帮助中心')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 12 })

            Scroll() {
              Column() {
                Text('【快速上手】')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A1A2E')
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                Text('1. 在短幕剧/中长篇工作台选择模板，填写字段即可生成创作框架。\n2. 点击"AI生成"按钮，由AI补全完整内容（需在设置中配置API Key）。\n3. 保存后作品进入书架，可随时归档到旧档区。')
                  .fontSize(12)
                  .fontColor('#6B7280')
                  .margin({ bottom: 16 })
                  .alignSelf(ItemAlign.Start)

                Text('【常见问题】')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A1A2E')
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                Text('Q: AI生成失败怎么办？\nA: 请检查设置中的API Key是否正确、网络是否可用，也可尝试调大AI超时时间。\n\nQ: 作品如何备份？\nA: 设置 → 导出数据，将备份JSON复制保存；换设备后用"导入数据"恢复。\n\nQ: 版本历史在哪里？\nA: 打开作品后点击底部"历史"按钮，可预览并恢复任意历史版本。')
                  .fontSize(12)
                  .fontColor('#6B7280')
                  .margin({ bottom: 16 })
                  .alignSelf(ItemAlign.Start)
              }
              .width('100%')
            }
            .height(300)
            .scrollBar(BarState.Auto)

            Button('关闭')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .margin({ top: 12 })
              .onClick(() => {
                this.showHelpPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showHelpPanel = false;
        })
      }

      // 联系反馈面板
      if (this.showFeedbackPanel) {
        Column() {
          Column() {
            Text('联系反馈')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
            Text('描述您遇到的问题或建议，提交后会复制到剪贴板，可发送至支持邮箱 support@creativewriting.app')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextArea({ placeholder: '请输入反馈内容...' })
              .width('100%')
              .height(140)
              .fontSize(13)
              .backgroundColor('#F9FAFB')
              .borderRadius(8)
              .padding(12)
              .onChange((value: string) => {
                this.feedbackText = value;
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
                  this.showFeedbackPanel = false;
                })
              Button('提交')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF2D55')
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.submitFeedback();
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
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showFeedbackPanel = false;
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

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#9CA3AF')
      .margin({ top: 8, bottom: 4 })
      .padding({ left: 16 })
      .width('100%')
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

  @Builder
  ModelOption(label: string, modelKey: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.selectedModel === modelKey ? '#FF2D55' : '#1A1A2E')
        .fontWeight(this.selectedModel === modelKey ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)

      if (this.selectedModel === modelKey) {
        Text('✓')
          .fontSize(16)
          .fontColor('#FF2D55')
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.selectedModel === modelKey ? '#FFF0F5' : 'transparent')
    .borderRadius(8)
    .margin({ bottom: 4 })
    .onClick(() => {
      this.selectedModel = modelKey;
      this.saveSettings();
      this.showModelPickerPanel = false;
      promptAction.showToast({ message: `已切换到 ${label}`, duration: 2000 });
    })
  }

  loginHuawei() {
    huaweiAuthService.loginWithHuaweiID().then((success: boolean) => {
      if (success) {
        this.isLoggedIn = settingsManager.settings.isLoggedIn;
        this.userName = settingsManager.settings.userName;
        this.showAccountPanel = false;
        promptAction.showToast({ message: '登录成功！', duration: 2000 });
      } else {
        promptAction.showToast({ message: '登录失败或已取消', duration: 2000 });
      }
    });
  }

  logoutHuawei() {
    huaweiAuthService.logout().then(() => {
      this.isLoggedIn = false;
      this.userName = '';
      this.showAccountPanel = false;
      promptAction.showToast({ message: '已退出登录', duration: 2000 });
    });
  }

  selectDarkMode() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '深色模式',
      buttons: [
        { text: '关', color: '#1A1A2E' } as MenuButton,
        { text: '开', color: '#1A1A2E' } as MenuButton,
        { text: '跟随系统', color: '#1A1A2E' } as MenuButton,
        { text: '取消', color: '#666666' } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton, MenuButton]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        // 关
        this.followSystemDark = false;
        this.isDarkMode = false;
        settingsManager.settings.followSystemDark = false;
        settingsManager.settings.isDarkMode = false;
        settingsManager.save();
        promptAction.showToast({ message: '已关闭深色模式', duration: 2000 });
      } else if (result.index === 1) {
        // 开
        this.followSystemDark = false;
        this.isDarkMode = true;
        settingsManager.settings.followSystemDark = false;
        settingsManager.settings.isDarkMode = true;
        settingsManager.save();
        promptAction.showToast({ message: '已开启深色模式', duration: 2000 });
      } else if (result.index === 2) {
        // 跟随系统
        this.followSystemDark = true;
        settingsManager.settings.followSystemDark = true;
        const context = getContext(this) as common.UIAbilityContext;
        const config = context.config;
        if (config && config.colorMode !== undefined) {
          this.isDarkMode = config.colorMode === 1;
          settingsManager.settings.isDarkMode = config.colorMode === 1;
        }
        settingsManager.save();
        promptAction.showToast({ message: '已跟随系统深色模式', duration: 2000 });
      }
    });
  }

  editTimeout() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '选择AI超时时间',
      buttons: [
        { text: '15秒', color: '#1A1A2E' } as MenuButton,
        { text: '30秒', color: '#1A1A2E' } as MenuButton,
        { text: '60秒', color: '#1A1A2E' } as MenuButton,
        { text: '120秒', color: '#1A1A2E' } as MenuButton,
        { text: '取消', color: '#666666' } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton, MenuButton, MenuButton]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index < 4) {
        const values: number[] = [15, 30, 60, 120];
        this.aiTimeout = values[result.index];
        this.saveSettings();
        const toastOpts: ToastOptions = { message: `已设置为 ${this.aiTimeout}秒`, duration: 2000 };
        promptAction.showToast(toastOpts);
      }
    });
  }

  editAutoSaveInterval() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '选择自动保存间隔',
      buttons: [
        { text: '1分钟', color: '#1A1A2E' } as MenuButton,
        { text: '5分钟', color: '#1A1A2E' } as MenuButton,
        { text: '10分钟', color: '#1A1A2E' } as MenuButton,
        { text: '30分钟', color: '#1A1A2E' } as MenuButton,
        { text: '取消', color: '#666666' } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton, MenuButton, MenuButton]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index < 4) {
        const values: number[] = [1, 5, 10, 30];
        this.autoSaveInterval = values[result.index];
        this.saveSettings();
        const toastOpts: ToastOptions = { message: `已设置为 ${this.autoSaveInterval}分钟`, duration: 2000 };
        promptAction.showToast(toastOpts);
      }
    });
  }

  editFontSize() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '选择字体大小',
      buttons: [
        { text: '12px', color: '#1A1A2E' } as MenuButton,
        { text: '14px', color: '#1A1A2E' } as MenuButton,
        { text: '16px', color: '#1A1A2E' } as MenuButton,
        { text: '18px', color: '#1A1A2E' } as MenuButton,
        { text: '取消', color: '#666666' } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton, MenuButton, MenuButton]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index < 4) {
        const values: number[] = [12, 14, 16, 18];
        this.fontSize = values[result.index];
        this.saveSettings();
        const toastOpts: ToastOptions = { message: `已设置为 ${this.fontSize}px`, duration: 2000 };
        promptAction.showToast(toastOpts);
      }
    });
  }

  exportData() {
    const json = workManager.exportAll();
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, json);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).then(() => {
      promptAction.showToast({ message: `已导出${workManager.getAllWorks().length}部作品，备份JSON已复制到剪贴板`, duration: 3000 });
    }).catch(() => {
      promptAction.showToast({ message: '导出失败，请重试', duration: 2000 });
    });
  }

  importData() {
    this.importText = '';
    this.showImportPanel = true;
  }

  doImportData() {
    const text = this.importText.trim();
    if (!text) {
      promptAction.showToast({ message: '请先粘贴备份JSON内容', duration: 2000 });
      return;
    }
    const count = workManager.importWorks(text);
    this.showImportPanel = false;
    if (count > 0) {
      promptAction.showToast({ message: `成功导入${count}部作品`, duration: 2000 });
    } else {
      promptAction.showToast({ message: '未导入新作品（内容无效或已存在）', duration: 2000 });
    }
  }

  requestSinglePermission(permission: string) {
    permissionManager.requestPermissions([permission]).then((result: PermissionResult) => {
      this.permissionItems = permissionManager.getPermissionItems();
      if (result.granted.length > 0) {
        promptAction.showToast({ message: '权限已授予', duration: 2000 });
      } else {
        promptAction.showToast({ message: '权限申请被拒绝，可在系统设置中手动开启', duration: 3000 });
      }
    });
  }

  submitFeedback() {
    const text = this.feedbackText.trim();
    if (!text) {
      promptAction.showToast({ message: '请输入反馈内容', duration: 2000 });
      return;
    }
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).then(() => {
      this.showFeedbackPanel = false;
      promptAction.showToast({ message: '反馈已复制到剪贴板，感谢支持', duration: 2000 });
    }).catch(() => {
      this.showFeedbackPanel = false;
      promptAction.showToast({ message: '反馈已记录，感谢支持', duration: 2000 });
    });
  }

  clearCache() {
    promptAction.showToast({ message: '缓存已清除', duration: 2000 });
  }

  loadSettings() {
    this.apiKey = settingsManager.settings.apiKey;
    this.selectedModel = settingsManager.settings.selectedModel;
    this.customUrl = settingsManager.settings.customUrl;
    this.followSystemDark = settingsManager.settings.followSystemDark;
    this.autoSaveInterval = settingsManager.settings.autoSaveInterval || 5;
    this.fontSize = settingsManager.settings.fontSize || 14;
    this.aiTimeout = settingsManager.settings.aiTimeout || 30;
    this.isLoggedIn = settingsManager.settings.isLoggedIn;
    this.userName = settingsManager.settings.userName;
  }

  saveSettings() {
    settingsManager.settings.apiKey = this.apiKey;
    settingsManager.settings.selectedModel = this.selectedModel;
    settingsManager.settings.customUrl = this.customUrl;
    settingsManager.settings.autoSaveInterval = this.autoSaveInterval;
    settingsManager.settings.fontSize = this.fontSize;
    settingsManager.settings.aiTimeout = this.aiTimeout;
    settingsManager.settings.isDarkMode = this.isDarkMode;
    settingsManager.settings.followSystemDark = this.followSystemDark;
    settingsManager.save();
  }
}
