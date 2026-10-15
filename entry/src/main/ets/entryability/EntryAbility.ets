import { UIAbility, Want, AbilityConstant, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { SuppressWarnings, SuppressWarningsType } from '@ohos.annotation';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager } from '../model/ResponsiveManager';
import { permissionManager } from '../model/PermissionManager';
import { systemResourceMonitor } from '../model/SystemResourceMonitor';

export default class EntryAbility extends UIAbility {
  private storedWindowStage: window.WindowStage | null = null;
  /** 从 want 参数中提取卡片跳转目标，与 onNewWant 共用逻辑 */
  private processCardWant(want: Want | undefined): void {
    if (!want || !want.parameters) {
      return;
    }
    const params = want.parameters;
    let target: string = '';
    const direct = params['target'];
    if (typeof direct === 'string') {
      target = direct;
    } else {
      const nested = params['params'] as Record<string, Object>;
      if (nested) {
        const nestedTarget = nested['target'];
        if (typeof nestedTarget === 'string') {
          target = nestedTarget;
        }
      }
    }
    if (target === 'inspiration') {
      this.persistCardNavTarget('inspiration');
      AppStorage.setOrCreate('appNavTarget', 'inspiration');
    }
  }

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate');
    console.info('[EntryAbility] VERSION=v5');
    // 冷启动：处理来自原子卡片的跳转目标
    this.processCardWant(want);
    workManager.init(this.context);
    settingsManager.init(this.context);
    responsiveManager.init(this.context);
    permissionManager.init(this.context);
    // 初始化热管理监控，防止CPU过热导致设备卡死重启
    systemResourceMonitor.initThermalMonitor();
    // 等待设置从磁盘加载完成后，再初始化全局深色模式到AppStorage并恢复颜色模式
    // 必须在 initPromise 完成后再读 settings，否则会拿到内存默认值（全false），
    // 导致每次冷启动都重置为浅色，手动深色设置丢失
    settingsManager.initPromise?.then(() => {
      AppStorage.setOrCreate('appDarkMode', settingsManager.settings.isDarkMode);
      this.applyColorModeFromSettings();
    });
  }

  /** 根据已保存设置恢复 App 颜色模式：手动深色→DARK，手动浅色→LIGHT，跟随系统→NOT_SET。
   * 使用 ApplicationContext 级 setColorMode（文档推荐的全局设置），驱动 $r 资源限定符色板全局联动 */
  private applyColorModeFromSettings(): void {
    try {
      const appContext = this.context.getApplicationContext();
      if (settingsManager.settings.followSystemDark) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      } else if (settingsManager.settings.isDarkMode) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      }
      console.info('[EntryAbility] 恢复颜色模式: followSystem=' + settingsManager.settings.followSystemDark + ', isDark=' + settingsManager.settings.isDarkMode);
    } catch (e) {
      console.error('[EntryAbility] applyColorModeFromSettings 失败: ' + JSON.stringify(e));
    }
  }

  /** 处理从桌面原子卡片的跳转（热启动/前台时） */
  onNewWant(want: Want): void {
    console.info('[EntryAbility] onNewWant raw: ' + JSON.stringify(want.parameters));
    this.processCardWant(want);
  }

  /** 持久化卡片跳转目标到 preferences，Index 页 onPageShow/@Watch 兜底消费 */
  private async persistCardNavTarget(target: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app');
      await prefs.put('card_nav_target', target);
      await prefs.put('card_nav_ts', String(Date.now()));
      await prefs.flush();
    } catch (err) {
      console.warn('[EntryAbility] 持久化卡片目标失败: ' + JSON.stringify(err));
    }
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');
    this.storedWindowStage = windowStage;

    // 配置窗口全屏模式：内容延伸到状态栏和导航栏区域
    this.applyWindowExtensionBar(windowStage);
    // 键盘避让由 ArkUI 自动处理（RESIZE 模式）
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error('[EntryAbility] loadContent failed: ' + JSON.stringify(err));
        return;
      }
      console.info('[EntryAbility] loadContent succeeded');
    });
  }

  /**
   * 配置窗口扩展区域，让页面内容铺满整个屏幕（覆盖状态栏和导航栏）
   * 设置状态栏和导航栏透明，隐藏底部导航指示条，实现沉浸式全屏效果
   */
  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private applyWindowExtensionBar(windowStage: window.WindowStage): void {
    try {
      const mainWin = windowStage.getMainWindowSync();
      // 设置全屏布局，让内容延伸到状态栏和导航栏下方（2in1设备不支持此API）
      if (deviceInfo.deviceType !== '2in1') {
        mainWin.setWindowLayoutFullScreen(true).catch((e: Error) => console.error('[EntryAbility] setWindowLayoutFullScreen: ' + JSON.stringify(e)));
      }
      // 根据当前颜色模式设置系统栏内容色（深色模式用白色，浅色模式用黑色）
      this.updateSystemBarContentColor(mainWin);
      // 显示底部导航指示条（2in1设备不支持此API）
      if (deviceInfo.deviceType !== '2in1') {
        mainWin.setSpecificSystemBarEnabled('navigationIndicator', true).catch((err: Error) => {
          console.error('[EntryAbility] setSpecificSystemBarEnabled failed: ' + JSON.stringify(err));
        });
      }
      // 获取状态栏高度（px→vp），存入 AppStorage 供 UI 层做顶部占位
      const avoidArea = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const statusBarPx: number = avoidArea.topRect.height;
      const statusBarVp: number = px2vp(statusBarPx);
      const bottomBarPx: number = avoidArea.bottomRect.height;
      const bottomBarVp: number = px2vp(bottomBarPx);
      const is2in1 = deviceInfo.deviceType === '2in1';
      AppStorage.setOrCreate('statusBarHeightVp', is2in1 ? 0 : statusBarVp);
      AppStorage.setOrCreate('bottomAvoidHeightVp', is2in1 ? 0 : bottomBarVp);
      AppStorage.setOrCreate('is2in1Device', is2in1);
      console.info('[EntryAbility] applyWindowExtensionBar: fullscreen configured, statusBarVp=' + statusBarVp + ', bottomBarVp=' + bottomBarVp + ', is2in1=' + is2in1);
    } catch (err) {
      console.error('[EntryAbility] applyWindowExtensionBar error: ' + JSON.stringify(err));
    }
  }

  /** 根据颜色模式更新状态栏/导航栏内容色 */
  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private updateSystemBarContentColor(mainWin: window.Window): void {
    if (deviceInfo.deviceType !== '2in1') {
      const colorMode = this.context.config.colorMode;
      // 0 = DARK, 1 = LIGHT, -1 = NOT_SET
      const isDark = colorMode === 0;
      const contentColor = isDark ? '0xFFFFFFFF' : '0xFF000000';
      mainWin.setWindowSystemBarProperties({ statusBarColor: '0x00000000', statusBarContentColor: contentColor, navigationBarColor: '0x00000000', navigationBarContentColor: contentColor }).catch((e: Error) => console.error('[EntryAbility] setWindowSystemBarProperties: ' + JSON.stringify(e)));
    }
  }

  onConfigurationUpdate(newConfig: Record<string, Object>): void {
    // 系统深色模式切换时同步到 AppStorage
    // 手动模式下（followSystemDark=false）不更新 sysDarkMode，避免反向覆盖手动选择：
    // Index.onSysDarkModeChange 的守卫依赖 settingsManager.settings，若 init 异步未完成会读默认值导致守卫失效
    const colorMode = newConfig.colorMode as number;
    if (colorMode !== undefined) {
      if (settingsManager.settings.followSystemDark) {
        AppStorage.setOrCreate('sysDarkMode', colorMode === 0);
      }
      // 色板变化时更新系统栏内容色（手动/跟随系统都需同步，避免状态栏文字与色板不匹配）
      try {
        if (this.storedWindowStage) {
          const mainWin = this.storedWindowStage.getMainWindowSync();
          this.updateSystemBarContentColor(mainWin);
        }
      } catch (err) {
        console.warn('[EntryAbility] onConfigurationUpdate: failed to update system bar color: ' + JSON.stringify(err));
      }
    }
  }

  onForeground(): void {
    console.info('[EntryAbility] onForeground');
    // 静默登录移至 Index.onPageShow（需要 UI 就绪后的实时 context）
    // App 回到前台时，持久化兜底消费卡片跳转目标（防止高频点击时 onNewWant 被合并丢失）
    this.consumePersistedCardNavTargetForForeground();
  }

  /** App 回前台时检查并消费持久化的卡片跳转目标 */
  private async consumePersistedCardNavTargetForForeground(): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app');
      const persisted = await prefs.get('card_nav_target', '') as string;
      if (persisted === 'inspiration') {
        await prefs.put('card_nav_target', '');
        await prefs.flush();
        AppStorage.setOrCreate('appNavTarget', 'inspiration');
        console.info('[EntryAbility] onForeground 消费持久化卡片目标');
      }
    } catch (err) {
      console.warn('[EntryAbility] 前台消费持久化卡片目标失败: ' + JSON.stringify(err));
    }
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
    // 进入后台立即同步落盘，防系统杀进程丢数据
    try {
      workManager.forceSaveToDisk();
    } catch (_e) {
      console.warn('[EntryAbility] forceSaveToDisk on background failed');
    }
  }
}
