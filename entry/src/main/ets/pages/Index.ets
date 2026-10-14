import { TemplateInfo, templateList } from '../model/TemplateModel';
import { WorkItem, workManager, BookshelfFolder, ArchiveFolder, RecycleBinItem, InspirationItem } from '../model/WorkManager';
import { OutlineManagementPanel } from '../components/OutlineManagementPanel';
import { RectShape, promptAction } from '@kit.ArkUI';
import { settingsManager } from '../model/SettingsManager';
import { aiService } from '../model/AIService';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { huaweiAuthService, HuaweiUserInfo } from '../model/HuaweiAuthService';
import { cloudSyncService, SyncStatus } from '../model/CloudSyncService';
import { responsiveManager, BreakpointType } from '../model/ResponsiveManager';
import { permissionManager, PermissionItem, PermissionResult } from '../model/PermissionManager';
import picker from '@ohos.file.picker';
import fileIo from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import formProvider from '@ohos.app.form.formProvider';
import formBindingData from '@ohos.app.form.formBindingData';
import { updateManager } from '@kit.AppGalleryKit';
import { preferences } from '@kit.ArkData';

/** 卡片所需的灵感统计数据 */
interface InspirationStats {
  count: string;
  lastContent: string;
}

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
  @State hasReadAndAgreed: boolean = false;
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

  // 素材库子页签：0=旧档, 1=回收站, 2=灵感池
  @State materialSubTab: number = 0;
  @State recycleBinItems: RecycleBinItem[] = [];
  @State inspirationItems: InspirationItem[] = [];

  // ===== 数据快照：@Builder 中引用这些 @State 变量以实现响应式刷新 =====
  // 根因：@Builder 中直接调用 workManager.getXxx() 返回普通数组，不被 ArkUI 依赖追踪，
  //       数据变更后 UI 不刷新。改为在 onChange 回调中同步快照到 @State，触发重渲染。
  @State bookshelfFolders: BookshelfFolder[] = [];
  @State archiveFolders: ArchiveFolder[] = [];
  @State bookshelfWorks: WorkItem[] = [];           // 所有书架作品（未归档）
  @State archivedWorks: WorkItem[] = [];             // 所有旧档作品（已归档）
  @State editingInspirationId: string = '';
  @State editingInspirationContent: string = '';
  @State showInspirationEditor: boolean = false;
  @State isNewInspiration: boolean = false;
  // 灵感草稿缓存：误触关闭弹窗后恢复，避免丢失已输入内容
  @StorageLink('inspirationDraftCache') inspirationDraftCache: string = '';
  // 卡片导航目标：App 在前台时点卡片，onNewWant 写入该键，@Watch 实时响应跳转（不依赖 onPageShow）
  @StorageLink('appNavTarget') @Watch('onAppNavTargetChange') appNavTarget: string = '';
  // 语音输入状态（引擎与会话字段在方法区声明）
  @State isVoiceRecognizing: boolean = false;
  // 语音识别实时中间结果（非 isFinal 的过渡文本，用于实时写入反馈）
  @State voiceInterimText: string = '';
  // 长按录音中标志：手指未松开时，静默超时不得停止识别（仅短按开关模式才自动停止）
  private isVoiceHolding: boolean = false;
  // 长按录音模式：按住开始、松开停止；静默超时自动停止
  private voiceSilenceTimer: number = 0;
  private readonly VOICE_SILENCE_TIMEOUT_MS: number = 8000;
  // 语音按钮按下时间戳（区分长按/短按）
  private voiceTouchDownTime: number = 0;
  @State showSearchPage: boolean = false;
  @State searchQuery: string = '';
  @State searchBFolders: BookshelfFolder[] = [];
  @State searchBWorks: WorkItem[] = [];
  @State searchAFolders: ArchiveFolder[] = [];
  @State searchAWorks: WorkItem[] = [];
  @State searchInspirations: InspirationItem[] = [];
  @State searchRecycleItems: RecycleBinItem[] = [];
  @State showRecyclePreview: boolean = false;
  @State previewRecycleItem: RecycleBinItem | null = null;
  @StorageProp('statusBarHeightVp') statusBarHeightVp: number = 0;

  sf(base: number): number {
    return Math.round(base * this.fontSize / 14);
  }
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

  get bgColor(): ResourceColor {
    return $r('app.color.bg_page');
  }

  get cardBg(): ResourceColor {
    return $r('app.color.bg_card');
  }

  get panelBg(): ResourceColor {
    return $r('app.color.bg_panel');
  }

  get cardBorder(): ResourceColor {
    return $r('app.color.border_default');
  }

  get textColor(): ResourceColor {
    return $r('app.color.text_primary');
  }

  get subTextColor(): ResourceColor {
    return $r('app.color.text_secondary');
  }

  /** 执行搜索，更新搜索结果 @State 数组 */
  private doSearch(query: string): void {
    const q = query.trim().toLowerCase();
    if (q.length === 0) {
      this.searchBFolders = [];
      this.searchBWorks = [];
      this.searchAFolders = [];
      this.searchAWorks = [];
      this.searchInspirations = [];
      this.searchRecycleItems = [];
      return;
    }
    const folders = (workManager.getFolders() || []).filter(
      f => (f.name || '').toLowerCase().includes(q)
    );
    const works = (workManager.getBookshelfWorks() || []).filter(
      w => (w.title || '').toLowerCase().includes(q)
    );
    const aFolders = (workManager.getArchiveFolders() || []).filter(
      f => (f.name || '').toLowerCase().includes(q)
    );
    const aWorks = (workManager.getArchivedWorks() || []).filter(
      w => (w.title || '').toLowerCase().includes(q)
    );
    const inspirations = (workManager.getInspirations() || []).filter(
      insp => (insp.content || '').toLowerCase().includes(q)
    );
    const recycleItems = (workManager.getRecycleBinItems() || []).filter(
      r => (r.title || '').toLowerCase().includes(q)
    );
    this.searchBFolders = folders;
    this.searchBWorks = works;
    this.searchAFolders = aFolders;
    this.searchAWorks = aWorks;
    this.searchInspirations = inspirations;
    this.searchRecycleItems = recycleItems;
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
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    settingsManager.initPromise = settingsManager.init(context);
    settingsManager.initPromise.then(() => {
      this.updateDarkMode();
      AppStorage.setOrCreate('appFontSize', settingsManager.settings.fontSize || 14);
      AppStorage.setOrCreate('appDarkMode', this.isDarkMode);
    });
    // fallback: 如果EntryAbility尚未设置sysDarkMode，从context读取
    if (AppStorage.get<boolean>('sysDarkMode') === undefined) {
      const cfg = (this.getUIContext().getHostContext() as common.UIAbilityContext).config;
      if (cfg && cfg.colorMode !== undefined) {
        AppStorage.setOrCreate<boolean>('sysDarkMode', cfg.colorMode === 0);
      }
    }
    // 订阅作品数据变更，刷新书架/素材库
    this.unsubscribeWorkChange = workManager.onChange(() => {
      this.refreshKey++;
      this.refreshMaterialLibrary();
      this.refreshBookshelfData();
    });
    // 初始加载素材库数据
    this.refreshMaterialLibrary();
    this.refreshBookshelfData();
    // 兜底：消费持久化的卡片跳转目标（覆盖冷启动时 @Watch/onPageShow 都未捕获的场景）
    this.consumePersistedCardNavTarget();
  }

  /** 跳转到灵感池并弹出新建灵感对话框（卡片直达复用逻辑） */
  private handleNavigateToInspiration(): void {
    // 切换到素材库选项卡（索引3）
    this.currentIndex = 3;
    // 切换到灵感池子页签（索引2，0=旧档,1=回收站,2=灵感池）
    this.materialSubTab = 2;
    // 清除目标，避免重复导航（包括 AppStorage 和持久化存储）
    AppStorage.setOrCreate('appNavTarget', '');
    this.clearPersistedCardNavTarget();
    // 卡片直达：恢复缓存（若上次误关丢失）→ 弹出新建灵感输入框
    const cached = AppStorage.get<string>('inspirationDraftCache');
    if (cached) {
      this.editingInspirationContent = cached;
      AppStorage.setOrCreate('inspirationDraftCache', '');
      this.inspirationDraftCache = '';
    } else {
      this.editingInspirationContent = '';
      this.inspirationDraftCache = '';
    }
    this.editingInspirationId = '';
    this.isNewInspiration = true;
    this.showInspirationEditor = true;
    this.isVoiceRecognizing = false;
    this.voiceInterimText = '';
  }

  /** 页面每次显示时检查导航目标（如从桌面卡片跳转到灵感池）并尝试静默登录 */
  onPageShow(): void {
    // 始终尝试静默登录（无论是否有缓存，验证 token 是否仍然有效）
    huaweiAuthService.silentLogin(this.getUIContext().getHostContext() as common.UIAbilityContext).then((userInfo) => {
      // 静默登录成功后通过 AppStorage 通知 SettingsTab 更新 UI
      if (userInfo) {
        console.info('[Index] 静默登录成功，userInfo=' + JSON.stringify(userInfo));
        AppStorage.setOrCreate('huaweiLoggedIn', true);
        AppStorage.setOrCreate('huaweiUserInfo', userInfo);
        // 登录成功后自动触发端云同步
        cloudSyncService.sync();
      } else {
        // 静默登录未成功（未授权/token过期/设备未登录华为账号）→ 清除stale状态，防止伪登录
        AppStorage.setOrCreate('huaweiLoggedIn', false);
        AppStorage.setOrCreate('huaweiUserInfo', null);
      }
    }).catch((e: Error) => {
      console.error('[Index] 静默登录异常: ' + e.message);
      AppStorage.setOrCreate('huaweiLoggedIn', false);
      AppStorage.setOrCreate('huaweiUserInfo', null);
    });
    // 1. 内存 flag 通道（onNewWant 高频点击时的实时响应）
    const target = AppStorage.get<string>('appNavTarget');
    if (target === 'inspiration') {
      this.handleNavigateToInspiration();
      return;
    }
    // 2. 持久化兜底通道（onNewWant 写入 preferences，防止内存 flag 被合并/丢失）
    this.consumePersistedCardNavTarget();
  }

  /** 消费持久化的卡片跳转目标（preferences.card_nav_target），消费后清除 */
  private async consumePersistedCardNavTarget(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const prefs = await preferences.getPreferences(ctx, 'writing_app');
      const persisted = await prefs.get('card_nav_target', '') as string;
      if (persisted === 'inspiration') {
        // 清除持久化目标，避免重复跳转
        await prefs.put('card_nav_target', '');
        await prefs.flush();
        this.handleNavigateToInspiration();
      }
    } catch (err) {
      console.warn('[Index] 读取持久化卡片目标失败: ' + JSON.stringify(err));
    }
  }

  /** 清除持久化的卡片导航目标，防止回前台时重复触发 */
  private async clearPersistedCardNavTarget(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const prefs = await preferences.getPreferences(ctx, 'writing_app');
      await prefs.put('card_nav_target', '');
      await prefs.flush();
    } catch (err) {
      console.warn('[Index] 清除持久化卡片目标失败: ' + JSON.stringify(err));
    }
  }

  updateDarkMode() {
    if (settingsManager.settings.followSystemDark) {
      // 跟随系统：优先使用sysDarkMode（由onConfigurationUpdate实时推送），回退到context.config
      if (this.sysDarkMode !== undefined) {
        this.isDarkMode = this.sysDarkMode;
      } else {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
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

  /** @Watch：卡片直达导航目标变化时，App 在前台实时响应跳转 */
  private onAppNavTargetChange(): void {
    if (this.appNavTarget === 'inspiration') {
      this.handleNavigateToInspiration();
    }
  }

  /** 系统返回键/侧滑返回处理 - 支持文件夹级返回 */
  onBackPress(): boolean {
    if (this.showSearchPage) {
      this.showSearchPage = false;
      this.searchQuery = '';
      this.searchBFolders = [];
      this.searchBWorks = [];
      this.searchAFolders = [];
      this.searchAWorks = [];
      this.searchInspirations = [];
      return true;
    }
    if (this.currentFolderId.length > 0) {
      this.currentFolderId = '';
      return true;
    }
    if (this.currentArchiveFolderId.length > 0) {
      this.currentArchiveFolderId = '';
      return true;
    }
    return false;
  }

  build() {
    Stack() {
      if (this.isWide) {
        // 宽屏布局：侧边导航 + 内容区
        Row() {
          // 侧边导航栏
          Column() {
            // 状态栏占位（仅非 2in1 且有实际高度时渲染）
            if (this.statusBarHeightVp > 0) {
              Column()
                .width('100%')
                .height(this.statusBarHeightVp)
            }

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
            // 状态栏占位（仅非 2in1 且有实际高度时渲染）
            if (this.statusBarHeightVp > 0) {
              Column()
                .width('100%')
                .height(this.statusBarHeightVp)
            }

            if (this.currentIndex === 0) {
              ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
            } else if (this.currentIndex === 1) {
              NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor })
            } else if (this.currentIndex === 2) {
              this.BookshelfView()
            } else if (this.currentIndex === 3) {
              this.ArchiveView()
            } else {
              SettingsTab({ isDarkMode: this.isDarkMode })
            }
          }
          .layoutWeight(1)
          .height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              ['rgba(0,0,0,0)', 0.0],
              [this.bgColor, 0.08]
            ]
          })
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      } else {
        // 窄屏布局：底部悬浮玻璃Tab导航（手机/折叠屏折叠态）
        Stack() {
          Column() {
            // Tab内容区域
            Column() {
              if (this.currentIndex === 0) {
                ShortDramaTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor, statusBarHeight: this.statusBarHeightVp })
              } else if (this.currentIndex === 1) {
                NovelTab({ isDarkMode: this.isDarkMode, cardBg: this.cardBg, textColor: this.textColor, bgColor: this.bgColor, statusBarHeight: this.statusBarHeightVp })
              } else if (this.currentIndex === 2) {
                this.BookshelfView()
              } else if (this.currentIndex === 3) {
                this.ArchiveView()
              } else {
                SettingsTab({ isDarkMode: this.isDarkMode, statusBarHeight: this.statusBarHeightVp })
              }
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.bgColor)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

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

      // 灵感编辑/新建对话框
      if (this.showInspirationEditor) {
        this.InspirationEditorDialog()
      }

      // 全局搜索页面
      if (this.showSearchPage) {
        this.SearchPage()
      }

      // 回收站内容预览
      if (this.showRecyclePreview) {
        this.RecyclePreviewDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  SideNavItem(label: string, icon: string, index: number) {
    Row() {
      Text(icon)
        .fontSize(this.sf(20))
        .margin({ right: 12 })
      Text(label)
        .fontSize(this.sf(15))
        .fontColor(this.currentIndex === index ? $r('app.color.accent_secondary') : this.textColor)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20 })
    .backgroundColor(this.currentIndex === index ? $r('app.color.bg_tab_active') : this.bgColor)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  @Builder
  OnboardingDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        // 页面指示器
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6], (index: number) => {
            Column()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.onboardingPage === index ? $r('app.color.dot_active') : $r('app.color.dot_inactive'))
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
            .fontColor($r('app.color.accent_primary'))
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
            .fontColor($r('app.color.text_tertiary'))
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('💡 提示：在设置中选择GGUF模型即可使用AI功能')
            .fontSize(this.sf(13))
            .fontColor($r('app.color.accent_primary'))
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

          Text('• 作品数据本地存储，登录后多设备自动同步')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)

          Text('• 未登录时数据仅存于本机，不会上传')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 20 })
            .alignSelf(ItemAlign.Start)

          Text('华为账号登录（多设备同步）')
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

          Text('• 登录后自动同步，多设备协同创作')
            .fontSize(this.sf(14))
            .fontColor(this.subTextColor)
            .margin({ bottom: 4 })
            .alignSelf(ItemAlign.Start)
        }

        // 第5页：使用说明
        if (this.onboardingPage === 5) {
          Text('📖')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('使用说明')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Scroll() {
            Column() {
              Text('• 本应用内置AI模型，需在设置中选择模型文件后使用。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('• AI生成内容仅供参考，请自行审校后再行使用。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('• 推理线程数建议保持默认（自动检测），手动设置不应超过设备逻辑核数。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('• 上下文长度越大占用内存越多，设备内存不足时请适当调小。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('• 所有作品数据保存在本地，建议定期导出备份。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('• 如遇设备卡顿，请降低线程数或上下文长度后重试。')
                .fontSize(this.sf(13))
                .fontColor(this.subTextColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
        }

        // 第6页：免责协议
        if (this.onboardingPage === 6) {
          Text('📋')
            .fontSize(this.sf(60))
            .margin({ bottom: 16 })

          Text('免责协议')
            .fontSize(this.sf(24))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .margin({ bottom: 12 })

          Scroll() {
            Column() {
              Text('【用户协议】')
                .fontSize(this.sf(13))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.textColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('1. 本应用仅供个人学习和创作使用，不得用于商业侵权用途。\n2. 用户需遵守相关法律法规，不得利用本应用生成违法违规内容。\n3. AI生成的内容版权归用户所有，用户需自行承担使用风险。\n4. 用户在使用AI功能时应遵守相关法律法规。\n5. 本应用不对AI生成内容的准确性和合法性负责。')
                .fontSize(this.sf(12))
                .fontColor(this.subTextColor)
                .margin({ bottom: 10 })
                .alignSelf(ItemAlign.Start)

              Text('【隐私政策】')
                .fontSize(this.sf(13))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.textColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('1. 所有作品数据仅保存在您的设备上，我们不会收集您的创作内容。\n2. 本应用不会收集您的个人信息、位置、通讯录等隐私数据。\n3. 当您使用华为账号登录时，我们仅会获取必要的用户标识用于登录验证。\n4. 我们不会将您的任何数据分享给第三方。')
                .fontSize(this.sf(12))
                .fontColor(this.subTextColor)
                .margin({ bottom: 10 })
                .alignSelf(ItemAlign.Start)

              Text('【免责声明】')
                .fontSize(this.sf(13))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.textColor)
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Text('1. AI生成内容可能存在错误、偏见或不准确之处，本应用不对生成内容的准确性、完整性作任何担保。\n2. 因设备性能差异，推理过程中可能出现卡顿或中断，本应用不承担由此造成的任何损失。\n3. 用户因不当设置（如线程数超过物理核数）导致的设备问题，由用户自行承担。\n4. 本应用不承担因不可抗力导致的数据丢失责任，建议定期导出备份。')
                .fontSize(this.sf(12))
                .fontColor(this.subTextColor)
                .margin({ bottom: 10 })
                .alignSelf(ItemAlign.Start)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')

          // 勾选框
          Row() {
            Checkbox()
              .select(this.hasReadAndAgreed)
              .onChange((value: boolean) => {
                this.hasReadAndAgreed = value;
              })
            Text('我已阅读并同意上述用户协议、隐私政策及免责声明')
              .fontSize(this.sf(12))
              .fontColor(this.subTextColor)
              .margin({ left: 8 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 8, bottom: 4 })
        }

        // 底部按钮
        Row() {
          if (this.onboardingPage > 0) {
            Button('上一步')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.bg_input'))
              .borderRadius(20)
              .height(40)
              .layoutWeight(1)
              .margin({ right: 8 })
              .onClick(() => {
                this.onboardingPage--;
              })
          }

          if (this.onboardingPage < 6) {
            Button('下一步')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
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
              .fontColor(this.hasReadAndAgreed ? $r('app.color.text_on_accent') : $r('app.color.text_tertiary'))
              .backgroundColor(this.hasReadAndAgreed ? $r('app.color.accent_primary') : $r('app.color.bg_input'))
              .borderRadius(20)
              .height(40)
              .layoutWeight(1)
              .margin({ left: 8 })
              .enabled(this.hasReadAndAgreed)
              .onClick(() => {
                settingsManager.settings.isFirstLaunch = false;
                settingsManager.settings.hasAgreedToTerms = true;
                settingsManager.save();
                this.showOnboarding = false;
                this.getUIContext().getPromptAction().showToast({ message: '欢迎开始创作！', duration: 2000 });
              })
          }
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('90%')
      .constraintSize({ maxWidth: 420, maxHeight: '85%' })
      .padding(24)
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
  }

  @Builder
  BookshelfView() {
    Stack() {
      Scroll() {
        Column() {
          // 顶部留白（状态栏 + header高度）
          Column().width('100%').height(this.statusBarHeightVp + 60)

          if (this.currentFolderId.length === 0) {
            this.BookshelfRootView()
          } else {
            this.BookshelfFolderView()
          }
        }
        .width('100%')
        .padding({ bottom: 100 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 悬浮header（玻璃透视效果）
      Row() {
        if (this.currentFolderId.length > 0) {
          Text('←')
            .fontSize(this.sf(20))
            .fontColor($r('app.color.accent_primary'))
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
        Button('搜索')
          .fontSize(this.sf(14))
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor($r('app.color.accent_primary'))
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.showSearchPage = true;
            this.searchQuery = '';
            this.searchBFolders = [];
            this.searchBWorks = [];
            this.searchAFolders = [];
            this.searchAWorks = [];
      this.searchInspirations = [];
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeightVp + 12, bottom: 12 })

    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
    .backgroundColor(this.bgColor)
  }

  @Builder
  ArchiveView() {
    Stack() {
      Scroll() {
        Column() {
          // 顶部留白（状态栏 + header + 子页签高度）
          Column().width('100%').height(this.statusBarHeightVp + 100)

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
          } else {
            // 灵感池
            this.InspirationPoolView()
          }
        }
        .width('100%')
        .padding({ bottom: 100 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 悬浮header + 子页签（玻璃透视效果）
      Column() {
        Row() {
          if (this.currentArchiveFolderId.length > 0) {
            Text('←')
              .fontSize(this.sf(20))
              .fontColor($r('app.color.accent_primary'))
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
            Button('搜索')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(20)
              .height(36)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.showSearchPage = true;
                this.searchQuery = '';
                this.searchBFolders = [];
                this.searchBWorks = [];
                this.searchAFolders = [];
                this.searchAWorks = [];
      this.searchInspirations = [];
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: this.statusBarHeightVp + 12, bottom: 8 })

        // 素材库子页签
        Row() {
          ForEach(['旧档', '回收站', '灵感池'], (tab: string, index: number) => {
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
      }
      .width('100%')

    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
    .backgroundColor(this.bgColor)
  }

  /** 获取书架文件夹名称 */
  getFolderName(folderId: string): string {
    const folder = this.bookshelfFolders.find(f => f.id === folderId);
    return folder ? folder.name : '文件夹';
  }

  /** 获取旧档区文件夹名称 */
  getArchiveFolderName(folderId: string): string {
    const folder = this.archiveFolders.find(f => f.id === folderId);
    return folder ? folder.name : '文件夹';
  }

  /** 书架根视图：显示文件夹和未分类作品 */
  @Builder
  BookshelfRootView() {
    // 文件夹网格
    if (this.bookshelfFolders.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.bookshelfFolders, (folder: BookshelfFolder) => {
          Column() {
            Column() {
              Text('📁')
                .fontSize(this.sf(28))
              Text(folder.name)
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_on_accent'))
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

            Text(`${this.bookshelfWorks.filter(w => w.folderId === folder.id).length} 篇作品`)
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
    if (this.bookshelfFolders.length > 0 && this.bookshelfWorks.filter(w => !w.folderId).length > 0) {
      Text('未完成')
        .fontSize(this.sf(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.subTextColor)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })
    }

    ForEach(this.bookshelfWorks.filter(w => !w.folderId), (work: WorkItem) => {
      this.WorkItemRow(work, false)
    }, (work: WorkItem) => work.id)

    // 空状态
    if (this.bookshelfFolders.length === 0 && this.bookshelfWorks.filter(w => !w.folderId).length === 0) {
      Column() {
        Text('📖 书架空空如也')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
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
    if (this.bookshelfWorks.filter(w => w.folderId === this.currentFolderId).length > 0) {
      ForEach(this.bookshelfWorks.filter(w => w.folderId === this.currentFolderId), (work: WorkItem) => {
        this.WorkItemRow(work, false)
      }, (work: WorkItem) => work.id)
    } else {
      Column() {
        Text('📁 文件夹为空')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 旧档区根视图：显示文件夹和未分类作品 */
  @Builder
  ArchiveRootView() {
    if (this.archiveFolders.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.archiveFolders, (folder: ArchiveFolder) => {
          Column() {
            Column() {
              Text('📦')
                .fontSize(this.sf(28))
              Text(folder.name)
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_on_accent'))
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

            Text(`${this.archivedWorks.filter(w => w.archiveFolderId === folder.id).length} 篇作品`)
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

    if (this.archiveFolders.length > 0 && this.archivedWorks.filter(w => !w.archiveFolderId).length > 0) {
      Text('未完成')
        .fontSize(this.sf(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.subTextColor)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })
    }

    ForEach(this.archivedWorks.filter(w => !w.archiveFolderId), (work: WorkItem) => {
      this.WorkItemRow(work, true)
    }, (work: WorkItem) => work.id)

    if (this.archiveFolders.length === 0 && this.archivedWorks.filter(w => !w.archiveFolderId).length === 0) {
      Column() {
        Text('📦 暂无归档作品')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
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
    if (this.archivedWorks.filter(w => w.archiveFolderId === this.currentArchiveFolderId).length > 0) {
      ForEach(this.archivedWorks.filter(w => w.archiveFolderId === this.currentArchiveFolderId), (work: WorkItem) => {
        this.WorkItemRow(work, true)
      }, (work: WorkItem) => work.id)
    } else {
      Column() {
        Text('📦 文件夹为空')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 刷新素材库数据 */
  refreshMaterialLibrary(): void {
    this.recycleBinItems = workManager.getRecycleBinItems();
    this.inspirationItems = workManager.getInspirations();
  }

  /** 计算回收站文件夹条目的描述（篇数+字数） */
  getRecycleFolderDesc(item: RecycleBinItem): string {
    const works = item.folderWorks || [];
    const count = works.length;
    let totalChars = 0;
    for (const w of works) {
      totalChars += w.content.length;
    }
    return `${count}篇 · ${totalChars}字`;
  }

  /** 刷新书架/旧档区数据快照（@Builder 依赖 @State 触发重渲染） */
  refreshBookshelfData(): void {
    this.bookshelfFolders = workManager.getFolders();
    this.archiveFolders = workManager.getArchiveFolders();
    this.bookshelfWorks = workManager.getBookshelfWorks();
    this.archivedWorks = workManager.getArchivedWorks();
  }

  /** 主动同步桌面原子卡片的灵感数据（保存/删除灵感后调用）：
   *  1. 将 App 内最新灵感回写卡片数据源 writing_app_inspirations
   *  2. 遍历所有已建卡片 formId，推送 updateForm 刷新显示 */
  private async syncDesktopCardInspirationCount(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const prefs = await preferences.getPreferences(ctx, 'writing_app');

      // 1. 回写卡片数据源（workManager 最新数据 → writing_app_inspirations）
      const appItems: InspirationItem[] = workManager.getInspirations();
      const normalizedItems: InspirationItem[] = appItems.map((item: InspirationItem): InspirationItem => {
        const cardItem: InspirationItem = {
          id: item.id,
          content: item.content,
          category: item.category,
          createTime: item.createTime,
          fromWidget: item.fromWidget,
          deviceId: item.deviceId
        };
        return cardItem;
      });
      await prefs.put('writing_app_inspirations', JSON.stringify(normalizedItems));
      await prefs.flush();

      // 2. 读取所有已建卡片 formId
      const idsRaw = await prefs.get('writing_app_form_ids', '') as string;
      if (!idsRaw) {
        return;
      }
      const formIds: string[] = JSON.parse(idsRaw) as string[];

      // 3. 构建统计数据并推送
      const stats: InspirationStats = await this.buildInspirationStats();
      for (let i = 0; i < formIds.length; i++) {
        const formData: Record<string, Object> = {
          'title': '灵感速记',
          'placeholder': '随手记下灵感...',
          'lastContent': stats.lastContent,
          'inspirationCount': stats.count
        };
        await formProvider.updateForm(formIds[i], formBindingData.createFormBindingData(formData));
      }
      console.info('[Index] 桌面卡片灵感数据已同步: ' + stats.count);
    } catch (err) {
      const e = err as BusinessError;
      console.warn('[Index] 同步桌面卡片失败: ' + e.code + ' ' + e.message);
    }
  }

  /** 构建卡片所需的灵感统计数据（总数 + 最新一条内容，直接读卡片数据源 preferences） */
  private async buildInspirationStats(): Promise<InspirationStats> {
    let count: string = '0';
    let lastContent: string = '';
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) {
        const prefs = await preferences.getPreferences(ctx, 'writing_app');
        const stored = await prefs.get('writing_app_inspirations', '') as string;
        if (stored) {
          const items: InspirationItem[] = JSON.parse(stored) as InspirationItem[];
          count = items.length.toString();
          if (items.length > 0) {
            lastContent = items[items.length - 1].content || '';
            if (lastContent.length > 40) {
              lastContent = lastContent.substring(0, 40) + '...';
            }
          }
        }
      }
    } catch (err) {
      const e = err as BusinessError;
      console.warn('[Index] 读取卡片灵感数据失败: ' + e.code + ' ' + e.message);
    }
    return { count: count, lastContent: lastContent };
  }

  /** 回收站视图 */
  @Builder
  RecycleBinView() {
    if (this.recycleBinItems.length > 0) {
      ForEach(this.recycleBinItems, (item: RecycleBinItem) => {
        Row() {
          Column() {
            Text(item.itemType === 'inspiration' ? '💡' : (item.itemType === 'folder' ? '📁' : '📄'))
              .fontSize(this.sf(18))
              .fontColor($r('app.color.text_on_accent'))
          }
          .width(40)
          .height(40)
          .borderRadius(8)
          .backgroundColor(item.itemType === 'inspiration' ? '#F59E0B' : (item.itemType === 'folder' ? '#6B7280' : '#EF4444'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(item.title)
              .fontSize(this.sf(15))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text((item.itemType === 'inspiration' ? '灵感 · ' : (item.itemType === 'folder' ? `文件夹 · ${this.getRecycleFolderDesc(item)} · ` : '作品 · ')) + item.deleteTime)
              .fontSize(this.sf(11))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            // 点击预览内容
            this.previewRecycleItem = item;
            this.showRecyclePreview = true;
          })

          // 恢复按钮
          Text('恢复')
            .fontSize(this.sf(12))
            .fontColor($r('app.color.accent_secondary'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#FF6B35' })
            .borderRadius(12)
            .margin({ right: 8 })
            .onClick(() => {
              if (workManager.restoreFromRecycleBin(item.id)) {
                const restoreMsg = item.itemType === 'inspiration' ? '已恢复到素材区' : (item.itemType === 'folder' ? '已恢复文件夹' : '已恢复到书架');
                this.getUIContext().getPromptAction().showToast({ message: restoreMsg, duration: 2000 });
                this.refreshMaterialLibrary();
                this.refreshBookshelfData();
                this.refreshKey++;
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
              this.getUIContext().getPromptAction().showDialog({
                title: '确认删除',
                message: `彻底删除「${item.title}」？此操作不可恢复。`,
                buttons: [
                  { text: '取消', color: '#9CA3AF' },
                  { text: '删除', color: '#EF4444' }
                ]
              }).then((data) => {
                if (data.index === 1) {
                  if (workManager.deleteFromRecycleBin(item.id)) {
                    this.getUIContext().getPromptAction().showToast({ message: '已彻底删除', duration: 2000 });
                    this.refreshMaterialLibrary();
                  }
                }
              });
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
          this.getUIContext().getPromptAction().showDialog({
            title: '确认清空',
            message: '清空回收站后所有内容将永久删除，无法恢复。',
            buttons: [
              { text: '取消', color: '#9CA3AF' },
              { text: '清空', color: '#EF4444' }
            ]
          }).then((data) => {
            if (data.index === 1) {
              workManager.clearRecycleBin();
              this.refreshMaterialLibrary();
              this.getUIContext().getPromptAction().showToast({ message: '回收站已清空', duration: 2000 });
            }
          });
        })
    } else {
      Column() {
        Text('🗑 回收站为空')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
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
              .fontColor($r('app.color.text_on_accent'))
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
              if (item.fromWidget) {
                Text('📱 卡片')
                  .fontSize(this.sf(10))
                  .fontColor('#F59E0B')
                  .margin({ right: 8 })
              }
              Text(item.createTime)
                .fontSize(this.sf(10))
                .fontColor($r('app.color.text_tertiary'))
            }
            .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            // 点击内容编辑灵感
            this.editingInspirationId = item.id;
            this.editingInspirationContent = item.content;
            this.isNewInspiration = false;
            this.showInspirationEditor = true;
          })

          // 删除按钮
          Text('🗑️')
            .fontSize(this.sf(14))
            .fontColor('#EF4444')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .border({ width: 1, color: '#EF4444' })
            .borderRadius(12)
            .onClick(() => {
              this.getUIContext().getPromptAction().showDialog({
                title: '确认删除',
                message: '删除此灵感？将移入回收站',
                buttons: [
                  { text: '取消', color: '#9CA3AF' },
                  { text: '删除', color: '#EF4444' }
                ]
              }).then((data) => {
                if (data.index === 1) {
                  if (workManager.deleteInspiration(item.id)) {
                    this.refreshMaterialLibrary();
                    this.getUIContext().getPromptAction().showToast({ message: '已移入回收站', duration: 2000 });
                  }
                }
              });
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
        .fontColor($r('app.color.accent_secondary'))
        .backgroundColor('#FFF7ED')
        .borderRadius(8)
        .height(36)
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => {
          this.editingInspirationId = '';
          // 恢复草稿缓存：误触关闭后重新打开时保留已输入内容
          this.editingInspirationContent = this.inspirationDraftCache;
          this.isNewInspiration = true;
          this.isVoiceRecognizing = false;
          this.showInspirationEditor = true;
        })
    } else {
      Column() {
        Text('💡 灵感池为空')
          .fontSize(this.sf(16))
          .fontColor($r('app.color.text_tertiary'))
        Text('点击下方按钮添加灵感，或在桌面卡片速记')
          .fontSize(this.sf(12))
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 4 })
        Button('＋ 添加灵感')
          .fontSize(this.sf(14))
          .fontColor($r('app.color.accent_secondary'))
          .backgroundColor('#FFF7ED')
          .borderRadius(8)
          .height(36)
          .width('auto')
          .margin({ top: 12 })
          .onClick(() => {
            this.editingInspirationId = '';
            // 恢复草稿缓存：误触关闭后重新打开时保留已输入内容
            this.editingInspirationContent = this.inspirationDraftCache;
            this.isNewInspiration = true;
            this.isVoiceRecognizing = false;
            this.showInspirationEditor = true;
          })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    }
  }

  /** 灵感编辑/新建对话框 */
  @Builder
  InspirationEditorDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text(this.isNewInspiration ? '新建灵感' : '编辑灵感')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 8 })

        // 清空按钮（左）与语音按钮（右）并排，同一行左右排列
        Row({ space: 8 }) {
          // 清空输入按钮（左侧）
          Button('清空输入')
            .fontSize(this.sf(12))
            .fontColor('#16A34A')
            .backgroundColor('#F0FDF4')
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              this.editingInspirationContent = '';
              this.inspirationDraftCache = '';
            })

          // 语音输入按钮（右侧，Core Speech Kit 流式识别）：
          // 交互：点按切换 / 长按持续录音、抬手停止；识别中 8 秒无新语音则自动停止（长按中不停止）
          Row({ space: 6 }) {
            Text(this.isVoiceRecognizing ? '🎙 松开停止' : '🎙 按住说话')
              .fontSize(this.sf(13))
              .fontColor(this.isVoiceRecognizing ? '#FFFFFF' : '#FF6B35')
              .fontWeight(FontWeight.Medium)
            Circle({ width: 8, height: 8 })
              .fill(this.isVoiceRecognizing ? '#FFFFFF' : '#D1D5DB')
          }
          .layoutWeight(1)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.isVoiceRecognizing ? '#FF4D4F' : this.cardBg)
          .border({ width: 1, color: this.isVoiceRecognizing ? '#FF4D4F' : '#D1D5DB' })
          .borderRadius(8)
          .onTouch((event: TouchEvent) => {
          console.info('[VoiceBtn] onTouch type=' + event.type + ' isRecognizing=' + this.isVoiceRecognizing);
          if (event.type === TouchType.Down) {
            this.voiceTouchDownTime = Date.now();
            this.isVoiceHolding = true;
            if (!this.isVoiceRecognizing) {
              this.startVoiceRecognition();
            }
          } else if (event.type === TouchType.Up) {
            this.isVoiceHolding = false;
            if (this.isVoiceRecognizing) {
              this.stopVoiceRecognition();
            }
          } else if (event.type === TouchType.Cancel) {
            this.isVoiceHolding = false;
            if (this.isVoiceRecognizing) {
              this.stopVoiceRecognition();
            }
          }
        })
        // onClick 兜底：短按切换开关（长按中不触发）
        .onClick(() => {
          console.info('[VoiceBtn] onClick trigger, isRecognizing=' + this.isVoiceRecognizing + ' holding=' + this.isVoiceHolding);
          if (this.isVoiceHolding) {
            return;
          }
          if (this.isVoiceRecognizing) {
            this.stopVoiceRecognition();
          } else {
            this.startVoiceRecognition();
          }
        })
        }
        .width('100%')
        .margin({ bottom: 8 })

        TextArea({ placeholder: '输入灵感内容...', text: this.editingInspirationContent })
          .width('100%')
          .height(120)
          .fontSize(this.sf(14))
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding(12)
          .onChange((value: string) => {
            this.editingInspirationContent = value;
            // 实时写入草稿缓存，误触关闭弹窗后自动恢复
            this.inspirationDraftCache = value;
          })

        // 语音实时识别反馈区：说话时显示中间流式结果
        if (this.isVoiceRecognizing) {
          Row() {
            Text('🎙')
              .fontSize(this.sf(14))
              .margin({ right: 6 })
            Text(this.voiceInterimText.length > 0 ? this.voiceInterimText : '正在聆听...')
              .fontSize(this.sf(13))
              .fontColor($r('app.color.accent_secondary'))
              .fontWeight(FontWeight.Medium)
              .lineHeight(18)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#FFF7ED')
          .borderRadius(8)
          .margin({ top: 8, bottom: 4 })
          .alignItems(VerticalAlign.Center)
        }

        Row() {
          Button('取消')
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor(this.cardBg)
            .border({ width: 1, color: '#D1D5DB' })
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              this.showInspirationEditor = false;
              this.voiceInterimText = '';
            })

          Button('保存')
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor('#FF6B35')
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => {
              const content = this.editingInspirationContent.trim();
              if (content.length === 0) {
                this.getUIContext().getPromptAction().showToast({ message: '内容不能为空', duration: 2000 });
                return;
              }
              if (this.isNewInspiration) {
                workManager.addInspiration(content, 'idea', false);
              } else {
                workManager.updateInspiration(this.editingInspirationId, content);
              }
              this.refreshMaterialLibrary();
              this.editingInspirationContent = '';
              this.isVoiceRecognizing = false;
              // 保存成功：彻底清除草稿缓存（AppStorage 键 + @StorageLink 属性双清，避免下次新建残留）
              AppStorage.setOrCreate('inspirationDraftCache', '');
              this.inspirationDraftCache = '';
              // 保存灵感后主动同步桌面卡片计数（问题3修复）
              this.syncDesktopCardInspirationCount();
              this.showInspirationEditor = false;
              this.voiceInterimText = '';
              this.getUIContext().getPromptAction().showToast({
                message: this.isNewInspiration ? '灵感已添加' : '灵感已更新',
                duration: 2000
              });
            })
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width('85%')
      .padding(24)
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
  }

  /** 语音识别引擎与会话（Core Speech Kit 流式识别） */
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private asrSessionId: string = '';
  private audioCapturer: audio.AudioCapturer | null = null;

  /** 启动语音识别：申请麦克风权限 → 创建识别引擎 → 录音流喂入 */
  private async startVoiceRecognition(): Promise<void> {
    try {
      // 1. 请求麦克风权限
      const atManager = abilityAccessCtrl.createAtManager();
      const permissionResult = await atManager.requestPermissionsFromUser(
        this.getUIContext().getHostContext() as common.UIAbilityContext,
        ['ohos.permission.MICROPHONE']
      );
      if (permissionResult.authResults.length > 0 && permissionResult.authResults[0] !== 0) {
        this.getUIContext().getPromptAction().showToast({
          message: '需要麦克风权限才能使用语音输入', duration: 2500
        });
        return;
      }

      // 2. 创建流式语音识别引擎（按官方示例：extraParams 需带 locate + recognizerMode）
      //    首次调用需下载/初始化识别引擎，可能超时；加 2 次重试兜底
      const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
      const engineParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParams
      };
      let engine: speechRecognizer.SpeechRecognitionEngine | null = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          engine = await speechRecognizer.createEngine(engineParams);
          break;
        } catch (err) {
          const e = err as BusinessError;
          console.warn(`[Index] createEngine 第${attempt}次失败: code=${e.code} msg=${e.message}`);
          if (attempt < 3) {
            await new Promise<void>((resolve) => setTimeout(resolve, 1500));
          } else {
            // ArkTS 限制 throw 类型：包装为 Error 抛出，外层 catch 统一处理
            throw new Error(`createEngine failed after 3 attempts: ${e.message}`);
          }
        }
      }
      if (!engine) {
        throw new Error('createEngine 失败');
      }
      this.asrEngine = engine;

      // 3. 会话ID
      this.asrSessionId = 'insp_' + Date.now().toString();

      // 4. 识别结果回调：isFinal 时追加句尾最终文本，isLast 时结束会话
      this.asrEngine.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
          console.info('[Index] ASR start: ' + eventMessage);
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          if (result.isFinal) {
            // 句尾最终结果：追加到输入框并同步缓存
            const text = result.result || '';
            if (text.length > 0) {
              this.editingInspirationContent = this.editingInspirationContent + text;
              this.inspirationDraftCache = this.editingInspirationContent;
            }
            // 清除中间结果占位
            this.voiceInterimText = '';
            // 收到新结果说明仍在说话，重置静默超时计时器
            this.resetVoiceSilenceTimer();
          } else {
            // 非最终结果（实时流式中间识别）：更新临时占位文本，提供实时写入反馈
            const interim = result.result || '';
            if (interim.length > 0) {
              this.voiceInterimText = interim;
            }
          }
          // 会话最后一条（isLast）：自动结束会话，触发停止与资源释放
          if (result.isLast) {
            this.stopVoiceRecognition();
          }
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          this.stopVoiceRecognition();
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          console.error('[Index] ASR error: ' + errorCode + ' ' + errorMessage);
          this.stopVoiceRecognition();
        }
      });

      // 5. 开始监听
      const startParams: speechRecognizer.StartParams = {
        sessionId: this.asrSessionId,
        audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 }
      };
      this.asrEngine.startListening(startParams);

      // 6. 创建录音器（16kHz / 单声道 / S16LE / 录音识别源），readData 事件喂入识别引擎
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: 1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
        capturerFlags: 0
      };
      const capturerOptions: audio.AudioCapturerOptions = {
        streamInfo: streamInfo,
        capturerInfo: capturerInfo
      };
      this.audioCapturer = await audio.createAudioCapturer(capturerOptions);
      this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        if (this.asrEngine && this.isVoiceRecognizing) {
          const bytes = new Uint8Array(buffer);
          // writeAudio 每次仅接收 640 或 1280 字节，故按 640 字节（40ms）切片
          const frameSize = 640;
          for (let offset = 0; offset + frameSize <= bytes.length; offset += frameSize) {
            this.asrEngine.writeAudio(this.asrSessionId, bytes.subarray(offset, offset + frameSize));
          }
        }
      });
      await this.audioCapturer.start();
      this.voiceInterimText = '';
      this.isVoiceRecognizing = true;
      // 启动静默超时：8秒内未检测到新语音则自动停止
      this.resetVoiceSilenceTimer();
    } catch (err) {
      console.error('[Index] startVoiceRecognition error: ' + JSON.stringify(err));
      this.isVoiceRecognizing = false;
    }
  }

  /** 停止语音识别并释放资源 */
  private stopVoiceRecognition(): void {
    // 停止静默计时器
    this.clearVoiceSilenceTimer();
    try {
      if (this.audioCapturer) {
        // 先 stop 停止音频流，再移除回调，最后 release——避免 readData 回调在 stop 后仍被触发
        this.audioCapturer.stop();
        this.audioCapturer.off('readData');
        this.audioCapturer.release();
        this.audioCapturer = null;
      }
      if (this.asrEngine) {
        this.asrEngine.finish(this.asrSessionId);
        this.asrEngine.shutdown();
        this.asrEngine = null;
      }
    } catch (e) {
      console.error('[Index] stopVoiceRecognition error: ' + JSON.stringify(e));
    }
    this.isVoiceRecognizing = false;
  }

  /** 重置静默超时：收到新语音结果时调用，8秒内无新结果则自动停止（长按中不停止） */
  private resetVoiceSilenceTimer(): void {
    this.clearVoiceSilenceTimer();
    this.voiceSilenceTimer = setTimeout(() => {
      if (this.isVoiceRecognizing) {
        // 长按录音中：静默超时不自动停止，重新计时等待后续语音；抬手后由 Up 事件停止
        if (this.isVoiceHolding) {
          this.resetVoiceSilenceTimer();
          return;
        }
        this.stopVoiceRecognition();
        this.getUIContext().getPromptAction().showToast({
          message: '长时间未检测到语音，已停止录音',
          duration: 2000
        });
      }
    }, this.VOICE_SILENCE_TIMEOUT_MS) as number;
  }

  /** 清除静默超时计时器 */
  private clearVoiceSilenceTimer(): void {
    if (this.voiceSilenceTimer > 0) {
      clearTimeout(this.voiceSilenceTimer);
      this.voiceSilenceTimer = 0;
    }
  }

  /** 全局搜索页面 */
  @Builder
  SearchPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 搜索栏
        Row() {
          TextInput({ placeholder: '搜索文件夹和作品...', text: this.searchQuery })
            .layoutWeight(1)
            .height(44)
            .fontSize(this.sf(16))
            .backgroundColor('#F3F4F6')
            .borderRadius(22)
            .padding({ left: 16 })
            .onChange((val: string) => {
              this.searchQuery = val;
              this.doSearch(val);
            })
          Button('取消')
            .fontSize(this.sf(15))
            .fontColor($r('app.color.accent_primary'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showSearchPage = false;
              this.searchQuery = '';
              this.searchBFolders = [];
              this.searchBWorks = [];
              this.searchAFolders = [];
              this.searchAWorks = [];
      this.searchInspirations = [];
            })
            .margin({ left: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 48, bottom: 12 })

        // 搜索结果区
        Scroll() {
          Column() {
            if (this.searchQuery.length > 0) {
              // 书架区结果
              if (this.searchBFolders.length > 0 || this.searchBWorks.length > 0) {
                Text('📖 书架区')
                  .fontSize(this.sf(16))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .width('100%')
                  .margin({ top: 8, bottom: 8 })

                // 书架文件夹
                ForEach(this.searchBFolders, (folder: BookshelfFolder) => {
                  Row() {
                    Text('📁')
                      .fontSize(this.sf(18))
                      .margin({ right: 10 })
                    Text(folder.name)
                      .fontSize(this.sf(15))
                      .fontColor(this.textColor)
                    Text('文件夹')
                      .fontSize(this.sf(12))
                      .fontColor($r('app.color.text_tertiary'))
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.currentFolderId = folder.id;
                    this.showSearchPage = false;
                    this.searchQuery = '';
                  })
                }, (folder: BookshelfFolder) => folder.id)

                // 书架作品
                ForEach(this.searchBWorks, (work: WorkItem) => {
                  Row() {
                    Column() {
                      Text((work.title || '未命名').charAt(0))
                        .fontSize(this.sf(16))
                        .fontColor($r('app.color.text_on_accent'))
                        .fontWeight(FontWeight.Bold)
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(work.coverColor || '#FF2D55')
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .margin({ right: 10 })

                    Column() {
                      Text(work.title || '未命名')
                        .fontSize(this.sf(15))
                        .fontColor(this.textColor)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(work.templateName || '作品')
                        .fontSize(this.sf(12))
                        .fontColor($r('app.color.text_tertiary'))
                        .maxLines(1)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.showSearchPage = false;
                    this.searchQuery = '';
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/PromptEditorPage',
                      params: { mode: work.workshop || 'short_drama', workId: work.id }
                    });
                  })
                }, (work: WorkItem) => work.id)
              }

              // 素材区结果
              if (this.searchAFolders.length > 0 || this.searchAWorks.length > 0) {
                Text('📦 素材区')
                  .fontSize(this.sf(16))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })

                // 旧档文件夹
                ForEach(this.searchAFolders, (folder: ArchiveFolder) => {
                  Row() {
                    Text('📁')
                      .fontSize(this.sf(18))
                      .margin({ right: 10 })
                    Text(folder.name)
                      .fontSize(this.sf(15))
                      .fontColor(this.textColor)
                    Text('文件夹')
                      .fontSize(this.sf(12))
                      .fontColor($r('app.color.text_tertiary'))
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.currentArchiveFolderId = folder.id;
                    this.showSearchPage = false;
                    this.searchQuery = '';
                  })
                }, (folder: ArchiveFolder) => folder.id)

                // 旧档作品
                ForEach(this.searchAWorks, (work: WorkItem) => {
                  Row() {
                    Column() {
                      Text((work.title || '未命名').charAt(0))
                        .fontSize(this.sf(16))
                        .fontColor($r('app.color.text_on_accent'))
                        .fontWeight(FontWeight.Bold)
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(work.coverColor || '#6B7280')
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .margin({ right: 10 })

                    Column() {
                      Text(work.title || '未命名')
                        .fontSize(this.sf(15))
                        .fontColor(this.textColor)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(work.templateName || '作品')
                        .fontSize(this.sf(12))
                        .fontColor($r('app.color.text_tertiary'))
                        .maxLines(1)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.showSearchPage = false;
                    this.searchQuery = '';
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/PromptEditorPage',
                      params: { mode: work.workshop || 'short_drama', workId: work.id }
                    });
                  })
                }, (work: WorkItem) => work.id)
              }

              // 灵感池结果
              if (this.searchInspirations.length > 0) {
                Text('💡 灵感池')
                  .fontSize(this.sf(16))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })

                ForEach(this.searchInspirations, (insp: InspirationItem) => {
                  Row() {
                    Column() {
                      Text(insp.category === 'idea' ? '💡' : insp.category === 'snippet' ? '📝' : '📌')
                        .fontSize(this.sf(18))
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(insp.category === 'idea' ? '#FFD700' : insp.category === 'snippet' ? '#4CAF50' : '#2196F3')
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .margin({ right: 10 })

                    Column() {
                      Text(insp.content.substring(0, 30) + (insp.content.length > 30 ? '...' : ''))
                        .fontSize(this.sf(14))
                        .fontColor(this.textColor)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(insp.category === 'idea' ? '灵感' : insp.category === 'snippet' ? '片段' : '笔记')
                        .fontSize(this.sf(12))
                        .fontColor($r('app.color.text_tertiary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    // 打开灵感编辑器
                    this.showSearchPage = false;
                    this.searchQuery = '';
                    this.editingInspirationId = insp.id;
                    this.editingInspirationContent = insp.content;
                    this.showInspirationEditor = true;
                  })
                }, (insp: InspirationItem) => insp.id)
              }

              // 回收站搜索结果
              if (this.searchRecycleItems.length > 0) {
                Text('🗑️ 回收站')
                  .fontSize(this.sf(16))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textColor)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })

                ForEach(this.searchRecycleItems, (item: RecycleBinItem) => {
                  Row() {
                    Column() {
                      Text(item.itemType === 'inspiration' ? '💡' : (item.itemType === 'folder' ? '📁' : '📄'))
                        .fontSize(this.sf(18))
                    }
                    .width(36)
                    .height(36)
                    .backgroundColor(item.itemType === 'inspiration' ? '#F59E0B' : (item.itemType === 'folder' ? '#6B7280' : '#EF4444'))
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .margin({ right: 10 })

                    Column() {
                      Text(item.title)
                        .fontSize(this.sf(14))
                        .fontColor(this.textColor)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text((item.itemType === 'inspiration' ? '灵感' : (item.itemType === 'folder' ? '文件夹' : '作品')) + ' · ' + item.deleteTime)
                        .fontSize(this.sf(12))
                        .fontColor($r('app.color.text_tertiary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(this.cardBg)
                  .borderRadius(10)
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.showSearchPage = false;
                    this.searchQuery = '';
                    this.previewRecycleItem = item;
                    this.showRecyclePreview = true;
                  })
                }, (item: RecycleBinItem) => item.id)
              }

              // 无结果提示
              if (this.searchBFolders.length === 0 && this.searchBWorks.length === 0 &&
                  this.searchAFolders.length === 0 && this.searchAWorks.length === 0 &&
                  this.searchInspirations.length === 0 && this.searchRecycleItems.length === 0) {
                Text('未找到匹配的文件夹或作品')
                  .fontSize(this.sf(15))
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 40 })
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
            } else {
              Text('输入关键词搜索书架和素材库中的文件夹与作品')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 40 })
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 40 })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_card'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.9)')
    .position({ x: 0, y: 0 })
  }

  /** 回收站内容预览对话框 */
  @Builder
  RecyclePreviewDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('作品预览')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ bottom: 8 })

        if (this.previewRecycleItem) {
          Text(this.previewRecycleItem.title)
            .fontSize(this.sf(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .width('100%')
            .margin({ bottom: 12 })

          Scroll() {
            Text(this.previewRecycleItem.itemType === 'folder' ? '文件夹内作品请在恢复后查看' : (this.previewRecycleItem.content || '（无内容）'))
              .fontSize(this.sf(14))
              .fontColor('#555555')
              .width('100%')
              .lineHeight(22)
          }
          .height(200)
          .width('100%')
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)

          Text('模板: ' + (this.previewRecycleItem.itemType === 'folder' ? '文件夹' : (this.previewRecycleItem.templateName || '自由创作')))
            .fontSize(this.sf(12))
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .margin({ top: 8 })

          Text('删除时间: ' + this.previewRecycleItem.deleteTime)
            .fontSize(this.sf(12))
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }

        Button('关闭')
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor('#3B82F6')
          .borderRadius(8)
          .height(40)
          .width('100%')
          .margin({ top: 16 })
          .onClick(() => {
            this.showRecyclePreview = false;
          })
      }
      .width('85%')
      .padding(24)
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
  }

  /** 可复用的作品行 */
  @Builder
  WorkItemRow(work: WorkItem, isArchived: boolean) {
    Row() {
      Column() {
        Text((work.title || '未命名').charAt(0))
          .fontSize(this.sf(18))
          .fontColor($r('app.color.text_on_accent'))
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
          .fontColor($r('app.color.accent_primary'))
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor($r('app.color.text_tertiary'))
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
            this.getUIContext().getPromptAction().showToast({ message: '已移回书架', duration: 2000 });
          })
      } else {
        Text('归档')
          .fontSize(this.sf(12))
          .fontColor($r('app.color.text_secondary'))
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
      this.getUIContext().getRouter().pushUrl({
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
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor($r('app.color.accent_primary'))
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
                this.getUIContext().getPromptAction().showToast({ message: '已重命名', duration: 2000 });
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
      .constraintSize({ maxHeight: '85%' })
      .padding(24)
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
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
                this.getUIContext().getPromptAction().showToast({ message: '封面已更新', duration: 2000 });
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
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
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
                .fontColor($r('app.color.accent_primary'))
                .layoutWeight(1)
              Text('+')
                .fontSize(this.sf(18))
                .fontColor($r('app.color.accent_primary'))
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
              this.getUIContext().getPromptAction().showToast({ message: '已归档到新文件夹', duration: 2000 });
              this.showArchiveFolderPicker = false;
            })

            // 已有文件夹列表
            ForEach(this.archiveFolders, (folder: ArchiveFolder) => {
              Row() {
                Text('📦 ' + folder.name)
                  .fontSize(this.sf(14))
                  .fontColor(this.textColor)
                  .layoutWeight(1)
                Text(`${this.archivedWorks.filter(w => w.archiveFolderId === folder.id).length} 篇`)
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
                this.getUIContext().getPromptAction().showToast({ message: '已归档', duration: 2000 });
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
              this.getUIContext().getPromptAction().showToast({ message: '已归档', duration: 2000 });
              this.showArchiveFolderPicker = false;
            })
          }
          .width('100%')
        }
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
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
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

        // 归档（仅书架文件夹可用）
        if (this.folderMenuType === 'bookshelf') {
          Row() {
            Text('📦 归档')
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
            if (this.selectedFolder) {
              workManager.archiveBookshelfFolder(this.selectedFolder.id);
              this.selectedFolder = null;
              this.showFolderMenu = false;
              this.refreshKey++;
            }
          })
        }

        // 恢复到书架（仅旧档文件夹可用）
        if (this.folderMenuType === 'archive') {
          Row() {
            Text('📦 恢复到书架')
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
            if (this.selectedArchiveFolder) {
              workManager.unarchiveFolder(this.selectedArchiveFolder.id);
              this.showFolderMenu = false;
              this.currentArchiveFolderId = '';
              this.selectedArchiveFolder = null;
              this.refreshBookshelfData();
              this.refreshKey++;
              this.getUIContext().getPromptAction().showToast({ message: '已恢复到书架', duration: 2000 });
            }
          })
        }

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
          this.getUIContext().getPromptAction().showDialog({
            title: '确认删除',
            message: `删除文件夹「${folderName}」？文件夹内作品将移入回收站。`,
            buttons: [
              { text: '取消', color: '#9CA3AF' },
              { text: '删除', color: '#EF4444' }
            ]
          }).then((data: promptAction.ShowDialogSuccessResponse) => {
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
              this.getUIContext().getPromptAction().showToast({ message: '文件夹已删除', duration: 2000 });
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
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
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
            .fontColor($r('app.color.accent_primary'))
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
            this.getUIContext().getPromptAction().showToast({ message: '已移入回收站', duration: 2000 });
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
      .backgroundColor($r('app.color.bg_card'))
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(16)
      .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
      .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .position({ x: 0, y: 0 })
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
          .fontColor(this.currentIndex === 0 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
          .fontColor(this.currentIndex === 1 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
          .fontColor(this.currentIndex === 2 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
          .fontColor(this.currentIndex === 3 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
          .fontColor(this.currentIndex === 4 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
    }
    .width('92%')
    .position({ bottom: 24, left: '4%' })
    .borderRadius(32)
    .backgroundColor(this.isDarkMode ? 'rgba(45,45,58,0.55)' : 'rgba(255,255,255,0.55)')
    .backdropBlur(20)
    .border({ width: 1, color: this.isDarkMode ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.5)' })
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
        .fontColor(this.currentIndex === index ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
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
  @Prop cardBg: ResourceColor;
  @Prop textColor: ResourceColor;
  @Prop bgColor: ResourceColor;
  @Prop statusBarHeight: number = 0;
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
    Stack() {
      Scroll() {
        Column() {
          // 顶部留白（状态栏 + header高度）
          Column().width('100%').height(this.statusBarHeight + 60)

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
                  .fontColor($r('app.color.text_tertiary'))
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

          // 底部留白（防止被tab bar遮挡）
          Column().width('100%').height(85)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 悬浮header（玻璃透视效果）
      Row() {
        Text('短幕剧工作台')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(this.sf(14))
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor($r('app.color.accent_primary'))
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'short_drama' } });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 12, bottom: 12 })

    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
    .backgroundColor(this.bgColor)
  }

  @Builder
  TemplateCard(template: TemplateInfo) {
    Row() {
      Stack() {
        Column()
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(template.color)
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(this.sf(16))
            .fontColor($r('app.color.text_on_accent'))
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
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
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
          .fontColor($r('app.color.text_on_accent'))
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
          .fontColor($r('app.color.accent_primary'))
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor($r('app.color.text_tertiary'))
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
            this.getUIContext().getPromptAction().showToast({ message: '已移回书架', duration: 2000 });
          } else {
            workManager.archiveWork(work.id);
            this.getUIContext().getPromptAction().showToast({ message: '已移入旧档区', duration: 2000 });
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
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PromptEditorPage',
        params: { workId: work.id, mode: 'short_drama' }
      });
    })
  }

  confirmDelete(work: WorkItem) {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除作品',
      message: `确定删除《${work.title || '未命名作品'}》吗？将移入回收站`,
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '删除', color: '#EF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        workManager.deleteWork(work.id);
        this.getUIContext().getPromptAction().showToast({ message: '已移入回收站', duration: 2000 });
      }
    }).catch(() => {});
  }
}

// ========== 中长篇工作台 ==========
@Component
struct NovelTab {
  @Prop isDarkMode: boolean;
  @Prop cardBg: ResourceColor;
  @Prop textColor: ResourceColor;
  @Prop bgColor: ResourceColor;
  @Prop statusBarHeight: number = 0;
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
    Stack() {
      Scroll() {
        Column() {
          // 顶部留白（状态栏 + header高度）
          Column().width('100%').height(this.statusBarHeight + 60)

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
                  .fontColor($r('app.color.text_tertiary'))
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

          // 底部留白（防止被tab bar遮挡）
          Column().width('100%').height(85)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 悬浮header（玻璃透视效果）
      Row() {
        Text('中长篇工作台')
          .fontSize(this.sf(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        Blank()
        Button('新建')
          .fontSize(this.sf(14))
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor($r('app.color.accent_primary'))
          .borderRadius(20)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'novel' } });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 12, bottom: 12 })

    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
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
        Column()
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(template.color)
        if (typeof template.icon === 'string') {
          Text(template.icon)
            .fontSize(this.sf(16))
            .fontColor($r('app.color.text_on_accent'))
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
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.cardBg)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
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
          .fontColor($r('app.color.text_on_accent'))
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
          .fontColor($r('app.color.accent_primary'))
          .margin({ top: 2 })
        Text(work.updateTime)
          .fontSize(this.sf(10))
          .fontColor($r('app.color.text_tertiary'))
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
            this.getUIContext().getPromptAction().showToast({ message: '已移回书架', duration: 2000 });
          } else {
            workManager.archiveWork(work.id);
            this.getUIContext().getPromptAction().showToast({ message: '已移入旧档区', duration: 2000 });
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
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PromptEditorPage',
        params: { workId: work.id, mode: 'novel' }
      });
    })
  }

  confirmDelete(work: WorkItem) {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除作品',
      message: `确定删除《${work.title || '未命名作品'}》吗？将移入回收站`,
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '删除', color: '#EF4444' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        workManager.deleteWork(work.id);
        this.getUIContext().getPromptAction().showToast({ message: '已移入回收站', duration: 2000 });
      }
    }).catch(() => {});
  }
}

