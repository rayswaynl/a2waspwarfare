# Per-Unit Client Init Pipeline Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Common\Init\Init_Unit.sqf` is the JIP-compatible per-unit/per-vehicle client initializer. Every unit and vehicle created during the mission runs it on each client, which is where role-specific scripted actions (Zeta lift, repair-truck build/repair, Valhalla low-gear, manual flip, boat push, HALO/cargo-eject, plane taxi-reverse), the combat event handlers (countermeasure flares, incoming-missile range cap, bomb/missile Fired handlers, terrain-masking glitch detection, combat-blink marker EH), and the map-marker classification all get attached. The script header credits `Marty` (`Common/Init/Init_Unit.sqf:1-4`). This page documents what attaches per unit class and the where/why of the staged setup.

## How units reach this pipeline

The script is invoked once per created object, always with `[unit, sideID]`. It is launched either via `setVehicleInit` (so it re-runs on JIP clients when the object replicates) or via direct `ExecVM` on already-replicated objects.

| Caller | Path:line | Mechanism |
|---|---|---|
| Generic unit creation | `Common/Functions/Common_CreateUnit.sqf:108` | `_unit setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _side]` |
| Generic unit creation (already-local path) | `Common/Functions/Common_CreateUnit.sqf:114` | `[_unit, _side] ExecVM 'Common\Init\Init_Unit.sqf'` |
| Generic vehicle creation | `Common/Functions/Common_CreateVehicle.sqf:65` | builds `_initStr = Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf'", _side]` |
| UAV spawn | `Client/Module/UAV/uav.sqf:30` | `_uav setVehicleInit Format[... Init_Unit.sqf ...]` |
| Ammo paradrop delivery aircraft | `Server/Support/Support_ParaAmmo.sqf:40` | `setVehicleInit` |
| Paratroopers | `Server/Support/Support_Paratroopers.sqf:52` | `setVehicleInit` |
| Para-dropped vehicles | `Server/Support/Support_ParaVehicles.sqf:41` | `setVehicleInit` |

A skin/class swap deliberately skips re-running this pipeline for the non-global swap unit: see the note at `WASP/actions/SkinSelector/SkinSelector_Apply.sqf:219`. The texture helper is also aware that `setVehicleInit` is re-issued for `Init_Unit.sqf` after it returns (`Common/Functions/Common_AddVehicleTexture.sqf:232`).

## Stage 1 — guards and the wait chain

The script reads its args, then passes through a strict gate sequence before doing any client work. The early waits run on every machine (including the server); the local-player gate then drops the server.

| Step | Path:line | Effect |
|---|---|---|
| Read args | `Init_Unit.sqf:8-10` | `_unit = _this select 0`, `_sideID = _this select 1`, `_unit_kind = typeOf _unit` |
| Alive guard | `Init_Unit.sqf:12` | `if !(alive _unit) exitWith {}` — abort if the unit is null or dead |
| Common-init flag bootstrap | `Init_Unit.sqf:14-16` | `if(isNil 'commonInitComplete')then{ commonInitComplete = false }` |
| Wait: common part | `Init_Unit.sqf:18` | `waitUntil {commonInitComplete}` — set true at `Common/Init/Init_Common.sqf:419` |
| Resolve side + logic | `Init_Unit.sqf:21-22` | `_side = _sideID Call GetSideFromID`; `_logik = _side Call WFBE_CO_FNC_GetSideLogic` |
| Wait: upgrades replicated | `Init_Unit.sqf:24` | `waitUntil {!isNil {_logik getVariable "wfbe_upgrades"}}` |
| Read upgrades | `Init_Unit.sqf:25` | `_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades` |
| Local-player gate | `Init_Unit.sqf:30` | `if !(local player) exitWith {}` — the server does not process the client half |
| Wait: client part | `Init_Unit.sqf:32` | `waitUntil {clientInitComplete}` — set true at `Client/Init/Init_Client.sqf:1032` |
| Settle delay | `Init_Unit.sqf:34` | `sleep 2` |

