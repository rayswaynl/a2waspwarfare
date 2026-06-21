# Marker Loop Engine and Registries (the consolidated client marker loop)
> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the PERF1 consolidated client marker engine: the single `WFBE_CL_MarkerLoop` (`Common/Common_MarkerLoop.sqf`) plus its two registrars. Before PERF1 the marker subsystem ran **N scheduled VMs** — one per tracked unit (150-400 concurrent per client at peak) and one per tracked enemy aircraft (`Common/Common_MarkerLoop.sqf:1-3`, `Common/Common_MarkerUpdate.sqf:1-3`, `Common/Common_AARadarMarkerUpdate.sqf:1-2`). The refactor folded all periodic work into one loop; the old files are now **registrars** that create the marker once, append a registry entry, and start the loop if it is not already running.

Everything here is client-side and local: `createMarkerLocal`, `setMarker*Local`, `deleteMarkerLocal`. There is no global marker channel — each client maintains its own markers for its own side's tracked units. `createMarkerLocal` does not replicate; `setMarker*Local` verbs do not replicate. This page describes current master `0139a346`; the older [cleanup atlas](Marker-Cleanup-Restoration-Systems-Atlas) predates this refactor.

## Components

| Component | Definition / body | Locality | Role |
| --- | --- | --- | --- |
| `WFBE_CL_MarkerLoop` | compiled `Common/Init/Init_Common.sqf:73`; body `Common/Common_MarkerLoop.sqf` | local (one scheduled script per client) | Consolidated refresh loop; walks `WFBE_CL_UnitMarkerRegistry` + `WFBE_CL_AARMarkerRegistry` on a fixed `sleep 0.2` tick (`Common/Common_MarkerLoop.sqf:34-36`). |
| `MarkerUpdate` (unit registrar) | compiled `Common/Init/Init_Common.sqf:72`; body `Common/Common_MarkerUpdate.sqf` | local | Creates the marker, appends an 18-field entry to `WFBE_CL_UnitMarkerRegistry` (`Common/Common_MarkerUpdate.sqf:67-68`), and lazily starts the loop. |
| `Common_AARadarMarkerUpdate.sqf` (AAR registrar) | body `Common/Common_AARadarMarkerUpdate.sqf` | local | Creates a hidden red-arrow marker, appends a 12-field entry to `WFBE_CL_AARMarkerRegistry` (`Common/Common_AARadarMarkerUpdate.sqf:45-46`), and lazily starts the loop. |
| `Common_MarkerRebuildRequest.sqf` (action handler) | body `Common/Common_MarkerRebuildRequest.sqf` (3 lines) | local | Sets `WFBE_CL_MarkerRebuildRequested = true` and hints (`Common/Common_MarkerRebuildRequest.sqf:2-3`); the loop consumes it next tick. |

The loop is started lazily by whichever registrar fires first, guarded by `isNil` so there is **exactly one loop per client** (`Common/Common_MarkerUpdate.sqf:72-73`, `Common/Common_AARadarMarkerUpdate.sqf:50-51`). The `WFBE_CL_MarkerLoop` handle compiled at `Init_Common.sqf:73` is the body; the running script handle is `WFBE_CL_MarkerLoopHandle`.

## Registry data shapes

Both registry arrays and the ledger are initialised nil-safe at the top of the loop (`Common/Common_MarkerLoop.sqf:14-16`) and again by each registrar.

### Unit registry entry (18 fields)

Built at `Common/Common_MarkerUpdate.sqf:67`; the field comment is at `Common/Common_MarkerUpdate.sqf:63-64`.

| Slot | Field | Notes |
| --- | --- | --- |
| 0 | `tracked` | the tracked object |
| 1 | `name` | marker name (`unitMarker*`) |
| 2 | `baseType` | base marker type |
| 3 | `baseSize` | base marker size |
| 4 | `baseText` | base marker text |
| 5 | `refresh` | base refresh seconds |
| 6 | `trackDeath` | bool: show a death marker before deleting |
| 7 | `deathType` | death marker type |
| 8 | `deathColor` | death marker color |
| 9 | `deathSize` | death marker size (`[1,1]` default, `Common/Common_MarkerUpdate.sqf:22-23`) |
| 10 | `kind` | `"man"`/`"car"`/`"tank"`/`"air"`/`"ship"`/`"object"` (`Common/Common_MarkerUpdate.sqf:30-35`) |
| 11 | `isHQ` | bool: HQ fast-path flag (`Common/Common_MarkerUpdate.sqf:37`) |
| 12 | `lastText` | last-written text cache |
| 13 | `lastType` | last-written type cache |
| 14 | `lastSize` | last-written size cache |
| 15 | `nextDue` | per-entry due time (gates service) |
| 16 | `state` | `1` = death-marker window active |
| 17 | `deadUntil` | death-window expiry time |
| 18 | `lastPos` | position-delta cache — appended lazily by the loop on first service (`Common/Common_MarkerLoop.sqf:230-234`) |

