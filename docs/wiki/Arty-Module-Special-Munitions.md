# Arty Module — Special Artillery Munitions (SADARM and ILLUM handlers)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The `Common/Module/Arty/` directory contains four scripts that implement special artillery munition simulation. They run entirely outside the fire-mission UI path documented in [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas). All four are compiled at mission start by `Common/Init/Init_Common.sqf` (lines 88–91) and invoked from the Fired event-handler dispatcher `Common/Functions/Common_HandleArtillery.sqf` or the mobile-gun emplacement wrapper `Common/Functions/Common_FireArtillery.sqf`.

---

## Compiled Globals

These four module functions are compiled once per session and stored as global variables (`Compile preprocessFile`), making them callable anywhere on the machine that ran `Init_Common.sqf`.

| Global variable | Source file | Lines in Init_Common.sqf |
|---|---|---|
| `ARTY_HandleILLUM` | `Common/Module/Arty/ARTY_HandleILLUM.sqf` | 88 |
| `ARTY_HandleSADARM` | `Common/Module/Arty/ARTY_HandleSADARM.sqf` | 89 |
| `ARTY_Prep` | `Common/Module/Arty/ARTY_mobileMissionPrep.sqf` | 90 |
| `ARTY_Finish` | `Common/Module/Arty/ARTY_mobileMissionFinish.sqf` | 91 |

All four use `preprocessFile` (not `preprocessFileLineNumbers`), so line-number macros are unavailable in their bodies. (`Common/Init/Init_Common.sqf:88-91`)

---

## Dispatch: Common_HandleArtillery.sqf

`Common/Functions/Common_HandleArtillery.sqf` is the Fired event-handler body registered per artillery unit. It receives the ammo classname and checks it against per-side lists before dispatching.

```sqf
// SADARM Rounds.
if (_ammo in (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMO_SADARM",_side])) then {
    [_projectile,_landDestination,_velocity] Spawn ARTY_HandleSADARM;
    _keepShellAlive = false; //--- SADARM Destroy the original round.
};

// ILLUM Rounds.
if (_ammo in (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMO_ILLUMN",_side])) then {
    [_projectile,_landDestination,_velocity] Spawn ARTY_HandleILLUM;
    _keepShellAlive = false; //--- ILLUM Destroy the original round.
};
```
(`Common/Functions/Common_HandleArtillery.sqf:32-41`)

Both handlers receive `[_projectile, _landDestination, _velocity]` as `_this` and are called with `Spawn` so they run in a separate thread, detached from the Fired EH. Setting `_keepShellAlive = false` suppresses the standard ballistic repositioning that runs for HE/WP/LASER rounds.

---

## ARTY_HandleILLUM — Illumination Handler

**File:** `Common/Module/Arty/ARTY_HandleILLUM.sqf`

### Parameters

| Index | Variable | Description |
|---|---|---|
| 0 | `_shell` | The actual projectile object from the Fired EH |
| 1 | `_destination` | Computed land position `[x, y, z]` |
| 2 | `_velocity` | Projectile fall velocity (from per-faction config) |

### Execution Flow

| Step | What happens | Source line |
|---|---|---|
| 1 | Override destination altitude to 1000 m: `_destination set [2, 1000]` | `ARTY_HandleILLUM.sqf:8` |
| 2 | Teleport `_shell` to that position with `_shell setPos _destination` | `ARTY_HandleILLUM.sqf:11` |
| 3 | Force straight-down velocity: `_shell setVelocity [0,0,-_velocity]` | `ARTY_HandleILLUM.sqf:15` |
| 4 | Wait until shell altitude drops below **310 m** (`waitUntil {(getPos _shell select 2) < 310}`) | `ARTY_HandleILLUM.sqf:18` |
| 5 | Record deploy position, delete the original shell | `ARTY_HandleILLUM.sqf:21-22` |
| 6 | Spawn `"ARTY_Flare_Medium"` at deploy position and re-set its position | `ARTY_HandleILLUM.sqf:25-26` |

