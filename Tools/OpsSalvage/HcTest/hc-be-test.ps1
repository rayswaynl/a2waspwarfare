$ErrorActionPreference = "Continue"
$oa = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
$cfg = "C:\WASP\profiles-pr8\server-pr8.cfg"
$rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
$loadDirs = @("C:\Users\Administrator\AppData\Local\ArmA 2 OA\BattlEye", "$oa\BattlEye")
$src = "$oa\Expansion\BattlEye"

# BE launcher variant of hc_launch.cmd (HC1 only, non-sandboxed)
$hcBe = @"
@echo off
set SteamAppId=33930
cd /d "$oa"
taskkill /f /im ArmA2OA.exe >nul 2>&1
timeout /t 2 /nobreak >nul
"ArmA2OA_BE.exe" 2 0 -client -connect=127.0.0.1 -port=2302 -window -cfg="C:\WASP\hc-profile\hc-video.cfg" "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ACR;@CBA_CO;@adwasp;@admkswf" -name="HC-AI-Control-1" -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound
"@
Set-Content "C:\WASP\hc_launch_be.cmd" $hcBe -Encoding ASCII

try {
    # stop (kill first)
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null; schtasks /End /TN MiksuuHC2 2>&1 | Out-Null
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    # ensure dll fix present
    foreach ($d in $loadDirs) { New-Item -ItemType Directory -Force $d | Out-Null; Copy-Item "$src\BEServer.dll" "$d\" -Force; Copy-Item "$src\BEClient.dll" "$d\" -Force }
    # BE=1
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*0\s*;", "BattlEye = 1;"; Set-Content $cfg $c -NoNewline
    Remove-Item $rpt -Force -ErrorAction SilentlyContinue
    net start Arma2OA-PR8 | Out-Null
    Write-Output "server up BE=1; waiting for Steam..."
    Start-Sleep 45
    Write-Output "=== launch HC1 via ArmA2OA_BE.exe ==="
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null
    Start-Process "cmd.exe" -ArgumentList '/c','C:\WASP\hc_launch_be.cmd'
    for ($i=0; $i -lt 5; $i++) {
        Start-Sleep 30
        $ident = (Select-String -LiteralPath $rpt -Pattern 'Player without identity "HC-AI-Control-1"' -ErrorAction SilentlyContinue | Measure-Object).Count
        $seat  = (Select-String -LiteralPath $rpt -Pattern 'HCSIDE.*HC-AI-Control-1|preseat.*HC-AI-Control-1' -ErrorAction SilentlyContinue | Measure-Object).Count
        $hc = @(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count
        Write-Output ("t+$(($i+1)*30)s  HCproc=$hc  identityErrors=$ident  seatLines=$seat")
        if ($seat -gt 0) { break }
    }
    Write-Output "=== VERDICT ==="
    Write-Output "--- server RPT: HC lines ---"
    Select-String -LiteralPath $rpt -Pattern "HC-AI-Control-1|Player without identity|BattlEye|verified|kicked" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 12
}
finally {
    Write-Output "=== REVERT (kill-first, BE=0, normal HCs) ==="
    schtasks /End /TN MiksuuHC 2>&1 | Out-Null
    Stop-Process -Name ArmA2OA -Force -ErrorAction SilentlyContinue
    sc.exe stop Arma2OA-PR8 | Out-Null; Start-Sleep 6
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue; Start-Sleep 4
    $c = Get-Content $cfg -Raw; $c = $c -replace "BattlEye\s*=\s*1\s*;", "BattlEye = 0;"; Set-Content $cfg $c -NoNewline
    Remove-Item "C:\WASP\hc_launch_be.cmd" -Force -ErrorAction SilentlyContinue
    net start Arma2OA-PR8 | Out-Null; Start-Sleep 50
    schtasks /Run /TN MiksuuHC 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 40
    schtasks /Run /TN MiksuuHC2 2>&1 | Out-Null; schtasks /Run /TN DismissACR 2>&1 | Out-Null; Start-Sleep 25
    Write-Output ("cfg " + ((Get-Content $cfg | Select-String 'BattlEye').Line.Trim()) + " | svc " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()) + " | HC " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count))
}
