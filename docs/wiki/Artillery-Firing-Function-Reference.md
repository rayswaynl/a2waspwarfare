# Artillery Firing Function Reference (FireArtillery and friends)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is the function-contract reference for the artillery firing pipeline compiled from `Common/Functions/`: the fire-mission entry point `FireArtillery`, its `Fired` event-handler companion `HandleArtillery`, the gun discovery/identification helpers (`IsArtillery`, `GetTeamArtillery`), the ammunition selection/loading helpers (`GetArtilleryAmmoOptions`, `LoadArtilleryAmmo`, `EquipArtillery`), and the reload tweaks (`HandleArty`, `HandleCommanderReload`). It documents parameters, the `WFBE_<side>_ARTILLERY_*` config arrays each function reads by type index, return shapes, guards, and live callers. This is distinct from [Artillery-Reference-Per-Faction](Artillery-Reference-Per-Faction) (which tabulates the per-faction config DATA those arrays hold) and from [Counter-Battery-Radar-System](Counter-Battery-Radar-System) (the detection hook). All function names below are the `Compile preprocessFileLineNumbers` aliases registered in `Common/Init/Init_Common.sqf`.

## Function Registration

| Registered name | Source file | Compiled at |
| --- | --- | --- |
| `FireArtillery` / `WFBE_CO_FNC_FireArtillery` | `Common/Functions/Common_FireArtillery.sqf` | `Common/Init/Init_Common.sqf:23,122` |
| `WFBE_CO_FNC_HandleArtillery` | `Common/Functions/Common_HandleArtillery.sqf` | `Common/Init/Init_Common.sqf:151` |
| `IsArtillery` | `Common/Functions/Common_IsArtillery.sqf` | `Common/Init/Init_Common.sqf:71` |
| `GetTeamArtillery` | `Common/Functions/Common_GetTeamArtillery.sqf` | `Common/Init/Init_Common.sqf:48` |
| `EquipArtillery` | `Common/Functions/Common_EquipArtillery.sqf` | `Common/Init/Init_Common.sqf:21` |
| `WFBE_CO_FNC_GetArtilleryAmmoOptions` | `Common/Functions/Common_GetArtilleryAmmoOptions.sqf` | `Common/Init/Init_Common.sqf:50` |
| `WFBE_CO_FNC_LoadArtilleryAmmo` | `Common/Functions/Common_LoadArtilleryAmmo.sqf` | `Common/Init/Init_Common.sqf:51` |
| `HandleArty` | `Common/Functions/Common_HandleArty.sqf` | `Common/Init/Init_Common.sqf:15` |
| `HandleCommanderReload` | `Common/Functions/Common_HandleCommanderReload.sqf` | `Common/Init/Init_Common.sqf:7` |

Note that `FireArtillery` is registered under both the bare alias and the prefixed `WFBE_CO_FNC_FireArtillery` (`Common/Init/Init_Common.sqf:23,122`); the live callers all use the prefixed form (`Server/AI/Commander/AI_Commander_Strategy.sqf:273`, `Client/Functions/Client_RequestFireMission.sqf:15`).

## Per-Type Config Arrays Read By This Family

Every function below indexes per-side, per-artillery-type arrays via the integer returned by `IsArtillery`. The arrays are read with `missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_<NAME>", _side]`, where `_side` is the side TEXT (`"WEST"`/`"EAST"`/`"GUER"`).

