import { authentication } from '@kit.AccountKit';
import common from '@ohos.app.ability.common';
import { settingsManager } from './SettingsManager';

/**
 * 华为账号登录服务
 * 基于 Account Kit 实现普通登录、静默登录、登出
 */
export class HuaweiAuthService {
  private context: common.UIAbilityContext | null = null;

  /**
   * 初始化，传入 UIAbilityContext
   */
  init(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 华为账号登录（弹出登录页 + 授权页）
   * 使用 createLoginWithHuaweiIDRequest 获取 UnionID / OpenID / AuthorizationCode
   */
  async loginWithHuaweiID(): Promise<boolean> {
    if (!this.context) {
      console.error('[HuaweiAuth] context 未初始化');
      return false;
    }

    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = true;

      const controller = new authentication.AuthenticationController(this.context);
      const response = await controller.executeRequest(loginRequest);

      const loginResponse = response as authentication.LoginWithHuaweiIDResponse;
      const credential = loginResponse?.data;
      const unionID = credential?.unionID || '';
      const openID = credential?.openID || '';
      const authCode = credential?.authorizationCode || '';

      if (unionID || authCode) {
        // 保存登录信息到全局设置
        settingsManager.settings.isLoggedIn = true;
        settingsManager.settings.userName = '华为用户';
        settingsManager.save();

        // 保存华为ID信息到本地
        this.saveHuaweiIDInfo(unionID, openID, authCode);

        console.info('[HuaweiAuth] 登录成功, unionID: ' + unionID);
        return true;
      } else {
        console.error('[HuaweiAuth] 登录返回数据为空');
        return false;
      }
    } catch (e) {
      const err = e as Error;
      console.error('[HuaweiAuth] 登录失败: ' + err.message);
      return false;
    }
  }

  /**
   * 静默登录（不弹出登录页，自动恢复登录态）
   * 适用于应用二次打开时自动登录
   */
  async silentLogin(): Promise<boolean> {
    if (!this.context) {
      console.error('[HuaweiAuth] context 未初始化');
      return false;
    }

    try {
      const provider = new authentication.HuaweiIDProvider();
      const loginRequest = provider.createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = false; // 不拉起登录页

      const controller = new authentication.AuthenticationController(this.context);
      const response = await controller.executeRequest(loginRequest);

      const loginResponse = response as authentication.LoginWithHuaweiIDResponse;
      const credential = loginResponse?.data;
      const unionID = credential?.unionID || '';

      if (unionID) {
        settingsManager.settings.isLoggedIn = true;
        settingsManager.settings.userName = '华为用户';
        settingsManager.save();

        console.info('[HuaweiAuth] 静默登录成功');
        return true;
      } else {
        console.info('[HuaweiAuth] 静默登录未返回数据');
        return false;
      }
    } catch (e) {
      const err = e as Error;
      console.info('[HuaweiAuth] 静默登录跳过: ' + err.message);
      return false;
    }
  }

  /**
   * 退出登录
   */
  async logout(): Promise<void> {
    try {
      settingsManager.settings.isLoggedIn = false;
      settingsManager.settings.userName = '';
      settingsManager.save();

      // 清除本地华为ID信息
      this.clearHuaweiIDInfo();

      console.info('[HuaweiAuth] 退出登录成功');
    } catch (e) {
      const err = e as Error;
      console.error('[HuaweiAuth] 退出登录失败: ' + err.message);
    }
  }

  /**
   * 保存华为ID信息到 AppStorage
   */
  private saveHuaweiIDInfo(unionID: string, openID: string, authCode: string): void {
    try {
      const info = JSON.stringify({ unionID, openID, authCode });
      AppStorage.setOrCreate('huawei_id_info', info);
    } catch (e) {
      console.error('[HuaweiAuth] 保存华为ID信息失败');
    }
  }

  /**
   * 清除本地华为ID信息
   */
  private clearHuaweiIDInfo(): void {
    try {
      AppStorage.setOrCreate('huawei_id_info', '');
    } catch (e) {
      console.error('[HuaweiAuth] 清除华为ID信息失败');
    }
  }

  /**
   * 获取已保存的华为ID信息
   */
  getHuaweiIDInfo(): string {
    return AppStorage.get<string>('huawei_id_info') || '';
  }

  /**
   * 检查是否已保存登录信息（用于判断是否尝试静默登录）
   */
  hasSavedLogin(): boolean {
    const info = this.getHuaweiIDInfo();
    return info.length > 0;
  }
}

export const huaweiAuthService = new HuaweiAuthService();
