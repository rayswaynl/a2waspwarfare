<#
.SYNOPSIS
    Deploy a stresstest PBO to the shared WASP test box (Miksuus-TEST), stop-first.

.DESCRIPTION
    Hardened replacement for the ad-hoc deploy-stresstest-zg.ps1 that ran on 2026-07-08/09.
    Fixes carried over from that incident (see Tools/Stresstest/README.md for the full
    defect list):

      - RPT failure probe EXPANDED to also catch 'Include file' / 'ErrorMessage:' / 'not found'
        (a mission that fails to load because version.sqf is missing prints exactly those
        signatures, and the narrower pattern used on 2026-07-08 let that slip through as a
        false "3/3 up").
      - Preflight requires the staged PBO to exist, be >= 8MB, AND to have been produced by
        Tools/Stresstest/pack_stresstest.py's own render+assert (this script does not re-open
        the PBO; pack_stresstest.py already refuses to write one without version.sqf).
      - Stop-before-edit ordering (this script already stopped first even before tonight's
        incident; rollback.ps1 in this same directory is the one that had the bug and is fixed
        to match this ordering).

    This script only WRITES/PRINTS what it would do when -WhatIf is NOT passed - see the
    "ONE hands-on step" note in README.md: actually stopping/restarting the shared box is an
    intentionally owner-gated action, not something this harness runs unattended.

.PARAMETER StagedPbo
    Path to the PBO already built by pack_stresstest.py.

.PARAMETER TargetPboName
    Filename (with extension) to place the staged PBO under in MPMissions.

.PARAMETER NewTemplate
    The 'template =' value server-pr8.cfg should point at after this deploy (no extension).

.PARAMETER OldTemplate
    The 'template =' value currently live, to be replaced. Must appear in server-pr8.cfg.

