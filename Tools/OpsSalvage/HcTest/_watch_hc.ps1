$ErrorActionPreference = 'SilentlyContinue'
$rpt = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$logf = 'C:\WASP\_hcwatch.log'
function Say($m) { Write-Output $m; Add-Content -LiteralPath $logf -Value $m }
Say ("==== HC WATCH START " + (Get-Date -Format 'HH:mm:ss') + " ====")
for ($k = 0; $k -lt 12; $k++) {
    $t   = Get-Date -Format 'HH:mm:ss'
    $svc = (Get-Service Arma2OA-PR8).Status
    $hc  = @(Get-Process ArmA2OA).Count
    $hl  = '-'
    if (Test-Path $rpt) {
        $au = @(Get-Content $rpt | Select-String 'headless:\d') | Select-Object -Last 1
        if ($au -and $au.Line -match 'headless:(\d+)') { $hl = $Matches[1] }
    }
    Say ("[$t] svc=$svc hcProc=$hc poolHeadless=$hl")
    Start-Sleep -Seconds 150
}
Say "==== HC WATCH DONE ===="