| Array (`WFBE_<side>_ARTILLERY_…`) | Read by | Read at |
| --- | --- | --- |
| `_CLASSNAMES` (list of classname-lists, one per type) | `IsArtillery`, `GetTeamArtillery` | `Common_IsArtillery.sqf:6`, `Common_GetTeamArtillery.sqf:21` |
| `_RANGES_MIN` / `_RANGES_MAX` | `FireArtillery` | `Common_FireArtillery.sqf:16-17` |
| `_WEAPONS` | `FireArtillery`, `GetTeamArtillery`, ammo helpers | `Common_FireArtillery.sqf:18`, `Common_GetTeamArtillery.sqf:22` |
| `_AMMOS` | `FireArtillery`, `GetArtilleryAmmoOptions` | `Common_FireArtillery.sqf:19`, `Common_GetArtilleryAmmoOptions.sqf:23` |
| `_VELOCITIES` | `FireArtillery` (passed into `HandleArtillery`) | `Common_FireArtillery.sqf:20` |
| `_DISPERSIONS` | `FireArtillery` (passed into `HandleArtillery`) | `Common_FireArtillery.sqf:21` |
| `_TIME_RELOAD` | `FireArtillery` (burst pacing) | `Common_FireArtillery.sqf:22` |
| `_BURST` | `FireArtillery` (shell count) | `Common_FireArtillery.sqf:23` |
| `_EXTENDED_MAGS` / `_EXTENDED_MAGS_UPGRADE` | `EquipArtillery`, `GetArtilleryAmmoOptions` | `Common_EquipArtillery.sqf:20,23`, `Common_GetArtilleryAmmoOptions.sqf:41-42` |
| `_AMMO_SADARM` / `_AMMO_ILLUMN` / `_AMMO_LASER` / `_DEPLOY_SMOKE` | `HandleArtillery` (round-effect routing) | `Common_HandleArtillery.sqf:32,38,46,68` |

The faction-specific contents of these arrays are tabulated in [Artillery-Reference-Per-Faction](Artillery-Reference-Per-Faction); this page documents only how the firing functions consume them.

## Gun Discovery And Identification

| Function | Params (`_this select …`) | Returns | Source |
| --- | --- | --- | --- |
| `IsArtillery` | `0`=unit/classname, `1`=side text | Type INDEX (`0`-based) into the `_CLASSNAMES` array, or `-1` sentinel if the classname is in no type-list | `Common_IsArtillery.sqf:2-12` |
| `GetTeamArtillery` | `0`=`_team` (group), `1`=`_ignoreAmmo`, `2`=`_index` (type), `3`=`_side` | ARRAY of vehicle objects of the given type owned by the team (AI-gunner, non-player, with ammo unless `_ignoreAmmo`) | `Common_GetTeamArtillery.sqf:2-81` |

`IsArtillery` walks `WFBE_<side>_ARTILLERY_CLASSNAMES` (itself a list of classname-lists, one entry per artillery type) and returns the index `_i` of the first sub-list containing the classname (`Common_IsArtillery.sqf:8-10`). It initialises `_retVal = -1` (`Common_IsArtillery.sqf:5`); the `-1` is the canonical "not artillery" sentinel that every caller checks before continuing.

`GetTeamArtillery` filters `units _team` to vehicles whose `typeOf` is in the selected type's classname list, requiring a non-null, non-player gunner, and (unless `_ignoreAmmo`) `_vehicle ammo _weapon > 0` (`Common_GetTeamArtillery.sqf:29-39`). It additionally extends the search to commander-built guns: when `_team` is the side's commander team, it scans all `vehicles` tagged with a matching `WFBE_CommanderArtillerySide` getVariable and located within `WFBE_C_BASE_AREA_RANGE + WFBE_C_BASE_HQ_BUILD_RANGE` of the side HQ or any registered base area (`Common_GetTeamArtillery.sqf:46-78`).

### Side-text vs side-value normalization

`GetTeamArtillery`, `EquipArtillery`, `GetArtilleryAmmoOptions`, and `LoadArtilleryAmmo` each accept either a side VALUE (`west`/`east`/`resistance`) or side TEXT (`"WEST"`/`"EAST"`/`"GUER"`/`"RESISTANCE"`) and normalize both ways: config getVariables need the text form, while `WFBE_CO_FNC_GetSideUpgrades` needs the value form (`Common_EquipArtillery.sqf:6-17`, `Common_GetArtilleryAmmoOptions.sqf:11-20`, `Common_GetTeamArtillery.sqf:7-16`, `Common_LoadArtilleryAmmo.sqf:11`). The normalization `switch` defaults unknown text to `west` (`Common_EquipArtillery.sqf:15`). By contrast `IsArtillery` and `FireArtillery` take the side as-passed and do NOT normalize, so callers must pass a value the config-variable name interpolation accepts.

## Fire Submission

### `FireArtillery` — `[_artillery, _destination, _side, _radius]`

The fire-mission entry point (`Common_FireArtillery.sqf:3-6`). Spawned, not called, by both live callers (`Server/AI/Commander/AI_Commander_Strategy.sqf:273`, `Client/Functions/Client_RequestFireMission.sqf:15`).

