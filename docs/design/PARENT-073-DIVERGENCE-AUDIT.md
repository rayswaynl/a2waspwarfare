# Parent 2.073 LiteCO Divergence Audit

Lane: 207  
Branch: `codex/lane207-parent-073-divergence-audit`  
Target: `origin/claude/build84-cmdcon36@3ac68b5dccbd28f4b79f938ac969a3d80d2bf4fe`  
Parent source: `WarfareV2_073LiteCO.zip` from the upstream `BennyBoy-/ArmA2_WarfareBE` `cti` release  
Parent asset URL: <https://github.com/BennyBoy-/ArmA2_WarfareBE/files/7354986/WarfareV2_073LiteCO.zip>  
Parent zip SHA-256: `212048B93831A711BF896679069CF1DFF9B3726B28238DAC52CA82729CA58E0A`  

## Scope

This pass unpacked the upstream 2.073 LiteCO Chernarus PBO outside the repository and compared it against the current WASP Chernarus mission. It was intentionally docs-only: no mission SQF, mission metadata, PBO contents, or generated assets are changed here.

The goal was not to rebase WASP onto the parent mission. It was to identify whether any narrow parent behavior should be borrowed, whether current WASP divergence is intentional and safer, and where future agents should avoid accidental rollback.

## Verdict Summary

| Area | Parent 2.073 behavior | Current WASP behavior | Verdict |
| --- | --- | --- | --- |
| Attack-path helper safety checks | `Server_AI_SetTownAttackPath_PathIsSafe.sqf` and `Server_AI_SetTownAttackPath_PosIsSafe.sqf` match the current helpers. | Same helper logic is already present. | No borrow needed. |
| Attack-path waypoint generation | `Server_AI_SetTownAttackPath.sqf` can exit a 30% branch without adding the selected first waypoint, uses mostly `NORMAL` speed, and gives depot SAD waypoints a 150m random radius. | Current WASP adds the selected waypoint before that early exit, threads `WFBE_C_AICOM_MARCH_YELLOW`, uses `FULL` transit speed, and tightens depot SAD to 60m/`COMBAT`/`RED`. | Keep WASP divergence. Parent is a useful baseline only. |
| Town capture FSM | Parent `server_town.fsm` uses a simple 40m height scan, unguarded `supplyValue` reads, classic capture drain, and direct capture side effects. | Current `server_town.sqf` has default guards for missing supply/camp values, PerformanceAudit hooks, naval-HVT/deck-aware height handling, airfield/hangar capture support, mopup, lazy garrison, and safer capture side effects. | Do not borrow parent wholesale. Parent would roll back live fixes. |
| Town activation/deactivation FSM | Parent `server_town_ai.fsm` directly spawns/deletes town AI, keeps per-town patrol FSM support, and has simpler active flags. | Current `server_town_ai.sqf` adds activation budgets, population tiers, headless-client delegation, PerformanceAudit, episode spawn latches, local `!isPlayer` cleanup guards, sorties, and retires town-patrol FSM gating in favor of side patrols. | Do not borrow parent. Keep current safeguards. |
| AI commander upgrade helper | Parent `Server_AI_Com_Upgrade.sqf` charges funds with `_cost select 0` and side supply with `_cost select 1`, and blocks on the first queued upgrade even if a later one is affordable. | Current WASP prices by current level, applies the supply reserve floor, can pick the first affordable queued upgrade, logs AICOMSTAT research/exhaustion, and charges funds/supply with the corrected indices. | Do not borrow parent. Current helper explicitly fixes parent-era economy bugs. |
| Upgrade config check/labels | Parent `Check_Upgrades.sqf` matched current Chernarus in the direct diff. | Current upgrade check file is already parent-equivalent for this audit slice. | No borrow needed. |
| Monolithic AI commander FSM | Parent `Server/FSM/aicommander.fsm` owns HQ status, base construction, base defenses, upgrade cadence, team type assignment, workers, and relocation in one FSM. | Current WASP uses `Server/AI/Commander/AI_Commander.sqf` plus split workers for base, teams, strategy, allocation, production, execute, player artillery, paratroops, MHQ relocation, funds sink, and related telemetry compiled in `Server/Init/Init_Server.sqf`. | Treat parent FSM as historical reference only. Direct merge is unsafe. |

