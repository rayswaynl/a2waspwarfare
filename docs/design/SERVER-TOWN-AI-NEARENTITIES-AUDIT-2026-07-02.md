# Lane 106 - server_town_ai nearEntities audit

Date: 2026-07-02
Base: `origin/claude/build84-cmdcon36` at `b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`
Scope: lane 106, server-side town-AI activation scan cost

## Verdict

Lane 106 is still a real performance candidate, but the prompt wording is partly stale on the current
target. The live target does not scan "up to 1800m" by default. It scans each eligible town at a 600m
base range, with active and inactive coefficients both defaulting to `1`.

This PR does not narrow classes, reduce range, or change town activation behavior. It makes the existing
`town_activation_scan` performance probe measure the expensive `nearEntities` call it was meant to cover,
then records the current source-backed status so the next worker can compare real RPT data before changing
combat-AI behavior.

## Current source evidence

| Area | Evidence | Current status |
| --- | --- | --- |
| Town source array | `Common/Init/Init_Towns.sqf:6` seeds `towns` from `[0,0,0] nearEntities [["LocationLogicDepot"], 100000]`. | Mission scan count tracks depot/town logics, not `LocationLogicCity`. |
| Map counts | `mission.sqm` contains 46 `LocationLogicDepot` objects on Chernarus and 33 on Takistan. | Worst-case sweep is one activation scan per eligible known-side town. |
| FSM launch | `Server/Init/Init_Server.sqf:1018-1021` runs `Server/FSM/server_town_ai.sqf` when town defender or occupation AI is enabled. | Runtime path is live when town AI is enabled. |
| Scan classes | `Server/FSM/server_town_ai.sqf:118-120` scans `["Man","Car","Motorcycle","Tank","Air","Ship"]`, then applies `unitsBelowHeight 20`. | Broad class list remains; no class-cache or split cadence exists. |
| Cadence | `server_town_ai.sqf:466-470` sleeps `0.05` after each town, then `5` seconds after the sweep. | Cadence is roughly `5s + town_count * 0.05s + work time`, not a strict every-5s full sweep. |
| Range default | `Init_CommonConstants.sqf:1443-1446` defines `WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE = 0`, base range `600`, active coefficient `1`, inactive coefficient `1`. | A default-off range override already exists, but default behavior is the legacy 600m scan. |
| Related lane 107 | `Init_CommonConstants.sqf:1142-1144` and `server_town_camp.sqf:15-20,105-107` already add default-off camp-scan throttles. | Do not re-open lane 107 as part of lane 106. |
| Related lane 115 | `Init_CommonConstants.sqf:255` and `server_town_ai.sqf:3-10,65` already add startup pacing with default legacy behavior. | Do not re-open lane 115 as part of lane 106. |
| Existing probe issue | Before this PR, `server_town_ai.sqf` set `_scanStart = diag_tickTime` after the `nearEntities` line. | The `town_activation_scan` metric did not include the actual broad scan cost. This PR fixes only that instrumentation timing. |

Official command references for future implementation review:
Bohemia Interactive `nearEntities`: https://community.bistudio.com/wiki/nearEntities
Bohemia Interactive `unitsBelowHeight`: https://community.bistudio.com/wiki/unitsBelowHeight

## What changed in this PR

`Server/FSM/server_town_ai.sqf` now starts `_scanStart` immediately before:

```sqf
_detected = (_town nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"],_dynRange]) unitsBelowHeight 20;
```

The resulting `PerformanceAudit_Record` row keeps the same name, `town_activation_scan`, but now covers:

- the broad `nearEntities` lookup
- `unitsBelowHeight 20`
- defender filtering
- hostile-side filtering
- `GetAreaEnemiesCount`

No activation flags, ranges, class arrays, sleeps, or defaults changed.

## Why not narrow the scan in this lane

The broad class list has gameplay meaning:

- `Man` wakes towns for infantry, players and bought AI.
- Land vehicles and ships matter for mounted units, service/support movement and naval-HVT edges.
- `Air` drives the air-only activation path through `wfbe_active_air`.
- The scan feeds both activation and deactivation safety; false negatives can despawn or fail to spawn
  garrisons around an active fight.

Because this logic sits on the town-defense boundary, the safe next step is measurement, not a blind class
or range reduction. The current target already has an inactive range override, so the operator can trial a
smaller range in a controlled branch or owner-run test without mixing it with a class-list change.

## Recommended follow-up

Use the fixed `town_activation_scan` metric in a soak with performance audit enabled. Compare the resulting
`Tools/PerformanceAuditAnalyzer` outputs by session:

- `performance_by_script.csv` for weighted average, total ms and max ms on `town_activation_scan`
- `performance_spikes.csv` for repeated 10/25/50/100ms spikes
- `performance_extra_fields.csv` for `extra_town`, `extra_detected`, `extra_defendersIgnored` and
  `extra_enemies` context

Only if repeated server-side spikes show up should lane 106 move from measurement to behavior. Preferred
safe experiments, one at a time:

1. Trial the existing default-off range override with a lower base range and verify town activation,
   deactivation and air-only activations from RPT.
2. Add a new default-off split-cadence flag that keeps `Man` every sweep but scans vehicle classes less often.
3. Add a source-level reason table for any class removed from the scan, with a repro showing the removed class
   is redundant for activation and deactivation.

Do not combine range, cadence and class-list changes in one PR. That would make a town-defense regression
hard to grade.
