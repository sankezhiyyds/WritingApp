import { templateList } from '../../model/TemplateModel';
import promptAction from '@ohos.promptAction';

export default class EntryAbility {
  onCreate() {
    console.log('[EntryAbility] onCreate');
  }

  onDestroy() {
    console.log('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage) {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        promptAction.showToast({ message: '加载失败', duration: 2000 });
        return;
      }
    });
  }

  onForeground() {
    console.log('[EntryAbility] onForeground');
  }

  onBackground() {
    console.log('[EntryAbility] onBackground');
  }
}
