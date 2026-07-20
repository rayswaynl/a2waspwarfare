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
private ["_pending","_player","_requestToken","_veh"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if (driver _veh != _player) exitWith {};                 //--- driver only (belt-and-braces vs the action condition).
if (_veh getVariable ["wfbe_vbied_fired", false]) exitWith {};   //--- one-shot: ignore any re-select after the first click.

//--- Do not consume the client-visible one-shot latch until the authoritative server has accepted this exact
//--- detonation. A dismount/death between this click and the server handler used to leave wfbe_vbied_fired set
//--- locally even though no blast was scheduled. The pending receipt suppresses double-clicks while preserving a
//--- bounded retry if the PV/result is lost.
_pending = _veh getVariable ["wfbe_vbied_pending_token", ""];
if (_pending != "") exitWith {titleText ["VBIED request pending server confirmation.", "PLAIN DOWN", 0.2]};
_requestToken = Format ["vbied:%1:%2:%3", getPlayerUID _player, floor (time * 1000), floor (random 1000000)];
_veh setVariable ["wfbe_vbied_pending_token", _requestToken];
["RequestSpecial", ["guer-vbied-detonate", _veh, _player, _requestToken]] Call WFBE_CO_FNC_SendToServer;

[_veh, _requestToken] Spawn {
	private ["_pendingToken","_pendingVeh"];
	_pendingVeh = _this select 0;
	_pendingToken = _this select 1;
	sleep 8;
	if (!isNull _pendingVeh && {(_pendingVeh getVariable ["wfbe_vbied_pending_token", ""]) == _pendingToken}) then {
		_pendingVeh setVariable ["wfbe_vbied_pending_token", ""];
		titleText ["VBIED request timed out; detonation was not confirmed.", "PLAIN DOWN", 0.2];
	};
};
