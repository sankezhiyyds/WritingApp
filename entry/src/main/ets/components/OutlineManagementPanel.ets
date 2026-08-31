import { workManager, OutlineNode, CharacterInfo, SceneInfo } from '../model/WorkManager';
import { promptAction } from '@kit.ArkUI';

/**
 * 大纲管理面板组件
 * 包含三个Tab：大纲树、角色、场景
 */
@Component
export struct OutlineManagementPanel {
  @Prop workId: string;
  @Prop workTitle: string;
  @Prop cardBg: string;
  @Prop bgColor: string;
  @Prop textColor: string;
  onClose: () => void = () => {};

  @State outlineTab: number = 0;
  @State outlineNodes: OutlineNode[] = [];
  @State characterList: CharacterInfo[] = [];
  @State sceneList: SceneInfo[] = [];
  @State editingNodeId: string = '';
  @State editingNodeTitle: string = '';
  @State editingNodeContent: string = '';
  @State editingCharId: string = '';
  @State editingCharName: string = '';
  @State editingCharRole: string = '';
  @State editingSceneId: string = '';
  @State editingSceneTitle: string = '';
  @State editingSceneLocation: string = '';
  @State editingSceneTime: string = '';
  @State editingSceneSummary: string = '';
  @State showAddNodeDialog: boolean = false;
  @State addNodeParentId: string = '';
  @State addNodeLevel: number = 0;
  @State newNodeName: string = '';
  @State showCharDialog: boolean = false;
  @State showSceneDialog: boolean = false;

  aboutToAppear() {
    this.refreshData();
  }

  refreshData() {
    const work = workManager.getWork(this.workId);
    if (work) {
      this.outlineNodes = work.outline ? [...work.outline] : [];
      this.characterList = work.characters ? [...work.characters] : [];
      this.sceneList = work.scenes ? [...work.scenes] : [];
    }
  }

  getVisibleNodes(): OutlineNode[] {
    const sorted = [...this.outlineNodes].sort((a, b) => a.order - b.order);
    const result: OutlineNode[] = [];
    const addChildren = (parentId: string) => {
      const children = sorted.filter(n => n.parentId === parentId);
      for (const child of children) {
        result.push(child);
        if (!child.collapsed) {
          addChildren(child.id);
        }
      }
    };
    addChildren('');
    return result;
  }

  hasChildren(nodeId: string): boolean {
    return this.outlineNodes.some(n => n.parentId === nodeId);
  }

  getLevelLabel(level: number): string {
    if (level === 0) return '卷';
    if (level === 1) return '章';
    return '节';
  }

