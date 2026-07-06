# AICOM V2 Migration / Port Map

Guide rev: GR-2026-07-03a. Scope: final-form migration spec only.

Purpose: prevent Fable from either re-implementing dead V1 behavior or dropping required live behavior. Every row names the V2 home layer and the required port action.

Port actions:

| Action | Meaning |
|---|---|
| Lift As-Is | Keep behavior and current semantics, only move behind V2 data/interface shape. |
| Refactor | Keep intent, replace implementation shape to satisfy locality/pure-core/profile requirements. |
| Drop-Intentional | Do not port. Row must state why and replacement/owner rationale. |

## Supervisor and mandatory workers

Source cadence evidence: `AI_Commander.sqf:274-544` dispatches workers; `Init_CommonConstants.sqf:307-313`, `:557`, `:614`, `:736`, `:872` define live cadences.

| V1 behavior | Source evidence | V1 cadence/gate | V2 home | Action | V2 final form |
|---|---|---|---|---|---|
| Supervisor side loop | `AI_Commander.sqf:3`, `:15`, `:160` | One server-side instance per present side; active gate pauses parts when human owns command | Execution supervisor | Refactor | New `AI_Commander_V2.sqf` runs per side only when `WFBE_C_AICOM_V2_ENABLE > 0`; V1 supervisor stays untouched for flag-off rollback. |
| Worker phase jitter | `AI_Commander.sqf:44-50`; constant `WFBE_C_AICOM_SUPERVISOR_JITTER` at `Init_CommonConstants.sqf:1168` | Random start offset up to 7s | Execution supervisor | Lift As-Is | Keep jitter. Harness requires WEST/EAST first-tick offset >= 5s PASS. |
| Execute worker | `AI_Commander.sqf:274`; `AI_Commander_Execute.sqf:6`, `:71-100` | Every supervisor pass while active | Execution | Refactor | Execution consumes V2 decision records and writes `wfbe_aicom_order = [seq,mode,pos,radius,targetId,why]`; server-local teams still use SetTeamMoveMode/SetTeamMovePos compatibility. |
| PlayerArty worker | `AI_Commander.sqf:279`; `AI_Commander_PlayerArty.sqf:72` | Every pass if function exists | Planning/Execution fire-support | Refactor | Move target selection into planning; execution only fires already-owned arty. Keep no-cheat intel gate. |
| Paratroops worker | `AI_Commander.sqf:286-287` | `WFBE_C_AI_COMMANDER_TOWN_INTERVAL` 120s | Planning/execution special insertion | Refactor | Fold into V2 fire/support/insertion decisions; no independent scheduler. |
| AssignTowns worker | `AI_Commander.sqf:379-380`; `AI_Commander_AssignTowns.sqf:106`, `:149`, `:693-761` | `WFBE_C_AI_COMMANDER_TOWN_INTERVAL` 120s | Planning | Refactor | Becomes pure target/team assignment over `WorldState` + `Assessment`. Execution applies orders. Preserve arrival/stranded telemetry. |
| HCTopUp/merge worker | `AI_Commander.sqf:453-454`; constants `WFBE_C_AICOM_HC_MERGE_*` at `Init_CommonConstants.sqf:1182-1187` | `WFBE_C_AICOM_HC_MERGE_INTERVAL` 120s; enabled by merge/topup flags | Planning/Execution lifecycle | Refactor | Planning emits `merge` or `refit/topup` decisions. Execution sends HC merge/topup payload. Default merge remains off unless owner flips. |
| Teams worker | `AI_Commander.sqf:470-471`, `:533-534`; `AI_Commander_Teams.sqf` | `WFBE_C_AI_COMMANDER_TEAMS_INTERVAL` 90s | Planning/Execution economy-lifecycle | Refactor | Pure planner decides founding intent and team type; execution creates group and delegates. Uses map profile caps. |
| Produce worker | `AI_Commander.sqf:474-475`, `:543-544`; `Init_CommonConstants.sqf:309` | `WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL` 45s | Planning/Execution economy-lifecycle | Refactor | Planning chooses spend/refit/topup budget; execution performs existing CreateUnit/CreateVehicle paths. Must honor "money is pressure" spend floor. |
| DisbandLowTier worker | `AI_Commander.sqf:484-485`; `Init_CommonConstants.sqf:736`, ZG override `:1835` | `WFBE_C_AICOM_DISBAND_INTERVAL` 300s CH/TK, 150s ZG | Planning/Execution lifecycle | Refactor | V2 lifecycle manager owns all retire/merge decisions with TTL and player-proximity guard. |
| Snapshot worker | `AI_Commander.sqf:496` | Runs immediately before strategy tick | Perception | Lift As-Is concept, Refactor implementation | Replace with V2 perception record. Do not publish planner state from snapshot. |
| Strategy worker | `AI_Commander.sqf:494-498`; `Init_CommonConstants.sqf:557` | `WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL` 60s | Assessment/Planning | Refactor | Split into pure assessment and pure planning. Preserve outputs `_myStr`, `_enStr`, `wfbe_aicom_targets`, `wfbe_aicom_laststand` via execution compatibility writes. |
| MHQ relocation monitor | `AI_Commander.sqf:512-513`; `Init_CommonConstants.sqf:614` | `WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL` 180s | Planning/Execution base relocation | Refactor | Planning scores relocation utility; execution runs existing drive/deploy mechanics. Preserve `DEPLOYED` telemetry and abort TTL. |
| BaseSell worker | `AI_Commander.sqf:518-519`; `Init_CommonConstants.sqf:637` | Default-off gate `WFBE_C_AICOM_BASE_SELL_ENABLE`, 120s | Planning/Execution economy | Lift As-Is if flag enabled | Keep disabled by default. If enabled, V2 plans rare sell decisions; execution owns mutation. |
| Base worker | `AI_Commander.sqf:522-523`; `Init_CommonConstants.sqf:312` | `WFBE_C_AI_COMMANDER_BASE_INTERVAL` 60s | Planning/Execution base/economy | Refactor | Planning chooses build order from profile and threat; execution performs current build path. |
| SpawnBeacon worker | `AI_Commander.sqf:529-530`; `Init_CommonConstants.sqf:872` | Default-off `WFBE_C_AICOM_SPAWNBEACON_ENABLE`, 120s | Planning/Execution visible pulse | Drop-Intentional initially | Leave dark in V2 one-shot. It is a feature add, not required commander core. Replacement: no-dead-air pulse can use attack, arty, radio, wildcard first. |
| AssignTypes worker | `AI_Commander.sqf:536-537`; `Init_CommonConstants.sqf:310` | `WFBE_C_AI_COMMANDER_TYPES_INTERVAL` 30s | Planning/economy | Refactor | Convert to pure team-type demand planner keyed by target, threat, profile and spend floor. |
| Upgrade worker | `AI_Commander.sqf:539-540`; `Init_CommonConstants.sqf:307` | `WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL` 300s and `wfbe_upgrading` gate | Planning/economy | Refactor | Replace static order injection with goal-driven research plan. Preserve one-upgrade-at-a-time guard. |
| Wildcard supervisor sibling loop | `Init_CommonConstants.sqf:560`; wildcard files outside main loop | 900s per side | Planning/Execution pulse director | Refactor | Integrate as V2 escalation/no-dead-air director. It remains a sibling only if flag-off V1 path is active. |

