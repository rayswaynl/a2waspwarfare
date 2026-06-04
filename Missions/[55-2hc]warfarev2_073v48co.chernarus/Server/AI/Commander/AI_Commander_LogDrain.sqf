/*
	AI Commander structured log drain helper.
	Parameter: [_side, _afterSeq]
	Returns records with seq greater than _afterSeq. Does not mutate storage.
*/

Private ["_side","_afterSeq","_logik","_logs","_out","_record"];

if (count _this < 2) exitWith {[]};

_side = _this select 0;
_afterSeq = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {[]};

_logs = _logik getVariable ["wfbe_aicom_logs", []];
_out = [];

{
	_record = _x;
	if (typeName _record == "ARRAY") then {
		if (count _record > 0) then {
			if ((_record select 0) > _afterSeq) then {_out set [count _out, _record]};
		};
	};
} forEach _logs;

_out;