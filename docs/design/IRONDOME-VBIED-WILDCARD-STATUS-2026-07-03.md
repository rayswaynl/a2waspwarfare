# Iron Dome / VBIED Wildcard Status - 2026-07-03

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Lane: fleet lane 10, docs-only partial-status audit.

## Scope

Fleet lane 10 asks for two inert wildcard cards to be revived behind defaults:

- W14 Iron Dome / AA-pod dome.
- W21 GUER VBIED, for AI or losing-side use only.

This audit does not add or change mission source. It records which half already
has an open source draft, which half remains open, and why this lane should not
touch hot wildcard source tonight.

## Verdict

Lane 10 is partially covered, not complete.

W14 Iron Dome has open draft PR #357, but that PR is stacked on
`fable/aicom-recon-drone-wildcard`, not directly on `claude/build84-cmdcon36`.
Its visible diff only touches Chernarus and Takistan. Since the current target
now has Zargabad maintained roots, PR #357 needs rebasing/retargeting and an
explicit Zargabad propagation decision before it can be treated as ready.

W21 GUER VBIED wildcard revival does not have a matching open source PR in the
current search. Related VBIED work exists, but it is not the same lane:

- PR #413 adds a default-off two-click confirmation for player VBIED detonation.
- Earlier B75/B745-B750 docs route factory/structure reward and authority work.
- Closed wildcard-deck branches #112/#113 are not current target W21 revival.

Do not open duplicate W14 source work. If source work resumes, split it into:

1. Review/rebase/propagate PR #357 for W14.
2. A separate W21-only source lane after hot wildcard-file pressure clears.

## Coverage Table

| Prompt card | Source evidence | Current draft/source status | Lane status |
| --- | --- | --- | --- |
| W14 Iron Dome | `UNUSED-ASSETS.md:23` lists W14 as an inert wildcard card; `UNUSED-ASSETS.md:83` identifies W14 Iron Dome as AA-pod based. | PR #357, branch `fable/wildcard-irondome`, adds default-off `WFBE_C_WILDCARD_IRON_DOME = 0` and changes W14 weight from forced `0` to weight `7` when enabled. | Partially covered by stacked draft PR; needs direct-target review, hot-file coordination, and Zargabad decision. |
| W21 GUER VBIED | `UNUSED-ASSETS.md:32` proposes reviving W21 for AI GUER/losing-side use; `UNUSED-ASSETS.md:81` lists W21 as inert weight-0. | No matching open current-target W21 revival PR found. PR #413 is detonation-confirm UX, not wildcard revival. | Still open future source work. |

## PR #357 Evidence

PR: https://github.com/rayswaynl/a2waspwarfare/pull/357

- State at audit time: open draft, base `fable/aicom-recon-drone-wildcard`,
  CLEAN and MERGEABLE relative to that stacked base.
- Files changed: `Init_CommonConstants.sqf` and `AI_Commander_Wildcard.sqf` in
  Chernarus and Takistan.
- Adds `WFBE_C_WILDCARD_IRON_DOME = 0`.
- Changes W14 from forced zero to a dark-by-default gate:
  `missionNamespace getVariable ["WFBE_C_WILDCARD_IRON_DOME", 0]`, using weight
  `7` only when enabled.
- Leaves W21 as forced zero in the same wildcard weight block.

## Review Notes

- `AI_Commander_Wildcard.sqf` is currently hot. This docs-only lane deliberately
  avoids touching it.
- PR #357's base matters: it is stacked on the recon-drone branch, so reviewers
  should inspect the combined W25/W26 + W14 wildcard deck shape before merging.
- PR #357 currently omits Zargabad. That may have been correct before Zargabad
  became a maintained root, but it needs an explicit current-target answer now.
- W21 should not be smuggled into an Iron Dome rebase. Keep W21 as its own
  default-off source lane so VBIED authority, target selection, and player-side
  action interaction can be reviewed without mixing in W14.

## Verification

- `gh pr view 357` confirmed PR #357 is an open draft PR with base
  `fable/aicom-recon-drone-wildcard`, CLEAN/MERGEABLE relative to that base, and
  four changed Chernarus/Takistan files.
- `gh pr diff 357` confirmed the default-off Iron Dome constant and W14 weight
  gate while W21 remains forced zero.
- `gh pr list --state all --search "W21 VBIED wildcard"` found no matching open
  current-target W21 revival PR.
- `rg` confirmed the W14 and W21 source rows in `UNUSED-ASSETS.md`.
- This lane changed documentation only. No SQF/SQM/HPP/EXT mission files changed.
- LoadoutManager was not run because no mission source changed.
