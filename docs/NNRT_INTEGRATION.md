# NNRt (Neural Network Runtime) 集成指南

## 概述

NNRt (Neural Network Runtime Kit) 是鸿蒙面向 AI 领域的跨芯片推理计算运行时，位于 AI 推理框架和底层加速芯片（NPU、GPU、DSP）之间。接入 NNRt 后，GGUF 模型可以利用设备的 NPU 硬件加速，大幅提升推理速度并降低功耗。

## 推荐集成架构

```
ArkTS (GGUFService) → NAPI (libgguf.so) → C++ (llama_runner) 
                                           ↓
                                    NNRt C API (OH_NNModel / OH_NNCompilation)
                                           ↓
                                    NPU / GPU / DSP 加速芯片
```

## 实现步骤

### 1. 在 C++ 层引入 NNRt 头文件

```cpp
// entry/src/main/cpp/llama_runner/nnrt_engine.h
#include <nnrt/neural_network_runtime.h>
#include <nnrt/neural_network_runtime_type.h>
```

### 2. 设备枚举与选择

```cpp
// 枚举所有可用的加速设备
OH_NNDevice_GetAllDevices(&deviceList, &deviceCount);
// 优先选择 NPU，其次 GPU
for (uint32_t i = 0; i < deviceCount; i++) {
    OH_NNDevice_GetName(deviceList[i], &name);
    if (strcmp(name, "NPU") == 0) { /* 选择 NPU */ }
}
```

### 3. 模型编译与推理

NNRt 支持两种模式：

- **在线构图 (Online Model Building)**：逐层添加算子构建模型图
- **离线模型 (Offline Model)**：加载已编译的 om 模型文件

对于 GGUF 格式，推荐在 `llama_runner` 中将 llama.cpp 的输出通过 NNRt 进行后处理加速，或将注意力机制等计算密集型算子委托给 NNRt 执行。

### 4. NAPI 暴露接口

在 libgguf.so 中新增以下 NAPI 函数：

```cpp
napi_value EnableNNRt(napi_env env, napi_callback_info info);
napi_value IsNNRtAvailable(napi_env env, napi_callback_info info);
napi_value SetNNRtDevice(napi_env env, napi_callback_info info);  // "NPU" | "GPU" | "CPU"
```

### 5. ArkTS 调用

```typescript
// GGUFService.ets 新增
import { enableNNRt, isNNRtAvailable, setNNRtDevice } from 'libgguf.so';

// 在设置页面提供开关
async enableHardwareAcceleration(device: string): Promise<boolean> {
    if (!this.nativeAvailable) return false;
    setNNRtDevice(device);
    return true;
}
```

## 性能预期

| 加速方式 | 推理速度 | 功耗 | 说明 |
|---------|---------|------|------|
| CPU only (llama.cpp) | 1x (基准) | 高 | 当前状态 |
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
        hiperf      # 性能调优
)
```

## 注意事项

1. NNRt 以 C API 暴露，需在 C++ 层封装
2. 量化模型（4-bit/8-bit）在 NPU 上推理效果最佳
3. 首次编译模型耗时较长，建议缓存编译结果
4. 需要处理 NPU 不支持回退到 CPU 的 fallback 逻辑
