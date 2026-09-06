# GGUF 本地推理引擎

## 架构

```
ArkTS (GGUFService.ets)
  ↓ import 'libgguf.so'
NAPI (gguf_napi.cpp)
  ↓
C++ (llama_runner.cpp)
  ↓
llama.cpp (third_party/llama.cpp)
```

## 启用完整推理

1. 克隆 llama.cpp 源码：
```bash
cd entry/src/main/cpp
git clone https://github.com/ggerganov/llama.cpp third_party/llama.cpp
```

2. 重新构建项目，CMake 会自动检测并编译 llama.cpp

3. 在应用设置中选择"本地 GGUF"模型，选择 `.gguf` 模型文件

## 无 llama.cpp 时

- 项目仍可正常编译和运行
- `libgguf.so` 会生成桩版本
- 选择 GGUF 模型时会返回错误提示

## NAPI 接口

| 方法 | 说明 |
|------|------|
| `loadModel(path, ctxLen, threads)` | 加载 GGUF 模型 |
| `generate(prompt, maxTokens, temp, topP, cb)` | 流式生成文本 |
| `unloadModel()` | 卸载模型释放内存 |
| `isModelLoaded()` | 检查模型是否已加载 |
| `getModelInfo()` | 获取模型元数据 |
| `abort()` | 中止当前生成 |
