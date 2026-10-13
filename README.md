# 创意写作 - HarmonyOS 本地 AI 写作助手

> 基于 HarmonyOS 的 AI 创意写作应用，支持短剧、中长篇小说等多种创作模板，内置本地 GGUF 大模型离线推理引擎。无需联网、无需 API Key，数据完全本地存储，支持华为云空间自动同步。

## 功能特性

### 创作功能
- **短剧工作台**：短剧剧本、素描喜剧等模板，一键 AI 生成
- **中长篇工作台**：小说、散文等叙事类创作，支持多章节管理
- **创作模板**：内置多种专业模板，覆盖剧本、叙事等场景
- **章节管理**：多章节创作、对话历史、内容编辑
- **版本归档**：自动保存历史版本，可随时回溯
- **查找替换**：编辑器内置查找替换功能
- **大纲管理**：结构化大纲面板，支持层级编辑

### 本地 AI 推理（纯离线）
- 推理引擎：llama.cpp（CPU 推理，ARM NEON 优化）
- 推理链路：`ArkTS (AIService / GGUFService) → NAPI (libgguf.so) → C++ (llama_runner) → llama.cpp`
- 模型格式：用户自行导入 `.gguf` 模型文件
- 流式输出：逐 token 回调，实时显示思考过程和回复
- 思考分离：自动解析 `<think>` / `<thinking>` 标签，思考与回复分框展示
- 推理参数可调：上下文长度、线程数、最大 token、温度
- 自定义系统提示词
- 内存保护：AbilityStage 监听系统内存压力，低内存时拒绝推理请求
- 低电量保护：SystemResourceMonitor 监控电量，低电量跳过推理
- 设备防卡死保护：推理线程降优先级（nice +5）、`sched_yield()` + 自适应休眠让出 CPU、每 16 token 检查可用内存（< 48MB 主动中止）
- 线程数保护：自动检测取逻辑核 75%，手动设置超过逻辑核数时自动 clamp

### 华为账号与云同步
- 华为账号登录（静默登录 + 普通登录），基于 Account Kit
- 端云文件协同同步：数据写入 `cloudFileDir`，系统自动同步到华为云空间
- 同步性能优化：5 秒超时 + fire-and-forget push 模式
- 使用系统级华为账号，无需 App 内登录即可同步

### 多端适配
- 手机（竖屏）
- 折叠屏（折叠态 / 展开态）
- 平板（横屏 / 竖屏）
- 鸿蒙 PC（2in1）
- 响应式布局：窄屏底部 Tab 导航，宽屏侧边导航 + 多列网格

### 其他特性
- 深色 / 浅色模式切换（资源限定符方案，跟随系统或手动切换）
- 回收站：删除作品/灵感可恢复，AI 对话数据随作品保留
- 灵感池：快速记录灵感，支持桌面卡片
- 数据导出/导入：通过 DocumentViewPicker 导出为文件或导入恢复
- 首次启动引导（7 页：欢迎 → AI 功能 → 数据同步 → 编辑器 → 隐私保护 → 使用说明 → 免责协议）
- 免责协议需勾选确认后才能进入应用
- 沉浸式状态栏与导航栏适配

## 项目结构

```
WritingApp/
├── AppScope/
│   └── app.json5                    # 应用配置（bundleName、版本、云同步开关）
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── pages/
│       │   │   ├── Index.ets        # 主页（书架、素材库、设置）
│       │   │   ├── PromptEditorPage.ets  # 编辑器页面
│       │   │   └── InspirationCard.ets  # 灵感卡片
│       │   ├── components/
│       │   │   ├── AiSidebar.ets    # AI 侧边栏（对话、流式输出、思考分离）
│       │   │   ├── FindReplaceDialog.ets  # 查找替换
│       │   │   ├── OutlineManagementPanel.ets  # 大纲管理
│       │   │   └── SaveDialog.ets   # 保存弹窗
│       │   ├── model/
│       │   │   ├── WorkManager.ets  # 作品数据管理（增删改查、回收站、落盘）
│       │   │   ├── AIService.ets    # AI 服务层
│       │   │   ├── GGUFService.ets  # GGUF 推理服务（NAPI 桥接）
│       │   │   ├── SettingsManager.ets  # 设置管理
│       │   │   ├── HuaweiAuthService.ets  # 华为账号认证
│       │   │   ├── CloudSyncService.ets  # 端云文件协同同步
│       │   │   ├── SystemResourceMonitor.ets  # 系统资源监控
│       │   │   ├── PerformanceOptimizer.ets  # 性能优化
│       │   │   ├── ResponsiveManager.ets  # 响应式布局
│       │   │   ├── PermissionManager.ets  # 权限管理
│       │   │   └── TemplateModel.ets  # 创作模板
│       │   └── entryability/
│       │       ├── EntryAbility.ets  # 入口 Ability（全屏、状态栏适配）
│       │       └── MyAbilityStage.ets  # AbilityStage（内存压力监听）
│       ├── cpp/
│       │   ├── gguf_napi.cpp        # NAPI 桥接层
│       │   ├── llama_runner.cpp     # C++ 推理引擎
│       │   ├── CMakeLists.txt       # CMake 构建配置
│       │   └── third_party/llama.cpp/  # llama.cpp 源码
│       └── module.json5            # 模块配置（权限、设备类型）
├── docs/
│   └── NNRT_INTEGRATION.md         # NNRt NPU 加速集成指南
└── build-profile.json5             # 构建配置（签名、SDK 版本）
```

