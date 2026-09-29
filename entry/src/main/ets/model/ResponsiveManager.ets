import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { display } from '@kit.ArkUI';

/** 断点类型 */
export type BreakpointType = 'sm' | 'md' | 'lg';

/** 设备形态 */
export type DeviceForm = 'phone' | 'foldable' | 'tablet' | 'pc';

/**
 * 响应式布局管理器
 * 基于窗口宽度实现断点检测，支持折叠屏/平板/PC自适应
 */
export class ResponsiveManager {
  private static instance: ResponsiveManager | null = null;
  private currentBreakpoint: BreakpointType = 'sm';
  private listeners: Array<(bp: BreakpointType) => void> = [];
  private windowObj: window.Window | null = null;
  private density: number = 3.0;

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

  /** 初始化窗口监听 */
  init(context: common.UIAbilityContext): void {
    try {
      // 获取屏幕密度（px转vp用）
      const defaultDisplay = display.getDefaultDisplaySync();
      this.density = defaultDisplay.densityPixels;

      window.getLastWindow(context).then((win: window.Window) => {
        this.windowObj = win;
        // 初始断点检测
        const props = win.getWindowProperties();
        this.updateBreakpointFromWidthVp(props.windowRect.width / this.density);

        win.on('windowSizeChange', (size: window.Size) => {
          console.info('[ResponsiveManager] windowSizeChange: ' + size.width + 'x' + size.height);
          this.updateBreakpointFromWidthVp(size.width / this.density);
        });
      }).catch(() => {
        console.warn('[ResponsiveManager] window listener init failed');
      });
    } catch (e) {
      console.error('[ResponsiveManager] init failed: ' + JSON.stringify(e));
    }
  }

  private updateBreakpointFromWidthVp(widthVp: number): void {
    let bp: BreakpointType;
    if (widthVp < ResponsiveManager.BREAKPOINT_MD) {
      bp = 'sm';
    } else if (widthVp < ResponsiveManager.BREAKPOINT_LG) {
      bp = 'md';
    } else {
      bp = 'lg';
    }
    this.updateBreakpoint(bp);
  }

  private updateBreakpoint(bp: BreakpointType): void {
    if (this.currentBreakpoint !== bp) {
      this.currentBreakpoint = bp;
      AppStorage.setOrCreate('appBreakpoint', bp);
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
    return 2; // sm 显示2列
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
      if (this.windowObj) {
        this.windowObj.off('windowSizeChange');
      }
    } catch (e) {
      console.error('[ResponsiveManager] destroy failed: ' + JSON.stringify(e));
    }
    this.listeners = [];
  }
}

/** 全局单例 */
export const responsiveManager = ResponsiveManager.getInstance();
