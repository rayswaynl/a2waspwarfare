<#
.SYNOPSIS
    WASP Live Server Deploy Script — v2
    Replaces deploy47.ps1 (and earlier build-tagged variants).

.DESCRIPTION
    Fixes the three recurring live incidents of 2026-07-06 by eliminating all fixed
    Start-Sleep guesses and the racy kill/relaunch HC dance.

    RACES FIXED:
      RACE-1  — Start-Sleep 40 before HC1 replaced by RPT-readiness + UDP-2302 poll.
      RACE-2  — HC1/HC2 identified by command-line match (-name=HC-AI-Control-N),
                NOT by process birth-time sort.  Kill/relaunch dance removed entirely.
      RACE-3  — DismissACR re-armed in a tight HC-seat-wait loop so it stays alive
                longer than the 100 s close_acr.ps1 window.
      RACE-5  — cfg template rewrite scoped to the FIRST Missions stanza only;
                secondary stanzas left untouched.
      RACE-7  — deploy.lock acquired at start / released in finally; WaspSeatHeal
                and rotate2/match_end_rotate cannot run concurrently.
      RACE-8  — same lockfile covers direct manual calls and rotate2 (rotate2 must
                also be updated to honour C:\WASP\deploy.lock).

.PARAMETER BuildTag
    The build identifier embedded in PBO filenames, e.g. "cc48".
    Defaults to "cc47" for backwards compatibility with existing incoming files.

.PARAMETER ActiveMap
    Override the active-map auto-detect.  One of: ch, tk, zg.
    Leave empty to auto-detect from the cfg's first template stanza.

.EXAMPLE
    # Deploy build 89 cc48, Chernarus active:
    powershell -NoProfile -File C:\WASP\deploy-v2.ps1 -BuildTag cc48 -ActiveMap ch
#>
param(
    [string]$BuildTag  = 'cc47',
    [string]$ActiveMap = ''
)

$ErrorActionPreference = 'Stop'

# ── Constants ────────────────────────────────────────────────────────────────
$LOG        = 'C:\WASP\rotate2.log'
$LOCK       = 'C:\WASP\deploy.lock'
$CFG        = 'C:\WASP\profiles-pr8\server-pr8.cfg'
$RPT        = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$MP         = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
$PARK_CH    = 'C:\WASP\mission-park\ch'
$PARK_TK    = 'C:\WASP\mission-park\tk'
$PARK_ZG    = 'C:\WASP\mission-park\zg'
$RETIRED    = 'C:\WASP\retired'
$RPT_ARCH   = 'C:\WASP\rpt-archive'
$ACR_PBO    = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\ACR\Addons\tracked_acr.pbo'
$ACR_PATCH  = 'C:\WASP\incoming\tracked_acr_patched.pbo'
$ASR_CFG    = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\userconfig\asr_ai\asr_ai_settings.hpp'
$SVC        = 'Arma2OA-PR8'
$GAME_PORT  = 2302

# Build-parameterised PBO names
$NEW_CH     = "[55-2hc]warfarev2_073v48co_${BuildTag}.chernarus.pbo"
$NEW_TK     = "[61-2hc]warfarev2_073v48co_${BuildTag}.takistan.pbo"
$NEW_ZG     = "[61-2hc]warfarev2_073v48co_${BuildTag}.zargabad.pbo"
$INC_CH     = "C:\WASP\incoming\${BuildTag}-ch.pbo"
$INC_TK     = "C:\WASP\incoming\${BuildTag}-tk.pbo"
$INC_ZG     = "C:\WASP\incoming\${BuildTag}-zg.pbo"

# Timeouts (seconds)
$PROCESS_RELEASE_TIMEOUT  = 90   # wait for server process + port to clear after Stop-Service
$SERVER_READY_TIMEOUT     = 120  # wait for server RPT readiness marker after Start-Service
$HC_SEAT_TIMEOUT          = 120  # per-HC: wait for HCSIDE reseat-to-CIV confirmation in RPT

