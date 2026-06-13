# Navigation Inventory And Page Status

This page tracks what the wiki exposes as primary navigation, what MkDocs exposes for the repo mirror, and what pages are intentionally archive, machine-facing or hidden from daily reading.

Use it before adding pages to Home, `_Sidebar.md`, `mkdocs.yml`, `llms.txt` or `_Footer.md`.

## Current Snapshot

Snapshot generated from `docs/wiki/*.md`, `_Sidebar.md`, selected non-Markdown sidebar links and `mkdocs.yml` on 2026-06-13 after routing [Agent worklog archive](Agent-Worklog-Archive) into the sidebar and MkDocs mirror.

| Item | Count | Meaning |
| --- | ---: | --- |
| Markdown pages | 148 | All `.md` pages in `docs/wiki`, including `_Sidebar.md` and `_Footer.md`. |
| Content pages | 146 | Markdown pages excluding `_Sidebar.md` and `_Footer.md`. |
| Sidebar links | 116 | Markdown pages plus selected agent files linked from the GitHub wiki sidebar. This includes [`llms.txt`](llms.txt) and one intentional machine-file link: [`agent-machine-index.json`](agent-machine-index.json). |
| MkDocs entries | 124 | Markdown pages plus [`llms.txt`](llms.txt) listed in `mkdocs.yml` navigation. |
| Pages in both navs | 114 | Primary Markdown pages visible in both GitHub wiki and MkDocs. |
| Pages in neither nav | 23 | Usually archives, instruction pages, old queues, analysis notes or narrow patch pages reached through canonical pages. |
| Sidebar-only links | 1 | [`agent-machine-index.json`](agent-machine-index.json) is intentionally sidebar-only because it is an agent-readable JSON file, not a MkDocs Markdown page. Primary Markdown sidebar-only drift remains `0`. |
| MkDocs-only pages | 9 | All imported Miksuu archive pages. |
| Pages missing `Continue Reading` | 0 | All content pages now expose either owner-page or archive/queue-safe routing. |
| Imported Miksuu archive pages | 9 | Historical provenance; route through [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import). |

## Page Status Rules

| Status | Use when | Navigation rule |
| --- | --- | --- |
| `primary` | Page is a daily entrypoint or canonical owner page. | Link from sidebar and usually MkDocs. |
| `gateway` | Page routes a family of owner pages without owning much source evidence. | Link from sidebar if it reduces clicking friction; keep short. |
| `archive` | Historical provenance, imported wiki content or long chronology. | Route through an index page; do not list every archive in the sidebar. |
| `machine` | JSON/JSONL or huge agent-state material. | Link from status/agent pages, not broad human nav. |
| `patch-ready` | Narrow source-backed implementation handoff. | Link from Feature Status, hardening/backlog pages and the owning subsystem. |
| `hidden-support` | Useful page but not a normal reading starting point. | Keep discoverable through related owner pages and search. |

## Current Drift Buckets

### Sidebar-Only Pages

The sidebar-only primary Markdown page drift is closed as of the 2026-06-05 MkDocs parity pass. The only current sidebar-only item is the machine-readable [`agent-machine-index.json`](agent-machine-index.json), which is intentionally exposed for agents without adding it to MkDocs Markdown navigation.

| Page | Suggested status | Next action |
| --- | --- | --- |
| [`agent-machine-index.json`](agent-machine-index.json) | `machine-file` | Intentionally sidebar-only as of 2026-06-05; linked from LLM entrypoints and sidebar, but not a Markdown content page. |

### MkDocs-Only Pages

These are all imported Miksuu archive pages. Keeping them MkDocs-visible is useful for search, but GitHub wiki users should normally enter through [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) and [Community & Dev](Community-And-Dev).

| Page family | Suggested status | Next action |
| --- | --- | --- |
| `Miksuu-Wiki-Archive-*` | `archive` | Keep grouped under the MkDocs Community & Dev archive section; do not re-add every archive page to the sidebar. |

### Neither-Nav Pages

These pages are not directly listed in either `_Sidebar.md` or `mkdocs.yml`. That is now intentional for the 20-page support set below: they are still linked from owner/status pages, but they should not be first-click navigation unless their role changes.

