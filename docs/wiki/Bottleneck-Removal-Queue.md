# Bottleneck Removal Queue

Former lane: `bottleneck-reducer-progress-accelerator` (**closed / historical**).

This page is now a supporting checklist for recurring documentation/process drag. It is **not** the live open-task queue and does not claim active ownership. Use [Progress dashboard](Progress-Dashboard), [Coordination board](Coordination-Board), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger), [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions) and [`agent-status.json`](agent-status.json) as the current route.

Use this page when a broad docs/process problem reappears: stale patched wording, mirror drift, validation gaps, harvested-report residue, or release-readiness overclaims. If nothing here contradicts the current route, do not reopen the old bottleneck lane.

## Current Truth

| Fact | Use |
| --- | --- |
| The disputed cleanup lanes are not source-patched as of the current source snapshot. | Before any "patched", "propagated" or "smoke pending" claim, re-open [Current source status](Current-Source-Status-Snapshot). |
| Append-only event/worklog history contains superseded false patched pulses. | Treat older shipped-status lines as historical unless a newer direct source check with file/line evidence supersedes the snapshot. |
| `agent-release-readiness.json` now exists as an evidence-only gate index. | Do not treat it as a release-ready claim; it records blockers and validation gates that must close first. |
| `docs/wiki` and the active wiki checkout are currently managed by scoped parity checks. | Keep [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan) as the no-blind-copy policy for future drift or alternate-checkout reconciliation; latest scoped batches report `full-diffCount=0`. |
| Review coverage is mostly done; remaining risk is owner action and validation evidence. | Send code owners to [Pending owner decisions](Pending-Owner-Decisions), not more broad review prose. |
| The old `bottleneck-reducer-progress-accelerator` lane is historical. | Future agents should open a fresh lane if a new bottleneck appears, instead of treating this page header as an active claim. |

## P0 Bottlenecks

| Bottleneck | Evidence | Owner | Next action |
| --- | --- | --- | --- |
| Stale patched/propagated claims can still mislead agents. | `agent-events.jsonl`, `agent-knowledge.jsonl` and [Agent worklog](Agent-Worklog) retain superseded false patched history by design. | Any agent starting source/code work. | Read [Current source status](Current-Source-Status-Snapshot) first; only write new patched wording after source Chernarus, generated Vanilla and Arma 2 OA smoke evidence exist. |
| Release-readiness state was missing from the mirror. | `agent-release-readiness.json` did not exist before the original queue pass, despite being named in the mission brief. | Bottleneck reducer / release owner. | Keep [`agent-release-readiness.json`](agent-release-readiness.json) evidence-only until source patches, validation and OA smoke gates are recorded. |
| Wiki checkout and repo mirror parity can drift when agents publish directly to the wiki. | This page was referenced by Home/sidebar/agent records but missing from the current wiki checkout until the 2026-06-03 mirror reconciliation pass; later batches now record `full-diffCount=0` parity evidence in `agent-events.jsonl`. | Documentation finisher / docs owner. | Continue scoped syncs only. If drift appears, follow [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan); choose source-of-truth file by file and re-run validation before publishing. |
| Validation gates are present and now documented as a shared docs habit. | `docs/validate-wiki.ps1`, touched JSON/JSONL parse, `git diff --check`, wiki-checkout checks and full SHA parity are now repeated in recent docs batches. | Future docs agent. | Keep running the same gates before handoff; do not treat them as release/gameplay smoke. |

## P1 Bottlenecks

| Bottleneck | Evidence | Owner | Next action |
| --- | --- | --- | --- |
| Active-claim surfaces split live ownership from history. | `agent-collaboration.json.activeClaims` is the current lock surface; older lane objects may remain under archived/historical records. | Coordination maintainer. | Keep [Coordination board](Coordination-Board), `agent-status.json` and `agent-collaboration.json` aligned whenever a lane reactivates or signs off. |
| Codex-lane cross-link residue has been reconciled. | [Instructions for Codex](Instructions-For-Codex) and [Wiki quality audit](Wiki-Quality-Audit) record the closed cross-link items. | Docs agent. | Closed for docs; send future work to source-owner cleanup lanes instead of adding more duplicate DR prose. |
| Owner decisions are ready but not owned. | [Pending owner decisions](Pending-Owner-Decisions) separates authority, correctness and maintenance decisions. | Steff/code owner. | Pick one high-risk owner decision and open a code lane with source patch plus validation gates. |
| Current-source cleanup lanes are patch-ready, not documentation tasks. | [Feature status](Feature-Status-Register) lists commander, factory, paratrooper, skill init, hosted FPS, supply scan and WASP marker wait states. | Future gameplay code owner. | Patch source Chernarus first, propagate generated Vanilla, then record Arma 2 OA hosted/dedicated/JIP smoke where relevant. |

