import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

/** 华为账号用户信息 */
export interface HuaweiUserInfo {
  openID: string;
  unionID: string;
  authorizationCode: string;
  idToken: string;
  loginTime: string;
  isSilentLogin: boolean;
}

/** 登录状态回调 */
export type LoginCallback = (success: boolean, userInfo?: HuaweiUserInfo, error?: string) => void;

/**
 * 华为账号认证服务
 * 支持普通登录 + 静默登录（个人开发者账号）
 */
export class HuaweiAuthService {
  private static instance: HuaweiAuthService;

  private currentUser: HuaweiUserInfo | null = null;
  private prefs: preferences.Preferences | null = null;
  private loginCallbacks: LoginCallback[] = [];
  private readonly PREF_KEY: string = 'huawei_user_info';

  private constructor() {}

  static getInstance(): HuaweiAuthService {
    if (!HuaweiAuthService.instance) {
      HuaweiAuthService.instance = new HuaweiAuthService();
    }
    return HuaweiAuthService.instance;
  }

  /** 初始化服务 */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, 'huawei_auth');
      // 尝试从本地恢复登录状态
      const stored = await this.prefs.get(this.PREF_KEY, '') as string;
      if (stored) {
        this.currentUser = JSON.parse(stored) as HuaweiUserInfo;
        console.info('[HuaweiAuthService] 恢复登录状态: openID=' + this.currentUser.openID);
      }
    } catch (e) {
      console.error('[HuaweiAuthService] 初始化失败: ' + JSON.stringify(e));
    }
  }

  /** 获取当前登录用户 */
  getCurrentUser(): HuaweiUserInfo | null {
    return this.currentUser;
  }

  /** 是否已登录 */
  isLoggedIn(): boolean {
    return this.currentUser !== null;
  }

  /** 订阅登录状态变化 */
  onLoginChange(callback: LoginCallback): void {
    this.loginCallbacks.push(callback);
  }

  /** 取消订阅 */
  offLoginChange(callback: LoginCallback): void {
    const idx = this.loginCallbacks.indexOf(callback);
    if (idx >= 0) {
      this.loginCallbacks.splice(idx, 1);
    }
  }

  /** 通知所有订阅者 */
  private notifyLoginChange(success: boolean, userInfo?: HuaweiUserInfo, error?: string): void {
    for (const cb of this.loginCallbacks) {
      try {
        cb(success, userInfo, error);
      } catch (e) {
        console.error('[HuaweiAuthService] 回调异常: ' + JSON.stringify(e));
      }
    }
  }

  /** 保存登录用户信息到本地 */
  private async saveUserInfo(userInfo: HuaweiUserInfo): Promise<void> {
    if (!this.prefs) {
      return;
    }
    try {
      await this.prefs.put(this.PREF_KEY, JSON.stringify(userInfo));
      await this.prefs.flush();
    } catch (e) {
      console.error('[HuaweiAuthService] 保存用户信息失败: ' + JSON.stringify(e));
    }
  }

  /** 清除本地登录信息 */
  private async clearUserInfo(): Promise<void> {
    if (!this.prefs) {
      return;
    }
    try {
      await this.prefs.delete(this.PREF_KEY);
      await this.prefs.flush();
    } catch (e) {
      console.error('[HuaweiAuthService] 清除用户信息失败: ' + JSON.stringify(e));
    }
  }

  /**
   * 静默登录（不拉起登录页，仅当已授权时自动登录）
   * @param context 当前 UIAbility 的上下文（需从 EntryAbility 传入）
   */
  async silentLogin(context: common.UIAbilityContext): Promise<HuaweiUserInfo | null> {
    if (!context) {
      console.error('[HuaweiAuthService] context未提供');
      return null;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      // forceLogin=false: 不拉起登录页，若未登录则返回错误
      loginRequest.forceLogin = false;
      loginRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(loginRequest) as authentication.LoginWithHuaweiIDResponse;
      const credential = response?.data;
      if (credential) {
        const userInfo: HuaweiUserInfo = {
          openID: credential.openID || '',
          unionID: credential.unionID || '',
          authorizationCode: credential.authorizationCode || '',
          idToken: credential.idToken || '',
          loginTime: new Date().toISOString(),
          isSilentLogin: true
        };
        this.currentUser = userInfo;
        await this.saveUserInfo(userInfo);
        this.notifyLoginChange(true, userInfo);
        return userInfo;
      }
      return null;
    } catch (e) {
      const err = e as BusinessError;
      console.error('[HuaweiAuthService] 静默登录失败: code=' + err.code + ', msg=' + err.message);
      this.notifyLoginChange(false, undefined, err.message);
      return null;
    }
  }

  /**
   * 普通登录（拉起华为账号登录界面）
   */
  async login(context: common.UIAbilityContext): Promise<HuaweiUserInfo | null> {
    if (!context) {
      console.error('[HuaweiAuthService] context未提供');
      return null;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = true;
      loginRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(loginRequest) as authentication.LoginWithHuaweiIDResponse;
      const credential = response?.data;
      if (credential) {
        const userInfo: HuaweiUserInfo = {
          openID: credential.openID || '',
          unionID: credential.unionID || '',
          authorizationCode: credential.authorizationCode || '',
          idToken: credential.idToken || '',
          loginTime: new Date().toISOString(),
          isSilentLogin: false
        };
        this.currentUser = userInfo;
        await this.saveUserInfo(userInfo);
        this.notifyLoginChange(true, userInfo);
        return userInfo;
      }
      return null;
    } catch (e) {
      const err = e as BusinessError;
      console.error('[HuaweiAuthService] 普通登录失败: code=' + err.code + ', msg=' + err.message);
      this.notifyLoginChange(false, undefined, err.message);
      return null;
    }
  }

  /** 退出登录 */
  async logout(): Promise<void> {
    this.currentUser = null;
    await this.clearUserInfo();
    console.info('[HuaweiAuthService] 退出登录');
  }
}

export const huaweiAuthService = HuaweiAuthService.getInstance();
