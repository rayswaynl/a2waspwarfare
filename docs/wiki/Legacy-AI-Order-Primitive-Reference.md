# Legacy AI Order Primitive Reference (AIMoveTo / AIPatrol / AIWPAdd family)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the **legacy AI order primitive family** — the bare-named global functions `AIMoveTo`, `AIPatrol`, `AITownPatrol`, `AITownResitance`, `AIWPAdd`, and `AIWPRemove`. These are compiled server-side from `Server/AI/Orders/*.sqf` (plus `Server/AI/AI_Resistance.sqf`) and drive paradrop egress, AI-commander team movement, the wildcard/guerrilla system, and resistance defence. They are a **separate system** from the documented `WFBE_CO_FNC_Waypoint*` helper family (compiled in `Init_Common.sqf` from `Common/Functions/Common_Waypoint*.sqf`); see [Waypoint Helper Function Reference](Waypoint-Helper-Function-Reference) for that parallel family and the section below for how the two differ.

All six globals are compiled in one block in `Server/Init/Init_Server.sqf:19-24`:

| Global | Source file | Init_Server line |
| --- | --- | --- |
| `AIMoveTo` | `Server/AI/Orders/AI_MoveTo.sqf` | `Server/Init/Init_Server.sqf:19` |
| `AIPatrol` | `Server/AI/Orders/AI_Patrol.sqf` | `Server/Init/Init_Server.sqf:20` |
| `AITownPatrol` | `Server/AI/Orders/AI_TownPatrol.sqf` | `Server/Init/Init_Server.sqf:21` |
| `AITownResitance` | `Server/AI/AI_Resistance.sqf` | `Server/Init/Init_Server.sqf:22` |
| `AIWPAdd` | `Server/AI/Orders/AI_WPAdd.sqf` | `Server/Init/Init_Server.sqf:23` |
| `AIWPRemove` | `Server/AI/Orders/AI_WPRemove.sqf` | `Server/Init/Init_Server.sqf:24` |

All are compiled with `Compile preprocessFile` and run **server-side only**. They mutate group waypoints and posture directly, so callers must already hold a server-local group.

## The shared 6-element waypoint tuple

Every order in this family ultimately funnels into `AIWPAdd`, which consumes an array of **6-element waypoint tuples**. The element order is fixed by `AI_WPAdd.sqf:22-27`:

| Index | Field | Type | Consumed at | Notes |
| --- | --- | --- | --- | --- |
| 0 | `position` | Array or Object | `Server/AI/Orders/AI_WPAdd.sqf:22` | If an Object is passed, it is resolved via `getPos` (`Server/AI/Orders/AI_WPAdd.sqf:28`) |
| 1 | `type` | String | `Server/AI/Orders/AI_WPAdd.sqf:23` | Waypoint type, e.g. `'MOVE'`, `'SAD'`, `'CYCLE'`, `'HOLD'`, `'SCRIPTED'` |
| 2 | `radius` | Number | `Server/AI/Orders/AI_WPAdd.sqf:24` | Passed to `addWaypoint [position, radius]` (`Server/AI/Orders/AI_WPAdd.sqf:32`) |
| 3 | `completionRadius` | Number | `Server/AI/Orders/AI_WPAdd.sqf:25` | Passed to `setWaypointCompletionRadius` (`Server/AI/Orders/AI_WPAdd.sqf:34`) |
| 4 | `scripted` | String | `Server/AI/Orders/AI_WPAdd.sqf:26` | Only applied when `type == 'SCRIPTED'` (`Server/AI/Orders/AI_WPAdd.sqf:35`) |
| 5 | `statements` | Array | `Server/AI/Orders/AI_WPAdd.sqf:27` | When non-empty, applied as `setWaypointStatements [condition, statement]` (`Server/AI/Orders/AI_WPAdd.sqf:36`) |

This 6-tuple is **the distinguishing contract** of the legacy family. The newer `WFBE_CO_FNC_WaypointsAdd` family uses a **7-element tuple** (see [Waypoint Helper Function Reference](Waypoint-Helper-Function-Reference)). Mixing the two will mis-index — a 7-tuple fed to `AIWPAdd` would read garbage at indices 4-5.

## AIWPAdd — the waypoint writer

