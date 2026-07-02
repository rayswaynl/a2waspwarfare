# Stuck Recovery V2 Reference

Source-checked against `origin/claude/build84-cmdcon36` on 2026-07-02.

This page documents the shipped AICOM stuck/recovery path. It is an operator and tester reference, not a proposal for new behavior. Recovery v2 is already live behind `WFBE_C_AICOM_RECOVERY_V2` default 1.

## Source Anchors

| Area | Primary source | Notes |
| --- | --- | --- |
| Stuck thresholds | `Common/Init/Init_CommonConstants.sqf:874-877`, `:1113-1120` | Recovery v2 gate, reverse speed, slope/road snap constants, and stuck movement thresholds. |
| Abandon/recycle thresholds | `Common/Init/Init_CommonConstants.sqf:805`, `:832`, `:973-990` | Stall advance, failed-journey recycle, per-team and side-wide blacklist controls. |
| Detection and strike issue | `Server/AI/Commander/AI_Commander_AssignTowns.sqf:145-158`, `:321-325`, `:716-721` | Orbiter/position-stuck detection, `STUCKSTAT`, and strike-tier order publishing. |
| Abandon paths | `Server/AI/Commander/AI_Commander_AssignTowns.sqf:342`, `:432`, `:454` | `TARGET_ABANDON` from strike overflow, stall advance, and uncapturable parked states. |
| Team-local recovery executor | `Common/Functions/Common_RunCommanderTeam.sqf:944-1079` | Reads the strike tier from the order payload and runs recovery where the group is local. |
| Gear governor | `Common/Functions/Common_RunCommanderTeam.sqf:1291-1335` | Temporarily slows steep or active-strike teams without freezing them. |
| Auto-unflip | `Common/Functions/Common_AICOM_AutoFlip.sqf:18-75` | Server/HC local loop that rights flipped, dry, stationary AICOM ground hulls. |
| WASPSCALE recovery counter | `Server/AI/Commander/AI_Commander.sqf:913-918` | `recov=` is server-local; HC delegated recoveries are visible in HC RPT `UNSTUCK_FIRED` lines. |

## Lifecycle

1. `AI_Commander_AssignTowns.sqf` keeps a dispatch/arrival watch for each ordered team. If the team times out, it logs `ASSAULT_STRANDED` with distance, elapsed time, moved distance, and the computed `stuck` latch.
2. A team becomes position-stuck when it is not airborne, not in `COMBAT`, moved less than `WFBE_C_AICOM_STUCK_MOVED` from the order origin, and remains farther than `WFBE_C_AICOM_STUCK_FAR` from the target. That increments `wfbe_aicom_stuckstrikes` and emits `STUCKSTAT|v1|...|stuck|...|strike=N`.
3. When a strike is active, the server republishes the target order with the strike tier in element 3 and mirrors it to `wfbe_aicom_unstuck`. It also logs `UNSTUCK_STRIKE`.
4. `Common_RunCommanderTeam.sqf` sees the fresh order sequence, reads the tier from the order payload, logs `UNSTUCK_FIRED`, bumps the local `wfbe_waspscale_recov` counter, remounts dismounts with assigned vehicles, and runs the recovery action where the group/vehicle is local.
5. Recovery v2 layers extra action on top of the original strike ladder: dead-driver swap, reverse pulse plus lane-sign flip, water-stuck forced road snap, slope-aware foot road snap, and tier-3 road-node relocation when no player is close enough to witness it.
6. If the team keeps failing the same town, `TARGET_ABANDON` blacklists that town for the team. Repeated abandons can become side-wide, and repeated failed journeys can set `RECYCLE_FLAG` so the consumer retires and refounds the zombie team elsewhere.

## Constants

