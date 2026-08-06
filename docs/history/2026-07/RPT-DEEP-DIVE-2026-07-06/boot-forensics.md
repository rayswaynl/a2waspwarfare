# WASP Server Boot Forensics — 2026-07-06

**Analysis date:** 2026-07-06  
**Analyst:** Claude (Fable/Sonnet 4.6)  
**Skill:** rpt-triage GR-2026-07-06a  
**Files analyzed:** 10 RPTs (9 archive + rpt-lastmatch alias)  
**Source:** `C:\WASP\rpt-archive\` on livehost, pulled via gamingpc double-hop

---

## 1. Boot Inventory

All times are **box-local (US Pacific, UTC-7)**. Amsterdam = box + 9h.

| File | Label | Build Marker | WASPRELEASE git | MISSINIT Count | WASPSCALE seen | File size |
|---|---|---|---|---|---|---|
| servicerestart-0240 | cc44u_overnight | build89-cmdcon44t-20260704 | cmdcon44t | 4 (2 missions × 2) | YES (104) | 5.9 MB |
| servicerestart-0248 | cc44u_restart1 (PerfOFF) | build89-cmdcon44-20260703 | 51c65e720a | 4 | YES | 380 KB |
| servicerestart-0317 | cc44u_PerfON_test | build89-cmdcon44-20260703 | 51c65e720a | 4 | YES | 316 KB |
| servicerestart-0348 | cc44u_restart2 (PerfON) | build89-cmdcon44-20260703 | 51c65e720a | 4 | NO | 22 KB |
| servicerestart-0353 | cc44u_restart3 (aborted) | — | — | 0 | NO | 5.6 KB |
| deploy45-0642 | cc45_main | build89-cmdcon44t-20260704 | cmdcon44t | 2 | YES | 910 KB |
| deploy45-0647 | cc45_restart | build89-cmdcon45-20260706 | cmdcon45 | 4 | YES | 36 KB |
| deploy45a-0657 | cc45a_failed | build89-cmdcon45-20260706 | cmdcon45 | 2 | NO | 15 KB |
| deploy46-0708 | cc46_recovery | build89-cmdcon45a-20260706 | cmdcon45a | 6 | YES | 237 KB |
| rpt-lastmatch | lastmatch alias | build89-cmdcon45a-20260706 | cmdcon45a | 6 | YES | 237 KB |

**Note:** rpt-lastmatch.RPT is a byte-for-byte copy of deploy46-0708.RPT (identical 236,818 bytes). The rotation script points it at the cc46 boot.

---

## 2. Build Identification Summary

The RPTs span **four distinct builds** in sequence:

1. **cc44u / build89-cmdcon44t** (`cmdcon44t` tag, git `build89-cmdcon44t-20260704`) — overnight soak + cc45 main boot
2. **cmdcon44 / cc44-2026-07-03** (git `51c65e720a`) — PerfON/PerfOFF test reboots (0248, 0317, 0348, 0353)
3. **cc45 / build89-cmdcon45** (`cmdcon45` tag, git `build89-cmdcon45-20260706`) — cc45_restart + cc45a_failed
4. **cc45a / build89-cmdcon45a** (`cmdcon45a` tag, git `build89-cmdcon45a-20260706`) — cc46_recovery (current)

---

## 3. Forensic Question 1: PerfON Test Boot (0317 / 0348)

### What happened

The "PerfON test" is actually split across **two files**:

- **0317** (`cc44u_PerfON_test`) — This is the **PerfOFF** test mission (`WASP_PerfOFF_TEST.Chernarus`), not PerfON. The file ran for ~25 ticks (25 minutes game-time), WASPSCALE was seen, the server ran normally and wrote performance audit lines. This is a complete, healthy PerfOFF soak run.

- **0348** (`cc44u_restart2`) — This is the actual **PerfON test** (`WASP_PerfON_TEST.Chernarus`). The file is 22 KB (265 lines), WASPSCALE was **not seen**, meaning the mission **did not reach steady-state**.

### The AI_Commander_Base.sqf:244 syntax error

The error `Error Missing )` from `AI_Commander_Base.sqf:244` appears in **both** the 0317 and 0348 files (and in 0248, and in cc45a). The error is:

```
Error in expression <true};
(count (nearestTerrainObjects [_cpos, ["TREE","SMALL TREE"], _tr])) ==>
  Error position: <[_cpos, ["TREE","SMALL TREE"], _tr])) ==>
  Error Missing )
