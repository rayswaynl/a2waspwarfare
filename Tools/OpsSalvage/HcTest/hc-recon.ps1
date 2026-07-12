$ErrorActionPreference = "Continue"
Start-Sleep 40
Write-Output ("=== live health: svc " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()) + " | HC " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count) + " | cfg " + ((Get-Content 'C:\WASP\profiles-pr8\server-pr8.cfg' | Select-String 'BattlEye').Line.Trim()))
Write-Output "=== HC launch task actions (how HCs start - do they use BE?) ==="
foreach ($t in @("MiksuuHC","MiksuuHC2")) {
    $a = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).Actions
    foreach ($act in $a) { Write-Output ($t + ": " + $act.Execute + " " + $act.Arguments) }
}
Write-Output "=== server cfg headless/local client lines ==="
Get-Content 'C:\WASP\profiles-pr8\server-pr8.cfg' | Select-String -SimpleMatch "headless","localClient","kickduplicate","verifySignatures","BattlEye"
Write-Output "=== HC profile ArmA2OA.cfg ==="
Get-Content 'C:\WASP\hc-profile\ArmA2OA.cfg' -ErrorAction SilentlyContinue
Write-Output "=== RPT tail (health) ==="
Get-Content 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Tail 4 -ErrorAction SilentlyContinue
