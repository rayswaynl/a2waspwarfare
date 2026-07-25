# Start-Wasp-4HC.ps1 - start server + HC1..HC4 staggered, then pin affinity.
# ORDER MATTERS: hc_launch.cmd (HC1) begins with 'taskkill /f /im ArmA2OA.exe' which
# kills EVERY HC - so HC1 must always start before HC2/HC3/HC4.
# Run from the RDP console or a scheduled task - NOT from a bare ssh session
# (Windows sshd kills detached children when the session closes).
# PowerShell 5.1 compatible. Run elevated.
Param(
    [String]$WaspDir = 'C:\WASP',
    [Int]$ServerSettleSeconds = 45,
    [Int]$HcStaggerSeconds = 20,
    [Int]$AffinityDelaySeconds = 60
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$serverCmd = Join-Path $WaspDir 'server_launch.cmd'
if (-not (Test-Path $serverCmd)) {
    $fallback = Join-Path $here 'server_launch.cmd'
    if (Test-Path $fallback) { Write-Warning ("{0} missing - using provision copy." -f $serverCmd); $serverCmd = $fallback }
    else { throw 'server_launch.cmd not found.' }
}

$launchers = @()
foreach ($n in 1..4) {
    if ($n -eq 1) { $name = 'hc_launch.cmd' } else { $name = ('hc{0}_launch.cmd' -f $n) }
    $path = Join-Path $WaspDir $name
    if (-not (Test-Path $path)) { throw ("Missing launcher: {0} (copy the repo server-config versions to {1} first)" -f $name, $WaspDir) }
    $launchers += $path
}

Write-Host '== Starting dedicated server =='
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"{0}"' -f $serverCmd) -WorkingDirectory $WaspDir
Write-Host ("Waiting {0}s for the server to settle..." -f $ServerSettleSeconds)
Start-Sleep -Seconds $ServerSettleSeconds
if ($null -eq (Get-Process arma2oaserver -ErrorAction SilentlyContinue)) {
    throw 'arma2oaserver.exe is not running after the settle window - check the server RPT before starting HCs.'
}

for ($i = 0; $i -lt $launchers.Count; $i++) {
    Write-Host ("== Starting HC{0} ==" -f ($i + 1))
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"{0}"' -f $launchers[$i]) -WorkingDirectory $WaspDir
    Start-Sleep -Seconds $HcStaggerSeconds
}

Write-Host ("Waiting {0}s for HC processes to spawn (sandboxed Steam warmup included in launchers)..." -f $AffinityDelaySeconds)
Start-Sleep -Seconds $AffinityDelaySeconds

Write-Host '== Applying affinity map =='
& (Join-Path $here 'Set-WaspAffinity.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Not all 5 processes were pinned - HCs may still be warming up. Re-run Set-WaspAffinity.ps1 in ~2 minutes.'
}
Write-Host 'DONE Start-Wasp-4HC. Next: Verify-4HC.ps1 (give HCs ~2-3 min to connect first).'
