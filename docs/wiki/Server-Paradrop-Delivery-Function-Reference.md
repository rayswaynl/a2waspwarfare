# Server Paradrop Delivery Function Reference (Paratroopers / Ammo / Vehicle)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Three server-side scripts deliver air support to a clicked map position: `Support_Paratroopers.sqf` (AI infantry by parachute), `Support_ParaAmmo.sqf` (ammo crates by parachute) and `Support_ParaVehicles.sqf` (a repair/cargo vehicle by parachute). They share a common skeleton — map-edge spawn-point selection, a CARELESS pilot, a fly-to-target loop, a payload drop, then a fly-home/cleanup loop — but each handles its payload differently. The atlas and player guide name these scripts and cover cost/authority; this page documents the function bodies those pages omit. Player-facing costs and cooldowns live in [Tactical support menu player guide](Tactical-Support-Menu-Player-Guide); authority gaps live in [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas).

## Dispatch and binding

All three are compiled at server init and invoked from the `RequestSpecial` → `HandleSpecial` server router. The argument array is `[nil, _side, _destination, _playerTeam]` (`select 1/2/3`), where `_destination` is the clicked position and `_playerTeam` is the requesting commander's group.

| Fact | Value | Citation |
| --- | --- | --- |
| Compile binding (ammo) | `KAT_ParaAmmo = Compile preprocessFile "Server\Support\Support_ParaAmmo.sqf";` | `Server/Init/Init_Server.sqf:46` |
| Compile binding (paratroopers) | `KAT_Paratroopers = Compile preprocessFile "...Support_Paratroopers.sqf";` | `Server/Init/Init_Server.sqf:47` |
| Compile binding (vehicle) | `KAT_ParaVehicles = Compile preprocessFile "...Support_ParaVehicles.sqf";` | `Server/Init/Init_Server.sqf:48` |
| Router case `Paratroops` | `_args spawn KAT_Paratroopers;` | `Server/Functions/Server_HandleSpecial.sqf:43-44` |
| Router case `ParaVehi` | `_args spawn KAT_ParaVehicles;` | `Server/Functions/Server_HandleSpecial.sqf:47-48` |
| Router case `ParaAmmo` | `_args spawn KAT_ParaAmmo;` | `Server/Functions/Server_HandleSpecial.sqf:51-52` |
| Second paratrooper caller (AI commander wildcard W4, Airborne Assault) | `[nil, _side, _destination, _cmdTeam] Spawn (Compile preprocessFile "Server\Support\Support_Paratroopers.sqf");` (level forced to 3, then restored) | `Server/Functions/AI_Commander_Wildcard.sqf:614-621` |

## Shared lifecycle skeleton

Every script runs the same five phases. Line numbers below are per script.

| Phase | Behaviour | Paratroopers | ParaAmmo | ParaVehicles |
| --- | --- | --- | --- | --- |
| Spawn-point pick | If `WFBE_BOUNDARIESXY` is set, build 4 map-corner points at z `400+random(200)` with dirs `[45,145,225,315]`; else fall back to a 2-point set at `[0,0]`/`[15000,0]` with dirs `[45,315]` | `:14-26` | `:12-24` | `:12-24` |
| Index into points | `_ran` chosen randomly over the point set | `_ran = floor(random count _ranPos)` `:44` | `_ran = round(random((count _ranPos)-1))` `:27` | `_ran = round(random((count _ranPos)-1))` `:27` |
| Transport group | One `"paradrop"` group via `WFBE_CO_FNC_CreateGroup` | `:45` | `:28` | `:28` |
| Pilot posture | Group `setBehaviour 'CARELESS'`, `setCombatMode 'STEALTH'`, pilot `disableAI 'AUTOTARGET'`/`'TARGET'` | `:59-61` | `:34-37` | `:35-38` |
| Move out / loop / move home | `AIMoveTo` to target, poll loop until arrival/death/timeout, `AIMoveTo` back to spawn, poll loop, cleanup | `:92-147` | `:38,45-52,96-108` | `:39,51-58,78-90` |

Notes that apply to all three:

