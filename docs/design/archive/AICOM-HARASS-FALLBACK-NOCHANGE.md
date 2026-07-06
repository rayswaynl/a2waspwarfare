# AICOM Harass Fallback No-Change Verification

<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: Block M lane 331
Base checked: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`
Verdict: no mission source change is needed.

## Finding

The lane prompt warned that harass assignment can pick the deepest rear town even when
that town is globally unreachable by mounted teams, leaving harass quota unused instead
of falling back to the next reachable rear target. Current Build84 already contains the
opt-in fallback path for this behavior.

## Evidence

| Area | Source anchor | Result |
| --- | --- | --- |
| Fallback flag | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:215` | The harass target selection enters the fallback path when `WFBE_C_AICOM_HARASS_FALLBACK` is enabled. |
| Mounted-team reach pre-scan | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:218-238` | Eligible mounted AI teams are filtered before target selection and their leader positions are cached for reach tests. |
| Depth-sorted candidates | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:240-258` | Candidate rear towns are scored by depth and insertion-sorted deepest first with Arma 2 OA-safe SQF. |
| Reachable fallback walk | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:259-276` | The sorted list is walked until the deepest town reachable by at least one mounted team is selected. |
| Skip telemetry | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:277-278` | `AICOMSTAT|v2|EVENT|HARASS_SKIP` logs the skipped first candidate and the reachable target that replaced it. |
| Default-off registration | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:699` | `WFBE_C_AICOM_HARASS_FALLBACK` is registered default `0`, preserving the guide's default-off behavior rule. |
| Mirror parity | Takistan and Zargabad allocator lines `215-281`, constants line `699` | The maintained Vanilla mirrors carry the same fallback implementation, telemetry and default-off registration. |

This means lane 331 is already implemented as a gated behavior. With the flag off, the
legacy deepest-pick path remains intact; with the flag on, the allocator walks the
depth-sorted candidate list and chooses the deepest target reachable by the mounted
detachment.

## Why This Is Docs-Only

Editing `AI_Commander_Allocate.sqf` again would duplicate the existing
`WFBE_C_AICOM_HARASS_FALLBACK` path and add churn to a hot allocator file with active
Build84 PRs nearby. The remaining owner decision is whether to flip the flag on after
grading; that is outside this no-change verification.

## Validation

- Refreshed `origin/claude/build84-cmdcon36` before checking evidence.
- Re-read the maintained Chernarus, Takistan and Zargabad allocator anchors.
- Re-read the maintained Chernarus, Takistan and Zargabad constants anchors.
- Checked for exact lane331 / lane 331 / harass-fallback open PRs.
- Checked remote branches for lane331 / harass fallback names.
- Checked wiki coordination for a fleet-lane-331 owner before claiming this lane.
- Confirmed adjacent PR #579 is `HARASS_UNMET` telemetry, not this fallback behavior.
- No mission source files were edited.
- LoadoutManager was not run because this is a docs-only verification.

## Out Of Scope

- Enabling `WFBE_C_AICOM_HARASS_FALLBACK` by default.
- Changing harass quota, mounted eligibility, fist assignment or expand assignment.
- Editing `AI_Commander_Allocate.sqf` or `Init_CommonConstants.sqf`.
- Adding new lobby constants or defaults.
