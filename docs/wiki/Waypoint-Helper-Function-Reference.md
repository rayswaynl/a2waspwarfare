# Waypoint Helper Function Reference (WaypointsAdd / WaypointPatrol family)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Every AI group movement in WASP routes through five compiled waypoint helpers registered in `Common/Init/Init_Common.sqf` (lines 153–157). This page documents each function's call contract, the shared waypoint tuple format, and the live-caller map.

---

## Function Registration

All five functions are compiled at init time on both the server and headless client:

| Global name | Source file | Line |
|---|---|---|
| `WFBE_CO_FNC_WaypointsAdd` | `Common/Functions/Common_WaypointsAdd.sqf` | `Common/Init/Init_Common.sqf:156` |
| `WFBE_CO_FNC_WaypointsRemove` | `Common/Functions/Common_WaypointsRemove.sqf` | `Common/Init/Init_Common.sqf:157` |
| `WFBE_CO_FNC_WaypointPatrol` | `Common/Functions/Common_WaypointPatrol.sqf` | `Common/Init/Init_Common.sqf:153` |
| `WFBE_CO_FNC_WaypointPatrolTown` | `Common/Functions/Common_WaypointPatrolTown.sqf` | `Common/Init/Init_Common.sqf:154` |
| `WFBE_CO_FNC_WaypointSimple` | `Common/Functions/Common_WaypointSimple.sqf` | `Common/Init/Init_Common.sqf:155` |

All are invoked with `Call` or `Spawn` (see caller map below).

---

## The Waypoint Tuple Format

`WFBE_CO_FNC_WaypointsAdd` consumes an array of **7-element tuples**. Every caller must supply exactly 7 elements; a 6-element tuple will cause a script error on `_x select 6`.

```sqf
// Full tuple (7 elements):
[_position, _type, _radius, _completionRadius, _statements, _timeout, _squad_prop]
```

| Index | Field | Type | Notes |
|---|---|---|---|
| 0 | `_position` | Array or Object | If `typeName == 'OBJECT'`, `getPos` is applied automatically (`Common_WaypointsAdd.sqf:25`). Pass a 3-element position array or an object reference. |
| 1 | `_type` | String | Arma 2 waypoint type: `'MOVE'`, `'SAD'`, `'CYCLE'`, etc. Set via `setWaypointType` (`Common_WaypointsAdd.sqf:29`). |
| 2 | `_radius` | Number | Waypoint scatter radius passed directly to `addWaypoint [_position, _radius]` (`Common_WaypointsAdd.sqf:28`). |
| 3 | `_completionRadius` | Number | Applied via `setWaypointCompletionRadius` (`Common_WaypointsAdd.sqf:30`). |
| 4 | `_statements` | Array | Two-element array `[condition, onActivation]`. Applied only when `count _statements > 0` (`Common_WaypointsAdd.sqf:31`). Pass `[]` to skip. |
| 5 | `_timeout` | Array | Three-element array `[min, mid, max]`. Applied only when `count _timeout > 0` (`Common_WaypointsAdd.sqf:32`). Pass `[]` to skip. |
| 6 | `_squad_prop` | Array | Four-element array `[behaviour, combatMode, formation, speed]`. See Squad Properties section below. Pass `[]` to skip all four. |

### Squad Properties (`_squad_prop`)

When `_squad_prop` is non-empty (`count _squad_prop > 0`), each element is applied individually only if it is a **non-empty string** (`Common_WaypointsAdd.sqf:33`). Pass `""` to leave a specific property unchanged.

| Index | Setter called | Valid values (Arma 2 OA) |
|---|---|---|
| 0 | `setWaypointBehaviour` | `"CARELESS"`, `"SAFE"`, `"AWARE"`, `"COMBAT"`, `"STEALTH"` |
| 1 | `setWaypointCombatMode` | `"BLUE"`, `"GREEN"`, `"WHITE"`, `"YELLOW"`, `"RED"` |
| 2 | `setWaypointFormation` | `"COLUMN"`, `"STAG COLUMN"`, `"WEDGE"`, `"ECH LEFT"`, `"ECH RIGHT"`, `"VEE"`, `"LINE"`, `"DIAMOND"`, `"FILE"` |
| 3 | `setWaypointSpeed` | `"LIMITED"`, `"NORMAL"`, `"FULL"` |

