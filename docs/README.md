# A2 Wasp Warfare Docs

Canonical developer documentation lives in `docs/wiki` and is mirrored to the GitHub Wiki while the project transitions toward a repo-hosted docs site.

## Validate Locally

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File docs/validate-wiki.ps1
```

The validator checks:

- JSON files parse.
- JSONL files parse line by line.
- Local Markdown links point at existing wiki pages or machine files.
- No stale optimistic `source/Vanilla patched` style claims are present.

The same validator runs in GitHub Actions through `.github/workflows/docs.yml`.

## Preview With MkDocs

Install docs dependencies in your preferred Python environment:

```powershell
pip install -r docs/requirements-docs.txt
mkdocs serve
```

The MkDocs config is intentionally lightweight. `docs/wiki` remains the source tree, with GitHub Wiki compatibility links kept in the Markdown.

CI runs `mkdocs build --strict` after installing `docs/requirements-docs.txt`.

## Authoring Rules

- Keep short status rows in `Feature-Status-Register.md` and detailed evidence in subsystem pages.
- Update `llms.txt`, `LLM-Agent-Entry-Pack.md` and `agent-context.json` when adding major navigation pages.
- If a source fix has not been propagated through LoadoutManager, write `source fix; propagation pending`.
- Run `docs/validate-wiki.ps1` before committing docs changes.
