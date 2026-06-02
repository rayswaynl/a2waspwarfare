# Mission Entrypoints And Lifecycle

> For the machine-role truth table, per-role boot timelines, and global flag -> `waitUntil` dependency graph, read [Lifecycle wait-chain reference](Lifecycle-Wait-Chain) before reordering any init call.

## `description.ext`

The mission metadata and UI resource graph is assembled from:

- `version.sqf`
- `Sounds/description.ext`
- `Music/description.ext`
- `Rsc/Header.hpp`
- `Rsc/Styles.hpp`
- `Rsc/Parameters.hpp`
- `Rsc/Ressources.hpp`
- `Rsc/Dialogs.hpp`
- `Rsc/Titles.hpp`
- `Rsc/Identities.hpp` when not `VANILLA`

It also sets `loadScreen`, disables spoken sentences, disables channels 3 and 6, and leaves `disabledAI=0`.

`version.sqf` is included here and again by `initJIPCompatible.sqf`, but it is not committed in the current repo checkout. Treat it as generated terrain metadata from LoadoutManager, not as an optional nicety: a fresh source mission needs `version.sqf` produced or supplied before it can preprocess cleanly.

Source verification: `description.ext:39` includes `version.sqf`; `:41-58` include sound, music and Rsc bundles; `:64-67` set `loadScreen`, `disableChannels[]` and `disabledAI`. `version.sqf` is absent from the current Chernarus source mission checkout, so the generated-file warning is current.

Confirmed finding cross-link: [Deep-review findings](Deep-Review-Findings) DR-43a tracks the missing `version.sqf` source/build gap.

## `initJIPCompatible.sqf`

This is the first major runtime script. It creates early logging, determines server/client/headless roles, runs version detection, initializes common constants and parameters, applies environment time, then dispatches common/server/client/headless init scripts.

Important lifecycle flags include:

- `clientInitComplete`
- `commonInitComplete`
- `serverInitComplete`
- `serverInitFull`
- `townInitServer`
- `townInit`
- `WFBE_GameOver`
- `gameOver`

### Boot Graph And Parameter Gates

The high-level boot chain is:

```text
description.ext
  -> initJIPCompatible.sqf
  -> Init_Version.sqf / VERSION_SET
  -> Init_Parameters.sqf + Init_CommonConstants.sqf
  -> Init_TownMode.sqf / townModeSet
  -> Init_Common.sqf / commonInitComplete
  -> Init_Towns.sqf / townInit
  -> Init_Server.sqf, Init_Client.sqf and/or Init_HC.sqf
```

`Common/Init/Init_Parameters.sqf:5-10` copies each `description.ext` `Params` class name into `missionNamespace`, so parameter names are live runtime globals. `initJIPCompatible.sqf:142-162` can then override several of those values for air-war/debug modes before later init code consumes them. The most easily misread gates are `WFBE_DAYNIGHT_ENABLED`, `WFBE_C_AI_DELEGATION`, economy/supply mode constants, `WFBE_C_BASE_START_TOWN`, module toggles such as EASA/ICBM/IRS/CM, and map-icon blinking.

Headless mode is especially stateful: `WFBE_C_AI_DELEGATION == 2` means HC mode in configuration, but `initJIPCompatible.sqf:168-170` downgrades it to `0` when the detected OA build does not support HC. That downgrade happens during boot, so bug reports can show a different runtime value than the lobby parameter suggested.

WASP should not be described as a live parallel bootstrap branch. The old WASP block in `initJIPCompatible.sqf` is commented out; current WASP behavior is wired per feature from client/server init and from the specific WASP scripts documented in [WASP overlay](WASP-Overlay).

### Mission Object Init Layer

`mission.sqm` is part of the lifecycle, not just terrain metadata. Town logic objects run `Common\Init\Init_Town.sqf` from their `init` fields, and the `WF_Logic` object sets town-mode removal lists before running `Common\Init\Init_TownMode.sqf`.

Verified anchors:

| Source | Runtime role |
| --- | --- |
| `mission.sqm:128` and following town logic entries | Town objects call `Common\Init\Init_Town.sqf` with name, dubbing name, start SV, max SV, range and group templates. Current source scan found 40 such explicit `Init_Town.sqf` calls. |
| `mission.sqm:3265` | `WF_Logic` sets `totalTowns = 43`, disables simulation and seeds `Towns_Removed*` lists before `ExecVM "Common\Init\Init_TownMode.sqf"`. |
| `Common/Init/Init_Town.sqf:18` | Each town waits for `townModeSet && WFBE_Parameters_Ready` before applying town state. |
| `Common/Init/Init_Town.sqf:42` | Town object setup then waits for `commonInitComplete`. |
| `Common/Init/Init_Town.sqf:92` | Server-side town model/camp setup waits for `serverInitComplete`. |
| `Common/Init/Init_Town.sqf:134` | AI/patrol follow-up waits for `townInitServer`. |

This means town lifecycle bugs can live in mission object init, town init scripts and server FSMs together. Regex-only scans of SQF files will miss the `mission.sqm` entry layer.

