# Soak Heartbeat — install instructions (NOT DONE — owner action required)

**Status: staged, not installed.** `Watch-SoakHeartbeat.ps1` in this same folder has
not been run against a live soak, scheduled, or wired to any alert channel. This
document is the exact procedure to do so, once the owner reviews the script.

Context: `LAUNCH-PLAYBOOK-2026-07.md` §3 PRE-FLIGHT B calls for "a heartbeat poller
(5-10min: `Get-Process arma2oaserver` + RPT last-write-time) for every soak below,
since a mid-soak crash will NOT self-heal (NSSM gap) and won't surface unless
polled." This script is that poller, adapted to poll over the existing
`ssh gamingpc` → `ssh livehost` path rather than a local `Get-Process` (the box is
remote, not local to whichever machine runs the poll).

---

## 1. Where this runs

**Game PC** (`gamingpc`), not the Main PC. The Game PC already holds the
`ssh livehost` alias and is the always-on host per
`~/.claude/memory/services-migrated-to-game-pc.md`. Running it there means the poll
survives the Main PC sleeping/closing, which matters for a multi-hour unattended
soak (FORTIF ~2h, CTL 3-4h, RC 4-6h — see playbook §3.1).

## 2. Copy the script to the Game PC

```powershell
# From Main PC:
scp "C:\Users\Steff\a2waspwarfare\Tools\Soak\staged\Watch-SoakHeartbeat.ps1" `
    gamingpc:C:\Users\Game\wasp-soak-heartbeat\Watch-SoakHeartbeat.ps1
```

(Create `C:\Users\Game\wasp-soak-heartbeat\` first if it doesn't exist —
`ssh gamingpc "mkdir C:\Users\Game\wasp-soak-heartbeat"`.)

## 3. Confirm the RPT path BEFORE trusting the staleness signal

The script ships with `-RemoteRptDir` defaulted to the path
`Tools/Soak/README.md` documents, but SOAK-PREP recon (2026-07-13) could not
confirm it is actually populated on the live box (see the script's own docstring
for the exact dead ends hit). **Do this once, manually, before scheduling:**

```powershell
# On the Game PC (or via ssh gamingpc from Main PC):
ssh livehost forfiles /S /P "C:\Users\Administrator\Documents\Arma 2 Other Profiles" /M *.RPT /C "cmd /c echo @fdate @ftime @path"
```

If that comes back empty or `File Not Found`, locate the real path with:

```powershell
ssh livehost dir C:\Users\Administrator\*.RPT /S /B
```

Update `-RemoteRptDir` (or hardcode the confirmed value in the script) once you
have a real hit. Until then, run with a wide `-StaleMinutes` or accept that the
RPT-staleness half of the check may never go green — the process-presence half
does not depend on this and is safe to trust as-is (directly verified live during
recon).

## 4. Smoke-test once, manually, before scheduling anything

```powershell
cd C:\Users\Game\wasp-soak-heartbeat
powershell -File .\Watch-SoakHeartbeat.ps1 -OnceOnly
type .\logs\soak-heartbeat-<today's-date>.log
```

Confirm you see a `HEARTBEAT-OK` or a `HEARTBEAT-ALERT` line with a sensible
`Detail` message — NOT a `HEARTBEAT-SSHFAIL` (which would mean the `ssh livehost`
call itself is broken on the Game PC, unrelated to this script).

## 5. Install as a Windows Scheduled Task (owner action)

Two valid patterns — pick one:

### Pattern A — Task Scheduler owns the 5-10min recurrence (recommended)

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument '-NoProfile -File "C:\Users\Game\wasp-soak-heartbeat\Watch-SoakHeartbeat.ps1" -OnceOnly'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName "WaspSoakHeartbeat" -Action $action -Trigger $trigger `
    -Description "Soak-window poller: process presence + RPT staleness over ssh livehost. Read-only, no remediation."
```

### Pattern B — one long-running task, script owns its own loop

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument '-NoProfile -File "C:\Users\Game\wasp-soak-heartbeat\Watch-SoakHeartbeat.ps1" -IntervalMinutes 5'
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "WaspSoakHeartbeat" -Action $action -Trigger $trigger `
    -Description "Soak-window poller (self-looping). Read-only, no remediation."
```

Either way: **only enable/start this task for the duration of an actual soak
window** (start it right before `WaspServiceRestart`-deploying a soak build, stop
it after grading with `analyze_soak.py`). Leaving it running 24/7 outside soak
windows is harmless (it's read-only) but adds noise to the log for no reason.

```powershell
# Stop after a soak window ends:
Unregister-ScheduledTask -TaskName "WaspSoakHeartbeat" -Confirm:$false
```

## 6. Optional: wire to an actual alert (separate owner decision)

The script only writes `HEARTBEAT-ALERT` lines to its log file — it does not page
anyone. To get a real-time ping, tail the log with a second small watcher, e.g.:

```powershell
Get-Content "C:\Users\Game\wasp-soak-heartbeat\logs\soak-heartbeat-*.log" -Wait -Tail 5 |
    Where-Object { $_ -match "HEARTBEAT-ALERT" } |
    ForEach-Object {
        # existing Peach+ DM sender pattern (see ~/.claude/memory/peach-plus-dm-send-pattern.md):
        # POST http://localhost:5001/api/peach/admin/dm with the alert line as body
    }
```

This is deliberately left as a documented pattern, not a running piece of
automation — wiring a real DM send is a standing-automation change and should get
its own explicit review, not ride in silently attached to a read-only poller.

## 7. What this does NOT do (by design)

- Does not restart the service, redeploy, or run `WaspServiceRestart`.
- Does not require or assume any live-server write authority.
- Does not modify `server-pr8.cfg`, MPMissions, or any box state.
- Does not send any notification on its own (see §6).

Safe to install and start at any point without additional owner sign-off beyond
"yes, run this poller" — the risk surface is limited to noisy/wrong log lines if
the RPT path (§3) is wrong, not to the live server.
