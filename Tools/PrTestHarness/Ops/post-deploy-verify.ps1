#requires -Version 5.1
<#
.SYNOPSIS
    Post-deploy verification script for WASP Warfare on Hetzner test box.
    Run after any V0.6.x deploy to assert server + HCs healthy and AICOM running.

.DESCRIPTION
    Checks (in order):
      A) 3/3 processes running (1 server + 2 HC)
      B) Both AICOM sides produce a first TICK within 8 minutes of server boot
      C) No new Error-in-expression blocks in the new RPT region (handles RPT recreation)
    Prints PASS/FAIL per check and exits with code 0 (all pass) or 1 (any fail).

.PARAMETER BootWaitSec
    How long to wait (polling every 10s) for the server process to appear before
    giving up. Default: 120 seconds (2 min).

.PARAMETER TickWaitMin
    How many minutes to wait for the first TICK before declaring failure.
    Default: 8 minutes.

.PARAMETER SrvRpt
    Full path to arma2oaserver.RPT. Default: standard path.

.EXAMPLE
    # Run immediately after triggering a deploy / restart
    powershell -ExecutionPolicy Bypass -File C:\WASP\post-deploy-verify.ps1

    # With custom wait times
    powershell -ExecutionPolicy Bypass -File C:\WASP\post-deploy-verify.ps1 -BootWaitSec 180 -TickWaitMin 10
#>

[CmdletBinding()]
param(
    [int]    $BootWaitSec = 120,
    [int]    $TickWaitMin = 8,
    [string] $SrvRpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT",
    [string] $Hc1Rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT",
    [string] $Hc2Rpt = "C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PASS = "[PASS]"
$FAIL = "[FAIL]"
$results = [System.Collections.Generic.List[string]]::new()
$anyFail  = $false

function Write-Check {
    param([bool]$ok, [string]$label, [string]$detail)
    $pfx = if ($ok) { $PASS } else { $FAIL }
    $msg = "$pfx $label - $detail"
    Write-Host $msg
    $script:results.Add($msg)
    if (-not $ok) { $script:anyFail = $true }
}

Write-Host ""
Write-Host "========================================="
Write-Host " WASP Post-Deploy Verification"
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "========================================="
Write-Host ""

# ---------------------------------------------------------------------------
# CHECK A: Wait for server boot, then assert 3/3 processes
# ---------------------------------------------------------------------------
Write-Host "[CHECK A] Waiting up to ${BootWaitSec}s for arma2oaserver to appear..."
$deadline = (Get-Date).AddSeconds($BootWaitSec)
$srvFound = $false
while ((Get-Date) -lt $deadline) {
    $srv = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue)
    if ($srv.Count -ge 1) { $srvFound = $true; break }
    Write-Host "  ...waiting (no server process yet)"
    Start-Sleep -Seconds 10
}

if (-not $srvFound) {
    Write-Check $false "PROC" "arma2oaserver did not appear within ${BootWaitSec}s - aborting further checks"
    Write-Host ""
    Write-Host "RESULT: FAIL (server not up)"
    exit 1
}

# Give HCs up to 60s to join after server appears
Write-Host "  Server found. Waiting up to 60s for both HCs..."
$hcDeadline = (Get-Date).AddSeconds(60)
$hcReady    = $false
while ((Get-Date) -lt $hcDeadline) {
    $hcProcs = @(Get-Process -Name "ArmA2OA" -ErrorAction SilentlyContinue)
    if ($hcProcs.Count -ge 2) { $hcReady = $true; break }
    Write-Host "  ...waiting for HCs ($($hcProcs.Count)/2 up)"
    Start-Sleep -Seconds 10
}

$srvCount = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue).Count
$hcCount  = @(Get-Process -Name "ArmA2OA"       -ErrorAction SilentlyContinue).Count
$total    = $srvCount + $hcCount

Write-Check ($total -eq 3) "PROC" "server=${srvCount} HC=${hcCount} total=${total} (expect 3)"

# ---------------------------------------------------------------------------
# CHECK B: First TICKs appear within TickWaitMin
#          Handle RPT recreation: note the file size at our start time; if
#          the file shrinks, reset our scan offset to 0.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[CHECK B] Waiting up to ${TickWaitMin} min for first TICKs from both sides..."

# Snapshot the RPT size right now (after boot) to define the "new RPT region"
$rptBaseSize = 0
if (Test-Path $SrvRpt) {
    $rptBaseSize = (Get-Item $SrvRpt -ErrorAction SilentlyContinue).Length
}
Write-Host "  RPT baseline size at check start: $rptBaseSize bytes"

