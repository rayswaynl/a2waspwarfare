# Design: wedge watchdog COMBAT breadcrumb preservation

Lane: 220 - Relief wedge watchdog COMBAT breadcrumb resets too eagerly.

Status: design-only source PR. The runtime fix should stack on the active
`AI_Commander_Strategy.sqf` owner because that file is currently shared by
multiple AICOM work branches.

## Problem

The relief/strike wedge watchdog in
`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf`
tracks a per-team breadcrumb in `wfbe_aicom_wedge_bc` while a team is in
`defense` or `move` mode. The breadcrumb shape is `[leaderPos, time]`.

The intended rule is:

- if the leader moves more than `WFBE_C_AICOM_STUCK_MOVED`, refresh the
  breadcrumb;
- if the leader does not move for more than `WFBE_C_AICOM_STUCK_SECS` and is
  not in combat, release the team back to normal town orders;
- if the team is no longer in `defense` or `move`, clear the breadcrumb.

Current source anchors:

- `AI_Commander_Strategy.sqf:550-552` documents that COMBAT should be treated as
  legitimate stationary time.
- `AI_Commander_Strategy.sqf:560-596` implements the not-in-COMBAT watchdog path.
- `AI_Commander_Strategy.sqf:597-598` resets the breadcrumb every Strategy tick
  while the leader is in COMBAT or the leader check fails.
- `AI_Commander_Strategy.sqf:600-602` clears stale breadcrumbs once the team
  leaves `defense` or `move`.

The bug is the reset at `:597-598`. A relief team that is physically trapped in a
short repeated firefight keeps entering COMBAT. Each COMBAT tick writes
`[getPos leader, time]`, so the timestamp never ages past
`WFBE_C_AICOM_STUCK_SECS`. If the team is not meaningfully moving between those
firefights, the watchdog never accumulates enough stationary time to release it.

## Desired Behavior

COMBAT should pause the no-contact release decision, but it should not erase the
stall age unless the leader actually moved. The watchdog needs to distinguish:

- a legitimate moving firefight, where the breadcrumb should refresh;
- a static firefight at the same obstacle, where the timestamp should be
  preserved so the next non-COMBAT tick can release if the team is still stuck.

## Minimal Patch Shape

Keep the existing not-in-COMBAT block intact. Replace only the COMBAT side of
the final `else` branch with a movement-aware refresh:

```sqf
// Current branch:
// In COMBAT or null leader: reset the breadcrumb so a post-firefight stall is judged fresh.
_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos (leader _wTeam), time]];
```

Future runtime patch:

```sqf
// In COMBAT: keep the original stall timestamp unless the leader actually moved.
_wBc = _wTeam getVariable "wfbe_aicom_wedge_bc";
if (isNil "_wBc") then {
	_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos _wLdr, time]];
} else {
	_wBcPos = _wBc select 0;
	_wMoved = _wLdr distance _wBcPos;
	if (_wMoved > 50) then {
		_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos _wLdr, time]];
	};
};
```

Notes:

- Use plain group `getVariable` plus `isNil`, matching the existing A2-OA-safe
  idiom in the block.
- Keep the first COMBAT sighting seed so a team entering `defense` or `move`
  during a firefight has a valid breadcrumb.
- Use a small movement threshold around 50m, not
  `WFBE_C_AICOM_STUCK_MOVED` (currently 200m), because this branch is only
  deciding whether to refresh combat breadcrumbs, not whether the team qualifies
  as unstuck.
- Do not add a new flag. This restores the documented watchdog intent and is
  inert unless a team is already in the existing wedge watchdog path.
- If the later implementer wants a tunable, prefer
  `WFBE_C_AICOM_STUCK_COMBAT_MOVED` defaulting to 50, but a literal local
  threshold is enough for the narrow bug fix.

## Null/Dead Leader Handling

The current branch also catches null or dead leaders because it is the `else` of:

```sqf
if (!isNull _wLdr && {alive _wLdr} && {behaviour _wLdr != "COMBAT"}) then { ... }
```

The runtime patch should separate the cases:

- valid leader in COMBAT: movement-aware preservation as above;
- null or dead leader: leave the current conservative reset behavior or clear
  the breadcrumb. Do not call `getPos _wLdr` after `_wLdr` failed the null/dead
  guard.

This keeps lane 220 focused on the COMBAT reset bug and avoids changing group
death or leader replacement behavior in the same patch.

## Validation Plan

Static validation:

- `git diff --check`
- focused SQF lint on `AI_Commander_Strategy.sqf`
- added-line trap scan for A3-only commands, Boolean `==/!=`, and group
  `[name, default]` getVariable usage
- bracket delta check for the touched Strategy file

Runtime smoke:

- Force or observe an HC relief team in `defense` mode that enters repeated
  COMBAT without moving more than 50m.
- Confirm `wfbe_aicom_wedge_bc` keeps its original timestamp during static
  COMBAT ticks.
- Confirm that once the leader leaves COMBAT and remains below
  `WFBE_C_AICOM_STUCK_MOVED` for longer than `WFBE_C_AICOM_STUCK_SECS`, the
  existing `WEDGE_RELEASE` log fires and the team returns to `towns`.
- Confirm a moving firefight still refreshes the breadcrumb and does not release
  the team early.

Expected RPT evidence:

```text
AICOMSTAT|v2|EVENT|<side>|<minute>|WEDGE_RELEASE|team=<group>|mode=defense|moved=<N>
```

## Risk

Risk is limited to the relief/strike wedge watchdog. Preserving the COMBAT
timestamp can release a team sooner after a static firefight, which is the point
of the lane. The movement threshold protects active maneuvering teams from early
release. Revert by restoring the old unconditional breadcrumb reset in the
COMBAT branch.

## Out of Scope

- No runtime Strategy edit in this PR.
- No changes to `WFBE_C_AICOM_STUCK_MOVED` or `WFBE_C_AICOM_STUCK_SECS`.
- No changes to graceful withdrawal, HQ strike staging, AssignTowns stuck logic,
  or HC order execution.
- No LoadoutManager run, package artifact, deploy, or live runtime action.
