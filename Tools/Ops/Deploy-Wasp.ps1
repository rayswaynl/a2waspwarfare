#requires -Version 5.1
<#
.SYNOPSIS
    ONE reusable, idempotent WASP live-server deploy pipeline. Replaces the ~150
    single-use throwaway scripts (`_freshname_pbo_deploy_b59.ps1` ... `deploy47.ps1`,
    `rc11-deploy` ... `rc31zg`, `_box_deploy_b746` ...) with a single reviewed tool.

.DESCRIPTION
    OPERATOR TOOL. This script is run BY THE OWNER on a machine that has the repo (for the
    build/pack phases) and/or access to the live MPMissions dir + server cfg (for the
    deploy phases). Agents never run it against the live box (repo policy,
    docs/AGENT-HANDBOOK.md "Box and deploy policy").

    It composes the EXISTING helpers instead of re-copying their logic:
      - cfg repoint        -> Tools/Ops/Set-MissionTemplate.ps1  (NOT reimplemented)
      - service restart    -> the existing `WaspServiceRestart` scheduled task
                              (-> C:\WASP\service-restart.ps1)   (NOT reimplemented)
      - build / mirror     -> Tools/LoadoutManager (dotnet run -c RELEASE)
                              Chernarus is source of truth; Takistan/Zargabad are GENERATED.

    FULL CHAIN (task wasp-deploy-pipeline-v1-20260716):
      1. Build/mirror  - regenerate TK/ZG mirrors from CH via LoadoutManager, restore templates.
      2. Pack          - pack each mission folder to a build-tagged .pbo (external tool, see -PboTool).
      3. Stage + copy  - archive the current live PBO, then place the new PBO in MPMissions.
      4. Repoint cfg   - Set-MissionTemplate.ps1 -Apply (idempotent; the 2026-06-23 guard fix lives there).
      5. Restart       - trigger the WaspServiceRestart scheduled task (the only stop/start).
      6. Verify        - service Running, both HCs present, RPT shows the expected WASPSCALE build= line.
      7. Rollback      - keep the last N live PBOs; -Rollback restores the newest known-good.

    SAFE BY DEFAULT. Without -Apply the script performs a full DRY RUN: it validates
    everything, prints the exact plan, and writes NOTHING to the live box. Local build/pack
    into the staging dir also honours -Apply (they are skipped in a pure dry run unless
    -RunBuild/-RunPack force them) so a review dry-run is completely side-effect free.

    2026-06-23 INCIDENT — protection preserved (validate before stopping):
      A hand-copied cfg-repoint guard `throw`ed on a no-op AFTER the service was already
      stopped, stranding the server DOWN. Guard here: step 4 first does a DRY-RUN repoint
      while the server is still UP (verify-before-stop) and aborts untouched if the template
      line isn't found. Only once that dry-run proves the real repoint will succeed do we
      stop the chain and write the cfg — so a no-op/missing-line can never strand a stopped
      server. Restore-on-failure via -Rollback covers a bad-but-valid deploy.

    2026-07-17 LIVE-DEPLOY FIXES (this stacked PR):
      BUG 1 (cfg lock): the running arma2oaserver holds an EXCLUSIVE lock on the server cfg,
      so Set-MissionTemplate -Apply (WriteAllText) threw "being used by another process" when
      it ran while UP. The REAL repoint now happens with the chain STOPPED (dry-run stays
      up-front as verify-before-stop). Sequence: dry-run-while-up -> place PBO -> STOP service
      + end HCs -> real repoint (cfg now unlocked) -> WaspServiceRestart -> verify.
      BUG 2 (verify token): the live WASPSCALE `build=` surfaces the engine `missionName`,
      which DROPS the terrain suffix; the pipeline's mission-name strings keep `.chernarus`.
      Get-ExpectedBuildToken now strips a trailing `.chernarus/.takistan/.zargabad` so verify
      compares against the token the server actually emits.
      BUG 3 (stuck/overlapping restart): a single on-disk lock blocks overlapping deploy runs;
      Invoke-WaspServiceRestart ends a still-Running task instance and kills orphan procs
      before triggering, then guards for the service to come Running and surfaces the
      ACR/desktop-session dependency instead of silently looping.
      BUG 4 (verify timeout): phase 6 polled for only 240s, but the box's WASPSCALE `build=`
      line first surfaces ~5-6 min after the restart task fires (restart ~4-5 min + mission
      load). A healthy deploy therefore verified as FAILED (svc=True proc=True build=False) and
      auto-rolled back - and the rollback's own verify then timed out the same way, leaving the
      restore UNCONFIRMED. Verify now polls -VerifyTimeoutSec (default 480) on BOTH the deploy
      and rollback checks. Auto-rollback is unchanged: it still fires on a real failure, just no
      longer on a slow-but-good one.

.PARAMETER Build
    Build tag embedded in the deployed PBO filename, e.g. 'cmdcon48aicom' or 'b86'.
    Produces  [55-2hc]warfarev2_073v48co_<Build>.chernarus.pbo  (and tk/zg equivalents).
    NOTE: the live WASPSCALE `build=` field parses a `cmdcon<...>` token out of the mission
    name; a tag WITHOUT `cmdcon` makes build= fall back to the full mission name. Either
    verifies fine (see -ExpectBuild), but `cmdcon`-style tags read cleaner in telemetry.

.PARAMETER ActiveMap
    Which map is live in MPMissions. One of: ch, tk, zg. Default: ch.

