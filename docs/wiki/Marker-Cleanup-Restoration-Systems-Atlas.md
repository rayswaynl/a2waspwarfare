# Marker Cleanup Restoration Systems Atlas

This atlas maps map markers, visual tracking, cleanup loops and restoration loops. It connects the local UI marker world to server-owned object lifecycle maintenance.

## Runtime Ownership Model

The server owns object lifecycle and authoritative mission state: HQ death/repair state, garbage collection, empty-vehicle collection, map cleaners, mine cleanup and building restoration. Clients own most visible marker presentation locally: town SV labels, team leader arrows, unit/vehicle/HQ tracking markers, respawn UI markers and combat blinking.

Some feature markers use `WF_createMarker`, which creates global marker names and then applies side-local styling through the `MARKER_CREATION` publicVariable path. Because this mixes global marker creation with side-local visual intent, marker visibility should be smoke-tested before changing marker deletion or JIP behavior.

## Local Client Marker Families

| Family | Source refs | Notes |
| --- | --- | --- |
| Town markers | `Client/FSM/updatetownmarkers.sqf:6-18`, `:54-83`, `:103-121` | Caches town marker names, refreshes supply value text locally and throttles updates based on map/GPS/dialog visibility. |
| Team leader markers | `Client/FSM/updateteamsmarkers.sqf:14-25`, `:45-56`, `:158-193`, `:217-224` | Creates local squad leader markers once and updates while map/GPS/Warfare dialogs are visible. |
| Unit/vehicle/HQ tracking | `Common/Common_MarkerUpdate.sqf:21-245`; started from `Common/Init/Init_Unit.sqf:156-196`, `Common_CreateUnit.sqf:57-71`, `Common_CreateVehicle.sqf:40-55` | Per-object local marker loop for tracked entities, vehicles and HQ state. |
| Combat blinking | `Client_BookkeepBlinkingIcons.sqf:5-7`, `Client_BlinkMapIcon.sqf:5-38`, `Client_SetMapIconStatusInCombat.sqf:7-39` | Optional parameter-gated combat visual state. |
| WASP map text markers | `WASP/global_marking_monitor.sqf:2-28`, `:52-82` | Hooks map marker text input. The sleepless display wait remains a performance opportunity. |

## Public-Variable Marker Broadcasts

`Common/Functions/Common_CreateMarker.sqf:51-83` creates the marker name with `createMarker`, optionally creates an ellipse marker, sets `MARKER_CREATION` in mission namespace and broadcasts it. `Client/Functions/Client_onEventHandler_MARKER_CREATION.sqf:32-49` applies side-local styling.

This page treats the global-name/side-local-style split as a verification requirement. Do not assume enemy invisibility from comments alone; verify the rendered marker state in multiplayer before changing marker creation or deletion semantics.

## HQ Wreck Marker Lifecycle

HQ marker state is split across:

- `Server/Functions/Server_OnHQKilled.sqf:84-115`, which records killed HQ/wreck state and broadcasts side state.
- `Server/Functions/Server_MHQRepair.sqf:55-75`, which restores MHQ state.
- `Client/FSM/updateclient.sqf:41-99`, which reacts to side/HQ state and keeps client presentation in sync.

Use [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) for the full HQ object/authority map.

Current audit nuance: the repair path calls the marker helper, but that helper still executes `deleteMarker` while documenting local marker cleanup. If the tracked wreck object disappears before the dead-state update path runs, marker update exits on a null object instead of deleting the stale marker. West/east are covered by the explicit HQ marker variables; resistance is not.

## Server Cleanup And Restoration Loops

`Server/Init/Init_Server.sqf:521-560` starts the major maintenance loops after town initialization: garbage collection, empty vehicles, dropped item cleanup, crater cleanup, ruins cleanup, building restoration and tracked mine cleanup. Treat this as a server-owned runtime layer, not a client UI feature. The Chernarus source mission is the authoritative edit point; generated Vanilla/terrain copies should be produced through the LoadoutManager workflow after source changes.

### Runtime Contracts

