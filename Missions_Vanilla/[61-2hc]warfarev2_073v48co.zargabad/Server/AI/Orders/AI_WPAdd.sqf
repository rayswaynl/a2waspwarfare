/* 
	Author: Benny
	Name: AI_WPAdd.sqf
	Parameters:
	  0 - Team
	  1 - Clear (Remove WPs)
	  2 - Waypoints (given in an Array)
	Description:
	  This file is used to give a detailed WP system.
	Exemple:
	  [_team, true, [[getPos _camp, 'MOVE', 10, 20, "", []],[[1560,2560,0], 'SAD', 50, 70, "", ["canComplete", "this sidechat 'lets roll'"]]...]] Call AddWP;

	r73b: twin of Common_WaypointsAdd type-string fail-clean for the server AIWPAdd path
	(AI_MoveTo / AI_Patrol / AI_Resistance / AssignTowns SAD re-dispatch).
*/

Private ['_clear','_completionRadius','_position','_radius','_scripted','_statements','_team','_type','_waypoint','_waypoints','_WPCount','_validTypes'];

if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 3}) exitWith {};

_team = _this select 0;
_clear = _this select 1;
_waypoints = _this select 2;

if (isNil "_team" || {typeName _team != "GROUP"} || {isNull _team}) exitWith {
	["WARNING", "AI_WPAdd.sqf: aborted — team is null/non-GROUP."] Call WFBE_CO_FNC_LogContent;
};
if (isNil "_waypoints" || {typeName _waypoints != "ARRAY"}) exitWith {};
if (isNil "_clear") then {_clear = true};

_validTypes = ["MOVE","DESTROY","GETIN","SAD","JOIN","LEADER","GETOUT","CYCLE","LOAD","UNLOAD","TR UNLOAD","HOLD","SENTRY","GUARD","TALK","SCRIPTED","SUPPORT","GETIN NEAREST","DISMISS","LOITER"];

if (_clear) then {_team Call AIWPRemove};

{
	if (isNil "_x" || {typeName _x != "ARRAY"} || {count _x < 4}) then {
		["WARNING", Format ["AI_WPAdd.sqf: skipped malformed WP row (need >=4 slots) index=%1.", _forEachIndex]] Call WFBE_CO_FNC_LogContent;
	} else {
		_position = _x select 0;
		_type = _x select 1;
		_radius = _x select 2;
		_completionRadius = _x select 3;
		_scripted = if (count _x > 4) then {_x select 4} else {""};
		_statements = if (count _x > 5) then {_x select 5} else {[]};

		if (isNil "_position") then {_position = [0,0,0]};
		if (typeName _position == "OBJECT") then {
			if (isNull _position) then {_position = [0,0,0]} else {_position = getPos _position};
		};
		if (typeName _position != "ARRAY" || {count _position < 2}) then {_position = [0,0,0]};

		if (isNil "_type" || {typeName _type != "STRING"} || {_type == ""}) then {_type = "MOVE"};
		if (!(_type in _validTypes)) then {
			["WARNING", Format ["AI_WPAdd.sqf: unknown waypoint type [%1] coerced to MOVE.", _type]] Call WFBE_CO_FNC_LogContent;
			_type = "MOVE";
		};

		if (isNil "_radius" || {typeName _radius != "SCALAR"}) then {_radius = 30};
		if (isNil "_completionRadius" || {typeName _completionRadius != "SCALAR"}) then {_completionRadius = 20};
		if (isNil "_scripted") then {_scripted = ""};
		if (typeName _scripted != "STRING") then {_scripted = str _scripted};
		if (isNil "_statements" || {typeName _statements != "ARRAY"}) then {_statements = []};

		_WPCount = count (waypoints _team);

		_waypoint = _team addWaypoint [_position,_radius];
		[_team, _WPCount] setWaypointType _type;
		[_team, _WPCount] setWaypointCompletionRadius _completionRadius;
		if (_type == "SCRIPTED" && {_scripted != ""}) then {[_team, _WPCount] setWaypointScript _scripted};
		if ((count _statements) > 1) then {
			if ((typeName (_statements select 0) == "STRING") && {typeName (_statements select 1) == "STRING"}) then {
				[_team, _WPCount] setWaypointStatements [_statements select 0, _statements select 1];
			};
		};

		if (_forEachIndex == 0) then {_team setCurrentWaypoint [_team, _WPCount]}; //--- WAVE-3 re-lay activation fix (twin of Common_WaypointsAdd L34): AIWPRemove leaves a residual index-0 waypoint, so _WPCount is NEVER 0 on a RE-LAY -> the old _WPCount==0 gate never fired setCurrentWaypoint -> a re-tasked team (server-local AICOM SAD re-dispatch AssignTowns.sqf:1210/1218, human re-aim Execute.sqf:119, town sortie, patrol re-lay) never made its fresh chain ACTIVE and sat parked. Fire on the FIRST node of every batch at its real engine index _WPCount; fresh groups (_WPCount==0) unchanged.
	};
} forEach _waypoints;
