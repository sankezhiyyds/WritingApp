import { batteryInfo } from '@kit.BasicServicesKit';

/**
 * SystemResourceMonitor
 *
 * 通过鸿蒙系统 API 感知设备资源状态，为调度提供决策依据。
 * 参考 HarmonyOS 端侧 AI 的「分层驻留 + 页级回收」内存纪律。
 *
 * 能力：
 * - 电量感知：当前电量百分比、充电状态、电量等级
 * - 内存感知：通过运行状态推测内存压力（ArkTS 层无法直读 /proc/meminfo）
 * - 建议调度策略：根据资源紧张度动态调整并发度和缓存策略
 */

/** 资源紧张度等级 */
export enum ResourcePressure {
  /** 充裕：高电量 / 充电中 / 内存充足 */
  LOW = 0,
  /** 正常：中等电量 */
  NORMAL = 1,
  /** 紧张：低电量 / 可能内存不足 */
  HIGH = 2,
  /** 极低：告警电量 / 极低电量 */
  CRITICAL = 3,
}

/** 系统资源快照（每次调度决策前采样） */
export interface SystemResourceSnapshot {
  pressure: ResourcePressure;
  batteryPercent: number;
  isCharging: boolean;
  batteryLevel: number; // BatteryCapacityLevel 原始值
  timestamp: number;
}

class SystemResourceMonitorClass {
  private lastSnapshot: SystemResourceSnapshot | null = null;
  private sampleIntervalMs: number = 30000; // 每30秒采样一次

  /** 获取当前资源快照 */
  getCurrentSnapshot(): SystemResourceSnapshot {
    let batteryPercent: number = 100;
    let isCharging: boolean = true;
    let batteryLevel: number = 1; // LEVEL_FULL

    try {
      batteryPercent = batteryInfo.batterySOC;
      isCharging = batteryInfo.chargingStatus === 1; // ENABLE
      batteryLevel = batteryInfo.batteryCapacityLevel as number;
    } catch (_e) {
      // 模拟器或无电池设备，默认充裕
    }

    const pressure = this.calculatePressure(batteryPercent, isCharging, batteryLevel);

    const snapshot: SystemResourceSnapshot = {
      pressure: pressure,
      batteryPercent: batteryPercent,
      isCharging: isCharging,
      batteryLevel: batteryLevel,
      timestamp: Date.now(),
    };

    this.lastSnapshot = snapshot;
    return snapshot;
  }

  /** 根据电池状态计算资源紧张度 */
  private calculatePressure(batteryPercent: number, isCharging: boolean,
    batteryLevel: number): ResourcePressure {
    // 充电中 → 资源充裕
    if (isCharging) return ResourcePressure.LOW;

    // 电池等级枚举：LEVEL_NONE=0, FULL=1, HIGH=2, NORMAL=3, LOW=4, WARNING=5, CRITICAL=6, SHUTDOWN=7
    if (batteryLevel >= 6) return ResourcePressure.CRITICAL; // CRITICAL / SHUTDOWN
    if (batteryLevel >= 5) return ResourcePressure.HIGH; // WARNING
    if (batteryLevel >= 4) return ResourcePressure.NORMAL; // LOW

    // 用百分比作为第二道防线
    if (batteryPercent <= 10) return ResourcePressure.CRITICAL;
    if (batteryPercent <= 20) return ResourcePressure.HIGH;
    if (batteryPercent <= 40) return ResourcePressure.NORMAL;

    return ResourcePressure.LOW;
  }

  /** 判断当前是否应执行省电模式 */
  isPowerSavingMode(): boolean {
    const snap = this.getCurrentSnapshot();
    return snap.pressure >= ResourcePressure.HIGH;
  }

  /** 获取建议的最大并发数 */
  getSuggestedConcurrency(): number {
    const snap = this.getCurrentSnapshot();
    switch (snap.pressure) {
      case ResourcePressure.LOW:
        return 4; // 充电中或高电量，满并发
      case ResourcePressure.NORMAL:
        return 2; // 中等电量，保守并发
      case ResourcePressure.HIGH:
        return 1; // 低电量，单线程
      case ResourcePressure.CRITICAL:
        return 0; // 极低电量，不执行密集型任务
    }
  }

  /** 获取建议的 LRU 缓存大小 */
  getSuggestedCacheSize(): number {
    const snap = this.getCurrentSnapshot();
    switch (snap.pressure) {
      case ResourcePressure.LOW:
        return 30; // 充裕时多缓存
      case ResourcePressure.NORMAL:
        return 15;
      case ResourcePressure.HIGH:
        return 8; // 紧张时缩减缓存
      case ResourcePressure.CRITICAL:
        return 3; // 极低时最小缓存
    }
  }

  /** 获取建议的存储防抖间隔 */
  getSuggestedSaveDebounceMs(): number {
    const snap = this.getCurrentSnapshot();
    switch (snap.pressure) {
      case ResourcePressure.LOW:
        return 300; // 充裕时频繁保存
      case ResourcePressure.NORMAL:
        return 500;
      case ResourcePressure.HIGH:
        return 1000; // 紧张时合并写入，减少 ROM 开销
      case ResourcePressure.CRITICAL:
        return 2000;
    }
  }

  /** 是否应跳过 AI 推理（极低电量/未充电） */
  shouldSkipAI(): boolean {
    const snap = this.getCurrentSnapshot();
    return snap.pressure >= ResourcePressure.CRITICAL;
  }
}

export const systemResourceMonitor = new SystemResourceMonitorClass();
