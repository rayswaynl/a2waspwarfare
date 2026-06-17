/*
	Action_GuerVbiedDetonate.sqf — GUER PLAYER "Detonate VBIED" addAction handler (Feature B player-side, Ray 2026-06-16).
	Added by Client_BuildUnit.sqf to a hilux1_civil_2_covered when WFBE_C_GUER_PLAYERSIDE > 0; the action condition
	already restricts it to the resistance driver. Two-step safety: the FIRST selection ARMS a 5s confirm window;
	selecting it AGAIN within that window starts a short arm countdown, then asks the SERVER to detonate
	(Server_HandleSpecial "guer-vbied-detonate" mirrors the AI wildcard W21 blast + pays the driver's GUER team
	cash-for-kills). The blast itself runs server-side so kill credit + createVehicle damage behave the same as W21.

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack), no
	params/select-with-code/isEqualType, titleText (not the A3 hint structures). Lazy-eval `&& {}` is A2-safe.

	_this = [target(vehicle), caller(player), actionId, args]
*/
private ["_veh","_player","_now","_confirmUntil","_armDelay"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if (driver _veh != _player) exitWith {};                 //--- driver only (belt-and-braces vs the action condition).
if (_veh getVariable ["wfbe_vbied_arming", false]) exitWith {};   //--- already counting down; ignore re-selects.

_now          = time;
_confirmUntil = _veh getVariable ["wfbe_vbied_confirm", -1];

//--- Step 1: first press (or an expired window) ARMS a 5s confirm window. Nothing detonates yet.
if (_now > _confirmUntil) exitWith {
	_veh setVariable ["wfbe_vbied_confirm", _now + 5];
	titleText ["VBIED ARMED — select 'Detonate VBIED' again within 5s to confirm.", "PLAIN DOWN"];
};

//--- Step 2: confirmed within the window. Lock out re-entry, run a short arm countdown, then ask the server to blast.
_veh setVariable ["wfbe_vbied_arming", true];
_armDelay = missionNamespace getVariable ["WFBE_C_GUER_VBIED_ARM_DELAY", 3];

[_veh, _player, _armDelay] spawn {
	private ["_veh","_player","_armDelay","_i"];
	_veh      = _this select 0;
	_player   = _this select 1;
	_armDelay = _this select 2;
	for "_i" from _armDelay to 1 step -1 do {
		if (isNull _veh || {!alive _veh}) exitWith {};
		titleText [Format ["VBIED detonating in %1...", _i], "PLAIN DOWN"];
		sleep 1;
	};
	if (!isNull _veh && {alive _veh}) then {
		["RequestSpecial", ["guer-vbied-detonate", _veh, _player]] Call WFBE_CO_FNC_SendToServer;
	};
};