## Required behavior rows

| Behavior | Source evidence | V2 home | Action | Final migration instruction |
|---|---|---|---|---|
| Doctrine pick | `AI_Commander.sqf` boot program block and comments around doctrine/order | Planning profile | Refactor | Do not port as "personality". Convert to profile and skill-dial scalars: aggression, spend floor, attack-superiority threshold, tempo. Owner rejected doctrine personalities. |
| Research-program inject | `AI_Commander.sqf:591` notes the same AI upgrade function path; upgrade order arrays in core upgrade files | Planning economy | Refactor | V2 build planner emits ordered research intents from threat mix. Existing `WFBE_SE_FNC_AI_Com_Upgrade` remains execution backend. |
| Bootstrap stipend | `AI_Commander.sqf:418-442` | Planning/economy | Lift As-Is | Keep initial funds/supply stabilization but log into V3 constants/boot telemetry. |
| Adaptive spend/banking valve | `Init_CommonConstants.sqf:338-356`; `AI_Commander.sqf:550` rich threshold | Planning/economy | Refactor | Preserve intent, but V2 spend floor is posture-keyed. Harness fails hoard+lose. |
| Reactive CBR | `AI_Commander_Base.sqf:524`, `:595`; CBR min-time constant in init | Perception/Planning fire-support | Refactor | Perception records observable arty threat; planning chooses CBR build/research. Must reset threat on round boundary. |
| AICOMSTAT telemetry block | Many `AICOMSTAT|v1/v2` emits; `AI_Commander.sqf:998` WASPSCALE v2 | Execution telemetry | Lift As-Is plus extend | Keep all retained V1/V2 events parseable. Add V3 heartbeat/profile/WHY events. |
| AICOMHB heartbeat | Roster mandates v3; V1 lacks full heartbeat | Execution telemetry | Refactor | Emit `AICOMHB|v3|TICK` every strategy tick with gen/state/planSeq/decisions/cpuMs/profile. |
| Watchdog restart | Constants `WFBE_C_AICOM_WATCHDOG*` at `Init_CommonConstants.sqf:1163-1165` | Execution supervisor | Lift As-Is concept | V2 watchdog restarts only V2 side supervisor. Count >2 in one soak is FAIL. |
| HC founding path `delegate-aicom-team` | `Common_RunCommanderTeam.sqf:3`, `:84`, `:178`; Teams worker dispatches HC teams | Execution | Refactor | Server creates group, assigns stable primitive `groupKey`, then sends `delegate-aicom-team` payload with profileLite and first order. |
| HC merge path | `AI_Commander.sqf:453-454`; `Init_CommonConstants.sqf:1182-1187` | Execution lifecycle | Refactor | Keep default-off merge flag; if on, planning emits merge decision and execution sends `aicom-team-merge` to HC owner. |
| Capture-phase interrupt | `Common_RunCommanderTeam.sqf:1686`, `:2046-2076` | HC Execution | Lift As-Is | Keep local capture loop and order-seq interrupt behavior. Planning must never micro-manage camp loop. |
| MHQ relocation monitor | `AI_Commander_MHQReloc.sqf`; scheduler at `AI_Commander.sqf:512-513` | Planning/Execution | Refactor | Planning emits relocate intent with score and abort TTL. Execution owns vehicle drive/deploy. |
| Base-defense replace | `AI_Commander_Strategy.sqf:541-548`; `Server_HandleSpecial.sqf:705-706` | Planning/Execution defense | Refactor | V2 defense planner owns base security posture; execution writes `defense` order and HC `wfbe_aicom_order`. |
| HQ strike package | `AI_Commander_Strategy.sqf:708-757`, `:806-903`, `:975-978` | Planning/Execution endgame | Refactor | Treat order/gate/picker as atomic. Port only when all three are implemented: trigger, staging/mass gate, striker release. |
| Last-stand recall | `AI_Commander_Strategy.sqf:92-118` | Assessment/Planning defense | Refactor | Assessment computes laststand; planning emits defense orders. Execution writes compatibility `wfbe_aicom_laststand`. |
| Wedge watchdog | `AI_Commander_Strategy.sqf:566-610` | Planning lifecycle | Refactor | Keep safety, but suppress during laststand/HQ defense and emit WHY. |
| Factory rally set | `AI_Commander_Base.sqf:770` | Planning/Execution base | Lift As-Is | Keep rally placement as execution side effect from build planner. |
| Side-wide target blacklist | `Init_CommonConstants.sqf:1119-1127`; AssignTowns abandoned target flow | Assessment/Planning | Refactor | Port as side memory array with TTL and pain reason. |
| Stranded survivor merge | `Init_CommonConstants.sqf:1190-1195`; Produce/driver merge paths | Planning/Execution lifecycle | Refactor | V2 lifecycle owns, guarding slung/airborne units. |
| Service detour/self-service | `Init_CommonConstants.sqf:1129-1136`; `Common_RunCommanderTeam.sqf` service logic | HC Execution with planning guard | Lift As-Is | Keep local service execution. Planning should mark team `refit` and avoid retarget churn. |

