# AICOM V2 Cutover Soak Program — Retired

Guide-Rev: GR-2026-07-08a

Status: **RETIRED — historical plan, not an executable runbook**

Original owner authorization: Ray, 2026-07-06
Retirement basis: Fleet task `wasp-aicom-v2-cutover-doc-reconcile`, re-readied by the owner-directed queue audit on 2026-07-11

> Do not use this file to build, deploy, restore, or operate a server. The relevant AICOM2 machinery
> was integrated through a different path; the one-shot branch/flag workflow was superseded, and the
> full V1 removal described by the old plan did not occur as written. This file grants no runtime or
> live-host authority. A current, claimed Fleet task must supply scope, host authority, rollback,
> evidence gates, and an owner decision before any new soak or release action.

## Why the old runbook was retired

The previous revision was a transition plan for rebasing `fable/v2-cutover`, building a special
PBO, and switching a supposed global `WFBE_C_AICOM_V2_ENABLE` lobby flag. That no longer matches
the repository:

- No maintained source or lobby parameter named `WFBE_C_AICOM_V2_ENABLE` exists on current
  `master`. The supposed flag is also absent from the tips of the #760, #788, and #793 cutover
  branches; it was not a landed switch that was later removed.
- AICOM2 Snapshot, Allocator, and Decapitate are integrated into the normal commander loop. The
  functions are compiled directly by `Server/Init/Init_Server.sqf` and called on eligible strategy
  cadence by `Server/AI/Commander/AI_Commander.sqf`.
- Allocator and Decapitate have separate source constants, separate consumers, and different
  flag-off behavior. Neither is a global V1/V2 switch.
- The old `cc48` restore instructions, box paths, server commands, threshold snapshot, and
  `fable/v2-cutover` rebase checklist are historical. Reusing them would bypass current source,
  fixes, Fleet ownership, and deployment authority.

The historical text remains recoverable from Git. At repository snapshot
`bb79a88aa65f491a5c5d3d3d610c4e60237eb4b7`, its blob is
`71e7ddd01f38ddcdf21f382a5a3cfebc92b8e8c7`. The canonical 14,010-byte Git blob has SHA-256
`43B414A7838A4DDE9D06938F2726B2CF9FCCAE8CA05B4250BC4A42F7D152A9C7`; the previous 14,233-byte
Windows CRLF checkout has SHA-256
`6230ED334ADEF92F5B6905F14FACE9779343E73C429CEA1200CBA375BDF82ED5`.

## Current integrated controls

The paths and line numbers below are anchored to `master` snapshot `bbab122f0` observed during
the reconciliation. Revalidate them against the current head before future work.

| Subsystem | Current default | Authoritative behavior |
|---|---:|---|
| Snapshot | no subsystem flag | `Init_Server.sqf:82` compiles M0 Snapshot unconditionally; `AI_Commander.sqf:620-621` calls it before Strategy when the strategy path and cadence are eligible. It has no global cutover flag. |
| Allocator | `WFBE_C_AICOM2_ALLOCATE_ENABLE = 1` | Initialized to `1` when nil in `Common/Init/Init_CommonConstants.sqf:774`. At `0`, `AI_Commander_Allocate.sqf:25` exits before writing allocation state, and `AI_Commander_AssignTowns.sqf:749-762` ignores allocator targets unless the flag is positive. Legacy Strategy/AssignTowns target selection remains active. |
| Decapitate | `WFBE_C_AICOM2_DECAP_ENABLE = 1` | Initialized to `1` when nil in `Init_CommonConstants.sqf:796`. At `0`, Decapitate may still maintain sensing/state and emit telemetry, but `AI_Commander_Decapitate.sqf:193-245` performs no press-stamp or allocation-target writes and clears existing press stamps. `AI_Commander_Strategy.sqf:753-804` enables the legacy HQ-strike block while the flag is non-positive. |

Allocator, Decapitate, and AirResp are compiled unconditionally at `Init_Server.sqf:83-85`. They are invoked
after Strategy at `AI_Commander.sqf:620-629` only when `_aiStrategy` is true and the strategy cadence
is due; their internal gates then control their own behavior. There are no
`class WFBE_C_AICOM2_ALLOCATE_ENABLE`, `class WFBE_C_AICOM2_DECAP_ENABLE`, or
`class WFBE_C_AICOM2_AIRRESP_ENABLE` entries in
`Rsc/Parameters.hpp`, so these are not the lobby controls described by the retired plan.

