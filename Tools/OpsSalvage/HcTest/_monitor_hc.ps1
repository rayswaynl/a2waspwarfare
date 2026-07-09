$ErrorActionPreference = 'SilentlyContinue'
$rpt = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$logf = 'C:\WASP\_hcmon.log'
function Say($m) { Write-Output $m; Add-Content -LiteralPath $logf -Value $m }
Say ("==== HC MONITOR START " + (Get-Date -Format 'HH:mm:ss') + " ====")
for ($k = 0; $k -lt 9; $k++) {
    $t   = Get-Date -Format 'HH:mm:ss'
    $svc = (Get-Service Arma2OA-PR8).Status
    $srv = @(Get-Process arma2oaserver).Count
    $hc  = @(Get-Process ArmA2OA).Count
    $hc2 = (((schtasks /query /tn MiksuuHC2 /fo list) | Select-String 'Status:') -join '').Trim() -replace 'Status:\s*', ''
    $hl  = '-'
    $reg = 0
    if (Test-Path $rpt) {
        $all = Get-Content $rpt
        $reg = @($all | Select-String 'Headless client is now connected').Count
        $au = @($all | Select-String 'headless:\d') | Select-Object -Last 1
        if ($au -and $au.Line -match 'headless:(\d+)') { $hl = $Matches[1] }
    }
    Say ("[$t] svc=$svc srvProc=$srv hcProc=$hc hc2task=$hc2 regHC=$reg poolHeadless=$hl")
    Start-Sleep -Seconds 30
}
Say "==== HC MONITOR DONE ===="