### First-Waypoint Activation

When the waypoint index is 0 (first waypoint on the group), `setCurrentWaypoint [_team, 0]` is called immediately after adding it (`Common_WaypointsAdd.sqf:34`). This forces the group to start moving to the first waypoint without waiting for the engine's default activation logic.

### Tuple Examples from Source

```sqf
// Server_AI_SetTownAttackPath.sqf:39 — MOVE with squad_prop, no statements, no timeout
[([_nodes_a select 0, 20, 100] Call WFBE_CO_FNC_GetRandomPosition), 'MOVE', 40, 20, [], [], ["AWARE","","COLUMN","NORMAL"]]

// Server_AI_SetTownAttackPath.sqf:86 — SAD with squad_prop, no statements, no timeout
[([_x, 10, 35] Call WFBE_CO_FNC_GetRandomPosition), 'SAD', 40, 20, [], [], _behaviour]

// Server_AI_SetTownAttackPath.sqf:96 — (commented out) shows timeout usage
// [([_wp_dest, 10, 35] Call WFBE_CO_FNC_GetRandomPosition), 'SAD', 35, 25, [], [30,45,60], ["COMBAT","","FILE","LIMITED"]]

// Common_WaypointSimple.sqf:16 — minimal tuple, all optional fields empty
[_destination, _mission, _radius, 20, [], [], []]
```

---

## `WFBE_CO_FNC_WaypointsAdd`

**File:** `Common/Functions/Common_WaypointsAdd.sqf`

### Signature

```sqf
[_team, _clear, _waypoints] Call WFBE_CO_FNC_WaypointsAdd;
```

| Param | Type | Description |
|---|---|---|
| `_team` | Group | The group to assign waypoints to. |
| `_clear` | Boolean | If `true`, calls `WFBE_CO_FNC_WaypointsRemove` on the group before adding any new waypoints (`Common_WaypointsAdd.sqf:15`). |
| `_waypoints` | Array of 7-element tuples | The waypoints to add, in order. |

### Behavior Notes

- Iterates `_waypoints` with `forEach`; each iteration uses `count (waypoints _team)` as the current index, so waypoints accumulate correctly across multiple calls with `_clear = false` (`Common_WaypointsAdd.sqf:27`).
- Object positions are resolved at add-time, not stored as references (`Common_WaypointsAdd.sqf:25`).
- `_statements`, `_timeout`, and `_squad_prop` are silently skipped when empty — no engine error.

---

## `WFBE_CO_FNC_WaypointsRemove`

**File:** `Common/Functions/Common_WaypointsRemove.sqf`

### Signature

```sqf
_team Call WFBE_CO_FNC_WaypointsRemove;
```

### Behavior Notes

- Iterates from `(count (waypoints _team))-1` down to `0` (reverse order) and calls `deleteWaypoint [_team, _z]` on each (`Common_WaypointsRemove.sqf:11-12`).
- Reverse iteration is required: deleting a waypoint by index renumbers higher indices, so forward deletion skips entries.
- Called internally by `WaypointsAdd` when `_clear = true`. Also called directly to sanitize groups on player connect (`Server/Functions/Server_OnPlayerConnected.sqf:60`).

---

## `WFBE_CO_FNC_WaypointPatrol`

**File:** `Common/Functions/Common_WaypointPatrol.sqf`

### Signature

```sqf
[_team, _destination, _radius, _maxWaypoints] Spawn WFBE_CO_FNC_WaypointPatrol;
// Optional 5th param:
[_team, _destination, _radius, _maxWaypoints, _behaviours] Spawn WFBE_CO_FNC_WaypointPatrol;
```

| Param | Type | Default | Description |
|---|---|---|---|
| `_team` | Group | — | Group to assign the patrol to. |
| `_destination` | Array or Object | — | Center point of the patrol area. Objects are resolved via `getPos` (`Common_WaypointPatrol.sqf:15`). |
| `_radius` | Number | — | Maximum scatter offset from `_destination` in each axis. |
| `_maxWaypoints` | Number | — | Number of `MOVE` waypoints; a final `CYCLE` waypoint is appended automatically. |
| `_behaviours` | Array | `[]` | Optional `_squad_prop` array passed directly as element 6 of each waypoint tuple (`Common_WaypointPatrol.sqf:14`). |

