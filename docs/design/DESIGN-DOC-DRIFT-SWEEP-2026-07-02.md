# Design Doc Drift Sweep - 2026-07-02

Lane: `fleet-lane-68-design-doc-drift-sweep-2026-07-02`

Base checked: `origin/claude/build84-cmdcon36@6f2fc4bd10c8339fd13be087d327717ff58c85e8`

Scope: docs-only reconciliation for the live-status sections in:
- `docs/design/SPREAD-AND-HOLD.md`
- `docs/design/REAL-BASE-ASSAULT.md`
- `docs/design/AICOM-AIRCRAFT.md`

## Findings

| Document | Result | Notes |
| --- | --- | --- |
| `SPREAD-AND-HOLD.md` | Current | Build 86 live-status anchors still match the checked source. No content edit needed. |
| `REAL-BASE-ASSAULT.md` | Current | Build 86 live-status anchors still match the checked source. No content edit needed. |
| `AICOM-AIRCRAFT.md` | Refreshed | Live behavior was still described correctly, but line anchors shifted and the follow-up still treated PR `#151` and PR `#172` as open. Those PRs are now merged into the baseline. |

## Source Anchors Rechecked

Spread/hold:
- `Common/Init/Init_CommonConstants.sqf:560`
- `Common/Init/Init_CommonConstants.sqf:731-734`
- `Server/AI/Commander/AI_Commander_Allocate.sqf:234-280`
- `Server/AI/Commander/AI_Commander_AssignTowns.sqf:247-265`
- `Common/Functions/Common_RunCommanderTeam.sqf:1841-1855`
- `Client/GUI/GUI_Menu_Command.sqf:391`
- `Server/Functions/Server_HandleSpecial.sqf:649-727`

Real-base assault:
- `Common/Init/Init_CommonConstants.sqf:735-740`
- `Server/Functions/Server_BuildingHandleDamages.sqf:12-18`
- `Server/Functions/Server_HandleBuildingDamage.sqf:6-12`
- `Server/Functions/Server_BuildingDamaged.sqf:6-11`
- `Common/Functions/Common_RunCommanderTeam.sqf:1338-1452`
- `Server/AI/Commander/AI_Commander_Strategy.sqf:856-907`
- `server_victory_threeway.sqf`

AICOM aircraft:
- `Common/Init/Init_CommonConstants.sqf:380`
- `Common/Init/Init_CommonConstants.sqf:388`
- `Server/AI/Commander/AI_Commander_Teams.sqf:289-353`
- `Server/AI/Commander/AI_Commander_Teams.sqf:433-435`
- `Server/AI/Commander/AI_Commander_Teams.sqf:1078-1103`
- `Server/AI/Commander/AI_Commander.sqf:520-677`

## Collision Context

PR `#151` (`claude/cmdcon42-ah6x`) and PR `#172` (`claude/cmdcon42-tkair`) were merged on 2026-07-02, so they are part of the current baseline rather than active aircraft blockers.

The open PR queue still has AICOM work in nearby systems, so future aircraft-path edits should recheck overlap at claim time. In particular, the Build 88 recovery-ladder/high-climb work was active during this sweep and was avoided as a separate lane.

## Validation

This lane changes documentation only. No mission SQF was edited, so the LoadoutManager Chernarus-to-Takistan mirror step is not required.
