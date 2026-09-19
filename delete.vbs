Set fso = CreateObject("Scripting.FileSystemObject")
Set f = fso.GetFile("D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so")
f.Attributes = 0 ' Normal file, no read-only
On Error Resume Next
fso.DeleteFile "D:\Huawei\WritingApp\entry\build\default\intermediates\cmake\default\obj\arm64-v8a\libgguf.so", True
If Err.Number = 0 Then
    MsgBox "Deleted"
Else
    MsgBox "Error: " & Err.Description
End If
