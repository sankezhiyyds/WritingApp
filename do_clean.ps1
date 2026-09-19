$ErrorActionPreference = "Stop"
$log = "D:/Huawei/WritingApp/clean_status.txt"
try {
    "Starting at $(Get-Date)" | Out-File $log
    
    $cxxDir = "D:/Huawei/WritingApp/entry/.cxx"
    $cmakeDir = "D:/Huawei/WritingApp/entry/build/default/intermediates/cmake"
    
    if (Test-Path $cxxDir) {
        Remove-Item -Path $cxxDir -Recurse -Force
        "Removed .cxx dir" | Out-File $log -Append
    }
    if (Test-Path $cmakeDir) {
        Remove-Item -Path $cmakeDir -Recurse -Force
        "Removed cmake intermediates" | Out-File $log -Append
    }
    "Success at $(Get-Date)" | Out-File $log -Append
} catch {
    "Error: $_" | Out-File $log -Append
}
