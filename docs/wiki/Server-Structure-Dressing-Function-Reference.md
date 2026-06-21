# Server Structure Dressing Function Reference (Server_SpawnStructureDressing + WFBE_NEURODEF_*_WEST/_EAST)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server_SpawnStructureDressing.sqf` is the third and most lightweight of the three server-side composition spawners. Unlike `Server_ConstructPosition` (which spawns combat defenses with AI) and `CreateDefenseTemplate` (wall rings) documented in [Server-Composition-Spawner-Function-Reference](Server-Composition-Spawner-Function-Reference), this helper places **purely cosmetic static props** around an already-placed structure core, stores them on the core as `wfbe_dressing`, and attaches a `Killed` event handler that deletes the props when the core dies. It reuses the exact world-space rotation math of `Server_ConstructPosition.sqf` but does no `ConstructDefense`, spawns no AI, and tolerates missing classes gracefully. It is the spawner behind the Bank, Counter-Battery Radar (CBR), Reserve, and Artillery Radar visual identities.

This page documents the function signature, its template-resolution and graceful-degradation behavior, all four call sites, and the `WFBE_NEURODEF_BANK/CBRADAR/RESERVE/ARTILLERYRADAR _WEST/_EAST` dressing-template family.

## Registration

The function is compiled once at server init and exposed under the global `WFBE_SE_FNC_SpawnStructureDressing`.

| What | Value | Citation |
|---|---|---|
| Compile binding | `WFBE_SE_FNC_SpawnStructureDressing = Compile preprocessFileLineNumbers "Server\Functions\Server_SpawnStructureDressing.sqf";` | `Server/Init/Init_Server.sqf:109` |
| Source file | `Server/Functions/Server_SpawnStructureDressing.sqf` | (whole file, 69 lines) |

## Function: Server_SpawnStructureDressing

### Signature and parameters

`[_core, _tplName, _dir] Call WFBE_SE_FNC_SpawnStructureDressing` — returns nothing (cosmetic side effect only); the spawned prop array is published on the core via `setVariable`.

| Idx | Param | Type | Meaning | Citation |
|---|---|---|---|---|
| 0 | `_core` | object | The structure entity, already placed and oriented | `Server_SpawnStructureDressing.sqf:16` |
| 1 | `_tplName` | string | `missionNamespace` variable name of the dressing template, e.g. `"WFBE_NEURODEF_CBRADAR_WEST"` | `Server_SpawnStructureDressing.sqf:17` |
| 2 | `_dir` | number | Facing of the core in degrees (the same `_direction` passed to the construction caller) | `Server_SpawnStructureDressing.sqf:18` |

Locals are declared with capitalized `Private` (A2 form): `_core,_tplName,_dir,_template,_i,_entry,_cls,_relPos,_relDir,_origin,_worldPos,_worldDir,_prop,_props` (`Server_SpawnStructureDressing.sqf:14`).

### Behavior and guard rails

| Step | Behavior | Citation |
|---|---|---|
| Null-core guard | `if (isNull _core) exitWith {...}` logs a `WARNING` naming the skipped template and returns | `Server_SpawnStructureDressing.sqf:20-22` |
| Template resolve | `_template = missionNamespace getVariable [_tplName, []];` — 2-arg `getVariable` with default `[]` | `Server_SpawnStructureDressing.sqf:24` |
| Empty-template early exit | `if (count _template == 0) exitWith {...}` logs `INFORMATION` ("template is empty — no dressing") and returns | `Server_SpawnStructureDressing.sqf:25-27` |
| Origin capture | `_origin = getPos _core;` then iterate the template | `Server_SpawnStructureDressing.sqf:29,32` |
| Per-entry unpack | Each entry is `[_cls, _relPos, _relDir]` (classname, relative `[x,y,z]`, relative facing) | `Server_SpawnStructureDressing.sqf:33-36` |
| World-space rotation | Rotates `_relPos` by `_dir` using the same cos/sin formula as `Server_ConstructPosition.sqf:50-56`; sets z to 0; `_worldDir = _dir - _relDir` | `Server_SpawnStructureDressing.sqf:38-45` |
| Prop spawn | `_prop = createVehicle [_cls, _worldPos, [], 0, "NONE"];` (no flat-spot scatter, no random) | `Server_SpawnStructureDressing.sqf:47` |
| Missing-class degradation | If `isNull _prop`, logs a `WARNING` naming the class and template **and continues** — the rest of the composition still spawns | `Server_SpawnStructureDressing.sqf:48-50` |
| Place prop | Else `setDir _worldDir; setPos _worldPos;` and append to `_props` | `Server_SpawnStructureDressing.sqf:51-55` |
| Publish props | `_core setVariable ["wfbe_dressing", _props];` (local server var, **not** broadcast) | `Server_SpawnStructureDressing.sqf:58` |
| Killed cleanup EH | Inline `Killed` EH on the core deletes every non-null prop in `wfbe_dressing`, then logs an `INFORMATION` count | `Server_SpawnStructureDressing.sqf:60-67` |
| Summary log | Logs spawned-prop count, `typeOf _core`, and template name | `Server_SpawnStructureDressing.sqf:69` |

