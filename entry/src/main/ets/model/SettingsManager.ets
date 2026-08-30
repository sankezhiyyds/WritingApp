import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export interface SettingsData {
  apiKey: string;
  selectedModel: string;
  customUrl: string;
  customPrompt: string;
  isFirstLaunch: boolean;
  hasAgreedToTerms: boolean;
  followSystemDark: boolean;
  autoSaveInterval: number;
  fontSize: number;
  aiTimeout: number;
}

export class SettingsManager {
  private prefs: preferences.Preferences | null = null;
  private storageKey: string = 'writing_app_settings';
 private defaultSettings: SettingsData = {
    apiKey: '',
    selectedModel: 'deepseek',
    customUrl: '',
    customPrompt: '',
    isFirstLaunch: true,
    hasAgreedToTerms: false,
    followSystemDark: false,
    autoSaveInterval: 5,
    fontSize: 14,
    aiTimeout: 30
  };

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, 'writing_app');
      const stored = await this.prefs.get(this.storageKey, '') as string;
      if (stored) {
        const parsed = JSON.parse(stored) as SettingsData;
        this.settings = {
          apiKey: parsed.apiKey || '',
          selectedModel: parsed.selectedModel || 'deepseek',
          customUrl: parsed.customUrl || '',
          customPrompt: parsed.customPrompt || '',
          isFirstLaunch: parsed.isFirstLaunch !== undefined ? parsed.isFirstLaunch : true,
          hasAgreedToTerms: parsed.hasAgreedToTerms || false,
          followSystemDark: parsed.followSystemDark || false
        };
      }
    } catch (e) {
      console.error('[SettingsManager] 初始化失败: ' + JSON.stringify(e));
    }
  }

  async save(): Promise<void> {
    if (!this.prefs) return;
    try {
      await this.prefs.put(this.storageKey, JSON.stringify(this.settings));
      await this.prefs.flush();
    } catch (e) {
      console.error('[SettingsManager] 保存设置失败: ' + JSON.stringify(e));
    }
  }
}

export const settingsManager = new SettingsManager();
