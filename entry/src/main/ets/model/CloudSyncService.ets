import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cloudSync } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import fileIo from '@ohos.file.fs';
import { workManager, WorkItem, InspirationItem, RecycleBinItem } from './WorkManager';
import { huaweiAuthService } from './HuaweiAuthService';

/** 同步状态 */
export enum SyncStatus {
  IDLE = 'idle',
  SYNCING = 'syncing',
  SUCCESS = 'success',
  FAILED = 'failed'
}

/** 同步状态回调 */
type SyncStatusCallback = (status: SyncStatus, message?: string) => void;

/** 云端文件目录名 */
const CLOUD_DIR = 'writing_app/';

/**
 * 云盘同步服务
 * 使用 @kit.CoreFileKit 的 cloudSync 端云文件协同 API
 * 数据文件写入 context.cloudFileDir 目录，系统自动同步到用户华为云空间
 * 无需在 AGC 开通云存储服务，使用用户个人云空间配额
 */
export class CloudSyncService {
  private static instance: CloudSyncService;
  private context: common.UIAbilityContext | null = null;
  private fileSync: cloudSync.FileSync | null = null;
  private syncStatus: SyncStatus = SyncStatus.IDLE;
  private statusListeners: SyncStatusCallback[] = [];
  private autoSyncEnabled: boolean = false;
  /** 最近一次同步的真实结果消息 */
  private lastSyncMessage: string = '';
  /** 最近一次云存储操作的错误详情 */
  private lastErrorMessage: string = '';
  /** sync等待resolve */
  private syncPromiseResolve: ((value: boolean) => void) | null = null;

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

      // 初始化端云文件协同
      try {
        this.fileSync = new cloudSync.FileSync();
        this.fileSync.on('progress', (progress: cloudSync.SyncProgress) => {
          console.info('[CloudSyncService] 同步进度: state=' + progress.state + ', error=' + progress.error);
          if (progress.state === cloudSync.SyncState.STOPPED) {
            if (this.syncPromiseResolve) {
              const resolve = this.syncPromiseResolve;
              this.syncPromiseResolve = null;
              resolve(progress.error === cloudSync.ErrorType.NO_ERROR);
            }
          }
        });
        console.info('[CloudSyncService] 端云文件协同初始化成功');
      } catch (e) {
        const err = e as BusinessError;
        console.error('[CloudSyncService] 端云文件协同初始化失败: code=' + err.code + ', msg=' + err.message);
      }

      // 确保云目录存在
      await this.ensureCloudDir();

