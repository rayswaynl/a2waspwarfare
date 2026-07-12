<#
.SYNOPSIS
    Soak-window heartbeat poller — Game-PC-resident, polls the Hetzner livehost box
    over the existing `ssh livehost` hop every 5-10 minutes during an unattended soak run.

.DESCRIPTION
    Context (LAUNCH-PLAYBOOK-2026-07.md, Section 3 "PRE-FLIGHT B" + Key risk):
    the livehost `Arma2OA-PR8` service is NSSM `AppExit=Exit` with zero `sc qfailure`
    recovery actions (Section 1 gate 9, Section 4 headline) — a crash during an
    unattended AI-vs-AI soak run will NOT self-heal and will NOT surface unless
    something is actively polling. This script is that poll. It does NOT restart,
    redeploy, or otherwise mutate anything on the box — detection and logging only.
    Remediation (`schtasks /Run /TN WaspServiceRestart`) is a SEPARATE, owner-approved
    step per the playbook's Section 4 crash-watcher design; this script deliberately
    does not fire it, so it is safe to stage without any live-server authorization.

    Each poll cycle checks, via `ssh livehost <plain command>` (single hop — this
    script is intended to run FROM the Game PC, which already has a direct
    `ssh livehost` alias; it does not itself nest through gamingpc):

      1. Process presence — `tasklist` filtered locally (not via a remote /FI
         argument, to sidestep the nested-quoting fragility noted in the playbook's
         "Key risks") for `arma2oaserver.exe` (expect 1) and `ArmA2OA.exe` (expect 2,
         the two headless clients — HCs run as the same exe name as the client).
      2. RPT last-write-time — `forfiles` against the server RPT directory,
         printing the file's last-modified timestamp so staleness is computable
         locally (a live match writes to the RPT continuously; a frozen timestamp
         while the process still shows in tasklist is the "hung, not crashed"
         failure mode the playbook's Key Risks section calls out separately from
         a clean process-exit crash).

         ⚠ UNVERIFIED PATH — confirm before relying on this signal: SOAK-PREP recon
         (2026-07-13) could NOT conclusively locate the live `arma2oaserver.RPT`
         path on this box within its time budget. `Tools/Soak/README.md` documents
         `C:\Users\Administrator\Documents\Arma 2 Other Profiles\*\arma2oaserver.RPT`
         (server) and `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT`
         (HC) for this same box, but recon found neither populated as expected —
         `AppData\Local\ArmA 2 OA` (8.3: `ARMA2~1`) contains only a stale `arma2.RPT`
         + crash-dump pair from 2026-07-04, and `profiles-pr8\Users\PR8Server` (both
         the `C:\WASP\` copy and the one next to the installed exe) holds only a
         `.ArmA2OAProfile` stub, no `.RPT`. -RemoteRptDir below defaults to the
         README's documented server-RPT parent as a best-guess starting point ONLY
         — **run once with -OnceOnly and inspect the log before scheduling**, and
         update -RemoteRptDir (or hardcode the confirmed path) once the owner or a
         follow-up pass locates the actual live RPT. The process-presence check
         (signal 1 above) does NOT depend on this and was directly verified live
         during recon (`tasklist` over `ssh gamingpc "ssh livehost tasklist"` showed
         exactly 1 `arma2oaserver.exe` + 2 `ArmA2OA.exe` on 2026-07-13).

    On EITHER signal going bad (process count wrong, or RPT stale past
    -StaleMinutes), this script only LOGS a HEARTBEAT-ALERT line — it does not page,
    DM, or take any remediating action. Wiring that up (e.g. to the existing Peach+
    DM sender, `POST http://localhost:5001/api/peach/admin/dm`) is a follow-on,
    owner-approved step once this script is reviewed and installed; see
    "INSTALL INSTRUCTIONS" below for exactly how to wire it in without editing this
    file's core polling logic.

    Nested-SSH note (playbook Key Risks: "retry-once-then-alert, don't treat one
    failed poll as a crash"): a single failed SSH round-trip (kex/banner flake) is
    logged as HEARTBEAT-SSHFAIL and retried once immediately; only a SECOND
    consecutive failure in the same cycle escalates to HEARTBEAT-ALERT. This avoids
    a transient SSH hiccup being misread as a dead server.

.PARAMETER LogPath
    Where to append heartbeat log lines. Default: alongside this script, in a
    `logs\` subfolder, one file per UTC day (`soak-heartbeat-YYYYMMDD.log`) so a
    multi-day soak (e.g. the 4-6h RC soaks) never needs manual log rotation mid-run.

.PARAMETER StaleMinutes
    How old the RPT's last-write-time may get before it counts as "stalled" (default
    10 — twice the shortest recommended poll interval, so a single slow write burst
    under heavy AI load doesn't false-positive).

.PARAMETER ExpectedHcCount
    Expected count of `ArmA2OA.exe` processes (the two headless clients). Default 2,
    matching every soak lane in Section 3 (2-HC Chernarus). Override to 0 only if
    knowingly polling a non-HC test mission.

.PARAMETER RemoteRptDir
    Remote directory (on livehost) to scan for the newest `*.RPT` file. **NOT
    CONFIRMED — see the RPT last-write-time note above.** Defaults to the path
    `Tools/Soak/README.md` documents for the server RPT on this same box
    (`C:\Users\Administrator\Documents\Arma 2 Other Profiles`, one level above the
    per-profile subfolder `forfiles /S` will search into) — confirm or override
    before trusting the staleness signal.

.PARAMETER OnceOnly
    Run a single poll cycle and exit (for manual smoke-testing before scheduling).
    Without this switch the script loops forever at -IntervalMinutes cadence — it is
    meant to be launched under Task Scheduler as a long-running action, OR called
    repeatedly by Task Scheduler itself at a 5-10 min trigger interval (see install
    instructions — either pattern works; this script supports both).

.PARAMETER IntervalMinutes
    Poll cadence when NOT using -OnceOnly (default 5, per the playbook's "5-10min"
    ask). If Task Scheduler itself provides the recurrence (recommended — see
    install instructions), pass -OnceOnly instead and let the trigger own the cadence.

.NOTES
    STAGED, NOT INSTALLED. This file is not wired into Task Scheduler and does not
    run automatically. Per SOAK-PREP task constraints, installing/scheduling it is
    an owner action — see INSTALL INSTRUCTIONS below, and the companion
    SOAK-HEARTBEAT-INSTALL.md in this same folder.

    Read-only against the live box: every remote command below is a plain
    `tasklist` / `forfiles` read. Nothing here writes to, restarts, or redeploys
    the livehost box.
#>

[CmdletBinding()]
param(
    [string]$LogPath = (Join-Path $PSScriptRoot "logs\soak-heartbeat-$(Get-Date -Format 'yyyyMMdd').log"),
    [int]$StaleMinutes = 10,
    [int]$ExpectedHcCount = 2,
    [string]$RemoteRptDir = 'C:\Users\Administrator\Documents\Arma 2 Other Profiles',
    [switch]$OnceOnly,
    [int]$IntervalMinutes = 5
)

$ErrorActionPreference = "Stop"

# NOT CONFIRMED (see .PARAMETER RemoteRptDir and the docstring note above) — this
# is the README-documented path, not a path SOAK-PREP recon directly verified as
# populated on this box. Confirm before trusting the staleness signal; the
# process-presence check does not depend on this and IS verified.

function Write-HeartbeatLog {
    param([string]$Line)
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -LiteralPath $LogPath -Value "[$stamp] $Line"
}

function Invoke-LivehostCheck {
    <#
        Single poll cycle. Returns a hashtable:
          @{ Ok = $true/$false; Detail = "..."; SshFailed = $true/$false }
        Never throws — all failures are captured and reported so the caller's
        loop keeps running unattended for hours.
    #>

    # --- 1. Process presence -------------------------------------------------
    # Plain command, no /FI filter argument (nested-quoting fragility noted
    # live during SOAK-PREP recon) — list everything, filter locally instead.
    $tasklistRaw = $null
    try {
        $tasklistRaw = & ssh livehost "tasklist" 2>&1
    } catch {
        return @{ Ok = $false; SshFailed = $true; Detail = "ssh tasklist threw: $($_.Exception.Message)" }
    }
    if ($LASTEXITCODE -ne 0 -or -not $tasklistRaw) {
        return @{ Ok = $false; SshFailed = $true; Detail = "ssh tasklist non-zero exit or empty output (exit=$LASTEXITCODE)" }
    }

    $serverCount = ($tasklistRaw | Select-String -SimpleMatch "arma2oaserver.exe").Count
    $hcCount     = ($tasklistRaw | Select-String -SimpleMatch "ArmA2OA.exe").Count

    # --- 2. RPT last-write-time ------------------------------------------------
    # `forfiles` prints the file's last-modified date/time for the newest .RPT
    # in the profile dir; plain command, no pipes across the hop.
    $rptRaw = $null
    try {
        $rptRaw = & ssh livehost "forfiles /S /P `"$RemoteRptDir`" /M *.RPT /C `"cmd /c echo @fdate @ftime @fname`"" 2>&1
    } catch {
        return @{ Ok = $false; SshFailed = $true; Detail = "ssh forfiles threw: $($_.Exception.Message)" }
    }
    if ($LASTEXITCODE -ne 0 -or -not $rptRaw) {
        return @{ Ok = $false; SshFailed = $true; Detail = "ssh forfiles non-zero exit or empty output (exit=$LASTEXITCODE)" }
    }

    # forfiles emits one line per matching file; take the most recent by parsing
    # every line and keeping the max datetime (there can be more than one .RPT
    # — server + any stray archived ones — so don't just take the first line).
    $newestRptTime = $null
    $newestRptName = $null
    foreach ($line in $rptRaw) {
        if ($line -match '^(?<date>\d{2}/\d{2}/\d{4})\s+(?<time>\d{1,2}:\d{2}:\d{2})\s+(?<name>.+)$') {
            try {
                $dt = [datetime]::ParseExact("$($Matches.date) $($Matches.time)", "MM/dd/yyyy H:mm:ss", $null)
                if (-not $newestRptTime -or $dt -gt $newestRptTime) {
                    $newestRptTime = $dt
                    $newestRptName = $Matches.name
                }
            } catch { }
        }
    }

    $problems = @()
    if ($serverCount -ne 1) {
        $problems += "arma2oaserver.exe count=$serverCount (expected 1)"
    }
    if ($hcCount -ne $ExpectedHcCount) {
        $problems += "ArmA2OA.exe (HC) count=$hcCount (expected $ExpectedHcCount)"
    }
    if (-not $newestRptTime) {
        $problems += "could not parse an RPT timestamp from forfiles output"
    } else {
        $ageMin = ((Get-Date) - $newestRptTime).TotalMinutes
        if ($ageMin -gt $StaleMinutes) {
            $problems += "RPT '$newestRptName' last write $([math]::Round($ageMin,1))min ago (> -StaleMinutes $StaleMinutes) — possible hang, not crash"
        }
    }

    if ($problems.Count -gt 0) {
        return @{ Ok = $false; SshFailed = $false; Detail = ($problems -join "; ") }
    }
    $rptAgeStr = if ($newestRptTime) { "$([math]::Round(((Get-Date) - $newestRptTime).TotalMinutes,1))min" } else { "n/a" }
    return @{ Ok = $true; SshFailed = $false; Detail = "server=1 hc=$hcCount rpt='$newestRptName' age=$rptAgeStr" }
}

function Invoke-OneCycle {
    $result = Invoke-LivehostCheck
    if ($result.Ok) {
        Write-HeartbeatLog "HEARTBEAT-OK $($result.Detail)"
        return
    }

    if ($result.SshFailed) {
        Write-HeartbeatLog "HEARTBEAT-SSHFAIL $($result.Detail) — retrying once"
        Start-Sleep -Seconds 10
        $retry = Invoke-LivehostCheck
        if ($retry.Ok) {
            Write-HeartbeatLog "HEARTBEAT-OK (after retry) $($retry.Detail)"
            return
        }
        Write-HeartbeatLog "HEARTBEAT-ALERT SSH failed twice in a row — $($retry.Detail)"
        return
    }

    # Non-SSH failure (process/RPT signal itself is bad) — this is the real
    # "soak may have died" signal, no retry needed since the SSH round-trip
    # itself succeeded and returned a concrete bad reading.
    Write-HeartbeatLog "HEARTBEAT-ALERT $($result.Detail)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($OnceOnly) {
    Invoke-OneCycle
    exit 0
}

Write-HeartbeatLog "HEARTBEAT-START polling every $IntervalMinutes min (Ctrl+C to stop)"
while ($true) {
    Invoke-OneCycle
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
