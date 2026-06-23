# Server Composition Spawner Function Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Four closely related functions handle the spawning and destruction lifecycle of all server-side base structures and commander-placed WDDM positions. `Server_ConstructPosition` and `CreateDefenseTemplate` build objects; `BuildingDamaged` and `BuildingKilled` process the hit/killed event handlers attached to every structure after it is constructed.

---

## Registration in Init_Server.sqf

All four functions are compiled at mission start and assigned to global script variables.

| Global variable | Source file | `Init_Server.sqf` line |
|---|---|---|
| `BuildingDamaged` | `Server/Functions/Server_BuildingDamaged.sqf` | 19 |
| `BuildingKilled` | `Server/Functions/Server_BuildingKilled.sqf` | 21 |
| `CreateDefenseTemplate` | `Server/Functions/Server_CreateDefenseTemplate.sqf` | 25 |
| `Server_ConstructPosition` | `Server/Functions/Server_ConstructPosition.sqf` | 26 |

---

## Server_ConstructPosition

**File:** `Server/Functions/Server_ConstructPosition.sqf`

The entry point for all commander-placed WDDM defensive positions. Resolves a build-menu anchor classname to its composition template, converts each child's model-space offset to world space using direct trigonometry, and delegates each child to the stock `ConstructDefense` call.

### Signature

```sqf
[_side, _anchorType, _pos, _dir, _manned] Spawn Server_ConstructPosition
```

Run via `Spawn` (not `Call`) so `RequestDefense` can return immediately without blocking the PV handler while all composition children (`HandleEmptyVehicle`/`HandleDefense`) are spawned asynchronously.

### Parameters

| # | Name | Type | Notes |
|---|------|------|-------|
| 0 | `_side` | Side | The building faction (`west` or `east`). |
| 1 | `_anchorType` | String | CfgVehicles classname of the WDDM anchor. Must exist in `WFBE_POSITION_TEMPLATE_MAP`. |
| 2 | `_pos` | Array `[x,y,z]` | World position for the composition centre. |
| 3 | `_dir` | Number | Facing in Arma degrees (clockwise from north). |
| 4 | `_manned` | Bool | Whether crewable children should be staffed by AI. |

Source: `Server_ConstructPosition.sqf:9,12-16`

### Return value

Array of the created objects (one entry per `ConstructDefense` call that returned a non-nil result). Returns `[]` immediately on any validation failure.

### Caller

`Server/PVFunctions/RequestDefense.sqf:16` — invoked when `_defenseType` is found in `WFBE_POSITION_ANCHOR_NAMES`:

```sqf
[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
```

---

### Template Resolution

`WFBE_POSITION_TEMPLATE_MAP` is the single lookup table that maps every anchor classname to a composition template variable name and a faction-specificity flag.

**Definition:** `Server/Init/Init_Defenses.sqf:239-250`

```sqf
WFBE_POSITION_TEMPLATE_MAP = [
    [anchorClass, baseVarName, factionSpecific?],
    ...
];
```

Resolution logic (`Server_ConstructPosition.sqf:19-36`):

1. Walk `WFBE_POSITION_TEMPLATE_MAP` with `forEach`; match on `_anchorType`. If no match, log ERROR and return `[]`.
2. If `_factionSpecific` is `true`, append `"_WEST"` (side == west) or `"_EAST"` (any other side) to `_base`. If `false`, use `_base` unchanged.
3. Retrieve the template array via `missionNamespace getVariable _tplName`. If nil or empty, log ERROR/exit.

**Full anchor-to-template map (Init_Defenses.sqf:239-250):**