## P2 Bottlenecks

| Bottleneck | Evidence | Owner | Next action |
| --- | --- | --- | --- |
| Thin citation pages are raised to the first-read anchor standard. | [Wiki quality audit](Wiki-Quality-Audit) thin-citation row and [Instructions for Codex](Instructions-For-Codex) item 15 are resolved. | Docs agent. | Closed; keep future first-read pages on the same compact `path:line` anchor pattern. |
| Modded mission policy is unresolved. | [Content structure](Content-Structure-And-Maps) and [Deep-review findings](Deep-Review-Findings) DR-32 describe divergent forks/stubs. | Steff/code owner. | Decide regenerate, maintain-as-forks or delete stubs before propagating source fixes to modded missions. |
| Runtime smoke evidence is still missing for many patch-ready findings. | [Testing workflow](Testing-Debugging-And-Release-Workflow) defines smoke levels, but current docs mostly contain source review. | Code/test owner. | Attach RPT/log evidence to the relevant playbook before promoting release-ready wording. |

## Next 5 Best Actions

1. Choose one source cleanup lane from [Feature status](Feature-Status-Register) and implement it as a code-owner lane, not a docs lane.
2. Run `docs\validate-wiki.ps1` in the repo mirror before handoff and keep JSON/JSONL/link failures at zero.
3. Keep `docs/wiki` and the active wiki checkout in parity with scoped syncs, then re-run parity checks.
4. Pick one high-risk item from [Pending owner decisions](Pending-Owner-Decisions) and open a source patch lane with OA smoke expectations named up front.
5. If future parity drift appears, follow [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan) and choose source-of-truth file by file before syncing.

## Harvest Queue

| Returned report / lane | Finding | Target page | Priority | Next action |
| --- | --- | --- | --- | --- |
| Scout validation residue | Reports are harvested; repo validation, wiki-checkout validation and mirror/wiki parity should stay as separate gates. | [Subagent discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan), `agent-status.json` | Closed | Do not reopen old scout harvest unless new scout outputs appear. |
| Claude string/selection trap pass | `selectRandom` command is Arma 3-only, while `BIS_fnc_selectRandom` is OA-safe; `splitString`, `joinString` and `trim` remain unsafe without OA proof. | [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), `agent-compatibility-audit.json` | Closed | Machine audit and human audit already include the trap; no further docs action. |
| DR-44 direct side-supply forgery | Direct `wfbe_supply_temp_<side>` channels are integrated into the economy/networking docs. | [Economy](Economy-Towns-And-Supply), [Networking](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Feature status](Feature-Status-Register) | Closed | Keep detailed proof in [Deep-review findings](Deep-Review-Findings); do not duplicate it here. |
| DR-20 HQ-killed N-fold score exploit | DR-20 is visible from construction/gameplay/runtime pages, with detailed proof kept in [Deep-review findings](Deep-Review-Findings). | [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay atlas](Gameplay-Systems-Atlas), [Server runtime](Server-Gameplay-Runtime-Atlas) | Closed | No further harvest action; source idempotency remains a future code-owner lane. |

## Validation Gates To Keep

| Gate | Command |
| --- | --- |
| Repo wiki validation | `docs\validate-wiki.ps1` |
| Full machine parse isolation | Covered by `Tools\ValidateWiki.ps1`; every `*.json`, non-empty `*.jsonl` line and wiki file must parse cleanly without control characters. |
| Git whitespace/path check | `git diff --check` |
| Wiki checkout parity after sync | Compare changed files between `docs/wiki` and the wiki checkout. |
| Wiki checkout validation after sync | Run the same link/JSON checks against the wiki checkout where tooling supports it. |

## Latest Validation

| Check | Result | Notes |
| --- | --- | --- |
| Repo mirror validation | Pass | Recent 2026-06-05 docs batches run `docs/validate-wiki.ps1`; known legacy JSONL envelope warnings are non-failing. |
| Repo whitespace check | Pass | `git diff --check` is part of the docs handoff ritual; Windows LF-to-CRLF warnings are normal. |
| Wiki checkout JSON/diff check | Pass | Recent scoped publishes parse touched JSON/JSONL in the wiki checkout and run `git diff --check`. |
| Mirror/wiki parity | Pass | Full repo-mirror/wiki checkout SHA checks report `full-diffCount=0` after scoped syncs. Keep re-running after every publish. |

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan)

Main map: [Home](Home) | Fast path: [Current source status](Current-Source-Status-Snapshot) | Agent file: [`agent-status.json`](agent-status.json)
