# AntiStack — Installation, Database ("SQL") & Re-implementation Guide

How to get the AntiStack persistence system running on a WASP Warfare server,
**without needing anything from the previous host**. Companion to
`docs/ops/SERVER-INSTALL.md` (§8 there is the short version; this document is the
complete specification).

Context: the mission-side AntiStack module is fully in this repo, but it talks to a
**closed-source native extension `A2WaspDatabase.dll`** whose binary, configuration and
SQL backend have only ever existed on the original production host. If you cannot get
that transfer set (DLL + its config + a DB dump), the extension must be re-implemented.
**Everything the DLL must do is recoverable from the SQF in this repo** — every request
string it receives and every response the mission parses is in
`Server/Module/AntiStack/` — and this document specifies that contract completely,
plus a reference SQL schema and setup.

Your three options, in increasing order of effort:

| Option | What you need | What you get |
|---|---|---|
| **A. Run without it** | nothing | Mission runs today, no cross-session score persistence, no skill balancing. Safe default. |
| **B. Original transfer set** | `A2WaspDatabase.dll` + adjacent config + DB dump **from the current host** | Identical behavior to the original server. |
| **C. Re-implement the extension** | this spec + a small x86 DLL (§5–§7) + a database (§6) | Full AntiStack behavior, no dependency on the old host. |

A new server can go live on Option A immediately and add B or C later — the mission
degrades gracefully at every call site (§8).

---

## 1. What AntiStack does (player-visible behavior)

All of it is server-side; clients never talk to the database.

1. **Cross-session score & playtime persistence** — every connected human player's
   engine score is periodically written to the DB keyed by their **Steam UID**, as
   *deltas* the DB accumulates into a lifetime total, together with a playtime counter
   ("ticks"). A player's **skill** is defined as `total_score / ticks_played`.
2. **Join-time team-stack gate** — a first-time joiner in a match who picks the side
   whose summed skill is already higher gets bounced back to the lobby with a
   localized *Teamstack* message (`Server/PVFunctions/RequestJoin.sqf` →
   `compareTeamScores.sqf`). Small-server bias: with few players online, a
   player-count difference inflates the larger team's "effective skill"
   (`PLAYER_NUMBER_DIFFERENCE_MODIFIER = 0.15`, doubled below 8 total players,
   single below 12, off above).
3. **Skill-difference supply compensation** — a repeating server loop compares the two
   sides' total skill; if one side's accumulated advantage crosses a threshold, the
   *weaker* side receives bonus supply income every 60 s until the imbalance decays
   (`skillDiffCompensation.sqf`; constants in `Common/Init/Init_CommonConstants.sqf`:
   trigger threshold 30, end threshold 10, multiplier 0.045).
4. **No-player stagnation exemption** — a side with any registered skill in the DB is
   exempted from the "no players online" supply-income decay
   (`Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf`).
5. **Teamswap protection** — NOT database-backed and always active regardless of
   AntiStack: the side a player held at mission launch is pinned in `missionNamespace`
   (`clientHasConnectedAtLaunch.sqf`) and re-joining a *different* side is denied.
   Disabling AntiStack does not disable this.

The whole module is switchable in the lobby: parameter **`WFBE_C_ANTISTACK_ENABLED`**
(`Rsc/Parameters.hpp`, title "AntiStack", default **1** = enabled).

---

## 2. Architecture

```
Mission (server side only)
  Server/Module/AntiStack/*.sqf         one wrapper per DB procedure + the loops
        │  "A2WaspDatabase" callExtension "<code>,<params>"       (string in)
        ▼
  A2WaspDatabase.dll   (x86, next to arma2oaserver.exe)           (string out)
        │  SQL on its own worker thread(s)
        ▼
  Database (engine unknown for the original; §6 gives a reference schema)
```

- `callExtension` is **synchronous and blocks the server's script scheduler** for the
  duration of the DLL call. That is why the two read procedures (101, 606) are
  **asynchronous**: the initial call returns a request ID instantly and the mission
  polls a separate "try retrieve" code. A re-implementation must keep every call
  returning in ~1 ms or less and run all SQL on background threads.