`commonInitComplete` and `clientInitComplete` are the two phase flags this script consumes; their producers are `Common/Init/Init_Common.sqf:419` and `Client/Init/Init_Client.sqf:1032` respectively (see Lifecycle-Wait-Chain). Everything below Stage 1 runs only on the owning/viewing client after both phases finish.

## Stage 2 — performance instrumentation setup

After the JIP waits and the intentional `sleep 2`, the script snapshots the clock so the audit measures only active client setup, not the wait (`Init_Unit.sqf:36-37`).

| Local | Path:line | Purpose |
|---|---|---|
| `_perfStart = diag_tickTime` | `Init_Unit.sqf:37` | start of measured window |
| `_perfAARStarted = 0` | `Init_Unit.sqf:38` | flips to 1 if the AAR tracker is spawned |
| `_perfBlinkingEH = 0` | `Init_Unit.sqf:39` | flips to 1 if the combat-blink Fired EH is attached |
| `_perfMarkerType = ""` | `Init_Unit.sqf:40` | filled with the chosen marker type |
| `_perfMarkerRefresh = -1` | `Init_Unit.sqf:41` | filled with the marker refresh field |
| `_isMan` | `Init_Unit.sqf:43` | `_unit isKindOf 'Man'` — used as the man/vehicle branch selector throughout |

## Stage 3 — generic per-class action and event-handler attachment

This is the core matrix. Each block is gated by an `isKindOf`/membership test, so a given object only receives the actions appropriate to its class. All of these run on the local client (after the `local player` gate). NVG fix-up runs first (`Init_Unit.sqf:46-48`): any EAST-side unit lacking `NVGoggles` gets them added.

| Class / test | Path:line | Action(s) / EH(s) attached | Show/run condition |
|---|---|---|---|
| In `Zeta_Lifter` list, airlift upgrade > 0 | `Init_Unit.sqf:51-55` | `addAction [localize "STR_WF_Lift", 'Client\Module\ZetaCargo\Zeta_Hook.sqf']` | only if `Zeta_Lifter` not nil, `_unit_kind in Zeta_Lifter`, `_upgrades select WFBE_UP_AIRLIFT > 0` |
| In `WFBE_REPAIRTRUCKS` | `Init_Unit.sqf:56-58` | Build action → `Client\Action\Action_BuildRepair.sqf` (priority 99) | `side group player == side _target && alive _target && player distance _target <= WFBE_C_UNITS_REPAIR_TRUCK_RANGE` |
| Repair truck + camps enabled | `Init_Unit.sqf:60-63` | Repair Camp action → `Client\Action\Action_RepairCamp.sqf` (priority 97) | shown only when near a destroyed camp: `alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)`; gated by `WFBE_C_CAMPS_CREATE > 0` |
| Repair truck + victory condition != 1 | `Init_Unit.sqf:65-68` | Repair MHQ action → `Client\Action\Action_RepairMHQ.sqf` (priority 98) | `alive _target`; gated by `WFBE_C_GAMEPLAY_VICTORY_CONDITION != 1` |
| `isKindOf "Tank"` | `Init_Unit.sqf:71-77` | Valhalla `LowGearOn`/`LowGearOff` toggles → `Client\Module\Valhalla\LowGear_Toggle.sqf` (priority 91); manual `Flip Vehicle` → `WASP\actions\FlipVehicle.sqf` (priority 5) | LowGear on/off keyed off `WFBE_HighClimbingEnabled` per-vehicle var (default `WFBE_HighClimbingDefaultEnabled`) with `vehicle player == _target && canMove _target`; Flip when `(vectorUp _target select 2) < 0.35 && _target distance player < 10` |
| `isKindOf "Car"` | `Init_Unit.sqf:79-85` | same Valhalla low-gear pair + manual Flip | LowGear keyed on `player == driver _target` (vs `vehicle player == _target` for tanks); Flip identical to tank |
| `isKindOf "Ship"` | `Init_Unit.sqf:87-90` | Push action → `Client\Action\Action_Push.sqf` (priority 93) | `driver _target == _this && alive _target && speed _target < 30` |
| `isKindOf "Air"` + transporter | `Init_Unit.sqf:92-98` | HALO → `Client\Action\Action_HALO.sqf` (priority 97); Cargo Eject → `Client\Action\Action_EjectCargo.sqf` (priority 99) | only when `getNumber(CfgVehicles >> _unit_kind >> 'transportSoldier') > 0`; HALO gated on `getPos _target select 2 >= WFBE_C_PLAYERS_HALO_HEIGHT`; Eject on `driver _target == _this` |
| `isKindOf "Air"` + flares param + Vanilla | `Init_Unit.sqf:100-113` | `ExecVM 'Client\Module\CM\CM_Set.sqf'` + `addEventHandler ['incomingMissile', {_this Spawn CM_Countermeasures}]` | only `WFBE_C_MODULE_WFBE_FLARES > 0 && WF_A2_Vanilla`; case 1 also requires `_upgrades select WFBE_UP_FLARESCM > 0`, case 2 unconditional |
| `isKindOf "Air"` + AAR structure + enemy side | `Init_Unit.sqf:115-120` | `[_unit,_side,_sideID] ExecVM 'Common\Common_AARadarMarkerUpdate.sqf'`; sets `_perfAARStarted = 1` | only `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` and `sideJoined != _side` (skip own-side aircraft) |
| `isKindOf "Plane"` | `Init_Unit.sqf:122-125` | TaxiReverse action → `Client\Action\Action_TaxiReverse.sqf` (priority 92); `addEventHandler ['Fired', {_this Spawn HandleShootBombs}]` | TaxiReverse: `driver _target == _this && alive _target && speed within [-4,4] && getPos _target select 2 < 4` |

