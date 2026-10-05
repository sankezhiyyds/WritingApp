import { taskpool } from '@kit.ArkTS';
import { systemResourceMonitor, ResourcePressure } from './SystemResourceMonitor';

/**
 * PerformanceOptimizer
 *
 * 通过鸿蒙 TaskPool 系统调度 + 设备资源感知优化 SoC/CPU 性能：
 * - CPU 密集型任务通过 TaskPool 移至独立线程
 * - 根据电量/资源紧张度动态调整并发度（借鉴鸿蒙 HiAI Engine 策略）
 * - 低电量时自动降级，充电时满并发
 */

@Concurrent
export function serializeJsonStringify(obj: object): string {
  return JSON.stringify(obj);
}

@Concurrent
export function serializeJsonParse(jsonStr: string): object {
  return JSON.parse(jsonStr);
}

@Concurrent
export function searchWorksByKeyword(keyword: string, worksJson: string): string {
  const works: object[] = JSON.parse(worksJson) as object[];
  const kw = keyword.toLowerCase();
  const matched: object[] = [];
  for (let i = 0; i < works.length; i++) {
    const item = works[i] as Record<string, string>;
    const title = String(item['title'] ?? '').toLowerCase();
    const content = String(item['content'] ?? '').toLowerCase();
    if (title.includes(kw) || content.includes(kw)) {
      matched.push(works[i]);
    }
  }
  return JSON.stringify(matched);
}

class PerformanceOptimizerClass {
  private maxConcurrency: number = 4;
  private lastConcurrencyCheck: number = 0;
  private readonly CHECK_INTERVAL_MS: number = 30000; // 每30秒重新评估

  constructor() {
    this.refreshConcurrency();
    console.info(`[PerformanceOptimizer] 初始化并发度=${this.maxConcurrency}`);
  }

  /** 根据系统资源状态刷新并发度上限 */
  private refreshConcurrency(): void {
    const now = Date.now();
    if (now - this.lastConcurrencyCheck < this.CHECK_INTERVAL_MS) return;
    this.lastConcurrencyCheck = now;

    // 借鉴鸿蒙 HiAI Engine 策略：根据电量和资源状态动态调频
    const suggested = systemResourceMonitor.getSuggestedConcurrency();
    if (suggested !== this.maxConcurrency) {
      console.info(`[PerformanceOptimizer] 并发度调整: ${this.maxConcurrency} → ${suggested}`);
      this.maxConcurrency = suggested;
    }
  }

  /** 获取当前建议并发度（按需刷新） */
  getSuggestedConcurrency(): number {
    this.refreshConcurrency();
    return this.maxConcurrency;
  }

  /** 是否允许执行 CPU 密集型任务（极低电量时跳过） */
  canRunIntensiveTask(): boolean {
    return !systemResourceMonitor.shouldSkipAI();
  }

  /** 将对象序列化为 JSON（在 TaskPool 中执行） */
  async jsonStringify(obj: object): Promise<string> {
    const task = new taskpool.Task(serializeJsonStringify, obj);
    const result = await taskpool.execute(task) as string;
    return result;
  }

  /** 将 JSON 反序列化为对象（在 TaskPool 中执行） */
  async jsonParse<T>(jsonStr: string): Promise<T> {
    const task = new taskpool.Task(serializeJsonParse, jsonStr);
    const result = await taskpool.execute(task) as T;
    return result;
  }

  /** 在 TaskPool 中搜索作品 */
  async searchWorks(keyword: string, worksJson: string): Promise<object[]> {
    if (!this.canRunIntensiveTask()) {
      return []; // 极低电量时跳过搜索
    }
    const task = new taskpool.Task(searchWorksByKeyword, keyword, worksJson);
    const result = await taskpool.execute(task) as string;
    return JSON.parse(result) as object[];
  }

  /** 并行执行多个任务（受并发度限制） */
  async parallel<T>(tasks: Array<() => Promise<T>>): Promise<T[]> {
    this.refreshConcurrency();
    if (this.maxConcurrency <= 0) return []; // 极低电量时跳过

    const results: T[] = [];
    const limit = this.maxConcurrency;

    for (let i = 0; i < tasks.length; i += limit) {
      const chunk = tasks.slice(i, i + limit);
      const chunkResults = await Promise.all(chunk.map(t => t()));
      results.push(...chunkResults);
    }
    return results;
  }
}

export const performanceOptimizer = new PerformanceOptimizerClass();