### AAR registry entry (12 fields)

Built at `Common/Common_AARadarMarkerUpdate.sqf:45`; the field comment is at `Common/Common_AARadarMarkerUpdate.sqf:42`.

| Slot | Field | Notes |
| --- | --- | --- |
| 0 | `object` | tracked enemy aircraft |
| 1 | `name` | marker name (`unitMarker*`) |
| 2 | `sideID` | originating side id |
| 3 | `oppositeSide` | side whose AAR upgrade level drives refresh (`Common/Common_AARadarMarkerUpdate.sqf:33-39`) |
| 4 | `lastVisible` | bool: marker alpha currently shown |
| 5 | `lastText` | last-written text cache |
| 6 | `lastPos` | position-delta cache |
| 7 | `lastDir` | last-written direction cache |
| 8 | `forceRefresh` | bool: force next write |
| 9 | reserved | written `0`, never read |
| 10 | reserved | written `0`, never read |
| 11 | `nextDue` | per-entry due time |

### Ledger

`WFBE_CL_UnitMarkerLedger` is a flat list of every `unitMarker*` name this client created. Both registrars append to it (`Common/Common_MarkerUpdate.sqf:69`, `Common/Common_AARadarMarkerUpdate.sqf:47`). It is the owner index used by the orphan sweep (below). `unitMarker` is a per-client name counter, init `0` at `Common/Init/Init_Common.sqf:177`, incremented at each creation site (`Common/Init/Init_Unit.sqf:157`, `Common/Common_AARadarMarkerUpdate.sqf:11`, `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:29`).

## The tick: phases in order

The loop is a `while {true}` with `sleep 0.2` at the top (`Common/Common_MarkerLoop.sqf:34-36`), so it ticks at a fixed **5 Hz**. Per-entry refresh is gated by `nextDue` against `time`, which preserves the original per-type cadences. The phases run in this order each tick:

| # | Phase | Lines | Behavior |
| --- | --- | --- | --- |
| 1 | Map-open dirty pass | `:48-59` | Tracks `_mapWasClosed`; on a closed→open `visibleMap` transition, resets every unit entry's `nextDue` (slot 15) to `0` so all unit markers re-service immediately this tick. |
| 2 | Rebuild-action re-attach | `:64-67` | If `player != _actionPlayer && alive player` (respawn changed the player object), re-adds the "Rebuild Map Markers" action. |
| 3 | Auto-rebuild FPS lever | `:70-80` | If `diag_fps < _rebuildFps` sustained for >60s and past cooldown, sets `WFBE_CL_MarkerRebuildRequested = true` and logs `STATE-AUDIT: auto marker rebuild triggered`. Threshold `0` disables. |
| 4 | Rebuild execution | `:82-133` | When requested: sets a 300s cooldown (`:84`), then deletes+recreates every unit marker (`:87-113`) and AAR marker (`:114-131`) from registry state at live positions; resyncs slot-18 `lastPos` (`:100`); tombstones null-tracked entries (`:94`, `:120`); logs a done line (`:132`). |
| 5 | Unit-marker service loop | `:138-357` | `forEach WFBE_CL_UnitMarkerRegistry`; each entry is a `call` block with `exitWith` early-outs. |
| 6 | Unit registry compaction | `:361-367` | Only when `_tombstones > 64`: rebuilds the array dropping `0` tombstones. |
| 7 | AAR-marker service loop | `:370-499` | `forEach WFBE_CL_AARMarkerRegistry`. |
| 8 | Ledger sweep | `:504-522` | Every 60s (`_sweepNext`, init `:18`): any ledgered name not owned by a live registry entry is `deleteMarkerLocal`'d. |
| 9 | Publish + audit | `:525-531` | Writes `WFBE_CL_MarkerBudgetLastServiced` (read by `Client/Functions/Client_StateAudit.sqf:22`); emits a `markerloop_tick` PerformanceAudit record. |

## Unit-marker service path (`:138-357`)

Per entry, in order:

