$ErrorActionPreference = "Continue"
# HC-only clean cycle - server service is NOT touched (stays RUNNING)
schtasks /End /TN MiksuuHC 2>&1 | Out-Null
schtasks /End /TN MiksuuHC2 2>&1 | Out-Null
Start-Sleep 3
Stop-Process -Name ArmA2OA -Force -ErrorAction SilentlyContinue   # kills all HC clients, not the server (arma2oaserver)
Start-Sleep 5
Write-Output ("server still up: " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()))
schtasks /Run /TN MiksuuHC 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null
Start-Sleep 45
schtasks /Run /TN MiksuuHC2 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null
Start-Sleep 45
Write-Output ("HC processes: " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count) + " | server: " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()))
Get-Process ArmA2OA -ErrorAction SilentlyContinue | Select-Object Id, StartTime | Format-Table -AutoSize
Remove-Item "C:\WASP\hc-cycle.ps1" -Force -ErrorAction SilentlyContinue
