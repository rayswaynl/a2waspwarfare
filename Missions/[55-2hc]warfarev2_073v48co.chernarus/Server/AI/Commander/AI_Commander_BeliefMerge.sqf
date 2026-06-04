/*
	AI Commander belief merge helper.
	Phase 2: merges context candidates without changing decisions.
	Parameter: [_side, _context, _candidate]
*/

Private ["_side","_context","_candidate","_enemy","_category","_pos","_town","_best","_bestIndex","_idx","_belief","_bEnemy","_bCategory","_bPos","_bTown","_radius","_matchCategory","_sameTown","_oldConf","_newConf","_bonus","_sources","_newSources","_src","_countMin","_countMax","_status","_limit"];

if (count _this < 3) exitWith {[]};

_side = _this select 0;
_context = _this select 1;
_candidate = _this select 2;
if (typeName _context != "ARRAY") exitWith {[]};
if (typeName _candidate != "ARRAY") exitWith {_context};
if (count _candidate < 13) exitWith {_context};

_enemy = _candidate select 1;
_category = _candidate select 2;
_pos = _candidate select 3;
_town = _candidate select 4;

_radius = 400;
if (_category == "infantry") then {_radius = 300};
if (_category == "armor") then {_radius = 600};
if (_category == "air") then {_radius = 1200};
if (_category == "support") then {_radius = 600};

_best = [];
_bestIndex = -1;
_idx = 0;
{
	_belief = _x;
	if (typeName _belief == "ARRAY") then {
		if (count _belief >= 13) then {
			_bEnemy = _belief select 1;
			_bCategory = _belief select 2;
			_bPos = _belief select 3;
			_bTown = _belief select 4;
			_matchCategory = false;
			if (_bCategory == _category) then {_matchCategory = true};
			if (_bCategory == "unknown") then {_matchCategory = true};
			if (_category == "unknown") then {_matchCategory = true};
			if (_bEnemy == _enemy) then {
				if (_matchCategory) then {
					if (typeName _pos == "ARRAY") then {
						if (typeName _bPos == "ARRAY") then {
							if ((_pos distance _bPos) <= _radius) then {
								_sameTown = false;
								if (isNull _town) then {_sameTown = true};
								if (isNull _bTown) then {_sameTown = true};
								if (_town == _bTown) then {_sameTown = true};
								if (_sameTown) then {
									_best = _belief;
									_bestIndex = _idx;
								};
							};
						};
					};
				};
			};
		};
	};
	_idx = _idx + 1;
} forEach _context;

if (_bestIndex >= 0) then {
	_oldConf = _best select 8;
	_newConf = _candidate select 8;
	_bonus = 0.02;
	_sources = _best select 11;
	_newSources = _candidate select 11;
	if (typeName _sources != "ARRAY") then {_sources = []};
	if (typeName _newSources != "ARRAY") then {_newSources = []};
	{
		_src = _x;
		if (!(_src in _sources)) then {
			_sources set [count _sources, _src];
			_bonus = _bonus + 0.08;
		};
	} forEach _newSources;
	while {count _sources > 6} do {
		_sources set [0, false];
		_sources = _sources - [false];
	};

	_countMin = _best select 6;
	if ((_candidate select 6) >= 0) then {
		if (_countMin < 0) then {_countMin = _candidate select 6} else {_countMin = _countMin min (_candidate select 6)};
	};
	_countMax = _best select 7;
	if ((_candidate select 7) >= 0) then {_countMax = _countMax max (_candidate select 7)};
	_status = _best select 12;
	if ((_candidate select 12) == "active") then {_status = "active"};

	_best set [2, if ((_best select 2) == "unknown") then {_category} else {_best select 2}];
	_best set [3, _pos];
	_best set [4, _town];
	_best set [5, _candidate select 5];
	_best set [6, _countMin];
	_best set [7, _countMax];
	_best set [8, 0.95 min ((_oldConf max _newConf) + _bonus)];
	_best set [9, (_best select 9) min (_candidate select 9)];
	_best set [10, (_best select 10) max (_candidate select 10)];
	_best set [11, _sources];
	_best set [12, _status];
	_context set [_bestIndex, _best];
} else {
	_context set [count _context, _candidate];
};

_limit = 50;
while {count _context > _limit} do {
	_context set [0, false];
	_context = _context - [false];
};

_context;
