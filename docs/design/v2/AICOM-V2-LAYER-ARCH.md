# AICOM V2 Layer Architecture Spec

Guide rev: GR-2026-07-03a. Scope: final-form design spec only. No gameplay code.

## Non-negotiable shape

AICOM V2 is a parallel brain behind `WFBE_C_AICOM_V2_ENABLE` default `0`. Flag `0` must leave the current V1 commander path byte-identical. Flag `1` boots V2 per side from the existing server-side commander spawn point, while V1 remains present and callable for rollback.

All decision state lives on the server-side side logic namespace. HC instances execute orders only. Assessment and planning functions are pure by contract: one serialized world-state array in, one serialized decision/order array out. All inter-layer payloads use A2 OA-safe primitives only: arrays, strings, numbers and booleans represented as `0`/`1`. Runtime SQF may resolve object/group references locally after the primitive record is read, but object refs must not cross a layer boundary as part of the V2 contract.

## Current ownership map

| Layer | V1 source owners today | V2 owning files to create | Notes |
|---|---|---|---|
| Perception | `AI_Commander_Snapshot.sqf`, reads in `AI_Commander_Strategy.sqf`, `AI_Commander_AssignTowns.sqf`, `AI_Commander_Base.sqf`; town globals from `Init_Town.sqf`; team globals from `wfbe_teams` | `Server/AI/Commander/V2/AI_Commander_V2_Perception.sqf` | Pulls world state defensively and serializes it. No planning decisions. |
| Assessment | `AI_Commander_Strategy.sqf` computes `_myStr`, `_enStr`, `_myTowns`, `_enemyTowns`, `wfbe_aicom_targets`, `wfbe_aicom_laststand`; `AI_Commander_Allocate.sqf` publishes allocator state | `Server/AI/Commander/V2/AI_Commander_V2_Assessment.sqf` | Pure transform from perception record to side assessment record. |
| Planning | `AI_Commander_Strategy.sqf`, `AI_Commander_Teams.sqf`, `AI_Commander_AssignTowns.sqf`, `AI_Commander_MHQReloc.sqf`, `AI_Commander_Base.sqf`, `AI_Commander_Produce.sqf` | `Server/AI/Commander/V2/AI_Commander_V2_Planning.sqf` plus small topic planners | Pure transform from assessment and profile to decisions. No `setVariable`, no spawning, no PVF. |
| Execution | `AI_Commander_Execute.sqf`, `Common_RunCommanderTeam.sqf`, HC delegation from `AI_Commander_Teams.sqf`, server request paths in `Server_HandleSpecial.sqf` | `Server/AI/Commander/V2/AI_Commander_V2_Execution.sqf` and existing `Common_RunCommanderTeam.sqf` contract | Applies orders, writes side/team vars, delegates to HC, logs telemetry. |

## Perception contract

Function name:

`WFBE_SE_FNC_AICOMV2_PullWorldState`

Call shape:

`[_sideId, _now, _profileKey] call WFBE_SE_FNC_AICOMV2_PullWorldState`

Required inputs read defensively:

| Source | Read form | Nil/default rule |
|---|---|---|
| `wfbe_teams` | global array of groups | If nil or non-array, use `[]` and log `AICOMSTAT|v3|WARN|...|PERCEPTION_MISSING|key=wfbe_teams`. |
| `wfbe_town_*` / `towns` | global town array and town variables | If `towns` nil, use `[]`; every town variable read uses a local default. |
| `wfbe_units_<side>` | side unit pools | If nil, use `[]`; never assume side arrays exist before faction init. |
| Side logic | `WFBE_<side>_Logic` resolved by side id | If null, return state with `valid=0`; supervisor skips planning for this tick. |
| HQ/base refs | `GetSideHQ`, side structures, factories | Null HQ is legal; serialize as `[0,0]` and `hqAlive=0`. |
| Map profile | `WFBE_AICOMV2_PROFILE_<worldName>` | If absent, use compiled default profile and set `profileFallback=1`. |

World-state record, array index contract:

| Index | Name | Type | Description |
|---:|---|---|---|
| 0 | `schema` | string | Always `"AICOMV2_WORLD_V1"`. |
| 1 | `sideId` | number | `0` WEST, `1` EAST. GUER is read as environment, not planned by this commander. |
| 2 | `timeSec` | number | Mission `time`, rounded down. |
| 3 | `worldName` | string | Current `worldName`. |
| 4 | `profileKey` | string | `"CH"`, `"TK"`, `"ZG"` or fallback key. |
| 5 | `towns` | array | Array of town records, below. |
| 6 | `teams` | array | Array of team records, below. |
| 7 | `sideFunds` | number | AI commander cash pool. Missing -> `0`. |
| 8 | `sideSupply` | number | Side supply. Missing -> `0`. |
| 9 | `hq` | array | `[alive01, posX, posZ, deployed01]`. Null HQ -> `[0,0,0,0]`. |
| 10 | `factories` | array | Factory records: `[kind, alive01, posX, posZ]`. |
| 11 | `knownEnemy` | array | Intel records from V2 perception feed only. Empty in initial implementation. |
| 12 | `caps` | array | `[aiCap, teamCap, groupCap, popTier]`. |
| 13 | `v1Compat` | array | Snapshot of V1-only state needed during migration. |

