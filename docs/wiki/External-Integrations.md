# External Integrations

## Discord Bot

`DiscordBot` is a .NET 9 executable using:

- `Discord.Net` 3.10.0
- `Newtonsoft.Json` 13.0.2
- `Pastel` 4.0.2

The bot registers `/setup` and `/cleanup`, tracks a configured game-status channel/message, updates channel name and bot presence every 60 seconds, and reads `database.json` from a data source path. `GameData` maps exported mission stats to terrain/player-count display strings.

### Discord Data Path And Deserialization Risk

The game-status path is one-way: the Arma extension writes `database.json`, and the Discord bot reads it on a 60-second timer (`DiscordBot/src/GameStatusUpdater.cs:9`, `:19-27`). `DiscordBot/src/ExtensionData/GameData/GameData.cs:37-56` opens that file and deserializes it with Newtonsoft `TypeNameHandling.All`. That is unnecessary for the flat `GameData` shape and is a live deserialization risk in the same process that reads `token.txt` (`DiscordBot/src/ProgramRuntime.cs:21-37`).

The extension writer is safer today: `Extension/src/SerializationManager.cs:33` sets `TypeNameHandling.None`. Prefer matching that on the bot side unless a future schema truly requires explicit polymorphism, and then use a narrow binder/allow-list.

## Arma Extension: `a2waspwarfare_Extension`

`Extension` is a .NET Framework 4.8 library using `RGiesecke.DllExport` and Newtonsoft.Json. It exports `_RVExtension@12`, parses comma-separated arguments, resolves an extension class by enum name, and currently includes `GLOBALGAMESTATS`.

Mission bridge:

- `Server/CallExtensions/GlobalGameStats.sqf`
- calls `"a2waspwarfare_Extension" callExtension format ["%1,%2,%3,%4,%5,%6", ...]`
- sends class name, west score, east score, map, uptime and player count every 60 seconds.

## AntiStack Database Extension

Server AntiStack scripts call `"A2WaspDatabase" callExtension` for player/team score storage and map selection. Key scripts:

- `callDatabaseRetrieve.sqf`
- `callDatabaseStore.sqf`
- `callDatabaseStoreSide.sqf`
- `callDatabaseSendPlayerList.sqf`
- `callDatabaseRequestSideTotalSkill.sqf`
- `callDatabaseFlushPlayerList.sqf`
- `callDatabaseSetMap.sqf`

This is live-server sensitive because extension/database latency can affect monitoring loops and team-balance decisions.

### AntiStack Trust And Loop Drilldown

