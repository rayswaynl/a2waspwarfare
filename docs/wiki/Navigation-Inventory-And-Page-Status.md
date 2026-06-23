# Navigation Inventory And Page Status

This page tracks what the GitHub wiki exposes as primary navigation, what the repo mirror exposes when it is current, and what pages are intentionally archive, machine-facing or hidden from daily reading.

Use it before adding pages to Home, `_Sidebar.md`, `mkdocs.yml`, `llms.txt` or `_Footer.md`.

## Current Snapshot

Snapshot generated from a fresh GitHub wiki checkout rebased over `origin/master@d2bad96` on 2026-06-23. The older local wiki checkout `C:\Users\Steff\a2wasp-wiki` is dirty and behind `origin/master`; the older repo mirror `C:\Users\Steff\a2waspwarfare-docs\docs\wiki` is dirty and has only 93 Markdown files. Do not treat either dirty checkout as a parity source until its uncommitted work is preserved.

| Item | Count | Meaning |
| --- | ---: | --- |
| Markdown pages | 275 | All `.md` pages in the live wiki checkout, including `_Sidebar.md` and `_Footer.md`. |
| Content pages | 273 | Markdown pages excluding `_Sidebar.md` and `_Footer.md`; this matches the GitHub wiki page count shown on Home. |
| Sidebar link refs | 242 | Total local wiki links in `_Sidebar.md` after removing duplicate cross-family refs. |
| Sidebar unique targets | 242 | Unique sidebar targets. This includes [`llms.txt`](llms.txt) and [`agent-machine-index.json`](agent-machine-index.json). |
| Content pages in sidebar | 240 | Markdown content pages linked from `_Sidebar.md`. |
| Pages not in sidebar | 33 | Usually archives, instruction pages, narrow patch pages or support pages reached through canonical owner pages. |
| Footer unique targets | 58 | Shared footer links in `_Footer.md` after the footer support-page prune. |
| Pages not in sidebar or footer | 32 | Support/archive pages that should stay reachable from owner pages rather than broad persistent navigation. |
| Home unique targets | 183 | Local wiki targets linked from [Home](Home), excluding repeated route-table refs. |
| Duplicate sidebar targets | 0 | The duplicate [Player vehicle/travel actions](Player-Vehicle-And-Travel-Actions-Reference) and [QoL trio player hints](QoL-Trio-Player-Hints-Reference) content/reference refs were removed; the UI/player workflow refs remain. |
| Broken local links | 0 | Broad local Markdown link pass across `.md` pages found no missing wiki/file targets. |
| MkDocs entries | Not current | No current `mkdocs.yml` was present in this live wiki checkout, and the older repo mirror is not in parity. Refresh after mirror sync. |
| Pages missing `Continue Reading` | 0 | This batch found and fixed the two AI Commander B69 pages that were missing footer routing. |
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

The live sidebar intentionally exposes two non-Markdown files for agent entry: [`llms.txt`](llms.txt) and [`agent-machine-index.json`](agent-machine-index.json). Primary Markdown sidebar-only drift cannot be compared to MkDocs until the repo mirror is synced again.

| Page | Suggested status | Next action |
| --- | --- | --- |
| [`llms.txt`](llms.txt) | `agent-entry` | Keep in sidebar and Home agent routes. |
| [`agent-machine-index.json`](agent-machine-index.json) | `machine-file` | Keep in sidebar for agents; do not promote as a human content page. |
| [Player vehicle/travel actions](Player-Vehicle-And-Travel-Actions-Reference), [QoL trio player hints](QoL-Trio-Player-Hints-Reference) | `deduped-player-workflow-link` | Duplicate content/reference rows removed on 2026-06-23; keep the UI/player workflow rows. |

### Repo Mirror / MkDocs State

The live GitHub wiki is ahead of the local repo mirror state visible in this workspace. The safe next sync is file-by-file preservation, not a blind copy over either dirty checkout.

| Surface | Observed state | Next action |
| --- | --- | --- |
| `C:\Users\Steff\a2wasp-wiki` | Dirty, behind `origin/master`; many local modified wiki pages plus untracked `validate-wiki.ps1`. | Preserve or branch its uncommitted work before syncing to live wiki. |
| `C:\Users\Steff\a2waspwarfare-docs\docs\wiki` | Dirty, older repo mirror with 93 Markdown files / 91 content pages. | Treat as stale until reconciled against live wiki; do not claim parity. |
| `mkdocs.yml` | No current file in the live wiki checkout or the visible `a2waspwarfare-docs` root. | Refresh MkDocs counts only after the repo mirror is current again. |

### Neither-Nav Pages

These pages are not directly listed in `_Sidebar.md`; 32 of them are also absent from the shared footer. That is mostly intentional: they are linked from owner/status pages, archive indexes or source-fix queues, but should not become first-click navigation unless their role changes.

