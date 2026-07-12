<#
.SYNOPSIS
    Roll back a failed stresstest deploy on the shared WASP test box (Miksuus-TEST), stop-first.

.DESCRIPTION
    Hardened replacement for the ad-hoc rollback-stresstest.ps1 that ran on 2026-07-08/09.

    THE DEFECT THIS FIXES: the version that ran that night restored server-pr8.cfg from its
    backup BEFORE stopping the service - the running arma2oaserver holds the cfg file open, so
    the restore either failed outright or landed inconsistently, and only the subsequent call to
    service-restart.ps1 (which stops first internally) actually released the lock. This script
    stops the chain itself FIRST, exactly mirroring the working deploy.ps1 order, and only edits
    server-pr8.cfg once nothing has it open. service-restart.ps1 is still called afterward for
    bring-up (it is idempotent about stopping first), but this script no longer depends on it to
    be the only thing that stops the service.

    Also carries the RPT-probe fix from deploy.ps1 (expanded failure-signature list; see
    Tools/Stresstest/README.md) and the same drift-verify pattern on the restore direction.

.PARAMETER CfgBackup
    The pre-deploy backup written by deploy.ps1 (its final output line prints this path).

.PARAMETER RestoreTemplate
    The 'template =' value to restore (what was live before the stresstest deploy).

.PARAMETER StresstestTemplate
    The stresstest 'template =' value being rolled back away from, for drift-verify.

.EXAMPLE
    .\rollback.ps1 -CfgBackup 'C:\WASP\profiles-pr8\server-pr8.cfg.bak-stresstest-20260709-001040' `
                   -RestoreTemplate 'ch-dynAB-armB.chernarus' `
                   -StresstestTemplate '[61-2hc]warfarev2_073v48co_stresstest.zargabad'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)] [string]$CfgBackup,
    [Parameter(Mandatory = $true)] [string]$RestoreTemplate,
    [Parameter(Mandatory = $true)] [string]$StresstestTemplate,
    [string]$CfgPath      = 'C:\WASP\profiles-pr8\server-pr8.cfg',
    [string]$RptPath      = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT',
    [string]$RptArchive   = 'C:\WASP\rpt-archive',
    [string]$ServiceRestartScript = 'C:\WASP\service-restart.ps1',
    [string]$ServiceName  = 'Arma2OA-PR8',
    [int]$ProbeWaitSeconds = 90
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Output "=== ROLLBACK START $stamp ==="

# --- Preflight: backup must exist. ---
if (-not (Test-Path -LiteralPath $CfgBackup)) { throw "ROLLBACK FAILED: backup not found at $CfgBackup" }

# --- STOP FIRST. This is the fix: the 2026-07-08/09 version restored the cfg here, before any
#     stop, while arma2oaserver still had it open. Never reorder this ahead of the restore. ---
if ($PSCmdlet.ShouldProcess($ServiceName, "Stop chain")) {
    Write-Output "Stop chain..."
    Stop-Service $ServiceName -Force -ErrorAction Stop
    schtasks /End /TN MiksuuHC 2>$null
    schtasks /End /TN MiksuuHC2 2>$null
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue
    Start-Sleep 8
    Write-Output "Stop chain done."
}

# --- Restore cfg from the pre-deploy backup, now that nothing holds it open. [IO.File] static
#     method throughout - bracket-wildcard safe for names like '[61-2hc]...'. ---
if ($PSCmdlet.ShouldProcess($CfgPath, "Restore from $CfgBackup")) {
    [IO.File]::Copy($CfgBackup, $CfgPath, $true)
    Write-Output "Restored cfg from $CfgBackup"
}

# --- Count-verify the swap back succeeded (same drift-protection pattern as deploy.ps1). ---
if ($PSCmdlet.ShouldProcess($CfgPath, "Verify restore")) {
    $verifyRaw       = [IO.File]::ReadAllText($CfgPath)
    $restoredCount   = ([regex]::Matches($verifyRaw, [regex]::Escape($RestoreTemplate))).Count
    $stresstestCount = ([regex]::Matches($verifyRaw, [regex]::Escape($StresstestTemplate))).Count
    Write-Output "Verify: restored template '$RestoreTemplate' count=$restoredCount ; stresstest template count=$stresstestCount"
    if ($restoredCount -lt 1 -or $stresstestCount -ne 0) {
        throw "ROLLBACK DRIFT DETECTED (restored=$restoredCount stresstest=$stresstestCount) - cfg may be in a bad state, check $CfgPath against $CfgBackup"
    }
    Write-Output "Rollback template verified clean."
}

# --- Archive the broken RPT before restart so the post-boot probe only sees fresh lines. ---
if ($PSCmdlet.ShouldProcess($RptPath, "Archive broken RPT")) {
    if (-not (Test-Path -LiteralPath $RptArchive)) { New-Item -ItemType Directory -Path $RptArchive -Force | Out-Null }
    if (Test-Path -LiteralPath $RptPath) {
        $archiveName = Join-Path $RptArchive "arma2oaserver-stresstest-broken-$stamp.RPT"
        Move-Item -LiteralPath $RptPath -Destination $archiveName -Force
        Write-Output "Archived broken RPT to $archiveName"
    } else {
        Write-Output "No RPT present to archive."
    }
}

# --- Bring-up via the canonical box script. ---
if ($PSCmdlet.ShouldProcess($ServiceRestartScript, "Bring-up")) {
    Write-Output "Calling $ServiceRestartScript for bring-up..."
    & $ServiceRestartScript
    Write-Output "$ServiceRestartScript returned."
}

# --- RPT probe: same expanded failure-signature list as deploy.ps1. ---
if ($PSCmdlet.ShouldProcess($RptPath, "Probe post-rollback RPT")) {
    Start-Sleep $ProbeWaitSeconds
    if (Test-Path -LiteralPath $RptPath) {
        $probe   = Get-Content -LiteralPath $RptPath -TotalCount 300
        $failSig = $probe | Select-String -Pattern 'Invalid number|_camp_range|Cannot load mission|Cannot load|Unknown|Include file|ErrorMessage:|not found'
        $okSig   = $probe | Select-String -Pattern 'MISSINIT|WASPRELEASE'
        Write-Output "--- RPT PROBE: failure-signature hits ---"
        $failSig | ForEach-Object { Write-Output $_.Line }
        Write-Output "--- RPT PROBE: success-signature hits ---"
        $okSig | ForEach-Object { Write-Output $_.Line }
        if ($failSig -and -not $okSig) {
            Write-Warning "Failure signatures present with NO success signature after rollback - escalate, do not assume healthy."
        }
    } else {
        Write-Warning "RPT not found $ProbeWaitSeconds s after bring-up."
    }

    $procs = Get-Process -Name arma2oaserver, ArmA2OA -ErrorAction SilentlyContinue
    Write-Output "--- Final process count: $($procs.Count)/3 ---"
    $procs | ForEach-Object { Write-Output "$($_.ProcessName) PID=$($_.Id) Start=$($_.StartTime)" }
    if ($procs.Count -lt 3) {
        Write-Warning "$($procs.Count)/3 processes up after rollback - escalate."
    }
}

Write-Output "=== ROLLBACK DONE ==="
