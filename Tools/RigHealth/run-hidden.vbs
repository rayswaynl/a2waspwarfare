Option Explicit

Dim fso, shell, scriptDir, probe, command
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
probe = scriptDir & "\Invoke-WaspRigHealth.ps1"
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & probe & Chr(34)
shell.Run command, 0, False
