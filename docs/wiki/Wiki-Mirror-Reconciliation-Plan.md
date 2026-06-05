# Wiki Mirror Reconciliation Plan

This page records the no-blind-copy policy for mirror/wiki drift. The active wiki checkout is currently in full file parity with the `docs/wiki/` repo mirror as of 2026-06-05; the `_wasp_wiki_claude` inventory below is retained as historical/alternate-checkout evidence and as the process to use if drift returns.

## Current Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Repo mirror validation | Pass | `powershell -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1` passes in `C:\Users\Steff\a2waspwarfare-docs`. |
| Active wiki checkout validation | Pass | Current checkout uses `powershell -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1` from the repo mirror; the old `Tools\ValidateWiki.ps1` helper is not present in this tree. |
| Active repo mirror/wiki checkout parity | Pass | 2026-06-05 full-file SHA256 parity check over every top-level file in `docs/wiki/` and the active `a2waspwarfare.wiki` checkout reports `full-diffCount=0`. Scoped sync still compares touched files first during each batch. The old `Tools\TestWikiParity.ps1` helper is not present in this tree. |
| Older alternate checkout inventory | Historical drift | `C:\Users\Steff\_wasp_wiki_claude` previously reported broad divergence. Use the inventory below only if reconciling that alternate checkout. |

## Historical Alternate-Checkout Inventory

| Measure | Count |
| --- | ---: |
| Repo mirror files | 93 |
| Wiki checkout files | 109 |
| Exact matches | 1 |
| Missing from wiki checkout | 2 |
| Extra in wiki checkout | 18 |
| Shared files with hash mismatch | 90 |

## Missing From Wiki Checkout

| File | Initial disposition |
| --- | --- |
| External-Arma-2-OA-Reference-Index.md | Scoped-sync candidate from repo mirror after confirming it still matches the official Arma 2 OA reference posture. |
| Wiki-Mirror-Reconciliation-Plan.md | Expected missing-in-wiki while this plan is newly published in the repo mirror; sync only after the no-blind-copy policy is accepted. |

## Extra In Wiki Checkout

These pages existed in `C:\Users\Steff\_wasp_wiki_claude` but not in the repo mirror during the historical drift check. Do not delete or import them blindly; review each page for current source evidence, overlap with existing canonical pages and stale current-state claims.

| File | Initial disposition |
| --- | --- |
| `agent-entrypoint.json` | Machine-file review before import. |
| `Agent-Release-Readiness-Ledger.md` | Compare with `agent-release-readiness.json` and current release gates. |
| `AI-Commander-Autonomy-Audit.md` | Source-review before deciding import, merge or retire. |
| `AntiStack-Database-Extension-Audit.md` | Compare with External integrations and DR-7/DR-10/DR-29 coverage. |
| `Commander-HQ-Lifecycle-Atlas.md` | Compare with Construction, Gameplay and Server runtime atlases. |
| `Gear-Template-Profile-Filter.md` | Compare with Gear/loadout/EASA atlas. |
| `Integration-Trust-Boundary-Audit.md` | Compare with External integrations and hardening roadmap. |
| `Marker-Cleanup-Restoration-Systems-Atlas.md` | Compare with AI/headless marker/cleaner/restorer notes. |
| `Mission-Parameters-Localization-And-Generated-Build-Inputs.md` | Compare with Content structure, Tools/build and DR-35/DR-43 notes. |
| `Player-Join-Disconnect-And-AntiStack-Lifecycle.md` | Compare with Lifecycle wait-chain and AntiStack integration coverage. |
| `Respawn-And-Death-Lifecycle-Atlas.md` | Compare with gameplay/lifecycle/respawn coverage before import. |
| `Service-Menu-Affordability-Guards.md` | Compare with economy/service authority pages. |
| `Source-Fix-Propagation-Queue.md` | Compare with Current source status and Bottleneck queue. |
| `Support-Specials-And-Tactical-Modules-Atlas.md` | Compare with Modules, ICBM and support systems coverage. |
| `Towns-Camps-And-Capture-Atlas.md` | Compare with Gameplay systems atlas. |
| `Upgrades-And-Research-Atlas.md` | Compare with Economy, upgrades and hardening pages. |
| `Vehicle-Cargo-Equip-Loop-Bounds.md` | Compare with performance and gear/service docs. |
| `Victory-And-Endgame-Atlas.md` | Compare with Deep-review DR-11/DR-36 and Server runtime routing. |