# ── Helpers ──────────────────────────────────────────────────────────────────
function L([string]$m) {
    try { Add-Content -LiteralPath $LOG -Value ("[{0}] DEPLOY-V2 {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch {}
}

function End-Task([string]$n) { schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task([string]$n) { schtasks /Run /TN $n | Out-Null }

# Find an HC process by its -name= command-line argument (reliable; NOT birth-time sort).
function Get-HcProcess([string]$hcName) {
    Get-CimInstance Win32_Process -Filter "Name='ArmA2OA.exe'" -EA SilentlyContinue |
        Where-Object { $_.CommandLine -match [regex]::Escape($hcName) } |
        ForEach-Object { Get-Process -Id $_.ProcessId -EA SilentlyContinue } |
        Select-Object -First 1
}

# Kill an HC by reliable name match (not birth-time).  Idempotent.
function Kill-Hc([string]$hcName) {
    $p = Get-HcProcess $hcName
    if ($p) {
        try { Stop-Process -Id $p.Id -Force -EA Stop; L "killed HC $hcName (pid=$($p.Id))" }
        catch { L "kill HC $hcName note: $($_.Exception.Message)" }
    }
}

# Poll until the server's arma2oaserver process is gone AND UDP 2302 is not in use.
# Returns $true when clear, $false on timeout.
function Wait-ProcessAndPortClear([int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        $srvProc = @(Get-Process arma2oaserver -EA SilentlyContinue).Count
        $portInUse = $false
        try {
            $netstat = netstat -ano | Select-String ":$GAME_PORT\s"
            if ($netstat) { $portInUse = $true }
        } catch {}
        if ($srvProc -eq 0 -and -not $portInUse) { return $true }
        Start-Sleep 3
    }
    return $false
}

# Poll RPT for a readiness marker (server logs "Game Port" when UDP 2302 is bound).
# Also accepts MISSINIT as a fallback ready signal.
# Returns $true when found, $false on timeout.
function Wait-ServerReady([int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $lastLine = 0
    # Arm DismissACR immediately so it catches any blocking dialog during load.
    Run-Task 'DismissACR'
    while ((Get-Date) -lt $deadline) {
        # Re-arm DismissACR every ~40 s so it stays alive through the full boot window.
        $elapsed = ($deadline - (Get-Date)).TotalSeconds
        if ($elapsed % 40 -lt 4) { Run-Task 'DismissACR' }

        if ([IO.File]::Exists($RPT)) {
            $lines = @(Get-Content -LiteralPath $RPT -EA SilentlyContinue)
            # "Game Port" line: engine has opened UDP 2302.  Best readiness signal.
            $gp = $lines | Select-String 'Game Port' | Select-Object -Last 1
            if ($gp) { L "server ready: Game Port marker at line $($gp.LineNumber)"; return $true }
            # Fallback: MISSINIT already appeared (fast machine / warm cache).
            $mi = $lines | Select-String 'MISSINIT' | Select-Object -Last 1
            if ($mi) { L "server ready: MISSINIT marker at line $($mi.LineNumber)"; return $true }
        }

        # Also accept service Running + RPT growing as a secondary signal.
        try {
            $svc = Get-Service $SVC -EA Stop
            if ($svc.Status -eq 'Running' -and [IO.File]::Exists($RPT)) {
                $age = ((Get-Date) - (Get-Item $RPT -EA SilentlyContinue).LastWriteTime).TotalSeconds
                if ($age -lt 10) { L "server ready: service Running + RPT growing (age=${age}s)"; return $true }
            }
        } catch {}

        Start-Sleep 4
    }
    return $false
}

# Poll RPT for the HC-seat signal: HCSIDE line showing sideNow=CIV for the named HC.
# Returns $true when seated, $false on timeout.  Re-arms DismissACR every 35 s.
function Wait-HcSeated([string]$hcName, [int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $safeTag  = [regex]::Escape($hcName)
    $rearmAt  = (Get-Date).AddSeconds(35)
    while ((Get-Date) -lt $deadline) {
        if ((Get-Date) -ge $rearmAt) { Run-Task 'DismissACR'; $rearmAt = (Get-Date).AddSeconds(35) }
        if ([IO.File]::Exists($RPT)) {
            $lines  = @(Get-Content -LiteralPath $RPT -EA SilentlyContinue)
            # Match: HCSIDE|...|HC-AI-Control-N|...|sideNow=CIV
            $seated = $lines | Select-String "HCSIDE\|.*${safeTag}.*sideNow=CIV" | Select-Object -Last 1
            if ($seated) { L "HC $hcName seated (CIV): $($seated.Line.Substring(0, [Math]::Min(120,$seated.Line.Length)))"; return $true }
            # Fallback: HCSTAT line with CIV (older RPT format)
            $hcstat = $lines | Select-String "HCSTAT\|.*${safeTag}.*CIV" | Select-Object -Last 1
            if ($hcstat) { L "HC $hcName HCSTAT-CIV: $($hcstat.Line.Substring(0, [Math]::Min(120,$hcstat.Line.Length)))"; return $true }
            # Last resort: process is alive and at least 75 s have passed (reseat bounded ~80s)
            $hcProc = Get-HcProcess $hcName
            $elapsed = $timeoutSec - ($deadline - (Get-Date)).TotalSeconds
            if ($hcProc -and $elapsed -ge 80) { L "HC $hcName process alive after 80s; assuming seated"; return $true }
        }
        Start-Sleep 5
    }
    return $false
}

# Launch an HC via its scheduled task, then wait for it to seat.
# On seat failure: kill by reliable identifier, relaunch ONCE, wait again.
# Returns $true if seated (either attempt), $false if both attempts fail.
function Launch-And-Seat-Hc([string]$taskName, [string]$hcName) {
    L "launching HC $hcName via task $taskName"
    Run-Task $taskName
    $seated = Wait-HcSeated $hcName $HC_SEAT_TIMEOUT
    if ($seated) { return $true }

    L "HC $hcName did NOT seat within ${HC_SEAT_TIMEOUT}s — targeted recovery (kill + relaunch once)"
    End-Task $taskName
    Kill-Hc $hcName
    Start-Sleep 4
    Run-Task $taskName
    $seated2 = Wait-HcSeated $hcName ($HC_SEAT_TIMEOUT + 30)
    if ($seated2) {
        L "HC $hcName seated on recovery attempt"
        return $true
    }
    L "HC $hcName FAILED to seat after recovery — manual intervention required"
    return $false
}

# ── Lockfile ─────────────────────────────────────────────────────────────────
if ([IO.File]::Exists($LOCK)) {
    $lockAge = ((Get-Date) - (Get-Item $LOCK).LastWriteTime).TotalMinutes
    if ($lockAge -lt 30) {
        Write-Output "DEPLOY_V2_ABORT_LOCKED (age=${lockAge}min, lock=$LOCK)"
        L "ABORT: deploy.lock held (age=${lockAge}min)"
        exit 1
    }
    L "stale lock (age=${lockAge}min) removed"
}
[IO.File]::WriteAllText($LOCK, "deploy-v2 PID=$PID started=$(Get-Date -Format 'o')")

try {
    # ── Directory setup ───────────────────────────────────────────────────────
    foreach ($d in @($PARK_CH, $PARK_TK, $PARK_ZG, $RETIRED, $RPT_ARCH)) {
        if (-not [IO.Directory]::Exists($d)) { [IO.Directory]::CreateDirectory($d) | Out-Null }
    }

    # ── Incoming file guard ───────────────────────────────────────────────────
    foreach ($p in @($INC_CH, $INC_TK, $INC_ZG)) {
        if (-not [IO.File]::Exists($p)) { Write-Output "DEPLOY_V2_ABORT_NOINCOMING $p"; exit 1 }
        $sz = [IO.File]::ReadAllBytes($p).Length
        if ($sz -lt 5000000) { Write-Output "DEPLOY_V2_ABORT_SMALL $p got=$sz"; exit 1 }
    }

    # ── Active-map detection (RACE-5: first-stanza only) ─────────────────────
    $raw = [IO.File]::ReadAllText($CFG)
    $active = ''
    if ($ActiveMap -ne '') {
        $active = $ActiveMap.ToLower()
        L "active-map override: $active"
    } else {
        $mm = [regex]::Match($raw, 'class\s+Missions\s*\{(.+?)\}\s*;?', 'Singleline,IgnoreCase')
        if ($mm.Success) {
            $tm = [regex]::Match($mm.Groups[1].Value, 'template\s*=\s*"[^"]*\.(chernarus|takistan|zargabad)"', 'IgnoreCase')
            if ($tm.Success) {
                $active = switch ($tm.Groups[1].Value.ToLower()) {
                    'chernarus' { 'ch' }
                    'takistan'  { 'tk' }
                    'zargabad'  { 'zg' }
                }
            }
        }
        if (-not $active) { $active = 'ch'; L "active-map: cfg gave no signal, defaulting to ch" }
        else { L "active-map: detected from cfg first-stanza: $active" }
    }

    L "BUILD $BuildTag deploy START (activeMap=$active)"

    # ── Stop chain: tasks first, then service, then stray procs ──────────────
    End-Task 'WaspSeatHeal'
    End-Task 'MiksuuHC'
    End-Task 'MiksuuHC2'
    try { Stop-Service $SVC -Force -EA Stop; L 'service stop issued' }
    catch { L "stop note: $($_.Exception.Message)" }
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -EA SilentlyContinue

    # ── RACE-1 fix: poll for process + port release before patching files ─────
    L 'waiting for process+port release...'
    $cleared = Wait-ProcessAndPortClear $PROCESS_RELEASE_TIMEOUT
    if ($cleared) { L "process+port cleared" }
    else          { L "WARNING: process/port not fully cleared after ${PROCESS_RELEASE_TIMEOUT}s — proceeding anyway" }

    # ── ACR tracked_acr patch (file unlocked now) ─────────────────────────────
    if ([IO.File]::Exists($ACR_PATCH)) {
        Copy-Item $ACR_PATCH $ACR_PBO -Force
        $shimPaths = @(
            'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\ACR\Addons\wasp_acr_shim.pbo',
            'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\ACR\Addons\tracked_acr.PBO.bi.bisign',
            'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\ACR\Addons\tracked_acr.PBO.bi2.bisign'
        )
        Remove-Item $shimPaths -Force -EA SilentlyContinue
        L 'ACR tracked_acr patched-in (T72 dep fix) + shim/bisigns removed'
    }

    # ── ASR AI surrender off ──────────────────────────────────────────────────
    try {
        $t = [IO.File]::ReadAllText($ASR_CFG)
        if ($t -match 'auto_srrs\s*=\s*1') {
            Copy-Item $ASR_CFG "$ASR_CFG.bak-presurrender" -Force
            $t = $t -replace 'auto_srrs\s*=\s*1\s*;', 'auto_srrs = 0;   // deploy-v2: AI surrender OFF'
            [IO.File]::WriteAllText($ASR_CFG, $t)
            L 'asr_ai auto_srrs -> 0'
        } else { L 'asr_ai auto_srrs already 0' }
    } catch { L "asr_ai note: $($_.Exception.Message)" }

    # ── Retire old PBOs ───────────────────────────────────────────────────────
    Get-ChildItem $MP -Filter '*warfarev2*.pbo' -EA SilentlyContinue | ForEach-Object {
        $d = Join-Path $RETIRED $_.Name
        if ([IO.File]::Exists($d)) { Remove-Item -LiteralPath $d -Force }
        [IO.File]::Move($_.FullName, $d); L "retired MP $($_.Name)"
    }
    foreach ($pk in @($PARK_CH, $PARK_TK, $PARK_ZG)) {
        Get-ChildItem $pk -Filter '*.pbo' -EA SilentlyContinue | ForEach-Object {
            $d = Join-Path $RETIRED $_.Name
            if ([IO.File]::Exists($d)) { Remove-Item -LiteralPath $d -Force }
            [IO.File]::Move($_.FullName, $d); L "retired park $($_.Name)"
        }
    }

    # ── Place new PBOs ────────────────────────────────────────────────────────
    $activeT = ''
    switch ($active) {
        'ch' {
            [IO.File]::Copy($INC_CH, (Join-Path $MP $NEW_CH), $true); L "placed CH -> MP (ACTIVE)"
            [IO.File]::Copy($INC_TK, (Join-Path $PARK_TK $NEW_TK), $true)
            [IO.File]::Copy($INC_ZG, (Join-Path $PARK_ZG $NEW_ZG), $true); L "parked TK + ZG"
            $activeT = $NEW_CH -replace '\.pbo$', ''
        }
        'tk' {
            [IO.File]::Copy($INC_TK, (Join-Path $MP $NEW_TK), $true); L "placed TK -> MP (ACTIVE)"
            [IO.File]::Copy($INC_CH, (Join-Path $PARK_CH $NEW_CH), $true)
            [IO.File]::Copy($INC_ZG, (Join-Path $PARK_ZG $NEW_ZG), $true); L "parked CH + ZG"
            $activeT = $NEW_TK -replace '\.pbo$', ''
        }
        'zg' {
            [IO.File]::Copy($INC_ZG, (Join-Path $MP $NEW_ZG), $true); L "placed ZG -> MP (ACTIVE)"
            [IO.File]::Copy($INC_CH, (Join-Path $PARK_CH $NEW_CH), $true)
            [IO.File]::Copy($INC_TK, (Join-Path $PARK_TK $NEW_TK), $true); L "parked CH + TK"
            $activeT = $NEW_ZG -replace '\.pbo$', ''
        }
    }

    # ── RACE-5 fix: cfg rewrite scoped to first Missions stanza only ──────────
    # Strategy: locate the Missions { ... } block, rewrite only the FIRST template= line
    # inside it to point to $activeT.  Secondary stanzas are untouched.
    try {
        $missMatch = [regex]::Match($raw, '(class\s+Missions\s*\{)(.*?)(\}\s*;?)', 'Singleline,IgnoreCase')
        if ($missMatch.Success) {
            $prefix   = $missMatch.Groups[1].Value
            $body     = $missMatch.Groups[2].Value
            $suffix   = $missMatch.Groups[3].Value
            # Rewrite only the FIRST template= occurrence within the block
            $replaced = $false
            $newBody  = [regex]::Replace($body,
                'template\s*=\s*"[^"]*"',
                {
                    param($m)
                    if (-not $replaced) {
                        $script:replaced = $true
                        'template = "' + $activeT + '"'
                    } else { $m.Value }
                })
            $raw = $raw.Replace($missMatch.Value, $prefix + $newBody + $suffix)
            [IO.File]::WriteAllText($CFG, $raw)
            L "cfg first-stanza template -> $activeT (secondary stanzas unchanged)"
        } else {
            L "WARNING: could not locate class Missions block in cfg — skipping template rewrite"
        }
    } catch { L "cfg rewrite note: $($_.Exception.Message)" }

    # ── RPT archive ───────────────────────────────────────────────────────────
    if ([IO.File]::Exists($RPT)) {
        try {
            [IO.File]::Copy($RPT, 'C:\WASP\rpt-lastmatch.RPT', $true)
            [IO.File]::Move($RPT, "$RPT_ARCH\arma2oaserver-deploy-${BuildTag}-$(Get-Date -Format 'yyyyMMdd-HHmm').RPT")
            L "RPT archived"
        } catch { L "RPT archive note: $($_.Exception.Message)" }
    }

    # ── Start service + RACE-1 fix: readiness probe ───────────────────────────
    L 'starting service...'
    Start-Service $SVC
    L 'Start-Service returned; polling for server readiness...'

    $ready = Wait-ServerReady $SERVER_READY_TIMEOUT
    if ($ready) { L "server ready (readiness probe passed)" }
    else         { L "WARNING: server readiness probe timed out after ${SERVER_READY_TIMEOUT}s — HCs launching anyway" }

    # ── HC1: serialized + readiness-gated (RACE-2 fix: no kill/relaunch dance) ─
    # HC1 = MiksuuHC, -name=HC-AI-Control-1
    $hc1ok = Launch-And-Seat-Hc 'MiksuuHC' 'HC-AI-Control-1'

    # ── HC2: only after HC1 is confirmed seated ───────────────────────────────
    # HC2 = MiksuuHC2, -name=HC-AI-Control-2
    $hc2ok = Launch-And-Seat-Hc 'MiksuuHC2' 'HC-AI-Control-2'

    # ── Server tuning ─────────────────────────────────────────────────────────
    Start-Sleep 6
    try { & 'C:\WASP\Set-WaspServerTuning.ps1' | Out-Null; L 'tuning applied' }
    catch { L "tuning note: $($_.Exception.Message)" }

    # ── MISSINIT poll ─────────────────────────────────────────────────────────
    $mi = 0
    for ($i = 1; $i -le 8; $i++) {
        $c = @(Get-Content -LiteralPath $RPT -EA SilentlyContinue)
        $mi = @($c | Select-String 'MISSINIT').Count
        if ($mi -gt 0) { L "MISSINIT ok on poll $i"; break }
        Run-Task 'DismissACR'
        Start-Sleep 20
    }

    $procs = @(Get-Process arma2oaserver, ArmA2OA -EA SilentlyContinue).Count
    $tag   = "DEPLOY_V2_DONE BuildTag=$BuildTag active=$active procs=$procs/3 MISSINIT=$mi hc1=$hc1ok hc2=$hc2ok"
    L $tag
    Write-Output $tag

} catch {
    L "DEPLOY_V2_FAILED: $($_.Exception.Message)"
    Write-Output "DEPLOY_V2_FAILED $($_.Exception.Message)"
    throw
} finally {
    # Always release the lock
    try { Remove-Item -LiteralPath $LOCK -Force -EA SilentlyContinue } catch {}
}
