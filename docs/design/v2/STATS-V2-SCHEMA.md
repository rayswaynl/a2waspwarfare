# Stats V2 Schema + Migration Spec

Status: READY for builder implementation  
Lane: 435  
Scope: website + bot stats persistence only; no gameplay code.

## Source Contract

Primary sources named by the sprint roster:

- `db/src/schema.ts`: current `ingame_stats`, `aicom_rounds`, `aicom_round_sides`, `waspscale_samples`
- migrations `0009` through `0018`
- `docs/WASPSTAT-FORMAT.md`: authoritative wire format for `PLAYERSTATS`, `KILL`, `CAPTURE`, `ROUNDEND`
- `web/src/app/api/stats/route.ts`: current HTTP ingest and `compositeScore()`
- `bot/cogs/stats_reader.py`: legacy file-mode UPSERT and `_WEIGHTS`
- `web/src/lib/leaderboard.ts`: public `StatRow`

This spec adds append-only match detail alongside the existing aggregate `ingame_stats` table. It must not require a destructive migration of current player totals.

## Existing Table Expectations

`ingame_stats` remains the long-lived public aggregate row keyed by `steam_id64` and `world`. Before migration, confirm it already carries these 15 wire-derived counters plus current extended fields:

| Wire field | DB column | Notes |
|---|---|---|
| `WFBE_STAT_INF_KILLS` | `infantry_kills` | Infantry kill total. |
| `WFBE_STAT_VEH_KILLS` | `vehicle_kills` | Non-air vehicle kill total. |
| `WFBE_STAT_AIR_KILLS` | `air_kills` | Aircraft kill total. |
| `WFBE_STAT_STATIC_KILLS` | `static_kills` | Static weapon kill total. |
| `WFBE_STAT_STRUCT_KILLS` | `structure_kills` | Buildings/defenses destroyed. |
| `WFBE_STAT_HQ_KILLS` | `hq_kills` | HQ/MHQ kills. |
| `WFBE_STAT_DEATHS` | `deaths` | Player deaths. |
| `WFBE_STAT_CAPTURES` | `captures` | Town/camp capture contribution. |
| `WFBE_STAT_ASSISTS` | `assists` | Capture/combat assist credit if emitted; otherwise zero-filled. |
| `WFBE_STAT_SUPPLY_RUNS` | `supply_runs` | Completed supply missions. |
| `WFBE_STAT_SUPPLY_VALUE` | `supply_value` | Supply value delivered. |
| `WFBE_STAT_REPAIRS` | `repairs` | Repair/service actions if emitted; otherwise zero-filled. |
| `WFBE_STAT_STRUCT_BUILT` | `structures_built` | Commander/base structures built. |
| `WFBE_STAT_DEFENSES_BUILT` | `defenses_built` | Defense objects built. |
| `WFBE_STAT_PLAYTIME_SEC` | `playtime_seconds` | Seconds present in match/session. |

Existing extended fields must remain: `engine_score`, `kill_streak_max`, `longest_kill_m`, `display_name`.

If `docs/WASPSTAT-FORMAT.md` names differ from the draft DB names above, the builder must keep the existing DB column names and update the parser mapping, not rename live aggregate columns.

## New Drizzle DDL Draft

```ts
export const matches = pgTable(
  "matches",
  {
    roundKey: text("round_key").primaryKey(),
    rptId: text("rpt_id").notNull(),
    ordinal: integer("ordinal").notNull(),
    world: text("world").notNull(),
    map: text("map").notNull(),
    winner: text("winner").notNull(),
    durationSec: integer("duration_sec").notNull(),
    endedAt: timestamp("ended_at", { withTimezone: true }).notNull(),
    playerCount: integer("player_count").notNull().default(0),
    sourcePath: text("source_path"),
    backfillRunId: text("backfill_run_id"),
    backfilled: boolean("backfilled").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    worldIdx: index("matches_world_idx").on(table.world),
    endedAtIdx: index("matches_ended_at_idx").on(table.endedAt),
    winnerIdx: index("matches_winner_idx").on(table.winner),
    rptOrdinalUnique: uniqueIndex("matches_rpt_ordinal_uidx").on(table.rptId, table.ordinal),
  }),
);

export const matchEvents = pgTable(
  "match_events",
  {
    roundKey: text("round_key").notNull().references(() => matches.roundKey, { onDelete: "cascade" }),
    seq: integer("seq").notNull(),
    eventType: text("event_type").notNull(),
    eventTimeSec: integer("event_time_sec"),
    world: text("world"),
    side: text("side"),
    actorSteamId64: text("actor_steam_id64"),
    actorName: text("actor_name"),
    targetSteamId64: text("target_steam_id64"),
    targetName: text("target_name"),
    targetClass: text("target_class"),
    weaponClass: text("weapon_class"),
    distanceM: integer("distance_m"),
    townName: text("town_name"),
    rawLine: text("raw_line").notNull(),
    sourcePath: text("source_path"),
    backfillRunId: text("backfill_run_id"),
    backfilled: boolean("backfilled").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    pk: primaryKey({ columns: [table.roundKey, table.seq] }),
    roundIdx: index("match_events_round_key_idx").on(table.roundKey),
    seqIdx: index("match_events_seq_idx").on(table.seq),
    eventTypeIdx: index("match_events_event_type_idx").on(table.eventType),
    actorIdx: index("match_events_actor_idx").on(table.actorSteamId64),
  }),
);

export const matchPlayers = pgTable(
  "match_players",
  {
    roundKey: text("round_key").notNull().references(() => matches.roundKey, { onDelete: "cascade" }),
    steamId64: text("steam_id64").notNull(),
    displayName: text("display_name"),
    side: text("side").notNull(),
    world: text("world").notNull(),
    infantryKills: integer("infantry_kills").notNull().default(0),
    vehicleKills: integer("vehicle_kills").notNull().default(0),
    airKills: integer("air_kills").notNull().default(0),
    staticKills: integer("static_kills").notNull().default(0),
    structureKills: integer("structure_kills").notNull().default(0),
    hqKills: integer("hq_kills").notNull().default(0),
    deaths: integer("deaths").notNull().default(0),
    captures: integer("captures").notNull().default(0),
    assists: integer("assists").notNull().default(0),
    supplyRuns: integer("supply_runs").notNull().default(0),
    supplyValue: integer("supply_value").notNull().default(0),
    repairs: integer("repairs").notNull().default(0),
    structuresBuilt: integer("structures_built").notNull().default(0),
    defensesBuilt: integer("defenses_built").notNull().default(0),
    playtimeSeconds: integer("playtime_seconds").notNull().default(0),
    engineScore: integer("engine_score").notNull().default(0),
    compositeScore: integer("composite_score").notNull().default(0),
    killStreakMax: integer("kill_streak_max").notNull().default(0),
    longestKillM: integer("longest_kill_m").notNull().default(0),
    sourcePath: text("source_path"),
    backfillRunId: text("backfill_run_id"),
    backfilled: boolean("backfilled").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    pk: primaryKey({ columns: [table.roundKey, table.steamId64] }),
    steamIdx: index("match_players_steam_idx").on(table.steamId64),
    worldIdx: index("match_players_world_idx").on(table.world),
    sideIdx: index("match_players_side_idx").on(table.side),
    scoreIdx: index("match_players_composite_score_idx").on(table.compositeScore),
  }),
);
```

