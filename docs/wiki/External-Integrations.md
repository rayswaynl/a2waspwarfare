# External Integrations

## Discord Bot

`DiscordBot` is a .NET 9 executable using:

- `Discord.Net` 3.10.0
- `Newtonsoft.Json` 13.0.2
- `Pastel` 4.0.2

The bot registers `/setup` and `/cleanup`, tracks a configured game-status channel/message, updates channel name and bot presence every 60 seconds, and reads `database.json` from a data source path. `GameData` maps exported mission stats to terrain/player-count display strings.

Required local files are intentionally absent from the repo:

- `DiscordBot/preferences.json`
- `DiscordBot/token.txt`

`preferences_sample.json` points `DataSourcePath` at `C:\a2waspwarfare\Data`. Runtime refuses to continue if `token.txt` is missing or empty, so do not treat a local bot run failure as a mission-code failure until those files are supplied.

### Discord Config Hygiene

Claude Round 16 verified that `DiscordBot/preferences_sample.json` currently includes concrete sample IDs (`GuildID`, `AuthorizedUserIDs`) plus the production-style `DataSourcePath`. `DiscordBot/FileConfiguration.cs` also falls back to `C:\a2waspwarfare\Data`, while `DiscordBot/src/ExtensionData/GameData/GameData.cs` has its own fallback path if preferences do not set one.

No token is committed, which is good. Still, treat the sample identifiers and hardcoded path as governance cleanup:

- replace real-looking sample IDs with obvious placeholders;
- prefer one config-loading path instead of multiple fallbacks;
- document whether `botconfig.json`, `preferences.json` or environment variables are the intended deployment source;
- keep `token.txt` and any live Discord IDs out of committed files.

### Discord Data Path Risk

Claude DR-31 completed the consumer-side review of the extension data path. The bot polls `database.json` on a 60-second timer, at startup and from a command path. Secret hygiene is good (`token.txt` and `preferences.json` are ignored, and commands are auth-gated), but `DiscordBot/src/ExtensionData/GameData/GameData.cs` deserializes that JSON with Newtonsoft `TypeNameHandling.All`.

That setting is unnecessary for the flat `GameData` DTO and creates a local-write-gated RCE sink in the token-holding bot process if anything can write to `C:\a2waspwarfare\Data\database.json`. Fix direction: use `TypeNameHandling.None` for the active reader and remove the dead `.Auto` deserialization helper noted in DR-29/DR-31.

## Arma Extension: `a2waspwarfare_Extension`

`Extension` is a .NET Framework 4.8 library using `RGiesecke.DllExport` and Newtonsoft.Json. It exports `_RVExtension@12`, parses comma-separated arguments, resolves an extension class by enum name, and currently includes `GLOBALGAMESTATS`.

Mission bridge:

- `Server/CallExtensions/GlobalGameStats.sqf`
- calls `"a2waspwarfare_Extension" callExtension format ["%1,%2,%3,%4,%5,%6", ...]`
- sends class name, west score, east score, map, uptime and player count every 60 seconds.

The handoff is file-based, not an HTTP API:

```mermaid
flowchart LR
    Mission["Arma mission GlobalGameStats.sqf"] --> Extension["a2waspwarfare_Extension callExtension"]
    Extension --> Json["C:\\a2waspwarfare\\Data\\database.json"]
    Json --> Bot["DiscordBot 60-second poll"]
    Bot --> Discord["Discord channel name, presence and status embed"]
```

The extension writes `GameData.Instance` to `C:\a2waspwarfare\Data\database.json`; DiscordBot reads the configured data-source path and updates Discord every 60 seconds.

Implementation notes from the source:

- `Extension/src/ExtensionMethods.cs` exports `_RVExtension@12` through `RGiesecke.DllExport`.
- `Extension/src/BaseExtensionClass/ExtensionName.cs` only enumerates `GLOBALGAMESTATS` in the in-repo extension.
- `Extension/src/SerializationManager.cs` writes `database.json` through a temp file and `File.Replace`.
- `SerializeDB()` is `async void`, so extension write failures can become log-only/asynchronous failures rather than mission-visible errors.

Claude DR-29 sharpened this boundary: the in-repo `GLOBALGAMESTATS` extension is not an SQF RCE path today because `GlobalGameStats.sqf` discards the `callExtension` return and the extension does not write `_output`. It still has code-owner risks: a commented/load-path deserialization landmine using Newtonsoft `TypeNameHandling.Auto`, an `async void` create/write race around `File.Replace`, stale write-only persistence scaffolding, and a player-count heuristic that can misreport headless clients.

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

Claude DR-7 through DR-10 found that all seven AntiStack DB wrappers `call compile` the `A2WaspDatabase` extension return. The `A2WaspDatabase` DLL is not in this repo, and `WFBE_C_ANTISTACK_ENABLED` defaults on in mission constants. In Arma 2 OA there is no `parseSimpleArray`, so hardening has to guard and shape-check the compiled value before reading it, plus add a circuit breaker for missing/slow extension responses.

Important distinction: the in-repo `Extension` project implements `a2waspwarfare_Extension` / `GLOBALGAMESTATS`; AntiStack uses a separate out-of-repo `A2WaspDatabase` extension.

## BattlEye Filter

`BattlEyeFilter/publicvariable.txt` contains the public-variable rule used for AFK kick behavior. Client `updateclient.sqf` intentionally broadcasts `kickAFK`; BattlEye detects it and kicks because direct serverCommand paths are unavailable/disabled.

This file is feature-specific, not a comprehensive publicVariable hardening layer. The current filter contains only the `kickAFK` rule, so PVF spoofing and direct mission PV channels must not be considered protected by BattlEye until a restrictive whitelist is designed and tested.

Claude DR-30 closed the remediation loop: as shipped in this repo, the "rely on BattlEye" option is not implemented. No `scripts.txt`, `server.cfg`, `basic.cfg` or broader BattlEye filter bundle is present in the tree. Production servers may have external `BEpath` files, but that is an owner/deployment question, not documented source truth.

The filter design should be driven by [Networking and public variables](Networking-And-Public-Variables), including both `WFBE_PVF_*` registered commands and direct channels such as supply missions, day/night, HQ state, attack waves, server FPS, MASH markers and AntiStack compensation. A PV filter alone still will not solve client-side `createVehicle`/`createUnit` authority; that class needs BattlEye `scripts.txt` or a server-authoritative redesign.

## License And CI Posture

Claude Round 16 resolved the external reports' license uncertainty: `LICENSE.md` is a custom/proprietary/source-available license, not an OSI open-source license. Treat redistribution/reuse as restricted unless the repo owner explicitly grants it.

The repo currently has no CI beyond `.github/FUNDING.yml`. Useful checks for this project would be:

- .NET builds for `Tools/LoadoutManager`, `DiscordBot` and `Extension` where the platform/toolchain is available;
- generated-mission drift checks after LoadoutManager runs;
- SQF/string reference checks for `preprocessFileLineNumbers`, `execVM`, `ExecFSM` and dialog `onLoad` paths;
- wiki machine-file validation for `agent-context.json`, `agent-status.json`, `agent-collaboration.json` and `agent-events.jsonl`.

## Public Server Metadata

The repo README lists:

- IP: `144.76.185.231`
- Port: `2302`
- Server name: `Miksuu's Warfare | CTI TvT PvE | discord.me/warfare`
- BattleMetrics and GameTracker links
- Trello board link

## Continue Reading

Previous: [Tools/build](Tools-And-Build-Workflow) | Next: [Feature status](Feature-Status-Register)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
