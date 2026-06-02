# WASP Overlay

> Claude deep-dive page (source-cited). Documents the project-specific `WASP/` subtree that is layered on top of stock Benny Warfare BE (WFBE). Stock WFBE systems are covered in [Architecture overview](Architecture-Overview) and the per-system pages; this page covers only the WASP additions.

All paths are relative to the source mission root `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## What "WASP" is

WASP is the community/server identity this fork is built for. The mission credits itself as "Warfare WASP-AWESOME EDITION" in `Client/GUI/GUI_Menu_Help.sqf:149`, and `mission.sqm:26` reads `briefingDescription="by Benny and Awesome&WASP"`. The `WASP/` folder holds custom features added on top of stock WFBE, contributed over time by several authors (English additions by "Marty", Russian-language contributions with Cyrillic comments, and DeraKOren for the RPG-dropping system). It is unrelated to "WASP" as any engine term.

## Subtree map

| File | Purpose | Wired in / status |
| --- | --- | --- |
| `WASP/Init_Client.sqf` | Original WASP client entry point. | **Dead** — entire body commented (`WASP/Init_Client.sqf:5-21`). Superseded by direct wiring in `Client/Init/Init_Client.sqf`. |
| `WASP/common/procInitComm.sqf` | MP-safe wrapper around `setVehicleInit`/`processInitCommands`/`clearVehicleInit` to run init code on a vehicle network-wide. | Compiled as `WASP_procInitComm` only at `initJIPCompatible.sqf:253`, which is **commented out** → function is undefined at runtime. |
| `WASP/actions/AddActions.sqf` | Re-adds player scroll actions on spawn/respawn. | **Live** (`Init_Client.sqf:575`). Most actions commented; only the HQ cash-recovery action is active. |
| `WASP/actions/Action_RepairMHQDepot.sqf` | Commander-only: spend cash to paradrop-respawn a destroyed HQ near the player; resets all town SV to 10. | **Live** (via `AddActions.sqf`). |
| `WASP/actions/OnKilled.sqf` | On player death, re-runs `AddActions.sqf` to reattach actions after respawn. | **Live** (`Client/Functions/Client_PreRespawnHandler.sqf:11`). |
| `WASP/actions/GearYouUnit.sqf` | Open the gear dialog on a nearby AI subordinate. | **Orphan** — only caller is a commented line `AddActions.sqf:4`. |
| `WASP/actions/car_wheel_new.sqf` | Wheel repair for immobilized cars; calls `WASP_procInitComm`. | **Broken orphan** — only caller is commented (`AddActions.sqf:6`); would also crash on the undefined `WASP_procInitComm`. |
| `WASP/baserep/init.sqf` | Bootstraps base-repair: `#include`s `data.sqf` + `viem.sqf`. | **Live** (`Init_Client.sqf:574`). |
| `WASP/baserep/data.sqf` | Table mapping base building classnames → display name, interaction distance, repair-rate %. | Data include. |
| `WASP/baserep/viem.sqf` | Commander-only loop: HUD building-health overlay; attaches/removes a "Repair" action near damaged structures. Spotters also see enemy building health at range. | Main baserep loop. |
| `WASP/baserep/repair.sqf` | Performs the repair: medic animation, drains side supply, increments building HP per tick. | Called by `viem.sqf`. |
| `WASP/global_marking_monitor.sqf` | Intercepts map double-click to auto-prefix the player's name onto marker text. | **Live** (`Init_Client.sqf:267`). Display wait still has a short busy-poll opportunity; see [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup). |
| `WASP/rpg_dropping/DropRPG.sqf` | By DeraKOren (2012). (a) single-use AT-launcher weapon-swap, (b) pipe-bomb TK prevention near friendly bases, (c) mine time-tracking. | **Live** (`Init_Client.sqf:15` + recompiled on respawn at `Client_PreRespawnHandler.sqf:12`). |
| `WASP/unsort/StartVeh.sqf` | Defines `EAST_StartVeh` / `WEST_StartVeh` classname pools for one random extra starting vehicle per side. | **Live** (compiled `Init_Server.sqf:306`, used `:425-459`). |
| `test/wasp_selftest.sqf` | Server-only read-only diagnostic observer. | **Live** (`init.sqf:4`). See below. |

> "**baserep**" is **base repair**, not base reputation. "**unsort**" is literally an unsorted dumping folder — `StartVeh.sqf` is live but the author never moved it into the proper `Common/Config/` hierarchy.

Do not confuse WASP base repair with the stock `Server_HandleBuildingRepair.sqf` path. WASP base repair is live client-side wiring from `Init_Client.sqf:574` through `WASP/baserep/viem.sqf` and `repair.sqf`; `Server_HandleBuildingRepair.sqf` is compiled but no active source caller was found during the construction audit.

## How WASP is wired into the stock lifecycle

The original single entry point (`WASP/Init_Client.sqf`, called from `initJIPCompatible.sqf:253-255`) was disabled by Marty as "old wasp script using resources unnecessarily." WASP features are now wired individually:

| Call site | Wires |
| --- | --- |
| `init.sqf:4` | `test/wasp_selftest.sqf` (server-only) |
| `Init_Client.sqf:15` | `WASP/rpg_dropping/DropRPG.sqf` |
| `Init_Client.sqf:267` | `WASP/global_marking_monitor.sqf` |
| `Init_Client.sqf:574` | `WASP/baserep/init.sqf` |
| `Init_Client.sqf:575` | `WASP/actions/AddActions.sqf` |
| `Client_PreRespawnHandler.sqf:11-12` | `WASP/actions/OnKilled.sqf` + recompile `DropRPG.sqf` |
| `Init_Server.sqf:306,425-459` | `WASP/unsort/StartVeh.sqf` |
| `updateclient.sqf:124-145` / `updateteamsmarkers.sqf:88` | `WASP_AFK` player variable (AFK detection + "(AFK)" marker suffix) |

## Locality / JIP Notes

| WASP feature | Locality status | Development note |
| --- | --- | --- |
| HQ recovery action | Mostly client-side. `Action_RepairMHQDepot.sqf` checks funds/HQ state, deducts player cash, moves the HQ and mutates town supply locally before sending the repair request. | Treat as an authority-light legacy action. If hardened, move commander/funds/HQ/town-SV validation to the server side through [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) and [Server authority map](Server-Authority-Migration-Map). |
| Global marking monitor | Intentionally client-local map double-click helper. | Safe for UI behavior; do not expect it on HC/server. |
| Start vehicles | Server-owned spawn state from `WASP/unsort/StartVeh.sqf`, compiled/used in `Init_Server.sqf`. | Not a JIP UI feature; changes affect initial server-side vehicle spawning and generated mission skip-list mirroring. |
| Respawn action re-add | `WASP/actions/OnKilled.sqf` re-runs `AddActions.sqf`; current wiring comes through `Client_PreRespawnHandler.sqf`. | Keep this dependency when changing respawn handlers, or the active HQ recovery action can disappear after respawn. |

Claude DR-40 reviewed the WASP Perf + JIP/HC cells. The live WASP wiring is JIP/HC-clean because it runs per player from `Init_Client.sqf`, and headless clients skip these player-local features. The DR-40 perf nit in `WASP/global_marking_monitor.sqf:62` remains a small local cleanup opportunity: add a tiny sleep/backoff to the display-54 wait before expanding marker behavior. See [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup).

## `test/wasp_selftest.sqf`

A **read-only** observer harness, gated to the server twice (`init.sqf:4` via `isServer`, and `if (!isServer) exitWith {}` inside).

- Waits up to 240s for `WFBE_PRESENTSIDES`; logs FAIL if it times out.
- Asserts `count WFBE_PRESENTSIDES > 0`.
- Samples 20 times at 30s intervals (~10 min window): per side it logs AI-commander funds (`GetAICommanderFunds`), town supply (`WFBE_CO_FNC_GetTownsSupply`), and whether the commander is AI (`WFBE_CO_FNC_GetCommanderTeam`). Exits early if `gameOver`.
- Reports exclusively via `diag_log` with the tag `[WASP-SELFTEST]` (grep the server RPT). It never mutates mission state — safe to leave enabled.

## Dead / missing WASP references (cleanup candidates)

These are referenced only from commented-out lines, or point at files that no longer exist. See [Feature status register](Feature-Status-Register) for the full disabled-feature inventory.

- `WASP/Init_Client.sqf` body — fully commented (Killed EH, OnArmor timer, KeyDown handler, trigger creation).
- `WASP/actions/OnArmor/` and `WASP/actions/SitsOnArmor/` directories — **deleted**; still referenced by commented `AddActions.sqf:10-12` and `Init_Client.sqf:7,21`.
- `WASP/KeyDown.sqf` — **missing**; referenced by commented `Init_Client.sqf:12-13`.
- `WASP_procInitComm` — compile line commented (`initJIPCompatible.sqf:253` in this checkout's line map; Gauss also observed the old block around `:241-245`), so `car_wheel_new.sqf` (its only consumer) is a dead chain.
- `WASP/actions/GearYouUnit.sqf` is still present, but the action that opens it is commented at `WASP/actions/AddActions.sqf:4`; DR-35 also found this dead action was one of the apparent localization misses.
- The commented OnArmor actions reference missing localization keys and missing scripts, but DR-35 verified these are dead-code misses rather than live broken strings.

## Parameters And Localization Notes

The mission parameter system is live and index-aligned: `Common/Init/Init_Parameters.sqf:5-10` iterates `missionConfigFile >> "Params"` and reads `paramsArray select _i` in multiplayer. Keep `class Params` ordering stable when inserting or removing parameters, or every later parameter value can silently shift.

Localization was reviewed clean in DR-35 after case-folding and dead-code filtering. Do not spend time chasing the WASP OnArmor/Gear string keys as live UI bugs unless the dead actions are deliberately revived.

## Continue Reading

Previous: [Content/maps](Content-Structure-And-Maps) | Next: [SQF code atlas](SQF-Code-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
