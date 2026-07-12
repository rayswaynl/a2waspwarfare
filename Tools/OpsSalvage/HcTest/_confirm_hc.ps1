$ErrorActionPreference = 'SilentlyContinue'
$rpt = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
for ($k = 0; $k -lt 14; $k++) {
    $t   = Get-Date -Format 'HH:mm:ss'
    $svc = (Get-Service Arma2OA-PR8).Status
    $hc  = @(Get-Process ArmA2OA).Count
    $h   = @(Get-Content $rpt | Select-String 'headless:\d')
    if ($h.Count -gt 0) {
        Write-Output ("[$t] svc=$svc hcProc=$hc  CONFIRMED -> " + $h[-1].Line)
        Write-Output 'CONFIRM DONE (audit caught)'
        return
    }
    Write-Output ("[$t] svc=$svc hcProc=$hc  (no delegation audit yet)")
    Start-Sleep -Seconds 80
}
Write-Output 'CONFIRM DONE (timed out, no town delegated in window)'
