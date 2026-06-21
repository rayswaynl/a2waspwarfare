# Town Garrison Patrol/Defense Worker

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server/FSM/server_town_patrol.sqf` is the per-town garrison stance worker. One instance is spawned for each defending town team, and it runs a 30-second monitor loop that watches the town's economy and ownership and flips the garrison between two stances: a roaming **patrol** (cycle waypoints across the town and its camps) and a reactive **defense** (a Seek-And-Destroy sweep tightly around the town center). The trigger for defense is the town being attacked, detected indirectly through a drop in `supplyValue` or a change of `sideID`. Waypoints are only re-issued on a stance *transition*, so a garrison that stays in the same stance does no waypoint work between ticks.

This page documents the worker's decision logic. The loop lifecycle (cadence, exit) is covered by [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map); the waypoint primitives it calls are documented from the helper side in [Waypoint-Helper-Function-Reference](Waypoint-Helper-Function-Reference).

## Signature and spawn site

The worker is launched once per valid town garrison team during town unit creation.

| Item | Detail | Source |
| --- | --- | --- |
| Launch | `[_town, _team, _sideID] execVM "Server\FSM\server_town_patrol.sqf"` | `Common/Functions/Common_CreateTownUnits.sqf:81` |
| Args `[_location, _team, _sideID]` | town object, garrison group, owning side ID at spawn time | `server_town_patrol.sqf:3-5` |
| Optional `_focus` (arg index 3) | object to focus-patrol; `objNull` when omitted (caller passes only 3 args, so normally null) | `server_town_patrol.sqf:6` |
| Null-team guard | `if (isNull _team) exitWith {}` — Marty note: town unit creation can fail under engine limits, do not keep a worker alive for a null group | `server_town_patrol.sqf:8-9` |

Only the three positional args are passed at the live spawn site; `_focus` therefore defaults to `objNull` in the shipped Chernarus path. The garrison team is stamped with `WFBE_TownAI_Town` / `_Side` / `_Group` and made brave (`allowFleeing 0`) immediately before this worker is launched (`Common/Functions/Common_CreateTownUnits.sqf:78-84`). See [Batch-AI-Spawner-Orchestrator](Batch-AI-Spawner-Orchestrator) for the surrounding spawn wiring.

## State captured at start

| Local | Initial value | Source |
| --- | --- | --- |
| `_lastSV` | `_location getVariable 'supplyValue'` (the town's supply at worker start) | `server_town_patrol.sqf:11` |
| `_startSV` | `_location getVariable 'startingSupplyValue'` (the town's baseline supply) | `server_town_patrol.sqf:12` |
| `_mode` | `"patrol"` (the assumed starting stance) | `server_town_patrol.sqf:13` |
| `_lastMode` | `"nil"` (sentinel so the first real stance always edge-triggers) | `server_town_patrol.sqf:14` |
| `_patrol_range` | `WFBE_C_TOWNS_PATROL_RANGE` (default `500`) | `server_town_patrol.sqf:16` |
| `_defense_range` | `WFBE_C_TOWNS_DEFENSE_RANGE` (default `30`) | `server_town_patrol.sqf:17` |
| `_aliveTeam` | `false` if the team has zero live units or is null, else `true` | `server_town_patrol.sqf:18` |

`_aliveTeam` is computed with `(units _team) Call WFBE_CO_FNC_GetLiveUnits` (which returns the subset of units passing `alive`, `Common/Functions/Common_GetLiveUnits.sqf:1-8`) and short-circuits to `false` when that count is `0` or the group is null.

## Stance decision (per tick)

Each iteration re-reads the town's current supply and decides the stance:

| Condition (any true) | Resulting `_mode` | Source |
| --- | --- | --- |
| `_currentSV < _lastSV` (supply dropped since last tick) | `"defense"` | `server_town_patrol.sqf:28-29` |
| `_currentSV < _startSV` (supply below baseline) | `"defense"` | `server_town_patrol.sqf:28-29` |
| `_sideID != (_location getVariable 'sideID')` (town changed hands vs. spawn-time owner) | `"defense"` | `server_town_patrol.sqf:28-29` |
| none of the above | `"patrol"` | `server_town_patrol.sqf:30-31` |

`_currentSV = _location getVariable 'supplyValue'` is read at `server_town_patrol.sqf:27`, and after the decision `_lastSV` is advanced to `_currentSV` (`server_town_patrol.sqf:34`) so the next tick's `<` comparison measures the delta over the last 30 seconds. The semantics: a town whose supply is being drained by an enemy (or that has just flipped sides) is "under attack", and its garrison reacts by switching to an aggressive close-in defense. When supply stabilizes at or above baseline and ownership is intact, the garrison returns to patrol. The `supplyValue` / `sideID` town variables this reads are described in [Economy-Towns-And-Supply](Economy-Towns-And-Supply).

## Stance dispatch (edge-triggered)

Waypoints are re-issued only when the stance actually changes, guarded by `_aliveTeam && _mode != _lastMode && !WFBE_GameOver` (`server_town_patrol.sqf:36`). On a transition, `_lastMode` is advanced and `_perfModeChange` is set to `1` for telemetry (`server_town_patrol.sqf:37-38`).

| Stance | Focus | Spawned call | Source |
| --- | --- | --- | --- |
| `"patrol"` | none (`isNull _focus`) | `[_team,_location,_patrol_range] Spawn WFBE_CO_FNC_WaypointPatrolTown` — roam the whole town + its camps at radius `500` | `server_town_patrol.sqf:41-42` |
| `"patrol"` | focus object set | `[_team,_focus,_patrol_range/4] Spawn WFBE_CO_FNC_WaypointPatrol` — tighter patrol around the focus at radius `125` | `server_town_patrol.sqf:43-44` |
| `"defense"` | (either) | `[_team,getPos _location,'SAD',_defense_range] Spawn WFBE_CO_FNC_WaypointSimple` — a single Seek-And-Destroy waypoint at town center, radius `30` | `server_town_patrol.sqf:46-47` |

Because the live caller never passes a focus object, the patrol branch in practice always takes the `WaypointPatrolTown` path; the focus/`WaypointPatrol` branch is a latent capability. `WaypointSimple` issues one waypoint of kind `'SAD'` at the given radius via `WFBE_CO_FNC_WaypointsAdd` (`Common/Functions/Common_WaypointSimple.sqf:12-17`). Each of the three primitives is documented (radius/completion-radius details, the water-resample caveat) from the helper side in [Waypoint-Helper-Function-Reference](Waypoint-Helper-Function-Reference).

The edge-trigger is what keeps the worker cheap: between transitions, the loop only re-reads supply and writes a telemetry record. A garrison sitting in patrol with stable supply re-issues no waypoints.

## Loop lifecycle and teardown

| Aspect | Behavior | Source |
| --- | --- | --- |
| Loop condition | `while {!WFBE_GameOver && _aliveTeam}` — runs while the game is live and the team has live units | `server_town_patrol.sqf:21` |
| Per-tick re-check | `_aliveTeam` is recomputed from live-unit count at the top of every iteration | `server_town_patrol.sqf:25` |
| Cadence | `sleep 30` at the end of each iteration | `server_town_patrol.sqf:56` |
| Exit | falls out of the loop once `WFBE_GameOver` becomes true OR the garrison team is dead/empty | `server_town_patrol.sqf:21,57` |

The `&&` in the loop condition (not `||`) is deliberate: the worker must exit on *either* game-over *or* team death, otherwise dead empty garrisons would loop forever, each still paying the 30-second telemetry cost. This was the AI1 zombie-loop finding fixed by flipping `||`→`&&` (`Server-Authority` / audit history; see [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map) for the loop-lifecycle treatment).

## Performance telemetry

When `PerformanceAudit_Record` is defined and `PerformanceAuditEnabled` is true (default true), every tick emits a `town_patrol` channel record (`server_town_patrol.sqf:50-55`).

| Field | Value | Source |
| --- | --- | --- |
| channel | `"town_patrol"` | `server_town_patrol.sqf:53` |
| duration | `diag_tickTime - _perfStart` (time for this iteration's work) | `server_town_patrol.sqf:23,53` |
| `town` | `_location getVariable "name"` | `server_town_patrol.sqf:53` |
| `side` | `_sideID` | `server_town_patrol.sqf:53` |
| `alive` | `_aliveTeam` | `server_town_patrol.sqf:53` |
| `units` | `count (units _team)` | `server_town_patrol.sqf:53` |
| `mode` | current stance (`patrol`/`defense`) | `server_town_patrol.sqf:53` |
| `changed` | `_perfModeChange` (`1` on a transition tick, else `0`) | `server_town_patrol.sqf:53` |
| `focus` | `!(isNull _focus)` | `server_town_patrol.sqf:53` |

The scope tag is `"SERVER"` when `isServer && !hasInterface`, else `"CLIENT"` (so a delegated headless-client instance records as `CLIENT`) (`server_town_patrol.sqf:52`). The record sink itself is documented in [Performance-Audit-Writer-Function-Reference](Performance-Audit-Writer-Function-Reference).

## Known performance caveat

The patrol-mode call into `WFBE_CO_FNC_WaypointPatrolTown` (and the focus `WaypointPatrol`) contains an uncapped `while { surfaceIsWater _pos }` re-sample loop. For towns adjacent to water, this can spin without an iteration cap and starve the spawned thread's scheduler. This is a live hazard traced to `Common/Functions/Common_WaypointPatrolTown.sqf:48-52`, invoked from `server_town_patrol.sqf:42,44` (line 42 spawns `WaypointPatrolTown`, line 44 the focus `WaypointPatrol`) — see [Deep-Review-Findings](Deep-Review-Findings) and the water-avoidance note in [Waypoint-Helper-Function-Reference](Waypoint-Helper-Function-Reference).

## Continue Reading

- [Waypoint-Helper-Function-Reference](Waypoint-Helper-Function-Reference) — the `WaypointPatrolTown` / `WaypointPatrol` / `WaypointSimple` primitives this worker spawns
- [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map) — loop cadence and exit lifecycle across all AI runtime workers
- [Town-Runtime-Tuning-Constants](Town-Runtime-Tuning-Constants) — `WFBE_C_TOWNS_PATROL_RANGE` / `WFBE_C_TOWNS_DEFENSE_RANGE` and the other town garrison tunables
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — how towns track `supplyValue`, `startingSupplyValue`, and `sideID`
- [Batch-AI-Spawner-Orchestrator](Batch-AI-Spawner-Orchestrator) — town garrison creation and the patrol-worker spawn wiring
