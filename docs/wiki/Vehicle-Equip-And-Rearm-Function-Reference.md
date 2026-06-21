# Vehicle Equip and Rearm Function Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the post-spawn vehicle and unit modification pipeline: how units receive loadouts, how vehicles get cargo, how every vehicle gets rearmed after a service call, and the per-type damage-reduction closures applied at spawn time. These functions are registered in `Common/Init/Init_Common.sqf` and several are split into vanilla / OA variants selected at startup via the `WF_A2_Vanilla` preprocessor flag.

---

## Runtime flag: WF_A2_Vanilla

Set at `initJIPCompatible.sqf:95–97` via `#ifdef VANILLA`. When `false` (the shipping Arrowhead / Combined Ops build), several functions are replaced with OA variants that use `Global`-suffixed commands and turret-path-aware APIs. The table below notes which functions diverge.

| Flag | Value in shipping build | Effect |
|---|---|---|
| `WF_A2_Vanilla` | `false` | OA variants active for Rearm, EquipVehicle, EquipBackpack, ClearVehicleCargo, SetTurretsMagazines, RemoveCountermeasures |
| `IS_chernarus_map_dependent` | `true` on Chernarus, `false` on desert maps | Controls texture branch in `Common_AddVehicleTexture.sqf` |

Source: `initJIPCompatible.sqf:95-117`

---

## Unit loadout functions

### WFBE_CO_FNC_EquipUnit

Registered at `Common/Init/Init_Common.sqf:110`.

**Signature**

```
[_unit, _weapons, _magazines, _eligible, {_backpack}, {_backpack_content}] Call WFBE_CO_FNC_EquipUnit
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_unit` | Object | Unit to equip |
| 1 | `_weapons` | Array of String | Weapon class names, passed to `addWeapon` |
| 2 | `_magazines` | Array of String | Magazine class names, passed to `addMagazine` |
| 3 | `_eligible` | Array of String | Priority weapon list; first non-empty string is selected via `selectWeapon` |
| 4 | `_backpack` | String (optional) | Backpack class or `""` to remove existing backpack |
| 5 | `_backpack_content` | Array (optional) | Content struct (see `EquipBackpack`) |

**Behavior** (`Common/Functions/Common_EquipUnit.sqf:22-37`)

1. `removeAllWeapons` then `removeAllItems` on `_unit`.
2. Adds all `_weapons` first, then all `_magazines`. (Weapons must precede magazines so each magazine binds to a matching muzzle; reversing the order causes OA to throw "Cannot use magazine X in muzzle Y".)
3. Iterates `_eligible`; on the first non-empty string, reads `CfgWeapons >> _use >> muzzles` — if the muzzle list contains `"this"` the weapon is selected directly, otherwise `_muzzles select 0` is selected.
4. Delegates to `WFBE_CO_FNC_EquipBackpack` with `[_unit, _backpack, _backpack_content]`.

**Call sites**

| Site | Context |
|---|---|
| `Client/Init/Init_Client.sqf:579,581` | Player initial loadout on join |
| `Client/GUI/GUI_BuyGearMenu.sqf:429` | Gear store purchase |
| `Client/Functions/Client_OnRespawnHandler.sqf:74,101,103` | Player respawn |
| `Server/AI/AI_AdvancedRespawn.sqf:72,74` | AI respawn (OA path) |
| `Server/AI/AI_SquadRespawn.sqf:60,62` | AI respawn (vanilla path) |

Source: `Common/Functions/Common_EquipUnit.sqf:12-37`

---

### EquipLoadout

Registered at `Common/Init/Init_Common.sqf:22`. Legacy entry point; its call site in `Client/Init/Init_Client.sqf:562` is commented out.

**Signature**

```
[_unit, _weapons, _ammo] Call EquipLoadout
```

| Position | Parameter | Type |
|---|---|---|
| 0 | `_unit` | Object |
| 1 | `_weapons` | Array of String |
| 2 | `_ammo` | Array of String |

**Behavior** (`Common/Functions/Common_EquipLoadout.sqf:7-25`)

