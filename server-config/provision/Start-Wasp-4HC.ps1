# Start-Wasp-4HC.ps1 - start server + HC1..HC4, then pin affinity.
# ORDER MATTERS: hc_launch.cmd (HC1) begins with 'taskkill /f /im ArmA2OA.exe' which
# kills EVERY HC - so HC1 must always start before HC2/HC3/HC4.
# Run from the RDP console or a scheduled task - NOT from a bare ssh session
# (Windows sshd kills detached children when the session closes).
# PowerShell 5.1 compatible. Run elevated.
#
# 2026-07-27 HC-SEATING ROOT-CAUSE FIX (owner-authorised):
#   forceHeadlessClient=1 does NOT route a slot on A2 OA 1.64 -client connections. The engine
#   assigns the LOWEST-NUMBERED free player="PLAY CDG" slot by id order, side-blind. The CIV
#   headless slots are ids 9009-9012, far above the WEST slots (id 229), so they can never win
#   a fair race. What DOES work is JIPing into an ALREADY-LIVE mission - which is exactly why the
#   manual post-start bounce has been the only remedy for six weeks.
#   The old gate here was a blind `Start-Sleep -Seconds 45` against SERVER PROCESS start, which on
#   this mission put every HC connect (measured t=64/79/94/109s) inside the load window - the
#   mission does not finish initialising until MATCH|v1|START| at ~t=120s.
#   We now WAIT FOR THE MISSION TO BE LIVE (MATCH|v1|START| in the server RPT, appearing AFTER we
#   started the server) before launching any HC. Falls back to the legacy fixed sleep on timeout so
#   a marker change can never wedge the boot.
Param(
    [String]$WaspDir = 'C:\WASP',
    [Int]$ServerSettleSeconds = 45,          # legacy fallback only (see MissionLiveTimeoutSeconds)
    [Int]$HcStaggerSeconds = 20,
    [Int]$AffinityDelaySeconds = 60,
    [String]$ServerRpt = "$env:USERPROFILE\AppData\Local\ArmA 2 OA\arma2oaserver.RPT",
    [String]$MissionLiveMarker = 'MATCH|v1|START|',
    [Int]$MissionLiveTimeoutSeconds = 420,   # generous: a cold Chernarus load measured ~120s
    [Int]$PostLiveBufferSeconds = 15         # small settle after the marker before the first HC
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

# --- Record where the RPT ends BEFORE we start, so we only ever match OUR boot's marker.
# The RPT accumulates across restarts; matching the whole file would see a previous match's marker
# and let the HCs go early - reintroducing the exact race this fix removes.
$rptOffset = 0
if (Test-Path -LiteralPath $ServerRpt) {
    try { $rptOffset = ([IO.FileInfo]::new($ServerRpt)).Length } catch { $rptOffset = 0 }
}
Write-Host ("Server RPT: {0}" -f $ServerRpt)
Write-Host ("Pre-start RPT offset: {0} bytes" -f $rptOffset)

Write-Host '== Starting dedicated server =='
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"{0}"' -f $serverCmd) -WorkingDirectory $WaspDir

# --- Wait for the MISSION to be live, not merely for the process to exist. -------------------
function Test-MissionLive {
    Param([String]$Path, [Long]$Offset, [String]$Marker)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $fs = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            if ($fs.Length -le $Offset) { return $false }
            [void]$fs.Seek($Offset, [IO.SeekOrigin]::Begin)
            $sr = New-Object IO.StreamReader($fs)
            $new = $sr.ReadToEnd()
            $sr.Close()
        } finally { $fs.Dispose() }
        return ($new -like ("*" + $Marker + "*"))
    } catch { return $false }
}

Write-Host ("Waiting for the mission to go LIVE (marker '{0}', timeout {1}s)..." -f $MissionLiveMarker, $MissionLiveTimeoutSeconds)
$sw = [Diagnostics.Stopwatch]::StartNew()
$live = $false
while ($sw.Elapsed.TotalSeconds -lt $MissionLiveTimeoutSeconds) {
    if ($null -eq (Get-Process arma2oaserver -ErrorAction SilentlyContinue)) {
        if ($sw.Elapsed.TotalSeconds -gt 30) {
            throw 'arma2oaserver.exe is not running - check the server RPT before starting HCs.'
        }
    }
    if (Test-MissionLive -Path $ServerRpt -Offset $rptOffset -Marker $MissionLiveMarker) {
        $live = $true
        break
    }
    Start-Sleep -Seconds 3
}
$sw.Stop()

if ($live) {
    Write-Host ("MISSION LIVE after {0:N0}s - HCs will now JIP into a running mission (this is the seating fix)." -f $sw.Elapsed.TotalSeconds)
    if ($PostLiveBufferSeconds -gt 0) {
        Write-Host ("Settling {0}s before the first HC..." -f $PostLiveBufferSeconds)
        Start-Sleep -Seconds $PostLiveBufferSeconds
    }
} else {
    Write-Warning ("Mission-live marker '{0}' not seen within {1}s - FALLING BACK to the legacy fixed {2}s settle." -f $MissionLiveMarker, $MissionLiveTimeoutSeconds, $ServerSettleSeconds)
    Write-Warning 'HC seating may fail (this is the pre-2026-07-27 behaviour). Check the marker string against the current build.'
    Start-Sleep -Seconds $ServerSettleSeconds
}

if ($null -eq (Get-Process arma2oaserver -ErrorAction SilentlyContinue)) {
    throw 'arma2oaserver.exe is not running after the wait - check the server RPT before starting HCs.'
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