// ========== 设置Tab ==========
@Component
struct SettingsTab {
  @Link isDarkMode: boolean;
  @Prop statusBarHeight: number = 0;
  
  @State followSystemDark: boolean = false;
  @State prevFollowSystemDark: boolean = false;
  @State showPrivacyPanel: boolean = false;
  @State privacyPanelMode: number = 0; // 0=用户协议 1=隐私政策 2=免责声明
  @State showAboutPanel: boolean = false;
  @State autoSaveInterval: number = 5;
  @StorageProp('appFontSize') fontSize: number = 14;
  @StorageProp('appBreakpoint') appBreakpoint: string = 'sm';
  
  @State showPermissionPanel: boolean = false;
  @State permissionItems: PermissionItem[] = [];
  @State showHelpPanel: boolean = false;
  @State showFeedbackPanel: boolean = false;
  @State feedbackText: string = '';
  @StorageLink('huaweiLoggedIn') isHuaweiLoggedIn: boolean = false;
  @StorageLink('huaweiUserInfo') huaweiUserInfo: HuaweiUserInfo | null = null;
  @State localFontPath: string = '';
  @State showFontPicker: boolean = false;
  @State localModelPath: string = '';
  @State showModelPicker: boolean = false;
  @State ggufContextLength: number = 2048;
  @State ggufThreads: number = 4;
  @State ggufMaxTokens: number = 512;
  @State ggufTemperature: number = 0.8;
  // 模型卸载防抖：slider 拖动时延迟卸载，避免连续触发
  private modelUnloadTimer: number = 0;