Calls `removeAllWeapons` + `removeAllItems`, adds weapons then magazines (weapons must be added first so each magazine binds to the correct muzzle in OA; the source has a `//--- Weapons FIRST` comment at line 18), then selects a weapon as follows: first calls `primaryWeapon _unit`; if the result is non-empty it is used directly as `_use`. Only if `_use == ""` does it fall back to scanning `_weapons` for a `CfgWeapons >> type` in `[1,2,4,5]` (primary/handgun/GL/launcher). Unlike `EquipUnit`, it has no `_eligible` priority list and no backpack handling. **Status: effectively dead** — replaced by `WFBE_CO_FNC_EquipUnit` everywhere active.

Source: `Common/Functions/Common_EquipLoadout.sqf:1-25`

---

### WFBE_CO_FNC_EquipBackpack

Registered at `Common/Init/Init_Common.sqf:109`. OA only — the vanilla assignment is `{{}}` (no-op).

**Signature**

```
[_unit, _backpack, {_backpack_content}] Call WFBE_CO_FNC_EquipBackpack
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_unit` | Object | |
| 1 | `_backpack` | String | Class name or `""` |
| 2 | `_backpack_content` | Array (optional) | `[[[weapons],[counts]],[[mags],[counts]]]` |

**Behavior** (`Common/Functions/Common_EquipBackpack.sqf:16-42`)

1. Always removes the existing backpack via `unitBackpack` + `removeBackpack`.
2. If `_backpack != ""`, adds the backpack and clears its default contents with `clearWeaponCargoGlobal` + `clearMagazineCargoGlobal`.
3. Iterates the content struct (index 0 = weapons, index 1 = magazines) and calls `addWeaponCargoGlobal` / `addMagazineCargoGlobal` on the backpack object.

**Content struct layout** (mirrors `EquipVehicle` cargo struct):

```
_backpack_content = [
    [[weapon_class, ...], [count, ...]],   // index 0: weapons
    [[mag_class, ...],    [count, ...]]    // index 1: magazines
]
```

Source: `Common/Functions/Common_EquipBackpack.sqf:9-42`

---

## Vehicle cargo functions

### WFBE_CO_FNC_EquipVehicle

Registered at `Common/Init/Init_Common.sqf:111`. OA only — vanilla assignment is `{{}}`.

**Signature**

```
[_vehicle, _vehicle_content] Call WFBE_CO_FNC_EquipVehicle
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_vehicle` | Object | Vehicle must be `alive`; no-op otherwise |
| 1 | `_vehicle_content` | Array | Three-slot content struct |

**Content struct layout** (`Common/Functions/Common_EquipVehicle.sqf:24-38`):

```
_vehicle_content = [
    [[weapon_class, ...], [count, ...]],   // index 0: weapon cargo
    [[mag_class,    ...], [count, ...]],   // index 1: magazine cargo
    [[backpack_class,...],[count, ...]]    // index 2: backpack cargo
]
```

**Behavior**

1. Guards on `alive _vehicle`; exits silently if dead.
2. Clears all three cargo types with `clearWeaponCargoGlobal`, `clearMagazineCargoGlobal`, `clearBackpackCargoGlobal`.
3. Exits early if `count _vehicle_content == 0`.
4. Iterates each slot and calls `addWeaponCargoGlobal`, `addMagazineCargoGlobal`, `addBackpackCargoGlobal`.

**Call site**: `Client/GUI/GUI_BuyGearMenu.sqf:439` — invoked after `EquipUnit` when the player selects vehicle cargo in the gear store.

Source: `Common/Functions/Common_EquipVehicle.sqf:8-40`

---

### WFBE_CO_FNC_ClearVehicleCargo

Registered at `Common/Init/Init_Common.sqf:101`. Variant selected by `WF_A2_Vanilla`.

| Variant | File | Commands used |
|---|---|---|
| Vanilla | `Common_ClearVehicleCargo.sqf` | `clearMagazineCargo`, `clearWeaponCargo` (local) |
| OA | `Common_ClearVehicleCargoOA.sqf` | `clearMagazineCargoGlobal`, `clearWeaponCargoGlobal`, `clearBackpackCargoGlobal` (global) |

