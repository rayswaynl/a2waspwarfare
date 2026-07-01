/*
	Server receives PVF Here.
	 Parameters:
		- Server PVF
*/

Private ["_code","_parameters","_publicVar","_script"];

_publicVar = _this;

_script = _publicVar select 0;
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};

if (isNil "WFBE_SE_PVF_ALLOWED" || {!(_script in WFBE_SE_PVF_ALLOWED)}) exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};

_code = missionNamespace getVariable _script;
if (isNil "_code" || {typeName _code != "CODE"}) exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: registered PVF handler [%1] is not CODE.", _script]] Call WFBE_CO_FNC_LogContent;
};

_parameters Spawn _code;
