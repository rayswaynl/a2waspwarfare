Private ["_cap","_capDeadline","_capKey","_capValid","_challenge","_challengeKey","_clientCost","_factory","_factoryType","_params","_pendingKey","_proof","_sendTelToServer","_side","_team","_token","_uid","_unit"];

//--- Ask the server to certify this exact HF purchase before the client build starts. The
//--- server binds the proof to player UID, team, side, factory, configured SCUD class, price,
//--- and build window; Client_BuildUnit later consumes it against the exact spawned hull.
if (typeName _this != "ARRAY" || {count _this != 6}) exitWith {};
_params = _this select 0;
_factory = _this select 1;
_unit = _this select 2;
_side = _this select 3;
_team = _this select 4;
_clientCost = _this select 5;
if (typeName _params != "ARRAY" || {count _params != 6}) exitWith {};
if (typeName _factory != "OBJECT" || {isNull _factory}) exitWith {};
if (typeName _unit != "STRING") exitWith {};
if (typeName _side != "SIDE" || {!(_side in [west,east,resistance])}) exitWith {};
if (typeName _team != "GROUP" || {isNull _team}) exitWith {};
if (typeName _clientCost != "SCALAR" || {_clientCost < 0}) exitWith {};
if (isNull player || {!alive player} || {!isPlayer player}) exitWith {};

_uid = getPlayerUID player;
if (_uid == "") exitWith {};
_pendingKey = Format ["wfbe_icbm_tel_purchase_pending_%1", _uid];
if (missionNamespace getVariable [_pendingKey, false]) exitWith {
	_factoryType = _params select 3;
	missionNamespace setVariable [Format ["WFBE_C_QUEUE_%1",_factoryType],((missionNamespace getVariable Format ["WFBE_C_QUEUE_%1",_factoryType])-1) max 0];
	hint "A SCUD purchase authorization is already pending.";
};
missionNamespace setVariable [_pendingKey, true];

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

_capKey = Format ["wfbe_icbm_tel_purchase_cap_client_%1", _uid];
_challengeKey = Format ["wfbe_icbm_tel_purchase_challenge_%1", _uid];
missionNamespace setVariable [_capKey, []];
_challenge = Format ["%1:%2:%3", _uid, floor (diag_tickTime * 1000), floor (random 1000000000)];
missionNamespace setVariable [_challengeKey, _challenge];
["icbm-tel-purchase-auth",player,_challenge,_factory,_unit] Call _sendTelToServer;

_capDeadline = time + 5;
_proof = [];
waitUntil {
	sleep 0.05;
	_proof = missionNamespace getVariable [_capKey, []];
	(count _proof >= 3) || {time >= _capDeadline}
};
missionNamespace setVariable [_challengeKey, ""];
missionNamespace setVariable [_pendingKey, false];

_capValid = false;
if (typeName _proof == "ARRAY" && {count _proof >= 3}) then {
	if (typeName (_proof select 0) == "STRING" && {typeName (_proof select 1) == "SCALAR"}) then {
		if ((_proof select 0) != "" && {(_proof select 1) > time}) then {_capValid = true};
	};
};
if (!_capValid) exitWith {
	_factoryType = _params select 3;
	missionNamespace setVariable [Format ["WFBE_C_QUEUE_%1",_factoryType],((missionNamespace getVariable Format ["WFBE_C_QUEUE_%1",_factoryType])-1) max 0];
	if (typeName _proof == "ARRAY" && {count _proof >= 3} && {typeName (_proof select 2) == "STRING"}) then {
		hint parseText Format ["<t color='#ff5a5a'>SCUD purchase refused: %1</t>", _proof select 2];
	} else {
		hint "SCUD purchase authorization timed out. Nothing was charged.";
	};
};

_token = _proof select 0;
missionNamespace setVariable [_capKey, []];
_params set [6, _token];
_params Spawn BuildUnit;
if (_clientCost > 0) then {-(_clientCost) Call ChangePlayerFunds};
