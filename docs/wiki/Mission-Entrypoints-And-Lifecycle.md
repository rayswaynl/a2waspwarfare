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

## Continue Reading

Previous: [Architecture overview](Architecture-Overview) | Next: [Lifecycle wait-chain](Lifecycle-Wait-Chain)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
