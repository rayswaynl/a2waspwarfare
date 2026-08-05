/*
	Define how an AI leader shall attack a town, this whole process can be customized or replaced by other tactics if needed.
	AI will currently use an ARC system.
	 Parameters:
		- Team.
		- Town Assigned.
*/

Private ["_distance_node","_select","_side","_team","_town_assigned","_wp_dest","_wp_origin","_wp_sel","_marchCombat","_fallbackLeader"];  //--- cmdcon41-w2: +_marchCombat (yellow-march transit combat-mode token) + nil-side recovery.

_team = _this select 0;
_town_assigned = _this select 1;

//--- CULLED-DISPATCH GUARD: the commander can delete a team or town between dispatch and path planning.
//--- Skip before leader/getPos dereferences and leave one always-on RPT attribution line.
if (isNull _team || {isNull _town_assigned}) exitWith {
	["WARNING", Format ["Server_AI_SetTownAttackPath: skipped culled dispatch team=%1 town=%2.", _team, _town_assigned]] Call WFBE_CO_FNC_LogContent;
};

//--- r78b: empty/culled group has null leader — getPos objNull throws and aborts path planning
//--- for the whole dispatch (no depot SAD either). Guard after team null-check, before getPos.
_fallbackLeader = leader _team;
if (isNull _fallbackLeader) exitWith {
	["WARNING", Format ["Server_AI_SetTownAttackPath: skipped dispatch with null leader team=%1 town=%2.", _team, _town_assigned]] Call WFBE_CO_FNC_LogContent;
};

_wp_origin = getPos _fallbackLeader;
_wp_dest = getPos _town_assigned;
_select = _wp_origin;

//--- Clear the AI waypoints
(_team) Call WFBE_CO_FNC_WaypointsRemove;
_distance_node = 700;
_side = (_team getVariable "wfbe_side") Call WFBE_CO_FNC_GetSideID;
if (isNil "_side" || {_side < 0}) then {
	_fallbackLeader = objNull;
	if (!isNull _team) then {_fallbackLeader = leader _team};
	if (!isNull _fallbackLeader && {alive _fallbackLeader}) then {_side = (side _fallbackLeader) Call WFBE_CO_FNC_GetSideID};
};
if (isNil "_side" || {_side < 0}) exitWith {
	["WARNING", Format ["Server_AI_SetTownAttackPath: skipped dispatch with undefined side team=%1.", _team]] Call WFBE_CO_FNC_LogContent;
};

//--- cmdcon41-w2 (mhq-... yellow-march): behind WFBE_C_AICOM_MARCH_YELLOW>0, the TRANSIT MOVE nodes' combat
//--- mode switches "RED"->"YELLOW" so a marching column returns fire but does NOT peel off to hunt every
//--- contact on the approach (less roving/stalling en route). The depot SAD/MOVE entries at the very end
//--- STAY COMBAT/RED (they must actually clear the objective's defenders). 0 = unchanged legacy RED transit.
//--- A2-OA-safe: plain missionNamespace getVariable + exact-case mode string token in the props array.
_marchCombat = if ((missionNamespace getVariable ["WFBE_C_AICOM_MARCH_YELLOW", 1]) > 0) then {"YELLOW"} else {"RED"};

