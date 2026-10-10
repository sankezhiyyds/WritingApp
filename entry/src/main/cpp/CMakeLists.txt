cmake_minimum_required(VERSION 3.10)
project(gguf_napi)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# NAPI headers (provided by HarmonyOS SDK)
include_directories(${NAPI_ROOT}/include)

# llama.cpp source directory (clone to third_party/llama.cpp)
set(LLAMA_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp)

# Build llama.cpp as static library if source exists
if(EXISTS ${LLAMA_CPP_DIR}/CMakeLists.txt)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    # 禁用 OpenMP — HarmonyOS 设备无 libomp.so，链接后加载失败
    set(LLAMA_OPENMP OFF CACHE BOOL "" FORCE)
    set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
    # 启用 ARM NEON 优化 — 交叉编译时 GGML_NATIVE 默认 OFF，导致无架构标志
    # 不设此变量则量化内核使用纯 C 标量实现，极慢且可能 SIGSEGV
    set(GGML_CPU_ARM_ARCH "armv8.2-a+fp16+dotprod" CACHE STRING "ARM architecture" FORCE)
    add_subdirectory(${LLAMA_CPP_DIR} llama_cpp_build EXCLUDE_FROM_ALL)
    set(LLAMA_LIBS llama ggml)

    # Debug 构建默认 -O0，NEON intrinsics 虽编译但无循环展开/内联/向量化，
    # 量化内核极慢导致推理超时。强制对 llama.cpp 全部目标启用 -O2。
    foreach(_tgt ggml ggml-base ggml-cpu llama)
        if(TARGET ${_tgt})
            target_compile_options(${_tgt} PRIVATE
                $<$<CONFIG:Debug>:-O2 -fno-semantic-interposition>
            )
        endif()
    endforeach()
    message(STATUS "llama.cpp found — full inference enabled")
else()
    message(WARNING "llama.cpp not found at ${LLAMA_CPP_DIR}. "
        "Building stub. To enable GGUF inference:\n"
        "  git clone https://github.com/ggerganov/llama.cpp "
        "${LLAMA_CPP_DIR}")
    set(LLAMA_LIBS "")
endif()

# NAPI wrapper shared library
add_library(gguf SHARED
    gguf_napi.cpp
    llama_runner.cpp
)

target_include_directories(gguf PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

if(LLAMA_LIBS)
    target_include_directories(gguf PRIVATE
        ${LLAMA_CPP_DIR}/include
        ${LLAMA_CPP_DIR}/ggml/include
    )
    target_link_libraries(gguf PRIVATE ${LLAMA_LIBS})
endif()

# NAPI wrapper 也强制 -O2（含 llama_runner.cpp 的 prefill/生成循环）
target_compile_options(gguf PRIVATE $<$<CONFIG:Debug>:-O2>)

target_link_libraries(gguf PRIVATE
    libace_napi.z.so
    libhilog_ndk.z.so
)