| Step | Lines | Behavior |
| --- | --- | --- |
| Dead-marker window expiry | `:146-156` | If slot 16 == 1 and `now >= deadUntil` (slot 17): delete marker, tombstone the slot. |
| Unit gone | `:161-192` | On `isNull` or `!alive`: removes the unit's blink and missile-masking `Fired` EHs (`:164-175`), then either shows the death marker for `WFBE_C_PLAYERS_MARKER_DEAD_DELAY` (`:180-182`) or deletes+tombstones (`:184-185`). |
| Due gate | `:194` | `if (_now < (_entry select 15)) exitWith {}`. |
| Map-closed suspend | `:199` | `if (!_mapVisible) exitWith {}` — visual work skipped; `nextDue` NOT advanced, so the entry re-services immediately on map open. |
| Budget gate | `:205-206` | `if (_budgetServiced >= _budgetMax) exitWith {}`; otherwise increments the shared budget counter. |
| Refresh tiering | `:213-221` | base = slot 5; non-player-group infantry forced to `max 3` (`:214`); non-HQ distance tier `>2000m → max 5s`, else `>500m → max 2s` (`:219`). Sets `nextDue = now + sleepRate` (`:221`). |
| Position-delta gate | `:230-240` | `setMarkerPosLocal` only when moved >3m vs slot-18 cache (first service writes unconditionally and seeds the cache). |
| HQ fast path | `:242-248` | `if (_entry select 11) exitWith` — position-only, no text/type/size work. (HQ entries register with refresh `0.2`, type `Headquarters` at `Common/Init/Init_Unit.sqf:186`.) |
| Crew/cargo text | `:250-324` | For player-group infantry sharing a vehicle, builds readable text like `2/4/3 | 5/6`; written only on change (`:321-324`). |
| Type / size | `:326-346` | Disabled vehicles (`!canMove`) draw `mil_objective` size `[0.5,0.5]` (`:328-330`); type and size written only on change (`:336-346`). |

## AAR-marker service path (`:370-499`) — enemy-aircraft tracking

The AAR markers are **filled red arrows**: `mil_arrow2`, `ColorRed`, size `[0.5,0.5]`, alpha `0` by default, created by the registrar (`Common/Common_AARadarMarkerUpdate.sqf:14-18`). The loop drives them as an anti-air-radar HUD for **enemy** aircraft, visible only while the map is open.

| Step | Lines | Behavior |
| --- | --- | --- |
| Aircraft gone | `:380-393` | On `isNull` or `!alive`: delete + tombstone + emit `aar_marker_end`. |
| Due gate | `:395` | `if (_now < (_aarEntry select 11)) exitWith {}`. |
| Budget gate | `:399-400` | Shared `_budgetServiced` / `_budgetMax` counter with the unit path. |
| Map closed | `:405-412` | Hide marker (alpha 0), set `forceRefresh`, retry `+2s`. |
| Not in radar range | `:414-421` | If `!antiAirRadarInRange` (set by `Client/FSM/updateavailableactions.fsm:190`): hide, retry `+5s`. |
| Below detection floor | `:424-431` | If `getPos select 2 <= _height` (floor `WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION`, read once at `:20`): hide, retry `+5s`. |
| Upgrade-tiered refresh | `:436-447` | One shared 5s-cached side→AAR-level lookup via `WFBE_CO_FNC_GetSideUpgrades` (index `WFBE_UP_AAR`, `:437-439`), keyed by `oppositeSide` so 3-way games do not cross-read (`:436`). Refresh: **AAR0 = 5s, AAR1 = 3s, AAR2 = 1s** (`:444-446`). |
| Text | `:449-473` | `speed` (AAR0) + `altitude` via `getPosATL` (AAR1, `:454`) + aircraft name via `WFBE_CL_FNC_ReturnAircraftNameFromItsType` (AAR2, `:459`); written only on change/forceRefresh (`:470-473`). |
| Position write | `:476-479` | `setMarkerPosLocal` only when moved >25m (or forceRefresh). |
| Direction write | `:481-488` | `setMarkerDirLocal` only when turned >7° (or forceRefresh); `forceRefresh` cleared at `:490`. |

## Refresh tiering summary

| Tracked kind | Effective cadence | Source |
| --- | --- | --- |
| HQ | 0.2s, position only | `Common/Init/Init_Unit.sqf:186`; `Common/Common_MarkerLoop.sqf:242` |
| Player-group infantry | base (1s typical) | `Common/Common_MarkerLoop.sqf:213-214` |
| Other infantry | `max 3s` | `Common/Common_MarkerLoop.sqf:214` |
| Distance >500m / >2000m (non-HQ) | `max 2s` / `max 5s` | `Common/Common_MarkerLoop.sqf:219` |
| AICOM leader markers | ~8s | `Client/FSM/updateaicommarkers.sqf:10` (reuses `MarkerUpdate`) |
| Patrol leader markers | 5s | `Client/FSM/updatepatrolmarkers.sqf:6` (reuses `MarkerUpdate`) |
| Paratrooper markers | 1s, trackDeath | `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:40` |
| AAR (enemy aircraft) | 5s / 3s / 1s by AAR upgrade | `Common/Common_MarkerLoop.sqf:444-446` |

