# dbg0726g five-RPT sweep

Build under test: `dbg0726g`, `master` `bcd35dbb47`.  Collection was read-only over SSH on 2026-07-26.  Each active RPT was opened with a shared-read stream because the running Arma processes hold exclusive ordinary read handles.  The examined windows begin at the final `MISSINIT` and run to EOF:

| Process | RPT | final-MISSINIT window |
| --- | --- | --- |
| Server | `C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT` | L14731-L19691 (4,961 lines) |
| HC1 | `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | L21264-L22384 (1,121 lines) |
| HC2 | `C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | L23847-L25091 (1,245 lines) |
| HC3 | `C:\Sandbox\Administrator\HC3\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | L24485-L25868 (1,384 lines) |
| HC4 | `C:\Sandbox\Administrator\HC4\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | L25324-L26497 (1,174 lines) |

## Executive result

The visible fixes from #1476, #1478 and #1483 are present in their exercised paths.  #1473 is **not clean**: every process reports that `Common_RealPlayersNear.sqf` cannot be found, and HC2--4 subsequently emit seven undefined-variable expression errors.  Treat that as the highest-priority follow-up before relying on any player-proximity protection.  The air-defence slice work is working as designed; the apparently high `guer_airdef_cycle` value is the sum of active slices, not evidence of a second unsliced call path.

## Merged-batch verification

| Item | Verdict | RPT evidence |
| --- | --- | --- |
| #1476 marker-loop BOOLCMP | PASS for error removal; survival evidence is limited | `BOOLCMP` and `Error ==: Type Bool` are absent from all five final windows.  The server window exceeds 1,100 seconds of mission time, but no client marker-loop heartbeat exists to prove its lifetime directly.  Keep a marker-specific heartbeat/counter as the next soak instrumentation rather than infer phantom-marker absence. |
| #1478 side patrols | PASS | The server has eight explicit `server_side_patrols.sqf: patrol dispatched` records (including L15204/L15206/L16688/L16689) and eight `HSDISPATCH sidepatrol-started` records.  `WASPSCALE ... patr=` rises `0 -> 2 -> 3 -> 5` at L15103/L16092/L17637/L18743.  No `currentWaypointPosition` parse error occurs in any window. |
| #1483 idle-RTB | PASS in this run | `_idleRtbEnabled` and `BE_C_AICOM_AIR_IDLE_SENSE_R` have zero matches in all five final windows. |
| #1473 player-near / top-defer | FAIL | `_topDefer` itself is absent, but all five processes log `Warning Message: Script Common/Functions/Common_RealPlayersNear.sqf not found` (server L14752; HC1 L21291; HC2 L23870; HC3 L24511; HC4 L25346).  HC2 then has four expression/undefined-variable pairs, HC3 one, HC4 one.  This is a reduced storm, not zero. |
| #1471 air wreck persistence | PASS, with limited coverage | HC2 emits `CLIENT_EMPTY_GROUP_CLEANUP` with `skippedPersistent=1` at L25053/L25093/L25171, directly showing persistent objects are skipped.  No instant shot-down-AICOM-hull deletion signature appears.  Add a paired `AICOM_AIR_WRECK` death/retire reason to make this proof specific to the next shot-down air test. |
| #1481 air-defence and anti-stack perf | PASS; no second path found | `antistack_flush` stays 21--23 ms in the sampled server records.  At L19446 the slice average is 31.78 ms (`max=341.92`); L19449's 413.09 ms cycle has `slices=13`, `sliceMaxMs=341.92`, and `wallMs=5741.09`.  Even the later 570.92 ms cycle is accompanied by 14 slices and 6388.06 ms wall time.  The source deliberately records `_perfActive` after `_sliceCut`, so cycle is aggregate active work, not a monolithic unsliced invocation. |

## Ranked findings and proposed follow-ups

### P0 -- repair the RealPlayersNear load path

**Impact:** HC2--4 have live undefined-variable errors in movement/near-player guards.  The same missing-file warning is on server and HC1, so this is deployment-wide and can invalidate several safety checks.

