# Bottleneck Removal Queue

Lane claimed: `bottleneck-reducer-progress-accelerator`.

This page is the compact queue for removing documentation/process drag. It does not replace [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), [Codebase coverage ledger](Codebase-Coverage-Ledger), [Wiki quality audit](Wiki-Quality-Audit) or [Current source status](Current-Source-Status-Snapshot); it points at the next action when those pages disagree or get too large.

## Current Truth

| Fact | Use |
| --- | --- |
| The disputed cleanup lanes are not source-patched as of the current source snapshot. | Before any "patched", "propagated" or "smoke pending" claim, re-open [Current source status](Current-Source-Status-Snapshot). |
| Append-only event/worklog history contains superseded false patched pulses. | Treat older `source/Vanilla patched` lines as historical unless a newer direct source check with file/line evidence supersedes the snapshot. |
| `agent-release-readiness.json` now exists as an evidence-only gate index. | Do not treat it as a release-ready claim; it records blockers and validation gates that must close first. |
| `docs/wiki` and the active `_wasp_wiki_tmp` checkout are currently in parity. | Keep [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan) as the no-blind-copy policy for future drift or alternate-checkout reconciliation. |
| Review coverage is mostly done; remaining risk is owner action and validation evidence. | Send code owners to [Pending owner decisions](Pending-Owner-Decisions), not more broad review prose. |

## P0 Bottlenecks

| Bottleneck | Evidence | Owner | Next action |
| --- | --- | --- | --- |
| Stale patched/propagated claims can still mislead agents. | `agent-events.jsonl`, `agent-knowledge.jsonl` and [Agent worklog](Agent-Worklog) retain superseded false patched history by design. | Any agent starting source/code work. | Read [Current source status](Current-Source-Status-Snapshot) first; only write new patched wording after source Chernarus, generated Vanilla and Arma 2 OA smoke evidence exist. |
| Release-readiness state was missing from the mirror. | `agent-release-readiness.json` did not exist before this pass, despite being named in the mission brief. | Bottleneck reducer / release owner. | Keep [`agent-release-readiness.json`](agent-release-readiness.json) evidence-only until source patches, validation and OA smoke gates are recorded. |
| Wiki checkout and repo mirror parity is restored for the active checkout. | Latest `_wasp_wiki_tmp` parity check passed across 93 files after scoped sync. Older `_wasp_wiki_claude` divergence is retained only as historical/alternate-checkout inventory. | Bottleneck reducer / docs owner. | Closed for active checkout; keep the reconciliation plan for future drift and avoid blind copy-over. |
| Validation gates are present but not yet a shared release habit. | `Tools/ValidateWiki.ps1`, `docs/validate-wiki.ps1` and `Tools\TestWikiParity.ps1` exist, but parity can fail while mirror/wiki diverge. | Future docs agent. | Run docs validation before handoff; after any intended mirror sync, run parity and wiki-checkout validation. |

## P1 Bottlenecks

| Bottleneck | Evidence | Owner | Next action |
| --- | --- | --- | --- |
| Active-claim surfaces now split live ownership from history. | `agent-collaboration.json.activeClaims` keeps the live bottleneck lane plus Codex-2 `oa-object-lifecycle-command-addendum`; Codex-2's earlier command addenda plus historical lane objects remain under `archivedClaims`. | Coordination maintainer. | Keep [Coordination board](Coordination-Board), `agent-status.json` and `agent-collaboration.json` aligned whenever a lane reactivates or signs off. |
| Codex-lane cross-link residue has been reconciled. | [Instructions for Codex](Instructions-For-Codex) items 5 and 8 are done; [Wiki quality audit](Wiki-Quality-Audit) C2/R2-5 are resolved. | Docs agent. | Closed for docs; send future work to source-owner cleanup lanes instead of adding more DR-20/C2 prose. |
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
3. Keep `docs/wiki` and `_wasp_wiki_tmp` in parity with scoped syncs, then re-run `Tools\TestWikiParity.ps1`.
4. Pick one high-risk item from [Pending owner decisions](Pending-Owner-Decisions) and open a source patch lane with OA smoke expectations named up front.
5. If future parity drift appears, follow [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan) and choose source-of-truth file by file before syncing.

## Harvest Queue

| Returned report / lane | Finding | Target page | Priority | Next action |
| --- | --- | --- | --- | --- |
| `scout-wave-k` / `scout-wave-j` validation residue | Reports are harvested; repo validation, wiki-checkout validation and mirror/wiki parity pass against `C:\Users\Steff\_wasp_wiki_tmp`. | [Subagent discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan), `agent-status.json`, `Tools\TestWikiParity.ps1` | Closed | No further scout-harvest action; keep future mirror drift as a separate parity-maintenance task. |
| Claude string/selection trap pass | `selectRandom` command is Arma 3-only, while `BIS_fnc_selectRandom` is OA-safe; `splitString`, `joinString` and `trim` remain unsafe without OA proof. | [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), `agent-compatibility-audit.json` | Closed | Machine audit and human audit already include the trap; no further docs action. |
| DR-44 direct side-supply forgery | Direct `wfbe_supply_temp_<side>` channels were integrated after this queue was claimed. | [Economy](Economy-Towns-And-Supply), [Networking](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server runtime](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register) | Closed | Keep detailed proof in [Deep-review findings](Deep-Review-Findings); do not duplicate it here. |
| DR-20 HQ-killed N-fold score exploit | DR-20 is now visible from construction/gameplay/runtime pages, with detailed proof kept in [Deep-review findings](Deep-Review-Findings). | [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay atlas](Gameplay-Systems-Atlas), [Server runtime](Server-Gameplay-Runtime-Atlas) | Closed | No further harvest action; source idempotency remains a future code-owner lane. |

## Validation Gates To Keep

| Gate | Command |
| --- | --- |
| Repo wiki validation | `docs\validate-wiki.ps1` |
| Full machine parse isolation | Covered by `Tools\ValidateWiki.ps1`; every `*.json`, non-empty `*.jsonl` line and wiki file must parse cleanly without control characters. |
| Git whitespace/path check | `git diff --check` |
| Wiki checkout parity after sync | `Tools\TestWikiParity.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp` |
| Wiki checkout validation after sync | `Tools\ValidateWiki.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp -SkipGitDiffCheck` |

## Latest Validation

| Check | Result | Notes |
| --- | --- | --- |
| Repo mirror validation | Pass | 2026-06-02T21:59+02:00: `docs\validate-wiki.ps1` passed, including 7 JSON files, 4 JSONL files, 555 JSONL entries, links, exact machine refs, stale patched wording scan, OA guardrail scan and `git diff --check`. |
| Repo whitespace check | Pass | `git diff --check` passed; only normal Windows LF-to-CRLF warnings were reported. |
| Wiki checkout validation | Pass | `Tools\ValidateWiki.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp -SkipGitDiffCheck` passed with the same parse, link, machine-reference, stale-wording and OA guardrail checks. |
| Mirror/wiki parity | Pass | `Tools\TestWikiParity.ps1 -WikiPath C:\Users\Steff\_wasp_wiki_tmp` passed across 93 files after the latest scoped sync. |

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Current source status](Current-Source-Status-Snapshot) | Agent file: [`agent-status.json`](agent-status.json)
