# Player Stats Branch Audit

This page began as a source-backed review of `origin/feat/player-stats` at head `e01e47e1`. Treat the original branch sections as historical branch evidence unless the current-status table below says otherwise: current stable/B74.1 `origin/master@f8a76de34` now has a mission-side stats pipeline in the source Chernarus mission and sets `WFBE_C_STATS_ENABLED = true`, while maintained Vanilla Takistan still carries the helper/constants path with `WFBE_C_STATS_ENABLED = false`. B74.2 adds source Chernarus fast-follow stat writers, but is branch-only and has no `Missions_Vanilla` payload. PR #84 is a later stack on the original player-stats branch that adds optional in-game names to the in-repo `stats.json` producer; keep it branch-only until merge/deploy/runtime smoke proves otherwise.

## What It Is

`origin/feat/player-stats` adds a dark-launched player statistics pipeline:

- SQF server instrumentation buffers stat deltas per Steam UID.
- A server flush loop emits batched `WASPSTAT|v1|...` lines to the server RPT.
- The in-repo `DiscordBot` tails the RPT, parses batches, accumulates lifetime totals and writes `stats.json`.
- `DiscordBot.Tests` covers the parser, tailer, accumulator, document writer and an end-to-end producer pipeline test.

The original `origin/feat/player-stats` branch contains 23 changed files, `+1919/-1`, and `git diff --check origin/master..origin/feat/player-stats` is clean.

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

On the original branch, the mission side is off by default. `Init_CommonConstants.sqf:442-444` defines `WFBE_C_STATS_ENABLED = false` and a 60-second flush interval. The stat index constants run from `WFBE_STAT_KILLS_INFANTRY = 0` through `WFBE_STAT_PLAYTIME = 14`, with `WFBE_STAT_FIELD_COUNT = 15` and `WFBE_STATS_DIRTY_UIDS = []` at `:445-461`.

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

## PR #84 Player Name Stack

