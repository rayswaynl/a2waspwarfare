# Discord Bot Instrumented-Variable Logging Framework

> Source-verified 2026-06-21 against master 0139a346. Paths relative to the repo root (root here: `DiscordBot/`). Arma 2 OA 1.64.

The Discord status bot (`DiscordBot/`) ships a small self-contained instrumentation subsystem under `DiscordBot/src/LoggingSystem/` whose purpose is to make *variable reads and writes* trace themselves. Instead of a developer hand-writing a `Log.WriteLine(...)` call on every assignment, a field is wrapped in a generic "log variable" type (`logVar<T>` and friends); the wrapper's `GetValue`/`SetValue` methods automatically emit a log line tagged with the **exact caller source file, method name and line number** via C# caller-info attributes. The existing operator reference ([Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) section 12) documents the log *sinks* (console / `.logs/` files / Discord channel) and the `LogLevel` enum table, but does **not** document these wrapper classes or the auto-tracing mechanism. This page fills that gap.

This is a C#/.NET tooling artifact (the out-of-game status bot), not runtime mission SQF. The framework is generic and library-style: most of the wrapper types are present in the tree but unused by the live bot (see Live Footprint below).

## Wrapper Classes (`DiscordBot/src/LoggingSystem/CustomVariables/`)

Each wrapper is a `[DataContract]` type holding a `[DataMember]` private backing field, exposing `GetValue`/`SetValue` accessors that log on every access, plus a `GetParameter()` string-projection used for serialization/display. Collection wrappers also add an `Add()` accessor.

| Class | File:line | Backing field | Accessors that log | Notes |
|---|---|---|---|---|
| `logVar<T>` | `logVar.cs:5` | `T? _value` (`:7`) | `GetValue` → `GET_VERBOSE` (`:26-34`), `SetValue` → `SET_VERBOSE` (`:36-44`) | The base wrapper. `GetParameter()` returns `_value?.ToString() ?? "[null]"` (`:46-49`). |
| `logString` | `logString.cs:7` | `string? _value` (`:9`) | `GetValue` → `GET_VERBOSE` (`:23-30`), `SetValue` → `SET_VERBOSE` (`:32-39`) | The value-arg ctor logs a "Creating logString" line at `SET_VERBOSE` (`:14`). |
| `logEnum<T>` | `logEnum.cs:6` | `T? _value` where `T : struct, Enum` (`:9`) | `GetValue` → `GET_VERBOSE` (`:22-30`), `SetValue` → `SET_VERBOSE` (`:32-40`) | Value ctor logs "Creating logEnum" at `SET_VERBOSE` (`:18`). |
| `logConcurrentBag<T>` | `logConcurrentBag.cs:9` | `ConcurrentBag<T> _values` (`:11`) | `GetValue`/`SetValue` → `GET_VERBOSE` (`:52-73`), `Add` → `ADD_VERBOSE` (`:75-84`) | `IEnumerable<T>`. `GetParameter()` (`:20-49`) stringifies members, recursing into `logVar<T>` elements. |
| `logConcurrentDictionary<TKey,TValue>` | `logConcurrentDictionary.cs:8` | `ConcurrentDictionary<TKey,TValue> _values` (`:10`) | `GetValue` → `GET_VERBOSE` (`:56-65`), `SetValue` → `SET_VERBOSE` (`:67-77`), `Add` → `ADD_VERBOSE` (`:79-91`) | `IEnumerable<KeyValuePair<>>`. `Add` uses `TryAdd` (`:90`). |

### How a wrapper traces its caller

Every accessor declares three optional parameters decorated with compiler-info attributes; the compiler fills them at each call site, so the wrapper learns where it was touched without the caller passing anything. From `logVar.cs:26-44`:

```csharp
public T GetValue(
    [CallerFilePath]   string _filePath   = "",
    [CallerMemberName] string _memberName = "",
    [CallerLineNumber] int    _lineNumber = 0)
{
    Log.WriteLine("Getting " + _value?.GetType() + " " + _memberName + ": " +
                _value, LogLevel.GET_VERBOSE, _filePath, "", _lineNumber);
    return _value;
}
```

The `[CallerFilePath]`/`[CallerMemberName]`/`[CallerLineNumber]` triple (`System.Runtime.CompilerServices`, imported at `logVar.cs:1`) is the mechanism behind the whole framework: a read or write of a wrapped field produces a `Getting …` / `Setting …` log line stamped with the consumer's file, method and line — not the wrapper's own. Reads log at `GET_VERBOSE`, writes at `SET_VERBOSE`, and collection inserts at `ADD_VERBOSE` (see the level table below).

