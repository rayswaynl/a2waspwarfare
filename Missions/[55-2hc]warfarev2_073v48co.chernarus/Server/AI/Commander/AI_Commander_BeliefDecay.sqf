/*
	AI Commander belief decay helper.
	Phase 2: keeps context bounded and stale beliefs harmless.
	Parameter: [_side, _context]
*/

Private ["_side","_context","_out","_belief","_age","_conf","_status","_decay","_expired","_limit"];

if (count _this < 2) exitWith {[]};

_side = _this select 0;
_context = _this select 1;
if (typeName _context != "ARRAY") exitWith {[]};

_out = [];
{
	_belief = _x;
	if (typeName _belief == "ARRAY") then {
		if (count _belief >= 13) then {
			_age = time - (_belief select 10);
			_conf = _belief select 8;
			_status = _belief select 12;
			_decay = 0;
			if (_age > 120) then {_decay = 0.03};
			if (_age > 300) then {_decay = 0.08};
			if (_age > 600) then {_decay = 0.16};
			_conf = 0 max (_conf - _decay);
			if (_conf < 0.25) then {_status = "stale"};
			_expired = false;
			if (_conf < 0.10) then {_expired = true};
			if (_age > 900) then {_expired = true};
			if (_expired) then {_status = "expired"};
			_belief set [8, _conf];
			_belief set [12, _status];
			if (_status != "expired") then {_out set [count _out, _belief]};
		};
	};
} forEach _context;

_limit = 50;
while {count _out > _limit} do {
	_out set [0, false];
	_out = _out - [false];
};

_out;
