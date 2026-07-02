/*
	Action_GuerVbiedDetonate.sqf — GUER PLAYER "Detonate VBIED" addAction handler (Feature B player-side, Ray 2026-06-16).
	Added by Client_BuildUnit.sqf to a hilux1_civil_2_covered when WFBE_C_GUER_PLAYERSIDE > 0; the action condition
	already restricts it to the resistance driver.

	INSTANT DETONATION (Ray 2026-06-18): no confirm window, no arm countdown, no dialog. The single scroll-wheel
	click immediately asks the SERVER to detonate (Server_HandleSpecial "guer-vbied-detonate" mirrors the AI wildcard
	W21 blast = setDamage 1 + 3x Sh_122_HE, and pays the driver's GUER team cash-for-kills). The blast runs server-side
	so kill credit + createVehicle damage behave the same as W21.

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack), no
	params/select-with-code/isEqualType, titleText (not the A3 hint structures).

	_this = [target(vehicle), caller(player), actionId, args]
*/
private ["_veh","_player","_confirmKey","_confirmMsg","_confirmed"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if (driver _veh != _player) exitWith {};                 //--- driver only (belt-and-braces vs the action condition).
if (_veh getVariable ["wfbe_vbied_fired", false]) exitWith {};   //--- one-shot: ignore any re-select after the first click.

_confirmed = true;
if ((missionNamespace getVariable ["WFBE_C_GUER_VBIED_CONFIRM", 0]) > 0) then {
	_confirmKey = Format ["wfbe_vbied_%1", _veh];
	_confirmMsg = "<t color='#ff5a5a' size='1.1'>Confirm VBIED detonation?</t><br/>Click Detonate VBIED again within 6s.";
	_confirmed = [_confirmKey, _confirmMsg] call WFBE_CL_FNC_ConfirmAction;
};
if (!_confirmed) exitWith {};

//--- INSTANT blast on the single scroll-wheel click. Mark fired so a same-frame double-select can't double-send.
_veh setVariable ["wfbe_vbied_fired", true];
["RequestSpecial", ["guer-vbied-detonate", _veh, _player]] Call WFBE_CO_FNC_SendToServer;
