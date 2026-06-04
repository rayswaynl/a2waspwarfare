/*
	AI Commander structured log append helper.
	Phase 1: records existing commander behavior without changing decisions.
	Parameter: [_side, _kind, _source, _payload]
*/

Private ["_side","_kind","_source","_payload","_logik","_logs","_seq","_record","_max","_sideText"];

if (count _this < 4) exitWith {};

_side = _this select 0;
_kind = _this select 1;
_source = _this select 2;
_payload = _this select 3;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_logs = _logik getVariable ["wfbe_aicom_logs", []];
_seq = _logik getVariable ["wfbe_aicom_log_seq", 0];
_seq = _seq + 1;

_record = [_seq, _kind, time, _side, _source, _payload];
_logs set [count _logs, _record];

_max = 200;
while {count _logs > _max} do {
	_logs set [0, false];
	_logs = _logs - [false];
};

_logik setVariable ["wfbe_aicom_logs", _logs];
_logik setVariable ["wfbe_aicom_log_seq", _seq];
if (isNil {_logik getVariable "wfbe_aicom_log_last_prune"}) then {_logik setVariable ["wfbe_aicom_log_last_prune", time]};

_sideText = str _side;
["INFORMATION", Format ["AI_Commander_Log: [%1] #%2 %3.", _sideText, _seq, _kind]] Call WFBE_CO_FNC_LogContent;

_record;