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
 * 支持普通登录 + 静默登录（个人开发者配置）
 * 使用 @kit.AccountKit authentication API
 */
export class HuaweiAuthService {
  private static instance: HuaweiAuthService;
  private context: common.UIAbilityContext | null = null;
  private prefs: preferences.Preferences | null = null;
  private currentUser: HuaweiUserInfo | null = null;
  private loginListeners: LoginCallback[] = [];
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
    this.context = context;
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
  onLoginChange(callback: LoginCallback): () => void {
    this.loginListeners.push(callback);
    return () => {
      this.loginListeners = this.loginListeners.filter(fn => fn !== callback);
    };
  }

  private notifyLogin(success: boolean, userInfo?: HuaweiUserInfo, error?: string): void {
    for (let i = 0; i < this.loginListeners.length; i++) {
      this.loginListeners[i](success, userInfo, error);
    }
  }

  /**
   * 静默登录（不拉起登录页面）
   * 适用于已授权用户自动登录场景
   */
  async silentLogin(): Promise<HuaweiUserInfo | null> {
    if (!this.context) {
      console.error('[HuaweiAuthService] context未初始化');
      return null;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      // forceLogin=false: 不拉起登录页，若未登录则返回错误
      loginRequest.forceLogin = false;
      loginRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(this.context);
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
        console.info('[HuaweiAuthService] 静默登录成功: openID=' + userInfo.openID);
        this.notifyLogin(true, userInfo);
        return userInfo;
      }
      return null;
    } catch (e) {
      const error = e as BusinessError;
      console.error('[HuaweiAuthService] 静默登录失败: code=' + error.code + ', msg=' + error.message);
      return null;
    }
  }

  /**
   * 普通登录（拉起华为账号登录页面）
   */
  async login(): Promise<HuaweiUserInfo | null> {
    if (!this.context) {
      console.error('[HuaweiAuthService] context未初始化');
      return null;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      // forceLogin=true: 若未登录则拉起登录页
      loginRequest.forceLogin = true;
      loginRequest.state = util.generateRandomUUID();

      const controller = new authentication.AuthenticationController(this.context);
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
        console.info('[HuaweiAuthService] 登录成功: openID=' + userInfo.openID);
        this.notifyLogin(true, userInfo);
        return userInfo;
      }
      return null;
    } catch (e) {
      const error = e as BusinessError;
      console.error('[HuaweiAuthService] 登录失败: code=' + error.code + ', msg=' + error.message);
      this.notifyLogin(false, undefined, error.message);
      return null;
    }
  }

  /** 退出登录 */
  async logout(): Promise<void> {
    this.currentUser = null;
    if (this.prefs) {
      await this.prefs.delete(this.PREF_KEY);
      await this.prefs.flush();
    }
    console.info('[HuaweiAuthService] 已退出登录');
    this.notifyLogin(false);
  }

  /** 保存用户信息到本地 */
  private async saveUserInfo(userInfo: HuaweiUserInfo): Promise<void> {
    if (this.prefs) {
      await this.prefs.put(this.PREF_KEY, JSON.stringify(userInfo));
      await this.prefs.flush();
    }
  }
}

export const huaweiAuthService = HuaweiAuthService.getInstance();