**Signature** (both variants)

```
_vehicle Call WFBE_CO_FNC_ClearVehicleCargo
```

The OA variant adds a guard: it only calls `clearMagazineCargoGlobal` when `count ((getMagazineCargo _vehicle) select 0) > 0`, and similarly for weapons and backpacks, avoiding unnecessary global traffic.

Source: `Common/Functions/Common_ClearVehicleCargo.sqf:1-12`, `Common/Functions/Common_ClearVehicleCargoOA.sqf:1-13`

---

## Rearm pipeline

`RearmVehicle` is the single entry point for service-station rearming. It is registered at `Common/Init/Init_Common.sqf:73` and is always called as `[_vehicle, _side] Spawn RearmVehicle` (or `Call`; the call site at `Client/Functions/Client_SupportRearm.sqf:77` uses `Spawn`).

The vanilla and OA pipelines are **not interchangeable** — using the wrong one silently produces the wrong magazine state.

### Pipeline comparison

| Step | Vanilla (`Common_RearmVehicle.sqf`) | OA (`Common_RearmVehicleOA.sqf`) |
|---|---|---|
| SAM / StaticAT fast path | `setVehicleAmmo 1` and return | `setVehicleAmmo 1` and return |
| Clear existing rounds | `removeMagazine` forEach `magazines _vehicle` | `_vehicle setVehicleAmmo 0` |
| Restore main turret | Reads `CfgVehicles >> typeOf >> Turrets >> MainTurret >> Magazines` + `CfgVehicles >> typeOf >> Magazines`, then `addMagazine` forEach | `WFBE_CO_FNC_GetVehicleTurretsGear` + `WFBE_CO_FNC_SetTurretsMagazines` (turret-path-aware) |
| Driver magazines | Not separate | `CfgVehicles >> typeOf >> magazines` → `addMagazineTurret [_x, [-1]]` |
| Full fill | `setVehicleAmmo 1` + `reload _vehicle` | `reload _vehicle` only (OA zeroed ammo earlier via `setVehicleAmmo 0`) |
| IRS reset | Yes (both) | Yes (both) |
| Flare/CM reset | Yes (`WFBE_C_MODULE_WFBE_FLARES` switch) | Yes (`WF_A2_Vanilla` guard; case 0 disables CM) |
| Artillery extended mags | `EquipArtillery` if `IsArtillery != -1` | `EquipArtillery` if `IsArtillery != -1` |
| Balance init | `BalanceInit` if `WFBE_C_UNITS_BALANCING > 0` and not `M6_EP1` | Same |
| AA missile gating | `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` switch | Same |
| EASA module | `EASA_Equip` if vehicle in `WFBE_EASA_Vehicles` | Same |

**Signature** (both variants)

```
[_vehicle, _side] Call RearmVehicle
```

| Position | Parameter | Type |
|---|---|---|
| 0 | `_vehicle` | Object |
| 1 | `_side` | Side value (west/east/resistance) |

**SAM fast-path classes** hardcoded at lines 6–7 of both files:

```
_sam = ['2S6M_Tunguska','M6_EP1']
```

Both classes and all `isKindOf "StaticATWeapon"` vehicles skip all magazine manipulation and receive `setVehicleAmmo 1` only.

Source: `Common/Functions/Common_RearmVehicle.sqf:1-69`, `Common/Functions/Common_RearmVehicleOA.sqf:1-68`

---

### Upgrade constants used during rearm

| Constant | Value | Purpose |
|---|---|---|
| `WFBE_UP_FLARESCM` | `9` | Flare / countermeasure upgrade index |
| `WFBE_UP_ARTYAMMO` | `17` | Artillery extended ammo upgrade index |
| `WFBE_UP_AIRAAM` | `19` | Air-to-air missile upgrade index |

Source: `Common/Init/Init_CommonConstants.sqf:46,54,56`

---

### CM / AA missile gating logic

**Vanilla `RearmVehicle`** (air vehicles only):

