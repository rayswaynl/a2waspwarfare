# Player Stats Page UX Spec

Status: READY for builder implementation  
Lane: 440  
Scope: public player profile UX and query contract.

## Component Tree

`PlayerProfilePage`

- `ProfileHero`
- `ProfilePrivacyNotice`
- `CombatRecordSection`
- `LogisticsSection`
- `BuilderSection`
- `PersonalBestsSection`
- `RecentMatchesTable`
- `StatsEmptyState`

## Hero

Purpose: identify the player and give the fastest read of their battlefield profile.

Content:

- display name
- side badge from latest known side: NATO, CSAT, Insurgents, Mixed/Unknown
- total score
- playtime
- kill/death ratio
- profile visibility state

Layout:

- Gunmetal/steel surface
- chalk-style heading
- orange focal numbers for score and K/D
- no marketing copy

## Sections

### Combat Record

Reuse the existing `CombatRecord.tsx` grid. Add computed K/D beside the kill cells.

Cells:

- Infantry Kills
- Vehicle Kills
- Air Kills
- Static Kills
- Structure Kills
- HQ / MHQ Kills
- Deaths
- Captures

### Logistics

Cells:

- Supply Runs
- Supplies Delivered
- Repairs
- Playtime

### Builder

Cells:

- Structures Built
- Defenses Built
- Support Actions if present in schema

### Personal Bests

Cells:

- Best Kill Streak: `killStreakMax`
- Longest Kill: `longestKillM`, formatted in m below 1000 and km at 1000+
- Engine Score: `engineScore`

### Recent Matches

Table columns:

- Date
- Map
- Side
- Winner
- Duration
- Score
- Kills
- Deaths
- Captures
- Supply

Click target: `/admin/matches` only for admins; public users see no admin link.

## Query Contract

Extend `getPublicProfile(steamId64)` to return:

```ts
type PublicProfileV2 = {
  steamId64: string;
  displayName: string;
  hidden: boolean;
  linked: boolean;
  world: string | null;
  side: "WEST" | "EAST" | "GUER" | "UNKNOWN" | null;
  playtimeSeconds: number;
  engineScore: number;
  killStreakMax: number;
  longestKillM: number;
  stats: StatRow;
};
```

Profile query:

```sql
select
  s.*,
  coalesce(nullif(s.display_name, ''), 'Soldier #' || right(s.steam_id64, 4)) as public_display_name,
  s.engine_score,
  s.kill_streak_max,
  s.longest_kill_m,
  s.playtime_seconds,
  latest.side as latest_side
from ingame_stats s
left join lateral (
  select side
  from match_players mp
  where mp.steam_id64 = s.steam_id64
  order by mp.created_at desc
  limit 1
) latest on true
where s.steam_id64 = $1;
```

Add `getPlayerMatchHistory(steamId64, limit = 10)`:

```sql
select
  m.round_key,
  m.ended_at,
  m.world,
  m.map,
  m.winner,
  m.duration_sec,
  mp.side,
  mp.composite_score,
  mp.infantry_kills + mp.vehicle_kills + mp.air_kills + mp.static_kills + mp.structure_kills + mp.hq_kills as kills,
  mp.deaths,
  mp.captures,
  mp.supply_value
from match_players mp
join matches m on m.round_key = mp.round_key
where mp.steam_id64 = $1
order by m.ended_at desc
limit $2;
```

## Privacy Matrix

| State | Hero | Stats | Match history |
|---|---|---|---|
| Visible linked profile | Real display name | Full public stats | Last 10 matches |
| Visible unlinked profile | `Soldier #XXXX` | Full public stats | Last 10 matches |
| Hidden by PRIV-04 | `Profile Hidden` | No stat grid | No match table |
| No stats row | Display fallback | Empty state | Empty state |

PRIV-04 remains unchanged.

## Empty States

All-zero stats row:

`Stats arriving once the server syncs. Play a full round and check back after the next ingest.`

No match history:

`No completed matches recorded yet.`

Hidden:

`Profile Hidden`

## Brand Notes

Use the Miksuu/WASP brand direction referenced by `2026-05-30-miksuus-warfare-brand-design.md`:

- gunmetal and steel surfaces
- orange focal numbers
- chalk headings
- dense operational layout
- no oversized hero marketing treatment

## Acceptance

- Component tree is explicit.
- Query SQL covers extended fields and match history.
- Privacy states are deterministic.
- Empty state prevents an all-zero grid from looking like real performance.
