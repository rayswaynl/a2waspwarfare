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

`Server/Init/Init_Server.sqf:521-560` starts the major maintenance loops: garbage collection, empty vehicles, map cleaners and building restoration.

| Loop | Source refs | Responsibility |
| --- | --- | --- |
| Garbage collector | `Server/FSM/server_collector_garbage.sqf:17+` | Queues dead/unwanted objects for trash handling. |
| Empty vehicle collector | `Server/FSM/emptyvehiclescollector.sqf` | Handles empty vehicle cleanup. |
| Mine cleaner | `Server/FSM/cleaners/mines_cleaner.sqf:3-17` | Maintains tracked mine pairs. |
| Building restorer | `Server/FSM/restorers/buildings_restorer.sqf:11-20` | Periodically repairs `WarfareBBaseStructure` objects in a large scan. |

The building restorer's broad scan radius means future balancing work should explicitly decide whether it should affect player-built structures, ambient Warfare structures or both.

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
