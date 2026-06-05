# A2 Wasp Warfare Developer Wiki

Developer documentation for `rayswaynl/a2waspwarfare`, an Arma 2: Operation Arrowhead 1.64 Warfare / CTI mission and server ecosystem.

This page is the front door. It should help you choose the right owner page quickly, not repeat the whole wiki.

## Start Here

| If you are... | Open first | Then |
| --- | --- | --- |
| New human developer | [Quickstart](Quickstart-For-Humans-And-Agents) | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [SQF code atlas](SQF-Code-Atlas) |
| AI assistant / LLM | [LLM agent entry pack](LLM-Agent-Entry-Pack) | [`llms.txt`](llms.txt), [`agent-entrypoint.json`](agent-entrypoint.json), [`agent-context.json`](agent-context.json), [AI assistant guide](AI-Assistant-Guide) |
| Current work reviewer | [Progress dashboard](Progress-Dashboard) | [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [Agent worklog](Agent-Worklog) |
| Feature or bug triager | [Feature status register](Feature-Status-Register) | [Dead/stale code register](Dead-Code-And-Stale-Code-Register), [Pending owner decisions](Pending-Owner-Decisions) |
| Gameplay implementer | [Gameplay systems atlas](Gameplay-Systems-Atlas) | [Construction/CoIn](Construction-And-CoIn-Systems-Atlas), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Server runtime](Server-Runtime-And-Operations) |
| Public-server hardening owner | [Hardening roadmap](Hardening-Implementation-Roadmap) | [Server authority map](Server-Authority-Migration-Map), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Upstream/community archaeologist | [Community & Dev](Community-And-Dev) | [Miksuu wiki import](Miksuu-Upstream-Wiki-Import), [Developer history](Developer-History-And-Upstream-Lessons), [Upstream commit intel](Upstream-Miksuu-Commit-Intel) |
| Docs/platform maintainer | [Navigation inventory](Navigation-Inventory-And-Page-Status) | [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger), [Knowledge platform roadmap](Knowledge-Platform-Roadmap), [Wiki mirror plan](Wiki-Mirror-Reconciliation-Plan) |

## Non-Negotiables

| Rule | Why it matters |
| --- | --- |
| Source gameplay edits start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`. | This is the source mission. |
| Treat `Missions_Vanilla` as maintained generated/copy output. | Propagate with `Tools/LoadoutManager`; do not hand-edit drift unless a release owner says so. |
| Treat `Modded_Missions` as divergent/stubbed unless tooling proves otherwise. | Current generation/package paths do not actively maintain those folders. |
| Use Arma 2 OA 1.64 scripting references. | Arma 3 assumptions are a common source of bad fixes. |
| Check [Progress dashboard](Progress-Dashboard) before claiming work. | It prevents duplicate Codex/Claude/agent lanes. |
| Keep `docs/wiki` and the GitHub wiki mirror in sync. | Humans use the wiki; agents use the repo mirror. |

## Main Routes

| Need | Canonical route |
| --- | --- |
| Startup, lifecycle, includes | [Architecture overview](Architecture-Overview) -> [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) -> [Mission config/version graph](Mission-Config-Version-Include-Graph) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| SQF ownership and compile flow | [SQF code atlas](SQF-Code-Atlas) -> [Function and module index](Function-And-Module-Index) -> [Source inventory](Source-Inventory) |
| Networking and authority | [Networking/PV](Networking-And-Public-Variables) -> [Public variable channel index](Public-Variable-Channel-Index) -> [Server authority map](Server-Authority-Migration-Map) |
| Economy, towns, supply | [Economy/towns/supply](Economy-Towns-And-Supply) -> [Towns/camps/capture](Towns-Camps-And-Capture-Atlas) -> [Supply mission architecture](Supply-Mission-Architecture) |
| Commander, HQ, construction | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) -> [Construction/CoIn](Construction-And-CoIn-Systems-Atlas) -> [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) |
| Factories, purchases, upgrades | [Factory/purchase](Factory-And-Purchase-Systems-Atlas) -> [Upgrades/research](Upgrades-And-Research-Atlas) -> [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) |
| AI, HC, performance | [AI/headless/performance](AI-Headless-And-Performance) -> [Headless client scaling](Headless-Client-Scaling-And-Topology) -> [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| UI, HUD, menus | [Client UI/HUD/menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Tools, build, release | [Tools/build workflow](Tools-And-Build-Workflow) -> [Source fix propagation queue](Source-Fix-Propagation-Queue) -> [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Integrations and ops | [External integrations](External-Integrations) -> [Integration trust boundary audit](Integration-Trust-Boundary-Audit) -> [Server runtime and operations](Server-Runtime-And-Operations) |

## Current Work

| Surface | Use it for |
| --- | --- |
| [Progress dashboard](Progress-Dashboard) | Human-readable current lanes, July update queue and recent published batches. |
| [`agent-status.json`](agent-status.json) | Compact machine snapshot of active/watchlist/code-owner lanes. |
| [`agent-collaboration.json`](agent-collaboration.json) | Current claim/ownership surface. Historical lanes live in the worklog and event stream. |
| [`agent-events.jsonl`](agent-events.jsonl) | Append-only coordination events. |
| [Agent worklog](Agent-Worklog) | Dated narrative notes and historical batch detail. |

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1
```

After meaningful docs or machine-file edits, also parse touched JSON/JSONL files, mirror touched wiki files, inspect diffs and keep gameplay source unchanged unless Steff explicitly asks for a code patch.

## Navigation Notes

- Persistent navigation is in [`_Sidebar.md`](_Sidebar).
- Shared footer navigation is in [`_Footer.md`](_Footer).
- Page-status and hidden/support-page classification lives in [Navigation inventory](Navigation-Inventory-And-Page-Status).
- Bloat, merge, archive and relevance decisions live in [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger).
- The long-term docs platform recommendation lives in [Knowledge platform roadmap](Knowledge-Platform-Roadmap).

## Continue Reading

Previous: [Claude long-term goal](Claude-Long-Term-Goal) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent pack: [LLM agent entry pack](LLM-Agent-Entry-Pack)