| Family | Pages | Suggested action |
| --- | --- | --- |
| Patch-ready performance/source-fix pages | [Client skill init](Client-Skill-Init-Idempotency), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Paratrooper marker revival](Paratrooper-Marker-Revival), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Keep out of primary nav if Feature Status, Performance sweep and Testing workflow route to them. |
| Evidence archives and queues | [Agent worklog archive](Agent-Worklog-Archive), [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Audit findings queue](Audit-Findings-Queue-2026-06-03), [Development lessons](Development-Lessons-Learned), [Subagent discovery swarm](Subagent-Discovery-Swarm) | Keep as archive/support pages; expose compact owner routes first. |
| Claude/instruction pages | [Claude goal](Claude-Goal), [Claude long-term goal](Claude-Long-Term-Goal), [Claude loop goal](Claude-Loop-Goal), [Instructions for Codex](Instructions-For-Codex) | Keep discoverable through coordination pages; avoid primary human nav unless actively used. |
| Analysis/support pages | [Client UI and server loop perf findings](Client-UI-And-Server-Loop-Perf-Findings), [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [Performance gain simulation](Performance-Gain-Simulation), [Self-host testing field notes](Self-Host-Testing-Field-Notes) | Keep linked from the owning subsystem or archive index only. |

## Remaining Support-Only Pages

Use this list as the closeout state for neither-nav cleanup. A page should leave this table only when it becomes a primary owner page, a current gateway, or stale enough to merge/archive.

| Status | Pages | Keep reachable through |
| --- | --- | --- |
| `patch-ready` | [Client skill init](Client-Skill-Init-Idempotency), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Paratrooper marker revival](Paratrooper-Marker-Revival), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | [Feature status](Feature-Status-Register), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Hardening roadmap](Hardening-Implementation-Roadmap). |
| `archive` / `evidence-ledger` | [Agent worklog archive](Agent-Worklog-Archive), [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Audit findings queue](Audit-Findings-Queue-2026-06-03), [Development lessons](Development-Lessons-Learned), [Subagent discovery swarm](Subagent-Discovery-Swarm) | [Agent worklog](Agent-Worklog), [Progress dashboard](Progress-Dashboard), [Feature status](Feature-Status-Register), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger). |
| `agent-instruction` | [Claude goal](Claude-Goal), [Claude long-term goal](Claude-Long-Term-Goal), [Claude loop goal](Claude-Loop-Goal), [Instructions for Codex](Instructions-For-Codex) | [Coordination board](Coordination-Board), [Agent collaboration protocol](Agent-Collaboration-Protocol), [AI assistant developer guide](AI-Assistant-Developer-Guide). |
| `analysis-support` | [Client UI/server loop perf findings](Client-UI-And-Server-Loop-Perf-Findings), [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [Performance gain simulation](Performance-Gain-Simulation), [Self-host testing field notes](Self-Host-Testing-Field-Notes) | [Client UI systems atlas](Client-UI-Systems-Atlas), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Server ops runbook](Server-Ops-Runbook). |

## Continue Reading Gaps

Every content page has a `## Continue Reading` block as of the 2026-06-05 archive/queue closeout pass.

| Family | Pages missing block | Decision |
| --- | --- | --- |
| High-traffic owner pages | None | Previously missing owner-page blocks were normalized on 2026-06-05. |
| Archive/queue pages | None | Queue pages route back to owning indexes; imported archive pages keep an archive-chain caveat. |

## Maintenance Checklist

1. Add a page to exactly one obvious owner family before linking it broadly.
2. If the page is archive or machine material, link it from an index instead of the sidebar.
3. If a page becomes a primary owner page, add it to `_Sidebar.md`, `mkdocs.yml`, Home or the relevant gateway page.
4. Update [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) when demoting, merging or archiving pages.
5. Run `docs/validate-wiki.ps1` after link changes.

## Continue Reading

Previous: [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) | Next: [Knowledge platform roadmap](Knowledge-Platform-Roadmap)

Main map: [Home](Home) | Status: [Progress dashboard](Progress-Dashboard) | Agent file: [`agent-context.json`](agent-context.json)