.PARAMETER RepoRoot
    Repo root that holds Missions/ + Missions_Vanilla/ + Tools/LoadoutManager. Defaults to
    the repo this script lives in (two levels up from Tools/Ops).

.PARAMETER MissionsDir
    Live MPMissions directory on the box. Default matches the live box layout.

.PARAMETER CfgPath
    Server cfg containing the active `template = "...";` line. Default matches the live box.

.PARAMETER StageRoot
    Local scratch dir where mission folders are tagged + packed. Default: <RepoRoot>\.deploy-stage.

.PARAMETER ArchiveRoot
    Where the last-known-good PBOs are archived for rollback. Default: <MissionsDir>\..\wasp-pbo-archive.

.PARAMETER KeepArchives
    How many previous PBOs to retain per map for rollback. Default: 5.

.PARAMETER PboTool
    OPTIONAL override packer. By default this pipeline packs with the repo's own recovered
    pure-Python writer Tools/Pack/pack_pbo.py (PR #1085 - this pipeline stacks on it); that is
    the tool the owner's build scripts actually used, and it needs no binary dependency. Pass
    -PboTool <path> only to use a Mikero-style native packer (MakePbo.exe / pboProject.exe,
    positional `MakePbo <folder> <out>`) instead. See docs/ops/DEPLOY-PIPELINE.md.

.PARAMETER RestartTask
    Name of the existing scheduled task that stops+starts the whole chain. Default: WaspServiceRestart.

.PARAMETER ServiceName
    Windows service name for the dedicated server (verify step). Default: Arma2OA-PR8.

.PARAMETER RptPath
    Server RPT for the verify step. Default matches the live box.

.PARAMETER ExpectBuild
    Substring the deployed WASPSCALE `build=` field must contain for verify to pass.
    Default: the -Build tag (or the map-name token it reduces to).

.PARAMETER VerifyTimeoutSec
    How long phase 6 polls for the expected WASPSCALE `build=` line before declaring the deploy
    failed (and auto-rolling back). Default: 480. The live box needs ~5-6 min after the restart
    task fires before the line surfaces (restart ~4-5 min + mission load), so the previous 240s
    ceiling false-failed healthy deploys - see the 2026-07-17 note below. Also bounds the
    post-rollback verify. Raise it on a slower box; do NOT lower it below the observed
    restart+load time or a good deploy will roll itself back.

.PARAMETER TemplatePattern
    Regex passed through to Set-MissionTemplate for WHICH template line to repoint. Defaults
    to the per-map WASP family pattern for -ActiveMap.

.PARAMETER RunBuild
    Force the build/mirror phase even in a dry run (writes only to the repo working tree +
    staging). Omit to skip it in dry runs.

.PARAMETER RunPack
    Force the pack phase even in a dry run (writes only to StageRoot). Omit to skip in dry runs.

.PARAMETER SkipBuild
    Skip the LoadoutManager build/mirror phase (PBOs will be packed from the tree as-is).

.PARAMETER SkipPack
    Skip packing; deploy an already-built PBO. Requires -PboPath.

.PARAMETER PboPath
    Path to a pre-built active-map PBO to deploy (used with -SkipPack).

.PARAMETER Rollback
    Restore the newest archived PBO for -ActiveMap instead of deploying a new build.

.PARAMETER Apply
    Perform the LIVE-box mutations (copy PBO into MPMissions, repoint cfg, trigger restart).
    Without it the whole live phase is a dry run.

.PARAMETER NoAutoRollback
    Disable the automatic restore-on-failure step (by default, if verify fails after the
    restart, the pipeline repoints back to the archived known-good and restarts once).

.EXAMPLE
    # Review dry-run (writes nothing live): validate the whole plan for build cmdcon48aicom.
    .\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch

.EXAMPLE
    # Owner, on the box: full deploy.
    .\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch -Apply

.EXAMPLE
    # Emergency rollback to the previous known-good Chernarus PBO.
    .\Deploy-Wasp.ps1 -ActiveMap ch -Rollback -Apply

.OUTPUTS
    [pscustomobject] summary + a final `WASP_DEPLOY_*` token line for log/cron greps.

.NOTES
    PowerShell 5.1-compatible (the box runs PS 5.1). Reuses Set-MissionTemplate.ps1 for the
    cfg step, so the ISO-8859-1 byte-preserving cfg round-trip and the correct 3-way guard
    (no-match=throw, no-op=success, differ=rewrite) are inherited, not re-copied.
#>
[CmdletBinding()]
param(
    [string]$Build,
    [ValidateSet('ch','tk','zg')][string]$ActiveMap = 'ch',
    [string]$RepoRoot,
    [string]$MissionsDir = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions',
    [string]$CfgPath     = 'C:\WASP\profiles-pr8\server-pr8.cfg',
    [string]$StageRoot,
    [string]$ArchiveRoot,
    [int]$KeepArchives   = 5,
    [string]$PboTool,
    [string]$RestartTask = 'WaspServiceRestart',
    [string]$ServiceName = 'Arma2OA-PR8',
    [int]$RestartGuardSec = 180,
    [int]$LockStaleMinutes = 30,
    [string]$RptPath     = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT',
    [string]$ExpectBuild,
    [int]$VerifyTimeoutSec = 480,
    [string]$TemplatePattern,
    [switch]$RunBuild,
    [switch]$RunPack,
    [switch]$SkipBuild,
    [switch]$SkipPack,
    [string]$PboPath,
    [switch]$Rollback,
    [switch]$Apply,
    [switch]$NoAutoRollback,
    [switch]$LoadFunctionsOnly   # testing hook: define functions, then return before the deploy body
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# ── Static map facts ─────────────────────────────────────────────────────────
# folder = mission source dir (relative to RepoRoot); prefix = PBO name prefix;
# ext = the terrain suffix that trails the build tag; pat = the Set-MissionTemplate
# family pattern that isolates THIS map's template line.
$script:MAPS = @{
    ch = @{
        Folder = 'Missions\[55-2hc]warfarev2_073v48co.chernarus'
        Prefix = '[55-2hc]warfarev2_073v48co'
        Ext    = 'chernarus'
        Pat    = '(?m)(?<=^[ \t]*)template\s*=\s*"\[55-2hc\][^"]*chernarus[^"]*"\s*;'
    }
    tk = @{
        Folder = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan'
        Prefix = '[61-2hc]warfarev2_073v48co'
        Ext    = 'takistan'
        Pat    = '(?m)(?<=^[ \t]*)template\s*=\s*"\[61-2hc\][^"]*takistan[^"]*"\s*;'
    }
    zg = @{
        Folder = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad'
        Prefix = '[61-2hc]warfarev2_073v48co'
        Ext    = 'zargabad'
        Pat    = '(?m)(?<=^[ \t]*)template\s*=\s*"\[61-2hc\][^"]*zargabad[^"]*"\s*;'
    }
}
$script:MIN_PBO_BYTES = 3000000   # a real WASP mission PBO is multi-MB; smaller = truncated/failed pack

# ── Logging ──────────────────────────────────────────────────────────────────
function Write-Step([string]$m) { Write-Host "[Deploy-Wasp] $m" }
function Write-DryNote([string]$m) { Write-Host "[Deploy-Wasp][DRY-RUN] $m" -ForegroundColor DarkYellow }

# Verify a live deploy: service Running, full 3-process chain (server + 2 HC), and the RPT's
# current-match WASPSCALE line carries the expected build token. Bounded poll; read-only.
# Returns $true only when all three hold. Windows RPT after the last MISSINIT boundary so a
# stale previous-match line can't produce a false pass.
# BUG 4 (2026-07-17): the default was 240s, but the box surfaces the WASPSCALE build= line only
# ~5-6 min after the restart fires - so this returned $false on a HEALTHY deploy and the caller
# auto-rolled it back. svc/proc go true within ~4-5 min; build= is the laggard. Callers pass
# -VerifyTimeoutSec; the default here matches it so an unparameterised call can't regress.
function Test-WaspLive {
    param(
        [string]$ServiceName,
        [string]$RptPath,
        [string]$ExpectBuild,
        [int]$TimeoutSec = 480
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $svcOk = $false; $procOk = $false; $buildOk = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
            $svcOk = ($svc -and $svc.Status -eq 'Running')
        } catch { $svcOk = $false }

        $srv = @(Get-Process arma2oaserver -ErrorAction SilentlyContinue).Count
        $hc  = @(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count
        $procOk = ($srv -ge 1 -and $hc -ge 2)   # dedicated server + both HCs

        if ($svcOk -and (Test-Path -LiteralPath $RptPath)) {
            $lines = @(Get-Content -LiteralPath $RptPath -ErrorAction SilentlyContinue)
            $mi = ($lines | Select-String 'MISSINIT' | Select-Object -Last 1)
            $start = if ($mi) { $mi.LineNumber - 1 } else { 0 }
            if ($start -lt $lines.Count) {
                $window = $lines[$start..($lines.Count - 1)]
                $ws = $window | Select-String 'WASPSCALE\|v2\|' | Select-Object -Last 1
                if ($ws) {
                    if ([string]::IsNullOrEmpty($ExpectBuild)) {
                        $buildOk = $true
                    } else {
                        $bm = [regex]::Match($ws.Line, 'build=([^|]*)')
                        $buildOk = ($bm.Success -and $bm.Groups[1].Value -like ('*{0}*' -f $ExpectBuild))
                    }
                }
            }
        }

        if ($svcOk -and $procOk -and $buildOk) {
            Write-Step "verify: service Running, procs server=$srv hc=$hc, WASPSCALE build~='$ExpectBuild' OK"
            return $true
        }
        Start-Sleep 6
    }
    Write-Step "verify TIMEOUT after ${TimeoutSec}s (svc=$svcOk proc=$procOk build=$buildOk)"
    return $false
}

# Build the tagged mission-name (no extension .pbo) for a map + build tag.
function Get-MissionName([hashtable]$map, [string]$build) {
    # e.g. [55-2hc]warfarev2_073v48co_cmdcon48aicom.chernarus
    return ('{0}_{1}.{2}' -f $map.Prefix, $build, $map.Ext)
}
function Get-PboName([hashtable]$map, [string]$build) { return (Get-MissionName $map $build) + '.pbo' }

# Reduce a build tag OR full mission name to the WASPSCALE build= token it will surface as:
# the `cmdcon<...>` slice if present (matching AI_Commander.sqf's parser), else the whole
# thing. BUG 2 (2026-07-17): the live emitter's fallback is the engine `missionName`, which
# DROPS the terrain suffix (`missionName` never contains `.chernarus`). Our mission-name
# strings carry that suffix (they come from the PBO filename), so strip it FIRST - otherwise
# a non-cmdcon build verifies against '...chernarus' which the server never emits and every
# healthy deploy false-fails into a rollback (exactly what happened on the 2026-07-17 deploy).
function Get-ExpectedBuildToken([string]$build) {
    $build = $build -replace '\.(chernarus|takistan|zargabad)$',''
    $i = $build.IndexOf('cmdcon')
    if ($i -lt 0) { return $build }
    $rest = $build.Substring($i)
    $cut  = $rest.IndexOfAny([char[]]@('_','.'))
    if ($cut -ge 0) { $rest = $rest.Substring(0, $cut) }
    return $rest
}

# Locate a PBO packer. Returns a path or $null.
function Find-PboTool([string]$explicit) {
    if ($explicit) {
        if (Test-Path -LiteralPath $explicit) { return (Resolve-Path -LiteralPath $explicit).Path }
        throw "PboTool '$explicit' not found."
    }
    $candidates = @(
        'C:\Program Files (x86)\Mikero\Tools\bin\MakePbo.exe',
        'C:\Program Files\Mikero\Tools\bin\MakePbo.exe',
        'C:\Program Files (x86)\Mikero\Tools\bin\pboProject.exe',
        'C:\Program Files\Mikero\Tools\bin\pboProject.exe'
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    foreach ($n in @('MakePbo.exe','pboProject.exe','MakePbo','pboProject')) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

# Archive-rotation helper (pure): given the archive filenames for a map (newest last is
# NOT assumed — they carry a sortable yyyyMMdd-HHmmss prefix), return the set to DELETE so
# only $keep newest remain. Exposed for tests.
function Get-ArchivesToPrune([string[]]$names, [int]$keep) {
    if ($keep -lt 0) { $keep = 0 }
    $sorted = @($names | Sort-Object)          # timestamp prefix -> lexicographic == chronological
    $excess = $sorted.Count - $keep
    if ($excess -le 0) { return @() }
    return @($sorted[0..($excess - 1)])
}

# Pure lock-staleness decision (exposed for tests): a deploy lock older than $staleMinutes may
# be taken over; a fresher one means another deploy is genuinely in progress. BUG 3 helper.
function Test-DeployLockIsStale([datetime]$writtenAt, [datetime]$now, [int]$staleMinutes) {
    return ((($now - $writtenAt).TotalMinutes) -ge $staleMinutes)
}

# Stop the dedicated-server service and end both HCs so the server cfg is UNLOCKED for rewrite.
# BUG 1 (2026-07-17): arma2oaserver holds an exclusive lock on the cfg while running, so
# Set-MissionTemplate -Apply (WriteAllText) throws "being used by another process". The real
# cfg repoint must therefore run with the chain stopped. Callers reach here ONLY after the
# verify-before-stop dry-run proved the repoint will succeed (2026-06-23 protection preserved).
function Stop-WaspChain {
    param([string]$ServiceName, [int]$TimeoutSec = 60)
    Write-Step "stop: stopping service '$ServiceName' + ending HCs (unlock cfg for repoint)"
    try {
        $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') { Stop-Service $ServiceName -Force -ErrorAction Stop }
    } catch { Write-Step "stop: Stop-Service '$ServiceName' failed ($($_.Exception.Message)); killing procs directly" }
    # HCs are separate ArmA2OA client procs (not the service); kill them + any lingering server.
    foreach ($pn in @('arma2oaserver','ArmA2OA')) {
        @(Get-Process $pn -ErrorAction SilentlyContinue) | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    # Wait for the server proc to actually exit so the OS releases the cfg file handle.
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ((@(Get-Process arma2oaserver -ErrorAction SilentlyContinue).Count) -eq 0) { break }
        Start-Sleep 2
    }
    Start-Sleep 2   # small grace for the handle to be released after PID exit
}

# Safely (re)start the whole WASP chain via the EXISTING WaspServiceRestart scheduled task.
# BUG 3 (2026-07-17): rapid repeated deploys stacked restarts; one task instance got stuck
# (state=Running) and the box went DOWN with orphan procs. Before triggering: END the task if
# it is already Running (a stuck instance never self-clears), then kill any orphan server/HC
# procs so the fresh start isn't blocked by a half-dead chain. After triggering, poll for the
# service to come Running; if it stays Stopped past the guard window, surface the likely
# ACR-popup / desktop-session dependency and return $false instead of silently looping.
function Invoke-WaspServiceRestart {
    param([string]$RestartTask, [string]$ServiceName, [int]$GuardSec = 180)
    $taskState = $null
    try {
        $q = schtasks /Query /TN $RestartTask /FO LIST /V 2>$null
        $m = ($q | Select-String '^\s*Status:\s*(.+?)\s*$' | Select-Object -First 1)
        if ($m) { $taskState = $m.Matches[0].Groups[1].Value.Trim() }
    } catch { $taskState = $null }
    if ($taskState -eq 'Running') {
        Write-Step "restart: task '$RestartTask' already Running - ending stuck instance first"
        schtasks /End /TN $RestartTask 2>$null | Out-Null
        Start-Sleep 2
    }
    foreach ($pn in @('arma2oaserver','ArmA2OA')) {
        $orphans = @(Get-Process $pn -ErrorAction SilentlyContinue)
        if ($orphans.Count -gt 0) {
            Write-Step "restart: killing $($orphans.Count) orphan '$pn' proc(s) before restart"
            $orphans | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep 1
    Write-Step "restart: trigger scheduled task '$RestartTask'"
    schtasks /Run /TN $RestartTask | Out-Null
    $deadline = (Get-Date).AddSeconds($GuardSec)
    while ((Get-Date) -lt $deadline) {
        $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') { Write-Step "restart: service '$ServiceName' Running"; return $true }
        Start-Sleep 5
    }
    Write-Step "restart GUARD: service '$ServiceName' still NOT Running after ${GuardSec}s"
    Write-Warning ("WaspServiceRestart did not bring '{0}' up within {1}s. On this box the restart chain depends on an interactive desktop session (ACR / launcher popup); if no one is logged in at the console the service can stay Stopped. Check the console session and re-run the restart MANUALLY - this tool is not auto-looping." -f $ServiceName, $GuardSec)
    return $false
}

if ($LoadFunctionsOnly) { return }   # tests dot-source to here and exercise the pure helpers

# ── Resolve paths ────────────────────────────────────────────────────────────
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not $StageRoot)   { $StageRoot   = Join-Path $RepoRoot '.deploy-stage' }
if (-not $ArchiveRoot) { $ArchiveRoot = Join-Path (Split-Path -Parent $MissionsDir) 'wasp-pbo-archive' }

$map = $script:MAPS[$ActiveMap]
if (-not $TemplatePattern) { $TemplatePattern = $map.Pat }

$setTemplate = Join-Path $PSScriptRoot 'Set-MissionTemplate.ps1'
if (-not (Test-Path -LiteralPath $setTemplate)) {
    throw "Set-MissionTemplate.ps1 not found next to this script ($setTemplate) - cannot compose the cfg repoint step."
}

$mode = if ($Apply) { 'APPLY' } else { 'DRY-RUN' }
Write-Step "mode=$mode map=$ActiveMap build=$Build rollback=$([bool]$Rollback) repo=$RepoRoot"

# ══════════════════════════════════════════════════════════════════════════════
#  ROLLBACK MODE — restore newest archived PBO for the active map
# ══════════════════════════════════════════════════════════════════════════════
if ($Rollback) {
    $mapArchive = Join-Path $ArchiveRoot $ActiveMap
    if (-not (Test-Path -LiteralPath $mapArchive)) {
        Write-Output "WASP_DEPLOY_ROLLBACK_ABORT no archive dir: $mapArchive"
        return
    }
    $archived = @(Get-ChildItem -LiteralPath $mapArchive -Filter '*.pbo' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($archived.Count -eq 0) {
        Write-Output "WASP_DEPLOY_ROLLBACK_ABORT no archived PBO in $mapArchive"
        return
    }
    $newest = $archived[-1]
    # Archive names are '<timestamp>__<original.pbo>' - recover the deployable name.
    $restoreName = $newest.Name -replace '^\d{8}-\d{6}__',''
    $restoreMissionName = $restoreName -replace '\.pbo$',''
    Write-Step "rollback target: $($newest.Name) -> deploy as $restoreName (mission '$restoreMissionName')"

    if (-not $Apply) {
        Write-DryNote "would copy $($newest.FullName) -> $(Join-Path $MissionsDir $restoreName)"
        Write-DryNote "would repoint cfg to '$restoreMissionName' via Set-MissionTemplate -Apply"
        Write-DryNote "would trigger scheduled task '$RestartTask'"
        Write-Output "WASP_DEPLOY_ROLLBACK_DRYRUN target=$restoreName"
        return
    }

    # verify-before-stop: confirm the cfg template line exists BEFORE any mutation (2026-06-23).
    & $setTemplate -CfgPath $CfgPath -MissionName $restoreMissionName -Pattern $TemplatePattern | Out-Null
    Copy-Item -LiteralPath $newest.FullName -Destination (Join-Path $MissionsDir $restoreName) -Force
    # BUG 1: stop the chain so the cfg is unlocked, THEN repoint, THEN safe restart (BUG 3).
    Stop-WaspChain -ServiceName $ServiceName
    & $setTemplate -CfgPath $CfgPath -MissionName $restoreMissionName -Pattern $TemplatePattern -Apply | Out-Null
    $rbUp = Invoke-WaspServiceRestart -RestartTask $RestartTask -ServiceName $ServiceName -GuardSec $RestartGuardSec
    Write-Output ("WASP_DEPLOY_ROLLBACK_DONE restored={0} restart={1}" -f $restoreName, ($(if($rbUp){'OK'}else{'STUCK'})))
    return
}

# ══════════════════════════════════════════════════════════════════════════════
#  DEPLOY MODE
# ══════════════════════════════════════════════════════════════════════════════
if (-not $Build -and -not $SkipPack) {
    throw "-Build is required (unless -SkipPack -PboPath is used)."
}
if (-not $ExpectBuild -and $Build) { $ExpectBuild = Get-ExpectedBuildToken $Build }

$missionName = if ($Build) { Get-MissionName $map $Build } else { '' }
$pboName     = if ($Build) { Get-PboName $map $Build } else { '' }

# ── Phase 1: Build / mirror (local; regenerates TK/ZG from CH) ────────────────
$doBuild = (-not $SkipBuild) -and ($Apply -or $RunBuild)
if ($SkipBuild) {
    Write-Step "phase 1 build/mirror: SKIPPED (-SkipBuild)"
} elseif (-not $doBuild) {
    Write-DryNote "phase 1 build/mirror: would run 'dotnet run -c RELEASE' in Tools\LoadoutManager (pass -RunBuild to run it in a dry run)"
} else {
    $lm = Join-Path $RepoRoot 'Tools\LoadoutManager'
    Write-Step "phase 1 build/mirror: dotnet run -c RELEASE in $lm"
    Push-Location $lm
    try {
        & dotnet run -c RELEASE
        if ($LASTEXITCODE -ne 0) { throw "LoadoutManager build failed (dotnet exit $LASTEXITCODE) - install the .NET SDK or inspect generator output." }
    } finally { Pop-Location }
    # Restore per-map templates that LoadoutManager may drift (CLAUDE.md source rule).
    Write-Step "phase 1 build/mirror: restoring TK/ZG version.sqf.template to merge-base"
    git -C $RepoRoot checkout origin/master -- `
        'Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template' `
        'Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template' 2>$null
}

# ── Phase 2: Pack mission folder -> build-tagged .pbo ─────────────────────────
$stagedPbo = $null
$doPack = (-not $SkipPack) -and ($Apply -or $RunPack)
if ($SkipPack) {
    if (-not $PboPath -or -not (Test-Path -LiteralPath $PboPath)) {
        throw "-SkipPack requires -PboPath pointing at a pre-built active-map PBO."
    }
    $stagedPbo = (Resolve-Path -LiteralPath $PboPath).Path
    # With a pre-built PBO and no -Build, derive the deploy name from the PBO file itself
    # (Arma uses the PBO filename as the mission name).
    if (-not $pboName)     { $pboName     = Split-Path -Leaf $stagedPbo }
    if (-not $missionName) { $missionName = $pboName -replace '\.pbo$','' }
    if (-not $ExpectBuild) { $ExpectBuild = Get-ExpectedBuildToken $missionName }
    Write-Step "phase 2 pack: SKIPPED (-SkipPack); using $stagedPbo -> deploy as $pboName"
} else {
    $srcFolder = Join-Path $RepoRoot $map.Folder
    if (-not (Test-Path -LiteralPath $srcFolder)) { throw "mission source folder not found: $srcFolder" }
    $stagedPbo = Join-Path $StageRoot $pboName
    # Primary packer: the repo's own recovered pure-Python writer Tools/Pack/pack_pbo.py
    # (PR #1085 - this PR stacks on it). It derives the PBO `prefix` from the source folder
    # name + --build-tag, so no build-tagged staging folder is needed. -PboTool overrides with
    # a Mikero-style positional `MakePbo <folder> <out>` binary for operators who prefer it.
    $packPy = Join-Path $RepoRoot 'Tools\Pack\pack_pbo.py'
    $useNative = [bool]$PboTool

    if (-not $doPack) {
        if ($useNative) {
            $probe = Find-PboTool $PboTool
            $toolNote = if ($probe) { "native packer: $probe" } else { "native packer NOT found at -PboTool '$PboTool'" }
        } else {
            $toolNote = if (Test-Path -LiteralPath $packPy) { "packer: Tools\Pack\pack_pbo.py (repo, PR #1085)" } else { "Tools\Pack\pack_pbo.py MISSING (this PR stacks on #1085 - base on it, or pass -PboTool)" }
        }
        Write-DryNote "phase 2 pack: would pack $srcFolder -> $stagedPbo (build-tag '$Build'); $toolNote"
    } else {
        if (-not (Test-Path -LiteralPath $StageRoot)) { New-Item -ItemType Directory -Path $StageRoot -Force | Out-Null }
        if (Test-Path -LiteralPath $stagedPbo) { Remove-Item -LiteralPath $stagedPbo -Force }

        if ($useNative) {
            # Mikero MakePbo-style path: pack a build-tagged staging folder positionally.
            $tool = Find-PboTool $PboTool
            if (-not $tool) { $m = "WASP_DEPLOY_ABORT_NOPBOTOOL -PboTool '$PboTool' not found."; Write-Output $m; throw $m }
            $taggedFolder = Join-Path $StageRoot $missionName
            if (Test-Path -LiteralPath $taggedFolder) { Remove-Item -LiteralPath $taggedFolder -Recurse -Force }
            $rc = Start-Process -FilePath robocopy -ArgumentList @("`"$srcFolder`"", "`"$taggedFolder`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -Wait -PassThru -NoNewWindow
            if ($rc.ExitCode -ge 8) { throw "robocopy stage failed (exit $($rc.ExitCode))" }
            Write-Step "phase 2 pack: native tool=$tool"
            & $tool $taggedFolder $stagedPbo
            if ($LASTEXITCODE -ne 0) { throw "PBO pack failed (tool exit $LASTEXITCODE)" }
        } else {
            if (-not (Test-Path -LiteralPath $packPy)) {
                $m = "WASP_DEPLOY_ABORT_NOPBOTOOL Tools\Pack\pack_pbo.py not found - this pipeline stacks on PR #1085; base your branch on it, or pass -PboTool for a native packer."
                Write-Output $m; throw $m
            }
            Write-Step "phase 2 pack: python $packPy --source ... --output $stagedPbo --build-tag $Build"
            & python $packPy --source $srcFolder --output $stagedPbo --build-tag $Build --force
            if ($LASTEXITCODE -ne 0) { throw "pack_pbo.py failed (exit $LASTEXITCODE)" }
        }

        if (-not (Test-Path -LiteralPath $stagedPbo)) { throw "PBO pack produced no output: $stagedPbo" }
        $sz = (Get-Item -LiteralPath $stagedPbo).Length
        if ($sz -lt $script:MIN_PBO_BYTES) { throw "packed PBO suspiciously small ($sz bytes < $script:MIN_PBO_BYTES) - aborting before deploy" }
        Write-Step "phase 2 pack: OK $stagedPbo ($([math]::Round($sz/1MB,1)) MB)"
    }
}

# ── Phase 3-6: LIVE deploy (gated by -Apply) ─────────────────────────────────
if (-not $Apply) {
    Write-DryNote "phase 3 stage+copy: would archive current live '$($map.Ext)' PBO from $MissionsDir into $ArchiveRoot\$ActiveMap, keep newest $KeepArchives"
    Write-DryNote "phase 3 stage+copy: would place $pboName into $MissionsDir"
    Write-DryNote "phase 4 repoint : would dry-run cfg repoint while UP (verify-before-stop), then STOP service '$ServiceName' + end HCs, then real Set-MissionTemplate -Apply -MissionName '$missionName' (cfg unlocked only when stopped - BUG 1)"
    Write-DryNote "phase 5 restart : would safely (re)start via '$RestartTask' - end stuck task, kill orphan procs, trigger, then guard ${RestartGuardSec}s for '$ServiceName' Running (BUG 3)"
    Write-DryNote "phase 6 verify  : would confirm service '$ServiceName' Running, 3 procs (server+2HC), and RPT 'WASPSCALE|v2|...|build=' contains '$ExpectBuild' - polling up to ${VerifyTimeoutSec}s (box surfaces build= ~5-6min post-restart; BUG 4)"
    Write-Output "WASP_DEPLOY_DRYRUN map=$ActiveMap build=$Build mission=$missionName expectBuild=$ExpectBuild"
    return
}

# --- APPLY path -------------------------------------------------------------
if (-not $stagedPbo -or -not (Test-Path -LiteralPath $stagedPbo)) {
    throw "no staged PBO to deploy (pack phase produced nothing). Aborting before any live mutation."
}

# ── DEPLOY LOCK (BUG 3): block overlapping runs so rapid re-deploys can't stack restarts.
#    A single on-disk lock guards the whole live phase; a fresh concurrent run aborts, a stale
#    one (> -LockStaleMinutes) is taken over. Released in the finally below.
$lockFile = Join-Path ([System.IO.Path]::GetTempPath()) 'deploy-wasp.lock'
$lockAcquired = $false
if (Test-Path -LiteralPath $lockFile) {
    $lockWritten = (Get-Item -LiteralPath $lockFile).LastWriteTime
    if (-not (Test-DeployLockIsStale $lockWritten (Get-Date) $LockStaleMinutes)) {
        $holder = ((Get-Content -LiteralPath $lockFile -ErrorAction SilentlyContinue) -join ' ')
        $ageMin = [int]((Get-Date) - $lockWritten).TotalMinutes
        Write-Output "WASP_DEPLOY_ABORT_LOCKED another deploy is in progress (lock $lockFile age ${ageMin}m; $holder)"
        throw "deploy lock held by another run ($lockFile) - refusing to overlap."
    }
    Write-Step "APPLY: taking over STALE deploy lock (older than $LockStaleMinutes min)"
}
Set-Content -LiteralPath $lockFile -Value ("pid=$PID started=$(Get-Date -Format o) map=$ActiveMap build=$Build") -Encoding ASCII
$lockAcquired = $true

try {
    $mapArchive = Join-Path $ArchiveRoot $ActiveMap
    if (-not (Test-Path -LiteralPath $mapArchive)) { New-Item -ItemType Directory -Path $mapArchive -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $MissionsDir)) { throw "MissionsDir not found: $MissionsDir" }

    # Snapshot current live active-map PBO(s) BEFORE touching anything (rollback point).
    $liveOld = @(Get-ChildItem -LiteralPath $MissionsDir -Filter ("*.{0}.pbo" -f $map.Ext) -ErrorAction SilentlyContinue)
    $stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
    $prevMissionName = $null

    # ── VERIFY-BEFORE-STOP (2026-06-23 guard): confirm the cfg template line exists NOW,
    #    while the server is still running. If it doesn't, abort before any file/service change.
    #    This dry-run proves the REAL repoint (done stopped, phase 4) will succeed - so stopping
    #    the chain to unlock the cfg can never strand a stopped server on a no-op/missing line.
    Write-Step "verify-before-stop: dry-run cfg repoint (must find the template line)"
    $dry = & $setTemplate -CfgPath $CfgPath -MissionName $missionName -Pattern $TemplatePattern
    if ($dry.Matches -lt 1) { throw "cfg template line not found (pattern /$TemplatePattern/) - aborting; server untouched." }
    $prevRaw = [System.IO.File]::ReadAllText($CfgPath, [System.Text.Encoding]::GetEncoding(28591))
    $prevM = [regex]::Match($prevRaw, $TemplatePattern)
    if ($prevM.Success) {
        $pm2 = [regex]::Match($prevM.Value, 'template\s*=\s*"([^"]*)"')
        if ($pm2.Success) { $prevMissionName = $pm2.Groups[1].Value }
    }

    # ── Phase 3: archive current live PBO, then place new PBO ─────────────────────
    foreach ($old in $liveOld) {
        $dest = Join-Path $mapArchive ("{0}__{1}" -f $stamp, $old.Name)
        Copy-Item -LiteralPath $old.FullName -Destination $dest -Force
        Write-Step "phase 3: archived live $($old.Name) -> $dest"
    }
    # Prune archive to newest $KeepArchives.
    $toPrune = Get-ArchivesToPrune (@(Get-ChildItem -LiteralPath $mapArchive -Filter '*.pbo' | Select-Object -ExpandProperty Name)) $KeepArchives
    foreach ($p in $toPrune) { Remove-Item -LiteralPath (Join-Path $mapArchive $p) -Force; Write-Step "phase 3: pruned old archive $p" }

    $livePbo = Join-Path $MissionsDir $pboName
    Copy-Item -LiteralPath $stagedPbo -Destination $livePbo -Force
    Write-Step "phase 3: placed $pboName in MPMissions"

    # ── Phase 4: STOP chain, THEN repoint cfg (BUG 1: cfg is lock-free only when server is down) ──
    Stop-WaspChain -ServiceName $ServiceName
    Write-Step "phase 4: repoint cfg -> '$missionName' (Set-MissionTemplate -Apply; server stopped)"
    try {
        & $setTemplate -CfgPath $CfgPath -MissionName $missionName -Pattern $TemplatePattern -Apply | Out-Null
    } catch {
        # Repoint failed with the chain stopped: the cfg still points at the previous mission
        # (byte-preserving writer throws before writing), the old PBO is still present, so revert
        # the new PBO and restart back onto the previous mission - never leave the box DOWN.
        Write-Step "phase 4 FAILED: $($_.Exception.Message) - reverting PBO, restarting on previous mission '$prevMissionName'"
        Remove-Item -LiteralPath $livePbo -Force -ErrorAction SilentlyContinue
        Invoke-WaspServiceRestart -RestartTask $RestartTask -ServiceName $ServiceName -GuardSec $RestartGuardSec | Out-Null
        Write-Output "WASP_DEPLOY_ABORT_CFG repoint failed; reverted PBO, restarted on previous mission '$prevMissionName'; $($_.Exception.Message)"
        throw
    }

    # ── Phase 5: (re)start via the existing WaspServiceRestart task (BUG 3: safe restart) ─────
    Write-Step "phase 5: (re)start the chain"
    $restartUp = Invoke-WaspServiceRestart -RestartTask $RestartTask -ServiceName $ServiceName -GuardSec $RestartGuardSec
    if (-not $restartUp) {
        Write-Output "WASP_DEPLOY_RESTART_STUCK map=$ActiveMap build=$Build - service '$ServiceName' did not come Running within ${RestartGuardSec}s (see ACR/desktop-session warning above); NOT auto-looping."
        throw "restart guard: service did not come up within ${RestartGuardSec}s"
    }

    # ── Phase 6: verify ───────────────────────────────────────────────────────────
    $verifyOk = Test-WaspLive -ServiceName $ServiceName -RptPath $RptPath -ExpectBuild $ExpectBuild -TimeoutSec $VerifyTimeoutSec
    if ($verifyOk) {
        # prune any OTHER active-map PBOs so exactly one remains (park model + match-report dual-PBO guard).
        Get-ChildItem -LiteralPath $MissionsDir -Filter ("*.{0}.pbo" -f $map.Ext) -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $pboName } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; Write-Step "phase 6: removed stale live PBO $($_.Name)" }
        Write-Output "WASP_DEPLOY_DONE map=$ActiveMap build=$Build mission=$missionName verify=OK"
        return
    }

    # ── Restore-on-failure ────────────────────────────────────────────────────────
    if ($NoAutoRollback) {
        Write-Output "WASP_DEPLOY_VERIFY_FAILED map=$ActiveMap build=$Build (auto-rollback disabled) - run '-Rollback -Apply' to restore"
        throw "verify failed and -NoAutoRollback set"
    }
    if (-not $prevMissionName) {
        Write-Output "WASP_DEPLOY_VERIFY_FAILED map=$ActiveMap build=$Build - no prior mission name captured; run '-Rollback -Apply' manually"
        throw "verify failed; manual rollback required"
    }
    Write-Step "verify FAILED - auto-rollback to '$prevMissionName'"
    # BUG 1: the failed deploy's restart may have left the server Running (cfg locked); stop first.
    Stop-WaspChain -ServiceName $ServiceName
    & $setTemplate -CfgPath $CfgPath -MissionName $prevMissionName -Pattern $TemplatePattern -Apply | Out-Null
    Remove-Item -LiteralPath $livePbo -Force -ErrorAction SilentlyContinue
    $rbUp = Invoke-WaspServiceRestart -RestartTask $RestartTask -ServiceName $ServiceName -GuardSec $RestartGuardSec
    $rbOk = $false
    if ($rbUp) { $rbOk = Test-WaspLive -ServiceName $ServiceName -RptPath $RptPath -ExpectBuild (Get-ExpectedBuildToken $prevMissionName) -TimeoutSec $VerifyTimeoutSec }
    Write-Output ("WASP_DEPLOY_ROLLED_BACK map={0} failedBuild={1} restored={2} verify={3}" -f $ActiveMap, $Build, $prevMissionName, ($(if($rbOk){'OK'}else{'UNCONFIRMED'})))
}
finally {
    if ($lockAcquired) { Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue }
}
