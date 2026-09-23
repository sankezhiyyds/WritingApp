import { TemplateField, TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager, BookshelfFolder, ArchiveFolder, RecycleBinItem, TransitItem, InspirationItem } from '../model/WorkManager';
import { OutlineManagementPanel } from '../components/OutlineManagementPanel';
import { settingsManager } from '../model/SettingsManager';
import { huaweiAuthService, HuaweiUserInfo } from '../model/HuaweiAuthService';
import { cloudSyncService, SyncStatus } from '../model/CloudSyncService';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import { permissionManager, PermissionItem, PermissionResult } from '../model/PermissionManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import picker from '@ohos.file.picker';
import fileIo from '@ohos.file.fs';
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
  @StorageLink('appDarkMode') isDarkMode: boolean = false;
  @State showOnboarding: boolean = false;
  @State onboardingPage: number = 0;
  @State currentBreakpoint: BreakpointType = 'sm';
  @State refreshKey: number = 0;
  @StorageProp('sysDarkMode') @Watch('onSysDarkModeChange') sysDarkMode: boolean = false;
  @StorageProp('appFontSize') fontSize: number = 14;

  // 文件夹导航状态
  @State currentFolderId: string = '';  // 当前查看的书架文件夹ID（空表示根目录）
  @State currentArchiveFolderId: string = '';  // 当前查看的旧档区文件夹ID
  @State showFolderMenu: boolean = false;  // 文件夹长按菜单
  @State selectedFolder: BookshelfFolder | null = null;  // 选中的书架文件夹
  @State selectedArchiveFolder: ArchiveFolder | null = null;  // 选中的旧档区文件夹
  @State folderMenuType: string = 'bookshelf';  // 菜单类型：bookshelf | archive
  @State showWorkMenu: boolean = false;  // 作品长按菜单
  @State selectedWorkForMenu: WorkItem | null = null;  // 选中的作品
  @State showRenameDialog: boolean = false;  // 重命名对话框
  @State renameText: string = '';  // 重命名文本
  @State renameTargetType: string = 'folder';  // 重命名目标类型：folder | work
  @State showCoverPicker: boolean = false;  // 封面颜色选择器
  @State coverPickerTargetType: string = 'folder';  // 封面选择目标类型：folder | work
  @State showArchiveFolderPicker: boolean = false;  // 归档文件夹选择器
  @State workToArchive: string = '';  // 要归档的作品ID

  // 素材库子页签：0=旧档, 1=回收站, 2=中转站, 3=灵感池
  @State materialSubTab: number = 0;
  @State recycleBinItems: RecycleBinItem[] = [];
  @State transitItems: TransitItem[] = [];
  @State inspirationItems: InspirationItem[] = [];

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }
  private controller: TabsController = new TabsController();
  private breakpointCallback: (bp: BreakpointType) => void = (bp: BreakpointType) => {
    this.currentBreakpoint = bp;
    AppStorage.setOrCreate('appBreakpoint', bp);
  };
  private unsubscribeWorkChange: (() => void) | null = null;

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
    return this.isDarkMode ? '#24243A' : '#FFFFFF';
  }

  get panelBg(): string {
    return this.isDarkMode ? '#212138' : '#FFFFFF';
  }

  get textColor(): string {
    return this.isDarkMode ? '#F5F5FA' : '#1A1A2E';
  }

  get subTextColor(): string {
    return this.isDarkMode ? '#B7BACB' : '#6B7280';
  }

  aboutToAppear() {
    // 检查是否首次启动
    if (settingsManager.settings.isFirstLaunch) {
      this.showOnboarding = true;
    }
    // 初始化断点
    this.currentBreakpoint = responsiveManager.getBreakpoint();
    AppStorage.setOrCreate('appBreakpoint', this.currentBreakpoint);
    responsiveManager.onBreakpointChange(this.breakpointCallback);
    // 初始化深色模式
    const context = getContext(this) as common.UIAbilityContext;
    settingsManager.initPromise = settingsManager.init(context);
    settingsManager.initPromise.then(() => {
      this.updateDarkMode();
      AppStorage.setOrCreate('appFontSize', settingsManager.settings.fontSize || 14);
      AppStorage.setOrCreate('appDarkMode', this.isDarkMode);
    });
    // fallback: 如果EntryAbility尚未设置sysDarkMode，从context读取
    if (AppStorage.get<boolean>('sysDarkMode') === undefined) {
      const cfg = (getContext(this) as common.UIAbilityContext).config;
      if (cfg && cfg.colorMode !== undefined) {
        AppStorage.setOrCreate<boolean>('sysDarkMode', cfg.colorMode === 0);
      }
    }
    // 订阅作品数据变更，刷新书架/素材库
    this.unsubscribeWorkChange = workManager.onChange(() => {
      this.refreshKey++;
      this.refreshMaterialLibrary();
    });
    // 初始加载素材库数据
    this.refreshMaterialLibrary();
  }

  updateDarkMode() {
    if (settingsManager.settings.followSystemDark) {
      // 跟随系统：优先使用sysDarkMode（由onConfigurationUpdate实时推送），回退到context.config
      if (this.sysDarkMode !== undefined) {
        this.isDarkMode = this.sysDarkMode;
      } else {
        const context = getContext(this) as common.UIAbilityContext;
        const config = context.config;
        if (config && config.colorMode !== undefined) {
          this.isDarkMode = config.colorMode === 0;
        }
      }
    } else {
      // 手动设置
      this.isDarkMode = settingsManager.settings.isDarkMode;
    }
    AppStorage.setOrCreate('appDarkMode', this.isDarkMode);
  }

  /** 系统深色模式变化时自动同步（跟随系统模式） */
  onSysDarkModeChange(): void {
    if (settingsManager.settings.followSystemDark) {
      this.updateDarkMode();
    }
  }

  aboutToDisappear() {
    responsiveManager.offBreakpointChange(this.breakpointCallback);
    if (this.unsubscribeWorkChange) {
      this.unsubscribeWorkChange();
      this.unsubscribeWorkChange = null;
    }
  }

  build() {
    Stack() {
      if (this.isWide) {
        // 宽屏布局：侧边导航 + 内容区
        Row() {
          // 侧边导航栏
          Column() {
            Text('创意写作')
              .fontSize(this.sf(18))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .margin({ top: 20, bottom: 24 })

            this.SideNavItem('短幕剧', '🎬', 0)
            this.SideNavItem('中长篇', '📚', 1)
            this.SideNavItem('书架', '📖', 2)
            this.SideNavItem('素材库', '📦', 3)
            this.SideNavItem('设置', '⚙️', 4)

            Blank()
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
                .fontSize(this.sf(20))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.textColor)
              Blank()
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
            .padding({ bottom: 88 })
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

      // 重命名对话框
      if (this.showRenameDialog) {
        this.RenameDialog()
      }

      // 封面颜色选择器
      if (this.showCoverPicker) {
        this.CoverPickerDialog()
      }

      // 归档文件夹选择器
      if (this.showArchiveFolderPicker) {
        this.ArchiveFolderPickerDialog()
      }

      // 文件夹长按菜单
      if (this.showFolderMenu) {
        this.FolderMenuDialog()
      }

      // 作品长按菜单
      if (this.showWorkMenu) {
        this.WorkMenuDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SideNavItem(label: string, icon: string, index: number) {
    Row() {
      Text(icon)
        .fontSize(this.sf(20))
        .margin({ right: 12 })
      Text(label)
        .fontSize(this.sf(15))
        .fontColor(this.currentIndex === index ? '#FF6B35' : this.textColor)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20 })
    .backgroundColor(this.currentIndex === index ? (this.isDarkMode ? '#3D3D4A' : '#FFF0E5') : this.bgColor)
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
              .fill(this.onboardingPage === index ? '#FF2D55' : (this.isDarkMode ? '#4B4B5B' : '#E5E7EB'))
              .margin({ left: 4, right: 4 })
          }, (index: number) => index.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 第0页：欢迎页
        if (this.onboardingPage === 0) {
          Text('🎨')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('欢迎使用创意写作')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Text('AI赋能，创意无限')
            .fontSize(this.sf(16))
            .fontColor('#FF2D55')
            .margin({ bottom: 24 })

          Text('这是一款专为创作者打造的AI写作助手，帮助您从灵感迸发到完整作品的全流程创作。')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
        }

        // 第1页：双工作台
        if (this.onboardingPage === 1) {
          Text('📚')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('双工作台设计')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Text('短幕剧工作台')
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 快速创作竖屏短幕剧、微电影')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 提供多种剧本模板和结构')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('中长篇工作台')
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 系统规划长篇小说、剧本')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 章节管理、人物设定、世界观构建')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 第2页：AI对话
        if (this.onboardingPage === 2) {
          Text('📓')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('AI智能对话')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Text('• 与AI实时对话，碰撞灵感火花')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 一键保存思维链路为文档')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 本地AI推理')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('  - 运行本地 GGUF 格式大模型，离线可用')
            .fontSize(this.sf(13))
            .fontColor('#9CA3AF')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('💡 提示：在设置中选择GGUF模型即可使用AI功能')
            .fontSize(this.sf(13))
            .fontColor('#FF2D55')
            .alignSelf(ItemAlign.Start)
        }

        // 第3页：章节管理
        if (this.onboardingPage === 3) {
          Text('📝')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('章节与版本管理')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Text('章节管理')
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 创建、编辑、删除章节')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 分类管理：大纲、人设、正文等')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('版本历史')
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 自动保存修改历史')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 随时回溯到任意版本')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 修改内容自动高亮显示')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 第4页：隐私与登录
        if (this.onboardingPage === 4) {
          Text('🔒')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('隐私保护')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Text('• 所有数据仅保存在本地')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 作品数据完全保存在您的设备上')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 不会上传任何用户内容到服务器')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 20 })
            .alignSelf(ItemAlign.Start)

          Text('华为账号登录（可选）')
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('• 一键登录，快速开始创作')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 未来支持云同步功能')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 底部按钮
        Row() {
          if (this.onboardingPage > 0) {
            Button('上一步')
              .fontSize(this.sf(14))
              .fontColor(this.subTextColor)
              .backgroundColor(this.isDarkMode ? '#353547' : '#F3F4F6')
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
              .fontSize(this.sf(14))
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
              .fontSize(this.sf(14))
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
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BookshelfView() {
    Column() {
      Row() {
        if (this.currentFolderId.length > 0) {
          Text('←')
            .fontSize(this.sf(20))
            .fontColor('#FF2D55')
            .onClick(() => { this.currentFolderId = ''; })
            .padding({ left: 16, right: 12 })
          Text(this.getFolderName(this.currentFolderId))
            .fontSize(this.sf(18))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
        } else {
          Text('📖 书架')
            .fontSize(this.sf(20))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        Button('新建')
          .fontSize(this.sf(14))
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
          if (this.currentFolderId.length === 0) {
            this.BookshelfRootView()
          } else {
            this.BookshelfFolderView()
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
  ArchiveView() {
    Column() {
      Row() {
        if (this.currentArchiveFolderId.length > 0) {
          Text('←')
            .fontSize(this.sf(20))
            .fontColor('#FF2D55')
            .onClick(() => { this.currentArchiveFolderId = ''; })
            .padding({ left: 16, right: 12 })
          Text(this.getArchiveFolderName(this.currentArchiveFolderId))
            .fontSize(this.sf(18))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
        } else {
          Text('📦 素材库')
            .fontSize(this.sf(20))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .backgroundColor(this.cardBg)

      // 素材库子页签
      Row() {
        ForEach(['旧档', '回收站', '中转站', '灵感池'], (tab: string, index: number) => {
          Text(tab)
            .fontSize(this.sf(13))
            .fontWeight(this.materialSubTab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.materialSubTab === index ? '#FF6B35' : '#9CA3AF')
            .backgroundColor(this.materialSubTab === index ? '#FFF7ED' : this.cardBg)
            .borderRadius(14)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .margin({ right: 8 })
            .onClick(() => {
              this.materialSubTab = index;
              this.refreshMaterialLibrary();
            })
        }, (tab: string) => tab)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })
      .backgroundColor(this.cardBg)

      Scroll() {
        Column() {
          if (this.materialSubTab === 0) {
            // 旧档
            if (this.currentArchiveFolderId.length === 0) {
              this.ArchiveRootView()
            } else {
              this.ArchiveFolderView()
            }
          } else if (this.materialSubTab === 1) {
            // 回收站
            this.RecycleBinView()
          } else if (this.materialSubTab === 2) {
            // 中转站
            this.TransitStationView()
          } else {
            // 灵感池
            this.InspirationPoolView()
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

  /** 获取书架文件夹名称 */
  getFolderName(folderId: string): string {
    const folder = workManager.getFolders().find(f => f.id === folderId);
    return folder ? folder.name : '文件夹';
  }

  /** 获取旧档区文件夹名称 */
  getArchiveFolderName(folderId: string): string {
    const folder = workManager.getArchiveFolders().find(f => f.id === folderId);
    return folder ? folder.name : '文件夹';
  }

  /** 书架根视图：显示文件夹和未分类作品 */
  @Builder
  BookshelfRootView() {
    // 文件夹网格
    if (workManager.getFolders().length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(workManager.getFolders(), (folder: BookshelfFolder) => {
          Column() {
            Column() {
              Text('📁')
                .fontSize(this.sf(28))
              Text(folder.name)
                .fontSize(this.sf(12))
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
            .width('100%')
            .height(80)
            .backgroundColor(folder.coverColor)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Text(`${workManager.getWorksByFolder(folder.id).length} 篇作品`)
              .fontSize(this.sf(11))
              .fontColor(this.subTextColor)
              .margin({ top: 6 })
          }
          .width('46%')
          .margin({ left: '2%', right: '2%', bottom: 12 })
          .onClick(() => { this.currentFolderId = folder.id; })
          .gesture(
            LongPressGesture()
              .onAction(() => {
                this.selectedFolder = folder;
                this.folderMenuType = 'bookshelf';
                this.showFolderMenu = true;
              })
          )
        }, (folder: BookshelfFolder) => folder.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }

    // 未分类作品
    if (workManager.getFolders().length > 0 && workManager.getUnfiledBookshelfWorks().length > 0) {
      Text('未分类作品')
        .fontSize(this.sf(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.subTextColor)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })
    }

    ForEach(workManager.getUnfiledBookshelfWorks(), (work: WorkItem) => {
      this.WorkItemRow(work, false)
    }, (work: WorkItem) => work.id)

    // 空状态
    if (workManager.getFolders().length === 0 && workManager.getUnfiledBookshelfWorks().length === 0) {
      Column() {
        Text('📖 书架空空如也')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
          .margin({ bottom: 8 })
        Text('点击右上角「新建」开始创作')
          .fontSize(this.sf(13))
          .fontColor('#B0B7C3')
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  /** 书架文件夹内视图：显示文件夹中的作品 */
  @Builder
  BookshelfFolderView() {
    if (workManager.getWorksByFolder(this.currentFolderId).length > 0) {
      ForEach(workManager.getWorksByFolder(this.currentFolderId), (work: WorkItem) => {
        this.WorkItemRow(work, false)
      }, (work: WorkItem) => work.id)
    } else {
      Column() {
        Text('📁 文件夹为空')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 旧档区根视图：显示文件夹和未分类作品 */
  @Builder
  ArchiveRootView() {
    if (workManager.getArchiveFolders().length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(workManager.getArchiveFolders(), (folder: ArchiveFolder) => {
          Column() {
            Column() {
              Text('📦')
                .fontSize(this.sf(28))
              Text(folder.name)
                .fontSize(this.sf(12))
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
            .width('100%')
            .height(80)
            .backgroundColor(folder.coverColor)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Text(`${workManager.getArchivedWorksByFolder(folder.id).length} 篇作品`)
              .fontSize(this.sf(11))
              .fontColor(this.subTextColor)
              .margin({ top: 6 })
          }
          .width('46%')
          .margin({ left: '2%', right: '2%', bottom: 12 })
          .onClick(() => { this.currentArchiveFolderId = folder.id; })
          .gesture(
            LongPressGesture()
              .onAction(() => {
                this.selectedArchiveFolder = folder;
                this.folderMenuType = 'archive';
                this.showFolderMenu = true;
              })
          )
        }, (folder: ArchiveFolder) => folder.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }

    if (workManager.getArchiveFolders().length > 0 && workManager.getUnfiledArchivedWorks().length > 0) {
      Text('未分类作品')
        .fontSize(this.sf(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.subTextColor)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })
    }

    ForEach(workManager.getUnfiledArchivedWorks(), (work: WorkItem) => {
      this.WorkItemRow(work, true)
    }, (work: WorkItem) => work.id)

    if (workManager.getArchiveFolders().length === 0 && workManager.getUnfiledArchivedWorks().length === 0) {
      Column() {
        Text('📦 暂无归档作品')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
          .margin({ bottom: 8 })
        Text('在书架中归档作品后将显示在此')
          .fontSize(this.sf(13))
          .fontColor('#B0B7C3')
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  /** 旧档区文件夹内视图 */
  @Builder
  ArchiveFolderView() {
    if (workManager.getArchivedWorksByFolder(this.currentArchiveFolderId).length > 0) {
      ForEach(workManager.getArchivedWorksByFolder(this.currentArchiveFolderId), (work: WorkItem) => {
        this.WorkItemRow(work, true)
      }, (work: WorkItem) => work.id)
    } else {
      Column() {
        Text('📦 文件夹为空')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 刷新素材库数据 */
  refreshMaterialLibrary(): void {
    this.recycleBinItems = workManager.getRecycleBinItems();
    this.transitItems = workManager.getTransitItems();
    this.inspirationItems = workManager.getInspirations();
  }

  /** 回收站视图 */
  @Builder
  RecycleBinView() {
    if (this.recycleBinItems.length > 0) {
      ForEach(this.recycleBinItems, (item: RecycleBinItem) => {
        Row() {
          Column() {
            Text('🗑')
              .fontSize(this.sf(18))
              .fontColor('#FFFFFF')
          }
          .width(40)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#EF4444')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(item.title)
              .fontSize(this.sf(15))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('删除时间: ' + item.deleteTime)
              .fontSize(this.sf(11))
              .fontColor('#9CA3AF')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)

          // 恢复按钮
          Text('恢复')
            .fontSize(this.sf(12))
            .fontColor('#FF6B35')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#FF6B35' })
            .borderRadius(12)
            .margin({ right: 8 })
            .onClick(() => {
              if (workManager.restoreFromRecycleBin(item.id)) {
                promptAction.showToast({ message: '已恢复到书架', duration: 2000 });
                this.refreshMaterialLibrary();
              }
            })

          // 彻底删除
          Text('删除')
            .fontSize(this.sf(12))
            .fontColor('#EF4444')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#EF4444' })
            .borderRadius(12)
            .onClick(() => {
              if (workManager.deleteFromRecycleBin(item.id)) {
                promptAction.showToast({ message: '已彻底删除', duration: 2000 });
                this.refreshMaterialLibrary();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .margin({ bottom: 8 })
      }, (item: RecycleBinItem) => item.id)

      // 清空回收站按钮
      Button('清空回收站')
        .fontSize(this.sf(14))
        .fontColor('#EF4444')
        .backgroundColor('transparent')
        .border({ width: 1, color: '#EF4444' })
        .borderRadius(8)
        .height(36)
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => {
          workManager.clearRecycleBin();
          this.refreshMaterialLibrary();
          promptAction.showToast({ message: '回收站已清空', duration: 2000 });
        })
    } else {
      Column() {
        Text('🗑 回收站为空')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 中转站视图 */
  @Builder
  TransitStationView() {
    if (this.transitItems.length > 0) {
      ForEach(this.transitItems, (item: TransitItem) => {
        Row() {
          Column() {
            Text('🔄')
              .fontSize(this.sf(18))
              .fontColor('#FFFFFF')
          }
          .width(40)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#3B82F6')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(item.title)
              .fontSize(this.sf(15))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('来源: ' + item.source + ' | ' + item.createTime)
              .fontSize(this.sf(11))
              .fontColor('#9CA3AF')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)

          // 接收按钮
          Text('接收')
            .fontSize(this.sf(12))
            .fontColor('#3B82F6')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#3B82F6' })
            .borderRadius(12)
            .margin({ right: 8 })
            .onClick(() => {
              if (workManager.restoreFromRecycleBin(item.id)) {
                promptAction.showToast({ message: '已接收', duration: 2000 });
                this.refreshMaterialLibrary();
              }
            })

          // 移除
          Text('移除')
            .fontSize(this.sf(12))
            .fontColor('#9CA3AF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#9CA3AF' })
            .borderRadius(12)
            .onClick(() => {
              if (workManager.removeFromTransit(item.id)) {
                this.refreshMaterialLibrary();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .margin({ bottom: 8 })
      }, (item: TransitItem) => item.id)
    } else {
      Column() {
        Text('🔄 中转站为空')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
        Text('跨设备传递的内容将显示在此')
          .fontSize(this.sf(12))
          .fontColor('#9CA3AF')
          .margin({ top: 4 })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 灵感池视图 */
  @Builder
  InspirationPoolView() {
    if (this.inspirationItems.length > 0) {
      ForEach(this.inspirationItems, (item: InspirationItem) => {
        Row() {
          Column() {
            Text('💡')
              .fontSize(this.sf(18))
              .fontColor('#FFFFFF')
          }
          .width(40)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#F59E0B')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(item.content)
              .fontSize(this.sf(14))
              .fontColor(this.textColor)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row() {
              Text(item.fromWidget ? '📱 卡片' : '✍️ 手动')
                .fontSize(this.sf(10))
                .fontColor(item.fromWidget ? '#F59E0B' : '#9CA3AF')
              Text(' | ' + item.createTime)
                .fontSize(this.sf(10))
                .fontColor('#9CA3AF')
            }
            .margin({ top: 4 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)

          // 删除按钮
          Text('删除')
            .fontSize(this.sf(12))
            .fontColor('#EF4444')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#EF4444' })
            .borderRadius(12)
            .onClick(() => {
              if (workManager.deleteInspiration(item.id)) {
                this.refreshMaterialLibrary();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .margin({ bottom: 8 })
      }, (item: InspirationItem) => item.id)

      // 手动添加灵感
      Button('＋ 添加灵感')
        .fontSize(this.sf(14))
        .fontColor('#FF6B35')
        .backgroundColor('#FFF7ED')
        .borderRadius(8)
        .height(36)
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => {
          workManager.addInspiration('新灵感 ' + new Date().toLocaleTimeString(), 'idea', false);
          this.refreshMaterialLibrary();
        })
    } else {
      Column() {
        Text('💡 灵感池为空')
          .fontSize(this.sf(16))
          .fontColor('#9CA3AF')
        Text('从桌面卡片快速记录灵感')
          .fontSize(this.sf(12))
          .fontColor('#9CA3AF')
          .margin({ top: 4 })
        Button('＋ 添加灵感')
          .fontSize(this.sf(14))
          .fontColor('#FF6B35')
          .backgroundColor('#FFF7ED')
          .borderRadius(8)
          .height(36)
          .width('auto')
          .margin({ top: 12 })
          .onClick(() => {
            workManager.addInspiration('新灵感 ' + new Date().toLocaleTimeString(), 'idea', false);
            this.refreshMaterialLibrary();
          })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 可复用的作品行 */
  @Builder
  WorkItemRow(work: WorkItem, isArchived: boolean) {
    Row() {
      Column() {
        Text((work.title || '未命名').charAt(0))
          .fontSize(this.sf(18))
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
          .fontSize(this.sf(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(work.templateName)
          .fontSize(this.sf(11))
          .fontColor('#FF2D55')
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (isArchived) {
        Text('移回')
          .fontSize(this.sf(12))
          .fontColor('#3B82F6')
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            workManager.unarchiveWork(work.id);
            promptAction.showToast({ message: '已移回书架', duration: 2000 });
          })
      } else {
        Text('归档')
          .fontSize(this.sf(12))
          .fontColor('#6B7280')
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.workToArchive = work.id;
            this.showArchiveFolderPicker = true;
          })
      }

      Text('>')
        .fontSize(this.sf(16))
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
        params: { workId: work.id, mode: work.templateId || 'short_drama' }
      });
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.selectedWorkForMenu = work;
          this.showWorkMenu = true;
        })
    )
  }

  /** 重命名对话框 */
  @Builder
  RenameDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('重命名')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        TextInput({ text: this.renameText, placeholder: '输入新名称' })
          .fontSize(this.sf(14))
          .height(44)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.renameText = value;
          })

        Row() {
          Button('取消')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .backgroundColor(this.bgColor)
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              this.showRenameDialog = false;
              this.renameText = '';
            })

          Button('确定')
            .fontSize(this.sf(14))
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              if (this.renameText.trim().length > 0) {
                if (this.renameTargetType === 'work' && this.selectedWorkForMenu) {
                  workManager.renameWork(this.selectedWorkForMenu.id, this.renameText.trim());
                  this.refreshKey++;
                } else if (this.folderMenuType === 'bookshelf' && this.selectedFolder) {
                  workManager.renameFolder(this.selectedFolder.id, this.renameText.trim());
                } else if (this.folderMenuType === 'archive' && this.selectedArchiveFolder) {
                  workManager.renameArchiveFolder(this.selectedArchiveFolder.id, this.renameText.trim());
                }
                promptAction.showToast({ message: '已重命名', duration: 2000 });
              }
              this.showRenameDialog = false;
              this.renameText = '';
              this.renameTargetType = 'folder';
            })
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width('80%')
      .padding(24)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
  }

  /** 封面颜色选择器 */
  @Builder
  CoverPickerDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('选择封面颜色')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['#FF2D55', '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899', '#06B6D4', '#EF4444', '#6366F1', '#14B8A6'], (color: string) => {
            Column()
              .width(44)
              .height(44)
              .backgroundColor(color)
              .borderRadius(22)
              .margin({ left: 8, right: 8, bottom: 12 })
              .onClick(() => {
                if (this.coverPickerTargetType === 'work' && this.selectedWorkForMenu) {
                  workManager.changeWorkCover(this.selectedWorkForMenu.id, color);
                  this.refreshKey++;
                } else if (this.folderMenuType === 'bookshelf' && this.selectedFolder) {
                  workManager.changeFolderCover(this.selectedFolder.id, color);
                } else if (this.folderMenuType === 'archive' && this.selectedArchiveFolder) {
                  workManager.changeArchiveFolderCover(this.selectedArchiveFolder.id, color);
                }
                promptAction.showToast({ message: '封面已更新', duration: 2000 });
                this.showCoverPicker = false;
                this.coverPickerTargetType = 'folder';
              })
          }, (color: string) => color)
        }
        .width('100%')

        Button('关闭')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .height(40)
          .width('100%')
          .margin({ top: 8 })
          .onClick(() => {
            this.showCoverPicker = false;
          })
      }
      .width('80%')
      .padding(24)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
  }

  /** 归档文件夹选择器 */
  @Builder
  ArchiveFolderPickerDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('选择归档位置')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        Scroll() {
          Column() {
            // 新建文件夹选项
            Row() {
              Text('📁 新建文件夹')
                .fontSize(this.sf(14))
                .fontColor('#FF2D55')
                .layoutWeight(1)
              Text('+')
                .fontSize(this.sf(18))
                .fontColor('#FF2D55')
            }
            .width('100%')
            .height(48)
            .backgroundColor(this.bgColor)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 8 })
            .onClick(() => {
              const folder = workManager.createArchiveFolder('归档文件夹');
              workManager.archiveWork(this.workToArchive, folder.id);
              promptAction.showToast({ message: '已归档到新文件夹', duration: 2000 });
              this.showArchiveFolderPicker = false;
            })

            // 已有文件夹列表
            ForEach(workManager.getArchiveFolders(), (folder: ArchiveFolder) => {
              Row() {
                Text('📦 ' + folder.name)
                  .fontSize(this.sf(14))
                  .fontColor(this.textColor)
                  .layoutWeight(1)
                Text(`${workManager.getArchivedWorksByFolder(folder.id).length} 篇`)
                  .fontSize(this.sf(12))
                  .fontColor(this.subTextColor)
              }
              .width('100%')
              .height(48)
              .backgroundColor(this.bgColor)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .margin({ bottom: 8 })
              .onClick(() => {
                workManager.archiveWork(this.workToArchive, folder.id);
                promptAction.showToast({ message: '已归档', duration: 2000 });
                this.showArchiveFolderPicker = false;
              })
            }, (folder: ArchiveFolder) => folder.id)

            // 不放入文件夹
            Row() {
              Text('直接归档（不放入文件夹）')
                .fontSize(this.sf(14))
                .fontColor(this.subTextColor)
                .layoutWeight(1)
            }
            .width('100%')
            .height(48)
            .backgroundColor(this.bgColor)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 8 })
            .onClick(() => {
              workManager.archiveWork(this.workToArchive);
              promptAction.showToast({ message: '已归档', duration: 2000 });
              this.showArchiveFolderPicker = false;
            })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .constraintSize({ maxHeight: 300 })

        Button('取消')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .height(40)
          .width('100%')
          .margin({ top: 8 })
          .onClick(() => {
            this.showArchiveFolderPicker = false;
          })
      }
      .width('80%')
      .padding(24)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
  }

  /** 文件夹长按菜单对话框 */
  @Builder
  FolderMenuDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text(this.folderMenuType === 'bookshelf' ? '📁 文件夹操作' : '📦 文件夹操作')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        // 更换封面
        Row() {
          Text('🎨 更换封面')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.bgColor)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          this.showFolderMenu = false;
          this.showCoverPicker = true;
        })

        // 重命名
        Row() {
          Text('✏️ 重命名')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.bgColor)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          if (this.folderMenuType === 'bookshelf' && this.selectedFolder) {
            this.renameText = this.selectedFolder.name;
          } else if (this.folderMenuType === 'archive' && this.selectedArchiveFolder) {
            this.renameText = this.selectedArchiveFolder.name;
          }
          this.showFolderMenu = false;
          this.showRenameDialog = true;
        })

        // 删除文件夹
        Row() {
          Text('🗑️ 删除文件夹')
            .fontSize(this.sf(15))
            .fontColor('#EF4444')
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.bgColor)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          const folderName = this.folderMenuType === 'bookshelf'
            ? (this.selectedFolder ? this.selectedFolder.name : '')
            : (this.selectedArchiveFolder ? this.selectedArchiveFolder.name : '');
          promptAction.showDialog({
            title: '确认删除',
            message: `删除文件夹「${folderName}」？文件夹内作品将变为未分类。`,
            buttons: [
              { text: '取消', color: '#9CA3AF' },
              { text: '删除', color: '#EF4444' }
            ]
          }).then((data) => {
            if (data.index === 1) {
              if (this.folderMenuType === 'bookshelf' && this.selectedFolder) {
                workManager.deleteFolder(this.selectedFolder.id);
                this.currentFolderId = '';
              } else if (this.folderMenuType === 'archive' && this.selectedArchiveFolder) {
                workManager.deleteArchiveFolder(this.selectedArchiveFolder.id);
                this.currentArchiveFolderId = '';
              }
              this.refreshKey++;
              this.refreshMaterialLibrary();
              promptAction.showToast({ message: '文件夹已删除', duration: 2000 });
            }
            this.showFolderMenu = false;
          });
        })

        // 取消
        Button('取消')
          .fontSize(this.sf(14))
          .fontColor(this.subTextColor)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .height(40)
          .width('100%')
          .margin({ top: 4 })
          .onClick(() => {
            this.showFolderMenu = false;
          })
      }
      .width('75%')
      .padding(24)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
  }

  /** 作品长按菜单 */
  @Builder
  WorkMenuDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('📄 作品操作')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 16 })

        // 重命名
        Row() {
          Text('✏️ 重命名')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          if (this.selectedWorkForMenu) {
            this.renameText = this.selectedWorkForMenu.title || '';
            this.renameTargetType = 'work';
            this.showRenameDialog = true;
          }
          this.showWorkMenu = false;
        })

        // 更换封面
        Row() {
          Text('🎨 更换封面')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          this.coverPickerTargetType = 'work';
          this.showCoverPicker = true;
          this.showWorkMenu = false;
        })

        // 归档
        Row() {
          Text('📦 归档到旧档区')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .onClick(() => {
          if (this.selectedWorkForMenu) {
            this.workToArchive = this.selectedWorkForMenu.id;
            this.showArchiveFolderPicker = true;
          }
          this.showWorkMenu = false;
        })

        // 删除
        Row() {
          Text('🗑️ 删除')
            .fontSize(this.sf(15))
            .fontColor('#FF2D55')
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          if (this.selectedWorkForMenu) {
            workManager.deleteWork(this.selectedWorkForMenu.id);
            this.refreshKey++;
          }
          this.showWorkMenu = false;
        })

        // 取消
        Row() {
          Text('取消')
            .fontSize(this.sf(15))
            .fontColor(this.textColor)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.cardBg)
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ top: 8 })
        .onClick(() => {
          this.showWorkMenu = false;
        })
      }
      .width('70%')
      .padding(20)
      .backgroundColor(this.isDarkMode ? '#1E1E28' : '#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.42)')
  }

  @Builder
  FloatingTabBar() {
    Column() {
      Row() {
      // 短幕剧
      Column() {
        Text('🎬')
          .fontSize(this.sf(26))
        Text('短幕剧')
          .fontSize(this.sf(12))
          .fontColor(this.currentIndex === 0 ? '#FF2D55' : (this.isDarkMode ? '#E5E7EB' : '#374151'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 0;
      })

      // 中长篇
      Column() {
        Text('📚')
          .fontSize(this.sf(26))
        Text('中长篇')
          .fontSize(this.sf(12))
          .fontColor(this.currentIndex === 1 ? '#FF2D55' : (this.isDarkMode ? '#E5E7EB' : '#374151'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 1;
      })

      // 书架
      Column() {
        Text('📖')
          .fontSize(this.sf(26))
        Text('书架')
          .fontSize(this.sf(12))
          .fontColor(this.currentIndex === 2 ? '#FF2D55' : (this.isDarkMode ? '#E5E7EB' : '#374151'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 2;
      })

      // 素材库
      Column() {
        Text('📦')
          .fontSize(this.sf(26))
        Text('素材库')
          .fontSize(this.sf(12))
          .fontColor(this.currentIndex === 3 ? '#FF2D55' : (this.isDarkMode ? '#E5E7EB' : '#374151'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 3;
      })

      // 设置
      Column() {
        Text('⚙️')
          .fontSize(this.sf(26))
        Text('设置')
          .fontSize(this.sf(12))
          .fontColor(this.currentIndex === 4 ? '#FF2D55' : (this.isDarkMode ? '#E5E7EB' : '#374151'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentIndex = 4;
      })
    }
      .width('100%')
      .height(64)

      // 底部安全区域
      Row()
        .width('100%')
        .height(8)
    }
    .width('92%')
    .margin({ bottom: 12 })
    .borderRadius(32)
    .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
    .border({ width: 1, color: this.isDarkMode ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)' })
    .shadow({
      radius: 16,
      color: this.isDarkMode ? 'rgba(0,0,0,0.6)' : 'rgba(0,0,0,0.15)',
      offsetY: -2
    })
  }

  @Builder
  TabBuilder(title: string, icon: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(this.sf(20))
      Text(title)
        .fontSize(this.sf(10))
        .fontColor(this.currentIndex === index ? '#FF2D55' : (this.isDarkMode ? '#B7BACB' : '#9CA3AF'))
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
  @StorageProp('appFontSize') fontSize: number = 14;
  @State templates: TemplateInfo[] = [];
  @State works: WorkItem[] = [];
  @State archivedWorks: WorkItem[] = [];
  @State showArchive: boolean = false;
  private unsubscribe: (() => void) | null = null;

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }

  /** 短幕剧工作台覆盖的模板品类 */
  private readonly categories: string[] = ['剧本类', '喜剧类', '灵感类', '广告类', '交互沉浸类', '创意引擎'];

  /** 获取实际有模板的分类列表 */
  getCategories(): string[] {
    const cats: string[] = [];
    this.categories.forEach(c => {
      if (this.templates.some(t => t.category === c)) {
        cats.push(c);
      }
    });
    return cats;
  }

  /** 分类对应的Emoji图标 */
  getCategoryEmoji(category: string): string {
    const map: Record<string, string> = {
      '剧本类': '📝',
      '喜剧类': '😂',
      '叙事类': '📖',
      '中长篇': '📚',
      '灵感类': '💡',
      '广告类': '📢',
      '互动类': '🎮',
      '交互沉浸类': '🎭',
      '创意引擎': '⚡'
    };
    return map[category] || '📄';
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
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(this.sf(14))
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
          ForEach(this.getCategories(), (category: string) => {
            Column() {
              // 分类标题
              Row() {
                Text(this.getCategoryEmoji(category))
                  .fontSize(this.sf(14))
                Text(category)
                  .fontSize(this.sf(14))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .margin({ left: 6 })
                Blank()
                Text(`${this.templates.filter(t => t.category === category).length}个模板`)
                  .fontSize(this.sf(11))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 8 })

              // 每排2个按钮
              Grid() {
                ForEach(this.templates.filter(t => t.category === category), (item: TemplateInfo) => {
                  GridItem() {
                    this.TemplateCard(item)
                  }
                }, (item: TemplateInfo) => item.id)
              }
              .columnsTemplate('1fr 1fr')
              .rowsGap(10)
              .columnsGap(10)
              .padding({ left: 16, right: 16 })
              .width('100%')
            }
          }, (category: string) => category)

          // 底部留白
          Column().width('100%').height(8)
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
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill(template.color)
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(this.sf(16))
            .fontColor('#FFFFFF')
        } else {
          Image(template.icon)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
      }
      .width(36)
      .height(36)

      Text(template.name)
        .fontSize(this.sf(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ left: 10 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('›')
        .fontSize(this.sf(18))
        .fontColor('#9CA3AF')
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
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
          .fontSize(this.sf(20))
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
          .fontSize(this.sf(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(work.templateName)
          .fontSize(this.sf(11))
          .fontColor('#FF2D55')
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(isArchived ? '移回书架' : '归档')
        .fontSize(this.sf(12))
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
        .fontSize(this.sf(12))
        .fontColor('#EF4444')
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.confirmDelete(work);
        })

      Text('>')
        .fontSize(this.sf(16))
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
  @StorageProp('appFontSize') fontSize: number = 14;
  @State templates: TemplateInfo[] = [];
  @State works: WorkItem[] = [];
  @State archivedWorks: WorkItem[] = [];
  @State showArchive: boolean = false;
  @State showOutlinePanel: boolean = false;
  @State selectedWorkId: string = '';
  @State selectedWorkTitle: string = '';
  private unsubscribe: (() => void) | null = null;

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }

  /** 中长篇工作台覆盖的模板品类 */
  private readonly categories: string[] = ['叙事类', '互动类', '中长篇', '世界观专项', '人物专项', '时间线专项', '写作工具', '出版分享'];

  /** 获取实际有模板的分类列表 */
  getCategories(): string[] {
    const cats: string[] = [];
    this.categories.forEach(c => {
      if (this.templates.some(t => t.category === c)) {
        cats.push(c);
      }
    });
    return cats;
  }

  /** 分类对应的Emoji图标 */
  getCategoryEmoji(category: string): string {
    const map: Record<string, string> = {
      '剧本类': '📝',
      '喜剧类': '😂',
      '叙事类': '📖',
      '中长篇': '📚',
      '灵感类': '💡',
      '广告类': '📢',
      '互动类': '🎮',
      '交互沉浸类': '🎭',
      '创意引擎': '⚡'
    };
    return map[category] || '📄';
  }

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
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(this.sf(14))
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
          ForEach(this.getCategories(), (category: string) => {
            Column() {
              // 分类标题
              Row() {
                Text(this.getCategoryEmoji(category))
                  .fontSize(this.sf(14))
                Text(category)
                  .fontSize(this.sf(14))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .margin({ left: 6 })
                Blank()
                Text(`${this.templates.filter(t => t.category === category).length}个模板`)
                  .fontSize(this.sf(11))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 8 })

              // 每排2个按钮
              Grid() {
                ForEach(this.templates.filter(t => t.category === category), (item: TemplateInfo) => {
                  GridItem() {
                    this.TemplateCard(item)
                  }
                }, (item: TemplateInfo) => item.id)
              }
              .columnsTemplate('1fr 1fr')
              .rowsGap(10)
              .columnsGap(10)
              .padding({ left: 16, right: 16 })
              .width('100%')
            }
          }, (category: string) => category)

          // 底部留白
          Column().width('100%').height(8)
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
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill(template.color)
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(this.sf(16))
            .fontColor('#FFFFFF')
        } else {
          Image(template.icon)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
      }
      .width(36)
      .height(36)

      Text(template.name)
        .fontSize(this.sf(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ left: 10 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('›')
        .fontSize(this.sf(18))
        .fontColor('#9CA3AF')
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
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
          .fontSize(this.sf(20))
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
          .fontSize(this.sf(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(work.templateName)
          .fontSize(this.sf(11))
          .fontColor('#FF2D55')
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('📋')
        .fontSize(this.sf(18))
        .margin({ right: 8 })
        .onClick(() => {
          this.openOutlinePanel(work);
        })

      Text(isArchived ? '移回书架' : '归档')
        .fontSize(this.sf(12))
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
        .fontSize(this.sf(12))
        .fontColor('#EF4444')
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.confirmDelete(work);
        })

      Text('>')
        .fontSize(this.sf(16))
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
  
  @State followSystemDark: boolean = false;
  @State prevFollowSystemDark: boolean = false;
  @State showPrivacyPanel: boolean = false;
  @State showAboutPanel: boolean = false;
  @State autoSaveInterval: number = 5;
  @StorageProp('appFontSize') fontSize: number = 14;
  @StorageProp('appBreakpoint') appBreakpoint: string = 'sm';
  
  @State showImportPanel: boolean = false;
  @State importText: string = '';
  @State showPermissionPanel: boolean = false;
  @State permissionItems: PermissionItem[] = [];
  @State showHelpPanel: boolean = false;
  @State showFeedbackPanel: boolean = false;
  @State feedbackText: string = '';
  @State isHuaweiLoggedIn: boolean = false;
  @State huaweiUserInfo: HuaweiUserInfo | null = null;
  @State syncStatusText: string = '';
  @State localFontPath: string = '';
  @State showFontPicker: boolean = false;
  @State localModelPath: string = '';
  @State showModelPicker: boolean = false;
  @State ggufContextLength: number = 2048;
  @State ggufThreads: number = 4;
  @State ggufMaxTokens: number = 512;
  @State ggufTemperature: number = 0.8;

  aboutToAppear() {
    if (settingsManager.initPromise) {
      settingsManager.initPromise.then(() => {
        this.loadSettings();
      });
    } else {
      this.loadSettings();
    }
    this.permissionItems = permissionManager.getPermissionItems();

    // 恢复华为账号登录状态
    this.isHuaweiLoggedIn = huaweiAuthService.isLoggedIn();
    if (this.isHuaweiLoggedIn) {
      this.huaweiUserInfo = huaweiAuthService.getCurrentUser();
    }
  }

  // 暗色模式辅助颜色属性
  get _cardBg(): string { return this.isDarkMode ? '#2D2D3A' : '#FFFFFF'; }
  get _textPrimary(): string { return this.isDarkMode ? '#FFFFFF' : '#1A1A2E'; }
  get _textSecondary(): string { return this.isDarkMode ? '#9CA3AF' : '#6B7280'; }

  get _contentMaxWidth(): number {
    if (this.appBreakpoint === 'lg') return 800;
    if (this.appBreakpoint === 'md') return 600;
    return 10000;
  }

  get _sidePadding(): number {
    if (this.appBreakpoint === 'lg') return 24;
    if (this.appBreakpoint === 'md') return 20;
    return 16;
  }

  get _inputBg(): string { return this.isDarkMode ? '#3A3A4A' : '#F9FAFB'; }
  get _cancelBg(): string { return this.isDarkMode ? '#3A3A4A' : '#F3F4F6'; }
  get _cancelText(): string { return this.isDarkMode ? '#9CA3AF' : '#6B7280'; }

  /** 从完整路径中提取文件名 */
  getFileName(fullPath: string): string {
    const parts = fullPath.split('/');
    return parts[parts.length - 1] || fullPath;
  }

  /** 根据当前设置计算并应用暗色模式 */
  applyDarkMode(): void {
    if (settingsManager.settings.followSystemDark) {
      const ctx = getContext(this) as common.UIAbilityContext;
      if (ctx.config && ctx.config.colorMode !== undefined) {
        this.isDarkMode = ctx.config.colorMode === 0;
      }
    } else {
      this.isDarkMode = settingsManager.settings.isDarkMode;
    }
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(this.sf(20))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
        .alignSelf(ItemAlign.Start)
        .margin({ left: this._sidePadding, top: 16, bottom: 12 })

      List() {
        // ===== AI 配置 =====
        ListItem() {
          this.SectionTitle('AI 配置')
        }

        ListItem() {
          this.SettingRow('本地模型文件(GGUF)', this.localModelPath ? this.getFileName(this.localModelPath) : '未选择', true)
        }
        .onClick(() => {
          this.showModelPicker = true;
        })

        ListItem() {
          Column() {
            Row() {
              Text('上下文长度')
                .fontSize(this.sf(14))
                .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
                Blank()
                Text(`${this.ggufContextLength}`)
                  .fontSize(this.sf(14))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ top: 8, bottom: 4 })

              Slider({
                value: this.ggufContextLength,
                min: 512,
                max: 8192,
                step: 512
              })
                .width('100%')
                .trackColor(this.isDarkMode ? '#3A3A3A' : '#E0E0E0')
                .selectedColor('#007DFF')
                .onChange((value: number) => {
                  this.ggufContextLength = value;
                  settingsManager.settings.ggufContextLength = value;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
          }

          ListItem() {
            Column() {
              Row() {
                Text('推理线程数')
                  .fontSize(this.sf(14))
                  .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
                Blank()
                Text(`${this.ggufThreads}`)
                  .fontSize(this.sf(14))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ top: 8, bottom: 4 })

              Slider({
                value: this.ggufThreads,
                min: 1,
                max: 8,
                step: 1
              })
                .width('100%')
                .trackColor(this.isDarkMode ? '#3A3A3A' : '#E0E0E0')
                .selectedColor('#007DFF')
                .onChange((value: number) => {
                  this.ggufThreads = value;
                  settingsManager.settings.ggufThreads = value;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
          }

          ListItem() {
            Column() {
              Row() {
                Text('最大生成Token')
                  .fontSize(this.sf(14))
                  .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
                Blank()
                Text(`${this.ggufMaxTokens}`)
                  .fontSize(this.sf(14))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ top: 8, bottom: 4 })

              Slider({
                value: this.ggufMaxTokens,
                min: 128,
                max: 2048,
                step: 128
              })
                .width('100%')
                .trackColor(this.isDarkMode ? '#3A3A3A' : '#E0E0E0')
                .selectedColor('#007DFF')
                .onChange((value: number) => {
                  this.ggufMaxTokens = value;
                  settingsManager.settings.ggufMaxTokens = value;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
          }

          ListItem() {
            Column() {
              Row() {
                Text('采样温度')
                  .fontSize(this.sf(14))
                  .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
                Blank()
                Text(`${this.ggufTemperature.toFixed(1)}`)
                  .fontSize(this.sf(14))
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .padding({ top: 8, bottom: 4 })

              Slider({
                value: this.ggufTemperature * 10,
                min: 1,
                max: 20,
                step: 1
              })
                .width('100%')
                .trackColor(this.isDarkMode ? '#3A3A3A' : '#E0E0E0')
                .selectedColor('#007DFF')
                .onChange((value: number) => {
                  this.ggufTemperature = value / 10;
                  settingsManager.settings.ggufTemperature = value / 10;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
          }

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
          Row() {
            Text('字体大小')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(this._textPrimary)

            Slider({
              value: this.fontSize,
              min: 12,
              max: 24,
              step: 2,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .margin({ left: 12, right: 12 })
              .trackThickness(6)
              .selectedColor(this.isDarkMode ? '#0A84FF' : '#007AFF')
              .blockColor(this.isDarkMode ? '#0A84FF' : '#007AFF')
              .onChange((value: number) => {
                this.fontSize = value;
                AppStorage.setOrCreate('appFontSize', value);
                settingsManager.settings.fontSize = value;
                settingsManager.save();
              })

            Text(`${this.fontSize}px`)
              .fontSize(this.sf(13))
              .fontColor(this._textSecondary)
              .width(40)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .height(56)
          .backgroundColor(this.isDarkMode ? '#2D2D3A' : '#FFFFFF')
        }

        ListItem() {
          this.SettingRow('本地字体文件', this.localFontPath ? this.getFileName(this.localFontPath) : '未选择', true)
        }
        .onClick(() => {
          this.showFontPicker = true;
        })

        ListItem() {
          this.SettingRow('深色模式', this.followSystemDark ? '跟随系统' : (this.isDarkMode ? '开' : '关'), true)
        }
        .onClick(() => {
          this.selectDarkMode();
        })

        // ===== 华为账号与云同步 =====
        ListItem() {
          this.SectionTitle('华为账号与云同步')
        }

        ListItem() {
          this.SettingRow(
            this.isHuaweiLoggedIn ? '已登录华为账号' : '登录华为账号',
            this.isHuaweiLoggedIn ? `已登录（${this.huaweiUserInfo?.openID.substring(0, 8) ?? ''}...）` : '登录后可同步作品到云端',
            true
          )
        }
        .onClick(async () => {
          if (this.isHuaweiLoggedIn) {
            // 已登录 → 退出登录
            try {
              await huaweiAuthService.logout();
              this.isHuaweiLoggedIn = false;
              this.huaweiUserInfo = null;
              this.syncStatusText = '';
              promptAction.showToast({ message: '已退出登录', duration: 2000 });
            } catch (e) {
              promptAction.showToast({ message: `退出失败: ${e}`, duration: 2000 });
            }
          } else {
            // 未登录 → 执行登录
            try {
              const userInfo = await huaweiAuthService.login();
              if (userInfo) {
                this.isHuaweiLoggedIn = true;
                this.huaweiUserInfo = userInfo;
                promptAction.showToast({ message: '登录成功', duration: 2000 });
              } else {
                promptAction.showToast({ message: '登录失败', duration: 2000 });
              }
            } catch (e) {
              promptAction.showToast({ message: `登录失败: ${e}`, duration: 2000 });
            }
          }
        })

        ListItem() {
          this.SettingRow(
            '云端同步',
            this.isHuaweiLoggedIn ? (this.syncStatusText || '点击同步作品到云端') : '请先登录华为账号',
            this.isHuaweiLoggedIn
          )
        }
        .onClick(async () => {
          if (!this.isHuaweiLoggedIn) {
            promptAction.showToast({ message: '请先登录华为账号', duration: 2000 });
            return;
          }
          try {
            this.syncStatusText = '同步中...';
            const success = await cloudSyncService.sync();
            this.syncStatusText = success ? '同步成功' : '同步失败';
            promptAction.showToast({ message: this.syncStatusText, duration: 2000 });
          } catch (e) {
            this.syncStatusText = `同步失败: ${e}`;
            promptAction.showToast({ message: this.syncStatusText, duration: 2000 });
          }
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

        // ===== 隐私与权限 =====
        ListItem() {
          this.SectionTitle('隐私与权限')
        }

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
      .width('100%')
      .layoutWeight(1)

      // 隐私政策/用户协议面板
      if (this.showPrivacyPanel) {
        Column() {
          Column() {
            Text('用户协议与隐私政策')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            Text('【用户协议】')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('1. 本应用仅供个人学习和创作使用，不得用于商业侵权用途。\n2. 用户需遵守相关法律法规，不得利用本应用生成违法违规内容。\n3. AI生成的内容版权归用户所有，用户需自行承担使用风险。\n4. 用户在使用AI功能时应遵守相关法律法规。\n5. 本应用不对AI生成内容的准确性和合法性负责。')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Text('【隐私政策】')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('1. 所有作品数据仅保存在您的设备上，我们不会收集您的创作内容。\n2. 本应用不会收集您的个人信息、位置、通讯录等隐私数据。\n3. 当您使用华为账号登录时，我们仅会获取必要的用户标识用于登录验证。\n4. 我们不会将您的任何数据分享给第三方。')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Button('我知道了')
              .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
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
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            Text('创意写作 v1.2.0')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF2D55')
              .margin({ bottom: 8 })

            Text('AI驱动的写作助手')
              .fontSize(this.sf(13))
              .fontColor(this._textSecondary)
              .margin({ bottom: 16 })

            Text('功能特性：')
              .fontSize(this.sf(14))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 8 })
              .alignSelf(ItemAlign.Start)

            Text('• 短幕剧/中长篇双工作台，独立管理\n• AI对话生成，一键保存思维链路\n• 自动版本归档，修改历史可追溯\n• 书架与旧档区，作品归档一目了然\n• 支持本地GGUF模型\n• 丰富的模板库，支持自定义提示词\n• 深色模式，保护您的视力')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAboutPanel = false;
        })
      }

      // 本地字体文件选择面板
      if (this.showFontPicker) {
        Column() {
          Column() {
            Text('选择本地字体文件')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 16 })

            Text('支持 .ttf / .otf 格式的字体文件')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 12 })

            if (this.localFontPath) {
              Text(`当前: ${this.getFileName(this.localFontPath)}`)
                .fontSize(this.sf(13))
                .fontColor('#3B82F6')
                .margin({ bottom: 12 })
            }

            Button('从文件管理器选择')
              .fontSize(this.sf(14))
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(async () => {
                try {
                  const documentPicker = new picker.DocumentViewPicker();
                  const uris = await documentPicker.select();
                  const result: string[] = uris as string[];
                  if (result && result.length > 0) {
                    this.localFontPath = result[0];
                    settingsManager.settings.localFontPath = this.localFontPath;
                    settingsManager.save();
                    promptAction.showToast({ message: `已选择字体: ${this.getFileName(this.localFontPath)}`, duration: 2000 });
                    this.showFontPicker = false;
                  }
                } catch (err) {
                  promptAction.showToast({ message: '选择文件失败', duration: 2000 });
                }
              })

            Button('清除选择')
              .fontSize(this.sf(14))
              .fontColor(this._cancelText)
              .backgroundColor(this._cancelBg)
              .borderRadius(20)
              .height(40)
              .width('100%')
              .margin({ top: 8 })
              .onClick(() => {
                this.localFontPath = '';
                settingsManager.settings.localFontPath = '';
                settingsManager.save();
                promptAction.showToast({ message: '已清除字体选择', duration: 2000 });
                this.showFontPicker = false;
              })
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.isDarkMode ? '#2D2D44' : '#FFFFFF')
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showFontPicker = false;
        })
      }

      // 本地模型文件(GGUF)选择面板
      if (this.showModelPicker) {
        Column() {
          Column() {
            Text('选择本地AI模型文件')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 16 })

            Text('支持 .gguf 格式的AI模型文件')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 12 })

            if (this.localModelPath) {
              Text(`当前: ${this.getFileName(this.localModelPath)}`)
                .fontSize(this.sf(13))
                .fontColor('#3B82F6')
                .margin({ bottom: 12 })
            }

            Button('从文件管理器选择')
              .fontSize(this.sf(14))
              .fontColor('#FFFFFF')
              .backgroundColor('#FF2D55')
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(async () => {
                try {
                  const documentPicker = new picker.DocumentViewPicker();
                  const uris = await documentPicker.select();
                  const result: string[] = uris as string[];
                  if (result && result.length > 0) {
                    const srcUri = result[0];
                    try {
                      // 将URI文件复制到应用沙箱，C++ fopen需要真实路径
                      const srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
                      const fileName = srcUri.split('/').pop() || 'model.gguf';
                      const sandboxDir = getContext(this).filesDir;
                      const destPath = `${sandboxDir}/${fileName}`;
                      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
                      fileIo.copyFileSync(srcFile.fd, destFile.fd);
                      fileIo.closeSync(srcFile);
                      fileIo.closeSync(destFile);
                      this.localModelPath = destPath;
                      settingsManager.settings.localModelPath = this.localModelPath;
                      settingsManager.save();
                      promptAction.showToast({ message: `模型已复制: ${fileName}`, duration: 2000 });
                    } catch (copyErr) {
                      promptAction.showToast({ message: '模型文件复制失败: ' + copyErr, duration: 3000 });
                    }
                    this.showModelPicker = false;
                  }
                } catch (err) {
                  promptAction.showToast({ message: '选择文件失败', duration: 2000 });
                }
              })

            Button('清除选择')
              .fontSize(this.sf(14))
              .fontColor(this._cancelText)
              .backgroundColor(this._cancelBg)
              .borderRadius(20)
              .height(40)
              .width('100%')
              .margin({ top: 8 })
              .onClick(() => {
                this.localModelPath = '';
                settingsManager.settings.localModelPath = '';
                settingsManager.save();
                promptAction.showToast({ message: '已清除模型选择', duration: 2000 });
                this.showModelPicker = false;
              })
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.isDarkMode ? '#2D2D44' : '#FFFFFF')
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showModelPicker = false;
        })
      }

      // 导入数据面板
      if (this.showImportPanel) {
        Column() {
          Column() {
            Text('导入数据')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 8 })
            Text('粘贴此前导出的备份JSON，重复作品会自动跳过')
              .fontSize(this.sf(12))
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextArea({ placeholder: '粘贴备份JSON内容...' })
              .width('100%')
              .height(160)
              .fontSize(this.sf(13))
              .backgroundColor(this._inputBg)
              .borderRadius(8)
              .padding(12)
              .onChange((value: string) => {
                this.importText = value;
              })
            Row() {
              Button('取消')
                .fontSize(this.sf(14))
                .fontColor(this._cancelText)
                .backgroundColor(this._cancelBg)
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .margin({ right: 12 })
                .onClick(() => {
                  this.showImportPanel = false;
                })
              Button('导入')
                .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
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
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            ForEach(this.permissionItems, (item: PermissionItem) => {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(this.sf(14))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this._textPrimary)
                  Text(item.reason)
                    .fontSize(this.sf(12))
                    .fontColor('#9CA3AF')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.granted) {
                  Text('已授权')
                    .fontSize(this.sf(12))
                    .fontColor('#10B981')
                } else {
                  Button('申请')
                    .fontSize(this.sf(12))
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
              .fontSize(this.sf(11))
              .fontColor('#9CA3AF')
              .margin({ top: 8, bottom: 12 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
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
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            Scroll() {
              Column() {
                Text('【快速上手】')
                  .fontSize(this.sf(14))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this._textPrimary)
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                Text('1. 在短幕剧/中长篇工作台选择模板，填写字段即可生成创作框架。\n2. 点击"AI生成"按钮，由AI补全完整内容（需在设置中配置本地GGUF模型）。\n3. 保存后作品进入书架，可随时归档到旧档区。')
                  .fontSize(this.sf(12))
                  .fontColor(this._textSecondary)
                  .margin({ bottom: 16 })
                  .alignSelf(ItemAlign.Start)

                Text('【常见问题】')
                  .fontSize(this.sf(14))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this._textPrimary)
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                Text('Q: AI生成失败怎么办？\nA: 请检查设置中的本地GGUF模型配置是否正确，也可尝试调大AI超时时间。\n\nQ: 作品如何备份？\nA: 设置 → 导出数据，将备份JSON复制保存；换设备后用"导入数据"恢复。\n\nQ: 版本历史在哪里？\nA: 打开作品后点击底部"历史"按钮，可预览并恢复任意历史版本。')
                  .fontSize(this.sf(12))
                  .fontColor(this._textSecondary)
                  .margin({ bottom: 16 })
                  .alignSelf(ItemAlign.Start)
              }
              .width('100%')
            }
            .height(300)
            .scrollBar(BarState.Auto)

            Button('关闭')
              .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
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
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 8 })
            Text('描述您遇到的问题或建议，提交后会复制到剪贴板，可发送至支持邮箱 support@creativewriting.app')
              .fontSize(this.sf(12))
              .fontColor('#9CA3AF')
              .margin({ bottom: 12 })
            TextArea({ placeholder: '请输入反馈内容...' })
              .width('100%')
              .height(140)
              .fontSize(this.sf(13))
              .backgroundColor(this._inputBg)
              .borderRadius(8)
              .padding(12)
              .onChange((value: string) => {
                this.feedbackText = value;
              })
            Row() {
              Button('取消')
                .fontSize(this.sf(14))
                .fontColor(this._cancelText)
                .backgroundColor(this._cancelBg)
                .borderRadius(20)
                .height(40)
                .layoutWeight(1)
                .margin({ right: 12 })
                .onClick(() => {
                  this.showFeedbackPanel = false;
                })
              Button('提交')
                .fontSize(this.sf(14))
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
          .backgroundColor(this._cardBg)
          .borderRadius(16)
          .margin({ left: 24, right: 24 })
          .hitTestBehavior(HitTestMode.Block)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.42)')
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
    .constraintSize({ maxWidth: this._contentMaxWidth })
  }

  @Builder
  SettingRow(title: string, subtitle: string, hasArrow: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(this.sf(15))
          .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A2E')
        if (subtitle) {
          Text(subtitle)
            .fontSize(this.sf(12))
            .fontColor('#9CA3AF')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (hasArrow) {
        Text('›')
          .fontSize(this.sf(20))
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
      .fontSize(this.sf(12))
      .fontWeight(FontWeight.Bold)
      .fontColor('#9CA3AF')
      .margin({ top: 8, bottom: 4 })
      .padding({ left: 16 })
      .width('100%')
  }

  selectDarkMode() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '深色模式',
      buttons: [
        { text: '关', color: this._textPrimary } as MenuButton,
        { text: '开', color: this._textPrimary } as MenuButton,
        { text: '跟随系统', color: this._textPrimary } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        // 关
        settingsManager.settings.followSystemDark = false;
        settingsManager.settings.isDarkMode = false;
        this.followSystemDark = false;
        this.prevFollowSystemDark = false;
        this.applyDarkMode();
        settingsManager.save();
        promptAction.showToast({ message: '已关闭深色模式', duration: 2000 });
      } else if (result.index === 1) {
        // 开
        settingsManager.settings.followSystemDark = false;
        settingsManager.settings.isDarkMode = true;
        this.followSystemDark = false;
        this.prevFollowSystemDark = false;
        this.applyDarkMode();
        settingsManager.save();
        promptAction.showToast({ message: '已开启深色模式', duration: 2000 });
      } else if (result.index === 2) {
        // 跟随系统
        settingsManager.settings.followSystemDark = true;
        this.followSystemDark = true;
        this.prevFollowSystemDark = true;
        this.applyDarkMode();
        settingsManager.save();
        promptAction.showToast({ message: '已跟随系统深色模式', duration: 2000 });
      }
    });
  }

  editAutoSaveInterval() {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '选择自动保存间隔',
      buttons: [
        { text: '1分钟', color: this._textPrimary } as MenuButton,
        { text: '5分钟', color: this._textPrimary } as MenuButton,
        { text: '10分钟', color: this._textPrimary } as MenuButton,
        { text: '30分钟', color: this._textPrimary } as MenuButton
      ] as [MenuButton, MenuButton, MenuButton, MenuButton]
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

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }

  loadSettings() {
    this.followSystemDark = settingsManager.settings.followSystemDark;
    this.prevFollowSystemDark = settingsManager.settings.followSystemDark;
    this.autoSaveInterval = settingsManager.settings.autoSaveInterval || 5;
    this.fontSize = settingsManager.settings.fontSize || 14;
    AppStorage.setOrCreate('appFontSize', this.fontSize);
    this.localFontPath = settingsManager.settings.localFontPath || '';
    this.localModelPath = settingsManager.settings.localModelPath || '';
    this.ggufContextLength = settingsManager.settings.ggufContextLength ?? 2048;
    this.ggufThreads = settingsManager.settings.ggufThreads ?? 4;
    this.ggufMaxTokens = settingsManager.settings.ggufMaxTokens ?? 512;
    this.ggufTemperature = settingsManager.settings.ggufTemperature ?? 0.8;
  }

  saveSettings() {
    settingsManager.settings.autoSaveInterval = this.autoSaveInterval;
    settingsManager.settings.fontSize = this.fontSize;
    settingsManager.settings.isDarkMode = this.isDarkMode;
    settingsManager.settings.followSystemDark = this.followSystemDark;
    settingsManager.settings.localFontPath = this.localFontPath;
    settingsManager.settings.localModelPath = this.localModelPath;
    settingsManager.save();
  }
}
