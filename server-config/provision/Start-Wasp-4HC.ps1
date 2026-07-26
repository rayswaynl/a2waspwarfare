# Start-Wasp-4HC.ps1 - start server + HC1..HC<N> staggered, then pin affinity.
# -HcCount 1..4 (default 4): a 1-HC or 2-HC box runs this same script with -HcCount 1|2;
# only launchers 1..N are fired, and the affinity map scales to match.
# ORDER MATTERS: hc_launch.cmd (HC1) begins with 'taskkill /f /im ArmA2OA.exe' which
# kills EVERY HC - so HC1 must always start before the others. HC1 is always part of the
# set (counts are contiguous 1..N), so the kill doubles as stale-HC cleanup on restart;
# that is also why the taskkill stays in hc_launch.cmd (scheduled tasks fire it standalone).
# Run from the RDP console or a scheduled task - NOT from a bare ssh session
# (Windows sshd kills detached children when the session closes).
# PowerShell 5.1 compatible. Run elevated.
Param(
    [String]$WaspDir = 'C:\WASP',
    [ValidateRange(1, 4)][Int]$HcCount = 4,
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
foreach ($n in 1..$HcCount) {
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
& (Join-Path $here 'Set-WaspAffinity.ps1') -HcCount $HcCount
if ($LASTEXITCODE -ne 0) {
    Write-Warning ("Not all {0} processes were pinned - HCs may still be warming up. Re-run Set-WaspAffinity.ps1 -HcCount {1} in ~2 minutes." -f (1 + $HcCount), $HcCount)
}
Write-Host ("DONE Start-Wasp-4HC ({0} HC(s)). Next: Verify-4HC.ps1 -HcCount {0} (give HCs ~2-3 min to connect first)." -f $HcCount)
