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
    add_subdirectory(${LLAMA_CPP_DIR} llama_cpp_build EXCLUDE_FROM_ALL)
    set(LLAMA_LIBS llama llama_common ggml)
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

target_link_libraries(gguf PRIVATE
    libace_napi.z.so
    libhilog_ndk.z.so
)
