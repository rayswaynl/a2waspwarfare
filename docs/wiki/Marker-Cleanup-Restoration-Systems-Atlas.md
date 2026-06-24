# Marker Cleanup Restoration Systems Atlas

This atlas maps map markers, visual tracking, cleanup loops and restoration loops. It connects the local UI marker world to server-owned object lifecycle maintenance.

## How To Use This Page

Use this page as the marker/cleanup gateway, not as the canonical owner for every UI or server-runtime defect. Keep branch matrices here only when the issue is specifically marker cleanup or server object lifecycle.

| Need | Start here |
| --- | --- |
| Town, team, HQ, respawn and tactical marker ownership | [Local Client Marker Families](#local-client-marker-families) and [Client UI systems](Client-UI-Systems-Atlas#indicator-surface-matrix) |
| Public marker channel / side-local styling risk | [Public-Variable Marker Broadcasts](#public-variable-marker-broadcasts), then [Public variable channel index](Public-Variable-Channel-Index) |
| HQ death, wreck and repair marker state | [HQ Wreck Marker Lifecycle](#hq-wreck-marker-lifecycle), then [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| Server cleanup/restoration loops, PerformanceAudit labels and smoke | [Server Cleanup And Restoration Loops](#server-cleanup-and-restoration-loops), then [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| Empty supply-truck 24-hour timeout branch status | [Empty Supply Truck Branch Matrix](#empty-supply-truck-branch-matrix) |
| MASH, paratrooper, artillery, UAV or support markers | [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) and [Paratrooper marker revival](Paratrooper-Marker-Revival) |

## Current Branch Scope

The empty supply-truck matrix below was refreshed on 2026-06-24 for current B74.2 `origin/claude/b74.2-aicom@21b62b04` after earlier rows still named `origin/claude/b74.2-aicom@d472da6a`. Docs/source `HEAD@248baa289ca5` is unchanged from `499c2543` / `b4e10b5f` for checked collector/handler paths; current stable/B74.1, current B74.2, B69, adjacent B74, direct current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f` and historical `a96fdda2` all still drain `WF_Logic` `emptyVehicles` through `WFBE_SE_FNC_HandleEmptyVehicle` and set supply-truck `_delay = 86400` in both maintained roots. Checked path deltas `b4e10b5f..HEAD`, `499c2543..HEAD`, `0139a3468609..origin/master`, `d472da6a..origin/claude/b74.2-aicom`, `origin/master..origin/claude/b74.2-aicom` and `origin/claude/b69..origin/claude/b74-aicom-spend` are empty. Current origin exposed no live `release/*`, cleanup or supply rescue head during this pass; historical `a96fdda2` is local source evidence, not current release proof.

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

`Server/Init/Init_Server.sqf:528-531` waits for `townInit` before starting victory detection and resource updates. The lifecycle maintenance loops start outside that wait block at `Init_Server.sqf:535-560`: garbage collection, empty vehicles, dropped item cleanup, crater cleanup, ruins cleanup, building restoration and tracked mine cleanup. Treat this as a server-owned runtime layer, not a client UI feature. The Chernarus source mission is the authoritative edit point; generated Vanilla/terrain copies should be produced through the LoadoutManager workflow after source changes.

### Runtime Contracts

| Loop | Startup / timer source | Runtime behavior | Performance hook | Developer notes |
| --- | --- | --- | --- | --- |
| Garbage collector | `Init_Server.sqf:535`; `server_collector_garbage.sqf:4-34` | Every 5 seconds it scans `allDead`, excludes current west/east HQ objects, skips objects already in `gc_collector` and skips objects carrying `wfbe_trashable`, then spawns `TrashObject` and records the object in `gc_collector`. | `server_garbage_collector` with `dead`, `tracked` and `spawned`. | Runs every 5s (`sleep 5` at `:34`, PERF1: corpses/wrecks do not need a 2Hz sweep). `RequestOnUnitKilled.sqf:51-54` uses `wfbe_trashed`, not `wfbe_trashable`, so the collector flag contract is inconsistent. |
| Empty vehicle collector | `Init_Server.sqf:537`; `emptyvehiclescollector.sqf:4-30`; `Server_HandleEmptyVehicle.sqf:22-23` on docs-shaped refs / `:30-31` on stable/B74-shaped refs | Polls replicated `WF_Logic getVariable "emptyVehicles"`, skips vehicles already in `emptyQueu`, adds new vehicles to `emptyQueu`, spawns `WFBE_SE_FNC_HandleEmptyVehicle`, then removes the handled vehicle from the replicated list. Supply-truck classes are given `_delay = 86400`. | `emptyvehiclescollector` with queued/handled counts. | `emptyVehicles` can be pushed by clients after buys (`Client_BuildUnit.sqf:252-253`), while the server handles lifecycle. Keep this queue idempotent. Empty supply trucks can remain for up to 24 hours by design, so do not diagnose them as ordinary cleanup failure without checking vehicle type. |
| Dropped items cleaner | `Init_Server.sqf:543`; `cleaners/droppeditems_cleaner.sqf:3-83` | Uses one map-wide center/radius scan for `weaponholder` only (`:62`) within radius `20000` from `[7000,7500,0]`, deletes up to a per-cycle cap with a cooperative `sleep 0.5` per object, then sleeps by `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD`. | `cleaner_droppeditems` with scanned/deleted counts and a weaponholder count. | Param default is 120 seconds (`Parameters.hpp:501`), but the script floors the interval at 300 and defaults to 600 on nil (`:19-21`), so effective cadence is ~10 minutes (B40, Ray spec). The B40 cleanup (`:7-15`) removed the old `Mine`/`MineE` scans; those are now handled by `mines_cleaner.sqf`, so this loop no longer touches mines. |
| Crater cleaner | `Init_Server.sqf:547`; `cleaners/crater_cleaner.sqf:3-49` | Scans `CraterLong_small` and `CraterLong` within a broad `20000` map radius, deletes every crater with cooperative sleeps, then sleeps by `WFBE_C_CRATER_CLEANER_TIME_PERIOD`. | `cleaner_craters` with scanned/deleted/small/long counts. | Default interval is 1800 seconds (`Parameters.hpp:521-525`). A future optimization should preserve the cooperative deletion behavior while narrowing the candidate set. |
| Ruins cleaner | `Init_Server.sqf:551`; `cleaners/ruins_cleaner.sqf:3-28` | Scans broad map center/radius for `Ruins`, deletes every result with cooperative sleeps, then sleeps by `WFBE_C_RUINS_CLEANER_TIME_PERIOD`. | `cleaner_ruins` with scanned/deleted counts. | Default interval is 1800 seconds (`Parameters.hpp:539-543`). This is broad ambient cleanup; verify it does not remove ruins that other systems expect as evidence/state. |
| Building restorer | `Init_Server.sqf:555`; `restorers/buildings_restorer.sqf:3-26` | Scans `[7500,7900,0]` for `WarfareBBaseStructure` within radius `10500` and calls `setdamage 0` on every result with cooperative sleeps, then `uisleep`s by `WFBE_C_BUILDING_RESTORER_TIME_PERIOD`. | `restorer_buildings` with scanned/restored counts. | Default parameter is 1800 seconds (`Parameters.hpp:515-519`), but the script has a fallback of 600 seconds if the parameter is missing. It repairs by class, not by ownership registry. |
| Mine cleaner | `Init_Server.sqf:559`; `cleaners/mines_cleaner.sqf:3-32` | Initializes global `mines = []`, then loops tracked `[mine, time]` pairs. When `time - _mine_timer >= _timer`, it deletes the mine object. | `cleaner_mines` with tracked/scanned/deleted counts. | Mine producers append pairs in `WASP/rpg_dropping/DropRPG.sqf:66-67` and `Construction_StationaryDefense.sqf:32,44,55`. Current removal uses `mines = mines - _x`, which is the wrong shape for removing a nested pair. |

### Timing And Parameter Notes

`Rsc/Parameters.hpp:515-543` exposes the operator-facing intervals for building restoration, crater cleanup, dropped items, minefields and ruins. Defaults are:

| Parameter | Default | Values | Consumed by |
| --- | --- | --- | --- |
| `WFBE_C_BUILDING_RESTORER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `buildings_restorer.sqf:3,26` |
| `WFBE_C_CRATER_CLEANER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `crater_cleaner.sqf:3,47` |
| `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD` | 120 seconds (param); script floors at 300 / nil-defaults 600 → effective ~600 | 60, 75, 90, 105, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600 | `droppeditems_cleaner.sqf:19-21,82` |
| `WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD` | 5400 seconds | 1800, 3600, 5400, 7200 | `mines_cleaner.sqf:4,30` |
| `WFBE_C_RUINS_CLEANER_TIME_PERIOD` | 1800 seconds | 1800, 3600, 5400, 7200 | `ruins_cleaner.sqf:3,26` |

The code intentionally separates active work time from wall-clock cycle time in PerformanceAudit records: wide scans and delete/restore calls are timed, but cooperative per-object sleeps are excluded and captured only indirectly in `cycleMs`. This is useful when testing because a low active time can still produce a long real-world cycle if a large delete queue is spread across many half-second pauses.

### Cadence And Cost Interpretation

This closes the old "cleaners/restorers perf is map-only" gap with source-level cadence evidence. It still does not replace live RPT measurement: use the PerformanceAudit rows below to decide whether a patch is worth taking.

| Class | Loops | Cost shape | First action |
| --- | --- | --- | --- |
| Registry drains | Garbage collector runs every 5 seconds (`server_collector_garbage.sqf:4,34`, PERF1 cadence cut); the empty-vehicle collector runs every 0.5 seconds (`emptyvehiclescollector.sqf:4,30`). | Garbage scans `allDead` and dedupes through `gc_collector`; empty vehicles drains `WF_Logic emptyVehicles`, which can be written by clients after buys (`Client_BuildUnit.sqf:252-253`). | Keep predicates cheap and idempotent. Fix queue/flag correctness before changing cadence. |
| Wide scan, long timer | Dropped items scans `weaponholder` only in a 20000 radius on an effective ~10-minute cadence (`droppeditems_cleaner.sqf:19-21,62`; param default 120 at `Parameters.hpp:501`, floored to 300 / nil-default 600 in script). Craters/ruins use the same broad center/radius with 1800-second defaults (`crater_cleaner.sqf:14-50`; `ruins_cleaner.sqf:9-29`; `Parameters.hpp:521-525,539-543`). | Broad `nearestObjects` scans, followed by `sleep 0.5` per deleted object. Active scan/delete time is recorded separately from wall-clock cycle time. | Audit first. If RPT rows show sustained high active time or huge cycle time, then consider terrain-aware centers/radii or producer-owned registries. |
| Restorer, long timer | Building restorer scans `WarfareBBaseStructure` within 10500 m from `[7500,7900,0]`, defaults to parameter 1800 seconds but falls back to 600 if missing (`buildings_restorer.sqf:3,10-26`; `Parameters.hpp:515-519`). | Repairs every matching class with `setdamage 0`, regardless of side-owned structure registry. | Treat behavior as gameplay-sensitive. Narrowing the scan or registry-filtering needs construction/base smoke, not only perf evidence. |
| Tracked mine queue | Mine cleaner iterates global `[mine, createdAt]` pairs and defaults to 5400 seconds (`mines_cleaner.sqf:3-32`; `Parameters.hpp:533-537`). Producers append pairs in RPG dropping and minefield construction (`DropRPG.sqf:65-68`; `Construction_StationaryDefense.sqf:31-55`). | Runtime cost is queue length, not map radius. Current removal uses `mines = mines - _x`, which is the wrong shape for nested pairs. | Patch pair removal before tuning cadence. Smoke mine expiry and repeated mine creation. |

PerformanceAudit labels to search in the server RPT:

| Label | Source | Fields |
| --- | --- | --- |
| `server_garbage_collector` | `server_collector_garbage.sqf:26-28` | `dead`, `tracked`, `spawned` |
| `emptyvehiclescollector` | `emptyvehiclescollector.sqf:23-27` | `queued`, `handled` |
| `cleaner_droppeditems` | `droppeditems_cleaner.sqf:77-78` | `scanned`, `deleted`, `weaponholders`, `mines` (always 0), `cap`, `cycleMs` |
| `cleaner_craters` | `crater_cleaner.sqf:40-42` | `scanned`, `deleted`, `small`, `long`, `cycleMs` |
| `cleaner_ruins` | `ruins_cleaner.sqf:20-22` | `scanned`, `deleted`, `cycleMs` |
| `restorer_buildings` | `buildings_restorer.sqf:21-23` | `scanned`, `restored`, `cycleMs` |
| `cleaner_mines` | `mines_cleaner.sqf:24-26` | `tracked`, `scanned`, `deleted`, `cycleMs` |

### Ownership And Data-Flow Notes

- `gc_collector` is a server global dedupe list for `allDead` objects already handed to `TrashObject`.
- `emptyQueu` is initialized at `Init_Server.sqf:300` and is used to avoid launching duplicate empty-vehicle handlers while `WF_Logic emptyVehicles` is drained.
- `mines` is a global array owned by the mine cleaner and populated by RPG-dropping and stationary-defense construction. It stores nested pairs `[mineObject, createdAt]`, not a flat object list.
- Dropped item, crater, ruins and building loops do not use registries; they use fixed map-center `nearestObjects` scans.
- The building restorer repairs all scanned `WarfareBBaseStructure` class objects. Future gameplay changes must decide whether this should include only player-built structures, stock Warfare base objects, destroyed AI-built structures or all matching ambient objects.
- Empty supply trucks have a special long lifetime: `Server_HandleEmptyVehicle.sqf:22-23` on docs-shaped refs and `:30-31` on stable/B74-shaped refs set a 24-hour delay for `V3S_Supply_TK_GUE_EP1`, Warfare supply trucks and OA supply truck classes. Long-lived abandoned logistics vehicles are therefore design/config behavior, not necessarily collector failure.
- These scripts exist in generated/terrain mission copies too. Patch Chernarus first, then run the LoadoutManager propagation workflow and inspect generated diffs.
- Filename note: the live empty-vehicle collector is `Server/FSM/emptyvehiclescollector.sqf`; there is no `server_empty_vehicles_collector.sqf` in the audited source tree.
- Modded mission drift note: old Lingor/Eden/Napf forks start the building restorer and mine cleaner, but their parameter files may lack the newer building/mine interval parameters. Treat Chernarus plus maintained Vanilla as authoritative until those forks are regenerated or explicitly maintained.

### Empty Supply Truck Branch Matrix

Use this matrix before diagnosing abandoned supply trucks as a broken cleanup loop. The collector drains the replicated queue quickly, but the spawned handler deliberately gives supply-truck classes a 24-hour empty-vehicle lifetime.

| Root / branch | Evidence | Outcome |
| --- | --- | --- |
| Docs/source Chernarus `HEAD@248baa289ca5` | Checked collector/handler paths are unchanged from `499c2543` / `b4e10b5f`: `Server/FSM/emptyvehiclescollector.sqf:9,15,17,19`; `Server/Functions/Server_HandleEmptyVehicle.sqf:22-23,33` | Queue drains through `emptyQueu`, spawns `WFBE_SE_FNC_HandleEmptyVehicle`, then supply trucks set `_delay = 86400` and are only deleted after the handler sees enough empty time. |
| Docs/source maintained Vanilla Takistan `HEAD@248baa289ca5` | Same unchanged-from-`499c2543` / `b4e10b5f` anchors: `emptyvehiclescollector.sqf:9,15,17,19`; `Server_HandleEmptyVehicle.sqf:22-23,33` | Same 24-hour supply-truck behavior in the maintained generated/copy target. |
| Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` | Chernarus and maintained Vanilla keep `emptyvehiclescollector.sqf:9,15,17,19`; `Server_HandleEmptyVehicle.sqf:30-31,41` after the nil/null guard and body/wreck cleanup split. Scoped `0139a3468609..origin/master` has no checked collector/handler path delta. | No current-stable/B74.1 rescue; the hard-coded 24-hour supply-truck delay remains in both maintained roots. |
| Current B74.2 `origin/claude/b74.2-aicom@21b62b04` | Chernarus and maintained Vanilla match current stable/B74.1 and the previous B74.2 snapshot for checked paths: `emptyvehiclescollector.sqf:9,15,17,19`; `Server_HandleEmptyVehicle.sqf:30-31,41`. Scoped `d472da6a..origin/claude/b74.2-aicom` and `origin/master..origin/claude/b74.2-aicom` are empty for the collector/handler paths. | B74.2 AI commander branch work still does not touch empty supply-truck cleanup. |
| Current B69 / adjacent B74 `origin/claude/b69@8d465fce` / `origin/claude/b74-aicom-spend@b23f557f` | Chernarus and maintained Vanilla match current stable/B74-shaped line drift: `emptyvehiclescollector.sqf:9,15,17,19`; `Server_HandleEmptyVehicle.sqf:30-31,41`. Checked delta `origin/claude/b69..origin/claude/b74-aicom-spend` is empty for maintained collector/handler paths. | B69/B74 AI commander work does not rescue empty supply-truck cleanup. |
| Direct current Miksuu `master@b8389e748243` | Chernarus and maintained Vanilla keep the docs-shaped collector and handler anchors: `emptyvehiclescollector.sqf:9,15,17,19`; `Server_HandleEmptyVehicle.sqf:22-23,33`. | No upstream rescue; this behavior is inherited, not a docs-branch-only change. |
| `origin/perf/quick-wins@0076040f` | Chernarus and maintained Vanilla keep the same docs-shaped collector and handler anchors. | The perf branch does not change supply-truck empty cleanup. |
| Release refs | `git ls-remote --heads origin release/* feat/*cleanup* feat/*supply* feature/*cleanup* feature/*supply* *cleanup* *supply*` returned no current release or cleanup/supply rescue head on 2026-06-24. Historical `a96fdda2` is available as local source evidence and both maintained roots keep `emptyvehiclescollector.sqf:9,15,17,19` and `Server_HandleEmptyVehicle.sqf:22-23,33`. | Historical `a96fdda2` also keeps the 24-hour policy, but do not call release status current without restoring or rechecking a live release ref. |

Future code-owner decision: either keep this as intentional logistics persistence and label it in operator docs, or replace `_delay = 86400` with a shorter/parameterized supply-truck timeout in source Chernarus and maintained Vanilla. Smoke must cover ordinary empty vehicles, ambulance/repair double-timeout vehicles, supply trucks during supply-mission/logistics use, and long-match object-count behavior.

## Patch-Ready Findings

| Finding | Evidence | Patch shape |
| --- | --- | --- |
| Empty supply trucks bypass normal timeout | [Empty Supply Truck Branch Matrix](#empty-supply-truck-branch-matrix) owns the refreshed docs/current-stable/B74.1/current-B74.2/B69/B74/Miksuu/perf proof: checked maintained roots still drain `emptyVehicles` through the collector and set supply-truck `_delay = 86400`; scoped deltas `b4e10b5f..HEAD`, `499c2543..HEAD`, `0139a3468609..origin/master`, `d472da6a..origin/claude/b74.2-aicom`, `origin/master..origin/claude/b74.2-aicom` and `origin/claude/b69..origin/claude/b74-aicom-spend` are empty for these paths; no live `release/*` or cleanup/supply rescue head was found on 2026-06-24, and verified `a96fdda2` remains historical-only release evidence. | Decide intentional logistics persistence versus shorter/parameterized cleanup; if changing, patch source Chernarus plus maintained Vanilla and smoke ordinary empty vehicles, double-timeout medical/repair vehicles and supply mission/logistics flows. |
| Mine cleaner pair removal likely wrong | Minefields push `[mine, time]` pairs; `mines_cleaner.sqf:17` uses `mines = mines - _x`. | Remove the tracked pair with `mines = mines - [_x]` or rewrite to filter live pairs. Smoke mine cleanup and verify no stale pairs persist. |
| Garbage flags are inconsistent | `server_collector_garbage.sqf:17` skips `wfbe_trashable`; `RequestOnUnitKilled.sqf:51-54` sets `wfbe_trashed`. | Align the flag contract: collector should also skip `wfbe_trashed`, or kill paths should set the collector's skip flag before spawning trash. |
| Local marker delete helper deletes globally | `Client_Delete_Marker.sqf:5` documents local marker creation; `:24` comments `deleteMarkerLocal`; `:25` uses `deleteMarker`. | Restore local deletion for side-local markers or rename/split helper behavior. Smoke side-specific marker removal. |
| HQ wreck marker can stale after object loss | `updateclient.sqf:52` only updates dead HQ marker when the wreck object exists; `Common_UpdateMarker.sqf:25` exits on null object. | Delete the marker when a tracked HQ wreck becomes null, or keep a side-owned registry that can explicitly clear stale marker names. |
| HQ marker state is west/east only | `Server_OnHQKilled.sqf:97`, `Server_MHQRepair.sqf:60`, `updateclient.sqf:42-100`. | Do not enable resistance HQ recovery without adding a resistance marker state machine and smoke. |
| Global marker names with side-local styling need proof | `Common_CreateMarker.sqf:53,59,82-83` creates global names then broadcasts side-local details. | Add an MP smoke case before changing marker visibility, deletion or JIP replay. |
| Dropped item cleaner broad scan | **RESOLVED (B40, current master f8a76de3):** the cleaner now runs a single 20 km `weaponholder` `nearestObjects` scan (`droppeditems_cleaner.sqf:62`); the two redundant `Mine`/`MineE` scans were removed (`:7-15`) and mines are handled by `mines_cleaner.sqf`. | One full-island scan remains. If RPT rows still show this cleaner as costly, narrow the scan center/radius without losing the weaponholder metric. Per-cycle deletion is already capped (`:30,67`). |
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
- For cleaner/restorer tuning, capture at least one server RPT sample for the relevant PerformanceAudit label before and after the change. Compare active time and `cycleMs`; do not optimize from scan width alone.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Performance: [Performance opportunity sweep](Performance-Opportunity-Sweep)
