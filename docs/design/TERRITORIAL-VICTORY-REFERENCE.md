# Territorial Victory Reference

Ray's cmdcon41 territorial win mode is implemented on the build84/cmdcon36 line. This page is the source-side
reference for operators and future agents: what toggles it, how the clock behaves, what RPT tokens prove it,
and which round-end path it uses.

## Live anchors

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:862-864` registers the
  territorial defaults: `WFBE_C_VICTORY_TERRITORIAL = 1`, `WFBE_C_VICTORY_TERRITORIAL_FRAC = 0.8`, and
  `WFBE_C_VICTORY_TERRITORIAL_MINS = 30`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_victory_threeway.sqf:41-54` documents the
  mode and gates the clock loop.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_victory_threeway.sqf:59-119` starts,
  advances, announces, completes, or breaks each side's territorial clock.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_victory_threeway.sqf:145-171` folds a
  completed territorial marker into the existing victory award condition.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_victory_threeway.sqf:179-198` sends the
  same endgame event, `WF_Winner`, WASPSTAT `ROUNDEND`, and game-end log as HQ/factory or all-town wins.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1178` keeps
  `WFBE_C_ENDGAME_HOLD = 45` so the winner-cam has time to play before `failMission`.

## Controls

| Constant | Default | Meaning |
|---|---:|---|
| `WFBE_C_VICTORY_TERRITORIAL` | `1` | Master enable. Set `0` to make the territorial clock inert without editing the FSM. |
| `WFBE_C_VICTORY_TERRITORIAL_FRAC` | `0.8` | Required live town share. The FSM checks `_held / _total >= _terrFrac`. |
| `WFBE_C_VICTORY_TERRITORIAL_MINS` | `30` | Unbroken minutes at or above the required share before the side is marked as territorial winner. |
| `WFBE_C_ENDGAME_HOLD` | `45` | Seconds to hold the finished round open after a winner is set. |

Endgame soft-forcing is separate. `WFBE_C_ENDGAME_FORCE_ENABLE` defaults to `0` at
`Init_CommonConstants.sqf:612`, and when disabled the victory FSM publishes neutral
`WFBE_ENDGAME_FORCE_MULT = 1`. If enabled later, it changes the economic taper only; it does not shorten or
lengthen the territorial clock.

## Runtime flow

The victory FSM evaluates territorial state once per normal victory loop while the round is not over.

1. The loop is skipped unless `WFBE_C_VICTORY_TERRITORIAL > 0` and `totalTowns > 0`.
2. Each evaluated side is taken from `WFBE_PRESENTSIDES - [WFBE_DEFENDER]`, so the defender/resistance side is
   not crowned by this path.
3. For each side, the FSM reads `GetTownsHeld`, compares the live ratio against
   `WFBE_C_VICTORY_TERRITORIAL_FRAC`, and stores state in missionNamespace keys built from side ID:
   `WFBE_TERRITORIAL_CLOCK_<sid>`, `WFBE_TERRITORIAL_MILE_<sid>`, and `WFBE_TERRITORIAL_WIN_<sid>`.
4. Crossing the threshold starts the clock, resets the milestone bucket, and sends a `DashboardAnnounce` to
   all clients.
5. Staying above threshold advances the clock. Milestone announcements fire once at the 20, 10, 5, and 1
   minute buckets.
6. Reaching the full hold time sets `WFBE_TERRITORIAL_WIN_<sid> = 1`.
7. Dropping below threshold resets the clock, milestone bucket, and win marker, then announces that the grip
   was broken.
8. The normal victory condition later ORs `_terrWin` with HQ/factory loss and all-town supremacy. Territorial
   completion crowns the evaluated side, sets `WF_Winner`, emits WASPSTAT `ROUNDEND` when stat logging is
   enabled, and calls the same `LogGameEnd` path as the other win types.

The `_needed` value logged for humans is display-only. The active check is the ratio comparison, which avoids
off-by-one ambiguity on odd town counts.

## Operator RPT tokens

Watch the server RPT for these source tokens during a soak:

- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|clock-start held<H>/<T> mins<M>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|milestone-20min held<H>/<T>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|milestone-10min held<H>/<T>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|milestone-5min held<H>/<T>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|milestone-1min held<H>/<T>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|clock-broken held<H>/<T>`
- `AICOMSTAT|v1|EVENT|<side>|<minute>|VICTORY_TERRITORIAL|win-awarded held<H>/<T>`
- `WASPSTAT|v1|<seq>|ROUNDEND|<winnerSide>|<durationSec>|<map>` when `WFBE_C_STATLOG == 1`.

If endgame soft-forcing is enabled for a separate test, its proof token is
`AICOMSTAT|v1|EVENT|ALL|<minute>|ENDGAME_FORCE|mult<N>`.

## Validation notes

- For a local clock-start test, set a side to hold at least `WFBE_C_VICTORY_TERRITORIAL_FRAC` of `totalTowns`
  and watch for the `clock-start` token plus the global dashboard announcement.
- For a broken-clock test, drop that side below the fraction before `WFBE_C_VICTORY_TERRITORIAL_MINS` expires
  and confirm `clock-broken` appears and the side can only win by restarting the full hold.
- For a completion test, temporarily lower `WFBE_C_VICTORY_TERRITORIAL_MINS` in a local profile/test build,
  hold the ratio unbroken, and confirm `win-awarded`, `WF_Winner`, `HandleSpecial ["endgame", sideId]`,
  WASPSTAT `ROUNDEND` if enabled, and the normal game-end log.
- Do not use `WFBE_C_VICTORY_THREEWAY` as the territorial toggle. The victory FSM intentionally runs standard
  detection unconditionally and reads the territorial constants separately.

## Guardrails

- This mode does not alter HQ/factory destruction victory or all-town supremacy; it adds a third trigger into
  the same award block.
- This mode does not require mission packaging or a client cache bump by itself. Behavior is controlled by
  constants already in the mission source.
- The maintained source is the Chernarus mission tree. Takistan inherits mission changes through
  `Tools/LoadoutManager`; this page is docs-only, so no mirror run is required for the documentation change.
