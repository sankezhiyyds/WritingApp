# NNRt (Neural Network Runtime) NPU 加速集成指南

## 概述

当前项目使用 llama.cpp 进行 CPU 推理。NNRt (Neural Network Runtime Kit) 是鸿蒙面向 AI 领域的跨芯片推理计算运行时，可利用设备 NPU 硬件加速推理。本文档描述将 NNRt 集成为 ggml backend 插件的方案。

## 设计约束

- **模型格式不限定**：支持任意 GGUF 量化类型（Q4_0 / Q4_K / Q5_K / Q8_0 / F16 / F32 等混合）
- **SoC 不限定**：不能硬编码特定芯片型号，需通过 NNRt 设备无关接口运行时适配
- **保持 llama.cpp 自主编译**：NPU 作为 ggml backend 插入，不修改 llama.cpp 核心代码

## 推荐集成架构

```
ArkTS (GGUFService) → NAPI (libgguf.so) → C++ (llama_runner)
                                           ↓
                                    ggml backend 插件
                                           ↓
                                    NNRt C API (OH_NNModel / OH_NNCompilation)
                                           ↓
                                    NPU / GPU / DSP 加速芯片
```

## 实现步骤

### 1. 在 C++ 层引入 NNRt 头文件

```cpp
// entry/src/main/cpp/llama_runner/nnrt_backend.h
#include <nnrt/neural_network_runtime.h>
#include <nnrt/neural_network_runtime_type.h>
```

### 2. 实现 ggml backend 接口

将 NNRt 封装为 ggml backend，使 llama.cpp 的计算图可自动将支持的算子委托给 NPU：

```cpp
// 注册 NNRt backend
struct ggml_backend nnrt_backend {
    // 实现 ggml_backend 接口函数
    // 支持的算子：matmul, attention, rope, softmax 等
    // 不支持的算子自动 fallback 到 CPU backend
};
```

### 3. 设备枚举与运行时适配

```cpp
// 枚举所有可用的加速设备（设备无关，不硬编码芯片型号）
OH_NNDevice_GetAllDevices(&deviceList, &deviceCount);
// 优先选择 NPU，其次 GPU
for (uint32_t i = 0; i < deviceCount; i++) {
    OH_NNDevice_GetName(deviceList[i], &name);
    if (strcmp(name, "NPU") == 0) { /* 选择 NPU */ }
}
```

### 4. NAPI 暴露接口

在 `libgguf.so` 中新增：

```cpp
napi_value EnableNNRt(napi_env env, napi_callback_info info);
napi_value IsNNRtAvailable(napi_env env, napi_callback_info info);
napi_value SetNNRtDevice(napi_env env, napi_callback_info info);  // "NPU" | "GPU" | "CPU"
```

### 5. ArkTS 调用

```typescript
// GGUFService.ets
import { enableNNRt, isNNRtAvailable, setNNRtDevice } from 'libgguf.so';

async enableHardwareAcceleration(device: string): Promise<boolean> {
    if (!this.nativeAvailable) return false;
    setNNRtDevice(device);
    return true;
}
```

## 性能预期

| 加速方式 | 推理速度 | 功耗 | 说明 |
|---------|---------|------|------|
| CPU only (当前) | 1x (基准) | 高 | 2线程 + Q8_0 量化，prefill 约 80s/128token |
| CPU + GPU (NNRt) | 1.5-3x | 中 | 计算密集型算子卸载 |
| CPU + NPU (NNRt) | 3-5x | 低 | 推荐方案，量化模型效果最佳 |

## 依赖项

- API Level: HarmonyOS 6.0+ (API 20+)
- 硬件：麒麟 SoC（内置达芬奇 NPU）或其它支持 NNRt 的芯片
- 编译配置：在 CMakeLists.txt 中添加 `libnnrt.so` 链接

```cmake
target_link_libraries(libgguf.so
    PRIVATE
        nnrt_ndk    # NNRt C API
)
```

## 注意事项

1. NNRt 以 C API 暴露，需在 C++ 层封装
2. 量化模型（4-bit/8-bit）在 NPU 上推理效果最佳
3. 首次编译模型耗时较长，建议缓存编译结果
4. 需处理 NPU 不支持算子时回退到 CPU 的 fallback 逻辑
5. 当前项目为个人开发者手机端，仅 CPU 推理可用；NPU 加速路径需 NNRt + MindSpore Lite
