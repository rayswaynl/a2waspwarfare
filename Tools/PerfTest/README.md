# PerfTest — salvaged A/B perf-test harness (WASP_PerfON/OFF_TEST.Chernarus)

**Provenance:** recovered 2026-07-08 from loose, never-committed files in `C:\Users\Game\` on the Game PC
(single test session dated 2026-06-07; run by a prior agent session, referenced in
`docs/project-management/RPT-DEEP-DIVE-2026-07-06/boot-forensics.md`). The runtime it targeted
(`C:\WASP\*`, service `Arma2OA-PR8`, scheduled task `WaspServiceRestart`) has since been
**decommissioned on that box** — the paths inside `perftest-ctl.ps1` are stale and must be
re-pointed before any reuse. Salvaged per the same never-lose-unversioned-work precedent as
`Tools/Ops/Update-PublicStats.ps1` (PR #905).

## Contents
- `perftest-ctl.ps1` — the A/B driver: stops the server service, swaps in the PerfON/PerfOFF
  mission variant (rewrites the `class Missions` block in `server-pr8.cfg`), restarts, captures RPTs.
- `missions/WASP_PerfOFF_TEST.Chernarus/` — the full control-mission tree (873 files; a dated
  Chernarus snapshot from the 2026-06/07 era — NOT synced to current master; treat as a fixture).
- `missions/PerfON.delta/Common/Init/Init_CommonConstants.sqf` — the ONLY file that differs in the
  PerfON variant (953-file trees, SHA-verified identical elsewhere).
- `baselines/rptA-off.txt`, `baselines/rptB-on.txt` — the captured server RPTs from the original run.

## The entire ON-vs-OFF experiment = 3 flag flips
| Flag | OFF | ON | What it does |
|---|---|---|---|
| `WFBE_C_LOOP_PHASE_JITTER` | 0 | 1 | staggers heavy server loops' tick phases (town capture/activation sweeps, groupsGC, dead collector, side patrols) so they stop landing on the same frames |
| `WFBE_C_TOWN_CAMP_ACTIVE_GATE` | 0 | 1 | a dormant town's camp-scan loop idles until the town is active/threatened |
| `WFBE_C_TOWN_SCAN_DICE` | 0 | 1 | dormant towns dice-roll (p=0.5/side/sweep) whether to run the 600 m activation nearEntities scan |

## Fast-bench context (owner directive 2026-07-08)
Custom test missions are the standard bench for future behaviour/UI iteration (full-mission soaks
remain for ship-validation only). Related, already-in-repo affordances: the `WF_Debug` build flag in
`version.sqf.template` (instant funds/tiers, 3s votes, `[`+map-click teleport) and
`WFBE_C_TEST_POPTIER_PIN` (skip the population warm-up ramp). A trimmed “2 teams + 1 town”
scenario gate is the missing piece (planned: `WFBE_C_TEST_SCENARIO_PIN`-style, effort S).

## Secret-scan note
Full-tree scan performed at salvage time: 85 pattern hits, all false positives (game-vocabulary
"token" = FOB/buy/queue tokens in comments/identifiers). No credentials, webhooks, or keys.