//--- If the leader is further than 550m we use a proper attack system.
if (_wp_origin distance _wp_dest > _distance_node) then {
	Private ["_a","_a_path_safe","_a_safe","_angle","_b_path_safe","_b_safe","_dir_to","_max_hops","_nodes","_nodes_a"];
	_dir_to = [_town_assigned, _wp_origin] Call WFBE_CO_FNC_GetDirTo;
	
	_nodes_a = [];
	_nodes = 8;
	_angle = 360/_nodes;
	for '_i' from 0 to _nodes-1 do {
		_a = (_dir_to + (_angle*_i)) mod 360;
		_nodes_a = _nodes_a + [[(_wp_dest select 0) + _distance_node * sin(_a),(_wp_dest select 1) + _distance_node * cos(_a)]];
	};
	_nodes_a = [_wp_origin, _nodes_a] Call WFBE_CO_FNC_SortByDistance;
	//--- r78b: bare getVariable can be nil if constants failed to init / missionNamespace wiped;
	//--- nil-2 throws and kills path planning mid-function (no depot assault). Default 4 matches Init_CommonConstants.
	_max_hops = ((missionNamespace getVariable ["WFBE_C_AI_TOWN_ATTACK_HOPS_WP", 4]) max 2) - 2;
	
	//--- First WP
	_wp_sel = [[([_nodes_a select 0, 20, 100] Call WFBE_CO_FNC_GetRandomPosition), 'MOVE', 40, 20, [], [], ["AWARE",_marchCombat,"COLUMN","FULL"]]];  //--- STANCE (task #1): RED/FULL advance-and-engage (was ""/NORMAL). cmdcon41-w2: transit combat mode = _marchCombat (RED->YELLOW behind WFBE_C_AICOM_MARCH_YELLOW).
	
	if (random 100 < 30) then {[_team, false, _wp_sel] Call WFBE_CO_FNC_WaypointsAdd;} else {
	
	//--- Determine the path to follow.
	_a_safe = [_nodes_a select 1, _side, _town_assigned] Call WFBE_SE_FNC_AI_SetTownAttackPath_PosIsSafe;
	_b_safe = [_nodes_a select 2, _side, _town_assigned] Call WFBE_SE_FNC_AI_SetTownAttackPath_PosIsSafe;
	_a_path_safe = [_nodes_a select 0, _nodes_a select 1, 10] Call WFBE_SE_FNC_AI_SetTownAttackPath_PathIsSafe;
	_b_path_safe = [_nodes_a select 0, _nodes_a select 2, 10] Call WFBE_SE_FNC_AI_SetTownAttackPath_PathIsSafe;
	
	//--- LANE-FIX (2026-07-25): these two guards were `exitWith`, which on A2 OA exits the WHOLE FUNCTION
	//--- (if/then is transparent to exitWith and there is no enclosing loop here), so the depot SAD/MOVE
	//--- assault waypoints at the end of this file were SKIPPED - the 30% simple-approach branch and the
	//--- no-safe-path branch each left the team parked ~700m short (or with zero waypoints) and it never
	//--- entered/captured the town. Restructured to then/else + a nested guard so control always falls
	//--- through to the depot-assault block below. A2-OA-safe: pure control-flow, no commands.
	if (!((!_a_safe && !_b_safe) || (!_a_path_safe && !_b_path_safe))) then {
	if (_a_safe && _b_safe) then {
		if (random 1 > 0.5) then {_select = if (_a_path_safe) then {_nodes_a select 1} else {_nodes_a select 2}} else {_select = if (_b_path_safe) then {_nodes_a select 2} else {_nodes_a select 1}};
	} else {
		if (_a_safe) then {_select = if (_a_path_safe) then {_nodes_a select 1} else {_nodes_a select 2}} else {_select = if (_b_path_safe) then {_nodes_a select 2} else {_nodes_a select 1}};
	};
	
	for '_i' from 0 to 1 do {_nodes_a set [_i, false]};
	_nodes_a = _nodes_a - [false];
	[_wp_sel, [([_select, 20, 100] Call WFBE_CO_FNC_GetRandomPosition), 'MOVE', 40, 20, [], [], ["AWARE",_marchCombat,"WEDGE","FULL"]]] Call WFBE_CO_FNC_ArrayPush;  //--- STANCE (task #1): RED/FULL advance-and-engage (was ""/NORMAL). cmdcon41-w2: transit combat mode = _marchCombat (RED->YELLOW behind WFBE_C_AICOM_MARCH_YELLOW).

	//--- Random Path
	for '_i' from 0 to _nodes-1 do {
		if (_i >= _max_hops || random 100 < 50) exitWith {};
		_nodes_a set [0, false];_nodes_a = _nodes_a - [false];
		_nodes_a = [_select, _nodes_a] Call WFBE_CO_FNC_SortByDistance;
		if !([_select, _nodes_a select 0, 10] Call WFBE_SE_FNC_AI_SetTownAttackPath_PathIsSafe) exitWith {};
		_select = _nodes_a select 0;
		_a_safe = [_select, _side, _town_assigned] Call WFBE_SE_FNC_AI_SetTownAttackPath_PosIsSafe;
		if !(_a_safe) exitWith {};
		if (_a_safe) then {[_wp_sel, [([_select, 20, 100] Call WFBE_CO_FNC_GetRandomPosition), 'MOVE', 60, 30, [], [], ["AWARE",_marchCombat,"","FULL"]]] Call WFBE_CO_FNC_ArrayPush};  //--- STANCE (task #1): RED/FULL advance-and-engage (was empty props -> engine default). cmdcon41-w2: transit combat mode = _marchCombat (RED->YELLOW behind WFBE_C_AICOM_MARCH_YELLOW).
	};
	[_team, false, _wp_sel] Call WFBE_CO_FNC_WaypointsAdd;
		};
	};
};

