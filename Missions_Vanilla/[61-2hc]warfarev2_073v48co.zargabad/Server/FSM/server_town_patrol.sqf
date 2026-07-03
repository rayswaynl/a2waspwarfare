Private["_aliveTeam","_currentSV","_defense_range","_focus","_lastMode","_lastSV","_location","_mode","_patrol_range","_perfModeChange","_perfScope","_perfStart","_sideChanged","_sideID","_startSV","_supplyDrop","_team","_townContested"];

_location = _this select 0;
_team = _this select 1;
_sideID = _this select 2;
_focus = if (count _this > 3) then {_this select 3} else {objNull};

// Marty: Town unit creation can fail under engine limits; do not keep a patrol script alive for a null group.
if (isNull _team) exitWith {};

_lastSV = _location getVariable 'supplyValue';
_startSV = _location getVariable 'startingSupplyValue';
_mode = "patrol";
_lastMode = "nil";

_patrol_range = missionNamespace getVariable 'WFBE_C_TOWNS_PATROL_RANGE';
_defense_range = missionNamespace getVariable 'WFBE_C_TOWNS_DEFENSE_RANGE';
_aliveTeam = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

// Marty: Stop the patrol monitor as soon as the team is gone; dead empty loops accumulate over long games.
while {!WFBE_GameOver && _aliveTeam} do {
	// Marty: Performance Audit for per-town-team patrol scripts spawned by town AI.
	_perfStart = diag_tickTime;
	_perfModeChange = 0;
	_aliveTeam = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	_currentSV = _location getVariable 'supplyValue';
	_sideChanged = !(_sideID in [_location getVariable 'sideID']);
	_supplyDrop = (_currentSV < _lastSV || _currentSV < _startSV);
	_townContested = _location getVariable ["wfbe_contested", false];
	if (_sideChanged || {_supplyDrop && {((missionNamespace getVariable ["WFBE_C_TOWNS_PATROL_CONTESTED_ONLY", 0]) < 1 || {_townContested})}}) then {
		_mode = "defense";
	} else {
		_mode = "patrol";
	};

	_lastSV = _currentSV;
	
	if(_aliveTeam && _mode != _lastMode && !WFBE_GameOver) then {
		_lastMode = _mode;
		_perfModeChange = 1;

		if (_mode == "patrol") then {
			if (isNull _focus) then {
				[_team,_location,_patrol_range] Spawn WFBE_CO_FNC_WaypointPatrolTown;
			} else {
				[_team,_focus,_patrol_range/4] Spawn WFBE_CO_FNC_WaypointPatrol;
			};
		} else {
			[_team,getPos _location,'SAD',_defense_range] Spawn WFBE_CO_FNC_WaypointSimple;
		};
	};
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
			["town_patrol", diag_tickTime - _perfStart, Format["town:%1;side:%2;alive:%3;units:%4;mode:%5;changed:%6;focus:%7", _location getVariable "name", _sideID, _aliveTeam, count (units _team), _mode, _perfModeChange, !(isNull _focus)], _perfScope] Call PerformanceAudit_Record;
		};
	};
	sleep 30;
};
