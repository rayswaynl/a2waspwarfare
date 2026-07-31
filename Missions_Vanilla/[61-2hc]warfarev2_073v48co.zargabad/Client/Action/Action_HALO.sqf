Private ["_act","_caller","_vehicle","_h"];

_vehicle = _this select 0;
_caller = _this select 1;
_act = _this select 2;

//--- r72 airborne state: action can fire after airframe despawn / death / mid-menu exit.
//--- Stacks with open #1720 null/in-vehicle gates (same checks; invuln + air-kind are NEW residual).
if (isNil "_vehicle" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};
if (isNil "_caller" || {isNull _caller} || {!alive _caller}) exitWith {};
if (vehicle _caller != _vehicle) exitWith {};
if !(_vehicle isKindOf "Air") exitWith {};

_caller action ["EJECT",_vehicle];
_caller setVelocity [0,0,0];
[_caller] Exec "ca\air2\Halo\data\Scripts\HALO_getout.sqs";

//--- r72: brief landing invulnerability so freefall/chute ground impact is not an instant kill
//--- when the jump is outside the join/respawn protection window (player HALO mid-match).
//--- Bounded sleep; re-enables only if still alive. A2-OA-safe allowDamage.
_h = missionNamespace getVariable ["WFBE_C_PLAYERS_HALO_INVULN", 12];
if (typeName _h != "SCALAR" || {_h < 0}) then {_h = 12};
if (_h > 0) then {
	_caller allowDamage false;
	[_caller, _h] spawn {
		private ["_u","_t"];
		_u = _this select 0;
		_t = _this select 1;
		sleep _t;
		if (!isNull _u && {alive _u}) then {_u allowDamage true};
	};
};
