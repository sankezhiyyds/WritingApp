@echo off
echo Starting cleanup...
del /f /s /q "D:\Huawei\WritingApp\entry\.cxx\*.*" 2>nul
echo Deleted .cxx files
if exist "D:\Huawei\WritingApp\entry\.cxx" (
    rmdir /s /q "D:\Huawei\WritingApp\entry\.cxx"
    echo Removed .cxx directory
)
if exist "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake" (
    rmdir /s /q "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake"
    echo Removed cmake intermediates
)
echo Cleanup finished!
pause
