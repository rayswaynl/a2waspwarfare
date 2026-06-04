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
| P2 | Overlapping atlases | Large gameplay/UI/factory/construction pages still share some introductory framing. | Prefer short gateway summaries with strong related-page links. |

## Decisions

| Date | Page | Action | Reason | Preserved evidence / destination |
| --- | --- | --- | --- | --- |
| 2026-06-05 | [Instructions for Codex](Instructions-For-Codex) | Condensed | The old file duplicated completed queue items from [Wiki quality audit](Wiki-Quality-Audit) and [Deep-review findings](Deep-Review-Findings), making new agents start from stale work. | Current loop kept here; old audit history remains in [Wiki quality audit](Wiki-Quality-Audit), [Deep-review findings](Deep-Review-Findings), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl). |
| 2026-06-05 | [External research reports](External-Research-Reports) | Condensed | The page repeated report metadata and broad findings that are already in the manifest, DR ledger and subsystem pages. | Exact hashes/paths stay in [`external-research-report-manifest.json`](external-research-report-manifest.json); current behavior proof stays in [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register) and owner atlases. |
| 2026-06-05 | [Subagent discovery swarm](Subagent-Discovery-Swarm) | Condensed | Historic scout-wave tables had become a long chronology of mostly harvested or non-evidence starts. | Promoted findings stay in owner pages and [Agent worklog](Agent-Worklog); the swarm page now keeps harvest state, non-evidence rules and narrow relaunch guidance. |
| 2026-06-05 | [Deep-review findings](Deep-Review-Findings) | Added routing index | The page is intentionally long as an evidence ledger, but readers needed a short map to canonical owner pages before diving into old DR prose. | Full DR entries remain untouched; the new index points finding families to current owner pages. |
| 2026-06-05 | [Subagent discovery swarm](Subagent-Discovery-Swarm) | Condensed | The page had become a long scout-wave chronology even though the dashboard now says historic scout detail belongs in [Agent worklog](Agent-Worklog), [`agent-events.jsonl`](agent-events.jsonl) and owner pages. Repeated duplicate-confirmation summaries slowed readers and risked reopening closed/non-evidence threads. | Preserved current state, canonical destination map, harvest snapshot, non-evidence rules and relaunch notes. Promoted findings remain in pages such as [Networking/PV](Networking-And-Public-Variables), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Client UI systems](Client-UI-Systems-Atlas), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl). |
| 2026-06-05 | [External research reports](External-Research-Reports) | Condensed / absorbed | The previous page repeated report-by-report synthesis even though the manifest preserves exact metadata and later DR/source checks own the actionable facts. | Replaced with a catch-up absorption matrix. Exact report paths/hashes remain in [`external-research-report-manifest.json`](external-research-report-manifest.json); verified facts route to [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables), [Testing workflow](Testing-Debugging-And-Release-Workflow) and subsystem atlases. |
| 2026-06-05 | [Deep-review findings](Deep-Review-Findings) | Keep / index | The DR entries are source-cited evidence and false-positive guardrails, but the chronological page is too large as a navigation surface. | Added a current routing index by finding family. Original DR evidence stays on the page; daily work routes through the listed canonical owner pages. |
| 2026-06-05 | [Subagent discovery swarm](Subagent-Discovery-Swarm) | Keep / defer broader pruning | Recent wave tables already mark returned, duplicate-confirmation, selected-harvest and unharvested scout output. | Current high-value action is routing readers to owner pages, not deleting scout provenance. Later pruning can summarize older wave tables after checking no unique unpromoted evidence remains. |

## Catch-Up Matrix

| Input family | Unique findings left after source-check | Already documented where | Missing destination | Decision |
| --- | --- | --- | --- | --- |
| External PDFs and Markdown reports | Mostly corroboration of source-backed DR and subsystem pages; DR-43 remains the notable source-confirmed report-intake delta. | [External research reports](External-Research-Reports), [Deep-review findings](Deep-Review-Findings), [`external-research-report-manifest.json`](external-research-report-manifest.json) | None for broad report prose. Specific new claims need named source targets. | Absorbed; keep metadata and routing only. |
| Deep-review findings DR-1..DR-47 | Source-backed evidence remains valuable; daily readers need owner-page routing. | [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), subsystem atlases | No new page. Implementation belongs to code-owner playbooks. | Keep evidence ledger; add routing index. |
| Recent scout waves | Most returned reports either confirmed canonical pages or had selected deltas already promoted. Economy/commander/respawn/runtime/perf interrupted scouts are explicitly non-evidence until relaunched. | [Subagent discovery swarm](Subagent-Discovery-Swarm), [Agent worklog](Agent-Worklog), owner pages named in the wave tables | Optional future micro-scouts only for narrow unharvested lanes. | Keep current wave summary; avoid duplicate prose. |
| Miksuu wiki imports and upstream lessons | Valuable provenance and branch/commit lessons; not current implementation truth without repo verification. | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | None; current-source caveats are already present. | Keep as archive/provenance. |

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