`Zeta_Lifter` is defined in `Client/Module/ZetaCargo/Zeta_Init.sqf:4` (the airlift-capable aircraft class list). `WFBE_REPAIRTRUCKS` is the global repair-truck class list assembled at `Common/Init/Init_Common.sqf:376`. `HandleShootBombs` is the bomb/missile Fired handler compiled at `Common/Init/Init_Common.sqf:69`; `CM_Countermeasures` is compiled at `Client/Module/CM/CM_Init.sqf:1`. All referenced action/module scripts exist under `Client/Action`, `Client/Module`, and `WASP/actions`.

## Stage 4 — vehicle-only gates (missile range, thermal)

Wrapped in `if !(_isMan)` (`Init_Unit.sqf:129`), so only non-infantry objects receive these.

| Gate | Path:line | Effect |
|---|---|---|
| Max missile range | `Init_Unit.sqf:130-132` | when `WFBE_C_GAMEPLAY_MISSILES_RANGE != 0`: `addEventHandler ['incomingMissile', {_this Spawn HandleIncomingMissile}]` |
| Thermal imaging disable | `Init_Unit.sqf:134-136` | non-Vanilla only; when `WFBE_C_GAMEPLAY_THERMAL_IMAGING < 2`: `Call Compile '_unit disableTIEquipment true;'` (Call Compile used to avoid errors on Vanilla where the command is absent) |

`HandleIncomingMissile` is compiled at `Common/Init/Init_Common.sqf:68`.

## Stage 5 — side-match gate and the first audit record

Before any side-specific (map-marker) work, the script computes `_perfSideMatch = sideID == _sideID` (`Init_Unit.sqf:140`) and emits the `init_unit_client_setup` audit record (`Init_Unit.sqf:141-145`) measuring `diag_tickTime - _perfStart`. The record tag string carries `type;side;isMan;sideMatch;aar;trackInf`. It then hard-exits non-matching clients: `if (!_perfSideMatch) exitWith {}` (`Init_Unit.sqf:146`). Only clients on the unit's own side proceed to draw a map marker.

