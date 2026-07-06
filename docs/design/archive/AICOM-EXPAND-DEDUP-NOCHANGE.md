# AICOM Expand Dedup No-Change Verification

<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: Block M lane 330
Base checked: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`
Verdict: no mission source change is needed.

## Finding

The lane prompt warned that expansion-lane teams can each run an independent
nearest-reachable search over the same neutral-town pool, dogpiling the closest neutral
town while farther neutral towns remain untouched. The current Build84 allocator already
contains the intended local claim list and opt-in flag.

## Evidence

| Area | Source anchor | Result |
| --- | --- | --- |
| Claim state | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:306-309` | `_expandClaimed` is declared and initialized once per allocation tick. |
| Dedup flag | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:317` | `_dedupOn` reads `WFBE_C_AICOM_EXPAND_DEDUP`. |
| Claimed-town exclusion | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:351-353` | The nearest-reachable expand target scan excludes towns already in `_expandClaimed` when dedup is enabled. |
| Claim recording | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:359-360` | Each selected expand target is appended to `_expandClaimed` for later teams in the same tick. |
| Flag registration | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:698` | `WFBE_C_AICOM_EXPAND_DEDUP` is registered default `0`, preserving the current guide's default-off rule. |
| Mirror parity | Takistan and Zargabad allocator lines `306-360`, constants line `698` | The maintained Vanilla mirrors carry the same opt-in dedup implementation and default-off registration. |

This means the lane 330 behavior is already present and gated. The prompt text requested
default `1`, but `AGENTS.md` / GUIDE-REV `GR-2026-07-03a` requires new behavior to stay
default-off until the owner flips it after grading, so the current default `0` is correct
for a draft-lane implementation.

## Why This Is Docs-Only

Changing the allocator again would duplicate the current `_expandClaimed` path and add
unnecessary churn to a hot AICOM file with multiple active allocator PRs. The only
remaining decision is whether the owner wants to flip `WFBE_C_AICOM_EXPAND_DEDUP` on after
grading; that is explicitly outside this no-change verification.

## Validation

- Refreshed `origin/claude/build84-cmdcon36` before checking evidence.
- Read maintained Chernarus, Takistan and Zargabad allocator and constants anchors.
- Checked for exact lane330 / `EXPAND_DEDUP` open PRs.
- Checked remote branches for lane330 / expand-dedup names.
- Checked wiki coordination for a lane330 owner.
- No mission source files were edited.
- LoadoutManager was not run because this is a docs-only verification.

## Out Of Scope

- Enabling `WFBE_C_AICOM_EXPAND_DEDUP` by default.
- Changing expand, harass, fist or field-order assignment.
- Editing `AI_Commander_Allocate.sqf` or `Init_CommonConstants.sqf`.
- Adding new lobby constants or defaults.
