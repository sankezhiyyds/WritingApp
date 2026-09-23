import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager } from '../model/ResponsiveManager';
import { aiService } from '../model/AIService';
import { permissionManager } from '../model/PermissionManager';
import { huaweiAuthService } from '../model/HuaweiAuthService';
import { cloudSyncService } from '../model/CloudSyncService';
import { distributedSyncService } from '../model/DistributedSyncService';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    console.info('[EntryAbility] onCreate');
    console.info('[EntryAbility] VERSION=v5');
    workManager.init(this.context);
    settingsManager.init(this.context);
    responsiveManager.init(this.context);
    aiService.setContext(this.context);
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

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
    cloudSyncService.destroy();
    distributedSyncService.destroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');

    // 配置窗口避免摄像头挖空遮挡（通过 ArkUI 组件属性 expandSafeArea 处理更安全）
    // 键盘避让由 ArkUI 自动处理（RESIZE 模式）
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error('[EntryAbility] loadContent failed: ' + JSON.stringify(err));
        return;
      }
      console.info('[EntryAbility] loadContent succeeded');
    });
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
    // 尝试静默登录（若已授权则自动登录，不拉起登录页）
    if (!huaweiAuthService.isLoggedIn()) {
      huaweiAuthService.silentLogin().then((userInfo) => {
        if (userInfo) {
          console.info('[EntryAbility] 静默登录成功');
          // 若启用了自动同步，触发云同步
          if (cloudSyncService.isAutoSyncEnabled()) {
            cloudSyncService.sync();
          }
        }
      });
    }
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
  }
}
