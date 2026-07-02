/*
	Action_GuerVbiedDetonate.sqf — GUER PLAYER "Detonate VBIED" addAction handler (Feature B player-side, Ray 2026-06-16).
	Added by Client_BuildUnit.sqf to a hilux1_civil_2_covered when WFBE_C_GUER_PLAYERSIDE > 0; the action condition
	already restricts it to the resistance driver.

	TWO-CLICK CONFIRM (Ray 2026-07-02): the first scroll-wheel click arms a short local confirmation window; the
	second click inside that window asks the SERVER to detonate via Server_HandleSpecial "guer-vbied-detonate". The blast runs server-side
	so kill credit + createVehicle damage behave the same as W21.

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack), no
	params/select-with-code/isEqualType, titleText (not the A3 hint structures).

	_this = [target(vehicle), caller(player), actionId, args]
*/
private ["_veh","_player","_now","_confirmWindow","_confirmUntil"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if !(_player in [driver _veh]) exitWith {};              //--- driver only (belt-and-braces vs the action condition).
if (_veh getVariable ["wfbe_vbied_fired", false]) exitWith {};   //--- one-shot: ignore any re-select after the confirmed send.

//--- First click only arms a local confirm window; second click inside the window sends the detonation request.
_now = time;
_confirmWindow = 4;
_confirmUntil = _veh getVariable ["wfbe_vbied_confirm_until", -1];
if (_confirmUntil < _now) exitWith {
	_veh setVariable ["wfbe_vbied_confirm_until", _now + _confirmWindow];
	titleText [Format ["VBIED detonation armed - select Detonate VBIED again within %1 seconds to confirm.", _confirmWindow], "PLAIN DOWN"];
};

//--- Mark fired so a same-frame double-select cannot double-send.
_veh setVariable ["wfbe_vbied_confirm_until", -1];
_veh setVariable ["wfbe_vbied_fired", true];
titleText ["VBIED detonation confirmed.", "PLAIN DOWN"];
["RequestSpecial", ["guer-vbied-detonate", _veh, _player]] Call WFBE_CO_FNC_SendToServer;
