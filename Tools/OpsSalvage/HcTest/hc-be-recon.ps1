# hc-be-recon.ps1 - READ ONLY. How would an HC connect under BE? (no restart, live server untouched)
$ErrorActionPreference = "Continue"
$oa = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"

Write-Output "=== box Windows build (client-BE service breaks on 24H2/25H2) ==="
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion") | Select-Object ProductName, DisplayVersion, CurrentBuild | Format-List

Write-Output "=== is ArmA2OA_BE.exe present (the client BE launcher)? ==="
foreach ($e in @("$oa\ArmA2OA_BE.exe","$oa\Expansion\beta\ArmA2OA_BE.exe")) {
    if (Test-Path $e) { Write-Output ("FOUND " + $e + " (" + (Get-Item $e).Length + " b)") } else { Write-Output ("absent: " + $e) }
}

Write-Output "=== BEService / BEService_x64 on box (Common Files) ==="
Get-ChildItem "C:\Program Files (x86)\Common Files\BattlEye" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
Get-Service -Name "*BE*","*BattlEye*" -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize

Write-Output "=== which USER runs the HC tasks? ==="
foreach ($t in @("MiksuuHC","MiksuuHC2")) {
    $p = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).Principal
    Write-Output ($t + " -> UserId=" + $p.UserId + " RunLevel=" + $p.RunLevel + " LogonType=" + $p.LogonType)
}

Write-Output "=== HC1 profile RPT (the CLIENT rpt - why did it drop under BE?) ==="
$hcrpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT"
if (Test-Path $hcrpt) {
    Write-Output ("HC RPT: " + $hcrpt + " mtime=" + (Get-Item $hcrpt).LastWriteTime)
    Write-Output "--- BE / kick / identity / connect lines ---"
    Select-String -LiteralPath $hcrpt -Pattern "BattlEye|BE |kick|identity|connect|disconnect|GUID|Punkbuster" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 20
    Write-Output "--- tail ---"
    Get-Content $hcrpt -Tail 8 -ErrorAction SilentlyContinue
} else { Write-Output "HC RPT not found at expected path" }

Write-Output "=== BEClient.dll present where an Administrator-run client would look? ==="
foreach ($d in @("C:\Users\Administrator\AppData\Local\ArmA 2 OA\BattlEye","$oa\BattlEye","$oa\Expansion\BattlEye")) {
    Write-Output ("  " + $d + " -> " + ((Get-ChildItem $d -ErrorAction SilentlyContinue).Name -join ", "))
}

Write-Output "=== Sandboxie HC2 profile (its LOCALAPPDATA is redirected into the box) ==="
Get-ChildItem "C:\Sandbox" -Directory -ErrorAction SilentlyContinue | Select-Object FullName | Format-Table -AutoSize
Get-ChildItem "C:\Users\*\Sandbox" -Directory -ErrorAction SilentlyContinue | Select-Object FullName | Format-Table -AutoSize
