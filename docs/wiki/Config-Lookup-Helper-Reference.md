# Config Lookup Helper Reference (GetConfigEntry / GetConfigInfo / GetGroupFromConfig / turret family)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

WASP provides a family of compiled config-reading helpers that sit above the raw `configFile >>` operator. This page documents all six functions, their call contracts, their registration names, and where each is consumed in the codebase.

---

## Function Registration

All six functions are compiled at init time on both the server and headless client from `Common/Init/Init_Common.sqf`. Two use the legacy bare-name convention; four use the `WFBE_CO_FNC_*` prefix.

| Global name | Source file | Registration line |
|---|---|---|
| `GetConfigInfo` | `Common/Functions/Common_GetConfigInfo.sqf` | `Common/Init/Init_Common.sqf:29` |
| `GetGroupFromConfig` | `Common/Functions/Common_GetGroupFromConfig.sqf` | `Common/Init/Init_Common.sqf:32` |
| `WFBE_CO_FNC_GetConfigEntry` | `Common/Functions/Common_GetConfigEntry.sqf` | `Common/Init/Init_Common.sqf:121` |
| `WFBE_CO_FNC_FindTurretsRecursive` | `Common/Functions/Common_FindTurretsRecursive.sqf` | `Common/Init/Init_Common.sqf:112` |
| `WFBE_CO_FNC_GetVehicleTurretsGear` | `Common/Functions/Common_GetVehicleTurretsGear.sqf` | `Common/Init/Init_Common.sqf:141` |
| *(inline — not compiled to a global)* | `Common/Functions/Common_GetConfigVehicleCrewSlot.sqf` | called via `Compile preprocessFile` at each call site |

