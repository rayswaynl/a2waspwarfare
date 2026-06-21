# Array and Collection Utility Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the foundational collection helpers that underpin nearly every system in WASP. All functions listed here are registered in `Common/Init/Init_Common.sqf` (lines 94–145) via `Compile preprocessFileLineNumbers`. They are available on every machine type (server, headless client, client) immediately after `Init_Common.sqf` executes. Two additional client-only helpers (`WFBE_CL_FNC_FindVariableInNestedArray` and `ReplaceArray`) are covered at the end.

---

## Array Mutation Functions

### WFBE_CO_FNC_ArrayPush

**File:** `Common/Functions/Common_ArrayPush.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:95`

#### Signature

```sqf
[_array, _value] Call WFBE_CO_FNC_ArrayPush
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_array` | Array | Mutated in-place via `set`; must be passed by reference (not a copy). |
| 1 | `_value` | Any | Value appended at index `count _array`. |

#### Return value

The modified array (same reference as `_array`). (`Common_ArrayPush.sqf:14`)

#### Behavior

Appends `_value` to the end of `_array` using `_array set [count(_array), _value]`. (`Common_ArrayPush.sqf:13`) Because `set` operates on the original array object rather than a copy, the caller's variable reflects the change immediately without reassignment — unlike the `+` operator which allocates a new array. This is the most-called function in the codebase; representative call sites include `Server/FSM/server_patrols.sqf:33`, `Server/FSM/server_town_ai.sqf:141–142`, and `Server/Functions/Server_AI_SetTownAttackPath.sqf:58`.

---

### WFBE_CO_FNC_ArrayRemoveIndex

**File:** `Common/Functions/Common_ArrayRemoveIndex.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:96`

#### Signature

```sqf
[_array, _index] Call WFBE_CO_FNC_ArrayRemoveIndex
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_array` | Array | Deep-copied internally; the original is not mutated. |
| 1 | `_index` | Number | Zero-based index of the element to remove. |

#### Return value

A new array with the element at `_index` removed. (`Common_ArrayRemoveIndex.sqf:17`)

#### Behavior

The function deep-copies the input (`+(_this select 0)`) so the caller's array is unchanged. (`Common_ArrayRemoveIndex.sqf:9`) It then uses a sentinel strategy: the element at `_index` is overwritten with the string `"wfbe_nil"`, and that sentinel is removed from the array using the subtraction operator `_array - ["wfbe_nil"]`. (`Common_ArrayRemoveIndex.sqf:13–14`) If `count _array` is zero, the copy is returned unchanged. (`Common_ArrayRemoveIndex.sqf:12`)

#### Sentinel collision hazard

Because the sentinel is the plain string `"wfbe_nil"`, any array that legitimately contains the string `"wfbe_nil"` as a value will have **all** occurrences of that string removed, not just the element at `_index`. This is a known design constraint: arrays of classnames, side strings, or arbitrary data must never use `"wfbe_nil"` as a value. The string does not appear as a legitimate classname or config value anywhere in the mission.

The function is also **not** a drop-in replacement for the `deleteAt` command introduced in later Arma versions (not available in OA 1.64). Callers that mix the sentinel strategy with `ArrayPush`-based arrays that hold arbitrary strings must verify the constraint holds.

Call site: `Server/FSM/server_patrols.sqf:45` — removes index 0 from the visited-towns list when the patrol cycles.

---

### WFBE_CO_FNC_ArrayShift

**File:** `Common/Functions/Common_ArrayShift.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:97`

#### Signature

```sqf
[_array, _removeIndices] Call WFBE_CO_FNC_ArrayShift
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_array` | Array | Deep-copied internally; the original is not mutated. |
| 1 | `_removeIndices` | Array of Numbers | Zero-based indices to skip in the output. |

#### Return value

A new array containing every element of `_array` whose index is **not** in `_removeIndices`. (`Common_ArrayShift.sqf:22`)

#### Behavior

Iterates `_array` with a `for` loop from index 0 to `count(_array) - 1`. (`Common_ArrayShift.sqf:15`) Elements whose index is not found in `_removeIndices` are written sequentially into a fresh array `_shifted` using a monotonically increasing write cursor `_i`. (`Common_ArrayShift.sqf:16–19`) Membership is tested with the `in` operator against `_removeIndices`, which is an O(n) scan per element — this is acceptable for the small arrays it operates on.

