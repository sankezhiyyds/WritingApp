import UIAbility from '@ohos.app.ability.UIAbility';
import { Configuration } from '@ohos.app.ability.Configuration';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';
import { responsiveManager } from '../model/ResponsiveManager';
import { aiService } from '../model/AIService';
import { permissionManager } from '../model/PermissionManager';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(): void {
    console.info('[EntryAbility] onCreate');
    workManager.init(this.context);
    settingsManager.init(this.context);
    responsiveManager.init(this.context);
    aiService.setContext(this.context);
    permissionManager.init(this.context);
    permissionManager.verifyOnLaunch();

    // 初始化系统深色模式状态（光感自动模式使用）
    const config = this.context.config;
    if (config && config.colorMode !== undefined) {
      AppStorage.setOrCreate<boolean>('sysDarkMode', config.colorMode === 1);
      console.info('[EntryAbility] init sysDarkMode=' + (config.colorMode === 1));
    } else {
      AppStorage.setOrCreate<boolean>('sysDarkMode', false);
    }
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  /** 系统配置变化时回调（深色模式切换等） */
  onConfigurationUpdate(config: Configuration): void {
    console.info('[EntryAbility] onConfigurationUpdate colorMode=' + config.colorMode);
    if (config.colorMode !== undefined) {
      AppStorage.set<boolean>('sysDarkMode', config.colorMode === 1);
    }
  }
}
