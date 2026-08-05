Private ["_act","_caller","_h","_minH","_vehicle"];

_vehicle = _this select 0;
_caller = _this select 1;
_act = _this select 2;

//--- r72: action can fire after airframe despawn / caller leave / sub-min height (menu condition races descent).
if (isNil "_vehicle" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};
if (isNil "_caller" || {isNull _caller} || {!alive _caller}) exitWith {};
if !(_vehicle isKindOf "Air") exitWith {};
if (vehicle _caller != _vehicle) exitWith {};
_minH = missionNamespace getVariable ["WFBE_C_PLAYERS_HALO_HEIGHT", 200];
if (typeName _minH != "SCALAR") then {_minH = 200};
if ((getPos _vehicle select 2) < _minH) exitWith {};

//--- Latch so the transport GetOut emergency path does not double-start HALO_getout.
_caller setVariable ["wfbe_halo_scripted", true];
if (!isNil "_act" && {typeName _act == "SCALAR"} && {_act >= 0}) then {_vehicle removeAction _act};

_caller action ["EJECT", _vehicle];
_caller setVelocity [0,0,0];
[_caller] Exec "ca\air2\Halo\data\Scripts\HALO_getout.sqs";

//--- Mid-match HALO landing grace; an invalid or negative override falls back to 12 seconds.
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

//--- Landing-damage grace + empty chute cleanup (spawn-protect window does not cover freefall).
_caller spawn {
	Private ["_u","_t0","_near","_c"];
	_u = _this;
	if (isNil "_u" || {isNull _u}) exitWith {};
	_t0 = time;
	waitUntil {
		sleep 0.35;
		isNull _u || {!alive _u} || {((getPos _u) select 2) < 25} || {(time - _t0) > 180}
	};
	if (isNull _u || {!alive _u}) exitWith {};
	if (((getPos _u) select 2) < 25) then {
		_u allowDamage false;
		waitUntil {
			sleep 0.2;
			isNull _u || {!alive _u} || {((getPos _u) select 2) < 1.5} || {(time - _t0) > 200}
		};
		sleep 0.8;
		if (!isNull _u && {alive _u}) then {_u allowDamage true};
	};
	if (!isNull _u) then {
		_near = (getPos _u) nearEntities ["ParachuteBase", 12];
		{
			_c = _x;
			if (!isNull _c && {(count crew _c) == 0}) then {
				deleteVehicle _c;
			};
		} forEach _near;
	};
	if (!isNull _u) then {_u setVariable ["wfbe_halo_scripted", false]};
};