| Anchor classname | Base variable | Faction-specific | Description |
|---|---|---|---|
| `Land_Ind_BoardsPack1` | `WFBE_NEURODEF_AAPOS` | Yes | AA light (2 AI) |
| `Land_CncBlock_Stripes` | `WFBE_NEURODEF_AAPOS_HEAVY` | Yes | AA heavy (4 AI) |
| `Land_Barrel_sand` | `WFBE_NEURODEF_ARTYPOS_LIGHT` | Yes | Artillery light (1 AI gun) |
| `Land_Ind_BoardsPack2` | `WFBE_NEURODEF_ARTYPOS` | Yes | Artillery heavy (4 AI, 3-gun battery) |
| `Land_WoodenRamp` | `WFBE_NEURODEF_MIXEDPOS` | Yes | Mixed light (2 AI: MG + AT) |
| `RoadCone` | `WFBE_NEURODEF_MIXEDPOS_HEAVY` | Yes | Mixed heavy (4 AI) |
| `Paleta1` | `WFBE_NEURODEF_WALL_STRAIGHT` | No | Straight wall section |
| `Paleta2` | `WFBE_NEURODEF_WALL_CORNER` | No | Corner wall section |
| `Land_Ind_Timbers` | `WFBE_NEURODEF_WALL_GATE` | No | Gate wall section |

`WFBE_POSITION_ANCHOR_NAMES` (`Init_Defenses.sqf:250`) is the flat array of all anchor classnames; `RequestDefense.sqf` uses `find` against it to decide whether to route through `Server_ConstructPosition` or the single-defense path.

---

### World-Space Rotation

Each child's position is in model space (relative offset from the composition centre). The function converts to world space at `Server_ConstructPosition.sqf:50-56`:

```sqf
_worldPos = [
    (_pos select 0) + (_relPos select 0) * (cos _dir) + (_relPos select 1) * (sin _dir),
    (_pos select 1) - (_relPos select 0) * (sin _dir) + (_relPos select 1) * (cos _dir),
    0
];
_worldDir = _dir - _relDir;
```

**Historical note:** A previous iteration spawned a `Land_HelipadEmpty` "origin" object and used `modelToWorld` to transform child offsets. That approach was abandoned because the helper vehicle spawned at `[0,0,0]` (the map corner) rather than at `_pos`, placing the entire composition approximately 12 km away. The direct trigonometry method is deterministic and requires no spawned helper. (`Server_ConstructPosition.sqf:39-42`)

---

### ConstructDefense delegation

For each child entry `[_cls, _relPos, _relDir]`, `Server_ConstructPosition` calls:

```sqf
[_cls, _side, _worldPos, _worldDir, _manned, false,
    missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",
    false, true] Call ConstructDefense;
```

`Server_ConstructPosition.sqf:60`

| Argument | Value | Notes |
|---|---|---|
| class | `_cls` | From template entry |
| side | `_side` | Caller's faction |
| position | `_worldPos` | Computed above |
| direction | `_worldDir` | `_dir - _relDir` |
| manned | `_manned` | Passed through from request |
| arg 5 | `false` | `builtByRepairTruck` — always false for WDDM positions |
| manning range | `WFBE_C_BASE_DEFENSE_MANNING_RANGE` | Default 250 m (`Init_CommonConstants.sqf:126`) |
| arg 7 | `false` | |
| arg 8 | `true` | WDDM child flag |

Every crewable child (guns, AA pods) passes through `ConstructDefense` identically to a single player-built defense: AI manning, score registration, and artillery-enable all apply. Props (walls, sandbags, ammo boxes) are also handled by the same path.

**Object tagging:** Each returned object is tagged with a per-placement composite ID so downstream systems can count distinct placed compositions (`Server_ConstructPosition.sqf:43-45,67`):

```sqf
WFBE_WDDMPlacementCounter = WFBE_WDDMPlacementCounter + 1;
_placementID = format ["%1_%2", _anchorType, str WFBE_WDDMPlacementCounter];
// ...
_one setVariable ["WFBE_WDDMPositionAnchor", _placementID, true];
```

The ID is the anchor classname plus a global monotonic counter (e.g. `"Land_Ind_BoardsPack1_1"`, `"Land_Ind_BoardsPack1_2"`). All child objects from the same placement share one ID; two separate placements of the same anchor type get different IDs. `RequestDefense.sqf` (lines 156-160) deduplicates these values into `_seenIDs` to count the number of distinct compositions near a base — a count that requires unique-per-placement IDs, not bare classnames.