| Step | Behavior | Source |
| --- | --- | --- |
| Lock | Sets `restricted = true` on the gun and force-ejects any player in the crew (`getOut` action) | `Common_FireArtillery.sqf:7-8` |
| Identify | `_index = [typeOf _artillery, _side] Call IsArtillery` | `Common_FireArtillery.sqf:9` |
| Guard: no type | `exitWith` + log warning if `_index == -1` | `Common_FireArtillery.sqf:12` |
| Guard: null gunner | `exitWith` + log warning if `isNull _gunner` | `Common_FireArtillery.sqf:13` |
| Guard: player gunner | `exitWith` + log warning if `isPlayer _gunner` | `Common_FireArtillery.sqf:14` |
| Read config | Pulls `_minRange/_maxRange/_weapon/_ammo/_velocity/_dispersion/_reloadTime/_burst` by `_index` | `Common_FireArtillery.sqf:16-23` |
| Prep | `[_artillery] Call ARTY_Prep` (engine off, wait `speed < 1`, 3s settle) | `Common_FireArtillery.sqf:26` |
| Solve | Computes direction from `atan2`, `_distance` (range minus `_minRange`), firing `_angle` capped at 70 | `Common_FireArtillery.sqf:29-36` |
| Guard: out of range | `exitWith` (no shot) if `_distance < 0` OR `_distance + _minRange > _maxRange` | `Common_FireArtillery.sqf:37` |
| Attach Fired EH | Compiles a `Fired` EH that spawns `HandleArtillery` with the 11-element payload | `Common_FireArtillery.sqf:39` |
| CBR hook (conditional) | If `WFBE_C_STRUCTURES_COUNTERBATTERY > 0`, attaches a second `Fired` EH routing the firer position to `WFBE_SE_FNC_CounterBatteryCheck` (server) or `SendToServer "CounterBatteryFired"` (client) | `Common_FireArtillery.sqf:45-56` |
| Aim | Disables gunner `MOVE/TARGET/AUTOTARGET`, `doWatch` a position elevated by `distance/tan(90-_angle)` | `Common_FireArtillery.sqf:58-61` |
| Settle | `sleep (10 + random 4)` before firing | `Common_FireArtillery.sqf:63` |
| Fire burst | `for _i from 1 to _burst`: `sleep (_reloadTime + random 3)` then `_artillery fire _weapon` (aborts if gunner/gun dead) | `Common_FireArtillery.sqf:75-80` |
| Cleanup | Removes the Fired EH(s), `sleep (_reloadTime + 20)`, re-enables gunner AI, `ARTY_Finish`, then `restricted = false` | `Common_FireArtillery.sqf:84-96` |

`_maxRange` is divided by the global `WFBE_C_ARTILLERY` (the artillery enable/range tier: 0 disabled, 1 short, 2 medium, 3 long — `Common/Init/Init_CommonConstants.sqf:224`) at `Common_FireArtillery.sqf:17`, so a higher tier shrinks the effective max range divisor. The same `/WFBE_C_ARTILLERY` divisor appears in the AI commander's own pre-flight range check (`Server/AI/Commander/AI_Commander_Strategy.sqf:271`). The firing `_radius` parameter is forwarded verbatim into the `HandleArtillery` payload and governs impact scatter (see below); the AI commander passes a fixed `60` (`AI_Commander_Strategy.sqf:273`) while the player path passes the client-side `artyRange` (`Client_RequestFireMission.sqf:15`).

The Fired-EH compile at `Common_FireArtillery.sqf:39` bakes the per-type config values into the handler at attach time, then forwards `_this select 4` (the ammo classname) and `_this select 6` (the projectile object) from the engine's `Fired` payload. The two-EH cleanup at lines 84-86 guards against `restricted`-stuck guns by removing both the main and the conditional CBR handler.

### `HandleArtillery` — the Fired-EH worker (11-element array)

Spawned by the compiled `Fired` EH, NOT called directly (`Common_FireArtillery.sqf:39`). Parameters in payload order:

| Index | Name | Meaning | Source |
| --- | --- | --- | --- |
| `0` | `_ammo` | Fired ammo classname (from `_this select 4` of the Fired EH) | `Common_HandleArtillery.sqf:4` |
| `1` | `_projectile` | The shell object (from `_this select 6`) | `Common_HandleArtillery.sqf:11` |
| `2` | `_ammoList` | The per-type `_AMMOS` allow-list | `Common_HandleArtillery.sqf:5` |
| `3` | `_destination` | Target position | `Common_HandleArtillery.sqf:12` |
| `4` | `_velocity` | Muzzle velocity for the relaunch | `Common_HandleArtillery.sqf:13` |
| `5` | `_dispersion` | Per-axis random spread | `Common_HandleArtillery.sqf:14` |
| `6` | `_cannon` | Firing gun position | `Common_HandleArtillery.sqf:15` |
| `7` | `_distance` | Solved range to target | `Common_HandleArtillery.sqf:16` |
| `8` | `_radius` | Fire-mission spread radius | `Common_HandleArtillery.sqf:17` |
| `9` | `_maxRange` | Max range for scatter scaling | `Common_HandleArtillery.sqf:18` |
| `10` | `_side` | Side text (for ammo-class lookups) | `Common_HandleArtillery.sqf:19` |

The handler returns nothing; its job is to relocate and relaunch each shell so the round lands inside the requested radius, and to route special-ammo behaviors:

| Behavior | Condition | Source |
| --- | --- | --- |
| Ammo allow-list gate | Whole body runs only if `_ammo in _ammoList` | `Common_HandleArtillery.sqf:8` |
| Land-area randomization | `_distance = random (_distance/_maxRange*100) + random _radius`; random 360 bearing; per-axis `± random _dispersion` jitter | `Common_HandleArtillery.sqf:24-28` |
| SADARM | If `_ammo in WFBE_<side>_ARTILLERY_AMMO_SADARM`: spawn `ARTY_HandleSADARM`, destroy original shell | `Common_HandleArtillery.sqf:32-35` |
| ILLUM | If `_ammo in WFBE_<side>_ARTILLERY_AMMO_ILLUMN`: spawn `ARTY_HandleILLUM`, destroy original shell | `Common_HandleArtillery.sqf:38-41` |
| LASER | If `_ammo in WFBE_<side>_ARTILLERY_AMMO_LASER`: snap to nearest `LaserTarget` within `WFBE_C_ARTILLERY_AMMO_RANGE_LASER` (175m) and quarter the dispersion | `Common_HandleArtillery.sqf:46-52`; range `Common/Init/Init_CommonConstants.sqf:226` |
| Standard relaunch | `setPos` shell to a 1000m-high spawn line toward target, `setVelocity` with `z = velocity*2.03*-1` | `Common_HandleArtillery.sqf:55-73` |
| Vanilla MLRS fix | If `WF_A2_Vanilla` and `_ammo` is `"R_MLRS"`/`"ARTY_R_227mm_HE_Rocket"`: hard `setPos` to land destination | `Common_HandleArtillery.sqf:75-80` |
| Smoke-on-impact | If `_ammo in WFBE_<side>_ARTILLERY_DEPLOY_SMOKE`: poll shell position to last-known, spawn `ARTY_SmokeShellWhite` at impact | `Common_HandleArtillery.sqf:68,85-100` |

The `setVelocity` z-component multiplier of `2.03` (`Common_HandleArtillery.sqf:73`) is the descent-steepness constant that turns the relaunched round into a near-vertical plunge; the SADARM/ILLUM paths set `_keepShellAlive = false` (lines 34,40) so the standard relaunch block, guarded by `if (_keepShellAlive)` at line 44, is skipped (`Common_HandleArtillery.sqf:34,40,44`).

### `HandleArty` — restricted-flag GetIn guard `[veh, ?, unit]`

Attached as a `GetIn` event handler when an artillery vehicle is built (`Client/Functions/Client_BuildUnit.sqf:388`). Reads `_unit = _this select 2`, `_vehicle = _this select 0` (`Common_HandleArty.sqf:3-4`), then `waituntil` the gun's `restricted` flag is set AND a player is in the crew, at which point it ejects the player with a `getOut` action and `hintSilent "ARTILLERY MISSION RUNNING"` (`Common_HandleArty.sqf:7-8`). This is the player-side counterpart to the `restricted` lock that `FireArtillery` sets at line 7 — it prevents a player climbing into a gun mid-fire-mission.