- `WFBE_C_MODULE_WFBE_FLARES == 1` (enabled with upgrades): sets `FlareCount` only if `WFBE_UP_FLARESCM > 0`.
- `WFBE_C_MODULE_WFBE_FLARES == 2` (always enabled): sets `FlareCount` unconditionally.
- `WFBE_C_GAMEPLAY_AIR_AA_MISSILES == 0`: calls `WFBE_CO_FNC_RemoveAAMissiles`.
- `WFBE_C_GAMEPLAY_AIR_AA_MISSILES == 1`: removes AA missiles unless `WFBE_UP_AIRAAM > 0`.

**OA `RearmVehicleOA`** (air vehicles only):

- Same AA missile gating as vanilla.
- CM case: skipped entirely when `WF_A2_Vanilla` is true. When false:
  - `WFBE_C_MODULE_WFBE_FLARES == 0`: calls `WFBE_CO_FNC_RemoveCountermeasures`.
  - `WFBE_C_MODULE_WFBE_FLARES == 1`: removes countermeasures unless `WFBE_UP_FLARESCM > 0`.

Source: `Common/Functions/Common_RearmVehicle.sqf:17-30,53-62`, `Common/Functions/Common_RearmVehicleOA.sqf:39-61`

---

## Turret gear helpers (OA only)

### WFBE_CO_FNC_GetVehicleTurretsGear

Registered at `Common/Init/Init_Common.sqf:141`.

**Signature**

```
_vehicle Call WFBE_CO_FNC_GetVehicleTurretsGear
// or
"ClassName" Call WFBE_CO_FNC_GetVehicleTurretsGear
```

Accepts either an object or a class name string. Reads `configFile >> "CfgVehicles" >> typeOf _this >> "turrets"` and delegates to `WFBE_CO_FNC_FindTurretsRecursive`.

**Return value**: array of turret entries. Each entry:

```
[weapons_array, magazines_array, turret_path_array, config_path_string]
```

Example (from inline comment in source):

```
[["M256","M240BC_veh"],["20Rnd_120mmSABOT_M1A2","20Rnd_120mmHE_M1A2","1200Rnd_762x51_M240"],[0],"bin\config.bin/CfgVehicles/M1A2_TUSK_MG/Turrets/MainTurret"]
```

Source: `Common/Functions/Common_GetVehicleTurretsGear.sqf:1-13`

---

### WFBE_CO_FNC_FindTurretsRecursive

Registered at `Common/Init/Init_Common.sqf:112`. Called by `GetVehicleTurretsGear`; not called directly in production code.

**Signature**

```
[_configRoot, _turretPath] Call WFBE_CO_FNC_FindTurretsRecursive
```

Iterates over config classes in `_configRoot`. For each class it appends `[weapons, magazines, currentPath, str _class]` to the outer `_result` array and then recurses into `_class >> "turrets"` if that key is a class. Operates on the shared `_result` variable declared by `GetVehicleTurretsGear`.

Source: `Common/Functions/Common_FindTurretsRecursive.sqf:1-20`

---

### WFBE_CO_FNC_SetTurretsMagazines

Registered at `Common/Init/Init_Common.sqf:151`. OA only — vanilla assignment is `{{}}`.

**Signature**

```
[_vehicle, _turretsData] Call WFBE_CO_FNC_SetTurretsMagazines
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_vehicle` | Object | |
| 1 | `_turretsData` | Array | Output of `WFBE_CO_FNC_GetVehicleTurretsGear` |

**Behavior**: iterates `_turretsData`; for each entry reads `_x select 2` as the turret path and `_x select 1` as the magazine list, then calls `addMagazineTurret [_mag, _turretPath]` for each magazine. Returns `true`.

Source: `Common/Functions/Common_SetTurretsMagazines.sqf:1-17`

---

## SpawnTurrets

Registered at `Common/Init/Init_Common.sqf:81`. Used by static defense construction, not by `RearmVehicle`.

**Signature**

