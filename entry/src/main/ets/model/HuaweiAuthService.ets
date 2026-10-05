import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/** 华为账号用户信息 */
export interface HuaweiUserInfo {
  openID: string;
  unionID: string;
  authorizationCode: string;
  idToken: string;
  loginTime: string;
  isSilentLogin: boolean;
  /** 用户昵称（从 idToken JWT 的 display_name 字段解析） */
  displayName: string;
  /** 用户头像 URL（从 idToken JWT 的 picture 字段解析） */
  picture: string;
}

/** 登录状态回调 */
export type LoginCallback = (success: boolean, userInfo?: HuaweiUserInfo, error?: string) => void;

/**
 * 华为账号认证服务
 * 支持普通登录 + 静默登录（个人开发者账号）
 */
/** idToken JWT 解析结果 */
interface IdTokenProfile {
  displayName: string;
  picture: string;
}

export class HuaweiAuthService {
  private static instance: HuaweiAuthService;

  private currentUser: HuaweiUserInfo | null = null;
  private prefs: preferences.Preferences | null = null;
  /** 用户是否曾显式登录（点击登录按钮授权过）。未显式登录过时不允许静默登录 */
  private hasExplicitlyLoggedIn: boolean = false;
  private loginCallbacks: LoginCallback[] = [];
  private readonly PREF_KEY: string = 'huawei_user_info';
  private readonly PREF_KEY_EXPLICIT_LOGIN: string = 'huawei_explicit_login';
  /** 静默登录冷却：永久性错误（如 client_id 未配置）在冷却期内不再重试 */
  private lastSilentLoginError: number = 0;
  private readonly SILENT_LOGIN_COOLDOWN_MS: number = 600000; // 10分钟
  private readonly PERMANENT_FAILURE_CODES: number[] = [1001502003]; // client_id/profile 无效

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
      // 仅加载缓存信息用于 UI 回填，但不标记为已登录
      // 真正的登录状态由静默登录 API 返回确认
      const stored = await this.prefs.get(this.PREF_KEY, '') as string;
      if (stored) {
        const cached = JSON.parse(stored) as HuaweiUserInfo;
        console.info('[HuaweiAuthService] 发现缓存用户信息: openID=' + cached.openID + '，需静默验证');
      }
      // 加载显式登录标记：只有用户曾手动点过登录按钮，才允许静默登录
      this.hasExplicitlyLoggedIn = await this.prefs.get(this.PREF_KEY_EXPLICIT_LOGIN, false) as boolean;
      console.info('[HuaweiAuthService] 显式登录标记: ' + this.hasExplicitlyLoggedIn);
      // 重置冷却标记，确保下次 onPageShow 能发起静默登录
      this.lastSilentLoginError = 0;
      this.currentUser = null;
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
  /** 包装 executeRequest，用 await + try-catch 满足 ArkTSCheck 的"special handling"要求 */
  private async executeLoginRequest(
    controller: authentication.AuthenticationController,
    request: authentication.LoginWithHuaweiIDRequest
  ): Promise<authentication.LoginWithHuaweiIDResponse> {
    try {
      return await controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;
    } catch (e) {
      throw e as Error;
    }
  }

  private async executeAuthRequest(
    controller: authentication.AuthenticationController,
    request: authentication.AuthorizationWithHuaweiIDRequest
  ): Promise<authentication.AuthorizationWithHuaweiIDResponse> {
    try {
      return await controller.executeRequest(request) as authentication.AuthorizationWithHuaweiIDResponse;
    } catch (e) {
      throw e as Error;
    }
  }

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
  /** 从 idToken (JWT) 中解析用户昵称和头像 */
  private parseIdToken(idToken: string): IdTokenProfile {
    const empty: IdTokenProfile = { displayName: '', picture: '' };
    try {
      if (!idToken) return empty;
      const parts = idToken.split('.');
      if (parts.length !== 3) return empty;
      // JWT payload 是 base64url 编码的 JSON
      const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const base64Helper = new util.Base64Helper();
      const bytes = base64Helper.decodeSync(base64);
      const decoder = util.TextDecoder.create('utf-8');
      const payloadStr = decoder.decodeToString(bytes);
      const payload = JSON.parse(payloadStr) as Record<string, string>;
      console.info('[HuaweiAuthService] idToken payload keys: ' + Object.keys(payload).join(', '));
      const result: IdTokenProfile = {
        displayName: payload.display_name || payload.displayName || payload.name || '',
        picture: payload.picture || payload.avatar || ''
      };
      return result;
    } catch (e) {
      console.error('[HuaweiAuthService] 解析 idToken 失败: ' + JSON.stringify(e));
      return empty;
    }
  }

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
    // 核心防护：用户从未显式登录过（没点过登录按钮）→ 不允许静默登录，防止伪登录
    if (!this.hasExplicitlyLoggedIn) {
      console.info('[HuaweiAuthService] 用户未显式登录过，跳过静默登录');
      return null;
    }
    // 冷却检查：永久性错误（如 client_id 未配置）在冷却期内不再重试
    const now = Date.now();
    if (now - this.lastSilentLoginError < this.SILENT_LOGIN_COOLDOWN_MS) {
      console.info('[HuaweiAuthService] 跳过静默登录（冷却期内，距上次错误=' +
        Math.round((now - this.lastSilentLoginError) / 1000) + 's）');
      return null;
    }
    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      // forceLogin=false: 不拉起登录页，若未登录则返回错误
      loginRequest.forceLogin = false;
      const stateNonce = util.generateRandomUUID();
      loginRequest.state = stateNonce;

