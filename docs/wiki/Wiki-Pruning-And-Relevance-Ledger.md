# Wiki Pruning And Relevance Ledger

This ledger records decisions to condense, archive, merge or keep wiki material. Its purpose is to stop the documentation set from growing forever after a finding has already been absorbed into canonical pages.

Rule of thumb: preserve evidence, reduce repeated narration.

## Decision Rules

| Action | Use when | Requirement |
| --- | --- | --- |
| Keep | The page owns a live system, source-backed bug, release gate or agent-readable artifact. | Keep source paths, branch scope and next action visible. |
| Condense | The page is useful but repeats a canonical page. | Replace repeated proof with a short summary plus canonical links. |
| Merge | Two pages answer the same developer question. | Pick one owner and leave the other as a gateway or archive note. |
| Archive | Material is historical, imported or low-action but still valuable as provenance. | Label it historical and link to the current owner page. |
| Remove | Content is duplicated elsewhere and has no unique source evidence or provenance value. | Only after confirming no inbound navigation depends on it. |

## Pruning Backlog Completion State

| Priority | Area | Completion state | Evidence / route |
| --- | --- | --- | --- |
| P0 | `Instructions-For-Codex.md` | Completed | Condensed into a current operating contract; history remains in [Wiki quality audit](Wiki-Quality-Audit), [Deep-review findings](Deep-Review-Findings), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl). |
| P0 | Research intake pages | Completed | [External research reports](External-Research-Reports) is an intake ledger; unique deltas are routed through [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), subsystem pages and the manifest. |
| P0 | [Deep-review findings](Deep-Review-Findings) | Completed | DR evidence is preserved and indexed by finding family; daily work routes through owner pages instead of expanding the ledger. |
| P1 | Progress/status pages | Completed for this pruning goal | [Progress dashboard](Progress-Dashboard) is compacted toward current-state use; long chronology is in [Agent worklog](Agent-Worklog), [`agent-status.json`](agent-status.json) and [`agent-events.jsonl`](agent-events.jsonl). |
| P1 | Imported Miksuu wiki archive | Completed | Archive pages are caveated as historical provenance, routed through [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) and [Community & Dev](Community-And-Dev), and demoted from sidebar page-by-page prominence. |
| P1 | Scout-wave pages | Completed | [Subagent discovery swarm](Subagent-Discovery-Swarm) is a compact gateway; raw chronology stays in [Agent worklog](Agent-Worklog), [`agent-events.jsonl`](agent-events.jsonl) and git history. |
| P2 | Overlapping atlases | Completed for the discovered bloat set | [Core systems index](Core-Systems-Index), [Gameplay systems atlas](Gameplay-Systems-Atlas), [Feature Status](Feature-Status-Register), UI gateways and runtime quick-reference pages have been pruned into owner-page routing. |

## Decisions

