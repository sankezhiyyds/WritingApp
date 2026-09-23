let storage = new LocalStorage();

@Entry(storage)
@Component
struct InspirationCard {
  @LocalStorageProp('title') title: string = '灵感速记';
  @LocalStorageProp('placeholder') placeholder: string = '随手记下灵感...';
  @LocalStorageProp('lastContent') lastContent: string = '';
  @LocalStorageProp('inspirationCount') inspirationCount: string = '0';

  build() {
    Column() {
      // 标题行
      Row() {
        Text(this.title)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)

        Text('💡 ' + this.inspirationCount)
          .fontColor('#FF6B35')
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })

      // 最近灵感预览
      Column() {
        if (this.lastContent.length > 0) {
          Text(this.lastContent)
            .fontColor('#555555')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 12, right: 12 })
        } else {
          Text(this.placeholder)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 12, right: 12 })
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部按钮：点击打开应用添加灵感
      Row() {
        Text('已记录 ' + this.inspirationCount + ' 条灵感')
          .fontColor('#999999')
          .layoutWeight(1)

        Button('记灵感')
          .fontColor('#FFFFFF')
          .backgroundColor('#FF6B35')
          .borderRadius(16)
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            // 通过router事件拉起应用
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
      .height(44)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}
