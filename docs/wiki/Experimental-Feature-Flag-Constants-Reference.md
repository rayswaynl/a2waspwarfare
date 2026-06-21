# Experimental Feature-Flag Constants Reference (EXPERITAL block + QoL/announcer trio)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is the single index of the build's hardcoded experimental and QoL **master gates** — the `WFBE_C_*` switches that the lobby cannot set. They are assigned directly in `Common/Init/Init_CommonConstants.sqf` (most as plain `WFBE_C_X = …` lines; the experimental, overridable ones via `if (isNil "WFBE_C_X") then {WFBE_C_X = …}` so a server `init.sqf`/`description.ext` can pre-seed an override before this file runs). None of them appear in `Parameters.hpp`, so they are absent from the lobby-parameter index — see [Mission Start Parameters Index](Mission-Start-Parameters-Index), which catalogs the lobby params only and explicitly excludes these forced gates.

Three sub-blocks live just above the `EXPERITAL FEATURES` banner and share the same hardcoded-gate character: the **QoL trio**, the **restart/dashboard announcers**, and the **per-player leaderboard emitter**. They are included here because they are non-lobby toggles set the same way.

All line numbers are exact against `Common/Init/Init_CommonConstants.sqf` at master 0139a346.

## EXPERITAL features block (lines 575–608)

The block header is at `Common/Init/Init_CommonConstants.sqf:575`. Each row below is one toggle, its literal default, and what it gates. "Type" distinguishes a hard `=` assignment (not overridable) from an `isNil`-guarded one (override-friendly).

| Constant | Default | Type | Gates | path:line |
|---|---|---|---|---|
| `WFBE_C_STRUCTURES_COUNTERBATTERY` | `1` | hard `=` | Counter Battery Radar structure (mid-game; requires own AAR) | Init_CommonConstants.sqf:576 |
| `WFBE_C_ECONOMY_BANK` | `1` | hard `=` | Federal Reserve / Bank Rossii endgame objective building | Init_CommonConstants.sqf:577 |
| `WFBE_C_STRUCTURES_ARTILLERYRADAR` | `1` | hard `=` | Artillery Radar buildable structure (WDDM walled-gate walls, fort-only by design) | Init_CommonConstants.sqf:578 |
| `WFBE_C_STRUCTURES_RESERVE` | `1` | hard `=` | Reserve buildable structure (WDDM floodlit walled-yard walls) | Init_CommonConstants.sqf:579 |
| `WFBE_C_UNITS_REDEPLOYTRUCK` | `1` | hard `=` | Medic redeployment truck (forward spawn) | Init_CommonConstants.sqf:580 |
| `WFBE_C_SUPPORT_REARM_PROPORTIONAL` | `1` | hard `=` | Rearm price scales with ammo actually missing (artillery exempt) | Init_CommonConstants.sqf:581 |
| `WFBE_C_UNITS_BULLDOZER` | `1` | hard `=` | Engineer base-area tree clearing | Init_CommonConstants.sqf:582 |
| `WFBE_C_DEFENSE_BUDGET` | `1` | hard `=` | Per-base-area defense caps scaling with barracks level | Init_CommonConstants.sqf:583 |
| `WFBE_C_BASE_DEFENSE_STATICS_CAP` | `25` | hard `=` | Max player-placed static base defenses (MGs/AA/AAPOD) per base area (raised from 10) | Init_CommonConstants.sqf:584 |
| `WFBE_C_DEFENSE_THREAT_MIN` | `3` | hard `=` | Min enemy ground units (west/east, no Air/GUER) inside base range before the statics/mines threat gate fires | Init_CommonConstants.sqf:585 |
| `WFBE_C_WDDM_COMP_CAP` | `3` | hard `=` | Max WDDM commander compositions per base area (size-independent) | Init_CommonConstants.sqf:586 |
| `WFBE_C_FACTORY_QUEUE_LIMITS` | `1` | hard `=` | Per-factory production queue caps scaling with factory level | Init_CommonConstants.sqf:587 |
| `WFBE_C_STATLOG` | `1` | hard `=` | `[WASPSTAT]` structured telemetry RPT lines | Init_CommonConstants.sqf:588 |
| `WFBE_C_TOWNS_GUNNERS_ON_CAPTURE` | `true` | `isNil` | Immediately man static defenses at capture (all sides); `false` = reactive only | Init_CommonConstants.sqf:589 |
| `WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY` | `300` | hard `=` | Seconds before the new owner's static defenses + defense teams spawn after capture (fire-time ownership guard aborts if town flipped again) | Init_CommonConstants.sqf:593 |
| `WFBE_C_TOWNS_DEFENDER_LINGER` | `180` | hard `=` | Seconds the old owner's gunners keep fighting after capture before cleanup (fire-time guard aborts cleanup if town flipped back) | Init_CommonConstants.sqf:596 |
| `WFBE_C_EASA_CATEGORIES` | `1` | `isNil` | EASA loadout category tags `[AA]`/`[AG]`/`[MR]` prefixed on each row (display-only) | Init_CommonConstants.sqf:597 |
| `WFBE_C_AIRFIELDS` | `1` | `isNil` | Airfield capture points (NWAF/NEAF/Balota): repair-point + exclusive hangar on capture | Init_CommonConstants.sqf:598 |
| `WFBE_C_CAPTURE_UNLOCKS` | `1` | `isNil` | Holding trigger towns unlocks premium ACR units at own factories (Krasnostav→T72M4CZ lvl4 Heavy; NWAF→RM70_ACR lvl4 Light) | Init_CommonConstants.sqf:599 |
| `WFBE_C_PATROL_CONVOY_PAY` | `750` | `isNil` | Task 41: cash pool paid to the side each time a convoy patrol stops at a town (split equally among living players) | Init_CommonConstants.sqf:600 |
| `WFBE_C_SKIN_SELECTOR` | `0` | `isNil` | Command Deck: join-time infantry skin selector (1 enabled, 0 disabled) — **OFF by default** | Init_CommonConstants.sqf:601 |
| `WFBE_C_VEHICLE_MARKINGS` | `0` | `isNil` | Miksuu vehicle-visuals master gate: per-side recognition markings (`Common_AddVehicleMarking.sqf`) + side-gated body skins / WEST matte-black (`Common_AddVehicleTexture.sqf`) — **OFF by default** (attaches up to 3 local `#lightpoints` per vehicle; FPS-sensitive, flip to 1 only after an in-engine attach/FPS test) | Init_CommonConstants.sqf:602 |
| `WFBE_C_VEHICLE_TINTS` | `1` | `isNil` | Vehicle faction body TINTS (cheap one-shot `setObjectTexture` colour strings in `Common_AddVehicleTexture.sqf`); decoupled from `WFBE_C_VEHICLE_MARKINGS` so tints can be live while the costly markings stay off | Init_CommonConstants.sqf:603 |
| `WFBE_C_FSMOKE_ENABLED` | `1` | `isNil` | Triggered faction-smoke master gate (1 enabled, 0 disabled) | Init_CommonConstants.sqf:605 |
| `WFBE_C_FSMOKE_MAX` | `8` | `isNil` | Global hard cap on concurrent faction-smoke shells (prune dead, then refuse new at cap) | Init_CommonConstants.sqf:606 |
| `WFBE_C_FSMOKE_TTL` | `20` | `isNil` | Seconds before each spawned smoke shell is `deleteVehicle`'d + de-listed | Init_CommonConstants.sqf:607 |
| `WFBE_C_FSMOKE_COOLDOWN` | `150` | `isNil` | Per-100m-grid-key cooldown (s) so one spot can't re-trigger smoke spam | Init_CommonConstants.sqf:608 |

