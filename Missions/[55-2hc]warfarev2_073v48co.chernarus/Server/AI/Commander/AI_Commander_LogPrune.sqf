/*
	AI Commander structured log prune helper.
	Parameter: _side
	Keeps structured logs bounded. Fails soft.
*/

Private ["_side","_logik","_logs","_max"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_logs = _logik getVariable ["wfbe_aicom_logs", []];
_max = 200;

while {count _logs > _max} do {
	_logs set [0, false];
	_logs = _logs - [false];
};

_logik setVariable ["wfbe_aicom_logs", _logs];
_logik setVariable ["wfbe_aicom_log_last_prune", time];

_logs;