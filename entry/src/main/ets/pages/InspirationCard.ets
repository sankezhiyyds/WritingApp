let storage = new LocalStorage();

@Entry(storage)
@Component
struct InspirationCard {
  @LocalStorageProp('title') title: string = '灵感速记';
  @LocalStorageProp('placeholder') placeholder: string = '随手记下灵感...';
  @LocalStorageProp('lastContent') lastContent: string = '';
  @LocalStorageProp('inspirationCount') inspirationCount: string = '0';

  get buttonTextColor(): string {
    return '#FFFFFF';
  }

  get cardBgColor(): string {
    return '#FFFFFF';
  }

  build() {
    Column() {
      // 顶部：灯泡 + 标题
      Row() {
        Text('💡')
          .fontSize(20)
        Text('  ')
          .fontSize(14)
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10 })
      .alignItems(VerticalAlign.Center)

      // 最近灵感预览区
      Column() {
        if (this.lastContent.length > 0) {
          Text('📝 最近')
            .fontSize(11)
            .fontColor('#999999')
            .width('100%')
            .margin({ bottom: 4 })
          Text(this.lastContent)
            .fontSize(13)
            .fontColor('#444444')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(18)
            .width('100%')
        } else {
          Text(this.placeholder)
            .fontSize(13)
            .fontColor('#BBBBBB')
            .width('100%')
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .justifyContent(FlexAlign.Center)

      // 底部：记灵感按钮（水平居中、适中宽度）
      Button('✏️ 记灵感')
        .fontColor(this.buttonTextColor)
        .backgroundColor('#FF6B35')
        .borderRadius(14)
        .height(30)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width('auto')
        .padding({ left: 24, right: 24 })
        .margin({ bottom: 12 })
        .onClick(() => {
          postCardAction(this, {
            'action': 'router',
            'abilityName': 'EntryAbility',
            'params': {
              'target': 'inspiration'
            }
          });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.cardBgColor)
    .borderRadius(12)
  }
}