| Date | Page | Action | Reason | Preserved evidence / destination |
| --- | --- | --- | --- | --- |
| 2026-06-05 | [Instructions for Codex](Instructions-For-Codex) | Condensed | The old file duplicated completed queue items from [Wiki quality audit](Wiki-Quality-Audit) and [Deep-review findings](Deep-Review-Findings), making new agents start from stale work. | Current loop kept here; old audit history remains in [Wiki quality audit](Wiki-Quality-Audit), [Deep-review findings](Deep-Review-Findings), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl). |
| 2026-06-05 | [External research reports](External-Research-Reports) | Condensed / absorbed | The previous page repeated report-by-report synthesis even though the manifest preserves exact metadata and later DR/source checks own the actionable facts. | Replaced with a catch-up absorption matrix. Exact report paths/hashes remain in [`external-research-report-manifest.json`](external-research-report-manifest.json); verified facts route to [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables), [Testing workflow](Testing-Debugging-And-Release-Workflow) and subsystem atlases. |
| 2026-06-05 | [Deep-review findings](Deep-Review-Findings) | Keep / index | The DR entries are source-cited evidence and false-positive guardrails, but the chronological page is too large as a navigation surface. | Added a current routing index by finding family. Original DR evidence stays on the page; daily work routes through the listed canonical owner pages. |
| 2026-06-05 | [Subagent discovery swarm](Subagent-Discovery-Swarm) | Condensed | Historic scout-wave tables had become a long chronology of mostly harvested or non-evidence starts, slowing readers and risking reopened closed threads. | Promoted findings stay in owner pages, [Agent worklog](Agent-Worklog), [`agent-events.jsonl`](agent-events.jsonl) and git history. The swarm page now keeps current state, canonical destinations, harvest state, non-evidence rules and narrow relaunch guidance. |
| 2026-06-05 | [Miksuu upstream wiki archive](Miksuu-Upstream-Wiki-Import) + [`_Sidebar.md`](_Sidebar) | Archive / demote from sidebar | The individual `Miksuu-Wiki-Archive-*` pages are valuable provenance, but listing every archive page in the sidebar made historical material look like current implementation docs. | Archive pages stay intact and are linked from [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) and [Community & Dev](Community-And-Dev). Sidebar now exposes the archive index, source-check leads and current upstream/history pages only. |
| 2026-06-05 | [Core systems index](Core-Systems-Index) + [Gameplay systems atlas](Gameplay-Systems-Atlas) | Condense / gateway prune | The core index repeated subsystem summaries and made overconfident split-authority claims, while the gameplay atlas repeated mini-atlases for economy, commander, upgrades, construction and factories already owned by dedicated pages. | Core systems is now a route index with gateway rules. Gameplay systems keeps town evidence and balance constants, but routes duplicated implementation walkthroughs to economy, commander, upgrade, construction and factory owner pages. |
| 2026-06-05 | [Feature status](Feature-Status-Register) | Condense / route scout harvest | Dated mini-scout waves, duplicate AIBuyUnit/side-supply notes, a stale PR #1 supply-handler defect claim and a trailing deep-audit addendum made the live register read like chronology rather than current triage. | Replaced scout-wave sections with a source-harvest routing matrix, kept AI supply logistics as a config-gated broken feature, corrected PR #1 killed-handler status, removed the duplicate AIBuyUnit row, and routed economy/supply/commander evidence to owner pages. |
| 2026-06-05 | UI/runtime quick-reference pages | Condense / gateway prune | The UI and runtime quick-reference pages repeated evidence already owned by [Client UI systems atlas](Client-UI-Systems-Atlas), [UI IDD collision repair](UI-IDD-Collision-Repair), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [External integrations](External-Integrations) and HC failover pages. | [UI HUD and dialogs](UI-HUD-And-Dialogs) is now a pure alias; [Client UI/HUD/menus](Client-UI-HUD-And-Menus) routes risk families; [Player UI workflow map](Player-UI-Workflow-Map) stays a player-clickable tour; [Server ops runbook](Server-Ops-Runbook) keeps operator contracts; [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) and [Headless client scaling](Headless-Client-Scaling-And-Topology) route generic runtime and implementation-sketch detail to owner pages. |
| 2026-06-05 | [Progress dashboard](Progress-Dashboard) + this ledger | Completion audit / compact | After the pruning batches landed, the dashboard and ledger still read like open work existed. | Dashboard now keeps one current completion batch plus compact route links; this ledger records completion state and separates optional future refinements from required pruning-goal tasks. |
| 2026-06-05 | [Progress dashboard](Progress-Dashboard) | Current-lane freshness | The `Current Lanes` table had re-accumulated published docs batches and stale "commit/push" next actions, making completed work look active. | `Current Lanes` is now a live control panel only. Published batches remain in [Latest Batch](Progress-Dashboard#latest-batch), [Agent worklog](Agent-Worklog), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history. |
| 2026-06-05 | Onboarding pages | Condense / gateway prune | Home, Quickstart, AI Assistant Guide and LLM Agent Entry Pack all partially owned AI boot order, safety rules, current status and routing. | [Home](Home) is a short front door, [Quickstart](Quickstart-For-Humans-And-Agents) is the human first-day path, [AI assistant guide](AI-Assistant-Guide) is a safety gateway and [LLM agent entry pack](LLM-Agent-Entry-Pack) owns canonical AI boot order. Volatile status routes to [Progress dashboard](Progress-Dashboard), [Current source status snapshot](Current-Source-Status-Snapshot), [Source fix propagation queue](Source-Fix-Propagation-Queue) and machine files. |
| 2026-06-05 | [Agent development pack](Agent-Development-Pack) | Alias / prevent duplicate page | Some prompts ask for an "agent development pack", but the canonical boot-order owner is [LLM agent entry pack](LLM-Agent-Entry-Pack). | Added a lightweight alias page and wired it into sidebar, MkDocs and `llms.txt`. Do not put boot-order content on the alias; update [LLM agent entry pack](LLM-Agent-Entry-Pack) instead. |
| 2026-06-05 | [`agent-machine-index.json`](agent-machine-index.json) | Add compact machine index | Future agents had to open many broad pages to find source refs, owner pages, machine records and next gates. | Added a small page-to-source/risk index plus JSONL vNext envelope convention. Keep it as a lookup table, not another narrative page. |

## Catch-Up Matrix

| Input family | Unique findings left after source-check | Already documented where | Missing destination | Decision |
| --- | --- | --- | --- | --- |
| External PDFs and Markdown reports | Mostly corroboration of source-backed DR and subsystem pages; DR-43 remains the notable source-confirmed report-intake delta. | [External research reports](External-Research-Reports), [Deep-review findings](Deep-Review-Findings), [`external-research-report-manifest.json`](external-research-report-manifest.json) | None for broad report prose. Specific new claims need named source targets. | Absorbed; keep metadata and routing only. |
| Deep-review findings DR-1..DR-47 | Source-backed evidence remains valuable; daily readers need owner-page routing. | [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), subsystem atlases | No new page. Implementation belongs to code-owner playbooks. | Keep evidence ledger; add routing index. |
| Recent scout waves | Most returned reports either confirmed canonical pages or had selected deltas already promoted. Economy/commander/respawn/runtime/perf interrupted scouts are explicitly non-evidence until relaunched. | [Subagent discovery swarm](Subagent-Discovery-Swarm), [Agent worklog](Agent-Worklog), owner pages named in the wave tables | Optional future micro-scouts only for narrow unharvested lanes. | Keep current wave summary; avoid duplicate prose. |
| Miksuu wiki imports and upstream lessons | Valuable provenance and branch/commit lessons; not current implementation truth without repo verification. | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Community & Dev](Community-And-Dev), [Upstream changelog feature leads](Upstream-Changelog-Feature-Leads), [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | None; current-source caveats are already present. | Keep as archive/provenance; do not sidebar every archive page. |
| Fresh pruning scouts on 2026-06-05 | UI/runtime gateway bloat has been source-checked and pruned. Navigation-chain inconsistencies had a first small fix, and the imported archive pages already carry historical/current-truth caveats. | [Client UI/HUD and menus](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Server ops runbook](Server-Ops-Runbook), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Progress dashboard](Progress-Dashboard) | None for the current pruning goal. Future page-owner refinements can be reopened with fresh evidence. | Harvested; do not expand gateway pages with duplicate proof. |

