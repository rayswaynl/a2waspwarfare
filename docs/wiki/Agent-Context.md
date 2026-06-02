# Agent Context

This is the compact human-readable context file for AI coding agents. Start machine readers with [`agent-entrypoint.json`](agent-entrypoint.json), then use `agent-context.json` for the larger snapshot and `agent-knowledge.jsonl` for durable source knowledge records.

## Identity

- Repo: `rayswaynl/a2waspwarfare`
- Game/runtime: Arma 2 Operation Arrowhead 1.64
- Mission type: Warfare / CTI TvT PvE, forked from Benny's Warfare and modernized for WASP/Miksuu.
- Documentation target: GitHub wiki plus `docs/wiki` mirror.
- Progress surface: `Progress-Dashboard.md` plus `agent-status.json` and `agent-knowledge.jsonl`.
- Agent-actionable backlog: `agent-hardening-backlog.jsonl`.
- Release-readiness ledger: `agent-release-readiness.json` for tracked source fixes, generated propagation and smoke gates.
- External report manifest: `external-research-report-manifest.json`; raw extracted report text is local cache only.

## Source Of Truth

- Source mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Generated vanilla mission: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- Modded generated missions: `Modded_Missions/*`
- Generator/tool: `Tools/LoadoutManager`
- Source-fix propagation gate: `Source-Fix-Propagation-Queue.md` plus `agent-release-readiness.json`

## Must-Follow Rules

- Use Arma 2 OA scripting documentation, not Arma 3.
- For gameplay changes, edit the Chernarus source mission first.
- Run `dotnet run` from `Tools/LoadoutManager` after mission edits, or run `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj` from the repo root; set `A2WASP_SKIP_ZIP=1` for propagation-only runs.
- Do not mark mission fixes release-complete until `agent-release-readiness.json` shows generated propagation and relevant Arma 2 OA smoke are done.
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
- `WASP/` overlay scripts documented in `WASP-Overlay.md`

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
- Supply system 0 with AI commanders can hit disabled `UpdateSupplyTruck` and missing `Server/FSM/supplytruck.fsm`.
- PR #1 supply vehicles currently stack `Killed` event handlers across repeated mission loads.

## Current Open Work

- PR #1 `feat/supply-helicopter`: documents supply helicopters, upgrade gating, cash runs, interdiction reward and deferred AI supply heli work.
- Implementation roadmap: `Documentation-Implementation-Plan.md`.
- Code-level atlas: `SQF-Code-Atlas.md`.
- Gameplay systems atlas: `Gameplay-Systems-Atlas.md`.
- Construction and CoIn systems atlas: `Construction-And-CoIn-Systems-Atlas.md`; important hardening note: cost/placement gating is mostly client-side while `RequestStructure` / `RequestDefense` perform only light server validation before object creation.
- Factory and purchase systems atlas: `Factory-And-Purchase-Systems-Atlas.md`; important note: player buy-unit flow is client-local (`GUI_Menu_BuyUnits.sqf` -> `Client_BuildUnit.sqf`) with no `RequestBuyUnit` PVF, while `Server_BuyUnit.sqf` / `AIBuyUnit` appears latent/unused.
- Client UI systems atlas: `Client-UI-Systems-Atlas.md`.
- Boot wait-chain atlas: `Lifecycle-Wait-Chain.md`.
- WASP custom subtree atlas: `WASP-Overlay.md`.
- AI commander/autonomous logistics revival audit: `AI-Commander-Autonomy-Audit.md`.
- External Claude review: use `Claude-Goal.md` for a focused pass or `Claude-Long-Term-Goal.md` for a long-running counterpart, then update `Agent-Worklog.md`.
- Cross-agent progress: read `Progress-Dashboard.md`, `agent-status.json` and `agent-release-readiness.json` first when you need the current Codex/Claude and release-readiness state.
- Cross-agent coordination: read `Agent-Collaboration-Protocol.md`, `agent-collaboration.json`, `agent-knowledge.jsonl` and `agent-events.jsonl` before starting a parallel pass.
- Independent review findings: `Deep-Review-Findings.md` records source-cited Claude findings that still need to be reconciled into owning atlas pages.
- Implementation-ready work packages: `Hardening-Implementation-Roadmap.md` plus machine-readable `agent-hardening-backlog.jsonl`. Current added backlog items include attack-wave authority, static-defense HC sync, hosted FPS loop sleep, town-AI vehicle despawn verification, tooling operator checklist, JIP wait-chain timeout polish and UI/player-map debt.

## Continue Reading

Previous: [AI assistant guide](AI-Assistant-Developer-Guide) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent entry: [`agent-entrypoint.json`](agent-entrypoint.json) | Agent file: [`agent-context.json`](agent-context.json)
