# GGUF 本地推理引擎

## 架构

```
ArkTS (GGUFService.ets)
  ↓ import 'libgguf.so'
NAPI (gguf_napi.cpp)
  ↓ napi_threadsafe_function（逐 token 流式回调）
C++ (llama_runner.cpp)
  ↓
llama.cpp (third_party/llama.cpp)
  ↓ CPU 推理, ARM NEON 优化
```

## 启用完整推理

1. 克隆 llama.cpp 源码：
```bash
cd entry/src/main/cpp
git clone https://github.com/ggerganov/llama.cpp third_party/llama.cpp
```

2. 重新构建项目，CMake 会自动检测并编译 llama.cpp

3. 在应用设置中选择「本地模型文件(GGUF)」，选择 `.gguf` 模型文件

## 无 llama.cpp 时

- 项目仍可正常编译和运行
- `libgguf.so` 会生成桩版本
- 选择 GGUF 模型时会返回错误提示

## NAPI 接口

| 方法 | 说明 |
|------|------|
| `loadModel(path, ctxLen, threads)` | 加载 GGUF 模型（异步，返回 `Promise<boolean>`） |
| `generateChat(messages, params, onToken)` | 多轮对话流式生成（返回 `Promise<string>`） |
| `generate(prompt, maxTokens, temp, topP, cb)` | 单轮流式生成（返回 `Promise<string>`） |
| `unloadModel()` | 卸载模型释放内存 |
| `isModelLoaded()` | 检查模型是否已加载 |
| `getModelInfo()` | 获取模型元数据 |
| `abort()` | 中止当前生成 |

## 推理配置约束

以下约束经过实机验证，违反会导致 prefill 卡死或 SIGABRT 闪退：

| 参数 | 约束 | 说明 |
|------|------|------|
| `n_batch` | 必须等于 `n_ctx` | 小于 n_ctx 会导致 `llama_decode` 卡死 |
| `flash_attn` | 必须为 `DISABLED` | `AUTO` 会导致 prefill 卡死 |
| Debug 优化级别 | `-O2` | `-O0` 导致量化内核性能极差 |

## 已实现的优化

| 优化项 | 实现方式 |
|--------|----------|
| 常驻推理上下文 | 模型加载后 `context_` 常驻内存，`generateChat` 直接复用 |
| 流式回调 | `napi_threadsafe_function` 逐 token 回调到 ArkTS |
| MMAP 加载 | `LLAMA_LOAD_MODE_MMAP` 降低 RSS 占用 |
| 线程自动检测 | 取在线逻辑核数 75%（向下取整，最小 1），手动设置超过逻辑核数时自动 clamp |
| YaRN RoPE scaling | 扩展上下文长度，对齐训练长度 |
| 采样链优化 | `min_p → top_k → top_p → temp → dist` |
| 多轮对话 | 结构化 messages 传递，chat template 对齐 |
| Prompt 长度保护 | 超过 `n_ctx` 时截断，防止 `ggml_abort` |
| KV cache 清除 | `abort` 后 `llama_memory_clear` 清除 KV cache |
| 设备防卡死 | `sched_yield()` + `sleep_for(1ms)` 让出 CPU，推理线程 nice +5 降优先级 |
| 内存检查中止 | 每 16 token 检查可用内存，< 48MB 时主动中止防止 OOM |

## CMake 构建配置

- 禁用 OpenMP
- ARM NEON 优化目标架构：`armv8.2-a+fp16+dotprod`
- Debug 构建强制 `-O2` 优化级别
- llama.cpp 构建为静态库链接到 `libgguf.so`

## 源码文件

| 文件 | 说明 |
|------|------|
| `gguf_napi.cpp` | NAPI 桥接层，导出 `loadModel`、`generateChat`、`abort` 等接口 |
| `llama_runner.cpp` | C++ 推理引擎封装，管理模型加载、采样、生成循环 |
| `CMakeLists.txt` | CMake 构建配置 |
| `third_party/llama.cpp/` | llama.cpp 源码（需手动克隆） |
