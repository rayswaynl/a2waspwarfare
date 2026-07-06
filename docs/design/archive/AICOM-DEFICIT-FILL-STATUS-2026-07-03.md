# AICOM Deficit-Fill Status - 2026-07-03

Lane 104 asked to re-verify the reported "aicom-deficitfill floor-of-1" bug in `AI_Commander_Produce.sqf` and ship a minimal fix if the live lane still allowed under-strength HC teams to plateau around template size instead of refilling toward the intended AICOM team floor.

Current status: **current-target present; do not reimplement on this pass.**

## Evidence

Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4`.

The live lane already carries the deficit-fill correction in all maintained mission roots:

| Root | Evidence |
| --- | --- |
| Chernarus | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Produce.sqf:359-376` documents and applies the refill floor with `_floorN` and `_want`. `:402-412` adds the FILL-TO-FLOOR fallback that pads with a Man classname when the template composition is already satisfied but the team is still below `_want`. |
| Takistan | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Produce.sqf:359-376` and `:402-412` match the same deficit-fill and fallback shape. |
| Zargabad | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Produce.sqf:359-376` and `:402-412` match the same deficit-fill and fallback shape. |

The relevant current constants in Chernarus are:

| Constant | Current line | Meaning |
| --- | --- | --- |
| `WFBE_C_AI_MAX` | `Common/Init/Init_CommonConstants.sqf:260` | Per-group AI maximum used as the final clamp in `_want`. |
| `WFBE_C_AICOM_TEAM_SIZE_MIN` | `Common/Init/Init_CommonConstants.sqf:813` | Current infantry/mixed-team refill floor. |
| `WFBE_C_AICOM_TEAM_SIZE_MAX` | `Common/Init/Init_CommonConstants.sqf:814` | Current AICOM team ceiling, now set to the lighter Build 84 value. |

The checked code uses A2 OA-safe primitives for the refill decision: `isKindOf`, `getNumber`, `configFile`, `forEach`, scalar min/max, and explicit string classnames. It does not require A3-only helpers.

## Verdict

The lane 104 defect is not live on the checked target. The old floor-of-1 behavior described by the lane is explicitly called out as fixed in the current source comments, and the surrounding code implements that fix:

1. Non-MBT and non-attack-heli templates use `WFBE_C_AICOM_TEAM_SIZE_MIN` as the refill floor.
2. `_want` clamps template size through the min and max bounds and then through `WFBE_C_AI_MAX`.
3. If all template class counts are satisfied but `_cur < _want`, the selector pads with a Man classname rather than exiting at template size.
4. Empty or all-vehicle templates still stop safely instead of duplicating vehicles.

Because the 2026-07-02 night-wave avoid list names `AI_Commander_Produce.sqf`, this pass intentionally leaves mission source untouched. A second code patch would create merge pressure in a hot AICOM file without changing behavior.

## Follow-Up

Runtime smoke remains useful after the active AICOM/Fable file holders merge their work:

| Smoke | Expected proof |
| --- | --- |
| AICOM refill trace | RPT lines from `AI_Commander_Produce.sqf` showing under-strength non-vehicle teams ordering fill units until they reach the current floor. |
| Team-size telemetry | CMDRSTAT or equivalent telemetry showing infantry/light-motorized teams no longer plateau at the old 5-6 live-unit range after refills. |
| Vehicle-team exemption | MBT and attack-heli teams do not receive unrelated rifleman padding. |

No LoadoutManager run is required for this report because no mission source or generated mission mirror was edited.
