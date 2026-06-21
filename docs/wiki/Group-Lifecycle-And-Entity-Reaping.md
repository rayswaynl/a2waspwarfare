# Group Lifecycle And Entity Reaping

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents how WASP Warfare creates AI groups under a hard engine cap and how it reaps dead entities (corpses, wrecks) and the now-empty groups they leave behind. Three pieces work together: `Common_CreateGroup` is the central `createGroup` wrapper that runs an emergency garbage-collection pass when a side nears the engine's 144-group ceiling; `Common_TrashObject` is the per-entity deferred-deletion routine that strips event handlers, waits a kind-dependent timeout, deletes the object, and reaps its empty group; and `server_collector_garbage.sqf` is the server FSM loop that sweeps `allDead` every 5 seconds and spawns a `TrashObject` thread per untracked corpse/wreck. A separate kill hook (`RequestOnUnitKilled.sqf`) schedules trash for player- and server-killed entities directly. The `wfbe_persistent` group flag protects commander and headless-bridge groups from ever being reaped.

## Group creation: Common_CreateGroup

`createGroup` in Arma 2 OA fails (returns `grpNull`) once a side already owns 144 groups. WASP wraps every managed `createGroup` call in this function so the cap is policed and each group is source-attributed.

Compiled at `Common/Init/Init_Common.sqf:112` as `WFBE_CO_FNC_CreateGroup`, registered immediately after `WFBE_CO_FNC_AICOMLog` (`Init_Common.sqf:109`) so the wrapper can call the logger. The inline comment at `Init_Common.sqf:111` labels it "LEVER 2".

| Aspect | Detail | Source |
|---|---|---|
| Parameters | `[_side, _sourceTag]` where `_sourceTag` is a string identifying the caller | `Common_CreateGroup.sqf:3,17-18` |
| Returns | the new group, or `grpNull` on failure | `Common_CreateGroup.sqf:4,64` |
| Group count | scans all of `allGroups`, increments `_cnt` for each group whose `side _x == _side` | `Common_CreateGroup.sqf:21-24` |
| GC trigger | when `_cnt >= 140` (a margin below the 144 engine ceiling) | `Common_CreateGroup.sqf:27` |
| Source tag | on success, `_grp setVariable ["wfbe_group_src", _sourceTag, true]` (public) | `Common_CreateGroup.sqf:61` |

### The emergency GC pass

When the side is at or above 140 groups, the function runs an in-line sweep (`Common_CreateGroup.sqf:27-53`) before attempting the new `createGroup`:

| Step | Behavior | Source |
|---|---|---|
| Two-pass collect | candidates are gathered into `_gcCands` first, then deleted in a second `forEach` — deliberately, because mutating `allGroups` while iterating it is undefined in A2 OA 1.64 | `Common_CreateGroup.sqf:29-46` |
| Persistence guard | a group is only a candidate if `wfbe_persistent` is falsy; `isNil` is treated as `false` | `Common_CreateGroup.sqf:35-36,38` |
| Emptiness test | uses `count (units _x) == 0`, NOT `{alive _x}` — `deleteGroup` no-ops on a group still holding even dead units, so true emptiness is required; an `{alive}` test would flag unreapable corpse-only groups and inflate the reap count | `Common_CreateGroup.sqf:37-38` |
| Deletion | each candidate gets `deleteGroup _x`; `_gcDone` counts successes | `Common_CreateGroup.sqf:43-46` |
| Recount + log | recounts the side after the sweep, then emits one `AICOMLog` `"WARNING"` reporting side, post-sweep count, source tag, and reaped count | `Common_CreateGroup.sqf:49-52` |

### Failure path

After the optional GC, the function calls `createGroup _side` (`Common_CreateGroup.sqf:56`). If the engine still returns `grpNull` (cap not relieved), it logs a second `AICOMLog` `"WARNING"` naming the side, source tag, and group count, and returns `grpNull` to the caller (`Common_CreateGroup.sqf:58-59,64`). Callers are expected to null-check the result.

## Entity reaping: Common_TrashObject

Compiled at `Common/Init/Init_Common.sqf:88` as the global `TrashObject` (note: plain `preprocessFile`, not `preprocessFileLineNumbers`). It is always invoked with `spawn`/`Spawn` because it sleeps; the entire body runs after a delay (`Common_TrashObject.sqf`).

