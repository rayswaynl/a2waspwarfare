# A2 Wasp Warfare Developer Wiki

Developer documentation for `rayswaynl/a2waspwarfare`, an Arma 2: Operation Arrowhead 1.64 Warfare / CTI mission and server ecosystem.

This wiki is built for two audiences at once:

| Audience | Start here | Why |
| --- | --- | --- |
| New human developer | [Quickstart](Quickstart-For-Humans-And-Agents) | Fast orientation, safe edit rules and reading paths. |
| AI assistant | [Agent context](Agent-Context) and [`agent-context.json`](agent-context.json) | Compact context, page map and high-risk rules. |
| Reviewer | [Feature status register](Feature-Status-Register) | Broken, partial, deferred and missing features. |
| Hardening implementer | [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Economy authority first cut](Economy-Authority-First-Cut) and [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) | Source-backed patch order, validation gates and safe implementation notes. |
| Tester / releaser | [Testing workflow](Testing-Debugging-And-Release-Workflow) | Source checks, smoke packs, RPT logging and release gates. |
| Mission implementer | [SQF code atlas](SQF-Code-Atlas) | Compile registry, PVF contract and entrypoint ownership. |
| Claude collaborator | [Agent collaboration protocol](Agent-Collaboration-Protocol) and [Claude loop goal](Claude-Loop-Goal) | Shared claim, handoff, event protocol and Claude's current operating mode. |
| Steff / project owner | [Progress dashboard](Progress-Dashboard) | One page for current Codex/Claude lanes, event feed and status files. |

## Click-Through Tours

Use these when you want to read the wiki like a connected handbook instead of jumping through the sidebar.

| Tour | Path |
| --- | --- |
| First day in the repo | [Quickstart](Quickstart-For-Humans-And-Agents) -> [Architecture overview](Architecture-Overview) -> [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Implement a gameplay change | [Gameplay atlas](Gameplay-Systems-Atlas) -> [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas) -> [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) -> [Server runtime atlas](Server-Gameplay-Runtime-Atlas) -> [Core systems](Core-Systems-Index) -> [Feature status](Feature-Status-Register) |
| Harden the mission | [Feature status](Feature-Status-Register) -> [Pending owner decisions](Pending-Owner-Decisions) -> [Hardening roadmap](Hardening-Implementation-Roadmap) -> [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) -> [Server authority map](Server-Authority-Migration-Map) -> [Economy authority first cut](Economy-Authority-First-Cut) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) -> [Testing workflow](Testing-Debugging-And-Release-Workflow) -> [Networking/PV](Networking-And-Public-Variables) -> [PV channel index](Public-Variable-Channel-Index) -> [Deep-review findings](Deep-Review-Findings) |
| Trace SQF and networking | [SQF atlas](SQF-Code-Atlas) -> [Function index](Function-And-Module-Index) -> [Networking/PV](Networking-And-Public-Variables) -> [PV channel index](Public-Variable-Channel-Index) |
| Work on UI/HUD | [Client UI/HUD/menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) -> [Tools/build](Tools-And-Build-Workflow) |
| Coordinate Codex and Claude | [Progress dashboard](Progress-Dashboard) -> [Coordination board](Coordination-Board) -> [Agent collaboration protocol](Agent-Collaboration-Protocol) -> [Claude loop goal](Claude-Loop-Goal) -> [Agent worklog](Agent-Worklog) |

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
| Work on networking | [Networking and public variables](Networking-And-Public-Variables) -> [Public variable channel index](Public-Variable-Channel-Index) -> [SQF code atlas](SQF-Code-Atlas) |
| Work on economy or supply | [Economy, towns and supply](Economy-Towns-And-Supply) -> [Economy authority first cut](Economy-Authority-First-Cut) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) -> [Supply mission architecture](Supply-Mission-Architecture) -> [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) |
| Work on AI/performance | [AI, headless and performance](AI-Headless-And-Performance) -> [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook) -> [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) -> [Feature status register](Feature-Status-Register) |
| Work on UI/HUD/menus | [Client UI, HUD and menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Work on core gameplay | [Gameplay systems atlas](Gameplay-Systems-Atlas) -> [Modules atlas](Modules-Atlas) -> [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) -> [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) -> [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) -> [Core systems index](Core-Systems-Index) |
| Test or release changes | [Testing workflow](Testing-Debugging-And-Release-Workflow) -> [Tools/build](Tools-And-Build-Workflow) -> [Hardening roadmap](Hardening-Implementation-Roadmap) -> [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) -> [Server authority map](Server-Authority-Migration-Map) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) |
| Check agent progress | [Progress dashboard](Progress-Dashboard) -> [`agent-status.json`](agent-status.json) -> [`agent-events.jsonl`](agent-events.jsonl) |
| Coordinate agents | [Progress dashboard](Progress-Dashboard) -> [Coordination board](Coordination-Board) -> [Agent worklog](Agent-Worklog) -> [Codebase coverage ledger](Codebase-Coverage-Ledger) -> [Claude long-term goal](Claude-Long-Term-Goal) -> [Claude loop goal](Claude-Loop-Goal) |
| Understand WASP-specific additions | [WASP overlay](WASP-Overlay) -> [Feature status register](Feature-Status-Register) |