This is the low-level primitive used by `WFBE_CO_FNC_ArrayShuffle` and by `Server/Functions/Server_SpawnTownDefense.sqf:26` to exclude already-chosen defense kinds from a selection pool.

---

### WFBE_CO_FNC_ArrayShuffle

**File:** `Common/Functions/Common_ArrayShuffle.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:98`

#### Signature

```sqf
_array Call WFBE_CO_FNC_ArrayShuffle
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| `_this` | Array | Deep-copied internally; the original is not mutated. |

#### Return value

A new array containing the same elements in randomized order. (`Common_ArrayShuffle.sqf:20`)

#### Behavior

Implements a selection-without-replacement shuffle. (`Common_ArrayShuffle.sqf:9–18`) On each iteration `_i`, a random index is chosen from the current pool via `floor(random(count _array))`, the element at that index is appended to `_shuffled`, and the chosen index is removed from the pool using `[_array, [_ran]] Call WFBE_CO_FNC_ArrayShift`. Because `ArrayShift` returns a new array, `_array` (the pool) shrinks by one each pass and `_ran` is always valid for the current pool size.

This is not a pure Fisher-Yates in-place swap; it is a selection shuffle that has the same uniform distribution property but allocates a new pool array on each iteration.

Used at `Server/Functions/Server_GetTownGroups.sqf:171–172` and `Server/Functions/Server_GetTownGroupsDefender.sqf:107–108` to randomize infantry and vehicle spawn lists when populating a town.

---

## Unit Filtering and Query Functions

### WFBE_CO_FNC_GetLiveUnits

**File:** `Common/Functions/Common_GetLiveUnits.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:124`

#### Signature

```sqf
_units Call WFBE_CO_FNC_GetLiveUnits
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| `_this` | Array of Objects | Typically the result of `units _group`. |

#### Return value

A new array containing only elements for which `alive _x` is true. (`Common_GetLiveUnits.sqf:7`)

#### Behavior

Iterates `_units` with `forEach`, appending each alive unit to `_liveUnits` via array concatenation (`_liveUnits = _liveUnits + [_x]`). (`Common_GetLiveUnits.sqf:7`) The input array is not mutated. Dead, null, or deleted units are silently excluded.

This is one of the most widely called helpers. Representative sites:

| Call site | Context |
|-----------|---------|
| `Common/Functions/Common_ChangeUnitGroup.sqf:7` | Guard before joining a unit to a new group. |
| `Client/Functions/Client_FNC_Groups.sqf:106,169` | Filter group members before squad-join UI logic. |
| `Client/Functions/Client_HandleMapSingleClick.sqf:24,107` | Build the target list for map-click orders. |
| `Server/FSM/server_patrols.sqf:28` | Check whether a patrol team has any survivors. |
| `Server/FSM/server_town_patrol.sqf:18,25` | Determine whether a town patrol group is still active. |

---

### WFBE_CO_FNC_GetUnitsPerSide

**File:** `Common/Functions/Common_GetUnitsPerSide.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:140`

#### Signature

```sqf
[_units, _sides] Call WFBE_CO_FNC_GetUnitsPerSide
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_units` | Array of Objects | Units to partition. |
| 1 | `_sides` | Array of Side | Ordered list of sides to bucket into (e.g. `[west, east]`). |

#### Return value

An array of arrays, one sub-array per side in `_sides`, each containing the units from `_units` whose `side` matches. (`Common_GetUnitsPerSide.sqf:21`)

#### Behavior

Initializes `_return` as an array of `count _sides` empty arrays, each appended via `WFBE_CO_FNC_ArrayPush`. (`Common_GetUnitsPerSide.sqf:14`) Then iterates `_units` with `forEach`; for each unit, `_sides find (side _x)` locates the matching bucket index, and the unit is pushed into that bucket. (`Common_GetUnitsPerSide.sqf:17–18`) Units whose side is not in `_sides` are silently dropped (find returns -1; the `-1 != -1` guard is absent, so a `select -1` would occur — see note below).

Note: the guard `if (_find != -1)` is present on line 18 of `Common_GetUnitsPerSide.sqf`, so units with an unrecognized side are correctly skipped.

The function is registered but has no call sites in the current master outside of `Init_Common.sqf`. It exists as an infrastructure helper for future systems.

---

