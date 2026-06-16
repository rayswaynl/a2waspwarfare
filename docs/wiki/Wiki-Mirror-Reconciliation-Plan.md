# Wiki Mirror Reconciliation Plan

The no-blind-copy policy for `docs/wiki` ↔ GitHub-wiki drift. The active wiki checkout is in **full file parity** with the `docs/wiki/` repo mirror as of 2026-06-05 (`full-diffCount=0`). Use this page only if drift returns.

## Current Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Repo mirror validation | Pass | `powershell -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1` passes in the repo-mirror checkout. |
| Active wiki checkout validation | Pass | Same `docs\validate-wiki.ps1` run from the repo mirror. |
| Repo mirror / wiki parity | Pass | 2026-06-05 full-file SHA256 parity over every top-level file reports `full-diffCount=0`. Scoped sync still compares touched files first per batch. |

## Reconciliation Policy

| Class | Policy |
| --- | --- |
| Current-state and machine coordination files | Prefer the repo mirror when it has the latest source-status correction, active-claim shaping, validation results and append-only event/worklog context. |
| Navigation files | Reconcile deliberately so `_Sidebar.md`, `_Footer.md`, `Home.md` and `agent-context.json` agree on entrypoints without duplicate links or stale parity claims. |
| Wiki-only atlas/audit pages | Source-review before importing; merge useful source-backed details into canonical pages when overlap is high. |
| Shared content mismatches | Decide owner file by file; prioritize current-status pages, machine files and navigation over long-form subsystem content. |
| Generated / release-readiness state | Preserve evidence-only wording until source Chernarus, generated Vanilla and Arma 2 OA smoke proof exist. |

## If Drift Returns

1. Keep repo and wiki-checkout validation green before any sync.
2. Reconcile navigation and agent-entry pages first (they shape every future agent's reading path), then machine/release files, then long-form atlases.
3. Decide source-of-truth **file by file**; never blind-copy either direction (both sides can hold useful but divergent state).
4. Merge useful wiki-rich pages into canonical repo pages when source-backed; retire only after the overlap is explained.
5. For each imported/retired page, update `agent-context.json`, `_Sidebar.md`, `Home.md`, `_Footer.md`, [Coordination board](Coordination-Board), `agent-status.json`, `agent-collaboration.json`, [Agent worklog](Agent-Worklog) and `agent-events.jsonl` as needed.
6. Re-run parity after every deliberate batch. A failing parity check is acceptable only while a specific drift lane is open; unexplained parity claims are not.

> Historical note: a 2026-06-05 drift check against the now-retired alternate checkout `C:\Users\Steff\_wasp_wiki_claude` found broad divergence (93 mirror files vs 109 checkout files; 90 hash mismatches; 18 wiki-only extras across content-atlas/machine/current-state/navigation buckets). That checkout no longer exists and current parity is `full-diffCount=0`; the inventory was removed as resolved. Recover it from git history if that specific checkout is ever reconciled.

## Validation Commands

```powershell
Set-Location '<repo-root>'
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1
git diff --check
```

When JSON/JSONL machine files change, parse them before committing. After copying changed `docs\wiki\<page>` files into the wiki checkout, compare SHA256 hashes for every mirrored page in the batch.

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
