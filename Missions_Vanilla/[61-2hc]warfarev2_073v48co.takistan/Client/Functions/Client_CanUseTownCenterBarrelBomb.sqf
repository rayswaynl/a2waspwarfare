/*
	Client helper: true when the given unit is standing at a FRIENDLY town center - GUER-held OR neutral
	(not WEST-held, not EAST-held). Same "town center" idiom Client_CanUseTownCenterEASA.sqf, the GUER
	vehicle-depot buy gate (WFBE_C_GUER_DEPOT_NEUTRAL_BUY, Init_CommonConstants.sqf) and the GUER
	spawn/respawn town pick already use - this is the FOURTH consumer of the same predicate, not a new
	mechanic. Range reuses WFBE_C_UNITS_SUPPORT_RANGE (70m) rather than a new constant, for the same
	reason the EASA check does: "you're standing right at this town."

	Used as the proximity leg of the "Call Barrel Bomb" WF-scroll addAction condition
	(Common\Init\Init_Unit.sqf / Client_OnRespawnHandler.sqf) - fable/guer-barrelbomb.

	_this = the unit to test (the addAction _target, i.e. the local player's own Man body)
	Returns: BOOL
*/
Private ["_ok","_range","_unit"];

_unit = _this;

if (isNull _unit || !(alive _unit)) exitWith {false};
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) <= 0) exitWith {false};	//--- playable GUER faction off -> never
if (side group _unit != resistance) exitWith {false};									//--- GUER-only: WEST/EAST locked out

_range = missionNamespace getVariable ["WFBE_C_UNITS_SUPPORT_RANGE", 70];
_ok = false;
{
	//--- Friendly town center = GUER-owned OR neutral (not held by WEST, not held by EAST). Same idiom as
	//--- Client_CanUseTownCenterEASA.sqf:23 and the GUER respawn/depot-buy town picks.
	if (((_x getVariable ["sideID",-1]) != WFBE_C_WEST_ID) && {(_x getVariable ["sideID",-1]) != WFBE_C_EAST_ID}) then {
		if (_unit distance _x < _range) exitWith {_ok = true};
	};
} forEach towns;

_ok
