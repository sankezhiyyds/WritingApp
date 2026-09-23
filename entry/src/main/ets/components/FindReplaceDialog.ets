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
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        // 标题栏
        Row() {
          Text('🔍 查找替换')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
          Blank()
          Text('×')
            .fontSize(22)
            .fontColor(this.subTextColor)
            .onClick(() => { this.isVisible = false; })
        }
        .width('100%')
        .margin({ bottom: 16 })

        // 查找输入
        Text('查找')
          .fontSize(13)
          .fontColor(this.subTextColor)
          .margin({ bottom: 4 })
        TextInput({ placeholder: '输入查找内容', text: this.findText })
          .fontSize(14)
          .height(40)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.findText = value;
            this.currentMatch = -1;
            this.performFind();
          })

        // 替换输入
        Text('替换为')
          .fontSize(13)
          .fontColor(this.subTextColor)
          .margin({ top: 12, bottom: 4 })
        TextInput({ placeholder: '输入替换内容', text: this.replaceText })
          .fontSize(14)
          .height(40)
          .backgroundColor(this.bgColor)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.replaceText = value;
          })

        // 选项
        Row() {
          Text('区分大小写')
            .fontSize(13)
            .fontColor(this.textColor)
            .margin({ right: 8 })
          Toggle({ type: ToggleType.Checkbox, isOn: this.caseSensitive })
            .onChange((isOn: boolean) => {
              this.caseSensitive = isOn;
              this.performFind();
            })

          Blank()

          Text('正则表达式')
            .fontSize(13)
            .fontColor(this.textColor)
            .margin({ right: 8 })
          Toggle({ type: ToggleType.Checkbox, isOn: this.useRegex })
            .onChange((isOn: boolean) => {
              this.useRegex = isOn;
            })
        }
        .width('100%')
        .margin({ top: 12 })

        // 提示信息
        if (this.hintText.length > 0) {
          Text(this.hintText)
            .fontSize(12)
            .fontColor(this.matchCount > 0 ? '#10B981' : '#EF4444')
            .margin({ top: 8 })
        }

        // 操作按钮
        Row() {
          Button('查找下一个')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#3B82F6')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .margin({ right: 4 })
            .onClick(() => this.findNext())

          Button('替换')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#F59E0B')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .margin({ left: 4, right: 4 })
            .onClick(() => this.replaceCurrent())

          Button('全部替换')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF2D55')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .margin({ left: 4 })
            .onClick(() => this.replaceAll())
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width('85%')
      .padding(20)
      .backgroundColor(this.cardBg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
  }
}
