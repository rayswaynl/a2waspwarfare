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
*/

Private ['_clear','_completionRadius','_position','_radius','_scripted','_statements','_team','_type','_waypoint','_waypoints','_WPCount'];
_team = _this select 0;
_clear = _this select 1;
_waypoints = _this select 2;

if (_clear) then {_team Call AIWPRemove};

{
	_position = _x select 0;
	_type = _x select 1;
	_radius = _x select 2;
	_completionRadius = _x select 3;
	_scripted = _x select 4;
	_statements = _x select 5;
	if (typeName _position == 'OBJECT') then {_position = getPos _position};
	
	_WPCount = count (waypoints _team);
	
	_waypoint = _team addWaypoint [_position,_radius];
	[_team, _WPCount] setWaypointType _type;
	[_team, _WPCount] setWaypointCompletionRadius _completionRadius;
	if (_type == 'SCRIPTED') then {[_team, _WPCount] setWaypointScript _scripted};
	if (count _statements > 0) then {[_team, _WPCount] setWaypointStatements [_statements select 0, _statements select 1]};
	
	if (_forEachIndex == 0) then {_team setCurrentWaypoint [_team, _WPCount]}; //--- WAVE-3 re-lay activation fix (twin of Common_WaypointsAdd L34): AIWPRemove leaves a residual index-0 waypoint, so _WPCount is NEVER 0 on a RE-LAY -> the old _WPCount==0 gate never fired setCurrentWaypoint -> a re-tasked team (server-local AICOM SAD re-dispatch AssignTowns.sqf:1210/1218, human re-aim Execute.sqf:119, town sortie, patrol re-lay) never made its fresh chain ACTIVE and sat parked. Fire on the FIRST node of every batch at its real engine index _WPCount; fresh groups (_WPCount==0) unchanged.
} forEach _waypoints;