## Common Init

`Common/Init/Init_Common.sqf` compiles most shared helpers and config. The central idea is that config arrays and helper functions are available to both server and clients before side-specific runtime code starts using them.

Major common responsibilities:

- combat handlers: reload, AT, AA, artillery, alarm;
- economy helpers: team funds, side supply, income, commander team;
- structure and town helpers: factories, closest town/camp/depot, side structures;
- network helpers: `Common_SendToClient`, `Common_SendToClients`, `Common_SendToServer`;
- config loading: core models, gear, root definitions, defenses, groups;
- module initialization: ICBM, IR smoke, CIPHER, boundaries.

## Server Init

`Server/Init/Init_Server.sqf` is authoritative. It compiles server functions, creates resistance center, initializes side logic and team state, starts global town scripts, starts cleanup/restorer loops, starts anti-stack if enabled, publishes server FPS, runs performance audit on server, launches day/night authority, and starts victory/resource loops.

Notable server loops:

- `Server/FSM/server_town.sqf`
- `Server/FSM/server_town_ai.sqf`
- `Server/FSM/server_victory_threeway.sqf`
- `Server/FSM/updateresources.sqf`
- `Server/FSM/server_collector_garbage.sqf`
- `Server/FSM/emptyvehiclescollector.sqf`
- dropped item, crater, ruin and mine cleaners;
- building restorer;
- `Server/Module/serverFPS/monitorServerFPS.sqf`.

## Client Init

`Client/Init/Init_Client.sqf` initializes player-side behavior. It compiles client functions, registers damage/fired handlers, adds map/menu/action behaviors, starts day/night client sync when needed, applies skill/module actions, sends join/anti-stack handshakes, and starts client update loops.

Global gameplay hotkeys are wired here through `findDisplay 46` `KeyDown` handlers. Gear filler hotkeys are separate in `Client/Init/Init_Keybind.sqf`.

## Headless Init

Headless support is gated by the OA version check in `initJIPCompatible.sqf`. When supported and configured, `Headless/Init/Init_HC.sqf` loads client PVF handling and common init pieces needed for delegated AI.

`Headless/Init/Init_HC.sqf` currently uses a fixed delay and then sends `["RequestSpecial", ["connected-hc", player]]` to the server. There is no explicit `waitUntil {serverInitFull}` barrier in that file, so HC timing bugs should be investigated against [Lifecycle wait-chain](Lifecycle-Wait-Chain) and [AI/headless](AI-Headless-And-Performance) together.

Source verification: `Headless/Init/Init_HC.sqf:12` is `sleep 20`; `:15` sends the `connected-hc` request. The server sets `serverInitComplete = true` early at `Server/Init/Init_Server.sqf:117`, waits for `commonInitComplete && townInit` at `:127`, and only later sets `serverInitFull = true` at `:507`. Treat the HC sleep as a timing proxy, not a real dependency barrier.

Confirmed finding cross-link: [Deep-review findings](Deep-Review-Findings) DR-37 is the boot wait-chain review; use [Lifecycle wait-chain](Lifecycle-Wait-Chain) before reordering init flags or replacing waits.

## 2026-06-02 Lifecycle Report Verification

Anscombe's lifecycle readout was source-checked against the actual `Missions/[55-2hc]warfarev2_073v48co.chernarus` tree. The report's `Migrations` path spelling was a typo; the substantive lifecycle claims below were confirmed from source:

| Claim | Verification |
| --- | --- |
| `description.ext` is the metadata/resource front door. | Confirmed at `description.ext:39-67`. |
| `initJIPCompatible.sqf` is the top-level runtime orchestrator. | Confirmed by role detection at `:52-56`, version wait at `:46-50`, parameter readiness at `:212`, and branch dispatch at `:214`, `:220`, `:233`, `:238`. |
| Lobby parameters become missionNamespace globals. | Confirmed in `Common/Init/Init_Parameters.sqf:5-9`. |
| Common init is the shared compile/config hub. | Confirmed by `Init_PublicVariables.sqf` load at `Init_Common.sqf:295`, airport/boundary init at `:311` and `:316`, and `commonInitComplete = true` at `:371`. |
| Town bootstrap spans mission objects plus SQF. | Confirmed by `mission.sqm` town object init lines, `mission.sqm:3265`, `Init_TownMode.sqf:3/21`, `Init_Towns.sqf:3/13`, and `Init_Town.sqf:18/42/92/134`. |
| Client waits on common and town state before full readiness. | Confirmed by `Init_Client.sqf:165`, `:360`, `:596`, `:788`, `:957`, and `:961-963`. |
| Server starts authoritative long-running loops after setup. | Confirmed by `Init_Server.sqf:514`, `:528`, `:531` and related server loop launches. |
| HC has no `serverInitFull` wait barrier. | Confirmed by `Init_HC.sqf:12/15` versus `Init_Server.sqf:507`. |

## Continue Reading

Previous: [Architecture overview](Architecture-Overview) | Next: [Lifecycle wait-chain](Lifecycle-Wait-Chain)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
