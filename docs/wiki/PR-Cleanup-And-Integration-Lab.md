# PR Cleanup And Integration Lab

Last updated: 2026-06-16.

This page tracks the June 2026 PR cleanup pass for `rayswaynl/a2waspwarfare`. It exists so humans and AI agents can see which PRs are real features, which are superseded by the release bundle, which are docs-only, and which branches should be tested together.

Current board state was refreshed from GitHub on 2026-06-16 with `gh pr list --repo rayswaynl/a2waspwarfare --state open --limit 100 --json number,title,headRefName,baseRefName,isDraft,updatedAt,url` plus `gh pr view` for PR #8 and PR #14. A later `git fetch --all --prune` removed local synthetic PR refs such as `origin/pr/*` and `miksuu/pr/*`; use the GitHub PR URLs, `headRefName`/`baseRefName` and remote branch heads as current evidence. Older ancestry notes below are preserved as historical results from the earlier PR-ref audit, not as refs future agents should expect to resolve locally.

## Current PR Board State

| State | PRs | Meaning |
| --- | --- | --- |
| Merged release/AICOM baselines | [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8), [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14) | No longer open board items. Keep their branch history as evidence, but do not route current work as if they still need merge decisions. |
| Open AICOM / Experital stack | [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29), [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30), [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34), [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35), [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36), [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37), [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38), [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39), [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40), [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | Current AI commander / Experital review train. Treat PR #35 as the deploy-to-master umbrella and the deploy-based children as review/fix lanes, not independent release baselines. |
| Other open release/test candidates | [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4), [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9), [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13), [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18), [#20](https://github.com/rayswaynl/a2waspwarfare/pull/20), [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21), [#31](https://github.com/rayswaynl/a2waspwarfare/pull/31), [#32](https://github.com/rayswaynl/a2waspwarfare/pull/32), [#33](https://github.com/rayswaynl/a2waspwarfare/pull/33) | Real features/tooling/performance work that still need their own review or smoke windows. PR #18 remains open but is based on merged `feat/ai-commander`, so treat it as legacy stacked work until rebased or explicitly closed. |
| Open docs/concept reference | [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Docs/concept only; keep outside gameplay release testing. |
| Closed/superseded feature PRs | [#1](https://github.com/rayswaynl/a2waspwarfare/pull/1), [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5), [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6), [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7), [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10), [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11), [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12), [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15), [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16), [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | Closed on the board; retain branch/head lessons where useful, but do not present them as open review items. |
| Closed docs PRs | [#2](https://github.com/rayswaynl/a2waspwarfare/pull/2), [#3](https://github.com/rayswaynl/a2waspwarfare/pull/3) | Historical docs mirror/review work; current docs truth is this branch plus the wiki checkout, not the stale closed PR branches. |

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

For current AI commander work, use PR #35 (`deploy/2026-06-12-aicom-experital` -> `master`, draft) as the deploy-review umbrella. PR #29 and PR #30 are still useful high-level AICOM / Experital surfaces, but child/fix lanes PR #34 and PR #36-#41 need explicit owner ordering against the deploy branch. PR #14 is merged (`gh pr view 14`: merged 2026-06-10T13:40:19Z); PR #18 remains open on `feat/ai-commander` and should not be treated as the current AICOM deploy base without a rebase/owner decision.

Keep PR #4, PR #9, PR #13, PR #20, PR #21, PR #31, PR #32 and PR #33 separate until they have their own focused test windows. PR #19 is closed; preserve it as branch/context evidence for the AI commander chain rather than as an open board item.

### 2026-06-16 AICOM / Experital PR Board Refresh

| PR | Head -> base | Board state | Practical route |
| --- | --- | --- | --- |
| [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29) | `ai-commander-main` -> `master` | Open | Live-verified AI Commander V0.6.6 surface. Review as AICOM source evidence, but current deploy-to-master routing now goes through PR #35. |
| [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30) | `experital` -> `release/2026-06-feature-bundle` | Open | Experital TEST mission branch. Useful for broad status/context, not the final deploy umbrella. |
| [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35) | `deploy/2026-06-12-aicom-experital` -> `master` | Open draft | Current Claude-led deploy review umbrella. Preserve the active `deploy-aicom-experital-merge-risk-audit` lane; do not merge solely from older #14/#18 wording. |
| [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34) | `fix/wildcard-w4w5-outer-capture` -> `deploy/2026-06-12-aicom-experital` | Open | Deploy-child W4/W5 wildcard fix. Needs owner choice for merge/cherry-pick ordering into #35. |
| [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36) | `fix/aicom-audit-verified-batch1` -> `deploy/2026-06-12-aicom-experital` | Open draft | Verified safe batch. Treat as deploy-child fixes, not a release baseline. |
| [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37) | `claude/aicom-review-fixes` -> `deploy/2026-06-12-aicom-experital` | Open draft | Lead-lane verified fixes. Coordinate with Claude before folding into deploy. |
| [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38) | `fix/aicom-review-batch-2026-06-15` -> `deploy/2026-06-12-aicom-experital` | Open | Review-fix batch against deploy. Also serves as base for PR #40. |
| [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39) | `review/aicom-deploy` -> `deploy/2026-06-12-aicom-experital` | Open | Pre-merge review fixes plus structure-refund proposal. Refund behavior needs MP/JIP/server smoke before release wording. |
| [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40) | `feat/client-fps` -> `fix/aicom-review-batch-2026-06-15` | Open | Client FPS/perf child lane stacked on PR #38, not directly on deploy. Rebase/merge-order matters. |
| [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | `notes/aicom-match-fixes` -> `deploy/2026-06-12-aicom-experital` | Open draft | Analysis and prepared patches from 8h test-server match. Treat as notes/proposals until owner selects fixes. |

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
| [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4) | Player stats phase 1 WIP | Open | Real feature, but keep separate from PR8 release test. | Clean merge candidate on top of PR8+12+16; adds DiscordBot stats pipeline and mission stat flush hooks. |
| [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5) | Upgrade queue | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6) | Engineer EASA repair truck | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7) | Delayed vehicle damage rewards | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8) | June 2026 feature bundle | Merged | Treat as merged release-bundle history, not an open board item. | `gh pr view 8` on 2026-06-16 reports merged 2026-06-09T07:47:34Z from `release/2026-06-feature-bundle` into `master`. |
| [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9) | Zargabad low-pop mission | Open | Real feature, but separate map-content test branch. | Clean merge candidate, but huge: 832 files and 77k+ insertions. |
| [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10) | Commander buildable positions | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11) | Buy-menu/EASA QoL | Closed | Superseded by PR #8 for board cleanup; retain branch audit as UI evidence. | Closed 2026-06-05. Earlier ancestry audit classified it as represented in PR #8. |
| [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12) | Quick-wins fixes | Closed | Folded into `dev/pr8-plus-testbed`; still needs focused server/economy smoke before release wording. | Closed 2026-06-05. Conflicted in five Chernarus files during lab merge, resolved by preserving PR8 behavior plus PR12 fixes. |
| [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13) | Recon UAV | Open | Real feature train, but do not combine casually with PR8. | Brings drone saturation strike stack; conflicts in tactical menu, UAV module deletion, and parameters. |
| [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14) | AI Commander draft | Merged | Treat as merged AICOM history. Use current AICOM/Experital PRs #29/#30/#35 and deploy-child lanes for live routing. | `gh pr view 14` on 2026-06-16 reports merged 2026-06-10T13:40:19Z from `feat/ai-commander` into `master`. |
| [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15) | WF menu ops-console reskin | Closed | Alternative UI direction only; cherry-pick ideas later if wanted. | Closed 2026-06-05. Conflicts with PR #16 in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for both Chernarus and Takistan. |
| [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16) | WF menu UX phase 1, original style | Closed | Included in `dev/pr8-plus-testbed` lab branch; PR itself is closed. | Closed 2026-06-05. Clean merge on top of PR8+12; less brand-opinionated than PR #15. |
| [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Quad AI commander docs | Open | Docs/concept only. Keep as reference, not gameplay merge material. | 23 docs/wiki files, no code. |
| [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18) | AI commander logs | Open draft | Legacy stacked AI commander logs. Rebase or close explicitly before using it as live deploy input. | 2026-06-16 GitHub metadata keeps base `feat/ai-commander`, which is already represented by merged PR #14; older PR8-lab conflict notes remain historical evidence. |
| [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | AI commander context beliefs | Closed | Treat as closed branch/context evidence for the PR #14/#18 AI commander chain. | Closed 2026-06-05. Base was `codex/ai-commander-logs`; conflicts in same commander upgrade function on PR8 lab. |
| [#20](https://github.com/rayswaynl/a2waspwarfare/pull/20) | Reusable PR test harness | Open | Tooling lane. Keep separate from gameplay bundles unless a release owner wants the harness in-tree. | 2026-06-16 GitHub metadata: `tools/reusable-pr-test-harness` -> `master`, non-draft. |
| [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21) | July 2026 update WIP | Open draft | Future roadmap/feature branch. Keep outside current June/AICOM deploy routing. | 2026-06-16 GitHub metadata: `dev/july-2026-update` -> `release/2026-06-feature-bundle`, draft. |
| [#29](https://github.com/rayswaynl/a2waspwarfare/pull/29) | AI Commander V0.6.6 | Open | Source/live-verification reference for AICOM. Route deploy-to-master through PR #35. | 2026-06-16 GitHub metadata: `ai-commander-main` -> `master`, non-draft. |
| [#30](https://github.com/rayswaynl/a2waspwarfare/pull/30) | Experital TEST mission | Open | Broad Experital surface and status target. Do not confuse with the deploy-to-master umbrella. | 2026-06-16 GitHub metadata: `experital` -> `release/2026-06-feature-bundle`, non-draft. |
| [#31](https://github.com/rayswaynl/a2waspwarfare/pull/31) | Marker consolidation perf | Open | Performance lane. Test separately from AICOM deploy unless an owner explicitly batches it. | 2026-06-16 GitHub metadata: `perf/marker-consolidation` -> `master`, non-draft. |
| [#32](https://github.com/rayswaynl/a2waspwarfare/pull/32) | Marker relevance perf | Open | Stacked performance lane. Review after or with PR #31, not as a standalone master baseline. | 2026-06-16 GitHub metadata: `perf/marker-relevance` -> `perf/marker-consolidation`, non-draft. |
| [#33](https://github.com/rayswaynl/a2waspwarfare/pull/33) | AI commander v06 hardening | Open | Older v06 hardening lane. Keep branch scope distinct from current deploy/Experital stack. | 2026-06-16 GitHub metadata: `ai-commander-v06-hardening` -> `ai-commander-v06`, non-draft. |
| [#34](https://github.com/rayswaynl/a2waspwarfare/pull/34) | W4/W5 wildcard fix | Open | Deploy-child fix. Fold through #35 only after owner ordering is clear. | 2026-06-16 GitHub metadata: `fix/wildcard-w4w5-outer-capture` -> `deploy/2026-06-12-aicom-experital`, non-draft. |
| [#35](https://github.com/rayswaynl/a2waspwarfare/pull/35) | Deploy AICOM Experital bundle | Open draft | Current deploy-to-master umbrella. Main live review route for AICOM/Experital. | 2026-06-16 GitHub metadata: `deploy/2026-06-12-aicom-experital` -> `master`, draft. Active audit lane is `deploy-aicom-experital-merge-risk-audit`. |
| [#36](https://github.com/rayswaynl/a2waspwarfare/pull/36) | AICOM audit verified batch 1 | Open draft | Deploy-child verified safe batch. Merge/cherry-pick only after owner order is chosen. | 2026-06-16 GitHub metadata: `fix/aicom-audit-verified-batch1` -> `deploy/2026-06-12-aicom-experital`, draft. |
| [#37](https://github.com/rayswaynl/a2waspwarfare/pull/37) | Lead-lane verified fixes | Open draft | Claude lead-lane fixes. Coordinate with Claude before folding. | 2026-06-16 GitHub metadata: `claude/aicom-review-fixes` -> `deploy/2026-06-12-aicom-experital`, draft. |
| [#38](https://github.com/rayswaynl/a2waspwarfare/pull/38) | AICOM review fixes | Open | Deploy-child review batch and base for #40. | 2026-06-16 GitHub metadata: `fix/aicom-review-batch-2026-06-15` -> `deploy/2026-06-12-aicom-experital`, non-draft. |
| [#39](https://github.com/rayswaynl/a2waspwarfare/pull/39) | AICOM pre-merge review / refund proposal | Open | Review fixes plus structure-refund proposal. Smoke refund behavior before release wording. | 2026-06-16 GitHub metadata: `review/aicom-deploy` -> `deploy/2026-06-12-aicom-experital`, non-draft. |
| [#40](https://github.com/rayswaynl/a2waspwarfare/pull/40) | Client FPS / marker-loop gating | Open | Child performance lane stacked on #38. Do not merge directly into deploy without rebase/order decision. | 2026-06-16 GitHub metadata: `feat/client-fps` -> `fix/aicom-review-batch-2026-06-15`, non-draft. |
| [#41](https://github.com/rayswaynl/a2waspwarfare/pull/41) | AICOM match-fix notes | Open draft | Notes/prepared patches from long test-server match. Treat as proposals until owner selects fixes. | 2026-06-16 GitHub metadata: `notes/aicom-match-fixes` -> `deploy/2026-06-12-aicom-experital`, draft. |

## Cleanup Actions

Recommended PR board cleanup:

1. Already closed/superseded on the board: PR #1, #5, #6, #7, #10, #11, #12, #15, #16 and #19.
2. Already merged: PR #8 and PR #14. Keep them as history/source evidence, not open merge targets.
3. Current AICOM route: use PR #35 as the deploy umbrella; treat PR #34 and #36-#41 as deploy-child review/fix/note lanes that need owner ordering.
4. Keep docs-only outside gameplay testing: PR #17. Treat PR #2 and PR #3 as closed historical docs work.
5. Test separately later: PR #4 player stats, PR #9 Zargabad, PR #13 drone/recon UAV, PR #18 legacy AI logs, PR #20 tooling, PR #21 July WIP, PR #31/#32 marker performance and PR #33 older AICOM v06 hardening.
6. WF menu direction is no longer an open PR-board choice: PR #16-style original UX lives in `dev/pr8-plus-testbed`; PR #15 is a closed alternative branch whose style ideas can be cherry-picked later only after visual smoke.

## Scout Findings Addendum

Additional read-only scout passes refined the branch guidance:

### PR #4 Player Stats

PR #4 is real, coherent, and off by default, but it should remain a separate feature lane. It adds a server-authoritative telemetry pipe:

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

PR #14 is now merged into `master`, PR #18 is still open as a draft on `feat/ai-commander`, and PR #19 is closed but still useful as context/belief evidence for that family. The chain is not perfectly linear by ancestry, so do not treat PR #18 as the current deploy base unless it is explicitly rebased or folded by the owner. The repeated hard conflict from the earlier PR8 lab was:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

The conflict is around AI commander upgrade debit/cost handling. There are no automated tests for no-human commander mode, human-assist mode, upgrade-spend correctness, smoke/JIP handoff, or context-belief output, so current AICOM work should follow PR #35 and the deploy-child lanes with manual lab and telemetry-first review.

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

Current AICOM route:
- PR35 is the deploy/2026-06-12-aicom-experital -> master umbrella
- PR34 and PR36-PR41 are child/review/note lanes around that deploy branch
- PR29/PR30 are useful AICOM/Experital context, but not substitutes for PR35 ordering

Keep separate for now:
- PR4 player stats: real but WIP
- PR9 Zargabad: real but huge map/content import
- PR13 drone/recon UAV: real but conflicts with PR8 UI/UAV files
- PR18 AI commander logs: open draft on merged PR14 base; rebase/close explicitly
- PR20 test harness, PR21 July WIP, PR31/32 marker perf and PR33 v06 hardening: separate lanes
- PR15 ops-console UI: closed alternate to PR16, cherry-pick ideas only
```

## Validation Performed

- Fetched `origin` and `miksuu`, including PR refs during the original pass. A later prune removed synthetic PR refs; current refresh uses GitHub PR metadata and branch heads.
- Refreshed GitHub PR metadata on 2026-06-16 with `gh pr list --repo rayswaynl/a2waspwarfare --state open --limit 100 --json number,title,headRefName,baseRefName,isDraft,updatedAt,url`; verified PR #8 and PR #14 merged with `gh pr view`.
- Checked PR ancestry against PR #8.
- Created isolated worktrees under `work/pr8-only-testbed` and `work/pr8-plus-testbed`.
- Merged PR #12 into PR8 lab with manual conflict resolution in five files.
- Merged PR #16 cleanly into the combined lab.
- Dry-tested PR #4, #9, #13, #14, #15, #18, and #19 on top of the combined lab.
- Pushed both dev branches to `origin`.

## Adjacent Upstream Note

`Miksuu/master` is ahead of `rayswaynl/master` by `Marty_town_defense_fix` as of this pass. That should be evaluated separately as an upstream-sync candidate before cutting a final gameplay release branch.

## Continue Reading

Previous: [Current source status snapshot](Current-Source-Status-Snapshot) | Next: [PR8 and Drone upstream lesson match](PR8-And-Drone-Upstream-Lesson-Match)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Testing: [Testing workflow](Testing-Debugging-And-Release-Workflow)
