# Server-Init Deadspawn Enclosure and Airfield Probe

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Two custom claude-gaming server-only one-shots run back-to-back near the end of server init: `Init_DeadspawnWall.sqf` and `Init_AirfieldProbe.sqf`. Both are fired once from `Server/Init/Init_Server.sqf` immediately after `serverInitFull = true` (`Server/Init/Init_Server.sqf:649`): the deadspawn wall at `Server/Init/Init_Server.sqf:657` and the airfield probe at `:664`. The first is a *physical protection* pass that rings the three per-side temporary-respawn markers with an indestructible H-barrier wall so an enemy-side AI bot cannot shoot a human parked on an adjacent side's holding marker during join. The second is a *diagnostic-only* probe that spawns nothing and instead logs a 5x5 grid of candidate airfield-camp positions to the RPT so blind coordinate guesses can be refuted with real `surfaceIsWater`/`nearRoads` data.

This page is distinct from [Server-Init-Bind-Cleanup](Server-Init-Bind-Cleanup), which covers duplicate compile/bind hygiene in `Init_Server.sqf` and touches neither of these scripts.

## Boot Invocation (Init_Server.sqf)

| Script | Call site | Form | Gate | Side-effect class |
| --- | --- | --- | --- | --- |
| `Server/Init/Init_DeadspawnWall.sqf` | `Server/Init/Init_Server.sqf:657` | `[] execVM "..."` | `if (!isServer) exitWith {}` (`Init_DeadspawnWall.sqf:41`) | Spawns persistent global objects (H-barriers) |
| `Server/Init/Init_AirfieldProbe.sqf` | `Server/Init/Init_Server.sqf:664` | `[] execVM "..."` | `if (!isServer) exitWith {}` (`Init_AirfieldProbe.sqf:25`) plus `wfbe_airfield_probe_done` one-shot guard (`:29-30`) | None — diagnostic `diag_log` only |

Both are placed after the world/logic init completes (`serverInitFull = true` at `Init_Server.sqf:649`) and before the town/economy server FSMs are spawned (`server_town.sqf` at `:667`).

## Init_DeadspawnWall: the problem

The three per-side holding markers — `WestTempRespawnMarker`, `EastTempRespawnMarker`, `GuerTempRespawnMarker` (`Init_DeadspawnWall.sqf:58`) — sit only 64–128m apart on a bare NE-Chernarus mountaintop (all three are static in `mission.sqm`; a `TempRespawnMarker` grep returns 3 entries). AI-slot bots respawn **exactly** onto their own side's marker: `Server/AI/AI_AdvancedRespawn.sqf:29` does `_respawnedUnit setPos getMarkerPos Format["%1TempRespawnMarker",_sideText]`. Because the markers are so close, an enemy-side bot has clear line-of-fire onto a HUMAN parked on an adjacent side's marker during join (the "AI killed <player> in the deadspawn" / Smarty kill). The header records the worst sightlines as GUER↔EAST ~44.5m and GUER↔WEST ~52m (`Init_DeadspawnWall.sqf:5-12`).

The fix is purely additive: it rings each marker with a closed wall and touches no protected file. It deliberately does not trap players, because the joiner is teleported to base by the client-side join handshake and never walks out of the ring, and a 120s client watchdog re-enables damage even if the move stalls (`Client/Init/Init_Client.sqf:21-26`, the `WFBE_Client_DeadspawnEscaped` / 120s timeout block). It never calls `setCaptive` or `disableAI`, keeping the standing hard guardrail intact (`Init_DeadspawnWall.sqf:14-23`).

## Init_DeadspawnWall: ring geometry

| Tunable | Value | Source | Meaning |
| --- | --- | --- | --- |
| `_wallCls` | `"Land_HBarrier_large"` | `Init_DeadspawnWall.sqf:47` | Tall LoS/line-of-fire blocker, confirmed-present class on this CO+EP1 box (reused from `Server/Init/Init_Defenses.sqf` wall templates) |
| `_radius` | `12` (m) | `:52` | Half-width of the ring → ~24m box; nearest neighbour marker is 64.5m so rings never overlap |
| `_segLen` | `5` (m) | `:56` | Approx footprint of one H-barrier section; drives segment count |
| `_perim` | `2 * 3.14159 * _radius` | `:78` | Ring circumference |
| `_count` | `ceil (_perim / _segLen)`, floored to min 8 | `:79-80` | Number of barrier segments; min-8 floor guarantees even a tiny ring is sealed |
| `_step` | `360 / _count` | `:81` | Angular spacing between segments |

For `_radius = 12`, `_perim ≈ 75.4m` and `_count = ceil(75.4/5) = 16` segments per marker (above the 8 floor), so a full run spawns ~48 barriers across the three markers.

## Init_DeadspawnWall: per-marker build loop

The script `forEach`-iterates the three markers (`:62-116`):