      console.info('[CloudSyncService] 初始化完成, autoSync=' + this.autoSyncEnabled);
    } catch (e) {
      console.error('[CloudSyncService] 初始化失败: ' + JSON.stringify(e));
    }
  }

  /** 注册同步状态监听 */
  onStatusChange(callback: SyncStatusCallback): () => void {
    this.statusListeners.push(callback);
    return () => {
      this.statusListeners = this.statusListeners.filter(fn => fn !== callback);
    };
  }

  private notifyStatus(status: SyncStatus, message?: string): void {
    this.syncStatus = status;
    if (message) {
      this.lastSyncMessage = message;
    }
    for (let i = 0; i < this.statusListeners.length; i++) {
      this.statusListeners[i](status, message);
    }
  }

  /** 获取最近一次同步消息 */
  getLastSyncMessage(): string {
    return this.lastSyncMessage;
  }

  /** 获取最近一次云存储操作的错误详情 */
  getLastErrorMessage(): string {
    return this.lastErrorMessage;
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
      try {
        const prefs = await preferences.getPreferences(this.context, 'cloud_sync_settings');
        await prefs.put('auto_sync_enabled', enabled);
        await prefs.flush();
      } catch (e) {
        console.error('[CloudSyncService] 保存自动同步设置失败: ' + JSON.stringify(e));
      }
    }
  }

  /** 销毁服务，释放资源 */
  destroy(): void {
    if (this.fileSync) {
      try {
        this.fileSync.off('progress');
      } catch (_e) {
        // 忽略
      }
      this.fileSync = null;
    }
    this.context = null;
    this.statusListeners = [];
  }

  // ==================== 文件 I/O 辅助方法 ====================

  /** 获取云文件目录路径 */
  private getCloudDir(): string {
    if (!this.context) return '';
    return this.context.cloudFileDir + '/' + CLOUD_DIR;
  }

  /** 确保云目录存在 */
  private async ensureCloudDir(): Promise<string> {
    const dirPath = this.getCloudDir();
    if (!dirPath) return '';
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true);
      }
      return dirPath;
    } catch (e) {
      console.error('[CloudSyncService] 创建云目录失败: ' + JSON.stringify(e));
      return '';
    }
  }

  /** 将数据序列化为 JSON 写入云目录，返回文件路径 */
  private async writeJsonToCloud(fileName: string, data: object): Promise<string> {
    const dirPath = await this.ensureCloudDir();
    if (!dirPath) return '';
    const filePath = dirPath + fileName;
    try {
      const content = JSON.stringify(data);
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
      console.info('[CloudSyncService] 已写入云目录: ' + fileName + ', 大小=' + content.length + 'B');
      return filePath;
    } catch (e) {
      console.error('[CloudSyncService] 写入云目录失败 ' + fileName + ': ' + JSON.stringify(e));
      return '';
    }
  }

  /** 从云目录读取 JSON 文件 */
  private async readJsonFromCloud<T>(fileName: string): Promise<T | null> {
    const dirPath = await this.ensureCloudDir();
    if (!dirPath) return null;
    const filePath = dirPath + fileName;
    try {
      if (!fileIo.accessSync(filePath)) return null;
      const stat = fileIo.statSync(filePath);
      if (stat.size === 0) return null;
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeToString(new Uint8Array(buf));
      return JSON.parse(text) as T;
    } catch (e) {
      console.error('[CloudSyncService] 读取云文件失败 ' + fileName + ': ' + JSON.stringify(e));
      return null;
    }
  }

  /** 检查云目录中文件是否存在 */
  private async cloudFileExists(fileName: string): Promise<boolean> {
    const dirPath = await this.ensureCloudDir();
    if (!dirPath) return false;
    try {
      return fileIo.accessSync(dirPath + fileName);
    } catch (_e) {
      return false;
    }
  }

  // ==================== 核心同步逻辑 ====================

  /**
   * 触发端云同步并等待完成
   * 系统会自动将 cloudFileDir 下的文件变更同步到用户华为云空间
   */
  private async triggerSyncAndWait(): Promise<boolean> {
    if (!this.fileSync) {
      console.warn('[CloudSyncService] fileSync 未初始化，跳过同步触发');
      return false;
    }
    return new Promise<boolean>((resolve) => {
      let resolved = false;
      this.syncPromiseResolve = (value: boolean) => {
        if (!resolved) {
          resolved = true;
          resolve(value);
        }
      };
      const timeoutId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          this.syncPromiseResolve = null;
          console.error('[CloudSyncService] 同步超时(30s)');
          resolve(false);
        }
      }, 30000);
      this.fileSync!.start().then(() => {
        console.info('[CloudSyncService] fileSync.start() 成功，等待同步完成...');
      }).catch((err: BusinessError) => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          this.syncPromiseResolve = null;
          console.error('[CloudSyncService] 启动同步失败: code=' + err.code + ', msg=' + err.message);
          this.lastErrorMessage = '同步启动失败[' + err.code + ']: ' + err.message;
          resolve(false);
        }
      });
    });
  }

  /**
   * 执行云盘同步
   * 策略：先触发同步拉取云端数据，读取并合并到本地，再将合并后的数据写入云目录触发上传
   */
  async sync(): Promise<boolean> {
    if (!huaweiAuthService.isLoggedIn()) {
      this.notifyStatus(SyncStatus.FAILED, '未登录华为账号');
      console.warn('[CloudSyncService] 未登录华为账号，跳过同步');
      return false;
    }

    if (!this.context) {
      this.notifyStatus(SyncStatus.FAILED, '服务未初始化');
      return false;
    }

    this.notifyStatus(SyncStatus.SYNCING, '正在同步到云盘...');
    this.lastErrorMessage = '';
    console.info('[CloudSyncService] ===== 开始端云文件同步 =====');

    try {
      // 第一步：触发同步，拉取云端最新数据到 cloudFileDir
      console.info('[CloudSyncService] 步骤1: 触发同步，拉取云端数据...');
      const pullSyncOk = await this.triggerSyncAndWait();
      console.info('[CloudSyncService] 步骤1完成: pullSyncOk=' + pullSyncOk);

      // 第二步：从 cloudFileDir 读取云端数据并合并到本地
      console.info('[CloudSyncService] 步骤2: 读取并合并云端数据...');
      const pullSuccess = await this.pullFromCloud();
      console.info('[CloudSyncService] 步骤2完成: pullSuccess=' + pullSuccess);

      // 第三步：将当前本地数据写入 cloudFileDir（触发上传同步）
      console.info('[CloudSyncService] 步骤3: 写入本地数据到云目录...');
      const syncTimestamp = new Date().toISOString();

      const worksData = workManager.getAllWorks();
      const recycleBinData = workManager.getRecycleBinItems();
      const inspirationData = workManager.getInspirations();

      const worksPath = await this.writeJsonToCloud('works.json', worksData);
      const recyclePath = await this.writeJsonToCloud('recycle_bin.json', recycleBinData);
      const inspirationPath = await this.writeJsonToCloud('inspirations.json', inspirationData);

      const uploadSuccess = worksPath !== '' && recyclePath !== '' && inspirationPath !== '';
      console.info('[CloudSyncService] 步骤3完成: uploadSuccess=' + uploadSuccess);

      // 第四步：触发同步，将本地变更上传到云端
      if (uploadSuccess) {
        console.info('[CloudSyncService] 步骤4: 触发同步，上传到云端...');
        const pushSyncOk = await this.triggerSyncAndWait();
        console.info('[CloudSyncService] 步骤4完成: pushSyncOk=' + pushSyncOk);
      }

      // 更新同步时间
      if (this.context) {
        try {
          const prefs = await preferences.getPreferences(this.context, 'cloud_sync_settings');
          await prefs.put('last_sync_time', syncTimestamp);
          await prefs.flush();
        } catch (_e) {
          // 忽略
        }
      }

      // 汇总结果
      let statusMsg: string;
      if (uploadSuccess && pullSuccess) {
        statusMsg = '同步完成';
      } else if (uploadSuccess) {
        statusMsg = '已上传到云盘，但拉取云端历史数据失败';
      } else {
        statusMsg = this.lastErrorMessage || '同步失败，请检查网络连接';
      }

      this.notifyStatus(SyncStatus.SUCCESS, statusMsg);
      console.info('[CloudSyncService] 端云同步完成: ' + statusMsg);
      return uploadSuccess;
    } catch (e) {
      const errorMsg = (e as Error).message || JSON.stringify(e);
      console.error('[CloudSyncService] 同步异常: ' + errorMsg);
      this.notifyStatus(SyncStatus.FAILED, '同步出错: ' + errorMsg);
      return false;
    }
  }

  /**
   * 从云目录读取数据并合并到本地
   * 使用 WorkManager 的 merge 方法进行冲突处理（按时间戳择新）
   */
  private async pullFromCloud(): Promise<boolean> {
    try {
      let hasAnyData = false;

      // 读取 works.json
      if (await this.cloudFileExists('works.json')) {
        const data = await this.readJsonFromCloud<WorkItem[]>('works.json');
        if (data && Array.isArray(data) && data.length > 0) {
          workManager.mergeFromCloud(data);
          hasAnyData = true;
          console.info('[CloudSyncService] 合并作品数据: ' + data.length + ' 条');
        }
      }

      // 读取 recycle_bin.json
      if (await this.cloudFileExists('recycle_bin.json')) {
        const data = await this.readJsonFromCloud<RecycleBinItem[]>('recycle_bin.json');
        if (data && Array.isArray(data) && data.length > 0) {
          workManager.mergeRecycleBinFromCloud(data);
          hasAnyData = true;
          console.info('[CloudSyncService] 合并回收站数据: ' + data.length + ' 条');
        }
      }

      // 读取 inspirations.json
      if (await this.cloudFileExists('inspirations.json')) {
        const data = await this.readJsonFromCloud<InspirationItem[]>('inspirations.json');
        if (data && Array.isArray(data) && data.length > 0) {
          workManager.mergeInspirationsFromCloud(data);
          hasAnyData = true;
          console.info('[CloudSyncService] 合并灵感数据: ' + data.length + ' 条');
        }
      }

      console.info('[CloudSyncService] 拉取合并完成, hasAnyData=' + hasAnyData);
      return true;
    } catch (e) {
      console.error('[CloudSyncService] 拉取合并异常: ' + JSON.stringify(e));
      return false;
    }
  }
}

/** 云同步服务单例 */
export const cloudSyncService = CloudSyncService.getInstance();