The shell is replaced by the flare at exactly 310 m altitude above the target grid. No further physics manipulation of the flare is performed; it uses its own CfgAmmo simulation from there.

---

## ARTY_HandleSADARM — Sensor-Fuzed SADARM Handler

**File:** `Common/Module/Arty/ARTY_HandleSADARM.sqf`

SADARM (Sense and Destroy Armor) is a fully scripted guided-munition simulation. It replaces the ballistic shell with a parachute-suspended seeker unit that locates a random vehicle in a scan window, then fires a kinetic sub-munition at it.

### Parameters

| Index | Variable | Description |
|---|---|---|
| 0 | `_shell` | Original projectile from Fired EH |
| 1 | `_destination` | Computed target area position `[x, y, z]` |
| 2 | `_velocity` | Fall velocity (per-faction config) |

### Air-Target Classification (`_airTypes`)

The seeker treats the following base classes as air targets — a distinct hit path is used for these (see Hit Path below):

```
"Plane", "AH1_Base", "AH64_base_EP1", "AW159_Lynx_BAF", "BAF_Merlin_HC3_D",
"Kamov_Base", "Mi17_base", "Mi24_Base", "UH1Y", "UH60_Base"
```
(`ARTY_HandleSADARM.sqf:7-9`)

### Execution Flow

| Step | What happens | Source lines |
|---|---|---|
| 1 | Override destination altitude to 1000 m | `ARTY_HandleSADARM.sqf:12` |
| 2 | Teleport `_shell` to position, init `_targetToHit = objNull`, `_impactAreaSimulation = objNull` | `ARTY_HandleSADARM.sqf:15-18` |
| 3 | Set straight-down velocity on shell | `ARTY_HandleSADARM.sqf:21` |
| 4 | Wait until shell altitude < 600 m; record `_deployPos`, delete shell | `ARTY_HandleSADARM.sqf:24-28` |
| 5 | Spawn parachute model: `missionNamespace getVariable Format ["WFBE_%1PARACHUTE",sideJoined]` at `_deployPos` | `ARTY_HandleSADARM.sqf:31-33` |
| 6 | Create `"Barrel4"` and attach it to the parachute (`attachTo`) as the seeker body | `ARTY_HandleSADARM.sqf:34-35` |
| 7 | **DR-56 throttled descent loop** (0.1 s sleep per tick): set `_parachute setVelocity [vx, vy, -_velocity]` each tick; wait until altitude < 400 m | `ARTY_HandleSADARM.sqf:38-45` |
| 8 | **Scan loop** (0.2 s sleep per tick): active while barrel altitude is in 275–75 m window; calls `nearEntities` with `WFBE_C_ARTILLERY_AMMO_RANGE_SADARM`; picks a random target, sleeps up to 3 s (simulated acquisition delay) | `ARTY_HandleSADARM.sqf:51-73` |
| 9 | Loop exits when altitude < 10 m (miss) or `_targetFound = true` | `ARTY_HandleSADARM.sqf:72` |
| 10 | If target found and barrel still alive: delete barrel + parachute, spawn `"ARTY_SADARM_BURST"` +5 m above barrel position | `ARTY_HandleSADARM.sqf:76-87` |
| 11 | **Hit path branches on target type** (air vs ground — see below) | `ARTY_HandleSADARM.sqf:89-131` |
| 12 | Unconditional cleanup: `deleteVehicle _barrel; deleteVehicle _parachute` (guarded nil-checks) | `ARTY_HandleSADARM.sqf:135-136` |
| 13 | If air path: `sleep 1; deleteVehicle _impactAreaSimulation` (DR-56 fix — was a leaking `while {true}` thread) | `ARTY_HandleSADARM.sqf:138-141` |

### SADARM Scan Parameters

