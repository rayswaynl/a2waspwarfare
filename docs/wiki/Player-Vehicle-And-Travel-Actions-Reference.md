# Player Vehicle And Travel Actions Reference

> Provenance: verified 2026-06-21 against stable `master@0139a346`, Arma 2 OA 1.64, source mission `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

This page catalogs the live player-facing vehicle and travel scroll actions that were previously only scattered across action scripts, UI atlases and owner pages. Repair actions are listed for routing, but their authority and economy risks remain owned by [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Towns/camps/capture](Towns-Camps-And-Capture-Atlas) and [Player skill abilities](Player-Skill-Abilities-Reference).

## Registration Map

| Surface | Source registration | Visible gate | Runtime target |
| --- | --- | --- | --- |
| Repair truck build menu | Repair trucks add `Action_BuildRepair.sqf`. `Common/Init/Init_Unit.sqf:56-58` | Same-side player, live repair truck, player within `WFBE_C_UNITS_REPAIR_TRUCK_RANGE`. `Common/Init/Init_Unit.sqf:56-58` | Construction/repair-truck build flow, owned by [Construction/CoIn](Construction-And-CoIn-Systems-Atlas). |
| Repair camp from repair truck | Repair trucks add `Action_RepairCamp.sqf` when camp creation is enabled. `Common/Init/Init_Unit.sqf:60-63` | Live repair truck and `WFBE_CL_FNC_CanRepairCampNearby` returns true. `Common/Init/Init_Unit.sqf:60-63` | Client pays/waits, then sends `RequestSpecial ["repair-camp", _camp, WFBE_Client_SideID]`. `Client/Action/Action_RepairCamp.sqf:33-66` |
| Repair camp from player skill | Skill apply adds `Action_RepairCampEngineer.sqf` for eligible roles. `Client/Module/Skill/Skill_Apply.sqf:38,45,121,139,157` | Same nearby-camp helper gate as repair truck camp repair. `Client/Module/Skill/Skill_Apply.sqf:38,45,121,139,157` | Client pays/waits, plays the medic animation during the delay, then sends the same `RequestSpecial` repair-camp payload. `Client/Action/Action_RepairCampEngineer.sqf:33-67` |
| Repair MHQ | Repair trucks add `Action_RepairMHQ.sqf` unless victory condition is `1`. `Common/Init/Init_Unit.sqf:65-68` | Action is visible on live repair trucks; the script itself rejects alive HQs or dead HQs farther than 30 m from the repair vehicle. `Common/Init/Init_Unit.sqf:65-68`; `Client/Action/Action_RepairMHQ.sqf:5-6` | Client checks/debits repair price, sends `RequestMHQRepair`, marks repair state and increments the local repair count. `Client/Action/Action_RepairMHQ.sqf:24-40` |
| Low Gear | Tanks and cars add `LowGear_Toggle.sqf` on/off actions. `Common/Init/Init_Unit.sqf:71-84` | Tank action allows `vehicle player == _target`; car action requires `player == driver _target`; both require `canMove`. `Common/Init/Init_Unit.sqf:73-74,81-82` | Toggle flips `WFBE_HighClimbingEnabled` and starts `VALHALLA_FNC_LowGear` for the driver when enabling. `Client/Module/Valhalla/LowGear_Toggle.sqf:7-19` |
| Manual Flip Vehicle | Tanks and cars add `WASP\actions\FlipVehicle.sqf`. `Common/Init/Init_Unit.sqf:75-84` | Target must be steeply tilted, within 10 m, and the target vehicle must be alive inside the script. `Common/Init/Init_Unit.sqf:76,84`; `WASP/actions/FlipVehicle.sqf:11-15` | Rights the vehicle with `setVectorUp`, raises it to `z = 0.5`, then applies a downward velocity. `WASP/actions/FlipVehicle.sqf:16-19` |
| Boat Push | Ships add `Action_Push.sqf`. `Common/Init/Init_Unit.sqf:87-90` | Driver-only, target alive, speed below 30. `Common/Init/Init_Unit.sqf:87-90` | Adds forward velocity using vehicle direction and `_speed = 10`. `Client/Action/Action_Push.sqf:3-8` |
| Air-transport HALO | Air vehicles with `transportSoldier > 0` add `Action_HALO.sqf`. `Common/Init/Init_Unit.sqf:92-95` | Target altitude must be at least `WFBE_C_PLAYERS_HALO_HEIGHT`; current default is `200`. `Common/Init/Init_Unit.sqf:92-95`; `Common/Init/Init_CommonConstants.sqf:424` | Ejects the caller, zeroes velocity and starts `ca\air2\Halo\data\Scripts\HALO_getout.sqs`. `Client/Action/Action_HALO.sqf:3-9` |
| Air-transport cargo eject | Air vehicles with `transportSoldier > 0` add `Action_EjectCargo.sqf`. `Common/Init/Init_Unit.sqf:92-98` | Driver-only and target alive. `Common/Init/Init_Unit.sqf:96-98` | Builds cargo as crew minus driver/gunner/commander, ejects local units directly, and sends remote player-led groups a client `HandleSpecial ["action-perform", _x, "EJECT", _vehicle]` request. `Client/Action/Action_EjectCargo.sqf:3-26` |
| Plane Taxi Reverse | Planes add `Action_TaxiReverse.sqf`. `Common/Init/Init_Unit.sqf:122-124` | Driver-only, target alive, speed between -4 and 4, altitude below 4. `Common/Init/Init_Unit.sqf:122-124` | Adds reverse velocity using vehicle direction and `_speed = -5`. `Client/Action/Action_TaxiReverse.sqf:3-8` |

## Lock And Unlock Paths

| Path | Source shape | Practical note |
| --- | --- | --- |
| Built-vehicle lock actions | Bought vehicles add `Action_ToggleLock.sqf` lock/unlock actions after local init. `Client/Functions/Client_BuildUnit.sqf:327-331` | The action script toggles `_vehicle lock _lock` from the target's current lock state. `Client/Action/Action_ToggleLock.sqf:3-7` |
| Commander MHQ lock actions | The client FSM adds MHQ lock/unlock actions for the commander group, and `SetMHQLock.sqf` can add the same actions after server MHQ repair. `Client/FSM/updateclient.sqf:228-232`; `Server/Functions/Server_MHQRepair.sqf:51`; `Client/PVFunctions/SetMHQLock.sqf:1-3` | The current registration lines name `Action_ToggleLock.sqf`; audit any wrapper revival separately. `Client/FSM/updateclient.sqf:231-232`; `Client/PVFunctions/SetMHQLock.sqf:2-3` |
| Server vehicle-lock request channel | `RequestVehicleLock` is registered as a server PVF; `SetVehicleLock` and `SetMHQLock` are registered as client PVFs. `Common/Init/Init_PublicVariables.sqf:9,41,43` | The server handler directly locks the payload vehicle and broadcasts `SetVehicleLock`. `Server/PVFunctions/RequestVehicleLock.sqf:3-8`; `Client/PVFunctions/SetVehicleLock.sqf:1` |
| SpecOps lockpick | The SpecOps skill searches nearby vehicles, runs the lockpick animation/check loop and sends `RequestVehicleLock` with `false` on success. `Client/Module/Skill/Skill_SpecOps.sqf:7-18,24-31,46-53` | This is the source-backed active request path to the server vehicle-lock handler in this pass. `Client/Module/Skill/Skill_SpecOps.sqf:46-53`; `Server/PVFunctions/RequestVehicleLock.sqf:3-8` |
| Legacy MHQ request wrapper | `Action_ToggleMHQLock.sqf` still contains a local-if-local / `RequestVehicleLock`-if-remote wrapper. `Client/Action/Action_ToggleMHQLock.sqf:11-16` | The active commander-MHQ registration anchors above use `Action_ToggleLock.sqf`, so keep future lock hardening tied to actual caller evidence before changing status. `Client/FSM/updateclient.sqf:231-232`; `Client/PVFunctions/SetMHQLock.sqf:2-3` |

## Repair Routes

| Action | Why this page does not own the deep behavior | Canonical owner |
| --- | --- | --- |
| `Action_RepairMHQ.sqf` | It carries client-side repair price/count/debit and sends only side to `RequestMHQRepair`. `Client/Action/Action_RepairMHQ.sqf:24-40` | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) and [Server authority map](Server-Authority-Migration-Map) |
| `Action_RepairCamp.sqf` and `Action_RepairCampEngineer.sqf` | Both client-pay/wait and then send `RequestSpecial ["repair-camp", _camp, WFBE_Client_SideID]`. `Client/Action/Action_RepairCamp.sqf:33-66`; `Client/Action/Action_RepairCampEngineer.sqf:33-67` | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas) and [Player skill abilities](Player-Skill-Abilities-Reference) |
| `WASP/actions/FlipVehicle.sqf` | The immediate manual flip is already distinguished from the automatic AutoFlip watcher. `WASP/actions/FlipVehicle.sqf:4-6,16-19`; `Client/Module/AutoFlip/AutoFlip.sqf:75-100` | [AutoFlip vehicle recovery](AutoFlip-Vehicle-Recovery-Reference) |
| `Client/Module/Valhalla/LowGear_Toggle.sqf` | The toggle is the entry action; key handling and climb loop behavior are Valhalla-specific. `Client/Module/Valhalla/LowGear_Toggle.sqf:11-19`; `Client/Module/Valhalla/Init_Valhalla.sqf:29-58` | [Valhalla vehicle climbing-assist](Valhalla-Vehicle-Climbing-Assist) |

## Continue Reading

- [AutoFlip vehicle recovery](AutoFlip-Vehicle-Recovery-Reference)
- [Valhalla vehicle climbing-assist](Valhalla-Vehicle-Climbing-Assist)
- [Vehicle countermeasure flares and spoofing](Vehicle-Countermeasure-Flares-And-Spoofing)
- [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas)
- [Player skill abilities](Player-Skill-Abilities-Reference)
