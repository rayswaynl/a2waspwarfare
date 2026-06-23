# Wiki Mirror Reconciliation Plan

The no-blind-copy policy for `docs/wiki` ↔ GitHub-wiki drift. The 2026-06-05 mirror checkout had **full file parity** with the GitHub wiki (`full-diffCount=0`), but parity is branch-sensitive: some active gameplay branches do not carry `docs/wiki` or `docs\validate-wiki.ps1`. In that case, use a standalone GitHub wiki checkout as the live docs surface and do not claim repo-mirror parity until a mirror-bearing checkout is inspected.

## Current Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Historical repo mirror validation | Pass on 2026-06-05 mirror checkout | `powershell -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1` passed in the repo-mirror checkout used for that batch. |
| Current active gameplay branch check | Mirror/validator absent on `feat/supply-helicopter` local checkout, 2026-06-23 | `Test-Path docs\wiki` and `Test-Path docs\validate-wiki.ps1` returned `False` in `C:\Users\Steff\a2waspwarfare`; this is a branch/worktree availability finding, not evidence that the mirror was deleted from all branches. |
| Repo mirror / wiki parity | Historical pass only until a mirror checkout is inspected | 2026-06-05 full-file SHA256 parity over every top-level file reported `full-diffCount=0`. Scoped sync should still compare touched files first per batch when a mirror checkout is present. |

## Reconciliation Policy

| Class | Policy |
| --- | --- |
| Current-state and machine coordination files | Prefer the repo mirror when it has the latest source-status correction, active-claim shaping, validation results and append-only event/worklog context. |
| Navigation files | Reconcile deliberately so `_Sidebar.md`, `_Footer.md`, `Home.md` and `agent-context.json` agree on entrypoints without duplicate links or stale parity claims. |
| Wiki-only atlas/audit pages | Source-review before importing; merge useful source-backed details into canonical pages when overlap is high. |
| Shared content mismatches | Decide owner file by file; prioritize current-status pages, machine files and navigation over long-form subsystem content. |
| Generated / release-readiness state | Preserve evidence-only wording until source Chernarus, generated Vanilla and Arma 2 OA smoke proof exist. |

## If Drift Returns

1. First confirm whether the active checkout has `docs/wiki` and `docs\validate-wiki.ps1`; if not, use a standalone wiki checkout and mark repo-mirror parity as not checked for that batch.
2. Keep repo and wiki-checkout validation green before any sync when both surfaces exist.
3. Reconcile navigation and agent-entry pages first (they shape every future agent's reading path), then machine/release files, then long-form atlases.
4. Decide source-of-truth **file by file**; never blind-copy either direction (both sides can hold useful but divergent state).
5. Merge useful wiki-rich pages into canonical repo pages when source-backed; retire only after the overlap is explained.
6. For each imported/retired page, update `agent-context.json`, `_Sidebar.md`, `Home.md`, `_Footer.md`, [Coordination board](Coordination-Board), `agent-status.json`, `agent-collaboration.json`, [Agent worklog](Agent-Worklog) and `agent-events.jsonl` as needed.
7. Re-run parity after every deliberate batch when a mirror checkout is present. A failing or unavailable parity check is acceptable only while a specific drift/mirror-availability lane is open; unexplained parity claims are not.

> Historical note: a 2026-06-05 drift check against the now-retired alternate checkout `C:\Users\Steff\_wasp_wiki_claude` found broad divergence (93 mirror files vs 109 checkout files; 90 hash mismatches; 18 wiki-only extras across content-atlas/machine/current-state/navigation buckets). That checkout no longer exists and current parity is `full-diffCount=0`; the inventory was removed as resolved. Recover it from git history if that specific checkout is ever reconciled.

## Validation Commands

```powershell
Set-Location '<repo-root>'
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1
git diff --check
```

When JSON/JSONL machine files change, parse them before committing. If `docs\validate-wiki.ps1` is unavailable in the active checkout, record that and run the fallback checks: JSON/JSONL parse, internal-link/page-existence check over the wiki checkout, conflict-marker scan and `git diff --check`. After copying changed `docs\wiki\<page>` files into the wiki checkout, compare SHA256 hashes for every mirrored page in the batch.

## Guardrails

| Guardrail | Reason |
| --- | --- |
| Use Arma 2 Operation Arrowhead 1.64 references only. | Arma 3 conveniences produce invalid/misleading SQF guidance for this mission. |
| Do not import Arma 3 scripts or examples. | The wiki is for `rayswaynl/a2waspwarfare`, not an Arma 3 port. |
| Do not edit gameplay source in this lane. | This is a documentation parity lane; source cleanup needs a separate code-owner claim and smoke plan. |
| Do not blind-copy repo mirror ↔ wiki checkout. | Both sides can hold useful but divergent state; choose file ownership deliberately. |

## Continue Reading

Previous: [Bottleneck removal queue](Bottleneck-Removal-Queue) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Current source status](Current-Source-Status-Snapshot) | Agent file: [`agent-status.json`](agent-status.json)