  build() {
    Column() {
      // 头部
      Row() {
        Text('📋 大纲管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .layoutWeight(1)

        Text('✕')
          .fontSize(20)
          .fontColor('#9CA3AF')
          .onClick(() => { this.onClose(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Text(this.workTitle)
        .fontSize(13)
        .fontColor('#6B7280')
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 12 })

      // Tab栏
      Row() {
        ForEach(['大纲树', '角色', '场景'], (tab: string, index: number) => {
          Text(tab)
            .fontSize(14)
            .fontWeight(this.outlineTab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.outlineTab === index ? '#FF6B35' : '#6B7280')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor(this.outlineTab === index ? '#FFF7ED' : 'transparent')
            .margin({ right: 8 })
            .onClick(() => { this.outlineTab = index; })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 12 })

      // 内容区
      Column() {
        if (this.outlineTab === 0) {
          this.OutlineTreeContent()
        } else if (this.outlineTab === 1) {
          this.CharacterContent()
        } else {
          this.SceneContent()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  // ========== 大纲树 ==========
  @Builder
  OutlineTreeContent() {
    Scroll() {
      Column() {
        if (this.getVisibleNodes().length === 0) {
          Text('暂无大纲，点击下方按钮添加')
            .fontSize(14)
            .fontColor('#9CA3AF')
            .margin({ top: 40 })
        }

        ForEach(this.getVisibleNodes(), (node: OutlineNode) => {
          Row() {
            Text('').width(node.level * 20)

            if (this.hasChildren(node.id)) {
              Text(node.collapsed ? '▶' : '▼')
                .fontSize(10).fontColor('#9CA3AF').width(20).textAlign(TextAlign.Center)
                .onClick(() => {
                  workManager.toggleOutlineCollapsed(this.workId, node.id);
                  this.refreshData();
                })
            } else {
              Text('').width(20)
            }

            Text(this.getLevelLabel(node.level))
              .fontSize(11).fontColor('#FF6B35').width(20)

            Text(node.title)
              .fontSize(14).fontColor(this.textColor).layoutWeight(1)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

            Text('✏').fontSize(14).fontColor('#6B7280').margin({ left: 8 })
              .onClick(() => {
                this.editingNodeId = node.id;
                this.editingNodeTitle = node.title;
                this.editingNodeContent = node.content;
              })

            if (node.level < 2) {
              Text('＋').fontSize(14).fontColor('#FF6B35').margin({ left: 8 })
                .onClick(() => {
                  this.addNodeParentId = node.id;
                  this.addNodeLevel = node.level + 1;
                  this.newNodeName = '';
                  this.showAddNodeDialog = true;
                })
            }

            Text('↑').fontSize(12).fontColor('#9CA3AF').margin({ left: 8 })
              .onClick(() => {
                workManager.moveOutlineNode(this.workId, node.id, 'up');
                this.refreshData();
              })

            Text('↓').fontSize(12).fontColor('#9CA3AF').margin({ left: 4 })
              .onClick(() => {
                workManager.moveOutlineNode(this.workId, node.id, 'down');
                this.refreshData();
              })

            Text('🗑').fontSize(12).fontColor('#EF4444').margin({ left: 8 })
              .onClick(() => {
                promptAction.showDialog({
                  title: '确认删除',
                  message: '删除该节点及其子节点？',
                  buttons: [
                    { text: '取消', color: '#666666' },
                    { text: '删除', color: '#EF4444' }
                  ]
                }).then((res: promptAction.ShowDialogSuccessResponse) => {
                  if (res.index === 1) {
                    workManager.deleteOutlineNode(this.workId, node.id);
                    this.refreshData();
                  }
                });
              })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 0.5 }, color: '#E5E7EB' })
        })

        Button('＋ 添加卷')
          .fontSize(14).fontColor('#FF6B35').backgroundColor('#FFF7ED')
          .borderRadius(8).height(36).width('100%').margin({ top: 16 })
          .onClick(() => {
            this.addNodeParentId = '';
            this.addNodeLevel = 0;
            this.newNodeName = '';
            this.showAddNodeDialog = true;
          })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')

    if (this.showAddNodeDialog) {
      this.AddNodeDialog()
    }
    if (this.editingNodeId) {
      this.EditNodeDialog()
    }
  }

  @Builder
  AddNodeDialog() {
    Stack() {
      Column() {
        Text('添加' + this.getLevelLabel(this.addNodeLevel))
          .fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

        TextInput({ placeholder: '请输入名称', text: this.newNodeName })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' })
          .onChange((v: string) => { this.newNodeName = v; })

        Row() {
          Button('取消')
            .fontSize(14).fontColor('#666666').backgroundColor('#F3F4F6')
            .borderRadius(8).height(36).layoutWeight(1).margin({ right: 8 })
            .onClick(() => { this.showAddNodeDialog = false; })

          Button('添加')
            .fontSize(14).fontColor('#FFFFFF').backgroundColor('#FF6B35')
            .borderRadius(8).height(36).layoutWeight(1)
            .onClick(() => {
              if (this.newNodeName.trim()) {
                workManager.addOutlineNode(this.workId, this.newNodeName.trim(), this.addNodeParentId, this.addNodeLevel);
                this.refreshData();
                this.showAddNodeDialog = false;
              }
            })
        }
        .width('80%').margin({ top: 12 })
      }
      .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16)
    }
    .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
  }

  // ========== 角色管理 ==========
  @Builder
  CharacterContent() {
    Scroll() {
      Column() {
        if (this.characterList.length === 0) {
          Text('暂无角色，点击下方按钮添加')
            .fontSize(14).fontColor('#9CA3AF').margin({ top: 40 })
        }

        ForEach(this.characterList, (char: CharacterInfo) => {
          Column() {
            Row() {
              Text(char.name)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)

              Text(char.role)
                .fontSize(11).fontColor('#FF6B35').backgroundColor('#FFF7ED')
                .borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 })

              Text('🗑').fontSize(12).fontColor('#EF4444').margin({ left: 8 })
                .onClick(() => {
                  workManager.deleteCharacter(this.workId, char.id);
                  this.refreshData();
                })
            }
            .width('100%').margin({ bottom: 4 })

            if (char.description) {
              Text(char.description)
                .fontSize(12).fontColor('#6B7280').maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }
            if (char.personality) {
              Text('性格：' + char.personality)
                .fontSize(11).fontColor('#9CA3AF').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 2 })
            }
          }
          .width('100%').padding(12).backgroundColor(this.cardBg)
          .borderRadius(10).margin({ bottom: 8 })
          .onClick(() => {
            this.editingCharId = char.id;
            this.editingCharName = char.name;
            this.editingCharRole = char.role;
            this.showCharDialog = true;
          })
        })

        Button('＋ 添加角色')
          .fontSize(14).fontColor('#FF6B35').backgroundColor('#FFF7ED')
          .borderRadius(8).height(36).width('100%').margin({ top: 16 })
          .onClick(() => {
            this.editingCharId = '';
            this.editingCharName = '';
            this.editingCharRole = '主角';
            this.showCharDialog = true;
          })
      }
      .width('100%')
    }
    .layoutWeight(1).width('100%')

    if (this.showCharDialog) {
      this.CharDialog()
    }
  }

  @Builder
  CharDialog() {
    Stack() {
      Column() {
        Text(this.editingCharId ? '编辑角色' : '添加角色')
          .fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

        TextInput({ placeholder: '角色名称', text: this.editingCharName })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' })
          .onChange((v: string) => { this.editingCharName = v; })

        Row() {
          ForEach(['主角', '配角', '反派', '路人'], (role: string) => {
            Text(role)
              .fontSize(13)
              .fontColor(this.editingCharRole === role ? '#FFFFFF' : '#6B7280')
              .backgroundColor(this.editingCharRole === role ? '#FF6B35' : '#F3F4F6')
              .borderRadius(12).padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .margin({ right: 8 })
              .onClick(() => { this.editingCharRole = role; })
          })
        }
        .width('80%').margin({ top: 8 })

        Row() {
          Button('取消')
            .fontSize(14).fontColor('#666666').backgroundColor('#F3F4F6')
            .borderRadius(8).height(36).layoutWeight(1).margin({ right: 8 })
            .onClick(() => { this.showCharDialog = false; })

          Button('保存')
            .fontSize(14).fontColor('#FFFFFF').backgroundColor('#FF6B35')
            .borderRadius(8).height(36).layoutWeight(1)
            .onClick(() => {
              if (this.editingCharName.trim()) {
                if (this.editingCharId) {
                  workManager.updateCharacter(this.workId, this.editingCharId, {
                    name: this.editingCharName, role: this.editingCharRole
                  });
                } else {
                  workManager.addCharacter(this.workId, this.editingCharName.trim(), this.editingCharRole);
                }
                this.refreshData();
                this.showCharDialog = false;
              }
            })
        }
        .width('80%').margin({ top: 12 })
      }
      .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16)
    }
    .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
  }

  @Builder
  EditNodeDialog() {
    Stack() {
      Column() {
        Text('编辑节点')
          .fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

        TextInput({ placeholder: '标题', text: this.editingNodeTitle })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' })
          .onChange((v: string) => { this.editingNodeTitle = v; })

        TextArea({ placeholder: '描述（可选）', text: this.editingNodeContent })
          .fontSize(14).width('80%').height(80).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' }).margin({ top: 8 })
          .onChange((v: string) => { this.editingNodeContent = v; })

        Row() {
          Button('取消')
            .fontSize(14).fontColor('#666666').backgroundColor('#F3F4F6')
            .borderRadius(8).height(36).layoutWeight(1).margin({ right: 8 })
            .onClick(() => { this.editingNodeId = ''; })

          Button('保存')
            .fontSize(14).fontColor('#FFFFFF').backgroundColor('#FF6B35')
            .borderRadius(8).height(36).layoutWeight(1)
            .onClick(() => {
              if (this.editingNodeTitle.trim()) {
                workManager.updateOutlineNode(this.workId, this.editingNodeId, this.editingNodeTitle.trim(), this.editingNodeContent);
                this.refreshData();
                this.editingNodeId = '';
              }
            })
        }
        .width('80%').margin({ top: 12 })
      }
      .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16)
    }
    .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
  }