## The Log Pipeline (`DiscordBot/src/LoggingSystem/Log.cs`)

The wrappers funnel into one static sink. `Log.WriteLine` (`Log.cs:8-41`) carries the **same** caller-info triple, with defaults, so the wrapper forwards its already-captured `_filePath`/`_lineNumber` straight through (passing `""` for the member-name slot, since the wrapper supplies the member text inside the message string).

| Concern | Behaviour | Source |
|---|---|---|
| Default level | `LogLevel.VERBOSE` when no level passed | `Log.cs:10` |
| Timestamp | `dd.MM.yyyy` date + `hh:mm:ss.fff` time, `CultureInfo.CurrentCulture` | `Log.cs:15-18` |
| Thread tag | `{Thread: <ManagedThreadId>}` | `Log.cs:25` |
| Line format | `<date> <time> {Thread: N} - [LOG \| <LEVEL>] <dashpad> <scriptfile>: <member>(), line N: <message>` | `Log.cs:25-28` |
| Caller script | `Path.GetFileName(_filePath)` (basename only) | `Log.cs:22` |
| File fan-out | writes the per-level file **and** `EVERYTHING` (both `.log`) | `Log.cs:32`, `:61-65` |
| Console | colour-coded via `Pastel` per level (`GetColorCode`) | `Log.cs:30,34,43-59` |
| Discord channel gate | sends to `#log` only if `_logLevel <= LoggingParameters.BotLogDiscordChannelLevel` | `Log.cs:37-40` |

The dash-padding token between `[LOG | LEVEL]` and the script name comes from `LogLevelNormalization.logLevelNormalizationStrings[_logLevel]` (`Log.cs:26`) — see below.

### File fan-out detail

`WriteToFileLogFile` (`Log.cs:61-65`) writes **two** files per call: `<LEVEL>.log` (e.g. `GET_VERBOSE.log`) and `EVERYTHING.log`. Both go under `FileConfiguration.LogsPath`, which is the exe-relative `".logs/"` (`FileConfiguration.cs:4`). `FileManager.CheckIfDirectoryExistsAndAppendToTheFile` (`FileManager.cs:21-34`) creates `.logs/` on demand, prepends a newline, and appends via `FileManager.AppendText`, which opens the file `FileMode.Append, FileAccess.Write, FileShare.Write` (`FileManager.cs:6-19`).

> Note the exe-relative `.logs/` here is distinct from the in-batch Extension DLL's logging subsystem, which writes to an absolute `C:\a2waspwarfare\Logs\` and uses a different 10-level enum with a `CRITICAL` level. See [GLOBALGAMESTATS Extension Reference](GLOBALGAMESTATS-Extension-Reference). They are two separate logging stacks, not one shared system.

## Log Levels (`DiscordBot/src/LoggingSystem/LogLevel.cs`)

The bot's enum has **9** values, `ERROR=0` most severe (`LogLevel.cs:1-12`). The four high-frequency `*_VERBOSE` levels are exactly the ones the instrumented wrappers emit at, which is why they exist:

| Value | Constant | Emitted by | Console colour |
|---|---|---|---|
| 0 | `ERROR` | fatal/unrecoverable | Red (`Log.cs:47`) |
| 1 | `WARNING` | unexpected but survivable | Orange (`Log.cs:48`) |
| 2 | `IMPORTANT` | key lifecycle | Gold (`Log.cs:49`) |
| 3 | `SERIALIZATION` | DB serialize/deserialize | Blue (`Log.cs:50`) |
| 4 | `DEBUG` | detailed step tracing | Green (`Log.cs:51`) |
| 5 | `ADD_VERBOSE` | collection `Add()` (`logConcurrentBag`/`Dictionary`) | DarkBlue (`Log.cs:52`) |
| 6 | `SET_VERBOSE` | wrapper `SetValue()` / value ctors | DarkTeal (`Log.cs:53`) |
| 7 | `GET_VERBOSE` | wrapper `GetValue()` | Teal (`Log.cs:54`) |
| 8 | `VERBOSE` | `Log.WriteLine` default | Purple (`Log.cs:55`) |

