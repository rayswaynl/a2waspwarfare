$rpt = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$all = Get-Content $rpt
$mi = ($all | Select-String -Pattern 'MISSINIT' | Select-Object -Last 1).LineNumber
$w = $all[($mi-1)..($all.Count-1)]
$w | Select-String -Pattern 'reseat|RESEAT|HC-AI|hcseat|magnet|civilian' -CaseSensitive:$false | Select-Object -First 12 | ForEach-Object { $_.Line }
