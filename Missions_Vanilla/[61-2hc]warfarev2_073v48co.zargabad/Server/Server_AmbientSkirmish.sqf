/*
	Server-side ambient skirmish cells.
	Lane 180: default-off background WEST/EAST firefights away from towns and players.
*/

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH", 0]) <= 0) exitWith {};

Private ["_active","_cell","_cellAlive","_center","_cleanupCell","_count","_drop","_eastID","_eastPool","_findCellPos","_height","_interval","_margin","_maxX","_maxY","_minX","_minY","_nextSpawn","_now","_p","_playerNearCell","_playerMin","_pos","_radius","_reason","_spawnCell","_townMin","_ttl","_westID","_westPool","_width"];

waitUntil {sleep 1; !isNil "townInit" && {townInit}};

_interval  = (missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_INTERVAL", 300]) max 60;
_ttl       = (missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_TTL", 120]) max 30;
_playerMin = (missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_PLAYER_MIN", 1500]) max 600;
_townMin   = (missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_TOWN_MIN", 1500]) max 600;
_radius    = (missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_RADIUS", 90]) max 40;

_westID = west Call WFBE_CO_FNC_GetSideID;
_eastID = east Call WFBE_CO_FNC_GetSideID;
_westPool = ["US_Soldier_EP1","US_Soldier_AR_EP1","US_Soldier_LAT_EP1"];
_eastPool = ["RU_Soldier","RU_Soldier_AR","RU_Soldier_LAT"];

_margin = _townMin + 400;
_minX = 99999;
_maxX = -99999;
_minY = 99999;
_maxY = -99999;
{
	_p = getPos _x;
	if ((_p select 0) < _minX) then {_minX = _p select 0};
	if ((_p select 0) > _maxX) then {_maxX = _p select 0};
	if ((_p select 1) < _minY) then {_minY = _p select 1};
	if ((_p select 1) > _maxY) then {_maxY = _p select 1};
} forEach towns;

if (_maxX < _minX) then {
	_minX = 0;
	_maxX = 15360;
	_minY = 0;
	_maxY = 15360;
} else {
	_minX = (_minX - _margin) max 0;
	_maxX = _maxX + _margin;
	_minY = (_minY - _margin) max 0;
	_maxY = _maxY + _margin;
};

_width = _maxX - _minX;
_height = _maxY - _minY;
if (_width < 1 || {_height < 1}) then {
	_minX = 0;
	_maxX = 15360;
	_minY = 0;
	_maxY = 15360;
	_width = _maxX - _minX;
	_height = _maxY - _minY;
};

_cleanupCell = {
	Private ["_entry","_grp"];
	_entry = _this;
	{
		_grp = _x;
		if (!isNull _grp) then {
			{if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _grp);
			deleteGroup _grp;
		};
	} forEach [_entry select 0, _entry select 1];
};

_cellAlive = {
	Private ["_aliveE","_aliveW","_entry","_grpE","_grpW"];
	_entry = _this;
	_grpW = _entry select 0;
	_grpE = _entry select 1;
	_aliveW = false;
	_aliveE = false;
	if (!isNull _grpW) then {if (({alive _x} count (units _grpW)) > 0) then {_aliveW = true}};
	if (!isNull _grpE) then {if (({alive _x} count (units _grpE)) > 0) then {_aliveE = true}};
	_aliveW && {_aliveE}
};

_playerNearCell = {
	Private ["_entry","_near","_p0"];
	_entry = _this;
	_p0 = _entry select 3;
	_near = false;
	{
		if (!_near && {isPlayer _x} && {alive _x} && {(_x distance _p0) < _playerMin}) then {_near = true};
	} forEach allUnits;
	_near
};

_findCellPos = {
	Private ["_cand","_i","_ok","_road","_roads","_tx","_ty"];
	_cand = [];
	_i = 0;
	while {(count _cand) < 1 && {_i < 45}} do {
		_tx = _minX + (random _width);
		_ty = _minY + (random _height);
		_cand = [_tx, _ty, 0];
		_roads = _cand nearRoads 250;
		if ((count _roads) > 0) then {
			_road = _roads select (floor (random (count _roads)));
			_cand = getPos _road;
		};
		_cand = [_cand, 25] Call WFBE_CO_FNC_GetEmptyPosition;
		_ok = true;
		if (surfaceIsWater _cand) then {_ok = false};
		{
			if (_ok && {isPlayer _x} && {alive _x} && {(_x distance _cand) < _playerMin}) then {_ok = false};
		} forEach allUnits;
		{
			if (_ok && {(_x distance _cand) < _townMin}) then {_ok = false};
		} forEach towns;
		if (!_ok) then {_cand = []};
		_i = _i + 1;
	};
	_cand
};

_spawnCell = {
	Private ["_builtE","_builtW","_center","_cls","_count","_dir","_ePos","_eSpawn","_grpE","_grpW","_i","_off","_u","_wPos","_wSpawn"];
	_center = _this;
	_count = 2 + floor (random 2);
	_dir = random 360;
	_off = 45 + random 25;
	_wSpawn = [(_center select 0) + ((sin _dir) * _off), (_center select 1) + ((cos _dir) * _off), 0];
	_eSpawn = [(_center select 0) - ((sin _dir) * _off), (_center select 1) - ((cos _dir) * _off), 0];
	_wSpawn = [_wSpawn, 12] Call WFBE_CO_FNC_GetEmptyPosition;
	_eSpawn = [_eSpawn, 12] Call WFBE_CO_FNC_GetEmptyPosition;
	if (surfaceIsWater _wSpawn) then {_wSpawn = _center};
	if (surfaceIsWater _eSpawn) then {_eSpawn = _center};

	_grpW = [west, "ambient-skirmish"] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _grpW) exitWith {[]};
	_grpE = [east, "ambient-skirmish"] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _grpE) exitWith {
		deleteGroup _grpW;
		[]
	};

	_builtW = 0;
	_builtE = 0;
	for [{_i = 0},{_i < _count},{_i = _i + 1}] do {
		_wPos = [(_wSpawn select 0) + (random 12) - (random 12), (_wSpawn select 1) + (random 12) - (random 12), 0];
		_ePos = [(_eSpawn select 0) + (random 12) - (random 12), (_eSpawn select 1) + (random 12) - (random 12), 0];
		_cls = if (_i < 1) then {"US_Soldier_TL_EP1"} else {_westPool select (floor (random (count _westPool)))};
		_u = [_cls, _grpW, _wPos, _westID, false] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _u) then {_builtW = _builtW + 1};
		_cls = if (_i < 1) then {"RU_Soldier_TL"} else {_eastPool select (floor (random (count _eastPool)))};
		_u = [_cls, _grpE, _ePos, _eastID, false] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _u) then {_builtE = _builtE + 1};
	};

	if (_builtW < 1 || {_builtE < 1}) exitWith {
		[_grpW, _grpE, time, _center] call _cleanupCell;
		diag_log format ["AMBIENTSKIRMISH|SPAWNFAIL|pos=%1|west=%2|east=%3", _center, _builtW, _builtE];
		[]
	};

	[_grpW, true, [[_center, "SAD", _radius, 25, "", []], [_wSpawn, "MOVE", 25, 20, "", []], [_center, "CYCLE", 10, 20, "", []]]] Call AIWPAdd;
	[_grpE, true, [[_center, "SAD", _radius, 25, "", []], [_eSpawn, "MOVE", 25, 20, "", []], [_center, "CYCLE", 10, 20, "", []]]] Call AIWPAdd;
	_grpW setBehaviour "COMBAT";
	_grpW setCombatMode "RED";
	_grpW setFormation "WEDGE";
	_grpW setSpeedMode "NORMAL";
	_grpE setBehaviour "COMBAT";
	_grpE setCombatMode "RED";
	_grpE setFormation "WEDGE";
	_grpE setSpeedMode "NORMAL";

	{
		_u = _x;
		{if (alive _x) then {_u reveal _x}} forEach (units _grpE);
	} forEach (units _grpW);
	{
		_u = _x;
		{if (alive _x) then {_u reveal _x}} forEach (units _grpW);
	} forEach (units _grpE);

	diag_log format ["AMBIENTSKIRMISH|SPAWN|pos=%1|west=%2|east=%3|ttl=%4", _center, _builtW, _builtE, _ttl];
	["INFORMATION", Format ["Server_AmbientSkirmish.sqf: spawned ambient skirmish at [%1] (%2 WEST / %3 EAST).", _center, _builtW, _builtE]] Call WFBE_CO_FNC_LogContent;
	[_grpW, _grpE, time, _center, _builtW, _builtE]
};

_active = [];
_nextSpawn = time + 30;

while {(missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH", 0]) > 0} do {
	_now = time;
	if ((count _active) > 0) then {
		_cell = _active select 0;
		_drop = false;
		_reason = "";
		if ((_now - (_cell select 2)) > _ttl) then {_drop = true; _reason = "ttl"};
		if (!_drop && {!(_cell call _cellAlive)}) then {_drop = true; _reason = "wiped"};
		if (!_drop && {_cell call _playerNearCell}) then {_drop = true; _reason = "player-near"};
		if (_drop) then {
			_cell call _cleanupCell;
			_active = [];
			_nextSpawn = _now + _interval;
			diag_log format ["AMBIENTSKIRMISH|DESPAWN|pos=%1|reason=%2", _cell select 3, _reason];
		};
	};

	if ((count _active) < 1 && {_now >= _nextSpawn}) then {
		_pos = call _findCellPos;
		if ((count _pos) > 0) then {
			_cell = _pos call _spawnCell;
			if ((count _cell) > 0) then {
				_active = [_cell];
				_nextSpawn = _now + _interval;
			} else {
				_nextSpawn = _now + 60;
			};
		} else {
			diag_log format ["AMBIENTSKIRMISH|NOSPOT|playerMin=%1|townMin=%2", _playerMin, _townMin];
			_nextSpawn = _now + _interval;
		};
	};

	sleep 15;
};

if ((count _active) > 0) then {
	_cell = _active select 0;
	_cell call _cleanupCell;
	diag_log format ["AMBIENTSKIRMISH|DESPAWN|pos=%1|reason=disabled", _cell select 3];
};
