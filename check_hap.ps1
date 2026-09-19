Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('D:/Huawei/WritingApp/entry/build/default/outputs/default/entry-default-signed.hap')
$entries = $zip.Entries | Where-Object { $_.FullName -like 'libs/arm64-v8a/*' }
foreach ($e in $entries) {
    Write-Host ($e.FullName + " - " + [math]::Round($e.Length/1KB, 0) + " KB")
}
$zip.Dispose()
