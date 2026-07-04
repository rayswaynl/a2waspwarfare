# AICOM ASSAULT_STRANDED Strike Coupling Status - 2026-07-03

Lane 88 asks for `ASSAULT_STRANDED` timeout events with near-zero movement to feed directly into the AICOM stuck-strike counter, so an immobile team can climb toward `TARGET_ABANDON` even when normal re-issue cadence does not bump the ladder.

Current verdict on `claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`: the direct `ASSAULT_STRANDED -> wfbe_aicom_stuckstrikes` coupling is not present. The adjacent stuck-recovery, failed-journey, and recycle systems are live, but the stranded timeout block itself only logs `_stuck` and increments failed journeys.

## Current Source Coverage

`Server/AI/Commander/AI_Commander_AssignTowns.sqf:153-172` handles the dispatch timeout. It computes `_moved`, derives `_stuck`, logs `ASSAULT_STRANDED`, closes `wfbe_aicom_dispatch_open`, increments `wfbe_aicom_failedjourneys`, and latches `wfbe_aicom_recycle` after `WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE`. That block does not read or write `wfbe_aicom_stuckstrikes`, so `stuck=true` is telemetry and recycle evidence, not a strike-ladder input.

The strike ladder is live elsewhere:

- `AI_Commander_AssignTowns.sqf:315-325` increments `wfbe_aicom_stuckstrikes` for a non-combat team parked far from target after a re-issue check.
- `AI_Commander_AssignTowns.sqf:332-342` turns an over-threshold parked-far strike count into `TARGET_ABANDON` and resets the counter.
- `AI_Commander_AssignTowns.sqf:398-405` increments the same counter for the uncapturable parked-town path.
- `AI_Commander_AssignTowns.sqf:425-463` blacklists and abandons stalled or uncapturable targets, then increments failed journeys for those abandon paths.
- `AI_Commander_AssignTowns.sqf:700-721` publishes the current strike tier into the `towns-target` order and logs `UNSTUCK_STRIKE`.
- `Common/Functions/Common_RunCommanderTeam.sqf:944-989` reads that order tier and runs the HC-side `UNSTUCK_FIRED` recovery path.

The same stranded timeout shape and strike-ladder separation exist in the maintained Chernarus, Takistan, and Zargabad `AI_Commander_AssignTowns.sqf` copies.

## Related PRs

Open draft PR #267 adds `docs/design/STUCK-RECOVERY-V2-REFERENCE.md`, the broader operator/tester reference for `STUCKSTAT`, `UNSTUCK_STRIKE`, `UNSTUCK_FIRED`, `TARGET_ABANDON`, `ASSAULT_STRANDED`, `RECYCLE_FLAG`, and the recovery constants. It is a reference route, not a lane 88 source implementation.

No dedicated open source PR for lane 88 was found in the refreshed board search. Future source work should be treated as a new hot-file lane, not as already-covered by lane 85/86/PR #267.

## Boundary

This lane is documentation-only. It does not edit `AI_Commander_AssignTowns.sqf`, `AI_Commander_Produce.sqf`, `Common_RunCommanderTeam.sqf`, `Common_AICOMAirLeg.sqf`, `Init_CommonConstants.sqf`, `Parameters.hpp`, GUI files, generated mission mirrors, packages, live runtime settings, or server deployment.

If lane 88 is implemented later, the minimal source question is how to increment `wfbe_aicom_stuckstrikes` from the `ASSAULT_STRANDED` timeout only when `_stuck` is true, without double-counting the existing parked-far or uncapturable branches.