```
[_turrets, _path, _vehicle, _crew, _team] Call SpawnTurrets
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_turrets` | Array | Flat list of alternating `[turretIndex, subTurretArray, ...]` pairs |
| 1 | `_path` | Array | Current turret path prefix (empty `[]` at root) |
| 2 | `_vehicle` | Object | |
| 3 | `_crew` | String | Unit class for spawned crew |
| 4 | `_team` | Group | Group the new unit joins |

**Behavior** (`Common/Functions/Common_SpawnTurrets.sqf:9-21`): iterates the turret list two elements at a time. For each turret index `_turretIndex`, builds `_thisTurret = _path + [_turretIndex]`. If `turretUnit _thisTurret` is null, calls `WFBE_CO_FNC_CreateUnit` and moves the unit in with `moveInTurret`. Recurses with `[_turrets select (_i+1), _thisTurret, ...]` to fill sub-turrets.

**Note**: `private` declaration at line 1 uses the array-string form (`private ["_i", "_turrets", ...]`), which is valid A2 OA syntax. The A3-only form to avoid is the inline typed assignment (`private _var = value`); that form is not present here.

Source: `Common/Functions/Common_SpawnTurrets.sqf:1-21`

---

## Artillery extended-mag equip

### EquipArtillery

Registered at `Common/Init/Init_Common.sqf:21`. Called from `RearmVehicle`, `RearmVehicleOA`, `Server_ProcessUpgrade.sqf`, `Client_BuildUnit.sqf`, and `Client_FNC_Special.sqf`.

**Signature**

```
[_unit, _index, _side] Call EquipArtillery
```

| Position | Parameter | Type | Notes |
|---|---|---|---|
| 0 | `_unit` | Object | The artillery vehicle |
| 1 | `_index` | Number | Artillery type index within `WFBE_<SIDE>_ARTILLERY_EXTENDED_MAGS` |
| 2 | `_side` | Side or String | Accepts either a `SIDE` value or a side text string (`"WEST"`, `"EAST"`, `"GUER"`, `"RESISTANCE"`) |

**Behavior** (`Common/Functions/Common_EquipArtillery.sqf:8-32`)

1. Normalises `_side` to both a side text (for variable lookup) and a side value (for `WFBE_CO_FNC_GetSideUpgrades`).
2. Reads the extended ammo list: `missionNamespace getVariable Format['WFBE_%1_ARTILLERY_EXTENDED_MAGS', _sideText] select _index`.
3. If the list is empty, exits immediately.
4. Reads upgrade threshold list: `WFBE_<SIDE>_ARTILLERY_EXTENDED_MAGS_UPGRADE select _index`.
5. Gets current `WFBE_UP_ARTYAMMO` (index 17) upgrade level via `WFBE_CO_FNC_GetSideUpgrades`.
6. For each extended magazine whose threshold is met (`_currentUpgrades >= threshold`), calls `_unit addMagazine`.

**Side text note**: callers may pass either form. `Client_BuildUnit.sqf:303` passes `sideJoinedText` (a string), while `RearmVehicle` passes a `SIDE` value. The normalisation block at lines 8–17 handles both.

Source: `Common/Functions/Common_EquipArtillery.sqf:1-32`

---

## ModifyVehicle — HandleDamage closures

### Common_ModifyVehicle.sqf

Called at `Common/Functions/Common_CreateVehicle.sqf:26` for every `Tank` or `APC` class vehicle immediately after `createVehicle`. Uses `addEventHandler ["HandleDamage", ...]` with an inline closure serialised via `format ["_this Call %1", _rearmor]`.

**Signature** (called by `Common_CreateVehicle`)

```
[_vehicle] Call Compile preprocessFile "Common\Functions\Common_ModifyVehicle.sqf"
```

The file ends with `processInitCommands` at line 240; its return value is discarded by the caller. `_vehicle` is returned by `Common_CreateVehicle.sqf` (line 79), not by this file.

**HandleDamage parameter layout** (A2 OA standard): `[unit, selection, damage, source, ammoClass, hitPointIndex, shooter, projectile]`. The closures use `_this select 4` for ammo class and `_this select 2` for raw damage, then return `(_dam/100) * (100 - _p)`.