1. **Resolve centre.** `_c = getMarkerPos _mk` (`:64`). `getMarkerPos` returns `[0,0,0]` for an unknown name, so if both X and Y are 0 (`:70`) it logs a `WARNING` via `WFBE_CO_FNC_LogContent` and skips **only this marker** using a guarded `else` block rather than `exitWith` — `exitWith` would abort the whole `forEach` and skip the remaining sides (`:66-72`).
2. **Walk the circle.** For each segment `_i` from 0 to `_count-1` (`:84`): bearing `_ang = _i * _step` (`:85`), point on the ring at `_px = (_c#0) + _radius * sin _ang`, `_py = (_c#1) + _radius * cos _ang` (`:88-89`).
3. **Spawn the barrier.** `_prop = createVehicle [_wallCls, _pos, [], 0, "NONE"]` (`:93`) — `createVehicle` (GLOBAL) is used deliberately so the wall is server-authoritative and AI LoS/collision sees it on a dedicated server, per the standing rule against `createVehicleLocal` here (`:28-30`).
4. **Graceful class-miss handling.** If `isNull _prop` (`:94`), log one `WARNING` and keep going — modelled on `Server/Functions/Server_SpawnStructureDressing.sqf:48-51` (`:36-38`, verified: same `isNull`/`WARNING` pattern).
5. **Orient and pin.** `setDir (_ang + 90)` orients the long face TANGENT to the ring so consecutive barriers overlap into a continuous wall instead of radial spokes (`:98-100`); `setPosATL [_px,_py,0]` pins each barrier to the marker's own terrain elevation (the three markers differ by up to ~12m, so no height is hardcoded — `:34-35`, `:101-102`); `setVectorUp [0,0,1]` (`:103`).
6. **Make it cheap and permanent.** `enableSimulation false` (no physics cost) and `allowDamage false` (bots can't shoot the wall down) — `:104-106`.

Each surviving prop is appended to `_allProps` (`:107`), and a per-marker `INITIALIZATION` line reports the marker, position, segment count, and radius (`:112`).

## Init_DeadspawnWall: handle storage

After the loop, the prop list is stored **non-broadcast** for debugging / potential teardown: `missionNamespace setVariable ["WFBE_DEADSPAWN_WALL_PROPS", _allProps]` (`:119`) — the 2-argument `setVariable` form (no `true` publish flag), so it stays server-local. A closing `INITIALIZATION` line reports the total barrier count across the side markers (`:121`). The variable is set in exactly one place and read nowhere else in the mission (verified).

## Init_AirfieldProbe: diagnostic-only grid scan

`Init_AirfieldProbe.sqf` changes NO coordinates and spawns NO objects (`:1-4`). Its purpose is to settle where the airfield capture camps should be placed: the airfield camps (`mission.sqm` LocationLogicCamp id=308 NWAF / id=310 Balota) sit ~300m south of the real airfields, and blind coordinate guesses were refuted, so instead of guessing it probes (`:6-8`).

| Aspect | Detail | Source |
| --- | --- | --- |
| Side gate | `if (!isServer) exitWith {}` | `Init_AirfieldProbe.sqf:25` |
| Async body | `[] spawn { ... }` | `:27` |
| One-shot guard | `if (!isNil "wfbe_airfield_probe_done") exitWith {}` then `wfbe_airfield_probe_done = true` | `:29-30` |
| Settle delay | `uiSleep 20` (so world/roads are loaded before sampling) | `:32` |
| Offsets per axis | `_offsets = [-120, -40, 0, 40, 120]` (5 samples → 5x5 = 25 candidates/field) | `:34-36` |
| Airport anchors | `["Balota", 4550, 2280]`, `["NWAF", 4479.3252, 10618.404]` (from `mission.sqm` LocationLogicAirport, Balota id=7 / NWAF id=8) | `:38-42` |

For every candidate it builds `_pos = [_ax + _px, _ay + _py, 0]` (`:57`) and samples two on-land validity signals:
- `_water = surfaceIsWater _pos` (`:59`) — true means in the sea, reject.
- `_roads = count (_pos nearRoads 8)` (`:61`) — a non-empty list means on/at a road, reject for an apron.

It then emits one greppable pipe line per candidate via `diag_log` (`:63-70`):

```
AIRFIELD_PROBE|v1|field:<NWAF|Balota>|x:..|y:..|water:<bool>|roads:<count>
```

The run is bracketed by `AIRFIELD_PROBE|v1|begin|grid:5x5|offsets:-120,-40,0,40,120` (`:44`) and `AIRFIELD_PROBE|v1|end` (`:75`), so an operator can isolate the whole block in the RPT and pick a verified on-land, off-road apron. The nested `forEach`/`forEach`/`forEach` structure (fields → X offsets → Y offsets) reuses the `_x` iterator name at each level (`:48`, `:53`, `:55`), which is valid A2-OA scoping.

## A2-OA command discipline

Both scripts are written to A2-OA-only command rules. The probe header explicitly notes it uses `surfaceIsWater`, `nearRoads`, `getPosASL`/`getPosATL` and NO `isOnRoad` / A3 commands (`Init_AirfieldProbe.sqf:22`). The wall uses `createVehicle` (not `createVehicleLocal`), `setDir`, `setPosATL`, `setVectorUp`, `enableSimulation`, `allowDamage`, capitalized `Private`/`Format`, and `Call WFBE_CO_FNC_LogContent` — all valid A2-OA forms. Neither script uses `remoteExec`, `BIS_fnc_MP`, `isEqualTo`, or any A3-only construct.

## Continue Reading

- [Server-Init-Bind-Cleanup](Server-Init-Bind-Cleanup)
- [Mission-Entrypoints-And-Lifecycle](Mission-Entrypoints-And-Lifecycle)
- [Lifecycle-Wait-Chain](Lifecycle-Wait-Chain)
- [Respawn-And-Death-Lifecycle-Atlas](Respawn-And-Death-Lifecycle-Atlas)
- [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas)
