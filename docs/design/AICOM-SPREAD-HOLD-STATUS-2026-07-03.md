# AICOM SPREAD+HOLD Status Audit - 2026-07-03

Lane: fleet lane 91, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for SPREAD+HOLD: widen the AI commander fist
(`FIST_TOWNS=2`), cap teams per fist town (`FIST_PERTOWN=4`), and let the first
captor hold a just-captured town briefly so it does not immediately flip back.

This pass checks current target-branch source and records status only. It does
not edit mission source because the relevant files are hot/open-PR AICOM
surfaces.

## Verdict

Lane 91 is already implemented on the checked target.

The implementation is default-on across all maintained roots:

- `WFBE_C_AICOM2_FIST_TOWNS = 2`
- `WFBE_C_AICOM_SPREAD_MODE = 1`
- `WFBE_C_AICOM2_FIST_PERTOWN = 4`
- `WFBE_C_AICOM_HOLD_MODE = 1`
- `WFBE_C_AICOM_HOLD_SECS = 180`

The behavior path is also present, not just telemetry:

- `AI_Commander_Allocate.sqf` reads the widened-fist/per-town-cap constants,
  tracks `_fistCounts`, and chooses a cap-aware target before falling back to
  least-loaded fist town.
- `Common_RunCommanderTeam.sqf` lets the first successful captor claim a timed
  DEFEND hold by stamping `wfbe_aicom_hold_until` on the town and
  `wfbe_aicom_holding_town` on the team.
- `AI_Commander_AssignTowns.sqf` reads the holder latch and sets
  `_explicitMode = true` while it is still live, preventing immediate retarget.

The existing `docs/design/SPREAD-AND-HOLD.md` already captures the design and
rollback levers. Some of its embedded line references have drifted, so this
audit records the current anchors.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Widened fist | `Common/Init/Init_CommonConstants.sqf:659` defines `WFBE_C_AICOM2_FIST_TOWNS = 2` in Chernarus, vanilla Takistan, and vanilla Zargabad. | Present, default on |
| Spread defaults | `Common/Init/Init_CommonConstants.sqf:830-831` defines `WFBE_C_AICOM_SPREAD_MODE = 1` and `WFBE_C_AICOM2_FIST_PERTOWN = 4`. | Present, default on |
| Hold defaults | `Common/Init/Init_CommonConstants.sqf:832-833` defines `WFBE_C_AICOM_HOLD_MODE = 1` and `WFBE_C_AICOM_HOLD_SECS = 180`. | Present, default on |
| Allocator fist size | `Server/AI/Commander/AI_Commander_Allocate.sqf:130` reads `WFBE_C_AICOM2_FIST_TOWNS`; `:237-243` builds `_fistCounts` and reads `WFBE_C_AICOM2_FIST_PERTOWN`. | Present |
| Cap-aware spread | `Server/AI/Commander/AI_Commander_Allocate.sqf:280-284` gates SPREAD mode; `:286-290` picks the nearest in-reach fist town below cap, with later fallback to least-loaded fist town at `:295-298`. | Present |
| First-captor hold | `Common_RunCommanderTeam.sqf:1973-1989` documents and claims the hold when a town flips; `:1990-1996` puts the team on DEFEND, sets `wfbe_aicom_holding_town`, clears stale strike/relief, and emits `HOLD-CLAIM`. | Present |
| Holder skip | `Server/AI/Commander/AI_Commander_AssignTowns.sqf:246-265` reads `wfbe_aicom_holding_town` and `wfbe_aicom_hold_until`; while the held town is still ours and the expiry is live, it sets `_explicitMode = true` so normal retarget logic skips the holder. | Present |
| Existing design doc | `docs/design/SPREAD-AND-HOLD.md` describes the dogpile/see-saw root cause, constants, rollback levers, and runtime validation target. | Documented |

## Maintained-Root Parity

The relevant AICOM source copies match across the maintained roots checked:
`Missions/[55-2hc]warfarev2_073v48co.chernarus`,
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`, and
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`.

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `Server/AI/Commander/AI_Commander_Allocate.sqf` | `478EB7A29DF24148649D27AFBA3DD207692F625473D05A5C67EAEA77C98C5D1E` |
| `Server/AI/Commander/AI_Commander_AssignTowns.sqf` | `852DE78475B26F01C6EB2A4956B2C99AD4B4E72A49943A02B342200F0934ED1D` |
| `Common/Functions/Common_RunCommanderTeam.sqf` | `8BF85FAC37DE04DC6355B5C930B5BD5769A527114A175377BA57F49ACE2F6CCD` |

Compact scan counts also match across all three roots:

| Root | constants `FIST_TOWNS` | `SPREAD_MODE` | `FIST_PERTOWN` | `HOLD_MODE` | `HOLD_SECS` | Allocator `FIST_TOWNS` | `SPREAD_MODE` | `FIST_PERTOWN` | `_fistCounts` | Run `hold_until` | Run `holding_town` | `HOLD-CLAIM` | Assign `holding_town` | Assign `hold_until` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 1 | 1 | 2 | 1 | 1 | 3 | 1 | 1 | 6 | 2 | 1 | 1 | 3 | 2 |
| Takistan | 1 | 1 | 2 | 1 | 1 | 3 | 1 | 1 | 6 | 2 | 1 | 1 | 3 | 2 |
| Zargabad | 1 | 1 | 2 | 1 | 1 | 3 | 1 | 1 | 6 | 2 | 1 | 1 | 3 | 2 |

## BI Command References

The relevant Arma 2 OA command family is the standard variable, distance, time,
array/count, and logging API used by the existing code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/setVariable
- https://community.bistudio.com/wiki/distance
- https://community.bistudio.com/wiki/time
- https://community.bistudio.com/wiki/count
- https://community.bistudio.com/wiki/diag_log
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat lane 91 as implemented on `claude/build84-cmdcon36`. Do not re-open
source work for the widened fist, per-fist-town cap, first-captor hold, or
holder-retarget skip unless a later soak shows a tuning problem.

The useful follow-up is runtime validation, not more source plumbing: soak a
full commander round and confirm captures distribute across more than one front
town, `HOLD-CLAIM` appears, and owned-town count climbs instead of see-sawing at
one town per side.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned lane 91 prompt text, active wiki claims, recent events, and open PRs
  before claiming the lane.
- Scanned SPREAD constants, allocator fist-count/cap logic, first-captor hold,
  holder skip-retarget, and existing `SPREAD-AND-HOLD.md` anchors.
- Verified `AI_Commander_Allocate.sqf`, `AI_Commander_AssignTowns.sqf`, and
  `Common_RunCommanderTeam.sqf` have matching SHA-256 hashes across all
  maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
