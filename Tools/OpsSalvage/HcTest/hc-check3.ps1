$ErrorActionPreference = "Continue"
Write-Output "=== ArmA2OA (HC) processes: id + start time ==="
Get-Process ArmA2OA -ErrorAction SilentlyContinue | Select-Object Id, StartTime, @{n="MB";e={[int]($_.WorkingSet64/1MB)}} | Sort-Object StartTime | Format-Table -AutoSize
Write-Output "=== server RPT: HC seat/preseat state (who is actually connected) ==="
Select-String -LiteralPath "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT" -Pattern "HC-AI-Control|Player without identity|Headless" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Last 10
