# GLOBALGAMESTATS Extension — Build, Deployment, and Data Contract Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Extension/ and DiscordBot/ paths are relative to the repo root. Arma 2 OA 1.64.

The WASP Warfare stats pipeline is a three-part system: the Arma 2 server calls an unmanaged x86 .NET DLL once per minute, the DLL writes `database.json` to disk, and a separate DiscordBot process reads that file and updates a Discord channel embed plus channel name. This page is the canonical reference for building the DLL, deploying it to the server, and understanding the exact data contract all three components share.

---

## 1. Extension Overview

| Item | Value | Source |
|------|-------|--------|
| DLL name on disk | `a2waspwarfare_Extension.dll` | Extension/Extension.csproj:11 (AssemblyName=Extension; rename required) / Server/CallExtensions/GlobalGameStats.sqf:22 |
| Arma extension handle in SQF | `"a2waspwarfare_Extension"` | Server/CallExtensions/GlobalGameStats.sqf:22 |
| Exported symbol | `_RVExtension@12` (Winapi calling convention) | Extension/src/ExtensionMethods.cs:10 |
| Required architecture | **x86 (32-bit)** — Arma 2 OA is a 32-bit process | Extension/Extension.csproj:33-40 |
| Target framework | **.NET Framework 4.8** | Extension/Extension.csproj:12 |
| Output type | `Library` (class library DLL) | Extension/Extension.csproj:8 |
| Only registered extension name | `GLOBALGAMESTATS` | Extension/src/BaseExtensionClass/ExtensionName.cs:3 |

---

## 2. Build Prerequisites and Toolchain

### Why `dotnet build` Will Not Work

The extension uses `RGiesecke.DllExport` (NuGet package `UnmanagedExports`) to inject the `_RVExtension@12` export symbol into the DLL. This package relies on MSBuild target injection — it imports its own `.targets` file at the bottom of the `.csproj` (Extension/Extension.csproj:85). The `dotnet` CLI does not invoke the full classic MSBuild pipeline that this target hook requires. **You must build with Visual Studio 2019/2022 or `msbuild.exe` from a Visual Studio installation.**

### NuGet Package Layout