| Parameter | Value | Source |
|---|---|---|
| Seeker activation altitude (upper) | 275 m | `ARTY_HandleSADARM.sqf:59` |
| Seeker activation altitude (lower) | 75 m | `ARTY_HandleSADARM.sqf:59` |
| Scan descent start | < 400 m (end of stabilisation loop) | `ARTY_HandleSADARM.sqf:44` |
| Deploy (shell → parachute) altitude | < 600 m | `ARTY_HandleSADARM.sqf:24` |
| Seeker radius | `WFBE_C_ARTILLERY_AMMO_RANGE_SADARM` (default 200 m) | `ARTY_HandleSADARM.sqf:61` |
| Target selection | Random from list (`floor(random count _targets)`) | `ARTY_HandleSADARM.sqf:64` |
| Acquisition delay | `sleep (random 3)` — up to 3 s | `ARTY_HandleSADARM.sqf:65` |
| Scan loop cadence | 0.2 s | `ARTY_HandleSADARM.sqf:70` |

Entity types scanned: `["Car","Motorcycle","Tank","Ship","StaticCannon"]` plus the `_airTypes` list above. (`ARTY_HandleSADARM.sqf:61`)

### SADARM Hit Paths

**Ground target** (`not isKindOf "Air"`):

A `"ARTY_SADARM_PROJO"` projectile is created 5 m above the barrel position, then given a computed velocity of 300 m/s aimed at the target's current position (`[(_dir select 0)*300, (_dir select 1)*300, (_dir select 2)*300]`). (`ARTY_HandleSADARM.sqf:109-130`)

**Air target** (`isKindOf "Air"`):

The projectile (`"ARTY_SADARM_PROJO"`) and a `weaponHolder` (`_impactAreaSimulation`) are both created at the target's position with a random offset of up to 8 m on X and Y and up to 5 m on Z (all positive/unidirectional: `+0–8 m X/Y, +0–5 m Z`). Their collision causes a mid-air explosion. The `_impactAreaSimulation` is deleted after a 1 s sleep (`ARTY_HandleSADARM.sqf:138-141`), resolving DR-56 (was a permanently-sleeping thread leak per air-kill, now removed).

### WFBE_C_ARTILLERY_AMMO_RANGE_SADARM

Defined in `Common/Init/Init_CommonConstants.sqf:112` as a hard constant (not config-gated):

```
WFBE_C_ARTILLERY_AMMO_RANGE_SADARM = 200; //--- Artillery SADARM rounds operative range (Per Shell).
```

This value is read at scan time via `missionNamespace getVariable "WFBE_C_ARTILLERY_AMMO_RANGE_SADARM"` (`ARTY_HandleSADARM.sqf:61`). Changing this constant directly scales the per-shell lethal radius; it is not per-faction. The complementary laser constant is `WFBE_C_ARTILLERY_AMMO_RANGE_LASER = 175` (`Init_CommonConstants.sqf:111`).

### Parachute Model by Faction

The seeker parachute is `missionNamespace getVariable Format ["WFBE_%1PARACHUTE",sideJoined]` — the same per-side variable used for supply paradropping:

| Faction config file | `WFBE_%1PARACHUTE` value | Source line |
|---|---|---|
| `Root_CDF.sqf` | `ParachuteMediumWest` | `Common/Config/Core_Root/Root_CDF.sqf:35` |
| `Root_GUE.sqf` | `ParachuteC` | `Common/Config/Core_Root/Root_GUE.sqf:34` |
| `Root_INS.sqf` | `ParachuteMediumEast` | `Common/Config/Core_Root/Root_INS.sqf:34` |
| `Root_PMC.sqf` | `ParachuteMediumEast_EP1` | `Common/Config/Core_Root/Root_PMC.sqf:33` |
| `Root_RU.sqf` | `ParachuteMediumEast` | `Common/Config/Core_Root/Root_RU.sqf:39` |
| `Root_TKA.sqf` | `ParachuteMediumEast_EP1` | `Common/Config/Core_Root/Root_TKA.sqf:41` |
| `Root_TKGUE.sqf` | `ParachuteMediumEast_EP1` | `Common/Config/Core_Root/Root_TKGUE.sqf:33` |
| `Root_US.sqf` | `ParachuteMediumWest_EP1` | `Common/Config/Core_Root/Root_US.sqf:43` |
| `Root_USMC.sqf` | `ParachuteMediumWest` | `Common/Config/Core_Root/Root_USMC.sqf:41` |
| `Root_US_Camo.sqf` | `ParachuteMediumWest` | `Common/Config/Core_Root/Root_US_Camo.sqf:42` |