---

### WFBE_NEURODEF_* Template Format

Every composition template is an array of child entries stored in `missionNamespace`:

```sqf
[[classname, [relX, relY, relZ], relDir], ...]
```

| Field | Type | Notes |
|---|---|---|
| classname | String | CfgVehicles class for `createVehicle` / `ConstructDefense` |
| `[relX, relY, relZ]` | Array | Model-space offset from composition origin; Z is zeroed by the spawner |
| relDir | Number | Local facing offset; subtracted from `_dir` to get world direction |

**Faction-specific template roster (Init_Defenses.sqf):**

| Template variable | Line | WEST guns | EAST guns |
|---|---|---|---|
| `WFBE_NEURODEF_AAPOS_WEST/EAST` | 136/144 | `Stinger_Pod_US_EP1` ×2 | `ZU23_TK_EP1`, `Igla_AA_pod_TK_EP1` |
| `WFBE_NEURODEF_AAPOS_HEAVY_WEST/EAST` | 191/199 | `Stinger_Pod_US_EP1` ×3 + `M2StaticMG` | `ZU23_TK_EP1` ×2 + `Igla_AA_pod_TK_EP1` + `DSHKM_TK_INS_EP1` |
| `WFBE_NEURODEF_ARTYPOS_LIGHT_WEST/EAST` | 224/230 | `M119_US_EP1` ×1 | `D30_TK_EP1` ×1 |
| `WFBE_NEURODEF_ARTYPOS_WEST/EAST` | 154/163 | `M119_US_EP1` ×3 + `M2StaticMG` | `D30_TK_EP1` ×3 + `DSHKM_TK_INS_EP1` |
| `WFBE_NEURODEF_MIXEDPOS_WEST/EAST` | 174/181 | `M2StaticMG` + `TOW_TriPod_US_EP1` | `DSHKM_TK_INS_EP1` + `SPG9_TK_INS_EP1` |
| `WFBE_NEURODEF_MIXEDPOS_HEAVY_WEST/EAST` | 207/216 | `M2StaticMG` ×2 + `TOW_TriPod_US_EP1` + `Stinger_Pod_US_EP1` | `DSHKM_TK_INS_EP1` ×2 + `Metis_TK_EP1` + `Igla_AA_pod_TK_EP1` |

**Neutral wall templates (no faction suffix):**

| Template variable | Line | Contents |
|---|---|---|
| `WFBE_NEURODEF_WALL_STRAIGHT` | 120 | Straight HESCO/barrier row |
| `WFBE_NEURODEF_WALL_CORNER` | 124 | Corner barrier arrangement |
| `WFBE_NEURODEF_WALL_GATE` | 129 | Barrier row with access gap |

---

## CreateDefenseTemplate

**File:** `Server/Functions/Server_CreateDefenseTemplate.sqf`  
**Global alias:** `CreateDefenseTemplate` (`Init_Server.sqf:25`)

Spawns a wall/barrier ring around an already-placed structure object. Used exclusively by the site construction pipeline — not by WDDM commander positions (which go through `Server_ConstructPosition` + `ConstructDefense` instead).

### Signature

```sqf
[_origin, _template, _existingTemplate] Call CreateDefenseTemplate
```

`_existingTemplate` is optional; omit it or pass an empty array for a fresh build.

### Parameters

| # | Name | Type | Default | Notes |
|---|------|------|---------|-------|
| 0 | `_origin` | Object | _(required)_ | The structure the walls should surround; its `getDir` and `modelToWorld` drive placement. |
| 1 | `_template` | Array | _(required)_ | `WFBE_NEURODEF_*_WALLS` array; nil or non-array exits with WARNING. |
| 2 | `_existingTemplate` | Array | `[]` | Array of previously spawned objects at the same indices. Any that are `alive` are skipped and reused. |

Source: `Server_CreateDefenseTemplate.sqf:2-4`

### Return value

