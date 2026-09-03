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
  isDarkMode: boolean;
  autoSaveInterval: number;
  fontSize: number;
  aiTimeout: number;
  isLoggedIn: boolean;
  userName: string;
  grantedPermissions: string[];
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
    isDarkMode: false,
    autoSaveInterval: 5,
    fontSize: 14,
    aiTimeout: 30,
    isLoggedIn: false,
    userName: '',
    grantedPermissions: []
  };
  settings: SettingsData = this.defaultSettings;
  initPromise: Promise<void> | null = null;

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
          followSystemDark: parsed.followSystemDark || false,
          isDarkMode: parsed.isDarkMode !== undefined ? parsed.isDarkMode : false,
          autoSaveInterval: parsed.autoSaveInterval || 5,
          fontSize: parsed.fontSize || 14,
          aiTimeout: parsed.aiTimeout || 30,
          isLoggedIn: parsed.isLoggedIn || false,
          userName: parsed.userName || '',
          grantedPermissions: Array.isArray(parsed.grantedPermissions) ? parsed.grantedPermissions : []
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
