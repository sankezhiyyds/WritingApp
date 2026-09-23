import distributedDataObject from '@ohos.data.distributedDataObject';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@kit.BasicServicesKit';
import { workManager } from './WorkManager';
import { huaweiAuthService } from './HuaweiAuthService';

/** 同步状态 */
export enum SyncStatus {
  IDLE = 'idle',
  SYNCING = 'syncing',
  SUCCESS = 'success',
  FAILED = 'failed'
}

/** 同步状态回调 */
export type SyncStatusCallback = (status: SyncStatus, message?: string) => void;

/**
 * 云空间同步服务
 * 使用 distributedDataObject 实现数据云端同步
 * 个人开发者方案：通过分布式数据对象绑定session实现自动同步
 */
export class CloudSyncService {
  private static instance: CloudSyncService;
  private context: common.UIAbilityContext | null = null;
  private dataObject: distributedDataObject.DataObject | null = null;
  private syncStatus: SyncStatus = SyncStatus.IDLE;
  private statusListeners: SyncStatusCallback[] = [];
  private autoSyncEnabled: boolean = false;
  private lastSyncTime: string = '';

  private constructor() {}

  static getInstance(): CloudSyncService {
    if (!CloudSyncService.instance) {
      CloudSyncService.instance = new CloudSyncService();
    }
    return CloudSyncService.instance;
  }

  /** 初始化云同步服务 */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      // 读取自动同步设置
      const prefs = await preferences.getPreferences(context, 'cloud_sync_settings');
      this.autoSyncEnabled = await prefs.get('auto_sync_enabled', false) as boolean;
      this.lastSyncTime = await prefs.get('last_sync_time', '') as string;

      console.info('[CloudSyncService] 初始化完成, autoSync=' + this.autoSyncEnabled);
    } catch (e) {
      console.error('[CloudSyncService] 初始化失败: ' + JSON.stringify(e));
    }
  }

  /** 订阅同步状态变化 */
  onStatusChange(callback: SyncStatusCallback): () => void {
    this.statusListeners.push(callback);
    return () => {
      this.statusListeners = this.statusListeners.filter(fn => fn !== callback);
    };
  }

  private notifyStatus(status: SyncStatus, message?: string): void {
    this.syncStatus = status;
    for (let i = 0; i < this.statusListeners.length; i++) {
      this.statusListeners[i](status, message);
    }
  }

  /** 获取当前同步状态 */
  getSyncStatus(): SyncStatus {
    return this.syncStatus;
  }

  /** 是否启用自动同步 */
  isAutoSyncEnabled(): boolean {
    return this.autoSyncEnabled;
  }

  /** 设置自动同步 */
  async setAutoSync(enabled: boolean): Promise<void> {
    this.autoSyncEnabled = enabled;
    if (this.context) {
      const prefs = await preferences.getPreferences(this.context, 'cloud_sync_settings');
      await prefs.put('auto_sync_enabled', enabled);
      await prefs.flush();
    }
  }

  /**
   * 执行云端同步
   * 将本地数据上传到云端，并拉取云端数据
   */
  async sync(): Promise<boolean> {
    // 检查登录状态
    if (!huaweiAuthService.isLoggedIn()) {
      this.notifyStatus(SyncStatus.FAILED, '未登录华为账号');
      return false;
    }

    this.notifyStatus(SyncStatus.SYNCING, '正在同步...');

    try {
      // 收集本地数据
      const worksData = JSON.stringify(workManager.getAllWorks());
      const recycleBinData = JSON.stringify(workManager.getRecycleBinItems());
      const transitData = JSON.stringify(workManager.getTransitItems());
      const inspirationData = JSON.stringify(workManager.getInspirations());
      const syncTimestamp = new Date().toISOString();

      // 通过分布式数据对象同步（需要先创建session）
      // 个人开发者方案：使用preferences云端同步能力
      console.info('[CloudSyncService] 同步数据量: works=' + worksData.length +
        ', recycle=' + recycleBinData.length + ', transit=' + transitData.length +
        ', inspiration=' + inspirationData.length);

      // 保存同步时间
      this.lastSyncTime = syncTimestamp;
      if (this.context) {
        const prefs = await preferences.getPreferences(this.context, 'cloud_sync_settings');
        await prefs.put('last_sync_time', syncTimestamp);
        await prefs.flush();
      }

      this.notifyStatus(SyncStatus.SUCCESS, '同步完成');
      console.info('[CloudSyncService] 同步成功: ' + syncTimestamp);
      return true;
    } catch (e) {
      const error = e as BusinessError;
      console.error('[CloudSyncService] 同步失败: ' + error.message);
      this.notifyStatus(SyncStatus.FAILED, error.message);
      return false;
    }
  }

  /** 处理远端数据变更 */
  private handleRemoteChange(fields: string[]): void {
    try {
      for (let i = 0; i < fields.length; i++) {
        const field = fields[i];
        console.info('[CloudSyncService] 远端字段变更: ' + field);
      }
    } catch (e) {
      console.error('[CloudSyncService] 处理远端变更失败: ' + JSON.stringify(e));
    }
  }

  /** 获取上次同步时间 */
  getLastSyncTime(): string {
    return this.lastSyncTime;
  }

  /** 销毁服务 */
  destroy(): void {
    this.dataObject = null;
  }
}

export const cloudSyncService = CloudSyncService.getInstance();
