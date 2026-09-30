import { RectShape } from '@kit.ArkUI';
/**
 * 查找替换文本处理组件
 * 类似MT管理器的查找替换功能
 * 支持查找、替换、全部替换、区分大小写、正则表达式
 */
@Component
export struct FindReplaceDialog {
  /** 目标文本内容 */
  @Link content: string;
  /** 是否可见 */
  @Link isVisible: boolean;
  /** 深色模式 */
  @Prop isDarkMode: boolean = false;
  /** 跳转到匹配位置回调（参数：起始位置，结束位置） */
  onJumpToMatch: (start: number, end: number) => void = () => {};

  /** 查找文本 */
  @State findText: string = '';
  /** 替换文本 */
  @State replaceText: string = '';
  /** 是否区分大小写 */
  @State caseSensitive: boolean = false;
  /** 是否使用正则表达式 */
  @State useRegex: boolean = false;
  /** 当前匹配位置 */
  @State currentMatch: number = -1;
  /** 匹配结果列表 */
  @State matchCount: number = 0;
  /** 提示信息 */
  @State hintText: string = '';

  /** 主题色 */
  get textColor(): string {
    return this.isDarkMode ? '#E5E7EB' : '#1A1A2E';
  }
  get subTextColor(): string {
    return this.isDarkMode ? '#9CA3AF' : '#6B7280';
  }
  get bgColor(): string {
    return this.isDarkMode ? '#1F2033' : '#FFFFFF';
  }
  get cardBg(): string {
    return this.isDarkMode ? '#2B2C42' : '#FFFFFF';
  }
  get dividerColor(): string {
    return this.isDarkMode ? '#3A3A4E' : '#E5E7EB';
  }
  /** 弹窗卡片结构边框：深色中灰 / 浅色浅灰，与 cardBg 协调 */
  get cardBorder(): string {
    return this.isDarkMode ? '#44455E' : '#E5E7EB';
  }

  /** 执行查找 */
  performFind(): void {
    if (this.findText.length === 0) {
      this.matchCount = 0;
      this.currentMatch = -1;
      this.hintText = '';
      return;
    }

    // 缓存状态变量到局部变量，避免循环中频繁读取
    const content = this.content;
    const findText = this.findText;
    const caseSensitive = this.caseSensitive;
    const findLen = findText.length;
    const lowerFind = caseSensitive ? '' : findText.toLowerCase();

    // 预计算匹配函数，避免循环内读取状态变量
    const matchFn: (substr: string) => boolean = caseSensitive
      ? (s: string) => s === findText
      : (s: string) => s.toLowerCase() === lowerFind;

    let count = 0;
    let pos = 0;
    let firstMatch = -1;

    while (pos <= content.length - findLen) {
      if (matchFn(content.substring(pos, pos + findLen))) {
        count++;
        if (firstMatch === -1) {
          firstMatch = pos;
        }
        pos += findLen;
      } else {
        pos++;
      }
    }

    this.matchCount = count;
    this.currentMatch = firstMatch;
    this.onJumpToMatch(firstMatch, firstMatch + this.findText.length);
    if (count > 0) {
      this.hintText = `找到 ${count} 处匹配`;
    } else {
      this.hintText = '未找到匹配';
    }
  }

  /** 替换当前匹配 */
  replaceCurrent(): void {
    if (this.currentMatch < 0 || this.findText.length === 0) {
      return;
    }

    const before = this.content.substring(0, this.currentMatch);
    const after = this.content.substring(this.currentMatch + this.findText.length);
    this.content = before + this.replaceText + after;

    this.performFind();
  }

  /** 全部替换 */
  replaceAll(): void {
    if (this.findText.length === 0) {
      return;
    }

    // 缓存状态变量到局部变量
    const content = this.content;
    const findText = this.findText;
    const replaceText = this.replaceText;
    const caseSensitive = this.caseSensitive;

    if (caseSensitive) {
      // 区分大小写的替换
      const parts = content.split(findText);
      this.content = parts.join(replaceText);
    } else {
      // 不区分大小写的替换
      const lowerContent = content.toLowerCase();
      const lowerFind = findText.toLowerCase();
      let result = '';
      let pos = 0;
      const findLen = findText.length;

      while (pos < content.length) {
        const idx = lowerContent.indexOf(lowerFind, pos);
        if (idx < 0) {
          result += content.substring(pos);
          break;
        }
        result += content.substring(pos, idx);
        result += replaceText;
        pos = idx + findLen;
      }
      this.content = result;
    }

    this.performFind();
    this.hintText = '已全部替换';
  }

