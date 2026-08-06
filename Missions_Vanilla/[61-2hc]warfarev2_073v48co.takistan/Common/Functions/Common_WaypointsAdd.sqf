/* 
	Add waypoints to a team.
	 Parameters:
		- Team.
		- Remove all existing WP.
		- WP List. (i.e: [_team, true, [[getPos _camp, 'MOVE', 10, 20, [], [10,20,30], ["COMBAT","RED","COLUMN","LIMITED"]],[[1560,2560,0], 'SAD', 50, 70, ["canComplete", "this sidechat 'lets roll'"], [], ["SAFE","","LINE",""]]...]] Call AddWP;)

	r73b: waypoint type-string fail-clean — null team / short WP rows / empty or non-STRING type used to
	throw mid-forEach (setWaypointType nil/""), leaving a half-laid chain with no setCurrentWaypoint.
*/

Private ['_clear','_completionRadius','_position','_radius','_squad_prop','_statements','_team','_timeout','_type','_waypoint','_waypoints','_WPCount','_validTypes'];

if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 3}) exitWith {};

_team = _this select 0;
_clear = _this select 1;
_waypoints = _this select 2;

if (isNil "_team" || {typeName _team != "GROUP"} || {isNull _team}) exitWith {
	["WARNING", "Common_WaypointsAdd.sqf: aborted — team is null/non-GROUP."] Call WFBE_CO_FNC_LogContent;
};
if (isNil "_waypoints" || {typeName _waypoints != "ARRAY"}) exitWith {};
if (isNil "_clear") then {_clear = true};

//--- A2 OA valid setWaypointType strings (engine rejects others silently / leaves default MOVE inconsistently).
_validTypes = ["MOVE","DESTROY","GETIN","SAD","JOIN","LEADER","GETOUT","CYCLE","LOAD","UNLOAD","TR UNLOAD","HOLD","SENTRY","GUARD","TALK","SCRIPTED","SUPPORT","GETIN NEAREST","DISMISS","LOITER"];

if (_clear) then {_team Call WFBE_CO_FNC_WaypointsRemove};

{
	if (isNil "_x" || {typeName _x != "ARRAY"} || {count _x < 4}) then {
		["WARNING", Format ["Common_WaypointsAdd.sqf: skipped malformed WP row (need >=4 slots) index=%1.", _forEachIndex]] Call WFBE_CO_FNC_LogContent;
	} else {
		_position = _x select 0;
		_type = _x select 1;
		_radius = _x select 2;
		_completionRadius = _x select 3;
		_statements = if (count _x > 4) then {_x select 4} else {[]};
		_timeout = if (count _x > 5) then {_x select 5} else {[]};
		_squad_prop = if (count _x > 6) then {_x select 6} else {[]};

		if (isNil "_position") then {_position = [0,0,0]};
		if (typeName _position == "OBJECT") then {
			if (isNull _position) then {_position = [0,0,0]} else {_position = getPos _position};
		};
		if (typeName _position != "ARRAY" || {count _position < 2}) then {_position = [0,0,0]};

		//--- r73b: empty / non-STRING / unknown type → MOVE (never feed setWaypointType garbage).
		if (isNil "_type" || {typeName _type != "STRING"} || {_type == ""}) then {_type = "MOVE"};
		if (!(_type in _validTypes)) then {
			["WARNING", Format ["Common_WaypointsAdd.sqf: unknown waypoint type [%1] coerced to MOVE.", _type]] Call WFBE_CO_FNC_LogContent;
			_type = "MOVE";
		};

		if (isNil "_radius" || {typeName _radius != "SCALAR"}) then {_radius = 30};
		if (isNil "_completionRadius" || {typeName _completionRadius != "SCALAR"}) then {_completionRadius = 20};
		if (isNil "_statements" || {typeName _statements != "ARRAY"}) then {_statements = []};
		if (isNil "_timeout" || {typeName _timeout != "ARRAY"}) then {_timeout = []};
		if (isNil "_squad_prop" || {typeName _squad_prop != "ARRAY"}) then {_squad_prop = []};

		_WPCount = count (waypoints _team);	
		_waypoint = _team addWaypoint [_position, _radius];
		[_team, _WPCount] setWaypointType _type;
		[_team, _WPCount] setWaypointCompletionRadius _completionRadius;
		if ((count _statements) > 1) then {
			if ((typeName (_statements select 0) == "STRING") && {typeName (_statements select 1) == "STRING"}) then {
				[_team, _WPCount] setWaypointStatements [_statements select 0, _statements select 1];
			};
		};
		if ((count _timeout) > 2) then {
			[_team, _WPCount] setWaypointTimeout [_timeout select 0, _timeout select 1, _timeout select 2];
		};
		if ((count _squad_prop) > 0) then {
			if ((count _squad_prop) > 0 && {typeName (_squad_prop select 0) == "STRING"} && {(_squad_prop select 0) != ""}) then {[_team, _WPCount] setWaypointBehaviour (_squad_prop select 0)};
			if ((count _squad_prop) > 1 && {typeName (_squad_prop select 1) == "STRING"} && {(_squad_prop select 1) != ""}) then {[_team, _WPCount] setWaypointCombatMode (_squad_prop select 1)};
			if ((count _squad_prop) > 2 && {typeName (_squad_prop select 2) == "STRING"} && {(_squad_prop select 2) != ""}) then {[_team, _WPCount] setWaypointFormation (_squad_prop select 2)};
			if ((count _squad_prop) > 3 && {typeName (_squad_prop select 3) == "STRING"} && {(_squad_prop select 3) != ""}) then {[_team, _WPCount] setWaypointSpeed (_squad_prop select 3)};
		};
		if (_forEachIndex == 0) then {_team setCurrentWaypoint [_team, _WPCount]}; //--- WAVE-3 MOVEMENT ROOT FIX (2026-07-02): A2-OA WaypointsRemove leaves a residual index-0 waypoint, so _WPCount is NEVER 0 on a RE-LAY (every commander-team seq-bump / arrival / capture) -> the old _WPCount==0 gate never fired setCurrentWaypoint -> the fresh MOVE chain was never made ACTIVE -> teams sat at spawn (live: moved=1m in 482s, begin_capture=0, 0 captures). Fire on the FIRST node of every batch (_forEachIndex==0) pointing at its real engine index _WPCount, so the team actually starts the road-march. Fresh groups (garrisons: _WPCount==0 too) are unchanged. Fleet root-cause w9kbdt0a3.
	};
} forEach _waypoints;
