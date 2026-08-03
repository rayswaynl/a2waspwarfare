/*
	Set a team on patrol.
	 Parameters:
		- Team.
		- Destination.
		- {Radius}.
*/

Private ["_behaviours","_destination","_maxWaypoints","_pos","_radius","_rand1","_rand2","_team","_type","_waterRetries","_waterRetryCap","_wps"];
_team = _this select 0;
_destination = _this select 1;
_radius = _this select 2;
//--- r41 patrol-waypoint: server_town_patrol spawns with only 3 args (team, focus, radius).
//--- Bare select 3 on a 3-arg payload is Zero divisor and aborts the whole focus-patrol path.
_maxWaypoints = if (count _this > 3) then {_this select 3} else {missionNamespace getVariable ["WFBE_C_TOWNS_UNITS_WAYPOINTS", 8]};
if (typeName _maxWaypoints != "SCALAR") then {_maxWaypoints = 8};
if (_maxWaypoints < 1) then {_maxWaypoints = 1}; //--- at least one MOVE before CYCLE needs 2 nodes total (0..max)
_behaviours = if (count _this > 4) then {_this select 4} else {[]};
if (typeName _destination == 'OBJECT') then {_destination = getPos _destination};
_waterRetryCap = missionNamespace getVariable ["WFBE_C_WAYPOINT_WATER_RETRY_CAP", 0];
//--- r41: cap<=0 used to mean "retry forever while water" (unbounded while) AND skipped the dry fallback.
//--- Match AI_Patrol.sqf: hard retry budget then snap to destination if still water.
if (typeName _waterRetryCap != "SCALAR" || {_waterRetryCap <= 0}) then {_waterRetryCap = 20};

//--- r110 (alife close-terrain formation/spacing, bughunt card ...r110-20260803): this FOCUS-patrol
//--- path is only ever called from server_town_patrol.sqf with a camp focus at radius/4 - the
//--- tightest close-terrain beat in the town system - but unlike its town-center sibling
//--- (Common_WaypointPatrolTown.sqf, DIAMOND-or-STAG-COLUMN + RED) it never stamped a group posture.
//--- Focus garrisons therefore kept the engine defaults: WEDGE (a ~40m-wide front inside a camp
//--- compound - wide spacing in close terrain, units stall on trees/walls) and YELLOW (fire-at-will
//--- but no maneuver to engage attackers). Behind WFBE_C_TOWNS_FOCUS_PATROL_POSTURE (default 0 =
//--- legacy untouched, flag-off byte-identical) stamp the close-terrain posture instead: STAG COLUMN
//--- (narrow two-file spacing, the same pick AI_Resistance "Defend" and WaypointPatrolTown use) +
//--- RED/AWARE/NORMAL, so a camp-focus garrison actually engages and stays tight between obstacles.
if (!isNull _team && {(missionNamespace getVariable ["WFBE_C_TOWNS_FOCUS_PATROL_POSTURE", 0]) > 0}) then {
	_team setFormation "STAG COLUMN";
	_team setCombatMode "RED";
	_team setBehaviour "AWARE";
	_team setSpeedMode "NORMAL";
	["INFORMATION", Format ["Common_WaypointPatrol.sqf: focus-patrol close-terrain posture stamped (STAG COLUMN/RED) for team [%1] at %2.", _team, _destination]] Call WFBE_CO_FNC_LogContent;
};

_wps = [];
for '_z' from 0 to _maxWaypoints do {
	_rand1 = random _radius - random _radius;
	_rand2 = random _radius - random _radius;
	_pos = [(_destination select 0)+_rand1,(_destination select 1)+_rand2,0];
	_waterRetries = 0;
	while {(surfaceIsWater _pos) && {_waterRetries < _waterRetryCap}} do {
		_waterRetries = _waterRetries + 1;
		_rand1 = random _radius - random _radius;
		_rand2 = random _radius - random _radius;
		_pos = [(_destination select 0)+_rand1,(_destination select 1)+_rand2,0];
	};
	if (surfaceIsWater _pos) then {_pos = [(_destination select 0),(_destination select 1),0]};
	_type = if (_z != _maxWaypoints) then {'MOVE'} else {'CYCLE'};
	[_wps, [_pos,_type,35,40,[],[],_behaviours]] Call WFBE_CO_FNC_ArrayPush;
};

[_team, true, _wps] Call WFBE_CO_FNC_WaypointsAdd;
