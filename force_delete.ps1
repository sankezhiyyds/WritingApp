$path = "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so"
try {
    # Try to remove read-only attribute first
    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
    [System.IO.File]::Delete($path)
    "DELETED OK" | Out-File "D:\Huawei\WritingApp\del_result.txt"
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File "D:\Huawei\WritingApp\del_result.txt"
    # Try attrib + del via cmd
    & cmd.exe /c "attrib -R `"$path`" && del /f /q `"$path`""
}
