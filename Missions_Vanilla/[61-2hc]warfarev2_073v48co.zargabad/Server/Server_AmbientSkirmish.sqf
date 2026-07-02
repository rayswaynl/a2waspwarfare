/*
	Server_AmbientSkirmish.sqf
	Default-off ambient WEST/EAST foot skirmish cells.

	Lane 180 scope:
	- server-only
	- hard cap: one active cell
	- spawn far from human players and towns
	- no AICOM, town, supply, score, or victory integration
	- self-clean spawned groups after WFBE_C_AMBIENT_SKIRMISH_LIFETIME
*/

scriptName "Server\Server_AmbientSkirmish.sqf";

if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH", 0]) < 1) exitWith {};
if (missionNamespace getVariable ["WFBE_AMBIENT_SKIRMISH_RUNNING", false]) exitWith {
	["INFORMATION", "Server_AmbientSkirmish.sqf: duplicate launch ignored; loop already running."] Call WFBE_CO_FNC_LogContent;
};

missionNamespace setVariable ["WFBE_AMBIENT_SKIRMISH_RUNNING", true];

Private ["_interval","_lifetime","_playerRadius","_townRadius","_min","_max","_tries","_center","_radius",
	"_westClasses","_eastClasses","_activeGroups","_cleanupGroups","_groupAlive","_findPosition","_spawnGroup",
	"_setSkirmishOrders","_activeAlive","_pos","_westPos","_eastPos","_westGrp","_eastGrp","_createFailed"];

_interval     = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_INTERVAL", 600];
_lifetime     = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_LIFETIME", 120];
_playerRadius = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_PLAYER_RADIUS", 1500];
_townRadius   = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_TOWN_RADIUS", 1500];
_min          = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_GROUP_MIN", 2];
_max          = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_GROUP_MAX", 3];
_tries        = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_SPAWN_TRIES", 24];
_center       = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_CENTER", [7680,7680,0]];
_radius       = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_RADIUS", 6200];
_westClasses  = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_WEST_CLASSES", ["USMC_Soldier","USMC_Soldier_LAT","USMC_Soldier_AR"]];
_eastClasses  = missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH_EAST_CLASSES", ["RU_Soldier","RU_Soldier_LAT","RU_Soldier_AR"]];

if (_interval < 60) then {_interval = 60};
if (_lifetime < 30) then {_lifetime = 30};
if (_playerRadius < 500) then {_playerRadius = 500};
if (_townRadius < 500) then {_townRadius = 500};
if (_min < 1) then {_min = 1};
if (_max < _min) then {_max = _min};
if (_tries < 1) then {_tries = 1};
if ((count _center) < 2) then {_center = [7680,7680,0]};

_activeGroups = [];

_cleanupGroups = {
	Private ["_groups","_grp"];
	_groups = _this select 0;
	{
		_grp = _x;
		if !(isNull _grp) then {
			{
				if (!isPlayer _x) then {deleteVehicle _x};
			} forEach units _grp;
		};
	} forEach _groups;
	sleep 0.5;
	{
		_grp = _x;
		if !(isNull _grp) then {deleteGroup _grp};
	} forEach _groups;
};

_groupAlive = {
	Private ["_grp","_alive"];
	_grp = _this select 0;
	_alive = 0;
	if !(isNull _grp) then {
		{
			if (alive _x) then {_alive = _alive + 1};
		} forEach units _grp;
	};
	_alive
};

_findPosition = {
	Private ["_center","_radius","_tries","_playerRadius","_townRadius","_found","_playersOnline","_i",
		"_ang","_dist","_candidate","_tooClose"];
	_center       = _this select 0;
	_radius       = _this select 1;
	_tries        = _this select 2;
	_playerRadius = _this select 3;
	_townRadius   = _this select 4;
	_found = [];
	_playersOnline = 0;

	{
		if (isPlayer _x) then {_playersOnline = _playersOnline + 1};
	} forEach allUnits;

	if (_playersOnline < 1) exitWith {[]};

	for "_i" from 1 to _tries do {
		_ang = random 360;
		_dist = random _radius;
		_candidate = [(_center select 0) + (_dist * sin _ang), (_center select 1) + (_dist * cos _ang), 0];
		_tooClose = false;

		if (surfaceIsWater _candidate) then {_tooClose = true};

		if (!_tooClose) then {
			{
				if (isPlayer _x) then {
					if (alive _x) then {
						if ((vehicle _x) distance _candidate < _playerRadius) then {_tooClose = true};
					};
				};
			} forEach allUnits;
		};

		if (!_tooClose) then {
			if !(isNil "towns") then {
				{
					if (_x distance _candidate < _townRadius) then {_tooClose = true};
				} forEach towns;
			};
		};

		if (!_tooClose) exitWith {_found = _candidate};
	};

	_found
};

_spawnGroup = {
	Private ["_side","_classes","_pos","_tag","_min","_max","_grp","_size","_i","_cls","_unit","_uPos"];
	_side    = _this select 0;
	_classes = _this select 1;
	_pos     = _this select 2;
	_tag     = _this select 3;
	_min     = _this select 4;
	_max     = _this select 5;

	if ((count _classes) < 1) exitWith {grpNull};

	_grp = [_side, _tag] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _grp) exitWith {grpNull};

	_size = _min + floor (random ((_max - _min) + 1));
	for "_i" from 1 to _size do {
		_cls = _classes select (floor (random (count _classes)));
		_uPos = [(_pos select 0) + (random 20) - 10, (_pos select 1) + (random 20) - 10, 0];
		_unit = [_cls, _grp, _uPos, _side] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _unit) then {
			_unit setVariable ["WFBE_IsAmbientSkirmishAI", true, true];
		};
	};

	if ((count units _grp) < 1) exitWith {
		deleteGroup _grp;
		grpNull
	};

	_grp
};