`AIWPAdd` (`Server/AI/Orders/AI_WPAdd.sqf`) is the low-level primitive every other order delegates to. It clears (optionally) then appends a list of waypoints to a group.

| Aspect | Detail |
| --- | --- |
| Parameters | `[_team, _clear, _waypoints]` — group, Boolean clear flag, array of 6-tuples (`Server/AI/Orders/AI_WPAdd.sqf:15-17`) |
| Returns | Nothing meaningful; mutates the group's waypoint list in place |
| Clear behaviour | When `_clear` is `true`, calls `_team Call AIWPRemove` first (`Server/AI/Orders/AI_WPAdd.sqf:19`) |
| Per-waypoint write | `_team addWaypoint [_position, _radius]` (`Server/AI/Orders/AI_WPAdd.sqf:32`), then `setWaypointType` / `setWaypointCompletionRadius` (`Server/AI/Orders/AI_WPAdd.sqf:33-34`) |
| Conditional fields | `setWaypointScript` only for `'SCRIPTED'` type (`Server/AI/Orders/AI_WPAdd.sqf:35`); `setWaypointStatements` only when `count _statements > 0` (`Server/AI/Orders/AI_WPAdd.sqf:36`) |
| First-waypoint activation | When `_WPCount == 0` (the first waypoint just added), it calls `_team setCurrentWaypoint [_team, _WPCount]` to make the group act on it immediately (`Server/AI/Orders/AI_WPAdd.sqf:38`) |
| Index bookkeeping | `_WPCount = count (waypoints _team)` is re-read each iteration **before** the add (`Server/AI/Orders/AI_WPAdd.sqf:30`), so the new waypoint's index is the pre-add count |

The header docstring at `Server/AI/Orders/AI_WPAdd.sqf:1-12` (author Benny) gives the canonical example tuple with a `'SAD'` waypoint carrying statements `["canComplete", "this sidechat 'lets roll'"]`.

## AIWPRemove — the waypoint clearer

`AIWPRemove` (`Server/AI/Orders/AI_WPRemove.sqf`) deletes every waypoint on a group.

| Aspect | Detail |
| --- | --- |
| Parameter | `_team = _this` — the group is passed bare, not wrapped in an array (`Server/AI/Orders/AI_WPRemove.sqf:2`) |
| Loop | Reverse-index `for` from `(count (waypoints _team))-1` down to `0` (`Server/AI/Orders/AI_WPRemove.sqf:4`) |
| Delete | `deleteWaypoint [_team, _z]` per index (`Server/AI/Orders/AI_WPRemove.sqf:5`) |

The reverse iteration is deliberate: deleting low indices first would re-number the remaining waypoints and skip entries. The only caller is `AIWPAdd` itself (`Server/AI/Orders/AI_WPAdd.sqf:19`); no other site invokes `AIWPRemove` directly.

## AIMoveTo — aggressive single-destination order

`AIMoveTo` (`Server/AI/Orders/AI_MoveTo.sqf`) sets an aggressive march posture and gives the group a **single** waypoint to a destination. It is the most heavily used member of the family.

| Aspect | Detail |
| --- | --- |
| Parameters | `[_team, _destination, _mission, _radius]` (`Server/AI/Orders/AI_MoveTo.sqf:2-5`); `_radius` defaults to `30` when fewer than 4 args (`Server/AI/Orders/AI_MoveTo.sqf:5`) |
| Posture set | `setCombatMode "RED"`, `setBehaviour "AWARE"`, `setFormation "COLUMN"`, `setSpeedMode "FULL"` (`Server/AI/Orders/AI_MoveTo.sqf:6-9`) — advance-and-engage at full march speed |
| Waypoint emitted | One 6-tuple `[_destination, _mission, _radius, 20, "", []]` via `AIWPAdd` with clear=true (`Server/AI/Orders/AI_MoveTo.sqf:32`) — completion radius hard-coded to `20` |
| Update gate | `_update` starts `true`; for WEST/EAST it is overwritten by `_team Call CanUpdateTeam` (`Server/AI/Orders/AI_MoveTo.sqf:11-14`) |

### The AICOM posture-preservation guard

Lines `Server/AI/Orders/AI_MoveTo.sqf:16-28` are the most consequential logic in this file. The shared `UpdateTeam` routine re-stamps `AWARE/NORMAL/YELLOW` plus a **random** formation, which would clobber the aggressive `RED/FULL/COLUMN` set at lines 6-9. To preserve posture for AI-commander teams, `AIMoveTo` reads two group variables and skips `UpdateTeam` when either is set:

| Variable | Read at | Meaning |
| --- | --- | --- |
| `wfbe_aicom_hc` | `Server/AI/Orders/AI_MoveTo.sqf:23` | AI-commander headless-delegated team |
| `wfbe_aicom_founded` | `Server/AI/Orders/AI_MoveTo.sqf:24` | AI-commander-founded team |

The guard `if ((!isNil "_aicomHc" && {_aicomHc}) || {!isNil "_aicomFnd" && {_aicomFnd}}) then {_update = false}` (`Server/AI/Orders/AI_MoveTo.sqf:25`) is written with **1-arg `getVariable` + `isNil`** for a documented A2-OA reason recorded in the comment at lines 19-22: under Arma 2 OA the **2-arg group `getVariable [name, default]` returns `nil` (not the default) when the variable is unset**. For non-AICOM groups (paradrop, para-ammo, para-vehicle, town, patrol) these variables are unset, so the old 2-arg form returned `nil`, and `nil || {nil}` threw "Type Nothing" — aborting `AIMoveTo` before the `AIWPAdd` call at line 32, leaving those groups with no waypoint. The 1-arg-plus-`isNil` form treats an unset variable as `false` and lets non-AICOM groups proceed. `UpdateTeam` is finally applied (when still permitted) at `Server/AI/Orders/AI_MoveTo.sqf:28`.

## AIPatrol — scattered MOVE+CYCLE loop

`AIPatrol` (`Server/AI/Orders/AI_Patrol.sqf`) builds a multi-waypoint patrol loop scattered around a destination.

| Aspect | Detail |
| --- | --- |
| Parameters | `[_team, _destination, _radius]` (`Server/AI/Orders/AI_Patrol.sqf:2-4`); `_radius` defaults to `30` (`Server/AI/Orders/AI_Patrol.sqf:4`) |
| Object resolve | If `_destination` is an Object it is resolved with `getPos` (`Server/AI/Orders/AI_Patrol.sqf:5`) |
| Posture | `setCombatMode "YELLOW"`, `setBehaviour "AWARE"`, `setFormation "COLUMN"`, `setSpeedMode "NORMAL"` (`Server/AI/Orders/AI_Patrol.sqf:7-10`) — calmer than `AIMoveTo` |
| Update gate | Same WEST/EAST `CanUpdateTeam` pattern, then `UpdateTeam` unconditionally for permitted groups (`Server/AI/Orders/AI_Patrol.sqf:12-18`) — **no** AICOM posture guard here |
| Waypoint count | `_maxWaypoints = 8`; loop runs `_z = 0` to `_z <= 8` inclusive (`Server/AI/Orders/AI_Patrol.sqf:20-22`) = 9 waypoints |
| Scatter | Each position offset by `random _radius - random _radius` on X and Y (`Server/AI/Orders/AI_Patrol.sqf:23-25`) |
| Water resample | `while {surfaceIsWater _pos && _wtr < 20}` re-rolls up to 20 times; if still water, falls back to the bare destination (`Server/AI/Orders/AI_Patrol.sqf:27-33`) |
| Types | All `'MOVE'` except the final index `_z == _maxWaypoints`, which is `'CYCLE'` to loop the patrol (`Server/AI/Orders/AI_Patrol.sqf:34`) |
| Tuple | `[_pos, _type, 35, 40, "", []]` — radius 35, completion 40 (`Server/AI/Orders/AI_Patrol.sqf:35`) |
| Emit | `[_team, true, _wps] Call AIWPAdd` (`Server/AI/Orders/AI_Patrol.sqf:40`) |

## AITownPatrol — camp/depot-interleaved town patrol

`AITownPatrol` (`Server/AI/Orders/AI_TownPatrol.sqf`) is a richer town-patrol generator that interleaves the town's camps and depots into the waypoint chain and randomizes per-group behaviour.