The rotation formula (`Server_SpawnStructureDressing.sqf:39-43`) is byte-identical in shape to the construction spawner: `worldX = ox + rx*cos d + ry*sin d`, `worldY = oy - rx*sin d + ry*cos d`. This means a dressing template authored in core-local coordinates lands correctly regardless of how the player rotated the structure at build time.

### Cleanup semantics (important caveat)

The `Killed` EH (`Server_SpawnStructureDressing.sqf:61-67`) only fires when the core is **destroyed**. It does **not** fire on `deleteVehicle`. Any caller that deletes a dressed core (rather than letting it die) must delete the `wfbe_dressing` props by hand first, or they orphan. The captured-town CBR recapture path does exactly this — see the caller table below (`server_town.sqf:510-516`).

## Call sites

Four distinct call sites resolve a side-specific template name via `Format` and invoke the function. Three are construction sites; the fourth is the non-buildable captured-town airfield CBR.

| Caller | Line | Structure type | Template resolved | Gate / notes |
|---|---|---|---|---|
| `Server/Construction/Construction_MediumSite.sqf` | `129` | `Bank` | `WFBE_NEURODEF_BANK_%1` (WEST/EAST) | Gated on `_rlType == "Bank" && WFBE_C_ECONOMY_BANK > 0` (`:126`); also creates the bank marker + income drip |
| `Server/Construction/Construction_MediumSite.sqf` | `156` | `Reserve`, `ArtilleryRadar` | `WFBE_NEURODEF_%1_%2` (`toUpper _rlType`, WEST/EAST) | Gated on `_rlType in ["Reserve","ArtilleryRadar"]` (`:153`); both types are then **excluded** from the auto-walls block by the `!(_rlType in ["AARadar","Bank","Reserve","ArtilleryRadar"])` guard (`:160`, with the "auto walls skipped" log at `:160-167`) so dressing isn't doubled |
| `Server/Construction/Construction_SmallSite.sqf` | `114` | `CBRadar` | `WFBE_NEURODEF_CBRADAR_%1` (WEST/EAST) | Gated on `_rlType == "CBRadar" && WFBE_C_STRUCTURES_COUNTERBATTERY > 0` (`:111`); also registers the core in the per-side `WFBE_CBR_WEST/EAST` array |
| `Server/FSM/server_town.sqf` | `543` | airfield CBR (captured town) | `WFBE_NEURODEF_CBRADAR_%1` (WEST/EAST) | Indestructible `Land_Antenna` placed on town capture; **reuses the buildable CBRADAR templates** for side identity; `_dir` passed as `0` (`:542-543`) |

The `server_town.sqf` caller is the only one that is not a player construction. On town recapture it first removes the old radar from both side registries (`:511-512`), then deletes the previous radar's dressing explicitly (`server_town.sqf:514-515`, because the `Killed` EH won't fire on `deleteVehicle`), spawns a fresh indestructible `Land_Antenna` 60 m off the airfield logic (`:521,528-535`), then calls the dressing helper with `_dir = 0` (`:543`).

## WFBE_NEURODEF_*_WEST/_EAST dressing template family

All dressing templates live in `Server/Init/Init_Defenses.sqf` and are stored on `missionNamespace`. Each is an array of `[classname, [relX,relY,relZ], relDir]` prop entries in core-local space. Note these are the `_WEST`/`_EAST` **dressing** templates — distinct from the `WFBE_NEURODEF_*_WALLS` wall-ring templates consumed by `CreateDefenseTemplate` (documented on the sibling page).

| Template | Side | Definition line | Style |
|---|---|---|---|
| `WFBE_NEURODEF_BANK_WEST` | WEST | `Init_Defenses.sqf:633` (`_b` opens `:594`) | Floodlit walled compound: barriers, illuminant tower, NATO camo net, vault crates, gate sandbags, road cones, danger sign, razorwire, OA/A2 corner watchtowers |
| `WFBE_NEURODEF_BANK_EAST` | EAST | `Init_Defenses.sqf:676` (`_b` opens `:637`) | Same layout, RU props (Bank Rossii) |
| `WFBE_NEURODEF_CBRADAR_WEST` | WEST | `Init_Defenses.sqf:310` (`_c` opens `:280`) | NATO radar outpost: control shelter + camo net, instrument crates, sandbag ring, `Base_WarfareBBarrier5x` screen, razorwire, campfire, OA/A2 corner tower |
| `WFBE_NEURODEF_CBRADAR_EAST` | EAST | `Init_Defenses.sqf:348` (`_c` opens `:316`) | RU/TK radar outpost variant |
| `WFBE_NEURODEF_ARTILLERYRADAR_WEST` | WEST | `Init_Defenses.sqf:226` (override) | Tight 5-prop themed cluster (≤6 with core), 0 walls |
| `WFBE_NEURODEF_ARTILLERYRADAR_EAST` | EAST | `Init_Defenses.sqf:233` (override) | RU variant of the 5-prop cluster |
| `WFBE_NEURODEF_RESERVE_WEST` | WEST | `Init_Defenses.sqf:240` (override) | Tight 5-prop themed cluster, 0 walls |
| `WFBE_NEURODEF_RESERVE_EAST` | EAST | `Init_Defenses.sqf:247` (override) | RU variant of the 5-prop cluster |

