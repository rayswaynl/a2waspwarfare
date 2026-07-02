/*
	Action_GuerVbiedDetonate.sqf — GUER PLAYER "Detonate VBIED" addAction handler (Feature B player-side, Ray 2026-06-16).
	Added by Client_BuildUnit.sqf to a hilux1_civil_2_covered when WFBE_C_GUER_PLAYERSIDE > 0; the action condition
	already restricts it to the resistance driver.

	CONFIRMED DETONATION (Codex 2026-07-02): first scroll-wheel click opens a short local confirmation window; a second
	click immediately asks the SERVER to detonate (Server_HandleSpecial "guer-vbied-detonate" mirrors the AI wildcard
	W21 blast = setDamage 1 + 3x Sh_122_HE, and pays the driver's GUER team cash-for-kills). The blast runs server-side
	so kill credit + createVehicle damage behave the same as W21.

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack), no
	params/select-with-code/isEqualType, titleText (not the A3 hint structures).

	_this = [target(vehicle), caller(player), actionId, args]
*/
private ["_confirmUntil","_player","_veh"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if !((driver _veh) in [_player]) exitWith {};            //--- driver only (belt-and-braces vs the action condition).
if (_veh getVariable ["wfbe_vbied_fired", false]) exitWith {};   //--- one-shot: ignore any re-select after confirmation.

_confirmUntil = _veh getVariable ["wfbe_vbied_confirm_until", -1];
if (_confirmUntil < time) exitWith {
	_veh setVariable ["wfbe_vbied_confirm_until", time + 5];
	titleText ["VBIED selected. Select Detonate VBIED again within 5 seconds to confirm.", "PLAIN DOWN", 0.2];
};

//--- Confirmed blast. Mark fired so a same-frame double-select can't double-send.
_veh setVariable ["wfbe_vbied_confirm_until", -1];
_veh setVariable ["wfbe_vbied_fired", true];
titleText ["VBIED detonation confirmed.", "PLAIN DOWN", 0.2];
["RequestSpecial", ["guer-vbied-detonate", _veh, _player]] Call WFBE_CO_FNC_SendToServer;