### Generated Waypoints

- Generates `_maxWaypoints + 1` total waypoints (loop variable runs `from 0 to _maxWaypoints`) (`Common_WaypointPatrol.sqf:18`).
- All but the last are type `'MOVE'`; the last is type `'CYCLE'` (`Common_WaypointPatrol.sqf:27`).
- Each point uses `random _radius - random _radius` for X and Y offset, producing a roughly uniform scatter centered on `_destination` (`Common_WaypointPatrol.sqf:19-20`).
- Fixed waypoint geometry: `radius = 35`, `completionRadius = 40`, `statements = []`, `timeout = []` (`Common_WaypointPatrol.sqf:28`).

### Water-Avoidance Loop Risk

Each point is tested with `surfaceIsWater _pos`; if the point lands on water, a new random offset is resampled (`Common_WaypointPatrol.sqf:22-26`). This loop has **no iteration cap**. On maps with large water bodies (or when `_destination` is near the coast and `_radius` is large), this loop can spin indefinitely. This is a confirmed performance risk noted in the codebase audit.

### Caller

`Server/FSM/server_town_patrol.sqf:44` — used for focus-object patrols (non-town patrol mode), with `_patrol_range / 4` as the radius.

---

## `WFBE_CO_FNC_WaypointPatrolTown`

**File:** `Common/Functions/Common_WaypointPatrolTown.sqf`

### Signature

```sqf
[_team, _town, _radius] Spawn WFBE_CO_FNC_WaypointPatrolTown;
// _radius is optional; default = 30 (Common_WaypointPatrolTown.sqf:13)
```

| Param | Type | Default | Description |
|---|---|---|---|
| `_team` | Group | — | Group to assign the patrol to. Must not be `isNull` (exits immediately if null, `Common_WaypointPatrolTown.sqf:15`). |
| `_town` | Object | — | The town depot/marker object. Must `typeName == 'OBJECT'` (exits immediately otherwise, `Common_WaypointPatrolTown.sqf:14`). |
| `_radius` | Number | `30` | Base random scatter radius for non-camp waypoints (`Common_WaypointPatrolTown.sqf:13`). |

### Algorithm

1. Reads the town's `camps` variable (`_town getVariable 'camps'`) to build a usable object list: `_usable = [_town] + _camps` (`Common_WaypointPatrolTown.sqf:18-20`).
2. Computes total waypoint count: `WFBE_C_TOWNS_UNITS_WAYPOINTS + count(_usable)` (default: `9 + (1 + campCount)`) (`Common_WaypointPatrolTown.sqf:21`; constant at `Common/Init/Init_CommonConstants.sqf:362`).
3. Randomizes group-level behaviour before building waypoints — four independent 50/50 rolls applied directly to the group (not per-waypoint): formation (`DIAMOND` or `STAG COLUMN`), combat mode (`YELLOW` or `RED`), behaviour (`AWARE` or `COMBAT`), speed (`NORMAL` or `LIMITED`) (`Common_WaypointPatrolTown.sqf:25-28`).
4. Interleaves camp/town visits at a computed `_insertStep = floor(_maxWaypoints / count(_usable))` (`Common_WaypointPatrolTown.sqf:31`). Every `_insertStep` waypoints, one object from `_usable` is selected at random (without replacement) and used as the waypoint position (`Common_WaypointPatrolTown.sqf:38-41`).
5. For random scatter waypoints: `radius = 32`, `completionRadius = 44` (`Common_WaypointPatrolTown.sqf:53-54`).
6. For camp/town object waypoints: `radius = 35`, `completionRadius = 68` (`Common_WaypointPatrolTown.sqf:57-58`).
7. All but the last waypoint are type `'MOVE'`; the last is type `'CYCLE'` (`Common_WaypointPatrolTown.sqf:61`).
8. All tuples pass `_squad_prop = []` — behaviours are pre-applied at group level in step 3, not per-waypoint (`Common_WaypointPatrolTown.sqf:62`).
9. Calls `WFBE_CO_FNC_WaypointsAdd` with `_clear = true` (`Common_WaypointPatrolTown.sqf:65`).