### Override nuance — ARTILLERYRADAR and RESERVE are defined twice

`WFBE_NEURODEF_ARTILLERYRADAR_WEST/EAST` and `WFBE_NEURODEF_RESERVE_WEST/EAST` are each **set twice** in `Init_Defenses.sqf`. The first definitions are full WDDM walled-compound presets (`ARTILLERYRADAR_WEST` `:151`, `ARTILLERYRADAR_EAST` `:173`, `RESERVE_WEST` `:201`, `RESERVE_EAST` `:221`). An owner-override block (`Init_Defenses.sqf:223-253`) then **re-sets all four** to tight themed clusters. Because the override runs after, the compound versions are dead — only the override clusters ever reach the spawner.

| Override template | Line | Props (5 each, all within ~3.5 m) | Citation |
|---|---|---|---|
| `WFBE_NEURODEF_ARTILLERYRADAR_WEST` | `226` | `Misc_cargo_cont_small`, `Land_CamoNetVar_NATO`, `USBasicAmmunitionBox_EP1`, `Land_fort_bagfence_round`, `FlagCarrierGUE` | `Init_Defenses.sqf:226-232` |
| `WFBE_NEURODEF_ARTILLERYRADAR_EAST` | `233` | `Misc_cargo_cont_small`, `Land_CamoNetVar_EAST`, `TKBasicAmmunitionBox_EP1`, `Land_fort_bagfence_round`, `FlagCarrierGUE` | `Init_Defenses.sqf:233-239` |
| `WFBE_NEURODEF_RESERVE_WEST` | `240` | `USBasicAmmunitionBox_EP1` ×2, `Land_fort_bagfence_long`, `Land_Campfire`, `FlagCarrierGUE` | `Init_Defenses.sqf:240-246` |
| `WFBE_NEURODEF_RESERVE_EAST` | `247` | `TKBasicAmmunitionBox_EP1` ×2, `Land_fort_bagfence_long`, `Land_Campfire`, `FlagCarrierGUE` | `Init_Defenses.sqf:247-253` |

The override comment block (`Init_Defenses.sqf:223-225`) states the intent explicitly: ArtyRadar + Reserve must be a tight cluster of ≤6 themed props, **not** a walled HESCO compound — "core model + these ≤5 small props = ≤6 items, all within ~3.5 m, 0 AI, 0 walls."

### Arma 2 vs OA conditional props

The `BANK` and `CBRADAR` templates branch on `WF_A2_Arrowhead` to swap watchtower classes between the OA (`Land_Fort_Watchtower_EP1`) and base-A2 (`Land_Fort_Watchtower`) variants, appending them with `_b = _b + [...]` / `_c = _c + [...]` before the final `setVariable` (Bank `Init_Defenses.sqf:621-633`; CBR `:305-310`). The override ARTILLERYRADAR/RESERVE clusters carry no watchtowers and so have no such branch.

## Relationship to the other two spawners

| Aspect | Server_SpawnStructureDressing | Server_ConstructPosition | CreateDefenseTemplate |
|---|---|---|---|
| Purpose | Cosmetic props | Combat defense + AI | Wall rings |
| Spawns AI | No | Yes (`ConstructDefense`) | No |
| Storage var on core | `wfbe_dressing` (`Server_SpawnStructureDressing.sqf:58`) | `WFBE_WDDMPositionAnchor` per child (`:67`) | `wfbe_defense` per prop (`:33`) |
| Cleanup | Inline `Killed` EH (`:61-67`) | — | — |
| Templates | `WFBE_NEURODEF_*_WEST/_EAST` (dressing) | `WFBE_NEURODEF_*POS*` | `WFBE_NEURODEF_*_WALLS` |
| Missing-class behavior | Log WARNING + continue (`:48-50`) | — | — |

The three share the same world-space rotation math; this function is the only one that publishes a `Killed`-EH self-cleanup and the only one explicitly tolerant of classes that fail `createVehicle` on a given content set (relevant because several dressing classes such as `Land_CamoNetVar_*` and `FlagCarrierGUE` are content-pack dependent).

## Continue Reading

- [Server-Composition-Spawner-Function-Reference](Server-Composition-Spawner-Function-Reference) — the sibling `Server_ConstructPosition` + `CreateDefenseTemplate` spawners and the `WFBE_NEURODEF_*POS`/`*_WALLS` template families.
- [Bank-Reserve-And-Artillery-Radar-Structures](Bank-Reserve-And-Artillery-Radar-Structures) — the structures dressed by this function, viewed from each structure's gameplay role.
- [Counter-Battery-Radar-System](Counter-Battery-Radar-System) — the CBR registries, radius logic, and the indestructible captured-town radar that calls this function.
- [Defense-Structures-Catalog](Defense-Structures-Catalog) — buildable defense classnames per faction, including props used inside the dressing compositions.
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_NEURODEF_*` namespace and `wfbe_*` object-variable conventions.
