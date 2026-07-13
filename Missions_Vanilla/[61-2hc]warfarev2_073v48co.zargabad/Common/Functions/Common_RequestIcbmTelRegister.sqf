Private ["_player","_sendTelToServer","_side","_team","_token","_vehicle"];

//--- Consume the server-issued purchase proof against the exact newly spawned SCUD.
if (typeName _this != "ARRAY" || {count _this != 5}) exitWith {};
_vehicle = _this select 0;
_side = _this select 1;
_team = _this select 2;
_player = _this select 3;
_token = _this select 4;
if (typeName _vehicle != "OBJECT" || {isNull _vehicle}) exitWith {};
if (typeName _side != "SIDE" || {!(_side in [west,east,resistance])}) exitWith {};
if (typeName _team != "GROUP" || {isNull _team}) exitWith {};
if (typeName _player != "OBJECT" || {isNull _player}) exitWith {};
if (typeName _token != "STRING" || {_token == ""}) exitWith {};

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
["icbm-tel-register",_vehicle,_side,_team,_player,_token] Call _sendTelToServer;