---

## Per-Faction SADARM and ILLUM Ammo Lists

Each faction's artillery config file (in `Common/Config/Core_Artillery/`) defines which projectile classnames trigger SADARM or ILLUM handling. The dispatcher (`Common_HandleArtillery.sqf:32,38`) matches `_ammo in` these lists.

| Config file | `WFBE_%1_ARTILLERY_AMMO_SADARM` | `WFBE_%1_ARTILLERY_AMMO_ILLUMN` | Source lines |
|---|---|---|---|
| `Artillery_CDF.sqf` | `['ARTY_Sh_122_SADARM']` | `['ARTY_Sh_122_ILLUM','ARTY_Sh_82_ILLUM']` | 13–14 |
| `Artillery_RU.sqf` | `['ARTY_Sh_122_SADARM']` | `['ARTY_Sh_122_ILLUM','ARTY_Sh_82_ILLUM']` | 13–14 |
| `Artillery_INS.sqf` | `['ARTY_Sh_122_SADARM']` | `['ARTY_Sh_122_ILLUM','ARTY_Sh_82_ILLUM']` | 13–14 |
| `Artillery_USMC.sqf` | `['ARTY_Sh_105_SADARM']` | `['ARTY_Sh_105_ILLUM','ARTY_Sh_81_ILLUM']` | 13–14 |
| `Artillery_GUE.sqf` | `[]` *(no SADARM)* | `['ARTY_Sh_82_ILLUM']` | 13–14 |
| `Artillery_CO_RU.sqf` | `['Sh_122_SADARM']` | `['Sh_122_ILLUM','Sh_82_ILLUM']` | 13–14 |
| `Artillery_CO_GUE.sqf` | `['Sh_122_SADARM']` | `['Sh_122_ILLUM','Sh_122_ILLUM']` | 13–14 |
| `Artillery_CO_US.sqf` | `['Sh_105_SADARM']` | `['Sh_105_ILLUM','Sh_81_ILLUM']` | 13–14 |
| `Artillery_OA_TKA.sqf` | `['Sh_122_SADARM']` | `['Sh_122_ILLUM','Sh_122_ILLUM']` | 13–14 |
| `Artillery_OA_TKGUE.sqf` | `['Sh_122_SADARM']` | `['Sh_122_ILLUM','Sh_122_ILLUM']` | 13–14 |
| `Artillery_OA_US.sqf` | `['Sh_105_SADARM']` | `['Sh_105_ILLUM','Sh_81_ILLUM']` | 13–14 |

Note: ARTY-prefixed classnames (`ARTY_Sh_*`) are WASP custom projectiles; non-prefixed ones (`Sh_*`) use base-game or OA/BAF assets. GUE (Guerrilla) is the only faction with an empty SADARM list — their artillery fires no sensor-fuzed munitions.

---

## Mobile Artillery Emplacement Scripts

These two scripts manage the emplacement cycle for AI-crewed mobile artillery. They are called synchronously (`Call`) by `Common/Functions/Common_FireArtillery.sqf`.

### ARTY_mobileMissionPrep (`ARTY_Prep`)

**File:** `Common/Module/Arty/ARTY_mobileMissionPrep.sqf`  
**Called at:** `Common/Functions/Common_FireArtillery.sqf:26` — before the fire mission begins.

**Parameter:** `[_vehicle]` (the artillery unit)

