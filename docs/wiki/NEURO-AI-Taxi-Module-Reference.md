# NEURO AI-Taxi Module Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/). Arma 2 OA 1.64.

NEURO is Benny's server-side "AI taxi" / vehicle-sharing system: it is meant to find unassigned AI infantry, locate nearby empty/compatible vehicles heading toward the squad's waypoint, and assign the foot AI as driver/gunner/commander/cargo so they ride instead of walk (header at `Server/Module/NEURO/NEURO.sqf:1-5`). The file defines nine compiled global functions (all prefixed `NEURO_BE_`) and is loaded once at boot.

**Critical finding — the dispatch loop is DORMANT in this build.** The module is compiled and its config hook is set, but the three dispatch entry points (`NEURO_BE_AssignToVehicle`, `NEURO_BE_UpdateTeamDestination`, `NEURO_BE_HandleArrivalCargo`) have **no runtime callers anywhere**. A repo-wide grep for `NEURO_BE_` across Server/ Common/ Client/ returns hits only inside `NEURO.sqf` itself (the helpers call each other). Nothing in the codebase ever invokes the entry points, so no AI is ever auto-assigned by NEURO at runtime. The system is effectively inert scaffolding. Despite this, many live systems still defensively set the `WFBE_Taxi_Prohib` opt-out flag (see the dedicated table below).

## Boot: load + config hook

NEURO is compiled once during server init, then its boarding-eligibility condition is installed into the mission namespace.

| Step | What happens | path:line |
|---|---|---|
| Compile module | `[] Call Compile preprocessFile "Server\Module\NEURO\NEURO.sqf"` — defines all nine `NEURO_BE_*` functions | `Server/Init/Init_Server.sqf:136-137` |
| Set condition hook | `missionNamespace setVariable["NEURO_TAXI_CONDITION", "isNil {_x getVariable 'WFBE_Taxi_Prohib'} && local _x"]` — `_x` is the candidate vehicle | `Server/Init/Init_Server.sqf:144-145` |

The hook string is `Call Compile`d per-vehicle inside `NEURO_BE_GetSuitableVehicles`, so `_x` is bound to the vehicle being tested. The default condition admits a vehicle only when it is **local to the server** and **not** flagged `WFBE_Taxi_Prohib` (`Server/Module/NEURO/NEURO.sqf:67`). The header comment shows the documented example without the `&& local _x` clause (`Server/Module/NEURO/NEURO.sqf:4`); the installed value adds it.

## Function reference

All functions live in `Server/Module/NEURO/NEURO.sqf`. Argument is passed via `_this` (no leading `[]` unless noted).

