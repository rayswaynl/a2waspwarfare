# Knowledge Platform Roadmap

The recommended long-term home for the developer wiki, agent-context files and source-backed research notes.

## Recommendation

Make `docs/wiki` in the main repo the canonical source of truth, publish it as a GitHub Pages site with MkDocs Material, and keep the GitHub Wiki as a compatibility front door until the Pages site is stable. Stay docs-as-code (PR review, generated validation, machine-readable agent bundles) rather than moving to a hosted SaaS docs product or a personal knowledge-garden tool.

Rationale, in brief: the wiki is great as a public front door but weak as the long-term source of truth — its edits are not reviewed beside code, CI cannot enforce JSON/JSONL/link/drift checks on it, and agent bundles are easier to generate from a repo-owned tree. MkDocs Material fits because it is Markdown-first, static, searchable and easy to generate from the current page set (Docusaurus is heavier than needed; Quartz/Obsidian and Mintlify add graph-garden or vendor dependencies this repo does not need). References: [GitHub wiki docs](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis), [MkDocs deploy](https://www.mkdocs.org/user-guide/deploying-your-docs/), [Material search](https://squidfunk.github.io/mkdocs-material/plugins/search/), [llms.txt proposal](https://llmstxt.org/).

## Target Shape

| Surface | Role |
| --- | --- |
| `docs/wiki` | Canonical Markdown documentation reviewed beside mission/tooling code. |
| GitHub Pages + MkDocs Material | Human-readable docs site with fast navigation and search. |
| GitHub Wiki | Legacy URL, lightweight landing page and temporary mirror. |
| [`llms.txt`](llms.txt) / `llms-full.txt` | Curated LLM entrypoint + generated full-docs bundle for deep agent ingestion. |
| [LLM agent entry pack](LLM-Agent-Entry-Pack) | Human/agent bootstrap brief with load order, safety rules and task bundles. |
| `agent-context.json` | Compact machine-readable repo map and high-risk rules. |
| `agent-knowledge.jsonl` / `agent-hardening-backlog.jsonl` | Append-only evidence and backlog streams. |

## Agent-Readable Debt Found During Scout Waves

The 2026-06-04 agent-readable scout found the docs have the right long-term direction, but the active-state layer was too heavy for fast agent ingestion.

| Finding | Evidence | Action |
| --- | --- | --- |
| Agent development pack alias is fixed | [Agent development pack](Agent-Development-Pack) now exists as a lightweight compatibility alias. | Keep it as a gateway only; update [LLM agent entry pack](LLM-Agent-Entry-Pack) for real boot-order changes. |
| Active state history leak is mostly fixed | `agent-status.json`, `agent-collaboration.json` and `agent-context.json` carry compact live lane snapshots after the 2026-06-05 cleanup. | Keep completed lanes in `agent-events.jsonl`, [Agent worklog](Agent-Worklog) and git history. Future work is schema naming/validation, not another large live-state archive. |
| Machine records use mixed envelopes | Existing JSONL rows mix `ts`/`timestamp` and different actor/status/source fields. | [`agent-machine-index.json`](agent-machine-index.json) documents the vNext envelope; the validator emits compact legacy-drift warnings while tolerating old rows. Add normalized records going forward; do not rewrite history blindly. |
| Page-to-source lookup is scattered | No compact machine index from page/system to source proof refs. | [`agent-machine-index.json`](agent-machine-index.json) maps high-traffic systems to page ids, branch scope, source refs, machine refs, risk tier and next gate. Keep it small. |

## Migration Plan

1. Declare `docs/wiki` canonical in `README.md`, `Home.md`, `Agent-Context` and contributor docs.
2. Add `mkdocs.yml` with `docs_dir: docs/wiki` and a nav generated from the page map/sidebar.
3. Publish GitHub Pages from Actions.
4. Add validation checks: JSON parse, JSONL parse, internal wiki links, missing page references and optional wiki mirror parity (local validator: `docs/validate-wiki.ps1`).
5. Keep [`llms.txt`](llms.txt) and [LLM agent entry pack](LLM-Agent-Entry-Pack) current, then generate `llms-full.txt` from the curated page map once the MkDocs build exists.
6. After Pages is stable, reduce the GitHub Wiki to a small landing page linking to Pages, the repo docs and the machine-readable agent files.

## Authoring Rules

- Source-backed claims live in canonical pages with direct file references or deep-review IDs.
- [Feature status register](Feature-Status-Register) stays short and dashboard-like; evidence belongs in linked pages.
- Machine files must parse cleanly and must not carry stale optimistic statuses.
- When a source patch cannot be propagated because LoadoutManager cannot run, write `source patched; propagation pending`, not `source + Vanilla patched`.
- Run `docs/validate-wiki.ps1` after docs or machine-file edits.

## Continue Reading

Previous: [Documentation implementation plan](Documentation-Implementation-Plan) | Next: [Wiki quality audit](Wiki-Quality-Audit)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
