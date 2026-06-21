# AI Commander Execution Loop Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the live, always-running per-side AI commander on stable master: the supervisor tick loop in `Server/AI/Commander/AI_Commander.sqf` and the seven workers it dispatches (`AI_Commander_Execute`, `_AssignTowns`, `_Strategy`, `_Base`, `_Teams`, `_AssignTypes`, `_Produce`, plus the externally-compiled `Server_AI_Com_Upgrade`). It is the runtime counterpart to the branch-status [AI Commander autonomy audit](AI-Commander-Autonomy-Audit), which names these files but does not document their internals. The audit was pinned to the old `feat/ai-commander` branch and predates the supervisor landing on master; on current master the supervisor is real, spawned at `Server/Init/Init_Server.sqf:847`, and sets `wfbe_aicom_running` at `AI_Commander.sqf:127`.

The model is one supervisor per commanding side (WEST/EAST; RESISTANCE is excluded because it has no HQ — `Init_Server.sqf:847`). Each supervisor decides every tick whether it is in FULL command (no human commander), ASSIST/hybrid (human commander present, executor only), or STOPPED (disabled or HQ dead), then fans out to its workers on per-worker cadences.

## Boot and compile

The eight worker functions are compiled once during server init, then the supervisor is spawned per side.

| What | Source | Detail |
| --- | --- | --- |
| Worker compile block | `Server/Init/Init_Server.sqf:55-64` | `WFBE_SE_FNC_AI_Com_Upgrade` (from `Server/Functions/Server_AI_Com_Upgrade.sqf`), `_AssignTypes`, `_AssignTowns`, `_Produce`, `_Execute`, `_Base`, `_Teams`, `_Strategy`, and the supervisor `WFBE_SE_FNC_AI_Commander` are all `Compile preprocessFileLineNumbers`. |
| Supervisor spawn | `Server/Init/Init_Server.sqf:847` | `{_x Spawn WFBE_SE_FNC_AI_Commander} forEach (WFBE_PRESENTSIDES - [resistance])` — one supervisor thread per present commanding side. |
| Wildcard spawn (sibling) | `Server/Init/Init_Server.sqf:850-853` | A separate `WFBE_SE_FNC_AI_Commander_Wildcard` loop runs only if `WFBE_C_AI_COMMANDER_WILDCARD == 1` and the commander is enabled. Not part of the tick loop documented here. |

## The supervisor tick (`AI_Commander.sqf`)

`WFBE_SE_FNC_AI_Commander` takes `_this = side` (`AI_Commander.sqf:17`). It resolves the side logic via `WFBE_CO_FNC_GetSideLogic` and exits if absent (`:18-19`), then `waitUntil`s for `serverInitFull` before commanding (`:23`). On first run it picks a doctrine and injects a research program (below), then enters `while {!gameOver}` at `:87` and sleeps `WFBE_C_AI_COMMANDER_TICK` (default 15 s) at the bottom of every iteration (`:447`).

| Step | Source | Behavior |
| --- | --- | --- |
| Active gate | `AI_Commander.sqf:88-91` | `_active` is true only when `WFBE_C_AI_COMMANDER_ENABLED > 0` AND the side HQ (`WFBE_CO_FNC_GetSideHQ`) is alive. Otherwise the loop falls to the STOPPED branch. |
| Human-commander detection | `AI_Commander.sqf:94-98` | Reads the commander team via `WFBE_CO_FNC_GetCommanderTeam`; `_humanCmd` is true only if `isPlayer (leader _cmdTeam)`. |
| Commander LOCK override | `AI_Commander.sqf:100-104`, `:83-85` | When `WFBE_C_AI_COMMANDER_LOCK > 0` (default 1, `Init_CommonConstants.sqf:106`), `_humanCmd` is forced false so the AI retains full command even if a human occupies the slot (eval/night protection). |
| Human-just-left cleanup | `AI_Commander.sqf:106-112` | On the transition `_prevHuman && !_humanCmd`, every team in `wfbe_teams` is reset to `"towns"` move mode (`SetTeamMoveMode`) and its `wfbe_exec_sig` cleared, so full-auto retakes cleanly. |
| Build-grace tracker (B36) | `AI_Commander.sqf:114-122` | `_noHumanSince` records when the side last went human-commander-less (`-1` while a human commands). `_canBuild` is true only once `(time - _noHumanSince) >= WFBE_C_AI_COMMANDER_BUILD_GRACE` (default 300 s, `Init_CommonConstants.sqf:131`). Re-armed each time a human commander leaves. |
| State + running latch | `AI_Commander.sqf:124-131` | `_state` is `"assist"` under a human, else `"full"`. On any state change the supervisor sets `wfbe_aicom_running` to `!_humanCmd` — the full-command latch. This is the flag the audit said master never sets. |
| STOPPED branch | `AI_Commander.sqf:251-257` | When `_active` is false, clears `wfbe_aicom_running` to false once and logs `STOPPED (disabled / HQ down)`. |