  // ========== 场景管理 ==========
  @Builder
  SceneContent() {
    Scroll() {
      Column() {
        if (this.sceneList.length === 0) {
          Text('暂无场景，点击下方按钮添加')
            .fontSize(14).fontColor('#9CA3AF').margin({ top: 40 })
        }

        ForEach(this.sceneList, (scene: SceneInfo) => {
          Column() {
            Row() {
              Text((scene.order + 1) + '. ' + scene.title)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)

              Text('🗑').fontSize(12).fontColor('#EF4444')
                .onClick(() => {
                  workManager.deleteScene(this.workId, scene.id);
                  this.refreshData();
                })
            }
            .width('100%').margin({ bottom: 4 })

            if (scene.location) {
              Text('📍 ' + scene.location)
                .fontSize(12).fontColor('#6B7280').width('100%').margin({ top: 2 })
            }
            if (scene.time) {
              Text('🕐 ' + scene.time)
                .fontSize(12).fontColor('#6B7280').width('100%').margin({ top: 2 })
            }
            if (scene.summary) {
              Text(scene.summary)
                .fontSize(12).fontColor('#9CA3AF').maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 4 })
            }
          }
          .width('100%').padding(12).backgroundColor(this.cardBg)
          .borderRadius(10).margin({ bottom: 8 })
          .onClick(() => {
            this.editingSceneId = scene.id;
            this.editingSceneTitle = scene.title;
            this.editingSceneLocation = scene.location;
            this.editingSceneTime = scene.time;
            this.editingSceneSummary = scene.summary;
            this.showSceneDialog = true;
          })
        })

