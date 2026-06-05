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

## Current Pruning Backlog

| Priority | Area | Current state | Preferred action |
| --- | --- | --- | --- |
| P0 | `Instructions-For-Codex.md` | Old completed Claude/Codex queue was still presented as a live action list. | Condensed into a current operating contract; history remains in [Wiki quality audit](Wiki-Quality-Audit), [Deep-review findings](Deep-Review-Findings) and [Agent worklog](Agent-Worklog). |
| P0 | Research intake pages | External reports are useful as leads, but much of the content is corroboration of already source-backed DR findings. | Keep [External research reports](External-Research-Reports) as an intake ledger; route unique deltas to canonical pages and mark repeated report claims absorbed. |
| P0 | [Deep-review findings](Deep-Review-Findings) | The page is a valuable 47-finding evidence ledger, but too long to use as a first stop. | Keep the DR evidence intact; add routing/index layers and route daily work through owner pages. |
| P1 | Progress/status pages | Dashboard has improved, but batch rows can still grow faster than readers can use them. | Keep the dashboard compact; move long chronology to [Agent worklog](Agent-Worklog) and event files. |
| P1 | Imported Miksuu wiki archive | Valuable history/provenance, not current implementation truth. | Keep archive pages under Community & Dev, but avoid promoting them as current source behavior without repo verification. |
| P1 | Scout-wave pages | Useful for provenance, but repeated "mostly confirmed canonical docs" text was low-value after harvest. | [Subagent discovery swarm](Subagent-Discovery-Swarm) is now a compact gateway; keep raw chronology in [Agent worklog](Agent-Worklog), [`agent-events.jsonl`](agent-events.jsonl) and git history. |
| P2 | Overlapping atlases | First gateway-pruning pass is complete for [Core systems index](Core-Systems-Index) and [Gameplay systems atlas](Gameplay-Systems-Atlas); Feature Status scout residue has been condensed. UI/runtime quick-ref pruning and navigation-chain cleanup remain later passes. | Prefer short gateway summaries with strong related-page links. |

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

## Catch-Up Matrix

| Input family | Unique findings left after source-check | Already documented where | Missing destination | Decision |
| --- | --- | --- | --- | --- |
| External PDFs and Markdown reports | Mostly corroboration of source-backed DR and subsystem pages; DR-43 remains the notable source-confirmed report-intake delta. | [External research reports](External-Research-Reports), [Deep-review findings](Deep-Review-Findings), [`external-research-report-manifest.json`](external-research-report-manifest.json) | None for broad report prose. Specific new claims need named source targets. | Absorbed; keep metadata and routing only. |
| Deep-review findings DR-1..DR-47 | Source-backed evidence remains valuable; daily readers need owner-page routing. | [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), subsystem atlases | No new page. Implementation belongs to code-owner playbooks. | Keep evidence ledger; add routing index. |
| Recent scout waves | Most returned reports either confirmed canonical pages or had selected deltas already promoted. Economy/commander/respawn/runtime/perf interrupted scouts are explicitly non-evidence until relaunched. | [Subagent discovery swarm](Subagent-Discovery-Swarm), [Agent worklog](Agent-Worklog), owner pages named in the wave tables | Optional future micro-scouts only for narrow unharvested lanes. | Keep current wave summary; avoid duplicate prose. |
| Miksuu wiki imports and upstream lessons | Valuable provenance and branch/commit lessons; not current implementation truth without repo verification. | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Community & Dev](Community-And-Dev), [Upstream changelog feature leads](Upstream-Changelog-Feature-Leads), [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | None; current-source caveats are already present. | Keep as archive/provenance; do not sidebar every archive page. |
| Fresh pruning scouts on 2026-06-05 | UI/runtime gateway bloat and navigation-chain inconsistencies are real next-pass targets, but they are not blockers for the Feature Status cleanup. | [Client UI/HUD and menus](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Server ops runbook](Server-Ops-Runbook), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Progress dashboard](Progress-Dashboard) | Optional next batch: UI/runtime quick-reference pruning plus Continue Reading/navigation fixes. | Keep as next-pass leads; patch only after source/page-owner review. |

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