| Aspect | Detail |
| --- | --- |
| Parameters | `[_team, _town, _radius]`; `_radius` defaults to `30` (`Server/AI/Orders/AI_TownPatrol.sqf:13-15`) |
| Guards | `exitWith` ERROR if `_town` is not an Object (`Server/AI/Orders/AI_TownPatrol.sqf:16`) or `_team` is null (`Server/AI/Orders/AI_TownPatrol.sqf:17`) |
| Insert set | `_usable = [_town] + _camps`, where `_camps = _town getVariable 'camps'` (`Server/AI/Orders/AI_TownPatrol.sqf:20-22`) |
| Waypoint count | `WFBE_C_TOWNS_PATROL_HOPS + count(_usable)` (`Server/AI/Orders/AI_TownPatrol.sqf:23`); `WFBE_C_TOWNS_PATROL_HOPS = 5` at `Common/Init/Init_CommonConstants.sqf:508` |
| Randomized posture | Per-group coin-flips: formation DIAMOND/STAG COLUMN, combat YELLOW/RED, behaviour AWARE/COMBAT, speed NORMAL/LIMITED (`Server/AI/Orders/AI_TownPatrol.sqf:27-30`) |
| Dynamic insert | `_insertStep = floor(_maxWaypoints / count(_usable))`; at each multiple a random unused camp/depot is consumed (`Server/AI/Orders/AI_TownPatrol.sqf:33-44`) |
| Dual completion radii | Scatter waypoints use radius 32 / completion 44; insert-object (camp/depot) waypoints use radius 35 / completion 68 (`Server/AI/Orders/AI_TownPatrol.sqf:58-63`) |
| Water resample | Same 20-try `surfaceIsWater` resample as `AIPatrol`, only on scatter waypoints (`Server/AI/Orders/AI_TownPatrol.sqf:51-57`) |
| Types | `'MOVE'` except final `'CYCLE'` (`Server/AI/Orders/AI_TownPatrol.sqf:66`) |
| Emit | `[_team, true, _wps] Call AIWPAdd` (`Server/AI/Orders/AI_TownPatrol.sqf:72`) |

**Dormancy note:** `AITownPatrol` is compiled at `Server/Init/Init_Server.sqf:21` but has **no live caller** anywhere in master — a tree-wide search finds only the compile line itself. It is a dormant primitive available to be wired up, not an active path.

## AITownResitance — resistance action dispatcher

`AITownResitance` (`Server/AI/AI_Resistance.sqf`; note the misspelled global name preserved from source) dispatches a resistance group into one of three behaviours by action string.

| Aspect | Detail |
| --- | --- |
| Parameters | `[_team, _position, _range, _action]` (`Server/AI/AI_Resistance.sqf:2-5`) |
| `"Patrol"` | `[_team, _position, _range] Call BIS_fnc_taskPatrol` — engine task-patrol generator (`Server/AI/AI_Resistance.sqf:8`) |
| `"Defend"` | Sets STAG COLUMN / AWARE / NORMAL, then one `'SAD'` waypoint `[_position, 'SAD', 40, 30, "", []]` via `AIWPAdd` (`Server/AI/AI_Resistance.sqf:9-15`) |
| `"CPatrol"` | `[_team, _position, _range] Spawn AIPatrol` — delegates to the scattered `AIPatrol` loop (`Server/AI/AI_Resistance.sqf:16`) |

**Dormancy note:** like `AITownPatrol`, `AITownResitance` is compiled (`Server/Init/Init_Server.sqf:22`) but has **no live caller** in master. It is dormant.

## Live caller map

Verified callers of the family across the mission tree (excluding internal delegation):

