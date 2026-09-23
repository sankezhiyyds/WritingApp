import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import common from '@ohos.app.ability.common';
import { workManager } from './WorkManager';

/** 设备信息 */
export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  deviceType: string;
  networkId: string;
}

/** 设备发现回调 */
export type DeviceDiscoveryCallback = (devices: DeviceInfo[]) => void;

/**
 * 多端协同服务
 * 使用 @kit.DistributedServiceKit distributedDeviceManager 进行设备管理
 * 配合中转站实现跨设备内容传递
 */
export class DistributedSyncService {
  private static instance: DistributedSyncService;
  private context: common.UIAbilityContext | null = null;
  private deviceManager: distributedDeviceManager.DeviceManager | null = null;
  private discoveryCallbacks: DeviceDiscoveryCallback[] = [];
  private readonly BUNDLE_NAME: string = 'com.creativewriting.ai';

  private constructor() {}

  static getInstance(): DistributedSyncService {
    if (!DistributedSyncService.instance) {
      DistributedSyncService.instance = new DistributedSyncService();
    }
    return DistributedSyncService.instance;
  }

  /** 初始化多端协同服务 */
  init(context: common.UIAbilityContext): void {
    this.context = context;
    try {
      this.deviceManager = distributedDeviceManager.createDeviceManager(this.BUNDLE_NAME);
      console.info('[DistributedSyncService] 初始化完成');
    } catch (e) {
      const error = e as BusinessError;
      console.error('[DistributedSyncService] 初始化失败: code=' + error.code + ', msg=' + error.message);
    }
  }

  /** 订阅设备发现 */
  onDeviceDiscovery(callback: DeviceDiscoveryCallback): () => void {
    this.discoveryCallbacks.push(callback);
    return () => {
      this.discoveryCallbacks = this.discoveryCallbacks.filter(fn => fn !== callback);
    };
  }

  private notifyDiscovery(devices: DeviceInfo[]): void {
    for (let i = 0; i < this.discoveryCallbacks.length; i++) {
      this.discoveryCallbacks[i](devices);
    }
  }

  /** 获取可信设备列表（同步） */
  getTrustedDevices(): DeviceInfo[] {
    if (!this.deviceManager) return [];
    try {
      const deviceList = this.deviceManager.getAvailableDeviceListSync();
      const devices: DeviceInfo[] = [];
      for (let i = 0; i < deviceList.length; i++) {
        const d = deviceList[i];
        devices.push({
          deviceId: d.deviceId,
          deviceName: d.deviceName,
          deviceType: d.deviceType,
          networkId: d.networkId || ''
        });
      }
      this.notifyDiscovery(devices);
      return devices;
    } catch (e) {
      console.error('[DistributedSyncService] 获取可信设备失败: ' + JSON.stringify(e));
      return [];
    }
  }

  /**
   * 发送内容到目标设备（通过中转站）
   * 将内容添加到中转站，目标设备可从中转站获取
   */
  sendToDevice(targetDevice: DeviceInfo, title: string, content: string): boolean {
    try {
      workManager.addToTransit(title, content, targetDevice.deviceName, 7);
      console.info('[DistributedSyncService] 已发送内容到设备: ' + targetDevice.deviceName);
      return true;
    } catch (e) {
      console.error('[DistributedSyncService] 发送失败: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 从中转站接收内容到书架
   */
  receiveFromTransit(transitId: string): boolean {
    const transitItems = workManager.getTransitItems();
    const item = transitItems.find(t => t.id === transitId);
    if (item) {
      workManager.createFreeWork(item.title, item.content, 'novel');
      workManager.removeFromTransit(transitId);
      console.info('[DistributedSyncService] 已从中转站接收: ' + item.title);
      return true;
    }
    return false;
  }

  /** 获取本地设备名称 */
  getLocalDeviceName(): string {
    if (!this.deviceManager) return '';
    try {
      return this.deviceManager.getLocalDeviceName();
    } catch (e) {
      return '';
    }
  }

  /** 获取本地设备ID */
  getLocalDeviceId(): string {
    if (!this.deviceManager) return '';
    try {
      return this.deviceManager.getLocalDeviceId();
    } catch (e) {
      return '';
    }
  }

  /** 销毁服务 */
  destroy(): void {
    if (this.deviceManager) {
      try {
        distributedDeviceManager.releaseDeviceManager(this.deviceManager);
      } catch (e) {
        console.error('[DistributedSyncService] 释放设备管理器失败: ' + JSON.stringify(e));
      }
      this.deviceManager = null;
    }
  }
}

export const distributedSyncService = DistributedSyncService.getInstance();
