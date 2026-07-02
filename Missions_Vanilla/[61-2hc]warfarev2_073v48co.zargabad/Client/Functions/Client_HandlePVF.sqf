/*
	Client receives PVF Here.
	 Parameters:
		- Client PVF
*/

Private ["_code","_destination","_exit","_hcAllowed","_isHeadless","_parameters","_publicVar","_script"];

_publicVar = _this;
_exit = true;

_destination = _publicVar select 0;
_script = _publicVar select 1;
_parameters = if (count _this > 2) then {_publicVar select 2} else {[]};

_isHeadless = if !(isNil "isHeadLessClient") then {isHeadLessClient} else {!(hasInterface || isDedicated)};
if (_isHeadless) then {
	_hcAllowed = false;
	if (_script == "CLTFNCHandleSpecial" && (typeName _parameters) == "ARRAY" && count _parameters > 0) then {
		_hcAllowed = ((_parameters select 0) in ["delegate-townai","delegate-ai-static-defence"]);
	};
	if !(_hcAllowed) exitWith {};
	_exit = false;
};

if (isNil '_destination') then {_destination = 0;_exit = false};
if (typeName(_destination) == 'SIDE') then {if !(isNil "sideJoined") then {if (sideJoined == _destination) then {_exit = false}}};
if (typeName(_destination) == 'STRING') then {if (isMultiplayer) then {if (getPlayerUID player == _destination) then {_exit = false}} else {_exit = true}};

if (_exit) exitWith {};

_code = missionNamespace getVariable _script;
if (!(isNil "_code") && {typeName _code == "CODE"}) then {_parameters Spawn _code};