| Constant | Default | Effect |
| --- | --- | --- |
| `WFBE_C_AICOM_RECOVERY_V2` | `1` | Enables recovery-v2 additions in the team executor. |
| `WFBE_C_AICOM_AUTOFLIP` | `1` | Starts the server/HC auto-unflip manager for local AICOM ground hulls. |
| `WFBE_C_AICOM_RECOVERY_REVERSE_SPEED` | `6` | Reverse-pulse speed before the lane-flip repath. |
| `WFBE_C_AICOM_RECOVERY_SLOPE_Z` | CH `0.85`, TK `0.80` | Surface-normal z below this makes a foot node too steep and widens road snap. |
| `WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R` | CH `200`, TK `300` | Road search radius for slope or water-forced foot recovery. |
| `WFBE_C_AICOM_STUCK_SECS` | `210` | Age of an order before the stuck reaction is considered. |
| `WFBE_C_AICOM_STUCK_MOVED` | `200` | Movement below this since order origin counts as no progress. |
| `WFBE_C_AICOM_STUCK_FAR` | `300` | Teams farther than this from target can be considered parked far from target. |
| `WFBE_C_AICOM_STUCK_ABANDON` | `4` | Strike count above which the team abandons/blacklists the current town. |
| `WFBE_C_AICOM_BLACKLIST_COOLDOWN` | `600` | Per-team town blacklist duration after abandon. |
| `WFBE_C_AICOM_SIDE_BLACKLIST` | `1` | Enables side-wide blacklist accumulation. |
| `WFBE_C_AICOM_SIDE_ABANDON` | `3` | Different-team abandons needed before side-wide blacklist. |
| `WFBE_C_AICOM_SIDE_BLACKLIST_COOLDOWN` | `900` | Side-wide blacklist duration. |
| `WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE` | `6` | Failed journeys needed before `RECYCLE_FLAG`. |
| `WFBE_C_AICOM_STALL_ADVANCE_SECS` | `420` | Backstop for a team parked at a town without flip/progress. |
| `WFBE_C_AICOM_ASSAULT_TIMEOUT` | `420` | Dispatch-to-arrival timeout used by the stranded watcher. |

## What Each Recovery Action Means

| Signal | Meaning |
| --- | --- |
| `STUCKSTAT\|v1\|...\|stuck\|...\|strike=N` | Server detected a parked, far-from-target, non-combat team and bumped its strike counter. |
| `AICOMSTAT\|v2\|EVENT\|...\|UNSTUCK_STRIKE\|...\|tier=N` | Server published a new order carrying the strike tier. |
| `AICOMSTAT\|v2\|EVENT\|...\|UNSTUCK_FIRED\|...\|tier=N` | Local executor actually ran recovery for that order. On HC teams this appears in the HC RPT. |
| `RECOVERY_V2 dead-driver swap` | A live non-player crewman was moved into an empty/dead driver seat. |
| `RECOVERY_V2 reverse-pulse + lane-flip` | Lead hull received a reverse velocity pulse and the team's lane jitter sign was flipped before repath. |
| `TIER3 unstuck teleport-nudge to road node` | Vehicle was moved to the nearest clear road node, only when no player was nearby. |
| `TIER3 FOOT/dead-hull unstuck teleport-nudge to road node` | Foot leader or dead/immobile-hull team was moved to a road node and foot units were ordered to reform. |
| `AICOMSTAT\|v1\|EVENT\|...\|AUTOFLIP\|righted=<type>` | AutoFlip righted a dry, stationary, tilted local AICOM ground hull. |
| `AICOMSTAT\|v2\|EVENT\|...\|ASSAULT_STRANDED\|...\|stuck=<bool>` | Dispatch watcher closed an over-budget journey and records whether it looked stuck. |
| `AICOMSTAT\|v2\|EVENT\|...\|TARGET_ABANDON\|...` | Team or side stopped grinding the current town and blacklisted it for a cooldown. |
| `AICOMSTAT\|v2\|EVENT\|...\|RECYCLE_FLAG\|...` | Too many failed journeys; the team is marked for retirement/refounding. |

## Operator Smoke Checks

When investigating a wedged front, scan server and HC RPTs together. A healthy recovery sequence usually looks like:

```text
STUCKSTAT|v1|...|stuck|...|reissue|strike=1
AICOMSTAT|v2|EVENT|...|UNSTUCK_STRIKE|...|tier=1
AICOMSTAT|v2|EVENT|...|UNSTUCK_FIRED|...|tier=1
Common_RunCommanderTeam.sqf: [...] RECOVERY_V2 reverse-pulse + lane-flip
```

For harder wedges, expect higher strike tiers, possible `TIER3` road-node logs, or `TARGET_ABANDON` if the same town remains unreachable. Auto-flip events can appear without a preceding strike because the auto-unflip loop is independent and runs every five seconds on the machine local to the hull.

`recov=` in WASPSCALE is useful as a trend counter, not a full fleet-wide total. It reports server-local recovery actions; HC-local teams must be counted from their HC RPT `UNSTUCK_FIRED` and `AUTOFLIP` lines.

## Guardrails

- Combat teams are not position-stuck by the normal parked-far gate; they may move slowly or orbit while fighting.
- Air-mobile legs are exempt while their airborne window is active or the leader is inside an aircraft.
- Tier-3 relocation is player-visibility guarded. A nearby player blocks the hidden road snap; the visible fallback is a small velocity bump.
- Water-stuck leaders or hulls force the road-snap path because AutoFlip deliberately skips water.
- Gear governor `LIMITED` is temporary and movement-preserving. It is not a sim gate or freeze.

## Out Of Scope

This page does not change recovery behavior, constants, telemetry, route generation, auto-flip thresholds, or HC/server ownership. It only maps the shipped system to source anchors and RPT smoke checks.
