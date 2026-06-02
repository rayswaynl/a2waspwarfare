# Documentation Implementation Plan

This page is the execution roadmap for keeping the developer wiki useful after the initial index. It is written for humans, Codex, Claude and future AI coding agents.

## Goal

Maintain an extensive, source-backed developer documentation set for `rayswaynl/a2waspwarfare` that explains architecture, runtime lifecycle, mission/server systems, functions, optimizations, broken or partial features, and safe development conventions.

## Published Artifacts

- GitHub wiki: canonical rendered documentation.
- `docs/wiki`: repo mirror for review, diffs and AI context loading.
- `docs/wiki/agent-context.json`: compact machine-readable map for agents.
- `CLAUDE.md`: root handoff for Claude and other assistants.

## Workstream 1: Architecture Coverage

Status: initial pass complete.

Next improvements:

- Expand sequence-level details for `initJIPCompatible.sqf`, server init, client init and headless init.
- Add more exact source references for commander election, factory production, upgrade unlocks and respawn paths.
- Add a small call-flow map for town activation, capture, supply value, commander income and resistance defense.

Evidence to use:

- `description.ext`
- `initJIPCompatible.sqf`
- `Common/Init/*`
- `Server/Init/*`
- `Client/Init/*`
- `Headless/Init/*`

## Workstream 2: Function And Module Indexing

Status: source-backed compile/PVF atlas started in `SQF-Code-Atlas.md`; per-function deep indexing is still ongoing.

Next improvements:

- For each high-use `Compile preprocessFileLineNumbers` registration, document purpose, call ownership and side effects.
- Build tables for `Client/Functions`, `Common/Functions`, `Server/Functions`, `Client/Module`, `Common/Module` and `Server/Module`.
- Separate pure helper functions from functions that mutate global mission state or broadcast over the network.
- Add payload-shape tables for each PVF command documented in `SQF-Code-Atlas.md`.

Evidence to use:

- `Common/Init/Init_Common.sqf`
- `Common/Init/Init_PublicVariables.sqf`
- `Client/Init/Init_Client.sqf`
- `Server/Init/Init_Server.sqf`
- `Headless/Init/Init_HC.sqf`

## Workstream 3: Broken, Partial And Deferred Features

Status: first register complete.

Next improvements:

- Verify every row in `Feature-Status-Register.md` against source before treating it as a bug backlog.
- Add severity and blast-radius fields for broken/deferred features.
- Split abandoned experiments from intentionally disabled runtime features.

Current high-confidence items:

- Autonomous AI supply logistics is incomplete: `UpdateSupplyTruck` is commented and `Server/FSM/supplytruck.fsm` is missing.
- Task system is disabled/commented in client init.
- MASH marker receiver and paratrooper marker receiver are confirmed broken receive-side paths.
- Construction requests need server-side authority hardening; cost, role and placement checks are mostly client-side today.
- CRV7PG loadout classes are explicitly marked as game-crashing.
- Some generated/modded mission support in LoadoutManager is marked TODO.

Implementation-ready owner decisions now live in [Hardening implementation roadmap](Hardening-Implementation-Roadmap). That page is the bridge from "known risk" to patch order, source files and validation gates.

## Workstream 4: PR #1 Supply Helicopters

Status: documented, pending code merge/review.

Next improvements:

- After PR #1 is merged, update all pages from "current PR" language to baseline behavior.
- Verify whether repeated vehicle supply reloads can stack duplicate `Killed` event handlers.
- Run LoadoutManager after merge to propagate Chernarus source changes if the PR did not already update generated targets.
- Keep autonomous AI supply helicopters documented as deferred until the underlying AI supply logistics path is restored or redesigned.

## Workstream 5: Tooling, Build And External Runtime

Status: initial pass complete.

Next improvements:

- Add command examples for `Tools/LoadoutManager` and `Tools/PerformanceAuditAnalyzer` once verified locally.
- Document the exact expected deployment layout for `a2waspwarfare_Extension`.
- Document BattlEye publicVariable filter maintenance rules with examples.
- Add CI/lint opportunities without inventing Arma 3-only SQF validation.

## Workstream 6: Agent Collaboration

Status: coordination files added.

Rules:

- Claude starts from `Claude-Goal.md`.
- Agents append findings to `Agent-Worklog.md`.
- Agents claim lanes in `agent-collaboration.json` and append events to `agent-events.jsonl` before substantial parallel work.
- Agents update `agent-context.json` when high-level architecture facts, risks or page names change.
- Agents should cite concrete source evidence before adding broken-feature claims.
- Documentation-only branches should not include gameplay code changes unless explicitly requested.

## Workstream 7: Mission Hardening Plans

Status: first roadmap published.

Next improvements:

- Turn each roadmap work package into a dedicated implementation PR plan when the owner chooses to patch gameplay code.
- Add post-patch validation notes after PVF dispatch, ICBM authority, victory/endgame or supply mission fixes land.
- Keep the roadmap tied to DR findings so "reviewed" and "fixed" cannot drift apart.

## Definition Of Done For Future Passes

A documentation pass is complete when:

- New or changed wiki pages are mirrored exactly under `docs/wiki`.
- Internal wiki links pass a local link check.
- `agent-context.json` parses as JSON and lists current page names.
- `Agent-Worklog.md` records what changed and who changed it.
- Source-backed claims include concrete file paths or clearly named runtime scripts.
- The docs avoid Arma 3 scripting assumptions.

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Claude focused goal](Claude-Goal)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
