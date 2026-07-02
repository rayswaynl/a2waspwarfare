/*
	Author: Marty
	Description:
		Lightweight local performance audit helpers.
		No network synchronization is used; each client/server writes only to its own RPT.
*/

// Marty: Performance audit is disabled by default unless the mission parameter explicitly enables it.
if (isNil "PerformanceAuditEnabled") then {PerformanceAuditEnabled = ((missionNamespace getVariable ["WFBE_C_PERFORMANCE_AUDIT_ENABLED", 0]) > 0)};
if (isNil "PerformanceAuditFlushInterval") then {PerformanceAuditFlushInterval = 60};
if (isNil "PerformanceAuditData_CLIENT") then {PerformanceAuditData_CLIENT = []};
if (isNil "PerformanceAuditData_SERVER") then {PerformanceAuditData_SERVER = []};
if (isNil "PerformanceAuditMarkerScripts") then {PerformanceAuditMarkerScripts = 0};
if (isNil "PerformanceAuditAARMarkerScripts") then {PerformanceAuditAARMarkerScripts = 0};
// Marty: Create a per-mission audit session id so appended RPT files can be split by game.
if (isNil "PerformanceAuditSessionId") then {
	PerformanceAuditSessionId = Format ["%1_%2_%3", worldName, round diag_tickTime, round (random 1000000)];
};
if (isNil "PerformanceAuditAnchorVersion") then {PerformanceAuditAnchorVersion = "20260524"};

PerformanceAudit_Round2 = {
	round ((_this) * 100) / 100
};

PerformanceAudit_DataName = {
	Format ["PerformanceAuditData_%1", _this]
};

PerformanceAudit_Snapshot = {
	private ["_activeAI","_dayNightEnabled","_dayTime","_fog","_map","_markerScripts","_overcast","_playerName","_players","_profileTerrainGrid","_profileViewDistance","_rain","_scope","_sessionId","_targetFPS","_teams","_townsActive","_uid","_units","_vehicles"];

	_scope = _this select 0;
	// Marty: Include the stable audit session id on every snapshot for post-game analysis.
	_sessionId = missionNamespace getVariable ["PerformanceAuditSessionId", "unknown"];
	// Marty: Include the runtime island name so shared Chernarus/Takistan logs can be sorted safely.
	_map = worldName;
	// Marty: Capture lightweight environment state to correlate FPS with day/night and weather.
	_dayNightEnabled = missionNamespace getVariable ["WFBE_DAYNIGHT_ENABLED", -1];
	_dayTime = daytime call PerformanceAudit_Round2;
	_fog = fog call PerformanceAudit_Round2;
	_overcast = overcast call PerformanceAudit_Round2;
	_rain = rain call PerformanceAudit_Round2;
	_players = 0;
	_activeAI = 0;
	_units = allUnits;
	_vehicles = vehicles;
	_teams = if (isNil "clientTeams") then {-1} else {count clientTeams};
	_townsActive = 0;
	_markerScripts = missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0];
	_playerName = "SERVER";
	_uid = "0";
	_profileViewDistance = -1;
	_targetFPS = -1;
	_profileTerrainGrid = -1;

	// Marty: Include the local player identity when the snapshot is produced on a client.
	if !(isNull player) then {
		_playerName = name player;
		_uid = getPlayerUID player;
	};

	// Marty: Log only mission/profile settings that are already used by this Warfare mission.
	_profileViewDistance = profileNamespace getVariable ["WFBE_PERSISTENT_CONST_VIEW_DISTANCE", -1];
	_targetFPS = profileNamespace getVariable ["WFBE_TARGET_FPS", -1];
	_profileTerrainGrid = profileNamespace getVariable ["WFBE_PERSISTENT_CONST_TERRAIN_GRID", -1];

	{
		if (isPlayer _x) then {
			_players = _players + 1;
		} else {
			if (alive _x) then {_activeAI = _activeAI + 1};
		};
	} forEach _units;

	if !(isNil "towns") then {
		{
			if ((_x getVariable ["wfbe_active", false]) || (_x getVariable ["wfbe_active_air", false])) then {
				_townsActive = _townsActive + 1;
			};
		} forEach towns;
	};

	[
		_scope,
		round diag_fps,
		_players,
		_activeAI,
		count _units,
		count _vehicles,
		_teams,
		_townsActive,
		_markerScripts,
		_playerName,
		_uid,
		viewDistance,
		_profileViewDistance,
		_targetFPS,
		_profileTerrainGrid,
		_map,
		_dayNightEnabled,
		_dayTime,
		_fog,
		_overcast,
		_rain,
		_sessionId
	]
};

