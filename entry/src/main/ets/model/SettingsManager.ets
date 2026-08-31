import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export type ThemeMode = 'system' | 'light' | 'dark';

export interface SettingsData {
  apiKey: string;
  selectedModel: string;
  customUrl: string;
  customPrompt: string;
  isFirstLaunch: boolean;
  hasAgreedToTerms: boolean;
  themeMode: ThemeMode;
  autoSaveInterval: number;
  fontSize: number;
  aiTimeout: number;
  isLoggedIn: boolean;
  userName: string;
  followSystemDark: boolean;
  isDarkMode: boolean;
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
    themeMode: 'system',
    autoSaveInterval: 5,
    fontSize: 14,
    aiTimeout: 30,
    isLoggedIn: false,
    userName: '',
    followSystemDark: true,
    isDarkMode: false
  };
  settings: SettingsData = this.defaultSettings;

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
          themeMode: (parsed.themeMode || 'system') as ThemeMode,
          autoSaveInterval: parsed.autoSaveInterval || 5,
          fontSize: parsed.fontSize || 14,
          aiTimeout: parsed.aiTimeout || 30,
          isLoggedIn: parsed.isLoggedIn || false,
          userName: parsed.userName || '',
          followSystemDark: parsed.followSystemDark !== undefined ? parsed.followSystemDark : true,
          isDarkMode: parsed.isDarkMode || false
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
