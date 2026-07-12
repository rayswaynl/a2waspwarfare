$ErrorActionPreference = "Continue"
$oa = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
$cfg = "C:\WASP\profiles-pr8\server-pr8.cfg"
$rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
$hccmd = "C:\WASP\hc_launch.cmd"
$loadDirs = @("C:\Users\Administrator\AppData\Local\ArmA 2 OA\BattlEye", "$oa\BattlEye")
$src = "$oa\Expansion\BattlEye"

if (-not (Test-Path "$hccmd.bak-betest")) { Copy-Item $hccmd "$hccmd.bak-betest" -Force }
$orig = Get-Content "$hccmd.bak-betest" -Raw

try {
    # write BE-launcher variant of hc_launch.cmd (ArmA2OA_BE.exe 2 0 <same args>)
    $be = $orig -replace '"ArmA2OA\.exe"', '"ArmA2OA_BE.exe" 2 0'
    Set-Content $hccmd $be -Encoding ASCII
    Write-Output "--- hc_launch.cmd now launches via:"
    (Get-Content $hccmd | Select-String "ArmA2OA").Line.Trim()

    # stop, stage dll fix, BE=1
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null; schtasks /End /TN MiksuuHC2 2>&1 | Out-Null
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    foreach ($d in $loadDirs) { New-Item -ItemType Directory -Force $d | Out-Null; Copy-Item "$src\BEServer.dll" "$d\" -Force; Copy-Item "$src\BEClient.dll" "$d\" -Force }
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*0\s*;", "BattlEye = 1;"; Set-Content $cfg $c -NoNewline
    Remove-Item $rpt -Force -ErrorAction SilentlyContinue
    net start Arma2OA-PR8 | Out-Null
    Write-Output "server up BE=1; waiting for Steam..."
    Start-Sleep 45

    Write-Output "=== run MiksuuHC task (launches HC1 via BE in the interactive session) ==="
    schtasks /Run /TN MiksuuHC 2>&1 | Out-Null
    schtasks /Run /TN DismissACR 2>&1 | Out-Null
    for ($i=0; $i -lt 6; $i++) {
        Start-Sleep 30
        $ident = (Select-String -LiteralPath $rpt -Pattern 'Player without identity "HC-AI-Control-1"' -ErrorAction SilentlyContinue | Measure-Object).Count
        $seat  = (Select-String -LiteralPath $rpt -Pattern 'HC-AI-Control-1' -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch "without identity" } | Measure-Object).Count
        $hc = @(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count
        $beproc = @(Get-Process BEService -ErrorAction SilentlyContinue).Count
        Write-Output ("t+$(($i+1)*30)s HCproc=$hc identityErr=$ident hcSeatLines=$seat BEService=$beproc")
        if ($seat -gt 0 -and $ident -eq 0) { break }
    }
    Write-Output "=== VERDICT ==="
    Select-String -LiteralPath $rpt -Pattern "HC-AI-Control-1|Player without identity|BattlEye|verified|kicked|GUID" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 14
}
finally {
    Write-Output "=== REVERT: restore hc_launch.cmd, BE=0, normal HCs ==="
    Set-Content $hccmd $orig -Encoding ASCII
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null
    Stop-Process -Name ArmA2OA -Force -ErrorAction SilentlyContinue
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*1\s*;", "BattlEye = 0;"; Set-Content $cfg $c -NoNewline
    net start Arma2OA-PR8 | Out-Null; Start-Sleep 50
    schtasks /Run /TN MiksuuHC 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 40
    schtasks /Run /TN MiksuuHC2 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 25
    Write-Output ("cfg " + ((Get-Content $cfg | Select-String 'BattlEye').Line.Trim()) + " | svc " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()) + " | HC " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count) + " | hc_launch restored=" + ((Get-Content $hccmd | Select-String 'ArmA2OA\.exe" -client' | Measure-Object).Count))
}