- The engine hands the DLL an output buffer of fixed size (4 KB class on Arma 2 OA
  builds — the engine passes the actual size as a parameter; never write more).
- `arma2oaserver.exe` is 32-bit → the DLL **must be x86**, and any DB client library
  it loads must exist in x86 form.
- Every response string is executed by the mission as SQF via `call compile`, so it
  must be a **valid SQF array literal**, e.g. `[1, 42]`. An empty response string is
  the "extension absent" signal and is safely absorbed by guards at every call site.

---

## 3. Mission-side wiring (what runs when)

Compiled in `Server/Init/Init_Server.sqf` (the `WFBE_SE_FNC_CallDatabase*` /
`WFBE_SE_FNC_*TeamScore*` block near the top of the file). The
`clientHasConnectedAtLaunch.sqf` public-variable event handler (teamswap pinning) is
installed unconditionally. Then, only when `WFBE_C_ANTISTACK_ENABLED == 1`
(`Init_Server.sqf`, `_antiStackEnabled` block):

| When | What | DB procedures used |
|---|---|---|
| Mission init | `SET_MAP` with 2 = Takistan, 3 = Zargabad, 1 = anything else (Chernarus and modded maps) | 909 |
| Mission init | `monitorTeamToJoin.sqf` — one-shot; RETRIEVEs every playable slot's stats to compute the weaker side, **result is discarded** (vestigial; costs one 101/505 round-trip per slot at boot) | 101/505 |
| Every 1 s | `updateScoreInternal.sqf` — samples each real player's engine `score` into `WFBE_CO_CURRENT_SCORE_PLAYER_<uid>` (no DB) | — |
| Every 120 s per player | `mainLoop.sqf` — RETRIEVE lifetime totals, then STORE the score **delta** since the previous sample (`WFBE_CO_OLD_SCORE_PLAYER_<uid>` bookkeeping) | 101/505, 202 |
| Every 120 s (after 10 s initial delay) | `flushLoop.sqf` — SEND_PLAYERLIST of `[uid, side]` for every connected human with a confirmed side | 303 |
| Every 120 s | `skillDiffCompensation.sqf` — REQUEST_SIDE_SKILL for both sides, accumulate, trigger/end the compensation sub-loop (60 s cadence while active) | 606/707 |
| Player requests to join a side (first join this match) | `RequestJoin.sqf` → `getTeamScore.sqf` per side → `compareTeamScores.sqf` verdict; on success the side is recorded | 606/707 ×2, then 404 |
| Player disconnects | `Server_OnPlayerDisconnected.sqf` — STORE final delta, then STORE_SIDE `uid,0` ("NONE") | 202, 404 |
| Side supply stagnation check | `Common_StagnateSupplyIncomeNoPlayers.sqf` — REQUEST_SIDE_SKILL both sides for the exemption | 606/707 |
| Match end (`server_victory_threeway.sqf`) | `SET_MAP 0`; per-player final STORE of remaining delta; FLUSH_PLAYERLIST **once** — from the round-end flush block (default), or from the post-hold final-save block only when the former was disabled (`WFBE_ROUNDEND_FLUSH_DONE` makes the two sites mutually exclusive) | 909, 202, 808 |

All loops terminate on `WFBE_GameOver`. Loop cadences come from
`countPlayerScores.sqf` (`_mainSleep = 120`, `_sleep = 1`, `_flushSleep = 120`,
`_initialSleep = 10`, `_miniSleep = 0.15` between per-player slices).

---

## 4. Wire protocol — normative spec for a replacement DLL

Transport: single input string `"<code>"` or `"<code>,<params>"`; single output string
that is a valid SQF array literal. Response element 0 is the **response code**:
`1` = success, any **negative** value = error (or "still pending" on the poll codes;
`-111` is the legacy convention for a database failure). UIDs are SteamID64 decimal
strings (17 digits today — do not assume a fixed width). Score deltas can be
**negative** (teamkills, deaths).