## The budget gate

A PERF3 token bucket caps visual-refresh work per tick. `_budgetMax` is read at tick start (`Common/Common_MarkerLoop.sqf:42`), default `30` — about 150 marker services/sec at 5 Hz. The counter `_budgetServiced` is **shared** across the unit and AAR paths. When a path hits the cap it `exitWith`s **without advancing `nextDue`**, so the entry is simply re-tried next tick (rolling stagger, no permanent loss). Because AAR entries are serviced after all unit entries each tick, AAR markers can be starved relative to unit markers under budget pressure within a single tick — recovered on the following tick.

## FPS auto-rebuild and manual rebuild

Two paths set `WFBE_CL_MarkerRebuildRequested = true`, consumed at `Common/Common_MarkerLoop.sqf:82`:

- **Manual** — the "Rebuild Map Markers" `addAction` (registered `:27`, re-attached on respawn `:66`) runs `Common/Common_MarkerRebuildRequest.sqf`, which sets the flag and hints (`:2-3`). The hint always fires even if a rebuild is already pending — the loop deduplicates via the single boolean, so this is cosmetic only.
- **Automatic** — sustained low FPS: `diag_fps < WFBE_C_MARKER_REBUILD_FPS` for >60s and past the cooldown (`:76-79`).

On execution the loop sets a 300s cooldown (`:84`), then deletes and recreates every unit and AAR marker from registry state at live positions, resyncing the slot-18 position cache so a stale `lastPos` cannot suppress the next legitimate move-write (`:97-100`). The done-log reports `allMapMarkers` as a hardcoded `-1` with comment "Arma-3-only, N/A in A2 OA" (`:132`) — an intentional placeholder, not a live value.

## State hygiene: tombstones, compaction, ledger sweep

Removals tombstone the registry slot (set to `0`) rather than splicing the array, keeping the registrars' single-statement append race window negligible (`Common/Common_MarkerLoop.sqf:8-11`). Compaction rebuilds the array only when `_tombstones > 64` (`:361`). Independently, every 60s the ledger sweep walks `WFBE_CL_UnitMarkerLedger` and `deleteMarkerLocal`s any name no longer owned by a live registry entry (`:504-522`) — this heals any marker that would slip through the append race.

## Config variables

| Var | Default | Definition | Read at |
| --- | --- | --- | --- |
| `WFBE_C_MARKER_REBUILD_FPS` | 15 | `getVariable` default | `Common/Common_MarkerLoop.sqf:30` (used `:71`) |
| `WFBE_C_MARKER_BUDGET_PER_TICK` | 30 | `getVariable` default | `Common/Common_MarkerLoop.sqf:42` |
| `WFBE_C_PLAYERS_MARKER_DEAD_DELAY` | 60 | `Common/Init/Init_CommonConstants.sqf:425` | `Common/Common_MarkerLoop.sqf:180` |
| `WFBE_C_STRUCTURES_ANTIAIRRADAR` | 1 | `Common/Init/Init_CommonConstants.sqf:457` | gate at `Common/Init/Init_Unit.sqf:115` |
| `WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION` | 100 | `Common/Init/Init_CommonConstants.sqf:463` | `Common/Common_MarkerLoop.sqf:20` (altitude floor) |
| `WFBE_UP_AAR` | 20 | `Common/Init/Init_CommonConstants.sqf:57` | upgrade index `Common/Common_MarkerLoop.sqf:439` |

## Registration gates and locality

- The unit registrar waits `waitUntil {commonInitComplete}` (`Common/Common_MarkerUpdate.sqf:8`; flag set `Common/Init/Init_Common.sqf:419`) and bails unless the tracked unit's side equals `side group player` (`Common/Common_MarkerUpdate.sqf:25`) — a client only registers markers for its own side's units.
- The AAR registrar is reached only for **enemy** aircraft: the call at `Common/Init/Init_Unit.sqf:118` is gated on `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` and `sideJoined != _side` (`Common/Init/Init_Unit.sqf:115-116`).
- The loop attaches its action to the `player` object and runs per player client; the headless/server path never reaches the registrars' side gate for the local player.

Per-function signatures and per-family marker content are out of scope here — see the function reference and the content catalog below.

## Continue Reading

- [Marker Subsystem Function Reference](Marker-Subsystem-Function-Reference)
- [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog)
- [Client Marker FSM Updater Map](Client-Marker-FSM-Updater-Map)
- [Marker Cleanup Restoration Systems Atlas](Marker-Cleanup-Restoration-Systems-Atlas)
- [AI Headless And Performance](AI-Headless-And-Performance)