| Aspect | Detail | Source |
|---|---|---|
| Parameter | a single object (`_this`), not an array | `Common_TrashObject.sqf:4,9` |
| Null guard | whole body is wrapped in `if !(isNull _object)` | `Common_TrashObject.sqf:11` |
| Kind branch | `_isMan = _object isKindOf "Man"` selects the body-vs-wreck path | `Common_TrashObject.sqf:12` |
| EH removal | always strips `"killed"`; strips `"hit"` only for non-man objects | `Common_TrashObject.sqf:15-16` |
| Group capture | for men, `_group = group _object` (else `grpNull`) | `Common_TrashObject.sqf:14` |
| Delay | `sleep _delay` then `deleteVehicle _object` | `Common_TrashObject.sqf:23,27` |
| Log | emits an `"INFORMATION"` `LogContent` line naming the object and elapsed seconds just before deletion | `Common_TrashObject.sqf:25` |

### The B35 timeout split

The delay (`Common_TrashObject.sqf:21`) is chosen by entity kind:

- **Man bodies** → `WFBE_C_UNITS_BODIES_TIMEOUT`, a fixed 60 s constant set unconditionally at `Common/Init/Init_CommonConstants.sqf:523`.
- **Vehicle wrecks** → `WFBE_C_UNITS_CLEAN_TIMEOUT`, the lobby-tunable value (runtime fallback 60 s at `Init_CommonConstants.sqf:521`; the lobby parameter `WFBE_C_UNITS_CLEAN_TIMEOUT` titled "Bodies Timeout" defaults to 120 s at `Rsc/Parameters.hpp:255-260`).

The header comment (`Common_TrashObject.sqf:18-20`) records the B35 fix (claude-gaming 2026-06-15): the prior code read `BODIES_TIMEOUT` for both kinds and doubled it for vehicles, so the lobby "Bodies Timeout" slider was silently ignored and wrecks were pinned at 120 s. The split restored the slider as the true wreck timeout; the Parameters default was lowered from 240 to 120 to keep prior effective behavior (`Rsc/Parameters.hpp:259`).

### Empty-group reaping tail

After deleting a man's body, the function reaps the now-empty group (`Common_TrashObject.sqf:29-33`): only if `_group` is non-null, only if `_group getVariable "wfbe_persistent"` is `isNil` (i.e. the group is not flagged persistent), and only if `count (units _group) <= 0`. This mirrors the persistence/emptiness contract enforced in `Common_CreateGroup`'s GC pass — commander and headless-bridge groups carry `wfbe_persistent` and are never deleted by either path. `GetClosestLocation` is called at `Common_TrashObject.sqf:10` (compiled at `Init_Common.sqf:25`) but the resulting `_town` is not used downstream in this branch.

## Lifecycle wiring: the server garbage-collector FSM

`server_collector_garbage.sqf` is launched once via `ExecVM` at `Server/Init/Init_Server.sqf:694` (logged "Garbage Collector is defined." at `Init_Server.sqf:695`). It is the steady-state reaper for dead entities the kill hook did not already schedule.

| Aspect | Detail | Source |
|---|---|---|
| Loop guard | `while {!WFBE_GameOver}` | `server_collector_garbage.sqf:4` |
| HQ exemptions | resolves `_whq`/`_ehq` via `GetSideHQ` and skips them | `server_collector_garbage.sqf:10-11,17` |
| Tracking array | `gc_collector` (lazily initialized to `[]`), pruned of `objNull` each pass | `server_collector_garbage.sqf:13,15` |
| Selection | for each `_x in allDead`: skip if it has the `wfbe_trashable` variable, is already in `gc_collector`, or is an HQ | `server_collector_garbage.sqf:16-17` |
| Action | `_x spawn TrashObject`, then add `_x` to `gc_collector` so it is not double-spawned | `server_collector_garbage.sqf:20-21` |
| Sweep cadence | `sleep 5` — PERF1 lowered this from a 2 Hz sweep to once per 5 s, cutting the `allDead` scan and array-diff cost ~10x | `server_collector_garbage.sqf:32-34` |
| Telemetry | records `"server_garbage_collector"` timing with `dead/tracked/spawned` counts via `PerformanceAudit_Record` when enabled | `server_collector_garbage.sqf:26-28` |

