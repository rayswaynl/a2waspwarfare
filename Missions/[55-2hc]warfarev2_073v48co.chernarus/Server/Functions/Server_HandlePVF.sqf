/*
	Server receives PVF Here.
	 Parameters:
		- Server PVF
*/

Private ["_code","_parameters","_publicVar","_script"];

_publicVar = _this;

if (isNil "_publicVar") exitWith {
	["WARNING", "Server_HandlePVF.sqf: rejected nil PVF payload."] Call WFBE_CO_FNC_LogContent;
};
if (typeName _publicVar != "ARRAY") exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: rejected malformed PVF payload type [%1].", typeName _publicVar]] Call WFBE_CO_FNC_LogContent;
};
if (count _publicVar < 1) exitWith {
	["WARNING", "Server_HandlePVF.sqf: rejected empty PVF payload."] Call WFBE_CO_FNC_LogContent;
};

_script = _publicVar select 0;
if (isNil "_script") exitWith {
	["WARNING", "Server_HandlePVF.sqf: rejected PVF payload with nil handler name."] Call WFBE_CO_FNC_LogContent;
};
if (typeName _script != "STRING") exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: rejected PVF payload with invalid handler name [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};

if (isNil "WFBE_SE_PVF_ALLOWED" || {!(_script in WFBE_SE_PVF_ALLOWED)}) exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};

_code = missionNamespace getVariable _script;
if (isNil "_code" || {typeName _code != "CODE"}) exitWith {
	["WARNING", Format ["Server_HandlePVF.sqf: registered PVF handler [%1] is not CODE.", _script]] Call WFBE_CO_FNC_LogContent;
};

_parameters Spawn _code;
