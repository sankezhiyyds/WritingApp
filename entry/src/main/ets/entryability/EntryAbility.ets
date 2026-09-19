import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager } from '../model/ResponsiveManager';
import { aiService } from '../model/AIService';
import { permissionManager } from '../model/PermissionManager';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    console.info('[EntryAbility] onCreate');
    console.info('[EntryAbility] VERSION=v4'); // UNIQUE MARKER - should appear in logs if new HAP deployed
    workManager.init(this.context);
    settingsManager.init(this.context);
    responsiveManager.init(this.context);
    aiService.setContext(this.context);
    permissionManager.init(this.context);
    // 初始化全局深色模式到AppStorage
    AppStorage.setOrCreate('appDarkMode', settingsManager.settings.isDarkMode);
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
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

  onForeground(): void {
    console.info('[EntryAbility] onForeground');
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
  }
}