## Ammunition Selection And Loading

### `GetArtilleryAmmoOptions` — `[_side, _artilleryIndex]`

Returns the selectable ammo choices for one side and one artillery type (`Common_GetArtilleryAmmoOptions.sqf:8-9`). Each entry is a 4-element array `[displayName, projectileClass, magazineClass, ammoIndex]` (`Common_GetArtilleryAmmoOptions.sqf:1-5,71`).

| Step | Behavior | Source |
| --- | --- | --- |
| Index guard | Returns `[]` if `_artilleryIndex < 0` or `>= count _AMMOS` | `Common_GetArtilleryAmmoOptions.sqf:24-25` |
| Weapon magazines | Collects `magazines` from every muzzle of the type's `_WEAPONS` entry (defaults muzzle list to `["this"]`) | `Common_GetArtilleryAmmoOptions.sqf:28-39` |
| Candidate mags | Concatenates weapon mags with `_EXTENDED_MAGS` for the type | `Common_GetArtilleryAmmoOptions.sqf:41-49` |
| Upgrade read | `_currentUpgrade = (GetSideUpgrades) select WFBE_UP_ARTYAMMO` | `Common_GetArtilleryAmmoOptions.sqf:50` |
| Match + gate | For each projectile in `_AMMOS`, find the magazine whose CfgMagazines `ammo` equals it; include only if `_currentUpgrade >= _extendedUpgrade` (extended-mag upgrade level, else 0) | `Common_GetArtilleryAmmoOptions.sqf:52-73` |

`WFBE_UP_ARTYAMMO` is upgrade index `17` (`Common/Init/Init_CommonConstants.sqf:54`). Base (non-extended) magazines carry an implicit upgrade level of 0 and are always offered; extended mags are gated by their per-index `_EXTENDED_MAGS_UPGRADE` value (`Common_GetArtilleryAmmoOptions.sqf:64-68`). The display name falls back to the projectile class when CfgMagazines has no `displayName` (`Common_GetArtilleryAmmoOptions.sqf:70`).

### `LoadArtilleryAmmo` — `[_artillery, _side, _artilleryIndex, _ammoIndex]`

Loads one selected magazine onto a player-owned gun (`Common_LoadArtilleryAmmo.sqf:7-10`). Returns `true` on success, `false` on any guard failure.

| Guard / step | Behavior | Source |
| --- | --- | --- |
| Null / dead | `exitWith false` if gun is null or not alive | `Common_LoadArtilleryAmmo.sqf:13-14` |
| Gunner | `exitWith false` if gunner is null OR a player | `Common_LoadArtilleryAmmo.sqf:15-16` |
| Resolve option | Looks up the matching option from `GetArtilleryAmmoOptions` by `_ammoIndex`; `exitWith false` if not found | `Common_LoadArtilleryAmmo.sqf:18-27` |
| Find turret | Locates the turret path whose gear contains the type `_WEAPONS` entry via `WFBE_CO_FNC_GetVehicleTurretsGear`; `exitWith false` if absent | `Common_LoadArtilleryAmmo.sqf:31-45` |
| Load | `addMagazineTurret` (if not already present) then `loadMagazine [turretPath, weapon, magazine]` | `Common_LoadArtilleryAmmo.sqf:47-51` |
| Persist selection | `setVariable ["WFBE_A_ArtilleryAmmoSelection", [_artilleryIndex, _ammoIndex], true]` (public) | `Common_LoadArtilleryAmmo.sqf:52` |

The public `WFBE_A_ArtilleryAmmoSelection` variable set at line 52 is read back by the fire-mission request to label the team warning with the chosen round (`Client/Functions/Client_RequestFireMission.sqf:40`).

### `EquipArtillery` — `[_unit, _index, _side]`

Adds the special/extended magazines (WP, SADARM, …) that the side's current artillery-ammo upgrade has unlocked (`Common_EquipArtillery.sqf:2-4`). It reads `WFBE_<side>_ARTILLERY_EXTENDED_MAGS` for the type (early-`exitWith` if empty), the parallel `_EXTENDED_MAGS_UPGRADE` thresholds, and the side's `WFBE_UP_ARTYAMMO` level, then `addMagazine` for each extended mag whose threshold is met (`Common_EquipArtillery.sqf:19-32`). Unlike the selection helpers it does NOT pick a turret — it adds to the unit's general magazine pool, so it is called at build/upgrade/rearm time rather than per-shot.

