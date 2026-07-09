//--- fix/own-marker-dest-dir-split (owner 2026-07-09): shared TP-17 destination-position lookup.
//--- Extracted so the OWNMarker block and the per-team player-leader block in
//--- Client/FSM/updateteamsmarkers.sqf both compute the DEST_DIR bearing from the SAME
//--- 3-source priority instead of two independently-maintained copies (which is what let
//--- the two co-located arrows disagree and visibly "double"). See RC29 note in that file.
//--- Priority: (1) last shift-click map order stored in
//--- WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION (only when it belongs to _unit's own
//--- group - same source used by Client_SendSpawnedUnitsToLeaderWaypoint), (2) current group
//--- waypoint via currentWaypoint/waypointPosition on _unit's group, (3) engine
//--- expectedDestination on _unit (DoNotPlan = no active destination). Returns [] when no
//--- destination source is usable (caller keeps its existing getDir facing fallback).
//--- A2-OA-1.64-safe: missionNamespace getVariable / group / waypoints / currentWaypoint /
//--- waypointPosition / expectedDestination / select / count / distance.
//--- Param: [_unit] - the object (player or AI leader) to resolve a destination for.
private ["_unit","_destPos","_destStoredGrp","_destStoredPos","_destWpCount","_destWpIdx","_destData","_destMode"];
_unit = _this select 0;
_destPos = [];

//--- Source 1: stored shift-click map order (missionNamespace-local, this client).
if (count _destPos == 0) then {
	_destStoredGrp = missionNamespace getVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", grpNull];
	_destStoredPos = missionNamespace getVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", []];
	if (!isNull _destStoredGrp && {_destStoredGrp == group _unit} && {count _destStoredPos > 1}) then {
		if (_unit distance _destStoredPos > 25) then {
			_destPos = _destStoredPos;
		};
	};
};

//--- Source 2: current group waypoint (local to this client for a local group).
if (count _destPos == 0) then {
	_destWpCount = count (waypoints group _unit);
	_destWpIdx   = currentWaypoint group _unit;
	if (_destWpCount > 0 && {_destWpIdx < _destWpCount}) then {
		_destPos = waypointPosition [group _unit, _destWpIdx];
		if ((_destPos select 0) == 0 && {(_destPos select 1) == 0}) then {_destPos = []};
		if (count _destPos > 0) then {
			if (_unit distance _destPos <= 25) then {_destPos = []};
		};
	};
};

//--- Source 3: engine expectedDestination on _unit (DoNotPlan = no active dest).
if (count _destPos == 0) then {
	_destData = expectedDestination _unit;
	_destMode = "DoNotPlan";
	if (count _destData > 1) then {_destMode = _destData select 1};
	if (_destMode != "DoNotPlan") then {
		_destPos = _destData select 0;
		if ((_destPos select 0) == 0 && {(_destPos select 1) == 0}) then {_destPos = []};
		if (count _destPos > 0) then {
			if (_unit distance _destPos <= 25) then {_destPos = []};
		};
	};
};

_destPos