- `WFBE_BOUNDARIESXY` is set per-island in `Common/Init/Init_Boundaries.sqf:28` (and `:35`); when no island boundaries are defined it stays nil and the scripts use the 2-point fallback.
- The pilot CARELESS/STEALTH posture set above is immediately re-stamped by `AIMoveTo`, which forces `setCombatMode "RED"`, `setBehaviour "AWARE"`, `setFormation "COLUMN"`, `setSpeedMode "FULL"` on the group (`Server/AI/Orders/AI_MoveTo.sqf:6-9`). `AIMoveTo = Compile preprocessFile "Server\AI\Orders\AI_MoveTo.sqf"` (`Server/Init/Init_Server.sqf:19`); it appends a single `AIWPAdd` waypoint at the destination (`AI_MoveTo.sqf:32`). For these unset (non-AICOM) `"paradrop"` groups, `wfbe_aicom_hc`/`wfbe_aicom_founded` are nil, so the script reads 1-arg + `isNil` and treats them as `false` (`AI_MoveTo.sqf:20-25`).
- `_vehicle setVehicleInit "[this, sideID] ExecVM 'Common\Init\Init_Unit.sqf';"` then `processInitCommands` re-registers each transport as a side unit (Paratroopers `:52,71`; ParaAmmo `:40-41`; ParaVehicles `:41-42`).
- The transport's `'killed'`/`'Killed'` EH routes to `WFBE_CO_FNC_OnUnitKilled` with the side id baked in (Paratroopers `:51`; ParaAmmo `:39`; ParaVehicles `:40`).
- Timeout is **500 s** (`time - _starttime > 500`), and the outbound loop also aborts if the requesting team's leader is no longer a player (Paratroopers `:101`; ParaAmmo `:48`; ParaVehicles `:54`).

## Faction payload variables

Each faction Core_Root file sets the per-side payload via `Format ["WFBE_%1...", _side]`. The scripts read these by side string. Citations below use CDF as the canonical example; every faction sets the same keys.

| Variable | Read by | Meaning | Example (CDF) | Citation |
| --- | --- | --- | --- | --- |
| `WFBE_%1PARACHUTELEVEL<lvl>` | Paratroopers `:31` | Unit-class array for the bought paradrop tier (levels 1-3) | `['CDF_Soldier_TL',...]` | `Common/Config/Core_Root/Root_CDF.sqf:25-27` |
| `WFBE_%1PARACARGO` | Paratroopers `:32,50` | Transport aircraft for paratroopers | `'Mi17_CDF'` | `Common/Config/Core_Root/Root_CDF.sqf:29` |
| `WFBE_%1PILOT` | Paratroopers `:43`; ParaAmmo `:30`; ParaVehicles `:32` | Pilot unit class | side default | `Common/Config/Core_Root/Root_CDF.sqf` |
| `WFBE_%1PARAVEHI` | ParaAmmo `:29`; ParaVehicles `:29` | Transport aircraft for the ammo/vehicle drop | `'Mi17_CDF'` | `Common/Config/Core_Root/Root_CDF.sqf:34` |
| `WFBE_%1PARAAMMO` | ParaAmmo `:59` | Array of crate classes to drop | `['RUBasicAmmunitionBox','RUBasicWeaponsBox','RULaunchersBox']` | `Common/Config/Core_Root/Root_CDF.sqf:32` |
| `WFBE_%1PARAVEHICARGO` | ParaVehicles `:45` | Vehicle class dropped under the transport | `'BRDM2_CDF'` | `Common/Config/Core_Root/Root_CDF.sqf:33` |
| `WFBE_%1PARACHUTE` | ParaAmmo `:71`; ParaVehicles `:68` | Parachute model the payload attaches to | `'ParachuteMediumWest'` | `Common/Config/Core_Root/Root_CDF.sqf:35` |

The full per-faction variable list is in [Faction root variables reference](Faction-Root-Variables-Reference). Note the RU ammo-paradrop config caveat: `WFBE_%1PARAAMMO` is set at `Common/Config/Core_Root/Root_RU.sqf:42` but the atlas flags a comment-swallow risk on the starting-vehicles line — see the atlas for the repair item.

## Support_Paratroopers.sqf — function reference

`Private[...]` header at `:1`; args `_side` `:3`, `_destination` `:4`, `_playerTeam` `:5`; `_sideID = _side Call GetSideID` `:6`; `_starttime = time` `:7`. Returns nothing (spawned).

