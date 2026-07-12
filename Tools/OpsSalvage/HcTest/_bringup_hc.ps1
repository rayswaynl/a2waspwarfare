$ErrorActionPreference = 'Continue'
$log = 'C:\WASP\deploy-chernarus.log'
function L($m) { Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
function End-Task($n) { schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task($n) { schtasks /Run /TN $n | Out-Null }

L 'MANUAL BRINGUP START (recover failed freshname deploy; pbo+cfg already b742aicom)'
try { Start-Service 'Arma2OA-PR8' -ErrorAction Stop; L 'service started' } catch { L ('service start note: ' + $_.Exception.Message) }
Start-Sleep 40

Run-Task 'MiksuuHC'; Start-Sleep 55; Run-Task 'DismissACR'
Run-Task 'MiksuuHC2'; Start-Sleep 50; Run-Task 'DismissACR'

# cull oldest stuck HC client, relaunch HC1
$hc1 = Get-Process ArmA2OA -EA SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
if ($hc1) { Stop-Process -Id $hc1.Id -Force }
End-Task 'MiksuuHC'; Run-Task 'MiksuuHC'; Start-Sleep 55; Run-Task 'DismissACR'

# keep only newest client, relaunch HC2
$clients = @(Get-Process ArmA2OA -EA SilentlyContinue | Sort-Object StartTime)
if ($clients.Count -gt 1) { $clients | Select-Object -SkipLast 1 | Stop-Process -Force }
End-Task 'MiksuuHC2'; Run-Task 'MiksuuHC2'; Start-Sleep 50; Run-Task 'DismissACR'

Start-Sleep 8
$n = @(Get-Process arma2oaserver, ArmA2OA -EA SilentlyContinue).Count
L ("MANUAL BRINGUP complete - $n/3 up")
Write-Output ("BRINGUP_DONE $n/3 up")
