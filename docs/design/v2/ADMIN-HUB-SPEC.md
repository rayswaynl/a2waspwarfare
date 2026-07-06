# Admin Hub READ-ONLY Spec

Status: READY for builder implementation  
Lane: 437  
Scope: admin pages and queries only. All pages in this spec are read-only.

## Auth

Use the existing Discord OAuth admin session described in `docs/superpowers/specs/2026-05-30-admin-shell-auth-design.md`. Do not add a second auth layer. All data-fetching functions must run server-side and must reject non-admin sessions before querying.

## Page Inventory

| Slug | Status | Purpose | Data source |
|---|---|---|---|
| `/admin` | Existing | Admin index/shell | Existing admin nav. |
| `/admin/appeals` | Existing | Moderation appeals | Existing admin API/query layer. |
| `/admin/bot` | Existing | Bot service/admin view | Existing bot status data. |
| `/admin/embeds` | Existing | Embed drafts/outbox view | Existing outbox/embed tables. |
| `/admin/logging` | Existing | Admin logs | Existing admin log queries. |
| `/admin/members` | Existing | Member/account views | Existing member/account tables. |
| `/admin/outbox` | Existing | Durable bot/web jobs | Existing `bot_outbox`. |
| `/admin/reports` | Existing | User reports | Existing reports queries. |
| `/admin/settings` | Existing | Config display/edit pages | Existing settings queries; keep V2 additions read-only. |
| `/admin/telemetry` | Existing, extend | Live telemetry dashboard | Existing telemetry + `matches` summary + Hetzner proxy. |
| `/admin/translations` | Existing | Copy/translation management | Existing translation tables. |
| `/admin/matches` | New | Round history browser and match detail | Postgres `matches`, `match_players`, `match_events`, `aicom_round_sides`. |
| `/admin/stats-health` | New | Ingest heartbeat, row counts, backfill progress | Postgres V2 stats tables + worker heartbeat. |

## `/admin/matches`

List view filters:

- world/map
- winner
- date range
- minimum player count
- backfilled/live

List query:

```sql
select
  m.round_key,
  m.world,
  m.map,
  m.winner,
  m.duration_sec,
  m.ended_at,
  m.player_count,
  m.backfilled,
  count(me.seq) filter (where me.event_type = 'KILL') as kill_events,
  count(me.seq) filter (where me.event_type = 'CAPTURE') as capture_events
from matches m
left join match_events me on me.round_key = m.round_key
where ($1::text is null or m.world = $1)
  and ($2::text is null or m.winner = $2)
  and ($3::timestamptz is null or m.ended_at >= $3)
  and ($4::timestamptz is null or m.ended_at <= $4)
group by m.round_key
order by m.ended_at desc
limit 100;
```

Detail query:

```sql
select *
from match_players
where round_key = $1
order by composite_score desc, infantry_kills desc, captures desc;
```

Timeline query:

```sql
select seq, event_type, event_time_sec, side, actor_name, target_name, town_name, distance_m
from match_events
where round_key = $1
order by seq asc;
```

Side summary query:

```sql
select side, towns_held, towns_captured, towns_lost, income, supply
from aicom_round_sides
where round_key = $1
order by side asc;
```

## `/admin/stats-health`

Panels:

- ingest heartbeat: last worker heartbeat, last parsed line time, last successful POST
- table freshness: max `created_at` per `match_events`, `matches`, `match_players`, `aicom_rounds`, `waspscale_samples`
- row counts: total rows and 24h rows per table
- backfill progress: current `backfill_run_id`, source file, rounds inserted, rounds skipped, parse warnings
- anomaly cards: stale ingest >30 min, match duration <120 sec, duplicate `ROUNDEND` skipped, seq gaps observed

Health query:

```sql
select 'match_events' as table_name, count(*) as rows, max(created_at) as newest from match_events
union all
select 'matches', count(*), max(created_at) from matches
union all
select 'match_players', count(*), max(created_at) from match_players
union all
select 'aicom_rounds', count(*), max(created_at) from aicom_rounds
union all
select 'waspscale_samples', count(*), max(created_at) from waspscale_samples;
```

## `/admin/telemetry` V2 Additions

Add:

- last completed round: winner, duration, map, player count
- 24h match count
- 7d match count
- latest V2 ingest age
- latest backfill run status

Query:

```sql
select
  count(*) filter (where ended_at >= now() - interval '24 hours') as matches_24h,
  count(*) filter (where ended_at >= now() - interval '7 days') as matches_7d,
  max(ended_at) as latest_round_end
from matches;
```

## Hetzner `:8080` Fold-In Coverage

| `stats.json` field/widget | Current `/admin/telemetry` target | Fold-in action | Retires `:8080` dependency? |
|---|---|---|---|
| `round` | Partial | Add last-round card from `matches` plus live proxy round label | Yes for round history. |
| `serverFps` | Partial/proxy | Keep live proxy widget; add freshness age | No, still live proxy. |
| `hcFps` | Partial/proxy | Keep live proxy widget; show HC count/freshness | No, still live proxy. |
| `aiWest`, `aiEast`, `aiGuer` | Partial/proxy | Add force-count strip | No, still live proxy. |
| group counts | Missing/partial | Add W/E/G group health card | No, until Postgres captures group telemetry. |
| perf benchmark history | Missing | Add trend from WASPSCALE samples | Yes once history is in Postgres. |
| match history | Missing | `/admin/matches` | Yes. |
| player stats | Public only | Link to public profiles and match_players detail | Yes. |

Admin hub can retire `:8080` for historical analysis after V2 ingest lands. It cannot fully retire `:8080` for live server state until every live-only proxy field has a durable Postgres sample path.

## Freshness Model

| Page/panel | Rendering |
|---|---|
| `/admin/matches` list/detail | `force-dynamic`; DB-backed historical data. |
| `/admin/stats-health` | `force-dynamic`; heartbeat must not cache. |
| `/admin/telemetry` live proxy widgets | `force-dynamic`; live server state. |
| `/admin/telemetry` 24h/7d match counts | `force-dynamic` initially; can cache 30s later. |

## Acceptance

- Every admin sub-page is accounted for.
- New match/stats pages have concrete read-only query skeletons.
- Data source is explicit: Postgres vs Hetzner HTTP proxy.
- No page in this spec creates, updates, or deletes gameplay, stats, or bot data.