### Doctrine pick and research program

On the first tick (guarded by `isNil` on `wfbe_aicom_doctrine`, `AI_Commander.sqf:26`):

| Element | Source | Behavior |
| --- | --- | --- |
| Doctrine | `AI_Commander.sqf:26-29` | Randomly `"HF"` (heavy-factory) or `"LF"` (light-factory), stored on the side logic as `wfbe_aicom_doctrine`. This is the primary factory path the AI builds and templates around. |
| Research program inject | `AI_Commander.sqf:36-53` | Builds an 11-entry `[upgradeId, level]` program (Barracks/doctrine-factory/Gear/Patrols, rushing the doctrine factory and Gear to 3) and **prepends** it to `WFBE_C_UPGRADES_<side>_AI_ORDER`. The upgrade worker always takes the first not-yet-reached entry, so a prepended program *is* the strategy. Duplicates in the tail are harmless (reached levels are skipped). |
| Experital scaffold (Convoys) | `AI_Commander.sqf:55-65` | Nil-guarded: appends `[WFBE_UP_PATROLS,4]` only if the side's LEVELS array shows PATROLS max >= 4. No-op on this mission. |
| Reactive CBR (deferred) | `AI_Commander.sqf:66-69`, `:237-249` | CBRADAR research is NOT appended at boot; it is appended once in the main loop (`:240-248`) the first tick after `wfbe_aicom_arty_threat` is set, if `WFBE_UP_CBRADAR` exists. |

### Worker dispatch table

The executor runs every tick. Town auto-assign is throttled but runs in both FULL and ASSIST. The economy/build workers run only when `_canBuild` (FULL command past the build-grace window). All intervals default from `Init_CommonConstants.sqf`.

| Worker call | Gate | Cadence (default) | Source |
| --- | --- | --- | --- |
| `WFBE_SE_FNC_AI_Com_Execute` | every active tick | tick rate (15 s) | `AI_Commander.sqf:134` |
| `WFBE_SE_FNC_AI_Com_AssignTowns` | active (self-gates per team) | `WFBE_C_AI_COMMANDER_TOWN_INTERVAL` = 120 s | `AI_Commander.sqf:137-139` |
| `WFBE_SE_FNC_AI_Com_Strategy` | `_canBuild` | `STRATEGY_INTERVAL` = 60 s | `AI_Commander.sqf:146-148` |
| `WFBE_SE_FNC_AI_Com_Base` | `_canBuild` | `BASE_INTERVAL` = 60 s | `AI_Commander.sqf:150-152` |
| `WFBE_SE_FNC_AI_Com_Teams` | `_canBuild` | `TEAMS_INTERVAL` = 90 s | `AI_Commander.sqf:154-156` |
| `WFBE_SE_FNC_AI_Com_AssignTypes` | `_canBuild` | `TYPES_INTERVAL` = 30 s | `AI_Commander.sqf:157-159` |
| `WFBE_SE_FNC_AI_Com_Upgrade` | `_canBuild` AND `!wfbe_upgrading` | `UPGRADE_INTERVAL` = 120 s | `AI_Commander.sqf:160-163` |
| `WFBE_SE_FNC_AI_Com_Produce` | `_canBuild` | `PRODUCE_INTERVAL` = 45 s | `AI_Commander.sqf:164-166` |

### In-loop economy controllers

Three economy controllers run inside the `_canBuild` block after the worker dispatch:

| Controller | Source | Behavior |
| --- | --- | --- |
| Adaptive spend (P4 wealth conversion) | `AI_Commander.sqf:168-193` | When funds exceed `WFBE_C_AI_COMMANDER_FUNDS_PER_EXTRA_TEAM * 2` (`_richThreshold`) AND all team targets are met, sets `wfbe_aicom_reinforce_rich` so Produce doubles its batch cap. Uses transition `if/else` (A2 has no `==`/`!=` on Bool). |
| Bootstrap stipend (V0.7) | `AI_Commander.sqf:195-235` | While the side owns 0 towns AND `time < WFBE_C_AICOM_BOOTSTRAP_MAXTIME` (3600 s), trickles `WFBE_C_AICOM_BOOTSTRAP_FUNDS` (100/min) via `ChangeAICommanderFunds` and, in dual-currency mode, `BOOTSTRAP_SUPPLY` (50/min) via `ChangeSideSupply`. Grants once per 60 s, scaled to actual tick spacing (capped at 3x) so a missed tick doesn't drop income. |
| Reactive CBR research | `AI_Commander.sqf:237-249` | Appends `[WFBE_UP_CBRADAR,1]`/`[,2]` to the AI upgrade order once, the first tick after `wfbe_aicom_arty_threat`. No-op without the CBR constant. |

