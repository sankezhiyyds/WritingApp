# 🤖 创意写作 - HarmonyOS AI 写作助手

> 一款基于 HarmonyOS 的 AI 创意写作应用，支持短剧、中长篇小说等多种创作模板，集成多种 AI 大模型，完全开源免费。

## ✨ 功能特性

### 📝 创作功能
- **短剧工作台**：短剧剧本、喜剧剧本等模板，一键 AI 生成
- **中长篇工作台**：小说、散文等叙事类创作，支持多章节管理
- **创作模板**：内置多种专业模板，覆盖剧本、叙事等场景
- **章节管理**：支持多章节创作、对话历史、内容编辑

### 🧠 AI 集成（BYOK 模式 - 用户自带 API Key）
| 模型 | 说明 | 是否需要 Key |
|------|------|:---:|
| **DeepSeek** | 深度求索大模型，推荐使用 | ✅ |
| **智谱 GLM** | 智谱 AI ChatGLM | ✅ |
| **百度文心** | 百度文心一言 | ✅ |
| **小艺助手** | 华为系统内置小艺助手，通过 Want 拉起 | ❌ |
| **本地 GGUF** | 本地离线推理，隐私最佳 | ❌ |
| **自定义接口** | 兼容 OpenAI 格式的任意 API | ✅ |

### 📱 多端适配
- ✅ 手机（竖屏）
- ✅ 阔折叠屏（折叠态 / 展开态）
- ✅ 阔直板
- ✅ 平板（横屏 / 竖屏）
- ✅ 鸿蒙 PC
- 🔄 响应式布局：窄屏底部 Tab 导航，宽屏侧边导航 + 多列网格

### 🎨 其他特性
- 🌙 深色 / 浅色模式切换
- 💾 纯本地存储，无服务器，无数据收集
- 🔒 API Key 仅存储在设备本地
- 📱 首次启动引导

## 📸 截图

> 建议添加应用截图到 `docs/screenshots/` 目录

## 🚀 安装方式

### 方式一：直接安装 HAP 包
1. 前往 [Releases](../../releases) 页面下载最新 HAP 包
2. 通过 hdc 工具安装：`hdc install xxx.hap`
3. 或通过 HarmonyOS 设备的文件管理器安装

### 方式二：源码编译
1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+
2. Clone 本仓库
3. 用 DevEco Studio 打开项目
4. 连接 HarmonyOS 设备，点击运行

## ⚙️ AI 模型配置

### DeepSeek（推荐）
1. 打开应用 → 设置 → 选择模型 → DeepSeek
2. 前往 [DeepSeek 开放平台](https://platform.deepseek.com/) 获取 API Key
3. 在设置中填入 API Key

### 小艺助手（无需配置）
1. 打开应用 → 设置 → 选择模型 → 小艺助手
2. 或在编辑页直接点击「小艺」按钮
3. 系统将自动拉起华为内置小艺助手

### 本地 GGUF
1. 选择模型 → 本地 GGUF
2. 在设置中填入本地推理服务地址（如 `http://localhost:8080`）

### 自定义接口
1. 选择模型 → 自定义接口
2. 填入 API Key 和接口地址
3. 接口需兼容 OpenAI Chat Completions 格式

## 🛠️ 技术栈

| 技术 | 说明 |
|------|------|
| **ArkTS** | HarmonyOS 应用开发语言 |
| **ArkUI** | 声明式 UI 框架 |
| **HarmonyOS API 12** | 目标 SDK 版本 |
| **@ohos.net.http** | 网络请求 |
| **@ohos.data.preferences** | 本地数据存储 |
| **@ohos.mediaquery** | 响应式断点检测 |

## 📂 项目结构

```
WritingApp/
├── AppScope/                 # 应用级配置
├── entry/                    # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/ # 入口 Ability
│       │   ├── model/        # 数据模型
│       │   │   ├── AIService.ets       # AI 服务（多模型集成）
│       │   │   ├── WorkManager.ets     # 作品管理
│       │   │   ├── SettingsManager.ets # 设置管理
│       │   │   ├── TemplateModel.ets   # 模板模型
│       │   │   └── ResponsiveManager.ets # 响应式布局管理
│       │   └── pages/        # 页面
│       │       ├── Index.ets           # 首页（短剧/中长篇/设置）
│       │       └── PromptEditorPage.ets # 创作编辑页
│       └── resources/        # 资源文件
└── build-profile.json5       # 构建配置
```

## 🔒 隐私声明

本应用 **不收集任何用户数据**：
- ✅ 所有创作内容存储在设备本地
- ✅ API Key 仅存储在设备本地，不上传任何服务器
- ✅ 无后端服务器，无数据上报
- ✅ 本地 GGUF 模型可完全离线使用

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/xxx`
3. 提交更改：`git commit -m 'feat: xxx'`
4. 推送分支：`git push origin feature/xxx`
5. 提交 Pull Request

### 提交规范
- `feat:` 新功能
- `fix:` 修复 Bug
- `refactor:` 重构
- `docs:` 文档
- `style:` 格式

## 📄 开源协议

[MIT License](./LICENSE) - 可自由使用、修改、分发

## 🙏 致谢

- [DeepSeek](https://www.deepseek.com/) - AI 大模型
- [HarmonyOS](https://www.harmonyos.com/) - 操作系统
- 所有贡献者和用户

---

⭐ 如果这个项目对你有帮助，请给个 Star！
