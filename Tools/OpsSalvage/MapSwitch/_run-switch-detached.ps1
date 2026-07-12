$ErrorActionPreference='Stop'
("=== B35 takistan deploy LAUNCH " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " ===") | Add-Content -LiteralPath 'C:\WASP\deploy-tonight.log'
Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\WASP\takistan-switch.ps1' -WindowStyle Hidden
Start-Sleep -Seconds 5
Write-Output ("detached switch launched at " + (Get-Date -Format 'HH:mm:ss'))
Write-Output ("arma processes now: " + @(Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue).Count)
Write-Output "--- deploy log tail ---"
Get-Content -LiteralPath 'C:\WASP\deploy-tonight.log' -Tail 6