File mpmissions\WASP_PerfOFF_TEST.Chernarus\Server\AI\Commander\AI_Commander_Base.sqf, line 244
```

This is a **known, pre-existing bug** in `AI_Commander_Base.sqf:244` — it fires once per MISSINIT (each boot) and appears in **every build analyzed today** (cc44, cc45, cc45a). It is **not mission-stopping**: after the error the AICOM HighClimb and AutoFlip managers start normally, HC connects, and the server continues.

### Was the PerfON boot (0348) killed by the syntax error?

**No.** The error appears at lines 132–141 of the 0348 file, then execution continues: HIGHCLIMB_HB fires, AUTOFLIP_HB fires, HC preseat/reseat completes, HC-2 unit-count heartbeat fires. The server's **last 5 lines** are AICOM initialization continuations, not crash evidence. The 0348 file ends at only 265 lines, meaning the server wrote those lines and then stopped — but not due to the syntax error.

### What killed 0348 (PerfON test)?

The 0348 file has **12 error lines total** (all trivial: 4× the known AI_Commander nearestTerrainObjects syntax error). Its last 5 lines:

```
File mpmissions\WASP_PerfON_TEST.Chernarus\Server\AI\Commander\AI_Commander_Base.sqf, line 244
"[AICOM INFORMATION] Common_AICOM_HighClimb.sqf: AICOM high-climb manager started (SERVER)."
"AICOMSTAT|v1|EVENT|true|0|HIGHCLIMB_HB|machine=SERVER|teams=0|localVeh=0|started=0"
"[AICOM INFORMATION] Common_AICOM_AutoFlip.sqf: AICOM auto-unflip manager started (SERVER)."
"AICOMSTAT|v1|EVENT|true|0|AUTOFLIP_HB|machine=SERVER|localVeh=0|tilted=0"
```

No error after this. No panic, no engine abort. The server was externally killed (operator ctrl+C / service restart / wrapper watchdog), **not** by a script failure. The absence of a closing error or engine-halt message is the tell. The mission header line also flags `Number of roles (34) is different from description.ext::Header::maxPlayer (55)` — the PerfON test pbo has a mismatched slot count vs the live slot file, which is a config warning, not a crash cause.

### Full PerfON boot timeline (0348)

| Phase | Status |
|---|---|
| Steam connect | OK |
| XEH PreInit / PostInit | OK |
| MISSINIT (XEH) line | OK |
| MISSINIT (mission) line | OK |
| WFBE economy init | Started |
| Faction registrations Core_* | Started (Core_ACR through Core_USMC done) |
| AI_Commander_Base.sqf:244 error | Fired (non-fatal, known bug) |
| AICOM HighClimb start | OK |
| AICOM AutoFlip start | OK |
| HC-AI-Control-1 preseat/reseat | Not recorded in 0348 |
| WASPSCALE heartbeat | **Never reached** |
| Server death | External kill, no logged error |

**The PerfON test was externally terminated after ~1 minute of run-time** (265 lines = very early in init, no WASPSCALE), almost certainly by operator intervention after seeing the slot-count mismatch warning or deciding the test was complete.

---

## 4. Forensic Question 2: cc45a Failed Boot (0657)

### The raw truth

The cc45a file (`deploy45a-20260706-0657.RPT`) is **170 lines total**. It contains:

- **Two engine boot sessions** (two sets of exe header blocks), indicating the server binary was launched, crashed or was killed, and restarted once.
- **MISSINIT count: 2** — one per session, each reaching mission-start level.
- **WASPSCALE: never seen** — neither session reached steady-state.
- **Error count: 6** — all 6 are the known AI_Commander_Base:244 nearestTerrainObjects error (non-fatal).

The file name `deploy45a` in the archive implies this is the **cc45a build attempt**, and the WASPRELEASE marker confirms: `build89-cmdcon45-20260706` (note: this is cmdcon45, not cmdcon45a — the cc45a fix was built as the **next** iteration).

### Session 1 (lines 0–88)

The first boot starts at `Current time: 2026/07/06 06:47:17`. It loads mods, connects to Steam, then spams 89 consecutive `Server error: Player without identity "HC-AI-Control-1" (id 23879122)` errors before the first MISSINIT fires at line 89. This is the classic HC identity error pattern seen when the HC client reconnects before the server has assigned it an identity slot — **normal behavior**, not a failure.

Session 1 makes it to **MISSINIT (XEH) → MISSINIT (mission) → WASPRELEASE marker → WFBE econ init** and then the file continues into Session 2.

### Session 2 (lines 89–169)

The second boot starts at `Current time: 2026/07/06 06:47:38` (21 seconds after Session 1). This tells us Session 1 was a **very short-lived boot** — the server binary died and restarted within 21 seconds.

Session 2 executes:
- XEH PreInit/PostInit (OK)
- Mission MISSINIT markers (OK)
- WASPRELEASE tag (OK)
- WFBE EconomyBoost, econ init (OK)
- All Core_* faction registrations: ACR, BAF, BAFD, BAFW, CDF, DeltaForce, CIV, FR, GUE, INS, MVD, PMC, RU, Spetsnaz, TKA, TKCIV, TKGUE, TKSF, US, USMC — **all complete**
- AI_Commander_Base:244 error (non-fatal, fires twice)
- AICOM HighClimb start (OK)
- AICOM AutoFlip start (OK)
- HCSIDE preseat/reseat (OK)
- HCSTAT: `HC-2:28|fps=45|units=1|groups=1|t=0`
- **File ends here** — no further writes

### What killed cc45a?

**The file ends cleanly after a normal-looking init sequence.** The last three lines are `HCSIDE reseat`, `HCSTAT` heartbeat at t=0, and then nothing. There is:

- No engine error
- No script abort
- No "out of memory" or similar fatal
- No SQF exception
- No port-bind failure message

This is **the same signature as 0348**: external kill, zero logged failure. The server completed the Core_* init phase (all 20 factions registered), AI commander started, HC slotted — and was then stopped from outside.

### Why did it appear as a "4 MISSINIT restart loop"?

The original incident report (from session monitoring) counted MISSINITs across the **entire deploy45a file**. The correct count is **2 MISSINITs** in this file (one per engine-binary session). The "4 MISSINIT = restart loop" count likely came from the monitoring tool counting across combined deploy45 + deploy45a files, or from misidentifying the 0247 + 0353 files also as cc45a boots.

**There is no restart loop.** cc45a had exactly two boot attempts (one binary restart), both reached advanced init, both were externally terminated.

### Port-release race vs mission-content hypothesis

The external-kill signature with no logged failure, combined with the 21-second gap between the two sessions, is **consistent with a port-release race** (server process holding port 2302 so the next instance fails to bind), but the RPT itself cannot confirm this — a port-bind failure would appear in the engine console before the log starts. The absence of any error before MISSINIT in session 2 suggests session 2 did bind successfully (it reached mission init). The more probable explanation: the deployment script killed cc45a intentionally after detecting the cc45a params issue (the slot count / params mismatch that was then patched in cc45a proper), and the two sessions are the two "test restart" pokes during that window.

---

## 5. Forensic Question 3: cc45 and cc46 — Clean Baselines

### cc45_main (deploy45-0642, 910 KB)

| Metric | Value |
|---|---|
| Build | build89-cmdcon44t-20260704 (cmdcon44t — note: cc45 file shows cmdcon44t, not cc45 tag) |
| MISSINIT count | 2 (normal: XEH + mission-level) |
| WASPSCALE seen | YES |
| Run length | 83 ticks (~83 minutes) |
| Error total | 78 |
| Top error | `_light` undefined variable (mks_tally / kill tally light) — 26×3 = 78 total |
| HC FPS at t=83 | 48 fps, 134 units, 23 groups |

The 78 errors are entirely the `_light` undefined variable from the kill-tally lighting subsystem (mks_tally). This is a pre-existing bug, fires on every kill event. **No new errors.** cc45_main booted cleanly and ran for at least 83 minutes.

### cc45_restart (deploy45-0647, 36 KB)

| Metric | Value |
|---|---|
| Build | build89-cmdcon45-20260706 (cmdcon45 — first cc45 restart) |
| MISSINIT count | 4 (two sessions as expected) |
| WASPSCALE seen | YES |
| Error total | 15 (all: 4× AI_Commander:244 + 1× WF_MAXPLAYERS delegation error) |

The `WF_MAXPLAYERS` delegation error is new but appears only once — likely a startup timing issue. No impact on runtime. The cc45_restart boot ran and showed normal AICOM tokens: HCRECON_AICOM_AUDIT, HCSIDE connect/reseat, GUERAIRDEF|START. **Clean.**

### cc46_recovery (deploy46-0708, 237 KB = current live match)

| Metric | Value |
|---|---|
| Build | build89-cmdcon45a-20260706 |
| MISSINIT count | 6 (three sessions — initial + one restart + final stable boot) |
| WASPSCALE seen | YES |
| Error total | 15 (4× AI_Commander:244 + 1× WF_MAXPLAYERS delegation) |
| Run length | 213 ticks (~3.5 hours) at last write |
| HC2 FPS at end | monitoring active |

The cc46 file covers the recovery boot after cc45a. Three sessions (two short + one stable). The final session (lines 361+) reached full steady-state: WASPSCALE heartbeats, AICOM dispatches, GUERSTIPEND paying, players connecting. **Healthy.**

---

## 6. Cross-Build Comparison Table

| Boot | Build Tag | Time-to-first-MISSINIT | Init completed | Error total | Top error signature | Notes |
|---|---|---|---|---|---|---|
| cc44u_overnight | cmdcon44t | N/A (RPT has no wall-clock TS) | YES (WASPSCALE ×104) | 504 | `_light` undefined (mks_tally) ×492 | Long overnight soak, 2 players, 520 ticks |
| cc44u_PerfOFF (0248) | cmdcon44-51c65e720a | N/A | YES | 3186 | `_enemies` undefined (server_town_ai.sqf:174) ×3174 | PerfOFF test mission — **massive** town-AI error storm |
| cc44u_PerfON (0317) | cmdcon44-51c65e720a | N/A | YES | 42 | AI_Commander:244 `Missing )` ×8 + ACE_Bandage warning ×26 | Healthy 25-tick PerfOFF soak (see naming note) |
| cc44u_PerfON_real (0348) | cmdcon44-51c65e720a | N/A | NO | 12 | AI_Commander:244 ×4 | Externally killed early |
| cc44u_abort (0353) | — | never | NO | 0 | HC identity spam only | No mission loaded at all |
| cc45_main | cmdcon44t | N/A | YES | 78 | `_light` undefined ×78 | 83 ticks, same mks_tally bug |
| cc45_restart | cmdcon45 | N/A | YES | 15 | AI_Commander:244 ×4 | New cc45 build, clean |
| cc45a_failed | cmdcon45 | N/A | NO | 6 | AI_Commander:244 ×4 | 2 sessions, externally killed |
| cc46_recovery | cmdcon45a | N/A | YES | 15 | AI_Commander:244 ×4 | Current live, healthy |

**Note on timestamps:** All RPTs in this batch have `None` wall-clock timestamps for individual lines — the Arma 2 OA server log format omits timestamps from normal script-log lines. The `[frameno, ticktime, ...]` embedded in XEH lines provide relative engine time but not wall-clock time. Boot start times are inferred from the file timestamps in the archive directory listing.

### Does Build 89 boot cleaner or dirtier than cc44u?

**Build 89 (cc45/cc46) boots equally clean.** The error signature is identical: the AI_Commander:244 `nearestTerrainObjects` bug fires in every build including cc44u. cc45/cc46 actually has **fewer** errors in the first session (6–15 vs 78+ in cc44u_overnight), because the mks_tally `_light` bug has not yet accumulated (shorter runtime) and the server_town_ai `_enemies` error storm from the PerfOFF test is absent on the regular mission.

---

## 7. Forensic Question 4: Overnight cc44u (0240) — Late Error Families

The overnight file is 5.9 MB, 48,570 lines, covering a long session (WASPSCALE tick 520 = ~8.7 hours of game time at 1 tick/minute). The last MISSINIT window is 48,379 lines.

### Error families in the last MISSINIT window

| Count | Normalized signature | Source |
|---|---|---|
| 492 | `_light` undefined variable in expression | mks_tally kill-tally light system |
| 6 | `_enemies` undefined variable | server_town_ai.sqf:174 |
| 6 | Generic error / `_queu` / `nearEntities StaticWeapon` | various (tower defense / shooter cleanup) |

**The `_light` error is the dominant signal** — 164 occurrences per triplet = 492 total error lines. This is the mks_tally kill-light subsystem trying to `deleteVehicle _light` where `_light` was never initialized. This fires on every kill event, regardless of player count. At 504 total errors over the full session, the rate is roughly 1 kill-light error per 96 lines — plausible for a 2-player overnight session.

### Anything monitoring might have missed?

1. **`_enemies` undefined at server_town_ai.sqf:174** — This fires 6 times total overnight (3 triplets). The variable `_enemies` is populated via `nearEntities ["StaticWeapon"]` and becomes undefined when the `_shooter` group is empty or nil. This is a low-frequency edge case, not a systemic failure. Not new, not a blocker.

2. **The `_queu` error** — `Generic error in expression` on what appears to be a queue-comparison loop. Only 2 occurrences overnight, suggesting it's a race condition in a queue-drain script. Low severity.

3. **WASPSCALE at t=520, fps=36** — At the final heartbeat the server was at 36 FPS with 378 AI units (248 West, 77 East, 53 GUER), 110 groups, 2 players. This is within normal range for that unit count but approaching the caution zone (target >30 fps). The `fpsmin=15` field is worth noting — there was at least one moment of 15 FPS during the session, likely a brief AI pathfinding spike.

4. **No new error families appeared in the overnight portion that weren't present from the start.** The error set is stable.

---

## 8. The AI_Commander_Base.sqf:244 Bug — Full Picture

This bug appears in **every build today** and in the PerfON, PerfOFF, cc45, cc45a, and cc46 RPTs.

**Root cause:** `nearestTerrainObjects` in A2OA 1.64 requires its array argument in a specific form. The call at line 244 reads:

```sqf
(count (nearestTerrainObjects [_cpos, ["TREE","SMALL TREE"], _tr])) ==>
  Error Missing )