| Family | Pages | Suggested action |
| --- | --- | --- |
| Patch-ready performance/source-fix pages | [Client skill init](Client-Skill-Init-Idempotency), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Paratrooper marker revival](Paratrooper-Marker-Revival), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Keep out of primary nav if Feature Status, Performance sweep and Testing workflow route to them. |
| Evidence archives and queues | [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Audit findings queue](Audit-Findings-Queue-2026-06-03), [Development lessons](Development-Lessons-Learned), [Subagent discovery swarm](Subagent-Discovery-Swarm), [Upstream mining ledger](Upstream-Mining-Ledger) | Keep as archive/support pages; expose compact owner routes first. |
| Claude/instruction pages | [Claude goal](Claude-Goal), [Claude long-term goal](Claude-Long-Term-Goal), [Claude loop goal](Claude-Loop-Goal), [Instructions for Codex](Instructions-For-Codex) | Keep discoverable through coordination pages; avoid primary human nav unless actively used. |
| Analysis/support pages | [Client UI and server loop perf findings](Client-UI-And-Server-Loop-Perf-Findings), [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [Performance gain simulation](Performance-Gain-Simulation), [Self-host testing field notes](Self-Host-Testing-Field-Notes) | Keep linked from the owning subsystem or archive index only. |
| Imported Miksuu archive pages | `Miksuu-Wiki-Archive-*` pages | Keep routed through [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) and [Community & Dev](Community-And-Dev), not individual sidebar rows. |
| Narrow branch/status pages | [Mission start parameters](Mission-Start-Parameters-Index), [Server init bind cleanup](Server-Init-Bind-Cleanup), [UI resource parity cleanup](UI-Resource-Parity-Cleanup) | Keep linked from source/status owner pages unless they become daily owner pages. |

## Remaining Support-Only Pages

Use this list as the closeout state for neither-nav cleanup. A page should leave this table only when it becomes a primary owner page, a current gateway, or stale enough to merge/archive.

| Status | Pages | Keep reachable through |
| --- | --- | --- |
| `patch-ready` | [Client skill init](Client-Skill-Init-Idempotency), [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Paratrooper marker revival](Paratrooper-Marker-Revival), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | [Feature status](Feature-Status-Register), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Hardening roadmap](Hardening-Implementation-Roadmap). |
| `archive` / `evidence-ledger` | [Deep-review findings](Deep-Review-Findings), [External research reports](External-Research-Reports), [Audit findings queue](Audit-Findings-Queue-2026-06-03), [Development lessons](Development-Lessons-Learned), [Subagent discovery swarm](Subagent-Discovery-Swarm) | [Agent worklog](Agent-Worklog), [Progress dashboard](Progress-Dashboard), [Feature status](Feature-Status-Register), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger). |
| `sidebar-visible archive` | [Agent worklog archive](Agent-Worklog-Archive) | Keep sidebar-visible as the long-form continuation of [Agent worklog](Agent-Worklog). |
| `agent-instruction` | [Claude goal](Claude-Goal), [Claude long-term goal](Claude-Long-Term-Goal), [Claude loop goal](Claude-Loop-Goal), [Instructions for Codex](Instructions-For-Codex) | [Coordination board](Coordination-Board), [Agent collaboration protocol](Agent-Collaboration-Protocol), [AI assistant developer guide](AI-Assistant-Developer-Guide). |
| `analysis-support` | [Client UI/server loop perf findings](Client-UI-And-Server-Loop-Perf-Findings), [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [Performance gain simulation](Performance-Gain-Simulation), [Self-host testing field notes](Self-Host-Testing-Field-Notes) | [Client UI systems atlas](Client-UI-Systems-Atlas), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Server ops runbook](Server-Ops-Runbook). |

## Continue Reading Gaps

Every content page has a `## Continue Reading` block as of the 2026-06-23 live-count refresh.

| Family | Pages missing block | Decision |
| --- | --- | --- |
| AI Commander B69 pages | Fixed: [AI commander B69 improvement roadmap](AI-Commander-B69-Improvement-Roadmap), [AI commander B69 implementation sketches](AI-Commander-B69-Implementation-Sketches) | Added owner-route blocks in this batch. |
| High-traffic owner pages | None | Previously missing owner-page blocks were normalized on 2026-06-05; live scan is clean again. |
| Archive/queue pages | None | Queue pages route back to owning indexes; imported archive pages keep an archive-chain caveat. |

## Maintenance Checklist

1. Add a page to exactly one obvious owner family before linking it broadly.
2. If the page is archive or machine material, link it from an index instead of the sidebar.
3. If a page becomes a primary owner page, add it to `_Sidebar.md`, Home or the relevant gateway page; add it to `mkdocs.yml` only after the repo mirror is current again.
4. Update [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) when demoting, merging or archiving pages.
5. Run `docs/validate-wiki.ps1` after link changes.

## Continue Reading

Previous: [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) | Next: [Knowledge platform roadmap](Knowledge-Platform-Roadmap)

Main map: [Home](Home) | Status: [Progress dashboard](Progress-Dashboard) | Agent file: [`agent-context.json`](agent-context.json)