.EXAMPLE
    .\deploy.ps1 -StagedPbo C:\WASP\staging\stresstest\zg-stresstest-upload.pbo `
                 -TargetPboName '[61-2hc]warfarev2_073v48co_stresstest.zargabad.pbo' `
                 -NewTemplate '[61-2hc]warfarev2_073v48co_stresstest.zargabad' `
                 -OldTemplate 'ch-dynAB-armB.chernarus'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)] [string]$StagedPbo,
    [Parameter(Mandatory = $true)] [string]$TargetPboName,
    [Parameter(Mandatory = $true)] [string]$NewTemplate,
    [Parameter(Mandatory = $true)] [string]$OldTemplate,
    [string]$MpMissions   = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions',
    [string]$CfgPath      = 'C:\WASP\profiles-pr8\server-pr8.cfg',
    [string]$RptPath      = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT',
    [string]$RptArchive   = 'C:\WASP\rpt-archive',
    [string]$ServiceRestartScript = 'C:\WASP\service-restart.ps1',
    [string]$ServiceName  = 'Arma2OA-PR8',
    [int]$ProbeWaitSeconds = 90
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Output "=== STRESSTEST DEPLOY START $stamp ==="

# --- Preflight ---
if (-not (Test-Path -LiteralPath $StagedPbo)) { throw "Preflight FAILED: staged PBO not found at $StagedPbo" }
$stagedSize = (Get-Item -LiteralPath $StagedPbo).Length
if ($stagedSize -lt 8MB) { throw "Preflight FAILED: staged PBO too small ($stagedSize bytes) - did pack_stresstest.py run to completion?" }
Write-Output "Preflight OK: staged PBO $stagedSize bytes"

$targetPbo = Join-Path $MpMissions $TargetPboName

# --- Backup cfg before any edit ---
$cfgBackup = "$CfgPath.bak-stresstest-$stamp"
if ($PSCmdlet.ShouldProcess($CfgPath, "Backup to $cfgBackup")) {
    Copy-Item -LiteralPath $CfgPath -Destination $cfgBackup
    Write-Output "Backed up cfg to $cfgBackup (needed by rollback.ps1 -CfgBackup)"
}

# --- STOP FIRST, always. The running arma2oaserver holds server-pr8.cfg; editing it before the
#     stop chain is exactly the bug rollback.ps1 had until 2026-07-09 - never reorder this. ---
if ($PSCmdlet.ShouldProcess($ServiceName, "Stop chain")) {
    Write-Output "Stop chain..."
    Stop-Service $ServiceName -Force -ErrorAction Stop
    schtasks /End /TN MiksuuHC 2>$null
    schtasks /End /TN MiksuuHC2 2>$null
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue
    Start-Sleep 8
    Write-Output "Stop chain done."
}

# --- Copy staged PBO into MPMissions. [IO.File]::Copy (not a PS cmdlet) so bracketed mission
#     names like '[61-2hc]...' are never treated as a wildcard glob by PowerShell. ---
if ($PSCmdlet.ShouldProcess($targetPbo, "Copy staged PBO")) {
    [IO.File]::Copy($StagedPbo, $targetPbo, $true)
    Write-Output "Copied PBO to $targetPbo"
}

# --- Template swap with drift-protection verify (count-check both directions; throw on drift). ---
if ($PSCmdlet.ShouldProcess($CfgPath, "Swap template $OldTemplate -> $NewTemplate")) {
    $raw = [IO.File]::ReadAllText($CfgPath)
    $newRaw = $raw.Replace($OldTemplate, $NewTemplate)
    [IO.File]::WriteAllText($CfgPath, $newRaw)
    $verifyRaw = [IO.File]::ReadAllText($CfgPath)
    $newCount = ([regex]::Matches($verifyRaw, [regex]::Escape($NewTemplate))).Count
    $oldCount = ([regex]::Matches($verifyRaw, [regex]::Escape($OldTemplate))).Count
    Write-Output "Template swap verify: new='$NewTemplate' count=$newCount ; old='$OldTemplate' count=$oldCount"
    if ($newCount -lt 1 -or $oldCount -ne 0) {
        throw "Template swap DRIFT DETECTED (new=$newCount old=$oldCount) - cfg may be in a bad state, check $CfgPath against backup $cfgBackup"
    }
    Write-Output "Template swap verified clean."
}

# --- Archive pre-existing RPT so the post-boot probe only sees fresh-load lines. ---
if ($PSCmdlet.ShouldProcess($RptPath, "Archive pre-deploy RPT")) {
    if (-not (Test-Path -LiteralPath $RptArchive)) { New-Item -ItemType Directory -Path $RptArchive -Force | Out-Null }
    if (Test-Path -LiteralPath $RptPath) {
        $archiveName = Join-Path $RptArchive "arma2oaserver-stresstest-pre-$stamp.RPT"
        Move-Item -LiteralPath $RptPath -Destination $archiveName -Force
        Write-Output "Archived pre-deploy RPT to $archiveName"
    } else {
        Write-Output "No pre-existing RPT to archive (fresh state)."
    }
}

# --- Bring-up via the canonical box script (unchanged - already stop-then-start internally). ---
if ($PSCmdlet.ShouldProcess($ServiceRestartScript, "Bring-up")) {
    Write-Output "Calling $ServiceRestartScript for bring-up..."
    & $ServiceRestartScript
    Write-Output "$ServiceRestartScript returned."
}

# --- RPT probe: EXPANDED failure-signature list (the 2026-07-08 defect: the old pattern missed
#     'Include file' / 'ErrorMessage:' / 'not found', which is exactly what a missing
#     version.sqf produces via description.ext's #include "version.sqf"). Longer wait (90s, not
#     the original 30s) so a slow-loading mission doesn't get probed before the RPT catches up. ---
if ($PSCmdlet.ShouldProcess($RptPath, "Probe post-boot RPT")) {
    Start-Sleep $ProbeWaitSeconds
    if (Test-Path -LiteralPath $RptPath) {
        $probe = Get-Content -LiteralPath $RptPath -TotalCount 300
        $failSig = $probe | Select-String -Pattern 'Invalid number|_camp_range|Cannot load mission|Cannot load|Unknown|Include file|ErrorMessage:|not found'
        $okSig   = $probe | Select-String -Pattern 'MISSINIT|WASPRELEASE'
        Write-Output "--- RPT PROBE: failure-signature hits ---"
        $failSig | ForEach-Object { Write-Output $_.Line }
        Write-Output "--- RPT PROBE: success-signature hits ---"
        $okSig | ForEach-Object { Write-Output $_.Line }
        if ($failSig -and -not $okSig) {
            Write-Warning "Failure signatures present with NO success signature - this deploy likely did NOT load. Consider rollback.ps1."
        }
    } else {
        Write-Warning "RPT not found $ProbeWaitSeconds s after bring-up."
    }

    $procs = Get-Process -Name arma2oaserver, ArmA2OA -ErrorAction SilentlyContinue
    Write-Output "--- Final process count: $($procs.Count)/3 ---"
    $procs | ForEach-Object { Write-Output "$($_.ProcessName) PID=$($_.Id) Start=$($_.StartTime)" }
    if ($procs.Count -lt 3) {
        Write-Warning "$($procs.Count)/3 processes up - check the RPT probe output above before declaring this deploy healthy."
    }
}

Write-Output "=== STRESSTEST DEPLOY DONE ==="
Write-Output "cfg backup for rollback.ps1: $cfgBackup"
