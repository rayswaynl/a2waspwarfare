/*
	Server receives PVF Here.
	 Parameters:
		- Server PVF
*/

Private ["_code","_parameters","_publicVar","_script"];

_publicVar = _this;

_script = _publicVar select 0;
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};

_code = missionNamespace getVariable _script;
if (!(isNil "_code") && {typeName _code == "CODE"}) then {_parameters Spawn _code};