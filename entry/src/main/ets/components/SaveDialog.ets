/**
 * 保存对话框组件
 * 支持编辑文件名、新建文件夹或选择已有文件夹保存
 */
import { workManager, BookshelfFolder } from '../model/WorkManager';

@Component
export struct SaveDialog {
  /** 是否可见 */
  @Link isVisible: boolean;
  /** 默认文件名 */
  @Prop defaultTitle: string = '';
  /** 深色模式 */
  @Prop isDarkMode: boolean = false;
  /** 保存回调 - 参数: 文件名, 文件夹ID(空字符串表示不指定文件夹) */
  onSave: (title: string, folderId: string) => void = () => {};

  /** 编辑的文件名 */
  @State editTitle: string = '';
  /** 文件夹列表 */
  @State folders: BookshelfFolder[] = [];
  /** 选中的文件夹ID */
  @State selectedFolderId: string = '';
  /** 是否正在新建文件夹 */
  @State isCreatingFolder: boolean = false;
  /** 新建文件夹名称 */
  @State newFolderName: string = '';

  /** 主题色 */
  get bgColor(): string {
    return this.isDarkMode ? '#1E1E1E' : '#FFFFFF';
  }
  get cardBg(): string {
    return this.isDarkMode ? '#2D2D2D' : '#F5F5F5';
  }
  get textColor(): string {
    return this.isDarkMode ? '#E0E0E0' : '#333333';
  }
  get subTextColor(): string {
    return this.isDarkMode ? '#9E9E9E' : '#666666';
  }
  get dividerColor(): string {
    return this.isDarkMode ? '#3D3D3D' : '#E0E0E0';
  }
  get accentColor(): string {
    return '#3B82F6';
  }

  aboutToAppear() {
    this.editTitle = this.defaultTitle;
    this.folders = workManager.getFolders();
  }

  build() {
    if (this.isVisible) {
      Stack() {
        // 遮罩层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.5)')
          .onClick(() => {
            this.isVisible = false;
          })

        // 对话框主体
        Column() {
          // 标题栏
          Row() {
            Text('保存到书架')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
            Blank()
            Image($r('sys.media.ohos_ic_public_cancel'))
              .width(24)
              .height(24)
              .fillColor(this.subTextColor)
              .onClick(() => {
                this.isVisible = false;
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: 20, right: 20 })

          // 分割线
          Divider()
            .color(this.dividerColor)
            .width('100%')

          // 文件名输入
          Column() {
            Text('文件名称')
              .fontSize(14)
              .fontColor(this.subTextColor)
              .margin({ bottom: 8 })

            TextInput({ text: this.editTitle, placeholder: '请输入文件名称' })
              .fontSize(16)
              .fontColor(this.textColor)
              .backgroundColor(this.cardBg)
              .borderRadius(8)
              .height(44)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.editTitle = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 16 })

          // 文件夹选择区域
          Column() {
            Text('选择文件夹')
              .fontSize(14)
              .fontColor(this.subTextColor)
              .margin({ bottom: 8 })

            // 文件夹列表
            Scroll() {
              Column() {
                // 不指定文件夹选项
                this.FolderItem('', '不指定文件夹', '#9E9E9E')

                // 已有文件夹
                ForEach(this.folders, (folder: BookshelfFolder) => {
                  this.FolderItem(folder.id, folder.name, folder.coverColor)
                }, (folder: BookshelfFolder) => folder.id)

                // 新建文件夹输入
                if (this.isCreatingFolder) {
                  Row() {
                    TextInput({ text: this.newFolderName, placeholder: '输入新文件夹名称' })
                      .fontSize(14)
                      .fontColor(this.textColor)
                      .backgroundColor(this.cardBg)
                      .borderRadius(8)
                      .height(40)
                      .layoutWeight(1)
                      .padding({ left: 10, right: 10 })
                      .onChange((value: string) => {
                        this.newFolderName = value;
                      })

                    Button('确定')
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .backgroundColor(this.accentColor)
                      .borderRadius(8)
                      .height(40)
                      .margin({ left: 8 })
                      .onClick(() => {
                        this.confirmCreateFolder();
                      })
                  }
                  .width('100%')
                  .margin({ top: 8 })
                }
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)

            // 新建文件夹按钮
            Button(this.isCreatingFolder ? '取消新建' : '+ 新建文件夹')
              .fontSize(14)
              .fontColor(this.accentColor)
              .backgroundColor(Color.Transparent)
              .borderWidth(1)
              .borderColor(this.accentColor)
              .borderRadius(8)
              .height(36)
              .width('100%')
              .margin({ top: 8 })
              .onClick(() => {
                this.isCreatingFolder = !this.isCreatingFolder;
                this.newFolderName = '';
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 16, bottom: 16 })
          .layoutWeight(1)

          // 底部按钮
          Row() {
            Button('取消')
              .fontSize(16)
              .fontColor(this.subTextColor)
              .backgroundColor(this.cardBg)
              .borderRadius(24)
              .height(44)
              .layoutWeight(1)
              .margin({ right: 8 })
              .onClick(() => {
                this.isVisible = false;
              })

            Button('保存')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accentColor)
              .borderRadius(24)
              .height(44)
              .layoutWeight(1)
              .margin({ left: 8 })
              .onClick(() => {
                this.handleSave();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 20 })
        }
        .width('85%')
        .height('70%')
        .backgroundColor(this.bgColor)
        .borderRadius(16)
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
  }

  @Builder
  FolderItem(folderId: string, folderName: string, coverColor: string) {
    Row() {
      // 文件夹图标
      Column() {
        Text('📁')
          .fontSize(20)
      }
      .width(36)
      .height(36)
      .borderRadius(8)
      .backgroundColor(coverColor)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(folderName)
        .fontSize(15)
        .fontColor(this.textColor)
        .margin({ left: 12 })
        .layoutWeight(1)

      // 选中标记
      if (this.selectedFolderId === folderId) {
        Text('✓')
          .fontSize(18)
          .fontColor(this.accentColor)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .borderRadius(8)
    .backgroundColor(this.selectedFolderId === folderId ? this.cardBg : Color.Transparent)
    .margin({ top: 4 })
    .onClick(() => {
      this.selectedFolderId = folderId;
    })
  }

  /** 确认新建文件夹 */
  private confirmCreateFolder() {
    if (this.newFolderName.trim().length === 0) {
      return;
    }
    const folder = workManager.createFolder(this.newFolderName.trim());
    this.folders = workManager.getFolders();
    this.selectedFolderId = folder.id;
    this.isCreatingFolder = false;
    this.newFolderName = '';
  }

  /** 处理保存 */
  private handleSave() {
    const title = this.editTitle.trim();
    if (title.length === 0) {
      return;
    }
    this.onSave(title, this.selectedFolderId);
    this.isVisible = false;
  }
}