**Root cause and evidence:** RPT locations above; HC2 examples L24631-L24634 and L24812-L24903; HC3 L25355-L25358; HC4 L26179-L26182.  The deployed release reports `git=733f07ce34` immediately before `MISSINIT`; that tree contains the 44-line helper for all three terrains (SHA-256 `E0A611B527205D517F049F60A27024D73DDE8A6F072C35A18ED9B7FEAB30599A` in the current source), its consumers, and the registration at `Common/Init/Init_Common.sqf:104`.  A read-only byte scan of deployed `C:\WASP\staging\[61-2hc]warfarev2_073v48co_dbg0726g.zargabad.pbo` (16,068,436 bytes) finds both the helper and the forward-slash path, not the backslash form.  The registration is uniquely written as `Common/Functions/...` while adjacent registrations use `Common\Functions\...`; the five live missing-file warnings therefore isolate A2 OA forward-slash resolution as the supported root cause, not package omission.

**Proposed fix:** normalize the registration to the established `Common\Functions\Common_RealPlayersNear.sqf` form, propagate through LoadoutManager, and inspect the packed mission before a fresh debug build.  Acceptance: the release commit and packed mission both contain the helper for all terrains, and five final-MISSINIT windows have zero missing-script warnings and zero consequent `_topnear`/`_pnear` expression errors.

### P1 -- make AICOM team founding cooperative at the 16-team cap

**Impact:** `aicom_teams_found` reaches 270.51 ms (max 348.02) at server L17345 with 288 AI/82 vehicles, then remains 136--192 ms while population climbs.  It is a recurring founding pass, not a one-off boot race.

**Source:** `Server/AI/Commander/AI_Commander_Teams.sqf:1649` records the whole pass; its telemetry exposes `eligible`, `groups`, `allUnits`, and `vehicles` but not which subscan dominates.

**Proposed fix:** first split timing around candidate/eligible enumeration, existing-team scan, and each actual creation; then yield/cursor the dominant all-units/group traversal between commander ticks.  Preserve the 16-team target and side fairness.  Acceptance: 16-team 4-HC soak has p95 below 100 ms with no loss of founding or pending-team correctness.

### P2 -- observe, do not prematurely retune, dropped-item cleaning

**Evidence:** server L16025 is 134.98 ms at 93 AI; later L17582/L18701 are about 20 ms with `scanned:0;deleted:0`.  This is materially below the old multi-second startup issue and matches the source comment in `Server/FSM/cleaners/droppeditems_cleaner.sqf:28-34` that early startup measurement is noisy.

**Proposed follow-up:** retain the existing deferred-first-sweep policy and add a sample only when holders/mines are nonzero.  Only slice the scan if populated-world samples, not empty scans, repeatedly exceed the budget.

### P2 -- add a direct marker-loop health signal

The BOOLCMP removal is verified, but marker-loop survival is only inferred from absence of its old error.  A 60-second client-local `MARKERLOOP` heartbeat (or a monotonic iteration count surfaced in the existing debug telemetry) would make #1476's acceptance direct and catch future silent exits without log scraping.

## Open-hunt notes and dedupe

- No `currentWaypointPosition`, `_idleRtbEnabled`, `BE_C_AICOM_AIR_IDLE_SENSE_R`, `_topDefer`, or BOOLCMP errors were found in the final windows.
- The `WASPSCALE` samples show meaningful patrol activation and neither an immediate GUER collapse nor a clean side steamroll in the observed Zargabad segment; WEST grows faster late in the sample, so retain this metric for a full-round rather than tune from this window.
- The RM-70 artillery, fast-travel/upgrade-clobber, Balota runway, and hourly-ideation cards were inspected before writing this report.  Their confirmed scopes are not duplicated here.  The direct RealPlayersNear packaging/runtime failure and the founding-pass timing follow-up are distinct.
- No code fix is included in this documentation PR.  This report is the evidence handoff; any implementation must be a separately claimed, source-first/mirrored draft PR.

## Source / evidence index

- `Common/Init/Init_Common.sqf:104` -- RealPlayersNear registration.
- `Common/Functions/Common_RunCommanderTeam.sqf:3012-3016` -- top-defer consumer.
- `Server/Server_GuerAirDef.sqf:186-207, 970-974` -- sliced active-time accounting.
- `Server/AI/Commander/AI_Commander_Teams.sqf:1648-1650` -- founding-pass telemetry.
- `Server/FSM/cleaners/droppeditems_cleaner.sqf:28-34, 95-100` -- startup deferral and measurement.
- Merges inspected: #1471 `095fea399e`, #1473 `23e40c7ead`, #1476 `4c37c287f0`, #1478 `733f07ce34`, #1481 `00edfb7219`, #1483 `459c2dcb3c`.
