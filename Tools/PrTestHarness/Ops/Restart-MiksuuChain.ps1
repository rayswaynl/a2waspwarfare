#requires -Version 5.1
<#
.SYNOPSIS
    Restart the full Miksuu WASP server chain in the proven boot order:
    MiksuuPR8 → MiksuuHC → MiksuuHC2 → bounce HC1 → bounce HC2.

.DESCRIPTION
    Every deploy script historically hand-copied the same ~30-line restart
    sequence.  This function centralises the PROVEN sequence so changes only
    need to be made in one place.

    BOOT ORDER RATIONALE
    The mission requires exactly 1 server + 2 headless clients (HCs).
    Naively starting both HCs together causes a race where both land in the
    default BLUFOR slot.  The bounce steps exist to fix this:

      - HC1 bounce (step 4):
          A lobby-seated HC (one that connected before the mission started)
          keeps whatever slot it grabbed at JIP — typically the BLUFOR default.
          Killing and re-launching HC1 after the mission is running forces it to
          re-connect as a JIP client.  Only JIP clients are auto-seated into
          the CIV forceHeadlessClient slot by the mission's Init_Server.sqf.
          Without this bounce, HC1 occupies the BLUFOR slot and the CIV AI
          delegation path is never established.

      - HC2 bounce (step 5):
          HC2 has the same problem.  It is bounced after HC1 so that both HCs
          are JIP-seated correctly.  The "kill all ArmA2OA except newest"
          targeting ensures only the original HC2 process is replaced, not the
          freshly-bounced HC1.

    TASK NAMES
    The scheduled tasks (MiksuuPR8, MiksuuHC, MiksuuHC2) are registered on
    the Hetzner box under Task Scheduler and are the authoritative way to
    start Arma processes on that machine.

.PARAMETER SkipStop
    If specified, skip the initial kill of all Arma processes and jump straight
    to launching MiksuuPR8.  Use only when you know the slot is already clear.

.PARAMETER LogPath
    Path to a log file.  Each major step is appended with a timestamp.
    Default: C:\WASP\logs\chain-restart.log

.EXAMPLE
    # Full restart from a clean state
    .\Restart-MiksuuChain.ps1

.EXAMPLE
    # Skip the stop phase (processes already gone) and log elsewhere
    .\Restart-MiksuuChain.ps1 -SkipStop -LogPath "C:\WASP\logs\deploy-$(Get-Date -f yyyyMMdd).log"

.NOTES
    PowerShell 5.1-compatible (box runs PS 5.1).
    All timing values are the empirically-proven waits from the original deploy
    scripts.  Do not reduce them without testing: HCs that connect before the
    mission lobby is ready grab permanent BLUFOR slots and the double-bounce
    stops working.
#>

[CmdletBinding()]
param(
    [switch]$SkipStop,
    [string]$LogPath = "C:\WASP\logs\chain-restart.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------
function Write-Step {
    param([string]$msg)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line
    try {
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    } catch {
        Write-Warning "Log write failed: $_"
    }
}

# ---------------------------------------------------------------------------
# Helper: dismiss the ACR / DLC prompt that appears when ArmA2OA starts
# without access to ACR content.  The window title varies; we target the
# process's MainWindowTitle and send an Enter keystroke via the shell.
# ---------------------------------------------------------------------------
function Dismiss-AcRPrompt {
    param([int]$WaitSec = 10)
    Start-Sleep -Seconds $WaitSec
    $wshell = New-Object -ComObject WScript.Shell
    # The prompt window is titled "" or "ArmA 2 Operation Arrowhead" - send Enter to any foreground
    $wshell.SendKeys("{ENTER}")
    Start-Sleep -Seconds 2
    $wshell.SendKeys("{ENTER}")   # belt-and-suspenders: dismiss a second time
}

Write-Step "=== Restart-MiksuuChain START ==="

# ---------------------------------------------------------------------------
# STEP 1 — Stop everything
# ---------------------------------------------------------------------------
if (-not $SkipStop) {
    Write-Step "STEP 1: Ending scheduled tasks MiksuuPR8 / MiksuuHC / MiksuuHC2..."
    foreach ($task in @("MiksuuPR8", "MiksuuHC", "MiksuuHC2")) {
        try { Stop-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue } catch {}
    }
    Start-Sleep -Seconds 3

    Write-Step "STEP 1: Killing remaining arma2oaserver / ArmA2OA processes..."
    Stop-Process -Name "arma2oaserver" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "ArmA2OA"       -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    $remaining = @(Get-Process -Name "arma2oaserver","ArmA2OA" -ErrorAction SilentlyContinue)
    if ($remaining.Count -gt 0) {
        Write-Step "STEP 1: WARNING - $($remaining.Count) process(es) still alive after kill attempt"
    } else {
        Write-Step "STEP 1: All Arma processes stopped."
    }
} else {
    Write-Step "STEP 1: -SkipStop specified - skipping process teardown."
}

# ---------------------------------------------------------------------------
# STEP 2 — Launch MiksuuPR8 (server), wait 40s for mission lobby
# ---------------------------------------------------------------------------
Write-Step "STEP 2: Launching MiksuuPR8 (server) via scheduled task..."
Start-ScheduledTask -TaskName "MiksuuPR8"
Write-Step "STEP 2: Waiting 40s for server to reach mission lobby..."
Start-Sleep -Seconds 40

$srvProcs = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue)
Write-Step "STEP 2: arma2oaserver count = $($srvProcs.Count)"