## 技术栈

| 技术 | 说明 |
|------|------|
| ArkTS | HarmonyOS 应用开发语言 |
| ArkUI | 声明式 UI 框架 |
| HarmonyOS API 12+ | 目标 SDK 版本（最低兼容 API 24） |
| llama.cpp | 本地 GGUF 大模型推理（CPU, ARM NEON） |
| NAPI | ArkTS 与 C++ 原生桥接 |
| @kit.AccountKit | 华为账号登录认证 |
| @kit.CoreFileKit.cloudSync | 端云文件协同同步 |
| @kit.ArkData.preferences | 本地偏好存储 |
| @kit.CoreFileKit.fileIo | 文件 I/O（数据落盘） |

## 本地 GGUF 推理引擎

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

### 推理优化

已实现的优化：
- 常驻推理上下文：模型加载后 `context_` 常驻内存，`generateChat` 直接复用
- 流式回调：`napi_threadsafe_function` 逐 token 回调
- MMAP 加载：`LLAMA_LOAD_MODE_MMAP` 降低 RSS 占用
- 线程自动检测：取在线逻辑核数 75%（向下取整，最小 1），手动设置超过逻辑核数时自动 clamp
- YaRN RoPE scaling：扩展上下文长度
- 采样链优化：`min_p → top_k → top_p → temp → dist`
- 多轮对话历史传递（结构化 messages）
- Chat template 对齐（`llama_chat_apply_template`）
- 设备防卡死：`sched_yield()` + 自适应休眠、推理线程 nice +5 降优先级、内存检查中止

配置约束：
- `n_batch` 必须等于 `n_ctx`（否则 prefill 卡死）
- `flash_attn` 必须设为 `DISABLED`（AUTO 导致卡死）
- Debug 构建下使用 `-O2` 优化（避免量化内核性能问题）

## 数据存储与同步

### 本地存储
- 数据文件存储在 `context.filesDir/writing_app/` 目录
- 核心文件：`works.json`、`recycle_bin.json`、`inspirations.json`
- 落盘触发点：编辑时（debounce 500ms）、导入后、推理前、进后台、内存压力时
- `loadFromStorage` 仅在 filesDir 无数据时补充，不会覆盖文件数据

### 云同步
- 端云文件协同：数据写入 `context.cloudFileDir/writing_app/`，系统自动同步
- 使用系统级华为账号，无需 App 内登录
- 同步超时 5 秒，push 阶段 fire-and-forget
- 需设备 HarmonyOS 6.0.0.115+，API 21+

## 安装方式

### 源码编译
1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+
2. Clone 本仓库
3. 用 DevEco Studio 打开项目
4. 连接 HarmonyOS 设备，点击运行

### 系统要求
- HarmonyOS 5.0+
- 设备类型：phone / tablet / 2in1
- 推荐 8GB+ 内存（加载 0.5B~1B 量化模型）

## 应用信息

| 属性 | 值 |
|------|-----|
| 包名 | `com.creativewriting.ai` |
| 版本 | 1.2.1 |
| 模块类型 | entry（HAP） |
| 云同步 | 已启用（`cloudFileSyncEnabled: true`） |

## 开源许可

本项目仅供学习交流使用。