## Trash scheduling on kill: RequestOnUnitKilled tail

`RequestOnUnitKilled.sqf:175-180` schedules trash at the moment of death so common cases do not wait for the 5 s FSM sweep. It branches on the A2-vanilla flag:

| Branch | Behavior | Source |
|---|---|---|
| Vanilla, non-server or local player | append `_killed` to the client-broadcast `WF_Logic "trash"` array (`setVariable ... true`) | `RequestOnUnitKilled.sqf:176` |
| Vanilla, server | set `wfbe_trashed = true` and `_killed Spawn TrashObject` directly | `RequestOnUnitKilled.sqf:176` |
| OA, server | set `wfbe_trashed` and `Spawn TrashObject` | `RequestOnUnitKilled.sqf:178` |
| OA, killed player | set `wfbe_trashed` and `Spawn TrashObject` | `RequestOnUnitKilled.sqf:179` |

The `WF_Logic "trash"` array is initialized to `[]` (vanilla only) at `Server/Init/Init_Server.sqf:679`. Note that in this branch the array is written by clients but has no SQF reader — the server reaps dead entities through `allDead` in the GC FSM, so the client-pushed `trash` list is effectively vestigial.

The kill hook sets `wfbe_trashed = true` on each entity it schedules (`RequestOnUnitKilled.sqf:176,178,179`), but this flag does **not** stop the GC FSM from re-scheduling that corpse. The GC's selection test gates on `wfbe_trashable` — a *different* variable — not on `wfbe_trashed` (`server_collector_garbage.sqf:17`). Across the whole kill→GC pipeline `wfbe_trashed` is effectively write-only: its single skip-gate read is the self-respawn guard inside the UAV teardown (`Support_UAV.sqf:18-20`, `isNil {_x getVariable "wfbe_trashed"}`); the GC FSM and `RequestOnUnitKilled` never read it. The only thing that actually prevents the GC from spawning a second `TrashObject` for a kill-hook-handled corpse is the `gc_collector` membership test documented above (`server_collector_garbage.sqf:17,21`), not `wfbe_trashed`.

The `wfbe_trashable` variable the GC *does* gate on is a separate HQ-protection flag: it is only ever set (to `false`) on HQ/MHQ objects (`Construction_HQSite.sqf:82`, `Server_OnHQKilled.sqf:30`, `Server_MHQRepair.sqf:39`, `Server/Init/Init_Server.sqf:393`), exempting those objects from garbage collection. It is never set on ordinary corpses or wrecks, so the `isNil` test at `server_collector_garbage.sqf:17` admits them for reaping.

## Related collector: empty vehicles

A sibling FSM, `emptyvehiclescollector.sqf` (launched at `Init_Server.sqf:696`), reaps abandoned empty vehicles rather than dead ones. It drains the `WF_Logic "emptyVehicles"` array, dedupes through `emptyQueu`, and spawns `WFBE_SE_FNC_HandleEmptyVehicle` per vehicle on a 0.5 s loop (`emptyvehiclescollector.sqf:4-21`). Empty-vehicle lifespan is governed by the separate `WFBE_C_UNITS_EMPTY_TIMEOUT` constant (1800 s runtime default at `Init_CommonConstants.sqf:522`; lobby default 300 s at `Rsc/Parameters.hpp:261-266`), distinct from the body/wreck timeouts used by `TrashObject`.

## Continue Reading

- [Kill And Score Pipeline](Kill-And-Score-Pipeline) — the OnUnitKilled flow that calls TrashObject as its final step
- [Spawn Primitive Function Reference](Spawn-Primitive-Function-Reference) — CreateUnit / CreateVehicle / CreateTeam, the creation side of the lifecycle
- [Town AI Vehicle Despawn Safety](Town-AI-Vehicle-Despawn-Safety) — despawn-safety playbook for AI-occupied town vehicles
- [Respawn And Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas) — player death/respawn handling around the same kill events
- [Server Gameplay Runtime Atlas](Server-Gameplay-Runtime-Atlas) — the server FSM set that the garbage collector belongs to
