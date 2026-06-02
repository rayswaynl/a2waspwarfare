# Mission Entrypoints And Lifecycle

> For the machine-role truth table, per-role boot timelines, and the global-flag → `waitUntil` dependency graph (read this before reordering any init call), see [Lifecycle wait-chain reference](Lifecycle-Wait-Chain).

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

`version.sqf` is generated/ignored rather than committed; raw source checkout needs LoadoutManager or a deploy step to provide it before the mission compiles. See [Tools and build workflow](Tools-And-Build-Workflow) and [Deep-review findings](Deep-Review-Findings) DR-43a.

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

For the post-join `wfbe_*` wait chain and the timeout-less JIP robustness note, see [Lifecycle wait-chain reference](Lifecycle-Wait-Chain#known-ordering-hazards) and [Deep-review findings](Deep-Review-Findings) DR-37.

## Headless Init

Headless support is gated by the OA version check in `initJIPCompatible.sqf`. When supported and configured, `Headless/Init/Init_HC.sqf` loads client PVF handling and common init pieces needed for delegated AI.

