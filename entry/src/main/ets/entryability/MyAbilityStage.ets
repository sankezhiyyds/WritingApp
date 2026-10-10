import { AbilityStage, AbilityConstant } from '@kit.AbilityKit';

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
      // 通过 AppStorage 通知 AI 侧栏和 GGUFService 释放临时资源
      AppStorage.setOrCreate('memoryPressureLevel', level);
      console.warn('[MyAbilityStage] Memory pressure detected, notifying components to release buffers');
    }
  }
}