Notes on the smoke set: `WFBE_CO_FNC_SpawnFactionSmoke` drops one side-coloured shell at assault onset / town garrison (west=Green, east=Red, resistance=Orange), server-only and event-triggered, bounded by the MAX/TTL/COOLDOWN trio above. The function lives at `Common/Functions/Common_SpawnFactionSmoke.sqf`; the gate banner comment is at `Common/Init/Init_CommonConstants.sqf:604`.

## QoL trio (lines 553–555)

Work-order item 16. The banner is at `Common/Init/Init_CommonConstants.sqf:553`. `WFBE_C_QOL_TRIO` is the master switch for all three QoL features; the advisor reads `WFBE_C_QOL_ADVISOR_INTERVAL` for its nudge cadence.

| Constant | Default | Type | Gates | path:line |
|---|---|---|---|---|
| `WFBE_C_QOL_TRIO` | `1` | `isNil` | Master switch — `0` disables all three QoL features | Init_CommonConstants.sqf:554 |
| `WFBE_C_QOL_ADVISOR_INTERVAL` | `300` | `isNil` | Seconds between advisor nudge checks (`0` = off) | Init_CommonConstants.sqf:555 |

Consumer route: [QoL trio player hints](QoL-Trio-Player-Hints-Reference) owns the client-facing behavior for the salvage payout toast, upgrade unlock banner and periodic advisor nudge. The compact gate proof stays here: the salvage-payout toast gates on `> 0` at `Client/FSM/updatesalvage.sqf:53`; the upgrade-advice path on `> 0 && _upgrade <= 3` at `Client/Functions/Client_FNC_Special.sqf:211`; the advisor loop exits when `< 1` at `Client/Functions/Client_QOL_Advisor.sqf:24` and reads the interval at `Client/Functions/Client_QOL_Advisor.sqf:27`.

## Restart announcer (lines 557–561)

Work-order item 15 — a server-side countdown that broadcasts once per minute over the final WARN window. Banner at `Common/Init/Init_CommonConstants.sqf:557`.

