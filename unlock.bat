@echo off
echo Attempting to delete locked files...
attrib -R "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so"
attrib -R "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libc++_shared.so"
attrib -R "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\*.so"
rename "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so" "libgguf.so.bak"
rename "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libc++_shared.so" "libc++_shared.so.bak"
echo Trying to remove cmake obj dir...
rmdir /s /q "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a"
if errorlevel 1 (
    echo Could not remove via rmdir, trying robocopy trick...
    mkdir "D:\Huawei\WritingApp\empty_dir"
    robocopy "D:\Huawei\WritingApp\empty_dir" "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a" /MIR /R:1 /W:1
    rmdir /s /q "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a"
    rmdir /s /q "D:\Huawei\WritingApp\empty_dir"
)
echo Done.
