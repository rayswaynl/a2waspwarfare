# PR Cleanup And Integration Lab

Last updated: 2026-06-05.

This page tracks the June 2026 PR cleanup pass for `rayswaynl/a2waspwarfare`. It exists so humans and AI agents can see which PRs are real features, which are superseded by the release bundle, which are docs-only, and which branches should be tested together.

## Branches Created

| Branch | Contents | Use |
| --- | --- | --- |
| [`dev/pr8-only-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-only-testbed) | Exact PR #8 tip, based on `release/2026-06-feature-bundle` / `origin/pr/8`. | Clean PR8-only multiplayer test baseline. |
| [`dev/pr8-plus-testbed`](https://github.com/rayswaynl/a2waspwarfare/tree/dev/pr8-plus-testbed) | PR #8 + resolved PR #12 + PR #16. | Combined test branch for bundle plus quick fixes plus original-style WF menu UX. |

## Main Recommendation

Use PR #8 as the release bundle baseline. It already contains PR #1, PR #5, PR #6, PR #7, PR #10, and PR #11 by ancestry, so those standalone PRs should not be merged separately.

The best current combined gameplay test branch is:

```text
dev/pr8-plus-testbed = PR #8 + PR #12 + PR #16
```

Keep PR #4, PR #9, PR #13, and PR #14/#18/#19 separate until they have their own focused test windows.

## PR Triage Matrix

| PR | Title / branch | Status | Recommendation | Evidence |
| --- | --- | --- | --- | --- |
| [#1](https://github.com/rayswaynl/a2waspwarfare/pull/1) | Supply helicopters | Closed | Superseded by PR #8. | `origin/pr/1` is an ancestor of `origin/pr/8`. |
| [#2](https://github.com/rayswaynl/a2waspwarfare/pull/2) | Developer wiki mirror | Open | Keep as docs PR, not gameplay test material. | 175 files, mostly `docs/wiki`; includes wiki mirror tooling and docs. |
| [#3](https://github.com/rayswaynl/a2waspwarfare/pull/3) | Claude wiki review | Open | Keep stacked on PR #2 or fold into docs branch later. | Docs-heavy branch based on `docs/developer-wiki-index`. |
| [#4](https://github.com/rayswaynl/a2waspwarfare/pull/4) | Player stats phase 1 WIP | Open | Real feature, but keep separate from PR8 release test. | Clean merge candidate on top of PR8+12+16; adds DiscordBot stats pipeline and mission stat flush hooks. |
| [#5](https://github.com/rayswaynl/a2waspwarfare/pull/5) | Upgrade queue | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#6](https://github.com/rayswaynl/a2waspwarfare/pull/6) | Engineer EASA repair truck | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#7](https://github.com/rayswaynl/a2waspwarfare/pull/7) | Delayed vehicle damage rewards | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#8](https://github.com/rayswaynl/a2waspwarfare/pull/8) | June 2026 feature bundle | Open | Treat as primary release bundle. | 72 mission files; contains supply heli, WDDM positions, upgrade queue, EASA/QoL, rewards, fixes. |
| [#9](https://github.com/rayswaynl/a2waspwarfare/pull/9) | Zargabad low-pop mission | Open | Real feature, but separate map-content test branch. | Clean merge candidate, but huge: 832 files and 77k+ insertions. |
| [#10](https://github.com/rayswaynl/a2waspwarfare/pull/10) | Commander buildable positions | Closed | Superseded by PR #8. | Ancestor of PR #8. |
| [#11](https://github.com/rayswaynl/a2waspwarfare/pull/11) | Buy-menu/EASA QoL | Open | Close or mark superseded by PR #8 after confirming PR #8 test passes. | `origin/pr/11` is an ancestor of `origin/pr/8`. |
| [#12](https://github.com/rayswaynl/a2waspwarfare/pull/12) | Quick-wins fixes | Open | Merged into `dev/pr8-plus-testbed`; needs focused server/economy smoke test. | Conflicted in five Chernarus files, resolved by preserving PR8 behavior plus PR12 fixes. |
| [#13](https://github.com/rayswaynl/a2waspwarfare/pull/13) | Recon UAV | Open | Real feature train, but do not combine casually with PR8. | Brings drone saturation strike stack; conflicts in tactical menu, UAV module deletion, and parameters. |
| [#14](https://github.com/rayswaynl/a2waspwarfare/pull/14) | AI Commander draft | Open | Keep experimental. Test alone or after commander-specific review. | Conflicts in `Server_AI_Com_Upgrade.sqf`; adds new `Server/AI/Commander` runtime. |
| [#15](https://github.com/rayswaynl/a2waspwarfare/pull/15) | WF menu ops-console reskin | Open | Alternative UI direction. Do not merge with PR #16 without design decision. | Conflicts with PR #16 in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for both Chernarus and Takistan. |
| [#16](https://github.com/rayswaynl/a2waspwarfare/pull/16) | WF menu UX phase 1, original style | Open | Included in `dev/pr8-plus-testbed`. | Clean merge on top of PR8+12; less brand-opinionated than PR #15. |
| [#17](https://github.com/rayswaynl/a2waspwarfare/pull/17) | Quad AI commander docs | Open | Docs/concept only. Keep as reference, not gameplay merge material. | 23 docs/wiki files, no code. |
| [#18](https://github.com/rayswaynl/a2waspwarfare/pull/18) | AI commander logs | Open | Stacked AI commander experiment. Keep with PR #14 chain. | Base is `feat/ai-commander`; conflicts in same commander upgrade function on PR8 lab. |
| [#19](https://github.com/rayswaynl/a2waspwarfare/pull/19) | AI commander context beliefs | Open | Stacked AI commander experiment. Keep with PR #14/#18 chain. | Base is `codex/ai-commander-logs`; conflicts in same commander upgrade function on PR8 lab. |

## Cleanup Actions

Recommended PR board cleanup:

1. Close or label as superseded: PR #1, #5, #6, #7, #10, #11.
2. Keep docs-only outside gameplay testing: PR #2, #3, #17.
3. Test now: PR #8, then `dev/pr8-plus-testbed`.
4. Test separately later: PR #4 player stats, PR #9 Zargabad, PR #13 drone/recon UAV, PR #14/#18/#19 AI commander chain.
5. Pick one WF menu direction: PR #16 for original-style UX, or PR #15 for ops-console reskin. They overlap enough that both should not be merged blindly.

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

PR #18 and PR #19 assume the PR #14 runtime. The chain is not perfectly linear by ancestry, so build a dedicated `ai-commander-lab` branch instead of merging directly into PR8. The repeated hard conflict is:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

The conflict is around AI commander upgrade debit/cost handling. There are no automated tests for no-human commander mode, human-assist mode, upgrade-spend correctness, smoke/JIP handoff, or context-belief output, so this needs a manual lab and telemetry-first review.

### PR #15 vs PR #16 UI

PR #16 remains the safer default because it is smaller, keeps the existing visual contract, and focuses on SafeZone/layout/grouping improvements. PR #15 is a broader visual reskin:

- PR #15 changes shared style/resource/title files, GUI structured-text colors, and adds `brand_chevron.jpg`.
- PR #16 rewrites the main WF menu layout and shared resources in a lower-risk way.
- Both overlap in `Rsc/Dialogs.hpp` and `Rsc/Ressources.hpp` for Chernarus and Takistan.

Do not merge both blindly. Cherry-pick PR #15 ideas later only after PR #16 is tested: style tokens, title typography, structured-text color polish, and optional branding/footer assets.

## Test Notes For Discord

Short version to share:

```text
PR8 is the baseline bundle.
PR8 already contains PR1/5/6/7/10/11, so those can be treated as superseded.

Two branches are ready:
- dev/pr8-only-testbed: PR8 only
- dev/pr8-plus-testbed: PR8 + PR12 quick fixes + PR16 WF menu UX

Keep separate for now:
- PR4 player stats: real but WIP
- PR9 Zargabad: real but huge map/content import
- PR13 drone/recon UAV: real but conflicts with PR8 UI/UAV files
- PR14/18/19 AI commander: real but experimental stacked chain
- PR15 ops-console UI: alternate to PR16, not both
```

## Validation Performed

- Fetched `origin` and `miksuu`, including PR refs.
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