Open non-draft [PR #84](https://github.com/rayswaynl/a2waspwarfare/pull/84) is `feat/player-stats-names` -> `feat/player-stats`, head `177539ed5585acdb086c9cfdacf1e671459a686a`, base `e01e47e12a767c3406f8b89b7df5ea9d95260b87`, GitHub clean merge state, updated 2026-06-24T12:51:37Z. Local checks confirm merge-base `e01e47e12a767c3406f8b89b7df5ea9d95260b87`, one commit, `git diff --shortstat origin/feat/player-stats..origin/feat/player-stats-names` = 6 files / +57 / -7, and clean `git diff --check` for the scoped stack. The scoped diff has no `Missions_Vanilla`, `Modded_Missions`, `Tools` or `Extension` payload.

| Layer | PR #84 evidence | Meaning |
| --- | --- | --- |
| SQF flush producer | `StatsFlush.sqf:24-25,44-50` on `origin/feat/player-stats-names` | The playtime loop caches `name _x` under `WFBE_STAT_NAME_<uid>`, appends `~<name>` after the numeric CSV/side payload, then clears the cached name with the stat buffer. |
| Parser wire format | `StatsBatchParser.cs:5,31-40,49` | `StatSegment` gains nullable `Name`; parsing splits the segment after `:` on the first `~`, preserving tildes inside the name while keeping numeric fields before the suffix. A player name containing `|` still truncates the name because the outer wire split is pipe-based, but the stat numbers remain before the suffix. |
| Accumulator | `StatsAccumulator.cs:21-23` | Deltas and side still apply first; a non-null parsed name overwrites the stored latest-seen name, while absent names preserve the previous value. |
| JSON contract | `PlayerStat.cs:22-24` | Adds nullable `[DataMember(Name = "name")] public string? Name`, matching the in-repo `stats.json` producer contract. |
| Tests | `StatsBatchParserTests.cs:43-69`; `StatsPipelineIntegrationTests.cs:77-83` | Parser tests cover name suffix, absent suffix and internal `~`; the integration contract now asserts the `name` key appears in `stats.json`. |

This pass could not re-run the PR #84 test suite locally: the detached worktree at `177539ed` failed immediately because `dotnet --info` reports runtime 8.0.28 but **no .NET SDKs installed**. The PR body reports `dotnet test` 16/16; treat that as PR-author evidence until a local SDK-backed run is recorded. The external website receiver named in the PR body is not present in this repo (`git ls-tree` found no `web/`, `bot/`, `api/stats`, `stats_reader` or `display_name` path on the branch), so this audit verifies only the in-repo producer/DiscordBot side.

## What Depends On It

- The DiscordBot must run on, or have file access to, the Arma 2 OA server RPT path.
- A downstream stats consumer must read `stats.json`. The branch design docs describe an existing receiver outside this repo, but this audit only verifies the in-repo producer and DiscordBot pieces.
- Steam UID64 becomes the identity key. That makes UID/privacy policy an owner decision before public enablement.

## Current Status

| Target | Status |
| --- | --- |
| Current stable/B74.1 source Chernarus `origin/master@f8a76de34` | Present and enabled. `Init_CommonConstants.sqf:920` sets `WFBE_C_STATS_ENABLED = true`; `Init_Server.sqf:534-536` compiles `Server\Stats\RecordStat.sqf` and starts `StatsFlush.sqf`; `RecordStat.sqf:7-32` guards record helpers; `StatsFlush.sqf:9-10,24-35` guards and emits batched `WASPSTAT` lines; `RequestOnUnitKilled.sqf:117-131` records kill/PvP deltas. This is mission-side source Chernarus evidence, not proof of a current DiscordBot stats ingester. |
| Current stable/B74.1 maintained Vanilla Takistan `origin/master@f8a76de34` | Helper/constants path is present but off by default: `Init_CommonConstants.sqf:786` sets `WFBE_C_STATS_ENABLED = false`; `Init_Server.sqf:529-530` compiles/starts `RecordStat`/`StatsFlush`; `RequestOnUnitKilled.sqf:102-116` has kill/PvP hooks guarded by the disabled flag. |
| Original `origin/feat/player-stats@e01e47e1` | Historical branch: source Chernarus present and off by default; DiscordBot ingest/tests present; maintained Vanilla Takistan absent on that branch audit. |
| PR #84 `origin/feat/player-stats-names@177539ed` | Open non-draft stack on `origin/feat/player-stats@e01e47e1`: source Chernarus `StatsFlush.sqf` appends optional `~<name>` suffix; DiscordBot parser/accumulator/`PlayerStat` preserve nullable `name`; parser/integration tests are updated. Branch-only; no maintained Vanilla, Modded, Tools or Extension payload. Local test rerun blocked by missing .NET SDK. |
| B74.2 source Chernarus `origin/claude/b74.2-aicom@21b62b04` | Branch-only fast-follow writer hooks: structures built at `Construction_MediumSite.sqf:200` and `Construction_SmallSite.sqf:161`; defenses built at `RequestDefense.sqf:283,294,305`; town/camp captures at `server_town.sqf:240` and `server_town_camp.sqf:90`; supply runs/value at `supplyMissionCompleted.sqf:27`; factory/HQ kills at `Server_BuildingKilled.sqf:65` and `Server_OnHQKilled.sqf:89`; deaths at `RequestOnUnitKilled.sqf:135`. `d472da6a..21b62b04` does not touch the checked stat-writer paths. No `Missions_Vanilla` payload. |
| Modded missions | Not reviewed; treat as absent unless a later branch proves propagation. |
| Static whitespace | Clean. |
| C# tests | Pass locally: 13/13. |
| Arma 2 OA runtime smoke | Not run. |

## Risks And Promotion Gates

This branch is a good candidate for review because it is dark-launched and test-backed, but it should not be enabled publicly until these gates are answered:

| Gate | Why |
| --- | --- |
| Privacy and retention | `stats.json` is keyed by Steam UID64. Decide retention, publication and whether UID-to-name joins happen outside this repo. |
| Player-name handling | PR #84 adds a nullable in-game `name` field. Decide whether player names are acceptable to publish alongside UID-keyed records, and record retention/redaction policy before enabling a public feed. |
| Runtime log volume | `StatsFlush.sqf:48` writes one line per dirty batch every 60 seconds. Smoke with realistic player counts before enabling on a live server. |
| Tail-state ownership | `StatsService.cs:23` stores tail state at `StatsJsonPath + ".tail.state"`. Moving `stats.json` changes the sidecar path and can affect duplicate/readback behavior. |
| Corrupt `stats.json` recovery | `StatsDocument.Load:22-30` returns an empty document on any read/deserialization error. That protects bot startup, but can hide data loss unless operators back up the file or alert on parse failure. |
| Mission propagation | Current stable has source Chernarus stats enabled and maintained Vanilla helper code off by default. B74.2 fast-follow writers are source Chernarus only. Decide whether live stats are Chernarus-only, whether maintained Vanilla should stay off, and whether any generated/Vanilla propagation is required before release wording. |
| Event coverage | Current stable records kills/PvP/playtime/side. B74.2 adds writers for deaths, supply, captures, builds and strategic kills, but only on a branch and only for source Chernarus. |
| Runtime proof | Static tests do not prove Arma RPT format, dedicated-server timing, player UID edge cases or interaction with headless clients. |

## Smoke Checklist

1. Run with `WFBE_C_STATS_ENABLED = false` and `Preferences.StatsEnabled = false`; generate kills and confirm no `WASPSTAT` lines and no `stats.json` changes.
2. Enable mission stats only; generate AI and player kills; confirm one batched RPT line appears after the flush interval.
3. On PR #84 or any branch that adopts it, join with normal names plus edge-case names containing `~` and `|`; confirm RPT `WASPSTAT` lines keep numeric fields intact, `~` inside a name is preserved by the parser, and `|` only truncates the name portion.
4. Enable DiscordBot stats with a throwaway `ServerRptPath` and `StatsJsonPath`; confirm `stats.json` accumulates the expected kill/PvP/playtime deltas and includes the latest non-null `name` value when the PR #84 stack is in scope.
5. Restart the bot without replacing the RPT; confirm tail state prevents duplicate accumulation.
6. Replace or rotate the RPT; confirm the first-line fingerprint/shrink logic reads the new session once.
7. Corrupt `stats.json` deliberately in a private test; confirm operator-visible recovery behavior is acceptable before live use.
8. Decide Chernarus-only versus maintained Vanilla propagation, then smoke the chosen target.
9. For B74.2, enable source Chernarus stats in a private run and exercise town/camp capture, supply completion, small/medium construction, defense purchase, HQ/factory kill and player death paths; confirm expected `WASPSTAT` deltas and no duplicate credit loop.

## Development Lessons

- Dark-launch flags help keep branch work merge-reviewable, but the docs must still separate "safe by default" from "safe to enable".
- RPT-tail integrations need both parser tests and operational runbooks. Offset state, file rotation, corrupt JSON recovery and log volume are part of the feature, not deployment trivia.
- Cross-language stat index maps need a single canonical owner. On the original branch, `Init_CommonConstants.sqf:445-459`, `PlayerStat.cs:23-45` and `StatsPipelineIntegrationTests.cs:12-20,56-83` form the contract; on current stable/B74.1, mission-side index changes must be checked against whatever current external ingest route is actually deployed.

## Continue Reading

Previous: [Feature status register](Feature-Status-Register) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)

Main map: [Home](Home) | Branch matrix: [Current source status snapshot](Current-Source-Status-Snapshot#2026-06-04-feature-branch-matrix) | Owner decisions: [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions)