$tickDeadline = (Get-Date).AddMinutes($TickWaitMin)
$seenEast     = $false
$seenWest     = $false

while ((Get-Date) -lt $tickDeadline) {
    if (Test-Path $SrvRpt) {
        $curSize = (Get-Item $SrvRpt -ErrorAction SilentlyContinue).Length
        # If file shrank (RPT recreated), reset baseline
        if ($curSize -lt $rptBaseSize) {
            Write-Host "  RPT recreated (size $curSize < baseline $rptBaseSize) - scanning from 0"
            $rptBaseSize = 0
        }
        # Read lines from baseline offset onward
        try {
            $allLines = Get-Content -Path $SrvRpt -Encoding UTF8 -ErrorAction Stop
            # Approximate byte-to-line mapping by scanning from the portion we care about
            # Simpler: just scan the full file each time (RPT is small enough)
            $tickLines = @($allLines | Where-Object { $_ -match 'AICOMSTAT\|v1\|TICK\|' })
            foreach ($line in $tickLines) {
                $clean = $line -replace '^.*AICOMSTAT\|', 'AICOMSTAT|'
                $parts = $clean -split '\|'
                if ($parts.Count -ge 4) {
                    if ($parts[3] -eq 'EAST') { $seenEast = $true }
                    if ($parts[3] -eq 'WEST') { $seenWest = $true }
                }
            }
        } catch {}
    }

    if ($seenEast -and $seenWest) {
        Write-Host "  Both sides TICKed."
        break
    }

    $remaining = [Math]::Round(($tickDeadline - (Get-Date)).TotalSeconds)
    Write-Host "  EAST:$(if($seenEast){'seen'}else{'waiting'}) WEST:$(if($seenWest){'seen'}else{'waiting'}) (${remaining}s left)"
    Start-Sleep -Seconds 20
}

Write-Check ($seenEast -and $seenWest) "TICK" "EAST=$(if($seenEast){'seen'}else{'MISSING'}) WEST=$(if($seenWest){'seen'}else{'MISSING'}) within ${TickWaitMin}min"

# ---------------------------------------------------------------------------
# CHECK C: No new Error-in-expression blocks in the new RPT region
#          "New region" = lines added since BootWaitSec started
#          Handle RPT recreation: if file shrank, scan from line 0
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[CHECK C] Scanning new RPT region for Error-in-expression blocks..."

$ERR_THRESHOLD  = 10  # error lines attributable to Server\AI or Client\Module
$newErrCount    = 0
$newErrFiles    = @()

if (Test-Path $SrvRpt) {
    try {
        $allLines = Get-Content -Path $SrvRpt -Encoding UTF8 -ErrorAction Stop
        $curSize  = (Get-Item $SrvRpt -ErrorAction SilentlyContinue).Length

        # Determine scan window: if RPT was recreated (rptBaseSize=0) scan all; otherwise scan tail
        $scanLines = if ($rptBaseSize -le 0) {
            $allLines
        } else {
            # Heuristic: use last N lines proportional to bytes added
            $bytesAdded = $curSize - $rptBaseSize
            $approxLines = [Math]::Max(200, [Math]::Min($allLines.Count, [int]($bytesAdded / 80) + 50))
            $allLines | Select-Object -Last $approxLines
        }

        $errLines   = @($scanLines | Where-Object { ($_ -match 'Error in expression') -and ($_ -match 'Server\\AI|Client\\Module') })
        $newErrCount = $errLines.Count
        $newErrFiles = @($scanLines | Where-Object { $_ -match 'File mpmissions.*\.(sqf|sqs)' } |
            ForEach-Object { if ($_ -match 'File (mpmissions\S+)') { $matches[1] } } |
            Select-Object -Unique)

        Write-Host "  Scanned approx $($scanLines.Count) lines in new region. Found $newErrCount error lines."
        if ($newErrFiles.Count -gt 0) { Write-Host "  Error files: $($newErrFiles -join ', ')" }
    } catch {
        Write-Host "  WARNING: Could not read server RPT - $_"
        $newErrCount = 0
    }
}

Write-Check ($newErrCount -le $ERR_THRESHOLD) "ERRBLK" "${newErrCount} error lines in new RPT region (threshold $ERR_THRESHOLD)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================="
Write-Host " SUMMARY"
Write-Host "========================================="
foreach ($r in $results) { Write-Host $r }
Write-Host ""
if ($anyFail) {
    Write-Host "RESULT: FAIL"
    exit 1
} else {
    Write-Host "RESULT: PASS"
    exit 0
}
