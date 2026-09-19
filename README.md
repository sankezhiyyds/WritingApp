# 🤖 创意写作 - HarmonyOS 本地 AI 写作助手

> 一款基于 HarmonyOS 的 AI 创意写作应用，支持短剧、中长篇小说等多种创作模板，内置本地 GGUF 大模型离线推理，无联网、无账号、无 API Key，完全开源免费。

## ✨ 功能特性

### 📝 创作功能
- **短剧工作台**：短剧剧本、素描喜剧等模板，一键本地 AI 生成
- **中长篇工作台**：小说、散文等叙事类创作，支持多章节管理
- **创作模板**：内置多种专业模板，覆盖剧本、叙事等场景
- **章节管理**：支持多章节创作、对话历史、内容编辑
- **版本归档**：自动保存历史版本，可随时回溯

### 🧠 本地 AI（纯离线）
- 唯一后端：本地 GGUF 大模型推理（基于 llama.cpp）
- 无云端 API、无 API Key、无账号登录
- 模型文件自行导入（`.gguf`），完全离线运行
- 支持自定义系统提示词
- 推理参数可调：上下文长度、线程数、最大 token、温度

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
- 📱 首次启动引导

## 🚀 本地 GGUF 推理引擎

推理链路：`ArkTS (AIService / GGUFService) → NAPI (libgguf.so) → llama_runner → llama.cpp`

### 启用完整推理
1. 克隆 llama.cpp 源码到原生目录：

   ```bash
   cd entry/src/main/cpp
   git clone https://github.com/ggerganov/llama.cpp third_party/llama.cpp
   ```

2. 重新构建项目，CMake 会自动检测并编译 llama.cpp（CPU 推理）
3. 在应用设置中「本地模型文件(GGUF)」选择 `.gguf` 模型文件

### 无 llama.cpp 时
- 项目仍可正常编译运行，`libgguf.so` 生成占位（桩）版本，AI 推理会返回提示
- 仍可使用写作模板、手动编辑等功能

## 📸 截图

> 建议添加应用截图到 `docs/screenshots/` 目录

## 🚀 安装方式

### 源码编译
1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+
2. Clone 本仓库
3. 用 DevEco Studio 打开项目
4. 连接 HarmonyOS 设备，点击运行

## 🛠️ 技术栈

| 技术 | 说明 |
|------|------|
| **ArkTS** | HarmonyOS 应用开发语言 |
| **ArkUI** | 声明式 UI 框架 |
| **HarmonyOS API 12** | 目标 SDK 版本 |
| **llama.cpp** | 本地 GGUF 大模型推理 |
| **NAPI** | ArkTS 与 C++ 原生桥接 |
| **@ohos.data.preferences** | 本地数据存储 |
| **@ohos.mediaquery** | 响应式断点检测 |

## 📂 项目结构

```
WritingApp/
├── AppScope/                 # 应用级配置
├── entry/                    # 主模块
│   └── src/main/
│       ├── cpp/              # 原生推理引擎（llama.cpp + NAPI）
│       │   ├── gguf_napi.cpp        # NAPI 桥接
│       │   ├── llama_runner.cpp/.h  # llama.cpp 封装
│       │   └── llama_stub.h         # 无 llama.cpp 时的桩
│       ├── ets/
│       │   ├── entryability/ # 入口 Ability
│       │   ├── model/        # 数据模型
│       │   │   ├── AIService.ets        # AI 服务（本地推理）
│       │   │   ├── GGUFService.ets      # GGUF 模型管理
│       │   │   ├── WorkManager.ets      # 作品管理
│       │   │   ├── SettingsManager.ets  # 设置管理
│       │   │   ├── PermissionManager.ets # 权限管理
│       │   │   ├── TemplateModel.ets    # 模板模型
│       │   │   └── ResponsiveManager.ets # 响应式布局管理
│       │   └── pages/        # 页面
│       │       ├── Index.ets            # 首页（短剧/中长篇/设置）
│       │       └── PromptEditorPage.ets # 创作编辑页
│       └── resources/        # 资源文件
└── build-profile.json5       # 构建配置
```

## 🔒 隐私声明

本应用 **完全离线，不收集任何用户数据**：
- ✅ 所有创作内容存储在设备本地
- ✅ 无后端服务器，无数据上报
- ✅ 无账号登录，无用户信息收集
- ✅ 本地 GGUF 模型完全离线推理

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

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - 本地大模型推理引擎
- [HarmonyOS](https://www.harmonyos.com/) - 操作系统
- 所有贡献者和用户

---

⭐ 如果这个项目对你有帮助，请给个 Star！