# Subagent Discovery Swarm

This page is the compact gateway for read-only scout waves. It records which scout output was harvested, rejected or left as non-evidence without repeating the same source claims already promoted into owner pages.

Current rule: scout reports are leads. A finding becomes canonical only after Codex source-checks it and promotes it into the owning atlas, [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) or a machine-readable record.

## Current State

| Area | State | Read next |
| --- | --- | --- |
| Active scout waves | None. The latest navigation/deep-slice wave is returned or closed. | [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json) |
| Current pruning note | This page was condensed on 2026-06-05 because the promoted scout evidence already lives in canonical owner pages. | [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) |
| Raw chronology | Preserved in append-only logs and worklog entries, not repeated here. | [Agent worklog](Agent-Worklog), [`agent-events.jsonl`](agent-events.jsonl), [`agent-collaboration.json`](agent-collaboration.json) |
| Relaunch candidates | Only relaunch narrow file-family micro-scouts when a canonical page names a real gap. | [Codebase coverage ledger](Codebase-Coverage-Ledger), [Pending owner decisions](Pending-Owner-Decisions) |

## Canonical Destinations

Use these pages instead of old scout summaries when developing or reviewing the mission.

| Scout topic | Canonical destination |
| --- | --- |
| Architecture, boot and lifecycle | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Networking, PV/PVF and direct publicVariable risk | [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) |
| Construction, factories, economy and upgrades | [Construction/CoIn](Construction-And-CoIn-Systems-Atlas), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Economy authority first cut](Economy-Authority-First-Cut), [Upgrades/research](Upgrades-And-Research-Atlas) |
| Towns, supply and victory | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [Supply mission architecture](Supply-Mission-Architecture), [Supply authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Victory/endgame](Victory-And-Endgame-Atlas) |
| Commander, HQ, AI and HC | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) |
| UI, HUD, gear and EASA | [Client UI systems](Client-UI-Systems-Atlas), [Player UI workflow](Player-UI-Workflow-Map), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas), [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Tooling, generated missions and release gates | [Tools/build](Tools-And-Build-Workflow), [Tooling release readiness](Tooling-Release-Readiness-Audit), [Source inventory](Source-Inventory), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| External integrations and ops | [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit), [AntiStack database audit](AntiStack-Database-Extension-Audit), [Server ops runbook](Server-Ops-Runbook) |
| Community, upstream and branch history | [Community & Dev](Community-And-Dev), [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [Current source status snapshot](Current-Source-Status-Snapshot) |

## Harvest Snapshot

This table keeps the useful routing memory while avoiding wave-by-wave duplicated proof.

| Batch | Status | What survived |
| --- | --- | --- |
| Navigation parity and deep-slice scouts, 2026-06-04 | Returned or closed. Economy scout timed out twice and is non-evidence. | Sidebar/MkDocs navigation parity was patched. Support, UI, AI/HC and tooling reports mostly confirmed existing owner pages. |
| Depth leftovers mini scouts, 2026-06-04 | Returned and closed. | Selected deltas landed in Gear/EASA, AI runtime/HC, PerformanceAuditAnalyzer, ops/tooling, generated-release drift notes and root-scope PV authority warnings. |
| Fresh background Spark threads, 2026-06-04 | Five completed, four interrupted, one UI thread errored. | Completed reports mostly confirmed canonical coverage; the buy-menu driver-default profile key split was promoted to Factory/Purchase and Development Lessons. Interrupted/error threads are not evidence. |
| Waves S through P | Harvested. | Selected corrections landed in Victory/endgame, External integrations, Tools/build, Abandoned feature revival, Deep-review findings, Command version reference, Economy authority, Public variable index, Construction/CoIn, AI runtime/HC, Client UI, Hosted FPS and Gear/EASA pages. |
| Waves O through J | Harvested or partially harvested. | Useful findings were promoted into owner pages. Remaining broad scout narration is historical only. |
| Waves I, H, G and F | Published or integrated. | Small focused reports seeded the current lifecycle, economy, UI, AntiStack, commander/HQ, respawn/MASH, direct-PV, tooling and support pages. |
| Older integration pool and waiting-report tables | Historical. | Treat as provenance. Current active ownership is in [Progress dashboard](Progress-Dashboard), [Coordination board](Coordination-Board) and [`agent-status.json`](agent-status.json). |

## Non-Evidence And Relaunch Notes

Do not treat these as current findings:

- Spark starts that hit quota or failed before a final report.
- Interrupted background threads without a final report.
- Broad "report received" rows from old pool tables after their useful findings were harvested into owner pages.
- Duplicate-confirmation scout summaries that only restated already source-backed DR or Feature Status rows.

Potential relaunches should be narrow and source-path bounded:

| Candidate | Relaunch only if |
| --- | --- |
| Economy/towns/supply micro-scout | A canonical economy or supply page names a specific unresolved source question. |
| Respawn/MASH micro-scout | New source changes touch MASH marker relay, respawn lookup or HQ recovery. |
| Runtime/HC micro-scout | HC delegation, AFK/AntiStack or FPS code changes need fresh source review. |
| UI/dialog micro-scout | A branch changes dialog IDs, missing resources, EASA/buy menus or RHUD display ownership. |

## Integration Rules

- Scouts do not edit files, commit, push or publish.
- Codex should spot-check high-risk scout claims before adding them to user-facing docs.
- Findings land in the owning atlas or playbook first, then in [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and machine files when relevant.
- If Claude is working the same subsystem, add a handoff note instead of overwriting Claude-owned review pages.
- Use Arma 2 OA 1.64 references only; do not import Arma 3 implementation assumptions from a scout.

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-status.json`](agent-status.json)