**Per-vehicle rearmour percentages**

| Vehicle class | SABOT (125/120mm) | HEAT / ATGM / RPG | AA cannon (20–40mm) |
|---|---|---|---|
| `T72_RU` | 30% | 20–23% | 12% |
| `T72_CDF` | 30% | 20–23% | 12% |
| `T72_INS` | 30% | 20–23% | 12% |
| `T72_TK_EP1` | 30% | 20–23% | 12% |
| `T72_Gue` | 25% | 20–23% | 12% |
| `T90` | 35% | 23–33% | 12% |
| All other APC/Tank | — | — | 12% |

**Note on `Sh_100_HEAT`**: despite its name, `Sh_100_HEAT` is treated at SABOT-level reduction — 30% for `T72_RU`/`T72_CDF`/`T72_INS`/`T72_TK_EP1` (`_p=30`, line 26 et al.), 25% for `T72_Gue` (`_p=25`, line 163), and 35% for `T90` (`_p=35`, line 200). It does **not** fall in the HEAT/ATGM/RPG (20–23%) column of the table above. The per-ammo class table below lists it separately at its correct value. Source: `Common/Functions/Common_ModifyVehicle.sqf:26,60,94,128,163,200`

The `default` branch (all other `Tank`/`APC` types) applies only 12% reduction against AA cannon rounds. Handgun, rifle, and HE infantry rounds are passed through at full damage (`_result = _this select 2`).

**Ammo class coverage** (T72_RU, lines 12–33 as representative):

| Ammo class | Reduction |
|---|---|
| `Sh_125_SABOT`, `Sh_120_SABOT` | 30% |
| `Sh_100_HEAT` | 30% |
| `R_SMAW_HEAA`, `R_MEEWS_HEAT`, `M_AT13_AT`, `M_TOW_AT`, `M_TOW2_AT`, `Sh_85_AP` | 23% |
| `R_RPG18_AT`, `R_PG9_AT`, `R_PG7V_AT`, `R_PG7VL_AT`, `R_M136_AT`, `M_47_AT_EP1` | 20% |
| `B_20mm_AA`, `B_23mm_AA`, `B_25mm_HE`, `B_25mm_HEI`, `B_30mm_AA`, `B_30mm_HE`, `Sh_40_HE` | 12% |

Source: `Common/Functions/Common_ModifyVehicle.sqf:5-240`

---

### Common_ModifyAirVehicle.sqf

Registered but **currently inactive**: the call at `Common/Functions/Common_CreateVehicle.sqf:29` is commented out. All cases apply 1% AA-missile damage reduction (`M_R73_AA`, `M_Sidewinder_AA`) and pass all other ammo through unchanged. The `default` branch (line 137) is a pass-through only. Marked `//LoadoutManagerInsertChanges` / `//LoadoutManagerInsertChanges_END` indicating it is generated by the LoadoutManager build tool.

**Status: latent / disabled.** Do not rely on air vehicle damage reduction being active.

Source: `Common/Functions/Common_ModifyAirVehicle.sqf:1-154`

---

## AddVehicleTexture — map-dependent texture init

### Common_AddVehicleTexture.sqf

Called at `Common/Functions/Common_CreateVehicle.sqf:32` for every created vehicle. Uses `setVehicleInit` with `processinitcommands` to apply textures globally. Returns `_vehicle`.

**Signature**

```
[_vehicle] Call Compile preprocessFile "Common\Functions\Common_AddVehicleTexture.sqf"
```

**Map branch logic**: `IS_chernarus_map_dependent` (`true` on Chernarus, `false` on desert maps) controls which texture variant is applied. Most cases use `if (IS_chernarus_map_dependent) then {woodland textures}` or `if !(IS_chernarus_map_dependent) then {desert textures}`.

**Covered vehicle types and texture counts**