| Loop | Startup / timer source | Runtime behavior | Performance hook | Developer notes |
| --- | --- | --- | --- | --- |
| Garbage collector | `Init_Server.sqf:521-536`; `server_collector_garbage.sqf:4-32` | Every 0.5 seconds it scans `allDead`, excludes current west/east HQ objects, skips objects already in `gc_collector` and skips objects carrying `wfbe_trashable`, then spawns `TrashObject` and records the object in `gc_collector`. | `server_garbage_collector` with `dead`, `tracked` and `spawned`. | Runs every 0.5s. `RequestOnUnitKilled.sqf:51-54` uses `wfbe_trashed`, not `wfbe_trashable`, so the collector flag contract is inconsistent. |
| Empty vehicle collector | `Init_Server.sqf:523,537-538`; `emptyvehiclescollector.sqf:4-30` | Polls replicated `WF_Logic getVariable "emptyVehicles"`, skips vehicles already in `emptyQueu`, adds new vehicles to `emptyQueu`, spawns `WFBE_SE_FNC_HandleEmptyVehicle`, then removes the handled vehicle from the replicated list. | `emptyvehiclescollector` with queued/handled counts. | `emptyVehicles` can be pushed by clients after buys (`Client_BuildUnit.sqf:252-253`), while the server handles lifecycle. Keep this queue idempotent. |
| Dropped items cleaner | `Init_Server.sqf:542-544`; `droppeditems_cleaner.sqf:3-44` | Uses one map-wide center/radius scan for `weaponholder`, `Mine` and `MineE` within radius `20000`, deletes every object with a cooperative `sleep 0.5` per object, then sleeps by `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD`. | `cleaner_droppeditems` with scanned/deleted counts and per-class counts. | Default interval is 120 seconds (`Parameters.hpp:527-531`). It also deletes generic `Mine`/`MineE`, so confirm it does not fight tracked minefield cleanup or intended live mine gameplay. |
| Crater cleaner | `Init_Server.sqf:546-548`; `crater_cleaner.sqf:3-49` | Scans `CraterLong_small` and `CraterLong` within a broad `20000` map radius, deletes every crater with cooperative sleeps, then sleeps by `WFBE_C_CRATER_CLEANER_TIME_PERIOD`. | `cleaner_craters` with scanned/deleted/small/long counts. | Default interval is 1800 seconds (`Parameters.hpp:521-525`). A future optimization should preserve the cooperative deletion behavior while narrowing the candidate set. |
| Ruins cleaner | `Init_Server.sqf:550-552`; `ruins_cleaner.sqf:3-28` | Scans broad map center/radius for `Ruins`, deletes every result with cooperative sleeps, then sleeps by `WFBE_C_RUINS_CLEANER_TIME_PERIOD`. | `cleaner_ruins` with scanned/deleted counts. | Default interval is 1800 seconds (`Parameters.hpp:539-543`). This is broad ambient cleanup; verify it does not remove ruins that other systems expect as evidence/state. |
| Building restorer | `Init_Server.sqf:554-556`; `buildings_restorer.sqf:3-26` | Scans `[7500,7900,0]` for `WarfareBBaseStructure` within radius `10500` and calls `setdamage 0` on every result with cooperative sleeps, then `uisleep`s by `WFBE_C_BUILDING_RESTORER_TIME_PERIOD`. | `restorer_buildings` with scanned/restored counts. | Default parameter is 1800 seconds (`Parameters.hpp:515-519`), but the script has a fallback of 600 seconds if the parameter is missing. It repairs by class, not by ownership registry. |
| Mine cleaner | `Init_Server.sqf:558-560`; `mines_cleaner.sqf:3-32` | Initializes global `mines = []`, then loops tracked `[mine, time]` pairs. When `time - _mine_timer >= _timer`, it deletes the mine object. | `cleaner_mines` with tracked/scanned/deleted counts. | Mine producers append pairs in `WASP/rpg_dropping/DropRPG.sqf:66-67` and `Construction_StationaryDefense.sqf:32,44,55`. Current removal uses `mines = mines - _x`, which is the wrong shape for removing a nested pair. |

### Timing And Parameter Notes

`Rsc/Parameters.hpp:515-543` exposes the operator-facing intervals for building restoration, crater cleanup, dropped items, minefields and ruins. Defaults are:

| Parameter | Default | Values | Consumed by |
| --- | --- | --- | --- |
| `WFBE_C_BUILDING_RESTORER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `buildings_restorer.sqf:3,26` |
| `WFBE_C_CRATER_CLEANER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `crater_cleaner.sqf:3,47` |
| `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD` | 120 seconds | 60, 75, 90, 105, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600 | `droppeditems_cleaner.sqf:3,44` |
| `WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD` | 5400 seconds | 1800, 3600, 5400, 7200 | `mines_cleaner.sqf:4,30` |
| `WFBE_C_RUINS_CLEANER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `ruins_cleaner.sqf:3,26` |

The code intentionally separates active work time from wall-clock cycle time in PerformanceAudit records: wide scans and delete/restore calls are timed, but cooperative per-object sleeps are excluded and captured only indirectly in `cycleMs`. This is useful when testing because a low active time can still produce a long real-world cycle if a large delete queue is spread across many half-second pauses.

### Ownership And Data-Flow Notes

- `gc_collector` is a server global dedupe list for `allDead` objects already handed to `TrashObject`.
- `emptyQueu` is initialized at `Init_Server.sqf:300` and is used to avoid launching duplicate empty-vehicle handlers while `WF_Logic emptyVehicles` is drained.
- `mines` is a global array owned by the mine cleaner and populated by RPG-dropping and stationary-defense construction. It stores nested pairs `[mineObject, createdAt]`, not a flat object list.
- Dropped item, crater, ruins and building loops do not use registries; they use fixed map-center `nearestObjects` scans.
- The building restorer repairs all scanned `WarfareBBaseStructure` class objects. Future gameplay changes must decide whether this should include only player-built structures, stock Warfare base objects, destroyed AI-built structures or all matching ambient objects.
- These scripts exist in generated/terrain mission copies too. Patch Chernarus first, then run the LoadoutManager propagation workflow and inspect generated diffs.

## Patch-Ready Findings

| Finding | Evidence | Patch shape |
| --- | --- | --- |
| Mine cleaner pair removal likely wrong | Minefields push `[mine, time]` pairs; `mines_cleaner.sqf:17` uses `mines = mines - _x`. | Remove the tracked pair with `mines = mines - [_x]` or rewrite to filter live pairs. Smoke mine cleanup and verify no stale pairs persist. |
| Garbage flags are inconsistent | `server_collector_garbage.sqf:17` skips `wfbe_trashable`; `RequestOnUnitKilled.sqf:51-54` sets `wfbe_trashed`. | Align the flag contract: collector should also skip `wfbe_trashed`, or kill paths should set the collector's skip flag before spawning trash. |
| Local marker delete helper deletes globally | `Client_Delete_Marker.sqf:5` documents local marker creation; `:24` comments `deleteMarkerLocal`; `:25` uses `deleteMarker`. | Restore local deletion for side-local markers or rename/split helper behavior. Smoke side-specific marker removal. |
| HQ wreck marker can stale after object loss | `updateclient.sqf:52` only updates dead HQ marker when the wreck object exists; `Common_UpdateMarker.sqf:25` exits on null object. | Delete the marker when a tracked HQ wreck becomes null, or keep a side-owned registry that can explicitly clear stale marker names. |
| HQ marker state is west/east only | `Server_OnHQKilled.sqf:97`, `Server_MHQRepair.sqf:60`, `updateclient.sqf:42-100`. | Do not enable resistance HQ recovery without adding a resistance marker state machine and smoke. |
| Global marker names with side-local styling need proof | `Common_CreateMarker.sqf:53,59,82-83` creates global names then broadcasts side-local details. | Add an MP smoke case before changing marker visibility, deletion or JIP replay. |
| Single active marker animation global | `Client_MarkerAnim.sqf` uses one `activeAnimMarker`. | If command marker animations are still used, make animation state per marker to avoid concurrent stomp. |
| Blink icon nil/default guards | `Client_BlinkMapIcon.sqf` uses marker/color state from bookkeeping. | Add nil/default guards before marker/color use and smoke combat marker blinking. |

## Validation Checklist

- Map/GPS open and closed while town/team markers update.
- Side-local marker visibility with at least one player per side.
- Marker deletion on side-local markers does not remove enemy/friendly markers globally unless intended.
- HQ destroyed/repaired marker state for both sides.
- Minefield cleanup removes expired tracked pairs.
- Garbage collector does not double-trash killed objects already handled by `RequestOnUnitKilled`.
- Building restorer repairs only the intended structure set.

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Performance: [Performance opportunity sweep](Performance-Opportunity-Sweep)
