# Hosted Server FPS Loop Sleep

## Status

`hosted-server-fps-loop-sleep` is patch-ready/current-source-unpatched. Current source Chernarus and generated Vanilla Takistan still enter the FPS publisher loops before checking `isDedicated`; `sleep 8` remains inside the dedicated branch only.

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- Source/Vanilla/modded search results for `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS`

## What The Code Does Now

Current source still starts two FPS publisher scripts. Each publisher currently loops first, only publishes/sleeps inside the `isDedicated` branch, and therefore can spin on hosted/listen servers:

| Source | Behavior |
| --- | --- |
| `Server/Init/Init_Server.sqf:578` | Starts `Server\GUI\serverFpsGUI.sqf`. |
| `Server/Init/Init_Server.sqf:595` | Starts `Server\Module\serverFPS\monitorServerFPS.sqf`. |
| `Server/GUI/serverFpsGUI.sqf:1-9` | Starts with `while {true}`, checks `isDedicated` inside the loop and sleeps only in that branch. |
| `Server/Module/serverFPS/monitorServerFPS.sqf:1-7` | Starts with `while {true}`, checks `isDedicated` inside the loop and sleeps only in that branch. |
| `Client/Client_UpdateRHUD.sqf:113-125` | Source/Vanilla RHUD reads `SERVER_FPS_GUI`. |

That means dedicated servers still publish roughly every 8 seconds, while hosted/listen servers can keep running the empty loop without a yield until the source patch is applied.

## Patch Shape

The source/Vanilla patch keeps dedicated behavior and removes the hosted/listen busy-spin:

- Add `if (!isDedicated) exitWith {};` before each `while {true}`.
- Remove the inner `if (isDedicated)` branch or leave only the dedicated loop body.
- Leave `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS` publishing cadence unchanged on dedicated servers.
- Do not consolidate the two publishers yet; source/Vanilla only consume `SERVER_FPS_GUI`, but stale/modded mission folders still contain `WFBE_VAR_SERVER_FPS` consumers.

Expected changed maintained files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/GUI/serverFpsGUI.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/serverFPS/monitorServerFPS.sqf`

## Validation

Source-only after patch:

- Chernarus and Vanilla Takistan `serverFpsGUI.sqf` have one early `!isDedicated` exit, one loop and one `sleep 8`.
- Chernarus and Vanilla Takistan `monitorServerFPS.sqf` have one early `!isDedicated` exit, one loop and one `sleep 8`.
- `git diff --check` passes.

Pending smoke:

- Dedicated: confirm RHUD/server FPS updates roughly every 8 seconds.
- Dedicated: confirm no RPT errors from either FPS publisher.
- Hosted/listen: confirm no scheduled busy-spin from these scripts and HUD behavior remains acceptable when server FPS is not published.

## Handoff

For Codex/future code owner:

- Treat this as a low-risk DR-19 patch-ready lane. It should not remove `monitorServerFPS.sqf` or merge `WFBE_VAR_SERVER_FPS` into `SERVER_FPS_GUI`.
- If cleaning further, decide whether stale/modded `WFBE_VAR_SERVER_FPS` consumers still matter before consolidating publishers.
- Modded mission folders still need their broader generated/forked maintenance model resolved before hand edits.

For Claude:

- Good contradiction check: inspect hosted/listen behavior in Arma 2 OA after this patch and verify no other `Init_Server.sqf` loop has the same `while true` + branch-only sleep shape.

## Continue Reading

- Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep)
- Next: [AI, headless and performance](AI-Headless-And-Performance)
