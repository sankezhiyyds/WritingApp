import { workManager } from '../model/WorkManager';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct SettingsPage {
  @State works: WorkItem[] = [];
  @State apiKey: string = '';
  @State selectedModel: string = 'deepseek';
  @State customUrl: string = '';

  aboutToAppear() {
    this.loadWorks();
    this.loadSettings();
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      List() {
        // AI 模型配置
        ListItem() {
          SettingSection(
            title: 'AI 模型配置',
            items: [
              { label: 'API Key', value: this.apiKey ? '● ● ● ● ● ● ● ●' : '未配置', editable: true, action: () => this.showApiKeyDialog() }
            ]
          )
        }

        ListItem() {
          SettingSection(
            title: '模型选择',
            items: [
              { label: '当前模型', value: this.getModelName(), editable: true, action: () => this.showModelPicker() }
            ]
          )
        }

        ListItem() {
          SettingSection(
            title: '写作技巧',
            items: [
              { label: 'Token压缩', value: '用42字写5个有效信息', editable: false },
              { label: '行为锚定', value: '多写具体行为，少写空洞情绪词', editable: false },
              { label: '视觉化描述', value: '用画面代替抽象概念', editable: false },
              { label: 'UI/LLM隔离', value: '前端代码不控制AI，由用户输入驱动', editable: false }
            ]
          )
        }

        ListItem() {
          SettingSection(
            title: '关于',
            items: [
              { label: '版本', value: '1.0.0', editable: false },
              { label: '开发者', value: '个人开发者', editable: false }
            ]
          )
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F6FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  getModelName(): string {
    switch (this.selectedModel) {
      case 'deepseek': return 'DeepSeek';
      case 'glm': return '智谱 GLM';
      case 'baidu': return '百度文心';
      case 'custom': return '自定义接口';
      default: return 'DeepSeek';
    }
  }

  showApiKeyDialog() {
    promptAction.showCustomDialog({
      title: '设置 API Key',
      message: '请输入您的 API Key（仅本地存储，不会上传到任何服务器）',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '保存',
        action: () => {
          this.saveSettings();
          promptAction.showToast({ message: '已保存', duration: 2000 });
        }
      }
    });
  }

  showModelPicker() {
    promptAction.showActionSheet({
      menu: ['DeepSeek', '智谱 GLM', '百度文心', '自定义接口']
    }).then((value) => {
      const models = ['deepseek', 'glm', 'baidu', 'custom'];
      const index = value.index;
      if (index >= 0 && index < models.length) {
        this.selectedModel = models[index];
        this.saveSettings();
      }
    });
  }

  loadWorks() {
    this.works = workManager.getAllWorks();
  }

  loadSettings() {
    // 从 LocalStorage 加载设置
    this.apiKey = '';
    this.selectedModel = 'deepseek';
  }

  saveSettings() {
    // 保存到 LocalStorage
  }
}

@Component
struct SettingSection {
  @Param title: string;
  @Param items: SettingItemData[];

  build() {
    Column() {
      Text(this.title)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .padding({ left: 16, bottom: 8 })
      
      ForEach(this.items, (item: SettingItemData) => {
        Row() {
          Column() {
            Text(item.label)
              .fontSize(14)
              .fontColor('#1A1A2E')
            if (item.value) {
              Text(item.value)
                .fontSize(12)
                .fontColor('#9CA3AF')
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          
          if (item.editable && item.action) {
            Text('>')
              .fontSize(16)
              .fontColor('#D1D5DB')
              .onClick(item.action)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        
        Divider().color('#F3F4F6').strokeWidth(0.5).margin({ left: 16, right: 16 })
      }, (item: SettingItemData) => item.label)
    }
    .backgroundColor('#FFFFFF')
  }
}

interface SettingItemData {
  label: string;
  value?: string;
  action?: () => void;
  editable: boolean;
}

interface WorkItem {
  id: string;
  title: string;
  templateId: string;
  templateName: string;
  content: string;
  createTime: string;
  updateTime: string;
}