        Button('＋ 添加场景')
          .fontSize(14).fontColor('#FF6B35').backgroundColor('#FFF7ED')
          .borderRadius(8).height(36).width('100%').margin({ top: 16 })
          .onClick(() => {
            this.editingSceneId = '';
            this.editingSceneTitle = '';
            this.editingSceneLocation = '';
            this.editingSceneTime = '';
            this.editingSceneSummary = '';
            this.showSceneDialog = true;
          })
      }
      .width('100%')
    }
    .layoutWeight(1).width('100%')

    if (this.showSceneDialog) {
      this.SceneDialog()
    }
  }

  @Builder
  SceneDialog() {
    Stack() {
      Column() {
        Text(this.editingSceneId ? '编辑场景' : '添加场景')
          .fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

        TextInput({ placeholder: '场景标题', text: this.editingSceneTitle })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' }).margin({ bottom: 8 })
          .onChange((v: string) => { this.editingSceneTitle = v; })

        TextInput({ placeholder: '地点', text: this.editingSceneLocation })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' }).margin({ bottom: 8 })
          .onChange((v: string) => { this.editingSceneLocation = v; })

        TextInput({ placeholder: '时间', text: this.editingSceneTime })
          .fontSize(14).width('80%').height(40).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' }).margin({ bottom: 8 })
          .onChange((v: string) => { this.editingSceneTime = v; })

        TextArea({ placeholder: '场景摘要', text: this.editingSceneSummary })
          .fontSize(14).width('80%').height(80).borderRadius(8)
          .border({ width: 1, color: '#D1D5DB' })
          .onChange((v: string) => { this.editingSceneSummary = v; })

        Row() {
          Button('取消')
            .fontSize(14).fontColor('#666666').backgroundColor('#F3F4F6')
            .borderRadius(8).height(36).layoutWeight(1).margin({ right: 8 })
            .onClick(() => { this.showSceneDialog = false; })

          Button('保存')
            .fontSize(14).fontColor('#FFFFFF').backgroundColor('#FF6B35')
            .borderRadius(8).height(36).layoutWeight(1)
            .onClick(() => {
              if (this.editingSceneTitle.trim()) {
                if (this.editingSceneId) {
                  workManager.updateScene(this.workId, this.editingSceneId, {
                    title: this.editingSceneTitle,
                    location: this.editingSceneLocation,
                    time: this.editingSceneTime,
                    summary: this.editingSceneSummary
                  });
                } else {
                  const scene = workManager.addScene(this.workId, this.editingSceneTitle.trim());
                  if (scene) {
                    workManager.updateScene(this.workId, scene.id, {
                      location: this.editingSceneLocation,
                      time: this.editingSceneTime,
                      summary: this.editingSceneSummary
                    });
                  }
                }
                this.refreshData();
                this.showSceneDialog = false;
              }
            })
        }
        .width('80%').margin({ top: 12 })
      }
      .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16)
    }
    .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
  }
}
