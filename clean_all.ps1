# Clean all build artifacts
$paths = @(
    "D:/Huawei/WritingApp/entry/.cxx",
    "D:/Huawei/WritingApp/entry/build/default/intermediates/cmake",
    "D:/Huawei/WritingApp/entry/build/default/intermediates/hap",
    "D:/Huawei/WritingApp/entry/build/default/outputs/default"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned: $p"
    }
}
Write-Host "All build artifacts cleaned"
