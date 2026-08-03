/*
	Common_SelectPlayerCrossGroup.sqf
	Drop-in selectPlayer replacement, safe for cross-group control handoffs.

	Parameters: [_targetUnit]
	Returns: nothing. Side effect: selectPlayer _targetUnit (always happens, on every path).

	PREVENTIVE INFRASTRUCTURE - re-labeled 2026-08-03 mining pass, no live bug found.
	The repo's one existing selectPlayer call site (WASP\actions\SkinSelector\SkinSelector_Apply.sqf)
	always targets a unit freshly created INSIDE the player's own slot group - never a borrowed AI
	unit from a different group - so the cross-group branch below never fires on that call site
	today. This wrapper exists so a FUTURE feature that DOES need a genuine cross-group selectPlayer
	(an admin/commander ride-along, or a squad-handoff style control swap into an AI-owned unit) has
	a ready-made guard instead of a bare selectPlayer call.

	Risk being guarded against: taking control of a unit that belongs to a DIFFERENT group than the
	player's CURRENT group can leave either group's AI movement stalled across the handoff - the
	group the player is leaving reverts to full AI control but its last-known move/doFollow state can
	go stale, and the group being entered can likewise lose cohesion while one of its own members was
	player-controlled. The un-stick technique below (doFollow-pulse the other members back onto their
	leader) is a pattern studied from community teamswitch scripts (reimplemented here in WASP idiom,
	no ported code) and mirrors the SAME doFollow-as-unstick idiom already live in
	Common_RunUnstuckRecovery.sqf and Common_SMLCampSplit.sqf.

	Flag: WFBE_C_FIX_TEAMSWITCH_CROSSGROUP_AIFREEZE, default 0.
	  - Flag OFF, OR the switch is same-group / degenerate (null or self target): fast path, a plain
	    `selectPlayer _targetUnit` - byte-identical to a bare call site.
	  - Flag ON AND a genuine cross-group switch: selectPlayer, then doFollow-pulse the OTHER members
	    of both the group being left and the group being entered.

	A2-OA-1.64 safe: isNull / group / units / alive / vehicle / leader / doFollow / selectPlayer.
	No A3-only commands, no inline "private _x =", no Boolean ==/!= comparisons.
*/

Private ["_targetUnit","_fromUnit","_fromGrp","_toGrp","_crossGroupGuardOn","_isCrossGroup","_ldrFrom","_ldrTo"];

_targetUnit = _this select 0;

//--- Fast path 1: guard disabled entirely - behave exactly like a bare selectPlayer call.
_crossGroupGuardOn = (missionNamespace getVariable ["WFBE_C_FIX_TEAMSWITCH_CROSSGROUP_AIFREEZE", 0]) > 0;
if (!_crossGroupGuardOn) exitWith {
	selectPlayer _targetUnit;
};

//--- Fast path 2: degenerate target (null / already the current player) - not our business,
//--- let a bare selectPlayer handle it exactly like the legacy call site did.
if (isNull _targetUnit || {_targetUnit == player}) exitWith {
	selectPlayer _targetUnit;
};

_fromUnit = player;
_fromGrp  = group _fromUnit;
_toGrp    = group _targetUnit;

//--- Only a genuine cross-group switch needs the pulse. Same-group switches (the only live
//--- call site today) are already safe and take the plain fast path.
_isCrossGroup = (!isNull _fromGrp) && {!isNull _toGrp} && {_fromGrp != _toGrp};

if (!_isCrossGroup) exitWith {
	selectPlayer _targetUnit;
};

diag_log format ["[WFBE (TEAMSWITCH)] cross-group selectPlayer: from=%1 (grp=%2) to=%3 (grp=%4)",
	_fromUnit, _fromGrp, _targetUnit, _toGrp];

selectPlayer _targetUnit;

//--- doFollow pulse on the group being LEFT: same idiom as Common_RunUnstuckRecovery.sqf /
//--- Common_SMLCampSplit.sqf. Un-sticks any AI whose move/doFollow state stalled the moment its
//--- leader/member stopped being player-controlled.
_ldrFrom = leader _fromGrp;
if (!isNull _ldrFrom && {alive _ldrFrom}) then {
	{if (alive _x && {_x != _ldrFrom} && {vehicle _x == _x}) then {_x doFollow _ldrFrom}} forEach (units _fromGrp);
};

//--- doFollow pulse on the group being ENTERED: its own cohesion can stall too while one of its
//--- members was momentarily borrowed for player control.
_ldrTo = leader _toGrp;
if (!isNull _ldrTo && {alive _ldrTo}) then {
	{if (alive _x && {_x != _ldrTo} && {vehicle _x == _x}) then {_x doFollow _ldrTo}} forEach (units _toGrp);
};