// Combat mode/speed (STANCE task #1, cmdcon41-w2): already tuned above via _marchCombat
// (RED, or YELLOW behind WFBE_C_AICOM_MARCH_YELLOW) + AWARE/FULL on every waypoint pushed
// in this function - not a stale gap, no further tuning needed here.
// Feature request (unimplemented, needs owner design decision): radio callout on WP
// completion, e.g. "B 1-1 A - HQ, we're attacking %1[town]".
_wp_sel = [];

//--- Todo: May secure the camp.
if (random 100 > 50) then {
	Private ["_behaviour","_camps"];
	//--- r78b: camps flag + array nil-guard. Bare getVariable "camps" is nil on towns that never
	//--- finished camp init (or after capture wipe); SortByDistance on nil throws and skips the
	//--- depot SAD/MOVE that follows this block. 2-arg default + type check; empty list is fine.
	if ((missionNamespace getVariable ["WFBE_C_CAMPS_CREATE", 1]) == 1) then {
		_camps = _town_assigned getVariable ["camps", []];
		if (isNil "_camps" || {typeName _camps != "ARRAY"}) then {_camps = []};
		if ((count _camps) > 0) then {
			_camps = [_select, _camps] Call WFBE_CO_FNC_SortByDistance;
			_behaviour = ["AWARE","","VEE","NORMAL"];
			{
				if (!isNull _x) then {
					[_wp_sel, [([_x, 10, 35] Call WFBE_CO_FNC_GetRandomPosition), 'SAD', 40, 20, [], [], _behaviour]] Call WFBE_CO_FNC_ArrayPush;
					if (random 100 < 65) exitWith {};
					_behaviour = [];
				};
			} forEach _camps;
		};
	};
};

//--- Depot SAD.
[_wp_sel, [([_wp_dest, 10, 60] Call WFBE_CO_FNC_GetRandomPosition), 'SAD', 35, 25, [], [], ["COMBAT","RED","FILE","NORMAL"]]] Call WFBE_CO_FNC_ArrayPush;  //--- STANCE (task #1): COMBAT/RED depot entry actually clears defenders (was AWARE/""). CAPTURE-FIX (2026-06-18): depot-SAD random offset 150->60m so the team prosecutes INSIDE the ~40m drain bubble instead of roving a 150m ring; RunCommanderTeam center-hold then finishes the flip.
[_wp_sel, [([_wp_dest, 5, 25] Call WFBE_CO_FNC_GetRandomPosition), 'MOVE', 35, 25, [], [], ["COMBAT","RED","FILE","NORMAL"]]] Call WFBE_CO_FNC_ArrayPush;  //--- STANCE (task #1): COMBAT/RED depot entry actually clears defenders (was AWARE/"").
// [_wp_sel, [([_wp_dest, 10, 35] Call WFBE_CO_FNC_GetRandomPosition), 'SAD', 35, 25, [], [30,45,60], ["COMBAT","","FILE","LIMITED"]]] Call WFBE_CO_FNC_ArrayPush;

[_team, false, _wp_sel] Call WFBE_CO_FNC_WaypointsAdd;