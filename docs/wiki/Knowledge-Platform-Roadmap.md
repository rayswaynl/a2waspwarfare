# Knowledge Platform Roadmap

This page records the recommended long-term home for the developer wiki, agent context files and source-backed research notes.

## Recommendation

Make `docs/wiki` in the main repo the canonical source of truth, publish it as a GitHub Pages site with MkDocs Material, and keep the GitHub Wiki as a compatibility front door until the Pages site is stable.

Do not move the canonical documentation to a SaaS docs platform or a separate knowledge garden yet. The project needs docs-as-code, PR review, generated validation and machine-readable agent bundles more than it needs a heavier publishing product.

## Target Shape

| Surface | Role |
| --- | --- |
| `docs/wiki` | Canonical Markdown documentation reviewed beside mission/tooling code. |
| GitHub Pages + MkDocs Material | Human-readable docs site with fast navigation and search. |
| GitHub Wiki | Legacy URL, lightweight landing page and temporary mirror. |
| [`llms.txt`](llms.txt) | Curated LLM entrypoint with the highest-signal pages and machine files. |
| [LLM agent entry pack](LLM-Agent-Entry-Pack) | Human/agent-readable bootstrap brief with load order, safety rules and task bundles. |
| `llms-full.txt` | Generated full-docs bundle for deep agent ingestion. |
| `agent-context.json` | Compact machine-readable repo map and high-risk rules. |
| `agent-knowledge.jsonl` / `agent-hardening-backlog.jsonl` | Append-only evidence and backlog streams for Codex, Claude and future agents. |

## Why Not Keep GitHub Wiki Canonical

The wiki is useful because it is public, familiar and easy to click through from GitHub. It is weaker as the long-term source of truth because:

- Wiki edits are not reviewed beside code changes.
- Navigation and search are limited for a large engineering handbook.
- CI cannot easily enforce JSON/JSONL validity, internal links, generated drift and source-reference checks.
- Agent-readable bundles are easier to generate from a repo-owned docs tree.

Keep the wiki reachable, but make it a mirror or launch pad rather than the canonical editing surface.

## Why MkDocs Material First

MkDocs Material fits this project because it is Markdown-first, lightweight, static, searchable and easy to generate from the current page set. Docusaurus is strong but heavier than needed unless the mission docs become a versioned product site with React components. Quartz/Obsidian is excellent for personal graph navigation, but this repo needs source-backed engineering docs more than a knowledge garden. Mintlify has good `llms.txt` support, but adds a hosted/vendor dependency that is not needed for an open Arma mission repo.

## External References

- GitHub notes that wikis have limited search-engine indexing rules and a 5,000-file soft limit, and recommends GitHub Pages for larger/indexed docs: [GitHub wiki docs](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis).
- MkDocs documents GitHub Pages publishing for project docs: [MkDocs deploy docs](https://www.mkdocs.org/user-guide/deploying-your-docs/).
- Material for MkDocs includes a built-in search plugin that builds an index from generated pages and sections: [Material search plugin](https://squidfunk.github.io/mkdocs-material/plugins/search/).
- Docusaurus has strong docs-site support, but official search is centered on Algolia DocSearch with other options maintained by the community: [Docusaurus search](https://docusaurus.io/docs/search).
- `llms.txt` is a proposal for a Markdown file that helps LLMs use a website at inference time: [llms.txt proposal](https://llmstxt.org/).

## Migration Plan

1. Declare `docs/wiki` canonical in `README.md`, `Home.md`, `Agent-Context` and future contributor docs.
2. Add `mkdocs.yml` with `docs_dir: docs/wiki` and a nav generated from the existing page map/sidebar.
3. Publish GitHub Pages from Actions.
4. Add validation checks: JSON parse, JSONL parse, internal wiki links, missing page references and optional wiki mirror parity. Local validator: `docs/validate-wiki.ps1`.
5. Keep [`llms.txt`](llms.txt) and [LLM agent entry pack](LLM-Agent-Entry-Pack) current, then generate `llms-full.txt` from the curated page map once the MkDocs build exists.
6. After Pages is stable, reduce the GitHub Wiki to a small landing page linking to Pages, the repo docs and the machine-readable agent files.

## Authoring Rules

- Source-backed claims live in canonical pages with direct file references or deep-review IDs.
- The [Feature status register](Feature-Status-Register) stays short and dashboard-like; evidence belongs in linked pages.
- Machine files must parse cleanly and should not carry stale optimistic statuses.
- When a source patch cannot be propagated because LoadoutManager cannot run, write `source patched; propagation pending`, not `source + Vanilla patched`.
- Run `docs/validate-wiki.ps1` after docs or machine-file edits.

## Continue Reading

Previous: [Documentation implementation plan](Documentation-Implementation-Plan) | Next: [Wiki quality audit](Wiki-Quality-Audit)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
