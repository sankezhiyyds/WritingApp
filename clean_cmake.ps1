Remove-Item -Path "D:/Huawei/WritingApp/entry/.cxx" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:/Huawei/WritingApp/entry/build/default/intermediates/cmake" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "CMake cache cleared"
