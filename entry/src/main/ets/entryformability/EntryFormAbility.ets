import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 原子化服务卡片能力
 * 桌面卡片：快速输入灵感，存入素材库-灵感池
 */
export default class EntryFormAbility extends FormExtensionAbility {

  /** 卡片添加到桌面 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    console.info('[EntryFormAbility] onAddForm');
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;

    // 初始化卡片数据
    const formData: Record<string, string> = {
      'title': '灵感速记',
      'placeholder': '随手记下灵感...',
      'lastContent': '',
      'inspirationCount': '0'
    };

    // 保存formId到本地
    this.saveFormId(formId);

    return formBindingData.createFormBindingData(formData);
  }

  /** 卡片更新 */
  onUpdateForm(formId: string): formBindingData.FormBindingData {
    console.info('[EntryFormAbility] onUpdateForm: ' + formId);
    const formData: Record<string, string> = {
      'title': '灵感速记',
      'placeholder': '随手记下灵感...',
      'lastContent': '',
      'inspirationCount': '0'
    };
    // 异步获取灵感数量并更新卡片
    this.getInspirationCount().then((count: string) => {
      formData['inspirationCount'] = count;
      formProvider.updateForm(formId, formBindingData.createFormBindingData(formData))
        .catch((e: BusinessError) => {
          console.error('[EntryFormAbility] 更新卡片失败: ' + e.message);
        });
    });
    return formBindingData.createFormBindingData(formData);
  }

  /** 卡片转为普通形态 */
  onCastToNormalForm(formId: string): formBindingData.FormBindingData {
    console.info('[EntryFormAbility] onCastToNormalForm: ' + formId);
    return formBindingData.createFormBindingData({
      'title': '灵感速记',
      'placeholder': '随手记下灵感...'
    });
  }

  /** 卡片从桌面移除 */
  onRemoveForm(formId: string): void {
    console.info('[EntryFormAbility] onRemoveForm: ' + formId);
    this.removeFormId(formId);
  }

  /** 保存灵感到本地（灵感池） */
  private async saveInspiration(content: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app');
      // 读取现有灵感列表
      const stored = await prefs.get('writing_app_inspirations', '') as string;
      let inspirations: Array<Record<string, string>> = [];
      if (stored) {
        inspirations = JSON.parse(stored) as Array<Record<string, string>>;
      }
      // 添加新灵感
      const newInspiration: Record<string, string> = {
        'id': Date.now().toString() + Math.floor(Math.random() * 1000).toString(),
        'content': content,
        'category': 'idea',
        'createTime': new Date().toISOString(),
        'fromWidget': 'true'
      };
      inspirations.push(newInspiration);
      // 保存回preferences
      await prefs.put('writing_app_inspirations', JSON.stringify(inspirations));
      await prefs.flush();
      console.info('[EntryFormAbility] 灵感已保存: ' + content.substring(0, 20));
    } catch (e) {
      console.error('[EntryFormAbility] 保存灵感失败: ' + JSON.stringify(e));
    }
  }

  /** 获取灵感数量（异步） */
  private async getInspirationCount(): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app');
      const stored = await prefs.get('writing_app_inspirations', '') as string;
      if (stored) {
        const arr = JSON.parse(stored) as Array<Record<string, string>>;
        return arr.length.toString();
      }
    } catch (e) {
      console.error('[EntryFormAbility] 获取灵感数量失败: ' + JSON.stringify(e));
    }
    return '0';
  }

  /** 保存formId */
  private async saveFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'form_ids');
      const stored = await prefs.get('ids', '') as string;
      let ids: string[] = [];
      if (stored) {
        ids = JSON.parse(stored) as string[];
      }
      ids.push(formId);
      await prefs.put('ids', JSON.stringify(ids));
      await prefs.flush();
    } catch (e) {
      console.error('[EntryFormAbility] 保存formId失败: ' + JSON.stringify(e));
    }
  }

  /** 移除formId */
  private async removeFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'form_ids');
      const stored = await prefs.get('ids', '') as string;
      if (stored) {
        let ids = JSON.parse(stored) as string[];
        ids = ids.filter(id => id !== formId);
        await prefs.put('ids', JSON.stringify(ids));
        await prefs.flush();
      }
    } catch (e) {
      console.error('[EntryFormAbility] 移除formId失败: ' + JSON.stringify(e));
    }
  }
}
