# Hosted Server FPS Loop Sleep

## Status

`hosted-server-fps-loop-sleep` is source + maintained Vanilla propagated and smoke pending as of 2026-06-02. This is the implementation pass for DR-19 / backlog id `server-fps-hosted-loop-sleep`. The earlier checkout-root blocker was removed by the LoadoutManager root-discovery patch, and propagation now works from this Codex checkout with `A2WASP_SKIP_ZIP=1`.

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- Source/Vanilla/modded search results for `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS`

## What The Code Did

Before the patch, `Init_Server.sqf` started two FPS publisher scripts:

| Source | Behavior |
| --- | --- |
| `Server/Init/Init_Server.sqf:578` | Starts `Server\GUI\serverFpsGUI.sqf`. |
| `Server/Init/Init_Server.sqf:595` | Starts `Server\Module\serverFPS\monitorServerFPS.sqf`. |
| `Server/GUI/serverFpsGUI.sqf:1-11` | Runs `while {true}`; publishes `SERVER_FPS_GUI` only inside `if (isDedicated)`; sleeps only inside that same branch. |
| `Server/Module/serverFPS/monitorServerFPS.sqf:1-8` | Runs `while {true}`; publishes `WFBE_VAR_SERVER_FPS` only inside `if (isDedicated)`; sleeps only inside that same branch. |
| `Client/Client_UpdateRHUD.sqf:113-125` | Source/Vanilla RHUD reads `SERVER_FPS_GUI`. |

That means dedicated servers published every 8 seconds, but hosted/listen servers entered both loops and skipped the only sleep. The result was two unslept scheduled loops doing no useful work.

## Patch Shape

The patch keeps dedicated behavior and removes the hosted/listen busy-spin:

- Add `if (!isDedicated) exitWith {};` before each `while {true}`.
- Remove the inner `if (isDedicated)` branch.
- Leave `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS` publishing cadence unchanged on dedicated servers.
- Do not consolidate the two publishers yet; source/Vanilla only consume `SERVER_FPS_GUI`, but stale/modded mission folders still contain `WFBE_VAR_SERVER_FPS` consumers.

Changed source files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`

Propagated maintained Vanilla files:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/GUI/serverFpsGUI.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/serverFPS/monitorServerFPS.sqf`

## Validation

Source/Vanilla validation done:

- Chernarus `serverFpsGUI.sqf` has one early `!isDedicated` exit, one loop, one `sleep 8` and no inner `if (isDedicated)` branch.
- Chernarus `monitorServerFPS.sqf` has one early `!isDedicated` exit, one loop, one `sleep 8` and no inner `if (isDedicated)` branch.
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
- If cleaning further, decide whether stale/modded `WFBE_VAR_SERVER_FPS` consumers still matter before consolidating publishers.
- Modded mission folders still need their broader generated/forked maintenance model resolved before hand edits.

For Claude:

- Good contradiction check: inspect hosted/listen behavior in Arma 2 OA after this patch and verify no other `Init_Server.sqf` loop has the same `while true` + branch-only sleep shape.

## Continue Reading

- Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep)
- Next: [AI, headless and performance](AI-Headless-And-Performance)
