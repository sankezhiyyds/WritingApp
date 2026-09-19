@echo off
attrib -R "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" >nul 2>&1
takeown /f "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" >nul 2>&1
icacls "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" /grant Everyone:F >nul 2>&1
del /f /q "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" >nul 2>&1
if exist "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" (
    echo FAIL
    dir "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" > D:\Huawei\WritingApp\clean_log2.txt
) else (
    echo SUCCESS
)