### Dual Completion Radii

| Waypoint category | `_radius` | `_completionRadius` | Source |
|---|---|---|---|
| Random scatter (no object) | 32 | 44 | `Common_WaypointPatrolTown.sqf:53-54` |
| Camp or town object | 35 | 68 | `Common_WaypointPatrolTown.sqf:57-58` |

The larger completion radius for object waypoints ensures the group registers arrival even when pathfinding stops slightly short of the precise object position.

### Water-Avoidance Loop Risk (inherited)

The same uncapped `surfaceIsWater` re-sample loop from `WaypointPatrol` is present for random scatter points (`Common_WaypointPatrolTown.sqf:48-51`). Object-position waypoints bypass this loop entirely (they use `getPos _insertObject` directly).

### Relevant Constants

| Constant | Default | Description | Source |
|---|---|---|---|
| `WFBE_C_TOWNS_UNITS_WAYPOINTS` | `9` | Base waypoint count before camp additions | `Common/Init/Init_CommonConstants.sqf:362` |
| `WFBE_C_TOWNS_PATROL_RANGE` | `500` | Patrol radius passed in by `server_town_patrol.sqf` | `Common/Init/Init_CommonConstants.sqf:356` |
| `WFBE_C_TOWNS_DEFENSE_RANGE` | `30` | Defense SAD radius (used by `WaypointSimple`, not `WaypointPatrolTown`) | `Common/Init/Init_CommonConstants.sqf:345` |

### Caller

`Server/FSM/server_town_patrol.sqf:42` — the primary town AI patrol loop calls this when `_mode == "patrol"` and no focus object is set.

---

## `WFBE_CO_FNC_WaypointSimple`

**File:** `Common/Functions/Common_WaypointSimple.sqf`

### Signature

```sqf
[_team, _destination, _mission, _radius] Spawn WFBE_CO_FNC_WaypointSimple;
// _radius is optional; default = 30 (Common_WaypointSimple.sqf:15)
```

A thin wrapper around `WaypointsAdd` that issues a single-waypoint order with `_clear = true`. All optional tuple fields are passed as empty arrays; `_completionRadius` is hardcoded to `20` (`Common_WaypointSimple.sqf:16`).

**Caller:** `Server/FSM/server_town_patrol.sqf:47` — used in `"defense"` mode with waypoint type `'SAD'` and `WFBE_C_TOWNS_DEFENSE_RANGE` (default `30`) as the radius.

---

## Live Caller Map

| Caller file | Function called | `_clear` | Notes |
|---|---|---|---|
| `Common/Functions/Common_WaypointsAdd.sqf:15` | `WaypointsRemove` | — | Internal: clear gate |
| `Common/Functions/Common_WaypointPatrol.sqf:31` | `WaypointsAdd` | `true` | Patrol route commit |
| `Common/Functions/Common_WaypointPatrolTown.sqf:65` | `WaypointsAdd` | `true` | Town patrol commit |
| `Common/Functions/Common_WaypointSimple.sqf:16` | `WaypointsAdd` | `true` | Single-order commit |
| `Server/FSM/server_town_patrol.sqf:42` | `WaypointPatrolTown` | — | Spawned; patrol mode, no focus |
| `Server/FSM/server_town_patrol.sqf:44` | `WaypointPatrol` | — | Spawned; patrol mode, with focus object |
| `Server/FSM/server_town_patrol.sqf:47` | `WaypointSimple` | — | Spawned; defense mode (`SAD`) |
| `Server/Functions/Server_AI_SetTownAttackPath.sqf:19` | `WaypointsRemove` | — | Explicit pre-clear before ARC attack route |
| `Server/Functions/Server_AI_SetTownAttackPath.sqf:41` | `WaypointsAdd` | `false` | Early exit: first WP only (30% random roll) |
| `Server/Functions/Server_AI_SetTownAttackPath.sqf:71` | `WaypointsAdd` | `false` | ARC route commit (multi-hop) |
| `Server/Functions/Server_AI_SetTownAttackPath.sqf:98` | `WaypointsAdd` | `false` | Final SAD push onto committed route |
| `Server/Functions/Server_OnPlayerConnected.sqf:60` | `WaypointsRemove` | — | Player reconnect sanitize |

