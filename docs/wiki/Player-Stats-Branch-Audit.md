# Player Stats Branch Audit

This page is a source-backed review of `origin/feat/player-stats` at head `e01e47e1`. It is branch evidence only: the feature is not present on stable `origin/master` and is not propagated to maintained Vanilla Takistan.

## What It Is

`origin/feat/player-stats` adds a dark-launched player statistics pipeline:

- SQF server instrumentation buffers stat deltas per Steam UID.
- A server flush loop emits batched `WASPSTAT|v1|...` lines to the server RPT.
- The in-repo `DiscordBot` tails the RPT, parses batches, accumulates lifetime totals and writes `stats.json`.
- `DiscordBot.Tests` covers the parser, tailer, accumulator, document writer and an end-to-end producer pipeline test.

The branch contains 23 changed files, `+1919/-1`, and `git diff --check origin/master..origin/feat/player-stats` is clean.

## Where It Lives

| Layer | Branch files |
| --- | --- |
| Mission constants | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:442-461` |
| Mission startup | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:300-302` |
| Kill hook | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf:50-69` |
| Stat buffer | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Stats/RecordStat.sqf:1-39` |
| RPT flush loop | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Stats/StatsFlush.sqf:1-50` |
| DiscordBot ingest | `DiscordBot/src/Stats/*`, `DiscordBot/src/Preferences.cs:16-20`, `DiscordBot/src/ProgramRuntime.cs:72-73` |
| Test project | `DiscordBot.Tests/*` |
| Branch design docs | `docs/superpowers/specs/2026-06-02-wasp-player-stats-design.md`, `docs/superpowers/plans/2026-06-02-wasp-player-stats-phase1.md` |

## How It Runs

The mission side is off by default. `Init_CommonConstants.sqf:442-444` defines `WFBE_C_STATS_ENABLED = false` and a 60-second flush interval. The stat index constants run from `WFBE_STAT_KILLS_INFANTRY = 0` through `WFBE_STAT_PLAYTIME = 14`, with `WFBE_STAT_FIELD_COUNT = 15` and `WFBE_STATS_DIRTY_UIDS = []` at `:445-461`.

`Init_Server.sqf:300-302` compiles `Server\Stats\RecordStat.sqf` and starts `Server\Stats\StatsFlush.sqf`. Both are guarded: `RecordStat.sqf:9-10,31-32` exits if stats are undefined or disabled, and `StatsFlush.sqf:6-7` exits before entering its loop unless the feature flag is true.

The current branch only records kill-derived stats. `RequestOnUnitKilled.sqf:51-65` records a stat when stats are enabled and killer side differs from killed side. It attributes to the killer UID when the killer is a player, otherwise to `getPlayerUID (leader _killer_group)`, classifies the victim as infantry/air/static/vehicle, and adds `WFBE_STAT_PVP_KILLS` when the victim is a player.

Every flush cycle, `StatsFlush.sqf:12-26` sleeps for `WFBE_C_STATS_FLUSH_INTERVAL`, credits connected human players with playtime and side, then `:29-49` emits one `diag_log` line for all dirty UIDs in the wire format:

```text
WASPSTAT|v1|<seq>|<uid>:<d0>,...,<d14>,<side>|<uid2>:...
```

The DiscordBot side starts from `ProgramRuntime.cs:72-73`, but `StatsService.Start()` is also off by default. `Preferences.cs:16-20` adds `StatsEnabled = false`, `ServerRptPath`, `StatsJsonPath = C:\a2waspwarfare\Data\stats.json` and `StatsPollSeconds = 60`. `StatsService.cs:17-23` exits unless `StatsEnabled` is true and `ServerRptPath` is set.

## DiscordBot Data Flow

| Component | Evidence | Notes |
| --- | --- | --- |
| `RptTailer` | `RptTailer.cs:24-45`, state load/save at `:57-71` | Reads new bytes from the RPT, persists offset + first-line fingerprint and resets on file shrink or changed first line. |
| `StatsBatchParser` | `StatsBatchParser.cs:10-41` | Looks for `WASPSTAT|v1|`, accepts numeric UID keys of 5-20 digits, requires 15 deltas plus side, skips malformed segments. |
| `StatsAccumulator` | `StatsAccumulator.cs:9-30` | Adds deltas to lifetime totals under lock and saves only when dirty. |
| `StatsDocument` | `StatsDocument.cs:22-40` | Loads existing `stats.json`, returns an empty document on read/deserialization errors, writes temp then `File.Replace`/`File.Move`. |
| `PlayerStat` | `PlayerStat.cs:6-25` | JSON field names and index order must match the SQF constants. |

The branch includes useful tests. I ran:

```powershell
dotnet test "C:\Users\Steff\Documents\Codex\2026-06-01\github-plugin-github-openai-curated-game\work\player-stats-audit\DiscordBot.Tests\DiscordBot.Tests.csproj" --nologo
```

Result: `Passed! - Failed: 0, Passed: 13, Skipped: 0, Total: 13` on .NET 9.0.314. The build emitted nullable warnings in existing DiscordBot files, but the test suite passed.

## What Depends On It

- The DiscordBot must run on, or have file access to, the Arma 2 OA server RPT path.
- A downstream stats consumer must read `stats.json`. The branch design docs describe an existing receiver outside this repo, but this audit only verifies the in-repo producer and DiscordBot pieces.
- Steam UID64 becomes the identity key. That makes UID/privacy policy an owner decision before public enablement.

## Current Status

| Target | Status |
| --- | --- |
| Stable `origin/master` | Absent. `git grep` finds no `WFBE_C_STATS_ENABLED`, `RecordStat`, `StatsFlush` or `WASPSTAT` in mission/DiscordBot source on `origin/master`. |
| Source Chernarus on branch | Present and off by default. |
| Maintained Vanilla Takistan on branch | Absent. `git grep` finds no stats hits under `Missions_Vanilla` on `origin/feat/player-stats`. |
| Modded missions | Not reviewed; treat as absent unless a later branch proves propagation. |
| Static whitespace | Clean. |
| C# tests | Pass locally: 13/13. |
| Arma 2 OA runtime smoke | Not run. |

## Risks And Promotion Gates

This branch is a good candidate for review because it is dark-launched and test-backed, but it should not be enabled publicly until these gates are answered:

| Gate | Why |
| --- | --- |
| Privacy and retention | `stats.json` is keyed by Steam UID64. Decide retention, publication and whether UID-to-name joins happen outside this repo. |
| Runtime log volume | `StatsFlush.sqf:48` writes one line per dirty batch every 60 seconds. Smoke with realistic player counts before enabling on a live server. |
| Tail-state ownership | `StatsService.cs:23` stores tail state at `StatsJsonPath + ".tail.state"`. Moving `stats.json` changes the sidecar path and can affect duplicate/readback behavior. |
| Corrupt `stats.json` recovery | `StatsDocument.Load:22-30` returns an empty document on any read/deserialization error. That protects bot startup, but can hide data loss unless operators back up the file or alert on parse failure. |
| Mission propagation | The branch only changes source Chernarus; Vanilla Takistan does not carry the SQF instrumentation. Decide whether this feature is Chernarus-only or regenerate/propagate maintained Vanilla. |
| Event coverage | The implemented branch records kills/PvP/playtime. The design docs list later stats such as deaths, supply runs, captures and builds, but this branch does not implement all of those hooks yet. |
| Runtime proof | Static tests do not prove Arma RPT format, dedicated-server timing, player UID edge cases or interaction with headless clients. |

## Smoke Checklist

1. Run with `WFBE_C_STATS_ENABLED = false` and `Preferences.StatsEnabled = false`; generate kills and confirm no `WASPSTAT` lines and no `stats.json` changes.
2. Enable mission stats only; generate AI and player kills; confirm one batched RPT line appears after the flush interval.
3. Enable DiscordBot stats with a throwaway `ServerRptPath` and `StatsJsonPath`; confirm `stats.json` accumulates the expected kill/PvP/playtime deltas.
4. Restart the bot without replacing the RPT; confirm tail state prevents duplicate accumulation.
5. Replace or rotate the RPT; confirm the first-line fingerprint/shrink logic reads the new session once.
6. Corrupt `stats.json` deliberately in a private test; confirm operator-visible recovery behavior is acceptable before live use.
7. Decide Chernarus-only versus maintained Vanilla propagation, then smoke the chosen target.

## Development Lessons

- Dark-launch flags help keep branch work merge-reviewable, but the docs must still separate "safe by default" from "safe to enable".
- RPT-tail integrations need both parser tests and operational runbooks. Offset state, file rotation, corrupt JSON recovery and log volume are part of the feature, not deployment trivia.
- Cross-language stat index maps need a single canonical owner. Here, `Init_CommonConstants.sqf:445-459`, `PlayerStat.cs:23-45` and `StatsPipelineIntegrationTests.cs:12-20,56-83` form the contract.

## Continue Reading

Previous: [Feature status register](Feature-Status-Register) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)

Main map: [Home](Home) | Branch matrix: [Current source status snapshot](Current-Source-Status-Snapshot#2026-06-04-feature-branch-matrix) | Owner decisions: [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions)