Town record:

`[townId, name, posX, posZ, sideId, supplyValue, maxSupplyValue, townValue, tier, townTypeCsv, isAirfield01, isCoastal01, zoneTagCsv]`

Team record:

`[teamId, sideId, groupKey, aliveCount, maxCount, mode, targetTownId, targetX, targetZ, seq, isHc01, isGarrison01, isRefit01, teamType, lastOrderAgeSec]`

`groupKey` is a stable string built by execution from side id and group index. It is not an object ref. The execution layer resolves it back to the current group object only when applying an order.

## Assessment contract

Function name:

`WFBE_SE_FNC_AICOMV2_Assess`

Call shape:

`[_worldState] call WFBE_SE_FNC_AICOMV2_Assess`

Assessment output record:

| Index | Name | Type | Description |
|---:|---|---|---|
| 0 | `schema` | string | `"AICOMV2_ASSESS_V1"`. |
| 1 | `sideId` | number | Planned side. |
| 2 | `myStr` | number | V1-compatible maneuver strength equivalent to `_myStr`. Computed from non-garrison, non-refit live teams plus vehicle class weight. |
| 3 | `enStr` | number | V1-compatible enemy maneuver strength equivalent to `_enStr`, using observable or currently owned/enemy town data only. |
| 4 | `myTowns` | number | Count of towns where `sideId == my side`. |
| 5 | `enemyTowns` | number | Count of towns where `sideId == enemy side`. |
| 6 | `guerTowns` | number | Count of resistance towns. |
| 7 | `targets` | array | Replacement for `wfbe_aicom_targets`: ordered town ids, not objects. |
| 8 | `laststand` | number | Replacement for `wfbe_aicom_laststand`: `1` active, `0` inactive. |
| 9 | `posture` | string | `"EXPAND"`, `"PRESS"`, `"ATTACK"`, `"DEFEND"`, `"LASTSTAND"`, `"STRIKE"`, `"CONSOLIDATE"`. |
| 10 | `reason` | string | One reason token from the V3 grammar. |
| 11 | `superiority` | number | Local superiority score at primary target, scaled as attacker bodies / defender bodies. |
| 12 | `tempo` | string | `"SLOW"`, `"NORMAL"`, `"EXPLOIT"`, `"RECOVER"`. |
| 13 | `economyPressure` | array | `[funds, supply, spendFloor, hoardAlarm01]`. |
| 14 | `risk` | array | `[groupBudgetRisk01, fpsRisk01, profileFallback01]`. |

Assessment writes no variables. Execution mirrors selected assessment fields to the side logic only after planning succeeds:

| Side-logic variable | Value |
|---|---|
| `wfbe_aicom_v2_targets` | Primitive town-id array from assessment index 7. |
| `wfbe_aicom_targets` | V1 compatibility object array, resolved by execution only. |
| `wfbe_aicom_laststand` | `true`/`false` compatibility bool, written only by execution. |
| `wfbe_aicom_v2_assess` | Full assessment primitive record for telemetry/debug. |

## Planning contract

Function name:

`WFBE_SE_FNC_AICOMV2_Plan`

Call shape:

`[_worldState, _assessment, _profile] call WFBE_SE_FNC_AICOMV2_Plan`

Decision record shape:

`[mode, target, teamRef, seq, reason, priority, ttlSec, notBeforeSec, profileKey]`

Field definitions:

| Field | Type | Values |
|---|---|---|
| `mode` | string | `"towns-target"`, `"defense"`, `"rally"`, `"goto"`, `"move"`, `"hold"`, `"refit"`, `"merge"`, `"disband"`, `"build"`, `"research"`, `"mhq-relocate"`, `"fire-support"`, `"wildcard"`. |
| `target` | array | For town work: `["town", townId, name, posX, posZ, radius]`; for pos work: `["pos", posX, posZ, radius]`; for structure/research: `["class", className, posX, posZ, radius]`. |
| `teamRef` | array | `[sideId, teamId, groupKey]`. `teamId=-1` for side-level decisions. |
| `seq` | number | Monotonic per team. Side-level decisions use side sequence. |
| `reason` | string | WHY token, e.g. `expand_neutral`, `mass_superiority`, `laststand_hq_threat`, `economy_hoard_spend`. |
| `priority` | number | `0` low to `100` critical. Higher wins conflicts. |
| `ttlSec` | number | Expiry. `0` means one-shot. |
| `notBeforeSec` | number | Earliest apply time. Enables hysteresis and phase jitter. |
| `profileKey` | string | Profile that shaped the decision. |