The `.csproj` references packages from a sibling `../packages/` directory (one level above the `Extension/` folder, i.e. the repo root's `packages/` directory). Packages must be restored with `nuget restore` before building.

| Package | Version | Expected hint path |
|---------|---------|-------------------|
| `Newtonsoft.Json` | 13.0.3 | `../packages/Newtonsoft.Json.13.0.3/lib/net45/Newtonsoft.Json.dll` |
| `UnmanagedExports` (`RGiesecke.DllExport.Metadata`) | 1.2.7 | `../packages/UnmanagedExports.1.2.7/lib/net/RGiesecke.DllExport.Metadata.dll` |

Sources: Extension/Extension.csproj:42-48, Extension/src/packages.config:3-4.

### Build Configurations

| Configuration | Platform | Output path | Use |
|--------------|----------|-------------|-----|
| `Debug\|AnyCPU` | AnyCPU | `bin\Debug\` | Local dev only — **not** for server deploy |
| `Release\|AnyCPU` | AnyCPU | `bin\Release\` | Compiles but may not export correctly without x86 target |
| `Debug\|x86` | x86 | `bin\x86\Debug\` | |
| `Release\|x86` | x86 | `bin\x86\Release\` | **Required for server deployment** |

Source: Extension/Extension.csproj:16-40.

Always build the `Release|x86` configuration for server deployment. The x86 platform target is mandatory because Arma 2 OA's extension loader is 32-bit.

### Build Steps

```
cd <repo-root>
nuget restore Extension\Extension.csproj
msbuild Extension\Extension.csproj /p:Configuration=Release /p:Platform=x86
```

Output: `Extension\bin\x86\Release\Extension.dll`

Rename the output file to `a2waspwarfare_Extension.dll` before copying to the server — the Arma SQF calls the extension by that name (Server/CallExtensions/GlobalGameStats.sqf:22).

---

## 3. Deployment

### File Placement on the Arma Server

Arma 2 OA loads extensions from the server's root directory (where `arma2oaserver.exe` resides) or from paths declared in the server's `Extensions` config key. The DLL must be named exactly `a2waspwarfare_Extension.dll`.

Place the file in the same directory as `arma2oaserver.exe`.

### Runtime Directories

The Extension hardcodes two server-local paths. These directories are created automatically if they do not exist (Extension/src/FileManager.cs:29-44), but the drive and parent path `C:\a2waspwarfare\` must be present.

| Purpose | Hardcoded path | Source |
|---------|---------------|--------|
| JSON database write location | `C:\a2waspwarfare\Data\database.json` | Extension/src/SerializationManager.cs:12-14 |
| Temp write target (atomic replace) | `C:\a2waspwarfare\Data\database.tmp` | Extension/src/SerializationManager.cs:16-17 |
| Extension log files | `C:\a2waspwarfare\Logs\` | Extension/src/Log.cs:8 |

The DiscordBot reads from the same path by default (`DataSourcePath` in `preferences.json` defaults to `C:\a2waspwarfare\Data` — DiscordBot/src/ExtensionData/GameData/GameData.cs:36 (runtime fallback via `??` operator); DiscordBot/src/Preferences.cs:13 (property declaration); DiscordBot/preferences_sample.json:8 (sample value)).

### Confirming the Extension Loaded (RPT Check)

When the DLL is present and loadable, the first `callExtension` from GlobalGameStats.sqf will produce Extension log entries under `C:\a2waspwarfare\Logs\`. The SQF loop also logs via `WFBE_CO_FNC_LogContent`:

```
Running with old vars GLOBALGAMESTATS: <west_score> | <east_score> | <worldname> | <uptime_seconds> | 0
Done GLOBALGAMESTATS: ...
```

(uptime is `round(time)` at log time; player count is 0 because `_playerCount` is reset before the player loop runs)

If Arma cannot find or load the DLL, `callExtension` silently returns an empty string and the log lines will never appear. Confirm the DLL architecture matches: `dumpbin /headers a2waspwarfare_Extension.dll` should show `machine (x86)`.

---

## 4. Extension Call Pipeline

### SQF Call Site

The entire stats-collection loop lives in a single file launched unconditionally from the server init:

- Launch point: `[] execVM "Server\CallExtensions\GlobalGameStats.sqf";` — Server/Init/Init_Server.sqf:294
- Loop file: Server/CallExtensions/GlobalGameStats.sqf

The loop runs once per 60 seconds (`sleep 60` — GlobalGameStats.sqf:24) for the lifetime of the mission.

### Wire Format

The SQF constructs a comma-separated string and passes it to `callExtension`:

```sqf
"a2waspwarfare_Extension" callExtension format ["%1,%2,%3,%4,%5,%6",_cSharpClassName,_scoreSideWest,_scoreSideEast,_currentMap,_uptime,_playerCount];
```

Source: GlobalGameStats.sqf:22.

The six comma-separated fields the extension receives:

| Field index in raw string | Content | SQF variable | Notes |
|--------------------------|---------|-------------|-------|
| 0 | Extension class name | `_cSharpClassName` = `"GLOBALGAMESTATS"` | GlobalGameStats.sqf:2; consumed by `ExtensionMethods` as the router key — stripped before passing to the implementation |
| 1 | BLUFOR (West) score | `scoreSide west` | GlobalGameStats.sqf:6 |
| 2 | OPFOR (East) score | `scoreSide east` | GlobalGameStats.sqf:7 |
| 3 | World name | `worldName` | GlobalGameStats.sqf:3; captured once at script start, not per-loop |
| 4 | Server uptime (seconds) | `round(time)` | GlobalGameStats.sqf:8 |
| 5 | Player count (adjusted) | see §5 | GlobalGameStats.sqf:20 |

### Extension Routing (C# side)

`ExtensionMethods.RvExtension` is the single DLL entry point (Extension/src/ExtensionMethods.cs:10-13). It:

1. Calls `ArrayTools.SplitArgsToArray` to split on commas (Extension/src/ArrayTools.cs:10).
2. Reads `splitArgsArray[0]` as the extension name — `"GLOBALGAMESTATS"` (Extension/src/ExtensionMethods.cs:19).
3. Strips the name with `RemoveFirstElement` (Extension/src/ExtensionMethods.cs:20).
4. Resolves the name to a `BaseExtensionClass` instance via `Enum.TryParse` → `ExtensionName.GLOBALGAMESTATS` (Extension/src/ExtensionMethods.cs:29, Extension/src/BaseExtensionClass/ExtensionName.cs:3).
5. Calls `ActivateExtensionMethodAndSerialize`, which stores the args then calls `SerializationManager.SerializeDB()` (Extension/src/BaseExtensionClass/BaseExtensionClass.cs:6-17).

After routing, the `_args` array passed to `GLOBALGAMESTATS.ActivateExtensionMethodOnTheDerivedClass` is a **5-element string array** (field index 0 has been consumed): `[BLUFOR_score, OPFOR_score, worldName, uptime_seconds, player_count]` — Extension/src/BaseExtensionClass/Implementations/GLOBALGAMESTATS.cs:6-11.

---

## 5. Player Count: One-HC Subtraction

The player count sent to the extension is not the raw `BIS_fnc_listPlayers` count. GlobalGameStats.sqf applies two transforms:

```sqf
{
    if (isPlayer _x) then {
        _playerCount = _playerCount + 1;
    }
} forEach call BIS_fnc_listPlayers;

_playerCount = abs(_playerCount - 1); // Exclude headless client
```

Source: GlobalGameStats.sqf:14-20.

| Condition | Effect |
|-----------|--------|
| Standard deployment (1 HC) | Correct: HC is counted by `BIS_fnc_listPlayers`, subtracted by `-1`, result is human players only |
| No HC (listen server / dev) | `abs(0 - 1)` = `1`, which is wrong — player count will show 1 even with 0 players |
| Two HCs (not a standard WASP setup) | Subtracts only one; the second HC is counted as a human player |

The `abs()` prevents a negative result but does not prevent the no-HC off-by-one. Operators running without a headless client will see the Discord status show one extra phantom player.

---

## 6. `ArrayTools.SplitArgsToArray` — `RemoveEmptyEntries` Behavior

```csharp
return _argsString.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
```

Source: Extension/src/ArrayTools.cs:10.

`StringSplitOptions.RemoveEmptyEntries` discards any empty token produced by adjacent commas or a trailing comma. This is significant: if the SQF passes a value that resolves to an empty string (e.g. `worldName` is empty on an unusual map), that slot is silently dropped. The resulting `_args` array will be shorter than expected, and index-based field reads in `GLOBALGAMESTATS` or the DiscordBot `GameData` will read from the wrong position or throw an `IndexOutOfRangeException`.

Known safe values: `scoreSide west/east` always returns a number; `worldName` is always a non-empty string in a running mission; `round(time)` is always a number.

---

## 7. `exportedArgs` Array — Extension vs. DiscordBot Drift

The same field is declared in two places with different default sizes:

| Component | File | Declaration | Default size |
|-----------|------|-------------|-------------|
| Extension (write side) | Extension/src/GameData.cs:29 | `[DataMember] public string[] exportedArgs = new string[2];` | **2** |
| DiscordBot (read side) | DiscordBot/src/ExtensionData/GameData/GameData.cs:30 | `[DataMember] private string[] exportedArgs = new string[4];` | **4** |

The Extension-side default `new string[2]` is overwritten on first call by the 5-element `_args` array from the SQF (GLOBALGAMESTATS.cs:19), so the default size is irrelevant in normal operation. However, the DiscordBot reads `database.json` written by the Extension: if the JSON was written before any SQF call populated `exportedArgs`, the DiscordBot deserializes an array of 2 null slots. All DiscordBot `GameData` accessors guard for this (DiscordBot/src/ExtensionData/GameData/GameData.cs:80, 112, 150-153, 167-170, 184-186), falling back to `"0"` for scores, `"00:00:00"` for uptime, `"TAKISTAN"` for terrain, and `"0"` for player count.

The DiscordBot player count accessor checks `exportedArgs.Length > 4` (index 4 requires length of at least 5) — DiscordBot/src/ExtensionData/GameData/GameData.cs:80. Since the Extension stores a 5-element array starting from the first SQF call, this check passes in steady state.

---

## 8. Serialization: `SerializeDB` and Silent Failure Risk

```csharp
public static async void SerializeDB()
{
    await semaphore.WaitAsync();
    // ...
    File.Replace(dbTempPathWithFileName, dbPathWithFileName, null);
    // ...
}
```

Source: Extension/src/SerializationManager.cs:20-68.

`SerializeDB` is declared `async void`. This means any unhandled exception inside the method is swallowed — the caller (`BaseExtensionClass.ActivateExtensionMethodAndSerialize`) receives no signal that the write failed. The method throws `InvalidOperationException` inside the try/catch and logs it (SerializationManager.cs:61-62), but `async void` exceptions that cross an async boundary are unobservable to callers. In practice: if `database.json` cannot be written (disk full, locked file, missing directory), the SQF `callExtension` call will return without error, the extension log will record a `CRITICAL`-level message, and the DiscordBot will continue serving the last successfully written data silently.

**Mitigation**: monitor `C:\a2waspwarfare\Logs\CRITICAL.log` on the server host.

The write uses an atomic temp-then-replace pattern (SerializationManager.cs:40-55): writes to `database.tmp` first, then `File.Replace` to swap atomically, preventing the DiscordBot from reading a partially written JSON file.

---

## 9. DiscordBot: Terrain Enum Lookup

The world name string from `exportedArgs[2]` (the SQF `worldName` value) is resolved to a terrain class via:

```csharp
return (InterfaceTerrain)EnumExtensions.GetInstance(exportedArgs[2]);
```

Source: DiscordBot/src/ExtensionData/GameData/GameData.cs:156.

`EnumExtensions.GetInstance` uses `Type.GetType(_string.ToUpper())` and `Activator.CreateInstance` (DiscordBot/src/EnumExtensions.cs, mirroring Extension/src/EnumExtensions.cs:11,20). The class name must match the Arma `worldName` value exactly (case-insensitive). If no matching class exists, an `ERROR` log entry is written and an `InvalidOperationException` is thrown (DiscordBot/src/EnumExtensions.cs:13; contrast the Extension side which uses `CRITICAL` — Extension/src/EnumExtensions.cs:15); the DiscordBot guard at GameData.cs:150-153 catches the null case and falls back to `TAKISTAN`.

### Supported Terrain Classes

| Class | `TerrainName` enum | `TerrainType` | `isModdedTerrain` | Max players |
|-------|--------------------|--------------|------------------|-------------|
| `CHERNARUS` | `CHERNARUS` ("Chernarus") | `FOREST` | false | 55 |
| `TAKISTAN` | `TAKISTAN` ("Takistan") | `DESERT` | false | 61 |
| `TAVI` | `TAVI` ("Taviana") | `FOREST` | true | 55 |
| `DINGOR` | `DINGOR` ("Dingor") | `DESERT` | true | 61 |
| `EDEN` | `EDEN` ("Everon") | `FOREST` | true | 55 |
| `LINGOR` | `LINGOR` ("Lingor") | `FOREST` | true | 55 |
| `SMD_SAHRANI_A2` | `SMD_SAHRANI_A2` ("Sahrani") | `FOREST` | true | 55 |
| `TASMANIA2010` | `TASMANIA2010` ("Tasmania") | `FOREST` | true | 55 |
| `ISLADUALA` | `ISLADUALA` ("Isla Duala") | `DESERT` | true | 61 |
| `NAPF` | `NAPF` ("Napf") | `FOREST` | true | 55 |

Sources: DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/TerrainName.cs:1-30; Implementations/BaseMaps/CHERNARUS.cs, TAKISTAN.cs; Implementations/ModdedMaps/EDEN.cs, LINGOR.cs, SMD_SAHRANI_A2.cs, TASMANIA2010.cs, ISLADUALA.cs, NAPF.cs. Max player count derived from `BaseTerrain.DetermineMissionTypeIfItsForestOrDesertAndGetThePlayerCount()` — returns `"55"` for FOREST, `"61"` for DESERT (DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/BaseTerrain.cs:40-48).

The Arma `worldName` value for a given terrain must match the class name (not the `EnumMember` display value). Example: Chernarus's `worldName` in Arma is `Chernarus` — `GetInstance` uppercases it to `CHERNARUS` and instantiates `class CHERNARUS`.

---

## 10. Discord Channel Name Format

The DiscordBot updates the configured `GameStatusChannelID` channel name (DiscordBot/src/GameStatusUpdater.cs:92-96) and the bot's own "Playing" status to a string produced by:

```
{terrain_emoji}  {playerCount}︱{maxPlayerCount}  {terrain_display_name}
```

Source: DiscordBot/src/ExtensionData/GameData/GameData.cs:134.

The embed title uses a slightly different format:

```
{terrain_emoji} [{playerCount}/{maxPlayerCount}] {terrain_display_name}
```

Source: DiscordBot/src/ExtensionData/GameData/GameData.cs:102-103.

The bot updates on a 60-second timer (DiscordBot/src/GameStatusUpdater.cs:9), matching the SQF `sleep 60` interval.

---

## 11. DiscordBot Configuration (`preferences.json`)

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `GuildID` | ulong | required | Discord guild (server) ID |
| `AuthorizedUserIDs` | ulong[] | `[]` | Users allowed to run bot commands |
| `GameStatusChannelID` | ulong? | `null` | Channel whose name and pinned embed are updated |
| `GameStatusMessageID` | ulong? | `null` | Message ID to edit; auto-populated on first run |
| `DataSourcePath` | string? | `"C:\\a2waspwarfare\\Data"` | Directory containing `database.json` |
| `a3Mode` | bool | `false` | Forces max players to 40 regardless of terrain type |

Source: DiscordBot/src/Preferences.cs:9-14; DiscordBot/preferences_sample.json.

---

## 12. Example `database.json` Payloads

**Normal (populated, Chernarus, 32 players, 2h uptime):**
```json
{
  "exportedArgs": ["1200", "850", "Chernarus", "7200", "32"]
}
```

**Degraded — written before first SQF call (Extension-side default size 2):**
```json
{
  "exportedArgs": [null, null]
}
```
DiscordBot response: scores show `0 vs 0`, uptime shows `00:00:00`, terrain falls back to TAKISTAN, player count shows `0`.

**Empty array (unexpected serialization path):**
```json
{
  "exportedArgs": []
}
```
DiscordBot response: all guards trigger, all values fall back to defaults.

The DiscordBot reads `database.json` on every 60-second tick via `GameData.LoadFromFile()` (DiscordBot/src/ExtensionData/GameData/GameDataDeSerialization.cs:13; DiscordBot/src/GameStatusUpdater.cs:84).

---

## Continue Reading

- [Architecture-Overview](Architecture-Overview) — mission component map showing where the extension fits in the server runtime
- [Server-Ops-Runbook](Server-Ops-Runbook) — server deployment checklist including extension and DiscordBot configuration steps
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — WFBE constant naming patterns referenced across server scripts
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — `scoreSide` context: how BLUFOR/OPFOR scores accumulate and what the extension exports
- [Server-Runtime-And-Operations](Server-Runtime-And-Operations) — server init sequence; `Init_Server.sqf:294` in context
