# A2 Wasp Warfare Developer Wiki

Developer documentation for `rayswaynl/a2waspwarfare`, an Arma 2: Operation Arrowhead 1.64 Warfare / CTI mission and server ecosystem.

This wiki is built for two audiences at once:

| Audience | Start here | Why |
| --- | --- | --- |
| New human developer | [Quickstart](Quickstart-For-Humans-And-Agents) | Fast orientation, safe edit rules and reading paths. |
| AI assistant | [Agent context](Agent-Context) and [`agent-context.json`](agent-context.json) | Compact context, page map and high-risk rules. |
| Reviewer | [Feature status register](Feature-Status-Register) | Broken, partial, deferred and missing features. |
| Mission implementer | [SQF code atlas](SQF-Code-Atlas) | Compile registry, PVF contract and entrypoint ownership. |
| Claude collaborator | [Claude long-term goal](Claude-Long-Term-Goal) | Complementary review role and work rhythm. |

## Click-Through Tours

Use these when you want to read the wiki like a connected handbook instead of jumping through the sidebar.

| Tour | Path |
| --- | --- |
| First day in the repo | [Quickstart](Quickstart-For-Humans-And-Agents) -> [Architecture overview](Architecture-Overview) -> [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Implement a gameplay change | [Gameplay atlas](Gameplay-Systems-Atlas) -> [Core systems](Core-Systems-Index) -> [Economy/towns/supply](Economy-Towns-And-Supply) -> [Feature status](Feature-Status-Register) |
| Trace SQF and networking | [SQF atlas](SQF-Code-Atlas) -> [Function index](Function-And-Module-Index) -> [Networking/PV](Networking-And-Public-Variables) |
| Work on UI/HUD | [Client UI/HUD/menus](Client-UI-HUD-And-Menus) -> [Tools/build](Tools-And-Build-Workflow) -> [Content/maps](Content-Structure-And-Maps) |
| Coordinate Codex and Claude | [Coordination board](Coordination-Board) -> [Agent worklog](Agent-Worklog) -> [Claude long-term goal](Claude-Long-Term-Goal) |

Every content page now includes a **Continue Reading** block with previous and next links for the main handbook path.

## First Principles

| Rule | Details |
| --- | --- |
| Source mission | Gameplay edits start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`. |
| Generated missions | `Missions_Vanilla` and `Modded_Missions` are generated/copied targets managed by `Tools/LoadoutManager`. |
| Script reference | Use Bohemia Interactive Arma 2 OA scripting docs, not Arma 3 assumptions. |
| Windows path trap | Use PowerShell `-LiteralPath` for `[55-2hc]` paths because brackets are wildcard syntax. |
| Current branch docs | Repo mirror lives in PR #2 on `docs/developer-wiki-index`. |

## Reading Paths

| Task | Pages |
| --- | --- |
| Understand startup flow | [Architecture overview](Architecture-Overview) -> [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) -> [SQF code atlas](SQF-Code-Atlas) |
| Work on networking | [Networking and public variables](Networking-And-Public-Variables) -> [SQF code atlas](SQF-Code-Atlas) |
| Work on economy or supply | [Economy, towns and supply](Economy-Towns-And-Supply) -> [Supply mission architecture](Supply-Mission-Architecture) -> [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) |
| Work on AI/performance | [AI, headless and performance](AI-Headless-And-Performance) -> [Feature status register](Feature-Status-Register) |
| Work on UI/HUD/menus | [Client UI, HUD and menus](Client-UI-HUD-And-Menus) -> [Tools and build workflow](Tools-And-Build-Workflow) |
| Work on core gameplay | [Gameplay systems atlas](Gameplay-Systems-Atlas) -> [Core systems index](Core-Systems-Index) |
| Coordinate agents | [Coordination board](Coordination-Board) -> [Agent worklog](Agent-Worklog) -> [Claude long-term goal](Claude-Long-Term-Goal) |
| Understand WASP-specific additions | [WASP overlay](WASP-Overlay) -> [Feature status register](Feature-Status-Register) |

## Current Map

| Area | Page |
| --- | --- |
| Architecture | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) |
| Boot dependencies | [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Inventory | [Source inventory](Source-Inventory), [Content structure and maps](Content-Structure-And-Maps) |
| Code | [Function and module index](Function-And-Module-Index), [SQF code atlas](SQF-Code-Atlas) |
| Runtime systems | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Core systems index](Core-Systems-Index), [Economy, towns and supply](Economy-Towns-And-Supply), [AI, headless and performance](AI-Headless-And-Performance) |
| Networking | [Networking and public variables](Networking-And-Public-Variables) |
| UI | [Client UI, HUD and menus](Client-UI-HUD-And-Menus) |
| WASP additions | [WASP overlay](WASP-Overlay) |
| Operations | [Tools and build workflow](Tools-And-Build-Workflow), [External integrations](External-Integrations) |
| Risk and future work | [Feature status register](Feature-Status-Register), [Documentation implementation plan](Documentation-Implementation-Plan) |
| Agent collaboration | [AI assistant developer guide](AI-Assistant-Developer-Guide), [Agent context](Agent-Context), [Coordination board](Coordination-Board) |

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

## Machine Context

- Human-readable agent brief: [Agent context](Agent-Context)
- Machine-readable agent file: [`agent-context.json`](agent-context.json)
- Agent coordination log: [Agent worklog](Agent-Worklog)

Persistent navigation is provided by `_Sidebar.md`; shared bottom navigation is provided by `_Footer.md`.

## Continue Reading

Previous: [Claude long-term goal](Claude-Long-Term-Goal) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