Planning output:

`["AICOMV2_PLAN_V1", sideId, timeSec, planSeq, decisions, planMetrics]`

`planMetrics = [retargetsThisTick, committedTeams, waitingTeams, attackGroups, defendGroups, spendBudget, cpuBudgetMs]`

Conflict rules:

1. A team can receive at most one movement decision per plan tick.
2. A target change from one live town to another must carry a reason in `["town_flipped","laststand","stuck_timeout","player_order","target_blacklisted","strike_stage_release"]`.
3. No attack decision may be emitted unless assessment superiority >= the profile's `attackSuperiorityMin`, unless mode is `"harass"` or `"laststand"`.
4. Planning must never read globals directly. If a field is missing from world state, the decision is skipped with a WHY token ending `_missing_data`.

## Execution contract

Function name:

`WFBE_SE_FNC_AICOMV2_Execute`

Call shape:

`[_plan, _worldState] call WFBE_SE_FNC_AICOMV2_Execute`

Order dispatch record written to HC teams:

`wfbe_aicom_order = [seq, mode, pos, radius, targetId, why]`

| Slot | Type | Description |
|---:|---|---|
| 0 | number | Sequence. Must increment on every material order change. |
| 1 | string | One of the movement mode strings. Existing HC driver supports `towns-target`, `defense`, `rally`; V2 adds `goto` and `move` but must map unsupported strings to V1-safe behavior until driver updated. |
| 2 | array | Position `[x,z]`. If existing V1 helper needs 3D, execution converts to `[x,0,z]` locally. |
| 3 | number | Completion/engage radius. Default `80` for assault SAD, `250` for arrival, profile-specific. |
| 4 | number | `townId` or `-1`. |
| 5 | string | WHY token for log correlation. |

Server-local teams receive the same primitive record but execution applies it through existing setters:

| Decision mode | V1-compatible action |
|---|---|
| `towns-target` | `SetTeamMoveMode "towns"` plus `SetTeamMovePos pos`; publish `wfbe_aicom_order` if HC. |
| `defense` | `SetTeamMoveMode "defense"` plus `SetTeamMovePos pos`; publish order. |
| `rally` | `SetTeamMoveMode "move"` plus rally pos; publish `rally`. |
| `goto` | `SetTeamMoveMode "move"` plus pos; publish `goto`. |
| `hold` | `SetTeamMoveMode "defense"`, set hold expiry and holding town. |

## HC split

Server only:

Perception, Assessment, Planning, economics, build/research decisions, target selection, side memory, profile loading, all WHY logs, all KPI self-watchdog decisions.

HC allowed:

Movement execution, waypoint laying, local vehicle boarding/dismounting, team capture loop, local cleanup of owned team entities, read-only consumption of `wfbe_aicom_order`.

HC delegation payload:

`["delegate-aicom-team", sideId, groupKey, teamId, teamType, veteranSkill, orderRecord, profileLite]`

`profileLite = [routeHopSpacing, routeCompletion, laneOffset, slopeZ, assaultSad, arriveRadius]`

Transport mechanism:

Use the existing `SendToClient` / `SendToClients` pattern only from server paths that already own HandleSpecial routing. The server sends one-direction payloads; HCs never send planning state back. HC may emit audit telemetry only:

`AICOMSTAT|v3|HC|<side>|<min>|ORDER_ACK|team=<teamId>|seq=<seq>|mode=<mode>|owner=<ownerId>`

## Boot and watchdog

On `WFBE_C_AICOM_V2_ENABLE > 0`, the V2 supervisor logs:

`AICOMSTAT|v3|PROFILE|<side>|0|LOAD|map=<worldName>|profile=<key>|fallback=<0/1>|nodes=<n>|edges=<n>`

Every strategy tick logs:

`AICOMHB|v3|TICK|<side>|<min>|gen=<n>|state=<posture>|planSeq=<n>|decisions=<n>|cpuMs=<n>|profile=<key>`

If the V2 supervisor dies, V1 watchdog may restart only the side-local V2 supervisor. More than two restarts in one round is harness FAIL.

## Builder checklist

1. Create V2 files under `Server/AI/Commander/V2/`.
2. Add only one new default-off master flag in `Init_CommonConstants.sqf`.
3. Keep V1 calls untouched when flag is `0`.
4. Implement pure assessment/planning so the same arrays can be fed to a Python harness without Arma.
5. No A3 commands, no group `getVariable [name,default]`, no public third arg on `missionNamespace setVariable`.