| Code | Purpose | Request (exact) | Success response | Notes |
|---|---|---|---|---|
| **101** | Begin fetch of one player's stats | `101,<uid>` | `[1, <requestID>]` | Async: kick the SELECT on a worker thread, return the ID immediately |
| **505** | Poll result of a 101 | `505,<requestID>` | `[1, <totalScore>, <ticksPlayed>]` — **flat, three elements** | While pending return `[-1]`. Mission polls immediately, then every 0.10 s, max 120 attempts (~12 s budget) |
| **202** | Store a score delta | `202,<uid>,<scoreDiff>` | `[1]` | Accumulate: `total_score += scoreDiff`. Create the row if the UID is new |
| **404** | Store a player's current side | `404,<uid>,<side>` | `[1]` | side: **0 = none** (sent on disconnect), 1 = WEST, 2 = EAST |
| **303** | Report who is online | `303,<uid1>,<side1>,<uid2>,<side2>,...` | `[1]` | Flat CSV, sides 1/2 only. **Empty list arrives as `303,`** (trailing comma, no pairs) |
| **808** | Clear the online-player list (match end) | `808` — no comma, code only | `[1]` | |
| **606** | Begin computing one side's total skill | `606,<side>` | `[1, <requestID>]` | side 1/2 (0 possible as a fallback). Async like 101 |
| **707** | Poll result of a 606 | `707,<requestID>` | `[1, <totalSkill>]` | While pending return `[-1]`. Mission polls immediately, then every **3 s, max 9 attempts** (~27 s budget) |
| **909** | Record the active map | `909,<mapId>` | `[1]` | 0 = none (set at match end), 1 = Chernarus/other, 2 = Takistan, 3 = Zargabad |

Request IDs are opaque to the mission (it just formats them back into the poll call);
keep them numeric and monotonically increasing. IDs only need to live until answered
or abandoned — the mission never re-polls after its attempt budget is exhausted, so
expire stale pending results after ~60 s.

**Failure semantics the mission relies on** (verified against every call site):

- On 505 timeout the mission substitutes `[1, 1]` (score 1, ticks 1 → skill 1).
- On 707 timeout the mission substitutes total skill `1`.
- A response code < 0 on a synchronous call is never fatal. 404/303/909 log an ERROR
  line for it; **202 and 808 swallow it silently** (their wrappers only log success) —
  so the DLL must log its own failures or 202 write errors are invisible.
- An **empty output string** (or any non-array) is treated exactly like "extension not
  installed": neutral sentinels everywhere, no script errors (§8).
- 303 side values: the mission's callers only ever submit WEST/EAST players (upstream
  confirmed-side filtering), and the wrapper's side→number conversion reuses the
  *previous* entry's number for any other side rather than emitting a fresh 0 — a
  replacement DLL should validate `side ∈ {1,2}` per pair and ignore anything else.

**Semantics the DLL must implement** (inferred from the contract — the original binary
is unobservable, but these are the only readings consistent with the mission code):

- **`ticks_played`** is maintained DB-side; the mission never sends playtime, yet
  divides `total_score / ticks_played` for skill. The natural unit is "number of
  ~2-minute intervals played". Recommended: increment `ticks_played` by 1 on every
  202 STORE for that UID (202 arrives every 120 s per online player). Disconnect and
  round-end also STORE, adding ≤2 extra ticks per session — negligible; rate-limit
  (min ~60 s between increments per UID) if you want it exact.
- **606 total skill** = `SUM(total_score / ticks_played)` over players **currently
  assigned to that side** — i.e. rows whose `side` column matches, as maintained by
  404 (join/disconnect) and refreshed by 303 (guard `ticks_played = 0` rows to skill
  contribution 0). This matches the join gate comparing side sums and the per-player
  skill definition used in `getTeamScoreMonitor.sqf`.