Use this when changing AntiStack, disabling it for performance comparison, or replacing the external database layer. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Surface | Source-backed behavior | Handoff note |
| --- | --- | --- |
| Compile and runtime gate | The database helpers are compiled from `Server/Init/Init_Server.sqf:72-79`, `:85-87`. The mission parameter is declared at `Rsc/Parameters.hpp:546-552` and defaults enabled; `Init_CommonConstants.sqf:175-177` keeps older parameter sets enabled by default. Server init logs/audits the state and starts AntiStack loops only when `WFBE_C_ANTISTACK_ENABLED == 1` at `Server/Init/Init_Server.sqf:597-613`. | The ON/OFF switch is a runtime/ops guard, not a parser hardening fix. Keep launch-side team-swap tracking separate from skill balancing. |
| External response parsing | All seven `callDatabase*.sqf` helpers call `"A2WaspDatabase" callExtension`, then parse extension text with `call compile`: retrieve `:24-49`, side-skill request `:30-56`, store `:25-33`, store-side `:40-48`, send-player-list `:58-65`, flush-player-list `:18-26`, set-map `:21-29`. | DR-7 remains the core trust boundary. If the DLL is absent, stale or compromised, the server is compiling extension output as SQF. Future code should guard empty/error returns and shape-check ARRAY/SCALAR fields before indexing. |
| Blocking/polling calls | `callDatabaseRetrieve.sqf:37-54` polls request status up to 120 times with configurable sleep; `callDatabaseRequestSideTotalSkill.sqf:42-59` polls up to 9 times with 3s sleep. Join checks call side-skill retrieval via `RequestJoin.sqf:58-62`; skill compensation calls side-skill retrieval repeatedly in `skillDiffCompensation.sqf:12-15`, `:33-35`, `:91-93`. | Treat database latency as gameplay latency. Any replacement should define timeouts/circuit-breakers and neutral fallback values for join and compensation decisions. |
| Score and player-list loops | `countPlayerScores.sqf:3-24` starts `mainLoop`, `updateScoreInternal` and `flushLoop`; `mainLoop.sqf:15-48` retrieves and stores player score deltas every 120s; `updateScoreInternal.sqf:13-33` samples current scores every second; `flushLoop.sqf:15-55` sends UID/side lists every 120s. Each loop now exits early if AntiStack is disabled. | These are performance-sensitive loops over `allUnits`. Use `PerformanceAudit_Record` rows already present in the code before changing cadence or DB batching. |
| Join/disconnect/endgame persistence | `RequestJoin.sqf:48-68` skips only the skill DB check when AntiStack is disabled, but keeps team-swap logic active; successful joins store side at `:86-90`. `Server_OnPlayerDisconnected.sqf:152-175` stores score delta and clears side unless AntiStack is disabled. `server_victory_threeway.sqf:52-84` exits DB finalization when disabled; otherwise it stores final score deltas and flushes player list. | Disable mode should still preserve team-swap protection via launch/connect state, but it intentionally stops DB skill/session persistence. State that explicitly in operator notes. |
| Skill-difference compensation | `skillDiffCompensation.sqf:8-15` reads total side skill every 120s, accumulates `TEAM_SKILL_TICKS_*`, and when thresholds trip it repeatedly calls the DB, computes a capped compensation percentage, calls `ChangeSideSupply`, then broadcasts `SUPPLY_COMPENSATION_AMOUNT_EAST/WEST` at `:54-75`, `:112-133`. | This is gameplay economy mutation driven by external skill totals. Do not tune thresholds or supply compensation without considering DB trust, side-supply authority and DR-22 clamp behavior. |
| Launch-connect ACK | `clientHasConnectedAtLaunch.sqf:1-16` records `WFBE_PLAYER_<uid>_CONNECTED_AT_LAUNCH` and targets `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` to `owner _player`. The source comment at `:10` says this side tracking must remain active even when AntiStack skill balancing is disabled. | This direct public-variable channel is documented in [Public variable channel index](Public-Variable-Channel-Index#2a-direct-handler-drilldown). It is teamswap state, not the external database risk. |

Current source has good disable guards around the scheduled loops and helper entrypoints, but enabled sessions still rely on `A2WaspDatabase` returning safe SQF-shaped text. Keep DR-7..DR-10 as the canonical risk record and this table as the implementation map.

## BattlEye Filter

`BattlEyeFilter/publicvariable.txt` contains `5 "kickAFK"` and is a feature filter for AFK kicking, not a general security posture. `Client/FSM/updateclient.sqf:153-160` intentionally broadcasts `kickAFK`; its comments explain that BattlEye catches that public variable because the direct `serverCommand` kick path is unavailable/disabled. The AFK path also seeds/sends `AFKthresholdExceededName` from `Client/Init/Init_Client.sqf:258`, `Client/Module/AFKkick/monitorAFK.sqf:25` and receives it in `Server/Module/afkKick/initAFKkickHandler.sqf:9`.

DR-30 confirms the repository only ships that `publicvariable.txt` feature rule; no `scripts.txt` or broader BattlEye security filters are present in the repo. That absence does not prove the production server's BattlEye path lacks filters, so public-server hardening still needs an owner decision or deployment check. For channel whitelist design, use [Public variable channel index](Public-Variable-Channel-Index); for the source-cited risk record, use [Deep-review findings](Deep-Review-Findings) DR-1 and DR-30.

## Public Server Metadata

The repo README lists:

- IP: `144.76.185.231`
- Port: `2302`
- Server name: `Miksuu's Warfare | CTI TvT PvE | discord.me/warfare`
- BattleMetrics and GameTracker links
- Trello board link