`GetConfigVehicleCrewSlot` is never assigned a global name; every faction Core file invokes it with a fresh `Compile preprocessFile` at startup. See the [Crew Slot section](#common_getconfigvehiclecrewslot) below.

---

## `GetConfigInfo`

**File:** `Common/Functions/Common_GetConfigInfo.sqf`

### Signature

```sqf
[_object, _element] Call GetConfigInfo
[_object, _element, _from] Call GetConfigInfo
```

| Param | Type | Description |
|---|---|---|
| `_object` | String or Object | Classname string, or an `OBJECT` — if `typeName _object == 'OBJECT'` the function substitutes `typeOf _object` automatically (`Common_GetConfigInfo.sqf:6`). |
| `_element` | String | Key to read (e.g. `'displayName'`, `'picture'`, `'portrait'`). |
| `_from` | String | Config root. Optional; defaults to `'CfgVehicles'` when omitted (`Common_GetConfigInfo.sqf:4`). Pass `'CfgWeapons'` or `'CfgMagazines'` as needed. |

### Behavior

Calls `getText (configFile >> _from >> _object >> _element)` directly (`Common_GetConfigInfo.sqf:7`). Returns an empty string if the key is absent or if the class does not exist — no recursive parent-class walk. This is a flat single-level read.

### Usage

This is the most-called config helper in the codebase. Representative call sites:

| Call site | What it reads |
|---|---|
| `Client/Functions/Client_SupportHeal.sqf:10` | `[typeOf _veh, 'displayName'] Call GetConfigInfo` — vehicle display name for chat message |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:438` | `[(_weapons select _i), 'displayName', 'CfgWeapons'] Call GetConfigInfo` — weapon name in buy panel |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:431` | `[_x, 'displayName', 'CfgMagazines'] Call GetConfigInfo` — magazine name in buy panel |
| `Client/GUI/GUI_Menu_Tactical.sqf:655` | `[typeOf _x, 'picture'] Call GetConfigInfo` — unit picture icon in tactical list |
| `Client/Functions/Client_UIFillListTeamOrders.sqf:32` | `[typeOf _unit, 'portrait'] Call GetConfigInfo` — portrait for infantry in team orders list |

**When to use `GetConfigInfo` vs `WFBE_CO_FNC_GetConfigEntry`:** use `GetConfigInfo` when the classname is known to be a concrete (non-inherited) entry in the target config, or when only a text value is needed quickly. Use `WFBE_CO_FNC_GetConfigEntry` when you need a number or array, or when the class hierarchy may carry the value in a parent class.

---

## `WFBE_CO_FNC_GetConfigEntry`

**File:** `Common/Functions/Common_GetConfigEntry.sqf`

### Signature

```sqf
[_config, _entryName] Call WFBE_CO_FNC_GetConfigEntry
```

| Param | Type | Description |
|---|---|---|
| `_config` | Config | A config reference, not a classname string. Must satisfy `typeName _config == typeName configFile`; exits with `nil` and a `debugLog` if not (`Common_GetConfigEntry.sqf:14`). |
| `_entryName` | String | Key to read. Must be a string; exits with `nil` and a `debugLog` if not (`Common_GetConfigEntry.sqf:15`). |

### Behavior

1. Looks up `_config >> _entryName`. If `configName` of that entry is the empty string (i.e. the key does not exist at this class level) **and** the current class is not already `CfgVehicles`, `CfgWeapons`, or the config root `""`, it recurses: `[inheritsFrom _config, _entryName] Call WFBE_CO_FNC_GetConfigEntry` (`Common_GetConfigEntry.sqf:21-22`). This is the recursive `inheritsFrom` walk up the class hierarchy.
2. When the entry is found (or the root is reached), it dispatches by type (`Common_GetConfigEntry.sqf:25-29`):

| Entry type | Accessor used | Return type |
|---|---|---|
| `isNumber` | `getNumber` | Number |
| `isText` | `getText` | String |
| `isArray` | `getArray` | Array |

3. Returns `nil` if no match is found after exhausting the hierarchy (`Common_GetConfigEntry.sqf:33`).

**Note on recursion root:** the walk stops at the first parent class whose `configName` is `"CfgVehicles"`, `"CfgWeapons"`, or `""`. It does not walk into other config roots.

### Usage

The call convention requires building the config reference before calling:

```sqf
// GUI_BuyGearMenu.sqf:428 — read displayName from CfgVehicles via configFile path
[configFile >> 'CfgVehicles' >> typeOf _target, "displayName"] Call WFBE_CO_FNC_GetConfigEntry

// Labels_Upgrades.sqf:85 — read displayName via missionNamespace variable holding a side-specific class
[configFile >> 'CfgVehicles' >> (missionNamespace getVariable Format["WFBE_%1PARACARGO", WFBE_Client_SideJoinedText]), "displayName"] Call WFBE_CO_FNC_GetConfigEntry
```

| Call site | Context |
|---|---|
| `Client/GUI/GUI_BuyGearMenu.sqf:428` | Fetches display name of Man target when inventory changed (inside `isKindOf "Man"` branch) |
| `Client/GUI/GUI_BuyGearMenu.sqf:438` | Fetches display name of vehicle target when vehicle gear changed |
| `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:85` | Fetches para-cargo vehicle display name for upgrade label |

---

## `GetGroupFromConfig`

**File:** `Common/Functions/Common_GetGroupFromConfig.sqf`

### Signature

```sqf
[_side, _faction, _kind, _type] Call GetGroupFromConfig
```

| Param | Type | Description |
|---|---|---|
| `_side` | String | CfgGroups side key (e.g. `"East"`, `"West"`, `"Guerrila"`). |
| `_faction` | String | Faction class under the side key. |
| `_kind` | String | Group kind class under the faction. |
| `_type` | String | Group type class under the kind. |

### Behavior

Navigates `configFile >> "CfgGroups" >> _side >> _faction >> _kind >> _type` (`Common_GetGroupFromConfig.sqf:7`). If `isClass _config` is true, iterates all sub-classes; for each sub-class it reads `getText(_mclass >> "vehicle")` and appends the result to the output array (`Common_GetGroupFromConfig.sqf:11-18`). Returns the array of vehicle classnames representing the AI squad composition.

If the config path is not a valid class, logs an error via `WFBE_CO_FNC_LogContent` and returns `[]` (`Common_GetGroupFromConfig.sqf:20`).

### Return value

An array of classname strings, one element per unit slot in the squad template (in config declaration order). Empty array on failure.

### Registration vs. usage

`GetGroupFromConfig` is registered at `Common/Init/Init_Common.sqf:32` but has no call site in the Chernarus mission scripts outside its own file — its usage is in the AI squad-building pipeline for faction-configured squads. Any new faction or AI group work that needs to resolve squad templates from `CfgGroups` should call this function rather than re-implementing the `CfgGroups` walk.

---

## Turret Discovery Pipeline

Three functions collaborate to enumerate all armed turrets on a vehicle and return their weapon/magazine loadouts. They are the foundation of `RearmVehicleOA` and `LoadArtilleryAmmo`.

### Pipeline overview

```
vehicle classname
      |
      v
WFBE_CO_FNC_GetVehicleTurretsGear
      |  reads configFile >> CfgVehicles >> class >> turrets
      |  calls WFBE_CO_FNC_FindTurretsRecursive
      v
_result array of [weapons[], magazines[], turretPath[], classPathStr]
      |
      v
WFBE_CO_FNC_SetTurretsMagazines  (downstream consumer, not documented here)
```

---

### `WFBE_CO_FNC_GetVehicleTurretsGear`

**File:** `Common/Functions/Common_GetVehicleTurretsGear.sqf`

#### Signature

```sqf
_vehicle Call WFBE_CO_FNC_GetVehicleTurretsGear
// or
_classname Call WFBE_CO_FNC_GetVehicleTurretsGear
```

`_this` may be a STRING (classname) or OBJECT; the function resolves the classname via a `switch (typeName _this)` (`Common_GetVehicleTurretsGear.sqf:11`). Any other type resolves to `nil`, which produces an empty result.

#### Behavior

1. Builds the config entry: `configFile >> "CfgVehicles" >> _resolvedClass >> "turrets"` (`Common_GetVehicleTurretsGear.sqf:11`).
2. Initialises `_result = []` in the local namespace, then calls `[_class, []] call WFBE_CO_FNC_FindTurretsRecursive` (`Common_GetVehicleTurretsGear.sqf:12`). `FindTurretsRecursive` populates `_result` via `_result set [count _result, ...]` (see below).
3. Returns `_result` — the accumulated array of turret records (`Common_GetVehicleTurretsGear.sqf:14`).

#### Return format

Each element of `_result` is a 4-element array (from `Common_FindTurretsRecursive.sqf:17`):

| Index | Content | Type |
|---|---|---|
| 0 | Weapons on this turret | Array of Strings |
| 1 | Magazines on this turret | Array of Strings |
| 2 | Turret path (indices from config root) | Array of Numbers |
| 3 | String representation of the config class path | String |

Example comment in source (`Common_GetVehicleTurretsGear.sqf:3`):
```
[["M256","M240BC_veh"],["20Rnd_120mmSABOT_M1A2","20Rnd_120mmHE_M1A2","1200Rnd_762x51_M240"],[0],"bin\config.bin/CfgVehicles/M1A2_TUSK_MG/Turrets/MainTurret"]
```

#### Live callers

| Caller | Purpose |
|---|---|
| `Common/Functions/Common_RearmVehicleOA.sqf:12` | Builds turret list before calling `SetTurretsMagazines` to restock vehicle ammo |
| `Common/Functions/Common_LoadArtilleryAmmo.sqf:32` | Builds turret list to selectively reload artillery rounds |

---

### `WFBE_CO_FNC_FindTurretsRecursive`

**File:** `Common/Functions/Common_FindTurretsRecursive.sqf`

#### Signature

```sqf
[_root, _path] call WFBE_CO_FNC_FindTurretsRecursive
```

| Param | Type | Description |
|---|---|---|
| `_root` | Config | The `turrets` config class to enumerate. |
| `_path` | Array | The turret index path accumulated so far; pass `[]` at the top level. |

#### Behavior

Iterates all sub-classes of `_root`; for each class, appends a record to the caller's `_result` variable, then recurses into `_class >> "turrets"` if that sub-key is itself a class (`Common_FindTurretsRecursive.sqf:13-20`). Reads `getArray(_class >> "weapons")` and `getArray(_class >> "magazines")` for each turret node.

**`_result` is shared state:** the function writes to a variable named `_result` in the calling scope, not its own local scope. `GetVehicleTurretsGear` initialises `_result = []` before calling `FindTurretsRecursive`, so callers of `GetVehicleTurretsGear` should not call `FindTurretsRecursive` directly.

This function is credited to the BIS `weaponsTurret` wiki pattern (source comment: `Common_FindTurretsRecursive.sqf:2`; reference: `http://community.bistudio.com/wiki/weaponsTurret`).

---

### `Common_GetConfigVehicleCrewSlot` (inline, no global name)

**File:** `Common/Functions/Common_GetConfigVehicleCrewSlot.sqf`

This file has no registered global name and is never pre-compiled. Each caller invokes:

```sqf
_ret = (_c select _z) Call Compile preprocessFile "Common\Functions\Common_GetConfigVehicleCrewSlot.sqf";
```

where `_this` is a classname string.

#### Behavior

1. Builds the config entry: `configFile >> 'CfgVehicles' >> _this >> 'Turrets'` (`Common_GetConfigVehicleCrewSlot.sqf:3`).
2. Initialises mission-namespace globals `vhasCommander = false` and `vhasGunner = false` (`Common_GetConfigVehicleCrewSlot.sqf:5-6`).
3. Calls `Common_GetConfigVehicleTurretsReturn.sqf` (via `Compile preprocessFile`) to get a flat turret index list, then calls `Common_GetConfigVehicleTurrets.sqf` to recursively walk sub-turrets, accumulating into `tmp_overall` (`Common_GetConfigVehicleCrewSlot.sqf:7-12`).
4. Subtracts 1 from the total turret count for the gunner slot (if `vhasGunner`) and for the commander slot (if `vhasCommander`) (`Common_GetConfigVehicleCrewSlot.sqf:16-17`), yielding the number of passenger/AI crew slots.
5. Returns `[[vhasCommander, vhasGunner, count(tmp_overall)+1, _turrestcount], tmp_overall]` (`Common_GetConfigVehicleCrewSlot.sqf:18`).

#### Return format

| Index | Content |
|---|---|
| 0 | `[hasCommander (Bool), hasGunner (Bool), totalSlots (Number), turretCount (Number)]` |
| 1 | `tmp_overall` — array of turret paths from the recursive walk |

#### Live callers

Called during startup in every faction Core file (`Common/Config/Core/Core_*.sqf`) when an entry in the buy list has crew-slot value `== -2` (the sentinel meaning "auto-detect from config"). The return value's index 0 is stored at `(_i select _z) set [4, _ret select 0]` and the turret path array at `(_i select _z) set [9, _ret select 1]`.

This pattern appears in: `Core_US.sqf:294`, `Core_RU.sqf:212`, `Core_TKA.sqf:260`, `Core_BAF.sqf:119`, `Core_CDF.sqf:171`, `Core_INS.sqf:186`, `Core_GUE.sqf:139`, `Core_PMC.sqf:86`, and all other faction core files.

---

## `Common_GetConfigVehicleTurretsReturn` (sub-helper, inline)

**File:** `Common/Functions/Common_GetConfigVehicleTurretsReturn.sqf`

Not pre-compiled to any global. Called inline from `Common_GetConfigVehicleCrewSlot.sqf:7` and from `Common_GetConfigVehicleTurretsReturn.sqf:41` itself (recursion).

Takes a `Turrets` config entry (`_this = _entry`), enumerates sub-classes, and for each sub-class reads `hasGunner` via `BIS_fnc_returnConfigEntry` (`Common_GetConfigVehicleTurretsReturn.sqf:22`). Sets the mission-namespace globals `vhasGunner` and `vhasCommander` based on `primaryGunner` and `primaryObserver` fields. Returns a flat array of `[turretIndex, subTurretArray]` pairs (`Common_GetConfigVehicleTurretsReturn.sqf:36,41 and :45`) consumed by `Common_GetConfigVehicleTurrets.sqf`.

Note: `Common_GetConfigVehicleTurretsReturn.sqf` calls `BIS_fnc_returnConfigEntry`, not `WFBE_CO_FNC_GetConfigEntry`. This is intentional — it is a BIS-origin pattern retained from upstream.

---

## Choosing the Right Function

| Need | Use |
|---|---|
| Display name / picture / portrait of a unit or vehicle, fast | `GetConfigInfo` |
| Any config value where the class may inherit from a parent | `WFBE_CO_FNC_GetConfigEntry` (pass the full `configFile >> "CfgVehicles" >> _class` path as param 0) |
| Resolve AI squad composition from `CfgGroups` | `GetGroupFromConfig` |
| Get all turret weapons/magazines for rearming | `WFBE_CO_FNC_GetVehicleTurretsGear` |
| Detect how many gunner/commander/passenger slots a vehicle has | `Common_GetConfigVehicleCrewSlot` (inline `Compile preprocessFile`) |

---

## Common Pitfalls

**`GetConfigInfo` does not walk `inheritsFrom`.** If a classname inherits `displayName` from a parent class and does not override it, `GetConfigInfo` returns an empty string. This is safe for standard BIS classes (which all define `displayName` directly) but will fail for mod classes that inherit the field. Use `WFBE_CO_FNC_GetConfigEntry` when inheritance is a concern.

**`WFBE_CO_FNC_GetConfigEntry` takes a Config, not a String.** Passing a bare classname string causes an immediate `exitWith nil` and a `debugLog` (`Common_GetConfigEntry.sqf:14`). Always build the config reference: `configFile >> "CfgVehicles" >> _classname`.

**`_result` shared-state pattern in `FindTurretsRecursive`.** The function modifies `_result` in the calling scope, not its own locals. Do not call `WFBE_CO_FNC_FindTurretsRecursive` directly without first initialising `_result = []` in the calling scope; use `WFBE_CO_FNC_GetVehicleTurretsGear` instead.

**`GetConfigVehicleCrewSlot` leaves `tmp_overall` in scope.** The function writes to the mission-namespace variable `tmp_overall` as a side effect. Faction Core files read this array immediately after the call and then discard it. Do not rely on `tmp_overall` persisting across calls.

---

## Continue Reading

- [Function-And-Module-Index](Function-And-Module-Index) — full catalog of all compiled SQF function globals registered at init time, including registration line numbers
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — how `RearmVehicleOA` (which calls `GetVehicleTurretsGear`) fits into the broader vehicle equipment pipeline
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — the faction Core files that call `GetConfigVehicleCrewSlot` and `GetConfigInfo` during startup to populate buy-list entries
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_CO_FNC_*` vs legacy bare-name conventions; why `GetConfigInfo` and `GetGroupFromConfig` predate the prefixed naming scheme
- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference) — the companion function reference covering vehicle and unit spawn primitives that consume config data read by these helpers
