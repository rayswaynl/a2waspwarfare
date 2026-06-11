# Ops Scripts

Box-side operational scripts for the Hetzner WASP test server (78.46.107.142).
These are fetched directly from the box and committed here for version control.
When editing, copy the updated file back to the box before deploying.

---

## post-deploy-verify.ps1

**Purpose:** Run immediately after any V0.6.x deploy or restart to assert that
the server and both HCs are healthy and that AICOM telemetry is flowing.

### What it checks

| Check | Description |
|-------|-------------|
| **A — PROC** | Waits up to `BootWaitSec` (default 120s) for `arma2oaserver` to appear, then asserts 1 server + 2 HC processes are running. |
| **B — TICK** | Waits up to `TickWaitMin` (default 8 min) for the first AICOMSTAT TICK from both EAST and WEST sides in the server RPT. |
| **C — ERRBLK** | Scans the new RPT region for `Error in expression` lines matching `Server\AI` or `Client\Module`; fails if more than 10 are found. |

### 8-minute TICK-freshness rule

The 8-minute window (`-TickWaitMin 8`) matches the AICOM telemetry interval.
If neither side has TICKed within 8 minutes of the server booting, the AI
commander supervisor loop is presumed dead (crash, desync, or failed init).
This is the same threshold used by `aicom-watch.ps1`.

### RPT-recreation handling

If the RPT file shrinks between polls (Arma recreated it on restart), the
script resets its baseline offset to 0 and scans from the beginning of the
new file.  This prevents false negatives from comparing against a stale
byte offset.

### Usage

```powershell
# Run on the Hetzner box immediately after triggering a restart
powershell -ExecutionPolicy Bypass -File C:\WASP\post-deploy-verify.ps1

# With extended wait times for slow starts
powershell -ExecutionPolicy Bypass -File C:\WASP\post-deploy-verify.ps1 -BootWaitSec 180 -TickWaitMin 10
```

Exits 0 on all-pass, 1 on any failure.

---

## aicom-watch.ps1

**Purpose:** Lightweight one-pass health check run every 5 minutes by the
`AicomWatch` scheduled task.  Appends a single timestamped status line to
`C:\WASP\monitor\monitor.log` and updates `C:\WASP\monitor\state.json` with
current HC RPT sizes for delta tracking.

### What it checks

| Check | Description |
|-------|-------------|
| **PROC** | Asserts exactly 1 `arma2oaserver` + 2 `ArmA2OA` (HC) processes. |
| **TICK** | Checks that the server RPT was written to within the last 8 minutes. Silence beyond 8 min = AI supervisor suspected dead. |
| **ERRBLK** | Scans the last 2000 lines of the server RPT for `Error in expression` lines matching `Server\AI` or `Client\Module`; alerts if more than 20. |
| **HC1 / HC2** | Compares current HC RPT sizes against the previous run (via `state.json`). Unchanged size = HC may be stalled; shrunken = RPT recreated (restart, benign). |

### 8-minute TICK-freshness rule

Same as post-deploy-verify: if the server RPT's `LastWriteTime` is 8 or more
minutes ago, the AICOM loop is presumed stalled and an ALERT is raised.

### RPT-recreation handling

HC RPT size shrinkage between runs is treated as a benign restart event (logged
as INFO, not ALERT).  The script updates `state.json` with the new size so the
next run has a fresh baseline.

### Scheduled task registration

Register `aicom-watch.ps1` on the Hetzner box to run every 5 minutes:

```powershell
# Run on the Hetzner box (as Administrator)
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NonInteractive -ExecutionPolicy Bypass -File C:\WASP\monitor\aicom-watch.ps1"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 4) `
    -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "AicomWatch" -Action $action -Trigger $trigger `
    -Settings $settings -RunLevel Highest -Force
```

The task runs with the highest available privilege so it can read process list
and RPT files in the Administrator profile.

### Log format

```
[2026-06-11 18:05:01] OK    | PROC:OK srv=1 HC=2 | TICK:OK lastElMin=42 rptAge=3min | ERRBLK:OK 0 errors in 2000 lines | HC1: RPT grew +1280 bytes OK | HC2: RPT grew +960 bytes OK
[2026-06-11 18:10:03] ALERT | TICK: server RPT not updated for 9 min - AI supervisor may be dead | INFO: PROC:OK srv=1 HC=2
```

---

## Deployment path on the Hetzner box

| Script | Box path |
|--------|----------|
| `post-deploy-verify.ps1` | `C:\WASP\post-deploy-verify.ps1` |
| `aicom-watch.ps1` | `C:\WASP\monitor\aicom-watch.ps1` |