### WFBE_CO_FNC_GetUnitConfigGear

**File:** `Common/Functions/Common_GetUnitConfigGear.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:139`

#### Signature

```sqf
_kind Call WFBE_CO_FNC_GetUnitConfigGear
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| `_this` | String | `CfgVehicles` class name (e.g. `"US_Soldier_EP1"`). |

#### Return value

`[_weapons, _magazines, _backpack, _get_backpack_content]` where: (`Common_GetUnitConfigGear.sqf:46`)

| Index | Type | Content |
|-------|------|---------|
| 0 | Array of String | Weapons from `CfgVehicles >> _kind >> weapons`, minus `"Throw"` and `"Put"`. |
| 1 | Array of String | Magazines from `CfgVehicles >> _kind >> magazines`. |
| 2 | String | Backpack classname from `CfgVehicles >> _kind >> backpack`, or `""` if none. |
| 3 | `[[[weapons],[counts]],[[magazines],[counts]]]` | Backpack `TransportWeapons` and `TransportMagazines` content tables; each resolved against `missionNamespace` variable filters. |

#### Behavior

Reads the unit's loadout directly from `configFile >> 'CfgVehicles' >> _kind`. (`Common_GetUnitConfigGear.sqf:11`) Weapons are filtered: `"Throw"` and `"Put"` are subtracted from the raw array. (`Common_GetUnitConfigGear.sqf:12`) The backpack is resolved; if present and if its `TransportWeapons` / `TransportMagazines` sub-classes exist, each entry's classname is looked up in `missionNamespace` to confirm it is a known, config-active item before it is included in the result. (`Common_GetUnitConfigGear.sqf:23–43`) Items not present in `missionNamespace` are silently excluded — this is the mechanism by which DLC-gated gear is filtered out.

Call sites: `Client/Functions/Client_BuildUnit.sqf:227` and `Client/GUI/GUI_BuyGearMenu.sqf:159` — both use the result to populate the gear purchase and loadout editor UI.

---

## Unit Identity and Position Helpers

### GetUnitVehicle

**File:** `Common/Functions/Common_GetUnitVehicle.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:65` (legacy prefix-free form)

#### Signature

```sqf
_unit Call GetUnitVehicle
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| `_this` | Object | Any unit or vehicle. |

#### Return value

`vehicle _unit` if the unit is inside a vehicle (i.e. `_unit != vehicle _unit`), otherwise `_unit` itself. (`Common_GetUnitVehicle.sqf:4`)

#### Naming note

This function predates the `WFBE_CO_FNC_*` naming convention and is registered as the bare name `GetUnitVehicle`, not `WFBE_CO_FNC_GetUnitVehicle`. (`Common/Init/Init_Common.sqf:65`) All call sites use the bare name. Do not wrap it in a `WFBE_CO_FNC_` prefix.

Call sites are exclusively in `Client/GUI/GUI_Menu_UnitCamera.sqf` (lines 32, 66, 78, 92, 117, 131) — the unit camera menu uses this to track the vehicle a player or selected unit occupies.

---

## Group Management

### WFBE_CO_FNC_ChangeUnitGroup

**File:** `Common/Functions/Common_ChangeUnitGroup.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:100`

#### Signature

```sqf
[_unit, _group, _side] Call WFBE_CO_FNC_ChangeUnitGroup
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_unit` | Object | The unit to move to `_group`. |
| 1 | `_group` | Group | Destination group. |
| 2 | `_side` | String | Side string used to look up the temp-unit classname (e.g. the value of `WFBE_Client_SideJoined`). The variable `WFBE_{_side}SOLDIER` must exist in `missionNamespace`. |

#### Return value

None.

#### Behavior and temp-unit guard

If the current live member count of `_unit`'s group is less than 2 (i.e. `_unit` is the sole survivor), a temporary filler unit of the faction's base soldier class is spawned at `[0,0,0]` before the join. (`Common_ChangeUnitGroup.sqf:9`) The base class is resolved via `missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side]`. This prevents the engine from deleting the originating group when the last member leaves — group deletion would break any outstanding waypoints or references held elsewhere. The temp unit is deleted immediately after the join completes. (`Common_ChangeUnitGroup.sqf:11`)