| Caller site | Order called | Argument shape |
| --- | --- | --- |
| `Server/Support/Support_Paratroopers.sqf:92` | `AIMoveTo` | `[_grp, _destination, "MOVE", 10]` (drop egress) |
| `Server/Support/Support_Paratroopers.sqf:122` | `AIMoveTo` | `[_grp, (_ranPos select _ran), "MOVE", 10]` (post-drop scatter) |
| `Server/Support/Support_ParaAmmo.sqf:38` | `AIMoveTo` | `[_grp, (_args select 2), "MOVE", 10]` |
| `Server/Support/Support_ParaAmmo.sqf:96` | `AIMoveTo` | `[_grp, (_ranPos select _ran), "MOVE", 10]` |
| `Server/Support/Support_ParaVehicles.sqf:39` | `AIMoveTo` | `[_grp, (_args select 2), "MOVE", 10]` |
| `Server/Support/Support_ParaVehicles.sqf:78` | `AIMoveTo` | `[_grp, (_ranPos select _ran), "MOVE", 10]` |
| `Server/AI/Commander/AI_Commander_Execute.sqf:46` | `AIMoveTo` | `[_team, _goto, _wpType, _radius]` (MOVE/SAD/HOLD by mode) |
| `Server/AI/Commander/AI_Commander_AssignTowns.sqf:377` | `AIMoveTo` | `[_team, getPos _target, "SAD", 200]` (non-arc fallback) |
| `Server/Functions/AI_Commander_Wildcard.sqf:776` | `AIPatrol` | `[_guerGrp, _guerPos, 200]` |
| `Server/Functions/AI_Commander_Wildcard.sqf:870` | `AIPatrol` | `[_w13Grp, _w13TargetPos, 200]` |
| `Server/Functions/AI_Commander_Wildcard.sqf:985` | `AIPatrol` | `[_w17Grp, _w17TargetPos, 100]` |
| `Server/Functions/AI_Commander_Wildcard.sqf:1034` | `AIPatrol` | `[_w18Grp, _w18Pos, 120]` |
| `Server/AI/AI_Resistance.sqf:16` | `AIPatrol` (via `AITownResitance` `"CPatrol"`) | `[_team, _position, _range] Spawn` |
| `Server/AI/Orders/AI_MoveTo.sqf:32` | `AIWPAdd` | internal (single MOVE waypoint) |
| `Server/AI/Orders/AI_Patrol.sqf:40` | `AIWPAdd` | internal (patrol loop) |
| `Server/AI/Orders/AI_TownPatrol.sqf:72` | `AIWPAdd` | internal (town loop) |
| `Server/AI/AI_Resistance.sqf:14` | `AIWPAdd` | `[_team, true, [[_position, 'SAD', 40, 30, "", []]]]` (Defend) |
| `Server/AI/Orders/AI_WPAdd.sqf:19` | `AIWPRemove` | internal (clear-before-add) |

Note that the AI commander's preferred path at `AI_Commander_AssignTowns.sqf:374-375` (the `if (_useArc) then {` guard at 374, then `[_team, _target] Call WFBE_SE_FNC_AI_SetTownAttackPath;` at 375) is `WFBE_SE_FNC_AI_SetTownAttackPath`; `AIMoveTo` at line 377 is only the **non-arc fallback** (`_useArc == false`).

## Distinction from the Waypoint-Helper family

This legacy family and the `WFBE_CO_FNC_Waypoint*` helper family are **independent**, with non-overlapping function names and incompatible tuple shapes:

| | Legacy AI order family (this page) | Waypoint-Helper family |
| --- | --- | --- |
| Globals | `AIMoveTo`, `AIPatrol`, `AITownPatrol`, `AITownResitance`, `AIWPAdd`, `AIWPRemove` | `WFBE_CO_FNC_WaypointsAdd`, `WaypointsRemove`, `WaypointPatrol`, `WaypointPatrolTown`, `WaypointSimple` |
| Compiled in | `Server/Init/Init_Server.sqf:19-24` (server-only) | `Init_Common.sqf` (common) — see [Waypoint Helper Function Reference](Waypoint-Helper-Function-Reference) |
| Source | `Server/AI/Orders/*.sqf`, `Server/AI/AI_Resistance.sqf` | `Common/Functions/Common_Waypoint*.sqf` |
| Waypoint tuple | **6 elements** `[position, type, radius, completionRadius, scripted, statements]` (`Server/AI/Orders/AI_WPAdd.sqf:22-27`) | **7 elements** |

When porting or extending AI movement, pick one family and keep its tuple shape; do not feed a 7-tuple into `AIWPAdd` (`Server/AI/Orders/AI_WPAdd.sqf` reads only indices 0-5).

## Continue Reading

- [Waypoint Helper Function Reference](Waypoint-Helper-Function-Reference) — the parallel `WFBE_CO_FNC_Waypoint*` family and its 7-element tuple
- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit) — how the AI commander drives `AIMoveTo` for team movement
- [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas) — the paradrop modules that call `AIMoveTo` for egress
- [Resistance Supply Scaffold](Resistance-Supply-Scaffold) — the resistance/GUER side that `AITownResitance` was built for
- [AI Runtime And HC Loop Map](AI-Runtime-HC-Loop-Map) — server-side AI loops and headless delegation context
