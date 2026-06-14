# PR Cleanup And Integration Lab

Last updated: 2026-06-14.

This page tracks the June 2026 PR cleanup pass for `rayswaynl/a2waspwarfare`. It exists so humans and AI agents can see which PRs are real features, which are superseded by the release bundle, which are docs-only, and which branches should be tested together.

Current board state was refreshed from GitHub on 2026-06-05. A later `git fetch --all --prune` removed local synthetic PR refs such as `origin/pr/*` and `miksuu/pr/*`; use the GitHub PR URLs, `headRefName`/`baseRefName` and remote branch heads as current evidence. Older ancestry notes below are preserved as historical results from the earlier PR-ref audit, not as refs future agents should expect to resolve locally.

## Current PR Board State

| State | PRs | Meaning |
| --- | --- | --- |
| Open release/test candidates | [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4), [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8), [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9), [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13), [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14), [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18) | Real feature or experiment branches that need separate review/smoke windows. |
| Open docs/concept reference | [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Docs/concept only; keep outside gameplay release testing. |
| Closed/superseded feature PRs | [#1](https://github.com/rayswaynl/a2waspwarfare/pull/1), [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5), [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6), [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7), [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10), [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11), [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12), [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15), [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16), [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | Closed on the board; retain branch/head lessons where useful, but do not present them as open review items. |
| Closed docs PRs | [#2](https://github.com/rayswaynl/a2waspwarfare/pull/2), [#3](https://github.com/rayswaynl/a2waspwarfare/pull/3) | Historical docs mirror/review work; current docs truth is this branch plus the wiki checkout, not the stale closed PR branches. |

## Branches Created

| Branch | Contents | Use |
| --- | --- | --- |
| [`dev/pr8-only-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-only-testbed) | Snapshot of PR #8 / `release/2026-06-feature-bundle` for clean bundle testing. Current fetched head observed as `68b34e6e`; current release/PR #8 branch head observed as `a96fdda2`, so the testbed branch is now an older clean snapshot unless it is rebuilt. | Clean PR8-only multiplayer test baseline. Rebuild/rebase if exact branch-head parity matters. |
| [`dev/pr8-plus-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-plus-testbed) | PR #8 lab plus manually resolved PR #12 quick fixes and PR #16 original-style WF menu UX. Current fetched head observed as `5fb51c37`. | Combined test branch for bundle plus quick fixes plus original-style WF menu UX. |

## Main Recommendation

Use PR #8 as the release bundle baseline. The earlier PR-ref ancestry audit found PR #1, PR #5, PR #6, PR #7, PR #10 and PR #11 already represented in the PR #8 bundle lineage, so those standalone PRs should not be merged separately. PR #11 is now closed.

The best current combined gameplay test branch is:

```text
dev/pr8-plus-testbed = PR #8 + PR #12 + PR #16
```

Keep PR #4, PR #9, PR #13 and the PR #14/#18 AI-commander chain separate until they have their own focused test windows. PR #19 is now closed; preserve it as branch/context evidence for the AI commander chain rather than as an open board item.

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
| [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8) | June 2026 feature bundle | Open | Treat as primary release bundle. | 72 mission files; contains supply heli, WDDM positions, upgrade queue, EASA/QoL, rewards, fixes. |
| [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9) | Zargabad low-pop mission | Open | Real feature, but separate map-content test branch. | Clean merge candidate, but huge: 832 files and 77k+ insertions. |
| [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10) | Commander buildable positions | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11) | Buy-menu/EASA QoL | Closed | Superseded by PR #8 for board cleanup; retain branch audit as UI evidence. | Closed 2026-06-05. Earlier ancestry audit classified it as represented in PR #8. |
| [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12) | Quick-wins fixes | Closed | Folded into `dev/pr8-plus-testbed`; still needs focused server/economy smoke before release wording. | Closed 2026-06-05. Conflicted in five Chernarus files during lab merge, resolved by preserving PR8 behavior plus PR12 fixes. |
| [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13) | Recon UAV | Open | Real feature train, but do not combine casually with PR8. | Brings drone saturation strike stack; conflicts in tactical menu, UAV module deletion, and parameters. |
| [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14) | AI Commander draft | Open | Keep experimental. Test alone or after commander-specific review. | Conflicts in `Server_AI_Com_Upgrade.sqf`; adds new `Server/AI/Commander` runtime. |
| [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15) | WF menu ops-console reskin | Closed | Alternative UI direction only; cherry-pick ideas later if wanted. | Closed 2026-06-05. Conflicts with PR #16 in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for both Chernarus and Takistan. |
| [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16) | WF menu UX phase 1, original style | Closed | Included in `dev/pr8-plus-testbed` lab branch; PR itself is closed. | Closed 2026-06-05. Clean merge on top of PR8+12; less brand-opinionated than PR #15. |
| [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Quad AI commander docs | Open | Docs/concept only. Keep as reference, not gameplay merge material. | 23 docs/wiki files, no code. |
| [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18) | AI commander logs | Open | Stacked AI commander experiment. Keep with PR #14 chain. | Base is `feat/ai-commander`; conflicts in same commander upgrade function on PR8 lab. |
| [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | AI commander context beliefs | Closed | Treat as closed branch/context evidence for the PR #14/#18 AI commander chain. | Closed 2026-06-05. Base was `codex/ai-commander-logs`; conflicts in same commander upgrade function on PR8 lab. |

## Cleanup Actions

Recommended PR board cleanup:

1. Already closed/superseded on the board: PR #1, #5, #6, #7, #10, #11, #12, #15, #16 and #19.
2. Keep docs-only outside gameplay testing: PR #17. Treat PR #2 and PR #3 as closed historical docs work.
3. Test now: PR #8, then `dev/pr8-plus-testbed`.
4. Test separately later: PR #4 player stats, PR #9 Zargabad, PR #13 drone/recon UAV and PR #14/#18 AI commander chain.
5. WF menu direction is no longer an open PR-board choice: PR #16-style original UX lives in `dev/pr8-plus-testbed`; PR #15 is a closed alternative branch whose style ideas can be cherry-picked later only after visual smoke.

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

PR #18 assumes the PR #14 runtime. PR #19 is now closed but still useful as context/belief evidence for that family. The chain is not perfectly linear by ancestry, so build a dedicated `ai-commander-lab` branch instead of merging directly into PR8. The repeated hard conflict is:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

The conflict is around AI commander upgrade debit/cost handling. There are no automated tests for no-human commander mode, human-assist mode, upgrade-spend correctness, smoke/JIP handoff, or context-belief output, so this needs a manual lab and telemetry-first review.

### PR #15 vs PR #16 UI

PR #16 remains the safer default because it is smaller, keeps the existing visual contract and focuses on SafeZone/layout/grouping improvements. PR #15 is a broader visual reskin. Both PRs are now closed on the board, so this section is branch-afterlife guidance:

- PR #15 changes shared style/resource/title files, GUI structured-text colors, and adds `brand_chevron.jpg`.
- PR #16 rewrites the main WF menu layout and shared resources in a lower-risk way and is represented in `dev/pr8-plus-testbed`.
- Both overlap in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for Chernarus and Takistan.

Do not revive both blindly. Cherry-pick PR #15 ideas later only after PR #16-style UI is tested: style tokens, title typography, structured-text color polish and optional branding/footer assets.

## Test Notes For Discord

Short version to share:

```text
PR8 is the baseline bundle.
PR8 already contains or supersedes PR1/5/6/7/10/11, so those are closed/superseded.

Two branches are ready:
- dev/pr8-only-testbed: PR8 only
- dev/pr8-plus-testbed: PR8 + closed PR12 quick fixes + closed PR16 WF menu UX

Keep separate for now:
- PR4 player stats: real but WIP
- PR9 Zargabad: real but huge map/content import
- PR13 drone/recon UAV: real but conflicts with PR8 UI/UAV files
- PR14/18 AI commander: real but experimental stacked chain; PR19 is closed context evidence
- PR15 ops-console UI: closed alternate to PR16, cherry-pick ideas only
```

## Validation Performed

- Fetched `origin` and `miksuu`, including PR refs during the original pass. A later prune removed synthetic PR refs; current refresh uses GitHub PR metadata and branch heads.
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