## Stage 6 — map-marker classification

After the side gate, the script declares a fresh `Private` block (`Init_Unit.sqf:148`) and classifies the object into a map-marker type/color/size. Defaults are `_type = "Vehicle"`, `_color = WFBE_C_<side>_COLOR`, `_size = [5,5]` (`Init_Unit.sqf:151-153`). A global `unitMarker` counter is incremented to mint a unique `_markerName` (`Init_Unit.sqf:157-158`).

Infantry branch (`_isMan`, `Init_Unit.sqf:160-167`):

| Field | Path:line | Value |
|---|---|---|
| Type | `Init_Unit.sqf:161` | `"mil_dot"` |
| Size | `Init_Unit.sqf:162` | `[0.5,0.5]` |
| Same-group recolor | `Init_Unit.sqf:163-166` | if `group _unit == group player`: `_color = "ColorOrange"`, `_txt = _unit Call GetAIDigit` |

Vehicle branch (`Init_Unit.sqf:168-187`) — overrides applied in order:

| Role / test | Path:line | Marker effect |
|---|---|---|
| `isKindOf "Bicycle"` | `Init_Unit.sqf:169` | `_color = "ColorWhite"` |
| `isKindOf "Plane"` | `Init_Unit.sqf:170` | `_color = "ColorPink"` (placeholder) |
| `isKindOf "Helicopter"` | `Init_Unit.sqf:171` | `_color = "ColorPink"` |
| Locally owned in MP | `Init_Unit.sqf:172` | `_color = "ColorOrange"` |
| In `WFBE_<side>SUPPLYTRUCKS` | `Init_Unit.sqf:173` | `_type = "SupplyVehicle"`, `_size = [1,1]` |
| In `WFBE_<side>REPAIRTRUCKS` | `Init_Unit.sqf:174` | `_color = "ColorBrown"`, `_type = "RepairVehicle"` |
| In `WFBE_<side>ARTYVEHICLE` | `Init_Unit.sqf:176` | `_color = "ColorPink"` |
| In `WFBE_<side>AMMOTRUCKS` | `Init_Unit.sqf:179` | `_size = [0.4,0.4]`, `_type = "Attack"`, `_color = "ColorRed"` |
| In `WFBE_<side>LIFTVEHICLE` | `Init_Unit.sqf:181` | `_color = "ColorWhite"` |
| In `WFBE_<side>AMBULANCES` | `Init_Unit.sqf:182` | `_color = "ColorYellow"` |
| In `WFBE_<side>SALVAGETRUCK` | `Init_Unit.sqf:184` | `_color = "ColorKhaki"`, `_type = "SalvageVehicle"` |
| Is the side HQ object | `Init_Unit.sqf:186` | full override: `'Headquarters'` type, `ColorPink`, `[1,1]`, marker name `'HQUndeployed'`, refresh `0.2`, persistent `false` — `_unit == (_side Call WFBE_CO_FNC_GetSideHQ)` |

The per-side class lists (`WFBE_<side>SUPPLYTRUCKS`, `...REPAIRTRUCKS`, `...SALVAGETRUCK`, `...AMBULANCES`, etc.) are `setVariable`'d per faction under `Common/Config/Core_Root/Root_*.sqf` (e.g. `Common/Config/Core_Root/Root_CDF.sqf:13-17`, `Common/Config/Core_Root/Root_RU.sqf:16-17`), looked up here via `Format['WFBE_%1SUPPLYTRUCKS', str _side]`.

Non-HQ objects build `_params = [_type,_color,_size,_txt,_markerName,_unit,1,true,"DestroyedVehicle",_color,false,_side,[2,2]]` (man uses `[1,1]` zoom params, `Init_Unit.sqf:167`; vehicle uses `[2,2]`, `Init_Unit.sqf:185`).

