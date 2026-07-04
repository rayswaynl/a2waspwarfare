# Town Camp Scan Throttle Audit - 2026-07-02

Lane: 107, `server_town_camp` near-unthrottled scan
Base checked: `origin/claude/build84-cmdcon36@ca278c4bc7`
Scope: docs/source audit only. No mission source, parameters, defaults, generated Takistan files, live deploy, or package artifacts are changed here.

## Summary

The prompt row is stale on the current live target. Both maintained mission roots already have a default-preserving scan-throttle hook for `server_town_camp.sqf`.

The current implementation keeps legacy behavior by default:

- `WFBE_C_TOWN_CAMP_SCAN_THROTTLE` defaults to `0`.
- `server_town_camp.sqf` reads the throttle once at startup.
- With the throttle off, it keeps the legacy sleeps: `0.01` seconds after each camp and `0.1` seconds after each full pass.
- With the throttle on, it reads `WFBE_C_TOWN_CAMP_STEP_SLEEP` default `0.03` and `WFBE_C_TOWN_CAMP_LOOP_SLEEP` default `0.25`.

That means the performance lever exists without silently retuning live camp capture responsiveness.

## Verdict

No source patch is recommended in this lane. The current target already provides the intended server-performance knob in both maintained roots while preserving legacy default behavior.

The remaining decision is operational: Ray can opt into the slower camp scan sleeps for a soak, then compare server FPS, camp-capture responsiveness, and town-capture feel. This audit does not flip the default or add a lobby parameter row.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1142-1144` | Defines `WFBE_C_TOWN_CAMP_SCAN_THROTTLE = 0`, `WFBE_C_TOWN_CAMP_STEP_SLEEP = 0.03`, and `WFBE_C_TOWN_CAMP_LOOP_SLEEP = 0.25`. | Default preserves legacy scan cadence; opt-in values are present. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:1142-1144` | Same default-off throttle and sleep tunables. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_camp.sqf:1,15-20` | Declares throttle/sleep locals, reads `WFBE_C_TOWN_CAMP_SCAN_THROTTLE`, defaults to `0.01` and `0.1`, and only reads the slower tunables when throttle is greater than 0. | Legacy behavior is retained unless the owner opts in. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town_camp.sqf:1,15-20` | Same throttle read/default path. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_camp.sqf:33,105,107` | The existing `nearEntities["Man", _camp_range]` scan still runs per camp; the loop sleeps `_camp_step_sleep` after each camp and `_camp_loop_sleep` after a full pass. | The throttle controls scan cadence, not capture math/range. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town_camp.sqf:33,105,107` | Same scan and sleep consumers. | Mirror present. |

## Non-Findings

- This is not a live behavior change while `WFBE_C_TOWN_CAMP_SCAN_THROTTLE` remains `0`; the script still sleeps `0.01` per camp and `0.1` per full pass.
- No camp range, player range, capture rate, side ownership, flag texture, repair-camp, or town activation behavior changed in this lane.
- No `Rsc/Parameters.hpp` row exists for this tunable in this audit. If the owner wants operator control, that belongs in a parameter-row lane with the same default value.

## Suggested Smoke

For an owner-run soak only:

1. Keep `WFBE_C_TOWN_CAMP_SCAN_THROTTLE = 0` as the control.
2. Test `WFBE_C_TOWN_CAMP_SCAN_THROTTLE = 1` with the shipped `0.03` / `0.25` sleeps.
3. Compare server FPS, camp flip latency, and any player-visible capture sluggishness around contested towns.
4. Revert by returning the throttle to `0`.

## Verification

- `rg` confirmed `WFBE_C_TOWN_CAMP_SCAN_THROTTLE`, `WFBE_C_TOWN_CAMP_STEP_SLEEP`, and `WFBE_C_TOWN_CAMP_LOOP_SLEEP` exist in both maintained roots.
- `rg` confirmed both maintained `server_town_camp.sqf` copies read the throttle, preserve legacy sleeps while disabled, and use the computed sleep values after each camp and full pass.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
