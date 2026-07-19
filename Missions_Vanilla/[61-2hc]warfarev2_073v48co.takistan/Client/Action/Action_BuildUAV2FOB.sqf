/*
	Client action for the UAV-upgrade-level-2 Forward FOB.
	Advisory eligibility only; the server recomputes position, authority, cap and funds.
*/
private ["_truck","_player","_pos","_uid","_capKey","_challengeKey","_cap","_capValid","_challenge","_deadline","_token"];
_truck = _this select 0;
_player = _this select 1;

if (!((missionNamespace getVariable ["WFBE_C_UAV2_FOB", 0]) > 0)) exitWith {};
if !([_player, _truck] Call WFBE_CO_FNC_CanUseUAV2FOB) exitWith {
	titleText ["UAV2 FOB unavailable: Engineer, repair truck and UAV level 2 are required.", "PLAIN DOWN"];
};

//--- The generic server PV bus carries no sender identity. Obtain a short-lived capability
//--- privately targeted to this player's network owner and bound server-side to this exact truck.
_uid = getPlayerUID _player;
if (_uid == "") exitWith {titleText ["UAV2 FOB authorization unavailable.", "PLAIN DOWN"]};
_capKey = Format ["wfbe_uav2_fob_cap_client_%1", _uid];
_challengeKey = Format ["wfbe_uav2_fob_auth_challenge_%1", _uid];
_cap = missionNamespace getVariable [_capKey, []];
_capValid = false;
if (typeName _cap == "ARRAY" && {count _cap >= 3}) then {
	if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"} && {typeName (_cap select 2) == "OBJECT"}) then {
		if ((_cap select 0) != "" && {(_cap select 1) > time} && {(_cap select 2) == _truck}) then {_capValid = true};
	};
};
if (!_capValid) then {
	_challenge = Format ["%1:%2:%3", _uid, floor (diag_tickTime * 1000), floor (random 1000000000)];
	missionNamespace setVariable [_challengeKey, _challenge];
	["RequestUAV2FOB", ["auth", _player, _truck, _challenge]] Call WFBE_CO_FNC_SendToServer;
	_deadline = time + 5;
	waitUntil {
		sleep 0.05;
		_cap = missionNamespace getVariable [_capKey, []];
		_capValid = false;
		if (typeName _cap == "ARRAY" && {count _cap >= 3}) then {
			if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"} && {typeName (_cap select 2) == "OBJECT"}) then {
				if ((_cap select 0) != "" && {(_cap select 1) > time} && {(_cap select 2) == _truck}) then {_capValid = true};
			};
		};
		_capValid || {time >= _deadline}
	};
	missionNamespace setVariable [_challengeKey, ""];
};
if (!_capValid) exitWith {titleText ["UAV2 FOB authorization timed out. Try again.", "PLAIN DOWN"]};
_token = _cap select 0;
missionNamespace setVariable [_capKey, []];

_pos = _truck modelToWorld [0, (missionNamespace getVariable ["WFBE_C_UAV2_FOB_BUILD_DIST", 22]), 0];
_pos set [2, 0];
["RequestUAV2FOB", ["build", _uid, _token, _pos]] Call WFBE_CO_FNC_SendToServer;
titleText ["Requesting UAV2 Forward FOB ...", "PLAIN DOWN"];
