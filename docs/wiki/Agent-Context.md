# Agent Context

This is the compact human-readable context file for AI coding agents. See `agent-context.json` for machine-readable structure.

## Identity

- Repo: `rayswaynl/a2waspwarfare`
- Game/runtime: Arma 2 Operation Arrowhead 1.64
- Mission type: Warfare / CTI TvT PvE, forked from Benny's Warfare and modernized for WASP/Miksuu.
- Documentation target: GitHub wiki plus `docs/wiki` mirror.

## Source Of Truth

- Source mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Generated vanilla mission: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- Modded generated missions: `Modded_Missions/*`
- Generator/tool: `Tools/LoadoutManager`

## Must-Follow Rules

- Use Arma 2 OA scripting documentation, not Arma 3.
- For gameplay changes, edit the Chernarus source mission first.
- Run `dotnet run` from `Tools/LoadoutManager` after mission edits; missing `7za` only blocks packaging.
- Do not casually alter anti-stack/database, extension, live-server or runtime mode behavior.
- Use `WF_Debug`-gated logs for detailed debug output.

## Primary Entrypoints

- `description.ext`
- `initJIPCompatible.sqf`
- `Common/Init/Init_Common.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Common/Init/Init_PublicVariables.sqf`
- `Server/Init/Init_Server.sqf`
- `Client/Init/Init_Client.sqf`
- `Headless/Init/Init_HC.sqf`

## High-Risk Systems

- PVF/publicVariable networking.
- Server init and long-running loops.
- Economy and side supply.
- Factories and purchase spawn markers.
- AI/headless delegation.
- Anti-stack database extension calls.
- LoadoutManager-generated mission output.
- Dangerous loadout classes marked `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS`.
- PowerShell path handling for the Chernarus folder; use `-LiteralPath` because `[55-2hc]` is a wildcard pattern.

## Current Open Work

- PR #1 `feat/supply-helicopter`: documents supply helicopters, upgrade gating, cash runs, interdiction reward and deferred AI supply heli work.
- Implementation roadmap: `Documentation-Implementation-Plan.md`.
- Code-level atlas: `SQF-Code-Atlas.md`.
- External Claude review: use `Claude-Goal.md` and update `Agent-Worklog.md`.