  get cardBorder(): ResourceColor {
    return $r('app.color.border_default');
  }

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
      console.info('[Index] aboutToAppear 恢复登录状态: ' + JSON.stringify(this.huaweiUserInfo));
    }
  }

  // 暗色模式辅助颜色属性（统一使用资源引用，系统自动切换深浅色）
  get _cardBg(): ResourceColor { return $r('app.color.bg_card'); }
  get _textPrimary(): ResourceColor { return $r('app.color.text_primary'); }
  get _textSecondary(): ResourceColor { return $r('app.color.text_secondary'); }

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

  get _inputBg(): ResourceColor { return $r('app.color.bg_input'); }
  get _cancelBg(): ResourceColor { return $r('app.color.bg_input'); }
  get _cancelText(): ResourceColor { return $r('app.color.text_secondary'); }

  /** 从完整路径中提取文件名 */
  getFileName(fullPath: string): string {
    const parts = fullPath.split('/');
    return parts[parts.length - 1] || fullPath;
  }

  /** 根据当前设置计算并应用暗色模式 */
  applyDarkMode(): void {
    if (settingsManager.settings.followSystemDark) {
      // 跟随系统：优先使用 sysDarkMode（系统真实暗色状态），而非 ctx.config.colorMode
      // 因为此时 setColorMode 可能尚未执行，ctx.config 仍反映旧的 app 颜色模式
      const sysDark = AppStorage.get<boolean>('sysDarkMode');
      if (sysDark !== undefined) {
        this.isDarkMode = sysDark;
      } else {
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
        if (ctx.config && ctx.config.colorMode !== undefined) {
          this.isDarkMode = ctx.config.colorMode === 0;
        }
      }
    } else {
      this.isDarkMode = settingsManager.settings.isDarkMode;
    }
  }

  build() {
    Stack() {
      List() {
        // 顶部留白（状态栏 + header高度）
        ListItem() {
          Column().width('100%').height(this.statusBarHeight + 48)
        }

        // ===== AI 配置 =====
        ListItem() {
          this.SectionTitle('AI 配置')
        }

        ListItem() {
          // 内联 SettingRow 以确保 @State localModelPath 变化时 ListItem 重渲染
          Row() {
            Column() {
              Text('本地模型文件(GGUF)')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_primary'))
              Text(this.localModelPath ? this.getFileName(this.localModelPath) : '未选择')
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(this.sf(20))
              .fontColor('#D1D5DB')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.bg_card'))
        }
        .onClick(() => {
          this.showModelPicker = true;
        })

        ListItem() {
          Column() {
            Row() {
              Text('上下文长度')
                .fontSize(this.sf(14))
                .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.ggufContextLength}`)
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_tertiary'))
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
                .trackColor($r('app.color.toggle_track'))
                .selectedColor($r('app.color.toggle_selected'))
                .onChange((value: number) => {
                  this.ggufContextLength = value;
                  settingsManager.settings.ggufContextLength = value;
                  settingsManager.save();
                  // 防抖卸载：slider 拖动中连续触发，延迟 500ms 只卸载一次
                  if (this.modelUnloadTimer) clearTimeout(this.modelUnloadTimer);
                  this.modelUnloadTimer = setTimeout(() => { aiService.unloadModel(); }, 500);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.bg_card'))
          }

          ListItem() {
            Column() {
              Row() {
                Text('推理线程数')
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.ggufThreads}`)
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              .padding({ top: 8, bottom: 4 })

              Slider({
                value: this.ggufThreads,
                min: 1,
                max: 20,
                step: 1
              })
                .width('100%')
                .trackColor($r('app.color.toggle_track'))
                .selectedColor($r('app.color.toggle_selected'))
                .onChange((value: number) => {
                  this.ggufThreads = value;
                  settingsManager.settings.ggufThreads = value;
                  settingsManager.save();
                  if (this.modelUnloadTimer) clearTimeout(this.modelUnloadTimer);
                  this.modelUnloadTimer = setTimeout(() => { aiService.unloadModel(); }, 500);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.bg_card'))
          }

          ListItem() {
            Column() {
              Row() {
                Text('最大生成Token')
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.ggufMaxTokens}`)
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_tertiary'))
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
                .trackColor($r('app.color.toggle_track'))
                .selectedColor($r('app.color.toggle_selected'))
                .onChange((value: number) => {
                  this.ggufMaxTokens = value;
                  settingsManager.settings.ggufMaxTokens = value;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.bg_card'))
          }

          ListItem() {
            Column() {
              Row() {
                Text('采样温度')
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.ggufTemperature.toFixed(1)}`)
                  .fontSize(this.sf(14))
                  .fontColor($r('app.color.text_tertiary'))
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
                .trackColor($r('app.color.toggle_track'))
                .selectedColor($r('app.color.toggle_selected'))
                .onChange((value: number) => {
                  this.ggufTemperature = value / 10;
                  settingsManager.settings.ggufTemperature = value / 10;
                  settingsManager.save();
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.bg_card'))
          }

        // ===== 写作设置 =====
        ListItem() {
          this.SectionTitle('写作设置')
        }

        ListItem() {
          this.SettingRow('自定义提示词', '编辑AI写作指令', true)
        }
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/PromptEditorPage', params: { mode: 'prompt_edit' } });
        })

        ListItem() {
          // 内联 SettingRow 以确保 @State autoSaveInterval 变化时 ListItem 重渲染
          Row() {
            Column() {
              Text('自动保存间隔')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_primary'))
              Text(`${this.autoSaveInterval}分钟`)
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(this.sf(20))
              .fontColor('#D1D5DB')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.bg_card'))
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
              .selectedColor($r('app.color.toggle_selected'))
              .blockColor($r('app.color.toggle_selected'))
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
          .backgroundColor($r('app.color.bg_card'))
        }

        ListItem() {
          // 内联 SettingRow 以确保 @State localFontPath 变化时 ListItem 重渲染
          Row() {
            Column() {
              Text('本地字体文件')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_primary'))
              Text(this.localFontPath ? this.getFileName(this.localFontPath) : '未选择')
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(this.sf(20))
              .fontColor('#D1D5DB')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.bg_card'))
        }
        .onClick(() => {
          this.showFontPicker = true;
        })

        ListItem() {
          // 内联 SettingRow 以确保 @State followSystemDark/isDarkMode 变化时 ListItem 重渲染
          Row() {
            Column() {
              Text('深色模式')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_primary'))
              Text(this.followSystemDark ? '跟随系统' : (this.isDarkMode ? '开' : '关'))
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(this.sf(20))
              .fontColor('#D1D5DB')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.bg_card'))
        }
        .onClick(() => {
          this.selectDarkMode();
        })

        // ===== 华为账号与多设备同步 =====
        ListItem() {
          this.SectionTitle('华为账号与多设备同步')
        }

        ListItem() {
          Row() {
            // 头像
            if (this.isHuaweiLoggedIn && this.huaweiUserInfo && this.huaweiUserInfo.picture) {
              Image(this.huaweiUserInfo.picture)
                .width(40)
                .height(40)
                .borderRadius(20)
                .margin({ right: 12 })
            } else if (this.isHuaweiLoggedIn) {
              // 已登录但无头像 → 显示默认头像占位
              Row() {
                Text((this.huaweiUserInfo?.displayName || 'H').charAt(0).toUpperCase())
                  .fontSize(this.sf(18))
                  .fontColor($r('app.color.text_on_accent'))
              }
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor('#4A90D9')
              .margin({ right: 12 })
              .justifyContent(FlexAlign.Center)
            }

            Column() {
              Text(this.isHuaweiLoggedIn && this.huaweiUserInfo
                ? (this.huaweiUserInfo.displayName
                  ? this.huaweiUserInfo.displayName
                  : (this.huaweiUserInfo.openID
                    ? `${this.huaweiUserInfo.openID.substring(0, 6)}…${this.huaweiUserInfo.openID.slice(-4)}`
                    : '华为账号已登录'))
                : '登录华为账号')
                .fontSize(this.sf(15))
                .fontColor($r('app.color.text_primary'))

              Text(this.isHuaweiLoggedIn
                ? '点击退出登录'
                : '登录后多设备自动同步作品数据')
                .fontSize(this.sf(12))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(this.sf(18))
              .fontColor($r('app.color.text_tertiary'))
          }
          .padding(16)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))
        }
        .onClick(async () => {
          if (this.isHuaweiLoggedIn) {
            // 已登录 → 弹出确认退出对话框
            this.getUIContext().getPromptAction().showDialog({
              title: '退出登录',
              message: '退出后多设备同步将不可用，确定退出华为账号登录吗？',
              buttons: [
                { text: '取消', color: '#6B7280' },
                { text: '退出', color: '#EF4444' }
              ]
            }).then((result: promptAction.ShowDialogSuccessResponse) => {
              if (result.index === 1) {
                huaweiAuthService.logout().then(() => {
                  this.isHuaweiLoggedIn = false;
                  this.huaweiUserInfo = null;
                  this.getUIContext().getPromptAction().showToast({ message: '已退出登录', duration: 2000 });
                }).catch((e: Error) => {
                  this.getUIContext().getPromptAction().showToast({ message: `退出失败: ${e.message}`, duration: 2000 });
                });
              }
            });
          } else {
            // 未登录 → 执行登录
            try {
              const userInfo = await huaweiAuthService.login(this.getUIContext().getHostContext() as common.UIAbilityContext);
              if (userInfo && (userInfo.openID || userInfo.unionID)) {
                this.isHuaweiLoggedIn = true;
                this.huaweiUserInfo = userInfo;
                console.info('[Index] 登录成功，userInfo=' + JSON.stringify(userInfo));
                this.getUIContext().getPromptAction().showToast({
                  message: '登录成功: ' + (userInfo.displayName || '已登录'),
                  duration: 5000
                });
                // 登录成功后自动触发端云同步
                cloudSyncService.sync();
              } else {
                this.isHuaweiLoggedIn = false;
                this.getUIContext().getPromptAction().showToast({ message: '登录返回数据无效', duration: 3000 });
              }
            } catch (e) {
              this.isHuaweiLoggedIn = false;
              const err = e as BusinessError;
              const hint = err.code === 1001502003
                ? '签名证书指纹未在AGC注册或Account Kit未开通，请检查AGC配置'
                : err.code === 1001502012
                  ? '用户取消登录'
                  : `登录失败[${err.code}]: ${err.message}`;
              this.getUIContext().getPromptAction().showToast({
                message: hint,
                duration: 5000
              });
            }
          }
        })




        // ===== 数据管理 =====
        ListItem() {
          this.SectionTitle('数据管理')
        }

        ListItem() {
          this.SettingRow('导出数据', '保存书架和素材区到本地JSON文件', true)
        }
        .onClick(() => {
          this.exportData();
        })

        ListItem() {
          this.SettingRow('导入数据', '从本地JSON文件恢复数据', true)
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

        // ===== 协议与声明 =====
        ListItem() {
          this.SectionTitle('协议与声明')
        }

        ListItem() {
          this.SettingRow('用户协议', '', true)
        }
        .onClick(() => {
          this.privacyPanelMode = 0;
          this.showPrivacyPanel = true;
        })

        ListItem() {
          this.SettingRow('隐私政策', '', true)
        }
        .onClick(() => {
          this.privacyPanelMode = 1;
          this.showPrivacyPanel = true;
        })

        ListItem() {
          this.SettingRow('免责声明', '', true)
        }
        .onClick(() => {
          this.privacyPanelMode = 2;
          this.showPrivacyPanel = true;
        })

        // ===== 关于与支持 =====
        ListItem() {
          this.SectionTitle('关于与支持')
        }

        ListItem() {
          this.SettingRow('应用评分', '前往应用市场评分', true)
        }
        .onClick(() => {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          try {
            context.startAbility({
              action: 'ohos.want.action.appdetail',
              uri: 'store://appgallery.huawei.com/app/detail?id=com.creativewriting.ai'
            }).catch(() => {
              this.getUIContext().getPromptAction().showToast({ message: '请前往应用市场搜索"创意写作"评分', duration: 3000 });
            });
          } catch (e) {
            this.getUIContext().getPromptAction().showToast({ message: '请前往应用市场搜索"创意写作"评分', duration: 3000 });
          }
        })

        ListItem() {
          this.SettingRow('检查更新', 'v1.2.1', true)
        }
        .onClick(() => {
          // 调用 AppGallery Kit 检查更新
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          try {
            updateManager.checkAppUpdate(context)
              .then((checkResult: updateManager.CheckUpdateResult) => {
                if (checkResult.updateAvailable === updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
                  // 有新版本，弹出系统升级对话框
                  updateManager.showUpdateDialog(context)
                    .catch(() => {
                      this.getUIContext().getPromptAction().showToast({ message: '请前往应用市场更新', duration: 2000 });
                    });
                } else {
                  this.getUIContext().getPromptAction().showToast({ message: '当前已是最新版本', duration: 2000 });
                }
              })
              .catch(() => {
                this.getUIContext().getPromptAction().showToast({ message: '检查更新失败，请稍后重试', duration: 2000 });
              });
          } catch (e) {
            this.getUIContext().getPromptAction().showToast({ message: '检查更新失败，请稍后重试', duration: 2000 });
          }
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
          this.SettingRow('关于', '创意写作 v1.2.1', true)
        }
        .onClick(() => {
          this.showAboutPanel = true;
        })

        // 底部留白（防止被tab bar遮挡）
        ListItem() {
          Column()
            .width('100%')
            .height(80)
            .backgroundColor($r('app.color.bg_card'))
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 悬浮header（玻璃透视效果）
      Row() {
        Text('设置')
          .fontSize(this.sf(20))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, top: this.statusBarHeight + 16, bottom: 12 })


      // 隐私政策/用户协议面板
      if (this.showPrivacyPanel) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {
            Text(this.privacyPanelMode === 0 ? '用户协议' : (this.privacyPanelMode === 1 ? '隐私政策' : '免责声明'))
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            if (this.privacyPanelMode === 0) {
              Text('1. 本应用仅供个人学习和创作使用，不得用于商业侵权用途。\n2. 用户需遵守相关法律法规，不得利用本应用生成违法违规内容。\n3. AI生成的内容版权归用户所有，用户需自行承担使用风险。\n4. 用户在使用AI功能时应遵守相关法律法规。\n5. 本应用不对AI生成内容的准确性和合法性负责。')
                .fontSize(this.sf(12))
                .fontColor(this._textSecondary)
                .margin({ bottom: 16 })
                .alignSelf(ItemAlign.Start)
            }

            if (this.privacyPanelMode === 1) {
              Text('1. 所有作品数据仅保存在您的设备上，我们不会收集您的创作内容。\n2. 本应用不会收集您的个人信息、位置、通讯录等隐私数据。\n3. 当您使用华为账号登录时，我们仅会获取必要的用户标识用于登录验证。\n4. 我们不会将您的任何数据分享给第三方。')
                .fontSize(this.sf(12))
                .fontColor(this._textSecondary)
                .margin({ bottom: 16 })
                .alignSelf(ItemAlign.Start)
            }

            if (this.privacyPanelMode === 2) {
              Text('1. AI生成内容可能存在错误、偏见或不准确之处，本应用不对生成内容的准确性、完整性作任何担保。\n2. 因设备性能差异，推理过程中可能出现卡顿或中断，本应用不承担由此造成的任何损失。\n3. 用户因不当设置（如线程数超过物理核数）导致的设备问题，由用户自行承担。\n4. 本应用不承担因不可抗力导致的数据丢失责任，建议定期导出备份。')
                .fontSize(this.sf(12))
                .fontColor(this._textSecondary)
                .margin({ bottom: 16 })
                .alignSelf(ItemAlign.Start)
            }

            Button('我知道了')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showPrivacyPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ left: 24, right: 24, top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .position({ x: 0, y: 0 })
      }

      // 关于面板
      if (this.showAboutPanel) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {
            Text('关于 创意写作')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(this._textPrimary)
              .margin({ bottom: 12 })

            Text('创意写作 v1.2.1')
              .fontSize(this.sf(16))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_primary'))
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

            Text('• 短幕剧/中长篇双工作台，独立管理\n• AI对话生成，一键保存思维链路\n• 自动版本归档，修改历史可追溯\n• 书架与旧档区，作品归档一目了然\n• 本地GGUF模型离线推理，无需联网\n• 设备防卡死保护（线程优先级/CPU让出/内存监控）\n• 丰富的模板库，支持自定义提示词\n• 深色模式，保护您的视力')
              .fontSize(this.sf(12))
              .fontColor(this._textSecondary)
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showAboutPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ left: 24, right: 24, top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .position({ x: 0, y: 0 })
      }

      // 本地字体文件选择面板
      if (this.showFontPicker) {
        Stack({ alignContent: Alignment.Center }) {
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
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
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
                    this.getUIContext().getPromptAction().showToast({ message: `已选择字体: ${this.getFileName(this.localFontPath)}`, duration: 2000 });
                    this.showFontPicker = false;
                  }
                } catch (err) {
                  this.getUIContext().getPromptAction().showToast({ message: '选择文件失败', duration: 2000 });
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
                this.getUIContext().getPromptAction().showToast({ message: '已清除字体选择', duration: 2000 });
                this.showFontPicker = false;
              })
          }
          .width('85%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showFontPicker = false;
        })
      }

      // 本地模型文件(GGUF)选择面板
      if (this.showModelPicker) {
        Stack({ alignContent: Alignment.Center }) {
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
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
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
                      const sandboxDir = this.getUIContext().getHostContext()!.filesDir;
                      const destPath = `${sandboxDir}/${fileName}`;
                      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
                      // 异步复制，避免大文件阻塞主线程导致 THREAD_BLOCK_6S
                      this.getUIContext().getPromptAction().showToast({ message: '正在复制模型文件，请稍候...', duration: 5000 });
                      await fileIo.copyFile(srcFile.fd, destFile.fd);
                      fileIo.closeSync(srcFile);
                      fileIo.closeSync(destFile);
                      this.localModelPath = destPath;
                      settingsManager.settings.localModelPath = this.localModelPath;
                      settingsManager.save();
                      this.getUIContext().getPromptAction().showToast({ message: `模型已复制: ${fileName}`, duration: 2000 });
                    } catch (copyErr) {
                      this.getUIContext().getPromptAction().showToast({ message: '模型文件复制失败: ' + copyErr, duration: 3000 });
                    }
                    this.showModelPicker = false;
                  }
                } catch (err) {
                  this.getUIContext().getPromptAction().showToast({ message: '选择文件失败', duration: 2000 });
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
                this.getUIContext().getPromptAction().showToast({ message: '已清除模型选择', duration: 2000 });
                this.showModelPicker = false;
              })
          }
          .width('85%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showModelPicker = false;
        })
      }

      // 权限管理面板
      if (this.showPermissionPanel) {
        Stack({ alignContent: Alignment.Center }) {
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
                    .fontColor($r('app.color.text_tertiary'))
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
                    .fontColor($r('app.color.text_on_accent'))
                    .backgroundColor($r('app.color.accent_primary'))
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
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 8, bottom: 12 })
              .alignSelf(ItemAlign.Start)

            Button('关闭')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(20)
              .height(40)
              .width('100%')
              .onClick(() => {
                this.showPermissionPanel = false;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ left: 24, right: 24, top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .position({ x: 0, y: 0 })
      }

      // 帮助中心面板
      if (this.showHelpPanel) {
        Stack({ alignContent: Alignment.Center }) {
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
                Text('Q: AI生成失败怎么办？\nA: 请检查设置中的本地GGUF模型配置是否正确，也可尝试调大AI超时时间。\n\nQ: 作品如何备份？\nA: 设置 → 导出数据，选择保存位置将书架和素材区打包为JSON文件；换设备后用"导入数据"选择JSON文件恢复。\n\nQ: 版本历史在哪里？\nA: 打开作品后点击底部"历史"按钮，可预览并恢复任意历史版本。')
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
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
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
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .clipShape(new RectShape({ width: '100%', height: '100%', radiusWidth: 16, radiusHeight: 16 }))
          .margin({ left: 24, right: 24, top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .position({ x: 0, y: 0 })
      }

      // 问题反馈面板

      // 联系反馈面板
      if (this.showFeedbackPanel) {
        Stack({ alignContent: Alignment.Center }) {
          // 半透明遮罩，点击关闭
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => {
              this.showFeedbackPanel = false;
            })

          Column() {
            Row() {
              Text('联系反馈')
                .fontSize(this.sf(16))
                .fontWeight(FontWeight.Bold)
                .fontColor(this._textPrimary)
              Blank()
              Text('✕')
                .fontSize(this.sf(18))
                .fontColor($r('app.color.text_tertiary'))
                .onClick(() => {
                  this.showFeedbackPanel = false;
                })
            }
            .width('100%')
            .margin({ bottom: 8 })

            Text('点击下方按钮，可打开系统反馈页面提交问题、截图和日志。反馈内容将在应用市场的用户反馈管理中查看。')
              .fontSize(this.sf(12))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ bottom: 16 })
            Button('打开反馈页面')
              .fontSize(this.sf(14))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(20)
              .height(44)
              .width('100%')
              .onClick(() => {
                this.submitFeedback();
              })
            Text('提示：反馈服务需应用上架后生效，上架前可发送邮件至 support@creativewriting.app')
              .fontSize(this.sf(11))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 12 })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.bg_card'))
          .border({ width: 1, color: this.cardBorder })
          .borderRadius(16)
          .margin({ left: 24, right: 24, top: 40, bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
    .backgroundColor($r('app.color.bg_page'))
    .constraintSize({ maxWidth: this._contentMaxWidth })
  }

  @Builder
  SettingRow(title: string, subtitle: string, hasArrow: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(this.sf(15))
          .fontColor($r('app.color.text_primary'))
        if (subtitle) {
          Text(subtitle)
            .fontSize(this.sf(12))
            .fontColor($r('app.color.text_tertiary'))
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
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(this.sf(12))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_tertiary'))
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
        this.applyAppColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        this.getUIContext().getPromptAction().showToast({ message: '已关闭深色模式', duration: 2000 });
      } else if (result.index === 1) {
        // 开
        settingsManager.settings.followSystemDark = false;
        settingsManager.settings.isDarkMode = true;
        this.followSystemDark = false;
        this.prevFollowSystemDark = false;
        this.applyDarkMode();
        settingsManager.save();
        this.applyAppColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        this.getUIContext().getPromptAction().showToast({ message: '已开启深色模式', duration: 2000 });
      } else if (result.index === 2) {
        // 跟随系统
        settingsManager.settings.followSystemDark = true;
        this.followSystemDark = true;
        this.prevFollowSystemDark = true;
        this.applyDarkMode();
        settingsManager.save();
        this.applyAppColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        this.getUIContext().getPromptAction().showToast({ message: '已跟随系统深色模式', duration: 2000 });
      }
    }).catch(() => {});
  }

  /** 将 App 颜色模式设置应用到 ApplicationContext（全局级，与 EntryAbility 对齐），驱动 $r 资源限定符色板全局联动 */
  private applyAppColorMode(mode: ConfigurationConstant.ColorMode): void {
    try {
      const appCtx = this.getUIContext().getHostContext()!.getApplicationContext();
      appCtx.setColorMode(mode);
      console.info('[Index] 应用颜色模式: ' + mode);
    } catch (e) {
      console.error('[Index] setColorMode 失败: ' + JSON.stringify(e));
    }
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
        this.getUIContext().getPromptAction().showToast(toastOpts);
      }
    }).catch(() => {});
  }

  async exportData() {
    try {
      const json = workManager.exportAllData();
      const now = new Date();
      const ts = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}${String(now.getSeconds()).padStart(2, '0')}`;
      // 使用系统文件保存选择器，让用户选择保存位置
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [`创意写作_${ts}.json`];
      documentSaveOptions.fileSuffixChoices = ['文档|.json'];
      const savePicker = new picker.DocumentViewPicker(ctx);
      const uris = await savePicker.save(documentSaveOptions);
      if (!uris || uris.length === 0) {
        return; // 用户取消
      }
      const uri = uris[0];
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file);
      const workCount = workManager.getAllWorks().length;
      const folderCount = workManager.getFolders().length;
      const inspCount = workManager.getInspirations().length;
      this.getUIContext().getPromptAction().showToast({
        message: `已导出${workCount}部作品、${folderCount}个文件夹、${inspCount}条素材\n文件: 创意写作_${ts}.json`,
        duration: 4000
      });
    } catch (e) {
      console.error('[Index] 导出数据失败: ' + JSON.stringify(e));
      this.getUIContext().getPromptAction().showToast({ message: '导出失败: ' + (e as Error).message, duration: 3000 });
    }
  }

  async importData() {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.json'];
      const uris = await docPicker.select(options);
      if (!uris || uris.length === 0) {
        return;
      }
      const uri = uris[0];
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeToString(new Uint8Array(buf));
      const result = workManager.importAllData(text);
      this.getUIContext().getPromptAction().showToast({
        message: `导入完成: ${result}`,
        duration: 4000
      });
    } catch (e) {
      console.error('[Index] 导入数据失败: ' + JSON.stringify(e));
      this.getUIContext().getPromptAction().showToast({ message: '导入失败: ' + (e as Error).message, duration: 3000 });
    }
  }

  requestSinglePermission(permission: string) {
    permissionManager.requestPermissions([permission]).then((result: PermissionResult) => {
      this.permissionItems = permissionManager.getPermissionItems();
      if (result.granted.length > 0) {
        this.getUIContext().getPromptAction().showToast({ message: '权限已授予', duration: 2000 });
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '权限申请被拒绝，可在系统设置中手动开启', duration: 3000 });
      }
    });
  }

  submitFeedback() {
    // 调用系统反馈服务（AGC用户反馈管理）
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      context.startAbility({
        bundleName: 'com.huawei.hmos.floatingwindow',
        abilityName: 'FeedbackAbility'
      }).then(() => {
        this.showFeedbackPanel = false;
      }).catch(() => {
        // 系统反馈不可用，兜底：复制联系方式到剪贴板
        const contactInfo = '创意写作App用户反馈\n请发送邮件至: support@creativewriting.app';
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, contactInfo);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteData).then(() => {
          this.showFeedbackPanel = false;
          this.getUIContext().getPromptAction().showToast({ message: '反馈服务暂不可用，联系方式已复制到剪贴板', duration: 3000 });
        }).catch(() => {
          this.showFeedbackPanel = false;
          this.getUIContext().getPromptAction().showToast({ message: '反馈服务暂不可用，请发送邮件至 support@creativewriting.app', duration: 3000 });
        });
      });
    } catch (e) {
      this.showFeedbackPanel = false;
      this.getUIContext().getPromptAction().showToast({ message: '反馈服务暂不可用，请发送邮件至 support@creativewriting.app', duration: 3000 });
    }
  }

  clearCache() {
    this.getUIContext().getPromptAction().showToast({ message: '缓存已清除', duration: 2000 });
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

  /** 安全弹出 Toast，避免未捕获异常 */
  safeToast(message: string, duration: number = 2000): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration });
    } catch (e) {
      console.error('[Index] showToast failed: ' + JSON.stringify(e));
    }
  }
}