| Constant | Default | Type | Gates | path:line |
|---|---|---|---|---|
| `WFBE_C_RESTART_ENABLED` | `1` | `isNil` | `0` disables the in-game restart announcer entirely | Init_CommonConstants.sqf:558 |
| `WFBE_C_RESTART_AT_MIN` | `90` | `isNil` | Mission uptime (minutes) at which the scheduled restart occurs | Init_CommonConstants.sqf:559 |
| `WFBE_C_RESTART_WARN_MIN` | `5` | `isNil` | Start warning this many minutes out; fires exactly this many times (once per minute) | Init_CommonConstants.sqf:560 |
| `WFBE_C_RESTART_MSG` | `"SERVER RESTART IN %1 MINUTE(S) - finish up and find cover."` | `isNil` | Broadcast line; `%1` = minutes remaining | Init_CommonConstants.sqf:561 |

## Dashboard-link announcer (lines 563–566)

Added by the claude-gaming 2026-06-14 work — a periodic broadcast of the public live-stats URL so players know where to find updates/benchmarks. Banner at `Common/Init/Init_CommonConstants.sqf:563`.

| Constant | Default | Type | Gates | path:line |
|---|---|---|---|---|
| `WFBE_C_DASHBOARD_ANNOUNCE_ENABLED` | `1` | `isNil` | `0` disables the in-game dashboard-link announcer | Init_CommonConstants.sqf:564 |
| `WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL` | `300` | `isNil` | Seconds between dashboard-link broadcasts (default 5 min) | Init_CommonConstants.sqf:565 |
| `WFBE_C_DASHBOARD_MSG` | `"WASP LIVE STATS  >>  http://78.46.107.142:8080/  <<  …"` | `isNil` | The broadcast line (full URL + blurb in source) | Init_CommonConstants.sqf:566 |

## Top-Players leaderboard emitter (lines 568–573)

Added by the claude-gaming 2026-06-14 work — a periodic per-player `PLAYERSTAT` snapshot, the only telemetry carrying the player display NAME (powers the public Top-Players tab: UID → name → score → side). It **reuses the always-on `WFBE_C_STATLOG` gate** and is independent of the OFF-by-default `WFBE_C_STATS_ENABLED` path (comment at `Common/Init/Init_CommonConstants.sqf:571`).

| Constant | Default | Type | Gates | path:line |
|---|---|---|---|---|
| `WFBE_C_PLAYERSTAT_ENABLED` | `1` | `isNil` | `0` disables the per-player leaderboard emit entirely | Init_CommonConstants.sqf:572 |
| `WFBE_C_PLAYERSTAT_INTERVAL` | `60` | `isNil` | Seconds between PLAYERSTAT snapshot bursts (floored at 30s in the loop) | Init_CommonConstants.sqf:573 |

Consumers (verified): the loop exits unless `WFBE_C_PLAYERSTAT_ENABLED == 1` at `Server/FSM/server_playerstat_loop.sqf:27`, reads the interval at `Server/FSM/server_playerstat_loop.sqf:32`, and applies the 30s floor (`if (_interval < 30) then {_interval = 30}`) at `Server/FSM/server_playerstat_loop.sqf:33`. The same loop gates its emit on `WFBE_C_STATLOG != 1` at `Server/FSM/server_playerstat_loop.sqf:28`; the emitter is armed from `Server/Init/Init_Server.sqf:791`. Capture telemetry shares the `WFBE_C_STATLOG == 1` gate at `Server/FSM/server_town.sqf:235`.

## Reading the gate forms

| Form in source | Behavior | Where used here |
|---|---|---|
| `WFBE_C_X = V;` | Plain assignment every load — a server cannot pre-seed an override (any earlier value is overwritten) | The 13 hard `=` rows in the EXPERITAL block (lines 576–588) plus the two grace-period values (593, 596) |
| `if (isNil "WFBE_C_X") then {WFBE_C_X = V};` | Default only when unset — a server `init.sqf`/`description.ext` may pre-seed an override before this file runs | The QoL/announcer/leaderboard blocks and the capture/cosmetic/smoke `isNil` rows (589, 597–608) |

When a consumer reads a flag it almost always does so defensively with `missionNamespace getVariable ["WFBE_C_X", <fallback>]` (e.g. `Server/FSM/server_playerstat_loop.sqf:27`), so a flag that is somehow never assigned still degrades to the consumer's own fallback rather than erroring.

## Continue Reading

- [Mission Start Parameters Index](Mission-Start-Parameters-Index) — the lobby-settable `Parameters.hpp` params; the complement to this hardcoded-gate index
- [Counter Battery Radar System](Counter-Battery-Radar-System) — the feature gated by `WFBE_C_STRUCTURES_COUNTERBATTERY`
- [Bank Reserve And Artillery Radar Structures](Bank-Reserve-And-Artillery-Radar-Structures) — `WFBE_C_ECONOMY_BANK` / `WFBE_C_STRUCTURES_ARTILLERYRADAR` / `WFBE_C_STRUCTURES_RESERVE`
- [Medic Redeployment Truck Forward Spawn](Medic-Redeployment-Truck-Forward-Spawn) — `WFBE_C_UNITS_REDEPLOYTRUCK`
- [Side Patrol Runtime And Convoy Mechanics](Side-Patrol-Runtime-And-Convoy-Mechanics) — `WFBE_C_PATROL_CONVOY_PAY` convoy stop payouts
