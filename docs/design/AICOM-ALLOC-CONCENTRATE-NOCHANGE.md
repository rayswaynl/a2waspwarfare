# AICOM Allocator Concentrate Telemetry No-Change Verification

<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: Block M lane 333
Base checked: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`
Verdict: no mission source change is needed.

## Finding

The lane prompt asked for the AICOM allocator's end-of-tick `ALLOC` telemetry to expose
whether concentrate mode suppressed expand and harass assignment. The current Build84
source already does this in all maintained `AI_Commander_Allocate.sqf` mirrors.

## Evidence

| Area | Source anchor | Result |
| --- | --- | --- |
| Concentrate gate | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:187-188` | `_concentrate` is set from `WFBE_C_AICOM_CONCENTRATE_TOWNS`, then zeroes `_expandN` and `_harassN`. |
| Field-order override | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:196-199` | SPLIT can clear `_concentrate`; MASS can force it true, so the final flag reflects player-order overrides. |
| ALLOC telemetry | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:521` | The `AICOM2|v1|ALLOC` line already appends `|concentrate=` plus `str _concentrate`. |
| Mirror parity | Takistan and Zargabad `AI_Commander_Allocate.sqf:187-188,196-199,521` | The maintained Vanilla mirrors carry the same concentrate gate, overrides and `ALLOC` field. |

The current `ALLOC` line therefore distinguishes a normal zero-expand tick from a
concentrate-mode suppression tick without adding a new flag, constant or behavior path.

## Why This Is Docs-Only

Adding another telemetry field would duplicate the existing `|concentrate=` output and
make the soak parser surface noisier without increasing observability. Editing
`AI_Commander_Allocate.sqf` would also collide with active allocator work for nearby lanes,
while the current base already satisfies lane 333.

## Validation

- Refreshed `origin/claude/build84-cmdcon36` before checking evidence.
- Read the maintained Chernarus, Takistan and Zargabad allocator anchors.
- Checked for exact lane333 / lane 333 / concentrate-mode open PRs.
- Checked remote branches for lane333 / concentrate names.
- Checked wiki coordination for a fleet-lane-333 owner.
- No mission source files were edited.
- LoadoutManager was not run because this is a docs-only verification.

## Out Of Scope

- Changing AICOM allocation behavior.
- Changing expand, harass, fist or field-order assignment.
- Editing `AI_Commander_Allocate.sqf`.
- Adding new lobby constants or defaults.
