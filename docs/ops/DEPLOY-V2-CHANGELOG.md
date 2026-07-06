# deploy-v2.ps1 — Change Log

## 2026-07-06 — Adversarial-verify patch (B1/B2 + pgate + DEPLOY_DONE)

### Fixes applied

| ID | Severity | Fix |
|----|----------|-----|
| B1/B2 | HIGH | HC1 recovery path no longer invokes `Run-Task 'MiksuuHC'`, which calls `hc_launch.cmd` whose **first line** is an unfiltered `taskkill /f /im ArmA2OA.exe` — this killed the already-seated HC2, leaving 0 HCs while the script reported success. The recovery now uses `Kill-Hc 'HC-AI-Control-1'` (CommandLine-targeted, HC2-safe) + `Start-Hc1Direct` (reads MiksuuHC task XML, launches ArmA2OA.exe directly, skipping the .cmd). After any HC1 recovery, HC2 is re-verified still seated; if HC2 also died it is recovered in turn. |
| PGATE | MED | Added `-Force` switch parameter and player-empty guard at startup. Reads `players=N` from the most recent SNAP/FPSREPORT line in the server RPT; aborts with `DEPLOY_V2_ABORT_PLAYERS` if `players > 0` unless `-Force` is passed. |
| DONE | LOW | Final output line now emits `DEPLOY_DONE DEPLOY_V2_DONE …` so legacy watcher/monitor cron jobs that grep for `DEPLOY_DONE` remain satisfied. |

### Box-side follow-up (NOT done in this script — separate maintenance task)

`C:\WASP\hc_launch.cmd` line 1 (`taskkill /f /im ArmA2OA.exe`) has no command-line filter and
will kill **any** `ArmA2OA.exe` process, including a running HC2.  Replace with:

```bat
taskkill /f /fi "COMMANDLINE eq *HC-AI-Control-1*"
```

This is safe to apply independently at any time.

---

## 2026-07-06 — Initial release (replaces deploy47.ps1 / deploy45.ps1 lineage)

### Background

Three live incidents on 2026-07-06 caused by two compounding bugs:

1. After `Stop-Service` the server process or its UDP 2302 binding did not clear within the
   hard-coded `Start-Sleep 3/8` window, causing `Start-Service` to bring up the binary while
   the old port was still occupied.  The service entered `Stopped` within ~75 s.

2. The kill/relaunch HC dance that followed identified HC1 and HC2 by birth-time sort
   (`Sort-Object StartTime | Select-Object -First 1`).  Under Sandboxie initialisation delay
   the birth-time order inverted, killing the wrong HC and producing stale
   "Player without identity HC-AI-Control-N" connections.

### Races fixed

| Race | Root cause | Fix in deploy-v2 |
|------|-----------|-----------------|
| RACE-1 | `Start-Sleep 40` before HC1 — blind guess at server readiness | Poll RPT for `Game Port` marker + service `Running` + RPT growing; re-arms `DismissACR` throughout the window |
| RACE-2 | HC identified by birth-time sort — reverses under Sandboxie delay | HC identified by `Win32_Process.CommandLine` match on `-name=HC-AI-Control-N`; kill/relaunch dance removed entirely |
| RACE-3 | `DismissACR` 100 s window may expire before HC dialog appears | `DismissACR` re-armed every ~35 s inside both the server-readiness poll and each HC-seat wait loop |
| RACE-5 | cfg template rewrite touched all `template =` lines in file | Rewrite scoped to the FIRST `template =` inside `class Missions { }` only; secondary stanzas untouched |
| RACE-7 | `WaspSeatHeal` (disabled) could collide with a concurrent deploy | `C:\WASP\deploy.lock` acquired at script start, released in `finally`; stale locks older than 30 min auto-cleared |
| RACE-8 | No mutual exclusion between `rotate2`, manual deploy, match-end watchdog | Same `deploy.lock` applies; `rotate2.ps1` should also be updated to honour this lock |

### What did NOT change

- ACR `tracked_acr_patched.pbo` byte-patch logic (unchanged)
- ASR AI `auto_srrs = 0` patch (unchanged)
- Retire/park PBO flow (unchanged)
- RPT archive to `C:\WASP\rpt-archive\` (unchanged)
- MISSINIT poll (8 × 20 s, re-arms DismissACR each round) (unchanged)
- `Set-WaspServerTuning.ps1` call (unchanged)
- Incoming file guard (>5 MB each) (unchanged)
- Active-map detection from cfg first-stanza (improved — explicitly scoped to first stanza)
- `DEPLOY_V2_DONE` output line and rotate2.log append (unchanged, tag updated)

### New behaviour: HC serialization

HC1 and HC2 are now launched strictly in sequence, each gated on an RPT readiness probe:

```
Start-Service
  └─ poll: Game Port in RPT (up to 120 s)
       └─ Launch HC1 (MiksuuHC / HC-AI-Control-1)
            └─ poll: HCSIDE|...|sideNow=CIV in RPT (up to 120 s)
                 └─ Launch HC2 (MiksuuHC2 / HC-AI-Control-2)
                      └─ poll: HCSIDE|...|sideNow=CIV in RPT (up to 150 s)
                           └─ tuning + MISSINIT poll
```

If an HC fails to seat within its timeout, the recovery is:
1. End the scheduled task.
2. Kill the HC process by command-line match (NOT birth-time sort).
3. Relaunch the task once.
4. Wait a further 150 s for seat confirmation.
5. Log success/failure and continue (both HCs report their status in the final DONE line).

### Deployment

1. Drop `deploy-v2.ps1` into `C:\WASP\incoming\` on livehost (or directly into `C:\WASP\`).
2. Invoke: `powershell -NoProfile -File C:\WASP\deploy-v2.ps1 -BuildTag cc48 -ActiveMap ch`
3. Monitor: `Get-Content C:\WASP\rotate2.log -Tail 40 -Wait`

### Remaining work

- `rotate2.ps1` should be updated to write/honour `C:\WASP\deploy.lock` (RACE-8 partial).
- `match_end_rotate_v2.ps1` already writes `match_end_rotate.lock` — consider whether that
  lock and `deploy.lock` should be unified into a single `C:\WASP\chain.lock`.
- RACE-4 (HC2 Sandboxie 30 s unconditional wait in `hc2_launch.cmd`) is not addressed here;
  polling for the sandboxed Steam process in the cmd file is a separate change.
- RACE-6 (RPT line-number guard vs. log rotation) is not addressed here.