Array of objects in template-index order. Slots where an existing object was reused contain the original object; slots that were freshly created contain the new vehicle.

### Behavior

`Server_CreateDefenseTemplate.sqf:20-44`

For each entry `[_object, _relPos, _relDir]` in `_template`:

1. If `_i < count _existingTemplate` and `alive (_existingTemplate select _i)` is true, skip creation and reuse the existing object.
2. Otherwise: `createVehicle [_object, [0,0,0], [], 0, "NONE"]`; tag it `wfbe_defense = true`; position via `_origin modelToWorld _relPos` (z zeroed); set direction `getDir _origin - _relDir`.

This incremental-rebuild pattern means calling `CreateDefenseTemplate` again with the current wall array safely fills only destroyed slots without disturbing intact barriers.

**Note:** `CreateDefenseTemplate` uses `modelToWorld` on the structure origin, which is reliable because `_origin` is a fully positioned, non-null object — unlike the abandoned `Land_HelipadEmpty` approach in `Server_ConstructPosition`. The `[0,0,0]` spawn location is immediately overwritten by `setPos`.

### Callers

| Site type | Caller file | Call line |
|---|---|---|
| HQ | `Server/Construction/Construction_HQSite.sqf` | 39 |
| Medium (Barracks, Factory, etc.) | `Server/Construction/Construction_MediumSite.sqf` | 126 |
| Small (Service point, light factory) | `Server/Construction/Construction_SmallSite.sqf` | 111 |

The Medium and Small site callers resolve the wall template via `missionNamespace getVariable format ["WFBE_NEURODEF_%1_WALLS", _rlType]`. The HQ caller passes the hardcoded string `"WFBE_NEURODEF_HEADQUARTERS_WALLS"` directly (no `format` call, no `_rlType` variable). Branch note from the 2026-06-23 auto-wall refresh: docs/source, current Miksuu and perf have no SmallSite/MediumSite structure exclusions beyond the global toggle, historical `a96fdda2` excludes only `AARadar`, and current stable/B69/B74 exclude `AARadar`/`CBRadar` for SmallSite plus `AARadar`/`Bank`/`Reserve`/`ArtilleryRadar` for MediumSite.

**Auto-wall gate:** `isAutoWallConstructingEnabled` is a mission-global value. Docs/source, current Miksuu and perf initialize it `false` at `Common/Init/Init_Common.sqf:201`; current stable initializes it `true` at `:213`; current B69/B74 initialize it `true` at `:214`; historical `a96fdda2` initializes it `true` at `:201`. Players with the commander role can toggle it via `User14` keybind (`coin_interface.sqf:180,207-217`); the new value is sent to the server via the `RequestAutoWallConstructinChange` public variable (`Common/Init/Init_PublicVariables.sqf:21`; handler writes one global at `RequestAutoWallConstructinChange.sqf:3-7`).

**Per-structure wall templates (Init_Defenses.sqf):**

| `_rlType` | Template variable | Line |
|---|---|---|
| `Barracks` | `WFBE_NEURODEF_BARRACKS_WALLS` | 4 |
| `Light` (light factory) | `WFBE_NEURODEF_LIGHT_WALLS` | 11 |
| `CommandCenter` | `WFBE_NEURODEF_COMMANDCENTER_WALLS` | 24 |
| `ServicePoint` | `WFBE_NEURODEF_SERVICEPOINT_WALLS` | 34 (empty array) |
| `AARadar` | `WFBE_NEURODEF_AARADAR_WALLS` | 39 (empty array, also caller-gated) |
| `Headquarters` | `WFBE_NEURODEF_HEADQUARTERS_WALLS` | 44 |
| `Heavy` (heavy factory) | `WFBE_NEURODEF_HEAVY_WALLS` | 70 |
| `Aircraft` (aircraft factory) | `WFBE_NEURODEF_AIRCRAFT_WALLS` | 86 |

---

## BuildingDamaged

**File:** `Server/Functions/Server_BuildingDamaged.sqf`  
**Global alias:** `BuildingDamaged` (`Init_Server.sqf:19`)

