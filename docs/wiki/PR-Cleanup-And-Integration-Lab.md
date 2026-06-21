# PR Cleanup And Integration Lab

Last updated: 2026-06-21.

This page tracks the June 2026 PR cleanup pass for `rayswaynl/a2waspwarfare`. It exists so humans and AI agents can see which PRs are real features, which are superseded by the release bundle, which are docs-only, and which branches should be tested together.

Current board state was refreshed from GitHub on 2026-06-21 with `gh pr list --repo rayswaynl/a2waspwarfare --state all --limit 80 --json number,title,state,headRefName,baseRefName,isDraft,updatedAt,mergedAt,url`. The returned set has `3` open PRs, `12` merged PRs and `28` closed PRs. A later `git fetch --all --prune` removed local synthetic PR refs such as `origin/pr/*` and `miksuu/pr/*`; use the GitHub PR URLs, `headRefName`/`baseRefName`, `mergedAt` / `updatedAt` and remote branch heads as current evidence. Older ancestry notes below are preserved as historical results from the earlier PR-ref audit, not as refs future agents should expect to resolve locally.

## Current PR Board State

| State | PRs | Meaning |
| --- | --- | --- |
| Open master-target soak / proposals | [#43](https://github.com/rayswaynl/a2waspwarfare/pull/43) | Current open master-target review surface: `claude/b57-soak-proposals` -> `master`, updated 2026-06-21T14:22:01Z. Treat as the live B57 soak/proposals PR, not as proof that the whole AICOM/GUER source set is release-ready. |
| Open stacked performance child | [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40) | Still open, but stacked on closed base `fix/aicom-review-batch-2026-06-15`. Rebase or owner decision is required before treating it as a clean master candidate. |
| Open map/content candidate | [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9) | Zargabad low-pop mission remains open against `master`, updated 2026-06-20T05:17:48Z. Keep as a separate map/content validation lane. |
| Merged into `master` | [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8), [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14), [#22](https://github.com/rayswaynl/a2waspwarfare/pull/22), [#23](https://github.com/rayswaynl/a2waspwarfare/pull/23), [#24](https://github.com/rayswaynl/a2waspwarfare/pull/24), [#25](https://github.com/rayswaynl/a2waspwarfare/pull/25), [#26](https://github.com/rayswaynl/a2waspwarfare/pull/26), [#27](https://github.com/rayswaynl/a2waspwarfare/pull/27), [#28](https://github.com/rayswaynl/a2waspwarfare/pull/28), [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29), [#31](https://github.com/rayswaynl/a2waspwarfare/pull/31) | No longer open board items. Their branch history remains useful source evidence, but current branch truth starts from fetched `origin/master@0139a346` unless a page names another ref. |
| Merged into a non-master branch | [#42](https://github.com/rayswaynl/a2waspwarfare/pull/42) | `claude/guer-merge` -> `claude/b39`, merged 2026-06-16T19:56:21Z. Treat as branch-integration evidence, not as a master merge by itself. |
| Closed former AICOM / Experital stack | [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30), [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34), [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35), [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36), [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37), [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38), [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39), [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | The old deploy umbrella and deploy-child review/fix/note PRs are closed as of 2026-06-17. Keep their findings as history; do not route current work through them as active PRs. |
| Closed feature/tooling/docs PRs | [#1](https://github.com/rayswaynl/a2waspwarfare/pull/1), [#2](https://github.com/rayswaynl/a2waspwarfare/pull/2), [#3](https://github.com/rayswaynl/a2waspwarfare/pull/3), [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4), [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5), [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6), [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7), [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10), [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11), [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12), [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13), [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15), [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16), [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17), [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18), [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19), [#20](https://github.com/rayswaynl/a2waspwarfare/pull/20), [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21), [#32](https://github.com/rayswaynl/a2waspwarfare/pull/32), [#33](https://github.com/rayswaynl/a2waspwarfare/pull/33) | Closed on the board. Retain branch/head lessons where useful, but do not present them as open review items. |

## Branches Created

| Branch | Contents | Use |
| --- | --- | --- |
| [`dev/pr8-only-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-only-testbed) | Snapshot of PR #8 / `release/2026-06-feature-bundle` for clean bundle testing. Current fetched head observed as `68b34e6e`; current release/PR #8 branch head observed as `a96fdda2`, so the testbed branch is now an older clean snapshot unless it is rebuilt. | Clean PR8-only multiplayer test baseline. Rebuild/rebase if exact branch-head parity matters. |
| [`dev/pr8-plus-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-plus-testbed) | PR #8 lab plus manually resolved PR #12 quick fixes and PR #16 original-style WF menu UX. Current fetched head observed as `5fb51c37`. | Combined test branch for bundle plus quick fixes plus original-style WF menu UX. |

## Main Recommendation

PR #8 is now merged into `master` (`gh pr view 8`: merged 2026-06-09T07:47:34Z), so treat it as release-bundle history rather than an open baseline. The earlier PR-ref ancestry audit found PR #1, PR #5, PR #6, PR #7, PR #10 and PR #11 already represented in the PR #8 bundle lineage, so those standalone PRs should not be merged separately. PR #11 is closed.

The best current combined gameplay test branch is:

```text
dev/pr8-plus-testbed = PR #8 + PR #12 + PR #16
```

The old AICOM deploy route through PR #35 is closed. PR #29 (`ai-commander-main` -> `master`) and PR #31 (`perf/marker-consolidation` -> `master`) both merged on 2026-06-17T11:45:52Z; PR #30, PR #34, PR #35, PR #36, PR #37, PR #38, PR #39 and PR #41 are closed. Current source truth for merged AICOM/GUER work starts from `origin/master@0139a346`; current open review routing is PR #43 for B57 soak/proposals, PR #40 for the still-open client-FPS child stacked on a closed base, and PR #9 for Zargabad.

Keep closed PRs as historical evidence unless an owner explicitly reopens or rebases them. In particular, PR #40 needs a rebase/owner decision before it is treated as mergeable because its base branch `fix/aicom-review-batch-2026-06-15` is closed, and PR #42 is branch integration into `claude/b39`, not a master merge.

### 2026-06-21 AICOM / Experital PR Board Refresh

| PR | Head -> base | Board state | Practical route |
| --- | --- | --- | --- |
| [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29) | `ai-commander-main` -> `master` | Merged 2026-06-17T11:45:52Z | Merged AICOM V0.6.6 source history. Use current `origin/master@0139a346` for current-head claims. |
| [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30) | `experital` -> `release/2026-06-feature-bundle` | Closed 2026-06-17T11:51:11Z | Historical Experital surface; do not use as active broad status target. |
| [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35) | `deploy/2026-06-12-aicom-experital` -> `master` | Closed draft 2026-06-17T11:51:11Z | Former deploy umbrella. Preserve its review history, but stop treating `deploy-aicom-experital-merge-risk-audit` as live dashboard work. |
| [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34) | `fix/wildcard-w4w5-outer-capture` -> `deploy/2026-06-12-aicom-experital` | Closed 2026-06-17T11:51:10Z | Former deploy-child fix; current source verification must start from `origin/master@0139a346` or the named branch, not from an open PR. |
| [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36) | `fix/aicom-audit-verified-batch1` -> `deploy/2026-06-12-aicom-experital` | Closed draft 2026-06-17T11:47:05Z | Closed deploy-child verified batch. Preserve as source-history evidence only. |
| [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37) | `claude/aicom-review-fixes` -> `deploy/2026-06-12-aicom-experital` | Closed draft 2026-06-17T11:47:03Z | Closed deploy-child fix lane. Future use needs branch/source recheck. |
| [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38) | `fix/aicom-review-batch-2026-06-15` -> `deploy/2026-06-12-aicom-experital` | Closed 2026-06-17T11:47:01Z | Closed review-fix batch. It still matters because PR #40 is stacked on this closed base. |
| [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39) | `review/aicom-deploy` -> `deploy/2026-06-12-aicom-experital` | Closed 2026-06-17T11:46:59Z | Closed pre-merge review/proposal lane. Keep refund behavior as source/smoke evidence only where separately verified. |
| [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40) | `feat/client-fps` -> `fix/aicom-review-batch-2026-06-15` | Open, updated 2026-06-19T22:50:34Z | Current open child/perf lane, but its base is closed. Needs rebase or explicit owner decision before merge/test routing. |
| [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | `notes/aicom-match-fixes` -> `deploy/2026-06-12-aicom-experital` | Closed draft 2026-06-17T11:46:57Z | Closed notes/prepared-patches lane. Preserve as analysis only. |
| [#42](https://github.com/rayswaynl/a2waspwarfare/pull/42) | `claude/guer-merge` -> `claude/b39` | Merged 2026-06-16T19:56:21Z | Branch-integration evidence for GUER into `claude/b39`; not a master-target PR. |
| [#43](https://github.com/rayswaynl/a2waspwarfare/pull/43) | `claude/b57-soak-proposals` -> `master` | Open, updated 2026-06-21T14:22:01Z | Current master-target soak/proposals PR. Use this for live PR-board routing unless a newer PR appears. |

### PR #8 Head Refresh: `a96fdda2`

A 2026-06-14 refetch found `origin/release/2026-06-feature-bundle` at `a96fdda2`, newer than the 2026-06-05 `7195b331` release matrix head and the intermediate `7ff18c49` head. The early delta after `3282ff3f` removes the Chernarus-only static smoke helper from the release payload (`d482c742`), applies broad live-playtest hardening (`fb3084c2`) and replaces the old FPS-only menu slot with a GPS toggle (`7195b331`). Later release work adds delegated-AI/town-defense, AFK, WDDM, gear/cargo, MASH-removal, jet-AA and economy/perf changes before the current `a96fdda2` merge head. Treat `a96fdda2` as the release-bundle branch head to review; older `dev/pr8-only-testbed` remains a stale clean snapshot unless rebuilt.

| Commit | Scope | Source evidence | Test implication |
| --- | --- | --- | --- |
| `68b34e6e` | WF menu player/playable-slot/town counts. | Chernarus and Vanilla `Client/GUI/GUI_Menu.sqf` add a compact top strip for uptime, clock, players, playable slots and towns held/total. Vanilla replaces the localized uptime line with the same hard-coded compact strip. | Client visual smoke for text fit, long names/localization assumptions and town-count correctness. |
| `cd63fb95` | Service-point menu QoL. | Chernarus and Vanilla `Client/GUI/GUI_Menu_Service.sqf` and `Rsc/Dialogs.hpp` add full-service helpers, refuel pricing, disabled-state reasons and batch/full start helpers. | Smoke destroyed/airborne/moving disabled reasons, full-service, repair/refuel/rearm/heal-all paths and visible funds debit. Treat as UX/QoL evidence, not server-authority hardening. |
| `379da6c0` | Shielded concrete HQ walls. | Chernarus and Vanilla `Server/Init/Init_Defenses.sqf` add `WFBE_NEURODEF_HEADQUARTERS_WALLS`; `Server/Construction/Construction_HQSite.sqf` stores deployed walls in `wfbe_hq_walls` and deletes them on mobilize. | Smoke HQ deploy/mobilize wall creation and cleanup, pathing/blockage, base-area interactions and no stale walls after redeploy. |
| `3282ff3f` | Static PR8 preflight, now historical. | `Tools/SmokeTests/Test-PR8StaticSmoke.ps1` scanned Chernarus changed `.sqf`/`.fsm` files against `origin/master`, A3-only command names, HQ shield wiring, key PR8 PVF registrations and Buy Units image-tab text writes. | Historical source/static preflight only. The next release commit removes this helper from the release payload, so rerun or recover it from git history if the static check is wanted. |
| `d482c742` | Keep smoke harness out of release payload. | Deletes `Tools/SmokeTests/Test-PR8StaticSmoke.ps1`. | Do not expect the PR8 smoke helper in the release branch checkout after this commit; validation must use an external/local copy or future tooling commit. |
| `fb3084c2` | Live-playtest hardening. | Broad Chernarus + maintained Vanilla changes across UI/RHUD, supply mission, stat hooks, construction/defense, public-variable registrations, generated mission files and LoadoutManager root discovery. Spot-checks at this intermediate head showed both release roots carrying paratrooper marker registration, single `Skill_Init`, hosted-FPS guard/removal, narrowed supply command-center scan, camp flag capture fix and resistance patrol `&&`, while commander-built ARTY ownership was still absent. | Broad static propagation evidence, but not the final observed release head. Keep the full Chernarus + Vanilla smoke list for supply, service, buy menu, RHUD/endgame, construction/defense, paratroopers, FPS publishers, town/camp capture and patrol lifecycle. |
| `7195b331` | GPS toggle QoL on top of PR8 hardening. | Chernarus and Vanilla `Client/GUI/GUI_Menu.sqf` make menu action `19` toggle `shownGPS`/`showGPS`; `Client/Client_UpdateRHUD.sqf` removes the FPS-only `RUBFPSHUD` mode; `Client/Init/Init_Client.sqf` removes `RUBFPSHUD` init while keeping the single `Skill_Init` shape. | Historical GPS-toggle intermediate, not the current release head. Add main-menu GPS toggle and RHUD FPS display checks to the full smoke list. |
| `7ff18c49` | Delegated-AI locality and cleaner/restorer startup hardening. | Release history after `7195b331` introduced fallback/locality guards and cleaner/restorer startup timer floors in both maintained roots. | HC town/static delegation and long-session cleaner/restorer behavior still require Arma smoke; do not close DR-42 static-defense update-back from this evidence alone. |
| `a96fdda2` | Current PR8/release branch head after upstream town-defense/AFK and follow-up PR8 hardening. | Current release Chernarus and maintained Vanilla mark non-repair-truck artillery defenses with `WFBE_CommanderArtillery*` at `Construction_StationaryDefense.sqf:132-135` and let the commander team discover same-side marked guns inside HQ/base-area radius through `Common_GetTeamArtillery.sqf:46-78`. Current release also keeps town HC group registration/update-back at `Client_DelegateTownAI.sqf:29-44` plus `Server_HandleSpecial.sqf:86-115`, while static-defense HC update-back remains commented at `Client_DelegateAIStaticDefence.sqf:27-30`. | Treat as the current branch to smoke, not runtime proof. Include commander-built artillery discovery, HC town/static delegation, town-defense/capture, AFK flow, GPS menu, MASH removal side effects, gear/cargo loops and economy/factory cases in release testing. |

## PR Triage Matrix

| PR | Title / branch | Status | Recommendation | Evidence |
| --- | --- | --- | --- | --- |
| [#1](https://github.com/rayswaynl/a2waspwarfare/pull/1) | Supply helicopters | Closed | Superseded by PR #8 for board cleanup; branch-specific heli evidence remains useful in the supply-heli page. | Earlier PR-ref ancestry audit classified it as represented in PR #8; current board shows closed. |
| [#2](https://github.com/rayswaynl/a2waspwarfare/pull/2) | Developer wiki mirror | Closed | Historical docs PR; do not use as live docs branch. | Closed 2026-06-05. Current docs truth is `docs/developer-wiki-index` plus wiki checkout. |
| [#3](https://github.com/rayswaynl/a2waspwarfare/pull/3) | Claude wiki review | Closed | Historical/harvested Claude docs branch; do not merge wholesale over newer navigation. | Closed 2026-06-05. Targeted findings were harvested; branch is stale relative to current docs. |
| [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4) | Player stats phase 1 WIP | Closed | Historical feature branch evidence only unless reopened or rebased. | 2026-06-21 GitHub metadata: `codex/ai-commander-logs` -> `master`, closed, updated 2026-06-17T11:47:31Z. Older scout notes still describe its off-by-default stats pipeline. |
| [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5) | Upgrade queue | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6) | Engineer EASA repair truck | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7) | Delayed vehicle damage rewards | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8) | June 2026 feature bundle | Merged | Treat as merged release-bundle history, not an open board item. | `gh pr view 8` on 2026-06-16 reports merged 2026-06-09T07:47:34Z from `release/2026-06-feature-bundle` into `master`. |
| [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9) | Zargabad low-pop mission | Open | Real feature, but separate map-content test branch. | Clean merge candidate, but huge: 832 files and 77k+ insertions. |
| [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10) | Commander buildable positions | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11) | Buy-menu/EASA QoL | Closed | Superseded by PR #8 for board cleanup; retain branch audit as UI evidence. | Closed 2026-06-05. Earlier ancestry audit classified it as represented in PR #8. |
| [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12) | Quick-wins fixes | Closed | Folded into `dev/pr8-plus-testbed`; still needs focused server/economy smoke before release wording. | Closed 2026-06-05. Conflicted in five Chernarus files during lab merge, resolved by preserving PR8 behavior plus PR12 fixes. |
| [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13) | Recon UAV | Closed | Historical drone/recon branch evidence only unless reopened or rebased. | 2026-06-21 GitHub metadata: `feat/recon-uav` -> `feat/drone-saturation-strike`, closed, updated 2026-06-17T11:47:29Z. Older scout notes still preserve its branch-risk lessons. |
| [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14) | AI Commander draft | Merged | Treat as merged AICOM history. Current source claims should start from `origin/master@0139a346` or a named branch/PR. | `gh pr view 14` on 2026-06-16 reported merged 2026-06-10T13:40:19Z from `feat/ai-commander` into `master`; 2026-06-21 metadata still reports merged. |
| [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15) | WF menu ops-console reskin | Closed | Alternative UI direction only; cherry-pick ideas later if wanted. | Closed 2026-06-05. Conflicts with PR #16 in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for both Chernarus and Takistan. |
| [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16) | WF menu UX phase 1, original style | Closed | Included in `dev/pr8-plus-testbed` lab branch; PR itself is closed. | Closed 2026-06-05. Clean merge on top of PR8+12; less brand-opinionated than PR #15. |
| [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Quad AI commander docs | Closed | Docs/concept history; keep useful ideas in wiki pages instead of treating the PR as open. | 2026-06-21 GitHub metadata: `codex/quad-ai-commander` -> `master`, closed, updated 2026-06-17T11:47:27Z. |
| [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18) | AI commander logs | Closed draft | Legacy stacked AI commander logs. Preserve conflict/context lessons only. | 2026-06-21 GitHub metadata: `codex/ai-commander-logs` -> `feat/ai-commander`, closed, updated 2026-06-17T11:47:25Z. |
| [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | AI commander context beliefs | Closed | Treat as closed branch/context evidence for the PR #14/#18 AI commander chain. | Closed 2026-06-05. Base was `codex/ai-commander-logs`; conflicts in same commander upgrade function on PR8 lab. |
| [#20](https://github.com/rayswaynl/a2waspwarfare/pull/20) | Reusable PR test harness | Closed | Tooling history; do not treat as an open harness PR. | 2026-06-21 GitHub metadata: `tools/reusable-pr-test-harness` -> `master`, closed, updated 2026-06-17T11:47:23Z. |
| [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21) | July 2026 update WIP | Closed draft | Historical July WIP branch. Use the dashboard July Update To-Do for current roadmap routing instead. | 2026-06-21 GitHub metadata: `dev/july-2026-update` -> `release/2026-06-feature-bundle`, closed, updated 2026-06-17T11:47:19Z. |
| [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29) | AI Commander V0.6.6 | Merged | Merged AICOM source history. Current AICOM claims should start from `origin/master@0139a346` or a named branch/PR. | 2026-06-21 GitHub metadata: `ai-commander-main` -> `master`, merged 2026-06-17T11:45:52Z. |
| [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30) | Experital TEST mission | Closed | Historical Experital surface; no longer a live broad status target. | 2026-06-21 GitHub metadata: `experital` -> `release/2026-06-feature-bundle`, closed, updated 2026-06-17T11:51:11Z. |
| [#31](https://github.com/rayswaynl/a2waspwarfare/pull/31) | Marker consolidation perf | Merged | Merged performance source history. Verify current behavior from `origin/master@0139a346` before claiming runtime status. | 2026-06-21 GitHub metadata: `perf/marker-consolidation` -> `master`, merged 2026-06-17T11:45:52Z. |
| [#32](https://github.com/rayswaynl/a2waspwarfare/pull/32) | Marker relevance perf | Closed | Stacked performance branch history; not an open PR. | 2026-06-21 GitHub metadata: `perf/marker-relevance` -> `perf/marker-consolidation`, closed, updated 2026-06-17T11:51:13Z. |
| [#33](https://github.com/rayswaynl/a2waspwarfare/pull/33) | AI commander v06 hardening | Closed | Older v06 hardening history; do not use as live deploy route. | 2026-06-21 GitHub metadata: `ai-commander-v06-hardening` -> `ai-commander-v06`, closed, updated 2026-06-17T11:51:10Z. |
| [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34) | W4/W5 wildcard fix | Closed | Former deploy-child fix; verify current source directly before claiming it landed. | 2026-06-21 GitHub metadata: `fix/wildcard-w4w5-outer-capture` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:51:10Z. |
| [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35) | Deploy AICOM Experital bundle | Closed draft | Former deploy umbrella. No longer the active dashboard route. | 2026-06-21 GitHub metadata: `deploy/2026-06-12-aicom-experital` -> `master`, closed, updated 2026-06-17T11:51:11Z. |
| [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36) | AICOM audit verified batch 1 | Closed draft | Closed deploy-child verified batch. Preserve only as source-review history. | 2026-06-21 GitHub metadata: `fix/aicom-audit-verified-batch1` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:47:05Z. |
| [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37) | Lead-lane verified fixes | Closed draft | Closed deploy-child fix lane. Future use needs branch/source recheck. | 2026-06-21 GitHub metadata: `claude/aicom-review-fixes` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:47:03Z. |
| [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38) | AICOM review fixes | Closed | Closed review-fix batch and stale base for PR #40. | 2026-06-21 GitHub metadata: `fix/aicom-review-batch-2026-06-15` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:47:01Z. |
| [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39) | AICOM pre-merge review / refund proposal | Closed | Closed review/proposal lane. Smoke refund behavior only if separately source-verified on a current target. | 2026-06-21 GitHub metadata: `review/aicom-deploy` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:46:59Z. |
| [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40) | Client FPS / marker-loop gating | Open | Current open child/perf lane, but its base PR #38 is closed. Rebase or owner decision required before merge/test routing. | 2026-06-21 GitHub metadata: `feat/client-fps` -> `fix/aicom-review-batch-2026-06-15`, open, updated 2026-06-19T22:50:34Z. |
| [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | AICOM match-fix notes | Closed draft | Closed notes/prepared-patches lane. Preserve as analysis only. | 2026-06-21 GitHub metadata: `notes/aicom-match-fixes` -> `deploy/2026-06-12-aicom-experital`, closed, updated 2026-06-17T11:46:57Z. |
| [#42](https://github.com/rayswaynl/a2waspwarfare/pull/42) | GUER Insurgents faction -> B39 | Merged to branch | Branch-integration evidence only; not a master-target PR. | 2026-06-21 GitHub metadata: `claude/guer-merge` -> `claude/b39`, merged 2026-06-16T19:56:21Z. |
| [#43](https://github.com/rayswaynl/a2waspwarfare/pull/43) | B57 soak proposals | Open | Current master-target review surface. | 2026-06-21 GitHub metadata: `claude/b57-soak-proposals` -> `master`, open, updated 2026-06-21T14:22:01Z. |

## Cleanup Actions

Recommended PR board cleanup:

1. Current open PRs are only PR #43, PR #40 and PR #9 in the 2026-06-21 `gh pr list --state all --limit 80` result.
2. Treat PR #43 as the live master-target soak/proposals route.
3. Treat PR #40 as open but blocked on rebase/owner ordering because its base `fix/aicom-review-batch-2026-06-15` is closed.
4. Treat PR #9 as the separate Zargabad map/content validation lane.
5. Treat PR #35 and deploy-child PR #34/#36-#39/#41 as closed historical AICOM deploy evidence, not active lanes.
6. Treat PR #42 as branch integration into `claude/b39`, not a master merge.
7. Keep older closed PR lessons below as historical scouting evidence only.

## Scout Findings Addendum

Additional read-only scout passes refined the branch guidance:

### PR #4 Player Stats

PR #4 is closed as of the 2026-06-21 board refresh. Its historical branch was real, coherent and off by default, but it is not an open PR lane. The preserved lesson is the server-authoritative telemetry pipe:

```text
server SQF stat buffer -> WASPSTAT RPT lines -> DiscordBot RPT tailer/parser -> stats.json
```

Both gates default off:

- Mission: `WFBE_C_STATS_ENABLED = false`.
- Bot: `Preferences.StatsEnabled = false`.

The branch includes deterministic `DiscordBot.Tests` coverage for parser, accumulator, document persistence, RPT tailing, and pipeline integration. The main risk is operational/privacy rather than mergeability: `stats.json` is keyed by raw SteamID64 and should be treated as sensitive local telemetry.

### PR #9 Zargabad

PR #9 is a mission-pack import, not a small feature. It is mechanically clean but operationally large:

- 80 commits ahead of `origin/master`.
- 832 files changed.
- 77k+ insertions.
- Hundreds of new files under `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad`.

Use its validation tooling as gates before promotion:

```text
Tools/Validate-ZargabadMission.ps1
Tools/New-ZargabadRuntimeReport.ps1
Tools/Validate-ZargabadRuntimeEvidence.ps1
Tools/Validate-ZargabadRuntimeReport.ps1
```

Also evaluate `miksuu/Marty_town_defense_fix` before serious release testing. It is a focused upstream runtime correctness fix and may reduce false confidence during PR8 town-defense sessions.

### PR #14 / #18 / #19 AI Commander Chain

These PRs are one experimental family, not standalone branches:

- PR #14 adds the commander supervisor/worker runtime.
- PR #18 adds structured AI commander logs.
- PR #19 adds context/belief tracking.

PR #14 is merged into `master`; PR #18 and PR #19 are closed but still useful as context/belief evidence for that family. The chain is not perfectly linear by ancestry, so do not treat PR #18 as a current deploy base unless a future owner reopens or rebases it. The repeated hard conflict from the earlier PR8 lab was:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

The conflict is around AI commander upgrade debit/cost handling. There are no automated tests for no-human commander mode, human-assist mode, upgrade-spend correctness, smoke/JIP handoff, or context-belief output. Current AICOM/GUER source claims should start from `origin/master@0139a346` or PR #43, then use the closed deploy PRs only as historical review evidence.

### PR #15 vs PR #16 UI

PR #16 remains the safer default because it is smaller, keeps the existing visual contract and focuses on SafeZone/layout/grouping improvements. PR #15 is a broader visual reskin. Both PRs are now closed on the board, so this section is branch-afterlife guidance:

- PR #15 changes shared style/resource/title files, GUI structured-text colors, and adds `brand_chevron.jpg`.
- PR #16 rewrites the main WF menu layout and shared resources in a lower-risk way and is represented in `dev/pr8-plus-testbed`.
- Both overlap in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for Chernarus and Takistan.

Do not revive both blindly. Cherry-pick PR #15 ideas later only after PR #16-style UI is tested: style tokens, title typography, structured-text color polish and optional branding/footer assets.

## Test Notes For Discord

Short version to share:

```text
PR8 and PR14 are merged, not open board items.
PR8 already contains or supersedes PR1/5/6/7/10/11, so those are closed/superseded.

Historical test branches:
- dev/pr8-only-testbed: old PR8-only snapshot
- dev/pr8-plus-testbed: old PR8 + closed PR12 quick fixes + closed PR16 WF menu UX snapshot

Current open PR route:
- PR43 is the live master-target B57 soak/proposals PR
- PR40 is still open, but it is stacked on a closed base and needs rebase/owner ordering
- PR9 is the separate Zargabad map/content PR
- PR35 and PR34/PR36-PR39/PR41 are closed AICOM deploy history
- PR29 and PR31 are merged history; current source truth starts at origin/master@0139a346

Keep separate for now:
- PR9 Zargabad: real but huge map/content import
- PR4 player stats, PR13 drone/recon UAV, PR18 logs, PR20 harness, PR21 July WIP, PR32 marker relevance and PR33 v06 hardening are closed historical PRs
- PR15 ops-console UI: closed alternate to PR16, cherry-pick ideas only
```

## Validation Performed

- Fetched `origin` and `miksuu`, including PR refs during the original pass. A later prune removed synthetic PR refs; current refresh uses GitHub PR metadata and branch heads.
- Refreshed GitHub PR metadata on 2026-06-16 with `gh pr list --repo rayswaynl/a2waspwarfare --state open --limit 100 --json number,title,headRefName,baseRefName,isDraft,updatedAt,url`; verified PR #8 and PR #14 merged with `gh pr view`.
- Refreshed GitHub PR metadata again on 2026-06-21 with `gh pr list --repo rayswaynl/a2waspwarfare --state all --limit 80 --json number,title,state,headRefName,baseRefName,isDraft,updatedAt,mergedAt,url`; result count was `3` open, `12` merged and `28` closed. The open PRs were #9, #40 and #43.
- Checked PR ancestry against PR #8.
- Created isolated worktrees under `work/pr8-only-testbed` and `work/pr8-plus-testbed`.
- Merged PR #12 into PR8 lab with manual conflict resolution in five files.
- Merged PR #16 cleanly into the combined lab.
- Dry-tested PR #4, #9, #13, #14, #15, #18, and #19 on top of the combined lab.
- Pushed both dev branches to `origin`.

## Adjacent Upstream Note

The older upstream note below was written during the original PR cleanup pass. This checkout currently has only the `origin` remote configured, so re-add/fetch a Miksuu upstream remote before using any `Miksuu/master` ahead/behind claim for a new release decision.

## Continue Reading

Previous: [Current source status snapshot](Current-Source-Status-Snapshot) | Next: [PR8 and Drone upstream lesson match](PR8-And-Drone-Upstream-Lesson-Match)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Testing: [Testing workflow](Testing-Debugging-And-Release-Workflow)
