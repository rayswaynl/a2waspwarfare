# SIDESCORE dual-field contract (public side-activity vs engine scoreboard)

**Task:** `wasp-score-dashboard-build-20260722` (build phase of the research card
`wasp-score-dashboard-source-20260722`).
**Feature flag:** `WFBE_C_SIDESCORE` (registered in `Common/Init/Init_CommonConstants.sqf`,
**default 0**). Flag off = byte-identical to HEAD end to end (no counters, no RPT line, no
stats.json fields). Flag on = the honest side-activity data below flows RPT -> generator ->
stats.json, ready for the miksuu web/bot consumer.

## Why

Public `SCORE|v1` (`server_groupsGC.sqf`) is built from the engine command `scoreSide`, which
credits **player-driven** score only. When a side is AI-only (typical: all humans on one side),
that side's public score freezes at 0 even while it fights — e.g. an observed 232-min match read
`west=0 / east=594` while WASPSTAT logged ~705 GUER kills + 7 town captures for the AI WEST side.
The public dashboard then misrepresents the battle. `scoreSide` is the wrong metric for a mostly-AI
war. This change is **additive**: `SCORE|v1` is untouched; a new honest line is published alongside.

## Mission RPT wire format (new, additive)

Emitted on the existing 60s GC cadence next to `SCORE|v1` / `CONTESTED|v1`, only when the flag is on:

```
SIDESCORE|v1|playerWest=<n>|playerEast=<n>|killWest=<n>|killEast=<n>|killGuer=<n>|capWest=<n>|capEast=<n>|capGuer=<n>|t=<roundMin>
```

- `playerWest/playerEast` — engine `scoreSide west/east` (the SAME player-driven number `SCORE|v1`
  carries; kept for continuity, NOT the honest battle metric).
- `killWest/killEast/killGuer` — running per-side kill counters incremented at the WASPSTAT `KILL`
  emit site (`RequestOnUnitKilled.sqf`). **AI-inclusive**: every unit (AI too) routes its `Killed`
  EH through this path, so an AI-only side is counted. Keyed by killer side; matches the `killerSide`
  field the generator already folds (`killsWest`/`killsEast`).
- `capWest/capEast/capGuer` — running per-side town-capture counters incremented once per real
  capture flip (`server_town.sqf`, inside the `if(_captured)` branch, credited to the capturing side).
- `t` — round minute (`round(time/60)`), same as `SCORE|v1`.

Counters reset naturally per mission instance (terrain rotation reloads the mission), matching how
`scoreSide` and `WFBE_WASPSTAT_SEQ` reset. These are mutual-knowledge combat aggregates (kills/captures
both sides already see in-game), NOT base/town-ownership intel — inside the 2026-06-21 competitive
integrity rule (analogous to the already-public `allTime.killsByWest/East`).

## Generator -> stats.json (`Tools/Ops/Update-PublicStats.ps1`)

The generator parses the LAST `SIDESCORE|v1` line of the post-MISSINIT window and adds three fields to
`currentRound` (all `null` when the flag is off / no line present, so nothing renders — unchanged):

```jsonc
"currentRound": {
  "score":        { "west": <killWest>, "east": <killEast> },        // HONEST battle score (AI-inclusive kills)
  "playerScore":  { "west": <playerWest>, "east": <playerEast> },     // engine scoreSide (player-driven), for reference
  "sideActivity": {
    "west": { "kills": <killWest>, "captures": <capWest> },
    "east": { "kills": <killEast>, "captures": <capEast> },
    "guer": { "kills": <killGuer>, "captures": <capGuer> }
  }
}
```

`currentRound.score` is the field the web normalizer (`normalizeStats.ts`) already reads (previously
never populated). Setting it to AI-inclusive side kills makes the existing web path honest with **no
web code change required** for the data itself.

## Miksuu consumer follow-up (separate repo `rayswaynl/miksuus-website-discord-bot`)

Additive — no field renames, so nothing breaks if the web is updated later:

1. `web/src/lib/wasp/types.ts` / `normalizeStats.ts`: accept the new optional `playerScore` +
   `sideActivity` (keep `score` = honest activity; keep `playerScore` separate). `score` is already
   read; it will now be non-zero for AI-only sides.
2. `web/src/components/wasp/LiveStatTiles.tsx`: render a **battle-score / side-activity** tile from
   `score` (or `sideActivity.kills`); label the engine number `playerScore` distinctly (e.g.
   "PLAYER SCOREBOARD" vs "SIDE ACTIVITY") to satisfy the public-stats quality contract (insight, not
   a raw misleading number). Do NOT present `scoreSide` as "who is winning the war".
3. Tests: fixture with `playerScore.west=0` + `sideActivity.west.kills=705` (humans-all-EAST) asserting
   the honest tile is non-zero.
4. `bot/cogs/status_reader.py`: `blufor_score`/`opfor_score` still map to army force size (unchanged);
   if a "battle activity" number is wanted in Discord, source it from `sideActivity`, not `scoreSide`.

## Rollout

1. Land this draft PR (mission + generator) after independent review (builder != reviewer).
2. Owner sets `WFBE_C_SIDESCORE = 1` (or lobby param) when ready; redeploy mission.
3. Land the miksuu web/bot tile as a separate PR against `miksuus-website-discord-bot`.

No agent deploys to the live server; PRs are the only output.