## Detailed Notes

### Attack Paths

The parent and current path-safety helpers are already equivalent, so there is no missing safety predicate to port. The meaningful divergence is in `Server_AI_SetTownAttackPath.sqf`.

The parent transit path sometimes exits before adding `_wp_sel`; current WASP first pushes the selected waypoint, then exits the branch. Current WASP also adds a march-combat mode read from `WFBE_C_AICOM_MARCH_YELLOW` and moves transit waypoints with `FULL` speed instead of the parent `NORMAL` patterns. The depot search-and-destroy waypoint is deliberately tighter and more aggressive in WASP: 60m, `COMBAT`, `RED`, instead of the parent 150m and lighter posture.

Recommendation: keep the current WASP attack-path file. If future path regressions appear, compare against parent for shape, but do not restore the parent early-exit behavior.

### Town Capture

The parent `server_town.fsm` is a clean baseline for classic Warfare capture logic, but it lacks many current fork protections. In particular, current `server_town.sqf` guards missing `supplyValue` and camp/rate values, emits capture-scan PerformanceAudit telemetry, supports naval HVT deck capture height, handles airfield capture unlocks/hangars/CB radar, and contains cleanup/garrison extensions.

The parent 40m `unitsBelowHeight` scan is not a safe universal improvement. WASP intentionally uses a normal lower capture height and special deck-aware handling for naval HVT cases. Reverting to parent would also discard the current Zargabad/missing-var hardening.

Recommendation: no parent town FSM borrow in this lane. Keep town-capture behavior changes scoped to current WASP mechanics and current docs such as `docs/design/NO-TOWN-UNCAPTURABLE.md` and `docs/design/SPREAD-AND-HOLD.md`.

### Town AI Activation

Parent `server_town_ai.fsm` is simpler and easier to read, but the current SQF version carries the important operational state: town activation budgets, episode spawn latches, headless-client paths, population tiers, PerformanceAudit, and safer cleanup. Parent also still references per-town patrol FSM behavior that current WASP has explicitly retired in favor of `server_side_patrols.sqf` and sortie-style town defenders.

Recommendation: do not revive parent per-town patrol wiring or parent direct deletion cleanup. If a future bug needs a small parent comparison, use it only as a reference for classic activation cadence.

### AI Commander And Upgrades

The parent `aicommander.fsm` shows the original single-FSM design: check HQ, deploy/repair/move HQ, update base structures, update defenses, update upgrades, update team types, update workers, then loop. Current WASP has replaced that with `AI_Commander.sqf` as a supervisor and separate workers for build, team founding, allocation, strategy, production, execution, MHQ relocation, player artillery, paratroops, and telemetry.

The direct upgrade-helper diff is especially important. Parent `Server_AI_Com_Upgrade.sqf` still has the old economy behavior:

- funds are debited with `_cost select 0`;
- side supply is debited with `_cost select 1`;
- the first unaffordable queued upgrade can stall the whole program.

Current WASP explicitly documents and fixes those problems with reserve-gated affordability, corrected cost indices, affordable-queue selection, AICOM telemetry, and current-level pricing.

Recommendation: treat the parent AI commander FSM and parent upgrade helper as reference history only. The current split commander code is the source of truth.

## Borrow Candidates

None found in this pass.

## Guardrails For Future Agents

- Do not use parent 2.073 LiteCO as a blanket rollback source for AICOM, town capture, or town activation.
- Do not reintroduce parent `Server_AI_Com_Upgrade.sqf` charging semantics.
- Do not revive parent per-town patrol FSMs without first reconciling `server_side_patrols.sqf`, sortie logic, HC delegation, and active-town budgets.
- Use parent files as comparison fixtures when diagnosing regressions, but merge only narrow, tested behavior.

## Verification

- Confirmed source branch was clean before adding this docs-only report.
- Downloaded and hashed upstream `WarfareV2_073LiteCO.zip` outside the repo.
- Unpacked `WarfareV2_073LiteCO.Chernarus.pbo` outside the repo with `E:\arma2-cache\tools\unpbo.py` for text comparison.
- Compared attack-path helpers, town FSMs, town AI FSMs, upgrade helper/config, and parent AI commander FSM against current WASP Chernarus files.