| Step | Action | Source line |
|---|---|---|
| 1 | If driver is alive: `driver action ["engineOff", _vehicle]` | `ARTY_mobileMissionPrep.sqf:6` |
| 2 | Re-enable AI modes: `enableAI "MOVE"`, `"TARGET"`, `"AUTOTARGET"` on the driver | `ARTY_mobileMissionPrep.sqf:7` |
| 3 | `waitUntil {speed _vehicle < 1}` — block until the vehicle has stopped | `ARTY_mobileMissionPrep.sqf:10` |
| 4 | `sleep 3` — settle delay before gunner begins aiming | `ARTY_mobileMissionPrep.sqf:12` |

The engine-off + AI-re-enable pattern ensures the driver is stationary but still able to respond to orders once the mission ends.

### ARTY_mobileMissionFinish (`ARTY_Finish`)

**File:** `Common/Module/Arty/ARTY_mobileMissionFinish.sqf`  
**Called at:** `Common/Functions/Common_FireArtillery.sqf:68` — after the burst completes and the Fired EH is removed.

**Parameter:** `[_vehicle]` (the artillery unit)

| Step | Action | Source line |
|---|---|---|
| 1 | Compute a look-at position 20 m ahead on the vehicle's bearing, 5 m below vehicle Z: `_lookPos = [x + sin(dir)*20, y + cos(dir)*20, z - 5]` | `ARTY_mobileMissionFinish.sqf:6` |
| 2 | If driver is alive: re-enable `"MOVE"`, `"TARGET"`, `"AUTOTARGET"` on driver | `ARTY_mobileMissionFinish.sqf:8-10` |
| 3 | `gunner lookAt _lookPos` — depress the gun/missile racks to a safe travel attitude | `ARTY_mobileMissionFinish.sqf:11` |

There is no engine-restart call. The AI driver's MOVE AI was already re-enabled in `ARTY_Prep`; `ARTY_Finish` only re-enables it again in case it was disrupted, and directs the gunner to lower the barrel.

---

## Configuration Constants (Artillery block)

All constants live in `Common/Init/Init_CommonConstants.sqf` (Artillery block, lines 108–120).

| Constant | Default | Description | Source line |
|---|---|---|---|
| `WFBE_C_ARTILLERY` | `1` (isNil-gated) | 0=off, 1=Short, 2=Medium, 3=Long range tier | 109 |
| `WFBE_C_ARTILLERY_UI` | `0` (isNil-gated) | 0=off, 1=enable direct-fire UI | 110 |
| `WFBE_C_ARTILLERY_AMMO_RANGE_LASER` | `175` | Laser round acquisition radius (m), per shell | 111 |
| `WFBE_C_ARTILLERY_AMMO_RANGE_SADARM` | `200` | SADARM scan radius (m), per shell | 112 |
| `WFBE_C_ARTILLERY_AREA_MAX` | `300` | Maximum spread area of a fire mission (m) | 113 |
| `WFBE_C_ARTILLERY_INTERVALS` | `[550,500,450,400,350,300,250]` (live) / `[15×7]` (debug) | Per-upgrade reload interval in seconds | 116–119 |

---

## DR-56 Regression History

Two concurrency bugs were addressed in the current master and annotated inline:

| DR | Location | Original bug | Fix |
|---|---|---|---|
| DR-56 (descent loop) | `ARTY_HandleSADARM.sqf:40` | `setVelocity` called every frame in `waitUntil` body with no sleep — high CPU load for the full descent | Added `sleep 0.1` inside the loop body |
| DR-56 (air-kill leak) | `ARTY_HandleSADARM.sqf:139` | `while {true} do {sleep 1; deleteVehicle _impactAreaSimulation}` — spawned a permanently-sleeping thread for each air-kill that never exited | Replaced with a single `sleep 1; deleteVehicle _impactAreaSimulation` after the `if (_targetFound)` block |

Both fixes are in-source via comments at lines 40 and 139.

---

## Continue Reading

- [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas) — fire-mission ordering, support UI, and all other special-support module types
- [Modules-Atlas](Modules-Atlas) — full catalogue of WASP module directories and their roles
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` constant naming conventions and `WFBE_%1_*` per-side variable patterns
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — artillery upgrade tiers that gate reload intervals and range
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — how fire missions are purchased and budgeted at faction level
