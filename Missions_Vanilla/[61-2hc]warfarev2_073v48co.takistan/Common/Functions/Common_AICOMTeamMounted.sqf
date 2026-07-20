/*
	WFBE_CO_FNC_AICOMTeamMounted - is this AICOM team "mounted" for assault-reach purposes?

	T1.2 FIX (R3-SYNTHESIS 2026-07-20; codex adversarial review, critical finding on PR #1194):
	AI_Commander_AssignTowns.sqf and AI_Commander_Allocate.sqf each independently computed a
	"mounted" classifier that flagged the WHOLE team mounted (9000m reach) the instant a SINGLE
	unit was embarked in a canMove LandVehicle - so a lone crew-driver sent a whole walking squad
	on a 9km dispatch the infantry then refuse to complete on foot (86% of dispatches exceeded
	real foot reach). AssignTowns was fixed first, in isolation; review correctly found Allocate
	still ran its own unguarded copy of the exact same bug at its OWN target-selection site (which
	runs independently of AssignTowns' classifier), so the fix was incomplete and the bug still
	reproduced via that path. Both sites now share this ONE helper so they cannot diverge again.

	A team is "mounted" when EITHER:
	  - the LEADER is alive and embarked in a canMove LandVehicle, OR
	  - at least WFBE_C_AICOM_MOUNTED_FRAC (default 0.5) of the team's ALIVE units are.
	LandVehicle only (never Air/Ship/StaticWeapon) - the correct semantic for "reach-mounted" in
	the assault-dispatch sense; functionally equivalent to Allocate's prior "not Air" test for
	every realistic AICOM ground-team composition, but precise rather than a negative test.

	A2-OA-safe: plain boolean/count arithmetic, isKindOf classname literal, no A3 commands.

	Params: [ group ]
	Returns: BOOL (true = mounted / REACH_MOUNTED applies, false = foot / REACH_FOOT applies).
*/
private ["_grp","_ldr","_ldrMounted","_total","_embarked","_frac","_veh"];
_grp = _this select 0;
if (isNull _grp) exitWith {false};
_ldr = leader _grp;
_ldrMounted = (!isNull _ldr) && {alive _ldr} && {(vehicle _ldr) != _ldr} && {(vehicle _ldr) isKindOf "LandVehicle"} && {canMove (vehicle _ldr)};
if (_ldrMounted) exitWith {true};
_total = 0; _embarked = 0;
{
	if (alive _x) then {
		_total = _total + 1;
		_veh = vehicle _x;
		if (_veh != _x && {_veh isKindOf "LandVehicle"} && {canMove _veh}) then {_embarked = _embarked + 1};
	};
} forEach (units _grp);
if (_total <= 0) exitWith {false};
_frac = missionNamespace getVariable ["WFBE_C_AICOM_MOUNTED_FRAC", 0.5];
_embarked >= (_total * _frac)
