# Dominant-Side Press Gate Status - 2026-07-03

Lane 93 asks for a re-check of the dominant-side press gate: the AICOM side that leads on territory should not become passive just because many bodies are tied up holding towns. The original risk was a posture gate that treated a territorial leader's depleted maneuver count as weakness, letting a side with a large town lead sit in HOLD/DEFEND instead of continuing the round.

Current status: **current-target present; do not reimplement in this pass.**

## Evidence

Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4`.

The current strategy worker already separates the posture decision from raw maneuver-only strength:

| Root | Evidence |
| --- | --- |
| Chernarus | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:953-960` labels the B69 territory-credited press gate, computes `_myEff = _myStr + (_myTowns * _townStr)`, and selects `PRESS` when town lead and effective strength both pass. `:982-995` emits `garBodies` telemetry beside `myStr`, `myEff`, and posture. |
| Takistan | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Strategy.sqf:953-960` and `:982-995` carry the same posture and telemetry shape. |
| Zargabad | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Strategy.sqf:953-960` and `:982-995` carry the same posture and telemetry shape. |

The checked constants in Chernarus are:

| Constant | Line | Role |
| --- | --- | --- |
| `WFBE_C_AICOM_TOWN_STRENGTH` | `Common/Init/Init_CommonConstants.sqf:1047` | Held-town credit used in `_myEff` / `_enEff`. |
| `WFBE_C_AICOM_STALL_TOWN_RATIO` | `Common/Init/Init_CommonConstants.sqf:488` | Sustained town-lead ratio for stall tracking. |
| `WFBE_C_AICOM_HQSTRIKE_STALL_OVERRIDE` | `Common/Init/Init_CommonConstants.sqf:482` | Number of dominant-stall ticks before HQ-strike override can fire. |

The current strategy file also documents why this exists:

| Area | Current behavior |
| --- | --- |
| Maneuver strength | `AI_Commander_Strategy.sqf:58-80` builds `_myStr` from live team bodies while filtering stranded/refit remnants. |
| Last-stand guard | `:83-85` uses effective strength so a town leader does not recall everything to HQ purely because towns are garrisoned. |
| Posture gate | `:953-960` uses effective strength for `DEFEND` / `HOLD` / `PRESS`. |
| Stall visibility | `:982-1017` logs `garBodies`, `myStr`, `myEff`, and passive-dominance STALL events so future soaks can tell whether a side is truly stuck. |

## Verdict

Lane 93's core stale finding is already addressed on the checked target. The side posture gate is no longer a raw `_myStr < _enStr` check; it credits held towns through `WFBE_C_AICOM_TOWN_STRENGTH`, keeps garrison-body telemetry visible, and counts sustained territory dominance for the HQ-strike stall override even when posture is already `PRESS`.

This pass intentionally does not edit mission source. The 2026-07-02 night-wave avoid list names `AI_Commander_Strategy.sqf` and adjacent AICOM files, and the live source already carries the relevant fix. A duplicate code patch here would add merge pressure without proving a new defect.

## Remaining Runtime Check

The useful follow-up is soak evidence, not another patch:

| Check | Expected signal |
| --- | --- |
| Dominant side posture | `AICOMSTAT|v1|POSTURE|...|PRESS|...|myEff=...|enEff=...|garBodies=...` when a side holds a material town lead and effective strength is not behind. |
| Passive-dominance telemetry | `AICOMSTAT|v1|STALL|...` should appear only for the passive subset where a sustained town lead is not pressing. |
| Override reachability | If the same side keeps a sustained town lead without closing, `HQ_STRIKE_STALL_OVERRIDE` should become reachable after the configured streak. |

`docs/design/SPREAD-AND-HOLD.md` still correctly says to re-check dominant-side-not-pressing after spread/hold territory accumulation. That is a runtime proof request against the current strategy machine, not a reason to reopen lane 93 as a source patch.

No LoadoutManager run is required for this report because no mission source or generated mission mirror was edited.
