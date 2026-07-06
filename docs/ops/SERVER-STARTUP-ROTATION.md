# WASP Live Server — Startup & Rotation Runbook

**Host**: `livehost` (78.46.107.142, Hetzner, hostname MIKSUUS-TEST)  
**Access path**: `ssh gamingpc "ssh livehost \"<cmd>\""` (Game PC is the SSH jump; livehost default shell = cmd, wrap PS as `powershell -NoProfile -Command "..."`)  
**Authoritative scripts on box**: `C:\WASP\rotate2.ps1`, `C:\WASP\match_end_rotate_v2.ps1`, `C:\WASP\Set-WaspServerTuning.ps1`  
**Log**: `C:\WASP\rotate2.log` (all operations append here)

---

## 1. Canonical Boot Order

The "chain" is three processes: the dedicated server (`arma2oaserver`) + HC1 (`ArmA2OA` via MiksuuHC task) + HC2 (`ArmA2OA` via MiksuuHC2 task, sandboxed via Sandboxie-Plus). All three must be up for the server to function correctly; the match-end watchdog (`match_end_rotate_v2.ps1`) uses `procs < 3` as a guard and will not rotate until the full chain is alive.

### Step-by-step with timings

| T+0s | **`Start-Service 'Arma2OA-PR8'`** | Starts the arma2oaserver Windows service. The service itself has no readiness check — it just fires the binary. The server takes ~35–40 s to load mission data and open UDP 2302 before it is joinable. |
|---|---|---|
| T+40s | **`Run-Task 'MiksuuHC'`** | Fires `C:\WASP\hc_launch.cmd`. The cmd kills any existing `ArmA2OA.exe` first (`taskkill /f`), then launches HC1 with `-client -connect=127.0.0.1 -port=2302 -name="HC-AI-Control-1"`. HC1 runs on the real Steam session. The 40-second pre-sleep exists because the server must have UDP 2302 open before a client can connect — connect too early and the HC silently fails to join. |
| T+40s | **`Run-Task 'DismissACR'`** (first run) | Fires `C:\WASP\close_acr.ps1`. This script polls for 40 iterations × 2.5 s = ~100 s, using `user32.dll EnumWindows` to find and dismiss: (a) the ACR DLC "Czech Republic Setup" dialog (clicks Cancel/Skip/No, then WM_CLOSE), and (b) BattlEye EULA dialogs (clicks I Agree/Accept/Install). Without this, both the server launch and each HC launch block on an interactive dialog that cannot be dismissed via SSH. Logs actions to `C:\WASP\dismiss.txt`. |
| T+95s | **`Run-Task 'MiksuuHC2'`** | Fires `C:\WASP\hc2_launch.cmd`. HC2 runs inside Sandboxie-Plus box "HC2" with a second (sandboxed) Steam account, bypassing Steam's single-instance mutex so two HC clients can coexist on one machine. The cmd starts sandboxed Steam first (`%SBIE% /box:HC2 steam.exe -silent`), waits 30 s for it to initialize, then launches `ArmA2OA.exe` in the same box with `-name="HC-AI-Control-2"`. The 55-second gap between HC1 and HC2 is to let HC1 fully seat before HC2 starts competing for the server's HC slots. |
| T+95s | **`Run-Task 'DismissACR'`** (second run) | Same dialog-killer, now targeting the HC2 Sandboxie launch which generates its own ACR/BattlEye dialogs. |
| T+95s–T+105s | **HC1 kill-and-relaunch** | After HC1 and HC2 are both running, the script kills HC1 (the oldest ArmA2OA process by start time) and relaunches it via `Run-Task 'MiksuuHC'` again. **Why**: the initial HC1 often seats on the wrong side (e.g. WEST instead of the AI-managed side). The kill-relaunch forces HC1 to re-negotiate its seat assignment after HC2 is already seated, improving the chance that each HC manages its intended faction. `Run-Task 'DismissACR'` follows again to catch the new ACR dialog. |
| T+150s | **HC2 kill-and-relaunch** | Same pattern: kills all but the latest ArmA2OA process, ends the MiksuuHC2 task, relaunches it. Kills stray HC2 instances from the first attempt before re-running the task. A third `DismissACR` run follows. |
| T+160s–T+165s | **`Set-WaspServerTuning.ps1`** | CPU affinity and priority tuning applied after the full chain is stable: server gets logical cores 0,2 (mask 0x05) at High priority; HC1 gets cores 4,5 (mask 0x30) at AboveNormal; HC2 gets cores 6,7 (mask 0xC0) at AboveNormal. Background processes (Steam, GameOverlayUI, Update-PublicStats.ps1) are pinned to 0xAA (even logical cores, away from the server's hot pair). Windows Defender exclusions for `arma2oaserver.exe`, `ArmA2OA.exe`, the Steam install path, and `C:\WASP` are also set idempotently. The 6-second sleep before calling this script lets the HC processes finish initializing so `Get-Process ArmA2OA` returns both. |
| T+166s | **MISSINIT poll** | The script reads the server RPT at `C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT` and looks for the string `MISSINIT`. MISSINIT is logged by the WASP mission's init code when the server-side mission has fully initialized and the AI commander is active. Its presence confirms the mission is running, not just that the binary is up. In deploy45, this is polled up to 8 times with 20-second sleeps between, re-running `DismissACR` each round. In rotate2, it is checked once at the end and the result is logged but not retried. |
| **Total**: ~160–170 s from service start to MISSINIT | | |

### Scheduled task inventory

| Task | Script | What it does | Last result |
|---|---|---|---|
| `MiksuuHC` | `C:\WASP\hc_launch.cmd` | Kills existing ArmA2OA.exe + launches HC1 (real Steam, -name HC-AI-Control-1) | 267009 (process still running when task checked) |
| `MiksuuHC2` | `C:\WASP\hc2_launch.cmd` | Starts sandboxed Steam in HC2 Sandboxie box (30s wait), then launches HC2 (sandboxed, -name HC-AI-Control-2) | 0 (OK) |
| `DismissACR` | `C:\WASP\close_acr.ps1` | Polls 40×2.5s for ACR setup and BattlEye dialogs, dismisses them via Win32 SendMessage/PostMessage | 0 (OK) |
| `WaspSeatHeal` | `C:\WASP\_box_seatheal_restart.ps1` | Self-correcting restart: up to 4 full stop→relaunch→HC-dance cycles, verifying SNAP\|WEST and SNAP\|EAST both have str>0 and teams>0 before declaring success. Waits 6 minutes per attempt for side logic to seat. | **DISABLED** (last run 2026-06-30, result 267014 = still running) |

`WaspSeatHeal` is currently disabled. It must be triggered manually or re-enabled when HC seating is suspected broken.

---

## 2. Mission Rotation Mechanics

### Park model

Only **one** map PBO is ever present in the active MPMissions directory at a time:

```
C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions\
```

The other two maps rest in their park directories:

```
C:\WASP\mission-park\ch\   — Chernarus PBO when not active
C:\WASP\mission-park\tk\   — Takistan PBO when not active
C:\WASP\mission-park\zg\   — Zargabad PBO when not active
```

The server boots whichever PBO it finds in MPMissions; it does not need any other configuration change. This is why the park model works without a server restart for map selection.

### Three-map cycle

`rotate2.ps1` (v4) cycles: **CH → TK → ZG → CH**

SKIP-IF-NOT-PARKED: if the next map's PBO is absent from its park directory, the script falls through to the map after it. Removing Zargabad from rotation requires only deleting its PBO from `mission-park\zg` — no script edits needed.

### Active-map detection (ambiguity resolver)

1. Count PBOs in MPMissions matching `*warfarev2*.pbo` for each map key.
2. If exactly one PBO is found: that is the active map.
3. If more than one PBO is found (ambiguous state): read `server-pr8.cfg`, extract the **first** `template =` line inside `class Missions { }` using the regex `class\s+Missions\s*\{(.+?)\}` (singleline) then `template\s*=\s*"[^"]*\.(chernarus|takistan|zargabad)"`. The map suffix of the first template is the authoritative active map. Stray PBOs are moved to their park directories. If the cfg gives no usable signal, rotate aborts with `ROTATE2_ABORT_AMBIGUOUS`.
4. If zero PBOs are found: rotate aborts with `ROTATE2_ABORT_AMBIGUOUS`.

### cfg template rewrite

After PBO parking/unparking, `rotate2.ps1` rewrites `server-pr8.cfg` in two passes:

1. **Name normalization**: for each of the three maps, replace all instances matching the pattern (e.g. `\[55-2hc\]warfarev2_073v48co_[A-Za-z0-9]+\.chernarus`) with the current canonical build name. This keeps the cfg consistent with whatever build is deployed.
2. **First-template override**: replace the first `template =` inside `class Missions` with the target map's template name (the one just unparked). This ensures the cfg-authoritative resolver will correctly identify the active map on the next rotation.

Current `server-pr8.cfg` `class Missions` block (three stanzas, all pointing to cmdcon44 build after the last deploy — the `PR8_Takistan` and `PR8_Chernarus` secondary stanzas are preserved but their template values are irrelevant; only the first stanza's `template` is read):

```
class Missions {
    class Experital_Chernarus { template = "[55-2hc]warfarev2_073v48co_cmdcon44uaicom.chernarus"; difficulty = "Veteran"; };
    class PR8_Chernarus       { template = "[55-2hc]warfarev2_073v48co_cmdcon44uaicom.chernarus"; difficulty = "Veteran"; };
    class PR8_Takistan        { template = "[55-2hc]warfarev2_073v48co_cmdcon44uaicom.chernarus"; difficulty = "Veteran"; };
};
```

Note: `PR8_Takistan` currently has a chernarus template — this is a stale artefact from the deploy. The server ignores all stanzas after the first.

### PBO naming pattern

| Map | Active-map PBO name (cmdcon45 example) | Park key |
|---|---|---|
| Chernarus | `[55-2hc]warfarev2_073v48co_cmdcon45.chernarus.pbo` | `ch` |
| Takistan | `[61-2hc]warfarev2_073v48co_cmdcon45.takistan.pbo` | `tk` |
| Zargabad | `[61-2hc]warfarev2_073v48co_cmdcon45.zargabad.pbo` | `zg` |

The slot count prefix (`55` vs `61`) differs between maps and is baked into the filename.

### RPT archival on rotation

Before restarting the chain, `rotate2.ps1`:
1. Copies the current RPT to `C:\WASP\rpt-lastmatch.RPT` (overwrite) — permanent "last match" snapshot.
2. Moves the RPT to `C:\WASP\rpt-archive\arma2oaserver-rot-<key>-<yyyyMMdd-HHmm>.RPT`.

The RPT path is `C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT`. After the service restarts, ArmA2OA writes a fresh RPT to the same path.

### Match-end watchdog (`match_end_rotate_v2.ps1`)

This script runs on a schedule (not shown in schtasks output — likely a repeating scheduled task or called from a loop) and calls `rotate2.ps1` automatically when a round ends.

Guards (all must pass before rotate triggers):
1. **Lock file**: `C:\WASP\match_end_rotate.lock` — prevents concurrent rotate calls. Stale locks older than 15 minutes are removed.
2. **Chain completeness**: `Get-Process arma2oaserver,ArmA2OA | Count >= 3` — will not rotate a degraded chain.
3. **ROUNDEND line freshness (the 2026-07-03 flap fix)**: compares the line number of the last `ROUNDEND|` or `ROUNDSTAT|v1|` RPT entry against the line number of the last `MISSINIT` entry. If the ROUNDEND is *before* the MISSINIT, it is a pre-boot stale marker from the previous match — it syncs the state file and exits without rotating. This prevents a false rotation immediately after a deploy or manual restart.
4. **State deduplication**: `C:\WASP\last_rotate_roundend.txt` stores the last ROUNDEND line that triggered a rotate. If the current last ROUNDEND equals the stored line, no action.

### Deploy sequence (deploy45.ps1 — canonical pattern)

A full build deploy follows the same relaunch dance as rotate but adds:
1. **Incoming file verification**: checks that all three `.pbo` files exist in `C:\WASP\incoming\` and are each >5 MB.
2. **Active-map lock**: reads the cfg's first template to determine which map is currently active, then overrides with a hardcoded `$active` value for the release (e.g. `$active='ch'` for build 89).
3. **Retire old PBOs**: moves all `*warfarev2*.pbo` from MPMissions and all three park directories to `C:\WASP\retired\`.
4. **ACR tracked_acr patch**: while files are unlocked, byte-patches `tracked_acr.pbo` (T72 dependency fix) if the patched version is in `incoming\`.
5. **ASR AI config patch**: sets `auto_srrs = 0` in `userconfig\asr_ai\asr_ai_settings.hpp` (disables AI surrender/weapon-drop).
6. **Place new PBOs**: copies active map to MPMissions, parks the other two.
7. **MISSINIT poll**: retries 8×20 s with DismissACR calls between each.

---

## 3. Failure Modes and Recovery

### Boot wedge: server up but no MISSINIT (RPT silent pre-MISSINIT)

**Symptom**: `arma2oaserver` process running, RPT file exists and is growing, but no `MISSINIT` line appears after >3 minutes.

**Cause**: usually a dialog (ACR setup, BattlEye EULA) blocking server init, or a stale lock file from a prior failed start.

**Diagnosis**:
```powershell
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Select-String -LiteralPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Pattern 'MISSINIT|Error|missing'\"""" "
```

**Recovery**:
```powershell
# Re-run DismissACR to clear any blocking dialog
ssh gamingpc "ssh livehost ""schtasks /Run /TN DismissACR"""
# Check C:\WASP\dismiss.txt for what was found/clicked
ssh gamingpc "ssh livehost ""type C:\WASP\dismiss.txt"""
# If still no MISSINIT after 2 min, full restart:
ssh gamingpc "ssh livehost ""powershell -NoProfile -File C:\WASP\rotate2.ps1"""
```

### HC seat failure (one side has str=0 or teams=0)

**Symptom**: players on one faction cannot enroll (WEST or EAST shows 0 teams); HC process count is 3 but AI is not managing that side. Check RPT for `SNAP|WEST` and `SNAP|EAST` lines.

**Diagnosis**:
```powershell
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Select-String -LiteralPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Pattern 'SNAP\|' | Select-Object -Last 10\"""" "
```
Look for `myStr=0` or `teams=0` on either side.

**Recovery (manual)**:
```powershell
# Enable and run the self-correcting seat-healer (up to 4 restart attempts):
ssh gamingpc "ssh livehost ""schtasks /Change /TN WaspSeatHeal /ENABLE"""
ssh gamingpc "ssh livehost ""schtasks /Run /TN WaspSeatHeal"""
# Monitor:
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-Content C:\WASP\rotate2.log -Tail 20\"""" "
# Re-disable after use to prevent accidental future runs:
ssh gamingpc "ssh livehost ""schtasks /Change /TN WaspSeatHeal /DISABLE"""
```

**Recovery (quick — no full restart)**:
```powershell
# Kill only HC1 (oldest ArmA2OA proc) and relaunch:
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""(Get-Process ArmA2OA -EA SilentlyContinue | Sort-Object StartTime | Select-Object -First 1) | Stop-Process -Force\"""" "
ssh gamingpc "ssh livehost ""schtasks /End /TN MiksuuHC & schtasks /Run /TN MiksuuHC"""
ssh gamingpc "ssh livehost ""schtasks /Run /TN DismissACR"""
```

### Service crash (arma2oaserver exits unexpectedly)

**Symptom**: RPT stops, process count drops below 3, match-end watchdog refuses to rotate.

**Diagnosis**:
```powershell
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue | Select Name,Id,CPU\"""" "
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-Content C:\WASP\rotate2.log -Tail 30\"""" "
```

**Recovery**:
```powershell
# Full restart via rotate2 (preserves current map):
ssh gamingpc "ssh livehost ""powershell -NoProfile -File C:\WASP\rotate2.ps1"""
```
`rotate2.ps1` will detect the current active map from MPMissions, stop any surviving processes, and relaunch the full chain. If the server crashes immediately on relaunch, check the RPT for missing addon errors.

### Stale PBO (wrong build name in MPMissions after a failed deploy)

**Symptom**: server starts but MISSINIT never arrives; RPT shows mission load errors or "no mission found"; cfg template does not match the PBO in MPMissions.

**Diagnosis**:
```powershell
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-ChildItem 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions' -Filter '*warfarev2*'\"""" "
# Compare against cfg first template:
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Select-String -LiteralPath 'C:\WASP\profiles-pr8\server-pr8.cfg' -Pattern 'template'\"""" "
```

**Recovery**: if a deploy was interrupted mid-swap, the incoming PBOs may still be in `C:\WASP\incoming\`. Re-run the deploy script, or manually move the correct PBO into MPMissions and retire the stale one, then relaunch.

### Rotation abort: ROTATE2_ABORT_NOTARGET

**Symptom**: rotate log shows `no parked target map at all - abort`.

**Cause**: all three park directories are empty — usually after a failed deploy that retired old PBOs but failed before parking new ones.

**Recovery**: copy the correct build PBOs from `C:\WASP\incoming\` or `C:\WASP\retired\` back into the park directories, then re-run rotate2.

### Rotation abort: ROTATE2_ABORT_AMBIGUOUS (cfg gave no signal)

**Symptom**: multiple PBOs in MPMissions AND the cfg's first template does not match any of them (e.g. cfg still points to cmdcon43 but cmdcon45 PBOs are present).

**Recovery**: manually move all but the intended active PBO out of MPMissions into their park directories, update the cfg's first template to match, then re-run rotate2.

### Lock file stuck

**Symptom**: match-end watchdog exits immediately without rotating; no new rotation in log.

**Check**:
```powershell
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-Item C:\WASP\match_end_rotate.lock | Select Name,LastWriteTime\"""" "
```
If age > 15 minutes, the watchdog clears it automatically on next run. To clear immediately:
```powershell
ssh gamingpc "ssh livehost ""del C:\WASP\match_end_rotate.lock"""
```

---

## 4. Race Conditions and Fragility

### RACE-1: Fixed sleeps vs. actual server readiness

**Location**: `rotate2.ps1` and `deploy45.ps1` — `Start-Sleep 40` before `Run-Task 'MiksuuHC'`.

**Risk**: 40 seconds is an empirically chosen value. Under load, after a cold boot, or if the Hetzner host is slow, the server may not have UDP 2302 open yet. HC1 then silently fails to connect and ArmA2OA.exe exits after its timeout. The script proceeds to launch HC2 against a server that has no HC1 seated.

**Proposed fix**: replace `Start-Sleep 40` with an active poll on UDP 2302 readiness:
```powershell
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline) {
    try { $c = New-Object System.Net.Sockets.UdpClient; $c.Connect('127.0.0.1', 2302); $c.Close(); break } catch {}
    Start-Sleep 3
}
```
Or poll the RPT for the `Game Port` line that ArmA2OA logs when UDP is bound.

### RACE-2: HC kill-and-relaunch timing

**Location**: rotate2.ps1, after HC1 and HC2 are both running — kills HC1 (oldest process) and relaunches.

**Risk**: The script identifies HC1 as "the oldest ArmA2OA process by start time" with `Sort-Object StartTime | Select-Object -First 1`. If HC2 starts slowly (Sandboxie overhead) and HC1 has not been fully seated yet when HC2 is launched, the start-time ordering may be reversed — HC2 may appear older than HC1. The kill would then remove HC2 instead of HC1. Similarly, if `hc_launch.cmd` itself kills and relaunches ArmA2OA, the timestamp resets.

**Proposed fix**: identify HC1/HC2 by process name argument (`-name=HC-AI-Control-1` is in the command line) rather than start time. Use `Get-CimInstance Win32_Process -Filter "Name='ArmA2OA.exe'" | Where-Object { $_.CommandLine -match 'HC-AI-Control-1' }`.

### RACE-3: DismissACR runs may expire before dialog appears

**Location**: `close_acr.ps1` — 40 iterations × 2.5 s = ~100 s polling window.

**Risk**: `DismissACR` is triggered immediately after `Run-Task 'MiksuuHC'` (or HC2). If HC startup is slow (e.g. Sandboxie initializing), the ACR dialog may not appear within the 100-second window. The task exits without dismissing the dialog, the HC launch hangs indefinitely on the dialog, and the HC process never joins the server.

**Proposed fix**: increase the polling iteration count, or re-run `DismissACR` in a loop until `dismiss.txt` shows an action taken. The watchdog in deploy45 already re-runs DismissACR during the MISSINIT poll loop, which partially mitigates this.

### RACE-4: HC2 Sandboxie Steam 30-second wait is unconditional

**Location**: `hc2_launch.cmd` — `timeout /t 30 /nobreak`.

**Risk**: 30 seconds may not be enough for Sandboxie to fully initialize the sandboxed Steam session, especially after a reboot. The game launches before Steam is ready, fails to authenticate, and exits silently. Conversely, if sandboxed Steam is already running from a previous launch, the 30-second wait is wasted.

**Proposed fix**: poll for the sandboxed Steam process being alive before launching the game, with a reasonable ceiling (e.g. 60 s).

### RACE-5: cfg rewrite regex matches all templates, not just first

**Location**: `rotate2.ps1` cfg rewrite, second pass — the regex `(class\s+Missions\s*\{.*?template\s*=\s*")[^"]*("` with Singleline matches the FIRST `template =` inside `class Missions`. The name-normalization pass (first pass) replaces ALL matching template strings across the entire file.

**Risk**: if the secondary stanzas (PR8_Chernarus, PR8_Takistan) contain a template string matching a different map's regex, they will all be rewritten to the current build name but for the wrong map. Currently, `PR8_Takistan` already has a chernarus template value (a pre-existing inconsistency). This is harmless because only the first template is read, but it means the secondary stanzas diverge further with each rotation.

**Proposed fix**: the secondary stanzas are never read by the server. They could be removed from `server-pr8.cfg` entirely, or the name-normalization pass could be scoped to only rewrite within the Missions block for the correct map.

### RACE-6: match_end_rotate ROUNDEND line-number guard vs. RPT rotation

**Location**: `match_end_rotate_v2.ps1` — guards against pre-boot ROUNDEND by comparing `$re.LineNumber` against `$mi.LineNumber`.

**Risk**: if the RPT file is rotated (moved to rpt-archive) by a deploy or rotate2 while the watchdog is mid-check, the line numbers from `Select-String` on the new (smaller) RPT will be lower than previously seen values. This could cause the guard to incorrectly classify a legitimate ROUNDEND as pre-boot and skip the rotation. After the next MISSINIT, the state file re-syncs, so the miss is at most one rotation.

**Proposed fix**: store the RPT's file creation time alongside the state file, and treat any RPT newer than the stored time as a fresh file (reset line-number comparison). Alternatively, use timestamps from RPT lines rather than line numbers.

### RACE-7: WaspSeatHeal disabled but not removed

**Location**: Task `WaspSeatHeal` — currently disabled (last result 267014 = "task is currently running" timeout exit).

**Risk**: WaspSeatHeal performs up to 4 full stop→relaunch cycles with 6-minute waits per attempt (total up to 30+ minutes). If it is accidentally re-enabled and triggered concurrently with a manual rotate or deploy, two scripts will both attempt to stop the service, kill HC processes, and relaunch — resulting in a chaotic multi-script collision with no mutual exclusion.

**Proposed fix**: WaspSeatHeal should check for the `match_end_rotate.lock` file before proceeding and write its own lock, or be replaced by triggering the watchdog with a special flag.

### RACE-8: No mutual exclusion between rotate2 and match_end_rotate

**Location**: `rotate2.ps1` has no lock mechanism. `match_end_rotate_v2.ps1` writes `match_end_rotate.lock` before calling `rotate2.ps1`, but a direct manual call to `rotate2.ps1` bypasses the lock entirely.

**Risk**: a manual `powershell -File C:\WASP\rotate2.ps1` invoked over SSH while an automatic match-end rotation is 30 seconds in will result in two concurrent script runs: both will stop the service, both will attempt to move PBOs, and one will fail with a file-in-use or file-not-found error partway through. The result is an unknown PBO state.

**Proposed fix**: add a lock at the top of `rotate2.ps1` itself (write a `rotate2.lock` file, check for it on entry, clear it in a `finally` block).

---

## Quick-reference one-liners

```powershell
# Tail the ops log (last 30 lines)
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-Content C:\WASP\rotate2.log -Tail 30\"""" "

# Check process count (expect 3: arma2oaserver + 2x ArmA2OA)
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""(Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue).Count\"""" "

# Check MISSINIT (confirm mission running)
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Select-String -LiteralPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Pattern 'MISSINIT' | Select-Object -Last 1\"""" "

# Check active map (which PBO is in MPMissions)
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-ChildItem 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions' -Filter '*warfarev2*' | Select Name\"""" "

# Check parked maps
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Get-ChildItem C:\WASP\mission-park -Recurse -Filter '*.pbo' | Select FullName\"""" "

# Manual rotate (next map in cycle)
ssh gamingpc "ssh livehost ""powershell -NoProfile -File C:\WASP\rotate2.ps1"""

# Full restart without rotating (stops chain, relaunches same map)
# Note: rotate2.ps1 will detect the same map as active and still rotate to the next.
# For a same-map restart, use the SeatHeal script (enable first):
ssh gamingpc "ssh livehost ""schtasks /Change /TN WaspSeatHeal /ENABLE & schtasks /Run /TN WaspSeatHeal"""

# Apply CPU tuning manually (e.g. after external process disturbs affinity)
ssh gamingpc "ssh livehost ""powershell -NoProfile -File C:\WASP\Set-WaspServerTuning.ps1"""

# Check HC seat health (SNAP lines, last 4)
ssh gamingpc "ssh livehost ""powershell -NoProfile -Command \""Select-String -LiteralPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Pattern 'SNAP\|' | Select-Object -Last 4\"""" "
```