Because the `*_VERBOSE` levels are numerically the *largest* and the Discord gate is `_logLevel <= BotLogDiscordChannelLevel` (default `WARNING = 1`, `LoggingParameters.cs:4`), instrumented-variable traces are **never** forwarded to the Discord channel — they only reach the console and the `.logs/` files. That gate is the practical reason the variable-tracing noise stays out of the `#log` channel.

## Level-Label Alignment (`DiscordBot/src/LoggingSystem/LogLevelNormalization.cs`)

To keep log columns aligned regardless of level-name width, `LogLevelNormalization` precomputes a dash string per level: for each `LogLevel` it emits `highestCount - name.Length` dashes, with `highestCount = 13` (`LogLevelNormalization.cs:4,8-23`). The table is built once by `InitLogLevelNormalizationStrings()` at startup (called from `ProgramRuntime.cs:11`, per [Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) section 5). `Log.WriteLine` then indexes it (`Log.cs:26`). The width-13 constant carries a `// Could automate this, maybe unnecessary` note (`LogLevelNormalization.cs:3`) — it is hand-tuned to the longest level name (`SERIALIZATION`, 13 chars).

## Routing Parameters (`DiscordBot/src/LoggingSystem/LoggingParameters.cs`)

Two static `LogLevel` thresholds, both defaulting to `WARNING` (`LoggingParameters.cs:1-9`):

| Field | Default | Effect | Source |
|---|---|---|---|
| `BotLogDiscordChannelLevel` | `WARNING` (1) | a line is sent to the `#log` channel only if its level `<=` this | `LoggingParameters.cs:4`, gate at `Log.cs:37` |
| `BotLogWarnAdminsLevel` | `WARNING` (1) | a line at or below this prepends an admin ping in the channel message | `LoggingParameters.cs:8`, used at `BotMessageLogging.cs:13-16` |

The channel send itself is `BotMessageLogging.SendLogMessage` (`BotLoggingFeatures/BotMessageLogging.cs:8-39`): it wraps the message in a Discord code fence, pings the hardcoded user `111788167195033600` for warn-level lines (`:15`), and only actually sends when `BotReference.Instance.ConnectionState` is true and `loggingChannelId != 0` (`:21,26`). `loggingChannelId` defaults to `0` (`:5`) and has no `preferences.json` setter, so the channel sink is inert unless set in code — the same caveat the operator reference records in section 12.

## Live Footprint — Mostly Unused Library

This is important for anyone reading the tree: **only `logVar<bool>` is actually wired into the running bot.** A repo-wide grep for `new logVar`/`logString`/`logEnum`/`logConcurrentBag`/`logConcurrentDictionary` finds a single live instantiation:

| Consumer | Source | Detail |
|---|---|---|
| `BotReference.connectionState` | `BotReference.cs:17` | `private logVar<bool> connectionState = new logVar<bool>();`, surfaced through the `ConnectionState` property (`BotReference.cs:7-11`) whose getter/setter call `connectionState.GetValue()` / `.SetValue(value)`. |

So in practice the bot's connection-state flag is the one variable that traces its own reads/writes (each access emits a `GET_VERBOSE`/`SET_VERBOSE` line with the touching method's file and line). `logString`, `logEnum<T>`, `logConcurrentBag<T>` and `logConcurrentDictionary<TKey,TValue>` are present and compiled but have **no consumers** in `DiscordBot/` — they are shared-style scaffolding (the cross-recursion in `logConcurrentBag.GetParameter` at `:40` and `logConcurrentDictionary.GetParameter` at `:35,44` expects nested `logVar<T>` elements that the bot never constructs). Treat them as a generic library carried alongside the bot, not as active instrumentation.

## Continue Reading

- [Discord Status Bot Setup And Reference](Discord-Status-Bot-Setup-And-Reference) — operator reference whose section 12 documents the log sinks and `LogLevel` table this framework feeds
- [GLOBALGAMESTATS Extension Reference](GLOBALGAMESTATS-Extension-Reference) — the separate Extension-DLL logging stack (`C:\a2waspwarfare\Logs\`, distinct enum)
- [Tools And Build Workflow](Tools-And-Build-Workflow) — how to build `DiscordBot` and the other C# tools from source
- [Integration Trust Boundary Audit](Integration-Trust-Boundary-Audit) — bot/extension/database trust boundaries and the JSON deserialization surface
- [External Integrations](External-Integrations) — full security/trust-boundary analysis of the bot and extension pipeline