---

## Attack Path Specifics (`Server_AI_SetTownAttackPath`)

`Server/Functions/Server_AI_SetTownAttackPath.sqf` is the only caller that builds multi-hop routes manually rather than delegating to a patrol helper.

**Proximity gate:** if the group leader is within `700 m` of the target town, the ARC routing block is skipped entirely and only the final SAD push is applied (`Server_AI_SetTownAttackPath.sqf:24`).

**ARC node generation:** 8 nodes are placed at `700 m` distance from the target at `360/8 = 45°` intervals; nodes are sorted by distance from the group's current position (`Server_AI_SetTownAttackPath.sqf:31-35`).

**Max hops:** `WFBE_C_AI_TOWN_ATTACK_HOPS_WP - 2` (default `4 - 2 = 2`) intermediate hop waypoints are permitted (`Server_AI_SetTownAttackPath.sqf:36`; constant at `Common/Init/Init_CommonConstants.sqf:106`).

**squad_prop values used in attack tuples:**

| Waypoint role | squad_prop |
|---|---|
| First ARC hop | `["AWARE","","COLUMN","NORMAL"]` (`Server_AI_SetTownAttackPath.sqf:39`) |
| Second ARC hop (flanking) | `["AWARE","","WEDGE","NORMAL"]` (`Server_AI_SetTownAttackPath.sqf:58`) |
| Intermediate random hops | `[]` — no squad_prop applied (`Server_AI_SetTownAttackPath.sqf:69`) |
| Camp SAD sweep | `["AWARE","","VEE","NORMAL"]`, degrading to `[]` after first camp (`Server_AI_SetTownAttackPath.sqf:84-89`) |
| Depot SAD | `["AWARE","","FILE","NORMAL"]` (`Server_AI_SetTownAttackPath.sqf:94-95`) |

---

## Common Pitfalls

**7-element tuple required.** `Common_WaypointsAdd.sqf:24` unconditionally executes `_squad_prop = _x select 6`. A 6-element tuple raises a script error. This is audit finding AI17. Always include the 7th element, even if `[]`.

**Object vs. position.** The `getPos` coercion at `Common_WaypointsAdd.sqf:25` applies only to element 0. Elements 4, 5, 6 must already be arrays of the correct shape.

**`_clear = false` accumulates.** Calling `WaypointsAdd` with `_clear = false` on a group that already has waypoints appends rather than replaces. `Server_AI_SetTownAttackPath` uses three separate `WaypointsAdd` calls with `_clear = false` to build the route incrementally; the first call in the ARC block uses `_clear = false` so the initial MOVE waypoint from line 39/41 is preserved.

**Water-avoidance spin.** Both `WaypointPatrol` and `WaypointPatrolTown` contain an uncapped `while { surfaceIsWater _pos } do { ... }` loop. On island-heavy terrains or when the patrol center is at sea, this can stall the spawned script indefinitely. Always verify that `_destination` / `_town` is on land and that `_radius` does not push all resampled positions into water.

**`_insertStep` of -1.** In `WaypointPatrolTown`, if `count(_usable) == 0` then `_insertStep = -1` (`Common_WaypointPatrolTown.sqf:31`). The insert counter `_insert` starts at `-1` and would match `_z == -1` on no iteration (since `_z` starts at `0`), so the degenerate case degrades gracefully to pure random scatter waypoints with no object insertion.

---

## Continue Reading

- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_CO_FNC_*` naming scheme and the distinction between Common and Server function scopes
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — how towns track `supplyValue`, `sideID`, and the `camps` variable consumed by `WaypointPatrolTown`
- [Commander-HQ-Lifecycle-Atlas](Commander-HQ-Lifecycle-Atlas) — the broader AI lifecycle that drives calls into `Server_AI_SetTownAttackPath`
- [AI-Headless-And-Performance](AI-Headless-And-Performance) — HC group delegation context in which these functions execute, and performance implications of the water-avoidance loop
- [Function-And-Module-Index](Function-And-Module-Index) — full index of compiled SQF functions registered at init time
