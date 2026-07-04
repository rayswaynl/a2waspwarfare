# AICOM F2 Journey Commit Status Audit - 2026-07-03

Lane: fleet lane 84, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for F2 journey commit / target stickiness: protect a team
that is making progress toward its open dispatch from retarget churn, protect it
from HQ strike-grab, and add spearhead/front dwell hysteresis so the primary
front target does not churn faster than long journeys can finish.

This pass checks the current Build 86/cmdcon41 target branch and records the
current state only. It does not edit mission source because the relevant AICOM
files are hot/open-PR surfaces and the only missing activation is a gameplay
default flip, not a mechanical source gap.

## Verdict

Lane 84 is mostly implemented on the checked target, with one explicit dark
sub-scope:

- Journey retarget protection is present and default-on via
  `WFBE_C_AICOM_JOURNEY_COMMIT = 1`.
- Front/spearhead dwell hysteresis is present and default-on via
  `WFBE_C_AICOM_FRONT_DWELL = 480`.
- HQ strike-grab protection is present in source, but intentionally dark:
  `WFBE_C_AICOM_STRIKE_COMMIT = 0`. Setting it to `1` would skip HQ strike-grab
  for a progressing open dispatch, but that is a balance/default decision and is
  not flipped here.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Front dwell flag | `Common/Init/Init_CommonConstants.sqf:844` in Chernarus, Takistan, and Zargabad defines `WFBE_C_AICOM_FRONT_DWELL = 480`. | Present, default on |
| Journey commit flag | `Common/Init/Init_CommonConstants.sqf:853` in Chernarus, Takistan, and Zargabad defines `WFBE_C_AICOM_JOURNEY_COMMIT = 1`. | Present, default on |
| Strike commit flag | `Common/Init/Init_CommonConstants.sqf:854` in Chernarus, Takistan, and Zargabad defines `WFBE_C_AICOM_STRIKE_COMMIT = 0`; the comment says `1` skips HQ strike-grab for a progressing team. | Present, default off |
| Dispatch latch | `AI_Commander_AssignTowns.sqf:91`, `:107`, `:159`, `:177`, `:741`, and `:749` maintain `wfbe_aicom_dispatch_open`, the open-dispatch latch used by the journey guard. | Present |
| Journey guard | `AI_Commander_AssignTowns.sqf:511-524` documents and gates journey commit when `_needs` is true and `WFBE_C_AICOM_JOURNEY_COMMIT > 0`. | Present |
| Progress test | `AI_Commander_AssignTowns.sqf:527-538` requires an open dispatch, a still-enemy target, and `_jcProg >= 150`, then sets `_needs = false` and logs `JOURNEY_COMMIT`. | Present |
| Front dwell guard | `AI_Commander_Strategy.sqf:365-374` documents F2 front/spearhead hysteresis and reads `WFBE_C_AICOM_FRONT_DWELL`. | Present |
| Front dwell state | `AI_Commander_Strategy.sqf:376-394` stores `wfbe_aicom_front_prim` and `wfbe_aicom_front_t0`, keeps a valid dwell pick at slot 0 while the dwell window is active, logs `FRONT_DWELL_HOLD`, or restamps the fresh primary when elapsed/invalid. | Present |
| Strike-grab guard | `AI_Commander_Strategy.sqf:815-838` contains the opt-in `WFBE_C_AICOM_STRIKE_COMMIT` guard that skips a progressing open-dispatch team for HQ strike-grab. | Present, dark |
| Existing design docs | `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md:84-88` describes F2 journey commit and front hysteresis; `:132-135` notes earlier sticky-order precedent but explains why additive journey commit/hysteresis was needed. | Documented |

## Maintained-Root Parity

The relevant AICOM source copies match across the maintained roots:

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `AI_Commander_AssignTowns.sqf` | `852DE78475B26F01C6EB2A4956B2C99AD4B4E72A49943A02B342200F0934ED1D` |
| `AI_Commander_Strategy.sqf` | `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806` |

Compact scan counts also match across all three roots:

| Root | AssignTowns `WFBE_C_AICOM_JOURNEY_COMMIT` | `wfbe_aicom_dispatch_open` | `_jcProg >= 150` | Strategy `WFBE_C_AICOM_FRONT_DWELL` | `wfbe_aicom_front_prim` | `FRONT_DWELL_HOLD` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 2 | 10 | 1 | 2 | 2 | 1 |
| Takistan | 2 | 10 | 1 | 2 | 2 | 1 |
| Zargabad | 2 | 10 | 1 | 2 | 2 | 1 |

## BI command references

The relevant Arma 2 OA command family is the standard variable/time/distance
API used by the existing guard code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/setVariable
- https://community.bistudio.com/wiki/distance
- https://community.bistudio.com/wiki/time
- https://community.bistudio.com/wiki/diag_log
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat the retarget and front-dwell portions of lane 84 as implemented on
`claude/build84-cmdcon36`. Do not re-open source work for those pieces.

Treat `WFBE_C_AICOM_STRIKE_COMMIT` as an explicit follow-up decision: the guard
exists, but the default is `0`. Flipping it to `1` should be a deliberate
behavior/default change with AICOM PR coordination, not an incidental docs-audit
change.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned `WFBE_C_AICOM_JOURNEY_COMMIT`, `WFBE_C_AICOM_FRONT_DWELL`, and
  `WFBE_C_AICOM_STRIKE_COMMIT` constants across Chernarus, Takistan, and
  Zargabad.
- Scanned AssignTowns journey-commit anchors and Strategy front-dwell /
  strike-commit anchors across Chernarus, Takistan, and Zargabad.
- Verified the relevant `AI_Commander_AssignTowns.sqf` and
  `AI_Commander_Strategy.sqf` copies have matching SHA-256 hashes across all
  maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
