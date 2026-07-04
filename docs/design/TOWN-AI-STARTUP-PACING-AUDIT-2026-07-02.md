# Town AI Startup Pacing Audit - 2026-07-02

Lane: 115, `server_town_ai` startup unthrottle
Base checked: `origin/claude/build84-cmdcon36@04b1ecf913`
Scope: docs/source audit only. No mission source, parameters, defaults, generated Takistan files, live deploy, or package artifacts are changed here.

## Summary

The prompt row is stale on the current live target. Both maintained mission roots already have a default-preserving startup pacing tunable for the `server_town_ai.sqf` initialization passes.

The current implementation keeps legacy behavior by default:

- `WFBE_C_TOWNS_STARTUP_SLEEP` defaults to `0`.
- `server_town_ai.sqf` reads the value at startup.
- Values at or below `0` are clamped to the legacy `0.01` second sleep.
- Both startup loops use the computed `_townInitSleep`.

That means the lane's performance lever exists without silently changing live pacing. A soak owner can test `0.05` or `0.10` as suggested by the inline constant comment.

## Verdict

No source patch is recommended in this lane. The current target already provides the intended performance knob in both maintained roots while preserving legacy default behavior.

The remaining decision is operational: Ray can opt into a larger startup sleep for large-map or high-town-count tests, then compare boot/early-match RPT cadence and server FPS. This audit does not flip the default or add a lobby parameter row.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:255` | Defines `WFBE_C_TOWNS_STARTUP_SLEEP = 0` when unset, with comment guidance to try `0.05-0.10`. | Default preserves legacy startup pacing. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:255` | Same default-0 tunable. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:1,3-4` | Declares `_townInitSleep`, reads `WFBE_C_TOWNS_STARTUP_SLEEP`, and clamps `<= 0` to `0.01`. | Legacy behavior is retained unless the owner opts in. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town_ai.sqf:1,3-4` | Same read and clamp. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:6-10` | First startup pass sleeps `_townInitSleep` after each town init log. | Startup cadence is tunable. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:58-65` | Second startup pass seeds per-town state, then sleeps `_townInitSleep`. | Both startup passes use the same pacing. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town_ai.sqf:6-10,58-65` | Same two-pass startup cadence. | Mirror present. |

## Non-Findings

- This is not a live behavior change while the flag remains `0`; the script still sleeps `0.01` seconds.
- No town activation budget, detection range, GUER group cap, sortie, or patrol logic changed in this lane.
- No `Rsc/Parameters.hpp` row exists for this tunable in this audit. If the owner wants operator control, that belongs in a parameter-row lane with the same default value.

## Suggested Smoke

For an owner-run soak only:

1. Keep the default `WFBE_C_TOWNS_STARTUP_SLEEP = 0` as the control.
2. Test `0.05`, then `0.10`, in a branch or local config.
3. Compare the early `server_town_ai.sqf : Initialized for [...]` RPT cadence, startup server FPS, and time to first town activation.
4. Revert by returning the value to `0`.

## Verification

- `rg` confirmed `WFBE_C_TOWNS_STARTUP_SLEEP` exists in both maintained roots.
- `rg` confirmed both maintained `server_town_ai.sqf` copies read `_townInitSleep`, clamp legacy values to `0.01`, and use the value in both startup passes.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