# ---------------------------------------------------------------------------
# STEP 3 — Launch MiksuuHC (first headless client), wait 55s, dismiss ACR
# ---------------------------------------------------------------------------
Write-Step "STEP 3: Launching MiksuuHC (HC1) via scheduled task..."
Start-ScheduledTask -TaskName "MiksuuHC"
Write-Step "STEP 3: Waiting 55s for HC1 to connect and settle..."
Start-Sleep -Seconds 55

Write-Step "STEP 3: Dismissing ACR/DLC prompt (if any)..."
Dismiss-AcRPrompt -WaitSec 0

# ---------------------------------------------------------------------------
# STEP 3b — Launch MiksuuHC2 (second headless client), wait 50s, dismiss ACR
# ---------------------------------------------------------------------------
Write-Step "STEP 3b: Launching MiksuuHC2 (HC2) via scheduled task..."
Start-ScheduledTask -TaskName "MiksuuHC2"
Write-Step "STEP 3b: Waiting 50s for HC2 to connect and settle..."
Start-Sleep -Seconds 50

Write-Step "STEP 3b: Dismissing ACR/DLC prompt (if any)..."
Dismiss-AcRPrompt -WaitSec 0

# ---------------------------------------------------------------------------
# STEP 4 — Bounce HC1
#   WHY: HC1 connected before the mission started (lobby-seated).  A
#   lobby-seated HC keeps the BLUFOR default slot it grabbed at join time.
#   Only a JIP-joining HC is auto-seated into the CIV forceHeadlessClient
#   slot by Init_Server.sqf.  We kill the earliest ArmA2OA process and
#   re-launch MiksuuHC so HC1 joins as a JIP.
# ---------------------------------------------------------------------------
Write-Step "STEP 4: Bouncing HC1 - killing earliest ArmA2OA process..."
$hcProcs = @(Get-Process -Name "ArmA2OA" -ErrorAction SilentlyContinue | Sort-Object StartTime)
if ($hcProcs.Count -ge 1) {
    $oldest = $hcProcs[0]
    Write-Step "STEP 4: Killing PID $($oldest.Id) (started $($oldest.StartTime))"
    Stop-Process -Id $oldest.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
} else {
    Write-Step "STEP 4: WARNING - no ArmA2OA processes found to kill for HC1 bounce"
}

Write-Step "STEP 4: Ending and re-running MiksuuHC scheduled task..."
Stop-ScheduledTask  -TaskName "MiksuuHC" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "MiksuuHC"

Write-Step "STEP 4: Waiting 55s for HC1 to JIP-reconnect..."
Start-Sleep -Seconds 55

Write-Step "STEP 4: Dismissing ACR/DLC prompt (if any)..."
Dismiss-AcRPrompt -WaitSec 0

# ---------------------------------------------------------------------------
# STEP 5 — Bounce HC2
#   WHY: Same lobby-seat problem as HC1.  We kill all ArmA2OA processes
#   EXCEPT the newest one (that is the freshly-bounced HC1 from step 4)
#   and re-launch MiksuuHC2.
# ---------------------------------------------------------------------------
Write-Step "STEP 5: Bouncing HC2 - killing all ArmA2OA except newest..."
$hcProcs = @(Get-Process -Name "ArmA2OA" -ErrorAction SilentlyContinue | Sort-Object StartTime)
if ($hcProcs.Count -ge 2) {
    $toKill = $hcProcs[0..($hcProcs.Count - 2)]   # all except the last (newest)
    foreach ($p in $toKill) {
        Write-Step "STEP 5: Killing PID $($p.Id) (started $($p.StartTime))"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
} elseif ($hcProcs.Count -eq 1) {
    Write-Step "STEP 5: Only 1 ArmA2OA found - that should be HC1; no kill needed for HC2 bounce"
} else {
    Write-Step "STEP 5: WARNING - no ArmA2OA processes found"
}

Write-Step "STEP 5: Ending and re-running MiksuuHC2 scheduled task..."
Stop-ScheduledTask  -TaskName "MiksuuHC2" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "MiksuuHC2"

Write-Step "STEP 5: Waiting 50s for HC2 to JIP-reconnect..."
Start-Sleep -Seconds 50

Write-Step "STEP 5: Dismissing ACR/DLC prompt (if any)..."
Dismiss-AcRPrompt -WaitSec 0

# ---------------------------------------------------------------------------
# STEP 6 — Final process count check; retry HC2 once if < 3 total
# ---------------------------------------------------------------------------
$srvCount = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue).Count
$hcCount  = @(Get-Process -Name "ArmA2OA"       -ErrorAction SilentlyContinue).Count
$total    = $srvCount + $hcCount
Write-Step "STEP 6: Process count: server=$srvCount HC=$hcCount total=$total (expect 3)"

if ($total -lt 3) {
    Write-Step "STEP 6: Total < 3 - retrying MiksuuHC2 once..."
    Stop-ScheduledTask  -TaskName "MiksuuHC2" -ErrorAction SilentlyContinue
    Stop-Process -Name "ArmA2OA" -Force -ErrorAction SilentlyContinue   # clear any partial
    Start-Sleep -Seconds 5
    Start-ScheduledTask -TaskName "MiksuuHC2"
    Start-Sleep -Seconds 50
    Dismiss-AcRPrompt -WaitSec 0

    $srvCount = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue).Count
    $hcCount  = @(Get-Process -Name "ArmA2OA"       -ErrorAction SilentlyContinue).Count
    $total    = $srvCount + $hcCount
    Write-Step "STEP 6: After retry: server=$srvCount HC=$hcCount total=$total"
}

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if ($total -eq 3) {
    Write-Step "=== Restart-MiksuuChain DONE - chain is up (3/3 processes) ==="
    exit 0
} else {
    Write-Step "=== Restart-MiksuuChain WARN - chain may be incomplete (total=$total, expected 3) ==="
    exit 1
}
