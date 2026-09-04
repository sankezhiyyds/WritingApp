import abilityAccessCtrl, { PermissionRequestResult, Permissions } from '@ohos.abilityAccessCtrl';
import bundleManager from '@ohos.bundle.bundleManager';
import common from '@ohos.app.ability.common';
import { settingsManager } from './SettingsManager';

/** 权限项元信息 */
export interface PermissionItem {
  permission: string;
  name: string;
  reason: string;
  granted: boolean;
}

/** 权限申请结果 */
export interface PermissionResult {
  allGranted: boolean;
  granted: string[];
  denied: string[];
}

/**
 * 权限管理器
 * 基于 abilityAccessCtrl 实现运行时权限检查与申请，
 * 申请结果记录到本地设置中，供设置页"权限管理"查看。
 */
export class PermissionManager {
  private context: common.UIAbilityContext | null = null;

  init(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /** 应用声明的运行时权限列表（与 module.json5 requestPermissions 对应） */
  getPermissionItems(): PermissionItem[] {
    const granted = settingsManager.settings.grantedPermissions;
    return [
      {
        permission: 'ohos.permission.INTERNET',
        name: '网络连接',
        reason: '用于调用AI模型接口生成创作内容',
        granted: granted.indexOf('ohos.permission.INTERNET') !== -1
      },
      {
        permission: 'ohos.permission.GET_NETWORK_INFO',
        name: '网络状态',
        reason: '用于检测网络可用性，避免AI请求超时',
        granted: granted.indexOf('ohos.permission.GET_NETWORK_INFO') !== -1
      },
      {
        permission: 'ohos.permission.READ_MEDIA',
        name: '文件读取',
        reason: '用于加载本地字体文件(.ttf/.otf)和AI模型文件(.gguf)',
        granted: granted.indexOf('ohos.permission.READ_MEDIA') !== -1
      }
    ];
  }

  /** 检查单个权限是否已授予 */
  async checkPermission(permission: string): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const result = await atManager.checkAccessToken(tokenId, permission as Permissions);
      return result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      console.error('[PermissionManager] 检查权限失败: ' + JSON.stringify(e));
      return false;
    }
  }

  /** 申请一组权限，返回申请结果 */
  async requestPermissions(permissions: string[]): Promise<PermissionResult> {
    const result: PermissionResult = { allGranted: false, granted: [], denied: [] };
    if (!this.context) {
      console.error('[PermissionManager] context 未初始化');
      return result;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const response = await atManager.requestPermissionsFromUser(this.context, permissions as Permissions[]);
      for (let i = 0; i < permissions.length; i++) {
        if (response.authResults[i] === 0) {
          result.granted.push(permissions[i]);
        } else {
          result.denied.push(permissions[i]);
        }
      }
      result.allGranted = result.denied.length === 0;
      this.recordGranted(result.granted);
    } catch (e) {
      console.error('[PermissionManager] 申请权限失败: ' + JSON.stringify(e));
      result.denied = permissions;
    }
    return result;
  }

  /** 记录已授予的权限到本地设置 */
  private recordGranted(granted: string[]): void {
    const list = settingsManager.settings.grantedPermissions;
    for (let i = 0; i < granted.length; i++) {
      if (list.indexOf(granted[i]) === -1) {
        list.push(granted[i]);
      }
    }
    settingsManager.save();
  }

  /** 启动时校验权限状态（system_grant 权限自动记录） */
  async verifyOnLaunch(): Promise<void> {
    const items = this.getPermissionItems();
    for (let i = 0; i < items.length; i++) {
      const ok = await this.checkPermission(items[i].permission);
      if (ok && settingsManager.settings.grantedPermissions.indexOf(items[i].permission) === -1) {
        settingsManager.settings.grantedPermissions.push(items[i].permission);
      }
    }
    settingsManager.save();
  }
}

export const permissionManager = new PermissionManager();
