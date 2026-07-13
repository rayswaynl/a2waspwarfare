Private ["_cap","_capDeadline","_capKey","_capValid","_challenge","_challengeKey","_fee","_muni","_pendingKey","_platform","_sendTelToServer","_side","_target","_team","_token","_uid"];

//--- Sender-bound ICBM/TEL request helper. RequestSpecial's shared PVEH has no sender metadata,
//--- so a short-lived secret is returned only to owner player and consumed by the server once.
if (typeName _this != "ARRAY" || {count _this != 6}) exitWith {};
if !((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 0]) > 0) exitWith {};

_side = _this select 0;
_target = _this select 1;
_muni = _this select 2;
_team = _this select 3;
_fee = _this select 4;
_platform = _this select 5;

if (typeName _side != "SIDE" || {!(_side in [west,east,resistance])}) exitWith {};
if (typeName _target != "ARRAY" && {typeName _target != "OBJECT"}) exitWith {};
if (typeName _muni != "STRING") exitWith {};
if (typeName _team != "GROUP" || {isNull _team}) exitWith {};
if (typeName _fee != "SCALAR") exitWith {};
if (typeName _platform != "OBJECT") exitWith {};
if (isNull player || {!alive player} || {!isPlayer player}) exitWith {};

_uid = getPlayerUID player;
if (_uid == "") exitWith {};
_pendingKey = Format ["wfbe_icbm_tel_auth_pending_%1", _uid];
if (missionNamespace getVariable [_pendingKey, false]) exitWith {hint "TEL launch authorization is already pending."};
missionNamespace setVariable [_pendingKey, true];

//--- OA 1.62+ server-only sender. Never use the legacy all-client RequestSpecial transport for secrets.
_sendTelToServer = {
	Private ["_pvf"];
	_pvf = ["SRVFNCRequestSpecial", _this];
	if (!isHostedServer) then {
		WFBE_PVF_RequestSpecial = _pvf;
		publicVariableServer "WFBE_PVF_RequestSpecial";
	} else {
		_pvf Spawn WFBE_SE_FNC_HandlePVF;
	};
};

_capKey = Format ["wfbe_icbm_tel_cap_client_%1", getPlayerUID player];
_challengeKey = Format ["wfbe_icbm_tel_auth_challenge_%1", getPlayerUID player];
_cap = missionNamespace getVariable [_capKey, []];
_capValid = false;
if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
	if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
		if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
	};
};

if (!_capValid) then {
	_challenge = Format ["%1:%2:%3", _uid, floor (diag_tickTime * 1000), floor (random 1000000000)];
	missionNamespace setVariable [_challengeKey, _challenge];
	["icbm-tel-auth",player,_challenge] Call _sendTelToServer;
	_capDeadline = time + 5;
	waitUntil {
		sleep 0.05;
		_cap = missionNamespace getVariable [_capKey, []];
		_capValid = false;
		if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
			if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
				if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
			};
		};
		_capValid || {time >= _capDeadline}
	};
	missionNamespace setVariable [_challengeKey, ""];
};

if (!_capValid) exitWith {
	missionNamespace setVariable [_pendingKey, false];
	hint "TEL launch authorization timed out. Try again.";
};

_token = _cap select 0;
missionNamespace setVariable [_capKey, []];
["icbm-tel-fire",_side,_target,_muni,_team,_fee,_platform,player,_token] Call _sendTelToServer;
missionNamespace setVariable [_pendingKey, false];