## Intentional drops

| Dropped behavior | Evidence | Reason | Replacement |
|---|---|---|---|
| Dormant move-interval loop | `WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600` at `Init_CommonConstants.sqf:302`; no live worker dispatch in `AI_Commander.sqf:274-544` | Orphaned scheduler. Re-adding would create unexplained long-period order churn. | V2 movement planning via route graph and order hysteresis. |
| Independent paratroops scheduler as core worker | `AI_Commander.sqf:286-287` | Separate town-interval side effect conflicts with pure planning and legibility. | Fold into insertion/fire-support decisions with WHY and profile gates. |
| Spawn beacon as mandatory V2 behavior | `AI_Commander.sqf:529-530`, default-off flag | Feature add, default-off, not required for V2 commander core. | Escalation/no-dead-air director may later include it behind explicit flag. |
| Doctrine personalities | Roster owner constraint rejects doctrine personalities | Owner rejected. | Profile constants plus skill/handicap dial only. |
| Any supply-truck AI commander loop | Archive prior art mentions ancestral supply trucks, but owner constraints say do not re-propose AI supply trucks | Owner constraint. | Money pressure handled by spend floors and existing economy, not new AI supply trucks. |

## V2 implementation order

1. Boot flag and profile loader.
2. Perception record plus pure assessment harness.
3. Planning record with existing V1-equivalent decisions only.
4. Execution bridge to current `wfbe_aicom_order` and SetTeamMoveMode/SetTeamMovePos.
5. Telemetry v3 heartbeat/profile/WHY.
6. Add new doctrine features only after V1 parity harness passes.

## Flag-off proof requirement

Every migration PR must prove:

- `WFBE_C_AICOM_V2_ENABLE = 0` leaves V1 supervisor dispatch unchanged.
- No V2 variables are read by V1 code paths unless guarded behind V2 flag.
- No V2 profile variables overwrite current `WFBE_C_AICOM_*` globals.
- V1 telemetry remains parseable by current `Tools/Soak/analyze_soak.py`.