| Function | Signature (`_this`) | What it does | path:line |
|---|---|---|---|
| `NEURO_BE_ClearVehiclePositions` | vehicle | Unassigns any assigned cargo unit, and the assigned driver/gunner/commander, if that unit is dead or more than 900 m from the vehicle. Housekeeping run before emptiness is measured. | `NEURO.sqf:7-15` |
| `NEURO_BE_GetVehicleEmptiness` | vehicle | Calls `ClearVehiclePositions` first, then returns `[_driver,_gunner,_commander,_cargo,_isFull,_isEmpty]`: open driver/gunner/commander slots (0 if filled or already assigned), free cargo seats (`abs` of cargo emptyPositions minus already-assigned cargo, `NEURO.sqf:35`), `_isFull` (all four zero), `_isEmpty` (no driver/gunner/commander assigned). | `NEURO.sqf:17-41` |
| `NEURO_BE_GetNonAssignedUnits` | array of units | Returns the subset whose `assignedVehicle` is null — i.e. units not already taxiing. | `NEURO.sqf:43-52` |
| `NEURO_BE_GetSuitableVehicles` | `[nearArray, side]` | Filters a candidate vehicle array: keeps vehicles that `canMove`, have `fuel > 0.2`, are `civilian` or the requesting `_side`, whose driver/assigned-driver (if any) is local and same-side, and that pass the `NEURO_TAXI_CONDITION` hook (`Call Compile`d per vehicle). | `NEURO.sqf:54-76` |
| `NEURO_BE_GetGroupWPDestination` | group | Returns the current waypoint position `waypointPosition [_this, currentWaypoint _this]`, or `[0,0,0]` if the group is null or has no waypoints. Used to compare squad vs. driver destinations. | `NEURO.sqf:78-89` |
| `NEURO_BE_GetVehicleZOffset` | vehicle | Returns the vehicle's altitude — `(getPos _this) select 2`. Used to decide paradrop vs. ground unload. | `NEURO.sqf:91-93` |
| `NEURO_BE_HandleArrivalCargo` | unit | On the unit's vehicle: if altitude > 25 m and not over water, eject each living, local cargo unit (unassign, `orderGetIn false`, `action ["EJECT"]`, `sleep 1.2`); if over water, unconditionally unassign (no alive/local guard, no eject); at ≤25 m, unload on the ground (unassign, `orderGetIn false`, `sleep 0.4`). The paradrop/dismount handler. **DORMANT — no caller.** | `NEURO.sqf:95-123` |
| `NEURO_BE_UpdateTeamDestination` | group | For each unit with an assigned vehicle: force out (`_forceOut`) if the vehicle has no driver/assigned-driver or is a player vehicle, or if the driver's group waypoint is >600 m from the squad's waypoint. Force-out units are unassigned and ordered out. Keeps taxis aligned with squad intent. **DORMANT — no caller.** | `NEURO.sqf:125-151` |
| `NEURO_BE_AssignToVehicle` | `[group, position]` | Main dispatch. Gets non-assigned units of the group; if none, exit. Finds vehicles of class `Motorcycle/Car/Tank/Helicopter` within `_range = 500` m of `_position`, filtered by `GetSuitableVehicles`. For each non-full, non-player vehicle, fills driver→gunner→commander (only if empty or its `effectiveCommander` is already in the group), then cargo (units within 500 m, only if the existing driver heads within 600 m of the squad's destination). Assigned units are finally `orderGetIn true`. **DORMANT — no caller.** | `NEURO.sqf:153-240` |

### `NEURO_BE_AssignToVehicle` internals

Notable hard-coded values inside the dispatch function:

| Detail | Value | path:line |
|---|---|---|
| Vehicle search radius | `_range = 500` | `NEURO.sqf:157` |
| Candidate vehicle classes | `["Motorcycle","Car","Tank","Helicopter"]` via `nearEntities` | `NEURO.sqf:163` |
| Cargo board distance gate | unit must be `< 500` m from vehicle | `NEURO.sqf:222` |
| Driver-destination alignment gate | driver's WP within `600` m of squad WP (else skip cargo) | `NEURO.sqf:214` |
| Crew-fill precondition | vehicle `_isEmpty` OR its `effectiveCommander` already in the group | `NEURO.sqf:181` |
| Skips player vehicles | `isPlayer(_vehicle)` → never assigned | `NEURO.sqf:176,179` |

## `WFBE_Taxi_Prohib` — the opt-out flag

This vehicle-level boolean is the NEURO blacklist: set it `true` and `NEURO_TAXI_CONDITION` rejects the vehicle (`Server/Init/Init_Server.sqf:145`). Because so many systems set it, it is the clearest evidence that NEURO was once wired live — these sites still defensively exclude structural/special/town/built vehicles even though the dispatch loop no longer runs. Every confirmed setter:

| Setter site | Vehicle flagged | path:line |
|---|---|---|
| Built unit (hosted server only) | newly built `_vehicle`, `if (isHostedServer)` | `Client/Functions/Client_BuildUnit.sqf:322` |
| Town unit creation | each spawned town `_x` (server side) | `Common/Functions/Common_CreateTownUnits.sqf:91` |
| HQ construction site (MHQ) | the deployed `_MHQ` | `Server/Construction/Construction_HQSite.sqf:80` |
| MHQ repair | repaired `_MHQ` | `Server/Functions/Server_MHQRepair.sqf:33` |
| HandleSpecial — TOWN_AI_HC_CLEANUP | each delegated town `_vehicle` | `Server/Functions/Server_HandleSpecial.sqf:114` |
| Init — side HQ creation | each side's `_hq` MHQ | `Server/Init/Init_Server.sqf:391` |
| Init — vehicle setup (×2) | `_vehicle` | `Server/Init/Init_Server.sqf:498`, `Server/Init/Init_Server.sqf:512` |
| Init — vehicle setup | `_vehicle` | `Server/Init/Init_Server.sqf:529` |

Note: the flag is only ever *set*, never read by gameplay outside the NEURO condition string. With NEURO dormant, these `setVariable` calls have no live effect — but they are harmless and document intent, so do not strip them as dead code without sign-off.

## Reactivation notes

To bring NEURO live you would need a server-side loop that periodically calls `NEURO_BE_AssignToVehicle` per AI group (passing `[group, leaderPos]`), plus `NEURO_BE_UpdateTeamDestination` to re-evaluate alignment and `NEURO_BE_HandleArrivalCargo` per cargo unit on arrival. The helpers are self-contained and side-effecting (`assignAsDriver`/`assignAsCargo`/`orderGetIn`), so any caller must run where the vehicles and units are local — the default hook already enforces `local _x` on the vehicle (`Server/Init/Init_Server.sqf:145`). Verify locality and headless-client ownership before enabling; the module predates the current HC delegation model.

## Continue Reading

- [Modules-Atlas](Modules-Atlas) — the one-paragraph NEURO entry and the full per-module gate/owner index this page expands on
- [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map) — the AI loops that actually run at runtime (contrast with dormant NEURO)
- [Headless-Delegation-And-Failover-Playbook](Headless-Delegation-And-Failover-Playbook) — locality/HC ownership rules any NEURO reactivation must respect
- [Server-Init-Bind-Cleanup](Server-Init-Bind-Cleanup) — the Init_Server boot sequence that compiles NEURO and sets the condition hook
- [Town-AI-Group-Composition-Catalog](Town-AI-Group-Composition-Catalog) — the town units that get `WFBE_Taxi_Prohib` set on spawn
