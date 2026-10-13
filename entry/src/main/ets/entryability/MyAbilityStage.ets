import { AbilityStage, AbilityConstant } from '@kit.AbilityKit';
import { workManager } from '../model/WorkManager';

/**
 * Module 级生命周期管理器。
 * onMemoryLevel: 系统内存压力回调，在内存紧张时释放推理临时 buffer。
 */
export default class MyAbilityStage extends AbilityStage {
  onCreate(): void {
    console.info('[MyAbilityStage] onCreate');
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    console.info('[MyAbilityStage] onMemoryLevel: ' + level);
    // MEMORY_LEVEL_CRITICAL = 0, MEMORY_LEVEL_LOW = 1, MEMORY_LEVEL_NORMAL = 2
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL ||
        level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_LOW) {
      // 内存紧张时先同步落盘，防系统杀进程丢数据
      try {
        workManager.forceSaveToDisk();
      } catch (_e) {
        console.warn('[MyAbilityStage] forceSaveToDisk on memory pressure failed');
      }
      // 通过 AppStorage 通知 AI 侧栏和 GGUFService 释放临时资源
      AppStorage.setOrCreate('memoryPressureLevel', level);
      console.warn('[MyAbilityStage] Memory pressure detected, data saved, notifying components to release buffers');
    }
  }
}