| Step | Behaviour | Citation |
| --- | --- | --- |
| Upgrade tier | `_currentLevel = (_side Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_PARATROOPERS`, then read `WFBE_%1PARACHUTELEVEL%2` | `:29-31` (`WFBE_UP_PARATROOPERS = 4`, `Common/Init/Init_CommonConstants.sqf:41`) |
| Nil guard | `exitWith` if units or `WFBE_%1PARACARGO` model are nil | `:34` |
| Transport sizing | `_vehicle_cargo = getNumber(CfgVehicles >> model >> 'transportSoldier')`; `exitWith` if 0; `_vehicle_count = ceil((count _units)/_vehicle_cargo)` | `:37-39` |
| Build aircraft | Loop `1..vehicle_count`: `createVehicle [...,"FLY"]`, add killed EH, push to `_vehicles`, spawn pilot via `WFBE_CO_FNC_CreateUnit` + `moveInDriver`, `doMove _destination`, set CARELESS/STEALTH + disableAI, `flyInHeight (300 + random 15)`, `lockDriver true` | `:48-66` |
| Load troops | `forEach _units`: spawn each unit into `_playerTeam` (note: the requesting team, not the transport group `_grp` — the `_grp` variant is commented out at `:80`), `moveInCargo _vehicle`, swap to next aircraft once `_built_inf >= _vehicle_cargo` | `:78-87` |
| Move to target | `[_grp, _destination, "MOVE", 10] Call AIMoveTo` | `:92` |
| Arrival loop | `while {true}`: `sleep 1`; abort on no-alive-vehicle, no-alive-driver, leader-not-player or `time-_starttime > 500`; set `_greenlight=true` when leader vehicle within 300 m of target | `:96-106` |
| Eject | If greenlight: `_delay = if plane then 0.35 else 0.85`; for each cargo unit (`crew - [driver,gunner,commander]`) `action ["EJECT", vehicle]`, `sleep _delay`, then `SendToClient` the per-trooper `HandleParatrooperMarkerCreation` callback | `:109-119` |
| Fly home / fail | On greenlight, `AIMoveTo` back to spawn + arrival loop; else `deleteVehicle` each paratrooper | `:121-138` |
| Cleanup | Delete each transport's crew, then the vehicle, then `deleteGroup _grp` | `:140-147` |

Statistics: `[str _side,'VehiclesCreated',_built] Call UpdateStatistics` `:68` and `[str _side,'UnitsCreated', _built] Call UpdateStatistics` `:89`. Note `_built` is reused as the troop counter accumulator at `:86` (`_built = _built + _built_inf`), so the `UnitsCreated` value at `:89` reflects partially-filled aircraft accounting rather than a clean head count.

The per-trooper client callback `HandleParatrooperMarkerCreation` is registered as a PVF receiver at `Common/Init/Init_PublicVariables.sqf:38`; its client edge (revive marker) is documented in [Paratrooper marker revival](Paratrooper-Marker-Revival).

## Support_ParaAmmo.sqf — function reference

`Private[...]` header `:1`; `_args` `:3`, `_side` `:4`, `_sideID` `:5`, `_playerTeam` `:7`. Single transport (no sizing loop). Returns nothing.

| Step | Behaviour | Citation |
| --- | --- | --- |
| Build transport | `createVehicle WFBE_%1PARAVEHI [...,"FLY"]`, spawn pilot, `moveInDriver`, CARELESS/STEALTH, disableAI, `AIMoveTo` to target, add `'Killed'` EH (via `Call Compile`), `setVehicleInit` + `processInitCommands`, `flyInHeight (200 + random 20)` | `:29-42` |
| Stats | `VehiclesCreated 1` and `UnitsCreated 1` | `:31-32` |
| Outbound loop | `sleep 1`; abort on dead pilot/vehicle/null; on timeout (`>500`) or leader-not-player, `setDammage 1` on cargo+pilot+vehicle and `deleteGroup`; exit when within 100 m | `:45-52` |
| Crate-drop spawn | `[_vehicle,_side] Spawn { ... }`: read `WFBE_%1PARAAMMO` (`:59`); `exitWith` WARNING if not an array (`:60`); `forEach _ammos` with `sleep 0.8` between crates | `:54-93` |
| Per-crate chute | Nested `[_chopper,_ammo,_side] Spawn`: create `WFBE_%1PARACHUTE` at z 20, snap it to the chopper position minus 11 m and match dir, `attachTo` the crate, `waitUntil {getPos _ammo select 2 < 3}`, `detach` | `:62-78` |
| Re-create crate | After landing, capture type+pos, `deleteVehicle _ammo`, re-`createVehicle` the same class at the landed position, re-add the `'Killed'` EH, `sleep 5`, then `deleteVehicle _chute` | `:80-89` |
| Fly home + cleanup | `AIMoveTo` back to spawn, arrival loop (200 m), `deleteVehicle _pilot`, `deleteVehicle _vehicle`, `deleteGroup _grp` | `:96-108` |

