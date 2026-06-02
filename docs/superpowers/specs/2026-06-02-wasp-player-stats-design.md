# WASP Warfare Player-Stats Module — Design

**Date:** 2026-06-02
**Status:** Draft for review (rev 3 — producer routed via the net9 DiscordBot + RPT tail; legacy extension untouched)
**Author:** brainstormed with Claude (explanatory mode)
**Repos involved:**
- Producer (new code): `rayswaynl/a2waspwarfare` — local working copy `C:\Users\Steff\a2waspwarfare` (SQF mission + the `net9` `DiscordBot`)
- Receiver (already built, contract owner): `rayswaynl/miksuus-website-discord-bot` — local working copy `C:\Users\Steff\miksuus-warfare`

**Delivery (DECIDED 2026-06-02):** Standalone branch `feat/player-stats` off `master` in the mission fork, shipped as **its own PR** — independent of `feat/supply-helicopter`. The PR contains SQF instrumentation + the DiscordBot stats module + docs. (The two tiny receiver-side touches — playtime display + a contract test — are a separate small change in the website repo.)

---

## 1. Problem & goal

The community wants per-player stats and website leaderboards for WASP Warfare (Arma 2 OA CTI). Today the mission **computes** rich per-kill / per-objective context and then **discards everything except an Arma score number**. The website + Discord bot **receiving** pipeline is already fully built and waiting for data; it is dormant only because nothing produces the feed.

**Goal:** Build the *producing* half — server-authoritative SQF instrumentation that emits stat events to the RPT log, and a stats module in the `net9` `DiscordBot` that accumulates lifetime per-player totals and writes `stats.json` in the exact shape the existing receiver already consumes. Enable combat (PvE + PvP) and objective leaderboards.

**Non-goal:** Changing the website/bot schema, ingestion, or UI. Touching the **legacy** `a2waspwarfare_Extension` DLL or the closed `A2WaspDatabase` DLL.

---

## 2. Key facts established during exploration (ground truth)

- **The receiver is already built** and defines the contract:
  - `db` table `ingame_stats` keyed by `steam_id64` with all stat columns.
  - HTTP `POST /api/stats` — Bearer-token auth (`STATS_INGEST_TOKEN`), timing-safe, size-capped, **idempotent overwrite** upsert.
  - File-mode reader `bot/cogs/stats_reader.py` — when `STATS_SOURCE=file`, polls `STATS_JSON` (default `C:\a2waspwarfare\Data\stats.json`) every `STATS_POLL_SECONDS` and upserts.
  - Composite leaderboard score is computed **receiver-side**. The producer sends **raw counts only**.
  - Receiver treats values as **lifetime totals** → the producer is the system of record and must persist across restarts.