_setSkirmishOrders = {
	Private ["_grp","_target","_wp"];
	_grp = _this select 0;
	_target = _this select 1;
	if (isNull _grp) exitWith {};

	_grp setBehaviour "COMBAT";
	_grp setCombatMode "RED";
	_grp setFormation "WEDGE";
	_grp setSpeedMode "NORMAL";
	_wp = _grp addWaypoint [_target, 30];
	_wp setWaypointType "SAD";
	_wp setWaypointBehaviour "COMBAT";
	_wp setWaypointCombatMode "RED";
	_wp setWaypointSpeed "NORMAL";
	{
		if (alive _x) then {_x doMove _target};
	} forEach units _grp;
};

["INITIALIZATION", Format ["Server_AmbientSkirmish.sqf: enabled (interval=%1, lifetime=%2, playerRadius=%3, townRadius=%4).", _interval, _lifetime, _playerRadius, _townRadius]] Call WFBE_CO_FNC_LogContent;

waitUntil {
	Private ["_townsReady"];
	sleep 5;
	_townsReady = false;
	if !(isNil "towns") then {
		if ((count towns) > 0) then {_townsReady = true};
	};
	_townsReady || WFBE_GameOver
};

if (!WFBE_GameOver) then {
	while {!WFBE_GameOver && ((missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH", 0]) > 0)} do {
		_activeAlive = 0;
		{
			_activeAlive = _activeAlive + ([_x] Call _groupAlive);
		} forEach _activeGroups;

		if (_activeAlive > 0) then {
			diag_log Format ["AMBSKIRMISH|v1|SKIP|t=%1|reason=active|alive=%2", round time, _activeAlive];
		} else {
			_activeGroups = [];
			_pos = [_center, _radius, _tries, _playerRadius, _townRadius] Call _findPosition;

			if ((count _pos) < 2) then {
				diag_log Format ["AMBSKIRMISH|v1|SKIP|t=%1|reason=no_safe_position|tries=%2", round time, _tries];
			} else {
				_westPos = [(_pos select 0) - 35, (_pos select 1) + (random 20) - 10, 0];
				_eastPos = [(_pos select 0) + 35, (_pos select 1) + (random 20) - 10, 0];
				if (surfaceIsWater _westPos) then {_westPos = _pos};
				if (surfaceIsWater _eastPos) then {_eastPos = _pos};

				_westGrp = [west, _westClasses, _westPos, "ambient-skirmish-west", _min, _max] Call _spawnGroup;
				_eastGrp = [east, _eastClasses, _eastPos, "ambient-skirmish-east", _min, _max] Call _spawnGroup;

				_createFailed = false;
				if (isNull _westGrp) then {_createFailed = true};
				if (isNull _eastGrp) then {_createFailed = true};

				if (_createFailed) then {
					[[_westGrp, _eastGrp]] Call _cleanupGroups;
					diag_log Format ["AMBSKIRMISH|v1|SKIP|t=%1|reason=create_failed|pos=%2", round time, _pos];
					["WARNING", Format ["Server_AmbientSkirmish.sqf: create failed at %1; partial groups cleaned.", _pos]] Call WFBE_CO_FNC_LogContent;
				} else {
					[_westGrp, _eastPos] Call _setSkirmishOrders;
					[_eastGrp, _westPos] Call _setSkirmishOrders;
					_activeGroups = [_westGrp, _eastGrp];
					[_activeGroups, _lifetime] spawn {
						Private ["_groups","_lifetime","_grp"];
						_groups = _this select 0;
						_lifetime = _this select 1;
						sleep _lifetime;
						{
							_grp = _x;
							if !(isNull _grp) then {
								{
									if (!isPlayer _x) then {deleteVehicle _x};
								} forEach units _grp;
							};
						} forEach _groups;
						sleep 0.5;
						{
							_grp = _x;
							if !(isNull _grp) then {deleteGroup _grp};
						} forEach _groups;
						diag_log Format ["AMBSKIRMISH|v1|CLEANUP|t=%1|groups=%2", round time, count _groups];
					};
					diag_log Format ["AMBSKIRMISH|v1|SPAWN|t=%1|pos=%2|west=%3|east=%4|life=%5", round time, _pos, count units _westGrp, count units _eastGrp, _lifetime];
					["INFORMATION", Format ["Server_AmbientSkirmish.sqf: spawned ambient skirmish at %1 (WEST %2, EAST %3, lifetime %4s).", _pos, count units _westGrp, count units _eastGrp, _lifetime]] Call WFBE_CO_FNC_LogContent;
				};
			};
		};

		sleep _interval;
	};
};

if ((count _activeGroups) > 0) then {[_activeGroups] Call _cleanupGroups};
missionNamespace setVariable ["WFBE_AMBIENT_SKIRMISH_RUNNING", false];
["INFORMATION", "Server_AmbientSkirmish.sqf: loop ended."] Call WFBE_CO_FNC_LogContent;