The `_side` parameter must be the text representation that matches the suffix used in the faction root config files (`Common/Config/Core_Root/Root_*.sqf:8`). For example, when the client's `WFBE_Client_SideJoined` is the sideJoined value, the lookup `WFBE_{sideJoined}SOLDIER` must resolve to a valid CfgVehicles classname.

#### Known latent bug

`_entitie` is declared in `Private` on line 1 but is only assigned inside the `if (count _units < 2)` branch on line 9. On line 11, `if !(isNull _entitie)` is evaluated even when the branch was skipped — at that point `_entitie` holds a nil/undefined value (A2 OA `Private` does not initialize variables). The `isNull` check on a nil value does not throw an error; it returns `false`, so `deleteVehicle` is not called and the function proceeds correctly. The code is safe in practice but the pattern is fragile: any re-ordering of lines 9–11 that assigns `_entitie` in the else-branch would trigger a double-delete. (`Common_ChangeUnitGroup.sqf:1,9,11`)

Call sites: `Client/Functions/Client_FNC_Groups.sqf:27,116,203` (player squad joins) and `Server/Functions/Server_HandleSpecial.sqf:30` (server-side group reassignment for special roles).

---

## Reveal and Waypoint Helpers

### WFBE_CO_FNC_RevealArea

**File:** `Common/Functions/Common_RevealArea.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:145`

#### Signature

```sqf
[_unit, _range, _pos] spawn WFBE_CO_FNC_RevealArea
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_unit` | Object or Group | The knower — the entity that gains the revealed knowledge. Accepts a group (the engine broadcasts to all members). |
| 1 | `_range` | Number | Radius in metres around `_pos` to scan for entities. |
| 2 | `_pos` | Array | `[x,y,z]` centre position. |

#### Return value

None. Always called via `spawn` (fire-and-forget). (`Common_CreateTownUnits.sqf:55`, `Common_CreateUnitForStaticDefence.sqf:122`)

#### Behavior

Iterates `_pos nearEntities _range`. (`Common_RevealArea.sqf:19`) For each entity in range, builds a reveal list starting with the entity itself; if the entity is inside a vehicle (`_x != vehicle _x`), the vehicle's crew is appended. (`Common_RevealArea.sqf:17`) Then `_unit reveal _x` is called for each item in the list. (`Common_RevealArea.sqf:18`)

Reveal ranges observed in production call sites:

| Call site | `_range` | Context |
|-----------|----------|---------|
| `Common/Functions/Common_CreateTownUnits.sqf:55` | 400 m | AI group spawned into a town |
| `Common/Functions/Common_CreateUnitForStaticDefence.sqf:122` | 175 m | Static defense unit placed at a position |
| `Server/Functions/Server_HandleDefense.sqf:44` | 1000 m | Defense unit triggered during server-side defense handling |
| `Server/Functions/Server_OperateTownDefensesUnits.sqf:62` | 175 m | Defense unit operated at a town |

---

### WFBE_CO_FNC_AreWaypointsComplete

**File:** `Common/Functions/Common_AreWaypointsComplete.sqf`  
**Registered:** `Common/Init/Init_Common.sqf:94`

#### Signature

```sqf
_group Call WFBE_CO_FNC_AreWaypointsComplete
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| `_this` | Group | The group to check. |

#### Return value

`Bool` — `true` if the group has no pending waypoints. (`Common_AreWaypointsComplete.sqf:7`)

#### Behavior

Single expression: `count (waypoints _this) == currentWaypoint _this`. (`Common_AreWaypointsComplete.sqf:7`) In Arma 2 OA, `currentWaypoint` returns the index of the waypoint the group is currently moving toward (0-based), and `count (waypoints _group)` is the total number of assigned waypoints. Equality means the group's current waypoint index has reached the count, i.e. all waypoints have been completed.

The function is registered but has no call sites in master outside `Init_Common.sqf`. It is available as an infrastructure helper for patrol and AI loop logic.

---

## Client-Only Array Helpers

These two functions are registered on clients only and use distinct naming patterns.

### WFBE_CL_FNC_FindVariableInNestedArray

**File:** `Client/Functions/Client_FindVariableInNestedArray.sqf`  
**Registered:** `Client/Init/Init_Client.sqf:139`

#### Signature

```sqf
[_array, _value] call WFBE_CL_FNC_FindVariableInNestedArray
```

#### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_array` | Array of Arrays | Outer array; each element is itself an array. |
| 1 | `_value` | Any | Value to search for inside the inner arrays. |