## Completion Audit

Current evidence as of 2026-06-05:

- No P0/P1/P2 pruning-backlog row above remains in an open state.
- Archive pages are preserved and caveated as historical provenance rather than current implementation truth.
- Major holding pages now route to canonical owner pages instead of repeating long scout/report chronology.
- The dashboard is compacted back to current-state use; old batches route to [Agent worklog](Agent-Worklog), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history.
- Future gameplay hardening, release smoke and code-owner implementation remain valid project work, but they are not unfinished tasks in this pruning ledger.

## Fresh Backlog Leads

These are new cleanup leads from the 2026-06-05 wiki-backlog scout wave. They are not evidence that the earlier pruning batches failed; they are the next refinements to pick when a docs owner wants another bloat pass.

| Priority | Lead | Evidence | Suggested action |
| --- | --- | --- | --- |
| P0 | Reconcile mirror drift before broad edits | The scout reported non-identical wiki/mirror pages including `Arma-2-OA-Command-Version-Reference`, `Miksuu-Wiki-Archive-Changelog` and `Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission`, plus line-ending-only noise in a few files. | File-by-file compare before any bulk copy; keep both sides additive on real content drift. |
| P1 | Separate machine/state files from human navigation | `agent-events.jsonl`, `agent-collaboration.json`, `agent-knowledge.jsonl`, `agent-hardening-backlog.jsonl`, `agent-context.json` and `Agent-Worklog.md` dominate page/file size. | Keep machine files available for agents, but route humans through [Progress dashboard](Progress-Dashboard), [Coordination board](Coordination-Board) and compact indexes. |
| P1 | Shorten Home and stop overclaiming navigation completeness | The scout found `Home.md` mixes start page, tours, repo shape, machine context and reading paths, and says every content page has `Continue Reading` while some current/archive pages do not. | Make Home a shorter launch pad, move large maps to dedicated index pages, or soften the blanket claim. |
| P1 | Maintain one navigation inventory | The scout found pages that are neither in MkDocs nav nor sidebar, plus sidebar-only and MkDocs-only archive differences. | Add a generated/current/archive/machine/hidden navigation inventory instead of hand-auditing drift repeatedly. |
| P2 | Keep imported/archive and raw scout pages demoted | Large historical pages such as Miksuu archives, [Deep-review findings](Deep-Review-Findings), [Agent worklog](Agent-Worklog) and scout chronology remain useful provenance but poor daily entrypoints. | Preserve archives, but expose compact owner routes and current-state indexes first. |
| P2 | Reduce onboarding overlap | [Quickstart](Quickstart-For-Humans-And-Agents), [AI assistant guide](AI-Assistant-Guide), [LLM agent entry pack](LLM-Agent-Entry-Pack), `llms.txt` and Home repeat boot-order guidance. | Pick one canonical agent boot order and make the other pages short audience-specific gateways. |

