# AICOM F4 Stuck-Ladder Status - 2026-07-03

Lane 85 asked for two fixes:

- decay the stuck-strike ladder by one on real progress instead of resetting it to zero, so oscillating wedgers can still reach terminal recovery;
- recycle "zombie" teams after repeated failed journeys, instead of dispatching the same non-arriving team forever.

Current verdict on `claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`: both behaviors are already present in the live target. Do not open another source implementation against the hot AICOM files for this lane.

## Current Source Coverage

`Common/Init/Init_CommonConstants.sqf:855` seeds `WFBE_C_AICOM_LADDER_DECAY = 1`. In `Server/AI/Commander/AI_Commander_AssignTowns.sqf:484-498`, a team that makes real en-route progress refreshes its breadcrumb and, when the flag is on, writes `wfbe_aicom_stuckstrikes = (current - 1) max 0` instead of hard-resetting the counter to zero.

`Common/Init/Init_CommonConstants.sqf:856` seeds `WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE = 6`. Successful arrivals clear `wfbe_aicom_failedjourneys` at `AI_Commander_AssignTowns.sqf:103-113`; failed closures increment it and latch `wfbe_aicom_recycle` from the `ASSAULT_STRANDED` path at `:159-172`, the `TARGET_ABANDON` path at `:343-352`, the stall-advance abandon path at `:433-441`, and the uncapturable abandon path at `:455-463`.

`Server/AI/Commander/AI_Commander_Produce.sqf:109-125` is the recycle consumer. It requests disband only when the team is not in `COMBAT`, no player is within 500 meters, and no disband is already pending. The comment is explicit that it does not use the command bypass, so the HC driver still keeps its normal proximity/combat veto. `AI_Commander_Strategy.sqf:818-829` also treats `wfbe_aicom_recycle` as an exemption from strike-commit skipping, so terminal zombie teams remain eligible for replacement instead of being preserved by journey-commit logic.

## Related PRs

Open draft PR #378, `fable/aicom-orbiter-stuckdecay`, is the current source review route for exposing the already-live stuck-decay and orbiter-detect behavior behind clearer constants across Chernarus, Takistan, and Zargabad. Its title still says "default 0, dark", but the body records the Opus review fix: `WFBE_C_AICOM_ORBITER_DETECT`, `WFBE_C_AICOM_ORBITER_WIN`, and `WFBE_C_AICOM_STUCK_DECAY` were reseeded to preserve live Build-87 behavior rather than disabling it.

Open draft PR #267 adds `docs/design/STUCK-RECOVERY-V2-REFERENCE.md`, the broader operator/tester reference for `STUCKSTAT`, `UNSTUCK_STRIKE`, `UNSTUCK_FIRED`, `TARGET_ABANDON`, `ASSAULT_STRANDED`, `RECYCLE_FLAG`, and the recovery constants. This status note intentionally stays narrower: it only routes lane 85.

## Boundary

This lane is documentation-only. It does not edit `AI_Commander_AssignTowns.sqf`, `AI_Commander_Produce.sqf`, `Common_RunCommanderTeam.sqf`, `Common_AICOMAirLeg.sqf`, `Init_CommonConstants.sqf`, `Parameters.hpp`, GUI files, generated mission mirrors, packages, live runtime settings, or server deployment.

If #378 is rejected, reopen only the owner-review question of whether the already-live F3/F4 behavior should stay unflagged or receive preserved-default flag exposure. The live lane should not receive a second F4 stuck-ladder or zombie-recycle implementation.
