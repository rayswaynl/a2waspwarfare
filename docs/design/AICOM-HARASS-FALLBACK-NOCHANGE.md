# AICOM Harass Fallback No-Change Audit

Lane 331 audit, 2026-07-03. The prompt requested a fallback for the M2 harass target when the deepest enemy
rear town is outside every mounted team's reach. Current `claude/build84-cmdcon36` already contains that fix,
merged through PR #535 (`block-m-allocate-pair`), so no mission SQF change is needed in this lane.

## Source Status

The implementation is present in all maintained mission copies.

- Flag: `WFBE_C_AICOM_HARASS_FALLBACK` defaults to `0` in `Common/Init/Init_CommonConstants.sqf:699`.
- Guarded path: `AI_Commander_Allocate.sqf:215-280` runs only when the flag is greater than zero.
- Mounted-team pre-scan: `AI_Commander_Allocate.sqf:218-238` caches eligible mounted team leader positions.
- Candidate walk: `AI_Commander_Allocate.sqf:240-276` depth-sorts candidate towns and selects the deepest one
  reachable by at least one mounted team.
- Telemetry: `AI_Commander_Allocate.sqf:277-279` emits `AICOMSTAT|v2|EVENT|HARASS_SKIP` when the first pick is
  discarded.
- Legacy behavior: `AI_Commander_Allocate.sqf:280+` remains available while the flag is default-off.

## Why This Satisfies The Lane

The prompt asked for three concrete pieces:

1. Cache mounted-team positions before target selection.
2. Walk `_tgtTowns` by depth descending until a reachable harass target is found.
3. Emit `HARASS_SKIP` when the initial deepest target is discarded.

All three are already present. The implementation also preserves the old single deepest-town selection behind
the default `WFBE_C_AICOM_HARASS_FALLBACK = 0`, so this remains an owner-flip behavioral feature rather than a
silent live behavior change.

## Verification

- Open PR search found no active lane 331 PR.
- All-state PR search found merged PR #535, `[block-m] ALLOCATE PAIR: expansion dedup + harass fallback`.
- Remote branch scan found no current `lane331` or harass-fallback branch.
- Brain scan found no active or released lane 331 record before this audit claim.
- Source scan found `WFBE_C_AICOM_HARASS_FALLBACK` and `HARASS_SKIP` mirrored across Chernarus, Vanilla
  Takistan, and Vanilla Zargabad.

## Follow-Up

No code follow-up is required for lane 331. The remaining product decision is when to flip
`WFBE_C_AICOM_HARASS_FALLBACK` from `0` to `1` after the owner wants the behavior active in live matches.