### Telemetry (AICOMSTAT)

Ungated (always flows regardless of LOG setting), the supervisor emits a block of `diag_log` lines every 300 s (`AI_Commander.sqf:259-392`), plus once-per-round lines.

| Line | Source | Content |
| --- | --- | --- |
| `AICOMSTAT|v1|TICK` | `AI_Commander.sqf:260-294` | 5-min snapshot: elapsed min, towns held, supply, funds, founded teams, editor teams, upgrade CSV, live unit count (from the `wfbe_units_<side>` cache). |
| `ECONOMY` / `ECONFLOW` | `AI_Commander.sqf:296-334` | Net funds/supply change since last window; player-team vs AI wallet split. |
| `CMDRSTAT` | `AI_Commander.sqf:338-369` | Server-local vs HC-delegated team split + 2-man-remnant fragmentation. |
| `COMBATSTAT` | `AI_Commander.sqf:371-391` | Per-side attrition delta from the free `WF_Logic` cumulative counters. |
| `SRVPERF` / `GRPBUDGET` / `HCDELEG` | `AI_Commander.sqf:394-445` | Server-global perf line; per-side group count vs the 144/side cap (WARN at `WFBE_C_GROUP_BUDGET_WARN`); per-HC owned-unit load and imbalance ratio. Throttled once per 300 s on `wfbe_srvperf_t`. |
| `ROUND OVER` / `AICOMSTAT|END` / `ROUNDSTAT` | `AI_Commander.sqf:450-470` | One verdict line per side after `gameOver`, plus a single guarded server-global round summary. |

## Workers

Each worker takes `_this = side`, resolves `WFBE_CO_FNC_GetSideLogic`, and reads the team registry `wfbe_teams` (an index-aligned array whose wiped-HC entries are nulled, not removed — every team loop guards `!isNull`).