PerformanceAudit_Log = {
	private ["_avgMs","_calls","_extra","_maxMs","_name","_snap"];

	_snap = _this select 0;
	_name = _this select 1;
	_calls = _this select 2;
	_avgMs = _this select 3;
	_maxMs = _this select 4;
	_extra = _this select 5;

	diag_log format [
		"[Performance Audit] SID=%27 MAP=%21 DNC=%22 DAYTIME=%23 FOG=%24 OVERCAST=%25 RAIN=%26 SCOPE=%1 PLAYER=""%15"" UID=%16 VD=%17 PVD=%18 TFPS=%19 PTG=%20 NAME=%2 FPS=%3 PLAYERS=%4 AI=%5 UNITS=%6 VEHICLES=%7 TEAMS=%8 TOWNS_ACTIVE=%9 MARKERS=%10 CALLS=%11 AVG_MS=%12 MAX_MS=%13 EXTRA=%14",
		_snap select 0,
		_name,
		_snap select 1,
		_snap select 2,
		_snap select 3,
		_snap select 4,
		_snap select 5,
		_snap select 6,
		_snap select 7,
		_snap select 8,
		_calls,
		_avgMs,
		_maxMs,
		_extra,
		_snap select 9,
		_snap select 10,
		_snap select 11,
		_snap select 12,
		_snap select 13,
		_snap select 14,
		_snap select 15,
		_snap select 16,
		_snap select 17,
		_snap select 18,
		_snap select 19,
		_snap select 20,
		_snap select 21
	];
};

PerformanceAudit_SessionAnchorExtra = {
	Format [
		"state:anchor;anchorVersion:%1;realTime:unavailable_a2oa;diagTick:%2;frame:%3",
		missionNamespace getVariable ["PerformanceAuditAnchorVersion", "unknown"],
		diag_tickTime call PerformanceAudit_Round2,
		diag_frameno
	]
};

PerformanceAudit_Record = {
	private ["_calls","_data","_dataName","_elapsed","_entry","_extra","_found","_i","_max","_name","_scope","_total"];

	if !(missionNamespace getVariable ["PerformanceAuditEnabled", true]) exitWith {};

	_name = _this select 0;
	_elapsed = _this select 1;
	_extra = if (count _this > 2) then {_this select 2} else {""};
	_scope = if (count _this > 3) then {_this select 3} else {if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"}};
	_dataName = _scope call PerformanceAudit_DataName;
	_data = missionNamespace getVariable [_dataName, []];
	_found = false;

	for "_i" from 0 to ((count _data) - 1) do {
		_entry = _data select _i;
		if ((_entry select 0) == _name) exitWith {
			_calls = (_entry select 1) + 1;
			_total = (_entry select 2) + _elapsed;
			_max = _entry select 3;
			if (_elapsed > _max) then {_max = _elapsed};
			_entry set [1, _calls];
			_entry set [2, _total];
			_entry set [3, _max];
			if (_extra != "") then {_entry set [4, _extra]};
			_data set [_i, _entry];
			_found = true;
		};
	};

	if !(_found) then {
		_data set [count _data, [_name, 1, _elapsed, _elapsed, _extra]];
	};

	missionNamespace setVariable [_dataName, _data];
};

PerformanceAudit_Flush = {
	private ["_avgMs","_calls","_data","_dataName","_entry","_extra","_maxMs","_scope","_snap"];

	if !(missionNamespace getVariable ["PerformanceAuditEnabled", true]) exitWith {};

	_scope = _this select 0;
	_snap = [_scope] call PerformanceAudit_Snapshot;
	_dataName = _scope call PerformanceAudit_DataName;
	_data = missionNamespace getVariable [_dataName, []];

	[_snap, "snapshot", 1, 0, 0, "periodic"] call PerformanceAudit_Log;

	{
		_entry = _x;
		_calls = _entry select 1;
		if (_calls > 0) then {
			_avgMs = (((_entry select 2) / _calls) * 1000) call PerformanceAudit_Round2;
			_maxMs = ((_entry select 3) * 1000) call PerformanceAudit_Round2;
			_extra = if (count _entry > 4) then {_entry select 4} else {""};
			[_snap, _entry select 0, _calls, _avgMs, _maxMs, _extra] call PerformanceAudit_Log;
		};
	} forEach _data;

	missionNamespace setVariable [_dataName, []];
};

PerformanceAudit_Run = {
	private ["_anchorExtra","_scope"];

	if !(missionNamespace getVariable ["PerformanceAuditEnabled", true]) exitWith {};

	_scope = _this select 0;
	_anchorExtra = call PerformanceAudit_SessionAnchorExtra;
	[[_scope] call PerformanceAudit_Snapshot, "session", 1, 0, 0, _anchorExtra] call PerformanceAudit_Log;
	[[_scope] call PerformanceAudit_Snapshot, "session", 1, 0, 0, "state:start"] call PerformanceAudit_Log;

	while {true} do {
		sleep (missionNamespace getVariable ["PerformanceAuditFlushInterval", 60]);
		[_scope] call PerformanceAudit_Flush;
		if !(isNil "gameOver") then {
			if (gameOver) exitWith {};
		};
	};

	[_scope] call PerformanceAudit_Flush;
};
