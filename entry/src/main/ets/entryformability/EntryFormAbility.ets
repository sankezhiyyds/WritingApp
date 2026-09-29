import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';

/** 灵感数据 */
interface InspirationData {
  id: string;
  content: string;
  category: string;
  createTime: string;
  fromWidget: string;
  deviceId: string;
}

/** 灵感统计 */
interface InspirationStats {
  count: string;
  lastContent: string;
}

/** 卡片表单数据 */
interface CardFormData {
  title: string;
  placeholder: string;
  lastContent: string;
  inspirationCount: string;
}

/**
 * 原子化服务卡片能力
 * 桌面卡片：快速输入灵感，存入素材库-灵感池
 */
export default class EntryFormAbility extends FormExtensionAbility {

  /** 卡片添加到桌面 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    console.info('[EntryFormAbility] onAddForm');
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;

    // 保存formId到本地
    this.saveFormId(formId);

    const formData: CardFormData = {
      title: '灵感速记',
      placeholder: '随手记下灵感...',
      lastContent: '',
      inspirationCount: '0'
    };

    // 异步更新
    this.getInspirationStats().then((stats: InspirationStats) => {
      const updatedData: CardFormData = {
        title: formData.title,
        placeholder: formData.placeholder,
        lastContent: stats.lastContent,
        inspirationCount: stats.count
      };
      formProvider.updateForm(formId, formBindingData.createFormBindingData(updatedData as object))
        .catch((e: BusinessError) => {
          console.error('[EntryFormAbility] updateForm on addForm failed: ' + e.message);
        });
    });

    return formBindingData.createFormBindingData(formData as object);
  }

  /** 卡片更新 */
  onUpdateForm(formId: string): void {
    console.info('[EntryFormAbility] onUpdateForm: ' + formId);
    this.getInspirationStats().then((stats: InspirationStats) => {
      const formData: CardFormData = {
        title: '灵感速记',
        placeholder: '随手记下灵感...',
        lastContent: stats.lastContent,
        inspirationCount: stats.count
      };
      formProvider.updateForm(formId, formBindingData.createFormBindingData(formData as object))
        .catch((e: BusinessError) => {
          console.error('[EntryFormAbility] 更新卡片失败: ' + e.message);
        });
    });
  }

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
      let inspirations: InspirationData[] = [];
      if (stored) {
        inspirations = JSON.parse(stored) as InspirationData[];
      }
      // 添加新灵感
      const newItem: InspirationData = {
        id: Date.now().toString(),
        content: content,
        category: 'idea',
        createTime: this.formatDate(new Date()),
        fromWidget: 'true',
        deviceId: ''
      };
      inspirations.push(newItem);
      await prefs.put('writing_app_inspirations', JSON.stringify(inspirations));
      await prefs.flush();
    } catch (e) {
      console.error('[EntryFormAbility] 保存灵感失败: ' + JSON.stringify(e));
    }
  }

  /** 获取灵感统计：数量和最近内容 */
  private async getInspirationStats(): Promise<InspirationStats> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app');
      const stored = await prefs.get('writing_app_inspirations', '') as string;
      if (stored) {
        const inspirations = JSON.parse(stored) as InspirationData[];
        const count = inspirations.length.toString();
        const lastContent = inspirations.length > 0
          ? (inspirations[inspirations.length - 1].content || '')
          : '';
        const stats: InspirationStats = { count: count, lastContent: lastContent };
        return stats;
      }
    } catch (e) {
      console.error('[EntryFormAbility] 读取灵感统计失败: ' + JSON.stringify(e));
    }
    const empty: InspirationStats = { count: '0', lastContent: '' };
    return empty;
  }

  /** 保存formId */
  private async saveFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app_form_ids');
      const stored = await prefs.get('form_ids', '[]') as string;
      const ids = JSON.parse(stored) as string[];
      if (!ids.includes(formId)) {
        ids.push(formId);
        await prefs.put('form_ids', JSON.stringify(ids));
        await prefs.flush();
      }
    } catch (e) {
      console.error('[EntryFormAbility] 保存formId失败: ' + JSON.stringify(e));
    }
  }

  /** 移除formId */
  private async removeFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'writing_app_form_ids');
      const stored = await prefs.get('form_ids', '[]') as string;
      const ids = JSON.parse(stored) as string[];
      const idx = ids.indexOf(formId);
      if (idx !== -1) {
        ids.splice(idx, 1);
        await prefs.put('form_ids', JSON.stringify(ids));
        await prefs.flush();
      }
    } catch (e) {
      console.error('[EntryFormAbility] 移除formId失败: ' + JSON.stringify(e));
    }
  }

  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    const h = String(date.getHours()).padStart(2, '0');
    const min = String(date.getMinutes()).padStart(2, '0');
    return `${y}-${m}-${d} ${h}:${min}`;
  }
}
