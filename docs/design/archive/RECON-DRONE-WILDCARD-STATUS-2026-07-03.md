# Recon-Drone Wildcard Status - 2026-07-03

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Lane: fleet lane 9, docs-only routing audit.

## Scope

Fleet lane 9 asks for the dormant recon-drone wildcard pair from
`docs/design/UNUSED-ASSETS.md`:

- Row 1: WEST-facing Ka-137 recon-drone wildcard using `Ka137_PMC` /
  `Ka137_MG_PMC` context.
- Row 11: EAST mirror using `Pchela1T`.

This audit does not add or change mission source. It records current open draft
PR coverage and the review gates that remain before the recon-drone source lane
can be considered safe.

## Verdict

Do not open a second source implementation for lane 9 while PR #287 is open.

PR #287 already implements the Ka-137/Pchela recon-drone wildcard pair as W25/W26
behind default-off `WFBE_C_AICOM_DRONE_RECON`. It targets
`claude/build84-cmdcon36`, is an open draft PR, and reports CLEAN/MERGEABLE.

This is not merge approval. PR #287 edits `AI_Commander_Wildcard.sqf`, which is
on tonight's avoid list, and the visible diff only touches Chernarus and
Takistan. Because the current target now includes Zargabad, source review should
require an explicit Zargabad propagation decision before that PR is treated as
complete.

## Coverage Table

| Prompt asset | Source proposal | Current draft PR | Coverage status |
| --- | --- | --- | --- |
| Ka-137 recon drone | `UNUSED-ASSETS.md:31` proposes a Ka-137 wildcard that orbits the enemy spearhead for about 180 seconds and reveals enemies. | PR #287, branch `fable/aicom-recon-drone-wildcard`, adds W25 and default-off `WFBE_C_AICOM_DRONE_RECON = 0`. | Covered by an open source PR; review hot-file and terrain propagation before merge. |
| Pchela-1T EAST mirror | `UNUSED-ASSETS.md:41` proposes the EAST counterpart so both AI commanders can call a UAV. | PR #287 adds W26 and uses `Pchela1T` for EAST. | Covered by the same source PR; review class availability and parity. |

## PR #287 Evidence

PR: https://github.com/rayswaynl/a2waspwarfare/pull/287

- State at audit time: open draft, base `claude/build84-cmdcon36`, CLEAN and
  MERGEABLE.
- Files changed: `Init_CommonConstants.sqf` and `AI_Commander_Wildcard.sqf` in
  Chernarus and Takistan.
- Registers `WFBE_C_AICOM_DRONE_RECON = 0` and
  `WFBE_C_AICOM_DRONE_TTL = 180`.
- Adds W25/W26 recon-drone cards, rare weights, eligibility checks, and a
  per-side anti-stack latch named `wfbe_aicom_drone_active_<side>`.
- Spawns a drone, moves a pilot into it, sets recon-only behavior, reveals nearby
  enemy units every loop with the A2-safe two-operand `reveal`, and self-despawns
  after the configured TTL.

## Review Notes

- Keep PR #287 as the owner of the source work. A duplicate source lane would
  overlap the same wildcard deck and constants.
- Before merge, re-check the branch against current `claude/build84-cmdcon36`
  expectations for all maintained roots, including Zargabad.
- Preserve the default-off gate. At `WFBE_C_AICOM_DRONE_RECON = 0`, W25/W26
  should remain inert.
- Review the server-local reveal loop in Arma 2 OA, especially drone locality,
  pilot cleanup, marker lifetime, and anti-stack reset on early failure paths.
- Source changes to `AI_Commander_Wildcard.sqf` remain out of scope for this
  docs-only lane because that file is currently hot.

## Verification

- `gh pr view 287` confirmed PR #287 targets `claude/build84-cmdcon36`, is an
  open draft PR, and reports CLEAN/MERGEABLE.
- `gh pr diff 287` confirmed the expected default-off constants, W25/W26
  wildcard additions, Ka-137/Pchela classes, TTL/reveal loop, and anti-stack
  latch.
- `rg` confirmed the dormant-asset source rows in `UNUSED-ASSETS.md`.
- This lane changed documentation only. No SQF/SQM/HPP/EXT mission files changed.
- LoadoutManager was not run because no mission source changed.