- **303 vs 404**: 404 is the authoritative single-player side transition; 303 is a
  periodic bulk refresh of who is online. A simple implementation updates the same
  `side` column from both and additionally clears `side` to 0 for every UID *not* in
  a 303 list (that is what makes 808-at-match-end and crash recovery consistent).

---

## 5. Building a replacement `A2WaspDatabase.dll`

The DLL must export the classic Arma 2 extension entry point:

```c
// exported as _RVExtension@12 (stdcall, x86)
void __stdcall RVExtension(char *output, int outputSize, const char *function);
```

This repo already contains an example of the export pattern: **`Extension/`** (the
match-status exporter) is a .NET Framework 4.8 class library using
`[DllExport("_RVExtension@12", CallingConvention.Winapi)]`
(`Extension/src/ExtensionMethods.cs`). Two caveats before cloning it:

- **Build it explicitly as x86** — `msbuild Extension.csproj /p:Configuration=Release
  /p:Platform=x86`. The csproj's default AnyCPU configuration will not load into the
  32-bit server; only the `x86` platform configurations set `PlatformTarget=x86`.
- The example demonstrates only the *request* half: it parses `function` and writes
  its result to a file on disk, **never writing to the `output` buffer** (its
  mission-side caller discards the return value). A2WaspDatabase must additionally
  write the SQF-array response into `output` — that response-writing half is the part
  you add, and every one of the §4 procedures needs it.

Clone that project layout, rename the output assembly to `A2WaspDatabase.dll`, and
implement the §4 table. Design rules:

- Parse `function` up to the first comma → procedure code; rest → params.
- **Never block**: 101/606 push a job to a worker thread and return `[1,<id>]`;
  202/303/404/808/909 enqueue a write-behind job and return `[1]` immediately.
- Keep an in-memory map `requestID → result` for the poll codes; reply `[-1]` until
  the worker fills it.
- Copy at most `outputSize - 1` bytes into `output`, always NUL-terminated.
- Log to a file next to the DLL — the engine has no stderr, and silent failures here
  historically cost days (see §9 verification instead of guessing).
- Database client: for MySQL/MariaDB use `MySql.Data` (managed, works in x86); for
  SQLite use `Microsoft.Data.Sqlite` or `System.Data.SQLite` (bundle the x86 native
  interop DLL).

Alternatively any native x86 DLL (C/C++) with the same export works — the mission
cares only about the strings.

---

## 6. Database setup ("SQL configuration")

> The original backend's engine and schema are unknown (closed DLL, never dumped).
> The schema below is the **reference schema for a re-implementation** — it is the
> minimal shape the §4 contract requires, not an archaeological reconstruction.

### 6.1 Reference schema

```sql
-- MySQL / MariaDB dialect; trivially portable to SQLite
CREATE DATABASE IF NOT EXISTS antistack CHARACTER SET utf8mb4;

CREATE TABLE antistack.players (
    uid          VARCHAR(20)  NOT NULL PRIMARY KEY,  -- SteamID64 as a string
    total_score  INT          NOT NULL DEFAULT 0,    -- accumulated 202 deltas (can go negative)
    ticks_played INT          NOT NULL DEFAULT 0,    -- ~2-minute intervals, incremented per 202 (see §4)
    side         TINYINT      NOT NULL DEFAULT 0,    -- 0 none, 1 west, 2 east (404/303)
    last_seen    TIMESTAMP    NULL DEFAULT NULL
);

CREATE TABLE antistack.session (
    id         TINYINT   NOT NULL PRIMARY KEY DEFAULT 1,  -- single row
    map_id     TINYINT   NOT NULL DEFAULT 0,              -- 909: 0 none, 1 chernarus, 2 takistan, 3 zargabad
    updated_at TIMESTAMP NULL DEFAULT NULL
);
INSERT INTO antistack.session (id, map_id) VALUES (1, 0);
```

Procedure → SQL sketch:

| Code | SQL |
|---|---|
| 101/505 | `SELECT total_score, ticks_played FROM players WHERE uid = ?` (missing row → `[1, 0, 0]`) |
| 202 | `INSERT INTO players (uid, total_score, ticks_played, last_seen) VALUES (?, ?, 1, NOW()) ON DUPLICATE KEY UPDATE total_score = total_score + VALUES(total_score), ticks_played = ticks_played + 1, last_seen = NOW()` |
| 404 | `INSERT INTO players (uid, side) VALUES (?, ?) ON DUPLICATE KEY UPDATE side = VALUES(side)` |
| 303 | upsert `side` for each listed pair; `UPDATE players SET side = 0 WHERE uid NOT IN (<list>)` |
| 808 | `UPDATE players SET side = 0` |
| 606/707 | `SELECT COALESCE(SUM(total_score / ticks_played), 0) FROM players WHERE side = ? AND ticks_played > 0` |
| 909 | `UPDATE session SET map_id = ?, updated_at = NOW() WHERE id = 1` |

### 6.2 Engine install (MariaDB on the game box)

The DB **server** can be x64 — only the DLL's client library must be x86. On the
Windows game box:

```powershell
winget install MariaDB.Server            # or the MSI from mariadb.org
# During/after setup: set a root password, keep networking on 127.0.0.1 only.
mysql -u root -p
```

```sql
CREATE USER 'antistack'@'localhost' IDENTIFIED BY '<generate-a-long-password>';
GRANT SELECT, INSERT, UPDATE, DELETE ON antistack.* TO 'antistack'@'localhost';
FLUSH PRIVILEGES;
```

Then run the §6.1 DDL. Least privilege: the extension user gets no DDL/GRANT rights;
bind the server to localhost (`bind-address=127.0.0.1` in `my.ini`) — nothing remote
ever needs this DB. Back it up with a nightly
`mysqldump antistack > antistack-$(date).sql` scheduled task.

**SQLite alternative (recommended for a single-box setup):** skip the server entirely
— the DLL opens `antistack.db` next to itself. Same tables minus the `DATABASE`
statement; use `INSERT ... ON CONFLICT(uid) DO UPDATE`. One file, zero services, one
file to back up. Team-stack data is small (hundreds of rows); SQLite is ample.

### 6.3 DLL configuration file

Put the connection settings in a plain config next to the DLL (e.g.
`A2WaspDatabase.ini`) rather than compiled in:

```ini
[database]
provider = mariadb            ; or sqlite
host     = 127.0.0.1
port     = 3306
database = antistack
user     = antistack
password = <the-password>
; provider = sqlite needs only:  file = A2WaspDatabase.sqlite
```

Never commit real credentials to this repo (it is public).

---

## 7. Deploying on the server box

