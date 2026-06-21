# Discord Status Bot — Operator Setup and Reference

> Source-verified 2026-06-21 against master cf2a6d6a4. All DiscordBot paths are relative to DiscordBot/ in the repo root (not the Chernarus mission dir). Arma 2 OA 1.64.

The `DiscordBot` component is a .NET 9 executable that reads mission telemetry from a shared JSON file written by the `a2waspwarfare_Extension` Arma extension, and publishes a live status embed to a Discord channel. This page covers everything an operator needs to deploy and run it from scratch.

---

## 1. Prerequisites

### Discord Application

Create a bot application at [discord.com/developers/applications](https://discord.com/developers/applications) and enable all three **Privileged Gateway Intents** (Presence, Server Members, Message Content) under the Bot tab. The bot client is configured with `GatewayIntents.All` — missing any privileged intent will cause the bot to silently misbehave or fail to see guild members.

> `DiscordBot/src/BotReference.cs:51-59` — `SetClientRefAndReturnIt()` constructs `DiscordSocketConfig { GatewayIntents = GatewayIntents.All }`.

### Runtime Dependencies

The bot depends on three NuGet packages. No additional runtime installation is required beyond .NET 9.

| Package | Version | Purpose |
|---|---|---|
| `Discord.Net` | 3.10.0 | Discord gateway and REST client |
| `Newtonsoft.Json` | 13.0.2 | JSON deserialization of `database.json` and `preferences.json` |
| `Pastel` | 4.0.2 | Coloured console log output |

> `DiscordBot/DiscordBot.csproj:16-20`

---

## 2. Local Files Required (not in repo)

Two files must be placed beside the compiled `.exe` before launch. Both are excluded from version control.

### `token.txt`

Contains the Discord bot token, one line, no extra whitespace.

Startup checks in order (`ProgramRuntime.cs:21-35`):

1. `File.Exists("token.txt")` — missing file → ERROR log and immediate return (bot does not start).
2. `string.IsNullOrWhiteSpace(token)` — empty file → ERROR log and immediate return.

**Note:** `GameData` and `Preferences` are loaded before the token check (`ProgramRuntime.cs:14-18`). A missing or malformed `preferences.json` can therefore produce a different failure before the clean missing-token exit. Provide a valid `preferences.json` first.

### `preferences.json`

Singleton read at first access via `Preferences.Instance` (`src/Preferences.cs:24-25`). Parsed with `JsonConvert.DeserializeObject<Preferences>`. A null return is suppressed with `#pragma warning disable CS8603` (`Preferences.cs:28-30`); a malformed file will throw at deserialisation rather than fail cleanly.

The file is written back by `Preferences.SaveToFile()` after `/setup` and when a new status message is created, so it must be writable by the process.

---

## 3. `preferences.json` Field Reference

Sample file: `DiscordBot/preferences_sample.json`.

```json
{
  "GuildID": "440257265941872660",
  "AuthorizedUserIDs": [
    111788167195033600
  ],
  "GameStatusChannelID": null,
  "GameStatusMessageID": null,
  "DataSourcePath": "C:\\a2waspwarfare\\Data",
  "a3Mode": false
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `GuildID` | `ulong` | Yes | — | Discord guild (server) snowflake ID. Used to look up the guild for slash-command registration and status updates. `BotReference.cs:66` |
| `AuthorizedUserIDs` | `ulong[]` | Yes | `[]` | Snowflake IDs of users permitted to run `/setup` and `/cleanup`. All other users receive an ephemeral "not authorized" response. `Preferences.cs:47-50`, `CommandHandler.cs:49,127` |
| `GameStatusChannelID` | `ulong?` | No | `null` | Set automatically by `/setup`. The channel where status embeds are posted and whose name is updated. Leave `null` on first deploy; the bot will fill it in. `Preferences.cs:11` |
| `GameStatusMessageID` | `ulong?` | No | `null` | Set automatically when the first status message is posted. The bot edits this message in place on every 60-second tick. `Preferences.cs:12` |
| `DataSourcePath` | `string?` | No | `C:\a2waspwarfare\Data` | Filesystem path to the directory containing `database.json`. See §5 for the full resolution chain. `Preferences.cs:13` |
| `a3Mode` | `bool` | No | `false` | When `true`, forces the displayed max-player cap to `40` regardless of terrain. See §6. `Preferences.cs:14` |

---

## 4. `botconfig.json` (secondary, lower priority)

`FileConfiguration.cs` provides a secondary data-path source via a `botconfig.json` file beside the `.exe`. It is **only consulted if `Preferences.Instance.DataSourcePath` is null or empty** — if `preferences.json` sets a non-empty path, `botconfig.json` is never read for that field.

```json
{
  "DataSourcePath": "C:\\a2waspwarfare\\Data"
}
```

Resolution order for `FileConfiguration.DataSourcePath` (`FileConfiguration.cs:9-44`):

1. `Preferences.Instance.DataSourcePath` (non-empty) → use it.
2. `customDataPath` (set via `SetCustomDataSourcePath()` at runtime) → use it.
3. `botconfig.json` → if it exists and has a non-empty `DataSourcePath`, use it and cache in `customDataPath`.
4. Hardcoded fallback: `C:\a2waspwarfare\Data`.

**In practice**, the live game-data reader (`GameData.LoadFromFile()`) always goes directly to `Preferences.Instance.DataSourcePath ?? @"C:\a2waspwarfare\Data"` (`GameData.cs:36`). `FileConfiguration.DataSourcePath` is not used by the live status-reader path; only `FileConfiguration.LogsPath` (`.logs/`) is used by the logging system. Treat `botconfig.json` as a dormant helper; **`preferences.json` is the effective config for the running bot**.

---

## 5. Startup Sequence

```
Program.Main()
  └─ ProgramRuntime.ProgramRuntimeTask()         (ProgramRuntime.cs:9)
       ├─ LogLevelNormalization.InitLogLevelNormalizationStrings()  (line 11)
       ├─ GameData.Instance = GameData.LoadFromFile()   (line 15)
       │    └─ reads Preferences.Instance.DataSourcePath  (GameData.cs:36)
       │         └─ reads preferences.json on first access (Preferences.cs:24)
       ├─ client = BotReference.SetClientRefAndReturnIt()  (line 18 / BotReference.cs:51-59)
       ├─ token = File.ReadAllText("token.txt")   (line 28)
       ├─ client.LoginAsync() / client.StartAsync()  (lines 37-38)
       └─ client.Ready event
            ├─ GameDataDeSerialization.DeSerializeGameDataFromExtension()
            │    └─ GameData.LoadFromFile() again  (GameDataDeSerialization.cs:13)
            └─ SetupProgramListenersAndSchedulers()       (ProgramRuntime.cs:63-73)
                 ├─ CommandHandler.InstallCommandsAsync()
                 │    └─ registers /setup and /cleanup as guild commands  (CommandHandler.cs:7-35)
                 └─ GameStatusUpdater.StartGameStatusUpdates(client)
                      └─ starts 60-second update timer  (GameStatusUpdater.cs:14-25)
```

The process blocks indefinitely on `await Task.Delay(-1)` (`ProgramRuntime.cs:60`). Stop it via the process manager (SIGTERM/task kill); no graceful shutdown path exists in the current source.

### Failure Modes at Startup

| Symptom | Cause | Fix |
|---|---|---|
| "Token file 'token.txt' not found" (ERROR) | `token.txt` missing | Create the file beside the `.exe` |
| "Token file 'token.txt' is empty" (ERROR) | `token.txt` has no content | Add the bot token |
| Exception before the token check | `preferences.json` missing or malformed | Provide a valid `preferences.json` first |
| Bot connects but slash commands fail | `GuildID` wrong in `preferences.json` | Check the guild ID in Discord (right-click server → Copy Server ID with developer mode on) |
| Bot connects but status never posts | `GameStatusChannelID` is null (not yet configured) | Run `/setup` in the target channel |
| Gateway privileged intent errors | Intents not enabled on the Discord application | Enable all privileged intents in the Discord Developer Portal → Bot page |

---

## 6. Slash Commands

Both commands are registered as **guild commands** (not global) against `Preferences.Instance.GuildID` (`CommandHandler.cs:24-25`). They are registered every time the bot reaches `Ready`. Authorization is checked via `Preferences.Instance.IsUserAuthorized(userId)` which returns `AuthorizedUserIDs.Contains(userId)` (`Preferences.cs:47-50`).

### `/setup`

Sets the channel where the command is issued as the game-status channel. Authorized users only (`CommandHandler.cs:43-119`).

What it does:
1. Records `command.Channel.Id` as `Preferences.Instance.GameStatusChannelID`.
2. Computes the channel name string from the in-memory `GameData.Instance` via `GetGameMapAndPlayerCountWithEmojiForChannelName()` (`CommandHandler.cs:64`).
3. Renames the channel via `guildChannel.ModifyAsync()`.
4. Sets the bot's presence activity via `client.SetGameAsync(newChannelName, null, ActivityType.Playing)`.
5. Calls `CreateGameStatusEmbed()`, which performs a fresh `GameData.LoadFromFile()` before building the embed (`CommandHandler.cs:211`).
6. Posts the initial status embed to the channel.
7. Saves the resulting message ID to `Preferences.Instance.GameStatusMessageID`.
8. Calls `Preferences.SaveToFile()` to persist both IDs to `preferences.json`.
9. Responds with an ephemeral confirmation.

**The bot must have `Manage Channels` and `Send Messages` permissions in the target channel.** Missing permissions on message send (step 6) produce Discord HTTP 403 errors caught at `CommandHandler.cs:98-107` with specific user-facing messages. A 403 on channel rename (step 3) has no local catch and propagates to the outer `SlashCommandHandler` catch at line 189, producing a generic error ephemeral. Ensure the bot has Manage Channels and Send Messages permissions to avoid both.

### `/cleanup`

Removes duplicate status embeds from the current channel. Authorized users only (`CommandHandler.cs:121-181`).

What it does:
1. Fetches the **last 50 messages** in the current channel (`CommandHandler.cs:139`).
2. Filters for bot-authored messages whose embed title contains `Chernarus` or `Takistan` (case-insensitive), or whose embed description contains `Score:` (`CommandHandler.cs:141-148`).
3. Keeps the **newest** matching message; deletes all older ones (`CommandHandler.cs:157`).
4. Responds with a count of deleted messages.

**Warning:** the title/description heuristic (`CommandHandler.cs:144-147`) can match any embed the bot posted with those strings — including embeds from other channels if the channel is shared. Prefer running `/cleanup` only in the dedicated status channel, and only after `/setup` has been run to pin a message ID.

---

## 7. 60-Second Update Loop

Started by `GameStatusUpdater.StartGameStatusUpdates()` after `Ready`. The timer fires every 60 seconds (`GameStatusUpdater.cs:9` — `UPDATE_INTERVAL_SECONDS = 60`). A `SemaphoreSlim(1,1)` prevents overlapping updates; if the previous tick has not finished, the new tick is skipped with a DEBUG log (`GameStatusUpdater.cs:30-33`).

Each tick (`UpdateGameStatus()`, `GameStatusUpdater.cs:52-158`):

1. Reads `Preferences.Instance.GameStatusChannelID`; if null, skips with DEBUG log.
2. Calls `GameData.LoadFromFile()` to get fresh data from `database.json`.
3. Computes new channel name and embed (see §8).
4. Calls `guild.GetChannel(...).ModifyAsync()` with a 30-second `CancellationTokenSource` timeout (`GameStatusUpdater.cs:93-97`).
5. Calls `client.SetGameAsync()` for bot presence — **no timeout is applied** to this call (`GameStatusUpdater.cs:100-107`).
6. Tries to edit `GameStatusMessageID` in place. If the message is not found (deleted externally), creates a new message and updates `preferences.json`.

Timeout counter: `consecutiveTimeouts` increments on each `TaskCanceledException` or unexpected exception but is **never reset to zero except on a successful message update or new-message creation** (`GameStatusUpdater.cs:121`). It is also reset to zero in `CreateNewStatusMessage()` (`GameStatusUpdater.cs:176`) when a replacement message is created successfully. It is only a diagnostic counter — no circuit breaker is implemented in the current source.

---

## 8. Embed and Channel-Name Format

The embed is built by `GameStatusMessage.GenerateMessage()` (`GAMESTATUSMESSAGE.cs:17-23`) and `CreateGameStatusEmbed()` (shared between `GameStatusUpdater.cs:195-208` and `CommandHandler.cs:208-224`).

### Channel Name

```
<emoji>  <playerCount>︱<maxPlayerCount>  <TerrainDisplayName>
```

Separator between counts is U+FE30 TWO DOT LEADER (`︱`) — a Unicode character, not a pipe — following the literal spaces in `GameData.cs:134`.

Example: `🌲  12︱55  Chernarus` or `🏜️  8︱61  Takistan`

| Token | Source |
|---|---|
| Terrain emoji (`🌲` / `🏜️`) | `EmojiName.EVERGREENTREE` / `EmojiName.DESERT` (`EmojiName.cs:14,18`) |
| `playerCount` | `exportedArgs[4]` from `database.json`; falls back to `"0"` if absent or short array (`GameData.cs:80-83`) |
| `maxPlayerCount` | Terrain `DetermineMissionTypeIfItsForestOrDesertAndGetThePlayerCount()` → `"55"` (FOREST) or `"61"` (DESERT) (`BaseTerrain.cs:40-48`); or `"40"` when `a3Mode` is `true` (see §9) |
| Terrain display name | `TerrainName` enum's `EnumMember(Value)` string (e.g., `"Chernarus"`, `"Takistan"`) (`TerrainName.cs`) |

### Embed Title

Same content as the channel name, but using a different format string (without the `︱` separator) — see `GetGameMapAndPlayerCountWithEmoji()` (`GameData.cs:74-103`):

```
<emoji> [<playerCount>/<maxPlayerCount>] <TerrainDisplayName>
```

### Embed Description

```
Score: <BLUFOR_emoji><bluforScore> vs <opforScore><OPFOR_emoji>
Uptime: HH:MM:SS

Please balance the teams accordingly!
```

| Token | Source |
|---|---|
| BLUFOR emoji | Custom Discord emoji `<:blufor_icon:1079531790873673819>` (`EmojiName.cs:8`) |
| OPFOR emoji | Custom Discord emoji `<:opfor_icon:1079531788319330304>` (`EmojiName.cs:11`) |
| `bluforScore` / `opforScore` | `exportedArgs[0]` / `exportedArgs[1]`; fallback `"0"` (`GameData.cs:165-171`) |
| Uptime | `exportedArgs[3]` parsed as `ulong` seconds, formatted via `TimeService`; fallback `"00:00:00"` (`GameData.cs:181-193`) |

### Embed Color

| Condition | Color |
|---|---|
| `TerrainType.FOREST` (Chernarus etc.) | `Color.DarkGreen` |
| `TerrainType.DESERT` (Takistan etc.) | `Color.Gold` |

> `GAMESTATUSMESSAGE.cs:31-41`

### Footer

`"Last updated at: " + DateTime.UtcNow.ToLongTimeString() + " " + DateTime.UtcNow.ToLongDateString() + " (GMT+0)"` (`GAMESTATUSMESSAGE.cs:26-29`).

---

## 9. `a3Mode` Flag

When `Preferences.a3Mode` is `true`, `GetGameMapAndPlayerCountWithEmoji()` and `GetGameMapAndPlayerCountWithEmojiForChannelName()` both substitute `"40"` for `maxPlayerCount` regardless of which terrain is loaded (`GameData.cs:87-89`, `GameData.cs:119-121`).

This was added to support displaying an Arma 3 mission cap without changing the Arma 2 terrain config. **It has no effect on the mission itself** — only on the displayed max-player count in the Discord channel name, embed title, and bot presence. Default is `false` (`Preferences.cs:14`).

---

## 10. Data Pipeline: Mission → Extension → Bot → Discord

The full telemetry chain:

```
Server/CallExtensions/GlobalGameStats.sqf   (mission side)
  └─ runs in a while {true} loop, sleep 60 each iteration
  └─ builds callExtension string: "GLOBALGAMESTATS,<west>,<east>,<map>,<uptime>,<playerCount>"
  └─ "a2waspwarfare_Extension" callExtension <string>         (line 22)

a2waspwarfare_Extension DLL  (Extension/ in repo)
  └─ ExtensionMethods._RVExtension@12()    (ExtensionMethods.cs:10)
  └─ splits on comma, resolves "GLOBALGAMESTATS" enum
  └─ GLOBALGAMESTATS.ActivateExtensionMethodOnTheDerivedClass()
       └─ GameData.Instance.exportedArgs = _args   (GLOBALGAMESTATS.cs:19)
  └─ SerializationManager.SerializeDB()    (via BaseExtensionClass)
       └─ writes temp file then File.Replace → C:\a2waspwarfare\Data\database.json
          TypeNameHandling.None            (SerializationManager.cs:33)

DiscordBot  (60-second poll)
  └─ GameData.LoadFromFile()  reads C:\a2waspwarfare\Data\database.json
     TypeNameHandling.All  ← security caveat, see External-Integrations
  └─ updates channel name, bot presence, edits or creates status embed
```

### `exportedArgs` Array Index Map

| Index | Mission variable | Bot reader location | Fallback |
|---|---|---|---|
| `[0]` | `_scoreSideWest` (BLUFOR score) | `GameData.cs:169` | `"0"` |
| `[1]` | `_scoreSideEast` (OPFOR score) | `GameData.cs:170` | `"0"` |
| `[2]` | `worldName` (map name string) | `GameData.cs:150-156` | defaults to `TAKISTAN` |
| `[3]` | `round(time)` (server uptime, seconds) | `GameData.cs:184-191` | `"00:00:00"` |
| `[4]` | `abs(_playerCount - 1)` | `GameData.cs:80-83` | `"0"` |

> Mission source: `Server/CallExtensions/GlobalGameStats.sqf:1-25`. Extension writer: `Extension/src/GameData.cs:29` (array size `new string[2]` — stale declaration; runtime fills all five slots). Bot reader: `DiscordBot/src/ExtensionData/GameData/GameData.cs:30` (array size `new string[4]` — also stale; index `[4]` is guarded at runtime).

**Player-count heuristic:** `GlobalGameStats.sqf:20` uses `abs(_playerCount - 1)` to exclude one assumed headless client. This under-reports on servers with zero or more than one HC, and does not use `WFBE_C_*` gate constants — it is an unconditional arithmetic adjustment.

---

## 11. Supported Terrains

The bot resolves the terrain name from `exportedArgs[2]` (the Arma `worldName` string, compared case-insensitively via `EnumExtensions.GetInstance()`). Unknown world names fall back to `TAKISTAN` (`GameData.cs:151-153`).

| `worldName` value | `TerrainName` | `TerrainType` | Max players (normal) |
|---|---|---|---|
| `Chernarus` | `CHERNARUS` | `FOREST` | 55 |
| `Takistan` | `TAKISTAN` | `DESERT` | 61 |
| `Tasmania` | `TASMANIA2010` | (see class) | varies |
| `Dingor` | `DINGOR` | (see class) | varies |
| `Everon` | `EDEN` | (see class) | varies |
| `Lingor` | `LINGOR` | (see class) | varies |
| `Sahrani` | `SMD_SAHRANI_A2` | (see class) | varies |
| `Taviana` | `TAVI` | (see class) | varies |
| `Isla Duala` | `ISLADUALA` | (see class) | varies |
| `Napf` | `NAPF` | (see class) | varies |

> `TerrainName.cs:1-30`, `BaseTerrain.cs:40-48`, terrain implementation classes in `DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/Implementations/`.

---

## 12. Logging

All log output goes to:

- **Console** (colour-coded by level via `Pastel`).
- **File** under `.logs/` relative to the `.exe` — one file per log level plus an `EVERYTHING` file. `FileConfiguration.cs:3`, `Log.cs:61-65`.
- **Discord channel** — only messages at `WARNING` (1) or below (i.e., `WARNING` and `ERROR`) are sent to a Discord channel if `BotMessageLogging.loggingChannelId` is non-zero. `LoggingParameters.cs:4`. `WARNING`-level messages also ping the hardcoded user ID `111788167195033600` (`BotMessageLogging.cs:13-16`).

**Note:** `BotMessageLogging.loggingChannelId` defaults to `0` (`BotMessageLogging.cs:5`) and has no setter in `preferences.json`. The Discord log channel feature is effectively inactive unless the field is set in code before deployment.

| Log level value | Constant | Meaning |
|---|---|---|
| 0 | `ERROR` | Fatal / unrecoverable |
| 1 | `WARNING` | Unexpected but survivable |
| 2 | `IMPORTANT` | Key lifecycle events |
| 3 | `SERIALIZATION` | DB serialize/deserialize tracing |
| 4 | `DEBUG` | Detailed step tracing |
| 5–8 | `ADD/SET/GET_VERBOSE`, `VERBOSE` | High-frequency variable tracing |

> `LogLevel.cs:1-12`, `LoggingParameters.cs:1-9`

---

## 13. Confirming the Bot Is Working

1. **Console/log:** Look for `"Bot is connected!"` (DEBUG) and `"Program listeners and schedulers setup completed"` (DEBUG) in `ProgramRuntime.cs:45,72`.
2. **Slash commands:** Run `/setup` in the target channel. You should receive an ephemeral confirmation and see the channel renamed immediately.
3. **Embed:** After `/setup`, the initial status embed appears in the channel. The footer timestamp advances every 60 seconds.
4. **Channel name:** Should update every 60 seconds. If the channel name is stuck, check for `"Skipping update - previous update still in progress"` (DEBUG) or timeout warnings (`WARNING`) in the logs.
5. **No embed, no channel rename:** Check `preferences.json` for a non-null `GameStatusChannelID`. If it is null, `/setup` was not completed successfully.
6. **`database.json` not found (WARNING):** The extension DLL has not run yet, or `DataSourcePath` in `preferences.json` points to the wrong directory. The bot will display default/fallback values (`"0"` scores, `"00:00:00"` uptime) until the extension writes data.

---

## Continue Reading

- [External Integrations](External-Integrations) — full security and trust-boundary analysis of the bot, extension, AntiStack database, and BattlEye filter
- [Integration Trust Boundary Audit](Integration-Trust-Boundary-Audit) — `TypeNameHandling.All` deserialization risk in the bot's JSON reader and the in-repo extension writer boundary
- [Tools And Build Workflow](Tools-And-Build-Workflow) — how to build `DiscordBot`, `Extension`, and `LoadoutManager` from source
- [Server Ops Runbook](Server-Ops-Runbook) — deployment checklist and server file layout
- [GLOBALGAMESTATS Extension Reference](GLOBALGAMESTATS-Extension-Reference) — in-batch deep-dive on the extension DLL side of the pipeline
