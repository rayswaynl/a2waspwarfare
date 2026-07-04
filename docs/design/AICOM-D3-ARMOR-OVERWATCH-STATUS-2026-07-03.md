# AICOM D3 Armor Overwatch Status - 2026-07-03

Lane 101 asks for AICOM D3 armor overwatch during capture: tank hulls screen outward beyond the 40m flag/town-center ring while infantry/APCs keep the existing capture pressure. The requested source shape is flag-gated and default-off.

Current verdict on `claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`: the exact D3 armor-overwatch behavior is not live on the target. Do not open a duplicate hot-file implementation; source review already routes through open draft PR #285.

## Current Source Coverage

The current target has no `WFBE_C_AICOM_ARMOR_SCREEN`, `WFBE_C_AICOM_ARMOR_SCREEN_R`, or `ARMOR_SCREEN` telemetry hits in the maintained Chernarus, Takistan, or Zargabad roots.

`Common/Functions/Common_RunCommanderTeam.sqf:1363-1474` handles the arrival latch. For non-plane town assaults, it reasserts `RED`, optionally drops approach smoke, then lays the existing `SAD` waypoint on `_dest` for the whole group. There is no tank-specific outward `doMove`, no hull-screen radius, and no D3 flag check in this block.

`Common_RunCommanderTeam.sqf:1630-1685` starts the town capture phase and always dismounts alive non-crew infantry. Drivers and gunners stay mounted so their hulls remain ready and parked near center. `Common_RunCommanderTeam.sqf:1776-1784` defensively dismounts any remaining foot soldiers for camp capture. These are capture/dismount primitives, not armor overwatch: tank hulls are not fanned outward beyond the flag ring.

## Related PR

Open draft PR #285, `fable/aicom-armor-screen-capture`, is the source review route for lane 101. It adds `WFBE_C_AICOM_ARMOR_SCREEN = 0` and `WFBE_C_AICOM_ARMOR_SCREEN_R = 80`, then inserts a guarded post-SAD tank loop in `Common_RunCommanderTeam.sqf`: each live `Tank` hull with a live driver receives a staggered outward screen position, `COMBAT`/`RED`/`LIMITED` posture, and `ARMOR_SCREEN` telemetry.

PR #285 currently reports CLEAN/MERGEABLE and changes four files: Chernarus `Common_RunCommanderTeam.sqf` and `Init_CommonConstants.sqf`, plus the Takistan mirrors. It does not include Zargabad files, while the current target now has a maintained Zargabad root. Review #285 for Zargabad propagation before treating D3 as fully ready.

## Boundary

This lane is documentation-only. It does not edit `Common_RunCommanderTeam.sqf`, `AI_Commander_AssignTowns.sqf`, `AI_Commander_Produce.sqf`, `Common_AICOMAirLeg.sqf`, `Init_CommonConstants.sqf`, `Parameters.hpp`, GUI files, generated mission mirrors, packages, live runtime settings, or server deployment.

If PR #285 is rejected, lane 101 remains a future default-off source lane. If PR #285 is accepted, close this lane through that PR rather than starting a second D3 armor-overwatch implementation.
