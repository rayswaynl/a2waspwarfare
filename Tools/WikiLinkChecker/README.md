# WASP wiki link checker

`check_wiki_links.py` is an offline hygiene checker for a local
`a2waspwarfare.wiki` clone. It uses only the Python standard library and does
not touch the network.

## Usage

```powershell
python Tools\WikiLinkChecker\check_wiki_links.py ..\wiki
python Tools\WikiLinkChecker\check_wiki_links.py ..\wiki --no-orphans
python Tools\WikiLinkChecker\check_wiki_links.py ..\wiki --include-stale-builds --current-build 86
python Tools\WikiLinkChecker\check_wiki_links.py ..\wiki --exit-zero
python Tools\WikiLinkChecker\check_wiki_links.py ..\wiki --json
python Tools\WikiLinkChecker\test_check_wiki_links.py
```

By default the tool exits non-zero for broken intra-wiki links and missing
anchors. Orphan pages and stale build references are report-only unless their
codes are passed to `--fail-on`.

Use `--exit-zero` for report-only CI or dashboard jobs that should print
findings without failing the run.

## Checks

- `DEADLINK`: a Markdown or `[[wiki]]` link points at a page that is not present
  in the local wiki checkout.
- `BADANCHOR`: the page exists, but the linked heading anchor does not.
- `ORPHAN`: a page has no incoming wiki links. `_Sidebar.md`, `_Footer.md`, and
  `Home.md` are exempt.
- `STALEBUILD`: optional scan for older `Build NN`, `buildNN`, or `BNN`
  mentions relative to `--current-build`.

External URLs are intentionally ignored. The checker is meant to feed wiki
cleanup lanes with local, repeatable findings rather than replace live URL
monitoring.

## Output

Text output uses:

```text
path:line: CODE: target: message
```

The final summary includes page and finding counts. Use `--json` when another
tool needs structured output.
