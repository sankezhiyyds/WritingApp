import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager } from '../model/ResponsiveManager';
import { permissionManager } from '../model/PermissionManager';
import { huaweiAuthService } from '../model/HuaweiAuthService';
import { cloudSyncService } from '../model/CloudSyncService';
import { distributedSyncService } from '../model/DistributedSyncService';

export default class EntryAbility extends UIAbility {
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
    // 初始化华为账号认证服务
    huaweiAuthService.init(this.context);
    // 初始化云空间同步服务
    cloudSyncService.init(this.context);
    // 初始化多端协同服务
    distributedSyncService.init(this.context);
    // 初始化全局深色模式到AppStorage
    AppStorage.setOrCreate('appDarkMode', settingsManager.settings.isDarkMode);
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
    cloudSyncService.destroy();
    distributedSyncService.destroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');

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
  private applyWindowExtensionBar(windowStage: window.WindowStage): void {
    try {
      const mainWin = windowStage.getMainWindowSync();
      // 设置全屏布局，让内容延伸到状态栏和导航栏下方
      mainWin.setWindowLayoutFullScreen(true);
      // 设置状态栏和导航栏的属性（透明背景+深色内容）
      mainWin.setWindowSystemBarProperties({
        statusBarColor: '0x00000000',
        statusBarContentColor: '0xFF000000',
        navigationBarColor: '0x00000000',
        navigationBarContentColor: '0xFF000000'
      });
      // 显示底部导航指示条
      mainWin.setSpecificSystemBarEnabled('navigationIndicator', true);
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

  onConfigurationUpdate(newConfig: Record<string, Object>): void {
    // 系统深色模式切换时同步到 AppStorage
    const colorMode = newConfig.colorMode as number;
    if (colorMode !== undefined) {
      AppStorage.setOrCreate('sysDarkMode', colorMode === 0);
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
  }
}