| Worker | Source / size | Returns | Behavior |
| --- | --- | --- | --- |
| Execute | `AI_Commander_Execute.sqf` (57 ln) | none | Order executor; runs every tick (FULL and ASSIST). For each non-player, alive AI team it reads `wfbe_teammode`; for `move`/`patrol`/`defense` with a real `wfbe_teamgoto` destination it issues a waypoint via `AIMoveTo` (`MOVE`/`SAD`/`HOLD`, radius 50/150/30). Idempotent: an unchanged `wfbe_exec_sig` is not re-issued (`:40-49`). `towns`/`""` modes are left to AssignTowns; `SetTeamMoveMode`/`SetTeamMovePos` only store vars, so this is the path that makes the command bar work. |
| AssignTowns | `AI_Commander_AssignTowns.sqf` | none | Sends idle teams at the nearest uncaptured town. Hybrid detection (`:23-28`): `_humanCmd` is computed but is only referenced in the optional garrison logic (`:138`), where it suppresses garrison assignment while a human commands. Since B36 (2026-06-15), `_canDrive` is set to `true` for every non-player-led team unconditionally (`:122-131`) — the former DELEGATED/autonomous-only filter under a human commander is no longer present. All non-player-led teams receive town orders regardless of human commander presence. Filters towns whose `sideID != _sideID` (`:30-33`); exits if none. V0.8 TRUE CONCENTRATION (`:38-61`) pre-seeds `_assigned` with the live `wfbe_aicom_townorder` target of every team already marching, so the per-town spearhead cap reflects real committed mass and rolls freed teams to the next town. Uses the arc-approach planner when `WFBE_C_AI_COMMANDER_USE_ARC_APPROACH > 0`, else the `AIMoveTo` fallback (`:35`). V0.7 bootstrap bias when the side owns 0 towns (`:63-66`). |
| Strategy | `AI_Commander_Strategy.sqf` | publishes `wfbe_aicom_targets` | War-strategy worker, FULL only. (1) SPEARHEADS: scores enemy/neutral towns by nearest-to-front with a small enemy-HQ pull and a far-penalty deprioritiser, publishing `wfbe_aicom_targets` for AssignTowns to concentrate on (`:46-60`). (2) REACTIVE DEFENSE: diverts the nearest free team to relieve own towns flagged `wfbe_active`. (3) HQ HUNT: when clearly winning, peels the strongest teams into a strike force on the enemy HQ so AI-vs-AI rounds end. (4) ARTILLERY: fires base guns at the spearhead town/enemy HQ, gated on no friendlies near impact (`:1-16`). Exits early if the enemy side is not in `WFBE_PRESENTSIDES` (`:31`). |
| AssignTypes | `AI_Commander_AssignTypes.sqf` | sets `wfbe_teamtype` | Picks a random UNLOCKED `WFBE_<side>AITEAMTEMPLATES` index for each unassigned team (a team needs a `wfbe_teamtype` before Produce can build for it). Eligibility = all four `[barracks,light,heavy,air]` min-upgrade levels in `WFBE_<side>AITEAMUPGRADES` met vs `WFBE_CO_FNC_GetSideUpgrades` (`:42-49`). Skips player-led and HC-resident teams (`:38`). Factory availability is not checked here on purpose; Produce no-ops gracefully when the factory is missing. P1 combined-arms weighting nudges toward the doctrine vehicle track (`:51-`). |
| Produce | `AI_Commander_Produce.sqf` | none | Reinforces under-strength teams via `AIBuyUnit`, within the per-side AI ceiling `WFBE_C_AI_COMMANDER_TOTAL_AI_MAX` (72) — exits if `_sideAI >= _cap` (`:27-30`). Batch cap is `WFBE_C_AICOM_PRODUCE_BATCH` (default 3), DOUBLED when `wfbe_aicom_reinforce_rich` is set (`:22-25`). Builds the first template unit a team is short on at an alive factory of the right kind (Barracks/Light/Heavy, plus Aircraft once the side holds `WFBE_C_AICOM_AIR_MIN_TOWNS` towns, `:43-52`). Reinforce-range gated: leaders beyond `REINFORCE_RANGE` (1200) only refill if hugging an owned town within `FWD_REINFORCE_RANGE` (500) (`:70-86`). HC-resident teams are produced whole on the HC, never here (`:62-63`). |
| Base | `AI_Commander_Base.sqf` | none | Deploys the HQ and builds the base on the doctrine, FULL only. Exits unless the side HQ is alive (`:20-21`). Costs are paid from side supply (server-deducted, mirroring a human COIN build, `:23-24`). One construction per call (gentle supply drain, no build spam). Deploys the MHQ first, nudging off-road/out-of-water within 20 tries before falling back to the raw start spot (`:32-50`), then follows the doctrine build order into defenses, with gated artillery/CBR/bank structures. |
| Teams | `AI_Commander_Teams.sqf` | sets `wfbe_aicom_pending`, `wfbe_aicom_dyntarget` | Founds new AI combat teams up to the side target, FULL only. Counts FOUNDED teams (`wfbe_aicom_hc` or `wfbe_aicom_founded`) separately from editor-slot teams so editor population never blocks founding (`:33-53`). Target = base + funds-extra (`floor(funds / FUNDS_PER_EXTRA_TEAM)`, capped at `TEAMS_MAX_EXTRA`, `:56-64`), then OVERRIDDEN by a B36.1 player-count curve (`WFBE_C_AICOM_TEAMS_PC_*`, more humans = fewer AI teams, `:66-86`) and lifted by the B37 banking valve at low/mid pop (`:88-95`). When a live HC is registered, whole teams are produced on the HC (`delegate-aicom-team`); otherwise it founds an empty server-local group that AssignTypes/Produce then fill (`:1-17`). |

## A2/OA notes

- The supervisor uses `Spawn` (capitalized wrapper), `Compile preprocessFileLineNumbers`, `Call`, and `getVariable [name, default]` throughout — all valid A2 OA forms. Null-group `getVariable [name,default]` returns nil (not the default) in 1.64, which is why every worker team-loop guards `!isNull _team` (e.g. `AI_Commander_Execute.sqf:18-25`, `AssignTypes:32-34`).
- Bool operands do not support `==`/`!=` in A2; the wealth-conversion and stipend controllers use transition `if/else` against a cached `_prev*` flag instead (`AI_Commander.sqf:184-193`).
- Group-bool reads go through `WFBE_CO_FNC_GroupGetBool` rather than a 2-arg `getVariable` on the group.

## Continue Reading

- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit)
- [AI Runtime And HC Loop Map](AI-Runtime-HC-Loop-Map)
- [Upgrade Queue Server Loop Reference](Upgrade-Queue-Server-Loop-Reference)
- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas)
- [Side Team State Function Reference](Side-Team-State-Function-Reference)
- [Headless Delegation And Failover Playbook](Headless-Delegation-And-Failover-Playbook)
