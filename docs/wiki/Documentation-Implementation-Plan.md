# Documentation Implementation Plan

This page is the execution roadmap for keeping the developer wiki useful after the initial index. It is written for humans, Codex, Claude and future AI coding agents.

## Goal

Maintain an extensive, source-backed developer documentation set for `rayswaynl/a2waspwarfare` that explains architecture, runtime lifecycle, mission/server systems, functions, optimizations, broken or partial features, and safe development conventions.

## Published Artifacts

- GitHub wiki: canonical rendered documentation.
- `docs/wiki`: repo mirror for review, diffs and AI context loading.
- `docs/wiki/agent-context.json`: compact machine-readable map for agents.
- `docs/wiki/agent-status.json`: compact current progress snapshot for agents and external tooling.
- `docs/wiki/agent-hardening-backlog.jsonl`: line-delimited current implementation handoffs for future code owners.
- `CLAUDE.md`: root handoff for Claude and other assistants.

Current machine-file authority: `docs/wiki/agent-context.json`, `docs/wiki/agent-status.json` and `docs/wiki/agent-hardening-backlog.jsonl` are refreshed against the current wiki mirror. If a future pass finds retired page names or missing machine files in them, refresh the files before using them as routing or status truth.

## Workstream 0: Authority Hardening And Handler Validation

Status: source-backed findings are consolidated; implementation remains future code-owner work.

This page is the current design preamble for server-authority work. Keep detailed source proof and patch bodies in the focused pages below:

| Surface | Canonical route |
| --- | --- |
| Generic PVF dispatch lookup | [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) and DR-1/DR-38. |
| Economy spend/effect class | [Economy](Economy-Towns-And-Supply#authority-model), [Economy authority first cut](Economy-Authority-First-Cut) and DR-6/14/16/22/23/27/28. |
| Direct public-variable authority | [Networking authority surfaces](Networking-And-Public-Variables#authority-surfaces-to-audit-together), [Public variable channel index](Public-Variable-Channel-Index) and DR-41. |
| Supply mission / PR #1 logistics | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Supply mission architecture](Supply-Mission-Architecture) and DR-18/DR-39. |
| BattlEye deployment posture | [External integrations](External-Integrations#battleye-filter), [Public variable channel index](Public-Variable-Channel-Index) and DR-30. |

Authority principles for future patches:

- Edit the Chernarus source mission first; generated missions follow through `Tools/LoadoutManager`.
- Treat client UI checks as preview/intent only. Price, side, commander status, upgrade level, dependencies and object eligibility must be re-derived on the server for authoritative flows.
- Separate PVF dispatcher hardening from per-handler authority. A validated dispatch lookup blocks arbitrary handler strings; it does not prove a legitimate handler payload is allowed.
- Audit direct `publicVariableServer` channels separately from `WFBE_PVF_*`; they bypass the generic PVF dispatcher.
- Preserve existing scheduling and hosted/dedicated routing unless the handler-specific audit proves a semantic change is safe.
- Do not describe the repo as public-server hardened unless real deployment BattlEye filters are confirmed or added.

Handler validation checklist:

- Identify the surface: registered PVF, direct public variable, client-local mutation, server loop or external extension.
- Find the trusted requester context available in Arma 2 OA; if the payload lacks it, add the smallest behavior-preserving context needed for validation.
- Recompute side, team, commander/role, funds/supply, cost, class allowlist, object locality/aliveness and dependency state from trusted server-side state where possible.
- Reject malformed payloads, wrong-side requests, out-of-range indices, unaffordable actions, invalid objects and duplicate/idempotency hazards before debiting or mutating state.
- Debit funds/supply and apply gameplay effects on the server after acceptance; keep client UI feedback as affordance.
- Log compact `WARNING` entries for rejected hardening-path requests and record validation level in [Agent worklog](Agent-Worklog) and the touched topic page.

## Workstream 1: Architecture Coverage

Status: initial pass complete.

Next improvements:

- Expand sequence-level details for `initJIPCompatible.sqf`, server init, client init and headless init.
- Add more exact source references for commander election, construction, factory production, upgrade unlocks and respawn paths.
- Add a small call-flow map for town activation, capture, supply value, commander income and resistance defense.

Evidence to use:

- `description.ext`
- `initJIPCompatible.sqf`
- `Common/Init/*`
- `Server/Init/*`
- `Client/Init/*`
- `Headless/Init/*`

## Workstream 2: Function And Module Indexing

Status: subsystem-level index plus Common/Client/Server function risk-class tables and Common/Client/Server module risk-class tables complete; direct public-variable, PVF handler payload and AntiStack trust/loop drilldowns complete; per-function/module deep indexing is still ongoing.

Next improvements:

- For each high-use `Compile preprocessFileLineNumbers` registration, document purpose, call ownership and side effects.
- Continue converting the remaining highest-risk risk-class rows into per-registration/per-handler notes where the owning page still lacks enough source-line detail, using the completed direct-PV, PVF payload and AntiStack drilldowns as the model.
- Keep separating pure helper functions from functions that mutate global mission state, world objects, profile state or broadcast over the network.

Evidence to use:

- `Common/Init/Init_Common.sqf`
- `Common/Init/Init_PublicVariables.sqf`
- `Client/Init/Init_Client.sqf`
- `Server/Init/Init_Server.sqf`
- `Headless/Init/Init_HC.sqf`

## Workstream 3: Broken, Partial And Deferred Features

Status: register and triage view complete; per-row verification remains ongoing when a code owner selects a row.

Next improvements:

- Verify every row in `Feature-Status-Register.md` against source before treating it as a bug backlog.
- Keep severity/blast-radius routing current in [Feature status](Feature-Status-Register#triage-view).
- Split abandoned experiments from intentionally disabled runtime features.
- Keep victory/endgame work searchable through [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 instead of restating the winner/guard mechanism on roadmap pages.

Current high-confidence items:

- Autonomous AI supply logistics is incomplete: `UpdateSupplyTruck` is commented and `Server/FSM/supplytruck.fsm` is missing.
- Task system is disabled/commented in client init.
- MASH marker receiver compile is commented.
- CRV7PG loadout classes are explicitly marked as game-crashing.
- Some generated/modded mission support in LoadoutManager is marked TODO.

## Workstream 4: PR #1 Supply Helicopters

Status: documented, pending code merge/review.

Next improvements:

- After PR #1 is merged, update all pages from "current PR" language to baseline behavior.
- Keep supply mission cooldown casing tracked via [Supply mission architecture](Supply-Mission-Architecture) and [Deep-review findings](Deep-Review-Findings) DR-18 instead of restating the key mismatch on roadmap pages.
- Verify whether repeated vehicle supply reloads can stack duplicate `Killed` event handlers.
- Run LoadoutManager after merge to propagate Chernarus source changes if the PR did not already update generated targets.
- Keep autonomous AI supply helicopters documented as deferred until the underlying AI supply logistics path is restored or redesigned.

## Workstream 5: Tooling, Build And External Runtime

Status: initial pass plus performance opportunity sweep complete; LoadoutManager build and PerformanceAuditAnalyzer command-shape checks are locally verified.

Next improvements:

- Run `Tools/LoadoutManager` after actual mission edits and record whether generation and packaging both completed.
- Run `Tools/PerformanceAuditAnalyzer` against a real Arma 2 OA RPT with `[Performance Audit]` rows after performance-sensitive mission changes.
- Document the exact expected deployment layout for `a2waspwarfare_Extension`.
- Keep BattlEye filter posture routed through [External integrations](External-Integrations#battleye-filter), [Public variable channel index](Public-Variable-Channel-Index) and DR-30 instead of duplicating filter examples on roadmap pages.
- Keep ranked performance patch candidates centralized in [Performance opportunity sweep](Performance-Opportunity-Sweep) unless a code owner selects a specific patch.
- Add CI/lint opportunities without inventing Arma 3-only SQF validation.

## Workstream 6: Agent Collaboration

Status: coordination files added.

Rules:

- Claude starts from `Claude-Goal.md`.
- Agents append findings to `Agent-Worklog.md`.
- Agents update `agent-context.json` when high-level architecture facts, risks or page names change.
- Agents should cite concrete source evidence before adding broken-feature claims.
- Documentation-only branches should not include gameplay code changes unless explicitly requested.

## Definition Of Done For Future Passes

A documentation pass is complete when:

- New or changed wiki pages are mirrored exactly under `docs/wiki`.
- `powershell -ExecutionPolicy Bypass -File .\Tools\ValidateWiki.ps1` passes.
- `agent-context.json`, `agent-status.json` and `agent-hardening-backlog.jsonl` stay current when page names, durable risks or machine handoffs change.
- `agent-context.json` `documentation.pages` matches the actual `docs/wiki/*.md` page set.
- Exact machine-file string references to wiki pages, agent JSON/JSONL files and repo tool scripts resolve.
- `Agent-Worklog.md` records what changed and who changed it.
- Source-backed claims include concrete file paths or clearly named runtime scripts.
- The docs avoid Arma 3 scripting assumptions.

