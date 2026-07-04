# AICOM Losing-Side Aggression Floor Status Audit - 2026-07-03

Lane: fleet lane 89, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for F7 losing-side aggression floor: when a side is behind
on towns, its base is not under direct threat, and it is still near strength
parity, force a minimum PRESS posture so it does not sit in DEFEND for the back
half of the match.

This pass checks the current target-branch source and records status only. It
does not edit mission source because the relevant AICOM files are hot/open-PR
surfaces.

## Verdict

Lane 89 is partially implemented on the checked target.

What is present:

- `WFBE_C_AICOM_LOSING_PRESS = 1` is defined in all maintained roots.
- `AI_Commander_Strategy.sqf` computes an effective-strength posture, applies a
  losing-side PRESS floor when the side is behind on towns but still at
  `>= 0.8 * enemy effective strength`, checks that the side is not in HQ strike
  or last-stand, probes for enemy units near its own HQ, and logs
  `AICOMSTAT|v1|EVENT|...|LOSING_PRESS_FLOOR`.
- The local `_posture = "PRESS"` also affects the later passive-stall
  telemetry gate, so this case is no longer classified as passive DEFEND in the
  POSTURE/STALL log stream.

What is not proven:

- `_posture` is local to the Strategy telemetry/stall block. A repo-wide search
  does not show the F7 floor being written to `wfbe_aicom_strat_mode` or read by
  `AI_Commander_Allocate.sqf`, `AI_Commander_AssignTowns.sqf`, or the HC order
  path as an actual order-routing input.
- Therefore, this audit should not be used as proof that lane 89 already
  changes commander assignments or movement behavior. It proves the default-on
  flag, telemetry floor, base-threat guard, and stall-classification behavior
  are present.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Losing-press flag | `Common/Init/Init_CommonConstants.sqf:845` defines `WFBE_C_AICOM_LOSING_PRESS = 1` in Chernarus, Takistan, and Zargabad. | Present, default on |
| Effective strength | `AI_Commander_Strategy.sqf:952-960` computes `_myEff` and `_enEff` from maneuver strength plus `WFBE_C_AICOM_TOWN_STRENGTH`, then derives a local `_posture`. | Present |
| F7 guard | `AI_Commander_Strategy.sqf:963-969` documents and gates the floor on `WFBE_C_AICOM_LOSING_PRESS`, not HQ strike, not last-stand, behind on towns, and `_myEff >= (_enEff * 0.8)`. | Present |
| Base safety probe | `AI_Commander_Strategy.sqf:970-976` checks own HQ with `nearEntities` using `WFBE_C_AICOM_RELIEF_ENEMY_DIST` before allowing the floor. | Present |
| Local floor and event | `AI_Commander_Strategy.sqf:977-979` sets local `_posture = "PRESS"` and logs `LOSING_PRESS_FLOOR` when the base is safe. | Present |
| Telemetry use | `AI_Commander_Strategy.sqf:995` emits the POSTURE row; `:1016-1017` suppresses passive STALL telemetry when `_posture == "PRESS"`. | Present |
| Behavior-path caveat | `AI_Commander_Strategy.sqf:87`, `:90`, `:534`, and `:730` are the `wfbe_aicom_strat_mode` writes; the F7 block does not write that variable. Repo-wide search found no F7 `_posture` consumer outside Strategy telemetry/stall code. | Not proven as order behavior |
| Design context | `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md:106-108` describes F7 as minimum PRESS when behind on towns and base-safe. | Documented |

## Maintained-Root Parity

`AI_Commander_Strategy.sqf` has the same SHA-256 hash in all three maintained
mission roots:

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `AI_Commander_Strategy.sqf` | `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806` |

Compact scan counts also match across all three roots:

| Root | `WFBE_C_AICOM_LOSING_PRESS` in Strategy | `LOSING_PRESS_FLOOR` | `_lpBaseThreat` | `_posture =` | `_posture` mentions | `wfbe_aicom_strat_mode` writes | F7 to strat-mode write | POSTURE log | passive-stall gate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 2 | 1 | 4 | 2 | 7 | 4 | 0 | 1 | 2 |
| Takistan | 2 | 1 | 4 | 2 | 7 | 4 | 0 | 1 | 2 |
| Zargabad | 2 | 1 | 4 | 2 | 7 | 4 | 0 | 1 | 2 |

Relevant constants also match across all three roots:

| Constant | Value / role |
| --- | --- |
| `WFBE_C_AICOM_LOSING_PRESS` | `1`, enables the F7 telemetry/stall floor |
| `WFBE_C_AICOM_RELIEF_ENEMY_DIST` | `500`, reused as the own-HQ base-threat probe radius |
| `WFBE_C_AICOM_LASTSTAND_TOWNS` | `1`, helps gate last-stand outside the F7 floor |
| `WFBE_C_AICOM_LASTSTAND_RATIO` | `0.30`, helps gate last-stand outside the F7 floor |
| `WFBE_C_AICOM_TOWN_STRENGTH` | `2`, used for effective-strength posture math |

## BI Command References

The relevant Arma 2 OA command family is the standard variable, side, entity
query, count, and logging API used by the existing code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/setVariable
- https://community.bistudio.com/wiki/nearEntities
- https://community.bistudio.com/wiki/alive
- https://community.bistudio.com/wiki/side
- https://community.bistudio.com/wiki/count
- https://community.bistudio.com/wiki/diag_log
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Do not duplicate the `WFBE_C_AICOM_LOSING_PRESS` flag or the
`LOSING_PRESS_FLOOR` telemetry. Those already exist and are root-parity clean.

Treat lane 89 as not fully closed if the intended deliverable is actual
assignment/order behavior. A follow-up source lane should wire the losing-side
floor into a behavior input that the commander actually consumes, with careful
coordination around `AI_Commander_Strategy.sqf`,
`AI_Commander_Allocate.sqf`, and `AI_Commander_AssignTowns.sqf`.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned lane 89 prompt text, active wiki claims, recent events, and open PRs
  before claiming the lane.
- Scanned `WFBE_C_AICOM_LOSING_PRESS`, effective-strength posture,
  base-threat probe, `LOSING_PRESS_FLOOR`, POSTURE telemetry, passive-stall
  gate, and `wfbe_aicom_strat_mode` writes across Chernarus, Takistan, and
  Zargabad.
- Verified `AI_Commander_Strategy.sqf` has matching SHA-256 hashes across all
  maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