Callers (all pass the type index from `IsArtillery`):

| Caller | Context | Source |
| --- | --- | --- |
| `Construction_StationaryDefense.sqf:164` | Base gun built by the construction worker | server |
| `Server_ProcessUpgrade.sqf:73` | Artillery-ammo upgrade researched | server |
| `Client_BuildUnit.sqf:376` | Mobile gun built by a player | client |
| `Client_FNC_Special.sqf:262` | Special-action top-up of newly unlocked mags | client |
| `Common_RearmVehicle.sqf:47` / `Common_RearmVehicleOA.sqf:34` | Rearm restocks extended mags | common |

## Reload Tweaks

### `HandleCommanderReload` — Fired-EH `[unit, …]`

Attached as a `Fired` EH on commander-built guns (`Server/Functions/Server_BuyUnit.sqf:117`, `Client/Functions/Client_BuildUnit.sqf:410`). It reads the commander's current muzzle and, only for the affected weapons `M242BC`/`M242`, drops the reload time to `0.5s` via `setWeaponReloadingTime`; any other weapon `exitWith` no-op (`Common_HandleCommanderReload.sqf:4-15`). This is a per-weapon rate-of-fire correction, independent of the `_TIME_RELOAD` config array that `FireArtillery` uses for burst pacing.

## Support Helpers (compiled separately)

`FireArtillery` brackets the fire mission with two `Common/Module/Arty/` helpers compiled in `Common/Init/Init_Common.sqf:93-94`:

| Helper | Contract | Source |
| --- | --- | --- |
| `ARTY_Prep` | Engine off, re-enable driver AI, `waitUntil {speed _vehicle < 1}`, 3s settle | `Common/Module/Arty/ARTY_mobileMissionPrep.sqf` (called `Common_FireArtillery.sqf:26`) |
| `ARTY_Finish` | Re-enable driver AI, point gunner `lookAt` a depressed forward position (lowers the barrel) | `Common/Module/Arty/ARTY_mobileMissionFinish.sqf` (called `Common_FireArtillery.sqf:93`) |

The special-round handlers `ARTY_HandleSADARM` and `ARTY_HandleILLUM` invoked from `HandleArtillery` (`Common_HandleArtillery.sqf:33,39`) are documented under [Arty-Module-Special-Munitions](Arty-Module-Special-Munitions).

## Live Caller Summary

| Caller | Function | Notes | Source |
| --- | --- | --- | --- |
| AI commander | `WFBE_CO_FNC_FireArtillery` | `[_p, _artyTgt, _side, 60]` after friendly-fire and range guards | `Server/AI/Commander/AI_Commander_Strategy.sqf:273` |
| Player fire mission | `WFBE_CO_FNC_FireArtillery` | per-gun `forEach _units` from `GetTeamArtillery` | `Client/Functions/Client_RequestFireMission.sqf:9,15` |
| Player fire mission | `GetTeamArtillery`, `GetArtilleryAmmoOptions` | discovers guns; labels the team warning with the selected round | `Client/Functions/Client_RequestFireMission.sqf:9,39` |
| AI commander | `IsArtillery` | pre-flight type + range check before firing | `Server/AI/Commander/AI_Commander_Strategy.sqf:269` |

## Continue Reading

- [Artillery-Reference-Per-Faction](Artillery-Reference-Per-Faction) — the per-faction config DATA (ranges, weapons, ammo, dispersion) that these functions index.
- [Arty-Module-Special-Munitions](Arty-Module-Special-Munitions) — the SADARM/ILLUM/LASER/smoke round handlers spawned from `HandleArtillery`.
- [Counter-Battery-Radar-System](Counter-Battery-Radar-System) — the conditional `Fired`-EH detection hook attached inside `FireArtillery`.
- [Side-Team-State-Function-Reference](Side-Team-State-Function-Reference) — the side/team helpers and side-text/side-value pattern reused across the artillery family.
- [Config-Lookup-Helper-Reference](Config-Lookup-Helper-Reference) — the config-array lookup helpers neighbouring this firing pipeline.