| Vehicle class | Texture slots | Map condition |
|---|---|---|
| `M2A2_EP1` | 5 slots | Chernarus only (woodland) |
| `M2A3_EP1` | 3 slots | Chernarus only |
| `M6_EP1` | 4 slots | Chernarus only |
| `M1128_MGS_EP1`, `M1129_MC_EP1`, `M1135_ATGMV_EP1`, `M1126_ICV_mk19_EP1`, `M1126_ICV_M2_EP1` | 2–3 slots | Chernarus only |
| `HMMWV_M1151_M2_DES_EP1`, `HMMWV_M998A2_SOV_DES_EP1`, `HMMWV_M1035_DES_EP1`, `HMMWV_M998_crows_MK19_DES_EP1`, `HMMWV_M998_crows_M2_DES_EP1` | 2–4 slots | Chernarus only (converts desert HMMWV to woodland) |
| `M113Ambul_TK_EP1`, `M113_TK_EP1` | 1 slot | Chernarus only |
| `BTR60_TK_EP1`, `T34_TK_EP1` | 1–3 slots | Chernarus only |
| `BVP1_TK_ACR` | 1 slot | Chernarus only |
| `AAV`, `LAV25`, `BMP3`, `BTR90` | 2 slots | Desert only |
| `2S6M_Tunguska` | 2 slots | Desert only |
| `T90` | 3 slots | Desert only |
| `Mi24_D_TK_EP1`, `Mi24_V`, `Mi24_P` | 2–3 slots | Desert only (insurgent camo) |

Texture paths are relative to the mission root (e.g., `Textures\base_co.paa`) except Mi-24 variants which reference absolute `\ca\` paths in the game installation.

Source: `Common/Functions/Common_AddVehicleTexture.sqf:1-230`

---

## Interaction map

```
Common_CreateVehicle.sqf
  ├── Common_ModifyVehicle.sqf    (Tank/APC only — HandleDamage closure)
  ├── [Common_ModifyAirVehicle.sqf]  (commented out)
  └── Common_AddVehicleTexture.sqf

Client_SupportRearm.sqf
  └── RearmVehicle  ──────────────────────────────────────────────────┐
                                                                       │
        Common_RearmVehicle.sqf (vanilla)        Common_RearmVehicleOA.sqf (OA, default)
          removeMagazine forEach                    setVehicleAmmo 0
          CfgVehicles MainTurret mags               GetVehicleTurretsGear
          setVehicleAmmo 1                            FindTurretsRecursive
          reload                                    SetTurretsMagazines
          IRS reset                                  driver [-1] turret mags
          EquipArtillery                            reload
          BalanceInit                               IRS reset
          CM/AA gating                              EquipArtillery
                                                    BalanceInit
                                                    CM/AA gating
```

---

## Known issues

| Issue | Location | Notes |
|---|---|---|
| `Common_ModifyAirVehicle` inactive | `Common_CreateVehicle.sqf:29` (commented out) | Air vehicles receive no HandleDamage reduction. If re-enabled, the duplicate EH problem (multiple closures per vehicle on rearm) would emerge; `ModifyVehicle` has the same risk if `CreateVehicle` is called twice on the same object. |
| Vanilla rearm does not use turret paths | `Common_RearmVehicle.sqf:11-14` | Reads `Turrets >> MainTurret >> Magazines` from config only — multi-turret vehicles with sub-turrets get an incomplete reload on the vanilla path. |
| `EquipLoadout` dead | `Client/Init/Init_Client.sqf:562` | Call is commented out; function remains registered. |

---

## Continue Reading

- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — architecture diagram showing where EquipUnit and EquipVehicle fit in the buy and respawn flows
- [IRS-IR-Smoke-Missile-Countermeasure](IRS-IR-Smoke-Missile-Countermeasure) — `wfbe_irs_flares` variable and IRS module reset referenced in both RearmVehicle variants
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — full WFBE_UP_* constant table and upgrade unlock flow that gates CM, AAM, and artillery ammo
- [Artillery-Reference-Per-Faction](Artillery-Reference-Per-Faction) — WFBE_WEST/EAST/GUER_ARTILLERY_EXTENDED_MAGS config and what EquipArtillery adds per upgrade tier
- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference) — Common_CreateVehicle call contract and the full post-spawn init sequence
