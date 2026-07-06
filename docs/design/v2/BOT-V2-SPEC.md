# Bot V2 Spec

Status: READY for builder implementation  
Lane: 439  
Scope: Discord bot behavior fed by V2 stats ingest.

## Features

1. Auto match report on `ROUNDEND`
2. `/mystats` slash command
3. Admin alert rules

All delivery uses `bot_outbox`; the web ingest path creates jobs, the bot drains jobs.

## Outbox Job Types

| Job type | Producer | Consumer | Dedup key |
|---|---|---|---|
| `match_report.post` | ingest/web API after `matches` insert | `match_reporter.py` | `round_key` |
| `admin_alert.ingest_stale` | scheduled health check | `match_reporter.py` | `alert_type + window_start` |
| `admin_alert.server_offline` | status reader/health check | `match_reporter.py` | `alert_type + offline_since` |
| `admin_alert.instant_match` | ingest/web API after `ROUNDEND` | `match_reporter.py` | `round_key` |
| `mystats.response` | slash command handler if deferred through outbox | stats cog | interaction id |

## Match Report Trigger

When ingest inserts a new `matches` row, it creates `match_report.post` with:

```json
{
  "roundKey": "<rptid>#<ordinal>",
  "channelEnv": "MATCH_REPORT_CHANNEL_ID"
}
```

The job must be created only after `matches` and `match_players` inserts finish. Duplicate retry attempts must no-op on the same `round_key`.

## Match Report Query

```sql
select round_key, world, map, winner, duration_sec, ended_at, player_count
from matches
where round_key = $1;
```

```sql
select steam_id64, display_name, side, composite_score, infantry_kills, vehicle_kills, air_kills,
       static_kills, structure_kills, hq_kills, deaths, captures, supply_value
from match_players
where round_key = $1
order by composite_score desc, captures desc, infantry_kills desc
limit 3;
```

```sql
select side, towns_held, towns_captured, towns_lost, income, supply
from aicom_round_sides
where round_key = $1;
```

## Match Report Embed

Title: `Chernarus Round Complete` or `<Map> Round Complete`  
Color:

- WEST/NATO: blue
- EAST/CSAT: red
- GUER/Insurgents: green/olive
- Unknown/no winner: neutral steel

Fields:

- `Winner`: `NATO`, `CSAT`, `Insurgents`, or `No winner recorded`
- `Map`: `Chernarus`, `Takistan`, `Zargabad`, etc.
- `Duration`: `h:mm:ss` for >=1h, otherwise `mm:ss`
- `Players`: integer
- `Top Players`: three lines: `1. Name - 1,234 score (12 kills, 3 captures)`
- `Town Count`: `NATO 8 / CSAT 6 / Insurgents 3` if side rows exist

Footer: `Round <round_key>`.

## Required MatchReport Bug Pre-Emptions

No prior implementation was verified in this sandbox session, so the builder must pre-empt these three known failure shapes:

1. GUER winner display: never render GUER as blank or `Resistance`; public copy says `Insurgents`.
2. Duration zero: if `duration_sec <= 0`, render `Duration: under 2 minutes` and create `admin_alert.instant_match`.
3. Duplicate suppression: retrying the same `ROUNDEND` must not post a second embed; enforce via `bot_outbox.dedup_key = round_key`.

## `/mystats`

Slash command: `/mystats`  
Access: any guild member.

Query:

```sql
select s.*
from account_links l
join ingame_stats s on s.steam_id64 = l.steam_id64
where l.discord_id = $1
order by s.updated_at desc
limit 1;
```

Hidden/opt-out logic:

- No account link: embed with account-link instructions.
- Linked but opted out: embed with opt-out confirmation and no stats.
- Linked and visible: embed same core fields as `CombatRecord.tsx`.

Embed fields:

- Score
- Infantry Kills
- Vehicle Kills
- Air Kills
- Static Kills
- HQ / MHQ Kills
- Deaths
- Captures
- Supply Runs
- Supplies Delivered
- Structures Built
- Defenses Built
- Longest Kill
- Best Kill Streak

## Admin Alerts

| Alert | Condition | Query/source | Channel |
|---|---|---|---|
| Ingest stale | no new `match_events` row for >30 minutes | `select max(created_at) from match_events` | `ADMIN_ALERT_CHANNEL_ID` |
| Server offline | `server_status.online = false` for >15 minutes | existing status reader table/source | `ADMIN_ALERT_CHANNEL_ID` |
| Instant match | `matches.duration_sec < 120` | `matches` insert trigger | `ADMIN_ALERT_CHANNEL_ID` |

Alert embeds must include condition, observed value, threshold, first seen, last checked, and a one-line operator action.

## Cog Design

New cog: `bot/cogs/match_reporter.py`

Responsibilities:

- drain `match_report.post`
- drain admin alert job types
- format embeds
- enforce channel env vars
- log success/failure back to outbox

Existing/extended cog: `bot/cogs/stats_reader.py`

Responsibilities:

- keep legacy stats reader if still needed
- own `/mystats`
- share stat formatting helper with match reporter if local patterns support it

## Acceptance

- All three features have trigger conditions, query SQL, embed fields, and outbox job types.
- Match report handles GUER, short duration, and duplicate retry.
- Bot never parses new V2 match data directly from RPT; it consumes DB/outbox state.