Attached as a `"hit"` event handler to every constructed structure. Applies server-side damage reduction and throttles the "IsUnderAttack" side notification.

### Event handler shape

```sqf
_site addEventHandler ["hit", {_this Spawn BuildingDamaged}];
```

`_this` in the EH is `[hitObject, causedBy, damage]` in Arma 2 OA. The function reads arguments positionally:

| `_this` index | Variable | Notes |
|---|---|---|
| 0 | `_structure` | The hit building |
| 1 | `_damagedBy` | Causer (object or unit that caused the hit; not used for logic, read only) |
| 2 | `_damage` | Raw damage value from the hit |

`Server_BuildingDamaged.sqf:3-5`

### Damage reduction

`Server_BuildingDamaged.sqf:6`

```sqf
_redu = if (_structure isKindOf "Warfare_HQ_base_unfolded") then {5}
        else {missionNamespace getVariable "WFBE_C_STRUCTURES_DAMAGES_REDUCTION"};
```

| Structure | Reduction divisor | Source |
|---|---|---|
| `Warfare_HQ_base_unfolded` (unfolded mobile HQ) | 5 (hardcoded) | `Server_BuildingDamaged.sqf:6` |
| All other structures | `WFBE_C_STRUCTURES_DAMAGES_REDUCTION` = **6** | `Init_CommonConstants.sqf:313` |

The reduced damage is not written back to the object's damage state — this function only fires the side alert. Actual structure HP is governed by the `handleDamage` EH registered separately (`Construction_MediumSite.sqf:144-148`, `Construction_SmallSite.sqf:128-133`).

### Side alert throttle

`Server_BuildingDamaged.sqf:10-14`

Fires a `SideMessage "IsUnderAttack"` only when:
- The structure is not already at full destruction (`getDammage + _damage / _redu < 1`), **and**
- At least 2 seconds have elapsed since the last alert (`time - wfbe_structure_lasthit > 2`), **and**
- The hit was meaningful (`_damage > 0.05`).

The per-side timestamp is stored in the side logic object: `_logik setVariable ["wfbe_structure_lasthit", time]`.

---

## BuildingKilled

**File:** `Server/Functions/Server_BuildingKilled.sqf`  
**Global alias:** `BuildingKilled` (`Init_Server.sqf:21`)

Attached as a `"killed"` event handler to medium and small site structures (not HQ — HQ has its own `WFBE_SE_FNC_OnHQKilled`). Handles kill credit, score, supplies, and structural bookkeeping before deleting the vehicle.

### Event handler shape

Attached via a compiled format string so the structure type is baked in at construction time:

```sqf
Call Compile Format ["_site AddEventHandler ['killed',{[_this select 0,_this select 1,'%1'] Spawn BuildingKilled}];", _type];
```

`Construction_MediumSite.sqf:149`, `Construction_SmallSite.sqf:134`

### Parameters (as received by the function)

| Index | Variable | Notes |
|---|---|---|
| 0 | `_structure` | The killed building object |
| 1 | `_killer` | The unit responsible |
| 2 | `_type` | CfgVehicles class of `_structure`, baked in at EH attachment |

`Server_BuildingKilled.sqf:2-4`

### Bounty table

`Server_BuildingKilled.sqf:26-35`

Uses `isKindOf` matching, so subclasses are covered. The `default` branch catches any type not explicitly listed.

| `isKindOf` match | `_bounty` |
|---|---|
| `Base_WarfareBBarracks` | 3000 |
| `Base_WarfareBLightFactory` | 4500 |
| `Base_WarfareBHeavyFactory` | 7000 |
| `Base_WarfareBAircraftFactory` | 8000 |
| `Base_WarfareBUAVterminal` | 5000 |
| `Base_WarfareBVehicleServicePoint` | 3000 |
| `BASE_WarfareBAntiAirRadar` | 8000 |
| default | 3000 |

### Score calculation

`Server_BuildingKilled.sqf:38-47,64-65`

