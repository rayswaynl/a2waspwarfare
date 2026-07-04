# AICOM F3 Orbiter Detection Status - 2026-07-03

Lane 86 asked for an AICOM F3 orbiter detector: teams stuck in `COMBAT` while circling GUER/contact should still enter the stuck-strike ladder when they stop closing on their assigned town.

Current verdict on `claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`: the detector is already live in the maintained Chernarus, Takistan, and Zargabad roots. Do not open another source implementation against the hot AICOM files for this lane.

## Current Source Coverage

`Server/AI/Commander/AI_Commander_AssignTowns.sqf:111-113` clears `wfbe_aicom_failedjourneys`, `wfbe_aicom_orbitwatchdist`, and `wfbe_aicom_orbitnoprog` after a successful arrival, so each fresh dispatch starts with a clean orbiter watch.

`AI_Commander_AssignTowns.sqf:115-152` is the F3 path. While a dispatched team is not yet inside the arrival radius, the watcher checks the leader's `COMBAT` behavior, stores `wfbe_aicom_orbitwatchdist`, and counts `wfbe_aicom_orbitnoprog` windows when the team has not closed at least 100 meters toward the target since the last watch. At three consecutive no-progress windows, it increments the same `wfbe_aicom_stuckstrikes` ladder used by the other stuck recovery paths, resets the window counter, and emits `ORBITER_STUCK`.

The non-COMBAT branch at `AI_Commander_AssignTowns.sqf:147-151` clears the orbiter state so normal position-stuck telemetry keeps handling non-combat stalls. This is the lane's key boundary: F3 fills the COMBAT blind spot without changing the existing non-combat stuck signal.

The same line block exists in:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf`

## Related PRs

Open draft PR #378, `fable/aicom-orbiter-stuckdecay`, is the current source review route for exposing this already-live behavior behind preserved-default constants across the maintained roots. Its title still says "default 0, dark", but the body records the Opus review fix: `WFBE_C_AICOM_ORBITER_DETECT` now seeds to 1, `WFBE_C_AICOM_ORBITER_WIN` now seeds to 3, and `WFBE_C_AICOM_STUCK_DECAY` now seeds to 1 so the PR preserves current Build-87 behavior instead of disabling it.

Open draft PR #267 adds `docs/design/STUCK-RECOVERY-V2-REFERENCE.md`, the broader operator/tester reference for `STUCKSTAT`, `UNSTUCK_STRIKE`, `UNSTUCK_FIRED`, `TARGET_ABANDON`, `ASSAULT_STRANDED`, `RECYCLE_FLAG`, and the recovery constants. This status note intentionally stays narrower: it only routes lane 86.

## Boundary

This lane is documentation-only. It does not edit `AI_Commander_AssignTowns.sqf`, `AI_Commander_Produce.sqf`, `Common_RunCommanderTeam.sqf`, `Common_AICOMAirLeg.sqf`, `Init_CommonConstants.sqf`, `Parameters.hpp`, GUI files, generated mission mirrors, packages, live runtime settings, or server deployment.

If #378 is rejected, reopen only the owner-review question of whether the already-live F3 behavior should stay unflagged or receive preserved-default flag exposure. The live lane should not receive a second F3 orbiter detector implementation.