- **Rich kill data is computed then discarded** in `Server\PVFunctions\RequestOnUnitKilled.sqf` — killer UID, victim class, inf/veh/air/static category, both sides, `_killed_isplayer`/`_killer_isplayer`. Only the score delta survives.
- **SteamID (`getPlayerUID`) is the universal identity key**, reachable at every server-side event, and matches the website's `account_links.steam_id64`.
- **Build-toolchain reality (drives the architecture):**
  - The in-repo `a2waspwarfare_Extension` (writes match-status `database.json`) is **legacy .NET 4.8 + `RGiesecke.DllExport` + `packages.config`**, and this PC has **no MSBuild/VS, no `.sln`, no restored `packages/`, no prior build output** (only the .NET 8 SDK, which can't build it). → **We do not touch it.**
  - SQF **cannot write arbitrary files**; its only server-side outbound channels are `callExtension` (needs a DLL) and `diag_log` → the server RPT.
  - The `DiscordBot` (`a2waspwarfare/DiscordBot`) is **`net9.0`, SDK-style** (Discord.Net 3.10, Newtonsoft 13), **builds with `dotnet`**, already runs on the game box and already reads the data dir. → It is the natural, testable home for the producer.
- **The producer does not exist on any branch.** Greenfield.

---

## 3. The contract (`stats.json`)

The DiscordBot writes this document atomically to `C:\a2waspwarfare\Data\stats.json`:

```json
{
  "schema": 1,
  "players": {
    "76561198000000000": {
      "kills_infantry": 0, "kills_vehicle": 0, "kills_air": 0, "kills_static": 0,
      "kills_factory": 0, "kills_hq": 0, "deaths": 0, "pvp_kills": 0,
      "supply_runs": 0, "supply_value": 0, "captures_town": 0, "captures_camp": 0,
      "structures_built": 0, "defenses_built": 0, "playtime_seconds": 0, "side": 1
    }
  }
}
```

- Keys MUST match `IncomingPlayer` in `route.ts` and `_COLS` in `stats_reader.py` **exactly**.
- All stat values are **cumulative lifetime totals**. `side` = current side (`0` unknown, `1` west, `2` east).
- Steam ID64 keys must be numeric 5–20 digits (receiver rejects non-numeric).

---

## 4. Architecture

Two principles: **(I) server-authoritative** — every stat is recorded on the server at an
engine-owned event; there is no client→server stat path, so a modified client cannot inject or
inflate stats. **(P) cheap on the sim thread** — per-event work is one in-memory integer
increment; the server emits a single `diag_log` line per ~60s flush (no per-event IO/IPC).

```
SQF mission (SERVER side only)            server RPT log              DiscordBot (net9, on the game box)        Receiver (already built)
──────────────────────────────           ────────────                ─────────────────────────────────        ────────────────────────
server event handler fires                                            RptTailer (offset state, rotation-safe)
  → RecordStat(uid,idx,+n)  (++ buffer)                                  → StatsBatchParser → StatsAccumulator
        │                                                                   (lifetime totals, seeded from stats.json)
        └ flush loop (~60s):  diag_log  ─►  WASPSTAT|v1|<seq>|<uid>:<d0..d14>,<side>|…  ─►  StatsService writes stats.json (atomic) ─file→ Python bot stats_reader.py (STATS_SOURCE=file)
            build line, zero buffers                                                       (Phase 4: also POST /api/stats)        ─POST→ /api/stats
                                                                                                                                    └→ Postgres ingame_stats → /leaderboard /players /profile /stats
```

### 4.1 SQF instrumentation (mission) — server-authoritative, buffered, RPT-emitting

- **Feature flag** `WFBE_C_STATS_ENABLED` (default `false`). When false, `WFBE_SE_FNC_RecordStat` and the flush loop no-op — zero gameplay impact, safe to ship dark.
- **Stat index constants** `WFBE_STAT_KILLS_INFANTRY = 0` … `WFBE_STAT_PLAYTIME = 14` (15 indices; mapping doc in §4.4).
- **`WFBE_SE_FNC_RecordStat(uid, statIndex, amount)` — buffer only.** Reads/increments a per-UID 15-int array in `missionNamespace` (`WFBE_STAT_BUF_<uid>`) and adds the UID to a dirty set. O(1), no allocation, no IPC. No-op when the flag is off.
- **`WFBE_SE_FNC_StatsFlush` — periodic (~60s loop from `Init_Server.sqf`).** Adds `+interval` to each connected player's playtime slot, then builds **one** line `WASPSTAT|v1|<seq>|<uid>:<d0..d14>,<side>|<uid2>:…` for all dirty UIDs, `diag_log`s it, increments `<seq>`, and zeroes the buffers. (Chunk into multiple lines, same `seq`, if the population makes the line very long.) Deltas-since-last-flush.
- **All recording is server-side** at engine-owned points — no client→server stat PVF exists.

  | JSON field | Server-side recording point (Chernarus) | Identity | Notes |
  |---|---|---|---|
  | `kills_*` by type + `pvp_kills` | `Server\PVFunctions\RequestOnUnitKilled.sqf`, ~line 41 (after identity, **before** the score gate) | `_killer` if `_killer_isplayer`, else `leader _killer_group` | classify victim via `isKindOf` (Man / Car+Tank / Air / StaticWeapon); add `pvp_kills` when `_killer_isplayer && _killed_isplayer` |
  | `deaths` | same file, when `_killed_isplayer` | `getPlayerUID _killed` | recorded for the victim — no client hook |
  | `kills_factory` / `kills_hq` | `Server\Functions\Server_BuildingKilled.sqf` ~68 / `Server\Functions\Server_OnHQKilled.sqf` ~81 | `_killer_uid` | non-teamkill paths |
  | `captures_town` / `captures_camp` | `Server\FSM\server_town.sqf` ~226 / `server_town_camp.sqf` ~122 | server enumerates players in capture range | server determines participants itself (+ voted commander) |
  | `supply_runs` + `supply_value` | `Server\Module\supplyMission\supplyMissionCompleted.sqf` ~26 | `getPlayerUID _playerObject` | server completion handler has the player object |
  | `structures_built` / `defenses_built` | server-side `RequestStructure` PVF handler | the PVF sender (commander) | classify class → defense vs other |
  | `playtime_seconds` | flush loop | `getPlayerUID _x` per connected player | `+interval` per flush; presence-based |

- **Teamkills / friendly fire:** not recorded in v1.

### 4.2 DiscordBot stats module (`a2waspwarfare/DiscordBot`, net9) — accumulator + writer

New files under `DiscordBot/src/Stats/`, mirroring the bot's existing patterns (`GameStatusUpdater` timer + `SemaphoreSlim`, `Preferences` singleton, `ProgramRuntime` launch point, Newtonsoft + `DataMemberContractResolver`):

1. **`PlayerStat.cs`** — POCO with `[DataMember(Name="kills_infantry")] public int KillsInfantry;` per JSON field + `Side`. Names MUST match §3 exactly.
2. **`StatsDocument.cs`** — `{ [DataMember("schema")] int Schema=1; [DataMember("players")] Dictionary<string,PlayerStat> Players; }` + `Load(path)` (returns empty doc on missing/corrupt) + `SaveAtomic(path)` (temp + `File.Replace`, `DataMemberContractResolver`, indented).
3. **`StatsBatchParser.cs`** — pure: parse a `WASPSTAT|v1|<seq>|seg|seg…` line → `(int seq, List<(string uid, int[15] deltas, int side)>)`; reject malformed segments (uid not numeric, wrong delta count). Lines without the `WASPSTAT|` prefix → ignored.
4. **`StatsAccumulator.cs`** — holds the in-memory `StatsDocument` (seeded from `stats.json` on boot); `ApplyBatch(parsed)` adds deltas to each player's lifetime totals + sets side; thread-safe; marks dirty.
5. **`RptTailer.cs`** — reads new bytes from the configured RPT path since a persisted byte offset; if the file is shorter than the offset (rotation/new session) resets to 0; returns new complete lines. Persists `{rptPath, offset}` to a sidecar (`stats-tail.state.json`) written after each successful flush.
6. **`StatsService.cs`** — timer (~60s, mirrors `GameStatusUpdater`'s `System.Timers.Timer` + `SemaphoreSlim` + try/catch): tail → parse matching lines → `ApplyBatch` → `SaveAtomic(stats.json)` → persist offset. Launched from `ProgramRuntime.SetupProgramListenersAndSchedulers()` when `Preferences.StatsEnabled`.
7. **`Preferences.cs`** edits — add `StatsEnabled`, `ServerRptPath`, `StatsJsonPath` (default `C:\a2waspwarfare\Data\stats.json`), and optional `StatsIngestUrl`/`StatsIngestToken` (Phase 4).

### 4.3 Transport

- **Local now ("C"):** the DiscordBot writes `stats.json`; the Python bot's `stats_reader.py` (set `STATS_SOURCE=file`, `STATS_JSON=C:\a2waspwarfare\Data\stats.json`) upserts to Postgres. **Zero new receiver code.**
- **Remote later ("A"):** the same `StatsService` also POSTs `stats.json` to `${StatsIngestUrl}` with `Authorization: Bearer <StatsIngestToken>` (receiver already built). Out of scope for v1.

### 4.4 Stat index map (SQF ↔ JSON)

`0 kills_infantry · 1 kills_vehicle · 2 kills_air · 3 kills_static · 4 kills_factory · 5 kills_hq · 6 deaths · 7 pvp_kills · 8 supply_runs · 9 supply_value · 10 captures_town · 11 captures_camp · 12 structures_built · 13 defenses_built · 14 playtime_seconds`. `side` is a separate trailing field per segment, not an index.

---

## 5. Data-model decisions

- **Raw counts only from the producer;** receiver computes composite score.
- **PvE vs PvP:** `kills_<type>` = all kills by victim class; `pvp_kills` = subset where the victim was a human player. A player kill increments both → "Total kills" board, "PvP kills" board, PvE = total − pvp. Per-type PvP split = new columns = out of scope.
- **Kill attribution:** actual human killer if the killer is a player; group leader when an AI subordinate of a player-led group made the kill.
- **`defenses_built` vs `structures_built`:** classify by structure class; if ambiguous in v1, route all to `structures_built`, leave `defenses_built` at 0.
- **Playtime:** `+interval` per connected player per flush. Presence-based.

---

## 6. Safety / integrity / performance

- **Off by default** (`WFBE_C_STATS_ENABLED=false`, `Preferences.StatsEnabled=false`). Shippable dark.
- **Server-authoritative.** Every stat is recorded on the server at an engine-owned event and emitted via server-side `diag_log`; there is no client→server stat message, so a modified client cannot inject or inflate stats. (Phrase neutrally as "server-authoritative" in PR/wiki text.)
- **Cheap on the sim thread.** Per-event = one `missionNamespace` array `++` (no alloc, no IPC). Per minute = build one short string + **one** `diag_log` (cheap append). No disk IO on the game thread. Verified by `diag_fps` flag-on/off (§9).
- **Idempotent steady-state.** Lifetime totals + overwrite upsert ⇒ duplicate file reads/POSTs are harmless. RPT lines processed once via byte-offset tracking; `<seq>` provides a dedupe backstop.
- **Crash safety.** `stats.json` written atomically (temp + `File.Replace`); offset persisted after. Reload lifetime from `stats.json` + offset on boot. A crash *between* the stats write and the offset write can re-apply the last batch (small over-count) — acceptable for a community board, documented; `<seq>` dedupe narrows it.
- **RPT robustness.** Tailer handles rotation/new-session (file shorter than offset → reset to 0) and missing file (idle). Only `WASPSTAT|`-prefixed lines are parsed.
- **Bounds.** Receiver caps body to 1 MB / 5000 players; parser validates every segment.
- **Legacy untouched.** Zero changes to `a2waspwarfare_Extension` or `A2WaspDatabase` → the live `database.json` status path cannot regress.

---

## 7. Map scope (Chernarus + Takistan only)

Edit the canonical Chernarus mission (`Missions\[55-2hc]warfarev2_073v48co.chernarus`), then **regenerate Takistan** (`Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan`) via `Tools\LoadoutManager` (needs the `7za` env var) — **never hand-edit Takistan**. The 7 modded variants are out of scope. The DiscordBot is map-agnostic (no per-map work).

---

## 8. Phasing (delivery order)

1. **Phase 1 — thin slice (prove the pipeline):** SQF flag/indices/`RecordStat`/`StatsFlush` + record **kills-by-type + pvp_kills + playtime** server-side on **Chernarus**; DiscordBot `Stats/*` (parser, accumulator, tailer, service, document) + wiring; local Python file-mode ingest. Verify: play a local match → `WASPSTAT` lines in RPT → DiscordBot writes `stats.json` → Python bot upserts → `/leaderboard` + `/stats` show data.
2. **Phase 2 — full hooks:** deaths, factory/HQ kills, town/camp captures (server in-range), supply runs+value, structures/defenses built.
3. **Phase 3 — Takistan:** regenerate via `LoadoutManager`, repack via `pack_pbo.py`, verify parity. (No DiscordBot change.)
4. **Phase 4 — remote POST:** `StatsService` POSTs to `/api/stats` for when the bot/site move off the game box. (Deferred.)

---

## 9. Testing strategy

- **DiscordBot (net9, xUnit — easy, SDK-style):** `StatsBatchParser` (well-formed + malformed segments), `StatsAccumulator` round-trip (`Load`→`ApplyBatch`→`SaveAtomic`→`Load` equals expected lifetime totals), `RptTailer` (offset advance, rotation reset, missing file). Pure logic, no Discord needed.
- **Contract guard test (receiver repo):** asserts the DiscordBot `[DataMember]` names == `_COLS`/`IncomingPlayer` keys, so the repos can't drift.
- **SQF:** no unit framework; validate by a local match with the flag on, asserting `WASPSTAT` lines appear in the RPT and reflect scripted kills.
- **Performance check:** flag-on vs flag-off `diag_fps` during a populated AI battle; confirm one `diag_log` flush line per interval.
- **End-to-end (local):** flag on → play → `stats.json` populated → Postgres `ingame_stats` rows → `/leaderboard`, `/players/[id]`, `/profile`, Discord `/stats`.

---

## 10. Out of scope (YAGNI)

- The legacy `a2waspwarfare_Extension` and closed `A2WaspDatabase` DLLs (untouched).
- The 7 modded map variants — Chernarus + Takistan only.
- Per-match / weekly / seasonal history (lifetime only in v1).
- Friendly-fire / teamkill boards, weapon breakdowns, killstreaks, per-vehicle-class kills (v2).
- K/D stored value (derived on display).
- Website/bot schema, ingestion, or UI changes (already built).
- Remote POST (Phase 4, deferred).

---

## 11. Decisions (resolved) & open items

**Resolved:**
- Delivery: own PR, `feat/player-stats` off `master`.
- **Producer: via the net9 `DiscordBot` + RPT tail** (legacy extension not buildable here / untouched).
- Recording: **server-authoritative**, buffered + one `diag_log` flush per ~60s (no client stat path).
- Kill attribution: actual human killer if player, else group leader; `pvp_kills` = player kills player.
- Kill hook: server-side at `RequestOnUnitKilled.sqf` ~line 41 (before the score gate).
- Maps: Chernarus + Takistan only.

**Open (low-stakes, defaults noted):**
1. `defenses_built` classification in v1, or defer (all → `structures_built`)? *Default: attempt; fall back to structures-only.*
2. RPT discovery: explicit `ServerRptPath` in `preferences.json` (default) vs auto-pick newest `.rpt`. *Default: explicit path.*
3. Prereq: install the **.NET 9 SDK** on the dev box to build the bot (current is 8.0.421). *Default: yes (light install).*

---

## 12. Risks & adjacent fixes

**Risks (with mitigation):**
- 🟠 **RPT-tail fragility** — rotation, offset drift, a server launched with reduced logging. Mitigation: rotation-reset logic, offset sidecar, `WASPSTAT|` prefix + `<seq>`; `ServerRptPath` explicit in config. Documented crash-window over-count is acceptable for a community board.
- 🟠 **Capture in-range detection** must be server-side (old credit was client-side). The server already detects the capture; we add an in-range player scan there.
- 🟠 **Map parity drift** — regenerate Takistan via `LoadoutManager`; never hand-edit. Parity check in Phase 3.
- 🟠 **Composite-weight / field-name drift** across `route.ts` / `stats_reader.py` / the DiscordBot POCO. Mitigation: contract test (#3 below).
- 🟡 **.NET 9 SDK prerequisite** to build the bot. Mitigation: one-time install; CI/build note in the plan.
- 🟡 **Batch line length** at high population. Mitigation: chunk into ≤N players per line (same `seq`).
- 🟡 **Playtime presence-based**, not wall-clock. Documented.
- 🟢 **Rollout** — off-by-default flag + legacy code untouched ⇒ cannot regress the live status path.

**Small adjacent fixes:**
1. **Empty-server player count off-by-one** — `Server\CallExtensions\GlobalGameStats.sqf:20` `abs(_playerCount - 1)` reports `1` on an empty server. Fix: subtract actual HC count, clamp at 0. (~1 line; mission repo, in this PR.)
2. **Playtime shown via an UNCONFIRMED factor** — `bot/insights/logic.py:12` (`ticks_to_hours`) + the profile page convert legacy `ticks/3600`. Once we emit real `playtime_seconds`, switch the `/stats` embed + profile to display that. (~10 lines; **website repo**, separate small change.)
3. **Stat-contract guard test** — fails if DiscordBot `[DataMember]` names and website columns drift. (~30 lines; **website repo**.)

*(Dropped vs rev 2: the `SerializeDB` async-void fix — we no longer touch the extension.)*

---

## 13. Footprint (estimates, ±20%, pre-implementation)

**Code (~450–550 LOC; ~5–6 new SQF + 6 new C# files; ~13 files touched; Takistan = 0 hand-written):**

| Area | New | Edits |
|---|---|---|
| SQF (Chernarus): config (indices+flag) ~20, `WFBE_SE_FNC_RecordStat` ~12, `WFBE_SE_FNC_StatsFlush` ~28 | ~60 | `Init_Server.sqf` +6; `RequestOnUnitKilled.sqf` ~12; building/HQ +4; town/camp ~22; supply +3; RequestStructure +4 → **~51** into live gameplay |
| DiscordBot (net9): `PlayerStat` ~30, `StatsDocument` ~75, `StatsBatchParser` ~45, `StatsAccumulator` ~60, `RptTailer` ~110, `StatsService` ~70 | ~390 | `Preferences.cs` +6; `ProgramRuntime.cs` +3 |
| Tests (xUnit, net9): parser + accumulator round-trip + tailer | ~120 | — |
| Adjacent (website repo): playtime display ~10, contract test ~30 | ~40 | — |
| Adjacent (mission): `GlobalGameStats.sqf` player-count | — | ~2 |

**Blast radius into live gameplay SQF ≈ ~50 lines**, each a guarded `RecordStat(...)` (no-op when off). The DiscordBot work is all-new files in a modern testable project; **zero legacy code touched**. **Phase 1 thin slice ≈ 320–360 LOC** (the parser/accumulator/tailer/service infra is needed even for one stat).

**Runtime:**
- **Sim-thread CPU:** per event = one array `++`; per minute = one `diag_log` line. Negligible (verified via `diag_fps`).
- **Memory:** SQF — one 15-int array per *connected* UID. DiscordBot — `Dictionary<steamId64,PlayerStat>` one entry per *lifetime* player (~<200 B → 10k ≈ ~2 MB).
- **Disk:** DiscordBot rewrites `stats.json` once/~60s (atomic); reads only *new* RPT bytes each tick. RPT itself is the server's existing log (no extra growth from us beyond our lines).
- **Network:** zero local; remote (Phase 4) one POST/~60s.
- **Build/dep:** +.NET 9 SDK on the dev box; no new NuGet deps (Newtonsoft already referenced).

**Grows over time (known, not v1):** `stats.json` + `ingame_stats` hold every *lifetime* player; full-file rewrite each flush. Trivial at community scale; "prune/rotate inactive" is future.