## Idempotency

`round_key` is always `<rptid>#<ordinal>`.

- `rptid`: stable file/session fingerprint, preferably the md5 of the RPT identity header plus file length. For live tail mode, use a temporary id until `ROUNDEND`, then resolve by source path + first mission boundary hash.
- `ordinal`: one-based round counter inside that RPT, incremented at each `MATCHSTART` boundary and closed at `ROUNDEND`.
- `match_events`: primary key is `(round_key, seq)`. Retry inserts use `onConflictDoNothing`.
- `matches`: primary key is `round_key`; `(rpt_id, ordinal)` is also unique.
- `match_players`: primary key is `(round_key, steam_id64)`. The row is built from the last `PLAYERSTATS` flush at or before `ROUNDEND`.

Sequence gaps are not repaired. Store the gap in ingest logs and continue; duplicate seq rows are skipped.

## Rollup Query SQL

Per-world aggregate:

```sql
select
  mp.world,
  mp.steam_id64,
  max(mp.display_name) as display_name,
  count(distinct mp.round_key) as matches_played,
  sum(mp.infantry_kills) as infantry_kills,
  sum(mp.vehicle_kills) as vehicle_kills,
  sum(mp.air_kills) as air_kills,
  sum(mp.static_kills) as static_kills,
  sum(mp.structure_kills) as structure_kills,
  sum(mp.hq_kills) as hq_kills,
  sum(mp.deaths) as deaths,
  sum(mp.captures) as captures,
  sum(mp.supply_runs) as supply_runs,
  sum(mp.supply_value) as supply_value,
  sum(mp.composite_score) as composite_score,
  max(mp.kill_streak_max) as kill_streak_max,
  max(mp.longest_kill_m) as longest_kill_m
from match_players mp
join matches m on m.round_key = mp.round_key
group by mp.world, mp.steam_id64;
```

Weekly player stats:

```sql
select
  mp.steam_id64,
  max(mp.display_name) as display_name,
  date_trunc('week', m.ended_at) as week_start,
  count(*) as matches_played,
  sum(mp.composite_score) as composite_score,
  sum(mp.infantry_kills + mp.vehicle_kills + mp.air_kills + mp.static_kills + mp.structure_kills + mp.hq_kills) as kills,
  sum(mp.deaths) as deaths,
  sum(mp.captures) as captures,
  sum(mp.supply_value) as supply_value
from match_players mp
join matches m on m.round_key = mp.round_key
where m.ended_at >= now() - interval '8 weeks'
group by mp.steam_id64, date_trunc('week', m.ended_at)
order by week_start desc, composite_score desc;
```

## Migration Strategy

1. Add the three tables in a new migration after current head.
2. Add no columns to `ingame_stats` unless verification finds a missing extended field.
3. Ship ingest in shadow mode first: write match tables and keep legacy `ingame_stats` UPSERT path unchanged.
4. Backfill with `backfilled = true` and a unique `backfill_run_id` for every inserted row.
5. Stop and report if any existing `round_key` would produce different `ROUNDEND` data than the stored `matches` row.

## Acceptance

- Drizzle DDL includes PKs, FKs, indexes, and backfill columns.
- Rollup SQL covers per-world and weekly views.
- `round_key` and conflict behavior are deterministic.
- Existing aggregate leaderboard behavior remains live during migration.
