# Architecture Overview

The repository is an Arma 2 OA Warfare/CTI mission derived from Benny's Warfare and actively modernized for the Miksuu/WASP server. The core runtime is SQF in a mission folder, surrounded by C# helper tools, a Discord status bot, and a Windows extension bridge.

## Runtime Partitions

- `Common`: shared constants, config, utility functions, public-variable registration, faction/core data, artillery and shared modules.
- `Server`: authoritative game state, economy, towns, AI spawning, victory checks, PVF request handling, cleanup, callExtension integration, anti-stack/database hooks.
- `Client`: UI, menus, player actions, local HUD/marker loops, skill modules, supply mission start flow, map interactions, PVF client handlers.
- `Headless`: detection and initialization for headless clients. The mission disables headless delegation when the OA build is too old.
- `WASP`: older/custom gameplay layer with MHQ repair, RPG dropping, base repair and marker monitor scripts. Some of it is still present but one old init block is commented out.

Representative anchors: `initJIPCompatible.sqf:214-238` dispatches Common/Server/Client/Headless entrypoints; `Common/Init/Init_Common.sqf:6-160,209-323` compiles shared functions/config/modules; `Server/Init/Init_Server.sqf:10-57,298,510-531,578` compiles server functions and starts extension/town/economy/FPS loops; `Client/Init/Init_Client.sqf:52,958` compiles client build/UI helpers and shows client onboarding text; the old WASP init block is commented at `initJIPCompatible.sqf:241-245`.

## Source Mission Versus Generated Missions

`Missions/[55-2hc]warfarev2_073v48co.chernarus` is the authoritative mission folder. The Takistan vanilla folder and modded mission folders are copy/generation outputs. The repo instructions say mission edits should be made in Chernarus, then copied with `Tools/LoadoutManager` via `dotnet run`.

## Initialization Model

`initJIPCompatible.sqf` is the main bootstrap. It:

- logs map, mission name, start distance, max player slots and log-content state;
- detects hosted server, dedicated server, normal client and headless client;
- reads mission parameters and common constants;
- starts `Common/Init/Init_Common.sqf` and `Common/Init/Init_Towns.sqf`;
- starts `Server/Init/Init_Server.sqf` on server/host;
- starts `Client/Init/Init_Client.sqf` on clients after side logic is ready;
- starts `Headless/Init/Init_HC.sqf` on headless clients.

Source anchors: `initJIPCompatible.sqf:26-32` writes the boot log, including `WF_MAXPLAYERS` as "Max players Defined"; `:52-56` detects hosted/headless role state; `:123` loads common constants; `:214-238` starts Common, town, server, client and headless init scripts.

## Data Flow At A Glance

1. `description.ext` includes version, sounds, music, resource/dialog/title definitions and mission parameters.
2. `initJIPCompatible.sqf` initializes globals, common constants and runtime partition entrypoints.
3. `Init_Common.sqf` compiles shared functions, loads faction/core/gear/defense/group config, and registers PVF handlers.
4. `Init_Server.sqf` creates side logic state, server functions, AI/town loops, cleanup loops, anti-stack, server FPS publishing and day/night authority.
5. `Init_Client.sqf` compiles local functions, wires player event handlers, UI actions, hotkeys, skill/action modules, client marker loops and HUD behavior.

Source anchors: `description.ext:39-58` includes generated version, Sounds, Music and Rsc bundles; `description.ext:64-67` sets load screen, disabled channels and `disabledAI`; `Common/Init/Init_Common.sqf:295` registers public variables; `Server/Init/Init_Server.sqf:510-531` starts town/resource loops; `Client/Init/Init_Client.sqf:52` compiles `Client_BuildUnit.sqf`.

## Development Philosophy

This mission values runtime performance and live-server stability. Many systems have explicit audit logging, cached UI writes, deferred loops, and optional switches. Documentation and feature work should preserve those patterns instead of reintroducing large per-frame scans or unconditional global broadcasts.

## Continue Reading

Previous: [Quickstart](Quickstart-For-Humans-And-Agents) | Next: [Mission lifecycle](Mission-Entrypoints-And-Lifecycle)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
