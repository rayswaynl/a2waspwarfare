# AICOM F1 March Discipline Status Audit - 2026-07-03

Lane: fleet lane 83, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for F1 march discipline: set AICOM transit waypoints and
team-level march posture to `YELLOW` so columns return fire and keep moving, but
keep the final objective approach and capture/assault phase at `RED`.

This pass checked the current Build 86/cmdcon41 target branch. It does not edit
mission source because the requested behavior is already present and
`Common_RunCommanderTeam.sqf` is an active hot file with unrelated open PR
overlap.

## Verdict

Lane 83 is already implemented on the checked target. No source fix is needed.

The current mission roots define `WFBE_C_AICOM_MARCH_YELLOW = 1`, compute
`_marchCM` from that flag in both vehicle and foot march paths, apply `_marchCM`
to team-level transit combat mode and transit waypoint props, keep final
destination MOVE nodes at `RED`, and reassert team-level `RED` at the arrival
latch before SAD/capture/base-assault work.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Feature flag | `Common/Init/Init_CommonConstants.sqf:842` in Chernarus, Takistan, and Zargabad defines `WFBE_C_AICOM_MARCH_YELLOW = 1` with the comment "YELLOW on the march ... RED at the objective". | Present, default on |
| Team-level vehicle march posture | `Common_RunCommanderTeam.sqf:1218-1220` computes `_marchCM` from `WFBE_C_AICOM_MARCH_YELLOW` and calls `_team setCombatMode _marchCM`. | Present |
| Vehicle road-node transit props | `Common_RunCommanderTeam.sqf:1234` builds intermediate road-node MOVE waypoints with `["AWARE",_marchCM,"","FULL"]`. | Present |
| Vehicle final objective MOVE | `Common_RunCommanderTeam.sqf:1236` keeps the final `_dest` MOVE waypoint at `["AWARE","RED","COLUMN","FULL"]`. | Present |
| Foot branch march posture | `Common_RunCommanderTeam.sqf:1259-1262` recomputes `_marchCM` for the foot path. | Present |
| Foot road-node transit props | `Common_RunCommanderTeam.sqf:1271` uses `["AWARE",_marchCM,"COLUMN","FULL"]` for foot road nodes. | Present |
| Foot final objective MOVE | `Common_RunCommanderTeam.sqf:1273` keeps the final `_dest` MOVE waypoint at `["AWARE","RED","COLUMN","FULL"]`. | Present |
| Short foot transit | `Common_RunCommanderTeam.sqf:1277-1280` uses `_marchCM` for the single fast-transit MOVE; this is the whole transit leg and the arrival latch still flips objective work back to `RED`. | Present |
| Objective arrival latch | `Common_RunCommanderTeam.sqf:1372-1376` documents and performs `_team setCombatMode "RED"` before the arrival SAD/capture/base-assault phase. | Present |
| Waypoint prop bridge | `Common_WaypointsAdd.sqf:33` maps the waypoint prop array to `setWaypointBehaviour`, `setWaypointCombatMode`, `setWaypointFormation`, and `setWaypointSpeed`. | Present |
| Existing design docs | `docs/design/AI-MODS-AND-PATHFINDING.md:53-57` describes road-march transit using `_marchCM` and `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md:78-80` records the F1 target behavior. | Documented |

The three maintained `Common_RunCommanderTeam.sqf` copies are byte-equivalent
for this audit:

| Root | SHA-256 |
| --- | --- |
| Chernarus | `8BF85FAC37DE04DC6355B5C930B5BD5769A527114A175377BA57F49ACE2F6CCD` |
| Takistan | `8BF85FAC37DE04DC6355B5C930B5BD5769A527114A175377BA57F49ACE2F6CCD` |
| Zargabad | `8BF85FAC37DE04DC6355B5C930B5BD5769A527114A175377BA57F49ACE2F6CCD` |

Compact scan counts also match across all three roots:

| Root | `WFBE_C_AICOM_MARCH_YELLOW` | `_marchCM` | `["AWARE",_marchCM` transit props | `["AWARE","RED","COLUMN","FULL"]` final props | `_team setCombatMode "RED"` |
| --- | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 4 | 14 | 3 | 2 | 3 |
| Takistan | 4 | 14 | 3 | 2 | 3 |
| Zargabad | 4 | 14 | 3 | 2 | 3 |

## BI command references

The relevant Arma 2 OA command family is the standard group/waypoint posture
API:

- https://community.bistudio.com/wiki/setCombatMode
- https://community.bistudio.com/wiki/setWaypointCombatMode
- https://community.bistudio.com/wiki/setWaypointBehaviour
- https://community.bistudio.com/wiki/setWaypointFormation
- https://community.bistudio.com/wiki/setWaypointSpeed
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat fleet lane 83 as satisfied on `claude/build84-cmdcon36`. Future work here
should be framed as a behavior retune or soak follow-up, not as the missing F1
implementation, and should coordinate with existing `Common_RunCommanderTeam.sqf`
PR overlap before editing source.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned `WFBE_C_AICOM_MARCH_YELLOW`, `_marchCM`, final `RED` waypoint props,
  and arrival-latch `setCombatMode "RED"` anchors across Chernarus, Takistan,
  and Zargabad.
- Verified the three maintained `Common_RunCommanderTeam.sqf` files have the
  same SHA-256 hash.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
