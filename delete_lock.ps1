$ErrorActionPreference = "SilentlyContinue"
$lockFile = "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so"
if (Test-Path $lockFile) {
    Remove-Item -Path $lockFile -Force
    Write-Host "Deleted locked libgguf.so"
}
$lockFile2 = "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libc++_shared.so"
if (Test-Path $lockFile2) {
    Remove-Item -Path $lockFile2 -Force
    Write-Host "Deleted libc++_shared.so"
}
$dir = "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a"
if (Test-Path $dir) {
    Get-ChildItem $dir -Recurse | Remove-Item -Force -Recurse
    Write-Host "Cleaned cmake obj directory"
}
Write-Host "Cleanup complete"
