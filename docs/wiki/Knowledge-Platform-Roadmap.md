# Knowledge Platform Roadmap

This page owns documentation-platform decisions, not mission behavior. Use it when the question is where the wiki should live, how the mirror should be validated, or how future agent-readable bundles should be produced.

## Current State

| Surface | Status | Notes |
| --- | --- | --- |
| GitHub wiki | Primary reader-facing target | The wiki is mirrored into `docs/wiki` for review, diffs and agent loading. |
| `docs/wiki` mirror | Active edit surface | Every Markdown wiki page should have a matching mirror file before handoff or publish. |
| Machine context | Active | `agent-context.json`, `agent-status.json`, `agent-collaboration.json`, `agent-events.jsonl`, `agent-knowledge.jsonl` and `agent-hardening-backlog.jsonl` preserve agent-readable state. |
| Validation | Active | `Tools/ValidateWiki.ps1` checks full JSON/JSONL parsing, page-list parity, Markdown/`.txt` links, machine references, retired-route hygiene, stale current-state patched wording, Arma 2 OA compatibility guardrails and `git diff --check`. `Tools/TestWikiParity.ps1` checks `docs/wiki` to GitHub wiki checkout parity after sync. |
| GitHub Pages / MkDocs / docs CI | Not established in this mirror | `docs/validate-wiki.ps1` exists as a thin wrapper around `Tools/ValidateWiki.ps1`, but no current `mkdocs.yml`, docs requirements file, Docusaurus config, Pages workflow or rendered build artifact is present. Treat static-site and docs-CI work as a future platform lane, not as the current publishing path. |

## Roadmap

| Step | Owner | Gate |
| --- | --- | --- |
| Keep wiki mirror parity | Codex / Claude / future agents | `Tools/ValidateWiki.ps1` passes after docs or machine-context edits, then `Tools/TestWikiParity.ps1` passes after mirror sync. |
| Decide static-site path | Docs/platform owner | Choose GitHub wiki only, GitHub Pages/MkDocs, or another rendered docs surface; add config only after owner approval. |
| Build an LLM bundle | Future docs tooling owner | Generate from validated `docs/wiki` plus machine JSON/JSONL files; exclude raw external reports and secrets. |
| Publish bundle metadata | Future docs tooling owner | Record source commit, generation time, included files and validation result. |

## Guardrails

- Do not treat GitHub Pages, MkDocs or an LLM bundle as shipped until a config/build artifact exists and validation covers it.
- Keep raw research reports as leads only; publish summarized, source-checked facts into the wiki instead of bundling raw report bodies.
- Keep `agent-context.json` page arrays in parity with actual `docs/wiki/*.md` files whenever new pages are added.

## Continue Reading

Previous: [Tools and build workflow](Tools-And-Build-Workflow) | Next: [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide)

Main map: [Home](Home) | Validation: [Testing workflow](Testing-Debugging-And-Release-Workflow) | Agent file: [`agent-context.json`](agent-context.json)
