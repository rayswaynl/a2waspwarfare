# GLOBALGAMESTATS Extension Logging Subsystem

> Source-verified 2026-06-21 against master 0139a346. Paths are relative to the repo root (the C# DLL lives under Extension/). Arma 2 OA 1.64.

Every code path inside the WASP Warfare stats-export DLL writes through one static helper, `Log.WriteLine`, which timestamps each line, tags it with a 10-level severity enum, dash-pads the level name into an aligned column, and fans the line out to **two or three** `.log` files under a hardcoded server-local directory. This is a tooling/integration artifact — the C# extension that the Arma server calls once per minute (see [GLOBALGAMESTATS-Extension-Reference](GLOBALGAMESTATS-Extension-Reference)) — not runtime mission SQF. The existing extension reference page mentions only the `Logs\` directory and `CRITICAL.log` in passing; this page documents the logging internals it omits: the enum, the file fan-out, the line format, the `MatchScheduler.cs` carve-out, and the column-alignment normalizer.

This subsystem is **distinct from the DiscordBot's** logging (documented in [Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) §12). The two share a similar design but have different enums (the bot's starts at `ERROR=0` with no `CRITICAL`), a different log directory (`.logs/` relative to the bot exe vs. the Extension's absolute `C:\a2waspwarfare\Logs\`), and different sinks (the bot also writes to console via `Pastel` and a Discord channel).

---

## 1. Entry Point: `Log.WriteLine`

A single static method is the only logging surface. It uses C# caller-attribute parameters so call sites never have to pass their own file/method/line — the compiler injects them.

| Parameter | Default | Source | Notes |
|-----------|---------|--------|-------|
| `_message` | (required) | Extension/src/Log.cs:11 | The log text |
| `_logLevel` | `LogLevel.VERBOSE` | Extension/src/Log.cs:12 | Severity; defaults to the least-severe level when omitted |
| `_filePath` | `[CallerFilePath]` | Extension/src/Log.cs:13 | Compiler-injected absolute source path; reduced to file name via `Path.GetFileName` (Log.cs:24) |
| `_memberName` | `[CallerMemberName]` | Extension/src/Log.cs:14 | Compiler-injected method name |
| `_lineNumber` | `[CallerLineNumber]` | Extension/src/Log.cs:15 | Compiler-injected source line |

Because `_logLevel` defaults to `VERBOSE` (Extension/src/Log.cs:12), any call written as `Log.WriteLine("...")` with no level is a `VERBOSE` line. Severity is therefore opt-in: most informational tracing is `VERBOSE` and only the explicit `LogLevel.X` calls escalate.

The method also unconditionally echoes the formatted line to `Console.WriteLine` (Extension/src/Log.cs:38). In the deployed DLL the host process is `arma2oaserver.exe`, which has no attached console, so the console echo is effectively a no-op on the live server — the `.log` files are the only durable sink.

---

## 2. The `LogLevel` Enum (10 Levels, `CRITICAL = 0`)

The Extension defines its own 10-value severity enum, **lowest numeric value = most severe**.

| Value | Name | Meaning (by usage) |
|-------|------|--------------------|
| 0 | `CRITICAL` | Caught exceptions; the catch-block default across the DLL |
| 1 | `ERROR` | Reserved (no live call site in Extension/src; see §6) |
| 2 | `WARNING` | Reserved (only in commented-out code) |
| 3 | `IMPORTANT` | Reserved (no live call site) |
| 4 | `SERIALIZATION` | DB serialize start/done markers |
| 5 | `DEBUG` | Step tracing (args received, instance lookup, export) |
| 6 | `ADD_VERBOSE` | Reserved |
| 7 | `SET_VERBOSE` | Reserved |
| 8 | `GET_VERBOSE` | Reserved |
| 9 | `VERBOSE` | Default level; un-tagged informational lines |

Source: Extension/src/LogLevel.cs:1-13.

Two facts an operator needs:

1. `CRITICAL = 0` is the most severe level and **the value `WriteToFileLogFile` will route to `CRITICAL.log`**. The DiscordBot's enum has no `CRITICAL` at all (its level 0 is `ERROR`) — do not assume the two share a numbering. See [Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) §12.
2. The enum value is **not** used to filter output — there is no minimum-level threshold. Every call, at every level, is written to disk (see §4). The level only affects the tag text and which per-level file receives a copy.

---

## 3. Log-Line Format

`WriteLine` builds one string (Extension/src/Log.cs:31-34):

```
dd.MM.yyyy hh:mm:ss.fff {Thread: N} - [LOG | LEVEL] <dashpad> <scriptfile>: <member>(), line N: <message>
```

| Segment | Built from | Source |
|---------|-----------|--------|
| `dd.MM.yyyy` | `DateTime.Now.Date.ToString("dd.MM.yyyy", culture)` | Extension/src/Log.cs:19 |
| `hh:mm:ss.fff` | `DateTime.Now.ToString("hh:mm:ss.fff", culture)` | Extension/src/Log.cs:20 |
| `{Thread: N}` | `System.Environment.CurrentManagedThreadId` | Extension/src/Log.cs:31 |
| `[LOG \| LEVEL]` | literal `LOG` + the enum name | Extension/src/Log.cs:31 |
| `<dashpad>` | the alignment dashes from `LogLevelNormalization` (see §5) | Extension/src/Log.cs:32 |
| `<scriptfile>` | `Path.GetFileName(_filePath)` | Extension/src/Log.cs:24 |
| `<member>()` | `": " + _memberName + "()"`, blank if member name empty | Extension/src/Log.cs:22-23 |
| `line N` | the caller line number | Extension/src/Log.cs:34 |
| `<message>` | the caller's text | Extension/src/Log.cs:34 |

Two format gotchas worth noting when grepping these files:

- The time uses **`hh`** (12-hour, no AM/PM marker), not `HH` (Extension/src/Log.cs:20). A line stamped `02:14:…` is ambiguous between 02:00 and 14:00.
- Both date and time format with `CultureInfo.CurrentCulture` (Extension/src/Log.cs:17), so the literal separators/digits follow the server's locale. On the WASP host this resolves to the `dd.MM.yyyy` shown above, but the format string itself is culture-sensitive.

A representative `CRITICAL` line (the catch-block pattern, see §6) looks like:

```
21.06.2026 09:03:11.842 {Thread: 7} - [LOG | CRITICAL] ----- SerializationManager.cs: SerializeDB(), line 61: <exception message>
```

---

## 4. File Fan-Out: Per-Level + `EVERYTHING.log` (+ MatchScheduler)

After formatting, `WriteLine` hands the line to `WriteToFileLogFile`, which appends it to **two files on every call, and a third in one special case** (Extension/src/Log.cs:41-50):

| File written | When | Source |
|--------------|------|--------|
| `<LEVEL>.log` (e.g. `CRITICAL.log`, `SERIALIZATION.log`, `DEBUG.log`, `VERBOSE.log`) | Every call — file name is `_logLevel.ToString()` | Extension/src/Log.cs:43 |
| `EVERYTHING.log` | Every call — the aggregate of all levels | Extension/src/Log.cs:44 |
| `MatchScheduler.cs.log` | Only when the **calling source file** is `MatchScheduler.cs` | Extension/src/Log.cs:46-49 |

So a single `Log.WriteLine(..., LogLevel.CRITICAL)` produces **two** appended lines: one in `CRITICAL.log` and one in `EVERYTHING.log`. `EVERYTHING.log` is the merged, chronological view; the per-level files are the filtered views. For health monitoring of the stats pipeline, `CRITICAL.log` is the file that fills only when something has actually failed (every catch block logs at `CRITICAL` — §6).

### The `MatchScheduler.cs` carve-out is vestigial

The third write keys off `_scriptName == "MatchScheduler.cs"` (Extension/src/Log.cs:46). **There is no `MatchScheduler.cs` anywhere in `Extension/src/`** — `Path.GetFileName([CallerFilePath])` can never equal that string in this fork, so this branch is dead code. It is a fossil of a larger, multi-feature extension this code was forked from: the only extension actually registered here is `GLOBALGAMESTATS` (Extension/src/BaseExtensionClass/ExtensionName.cs, and see [GLOBALGAMESTATS-Extension-Reference](GLOBALGAMESTATS-Extension-Reference) §1). Operators will never see a `MatchScheduler.cs.log` file appear.

---

## 5. Column Alignment: `LogLevelNormalization`

So that the variable-width level names line up into a fixed column, `WriteLine` inserts a run of dashes after the `[LOG | LEVEL]` tag. The dash string per level is precomputed by `LogLevelNormalization`.

- The target width is a hardcoded `highestCount = 13` (Extension/src/LogLevelNormalization.cs:8) — chosen because the longest enum name, `SERIALIZATION`, is exactly 13 characters.
- For each level the dash count is `13 - len(levelName)` (Extension/src/LogLevelNormalization.cs:18-21), stored in a `Dictionary<LogLevel, string>` (Extension/src/LogLevelNormalization.cs:10, 25).
- The dictionary is **lazily initialized**: `WriteLine` calls `InitLogLevelNormalizationStrings()` only if the requested level is not yet a key (Extension/src/Log.cs:26-29). The first log call of the process populates the whole table for all levels at once.

Resulting dash padding (so columns align to width 13):

| Level | Name length | Dashes appended |
|-------|-------------|-----------------|
| `CRITICAL` | 8 | 5 (`-----`) |
| `ERROR` | 5 | 8 (`--------`) |
| `WARNING` | 7 | 6 (`------`) |
| `IMPORTANT` | 9 | 4 (`----`) |
| `SERIALIZATION` | 13 | 0 (none) |
| `DEBUG` | 5 | 8 (`--------`) |
| `ADD_VERBOSE` / `SET_VERBOSE` / `GET_VERBOSE` | 11 | 2 (`--`) |
| `VERBOSE` | 7 | 6 (`------`) |

The `[LOG | LEVEL]` prefix itself is **not** padded — only the separate dash token is. So the level name still varies in width inside the brackets; the dashes restore alignment of everything that follows (the script-file column onward).

---

## 6. Who Logs `CRITICAL`: The Catch-Block Pattern

The `CRITICAL` level is the codebase's universal catch-block tag. Almost every `try/catch` in the DLL ends with `Log.WriteLine(_ex.Message, LogLevel.CRITICAL)` before rethrowing as `InvalidOperationException` (or, at the top-level entry point, swallowing and returning). These are the source-verified `CRITICAL` call sites:

| File:line | Context | After logging |
|-----------|---------|---------------|
| Extension/src/ExtensionMethods.cs:31 | Unknown extension name (`Enum.TryParse` failed) | `return` (swallowed) |
| Extension/src/ExtensionMethods.cs:40 | Top-level `RvExtension` catch — the DLL entry point | `return` (swallowed) |
| Extension/src/ExtensionMethods.cs:54 | `GetExtensionInstance` catch | rethrow `InvalidOperationException` |
| Extension/src/SerializationManager.cs:61 | DB serialize/replace failure (disk full, locked file) | rethrow `InvalidOperationException` |
| Extension/src/FileManager.cs:23 | `AppendText` write failure | rethrow `InvalidOperationException` |
| Extension/src/FileManager.cs:78 | `CheckIfFileAndPathExistsAndCreateItIfNecessary` failure | rethrow `InvalidOperationException` |
| Extension/src/EnumExtensions.cs:15 | Terrain/extension type resolution returned null | (continues; throws below) |
| Extension/src/EnumExtensions.cs:23 | `Activator.CreateInstance` returned null | (continues; throws below) |
| Extension/src/EnumExtensions.cs:32 | `GetInstance` catch | rethrow `InvalidOperationException` |
| Extension/src/ArrayTools.cs:14, 29 | Arg-split / first-element-removal failures | rethrow `InvalidOperationException` |
| Extension/src/BaseExtensionClass/BaseExtensionClass.cs:20 | `ActivateExtensionMethodAndSerialize` catch | rethrow `InvalidOperationException` |
| Extension/src/BaseExtensionClass/Implementations/GLOBALGAMESTATS.cs:25 | Arg-export catch | rethrow `InvalidOperationException` |

The non-`CRITICAL` live call sites are sparse: `SERIALIZATION` markers bracket the DB write (Extension/src/SerializationManager.cs:25, 57), and `DEBUG` traces the arg-receipt and instance-lookup steps (Extension/src/ExtensionMethods.cs:16, 49; GLOBALGAMESTATS.cs:17, 21). The `ERROR`, `WARNING`, `IMPORTANT`, and `*_VERBOSE` levels exist in the enum but have **no live producer** in `Extension/src/` — they appear only in commented-out code (e.g. Extension/src/EnumExtensions.cs:50, 65) and in the normalization table. In practice the live files an operator will see are `CRITICAL.log`, `SERIALIZATION.log`, `DEBUG.log`, `VERBOSE.log`, and `EVERYTHING.log`.

A subtle reentrancy note: `FileManager.AppendText`'s own catch logs at `CRITICAL` (Extension/src/FileManager.cs:23), which calls `Log.WriteLine`, which calls back into `AppendText` to write the failure. If the underlying write keeps failing (e.g. the directory is unwritable), this recurses until the second write also throws — the failure is not silently dropped, but it is logged via the very path that is failing.

---

## 7. The Append Primitive: `FileManager.AppendText`

The actual byte-level write is `FileManager.AppendText` (Extension/src/FileManager.cs:6-26):

| Property | Value | Source |
|----------|-------|--------|
| Open mode | `FileMode.Append` | Extension/src/FileManager.cs:11 |
| Access | `FileAccess.Write` | Extension/src/FileManager.cs:11 |
| Share | `FileShare.Write` | Extension/src/FileManager.cs:11 |
| Writer | `StreamWriter.WriteLine` (adds a trailing newline) | Extension/src/FileManager.cs:15 |
| On failure | log `CRITICAL` + throw `InvalidOperationException` | Extension/src/FileManager.cs:23-24 |

`CheckIfDirectoryExistsAndAppendToTheFile` (Extension/src/Log.cs:54-67) is the layer above it: it creates the `Logs\` directory on demand if missing (Extension/src/Log.cs:56-59), builds the path as `<dir><level>.log` (Extension/src/Log.cs:62), and **prepends** `Environment.NewLine` to the content (Extension/src/Log.cs:64). Combined with `StreamWriter.WriteLine` appending a trailing newline, each logged record is bracketed by newlines — files tend to open with a leading blank line and lines are well-separated.

The `FileShare.Write` flag (Extension/src/FileManager.cs:11) shares only the *write* lock, not read. A reader holding the file open for reading can block the extension's append; conversely, tailing the file with a tool that opens it read-only is generally fine. There is no buffering across calls — each `WriteLine` opens, appends, and closes the stream (Extension/src/FileManager.cs:10-18), so the files are flushed line-by-line and safe to tail live.

---

## 8. Directory and Deployment Facts

| Item | Value | Source |
|------|-------|--------|
| Log directory | `C:\a2waspwarfare\Logs\` (hardcoded, absolute) | Extension/src/Log.cs:8 |
| Directory auto-created? | Yes, on first write | Extension/src/Log.cs:56-59 |
| File naming | `<LEVEL>.log`, `EVERYTHING.log` | Extension/src/Log.cs:43-44 |
| Rotation / size cap | None — files grow unbounded | (no truncation logic in Log.cs / FileManager.cs) |

There is no log rotation or size limit anywhere in the subsystem: `EVERYTHING.log` in particular accumulates every line at every level for the lifetime of the deployment and will grow without bound. On a long-running server this file is the one to watch for disk usage. The absolute path differs from the DiscordBot's exe-relative `.logs/` directory (see [Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) §12), so the two components write to different locations even on the same host.

---

## Continue Reading

- [GLOBALGAMESTATS-Extension-Reference](GLOBALGAMESTATS-Extension-Reference) — build, deployment, and data contract for the same DLL; the page this logging detail was missing from
- [Discord-Status-Bot-Setup-And-Reference](Discord-Status-Bot-Setup-And-Reference) — §12 documents the DiscordBot's separate (and differently-numbered) logging enum and sinks
- [Server-Ops-Runbook](Server-Ops-Runbook) — server deployment checklist; where to look on disk when the stats pipeline misbehaves
- [Integration-Trust-Boundary-Audit](Integration-Trust-Boundary-Audit) — the extension/bot JSON write/read boundary that these logs trace
- [Architecture-Overview](Architecture-Overview) — where the stats extension sits in the overall server runtime