## Reconciliation Policy

| Class | Policy |
| --- | --- |
| Current-state and machine coordination files | Prefer the repo mirror when it contains the latest source-status correction, active-claim archive shaping, validation results and append-only event/worklog context. |
| Navigation files | Reconcile deliberately so `_Sidebar.md`, `_Footer.md`, `Home.md` and `agent-context.json` agree on the current entrypoints without duplicate links or stale parity claims. |
| Wiki-only atlas/audit pages | Source-review before importing; merge useful source-backed details into canonical pages when overlap is high. |
| Shared content mismatches | Decide owner file by file. Prioritize current-status pages, machine files and navigation before long-form subsystem content. |
| Generated or release-readiness state | Preserve evidence-only wording until source Chernarus, generated Vanilla and Arma 2 OA smoke proof exist. |

## Mismatch Buckets

| Bucket | Count | First handling |
| --- | ---: | --- |
| Content atlas/reference | 26 | Preserve wiki-rich content until topic pages are source-reviewed and merged into canonical repo pages. |
| Machine state / agent ledgers | 19 | Treat separately from human docs; current repo state often owns latest coordination truth, but append-only history must not be erased. |
| Current-state / active work / playbooks | 17 | Prefer the newest source-backed current-status wording, especially [Current source status](Current-Source-Status-Snapshot). |
| Navigation / agent entry pages | 14 | Reconcile first because these shape every future agent's reading path. |
| Other docs | 14 | Triage after navigation and active-state pages. |
 
Only `Current-Source-Status-Snapshot.md` currently matches exactly. Several wiki-checkout pages appear richer than their repo-side counterparts, so a bulk repo-to-wiki mirror could erase useful human-facing content.

## First Pass Order

1. Keep repo and wiki-checkout validation green before any sync.
2. Remove stale "parity restored" wording from current dashboards and queue pages.
3. Scoped-sync `External-Arma-2-OA-Reference-Index.md` only after an OA-reference spot check.
4. Reconcile navigation pages and agent entry pages before long-form atlas imports.
5. Review wiki-only extras in small batches: machine/release files first, then lifecycle/runtime atlases, then feature-specific audit pages.
6. Merge useful wiki-rich pages into canonical repo pages when source-backed; retire only after the overlap is explained.
7. For each imported or retired page, update `agent-context.json`, `_Sidebar.md`, `Home.md`, `_Footer.md`, [Coordination board](Coordination-Board), [Bottleneck removal queue](Bottleneck-Removal-Queue), `agent-status.json`, `agent-collaboration.json`, [Agent worklog](Agent-Worklog), `agent-events.jsonl` and `agent-knowledge.jsonl` as needed.
8. Re-run parity after every deliberate batch. A failing parity check is acceptable only while a specific drift lane is open; unexplained parity claims are not.

## Validation Commands

Current checkout commands:

```powershell
Set-Location '<repo-root>'
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\validate-wiki.ps1
git diff --check
```

When JSON or JSONL machine files change, parse them before committing. After copying changed `docs\wiki\<page>` files into the wiki checkout, compare SHA256 hashes for every mirrored page in the batch. The old `Tools\ValidateWiki.ps1` and `Tools\TestWikiParity.ps1` helper names are historical unless those scripts are restored.

## Guardrails

| Guardrail | Reason |
| --- | --- |
| Use Arma 2 Operation Arrowhead 1.64 references only. | Arma 3 scripting conveniences can produce invalid or misleading SQF guidance for this mission. |
| Do not import Arma 3 scripts or examples. | The wiki is for `rayswaynl/a2waspwarfare`, not a modernized Arma 3 port. |
| Do not edit gameplay source in this lane. | This is a documentation parity lane; source cleanup needs a separate code-owner claim and smoke plan. |
| Do not blind-copy repo mirror to wiki checkout or wiki checkout to repo mirror. | Both sides contain useful but divergent state; file ownership must be chosen deliberately. |

## Continue Reading

Previous: [Bottleneck removal queue](Bottleneck-Removal-Queue) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Current source status](Current-Source-Status-Snapshot) | Agent file: [`agent-status.json`](agent-status.json)