## Fresh Backlog Progress

| Date | Lead | Status | Evidence / next action |
| --- | --- | --- | --- |
| 2026-06-05 | Maintain one navigation inventory | Started / published | [Navigation inventory and page status](Navigation-Inventory-And-Page-Status) records current sidebar, MkDocs, neither-nav and `Continue Reading` gaps. Next pass should decide whether sidebar-only primary pages join MkDocs and whether MkDocs-only Miksuu archive pages stay search-visible or move behind archive indexes. |
| 2026-06-05 | Close remaining `Continue Reading` gaps | Completed / validated | Queue pages now route back to owning indexes, and imported Miksuu archive pages use archive-chain `## Continue Reading` blocks that preserve the historical-provenance caveat. Recomputed missing count: `0`. |
| 2026-06-05 | Resolve primary sidebar-only MkDocs drift | Completed / validated | Added [PR cleanup lab](PR-Cleanup-And-Integration-Lab), [Headless client scaling](Headless-Client-Scaling-And-Topology), [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and this ledger to `mkdocs.yml`. Primary Markdown sidebar-only drift is `0`; [`agent-machine-index.json`](agent-machine-index.json) is an intentional sidebar-only machine-file link. |
| 2026-06-05 | Promote hidden broad owner/reference pages | Completed / validated | Added [Core systems](Core-Systems-Index), [Modules atlas](Modules-Atlas), [Server runtime](Server-Gameplay-Runtime-Atlas), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Player AI caps](Player-AI-Caps-And-Role-Balance), [Variable conventions](Variable-And-Naming-Conventions) and [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) to both sidebar and MkDocs. Neither-nav count drops from `27` to `20`; remaining neither-nav pages are archives, prompts, old queues, analysis notes or narrow patch handoffs. |
| 2026-06-05 | Classify remaining neither-nav support pages | Completed / validated | [Navigation inventory](Navigation-Inventory-And-Page-Status) now lists the remaining 20 neither-nav pages by status: `patch-ready`, `archive/evidence-ledger`, `agent-instruction` and `analysis-support`. This makes the remaining hidden pages intentional instead of untriaged drift. |
| 2026-06-05 | Keep dashboard current lanes fresh | Completed / validated | [Progress dashboard](Progress-Dashboard) now keeps `Current Lanes` limited to active/watchlist/code-owner/release-smoke lanes. Completed published batches route through Latest Batch, [Agent worklog](Agent-Worklog), machine status files and git history instead of remaining in the live lane table. |
| 2026-06-05 | Shorten onboarding gateways and stop boot-order duplication | Completed / validated | [Home](Home), [Quickstart](Quickstart-For-Humans-And-Agents), [AI assistant guide](AI-Assistant-Guide), [LLM agent entry pack](LLM-Agent-Entry-Pack) and `agent-entrypoint.json` now separate front-door, human first-day, AI safety, canonical AI boot order and machine-bootstrap roles. |
| 2026-06-05 | Add Agent Development Pack alias | Completed / validated | [Agent development pack](Agent-Development-Pack) now exists as a compatibility alias to [LLM agent entry pack](LLM-Agent-Entry-Pack). |
| 2026-06-05 | Add compact page-to-source machine index | Completed / validated | [`agent-machine-index.json`](agent-machine-index.json) maps high-risk/high-traffic systems to canonical docs, source refs, machine refs, branch scope and next gate. It also records the JSONL vNext envelope convention so new machine rows are more consistent without rewriting legacy records, and [Navigation inventory](Navigation-Inventory-And-Page-Status) marks it as the one intentional sidebar-only machine-file link. |

## Agent Guidance

Before adding a new page, answer:

- Which existing page would a developer open first?
- Is this a new source-backed fact or just another explanation?
- Can the finding be a short section, table row or machine record instead?
- What exact source path, branch or verified DR record makes it trustworthy?
- What should a future agent delete or condense after this is absorbed?

## Continue Reading

Previous: [Wiki quality audit](Wiki-Quality-Audit) | Next: [Progress dashboard](Progress-Dashboard)

Main map: [Home](Home) | Agent instructions: [Instructions for Codex](Instructions-For-Codex) | Research intake: [External research reports](External-Research-Reports)