> **Note:** The `_score` switch (`Server_BuildingKilled.sqf:38-47`) returns `0` for the `default` case. Structures not explicitly listed in the switch yield no score despite the `_bounty` switch awarding a default of 3000. Only the seven explicitly matched types produce a non-zero score before the 3× multiplier is applied.

Base score: `_bounty * WFBE_C_UNITS_BOUNTY_COEF / 100`  
`WFBE_C_UNITS_BOUNTY_COEF` = **1** (`Init_CommonConstants.sqf:375`), making the initial score equal to `_bounty / 100`.

Final score: `_score * 3` — a hardcoded 3× multiplier applied after the bounty calculation.

```sqf
_score = _score * 3;  // Server_BuildingKilled.sqf:65
['SRVFNCREQUESTCHANGESCORE', [leader _killerGroup, score leader _killerGroup + _score]]
    Spawn WFBE_SE_FNC_HandlePVF;
```

Score is applied to the **leader of the killer's group**, not the killer directly.

### Guerrilla barracks special case

`Server_BuildingKilled.sqf:49-58`

When `typeOf _structure == "Gue_WarfareBBarracks"` (the GUER/resistance barracks), the function:

1. Overrides `_bounty` to 3000 and `_supplies` to 500.
2. Sends a "HeadHunterReceiveBountyInSupplies" notification to the killer's side.
3. Calls `[_side_killer, 500, "", false] Call ChangeSideSupply` to credit supplies directly.
4. Recalculates score from the new bounty before the 3× multiplier applies.

### Teamkill path

If `side _killer == _side` (structure's side), no score or supplies are awarded; a `"BuildingTeamkill"` message is broadcast to the building side. (`Server_BuildingKilled.sqf:17-20`)

### Post-kill bookkeeping

`Server_BuildingKilled.sqf:81-96`

1. Finds `_type` in `WFBE_%1STRUCTURENAMES` for the building side.
2. Decrements `wfbe_structures_live` at the matching index in the side logic object.
3. Removes `_structure` from `wfbe_structures`.
4. Fires a `SideMessage "Destroyed"`.
5. `sleep 10` — 10-second grace period before `deleteVehicle _structure`.

Resistance-side structures (`_side == resistance`) skip steps 1–4 since resistance has no side logic object or structure-limit tracking.

---

## Developer Notes

**Adding a new WDDM position type:** Register the anchor classname in `WFBE_POSITION_TEMPLATE_MAP` (`Init_Defenses.sqf:239`) and add both `_WEST` and `_EAST` template variables above it (or set `factionSpecific = false` if both sides share the layout). Without the map entry, `Server_ConstructPosition` logs an ERROR and returns `[]` silently — no in-game feedback to the commander.

**Do not re-introduce `modelToWorld` in `Server_ConstructPosition`:** The direct-trig approach is intentional. Any vehicle spawned at `[0,0,0]` for use as a `modelToWorld` origin will land at the map corner because Arma 2 OA does not teleport newly created vehicles to a requested position before the next game frame when that position is inside `createVehicle`.

**`CreateDefenseTemplate` incremental rebuild:** Pass the existing wall array as argument 2 when rebuilding a destroyed structure's walls. Alive objects at matching indices are left in place; only destroyed indices are re-created. This avoids duplicate props overlapping with survivors.

---

## Continue Reading

- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — high-level map of all construction pipeline files and how site types relate.
- [Defense-Structures-Catalog](Defense-Structures-Catalog) — full catalog of buildable defense classnames per faction, including those used inside WFBE_NEURODEF compositions.
- [Kill-And-Score-Pipeline](Kill-And-Score-Pipeline) — end-to-end scoring architecture; covers `WFBE_SE_FNC_HandlePVF`, `SRVFNCREQUESTCHANGESCORE`, and bounty coefficient interactions.
- [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas) — server init sequence and which globals are available at each phase.
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` constant naming rules, `WFBE_NEURODEF_*` namespace, and `wfbe_defense` object variable conventions.
