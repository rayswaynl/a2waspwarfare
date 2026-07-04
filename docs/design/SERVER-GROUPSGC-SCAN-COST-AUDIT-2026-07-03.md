# Server GroupsGC Scan-Cost Audit - 2026-07-03

Scope: fleet lane 110, source audit only. This page records the current
`server_groupsGC.sqf` scan shape on `origin/claude/build84-cmdcon36`
(`b1608b096eb4a02d7c213d794e22b8bc59df8df0`) and separates already-bounded
work from follow-up code-owner options.

This is deliberately separate from lane 48 group-cap hygiene. Lane 48 documents
whether group cleanup and cap telemetry exist; this page only tracks the cost
shape of the GC scans.

## Verdict

The prompt's original lane-110 warning is partially stale on the current target.
`server_groupsGC.sqf` still wakes every 60 seconds, and it still contains
`nearEntities`, `allGroups`, `vehicles`, and `allUnits` scans. The current source
does not run the most expensive pieces as broad unbounded per-group work:

- Empty-group GC still scans `allGroups` every 60 seconds, but it only collects
  zero-unit groups and deletes them in a second pass.
- BASE-GC still scans side groups and vehicles, but the enemy `nearEntities`
  calls are behind candidate gates: own side, server-local leader or vehicle,
  alive, non-player, in own-HQ range, not persistent, not AICOM-owned, not
  side-patrol, idle, and no player aboard for vehicles.
- Group count telemetry is one cheap `allGroups` pass per 60 seconds, and the
  counts are cached into missionNamespace for other systems.
- The expensive per-source group-audit dump is throttled by
  `WFBE_C_GROUPAUDIT_EVERY` and defaults to once every fifth 5-minute window,
  approximately every 25 minutes.
- The audit's unit/delegation math uses one combined `allUnits` pass inside that
  throttled branch rather than multiple separate passes.

Because of that, a blind rewrite of `server_groupsGC.sqf` is not recommended
without live timing evidence. The next code owner should use RPT `auditMs`,
`GCSTAT`, and server FPS windows to decide whether the remaining enumerations
are actually hot in long matches.

## Source Evidence

- `server_groupsGC.sqf:16-17` runs one main loop with `sleep 60`.
- `server_groupsGC.sqf:28-45` collects empty non-persistent groups first, then
  deletes them after the `allGroups` iteration.
- `server_groupsGC.sqf:57-72` gates BASE-GC behind `WFBE_C_BASEGC_ENABLE` and
  builds one live-player snapshot for the BASE-GC pass. With the default
  `WFBE_C_BASEGC_PLAYER_GUARD = 0`, that snapshot counts players but does not
  build proximity candidates.
- `server_groupsGC.sqf:128-150` places the group-side enemy scan behind side,
  non-empty, server-local leader, alive non-player, own-HQ range, persistence,
  AICOM ownership, and side-patrol guards.
- `server_groupsGC.sqf:219-238` places the vehicle enemy scan behind local,
  alive, Air/Tank/APC, crewed, own side, no player aboard, not commander/town
  owned, own-HQ range, and idle/immobile guards.
- `server_groupsGC.sqf:330-349` performs the 60-second group count pass,
  publishes `wfbe_grpcnt_west/east/guer/t`, and emits one `GCSTAT|v1|` line
  using values already in hand.
- `server_groupsGC.sqf:440-465` throttles the expensive audit branch with
  `WFBE_C_GROUPAUDIT_EVERY` and folds unit counts plus delegation totals into
  one `allUnits` pass.
- `Init_CommonConstants.sqf` defaults `WFBE_C_GROUPAUDIT_EVERY = 5` and documents
  the measured older audit cost as about 2100 ms on 276 groups, while preserving
  a one-parameter rollback to every 5-minute window by setting the value to 1.

## Residual Follow-Up Options

Only take these as source work after a live or soak RPT shows lane-110 cost still
matters:

- Snapshot `allGroups` and `vehicles` once per BASE-GC cycle after empty-group
  deletion, then reuse those arrays for the three side passes. This preserves
  behavior but reduces repeated engine-list materialization.
- Pre-bucket BASE-GC candidates by side before the side loop, preserving the
  current side, locality, ownership, range, idle, and player guards.
- Add a lightweight `BASEGCSTAT|v1|` line with candidate counts and elapsed ms if
  operators need proof before changing behavior.

Do not lower the `nearEntities` guard frequency just to reduce cost. That scan
is part of the continuous idle/combat safety contract: it prevents BASE-GC from
re-adopting or deleting units that are close to enemies.

## Verification

- `gh pr list` checked no open lane-110 PR and no active lane-110 claim before
  this docs-only pass.
- Source anchors above were read from `origin/claude/build84-cmdcon36`.
- No mission source, generated mirror, package artifact, live server, or
  LoadoutManager output is changed by this audit.
