# WASP Ingest Worker Spec

Status: READY for builder implementation  
Lane: 436  
Scope: RPT/file/HTTP ingestion only; no gameplay code.

## Inputs

The worker consumes these line families:

- `WASPSTAT|v1|PLAYERSTATS`
- `WASPSTAT|v1|KILL`
- `WASPSTAT|v1|CAPTURE`
- `WASPSTAT|v1|ROUNDEND`
- `AICOMSTAT|v2|EVENT`
- `WASPSCALE|v1|...`
- `WASPSCALE|v2|...`

It must tolerate CRLF, LF, trailing whitespace, and RPT prefixes before the token. It must reject malformed lines into a parse-error counter without stopping the tail.

## Parser Grammar

Use pipe-split only. Do not parse by regex except to strip a timestamp/RPT prefix before the first known token.

| Family | Required key | Required handling |
|---|---|---|
| `PLAYERSTATS` | `steam_id64`, `world`, stat fields | Latest row per `(round_key, steam_id64)` wins until `ROUNDEND`; final row becomes `match_players`. Also UPSERT aggregate `ingame_stats`. |
| `KILL` | `seq`, victim, class/category | Insert one `match_events` row with `event_type = 'KILL'`. Empty killer UID means AI/environment kill; empty victim UID means AI target. |
| `CAPTURE` | `seq`, town/camp, side | Insert `event_type = 'CAPTURE'`; side tokens normalize to `WEST`, `EAST`, `GUER`, or `UNKNOWN`. |
| `ROUNDEND` | winner, world/map, duration | Close current round, insert `matches`, flush buffered `match_players`, trigger Bot V2 outbox. |

Field positions must be copied directly from `docs/WASPSTAT-FORMAT.md` during implementation. The builder must add unit tests with one canonical sample line per family and one edge sample per family.

## AICOMSTAT v2 EVENT

The worker must parse the event family referenced by `AICOMSTAT-V2-Event-Vocabulary-Census.md`.

Required edge cases:

- 59 event families are accepted even if the app stores only raw JSON at first.
- Numeric side tokens are normalized: `0`/`west`, `1`/`east`, `2`/`guer`, `3`/`civilian`, otherwise `unknown`.
- `AI_SCUD_LOOP` may emit lowercase `all`; preserve raw token and normalize side to `ALL`.
- Unknown events are stored as `event_type = 'UNKNOWN_AICOM_EVENT'` with the original family in payload.

Storage target: existing AICOM append-only route/table, not `match_events`, unless the event is explicitly a match lifecycle marker.

## WASPSCALE Grammar

`WASPSCALE|v1` and `WASPSCALE|v2` lines keep the current append-only behavior used by `web/src/app/api/waspscale/route.ts`.

Decision:

- Live tail mode posts each parsed WASPSCALE row to the existing route.
- Backfill mode preserves source path, source line number, and `backfilled = true` where the table supports it.
- Schema mismatch is a parse warning, not fatal.

## MATCHSTART Synthetic Event

RPTs do not need a dedicated wire line. The worker creates `MATCHSTART` when either condition appears:

1. A mission/session boundary line is observed before the first WASPSTAT line after server start.
2. A new `ROUNDEND` appears after the prior round is closed and a later WASPSTAT event arrives.

`rptid` is computed from:

- RPT path
- first identity/session header line
- file length at close for archive mode
- md5 of the first 64 KiB plus last 64 KiB for stable retry identity

`round_key = <rptid>#<ordinal>`.

## Idempotency

Every DB insert uses the same keys as `STATS-V2-SCHEMA.md`:

- `matches`: `round_key`
- `match_events`: `(round_key, seq)`
- `match_players`: `(round_key, steam_id64)`
- AICOM/WASPSCALE append-only tables: use their existing unique source identity if present; otherwise add `source_path + source_line + raw_hash`.

Retries must be safe. `onConflictDoNothing` is correct for immutable event rows. Aggregate `ingame_stats` keeps the existing UPSERT behavior.

## Transport Decision Matrix

| Data | Live mode | Backfill mode | Reason |
|---|---|---|---|
| `PLAYERSTATS` aggregate | File-poll or HTTP POST to existing stats route | HTTP POST batches | Preserve current website behavior. |
| `match_events` | HTTP POST from worker to web API | HTTP POST batches | Append-only, low write contention, central auth. |
| `matches` | HTTP POST on `ROUNDEND` | HTTP POST after full round parse | Match close is transactional with players. |
| `match_players` | HTTP POST with `ROUNDEND` payload | HTTP POST after buffered stats | Requires final pre-roundend flush. |
| `AICOMSTAT` | Existing `/api/aicom-stats` route | Same route | Keep AICOM parser ownership centralized. |
| `WASPSCALE` | Existing `/api/waspscale` route | Same route | Keep current append-only contract. |

Default deployment: one worker on the box tails the live RPT and posts to the website API. The Discord bot consumes outbox jobs; it does not parse the RPT for new V2 match features.

## Backfill Procedure

Script outline only:

1. SSH to `livehost` read-only.
2. Enumerate `C:\WASP rpt-archive` chronologically.
3. For each RPT, compute `rptid`.
4. Ask DB/API for existing `round_key` values for that `rptid`.
5. Parse all WASPSTAT/AICOMSTAT/WASPSCALE lines.
6. Skip any already-ingested round.
7. POST round bundles to the same authenticated HTTP endpoints used by live mode.
8. Write a local JSONL backfill ledger with `source_path`, `rptid`, round count, inserted rows, skipped rows, parse warnings.

No archive mutation is allowed.

## HC-AI-Control Filter

Carry over the existing bot filter: rows where display name equals `HC-AI-Control`, starts with `HC`, or has an empty/non-player UID must not appear in public player stats or match top-3. Keep the raw event if it explains AI activity; exclude it only from player-facing ranking.

## Acceptance

- Grammar tables and field-position map are implemented against `docs/WASPSTAT-FORMAT.md`.
- Backfill and live modes hit identical write paths.
- Duplicate retry writes are harmless.
- Parse failures are counted and visible in `/admin/stats-health`.