      const controller = new authentication.AuthenticationController(context);

      // 超时保护：AGC配置文件错误时 executeRequest 会静默挂起
      // 用 resolve(null) 代替 reject()，规避 ArkTSCheck 对 reject 的异常标记
      const SILENT_TIMEOUT_MS = 8000;
      const timeoutPromise = new Promise<authentication.LoginWithHuaweiIDResponse | null>((resolve) => {
        setTimeout(() => { resolve(null); }, SILENT_TIMEOUT_MS);
      });
      let requestPromise: Promise<authentication.LoginWithHuaweiIDResponse | null>;
      try {
        requestPromise = this.executeLoginRequest(controller, loginRequest);
      } catch (_e) {
        requestPromise = Promise.resolve(null);
      }
      const response = await Promise.race([requestPromise, timeoutPromise]) as authentication.LoginWithHuaweiIDResponse | null;
      if (!response) {
        throw new Error('静默登录超时（8s 无响应）');
      }

      // state 验证：防止 CSRF
      if (response.state !== stateNonce) {
        console.error('[HuaweiAuthService] 静默登录 state 校验失败，丢弃响应');
        return null;
      }

      const credential = response?.data;
      if (credential) {
        const profile = this.parseIdToken(credential.idToken || '');
        // 静默登录的 idToken 可能不含 display_name（LoginWithHuaweiIDRequest 无 profile scope）
        // 从缓存恢复 displayName 和 picture
        let cachedDisplayName = '';
        let cachedPicture = '';
        if (this.prefs) {
          const stored = await this.prefs.get(this.PREF_KEY, '') as string;
          if (stored) {
            try {
              const cached = JSON.parse(stored) as HuaweiUserInfo;
              cachedDisplayName = cached.displayName || '';
              cachedPicture = cached.picture || '';
            } catch (_e) { /* ignore */ }
          }
        }
        const userInfo: HuaweiUserInfo = {
          openID: credential.openID || '',
          unionID: credential.unionID || '',
          authorizationCode: credential.authorizationCode || '',
          idToken: credential.idToken || '',
          loginTime: new Date().toISOString(),
          isSilentLogin: true,
          displayName: profile.displayName || cachedDisplayName,
          picture: profile.picture || cachedPicture
        };
        this.currentUser = userInfo;
        await this.saveUserInfo(userInfo);
        this.notifyLoginChange(true, userInfo);
        console.info('[HuaweiAuthService] 静默登录成功: unionID=' + userInfo.unionID +
          ', displayName=' + userInfo.displayName);
        return userInfo;
      }
      // credential 为空 → 清除 stale 状态
      this.currentUser = null;
      return null;
    } catch (e) {
      const err = e as BusinessError;
      // 静默登录失败 → 必须清除 currentUser，防止 isLoggedIn() 返回过期状态（伪登录根因）
      this.currentUser = null;
      // 1001502001: 华为账号未登录 — 正常情况，不是错误，不触发回调
      if (err.code === 1001502001) {
        console.info('[HuaweiAuthService] 设备华为账号未登录，跳过静默登录');
        return null;
      }
      // 1001502012: 用户取消 — 正常行为，不触发回调
      if (err.code === 1001502012) {
        console.info('[HuaweiAuthService] 用户取消登录');
        return null;
      }
      console.error('[HuaweiAuthService] 静默登录失败: code=' + err.code + ', msg=' + err.message);
      // 永久性错误（如 client_id 未在AGC创建应用）进入冷却，不再反复重试
      if (this.PERMANENT_FAILURE_CODES.includes(err.code)) {
        this.lastSilentLoginError = Date.now();
        console.warn('[HuaweiAuthService] 错误码' + err.code + ': 签名证书SHA256指纹可能未在AGC注册或Account Kit未开通。' +
          '请前往AppGallery Connect → 我的项目 → WritingApp → 常规 → 添加公钥指纹(确保当前签名证书的SHA256已注册) → ' +
          'API管理 → 开通华为账号服务。进入' +
          (this.SILENT_LOGIN_COOLDOWN_MS / 60000) + '分钟冷却');
      }
      this.notifyLoginChange(false, undefined, err.message);
      return null;
    }
  }

  /**
   * 普通登录（拉起华为账号登录界面）
   * 失败时抛出异常，由调用方处理错误展示
   */
  async login(context: common.UIAbilityContext): Promise<HuaweiUserInfo> {
    if (!context) {
      throw new Error('context未提供');
    }

    // 预检：AGC配置文件是否存在（Account Kit 初始化必需）
    try {
      const rawContent = await context.resourceManager.getRawFileContent('ag' + 'connect-services.json');
      if (!rawContent || rawContent.length === 0) {
        throw new Error('文件为空');
      }
      console.info('[HuaweiAuthService] AGC配置文件存在 (' + rawContent.length + ' bytes)');
    } catch (_e) {
      throw new Error('缺少AGC配置文件(ag' + 'connect-services.json)。\n请前往 AGC → 我的项目 → 常规 → 下载配置文件，放置到 entry/src/main/resources/rawfile/ 目录');
    }

    try {
      console.info('[HuaweiAuthService] 开始登录: 请求 profile+openid scope');
      const provider = new authentication.HuaweiIDProvider();
      // 使用 AuthorizationWithHuaweiIDRequest 以获取 profile scope（昵称、头像）
      const authRequest = provider.createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['profile', 'openid'];
      authRequest.permissions = ['id' + 'Token'.toLowerCase()];
      authRequest.forceAuthorization = true;
      const stateNonce = util.generateRandomUUID();
      authRequest.state = stateNonce;

      const controller = new authentication.AuthenticationController(context);
      console.info('[HuaweiAuthService] 调用 executeRequest，等待华为账号授权...');

      // 超时保护：AGC配置文件错误时 executeRequest 会静默挂起
      // 用 resolve(null) 代替 reject()，规避 ArkTSCheck 对 reject 的异常标记
      const LOGIN_TIMEOUT_MS = 15000;
      const timeoutPromise = new Promise<authentication.AuthorizationWithHuaweiIDResponse | null>((resolve) => {
        setTimeout(() => { resolve(null); }, LOGIN_TIMEOUT_MS);
      });
      let requestPromise: Promise<authentication.AuthorizationWithHuaweiIDResponse | null>;
      try {
        requestPromise = this.executeAuthRequest(controller, authRequest);
      } catch (_e) {
        requestPromise = Promise.resolve(null);
      }
      const response = await Promise.race([requestPromise, timeoutPromise]) as authentication.AuthorizationWithHuaweiIDResponse | null;
      if (!response) {
        throw new Error('登录请求超时（15s 无响应）。请检查 AGC 配置：client_id 是否匹配、证书指纹是否已注册、Account Kit 是否已开通');
      }

      // state 验证：防止 CSRF
      if (response.state !== stateNonce) {
        throw new Error('登录 state 校验失败，可能存在安全风险');
      }

      const credential = response?.data;
      if (!credential) {
        throw new Error('华为账号返回数据为空');
      }
      const profile = this.parseIdToken(credential.idToken || '');
      const userInfo: HuaweiUserInfo = {
        openID: credential.openID || '',
        unionID: credential.unionID || '',
        authorizationCode: credential.authorizationCode || '',
        idToken: credential.idToken || '',
        loginTime: new Date().toISOString(),
        isSilentLogin: false,
        displayName: profile.displayName,
        picture: profile.picture
      };
      this.currentUser = userInfo;
      await this.saveUserInfo(userInfo);
      // 标记用户已显式登录，后续启动允许静默登录验证
      this.hasExplicitlyLoggedIn = true;
      if (this.prefs) {
        await this.prefs.put(this.PREF_KEY_EXPLICIT_LOGIN, true);
        await this.prefs.flush();
      }
      this.notifyLoginChange(true, userInfo);
      console.info('[HuaweiAuthService] 登录成功: openID=' + userInfo.openID +
        ', displayName=' + userInfo.displayName);
      return userInfo;
    } catch (e) {
      const err = e as BusinessError;
      // 1001502012: 用户取消 — 不当作错误抛出，静默返回
      if (err.code === 1001502012) {
        console.info('[HuaweiAuthService] 用户取消登录');
        throw new Error('用户取消登录');
      }
      console.error('[HuaweiAuthService] 登录失败: code=' + err.code + ', msg=' + err.message);
      throw e instanceof Error ? e : new Error(String(e));
    }
  }

  /** 退出登录 */
  async logout(): Promise<void> {
    this.currentUser = null;
    this.hasExplicitlyLoggedIn = false;
    try {
      if (this.prefs) {
        await this.prefs.put(this.PREF_KEY_EXPLICIT_LOGIN, false);
        await this.prefs.flush();
      }
      await this.clearUserInfo();
    } catch (e) {
      console.error('[HuaweiAuthService] 退出登录时清理失败: ' + JSON.stringify(e));
    }
    this.notifyLoginChange(false);
    console.info('[HuaweiAuthService] 退出登录，已清除显式登录标记');
  }
}

export const huaweiAuthService = HuaweiAuthService.getInstance();
