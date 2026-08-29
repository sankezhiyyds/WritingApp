import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { workManager } from '../model/WorkManager';
import { settingsManager } from '../model/SettingsManager';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    console.info('[EntryAbility] onCreate');
    workManager.init(this.context);
    settingsManager.init(this.context);
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
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