#### Return value

The index of the first inner array that contains `_value`, or `-1` if not found. (`Client_FindVariableInNestedArray.sqf:11`)

#### Behavior

Uses `forEach` with `exitWith` on the outer array: for each inner array `_x`, tests `_value in _x` and exits with `_forEachIndex` on the first match. (`Client_FindVariableInNestedArray.sqf:7–9`) If no match is found, `_index` is nil; the trailing nil-guard returns `-1`. (`Client_FindVariableInNestedArray.sqf:11`)

Note: the source in `Common/Functions/Common_FindVariableInNestedArray.sqf` is a duplicate of this file but is never registered in `Init_Common.sqf` (note: lowercase `private` is valid in Arma 2 OA — SQF keywords are case-insensitive; only the inline-assignment form `private _var = value` is A3-only). The authoritative version is the client registration in `Init_Client.sqf:139`. Do not reference the Common copy — it is unreachable at runtime.

Call site: `Client/GUI/GUI_Menu_BuyUnits.sqf:491` — finds which artillery classname sub-array a selected unit class belongs to.

---

### ReplaceArray (dead code)

**File:** `Client/Functions/Client_ReplaceArray.sqf`  
**Registered:** `Client/Init/Init_Client.sqf:67` (bare name, legacy form)

#### Signature

```sqf
[_array, _indexExcluded] Call ReplaceArray
```

Returns a new array equal to `_array` with the element at `_indexExcluded` omitted, using a `for` loop write-through pattern. (`Client_ReplaceArray.sqf:6–10`)

This function is compiled and registered but has no call sites in the codebase. It is functionally equivalent to `WFBE_CO_FNC_ArrayShift` called with a single-element index list. It should be considered dead code; new code should use `WFBE_CO_FNC_ArrayShift` instead.

---

## Function Registration Summary

| Function | Registered name | File | Init line |
|----------|----------------|------|-----------|
| `WFBE_CO_FNC_AreWaypointsComplete` | Common | `Common/Init/Init_Common.sqf:94` | — |
| `WFBE_CO_FNC_ArrayPush` | Common | `Common/Init/Init_Common.sqf:95` | — |
| `WFBE_CO_FNC_ArrayRemoveIndex` | Common | `Common/Init/Init_Common.sqf:96` | — |
| `WFBE_CO_FNC_ArrayShift` | Common | `Common/Init/Init_Common.sqf:97` | — |
| `WFBE_CO_FNC_ArrayShuffle` | Common | `Common/Init/Init_Common.sqf:98` | — |
| `WFBE_CO_FNC_ChangeUnitGroup` | Common | `Common/Init/Init_Common.sqf:100` | — |
| `WFBE_CO_FNC_GetLiveUnits` | Common | `Common/Init/Init_Common.sqf:124` | — |
| `WFBE_CO_FNC_GetUnitConfigGear` | Common | `Common/Init/Init_Common.sqf:139` | — |
| `WFBE_CO_FNC_GetUnitsPerSide` | Common | `Common/Init/Init_Common.sqf:140` | — |
| `WFBE_CO_FNC_RevealArea` | Common | `Common/Init/Init_Common.sqf:145` | — |
| `GetUnitVehicle` | Common (legacy) | `Common/Init/Init_Common.sqf:65` | — |
| `WFBE_CL_FNC_FindVariableInNestedArray` | Client only | `Client/Init/Init_Client.sqf:139` | — |
| `ReplaceArray` | Client only (dead) | `Client/Init/Init_Client.sqf:67` | — |

---

## Continue Reading

- [Function-And-Module-Index](Function-And-Module-Index) — master index of all WFBE functions with file paths and registration lines
- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference) — `CreateUnit`, `CreateVehicle`, `CreateTeam`; `ChangeUnitGroup` is called from `CreateUnit`'s internal group guard
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — naming rules for `WFBE_CO_FNC_*`, `WFBE_CL_FNC_*`, and the legacy bare-name pattern
- [Waypoint-Helper-Function-Reference](Waypoint-Helper-Function-Reference) — `WaypointPatrol`, `WaypointPatrolTown`, `WaypointSimple`; `AreWaypointsComplete` is the companion query
- [SQF-Code-Atlas](SQF-Code-Atlas) — broad codebase map; cross-references these helpers in patrol FSMs and town AI loops
