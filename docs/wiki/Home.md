# A2 Wasp Warfare Developer Wiki

Developer documentation for `rayswaynl/a2waspwarfare`, an Arma 2: Operation Arrowhead 1.64 Warfare / CTI mission and server ecosystem.

This wiki is built for two audiences at once:

| Audience | Start here | Why |
| --- | --- | --- |
| New human developer | [Quickstart](Quickstart-For-Humans-And-Agents) | Fast orientation, safe edit rules and reading paths. |
| AI assistant | [Agent context](Agent-Context), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), [`agent-entrypoint.json`](agent-entrypoint.json) and [`agent-context.json`](agent-context.json) | Compact context, OA engine references, compatibility guardrails, page map and high-risk rules. |
| LLM / agent bootstrap | [LLM agent entry pack](LLM-Agent-Entry-Pack), [`agent-entrypoint.json`](agent-entrypoint.json) and [`llms.txt`](llms.txt) | Fast load order, task bundles and machine-readable entrypoints. |
| Reviewer | [Feature status register](Feature-Status-Register) | Broken, partial, deferred and missing features. |
| Hardening implementer | [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [ICBM authority playbook](ICBM-Authority-Playbook), [Economy authority first cut](Economy-Authority-First-Cut) and [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) | Source-backed patch order, validation gates and safe implementation notes. |
| Tester / releaser | [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [`agent-release-readiness.json`](agent-release-readiness.json) | Source checks, generated propagation, smoke packs, RPT logging and release gates. |
| Mission implementer | [SQF code atlas](SQF-Code-Atlas) | Compile registry, PVF contract and entrypoint ownership. |
| Claude collaborator | [Agent collaboration protocol](Agent-Collaboration-Protocol) and [Claude loop goal](Claude-Loop-Goal) | Shared claim, handoff, event protocol and Claude's current operating mode. |
| Steff / project owner | [Progress dashboard](Progress-Dashboard) | One page for current Codex/Claude lanes, event feed and status files. |
| Docs/platform owner | [Knowledge platform roadmap](Knowledge-Platform-Roadmap) | Canonical docs location, GitHub Pages/MkDocs path and LLM bundle plan. |

## Click-Through Tours

Use these when you want to read the wiki like a connected handbook instead of jumping through the sidebar.

| Tour | Path |
| --- | --- |
| First day in the repo | [Quickstart](Quickstart-For-Humans-And-Agents) -> [Architecture overview](Architecture-Overview) -> [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) -> [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) -> [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) |
| Implement a gameplay change | [Gameplay atlas](Gameplay-Systems-Atlas) -> [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) -> [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) -> [Victory/endgame atlas](Victory-And-Endgame-Atlas) -> [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) -> [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas) -> [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas) -> [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) -> [Upgrades/research atlas](Upgrades-And-Research-Atlas) -> [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup) -> [Server runtime atlas](Server-Gameplay-Runtime-Atlas) -> [Core systems](Core-Systems-Index) -> [Feature status](Feature-Status-Register) -> [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Risk triage shortcut | [Feature status](Feature-Status-Register) -> [Pending owner decisions](Pending-Owner-Decisions) -> [Hardening roadmap](Hardening-Implementation-Roadmap) -> [Source fix queue](Source-Fix-Propagation-Queue) -> [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Harden the mission | [Feature status](Feature-Status-Register) -> [Pending owner decisions](Pending-Owner-Decisions) -> [Abandoned feature revival](Abandoned-Feature-Revival-Review) -> [Paratrooper marker revival](Paratrooper-Marker-Revival) -> [Hardening roadmap](Hardening-Implementation-Roadmap) -> [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) -> [Server authority map](Server-Authority-Migration-Map) -> [ICBM authority playbook](ICBM-Authority-Playbook) -> [Economy authority first cut](Economy-Authority-First-Cut) -> [Upgrades/research atlas](Upgrades-And-Research-Atlas) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) -> [Integration trust boundary audit](Integration-Trust-Boundary-Audit) -> [AntiStack DB audit](AntiStack-Database-Extension-Audit) -> [Testing workflow](Testing-Debugging-And-Release-Workflow) -> [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) -> [Networking/PV](Networking-And-Public-Variables) -> [PV channel index](Public-Variable-Channel-Index) -> [Deep-review findings](Deep-Review-Findings) |
| Trace SQF and networking | [SQF atlas](SQF-Code-Atlas) -> [Function index](Function-And-Module-Index) -> [Networking/PV](Networking-And-Public-Variables) -> [PV channel index](Public-Variable-Channel-Index) |
| Work on UI/HUD | [Client UI/HUD/menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) -> [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) -> [Service menu affordability guards](Service-Menu-Affordability-Guards) -> [Tools/build](Tools-And-Build-Workflow) |
| Coordinate Codex and Claude | [Progress dashboard](Progress-Dashboard) -> [Coordination board](Coordination-Board) -> [Agent collaboration protocol](Agent-Collaboration-Protocol) -> [Claude loop goal](Claude-Loop-Goal) -> [Agent worklog](Agent-Worklog) |
| Bootstrap an LLM agent | [LLM agent entry pack](LLM-Agent-Entry-Pack) -> [`agent-entrypoint.json`](agent-entrypoint.json) -> [`llms.txt`](llms.txt) -> [`agent-context.json`](agent-context.json) -> [Feature status](Feature-Status-Register) -> [Progress dashboard](Progress-Dashboard) |

Most content pages now include a **Continue Reading** block with previous and next links for the main handbook path; a few index and ledger pages use lighter related-link strips.

## First Principles

| Rule | Details |
| --- | --- |
| Source mission | Gameplay edits start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`. |
| Generated missions | `Missions_Vanilla` is the maintained generated/copy target. `Modded_Missions` exists in-tree, but current LoadoutManager generation/package paths do not actively maintain it. |
| Script reference | Use Bohemia Interactive Arma 2 OA scripting docs, not Arma 3 assumptions; see [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) for the current docs scan. |
| Windows path trap | Use PowerShell `-LiteralPath` for `[55-2hc]` paths because brackets are wildcard syntax. |
| Current branch docs | Repo mirror lives in PR #2 on `docs/developer-wiki-index`. |

## Reading Paths

| Task | Pages |
| --- | --- |
| Understand startup flow | [Architecture overview](Architecture-Overview) -> [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) -> [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) -> [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) -> [SQF code atlas](SQF-Code-Atlas) |
| Work on networking | [Networking and public variables](Networking-And-Public-Variables) -> [Public variable channel index](Public-Variable-Channel-Index) -> [SQF code atlas](SQF-Code-Atlas) |
| Work on economy, towns, upgrades or supply | [Economy, towns and supply](Economy-Towns-And-Supply) -> [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) -> [Economy authority first cut](Economy-Authority-First-Cut) -> [Upgrades/research atlas](Upgrades-And-Research-Atlas) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) -> [Supply mission architecture](Supply-Mission-Architecture) -> [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) -> [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) -> [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) |
| Work on AI/performance | [AI, headless and performance](AI-Headless-And-Performance) -> [AI commander autonomy audit](AI-Commander-Autonomy-Audit) -> [Performance opportunity sweep](Performance-Opportunity-Sweep), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Client skill init idempotency](Client-Skill-Init-Idempotency), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) -> [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook) -> [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) -> [Feature status register](Feature-Status-Register) |
| Work on UI/HUD/menus | [Client UI, HUD and menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) -> [UI IDD collision repair](UI-IDD-Collision-Repair) -> [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) -> [Gear template profile filter](Gear-Template-Profile-Filter) -> [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) -> [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| Work on core gameplay | [Gameplay systems atlas](Gameplay-Systems-Atlas) -> [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) -> [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) -> [Victory/endgame atlas](Victory-And-Endgame-Atlas) -> [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) -> [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas) -> [Modules atlas](Modules-Atlas) -> [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) -> [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) -> [Upgrades/research atlas](Upgrades-And-Research-Atlas) -> [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup) -> [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) -> [Core systems index](Core-Systems-Index) |
| Test or release changes | [Testing workflow](Testing-Debugging-And-Release-Workflow) -> [Source fix propagation queue](Source-Fix-Propagation-Queue) -> [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) -> [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) -> [Tools/build](Tools-And-Build-Workflow) -> [Knowledge platform roadmap](Knowledge-Platform-Roadmap) -> [Hardening roadmap](Hardening-Implementation-Roadmap) -> [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) -> [Server authority map](Server-Authority-Migration-Map) -> [ICBM authority playbook](ICBM-Authority-Playbook) -> [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) |
| Check agent progress | [Progress dashboard](Progress-Dashboard) -> [`agent-status.json`](agent-status.json) -> [`agent-events.jsonl`](agent-events.jsonl) |
| Coordinate agents | [LLM agent entry pack](LLM-Agent-Entry-Pack) -> [Progress dashboard](Progress-Dashboard) -> [Coordination board](Coordination-Board) -> [Agent worklog](Agent-Worklog) -> [Codebase coverage ledger](Codebase-Coverage-Ledger) -> [Claude long-term goal](Claude-Long-Term-Goal) -> [Claude loop goal](Claude-Loop-Goal) |
| Understand WASP-specific additions | [WASP overlay](WASP-Overlay) -> [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) -> [Feature status register](Feature-Status-Register) |

## Current Map

| Area | Page |
| --- | --- |
| Architecture | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) |
| Boot dependencies | [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) |
| Inventory | [Source inventory](Source-Inventory), [Content structure and maps](Content-Structure-And-Maps) |
| Code | [Function and module index](Function-And-Module-Index), [SQF code atlas](SQF-Code-Atlas), [Variable and naming conventions](Variable-And-Naming-Conventions) |
| Runtime systems | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Modules atlas](Modules-Atlas), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas), [Upgrades/research atlas](Upgrades-And-Research-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Core systems index](Core-Systems-Index), [Economy, towns and supply](Economy-Towns-And-Supply), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [AI, headless and performance](AI-Headless-And-Performance), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Client skill init idempotency](Client-Skill-Init-Idempotency), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) |
| Networking | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index) |
| UI | [Client UI, HUD and menus](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| WASP additions | [WASP overlay](WASP-Overlay), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) |
| Operations | [Tools and build workflow](Tools-And-Build-Workflow), [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow), [Knowledge platform roadmap](Knowledge-Platform-Roadmap), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit), [AntiStack database extension audit](AntiStack-Database-Extension-Audit) |
| Risk and future work | [Feature status register](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Pending owner decisions](Pending-Owner-Decisions), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Paratrooper marker revival](Paratrooper-Marker-Revival), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Client skill init idempotency](Client-Skill-Init-Idempotency), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Resistance supply scaffold](Resistance-Supply-Scaffold), [UI IDD collision repair](UI-IDD-Collision-Repair), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Hardening implementation roadmap](Hardening-Implementation-Roadmap), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Server authority migration map](Server-Authority-Migration-Map), [ICBM authority playbook](ICBM-Authority-Playbook), [Economy authority first cut](Economy-Authority-First-Cut), [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas), [Upgrades/research atlas](Upgrades-And-Research-Atlas), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow), [HC delegation/failover playbook](Headless-Delegation-And-Failover-Playbook), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Codebase coverage ledger](Codebase-Coverage-Ledger), [Wiki quality audit](Wiki-Quality-Audit), [Documentation implementation plan](Documentation-Implementation-Plan) |
| LLM and agent entrypoints | [LLM agent entry pack](LLM-Agent-Entry-Pack), [`llms.txt`](llms.txt), [`agent-context.json`](agent-context.json), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl) |
| Agent collaboration | [AI assistant developer guide](AI-Assistant-Developer-Guide), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), [Agent context](Agent-Context), [Progress dashboard](Progress-Dashboard), [Coordination board](Coordination-Board), [Agent collaboration protocol](Agent-Collaboration-Protocol), [Claude loop goal](Claude-Loop-Goal) |

## Repo Shape

Tracked-file snapshot from `git ls-files`; see [Source inventory](Source-Inventory) for full extension and subsystem counts plus regeneration commands.

| Count | Top-level path |
| ---: | --- |
| 1475 | `Modded_Missions` |
| 787 | `Missions` |
| 786 | `Missions_Vanilla` |
| 199 | `Tools` |
| 110 | `docs` |
| 42 | `DiscordBot` |
| 16 | `Extension` |
| 3 | `Guides` |
| 3 | `Mods` |
| 2 | `BattlEyeFilter` |
| 2 | `.github` |

## Machine Context

- Human-readable agent brief: [Agent context](Agent-Context)
- Machine-readable agent file: [`agent-context.json`](agent-context.json)
- Machine-readable feature status: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
- Machine-readable OA compatibility audit: [`agent-compatibility-audit.json`](agent-compatibility-audit.json)
- Human-readable progress dashboard: [Progress dashboard](Progress-Dashboard)
- Machine-readable progress file: [`agent-status.json`](agent-status.json)
- Machine-readable collaboration file: [`agent-collaboration.json`](agent-collaboration.json)
- Machine-readable release-readiness ledger: [`agent-release-readiness.json`](agent-release-readiness.json)
- Machine-readable hardening backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)
- Machine-readable test evidence schema: [`agent-test-plan.schema.json`](agent-test-plan.schema.json)
- External PDF report metadata: [`external-research-report-manifest.json`](external-research-report-manifest.json)
- Append-only coordination feed: [`agent-events.jsonl`](agent-events.jsonl)
- Agent coordination log: [Agent worklog](Agent-Worklog)

Persistent navigation is provided by `_Sidebar.md`; shared bottom navigation is provided by `_Footer.md`.

## Continue Reading

Previous: [Claude long-term goal](Claude-Long-Term-Goal) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
