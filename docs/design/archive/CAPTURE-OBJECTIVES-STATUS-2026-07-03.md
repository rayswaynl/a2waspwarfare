# Capture Objectives Status - 2026-07-03

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Lane: fleet lane 13, docs-only routing audit.

## Scope

Fleet lane 13 asks for two dormant capture objectives from
`docs/design/UNUSED-ASSETS.md`:

- Row 6: a one-off capturable T-34 "museum piece" parked at a neutral objective.
- Row 7: a neutral artillery-cache objective based on GRAD, D-30, and mortar assets.

This audit does not add or change mission source. It records current open draft PR
coverage so the fleet does not open a third overlapping source implementation.

## Verdict

Do not reimplement lane 13 as a fresh source lane while PR #370 and PR #388 are
open.

The T-34 half is covered by PR #388. The artillery-cache half is covered by PR
#370, but with a narrower default shape than the original dormant-asset row:
the PR currently stages one configurable static gun rather than the full
GRAD + D-30 + mortar park. If that narrower shape is accepted, lane 13 is
functionally covered. If not, the follow-up should be an artillery-cache
expansion/review only, not a new T-34 objective.

## Coverage Table

| Prompt asset | Source proposal | Current draft PR | Coverage status |
| --- | --- | --- | --- |
| T-34 museum piece | `UNUSED-ASSETS.md:36` proposes a one-off capturable T-34 parked at a neutral objective. | PR #388, branch `codex/lane183-t34-relic-capturable`, adds `Server_T34Relic.sqf` plus default-off `WFBE_C_T34_RELIC_ENABLE = 0`. | Covered, with implementation class `T34_TK_GUE_EP1` instead of the proposal's `T34_TK_EP1`. Review class choice, not lane ownership. |
| Artillery cache | `UNUSED-ASSETS.md:37` proposes a neutral abandoned artillery park using GRAD, D-30, and mortar assets. | PR #370, branch `fable/arty-cache-objective`, adds `Server_ArtyCache.sqf` plus default-off `WFBE_C_ARTY_CACHE = 0`. | Covered as a narrower static-gun objective. Review whether single `D30_CDF` default is enough or whether the full park should remain a follow-up. |

## PR Evidence

PR #388: https://github.com/rayswaynl/a2waspwarfare/pull/388

- State at audit time: open draft, base `claude/build84-cmdcon36`, CLEAN and
  MERGEABLE.
- Adds `Server/Server_T34Relic.sqf` in Chernarus, Takistan, and Zargabad, and
  launches it from `Server/Init/Init_Server.sqf` only when
  `WFBE_C_T34_RELIC_ENABLE > 0`.
- Registers default-off constants for class, start delay, spawn radius, and fuel.
- Keeps the relic neutral until the first live WEST/EAST/GUER crew side claims
  it, then stamps ownership and normal vehicle killed/hit handling.

PR #370: https://github.com/rayswaynl/a2waspwarfare/pull/370

- State at audit time: open draft, base `claude/build84-cmdcon36`, CLEAN and
  MERGEABLE.
- Adds `Server/Server_ArtyCache.sqf` in Chernarus, Takistan, and Zargabad, and
  launches it from `Server/Init/Init_Server.sqf` only when
  `WFBE_C_ARTY_CACHE == 1`.
- Registers default-off constants for the static-gun class, position, capture
  radius, scan interval, first-capture supply bonus, and optional gun transfer.
- Defaults to a single `D30_CDF` static gun with presence-scan capture logic,
  not the full GRAD + D-30 + mortar asset mix from the dormant-asset sketch.

## Review Notes

- Keep the two source PRs separate. They touch the same launch/default files
  but implement different objectives.
- Treat this note as a routing guard, not merge approval. Both source PRs still
  need their own gameplay review and in-engine smoke.
- If PR #370 is revised, preserve the default-off gate and group-budget caution
  around optional crew transfer.
- If PR #388 is revised, preserve the neutral-before-claim behavior so the relic
  does not mint bounty handlers before a real side owns it.

## Verification

- `gh pr view` confirmed PR #370 and PR #388 target `claude/build84-cmdcon36`,
  are open draft PRs, and report CLEAN/MERGEABLE.
- `gh pr diff` scans confirmed the expected default-off constants, launch hooks,
  and added server scripts for both objectives.
- `rg` confirmed the dormant-asset source rows in `UNUSED-ASSETS.md`.
- This lane changed documentation only. No SQF/SQM/HPP/EXT mission files changed.
- LoadoutManager was not run because no mission source changed.