## Current Map

| Area | Page |
| --- | --- |
| Architecture | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) |
| Boot dependencies | [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Inventory | [Source inventory](Source-Inventory), [Content structure and maps](Content-Structure-And-Maps) |
| Code | [Function and module index](Function-And-Module-Index), [SQF code atlas](SQF-Code-Atlas), [Variable and naming conventions](Variable-And-Naming-Conventions) |
| Runtime systems | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Modules atlas](Modules-Atlas), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Core systems index](Core-Systems-Index), [Economy, towns and supply](Economy-Towns-And-Supply), [AI, headless and performance](AI-Headless-And-Performance), [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) |
| Networking | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index) |
| UI | [Client UI, HUD and menus](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| WASP additions | [WASP overlay](WASP-Overlay) |
| Operations | [Tools and build workflow](Tools-And-Build-Workflow), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow), [External integrations](External-Integrations) |
| Risk and future work | [Feature status register](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), [Hardening implementation roadmap](Hardening-Implementation-Roadmap), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Server authority migration map](Server-Authority-Migration-Map), [Economy authority first cut](Economy-Authority-First-Cut), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow), [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Codebase coverage ledger](Codebase-Coverage-Ledger), [Wiki quality audit](Wiki-Quality-Audit), [Documentation implementation plan](Documentation-Implementation-Plan) |
| Agent collaboration | [AI assistant developer guide](AI-Assistant-Developer-Guide), [Agent context](Agent-Context), [Progress dashboard](Progress-Dashboard), [Coordination board](Coordination-Board), [Agent collaboration protocol](Agent-Collaboration-Protocol), [Claude loop goal](Claude-Loop-Goal) |

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
- Human-readable progress dashboard: [Progress dashboard](Progress-Dashboard)
- Machine-readable progress file: [`agent-status.json`](agent-status.json)
- Machine-readable collaboration file: [`agent-collaboration.json`](agent-collaboration.json)
- Machine-readable hardening backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)
- Machine-readable test evidence schema: [`agent-test-plan.schema.json`](agent-test-plan.schema.json)
- External PDF report metadata: [`external-research-report-manifest.json`](external-research-report-manifest.json)
- Append-only coordination feed: [`agent-events.jsonl`](agent-events.jsonl)
- Agent coordination log: [Agent worklog](Agent-Worklog)

Persistent navigation is provided by `_Sidebar.md`; shared bottom navigation is provided by `_Footer.md`.

## Continue Reading

Previous: [Claude long-term goal](Claude-Long-Term-Goal) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
