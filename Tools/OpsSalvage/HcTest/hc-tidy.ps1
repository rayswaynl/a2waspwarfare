$ErrorActionPreference = "Continue"
# remove HC test scripts + betest backup; keep dll fix staged + proven revert tooling
foreach ($f in @("hc-be-recon.ps1","hc-be-test.ps1","hc-be-test2.ps1","hc-be-diag.ps1","hc_launch_be.cmd","hc-tidy.ps1")) { Remove-Item "C:\WASP\$f" -Force -ErrorAction SilentlyContinue }
# confirm hc_launch.cmd is the ORIGINAL (plain ArmA2OA.exe) and drop the betest backup if identical
$cur = Get-Content "C:\WASP\hc_launch.cmd" -Raw -ErrorAction SilentlyContinue
if ($cur -match 'ArmA2OA\.exe" -client') { Remove-Item "C:\WASP\hc_launch.cmd.bak-betest" -Force -ErrorAction SilentlyContinue; $ok="ORIGINAL (plain)" } else { $ok="!! NOT original - check" }
Write-Output ("hc_launch.cmd: " + $ok)
Write-Output ("service: " + ((sc.exe query Arma2OA-PR8 | Select-String 'STATE').ToString().Trim()) + " | HC " + (@(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count) + " | cfg " + ((Get-Content 'C:\WASP\profiles-pr8\server-pr8.cfg' | Select-String 'BattlEye').Line.Trim()))
Write-Output ("dll fix staged: LOCALAPPDATA=" + ((Get-ChildItem 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\BattlEye' -ErrorAction SilentlyContinue).Count) + " files | OA-root=" + ((Get-ChildItem 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\BattlEye' -ErrorAction SilentlyContinue).Count) + " files")