1. Copy `A2WaspDatabase.dll` (+ its config + x86 runtime dependencies, e.g. the VC++
   x86 redistributable for native builds) **next to `arma2oaserver.exe`** in `<OA>\`.
   The engine resolves `callExtension` names against the server root and mod dirs.
2. Ensure the DB is up (service running / SQLite file writable by the server's user).
3. Leave the lobby parameter `WFBE_C_ANTISTACK_ENABLED` at its default (1).
4. Restart the server; verify per §9.

For the **Option B** path instead: obtain from the current host (a) the DLL from
`<OA>\` next to `arma2oaserver.exe`, (b) every non-game config file next to it or in
`C:\WASP\` that mentions wasp/database/a connection string, (c) a dump of the backing
database, restored into the same engine on the new box. Then reconnect via (b).

---

## 8. Running WITHOUT the database (Option A)

Verified fallback behavior at every call site — a new box can go live with no DLL:

- Extension absent while the parameter is ON: every `callExtension` returns an empty
  string; guards convert that to neutral sentinels — RETRIEVE → `[1,1]` (skill 1),
  side skill → `0`, stores → success. Effects: join gate compares `0 vs 0` and always
  allows; skill compensation never triggers; no persistence. No script errors (the
  `task46` guards in each `callDatabase*.sqf`).
- Parameter OFF (`WFBE_C_ANTISTACK_ENABLED = 0`): the four loops (score sampling,
  score flush, player-list flush, skill compensation), the one-shot join-side
  monitor, and the init `SET_MAP` are never started; every wrapper early-exits with a
  neutral sentinel (note RETRIEVE's OFF sentinel is `[0,1]` — skill 0 — unlike the
  `[1,1]` absent-extension sentinel); the join skill check is bypassed (allow); and
  disconnect/match-end skip DB persistence.
  **Teamswap protection stays active** — it is deliberately outside the switch.

---

## 9. Verification checklist

RPT caveat first: **all** of the module's `INFORMATION`/`ERROR` lines — including the
boot line below — go through `WFBE_CO_FNC_LogContent`, which only prints when content
logging is active (`LOG_CONTENT_STATE == "ACTIVATED"`, driven by the
`WF_LOG_CONTENT` define in `version.sqf`; headless clients force it on). `version.sqf`
is generated and gitignored, so check *your* build: the tracked
`version.sqf.template` currently ships the define **enabled** (owner-directed live
diagnostics), but builds packed from older templates ran with it off. If the lines
below are absent, check that define before suspecting the DLL — and note 202/808
failures never log regardless (§4), so the functional tests are authoritative either
way.

1. **Boot line** (needs content logging, like everything below): `Init_Server.sqf:
   AntiStack is [ENABLED] for this session.` — confirms the parameter state the
   server actually saw.
2. **With content logging on**, expect within ~2 minutes of mission start:
   - `CountPlayerScores.sqf got execVMd!` and `MainLoop.sqf: Starting main loop...`
   - `CallDatabaseRetrieve.sqf: Called database with procedure: [RETRIEVE], RESPONSE
     (REQUEST ID) IS: [...]` with a real `[1, <id>]` — an empty `[]`/blank means the
     DLL did not load (wrong bitness, missing dependency, wrong filename).
   - No `CRITICAL ERROR! Something went wrong with database` lines (those are the
     505/707 poll timeouts).
3. **Functional persistence test** (works on production builds): join, earn score
   (capture/kill), disconnect, restart the mission, rejoin — with the DB live your
   lifetime score carried over (also visible in the DB:
   `SELECT * FROM players WHERE uid = '<your steamid64>'`).
4. **Join gate test**: stack several regulars on one side, then have a fresh account
   try to join that side — it should bounce to the lobby with the Teamstack message
   (needs real accumulated skill on that side, so this test only works once the DB
   has data).
5. **DLL smoke test without Arma**: call the DLL from a tiny harness (or
   `rundll32`-style test tool) with `101,76561198000000000` then `505,<id>` and check
   you get `[1, 0, 0]` for an unknown UID. Cheaper than a full server boot per
   iteration.

---

## 10. Operational notes

- **Never point two live servers at the same database** with AntiStack enabled (e.g.
  primary + hot-spare both running): 303/808 from each would fight over the `side`
  column and corrupt the side-skill sums. Keep the spare's server process stopped
  (`docs/ops/SERVER-INSTALL.md` §12).
- **Map rotation**: the map id written by 909 comes from `worldName` at init —
  modded rotation maps (Lingor, Eden, Napf, Tavi, Sahrani) all report as `1`. If you
  ever want per-map stats, extend the id mapping in `Init_Server.sqf` *and* the DLL
  together.
- The performance audit stream tags AntiStack work as `antistack_state`,
  `antistack_main`, `antistack_main_slice`, `antistack_flush`,
  `antistack_update_score` — use it to confirm the loops' cost stays negligible
  after installing a real DLL (the DB call should stay ~0 ms thanks to the async
  design; a spike here means the DLL is blocking).
- The lobby switch exists precisely so ops can A/B the module (`Parameters.hpp`
  comment) — if a new DLL misbehaves mid-event, flip AntiStack off at mission restart
  instead of hot-deleting files.
