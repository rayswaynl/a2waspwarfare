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

## BattlEye Filter

`BattlEyeFilter/publicvariable.txt` contains the public-variable rule used for AFK kick behavior. Client `updateclient.sqf` intentionally broadcasts `kickAFK`; BattlEye detects it and kicks because direct serverCommand paths are unavailable/disabled.

## Public Server Metadata

The repo README lists:

- IP: `144.76.185.231`
- Port: `2302`
- Server name: `Miksuu's Warfare | CTI TvT PvE | discord.me/warfare`
- BattleMetrics and GameTracker links
- Trello board link