Source comments that still mention an older default do not override the executable assignments
above. The current assignments are `1` for both controls.

## Exact rollback semantics

There is no supported one-flag rollback to a byte-identical `cc48` or V1 mission.

- Allocator rollback is scoped: on a fresh mission built with `WFBE_C_AICOM2_ALLOCATE_ENABLE = 0`,
  the allocator is inert and the legacy town-target selection path remains active. A hot flip may
  leave allocator state from earlier ticks, so it is not equivalent evidence. This control does not
  disable Snapshot, Decapitate, AirResp, or later integrated commander changes.
- Decapitate rollback is scoped: on a fresh mission built with `WFBE_C_AICOM2_DECAP_ENABLE = 0`,
  DECAP makes no press-stamp or allocation-target writes and the legacy Strategy HQ-strike path is
  active. Shadow sensing/state and telemetry may remain. This control does not disable the
  allocator or the rest of AICOM2.
- Setting both controls to `0` still does not recreate a historical mission tree. A full historical
  rollback would be a new source/release proposal with current collision analysis and runtime
  evidence, not a flag flip or the unaudited single-`cc48`-PBO restore from the retired runbook.

For a future authorized soak, operational rollback should restore the pinned, hashed pre-soak set
of all three mission PBOs through the current deployment process. That artifact rollback is distinct
from changing source defaults for a later fresh-mission build.

Any future default change must start from current `master`, edit the authoritative Chernarus
source, regenerate the Takistan and Zargabad mirrors through LoadoutManager, and prove the intended
fresh-mission behavior. It must not be applied ad hoc to a live mission namespace or server file.

## PR and Fleet provenance

- [PR #785](https://github.com/rayswaynl/a2waspwarfare/pull/785) merged the original runbook on
  2026-07-06 at `30c48643f8c847b8c866fc250a1cdb1bf7ab86a2`.
- [PR #760](https://github.com/rayswaynl/a2waspwarfare/pull/760), the original
  `fable/v2-cutover` one-shot, closed unmerged on 2026-07-06 and was superseded by #788. Its
  pending-rebase checklist is not current work.
- [PR #761](https://github.com/rayswaynl/a2waspwarfare/pull/761) merged the accompanying bug pack
  at `d77ef818d555d1bc9f1d238f8505a4500db1d0ea`; its fixes were preserved through reconciliation
  and remain in current-master ancestry.
- [PR #788](https://github.com/rayswaynl/a2waspwarfare/pull/788) was the next cutover attempt. It
  closed unmerged and was superseded by #793.
- [PR #793](https://github.com/rayswaynl/a2waspwarfare/pull/793), the reconciled
  `fable/v2-cutover-r3`, merged on 2026-07-07 at merge commit `33fbd08e5`. It landed DECAP with a
  default of `0`. The merge and the integrated Allocator/Decapitate commits are ancestors of
  `master` snapshot `bb79a88aa`.
- Commit `c9151e794` established the Allocator default of `1`. Commit `d21c610bf` later changed the
  DECAP default to `1` for release 1.1. Both are ancestors of that master snapshot.
- [PR #968](https://github.com/rayswaynl/a2waspwarfare/pull/968) later changed DECAP arming behavior,
  another reason that future validation must use current source instead of the old frozen plan.
- Fleet task `aicom2-decap-soak-gate` is the surviving validation record. It verified DECAP
  ARM-to-COMMIT telemetry in combat-disabled performance windows, but remains blocked because those
  windows cannot produce `BASE_OVERRUN` or a `ROUNDSTAT` winner. It requires a separately authorized,
  combat-enabled, round-length soak; this retired file does not grant that authority.

## If validation is reopened

Use the current Fleet task and current tooling as the authority. At minimum:

1. Confirm a unique owner, machine, worktree, branch, reviewer, and explicit runtime boundary.
2. Pin the source commit, built artifact hash, terrain, effective flag values, and bounded RPT
   session before grading.
3. Use the current `Tools/Soak/README.md`, `Tools/Soak/analyze_soak.py`, and any task-specific
   scorer self-tests rather than thresholds copied from this historical plan.
4. Require a combat-enabled window for round-closer claims and preserve server/HC RPT hashes.
5. Pin and hash the complete pre-soak three-PBO artifact set as the operational rollback input.
6. Treat deploy, restore, server restart, and live-state changes as separate owner-authorized
   operations. Documentation or read-only review authority is not deployment authority.

## Current references

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Decapitate.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf`
- `Tools/Soak/README.md`