## Stage 7 — combat-blink Fired EH and marker spawn

| Step | Path:line | Effect |
|---|---|---|
| Combat-blink Fired EH | `Init_Unit.sqf:190-197` | only when `WFBE_C_MAP_ICON_BLINKING_ENABLED == 1`: handle stored in per-unit var `WFBE_BlinkFiredEH`; handler calls `WFBE_CL_FNC_SetMapIconStatusInCombat`; sets `_perfBlinkingEH = 1` |
| Store original color | `Init_Unit.sqf:199` | `_unit setVariable ["OriginalMarkerColor", _color, false]` |
| Spawn the marker | `Init_Unit.sqf:201` | `_params Spawn MarkerUpdate` |
| Capture audit fields | `Init_Unit.sqf:202-203` | `_perfMarkerType = _params select 0`, `_perfMarkerRefresh = _params select 6` |
| Marker-spawn audit record | `Init_Unit.sqf:206-210` | emits `init_unit_marker_spawn` with `type;side;isMan;markerType;refresh;groupPlayer;blinkingEH` |

The EH handle is stored deliberately so the consolidated marker loop can remove it on death (EH hygiene, per the inline comment at `Init_Unit.sqf:192`).

## Stage 8 — missile-terrain-masking Fired EH (final)

Last block, gated to driven-class objects (`Init_Unit.sqf:213-219`):

| Step | Path:line | Effect |
|---|---|---|
| Class gate | `Init_Unit.sqf:213` | `_unit isKindOf "Tank" || ... "Car" || ... "Air"` |
| Idempotency guard | `Init_Unit.sqf:214-215` | only if `isNil {_unit getVariable "WFBE_MissileTerrainMaskingEH_Added"}`; sets that flag true to prevent duplicate EHs |
| Fired EH | `Init_Unit.sqf:217` | handle stored in `WFBE_MissileTerrainMaskingEH`; handler `{_this Spawn HandleShootMissiles}` ("glitch rocket detection") |

`HandleShootMissiles` is compiled at `Common/Init/Init_Common.sqf:70`.

## Notes on A2-OA idioms used here

This file is idiomatic Arma 2 OA: capitalized `Private [...]` declarations, capitalized `exitWith`, `Call`/`Spawn`/`ExecVM` capitalization, 2-arg/3-arg `getVariable`/`setVariable`, and `Call Compile` for the Vanilla-guarded `disableTIEquipment` call (`Init_Unit.sqf:135`). The marker is created indirectly through `MarkerUpdate` rather than a direct `createMarkerLocal`. There is no `remoteExec` / `BIS_fnc_MP` here — cross-machine distribution is achieved by `setVehicleInit` replication at the call sites (Stage 0).

## Continue Reading

- [Missile-And-Ordnance-Fired-EH-Reference](Missile-And-Ordnance-Fired-EH-Reference) — the bodies of `HandleShootBombs`/`HandleShootMissiles`/`HandleIncomingMissile` attached here
- [Lifecycle-Wait-Chain](Lifecycle-Wait-Chain) — the `commonInitComplete`/`clientInitComplete` phase flags this pipeline waits on
- [Valhalla-Vehicle-Climbing-Assist](Valhalla-Vehicle-Climbing-Assist) — the low-gear toggle actions attached to Tanks and Cars
- [Zeta-Cargo-Sling-Load-Reference](Zeta-Cargo-Sling-Load-Reference) — the `STR_WF_Lift` action and `Zeta_Lifter` class list
- [AutoFlip-Vehicle-Recovery-Reference](AutoFlip-Vehicle-Recovery-Reference) — the automatic counterpart to the manual `Flip Vehicle` action
- [Marker-Cleanup-Restoration-Systems-Atlas](Marker-Cleanup-Restoration-Systems-Atlas) — how the stored Fired-EH handles and unit markers are removed on death
