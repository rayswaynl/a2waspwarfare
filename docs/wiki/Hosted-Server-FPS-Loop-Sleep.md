# Hosted Server FPS Loop Sleep

## Status

Checked 2026-06-14 after `git fetch --all --prune`. Docs checkout `db7667c9` keeps the branch-local two-publisher DR-19 fix in Chernarus and maintained Vanilla: both `serverFpsGUI.sqf:1` and `monitorServerFPS.sqf:1` exit before their loops on `!isDedicated`. Stable `origin/master` `cf2a6d6a` and release `a96fdda2` now use a different fixed shape: one guarded `serverFpsGUI.sqf` publisher and no maintained-root `Server/Module/serverFPS/monitorServerFPS.sqf` file. Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` still keep the old two unguarded publisher loops in checked maintained roots. Arma 2 OA smoke is still pending.

## Current Branch Scope

| Ref / root scope | FPS publisher shape | Development meaning |
| --- | --- | --- |
| Docs checkout `db7667c9` Chernarus and maintained Vanilla | `Server/GUI/serverFpsGUI.sqf:1` and `Server/Module/serverFPS/monitorServerFPS.sqf:1` both exit on `!isDedicated`; `Init_Server.sqf:578,595` still starts both scripts. These FPS files are unchanged from the recent server-runtime atlas anchor `92c5cf05`. | Branch-local source carries the low-risk two-publisher guard. Smoke dedicated publish plus hosted/listen no-spin before release-ready wording. |
| Stable `origin/master` `cf2a6d6a` | Both maintained roots guard `serverFpsGUI.sqf` at `:4`, start it at `Init_Server.sqf:580`, and document the redundant monitor removal at `Init_Server.sqf:596-598`; `Server/Module/serverFPS/monitorServerFPS.sqf` is absent. | Stable is no longer old-loop-shaped. Smoke the single-publisher target branch rather than porting the docs-branch two-publisher shape blindly. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` | Both maintained roots guard `serverFpsGUI.sqf` at `:4`, start it at `Init_Server.sqf:579`, and document monitor removal at `Init_Server.sqf:595-597`; `monitorServerFPS.sqf` is absent. | Release matches stable for this runtime surface. Smoke the release single-publisher shape before release-complete claims. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Both checked roots keep `serverFpsGUI.sqf:1` and `monitorServerFPS.sqf:1` entering `while {true}` before the `isDedicated` branch; the only sleep remains inside that branch. Miksuu starts both scripts at `Init_Server.sqf:578,595`; perf starts them at `:573,590` in Chernarus and `:578,595` in maintained Vanilla. | These are the remaining old-loop targets. Port either the docs two-publisher guard or the stable/release single-publisher cleanup deliberately, then propagate maintained Vanilla and smoke. |

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- Source/Vanilla/modded search results for `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS`

## Original Bug Shape

Before the DR-19 patch, `Init_Server.sqf` started two FPS publisher scripts:

| Source | Behavior |
| --- | --- |
| Old-shape init, still visible on Miksuu/perf | Starts `Server\GUI\serverFpsGUI.sqf` and `Server\Module\serverFPS\monitorServerFPS.sqf`. |
| Old-shape `Server/GUI/serverFpsGUI.sqf:1-12` | Runs `while {true}`; publishes `SERVER_FPS_GUI` only inside `if (isDedicated)`; sleeps only inside that same branch. |
| Old-shape `Server/Module/serverFPS/monitorServerFPS.sqf:1-8` | Runs `while {true}`; publishes `WFBE_VAR_SERVER_FPS` only inside `if (isDedicated)`; sleeps only inside that same branch. |
| `Client/Client_UpdateRHUD.sqf:113-125` | Source/Vanilla RHUD reads `SERVER_FPS_GUI`. |

That means dedicated servers published every 8 seconds, but hosted/listen servers entered both loops and skipped the only sleep. The result was two unslept scheduled loops doing no useful work.

## Patch Shape

The patch keeps dedicated behavior and removes the hosted/listen busy-spin:

- Add `if (!isDedicated) exitWith {};` before each `while {true}`.
- Remove the inner `if (isDedicated)` branch.
- Leave `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS` publishing cadence unchanged on dedicated servers.
- Do not consolidate the two publishers yet; source/Vanilla only consume `SERVER_FPS_GUI`, but stale/modded mission folders still contain `WFBE_VAR_SERVER_FPS` consumers.

Changed branch-local docs/source files (`docs/developer-wiki-index`; stable/release use the one-publisher cleanup instead):

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`

Propagated maintained Vanilla files:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/GUI/serverFpsGUI.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/serverFPS/monitorServerFPS.sqf`

## Validation

Branch-local source/Vanilla validation done:

- This docs branch's Chernarus `serverFpsGUI.sqf` has one early `!isDedicated` exit, one loop, one `sleep 8` and no inner `if (isDedicated)` branch.
- This docs branch's Chernarus `monitorServerFPS.sqf` has one early `!isDedicated` exit, one loop, one `sleep 8` and no inner `if (isDedicated)` branch.
- Stable `origin/master` `cf2a6d6a` and release `a96fdda2` have the guarded `serverFpsGUI.sqf` shape at `:4-12` in both maintained roots. The redundant `Server/Module/serverFPS/monitorServerFPS.sqf` file is absent from those trees and `Init_Server.sqf` documents the removal.
- Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` remain old-loop-shaped in checked maintained roots.
- Vanilla Takistan has the same early-exit shape after the propagation run.
- `dotnet run` in `Tools/LoadoutManager` now works from `work\a`; use `A2WASP_SKIP_ZIP=1` for propagation-only runs so missing `7za` remains non-blocking.
- `git diff --check` passes.

Pending smoke:

- Dedicated: confirm RHUD/server FPS updates roughly every 8 seconds.
- Dedicated: confirm no RPT errors from either FPS publisher.
- Hosted/listen: confirm no scheduled busy-spin from these scripts and HUD behavior remains acceptable when server FPS is not published.

## Handoff

For Codex/future code owner:

- Treat this as the low-risk DR-19 implementation. It intentionally does not remove `monitorServerFPS.sqf` or merge `WFBE_VAR_SERVER_FPS` into `SERVER_FPS_GUI`.
- If cleaning docs/source further, decide whether to keep the two-publisher compatibility path or adopt the stable/release single-publisher cleanup. Check stale/modded `WFBE_VAR_SERVER_FPS` consumers before consolidating publishers.
- Modded mission folders still need their broader generated/forked maintenance model resolved before hand edits.

Wave P contract note: in current source Chernarus, RHUD/FPS HUD reads `SERVER_FPS_GUI` (`Client/Client_UpdateRHUD.sqf:113`), while `WFBE_VAR_SERVER_FPS` is published by `Server/Module/serverFPS/monitorServerFPS.sqf:5-6` with no player-UI reader found in the source mission. Consolidation is therefore a separate compatibility cleanup, not part of the hosted/listen busy-loop fix.

For Claude:

- Good contradiction check: inspect hosted/listen behavior in Arma 2 OA after this patch and verify no other `Init_Server.sqf` loop has the same `while true` + branch-only sleep shape.

## Continue Reading

- Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep)
- Next: [AI, headless and performance](AI-Headless-And-Performance)
