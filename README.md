# 写书助手 - HarmonyOS 应用

专业写作助手，提供16种写作模板，支持用户自定义AI模型。

## 项目信息

- **应用名称**: 写书助手
- **Bundle Name**: com.writingapp.helper
- **最低API**: 7.0.0(26) / API 12
- **目标API**: 7.0.0(26) / API 26
- **设备类型**: phone, tablet, foldable

## 目录结构

```
WritingApp/
├── AppScope/
│   └── app.json5              # 应用全局配置
├── build-profile.json5        # 项目构建配置
├── oh-package.json5           # 项目依赖管理
└── entry/
    ├── build-profile.json5    # 模块构建配置
    ├── oh-package.json5       # 模块依赖
    └── src/main/
        ├── ets/
        │   ├── entryability/
        │   │   └── EntryAbility.ets     # 应用入口
        │   ├── model/
        │   │   ├── RouterTypes.ets      # 路由类型定义
        │   │   ├── TemplateModel.ets    # 16个写作模板数据
        │   │   └── WorkManager.ets      # 作品管理逻辑
        │   └── pages/
        │       ├── Index.ets            # 主页面（Tab导航）
        │       ├── TemplateListPage.ets # 模板列表页
        │       ├── TemplateDetailPage.ets # 模板详情页
        │       ├── WorkManagerPage.ets  # 我的作品页
        │       ├── WorkEditorPage.ets   # 作品编辑页
        │       └── SettingsPage.ets     # 设置页
        └── resources/
            ├── base/element/
            │   ├── color.json           # 颜色配置
            │   └── string.json          # 字符串资源
            └── rawfile/
                └── rawfile.json         # 资源声明
```

## 功能特性

### 1. 16种写作模板（纯文本版，合规审核）

| 分类 | 模板 |
|------|------|
| **剧本类** | 短剧剧本、悬疑推理、剧本杀、短视频脚本、五幕剧 |
| **叙事类** | 英雄之旅、情感拉扯、故事核、爆款公式、三幕式 |
| **喜剧类** | 漫才、素描喜剧、喜剧冲突链、情景喜剧、荒诞派、戏剧独白 |

### 2. 核心设计理念（茉莉酱原则 adapted）

- **Token压缩**: 用简洁语言描述角色行为，避免空洞情绪词
- **行为锚定**: 多写具体行为，少写抽象形容词
- **视觉化描述**: 用画面代替抽象概念
- **UI/LLM隔离**: 前端代码不控制AI，由用户输入驱动

### 3. AI 接入方案

- 用户自选 API Key（DeepSeek / 智谱 GLM / 百度文心 / 自定义）
- 所有 API Key 仅本地存储，不上云
- 免费额度足够初期使用

### 4. 合规设计

- 纯文本写作方法论，无代码、无角色卡、无平台术语
- 通过鸿蒙应用市场审核
- 支持华为账号登录（激励计划要求）

## 导入到 DevEco Studio

### 方法一：新建项目导入

1. 打开 DevEco Studio
2. 点击 **File > New > Project**
3. 选择 **Empty Ability**
4. 填写 Bundle Name: `com.writingapp.helper`
5. 在 SDK Manager 中下载所需的 System-image 镜像
6. 将 `/workspace/WritingApp` 目录下的文件复制到项目中

### 方法二：直接复制

1. 创建新的 HarmonyOS 项目
2. 将以下文件复制到对应位置：
   - `entry/src/main/ets/` → 所有 .ets 文件
   - `entry/src/main/resources/` → 资源文件
   - 配置文件（build-profile.json5 等）

## 配置说明

### SDK 配置 (build-profile.json5)

```json5
{
  "compileSdkVersion": "7.0.0(26)",
  "compatibleSdkVersion": "7.0.0(26)",
  "targetSdkVersion": "7.0.0(26)"
}
```

### 签名配置

发布前需要配置正式签名：
1. 在 DevEco Studio 中生成签名证书
2. 更新 `build-profile.json5` 中的 signingConfigs
3. Bundle Name 需与开发者账号一致

## 下一步

1. **导入项目**: 在 DevEco Studio 中打开此项目
2. **下载镜像**: SDK Manager 下载 phone/foldable/tablet 镜像
3. **连接真机**: 畅享90pro max 通过 USB 连接
4. **运行测试**: 点击 Run 按钮运行到设备
5. **配置签名**: 发布前申请开发者签名
6. **提交审核**: 9月30日前完成上架

## 注意事项

- 8GB 内存运行模拟器会比较吃力，建议优先使用真机调试
- 模拟器镜像建议下载到 D 盘（1TB HDD）
- 首次运行需要下载 SDK 组件，需要联网
- 激励计划报名截止：9月25日
- 应用上线截止：9月30日