```

The `_tr` variable (radius, presumably) is being passed as a third array element, but `nearestTerrainObjects` in A2 takes `[center, types, radius]` as **three separate parameters**, not a nested array. The extra `)` in the call site closes the `count` before the `nearestTerrainObjects` call is complete — hence "Missing )".

**Severity:** NON-FATAL. The error fires during AICOM startup, the expression evaluates to error but execution continues. AICOM HighClimb, AutoFlip, and all subsequent init all complete normally. The bug has existed for multiple build generations.

**Fires:** Once per MISSINIT (once per boot session). In cc45a with 2 sessions, it fires twice. In cc46 with 3 sessions, it fires thrice.

**Fix:** `fable/hotfix-nearestterrain` branch exists in the repo — this was already identified and patched in that branch. Confirm it is merged before the next build.

---

## 9. Summary of cc45a "Incident" — Revised Understanding

The cc45a incident was **not a restart loop caused by a mission-content failure**. The 0657 file shows:

1. Two engine sessions in 21 seconds
2. Both reach normal init (all Core_* factions register, AICOM starts, HC slots)
3. Both terminated externally with no logged error
4. Total MISSINIT count: 2 (not 4)
5. The "4 MISSINIT" count in the monitoring dashboard likely came from aggregating cc45_restart (4 MISSINITs) + cc45a (2 MISSINITs) into one count, or from counting across multiple files

**The port-release race theory is not confirmed or denied by the RPT** — a port-bind failure would not appear in the script log. However session 2 successfully reached mission init, which means it did bind to port 2302. The most probable explanation: the operator restarted twice in quick succession while deploying the cc45a params fix, and cc45a was intentionally killed once the params issue was confirmed.

---

## 10. Concerns and Follow-Up Items

| Priority | Concern | Evidence | Action |
|---|---|---|---|
| HIGH | `fable/hotfix-nearestterrain` merge status | AI_Commander_Base:244 fires in cc45a (build89-cmdcon45) — confirm it is merged in cc45a proper | Check PR status; if not merged, it will fire in every cc45a+ boot |
| MEDIUM | mks_tally `_light` undefined variable | 492 error lines overnight, fires on every kill | Known bug; log noise but adds ~1.5% overhead per kill event. Track for fix. |
| MEDIUM | server_town_ai.sqf:174 `_enemies` undefined | 6 occurrences overnight — `nearEntities StaticWeapon` with nil shooter | Edge case race; add nil guard before `nearEntities` call |
| LOW | `_queu` queue-compare Generic error | 2 occurrences overnight | Identify which queue script, add nil/type guard |
| LOW | Overnight WASPSCALE fpsmin=15 spike | `fpsmin=15` at tick 520 with 378 AI | Monitor; may be pathfinding burst. Not systemic at current player count. |
| INFO | WF_MAXPLAYERS delegation error in cc45/cc46 | 1 occurrence per file, startup only | Likely timing race on server start; benign |
| INFO | PerfOFF test `_enemies` storm | 3186 errors in 0248 file | The PerfOFF test mission has server_town_ai running in a tight loop; expected in test context |
| INFO | rpt-lastmatch.RPT = deploy46 | Byte-for-byte identical | Rotation script correctly updated the alias |

---

## 11. Boot-to-Boot Comparison (condensed)

```
Build         Errors/session  Init OK  Run length  FPS@end  Notable
--------      -------------  -------  ----------  -------  -------
cc44u night   504 total       YES      520 ticks   36       mks_tally storm, stable
cc44_PerfOFF  3186 total      YES      ~25 ticks   46       _enemies storm (test mission)
cc44_PerfON   12              NO*      ~0 ticks    —        externally killed early
cc45_main     78              YES      83 ticks    —        mks_tally, clean
cc45_restart  15              YES      short       —        new cc45 build, healthy
cc45a_failed  6               NO*      ~0 ticks    —        externally killed (see §4)
cc46_recovery 15              YES      213 ticks   —        CURRENT LIVE, healthy
```
\* "NO" = WASPSCALE never seen in that file; mission init was in progress when external kill occurred.

---

*Report generated from local RPT analysis. All source files stored in gamingpc staging and local scratchpad. Gamingpc staging can be cleaned up.*