Source caveat: the crate-respawn EH at `:85` references `_sideID` inside the nested `Spawn` scope, but only `_chopper`, `_ammo`, `_side` are passed in (`:67-69`) — `_sideID` is the outer-script local and is not in scope there, so the formatted EH receives an undefined side id. The crate is detached, deleted, and re-spawned (`:78-83`) so the parachute can be removed cleanly without the box riding the chute back up.

## Support_ParaVehicles.sqf — function reference

`Private[...]` header `:1`; `_args` `:3`, `_side` `:4`, `_sideID` `:5`, `_playerTeam` `:7`. Structurally mirrors ParaAmmo but drops one attached vehicle. Returns nothing.

| Step | Behaviour | Citation |
| --- | --- | --- |
| Build transport | `createVehicle WFBE_%1PARAVEHI [...,"FLY"]`, stats, pilot `moveInDriver` + `doMove`, CARELESS/STEALTH, disableAI, `AIMoveTo`, `'Killed'` EH, `setVehicleInit` + `processInitCommands`, `flyInHeight (300 + random 75)` | `:29-43` |
| Create cargo vehicle | `_cargoVehicle = [WFBE_%1PARAVEHICARGO,[0,0,50],_sideID,0,false] Call WFBE_CO_FNC_CreateVehicle`, then `attachTo [_vehicle,[0,0,-3]]` (slung 3 m below) | `:45-46` |
| Empty-vehicle registration | `emptyQueu = emptyQueu + [_cargoVehicle]; [_cargoVehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle` — the dropped vehicle enters the standard empty-vehicle cleanup queue | `:48-49` |
| Outbound loop | `sleep 1`; abort on dead pilot/vehicle/cargo/null; timeout/leader-not-player → `setDammage 1` on cargo+pilot+vehicle+cargoVehicle and `deleteGroup`; exit within 100 m | `:51-58` |
| Drop | `detach _cargoVehicle` `:60`, then `[_cargoVehicle,_side] Spawn { ... }`: `sleep 2`, abort if not alive, create `WFBE_%1PARACHUTE`, snap to vehicle pos minus 11 m + match dir, `attachTo`, `waitUntil {getPos select 2 < 10 || !alive}`, `detach`, `sleep 10`, `deleteVehicle _chute` | `:62-76` |
| Fly home + cleanup | `AIMoveTo` back to spawn, arrival loop (200 m), `deleteVehicle _pilot`, `deleteVehicle _vehicle`, `deleteGroup _grp` | `:78-90` |

Unlike the ammo box, the cargo vehicle is **not** deleted-and-respawned after landing — it is detached and left in place (and remains tracked through `emptyQueu` / `WFBE_SE_FNC_HandleEmptyVehicle`).

## Cross-script differences at a glance

| Aspect | Paratroopers | ParaAmmo | ParaVehicles |
| --- | --- | --- | --- |
| Transport count | `ceil(count units / transportSoldier)` (multi-aircraft) `:39` | 1 `:29` | 1 `:29` |
| Transport var | `WFBE_%1PARACARGO` `:32` | `WFBE_%1PARAVEHI` `:29` | `WFBE_%1PARAVEHI` `:29` |
| Payload | infantry from `WFBE_%1PARACHUTELEVEL<lvl>` `:31` | crate array `WFBE_%1PARAAMMO` `:59` | one `WFBE_%1PARAVEHICARGO` `:45` |
| Drop method | `action ["EJECT"]` per unit, delay 0.35/0.85 `:110-116` | per-crate chute attach + re-spawn `:62-89` | single chute attach, no re-spawn `:62-76` |
| flyInHeight | `300 + random 15` `:64` | `200 + random 20` `:42` | `300 + random 75` `:43` |
| Post-land tracking | client revive marker per trooper `:117` | re-create crate + killed EH `:83-85` | `emptyQueu` + `HandleEmptyVehicle` `:48-49` |
| Stats | `VehiclesCreated _built` `:68`, `UnitsCreated _built` `:89` | `VehiclesCreated 1` `:31`, `UnitsCreated 1` `:32` | `VehiclesCreated 1` `:30`, `UnitsCreated 1` `:31` |

## Continue Reading

- [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas)
- [Tactical support menu player guide](Tactical-Support-Menu-Player-Guide)
- [Faction root variables reference](Faction-Root-Variables-Reference)
- [Paratrooper marker revival](Paratrooper-Marker-Revival)
- [Server authority migration map](Server-Authority-Migration-Map)
