$ErrorActionPreference = "Continue"
$oa = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
$cfg = "C:\WASP\profiles-pr8\server-pr8.cfg"
$rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
$hcrpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT"
$loadDirs = @("C:\Users\Administrator\AppData\Local\ArmA 2 OA\BattlEye", "$oa\BattlEye")
$src = "$oa\Expansion\BattlEye"
try {
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null; schtasks /End /TN MiksuuHC2 2>&1 | Out-Null
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    foreach ($d in $loadDirs) { New-Item -ItemType Directory -Force $d | Out-Null; Copy-Item "$src\BEServer.dll" "$d\" -Force; Copy-Item "$src\BEClient.dll" "$d\" -Force }
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*0\s*;", "BattlEye = 1;"; Set-Content $cfg $c -NoNewline
    Remove-Item $rpt, $hcrpt -Force -ErrorAction SilentlyContinue
    net start Arma2OA-PR8 | Out-Null
    Start-Sleep 45
    Write-Output "=== plain HC1 via task under BE=1 ==="
    schtasks /Run /TN MiksuuHC 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null
    Start-Sleep 75
    Write-Output ("HCproc=" + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count))
    Write-Output "=== SERVER rpt: identity / BE / HC ==="
    Select-String -LiteralPath $rpt -Pattern "HC-AI-Control-1|Player without identity|BattlEye|kicked" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 6
    Write-Output "=== HC CLIENT rpt (ArmA2OA.RPT): BE / GUID / kick / connect ==="
    if (Test-Path $hcrpt) {
        Select-String -LiteralPath $hcrpt -Pattern "BattlEye|BE |GUID|kick|identity|master|connect|Punk|initiali" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 20
        Write-Output "--- HC rpt tail ---"
        Get-Content $hcrpt -Tail 6 -ErrorAction SilentlyContinue
    } else { Write-Output "no HC rpt (process may have died before writing)" }
    Write-Output "=== any BE log now (server or client) ==="
    Get-ChildItem $loadDirs -Include "*.log" -Recurse -ErrorAction SilentlyContinue | Select-Object FullName, LastWriteTime, Length | Format-Table -AutoSize
}
finally {
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null; Stop-Process -Name ArmA2OA -Force -ErrorAction SilentlyContinue
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*1\s*;", "BattlEye = 0;"; Set-Content $cfg $c -NoNewline
    net start Arma2OA-PR8 | Out-Null; Start-Sleep 50
    schtasks /Run /TN MiksuuHC 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 40
    schtasks /Run /TN MiksuuHC2 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 25
    Write-Output ("=== REVERTED: cfg " + ((Get-Content $cfg | Select-String 'BattlEye').Line.Trim()) + " | svc " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()) + " | HC " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count))
}
