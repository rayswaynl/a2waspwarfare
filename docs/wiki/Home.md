# A2 Wasp Warfare Developer Wiki

This wiki indexes `rayswaynl/a2waspwarfare` for human developers and AI coding assistants. It focuses on the Arma 2: Operation Arrowhead 1.64 mission/server ecosystem, not Arma 3.

Use the Bohemia Interactive Arma 2 OA scripting command reference when checking engine behavior: <https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands>.

## Start Here

Use [Quickstart for humans and agents](Quickstart-For-Humans-And-Agents) first. It gives the current worktrees, source-mission rule, validation command and risk trail.

Then pick the route that matches your task:

| Need | Read |
| --- | --- |
| First architecture pass | [Architecture overview](Architecture-Overview), [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain reference](Lifecycle-Wait-Chain) |
| Source and generated-mission shape | [Source inventory](Source-Inventory), [Content structure and maps](Content-Structure-And-Maps), [Tools and build workflow](Tools-And-Build-Workflow) |
| Function/module ownership | [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index), [Modules atlas](Modules-Atlas), [Variable and naming conventions](Variable-And-Naming-Conventions) |
| Networking and authority | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) |
| Gameplay systems | [Core systems index](Core-Systems-Index), [Gameplay systems atlas](Gameplay-Systems-Atlas), [Economy, towns and supply](Economy-Towns-And-Supply), [Supply mission architecture](Supply-Mission-Architecture) |
| Current patch handoffs | [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1), [Economy authority first cut](Economy-Authority-First-Cut), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Client skill init idempotency](Client-Skill-Init-Idempotency), [Paratrooper marker revival](Paratrooper-Marker-Revival) |
| Runtime/performance/UI | [AI, headless and performance](AI-Headless-And-Performance), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Client UI, HUD and menus](Client-UI-HUD-And-Menus), [WASP overlay](WASP-Overlay) |
| External/runtime dependencies | [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [External integrations](External-Integrations) |
| Risks and owner decisions | [Feature status register](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), [Abandoned feature revival review](Abandoned-Feature-Revival-Review), [Deep-review findings](Deep-Review-Findings), [Codebase coverage ledger](Codebase-Coverage-Ledger) |
| Agent coordination | [AI assistant developer guide](AI-Assistant-Developer-Guide), [Agent context](Agent-Context), [Coordination board](Coordination-Board), [Agent worklog](Agent-Worklog), [Documentation implementation plan](Documentation-Implementation-Plan), [Wiki quality audit](Wiki-Quality-Audit), [Claude goal](Claude-Goal), [Claude loop goal](Claude-Loop-Goal) |

Machine-readable agent files: [`agent-context.json`](agent-context.json), [`agent-status.json`](agent-status.json), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

## Current Source State To Notice

- `HandleParatrooperMarkerCreation` is registered in source Chernarus and Vanilla Takistan; [paratrooper marker revival](Paratrooper-Marker-Revival) owns smoke/modded-mission follow-up.
- Duplicate client `Skill_Init.sqf` execution is patched in source Chernarus and Vanilla Takistan; [client skill init idempotency](Client-Skill-Init-Idempotency) owns smoke follow-up.
- No gameplay code is changed by this documentation set.

## Repo Shape

| Count | Top-level path |
| ---: | --- |
| 1475 | `Modded_Missions` |
| 787 | `Missions` |
| 786 | `Missions_Vanilla` |
| 199 | `Tools` |
| 42 | `DiscordBot` |
| 16 | `Extension` |
| 3 | `Guides` |
| 3 | `Mods` |
| 2 | `BattlEyeFilter` |
| 1 | `.gitattributes` |
| 1 | `.github` |
| 1 | `.gitignore` |
| 1 | `AGENTS.md` |
| 1 | `LICENSE.md` |
| 1 | `README.md` |

## Most Important Rule

For mission gameplay edits, treat `Missions/[55-2hc]warfarev2_073v48co.chernarus` as the source mission. `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` and modded mission folders are generated/copied targets managed by `Tools/LoadoutManager`.

## Current Documentation Scope

- Stable baseline: `master` at the time of indexing.
- Current work: PR #1, `feat/supply-helicopter`, documented separately.
- No gameplay code is changed by this documentation set.

## Continue Reading

First pass: [Quickstart for humans and agents](Quickstart-For-Humans-And-Agents) | Architecture: [Architecture overview](Architecture-Overview) | Current risks: [Feature status register](Feature-Status-Register)
