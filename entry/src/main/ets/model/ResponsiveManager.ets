import mediaquery from '@ohos.mediaquery';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';

/** 断点类型 */
export type BreakpointType = 'sm' | 'md' | 'lg';

/** 设备形态 */
export type DeviceForm = 'phone' | 'foldable' | 'tablet' | 'pc';

/**
 * 响应式布局管理器
 * 基于 mediaquery 实现断点检测，支持折叠屏/平板/PC自适应
 */
export class ResponsiveManager {
  private static instance: ResponsiveManager | null = null;
  private smListener: mediaquery.MediaQueryListener | null = null;
  private mdListener: mediaquery.MediaQueryListener | null = null;
  private lgListener: mediaquery.MediaQueryListener | null = null;
  private currentBreakpoint: BreakpointType = 'sm';
  private listeners: Array<(bp: BreakpointType) => void> = [];

  /** 断点阈值（vp） */
  static readonly BREAKPOINT_SM = 320;
  static readonly BREAKPOINT_MD = 600;
  static readonly BREAKPOINT_LG = 840;

  static getInstance(): ResponsiveManager {
    if (!ResponsiveManager.instance) {
      ResponsiveManager.instance = new ResponsiveManager();
    }
    return ResponsiveManager.instance;
  }

  /** 初始化媒体查询监听 */
  init(context: common.UIAbilityContext): void {
    try {
      // sm: 320vp-600vp
      this.smListener = mediaquery.matchMediaSync('(320vp <= width < 600vp)');
      this.smListener.on('change', (result: mediaquery.MediaQueryResult) => {
        if (result.matches) {
          this.updateBreakpoint('sm');
        }
      });

      // md: 600vp-840vp
      this.mdListener = mediaquery.matchMediaSync('(600vp <= width < 840vp)');
      this.mdListener.on('change', (result: mediaquery.MediaQueryResult) => {
        if (result.matches) {
          this.updateBreakpoint('md');
        }
      });

      // lg: 840vp+
      this.lgListener = mediaquery.matchMediaSync('(width >= 840vp)');
      this.lgListener.on('change', (result: mediaquery.MediaQueryResult) => {
        if (result.matches) {
          this.updateBreakpoint('lg');
        }
      });

      // 初始判断
      if (this.lgListener.matches) {
        this.currentBreakpoint = 'lg';
      } else if (this.mdListener.matches) {
        this.currentBreakpoint = 'md';
      } else {
        this.currentBreakpoint = 'sm';
      }
    } catch (e) {
      console.error('[ResponsiveManager] init failed: ' + JSON.stringify(e));
    }
  }

  private updateBreakpoint(bp: BreakpointType): void {
    if (this.currentBreakpoint !== bp) {
      this.currentBreakpoint = bp;
      this.listeners.forEach(fn => fn(bp));
    }
  }

  /** 获取当前断点 */
  getBreakpoint(): BreakpointType {
    return this.currentBreakpoint;
  }

  /** 注册断点变化监听 */
  onBreakpointChange(callback: (bp: BreakpointType) => void): void {
    this.listeners.push(callback);
  }

  /** 移除监听 */
  offBreakpointChange(callback: (bp: BreakpointType) => void): void {
    this.listeners = this.listeners.filter(fn => fn !== callback);
  }

  /** 是否为小屏（手机/折叠屏折叠态） */
  isSmall(): boolean {
    return this.currentBreakpoint === 'sm';
  }

  /** 是否为中屏（阔直板/折叠屏展开态） */
  isMedium(): boolean {
    return this.currentBreakpoint === 'md';
  }

  /** 是否为大屏（平板横屏/PC） */
  isLarge(): boolean {
    return this.currentBreakpoint === 'lg';
  }

  /** 是否为宽屏（md 或 lg） */
  isWide(): boolean {
    return this.currentBreakpoint === 'md' || this.currentBreakpoint === 'lg';
  }

  /** 获取内容区域最大宽度（vp），大屏限制避免内容过宽 */
  getContentMaxWidth(): number {
    if (this.currentBreakpoint === 'lg') {
      return 1200;
    } else if (this.currentBreakpoint === 'md') {
      return 840;
    }
    return 10000; // sm 不限制
  }

  /** 获取模板网格列数 */
  getTemplateColumns(): number {
    if (this.currentBreakpoint === 'lg') {
      return 4;
    } else if (this.currentBreakpoint === 'md') {
      return 3;
    }
    return 2; // sm 显示2列（原为3，但2列在手机上更舒适）
  }

  /** 是否使用侧边导航（宽屏） */
  useSideNavigation(): boolean {
    return this.isWide();
  }

  /** 获取导航栏宽度 */
  getNavWidth(): number {
    if (this.currentBreakpoint === 'lg') {
      return 240;
    }
    return 200; // md
  }

  /** 是否使用双栏布局（编辑页） */
  useDualPane(): boolean {
    return this.isWide();
  }

  /** 获取双栏比例（左:右） */
  getDualPaneRatio(): string {
    if (this.currentBreakpoint === 'lg') {
      return '1fr 2fr';
    }
    return '1fr 1fr'; // md
  }

  /** 销毁监听 */
  destroy(): void {
    try {
      this.smListener?.off('change');
      this.mdListener?.off('change');
      this.lgListener?.off('change');
    } catch (e) {
      console.error('[ResponsiveManager] destroy failed: ' + JSON.stringify(e));
    }
    this.listeners = [];
  }
}

/** 全局单例 */
export const responsiveManager = ResponsiveManager.getInstance();