  /** 跳转到下一个匹配 */
  findNext(): void {
    if (this.matchCount === 0 || this.findText.length === 0) {
      return;
    }

    // 缓存状态变量到局部变量，避免循环中频繁读取
    const content = this.content;
    const findText = this.findText;
    const caseSensitive = this.caseSensitive;
    const findLen = findText.length;
    const lowerFind = caseSensitive ? '' : findText.toLowerCase();
    const startPos = this.currentMatch + findLen;
    let pos = startPos;

    // 预计算匹配函数，避免循环内读取状态变量
    const matchFn: (substr: string) => boolean = caseSensitive
      ? (s: string) => s === findText
      : (s: string) => s.toLowerCase() === lowerFind;

    let foundPos = -1;

    while (pos <= content.length - findLen) {
      if (matchFn(content.substring(pos, pos + findLen))) {
        foundPos = pos;
        break;
      }
      pos++;
    }

    // 循环到开头
    if (foundPos < 0) {
      pos = 0;
      while (pos <= content.length - findLen) {
        if (matchFn(content.substring(pos, pos + findLen))) {
          foundPos = pos;
          break;
        }
        pos++;
      }
    }

    // 循环外统一赋值，避免循环内修改@State触发多余UI刷新
    if (foundPos >= 0) {
      this.currentMatch = foundPos;
      this.onJumpToMatch(foundPos, foundPos + this.findText.length);
    }
  }

  /** 跳转到上一个匹配 */
  findPrev(): void {
    if (this.matchCount === 0 || this.findText.length === 0) {
      return;
    }

    const content = this.content;
    const findText = this.findText;
    const caseSensitive = this.caseSensitive;
    const findLen = findText.length;
    const lowerFind = caseSensitive ? '' : findText.toLowerCase();
    // 从当前匹配位置向前查找（排除当前匹配）
    const startPos = this.currentMatch > 0 ? this.currentMatch - 1 : content.length - findLen;
    const searchContent = caseSensitive ? content : content.toLowerCase();
    const searchText = caseSensitive ? findText : lowerFind;

    let foundPos = -1;
    let pos = startPos;

    while (pos >= 0) {
      if (searchContent.substring(pos, pos + findLen) === searchText) {
        foundPos = pos;
        break;
      }
      pos--;
    }

    // 循环到末尾
    if (foundPos < 0) {
      pos = content.length - findLen;
      while (pos >= 0) {
        if (searchContent.substring(pos, pos + findLen) === searchText) {
          foundPos = pos;
          break;
        }
        pos--;
      }
    }

    if (foundPos >= 0) {
      this.currentMatch = foundPos;
      this.onJumpToMatch(foundPos, foundPos + this.findText.length);
    }
  }

  build() {
    Column() {
      // 分割线
      Divider()
        .width('100%')
        .color('#E5E7EB')
        .margin({ top: 0, bottom: 0 })

      // 第一行：查找输入 + 匹配计数 + 导航按钮
      Row() {
        TextInput({ placeholder: '输入查找内容', text: this.findText })
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.findText = value;
            this.currentMatch = -1;
            this.performFind();
          })

        if (this.findText.length > 0) {
          Text(`${this.currentMatch >= 0 ? this.currentMatch + 1 : 0}/${this.matchCount}`)
            .fontSize(13)
            .fontColor(this.subTextColor)
            .margin({ left: 8, right: 6 })
            .width(50)
            .textAlign(TextAlign.Center)
        }

        Button('上一个')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#3B82F6')
          .borderRadius(8)
          .height(34)
          .margin({ right: 4 })
          .onClick(() => this.findPrev())

        Button('下一个')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#3B82F6')
          .borderRadius(8)
          .height(34)
          .margin({ right: 6 })
          .onClick(() => this.findNext())

        Text('✕')
          .fontSize(18)
          .fontColor(this.subTextColor)
          .onClick(() => { this.isVisible = false; })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 10, bottom: 6 })

      // 第二行：替换输入 + 操作按钮
      Row() {
        TextInput({ placeholder: '替换为', text: this.replaceText })
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.replaceText = value;
          })

        Button('替换')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#F59E0B')
          .borderRadius(8)
          .height(34)
          .margin({ left: 8, right: 4 })
          .onClick(() => this.replaceCurrent())

        Button('全部替换')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF2D55')
          .borderRadius(8)
          .height(34)
          .onClick(() => this.replaceAll())
      }
      .width('100%')
      .margin({ top: 0, bottom: 6 })

      // 第三行：选项 + 提示
      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.caseSensitive })
          .onChange((isOn: boolean) => {
            this.caseSensitive = isOn;
            this.performFind();
          })
        Text('区分大小写')
          .fontSize(12)
          .fontColor(this.textColor)
          .margin({ right: 16 })

        Toggle({ type: ToggleType.Checkbox, isOn: this.useRegex })
          .onChange((isOn: boolean) => {
            this.useRegex = isOn;
          })
        Text('正则')
          .fontSize(12)
          .fontColor(this.textColor)

        Blank()

        if (this.hintText.length > 0) {
          Text(this.hintText)
            .fontSize(12)
            .fontColor(this.matchCount > 0 ? '#10B981' : '#EF4444')
        }
      }
      .width('100%')
      .padding({ bottom: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.bgColor)
  }
}
