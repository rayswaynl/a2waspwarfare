/*
    WASP PR8 stress mission harness.

    Server-side only and test-gated. It waits for the normal mission bootstrap,
    logs feature/action coverage, then creates sacrificial AI and vehicles so
    FPS and ownership systems have something observable to chew on.

    Enable only from a dedicated test mission init:
      WASP_PR8_STRESS_ENABLED = true;
      [] execVM "test\wasp_pr8_stress_mission.sqf";
*/

if (!isServer) exitWith {};
if (isNil "WASP_PR8_STRESS_ENABLED") exitWith {diag_log "[WASP-PR8-STRESS] disabled - WASP_PR8_STRESS_ENABLED is nil"};
if (!WASP_PR8_STRESS_ENABLED) exitWith {diag_log "[WASP-PR8-STRESS] disabled - flag is false"};

WASP_PR8_STRESS_OBJECTS = [];
WASP_PR8_STRESS_GROUPS = [];
WASP_PR8_STRESS_RUN_ID = Format ["%1-%2", round diag_tickTime, round (random 99999)];
WASP_PR8_STRESS_SEQ = 0;
WASP_PR8_STRESS_MAX_AI = 0;
WASP_PR8_STRESS_MAX_UNITS = 0;
WASP_PR8_STRESS_MAX_VEHICLES = 0;
WASP_PR8_STRESS_MAX_GROUPS = 0;
WASP_PR8_STRESS_MAX_DEAD = 0;

WASP_PR8_STRESS_LOG = {
	Private ["_level","_message","_line"];
	_level = _this select 0;
	_message = _this select 1;
	WASP_PR8_STRESS_SEQ = WASP_PR8_STRESS_SEQ + 1;
	_line = Format ["[WASP-PR8-STRESS] run=%1 seq=%2 %3", WASP_PR8_STRESS_RUN_ID, WASP_PR8_STRESS_SEQ, _message];
	diag_log _line;
	if (!isNil "WFBE_CO_FNC_LogContent") then {[_level, _line] Call WFBE_CO_FNC_LogContent};
};

WASP_PR8_STRESS_GETVAR = {
	Private ["_name","_default"];
	_name = _this select 0;
	_default = _this select 1;
	if (isNil _name) then {_default} else {missionNamespace getVariable _name}
};

WASP_PR8_STRESS_GETNUM = {
	Private ["_name"];
	_name = _this;
	if (isNil _name) then {-1} else {missionNamespace getVariable _name}
};

WASP_PR8_STRESS_SET_DEFAULT = {
	Private ["_name","_value"];
	_name = _this select 0;
	_value = _this select 1;
	if (isNil _name) then {missionNamespace setVariable [_name, _value]};
};

WASP_PR8_STRESS_APPLY_PROFILE = {
	Private ["_profile","_groups","_units","_pairs","_samples","_sampleDelay","_phaseDelay","_reinforcementInterval","_reinforcementGroups"];
	_profile = if (isNil "WASP_PR8_STRESS_PROFILE") then {"normal"} else {WASP_PR8_STRESS_PROFILE};
	if (typeName _profile != "STRING") then {_profile = "normal"};

	_groups = 8;
	_units = 5;
	_pairs = 6;
	_samples = 24;
	_sampleDelay = 20;
	_phaseDelay = 10;
	_reinforcementInterval = 6;
	_reinforcementGroups = 2;

	if (_profile == "light") then {
		_groups = 3;
		_units = 4;
		_pairs = 3;
		_samples = 12;
		_sampleDelay = 15;
		_phaseDelay = 5;
		_reinforcementInterval = 6;
		_reinforcementGroups = 1;
	};
	if (_profile == "brutal") then {
		_groups = 14;
		_units = 6;
		_pairs = 10;
		_samples = 36;
		_sampleDelay = 20;
		_phaseDelay = 10;
		_reinforcementInterval = 4;
		_reinforcementGroups = 4;
	};

	missionNamespace setVariable ["WASP_PR8_STRESS_PROFILE", _profile];
	["WASP_PR8_STRESS_GROUPS_PER_SIDE", _groups] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_UNITS_PER_GROUP", _units] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_VEHICLE_PAIRS", _pairs] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_SAMPLE_COUNT", _samples] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_SAMPLE_DELAY", _sampleDelay] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_PHASE_DELAY", _phaseDelay] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_REINFORCEMENT_INTERVAL", _reinforcementInterval] Call WASP_PR8_STRESS_SET_DEFAULT;
	["WASP_PR8_STRESS_REINFORCEMENT_GROUPS", _reinforcementGroups] Call WASP_PR8_STRESS_SET_DEFAULT;
};

WASP_PR8_STRESS_TRACK_OBJECT = {
	WASP_PR8_STRESS_OBJECTS set [count WASP_PR8_STRESS_OBJECTS, _this];
	_this
};

WASP_PR8_STRESS_TRACK_GROUP = {
	if (isNull _this) exitWith {_this};
	WASP_PR8_STRESS_GROUPS set [count WASP_PR8_STRESS_GROUPS, _this];
	_this
};

WASP_PR8_STRESS_MISSING = {
	Private ["_names","_missing"];
	_names = _this;
	_missing = [];
	{if (isNil _x) then {_missing set [count _missing, _x]}} forEach _names;
	_missing
};

WASP_PR8_STRESS_SIDETEXT = {
	Private ["_side"];
	_side = _this;
	if (_side == west) exitWith {"west"};
	if (_side == east) exitWith {"east"};
	if (_side == resistance) exitWith {"resistance"};
	str _side
};

WASP_PR8_STRESS_SAFE_POS = {
	Private ["_side","_fallback","_hq","_pos"];
	_side = _this select 0;
	_fallback = _this select 1;
	_pos = _fallback;
	if (!isNil "WFBE_CO_FNC_GetSideHQ") then {
		_hq = _side Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _hq) then {
			_pos = getPos _hq;
			if (((_pos select 0) < 50) && ((_pos select 1) < 50)) then {_pos = _fallback};
		};
	};
	_pos
};

WASP_PR8_STRESS_SPAWN_AI = {
	Private ["_side","_center","_groups","_units","_class","_enemyPos","_created","_i","_j","_grp","_pos","_unit","_wp"];
	_side = _this select 0;
	_center = _this select 1;
	_groups = _this select 2;
	_units = _this select 3;
	_class = _this select 4;
	_enemyPos = _this select 5;
	_created = 0;

	for "_i" from 1 to _groups do {
		_grp = createGroup _side;
		_grp Call WASP_PR8_STRESS_TRACK_GROUP;
		_grp setVariable ["wfbe_persistent", true];
		_grp setVariable ["WASP_PR8_STRESS_TARGET", _enemyPos];
		_grp setVariable ["WASP_PR8_STRESS_SIDE", _side Call WASP_PR8_STRESS_SIDETEXT];
		_grp setVariable ["WASP_PR8_STRESS_CREATED_AT", time];
		_grp setVariable ["WASP_PR8_STRESS_EXPECTED_UNITS", _units];
		for "_j" from 1 to _units do {
			_pos = [(_center select 0) + (random 240) - 120, (_center select 1) + (random 240) - 120, 0];
			_unit = _grp createUnit [_class, _pos, [], 20, "FORM"];
			if (!isNull _unit) then {
				_unit setSkill 0.45;
				_unit setVariable ["WASP_PR8_STRESS_UNIT", true, true];
				_unit addEventHandler ["Killed", {[_this select 0, _this select 1, ((side (_this select 0)) Call GetSideID)] Spawn WFBE_CO_FNC_OnUnitKilled}];
				_unit Call WASP_PR8_STRESS_TRACK_OBJECT;
				_created = _created + 1;
			};
		};
		_wp = _grp addWaypoint [_enemyPos, 80];
		_wp setWaypointType "SAD";
		_wp setWaypointBehaviour "AWARE";
		_wp setWaypointCombatMode "RED";
	};
	_created
};

WASP_PR8_STRESS_SPAWN_VEHICLE = {
	Private ["_type","_pos","_dir","_veh"];
	_type = _this select 0;
	_pos = _this select 1;
	_dir = _this select 2;
	_veh = createVehicle [_type, _pos, [], 0, "NONE"];
	if (!isNull _veh) then {
		_veh setDir _dir;
		_veh setPos _pos;
		_veh setVariable ["WASP_PR8_STRESS_OBJECT", true, true];
		_veh Call WASP_PR8_STRESS_TRACK_OBJECT;
	};
	_veh
};

WASP_PR8_STRESS_CLEANUP_NOW = {
	Private ["_label","_objectCount","_groupCount"];
	_label = _this;
	_objectCount = count WASP_PR8_STRESS_OBJECTS;
	_groupCount = count WASP_PR8_STRESS_GROUPS;
	{if (!isNull _x) then {deleteVehicle _x}} forEach WASP_PR8_STRESS_OBJECTS;
	{if (!isNull _x) then {deleteGroup _x}} forEach WASP_PR8_STRESS_GROUPS;
	WASP_PR8_STRESS_OBJECTS = [];
	WASP_PR8_STRESS_GROUPS = [];
	["INITIALIZATION", Format ["CLEANUP label=%1 objectsDeleted=%2 groupsDeleted=%3 unitsNow=%4 vehiclesNow=%5", _label, _objectCount, _groupCount, count allUnits, count vehicles]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_AI_BEHAVIOR = {
	Private ["_label","_trackedGroups","_activeGroups","_emptyGroups","_trackedUnits","_aliveTracked","_deadTracked","_farStopped","_noWaypoint","_inVehicle","_leadersAlive","_stopped","_ready","_noDestination","_underStrengthGroups","_leaderFarStopped","_avgSpeed","_speedSum","_westAlive","_eastAlive","_resistanceAlive","_grp","_groupUnits","_leader","_expectedUnits","_target","_targetOk","_side","_unit","_destinationData","_destination","_distanceToTarget"];
	_label = _this;
	_trackedGroups = 0;
	_activeGroups = 0;
	_emptyGroups = 0;
	_trackedUnits = 0;
	_aliveTracked = 0;
	_deadTracked = 0;
	_farStopped = 0;
	_noWaypoint = 0;
	_inVehicle = 0;
	_leadersAlive = 0;
	_stopped = 0;
	_ready = 0;
	_noDestination = 0;
	_underStrengthGroups = 0;
	_leaderFarStopped = 0;
	_speedSum = 0;
	_westAlive = 0;
	_eastAlive = 0;
	_resistanceAlive = 0;

	{
		_grp = _x;
		if (!isNull _grp) then {
			_trackedGroups = _trackedGroups + 1;
			_groupUnits = units _grp;
			if (count _groupUnits == 0) then {_emptyGroups = _emptyGroups + 1} else {_activeGroups = _activeGroups + 1};
			if (count (waypoints _grp) == 0) then {_noWaypoint = _noWaypoint + 1};
			_expectedUnits = _grp getVariable ["WASP_PR8_STRESS_EXPECTED_UNITS", -1];
			if ((_expectedUnits > 0) && {(count _groupUnits) < _expectedUnits}) then {_underStrengthGroups = _underStrengthGroups + 1};

			_leader = leader _grp;
			if ((!isNull _leader) && {alive _leader}) then {_leadersAlive = _leadersAlive + 1};

			_target = _grp getVariable ["WASP_PR8_STRESS_TARGET", []];
			_targetOk = (typeName _target == "ARRAY") && {(count _target) > 1};

			{
				_unit = _x;
				_trackedUnits = _trackedUnits + 1;
				if (alive _unit) then {
					_aliveTracked = _aliveTracked + 1;
					if (vehicle _unit != _unit) then {_inVehicle = _inVehicle + 1};
					if (stopped _unit) then {_stopped = _stopped + 1};
					if (unitReady _unit) then {_ready = _ready + 1};
					_speedSum = _speedSum + abs (speed _unit);

					_destinationData = expectedDestination _unit;
					_destination = [];
					if (count _destinationData > 0) then {_destination = _destinationData select 0};
					if ((typeName _destination != "ARRAY") || {(count _destination) < 2}) then {_noDestination = _noDestination + 1};

					if (_targetOk) then {
						_distanceToTarget = _unit distance _target;
						if ((stopped _unit) && {_distanceToTarget > 75}) then {_farStopped = _farStopped + 1};
						if (_unit == _leader && {(stopped _unit) && {_distanceToTarget > 75}}) then {_leaderFarStopped = _leaderFarStopped + 1};
					};

					_side = side _unit;
					if (_side == west) then {_westAlive = _westAlive + 1};
					if (_side == east) then {_eastAlive = _eastAlive + 1};
					if (_side == resistance) then {_resistanceAlive = _resistanceAlive + 1};
				} else {
					_deadTracked = _deadTracked + 1;
				};
			} forEach _groupUnits;
		};
	} forEach WASP_PR8_STRESS_GROUPS;

	_avgSpeed = if (_aliveTracked > 0) then {(round ((_speedSum / _aliveTracked) * 10)) / 10} else {0};
	["INFORMATION", Format ["AI_BEHAVIOR phase=%1 trackedGroups=%2 activeGroups=%3 emptyGroups=%4 noWaypoint=%5 underStrengthGroups=%6 trackedUnits=%7 aliveTracked=%8 deadTracked=%9 leadersAlive=%10 leaderFarStopped=%11 inVehicle=%12 stopped=%13 ready=%14 noDestination=%15 farStopped=%16 avgSpeed=%17 westAlive=%18 eastAlive=%19 resistanceAlive=%20",
		_label, _trackedGroups, _activeGroups, _emptyGroups, _noWaypoint, _underStrengthGroups, _trackedUnits, _aliveTracked, _deadTracked, _leadersAlive, _leaderFarStopped, _inVehicle, _stopped, _ready, _noDestination, _farStopped, _avgSpeed, _westAlive, _eastAlive, _resistanceAlive]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_SNAPSHOT = {
	Private ["_label","_hcs","_side","_logic","_hq","_walls","_structs","_funds","_supply","_sideAI"];
	_label = _this;
	_hcs = ["WFBE_HEADLESSCLIENTS_ID", []] Call WASP_PR8_STRESS_GETVAR;
	["INFORMATION", Format ["SNAPSHOT phase=%1 t=%2 fps=%3 units=%4 vehicles=%5 groups=%6 dead=%7 stressObjects=%8 stressGroups=%9 hcIds=%10",
		_label, round time, (round (diag_fps * 10)) / 10, count allUnits, count vehicles, count allGroups, count allDead, count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS, _hcs]] Call WASP_PR8_STRESS_LOG;
	_label Call WASP_PR8_STRESS_AI_BEHAVIOR;

	if (!isNil "WASP_PR8_STRESS_SIDES") then {
		{
			_side = _x;
			_logic = if (!isNil "WFBE_CO_FNC_GetSideLogic") then {_side Call WFBE_CO_FNC_GetSideLogic} else {objNull};
			_hq = if (!isNil "WFBE_CO_FNC_GetSideHQ") then {_side Call WFBE_CO_FNC_GetSideHQ} else {objNull};
			_walls = if (!isNull _hq) then {_hq getVariable ["wfbe_hq_walls", _hq getVariable ["WFBE_Walls", []]]} else {[]};
			_structs = if (!isNull _logic) then {_logic getVariable ["wfbe_structures", []]} else {[]};
			_funds = if (!isNil "GetAICommanderFunds") then {_side Call GetAICommanderFunds} else {-1};
			_supply = if (!isNil "GetSideSupply") then {_side Call GetSideSupply} else {[Format ["wfbe_supply_%1", str _side], -1] Call WASP_PR8_STRESS_GETVAR};
			_sideAI = {(side _x == _side) && !(isPlayer _x)} count allUnits;
			["INFORMATION", Format ["SNAPSHOT_SIDE phase=%1 side=%2 ai=%3 funds=%4 supply=%5 hqWalls=%6 structures=%7",
				_label, _side Call WASP_PR8_STRESS_SIDETEXT, _sideAI, _funds, _supply, (if (typeName _walls == "ARRAY") then {count _walls} else {-1}), (if (typeName _structs == "ARRAY") then {count _structs} else {-1})]] Call WASP_PR8_STRESS_LOG;
		} forEach WASP_PR8_STRESS_SIDES;
	};
};

WASP_PR8_STRESS_TOWN_SNAPSHOT = {
	Private ["_label","_town","_range","_objects","_west","_east","_resistance","_camps","_campWest","_campEast","_campResistance","_campUnknown","_defs","_aliveDefs","_townTeams","_townVehicles"];
	_label = _this select 0;
	_town = _this select 1;
	if (isNull _town) exitWith {["WARNING", Format ["TOWN_SNAPSHOT phase=%1 skipped nullTown", _label]] Call WASP_PR8_STRESS_LOG};
	_range = if (isNil "WFBE_C_TOWNS_CAPTURE_RANGE") then {250} else {WFBE_C_TOWNS_CAPTURE_RANGE};
	_objects = _town nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], _range];
	_west = west countSide _objects;
	_east = east countSide _objects;
	_resistance = resistance countSide _objects;
	_camps = _town getVariable ["camps", []];
	_campWest = {_x getVariable ["sideID", -1] == WFBE_C_WEST_ID} count _camps;
	_campEast = {_x getVariable ["sideID", -1] == WFBE_C_EAST_ID} count _camps;
	_campResistance = {_x getVariable ["sideID", -1] == WFBE_C_GUER_ID} count _camps;
	_campUnknown = {_x getVariable ["sideID", -1] == WFBE_C_UNKNOWN_ID} count _camps;
	_defs = _town getVariable ["wfbe_town_defenses", []];
	_aliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _defs;
	_townTeams = _town getVariable ["wfbe_town_teams", []];
	_townVehicles = _town getVariable ["wfbe_active_vehicles", []];
	["INFORMATION", Format ["TOWN_SNAPSHOT phase=%1 town=%2 sideID=%3 supply=%4 active=%5 activeAir=%6 activeSideIDs=%7 attackerSideIDs=%8 nearW=%9 nearE=%10 nearR=%11 camps=%12 campSides=[%13,%14,%15,%16] defenses=%17 aliveDefenses=%18 teams=%19 activeVehicles=%20 patrolEnabled=%21 patrolActive=%22",
		_label, _town getVariable ["name", str _town], _town getVariable ["sideID", -1], _town getVariable ["supplyValue", -1], _town getVariable ["wfbe_active", false], _town getVariable ["wfbe_active_air", false], _town getVariable ["wfbe_active_sideIDs", []], _town getVariable ["wfbe_attacker_sideIDs", []], _west, _east, _resistance, count _camps, _campWest, _campEast, _campResistance, _campUnknown, count _defs, _aliveDefs, count _townTeams, count _townVehicles, !(isNil {_town getVariable "wfbe_patrol_enabled"}), _town getVariable ["wfbe_patrol_active", false]]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_TOWN_LIFECYCLE = {
	Private ["_enabled","_town","_candidate","_camps","_campStates","_oldSideID","_oldSide","_oldSupply","_oldActive","_oldActiveAir","_oldActiveSides","_oldAttackers","_oldTeams","_oldVehicles","_newSideID","_newSide","_townPos","_attackerClass","_pressure","_wait","_defenderGroups","_occupationGroups","_restore","_camp","_campOldSideID","_preObjectCount","_preGroupCount","_idx","_cleanupObjects","_cleanupGroups"];
	_enabled = if (isNil "WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED") then {true} else {WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED};
	if (!_enabled) exitWith {["INFORMATION", "TOWN_LIFECYCLE skipped disabledByConfig"] Call WASP_PR8_STRESS_LOG};
	if (isNil "towns") exitWith {["WARNING", "TOWN_LIFECYCLE skipped missing towns"] Call WASP_PR8_STRESS_LOG};
	if ((typeName towns != "ARRAY") || {(count towns) == 0}) exitWith {["WARNING", "TOWN_LIFECYCLE skipped noTowns"] Call WASP_PR8_STRESS_LOG};

	_town = objNull;
	{
		_candidate = _x;
		if (isNull _town) then {
			if (!(_candidate getVariable ["wfbe_inactive", false]) && {(count (_candidate getVariable ["camps", []])) > 0}) then {_town = _candidate};
		};
	} forEach towns;
	if (isNull _town) then {
		{
			_candidate = _x;
			if (isNull _town) then {
				if (!(_candidate getVariable ["wfbe_inactive", false])) then {_town = _candidate};
			};
		} forEach towns;
	};
	if (isNull _town) exitWith {["WARNING", "TOWN_LIFECYCLE skipped noUsableTown"] Call WASP_PR8_STRESS_LOG};

	_camps = _town getVariable ["camps", []];
	_campStates = [];
	{
		_campStates set [count _campStates, [_x, _x getVariable ["sideID", -1], _x getVariable ["supplyValue", -1]]];
	} forEach _camps;

	_oldSideID = _town getVariable ["sideID", WFBE_C_GUER_ID];
	_oldSide = _oldSideID Call WFBE_CO_FNC_GetSideFromID;
	_oldSupply = _town getVariable ["supplyValue", _town getVariable ["startingSupplyValue", 10]];
	_oldActive = _town getVariable ["wfbe_active", false];
	_oldActiveAir = _town getVariable ["wfbe_active_air", false];
	_oldActiveSides = _town getVariable ["wfbe_active_sideIDs", []];
	_oldAttackers = _town getVariable ["wfbe_attacker_sideIDs", []];
	_oldTeams = _town getVariable ["wfbe_town_teams", []];
	_oldVehicles = _town getVariable ["wfbe_active_vehicles", []];
	_newSideID = if (_oldSideID == WFBE_C_WEST_ID) then {WFBE_C_EAST_ID} else {WFBE_C_WEST_ID};
	_newSide = _newSideID Call WFBE_CO_FNC_GetSideFromID;
	_townPos = getPos _town;
	_attackerClass = if (_newSide == west) then {["WFBE_WESTSOLDIER", "USMC_Soldier"] Call WASP_PR8_STRESS_GETVAR} else {["WFBE_EASTSOLDIER", "RU_Soldier"] Call WASP_PR8_STRESS_GETVAR};
	_wait = if (isNil "WASP_PR8_STRESS_TOWN_WAIT") then {8} else {WASP_PR8_STRESS_TOWN_WAIT};
	_restore = if (isNil "WASP_PR8_STRESS_TOWN_RESTORE") then {true} else {WASP_PR8_STRESS_TOWN_RESTORE};

	["INFORMATION", Format ["TOWN_LIFECYCLE_BEGIN town=%1 oldSideID=%2 newSideID=%3 camps=%4 restore=%5 wait=%6", _town getVariable ["name", str _town], _oldSideID, _newSideID, count _camps, _restore, _wait]] Call WASP_PR8_STRESS_LOG;
	["pre_cap", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;

	_defenderGroups = if (!isNil "WFBE_SE_FNC_GetTownGroupsDefender") then {[_town, WFBE_DEFENDER] Call WFBE_SE_FNC_GetTownGroupsDefender} else {[]};
	_occupationGroups = if (!isNil "WFBE_SE_FNC_GetTownGroups") then {[_town, _newSide] Call WFBE_SE_FNC_GetTownGroups} else {[]};
	["INFORMATION", Format ["TOWN_GROUPS town=%1 defenderTemplates=%2 occupationTemplates=%3 townType=%4 supply=%5", _town getVariable ["name", str _town], count _defenderGroups, count _occupationGroups, _town getVariable ["wfbe_town_type", "unknown"], _town getVariable ["supplyValue", -1]]] Call WASP_PR8_STRESS_LOG;

	_preObjectCount = count WASP_PR8_STRESS_OBJECTS;
	_preGroupCount = count WASP_PR8_STRESS_GROUPS;
	_pressure = [_newSide, [(_townPos select 0) + 35, (_townPos select 1) + 35, 0], 2, 4, _attackerClass, _townPos] Call WASP_PR8_STRESS_SPAWN_AI;
	_town setVariable ["wfbe_active_override", false];
	["INFORMATION", Format ["TOWN_PRESSURE town=%1 attackerSideID=%2 spawned=%3 captureRange=%4 aiDetectionCoef=%5", _town getVariable ["name", str _town], _newSideID, _pressure, ("WFBE_C_TOWNS_CAPTURE_RANGE" Call WASP_PR8_STRESS_GETNUM), ("WFBE_C_TOWNS_DETECTION_RANGE_COEF" Call WASP_PR8_STRESS_GETNUM)]] Call WASP_PR8_STRESS_LOG;
	sleep _wait;
	["pressure", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;

	if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _oldSide, "spawn"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
	["defense_manned", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;

	["INFORMATION", Format ["TOWN_CAPTURE_FORCE town=%1 oldSideID=%2 newSideID=%3 supplyBefore=%4", _town getVariable ["name", str _town], _oldSideID, _newSideID, _town getVariable ["supplyValue", -1]]] Call WASP_PR8_STRESS_LOG;
	_town setVariable ["supplyValue", _town getVariable ["startingSupplyValue", _oldSupply], true];
	_town setVariable ["sideID", _newSideID, true];
	if (!isNil "WFBE_CO_FNC_SendToClients") then {[nil, "TownCaptured", [_town, _oldSideID, _newSideID]] Call WFBE_CO_FNC_SendToClients};
	if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _oldSideID, _newSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
	if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _oldSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
	if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _newSide, _oldSideID] Call WFBE_SE_FNC_ManageTownDefenses};
	sleep 2;
	["post_cap", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;

	if (count _camps > 0) then {
		_camp = _camps select 0;
		_campOldSideID = _camp getVariable ["sideID", _oldSideID];
		_camp setVariable ["sideID", _newSideID, true];
		_camp setVariable ["supplyValue", _town getVariable ["startingSupplyValue", _oldSupply], true];
		if (!isNil "WFBE_CO_FNC_SendToClients") then {[nil, "CampCaptured", [_camp, _newSideID, _campOldSideID, true]] Call WFBE_CO_FNC_SendToClients};
		["INFORMATION", Format ["TOWN_CAMP_CAPTURE_FORCE town=%1 camp=%2 oldSideID=%3 newSideID=%4", _town getVariable ["name", str _town], _camp, _campOldSideID, _newSideID]] Call WASP_PR8_STRESS_LOG;
		["camp_event", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;
	};

	if (_restore) then {
		if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _newSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
		_town setVariable ["sideID", _oldSideID, true];
		_town setVariable ["supplyValue", _oldSupply, true];
		if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _newSideID, _oldSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
		sleep 1;
		{
			_camp = _x select 0;
			if (!isNull _camp) then {
				_camp setVariable ["sideID", _x select 1, true];
				_camp setVariable ["supplyValue", _x select 2, true];
			};
		} forEach _campStates;
		if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _oldSide, _newSideID] Call WFBE_SE_FNC_ManageTownDefenses};
		_town setVariable ["wfbe_active", _oldActive, true];
		_town setVariable ["wfbe_active_air", _oldActiveAir, true];
		_town setVariable ["wfbe_active_sideIDs", _oldActiveSides, true];
		_town setVariable ["wfbe_attacker_sideIDs", _oldAttackers, true];
		_town setVariable ["wfbe_town_teams", _oldTeams];
		_town setVariable ["wfbe_active_vehicles", _oldVehicles];
		_cleanupObjects = (count WASP_PR8_STRESS_OBJECTS) - _preObjectCount;
		_cleanupGroups = (count WASP_PR8_STRESS_GROUPS) - _preGroupCount;
		for "_idx" from _preObjectCount to ((count WASP_PR8_STRESS_OBJECTS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_OBJECTS select _idx)) then {deleteVehicle (WASP_PR8_STRESS_OBJECTS select _idx)};
		};
		for "_idx" from _preGroupCount to ((count WASP_PR8_STRESS_GROUPS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_GROUPS select _idx)) then {deleteGroup (WASP_PR8_STRESS_GROUPS select _idx)};
		};
		WASP_PR8_STRESS_OBJECTS resize _preObjectCount;
		WASP_PR8_STRESS_GROUPS resize _preGroupCount;
		["INFORMATION", Format ["TOWN_RESTORE town=%1 sideID=%2 supply=%3 camps=%4", _town getVariable ["name", str _town], _oldSideID, _oldSupply, count _campStates]] Call WASP_PR8_STRESS_LOG;
		["INFORMATION", Format ["TOWN_PRESSURE_CLEANUP town=%1 objectsDeleted=%2 groupsDeleted=%3 stressObjects=%4 stressGroups=%5", _town getVariable ["name", str _town], _cleanupObjects, _cleanupGroups, count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
		["restored", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;
	};
};

WASP_PR8_STRESS_TOWN_CAP_REGRESSION = {
	Private ["_cycles","_cycleDelay","_verifyDelay","_remanTimeout","_doOrganic","_organicTimeout","_organicGroups","_organicUnits","_doRapid","_town","_candidate","_rotation","_rotationSideIDs","_rotationClasses","_totalCaptures","_remanOk","_remanFail","_organicCaptured","_cycle","_ri","_capSide","_capSideID","_capClass","_oldSideID","_oldSide","_oldSupply","_oldActive","_oldActiveAir","_oldActiveSides","_oldAttackers","_oldTeams","_oldVehicles","_camps","_campStates","_camp","_preObjectCount","_preGroupCount","_townPos","_pressure","_defs","_aliveDefs","_townTeams","_nonNullTeams","_waited","_reManned","_townTeamsLen","_townTeamsAlive","_westGroups","_eastGroups","_guerGroups","_cleanupObjects","_cleanupGroups","_idx","_organicSideID","_organicSide","_organicClass","_organicStart","_organicElapsed","_organicPreObj","_organicPreGrp","_captureRange","_orgTownPos","_rapidSideA","_rapidSideAID","_rapidSideB","_rapidSideBID","_rapidWaited","_rapidReManned","_rapidDefs","_rapidAliveDefs","_rapidTeams","_rapidNonNull","_rapidPreObj","_rapidPreGrp","_rapidCleanObj","_rapidCleanGrp","_origSideID","_origSide","_origSupply","_origActive","_origActiveAir","_origActiveSides","_origAttackers","_origTeams","_origVehicles","_origCampStates","_currentSideID","_garrisonGrp","_garrisonUnits","_garrisonVeh"];
	_cycles = if (isNil "WASP_PR8_STRESS_TOWN_CAP_CYCLES") then {3} else {WASP_PR8_STRESS_TOWN_CAP_CYCLES};
	_cycleDelay = if (isNil "WASP_PR8_STRESS_TOWN_CAP_CYCLE_DELAY") then {5} else {WASP_PR8_STRESS_TOWN_CAP_CYCLE_DELAY};
	_verifyDelay = if (isNil "WASP_PR8_STRESS_TOWN_CAP_VERIFY_DELAY") then {4} else {WASP_PR8_STRESS_TOWN_CAP_VERIFY_DELAY};
	_remanTimeout = if (isNil "WASP_PR8_STRESS_TOWN_CAP_REMAN_TIMEOUT") then {15} else {WASP_PR8_STRESS_TOWN_CAP_REMAN_TIMEOUT};
	_doOrganic = if (isNil "WASP_PR8_STRESS_TOWN_CAP_ORGANIC") then {true} else {WASP_PR8_STRESS_TOWN_CAP_ORGANIC};
	_organicTimeout = if (isNil "WASP_PR8_STRESS_TOWN_CAP_ORGANIC_TIMEOUT") then {120} else {WASP_PR8_STRESS_TOWN_CAP_ORGANIC_TIMEOUT};
	_organicGroups = if (isNil "WASP_PR8_STRESS_TOWN_CAP_ORGANIC_GROUPS") then {3} else {WASP_PR8_STRESS_TOWN_CAP_ORGANIC_GROUPS};
	_organicUnits = if (isNil "WASP_PR8_STRESS_TOWN_CAP_ORGANIC_UNITS") then {5} else {WASP_PR8_STRESS_TOWN_CAP_ORGANIC_UNITS};
	_doRapid = if (isNil "WASP_PR8_STRESS_TOWN_CAP_RAPID") then {true} else {WASP_PR8_STRESS_TOWN_CAP_RAPID};

	if (isNil "towns") exitWith {["WARNING", "TOWN_CAP_REGRESSION skipped missing towns"] Call WASP_PR8_STRESS_LOG};
	if ((typeName towns != "ARRAY") || {(count towns) == 0}) exitWith {["WARNING", "TOWN_CAP_REGRESSION skipped noTowns"] Call WASP_PR8_STRESS_LOG};

	_town = objNull;
	{
		_candidate = _x;
		if (isNull _town) then {
			if (!(_candidate getVariable ["wfbe_inactive", false]) && {(count (_candidate getVariable ["camps", []])) > 0}) then {_town = _candidate};
		};
	} forEach towns;
	if (isNull _town) then {
		{
			_candidate = _x;
			if (isNull _town) then {
				if (!(_candidate getVariable ["wfbe_inactive", false])) then {_town = _candidate};
			};
		} forEach towns;
	};
	if (isNull _town) exitWith {["WARNING", "TOWN_CAP_REGRESSION skipped noUsableTown"] Call WASP_PR8_STRESS_LOG};

	_rotation = [west, east, resistance];
	_rotationSideIDs = [WFBE_C_WEST_ID, WFBE_C_EAST_ID, WFBE_C_GUER_ID];
	_rotationClasses = [
		["WFBE_WESTSOLDIER", "USMC_Soldier"] Call WASP_PR8_STRESS_GETVAR,
		["WFBE_EASTSOLDIER", "RU_Soldier"] Call WASP_PR8_STRESS_GETVAR,
		["WFBE_GUERSOLDIER", "GUE_Soldier_1"] Call WASP_PR8_STRESS_GETVAR
	];

	if (count _rotation == 0) exitWith {["WARNING", "TOWN_CAP_REGRESSION skipped noSidesInRotation"] Call WASP_PR8_STRESS_LOG};

	_totalCaptures = 0;
	_remanOk = 0;
	_remanFail = 0;
	_organicCaptured = false;
	_townPos = getPos _town;

	["INFORMATION", Format ["TOWN_CAP_REGRESSION_BEGIN town=%1 cycles=%2 sides=%3 sideIDs=%4", _town getVariable ["name", str _town], _cycles, _rotation, _rotationSideIDs]] Call WASP_PR8_STRESS_LOG;
	["pre_cap_regression", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;

	// --- Save ORIGINAL town state ONCE before all forced cycles ---
	_origSideID = _town getVariable ["sideID", WFBE_C_GUER_ID];
	_origSide = _origSideID Call WFBE_CO_FNC_GetSideFromID;
	_origSupply = _town getVariable ["supplyValue", _town getVariable ["startingSupplyValue", 10]];
	_origActive = _town getVariable ["wfbe_active", false];
	_origActiveAir = _town getVariable ["wfbe_active_air", false];
	_origActiveSides = _town getVariable ["wfbe_active_sideIDs", []];
	_origAttackers = _town getVariable ["wfbe_attacker_sideIDs", []];
	_origTeams = _town getVariable ["wfbe_town_teams", []];
	_origVehicles = _town getVariable ["wfbe_active_vehicles", []];
	_camps = _town getVariable ["camps", []];
	_origCampStates = [];
	{
		_origCampStates set [count _origCampStates, [_x, _x getVariable ["sideID", -1], _x getVariable ["supplyValue", -1]]];
	} forEach _camps;
	_preObjectCount = count WASP_PR8_STRESS_OBJECTS;
	_preGroupCount = count WASP_PR8_STRESS_GROUPS;
	["INFORMATION", Format ["TOWN_CAP_ORIG_SAVE town=%1 sideID=%2 supply=%3 camps=%4", _town getVariable ["name", str _town], _origSideID, _origSupply, count _origCampStates]] Call WASP_PR8_STRESS_LOG;

	// --- Chained forced-capture loop: captures chain through rotation ---
	// Each side captures FROM the current owner (left by previous step).
	// GUER-home example chain: west<-GUER, east<-west, GUER<-east, west<-GUER ...
	for "_cycle" from 1 to _cycles do {
		for "_ri" from 0 to ((count _rotation) - 1) do {
			_capSide = _rotation select _ri;
			_capSideID = _rotationSideIDs select _ri;
			_capClass = _rotationClasses select _ri;
			_currentSideID = _town getVariable ["sideID", -1];

			if (_currentSideID == _capSideID) then {
				["INFORMATION", Format ["TOWN_CAP_SKIP cycle=%1 side=%2 reason=alreadyOwned currentSideID=%3", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, _currentSideID]] Call WASP_PR8_STRESS_LOG;
			} else {
				_oldSideID = _currentSideID;
				_oldSide = _oldSideID Call WFBE_CO_FNC_GetSideFromID;

				_pressure = [_capSide, [(_townPos select 0) + 35, (_townPos select 1) + 35, 0], 2, 4, _capClass, _townPos] Call WASP_PR8_STRESS_SPAWN_AI;
				["INFORMATION", Format ["TOWN_CAP_PRESSURE cycle=%1 side=%2 spawned=%3 fromSideID=%4", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, _pressure, _oldSideID]] Call WASP_PR8_STRESS_LOG;

				if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _oldSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
				_town setVariable ["supplyValue", _town getVariable ["startingSupplyValue", _origSupply], true];
				_town setVariable ["sideID", _capSideID, true];
				if (!isNil "WFBE_CO_FNC_SendToClients") then {[nil, "TownCaptured", [_town, _oldSideID, _capSideID]] Call WFBE_CO_FNC_SendToClients};
				if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _oldSideID, _capSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
				if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _capSide, _oldSideID] Call WFBE_SE_FNC_ManageTownDefenses};
				_totalCaptures = _totalCaptures + 1;

				["INFORMATION", Format ["TOWN_CAP_FORCE cycle=%1 oldSideID=%2 newSideID=%3 town=%4", _cycle, _oldSideID, _capSideID, _town getVariable ["name", str _town]]] Call WASP_PR8_STRESS_LOG;
				[Format ["cap_c%1_s%2", _cycle, _ri], _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;
				sleep 2;

				_waited = 0;
				_reManned = false;
				while {(!_reManned) && {_waited < _remanTimeout}} do {
					sleep 2;
					_waited = _waited + 2;
					_defs = _town getVariable ["wfbe_town_defenses", []];
					_aliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _defs;
					_townTeams = _town getVariable ["wfbe_town_teams", []];
					_nonNullTeams = 0;
					{if (!isNil "_x") then {if (!isNull _x) then {_nonNullTeams = _nonNullTeams + 1}}} forEach _townTeams;
					if (_capSideID == WFBE_C_GUER_ID) then {
						if ((_aliveDefs > 0) || {_nonNullTeams > 0}) then {_reManned = true};
					} else {
						if (_nonNullTeams > 0) then {_reManned = true};
					};
				};

				_defs = _town getVariable ["wfbe_town_defenses", []];
				_aliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _defs;
				_townTeams = _town getVariable ["wfbe_town_teams", []];
				_nonNullTeams = 0;
				{if (!isNil "_x") then {if (!isNull _x) then {_nonNullTeams = _nonNullTeams + 1}}} forEach _townTeams;
				if (_reManned) then {
					_remanOk = _remanOk + 1;
					["INFORMATION", Format ["TOWN_REMAN_OK cycle=%1 side=%2 forced=true defenses=%3 teams=%4 waited=%5", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, _aliveDefs, _nonNullTeams, _waited]] Call WASP_PR8_STRESS_LOG;
				} else {
					_remanFail = _remanFail + 1;
					["INFORMATION", Format ["TOWN_REMAN_FAIL cycle=%1 side=%2 forced=true defenses=0 teams=0 waited=%3 timeout=true", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, _waited]] Call WASP_PR8_STRESS_LOG;
				};

				_townTeamsLen = count (_town getVariable ["wfbe_town_teams", []]);
				_townTeamsAlive = 0;
				{if (!isNil "_x") then {if (!isNull _x) then {_townTeamsAlive = _townTeamsAlive + 1}}} forEach (_town getVariable ["wfbe_town_teams", []]);
				_westGroups = {side _x == west} count allGroups;
				_eastGroups = {side _x == east} count allGroups;
				_guerGroups = {side _x == resistance} count allGroups;
				["INFORMATION", Format ["TOWN_CAP_LEAK cycle=%1 side=%2 townTeamsLen=%3 townTeamsAlive=%4 allGroupsWest=%5 allGroupsEast=%6 allGroupsGuer=%7", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, _townTeamsLen, _townTeamsAlive, _westGroups, _eastGroups, _guerGroups]] Call WASP_PR8_STRESS_LOG;

				// --- Per-step garrison cleanup: delete server-spawned garrison groups ---
				// This prevents group accumulation across chained captures.
				_townTeams = _town getVariable ["wfbe_town_teams", []];
				{
					_garrisonGrp = _x;
					if (!isNil "_garrisonGrp") then {
						if (!isNull _garrisonGrp) then {
							_garrisonUnits = units _garrisonGrp;
							{deleteVehicle _x} forEach _garrisonUnits;
							deleteGroup _garrisonGrp;
						};
					};
				} forEach _townTeams;
				_town setVariable ["wfbe_town_teams", []];
				// Delete tracked garrison vehicles
				_garrisonVeh = _town getVariable ["wfbe_active_vehicles", []];
				{
					if (!isNil "_x") then {
						if (!isNull _x) then {deleteVehicle _x};
					};
				} forEach _garrisonVeh;
				_town setVariable ["wfbe_active_vehicles", []];
				["INFORMATION", Format ["TOWN_GARRISON_CLEANUP cycle=%1 side=%2 teamsDeleted=%3 vehiclesDeleted=%4", _cycle, _capSide Call WASP_PR8_STRESS_SIDETEXT, count _townTeams, count _garrisonVeh]] Call WASP_PR8_STRESS_LOG;

				// --- Clean harness-spawned pressure AI (offset slicing) ---
				_cleanupObjects = (count WASP_PR8_STRESS_OBJECTS) - _preObjectCount;
				_cleanupGroups = (count WASP_PR8_STRESS_GROUPS) - _preGroupCount;
				for "_idx" from _preObjectCount to ((count WASP_PR8_STRESS_OBJECTS) - 1) do {
					if (!isNull (WASP_PR8_STRESS_OBJECTS select _idx)) then {deleteVehicle (WASP_PR8_STRESS_OBJECTS select _idx)};
				};
				for "_idx" from _preGroupCount to ((count WASP_PR8_STRESS_GROUPS) - 1) do {
					if (!isNull (WASP_PR8_STRESS_GROUPS select _idx)) then {deleteGroup (WASP_PR8_STRESS_GROUPS select _idx)};
				};
				WASP_PR8_STRESS_OBJECTS resize _preObjectCount;
				WASP_PR8_STRESS_GROUPS resize _preGroupCount;
			};
			if (_ri < ((count _rotation) - 1)) then {sleep _verifyDelay};
		};
		if (_cycle < _cycles) then {sleep _cycleDelay};
	};

	// --- Restore town to ORIGINAL state after all forced cycles ---
	_capSideID = _town getVariable ["sideID", _origSideID];
	_capSide = _capSideID Call WFBE_CO_FNC_GetSideFromID;
	if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _capSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
	// Garrison cleanup before restoring original state
	_townTeams = _town getVariable ["wfbe_town_teams", []];
	{
		_garrisonGrp = _x;
		if (!isNil "_garrisonGrp") then {
			if (!isNull _garrisonGrp) then {
				_garrisonUnits = units _garrisonGrp;
				{deleteVehicle _x} forEach _garrisonUnits;
				deleteGroup _garrisonGrp;
			};
		};
	} forEach _townTeams;
	_garrisonVeh = _town getVariable ["wfbe_active_vehicles", []];
	{
		if (!isNil "_x") then {
			if (!isNull _x) then {deleteVehicle _x};
		};
	} forEach _garrisonVeh;
	["INFORMATION", Format ["TOWN_GARRISON_CLEANUP_FINAL teamsDeleted=%1 vehiclesDeleted=%2", count _townTeams, count _garrisonVeh]] Call WASP_PR8_STRESS_LOG;
	_town setVariable ["sideID", _origSideID, true];
	_town setVariable ["supplyValue", _origSupply, true];
	if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _capSideID, _origSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
	sleep 1;
	{
		_camp = _x select 0;
		if (!isNull _camp) then {
			_camp setVariable ["sideID", _x select 1, true];
			_camp setVariable ["supplyValue", _x select 2, true];
		};
	} forEach _origCampStates;
	if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _origSide, _capSideID] Call WFBE_SE_FNC_ManageTownDefenses};
	_town setVariable ["wfbe_active", false, true];
	_town setVariable ["wfbe_active_air", false, true];
	_town setVariable ["wfbe_active_sideIDs", [], true];
	_town setVariable ["wfbe_attacker_sideIDs", [], true];
	_town setVariable ["wfbe_town_teams", []];
	_town setVariable ["wfbe_active_vehicles", []];
	["INFORMATION", Format ["TOWN_ORIG_RESTORE town=%1 sideID=%2 supply=%3", _town getVariable ["name", str _town], _origSideID, _origSupply]] Call WASP_PR8_STRESS_LOG;

	if (_doRapid) then {
		_rapidSideA = _rotation select 0;
		_rapidSideAID = _rotationSideIDs select 0;
		_rapidSideB = _rotation select 1;
		_rapidSideBID = _rotationSideIDs select 1;
		if ((_town getVariable ["sideID", -1]) == _rapidSideAID) then {
			_rapidSideA = _rotation select 1;
			_rapidSideAID = _rotationSideIDs select 1;
			_rapidSideB = _rotation select 2;
			_rapidSideBID = _rotationSideIDs select 2;
		};

		_oldSideID = _town getVariable ["sideID", WFBE_C_GUER_ID];
		_oldSide = _oldSideID Call WFBE_CO_FNC_GetSideFromID;
		_oldSupply = _town getVariable ["supplyValue", _town getVariable ["startingSupplyValue", 10]];
		_camps = _town getVariable ["camps", []];
		_campStates = [];
		{
			_campStates set [count _campStates, [_x, _x getVariable ["sideID", -1], _x getVariable ["supplyValue", -1]]];
		} forEach _camps;
		_rapidPreObj = count WASP_PR8_STRESS_OBJECTS;
		_rapidPreGrp = count WASP_PR8_STRESS_GROUPS;

		["INFORMATION", Format ["TOWN_RAPID_RECAP_BEGIN town=%1 sideA=%2 sideB=%3 sideAID=%4 sideBID=%5", _town getVariable ["name", str _town], _rapidSideA Call WASP_PR8_STRESS_SIDETEXT, _rapidSideB Call WASP_PR8_STRESS_SIDETEXT, _rapidSideAID, _rapidSideBID]] Call WASP_PR8_STRESS_LOG;

		if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _oldSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
		_town setVariable ["sideID", _rapidSideAID, true];
		_town setVariable ["supplyValue", _town getVariable ["startingSupplyValue", _oldSupply], true];
		if (!isNil "WFBE_CO_FNC_SendToClients") then {[nil, "TownCaptured", [_town, _oldSideID, _rapidSideAID]] Call WFBE_CO_FNC_SendToClients};
		if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _oldSideID, _rapidSideAID] Spawn WFBE_SE_FNC_SetCampsToSide};
		if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _rapidSideA, _oldSideID] Call WFBE_SE_FNC_ManageTownDefenses};

		_rapidWaited = 0;
		_rapidReManned = false;
		while {(!_rapidReManned) && {_rapidWaited < _remanTimeout}} do {
			sleep 2;
			_rapidWaited = _rapidWaited + 2;
			_rapidDefs = _town getVariable ["wfbe_town_defenses", []];
			_rapidAliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _rapidDefs;
			_rapidTeams = _town getVariable ["wfbe_town_teams", []];
			_rapidNonNull = 0;
			{if (!isNil "_x") then {if (!isNull _x) then {_rapidNonNull = _rapidNonNull + 1}}} forEach _rapidTeams;
			if ((_town getVariable ["wfbe_active", false]) || {_rapidNonNull > 0}) then {_rapidReManned = true};
		};

		if (!_rapidReManned) then {
			["INFORMATION", Format ["TOWN_RAPID_RECAP_FAIL town=%1 sideA=%2 sideB=%3 reason=sideA_never_manned waited=%4", _town getVariable ["name", str _town], _rapidSideA Call WASP_PR8_STRESS_SIDETEXT, _rapidSideB Call WASP_PR8_STRESS_SIDETEXT, _rapidWaited]] Call WASP_PR8_STRESS_LOG;
		} else {
			_town setVariable ["sideID", _rapidSideBID, true];
			if (!isNil "WFBE_CO_FNC_SendToClients") then {[nil, "TownCaptured", [_town, _rapidSideAID, _rapidSideBID]] Call WFBE_CO_FNC_SendToClients};
			if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _rapidSideAID, _rapidSideBID] Spawn WFBE_SE_FNC_SetCampsToSide};
			if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _rapidSideB, _rapidSideAID] Call WFBE_SE_FNC_ManageTownDefenses};

			_rapidWaited = 0;
			_rapidReManned = false;
			while {(!_rapidReManned) && {_rapidWaited < _remanTimeout}} do {
				sleep 2;
				_rapidWaited = _rapidWaited + 2;
				_rapidDefs = _town getVariable ["wfbe_town_defenses", []];
				_rapidAliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _rapidDefs;
				_rapidTeams = _town getVariable ["wfbe_town_teams", []];
				_rapidNonNull = 0;
				{if (!isNil "_x") then {if (!isNull _x) then {_rapidNonNull = _rapidNonNull + 1}}} forEach _rapidTeams;
				if (_rapidSideBID == WFBE_C_GUER_ID) then {
					if ((_rapidAliveDefs > 0) || {_rapidNonNull > 0}) then {_rapidReManned = true};
				} else {
					if (_rapidNonNull > 0) then {_rapidReManned = true};
				};
			};

			_rapidTeams = _town getVariable ["wfbe_town_teams", []];
			_rapidNonNull = 0;
			{if (!isNil "_x") then {if (!isNull _x) then {_rapidNonNull = _rapidNonNull + 1}}} forEach _rapidTeams;
			if (_rapidReManned) then {
				["INFORMATION", Format ["TOWN_RAPID_RECAP_OK town=%1 sideA=%2 sideB=%3 teams=%4 waited=%5", _town getVariable ["name", str _town], _rapidSideA Call WASP_PR8_STRESS_SIDETEXT, _rapidSideB Call WASP_PR8_STRESS_SIDETEXT, _rapidNonNull, _rapidWaited]] Call WASP_PR8_STRESS_LOG;
			} else {
				["INFORMATION", Format ["TOWN_RAPID_RECAP_FAIL town=%1 sideA=%2 sideB=%3 teams=%4 waited=%5", _town getVariable ["name", str _town], _rapidSideA Call WASP_PR8_STRESS_SIDETEXT, _rapidSideB Call WASP_PR8_STRESS_SIDETEXT, _rapidNonNull, _rapidWaited]] Call WASP_PR8_STRESS_LOG;
			};
		};

		_capSideID = _town getVariable ["sideID", _rapidSideBID];
		_capSide = _capSideID Call WFBE_CO_FNC_GetSideFromID;
		if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _capSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
		// Garrison cleanup before rapid-recap restore
		_townTeams = _town getVariable ["wfbe_town_teams", []];
		{
			_garrisonGrp = _x;
			if (!isNil "_garrisonGrp") then {
				if (!isNull _garrisonGrp) then {
					_garrisonUnits = units _garrisonGrp;
					{deleteVehicle _x} forEach _garrisonUnits;
					deleteGroup _garrisonGrp;
				};
			};
		} forEach _townTeams;
		_garrisonVeh = _town getVariable ["wfbe_active_vehicles", []];
		{
			if (!isNil "_x") then {
				if (!isNull _x) then {deleteVehicle _x};
			};
		} forEach _garrisonVeh;
		["INFORMATION", Format ["TOWN_GARRISON_CLEANUP_RAPID teamsDeleted=%1 vehiclesDeleted=%2", count _townTeams, count _garrisonVeh]] Call WASP_PR8_STRESS_LOG;
		_town setVariable ["sideID", _oldSideID, true];
		_town setVariable ["supplyValue", _oldSupply, true];
		if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _capSideID, _oldSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
		sleep 1;
		{
			_camp = _x select 0;
			if (!isNull _camp) then {
				_camp setVariable ["sideID", _x select 1, true];
				_camp setVariable ["supplyValue", _x select 2, true];
			};
		} forEach _campStates;
		if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _oldSide, _capSideID] Call WFBE_SE_FNC_ManageTownDefenses};
		_town setVariable ["wfbe_active", false, true];
		_town setVariable ["wfbe_active_air", false, true];
		_town setVariable ["wfbe_town_teams", []];
		_town setVariable ["wfbe_active_vehicles", []];
		_rapidCleanObj = (count WASP_PR8_STRESS_OBJECTS) - _rapidPreObj;
		_rapidCleanGrp = (count WASP_PR8_STRESS_GROUPS) - _rapidPreGrp;
		for "_idx" from _rapidPreObj to ((count WASP_PR8_STRESS_OBJECTS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_OBJECTS select _idx)) then {deleteVehicle (WASP_PR8_STRESS_OBJECTS select _idx)};
		};
		for "_idx" from _rapidPreGrp to ((count WASP_PR8_STRESS_GROUPS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_GROUPS select _idx)) then {deleteGroup (WASP_PR8_STRESS_GROUPS select _idx)};
		};
		WASP_PR8_STRESS_OBJECTS resize _rapidPreObj;
		WASP_PR8_STRESS_GROUPS resize _rapidPreGrp;
	};

	if (_doOrganic) then {
		_oldSideID = _town getVariable ["sideID", WFBE_C_GUER_ID];
		_oldSide = _oldSideID Call WFBE_CO_FNC_GetSideFromID;
		_oldSupply = _town getVariable ["supplyValue", _town getVariable ["startingSupplyValue", 10]];
		_oldActive = _town getVariable ["wfbe_active", false];
		_oldActiveAir = _town getVariable ["wfbe_active_air", false];
		_oldActiveSides = _town getVariable ["wfbe_active_sideIDs", []];
		_oldAttackers = _town getVariable ["wfbe_attacker_sideIDs", []];
		_oldTeams = _town getVariable ["wfbe_town_teams", []];
		_oldVehicles = _town getVariable ["wfbe_active_vehicles", []];
		_camps = _town getVariable ["camps", []];
		_campStates = [];
		{
			_campStates set [count _campStates, [_x, _x getVariable ["sideID", -1], _x getVariable ["supplyValue", -1]]];
		} forEach _camps;

		_organicSideID = -1;
		_organicSide = west;
		_organicClass = "";
		{
			Private ["_rs","_rsid"];
			_rs = _rotation select _forEachIndex;
			_rsid = _rotationSideIDs select _forEachIndex;
			if (_rsid != _oldSideID) exitWith {
				_organicSideID = _rsid;
				_organicSide = _rs;
				_organicClass = _rotationClasses select _forEachIndex;
			};
		} forEach _rotation;

		if (_organicSideID == -1) exitWith {
			["WARNING", "TOWN_CAP_ORGANIC skipped noEnemySideAvailable"] Call WASP_PR8_STRESS_LOG;
			["INFORMATION", Format ["TOWN_CAP_REGRESSION_END town=%1 cycles=%2 totalCaptures=%3 remanOk=%4 remanFail=%5 organicCaptured=false", _town getVariable ["name", str _town], _cycles, _totalCaptures, _remanOk, _remanFail]] Call WASP_PR8_STRESS_LOG;
			["post_cap_regression", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;
		};

		_captureRange = if (isNil "WFBE_C_TOWNS_CAPTURE_RANGE") then {250} else {WFBE_C_TOWNS_CAPTURE_RANGE};
		_orgTownPos = getPos _town;
		_organicPreObj = count WASP_PR8_STRESS_OBJECTS;
		_organicPreGrp = count WASP_PR8_STRESS_GROUPS;

		_pressure = [_organicSide, [(_orgTownPos select 0) + 20, (_orgTownPos select 1) + 20, 0], _organicGroups, _organicUnits, _organicClass, _orgTownPos] Call WASP_PR8_STRESS_SPAWN_AI;
		["INFORMATION", Format ["TOWN_CAP_ORGANIC_BEGIN town=%1 attackerSide=%2 attackerSideID=%3 ownerSideID=%4 spawned=%5 captureRange=%6 groups=%7 units=%8", _town getVariable ["name", str _town], _organicSide Call WASP_PR8_STRESS_SIDETEXT, _organicSideID, _oldSideID, _pressure, _captureRange, _organicGroups, _organicUnits]] Call WASP_PR8_STRESS_LOG;

		_organicStart = time;
		_organicElapsed = 0;
		_organicCaptured = false;
		while {(!_organicCaptured) && {_organicElapsed < _organicTimeout}} do {
			sleep 5;
			_organicElapsed = time - _organicStart;
			if ((_town getVariable ["sideID", _oldSideID]) != _oldSideID) then {
				_organicCaptured = true;
			};
			["INFORMATION", Format ["TOWN_CAP_ORGANIC_POLL elapsed=%1 currentSideID=%2 ownerSideID=%3 captured=%4", round _organicElapsed, _town getVariable ["sideID", -1], _oldSideID, _organicCaptured]] Call WASP_PR8_STRESS_LOG;
		};

		["INFORMATION", Format ["TOWN_CAP_ORGANIC_RESULT captured=%1 elapsed=%2 finalSideID=%3 town=%4", _organicCaptured, round _organicElapsed, _town getVariable ["sideID", -1], _town getVariable ["name", str _town]]] Call WASP_PR8_STRESS_LOG;

		if (_organicCaptured) then {
			_waited = 0;
			_reManned = false;
			_capSideID = _town getVariable ["sideID", _organicSideID];
			_capSide = _capSideID Call WFBE_CO_FNC_GetSideFromID;
			while {(!_reManned) && {_waited < _remanTimeout}} do {
				sleep 2;
				_waited = _waited + 2;
				_defs = _town getVariable ["wfbe_town_defenses", []];
				_aliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _defs;
				_townTeams = _town getVariable ["wfbe_town_teams", []];
				_nonNullTeams = 0;
				{if (!isNil "_x") then {if (!isNull _x) then {_nonNullTeams = _nonNullTeams + 1}}} forEach _townTeams;
				if (_capSideID == WFBE_C_GUER_ID) then {
					if ((_aliveDefs > 0) || {_nonNullTeams > 0}) then {_reManned = true};
				} else {
					if (_nonNullTeams > 0) then {_reManned = true};
				};
			};
			_defs = _town getVariable ["wfbe_town_defenses", []];
			_aliveDefs = {alive (_x getVariable ["wfbe_defense", objNull])} count _defs;
			_townTeams = _town getVariable ["wfbe_town_teams", []];
			_nonNullTeams = 0;
			{if (!isNil "_x") then {if (!isNull _x) then {_nonNullTeams = _nonNullTeams + 1}}} forEach _townTeams;
			if (_reManned) then {
				_remanOk = _remanOk + 1;
				["INFORMATION", Format ["TOWN_REMAN_OK cycle=organic side=%1 forced=false organic=true defenses=%2 teams=%3 waited=%4", _capSide Call WASP_PR8_STRESS_SIDETEXT, _aliveDefs, _nonNullTeams, _waited]] Call WASP_PR8_STRESS_LOG;
			} else {
				_remanFail = _remanFail + 1;
				["INFORMATION", Format ["TOWN_REMAN_FAIL cycle=organic side=%1 forced=false organic=true defenses=0 teams=0 waited=%2 timeout=true", _capSide Call WASP_PR8_STRESS_SIDETEXT, _waited]] Call WASP_PR8_STRESS_LOG;
			};
		};

		_capSideID = _town getVariable ["sideID", _oldSideID];
		_capSide = _capSideID Call WFBE_CO_FNC_GetSideFromID;
		if (!isNil "WFBE_SE_FNC_OperateTownDefensesUnits") then {[_town, _capSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits};
		// Garrison cleanup before organic restore
		_townTeams = _town getVariable ["wfbe_town_teams", []];
		{
			_garrisonGrp = _x;
			if (!isNil "_garrisonGrp") then {
				if (!isNull _garrisonGrp) then {
					_garrisonUnits = units _garrisonGrp;
					{deleteVehicle _x} forEach _garrisonUnits;
					deleteGroup _garrisonGrp;
				};
			};
		} forEach _townTeams;
		_garrisonVeh = _town getVariable ["wfbe_active_vehicles", []];
		{
			if (!isNil "_x") then {
				if (!isNull _x) then {deleteVehicle _x};
			};
		} forEach _garrisonVeh;
		["INFORMATION", Format ["TOWN_GARRISON_CLEANUP_ORGANIC teamsDeleted=%1 vehiclesDeleted=%2", count _townTeams, count _garrisonVeh]] Call WASP_PR8_STRESS_LOG;
		_town setVariable ["sideID", _oldSideID, true];
		_town setVariable ["supplyValue", _oldSupply, true];
		if (!isNil "WFBE_SE_FNC_SetCampsToSide") then {[_town, _capSideID, _oldSideID] Spawn WFBE_SE_FNC_SetCampsToSide};
		sleep 1;
		{
			_camp = _x select 0;
			if (!isNull _camp) then {
				_camp setVariable ["sideID", _x select 1, true];
				_camp setVariable ["supplyValue", _x select 2, true];
			};
		} forEach _campStates;
		if (!isNil "WFBE_SE_FNC_ManageTownDefenses") then {[_town, _oldSide, _capSideID] Call WFBE_SE_FNC_ManageTownDefenses};
		_town setVariable ["wfbe_active", _oldActive, true];
		_town setVariable ["wfbe_active_air", _oldActiveAir, true];
		_town setVariable ["wfbe_active_sideIDs", _oldActiveSides, true];
		_town setVariable ["wfbe_attacker_sideIDs", _oldAttackers, true];
		_town setVariable ["wfbe_town_teams", _oldTeams];
		_town setVariable ["wfbe_active_vehicles", _oldVehicles];
		_cleanupObjects = (count WASP_PR8_STRESS_OBJECTS) - _organicPreObj;
		_cleanupGroups = (count WASP_PR8_STRESS_GROUPS) - _organicPreGrp;
		for "_idx" from _organicPreObj to ((count WASP_PR8_STRESS_OBJECTS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_OBJECTS select _idx)) then {deleteVehicle (WASP_PR8_STRESS_OBJECTS select _idx)};
		};
		for "_idx" from _organicPreGrp to ((count WASP_PR8_STRESS_GROUPS) - 1) do {
			if (!isNull (WASP_PR8_STRESS_GROUPS select _idx)) then {deleteGroup (WASP_PR8_STRESS_GROUPS select _idx)};
		};
		WASP_PR8_STRESS_OBJECTS resize _organicPreObj;
		WASP_PR8_STRESS_GROUPS resize _organicPreGrp;
	};

	["INFORMATION", Format ["TOWN_CAP_REGRESSION_END town=%1 cycles=%2 totalCaptures=%3 remanOk=%4 remanFail=%5 organicCaptured=%6", _town getVariable ["name", str _town], _cycles, _totalCaptures, _remanOk, _remanFail, _organicCaptured]] Call WASP_PR8_STRESS_LOG;
	["post_cap_regression", _town] Call WASP_PR8_STRESS_TOWN_SNAPSHOT;
};

WASP_PR8_STRESS_PHASE = {
	Private ["_label","_delay"];
	_label = _this select 0;
	_delay = if (count _this > 1) then {_this select 1} else {0};
	["INITIALIZATION", Format ["PHASE_BEGIN %1 delay=%2", _label, _delay]] Call WASP_PR8_STRESS_LOG;
	_label Call WASP_PR8_STRESS_SNAPSHOT;
	if (_delay > 0) then {sleep _delay};
	["INITIALIZATION", Format ["PHASE_END %1", _label]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_DIRECT_TRIGGERS = {
	Private ["_enabled","_town","_beforeWest","_afterWest","_beforeEast","_afterEast","_amount","_reward","_team","_fundsBefore","_fundsAfter","_triggerGroup"];
	_enabled = if (isNil "WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS") then {true} else {WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS};
	if (!_enabled) exitWith {["INFORMATION", "TRIGGER directActions skipped disabledByConfig"] Call WASP_PR8_STRESS_LOG};

	_town = objNull;
	if (!isNil "towns") then {if ((typeName towns == "ARRAY") && {(count towns) > 0}) then {_town = towns select 0}};

	if (!isNil "ChangeSideSupply") then {
		_amount = 321;
		_reward = 77;
		_beforeWest = if (!isNil "GetSideSupply") then {west Call GetSideSupply} else {[Format ["wfbe_supply_%1", str west], -1] Call WASP_PR8_STRESS_GETVAR};
		[west, _amount, Format ["Stress direct supply completion trigger from %1 (+S %2).", _town, _amount], false] Call ChangeSideSupply;
		_afterWest = if (!isNil "GetSideSupply") then {west Call GetSideSupply} else {[Format ["wfbe_supply_%1", str west], -1] Call WASP_PR8_STRESS_GETVAR};
		if (_afterWest == _beforeWest) then {
			missionNamespace setVariable [Format ["wfbe_supply_%1", str west], _beforeWest + _amount];
			publicVariable Format ["wfbe_supply_%1", str west];
			_afterWest = if (!isNil "GetSideSupply") then {west Call GetSideSupply} else {_beforeWest + _amount};
		};
		["INFORMATION", Format ["TRIGGER supplyCompletion side=west town=%1 before=%2 delta=%3 after=%4", _town, _beforeWest, _amount, _afterWest]] Call WASP_PR8_STRESS_LOG;

		_beforeEast = if (!isNil "GetSideSupply") then {east Call GetSideSupply} else {[Format ["wfbe_supply_%1", str east], -1] Call WASP_PR8_STRESS_GETVAR};
		[east, _reward, Format ["Stress direct supply interdiction trigger (+S %1).", _reward], false] Call ChangeSideSupply;
		_afterEast = if (!isNil "GetSideSupply") then {east Call GetSideSupply} else {[Format ["wfbe_supply_%1", str east], -1] Call WASP_PR8_STRESS_GETVAR};
		if (_afterEast == _beforeEast) then {
			missionNamespace setVariable [Format ["wfbe_supply_%1", str east], _beforeEast + _reward];
			publicVariable Format ["wfbe_supply_%1", str east];
			_afterEast = if (!isNil "GetSideSupply") then {east Call GetSideSupply} else {_beforeEast + _reward};
		};
		["INFORMATION", Format ["TRIGGER supplyInterdiction side=east before=%1 reward=%2 after=%3", _beforeEast, _reward, _afterEast]] Call WASP_PR8_STRESS_LOG;
	} else {
		["WARNING", "TRIGGER supplyCompletion skipped missing ChangeSideSupply"] Call WASP_PR8_STRESS_LOG;
	};

	if (!isNil "WFBE_CO_FNC_ChangeTeamFunds") then {
		_triggerGroup = createGroup west;
		_triggerGroup setVariable ["wfbe_funds", 1000, true];
		_fundsBefore = _triggerGroup getVariable ["wfbe_funds", -1];
		[_triggerGroup, 250] Call WFBE_CO_FNC_ChangeTeamFunds;
		_fundsAfter = _triggerGroup getVariable ["wfbe_funds", -1];
		["INFORMATION", Format ["TRIGGER teamFunds group=%1 before=%2 delta=250 after=%3", _triggerGroup, _fundsBefore, _fundsAfter]] Call WASP_PR8_STRESS_LOG;
		deleteGroup _triggerGroup;
	} else {
		["WARNING", "TRIGGER teamFunds skipped missing WFBE_CO_FNC_ChangeTeamFunds"] Call WASP_PR8_STRESS_LOG;
	};

	["INFORMATION", Format ["TRIGGER confirmationSurfaces sellConfirm=%1 icbmConfirm=%2 clientConfirmFunction=%3", true, true, !(isNil "WFBE_CL_FNC_ConfirmAction")]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_FACTORY_AUDIT = {
	Private ["_label","_side","_sideKey","_logic","_structs","_live","_upgradeQueue","_upgrades","_upgrading","_upgradingId","_names","_labels","_counts","_i","_type","_aliveOfType","_alive","_dead","_damaged","_teamQueues","_queueGroups","_queue","_globalQueues","_factory","_q","_m","_funds","_supply"];
	_label = _this;
	{
		_side = _x;
		_sideKey = str _side;
		_logic = if (!isNil "WFBE_CO_FNC_GetSideLogic") then {_side Call WFBE_CO_FNC_GetSideLogic} else {objNull};
		_structs = if (!isNil "WFBE_CO_FNC_GetSideStructures") then {_side Call WFBE_CO_FNC_GetSideStructures} else {[]};
		if (typeName _structs != "ARRAY") then {_structs = []};
		_live = if (!isNull _logic) then {_logic getVariable ["wfbe_structures_live", []]} else {[]};
		_upgradeQueue = if (!isNull _logic) then {_logic getVariable ["wfbe_upgrade_queue", []]} else {[]};
		_upgrades = if (!isNull _logic) then {_logic getVariable ["wfbe_upgrades", []]} else {[]};
		_upgrading = if (!isNull _logic) then {_logic getVariable ["wfbe_upgrading", false]} else {false};
		_upgradingId = if (!isNull _logic) then {_logic getVariable ["wfbe_upgrading_id", -1]} else {-1};
		_names = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", _sideKey], []];
		_labels = missionNamespace getVariable [Format ["WFBE_%1STRUCTURES", _sideKey], []];
		_counts = [];
		if ((typeName _names == "ARRAY") && {typeName _labels == "ARRAY"}) then {
			for "_i" from 0 to ((count _labels) - 1) do {
				_type = if (_i < count _names) then {_names select _i} else {""};
				_aliveOfType = {alive _x && {typeOf _x == _type}} count _structs;
				_counts set [count _counts, Format ["%1:%2", _labels select _i, _aliveOfType]];
			};
		};
		_alive = {alive _x} count _structs;
		_dead = {!(alive _x)} count _structs;
		_damaged = {alive _x && {(getDammage _x) > 0.05}} count _structs;
		_teamQueues = 0;
		_queueGroups = 0;
		{
			if (side _x == _side) then {
				_queue = _x getVariable ["wfbe_queue", []];
				if (typeName _queue == "ARRAY") then {
					if ((count _queue) > 0) then {_queueGroups = _queueGroups + 1};
					_teamQueues = _teamQueues + (count _queue);
				};
			};
		} forEach allGroups;
		_globalQueues = [];
		{
			_factory = _x;
			_q = missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1", _factory], -1];
			_m = missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1_MAX", _factory], -1];
			_globalQueues set [count _globalQueues, Format ["%1:%2/%3", _factory, _q, _m]];
		} forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT","AIRPORT"];
		_funds = if (!isNil "GetAICommanderFunds") then {_side Call GetAICommanderFunds} else {-1};
		_supply = if (!isNil "GetSideSupply") then {_side Call GetSideSupply} else {[Format ["wfbe_supply_%1", _sideKey], -1] Call WASP_PR8_STRESS_GETVAR};
		["INFORMATION", Format ["FACTORY_AUDIT label=%1 side=%2 structures=%3 alive=%4 dead=%5 damaged=%6 liveSlots=%7 counts=%8 upgradeQueue=%9 upgrades=%10 upgrading=%11 upgradingId=%12 teamQueueGroups=%13 teamQueueItems=%14 globalQueues=%15 aiFunds=%16 supply=%17",
			_label, _side Call WASP_PR8_STRESS_SIDETEXT, count _structs, _alive, _dead, _damaged, _live, _counts, _upgradeQueue, _upgrades, _upgrading, _upgradingId, _queueGroups, _teamQueues, _globalQueues, _funds, _supply]] Call WASP_PR8_STRESS_LOG;
	} forEach WASP_PR8_STRESS_SIDES;
};

WASP_PR8_STRESS_SERVICE_SUPPLY_AUDIT = {
	Private ["_label","_heliTypes","_truckTypes","_supplyTypes","_loaded","_loading","_byHeli","_nearCcLoaded","_townCooldown","_townReady","_town","_side","_structs","_serviceCount","_ccCount","_names","_serviceType","_ccType"];
	_label = _this;
	_heliTypes = ["WFBE_C_SUPPLY_HELI_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
	_truckTypes = ["WFBE_C_SUPPLY_TRUCK_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
	if (typeName _heliTypes != "ARRAY") then {_heliTypes = []};
	if (typeName _truckTypes != "ARRAY") then {_truckTypes = []};
	_supplyTypes = _heliTypes + _truckTypes;
	_loaded = {alive _x && {(typeOf _x) in _supplyTypes} && {(_x getVariable ["SupplyAmount", 0]) > 0}} count vehicles;
	_loading = {alive _x && {_x getVariable ["SupplyLoading", false]}} count vehicles;
	_byHeli = {alive _x && {(typeOf _x) in _heliTypes} && {_x getVariable ["SupplyByHeli", false]} && {(_x getVariable ["SupplyAmount", 0]) > 0}} count vehicles;
	_nearCcLoaded = 0;
	_townCooldown = 0;
	_townReady = 0;
	if (!isNil "towns") then {
		{
			_town = _x;
			if (_town getVariable ["supplyMissionCoolDownEnabled", false]) then {_townCooldown = _townCooldown + 1} else {_townReady = _townReady + 1};
		} forEach towns;
	};
	["INFORMATION", Format ["SERVICE_SUPPLY_AUDIT label=%1 supplyTypes=%2 heliTypes=%3 truckTypes=%4 loadedVehicles=%5 loadingVehicles=%6 loadedHelis=%7 supplyTownsReady=%8 supplyTownsCooldown=%9 loadTime=%10 unloadTime=%11 unloadFunction=%12 startFunction=%13",
		_label, _supplyTypes, _heliTypes, _truckTypes, _loaded, _loading, _byHeli, _townReady, _townCooldown, "WFBE_C_SUPPLY_HELI_LOAD_TIME" Call WASP_PR8_STRESS_GETNUM, "WFBE_C_SUPPLY_HELI_UNLOAD_TIME" Call WASP_PR8_STRESS_GETNUM, !(isNil "WFBE_CL_FNC_SupplyMissionUnload"), !(isNil "WFBE_CL_FNC_SupplyMissionStart")]] Call WASP_PR8_STRESS_LOG;
	{
		_side = _x;
		_structs = if (!isNil "WFBE_CO_FNC_GetSideStructures") then {_side Call WFBE_CO_FNC_GetSideStructures} else {[]};
		if (typeName _structs != "ARRAY") then {_structs = []};
		_names = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", str _side], []];
		_serviceType = missionNamespace getVariable [Format ["WFBE_%1ServicePointTYPE", str _side], -1];
		_ccType = missionNamespace getVariable [Format ["WFBE_%1CommandCenterTYPE", str _side], -1];
		_serviceCount = if ((typeName _names == "ARRAY") && {_serviceType >= 0} && {_serviceType < count _names}) then {{alive _x && {typeOf _x == (_names select _serviceType)}} count _structs} else {0};
		_ccCount = if ((typeName _names == "ARRAY") && {_ccType >= 0} && {_ccType < count _names}) then {{alive _x && {typeOf _x == (_names select _ccType)}} count _structs} else {0};
		["INFORMATION", Format ["SERVICE_SUPPLY_SIDE label=%1 side=%2 servicePoints=%3 commandCenters=%4 repairTruckEasaFuncs=%5/%6", _label, _side Call WASP_PR8_STRESS_SIDETEXT, _serviceCount, _ccCount, !(isNil "WFBE_CL_FNC_CanUseRepairPointEASA"), !(isNil "WFBE_CL_FNC_GetRepairTruckServicePoints")]] Call WASP_PR8_STRESS_LOG;
	} forEach WASP_PR8_STRESS_SIDES;
};

WASP_PR8_STRESS_WDDM_ARTILLERY_AUDIT = {
	Private ["_label","_anchors","_templateMap","_statics","_emptyStatics","_crewedStatics","_staticCrew","_commanderArty","_side","_hq","_walls","_structs","_defs"];
	_label = _this;
	_anchors = ["WFBE_POSITION_ANCHOR_NAMES", []] Call WASP_PR8_STRESS_GETVAR;
	_templateMap = ["WFBE_POSITION_TEMPLATE_MAP", []] Call WASP_PR8_STRESS_GETVAR;
	_statics = {alive _x && {_x isKindOf "StaticWeapon"}} count vehicles;
	_emptyStatics = {alive _x && {_x isKindOf "StaticWeapon"} && {(count crew _x) == 0}} count vehicles;
	_crewedStatics = {alive _x && {_x isKindOf "StaticWeapon"} && {(count crew _x) > 0}} count vehicles;
	_staticCrew = 0;
	{if (alive _x && {_x isKindOf "StaticWeapon"}) then {_staticCrew = _staticCrew + count crew _x}} forEach vehicles;
	_commanderArty = {alive _x && {_x getVariable ["WFBE_CommanderArtillery", false]}} count vehicles;
	["INFORMATION", Format ["WDDM_ARTILLERY_AUDIT label=%1 anchors=%2 templateMapType=%3 templateMapCount=%4 statics=%5 crewedStatics=%6 emptyStatics=%7 staticCrew=%8 commanderArtillery=%9 autoManningRange=%10 maxAI=%11",
		_label, (if (typeName _anchors == "ARRAY") then {count _anchors} else {-1}), typeName _templateMap, (if (typeName _templateMap == "ARRAY") then {count _templateMap} else {-1}), _statics, _crewedStatics, _emptyStatics, _staticCrew, _commanderArty, "WFBE_C_BASE_DEFENSE_MANNING_RANGE" Call WASP_PR8_STRESS_GETNUM, "WFBE_C_BASE_DEFENSE_MAX_AI" Call WASP_PR8_STRESS_GETNUM]] Call WASP_PR8_STRESS_LOG;
	{
		_side = _x;
		_hq = if (!isNil "WFBE_CO_FNC_GetSideHQ") then {_side Call WFBE_CO_FNC_GetSideHQ} else {objNull};
		_walls = if (!isNull _hq) then {_hq getVariable ["wfbe_hq_walls", _hq getVariable ["WFBE_Walls", []]]} else {[]};
		_structs = if (!isNil "WFBE_CO_FNC_GetSideStructures") then {_side Call WFBE_CO_FNC_GetSideStructures} else {[]};
		if (typeName _structs != "ARRAY") then {_structs = []};
		_defs = 0;
		{if (alive _x && {_x isKindOf "StaticWeapon"} && {side _x == _side}) then {_defs = _defs + 1}} forEach vehicles;
		["INFORMATION", Format ["WDDM_ARTILLERY_SIDE label=%1 side=%2 hq=%3 hqWalls=%4 structures=%5 sideStatics=%6", _label, _side Call WASP_PR8_STRESS_SIDETEXT, _hq, (if (typeName _walls == "ARRAY") then {count _walls} else {-1}), count _structs, _defs]] Call WASP_PR8_STRESS_LOG;
	} forEach WASP_PR8_STRESS_SIDES;
};

WASP_PR8_STRESS_PERF_BURST = {
	Private ["_args","_label","_samples","_delay","_i","_fps","_min","_max","_sum","_avg"];
	_args = _this;
	_label = if ((typeName _args == "ARRAY") && {(count _args) > 0}) then {_args select 0} else {"manual"};
	_samples = if ((typeName _args == "ARRAY") && {(count _args) > 1}) then {_args select 1} else {12};
	_delay = if ((typeName _args == "ARRAY") && {(count _args) > 2}) then {_args select 2} else {2};
	_min = 999;
	_max = -1;
	_sum = 0;
	["INITIALIZATION", Format ["PERF_BURST_BEGIN label=%1 samples=%2 delay=%3", _label, _samples, _delay]] Call WASP_PR8_STRESS_LOG;
	for "_i" from 1 to _samples do {
		_fps = diag_fps;
		if (_fps < _min) then {_min = _fps};
		if (_fps > _max) then {_max = _fps};
		_sum = _sum + _fps;
		["INFORMATION", Format ["PERF_BURST #%1 label=%2 t=%3s fps=%4 units=%5 vehicles=%6 groups=%7 dead=%8 stressObjects=%9 stressGroups=%10",
			_i, _label, round time, (round (_fps * 10)) / 10, count allUnits, count vehicles, count allGroups, count allDead, count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
		sleep _delay;
	};
	_avg = if (_samples > 0) then {(round ((_sum / _samples) * 10)) / 10} else {-1};
	["INITIALIZATION", Format ["PERF_BURST_END label=%1 fpsMinAvgMax=[%2,%3,%4]", _label, (round (_min * 10)) / 10, _avg, (round (_max * 10)) / 10]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_SPAWN_VEHICLE_LOAD = {
	Private ["_label","_westPos","_eastPos","_heliTypes","_truckTypes","_heliType","_truckType","_westArmor","_eastArmor","_i","_h","_t","_wa","_ea","_created"];
	_label = _this;
	_westPos = if (isNil "WASP_PR8_STRESS_WESTPOS") then {[4700,2500,0]} else {WASP_PR8_STRESS_WESTPOS};
	_eastPos = if (isNil "WASP_PR8_STRESS_EASTPOS") then {[5200,2500,0]} else {WASP_PR8_STRESS_EASTPOS};
	_heliTypes = ["WFBE_C_SUPPLY_HELI_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
	_truckTypes = ["WFBE_C_SUPPLY_TRUCK_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
	if (typeName _heliTypes != "ARRAY") then {_heliTypes = []};
	if (typeName _truckTypes != "ARRAY") then {_truckTypes = []};
	_heliType = if ((count _heliTypes) > 0) then {_heliTypes select 0} else {"MH60S"};
	_truckType = if ((count _truckTypes) > 0) then {_truckTypes select 0} else {"WarfareSupplyTruck_USMC"};
	_westArmor = "M1A2_US_TUSK_MG_EP1";
	_eastArmor = "T72_RU";
	_created = 0;
	for "_i" from 1 to 4 do {
		_h = [_heliType, [(_westPos select 0) + 70 + (_i * 18), (_westPos select 1) + 130, 0], 90] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
		if (!isNull _h) then {_h setVariable ["SupplyByHeli", true, true]; _h setVariable ["SupplyAmount", 400 + (_i * 50), true]; _created = _created + 1};
		_t = [_truckType, [(_westPos select 0) + 70 + (_i * 18), (_westPos select 1) + 170, 0], 90] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
		if (!isNull _t) then {_t setVariable ["SupplyByHeli", false, true]; _t setVariable ["SupplyAmount", 250 + (_i * 25), true]; _created = _created + 1};
		_wa = [_westArmor, [(_westPos select 0) + 110 + (_i * 22), (_westPos select 1) - 170, 0], 90] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
		if (!isNull _wa) then {_created = _created + 1};
		_ea = [_eastArmor, [(_eastPos select 0) - 110 - (_i * 22), (_eastPos select 1) + 170, 0], 270] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
		if (!isNull _ea) then {_created = _created + 1};
	};
	["INFORMATION", Format ["SPAWN vehicleLoad label=%1 created=%2 heliType=%3 truckType=%4 westArmor=%5 eastArmor=%6 objectsTracked=%7", _label, _created, _heliType, _truckType, _westArmor, _eastArmor, count WASP_PR8_STRESS_OBJECTS]] Call WASP_PR8_STRESS_LOG;
	"vehicle_load" Call WASP_PR8_STRESS_SNAPSHOT;
};

WASP_PR8_STRESS_UI_AUDIT = {
	Private ["_args","_label","_clientFps","_hasDialog","_vehicleType","_cursorType","_visibleMap","_groupUnits","_vehicleSpeed","_cameraView","_shownGps","_hasItemGps","_rubGps","_zoomGps","_wfMenuOpen","_wfTopText","_serviceMenuOpen","_serviceStatusText","_serviceTextLen","_tacticalMenuOpen","_buyMenuOpen","_gpsBefore","_gpsToggled","_rubHud","_wfGpsButtonFound","_serviceClipRisk"];
	_args = _this;
	_label = if ((typeName _args == "ARRAY") && {(count _args) > 0}) then {_args select 0} else {"manual"};
	_clientFps = if ((typeName _args == "ARRAY") && {(count _args) > 1}) then {_args select 1} else {-1};
	_hasDialog = if ((typeName _args == "ARRAY") && {(count _args) > 2}) then {_args select 2} else {false};
	_vehicleType = if ((typeName _args == "ARRAY") && {(count _args) > 3}) then {_args select 3} else {"unknown"};
	_cursorType = if ((typeName _args == "ARRAY") && {(count _args) > 4}) then {_args select 4} else {"unknown"};
	_visibleMap = if ((typeName _args == "ARRAY") && {(count _args) > 5}) then {_args select 5} else {false};
	_groupUnits = if ((typeName _args == "ARRAY") && {(count _args) > 6}) then {_args select 6} else {-1};
	_vehicleSpeed = if ((typeName _args == "ARRAY") && {(count _args) > 7}) then {_args select 7} else {-1};
	_cameraView = if ((typeName _args == "ARRAY") && {(count _args) > 8}) then {_args select 8} else {"unknown"};
	_shownGps = if ((typeName _args == "ARRAY") && {(count _args) > 9}) then {_args select 9} else {false};
	_hasItemGps = if ((typeName _args == "ARRAY") && {(count _args) > 10}) then {_args select 10} else {false};
	_rubGps = if ((typeName _args == "ARRAY") && {(count _args) > 11}) then {_args select 11} else {-1};
	_zoomGps = if ((typeName _args == "ARRAY") && {(count _args) > 12}) then {_args select 12} else {-1};
	_wfMenuOpen = if ((typeName _args == "ARRAY") && {(count _args) > 13}) then {_args select 13} else {false};
	_wfTopText = if ((typeName _args == "ARRAY") && {(count _args) > 14}) then {_args select 14} else {""};
	_serviceMenuOpen = if ((typeName _args == "ARRAY") && {(count _args) > 15}) then {_args select 15} else {false};
	_serviceStatusText = if ((typeName _args == "ARRAY") && {(count _args) > 16}) then {_args select 16} else {""};
	_serviceTextLen = count toArray _serviceStatusText;
	_tacticalMenuOpen = if ((typeName _args == "ARRAY") && {(count _args) > 17}) then {_args select 17} else {false};
	_buyMenuOpen = if ((typeName _args == "ARRAY") && {(count _args) > 18}) then {_args select 18} else {false};
	_gpsBefore = if ((typeName _args == "ARRAY") && {(count _args) > 19}) then {_args select 19} else {_shownGps};
	_rubHud = if ((typeName _args == "ARRAY") && {(count _args) > 20}) then {_args select 20} else {-1};
	_wfGpsButtonFound = if ((typeName _args == "ARRAY") && {(count _args) > 21}) then {_args select 21} else {false};
	_serviceClipRisk = if ((typeName _args == "ARRAY") && {(count _args) > 22}) then {_args select 22} else {false};
	_gpsToggled = false;
	if (_gpsBefore) then {_gpsToggled = !_shownGps} else {_gpsToggled = _shownGps};
	["INFORMATION", Format ["UI_AUDIT label=%1 clientFps=%2 serverFps=%3 clientDialog=%4 visibleMap=%5 shownGPS=%6 hasItemGPS=%7 RUBGPS=%8 zoomgps=%9 wfMenuOpen=%10 tacticalMenuOpen=%11 buyMenuOpen=%12 serviceMenuOpen=%13 vehicleType=%14 cursorType=%15 groupUnits=%16 vehicleSpeed=%17 cameraView=%18 confirmFunction=%19 serviceMenuProof=see-GUI_Menu_Service queueTabs=see-GUI_Menu_BuyUnits topStrip=uptime|time|players|towns|svSigned|clientFps rhud=moneyIncome|baseStatus|fpsClientServer",
		_label, _clientFps, (round (diag_fps * 10)) / 10, _hasDialog, _visibleMap, _shownGps, _hasItemGps, _rubGps, _zoomGps, _wfMenuOpen, _tacticalMenuOpen, _buyMenuOpen, _serviceMenuOpen, _vehicleType, _cursorType, _groupUnits, _vehicleSpeed, _cameraView, !(isNil "WFBE_CL_FNC_ConfirmAction")]] Call WASP_PR8_STRESS_LOG;
	["INFORMATION", Format ["GPS_UI_AUDIT label=%1 gpsBefore=%2 shownGPS=%3 toggled=%4 hasItemGPS=%5 RUBGPS=%6 zoomgps=%7 visibleMap=%8 wfMenuOpen=%9 wfTopText='%10' serviceMenuOpen=%11 serviceStatusText='%12' tacticalMenuOpen=%13 buyMenuOpen=%14",
		_label, _gpsBefore, _shownGps, _gpsToggled, _hasItemGps, _rubGps, _zoomGps, _visibleMap, _wfMenuOpen, _wfTopText, _serviceMenuOpen, _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen]] Call WASP_PR8_STRESS_LOG;
	["INFORMATION", Format ["CLIENT_GPS_STATE label=%1 hasItemGPS=%2 shownGPS=%3 gpsBefore=%4 changed=%5 RUBHUD=%6 RUBGPS=%7 zoomgps=%8 visibleMap=%9 dialog=%10", _label, _hasItemGps, _shownGps, _gpsBefore, _gpsToggled, _rubHud, _rubGps, _zoomGps, _visibleMap, _hasDialog]] Call WASP_PR8_STRESS_LOG;
	["INFORMATION", Format ["CLIENT_UI_TEXT_STATE label=%1 wfMenu=%2 topStrip='%3' gpsButtonFound=%4 serviceMenu=%5 serviceLen=%6 serviceClipRisk=%7 tacticalMenu=%8 buyMenu=%9", _label, _wfMenuOpen, _wfTopText, _wfGpsButtonFound, _serviceMenuOpen, _serviceTextLen, _serviceClipRisk, _tacticalMenuOpen, _buyMenuOpen]] Call WASP_PR8_STRESS_LOG;
	if (_serviceMenuOpen) then {
		["INFORMATION", Format ["CLIENT_SERVICE_CLIP_AUDIT label=%1 display=20000 infoIdc=20021 textLen=%2 clipRisk=%3 text='%4'", _label, _serviceTextLen, _serviceClipRisk, _serviceStatusText]] Call WASP_PR8_STRESS_LOG;
	} else {
		["INFORMATION", Format ["CLIENT_SERVICE_CLIP_AUDIT label=%1 display=missing infoIdc=20021 textLen=0 clipRisk=false reason=noDisplay", _label]] Call WASP_PR8_STRESS_LOG;
	};
};

WASP_PR8_STRESS_PLAYER_EXPERIENCE_AUDIT = {
	Private ["_args","_label","_clientFps","_hasDialog","_vehicleType","_cursorType","_visibleMap","_groupUnits","_vehicleSpeed","_cameraView","_heliTypes","_nearLoadedHelis","_clientUnits","_serverUnits","_serverGroups"];
	_args = _this;
	_label = if ((typeName _args == "ARRAY") && {(count _args) > 0}) then {_args select 0} else {"manual"};
	_clientFps = if ((typeName _args == "ARRAY") && {(count _args) > 1}) then {_args select 1} else {-1};
	_hasDialog = if ((typeName _args == "ARRAY") && {(count _args) > 2}) then {_args select 2} else {false};
	_vehicleType = if ((typeName _args == "ARRAY") && {(count _args) > 3}) then {_args select 3} else {"unknown"};
	_cursorType = if ((typeName _args == "ARRAY") && {(count _args) > 4}) then {_args select 4} else {"unknown"};
	_visibleMap = if ((typeName _args == "ARRAY") && {(count _args) > 5}) then {_args select 5} else {false};
	_groupUnits = if ((typeName _args == "ARRAY") && {(count _args) > 6}) then {_args select 6} else {-1};
	_vehicleSpeed = if ((typeName _args == "ARRAY") && {(count _args) > 7}) then {_args select 7} else {-1};
	_cameraView = if ((typeName _args == "ARRAY") && {(count _args) > 8}) then {_args select 8} else {"unknown"};
	_heliTypes = ["WFBE_C_SUPPLY_HELI_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
	if (typeName _heliTypes != "ARRAY") then {_heliTypes = []};
	_nearLoadedHelis = {alive _x && {(typeOf _x) in _heliTypes} && {(_x getVariable ["SupplyAmount", 0]) > 0}} count vehicles;
	_clientUnits = {isPlayer _x} count allUnits;
	_serverUnits = count allUnits;
	_serverGroups = count allGroups;
	["INFORMATION", Format ["PLAYER_EXPERIENCE_AUDIT label=%1 clientFps=%2 serverFps=%3 dialog=%4 visibleMap=%5 vehicle=%6 cursor=%7 groupUnits=%8 vehicleSpeed=%9 cameraView=%10 serverUnits=%11 serverGroups=%12 playerUnits=%13 loadedSupplyHelis=%14 serviceUnloadFunc=%15 serviceStartFunc=%16 fpsRisk=%17",
		_label, _clientFps, (round (diag_fps * 10)) / 10, _hasDialog, _visibleMap, _vehicleType, _cursorType, _groupUnits, _vehicleSpeed, _cameraView, _serverUnits, _serverGroups, _clientUnits, _nearLoadedHelis, !(isNil "WFBE_CL_FNC_SupplyMissionUnload"), !(isNil "WFBE_CL_FNC_SupplyMissionStart"), (_clientFps > 0 && {_clientFps < 25})]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_AI_DELEGATION_AUDIT = {
	Private ["_label","_delegationMode","_hcs","_delegators","_delegatorState","_player","_uid","_varName","_value","_trackedGroups","_emptyGroups","_localLeaderGroups","_remoteLeaderGroups","_serverLeaderGroups","_nullLeaderGroups","_stuckLeaders","_grp","_leader","_target","_targetOk","_distanceToTarget","_waypointGroups","_noWaypointGroups"];
	_label = _this;
	_delegationMode = "WFBE_C_AI_DELEGATION" Call WASP_PR8_STRESS_GETNUM;
	_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_delegators = [];
	if (!isNil "WFBE_SE_FNC_GetDelegators") then {_delegators = 20 Call WFBE_SE_FNC_GetDelegators};
	_delegatorState = [];
	{
		_player = _x;
		_uid = getPlayerUID _player;
		_varName = Format ["WFBE_AI_DELEGATION_%1", _uid];
		_value = missionNamespace getVariable [_varName, "nil"];
		_delegatorState set [count _delegatorState, Format ["%1:%2:%3", name _player, owner _player, _value]];
	} forEach playableUnits;
	_trackedGroups = 0;
	_emptyGroups = 0;
	_localLeaderGroups = 0;
	_remoteLeaderGroups = 0;
	_serverLeaderGroups = 0;
	_nullLeaderGroups = 0;
	_stuckLeaders = 0;
	_waypointGroups = 0;
	_noWaypointGroups = 0;
	{
		_grp = _x;
		if (!isNull _grp) then {
			_trackedGroups = _trackedGroups + 1;
			if ((count units _grp) == 0) then {_emptyGroups = _emptyGroups + 1};
			if ((count waypoints _grp) == 0) then {_noWaypointGroups = _noWaypointGroups + 1} else {_waypointGroups = _waypointGroups + 1};
			_leader = leader _grp;
			if (isNull _leader) then {
				_nullLeaderGroups = _nullLeaderGroups + 1;
			} else {
				if (local _leader) then {_localLeaderGroups = _localLeaderGroups + 1} else {_remoteLeaderGroups = _remoteLeaderGroups + 1};
				if ((owner _leader) == 2) then {_serverLeaderGroups = _serverLeaderGroups + 1};
				_target = _grp getVariable ["WASP_PR8_STRESS_TARGET", []];
				_targetOk = (typeName _target == "ARRAY") && {(count _target) > 1};
				if (_targetOk) then {
					_distanceToTarget = _leader distance _target;
					if ((stopped _leader || unitReady _leader) && {_distanceToTarget > 75}) then {_stuckLeaders = _stuckLeaders + 1};
				};
			};
		};
	} forEach WASP_PR8_STRESS_GROUPS;
	["INFORMATION", Format ["AI_DELEGATION_AUDIT label=%1 mode=%2 hcIds=%3 delegators=%4 delegatorState=%5 trackedGroups=%6 emptyGroups=%7 waypointGroups=%8 noWaypointGroups=%9 localLeaderGroups=%10 remoteLeaderGroups=%11 serverLeaderGroups=%12 nullLeaderGroups=%13 stuckLeaders=%14 clientFpsMin=%15",
		_label, _delegationMode, _hcs, _delegators, _delegatorState, _trackedGroups, _emptyGroups, _waypointGroups, _noWaypointGroups, _localLeaderGroups, _remoteLeaderGroups, _serverLeaderGroups, _nullLeaderGroups, _stuckLeaders, "WFBE_C_AI_DELEGATION_FPS_MIN" Call WASP_PR8_STRESS_GETNUM]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_BUGHUNT_AUDIT = {
	Private ["_label","_hcs","_serverFps","_aiCount","_playerCount","_emptyGroups","_deadVehicles","_damagedVehicles","_staticCrew","_emptyStatics","_loadedSupply","_loadingSupply","_openQueueItems","_townsActive","_townsCooldown","_sidesReady","_missingClientFuncs","_missingServerFuncs"];
	_label = _this;
	_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_serverFps = (round (diag_fps * 10)) / 10;
	_aiCount = {!isPlayer _x} count allUnits;
	_playerCount = {isPlayer _x} count allUnits;
	_emptyGroups = {{alive _x} count (units _x) == 0} count allGroups;
	_deadVehicles = {!(alive _x)} count vehicles;
	_damagedVehicles = {alive _x && {(getDammage _x) > 0.05}} count vehicles;
	_staticCrew = 0;
	_emptyStatics = {alive _x && {_x isKindOf "StaticWeapon"} && {(count crew _x) == 0}} count vehicles;
	{if (alive _x && {_x isKindOf "StaticWeapon"}) then {_staticCrew = _staticCrew + count crew _x}} forEach vehicles;
	_loadedSupply = {alive _x && {(_x getVariable ["SupplyAmount", 0]) > 0}} count vehicles;
	_loadingSupply = {alive _x && {_x getVariable ["SupplyLoading", false]}} count vehicles;
	_openQueueItems = 0;
	{_openQueueItems = _openQueueItems + count (_x getVariable ["wfbe_queue", []])} forEach allGroups;
	_townsActive = 0;
	_townsCooldown = 0;
	if (!isNil "towns") then {
		{
			if (_x getVariable ["wfbe_active", false]) then {_townsActive = _townsActive + 1};
			if (_x getVariable ["supplyMissionCoolDownEnabled", false]) then {_townsCooldown = _townsCooldown + 1};
		} forEach towns;
	};
	_sidesReady = if (isNil "WASP_PR8_STRESS_SIDES") then {[]} else {WASP_PR8_STRESS_SIDES};
	_missingClientFuncs = ["WFBE_CL_FNC_SupplyMissionStart","WFBE_CL_FNC_SupplyMissionUnload","WFBE_CL_FNC_ConfirmAction","WFBE_CL_FNC_CanUseRepairPointEASA","WFBE_CL_FNC_GetRepairTruckServicePoints"] Call WASP_PR8_STRESS_MISSING;
	_missingServerFuncs = ["WFBE_SE_FNC_HandleEmptyVehicle","WFBE_SE_FNC_ProcessUpgrade","WFBE_SE_FNC_SupplyMissionTimerForTown","Server_ConstructPosition","ConstructDefense","HandleDefense"] Call WASP_PR8_STRESS_MISSING;
	["INFORMATION", Format ["BUGHUNT_AUDIT label=%1 serverFps=%2 hcIds=%3 players=%4 ai=%5 units=%6 vehicles=%7 groups=%8 emptyGroups=%9 deadVehicles=%10 damagedVehicles=%11 loadedSupply=%12 loadingSupply=%13 staticCrew=%14 emptyStatics=%15 openQueueItems=%16 townsActive=%17 townsCooldown=%18 sides=%19 missingClientFuncs=%20 missingServerFuncs=%21",
		_label, _serverFps, _hcs, _playerCount, _aiCount, count allUnits, count vehicles, count allGroups, _emptyGroups, _deadVehicles, _damagedVehicles, _loadedSupply, _loadingSupply, _staticCrew, _emptyStatics, _openQueueItems, _townsActive, _townsCooldown, _sidesReady, _missingClientFuncs, _missingServerFuncs]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_RANDOM_BUGHUNT_AUDIT = {
	Private ["_label","_units","_vehicles","_groups","_townList","_sampleUnits","_sampleVehicles","_sampleGroups","_sampleTowns","_i","_idx","_unit","_vehicle","_group","_leader","_destinationData","_destination","_veh","_town","_supply","_sideID","_orphanUnits","_noOwnerUnits","_stoppedNoDest","_deadSampleUnits","_crewNoDriver","_emptyStaticSample","_overCrewedStatics","_criticalVehicles","_loadedSupplySample","_loadingSupplySample","_emptyGroupSample","_noWaypointGroupSample","_nullLeaderGroupSample","_remoteLeaderGroupSample","_townBadSide","_townBadSupply","_townActive","_missingCoreVars","_missingClientFuncs","_missingServerFuncs","_name"];
	_label = _this;
	_units = allUnits;
	_vehicles = vehicles;
	_groups = allGroups;
	_townList = if (isNil "towns") then {[]} else {towns};
	_sampleUnits = 0;
	_sampleVehicles = 0;
	_sampleGroups = 0;
	_sampleTowns = 0;
	_orphanUnits = 0;
	_noOwnerUnits = 0;
	_stoppedNoDest = 0;
	_deadSampleUnits = 0;
	_crewNoDriver = 0;
	_emptyStaticSample = 0;
	_overCrewedStatics = 0;
	_criticalVehicles = 0;
	_loadedSupplySample = 0;
	_loadingSupplySample = 0;
	_emptyGroupSample = 0;
	_noWaypointGroupSample = 0;
	_nullLeaderGroupSample = 0;
	_remoteLeaderGroupSample = 0;
	_townBadSide = 0;
	_townBadSupply = 0;
	_townActive = 0;
	_missingCoreVars = [];

	for "_i" from 1 to 24 do {
		if (count _units > 0) then {
			_idx = floor (random (count _units));
			_unit = _units select _idx;
			_sampleUnits = _sampleUnits + 1;
			if (isNull (group _unit)) then {_orphanUnits = _orphanUnits + 1};
			if ((owner _unit) <= 0) then {_noOwnerUnits = _noOwnerUnits + 1};
			if !(alive _unit) then {_deadSampleUnits = _deadSampleUnits + 1};
			if (alive _unit && {!isPlayer _unit}) then {
				_destinationData = expectedDestination _unit;
				_destination = [];
				if (count _destinationData > 0) then {_destination = _destinationData select 0};
				if ((stopped _unit || unitReady _unit) && {((typeName _destination != "ARRAY") || {(count _destination) < 2})}) then {_stoppedNoDest = _stoppedNoDest + 1};
			};
		};
		if (count _vehicles > 0) then {
			_idx = floor (random (count _vehicles));
			_veh = _vehicles select _idx;
			_sampleVehicles = _sampleVehicles + 1;
			if (alive _veh && {(getDammage _veh) > 0.85}) then {_criticalVehicles = _criticalVehicles + 1};
			if (alive _veh && {(_veh getVariable ["SupplyAmount", 0]) > 0}) then {_loadedSupplySample = _loadedSupplySample + 1};
			if (alive _veh && {_veh getVariable ["SupplyLoading", false]}) then {_loadingSupplySample = _loadingSupplySample + 1};
			if (alive _veh && {_veh isKindOf "StaticWeapon"}) then {
				if ((count crew _veh) == 0) then {_emptyStaticSample = _emptyStaticSample + 1};
				if ((count crew _veh) > 1) then {_overCrewedStatics = _overCrewedStatics + 1};
			};
			if (alive _veh && {!(_veh isKindOf "StaticWeapon")} && {(count crew _veh) > 0} && {isNull (driver _veh)}) then {_crewNoDriver = _crewNoDriver + 1};
		};
		if (count _groups > 0) then {
			_idx = floor (random (count _groups));
			_group = _groups select _idx;
			if (!isNull _group) then {
				_sampleGroups = _sampleGroups + 1;
				if ((count units _group) == 0) then {_emptyGroupSample = _emptyGroupSample + 1};
				if ((count waypoints _group) == 0) then {_noWaypointGroupSample = _noWaypointGroupSample + 1};
				_leader = leader _group;
				if (isNull _leader) then {
					_nullLeaderGroupSample = _nullLeaderGroupSample + 1;
				} else {
					if !(local _leader) then {_remoteLeaderGroupSample = _remoteLeaderGroupSample + 1};
				};
			};
		};
		if (count _townList > 0) then {
			_idx = floor (random (count _townList));
			_town = _townList select _idx;
			_sampleTowns = _sampleTowns + 1;
			_sideID = _town getVariable ["sideID", -99];
			if ((_sideID < -1) || {_sideID > 3}) then {_townBadSide = _townBadSide + 1};
			_supply = _town getVariable ["supplyValue", _town getVariable ["supply", -1]];
			if ((typeName _supply == "SCALAR") && {_supply < 0}) then {_townBadSupply = _townBadSupply + 1};
			if (_town getVariable ["wfbe_active", false]) then {_townActive = _townActive + 1};
		};
	};

	{
		_name = _x;
		if (isNil _name) then {_missingCoreVars set [count _missingCoreVars, _name]};
	} forEach ["towns","WFBE_HEADLESSCLIENTS_ID","WFBE_C_AI_DELEGATION","WFBE_C_AI_DELEGATION_FPS_MIN","WFBE_C_SUPPLY_HELI_LOAD_TIME","WFBE_C_SUPPLY_HELI_UNLOAD_TIME"];
	_missingClientFuncs = ["WFBE_CL_FNC_SupplyMissionStart","WFBE_CL_FNC_SupplyMissionUnload","WFBE_CL_FNC_ConfirmAction","WFBE_CL_FNC_CanUseRepairPointEASA","WFBE_CL_FNC_GetRepairTruckServicePoints"] Call WASP_PR8_STRESS_MISSING;
	_missingServerFuncs = ["WFBE_SE_FNC_HandleEmptyVehicle","WFBE_SE_FNC_ProcessUpgrade","WFBE_SE_FNC_SupplyMissionTimerForTown","Server_ConstructPosition","ConstructDefense","HandleDefense"] Call WASP_PR8_STRESS_MISSING;

	["INFORMATION", Format ["RANDOM_BUGHUNT_AUDIT label=%1 samples=[units:%2,vehicles:%3,groups:%4,towns:%5] orphanUnits=%6 noOwnerUnits=%7 deadSampleUnits=%8 stoppedNoDest=%9 crewNoDriver=%10 emptyStaticSample=%11 overCrewedStatics=%12 criticalVehicles=%13 loadedSupplySample=%14 loadingSupplySample=%15 emptyGroupSample=%16 noWaypointGroupSample=%17 nullLeaderGroupSample=%18 remoteLeaderGroupSample=%19 townBadSide=%20 townBadSupply=%21 townActiveSample=%22 missingCoreVars=%23 missingClientFuncs=%24 missingServerFuncs=%25",
		_label, _sampleUnits, _sampleVehicles, _sampleGroups, _sampleTowns, _orphanUnits, _noOwnerUnits, _deadSampleUnits, _stoppedNoDest, _crewNoDriver, _emptyStaticSample, _overCrewedStatics, _criticalVehicles, _loadedSupplySample, _loadingSupplySample, _emptyGroupSample, _noWaypointGroupSample, _nullLeaderGroupSample, _remoteLeaderGroupSample, _townBadSide, _townBadSupply, _townActive, _missingCoreVars, _missingClientFuncs, _missingServerFuncs]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_HANDLE_COMMAND = {
	Private ["_payload","_command","_source","_sourceName","_clientFps","_clientDialog","_vehicleType","_cursorType","_visibleMap","_groupUnitsClient","_vehicleSpeed","_cameraView","_shownGps","_hasItemGps","_rubGps","_zoomGps","_wfMenuOpen","_wfTopText","_serviceMenuOpen","_serviceStatusText","_tacticalMenuOpen","_buyMenuOpen","_gpsBefore","_rubHud","_wfGpsButtonFound","_serviceClipRisk","_westPos","_eastPos","_westClass","_eastClass","_units","_groups","_rw","_re","_heavyGroups","_heavyUnits","_sample"];
	_payload = _this;
	_command = "unknown";
	_source = objNull;
	_sourceName = "unknown";
	_clientFps = -1;
	_clientDialog = false;
	_vehicleType = "unknown";
	_cursorType = "unknown";
	_visibleMap = false;
	_groupUnitsClient = -1;
	_vehicleSpeed = -1;
	_cameraView = "unknown";
	_shownGps = false;
	_hasItemGps = false;
	_rubGps = -1;
	_zoomGps = -1;
	_wfMenuOpen = false;
	_wfTopText = "";
	_serviceMenuOpen = false;
	_serviceStatusText = "";
	_tacticalMenuOpen = false;
	_buyMenuOpen = false;
	_gpsBefore = false;
	_rubHud = -1;
	_wfGpsButtonFound = false;
	_serviceClipRisk = false;
	if (typeName _payload == "ARRAY") then {
		if (count _payload > 0) then {_command = _payload select 0};
		if (count _payload > 1) then {_source = _payload select 1};
		if (count _payload > 3) then {_sourceName = _payload select 3};
		if (count _payload > 4) then {_clientFps = _payload select 4};
		if (count _payload > 5) then {_clientDialog = _payload select 5};
		if (count _payload > 6) then {_vehicleType = _payload select 6};
		if (count _payload > 7) then {_cursorType = _payload select 7};
		if (count _payload > 8) then {_visibleMap = _payload select 8};
		if (count _payload > 9) then {_groupUnitsClient = _payload select 9};
		if (count _payload > 10) then {_vehicleSpeed = _payload select 10};
		if (count _payload > 11) then {_cameraView = _payload select 11};
		if (count _payload > 12) then {_shownGps = _payload select 12};
		if (count _payload > 13) then {_hasItemGps = _payload select 13};
		if (count _payload > 14) then {_rubGps = _payload select 14};
		if (count _payload > 15) then {_zoomGps = _payload select 15};
		if (count _payload > 16) then {_wfMenuOpen = _payload select 16};
		if (count _payload > 17) then {_wfTopText = _payload select 17};
		if (count _payload > 18) then {_serviceMenuOpen = _payload select 18};
		if (count _payload > 19) then {_serviceStatusText = _payload select 19};
		if (count _payload > 20) then {_tacticalMenuOpen = _payload select 20};
		if (count _payload > 21) then {_buyMenuOpen = _payload select 21};
		if (count _payload > 22) then {_gpsBefore = _payload select 22};
		if (count _payload > 23) then {_rubHud = _payload select 23};
		if (count _payload > 24) then {_wfGpsButtonFound = _payload select 24};
		if (count _payload > 25) then {_serviceClipRisk = _payload select 25};
	};
	["INFORMATION", Format ["CLIENT_COMMAND command=%1 source=%2 sourceName=%3 clientFps=%4 clientDialog=%5 visibleMap=%6 shownGPS=%7 hasItemGPS=%8 wfMenuOpen=%9 serviceMenuOpen=%10 tacticalMenuOpen=%11 buyMenuOpen=%12 vehicleType=%13 cursorType=%14 groupUnits=%15 vehicleSpeed=%16 cameraView=%17 serverFps=%18",
		_command, _source, _sourceName, _clientFps, _clientDialog, _visibleMap, _shownGps, _hasItemGps, _wfMenuOpen, _serviceMenuOpen, _tacticalMenuOpen, _buyMenuOpen, _vehicleType, _cursorType, _groupUnitsClient, _vehicleSpeed, _cameraView, (round (diag_fps * 10)) / 10]] Call WASP_PR8_STRESS_LOG;

	if (_command == "queue-operator") exitWith {"operator" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-ai-long") exitWith {"ai-long" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-systems") exitWith {"systems" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-ui-long") exitWith {"ui-long" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-full") exitWith {"operator" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-ai") exitWith {"ai" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-factory") exitWith {"factory" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-service") exitWith {"service" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-wddm") exitWith {"wddm" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-ui") exitWith {"ui" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-load") exitWith {"load" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-gps-ui") exitWith {"gps-ui" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-bughunt") exitWith {"bughunt" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-town-regression") exitWith {"town-regression" Call WASP_PR8_STRESS_QUEUE_ADD};
	if (_command == "queue-status") exitWith {
		["INFORMATION", Format ["QUEUE_STATUS running=%1 pending=%2 cleanupLoop=%3 stopFlag=%4", WASP_PR8_STRESS_QUEUE_RUNNING, count WASP_PR8_STRESS_QUEUE, WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING, WASP_PR8_STRESS_QUEUE_STOP]] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "queue-stop") exitWith {
		WASP_PR8_STRESS_QUEUE_STOP = true;
		WASP_PR8_STRESS_QUEUE = [];
		["INFORMATION", "QUEUE_STOP requested pending=0"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "cleanup-loop-start") exitWith {true Call WASP_PR8_STRESS_CLEANUP_LOOP_SET};
	if (_command == "cleanup-loop-stop") exitWith {false Call WASP_PR8_STRESS_CLEANUP_LOOP_SET};
	if (_command == "queue-proof") exitWith {
		["INFORMATION", Format ["QUEUE_PROOF running=%1 pending=%2 cleanupLoop=%3 hcIds=%4 perfAuditSid=%5 serverFps=%6", WASP_PR8_STRESS_QUEUE_RUNNING, count WASP_PR8_STRESS_QUEUE, WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING, missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []], (if (isNil "PerformanceAuditSessionId") then {"none"} else {PerformanceAuditSessionId}), (round (diag_fps * 10)) / 10]] Call WASP_PR8_STRESS_LOG;
		"queue_proof" Call WASP_PR8_STRESS_SNAPSHOT;
	};
	if (_command == "snapshot") exitWith {
		"client_snapshot" Call WASP_PR8_STRESS_SNAPSHOT;
		["INFORMATION", "CLIENT_COMMAND_DONE snapshot"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "ai-audit") exitWith {
		"client_ai_audit" Call WASP_PR8_STRESS_AI_BEHAVIOR;
		"client_ai_audit" Call WASP_PR8_STRESS_AI_DELEGATION_AUDIT;
		"client_ai_audit" Call WASP_PR8_STRESS_SNAPSHOT;
		["INFORMATION", "CLIENT_COMMAND_DONE ai-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "ai-deep-sample") exitWith {
		[] Spawn {
			Private ["_sample"];
			for "_sample" from 1 to 5 do {
				Format ["client_ai_deep_%1", _sample] Call WASP_PR8_STRESS_AI_BEHAVIOR;
				sleep 3;
			};
			"client_ai_deep_done" Call WASP_PR8_STRESS_SNAPSHOT;
			["INFORMATION", "CLIENT_COMMAND_DONE ai-deep-sample"] Call WASP_PR8_STRESS_LOG;
		};
		["INFORMATION", "CLIENT_COMMAND_SCHEDULED ai-deep-sample"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "spawn-wave") exitWith {
		_westPos = if (isNil "WASP_PR8_STRESS_WESTPOS") then {[4700,2500,0]} else {WASP_PR8_STRESS_WESTPOS};
		_eastPos = if (isNil "WASP_PR8_STRESS_EASTPOS") then {[5200,2500,0]} else {WASP_PR8_STRESS_EASTPOS};
		_westClass = if (isNil "WASP_PR8_STRESS_WESTCLASS") then {"USMC_Soldier"} else {WASP_PR8_STRESS_WESTCLASS};
		_eastClass = if (isNil "WASP_PR8_STRESS_EASTCLASS") then {"RU_Soldier"} else {WASP_PR8_STRESS_EASTCLASS};
		_units = if (isNil "WASP_PR8_STRESS_UNITS_PER_GROUP") then {5} else {WASP_PR8_STRESS_UNITS_PER_GROUP};
		_groups = if (isNil "WASP_PR8_STRESS_REINFORCEMENT_GROUPS") then {2} else {WASP_PR8_STRESS_REINFORCEMENT_GROUPS};
		_rw = [west, [(_westPos select 0) + 260, (_westPos select 1) - 160, 0], _groups, _units, _westClass, _eastPos] Call WASP_PR8_STRESS_SPAWN_AI;
		_re = [east, [(_eastPos select 0) - 260, (_eastPos select 1) + 160, 0], _groups, _units, _eastClass, _westPos] Call WASP_PR8_STRESS_SPAWN_AI;
		["INFORMATION", Format ["SPAWN clientWave west=%1 east=%2 groupsTracked=%3", _rw, _re, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
		"client_spawn_wave" Call WASP_PR8_STRESS_SNAPSHOT;
	};
	if (_command == "spawn-heavy-wave") exitWith {
		_westPos = if (isNil "WASP_PR8_STRESS_WESTPOS") then {[4700,2500,0]} else {WASP_PR8_STRESS_WESTPOS};
		_eastPos = if (isNil "WASP_PR8_STRESS_EASTPOS") then {[5200,2500,0]} else {WASP_PR8_STRESS_EASTPOS};
		_westClass = if (isNil "WASP_PR8_STRESS_WESTCLASS") then {"USMC_Soldier"} else {WASP_PR8_STRESS_WESTCLASS};
		_eastClass = if (isNil "WASP_PR8_STRESS_EASTCLASS") then {"RU_Soldier"} else {WASP_PR8_STRESS_EASTCLASS};
		_units = if (isNil "WASP_PR8_STRESS_UNITS_PER_GROUP") then {5} else {WASP_PR8_STRESS_UNITS_PER_GROUP};
		_groups = if (isNil "WASP_PR8_STRESS_REINFORCEMENT_GROUPS") then {2} else {WASP_PR8_STRESS_REINFORCEMENT_GROUPS};
		_heavyGroups = _groups * 3;
		_heavyUnits = _units + 2;
		_rw = [west, [(_westPos select 0) + 340, (_westPos select 1) - 230, 0], _heavyGroups, _heavyUnits, _westClass, _eastPos] Call WASP_PR8_STRESS_SPAWN_AI;
		_re = [east, [(_eastPos select 0) - 340, (_eastPos select 1) + 230, 0], _heavyGroups, _heavyUnits, _eastClass, _westPos] Call WASP_PR8_STRESS_SPAWN_AI;
		["INFORMATION", Format ["SPAWN clientHeavyWave west=%1 east=%2 groups=%3 units=%4 groupsTracked=%5", _rw, _re, _heavyGroups, _heavyUnits, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
		"client_heavy_wave" Call WASP_PR8_STRESS_SNAPSHOT;
	};
	if (_command == "perf-burst") exitWith {
		["client_perf_burst", 12, 2] Spawn WASP_PR8_STRESS_PERF_BURST;
		["INFORMATION", "CLIENT_COMMAND_DONE perf-burst spawned"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "vehicle-load") exitWith {
		"client_vehicle_load" Call WASP_PR8_STRESS_SPAWN_VEHICLE_LOAD;
		["INFORMATION", "CLIENT_COMMAND_DONE vehicle-load"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "factory-audit") exitWith {
		"client_factory_audit" Call WASP_PR8_STRESS_FACTORY_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE factory-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "ui-audit") exitWith {
		["client_ui_audit", _clientFps, _clientDialog, _vehicleType, _cursorType, _visibleMap, _groupUnitsClient, _vehicleSpeed, _cameraView, _shownGps, _hasItemGps, _rubGps, _zoomGps, _wfMenuOpen, _wfTopText, _serviceMenuOpen, _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen, _gpsBefore, _rubHud, _wfGpsButtonFound, _serviceClipRisk] Call WASP_PR8_STRESS_UI_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE ui-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "gps-ui-audit") exitWith {
		["client_gps_ui_audit", _clientFps, _clientDialog, _vehicleType, _cursorType, _visibleMap, _groupUnitsClient, _vehicleSpeed, _cameraView, _shownGps, _hasItemGps, _rubGps, _zoomGps, _wfMenuOpen, _wfTopText, _serviceMenuOpen, _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen, _gpsBefore, _rubHud, _wfGpsButtonFound, _serviceClipRisk] Call WASP_PR8_STRESS_UI_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE gps-ui-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "gps-gain-toggle-audit") exitWith {
		["client_gps_gain_toggle_audit", _clientFps, _clientDialog, _vehicleType, _cursorType, _visibleMap, _groupUnitsClient, _vehicleSpeed, _cameraView, _shownGps, _hasItemGps, _rubGps, _zoomGps, _wfMenuOpen, _wfTopText, _serviceMenuOpen, _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen, _gpsBefore, _rubHud, _wfGpsButtonFound, _serviceClipRisk] Call WASP_PR8_STRESS_UI_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE gps-gain-toggle-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "player-experience-audit") exitWith {
		["client_player_experience", _clientFps, _clientDialog, _vehicleType, _cursorType, _visibleMap, _groupUnitsClient, _vehicleSpeed, _cameraView] Call WASP_PR8_STRESS_PLAYER_EXPERIENCE_AUDIT;
		"client_player_experience" Call WASP_PR8_STRESS_SNAPSHOT;
		["INFORMATION", "CLIENT_COMMAND_DONE player-experience-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "ai-delegation-audit") exitWith {
		"client_ai_delegation_audit" Call WASP_PR8_STRESS_AI_DELEGATION_AUDIT;
		"client_ai_delegation_audit" Call WASP_PR8_STRESS_AI_BEHAVIOR;
		["INFORMATION", "CLIENT_COMMAND_DONE ai-delegation-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "bughunt-audit") exitWith {
		"client_bughunt_audit" Call WASP_PR8_STRESS_BUGHUNT_AUDIT;
		"client_bughunt_audit" Call WASP_PR8_STRESS_RANDOM_BUGHUNT_AUDIT;
		"client_bughunt_audit" Call WASP_PR8_STRESS_SNAPSHOT;
		["INFORMATION", "CLIENT_COMMAND_DONE bughunt-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "random-bughunt-audit") exitWith {
		"client_random_bughunt_audit" Call WASP_PR8_STRESS_RANDOM_BUGHUNT_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE random-bughunt-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "service-supply-audit") exitWith {
		"client_service_supply_audit" Call WASP_PR8_STRESS_SERVICE_SUPPLY_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE service-supply-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "wddm-artillery-audit") exitWith {
		"client_wddm_artillery_audit" Call WASP_PR8_STRESS_WDDM_ARTILLERY_AUDIT;
		["INFORMATION", "CLIENT_COMMAND_DONE wddm-artillery-audit"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "trigger-direct") exitWith {
		[] Call WASP_PR8_STRESS_DIRECT_TRIGGERS;
		"client_direct_triggers" Call WASP_PR8_STRESS_SNAPSHOT;
	};
	if (_command == "town-lifecycle") exitWith {
		[] Spawn WASP_PR8_STRESS_TOWN_LIFECYCLE;
		["INFORMATION", "CLIENT_COMMAND_DONE town-lifecycle spawned"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "town-cap-regression") exitWith {
		[] Spawn WASP_PR8_STRESS_TOWN_CAP_REGRESSION;
		["INFORMATION", "CLIENT_COMMAND_DONE town-cap-regression spawned"] Call WASP_PR8_STRESS_LOG;
	};
	if (_command == "cleanup") exitWith {
		"client_command" Call WASP_PR8_STRESS_CLEANUP_NOW;
	};
	if (_command == "profile") exitWith {
		["INFORMATION", Format ["PROFILE selected=%1 groups=%2 units=%3 vehiclePairs=%4 samples=%5 sampleDelay=%6 phaseDelay=%7 reinforcementEvery=%8 reinforcementGroups=%9 cleanup=%10",
			WASP_PR8_STRESS_PROFILE, WASP_PR8_STRESS_GROUPS_PER_SIDE, WASP_PR8_STRESS_UNITS_PER_GROUP, WASP_PR8_STRESS_VEHICLE_PAIRS, WASP_PR8_STRESS_SAMPLE_COUNT, WASP_PR8_STRESS_SAMPLE_DELAY, WASP_PR8_STRESS_PHASE_DELAY, WASP_PR8_STRESS_REINFORCEMENT_INTERVAL, WASP_PR8_STRESS_REINFORCEMENT_GROUPS, (if (isNil "WASP_PR8_STRESS_CLEANUP") then {false} else {WASP_PR8_STRESS_CLEANUP})]] Call WASP_PR8_STRESS_LOG;
	};
	["WARNING", Format ["CLIENT_COMMAND skipped unknown=%1", _command]] Call WASP_PR8_STRESS_LOG;
};

WASP_PR8_STRESS_QUEUE = [];
WASP_PR8_STRESS_QUEUE_RUNNING = false;
WASP_PR8_STRESS_QUEUE_STOP = false;
WASP_PR8_STRESS_QUEUE_ENQUEUES = 0;
WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING = false;
WASP_PR8_STRESS_CLEANUP_LOOP_DELAY = 300;
WASP_PR8_STRESS_AUTORUN_STARTED = false;

WASP_PR8_STRESS_QUEUE_SEQUENCE = {
	Private ["_name","_steps"];
	_name = _this;
	if (typeName _name == "ARRAY") then {
		_name = if (count _name > 0) then {_name select 0} else {"full"};
	};
	if (_name == "full") then {_name = "operator"};
	_steps = [];
	if (_name == "operator") then {
		_steps = [
			["cleanup", 5], ["profile", 2], ["queue-proof", 5], ["snapshot", 5], ["ai-audit", 6], ["ai-deep-sample", 20],
			["ai-delegation-audit", 6], ["factory-audit", 8], ["service-supply-audit", 8], ["wddm-artillery-audit", 10],
			["ui-audit", 6], ["gps-ui-audit", 6], ["player-experience-audit", 6], ["bughunt-audit", 6], ["perf-burst", 28],
			["vehicle-load", 10], ["spawn-wave", 10], ["spawn-heavy-wave", 12],
			["town-lifecycle", 18], ["trigger-direct", 8], ["random-bughunt-audit", 6], ["bughunt-audit", 6], ["snapshot", 0]
		];
	};
	if (_name == "ai-long") then {
		_steps = [
			["cleanup", 5], ["queue-proof", 5], ["snapshot", 5], ["ai-audit", 6], ["ai-delegation-audit", 6],
			["ai-deep-sample", 20], ["spawn-wave", 10], ["ai-audit", 6], ["spawn-heavy-wave", 12],
			["ai-delegation-audit", 6], ["ai-deep-sample", 20], ["bughunt-audit", 6], ["perf-burst", 28],
			["random-bughunt-audit", 6], ["snapshot", 0]
		];
	};
	if (_name == "systems") then {
		_steps = [
			["cleanup", 5], ["queue-proof", 5], ["factory-audit", 8], ["service-supply-audit", 8],
			["wddm-artillery-audit", 10], ["town-lifecycle", 18], ["town-cap-regression", 75], ["trigger-direct", 8],
			["bughunt-audit", 6], ["perf-burst", 28], ["factory-audit", 6],
			["service-supply-audit", 6], ["wddm-artillery-audit", 0]
		];
	};
	if (_name == "ui-long") then {
		_steps = [
			["queue-proof", 4], ["ui-audit", 4], ["gps-ui-audit", 4], ["gps-gain-toggle-audit", 4],
			["player-experience-audit", 4], ["service-supply-audit", 6], ["bughunt-audit", 6],
			["perf-burst", 28], ["ui-audit", 4], ["gps-ui-audit", 0]
		];
	};
	if (_name == "ai") then {
		_steps = [
			["queue-proof", 5], ["snapshot", 5], ["ai-audit", 6], ["ai-delegation-audit", 6], ["ai-deep-sample", 20],
			["spawn-wave", 10], ["spawn-heavy-wave", 12], ["ai-delegation-audit", 6], ["ai-deep-sample", 20], ["perf-burst", 0]
		];
	};
	if (_name == "factory") then {
		_steps = [["snapshot", 5], ["factory-audit", 8], ["perf-burst", 28], ["factory-audit", 0]];
	};
	if (_name == "service") then {
		_steps = [["service-supply-audit", 8], ["player-experience-audit", 6], ["perf-burst", 28], ["service-supply-audit", 0]];
	};
	if (_name == "wddm") then {
		_steps = [["wddm-artillery-audit", 10], ["ai-audit", 6], ["perf-burst", 28], ["wddm-artillery-audit", 0]];
	};
	if (_name == "ui") then {
		_steps = [["ui-audit", 6], ["gps-ui-audit", 6], ["player-experience-audit", 6], ["perf-burst", 28], ["gps-ui-audit", 0]];
	};
	if (_name == "load") then {
		_steps = [["vehicle-load", 10], ["spawn-heavy-wave", 12], ["bughunt-audit", 6], ["perf-burst", 28], ["ai-deep-sample", 0]];
	};
	if (_name == "gps-ui") then {
		_steps = [["ui-audit", 4], ["gps-ui-audit", 4], ["gps-gain-toggle-audit", 4], ["player-experience-audit", 4], ["gps-ui-audit", 0]];
	};
	if (_name == "bughunt") then {
		_steps = [["snapshot", 4], ["bughunt-audit", 4], ["random-bughunt-audit", 4], ["ai-delegation-audit", 4], ["factory-audit", 4], ["service-supply-audit", 4], ["wddm-artillery-audit", 4], ["random-bughunt-audit", 4], ["bughunt-audit", 0]];
	};
	if (_name == "town-regression") then {
		_steps = [["cleanup", 5], ["queue-proof", 5], ["snapshot", 5], ["town-cap-regression", 75], ["bughunt-audit", 6], ["snapshot", 0]];
	};
	_steps
};

WASP_PR8_STRESS_QUEUE_RUNNER = {
	Private ["_step","_command","_delay","_rest","_i","_payload"];
	if (WASP_PR8_STRESS_QUEUE_RUNNING) exitWith {};
	WASP_PR8_STRESS_QUEUE_RUNNING = true;
	WASP_PR8_STRESS_QUEUE_STOP = false;
	["INFORMATION", Format ["QUEUE_BEGIN pending=%1", count WASP_PR8_STRESS_QUEUE]] Call WASP_PR8_STRESS_LOG;
	while {(count WASP_PR8_STRESS_QUEUE > 0) && {!WASP_PR8_STRESS_QUEUE_STOP}} do {
		_step = WASP_PR8_STRESS_QUEUE select 0;
		_rest = [];
		if (count WASP_PR8_STRESS_QUEUE > 1) then {
			for "_i" from 1 to ((count WASP_PR8_STRESS_QUEUE) - 1) do {
				_rest set [count _rest, WASP_PR8_STRESS_QUEUE select _i];
			};
		};
		WASP_PR8_STRESS_QUEUE = _rest;
		_command = if ((typeName _step == "ARRAY") && {(count _step) > 0}) then {_step select 0} else {"unknown"};
		_delay = if ((typeName _step == "ARRAY") && {(count _step) > 1}) then {_step select 1} else {0};
		["INFORMATION", Format ["QUEUE_STEP command=%1 delay=%2 pendingAfter=%3 serverFps=%4", _command, _delay, count WASP_PR8_STRESS_QUEUE, (round (diag_fps * 10)) / 10]] Call WASP_PR8_STRESS_LOG;
		_payload = [_command, objNull, time, "serverQueue", -1, false, "serverQueue", "serverQueue", false, -1, 0, "serverQueue"];
		_payload Call WASP_PR8_STRESS_HANDLE_COMMAND;
		if (_delay > 0) then {sleep _delay};
	};
	["INFORMATION", Format ["QUEUE_END stopped=%1 pending=%2", WASP_PR8_STRESS_QUEUE_STOP, count WASP_PR8_STRESS_QUEUE]] Call WASP_PR8_STRESS_LOG;
	WASP_PR8_STRESS_QUEUE_RUNNING = false;
	WASP_PR8_STRESS_QUEUE_STOP = false;
};

WASP_PR8_STRESS_QUEUE_ADD = {
	Private ["_name","_steps","_step","_before"];
	_name = _this;
	_steps = _name Call WASP_PR8_STRESS_QUEUE_SEQUENCE;
	if (count _steps == 0) exitWith {
		["WARNING", Format ["QUEUE_ENQUEUE skipped unknownSequence=%1", _name]] Call WASP_PR8_STRESS_LOG;
	};
	if ((WASP_PR8_STRESS_QUEUE_RUNNING || {(count WASP_PR8_STRESS_QUEUE) > 0}) && {!WASP_PR8_STRESS_QUEUE_STOP}) exitWith {
		["WARNING", Format ["QUEUE_ENQUEUE skipped busy sequence=%1 pending=%2 running=%3", _name, count WASP_PR8_STRESS_QUEUE, WASP_PR8_STRESS_QUEUE_RUNNING]] Call WASP_PR8_STRESS_LOG;
	};
	_before = count WASP_PR8_STRESS_QUEUE;
	WASP_PR8_STRESS_QUEUE_ENQUEUES = WASP_PR8_STRESS_QUEUE_ENQUEUES + 1;
	{
		_step = _x;
		WASP_PR8_STRESS_QUEUE set [count WASP_PR8_STRESS_QUEUE, _step];
	} forEach _steps;
	["INFORMATION", Format ["QUEUE_ENQUEUE sequence=%1 added=%2 before=%3 pending=%4 running=%5 totalEnqueues=%6", _name, count _steps, _before, count WASP_PR8_STRESS_QUEUE, WASP_PR8_STRESS_QUEUE_RUNNING, WASP_PR8_STRESS_QUEUE_ENQUEUES]] Call WASP_PR8_STRESS_LOG;
	if (!WASP_PR8_STRESS_QUEUE_RUNNING) then {[] Spawn WASP_PR8_STRESS_QUEUE_RUNNER};
};

WASP_PR8_STRESS_AUTORUN_START = {
	Private ["_enabled","_sequence","_delay"];
	_enabled = if (isNil "WASP_PR8_STRESS_AUTORUN_ENABLED") then {false} else {WASP_PR8_STRESS_AUTORUN_ENABLED};
	if (!_enabled) exitWith {
		["INFORMATION", "AUTORUN skipped enabled=false"] Call WASP_PR8_STRESS_LOG;
	};
	if (WASP_PR8_STRESS_AUTORUN_STARTED) exitWith {
		["INFORMATION", "AUTORUN skipped alreadyStarted=true"] Call WASP_PR8_STRESS_LOG;
	};
	WASP_PR8_STRESS_AUTORUN_STARTED = true;
	_sequence = if (isNil "WASP_PR8_STRESS_AUTORUN_SEQUENCE") then {"operator"} else {WASP_PR8_STRESS_AUTORUN_SEQUENCE};
	_delay = if (isNil "WASP_PR8_STRESS_AUTORUN_DELAY") then {45} else {WASP_PR8_STRESS_AUTORUN_DELAY};
	[_sequence, _delay] Spawn {
		Private ["_sequence","_delay"];
		_sequence = _this select 0;
		_delay = _this select 1;
		["INFORMATION", Format ["AUTORUN_WAIT sequence=%1 delay=%2", _sequence, _delay]] Call WASP_PR8_STRESS_LOG;
		if (_delay > 0) then {sleep _delay};
		["INFORMATION", Format ["AUTORUN_TRIGGER sequence=%1", _sequence]] Call WASP_PR8_STRESS_LOG;
		_sequence Call WASP_PR8_STRESS_QUEUE_ADD;
	};
};

WASP_PR8_STRESS_CLEANUP_LOOP_SET = {
	Private ["_enable"];
	_enable = _this;
	if (_enable) then {
		if (WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING) exitWith {
			["INFORMATION", Format ["CLEANUP_LOOP alreadyRunning delay=%1", WASP_PR8_STRESS_CLEANUP_LOOP_DELAY]] Call WASP_PR8_STRESS_LOG;
		};
		WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING = true;
		["INFORMATION", Format ["CLEANUP_LOOP start delay=%1", WASP_PR8_STRESS_CLEANUP_LOOP_DELAY]] Call WASP_PR8_STRESS_LOG;
		[] Spawn {
			while {WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING} do {
				sleep WASP_PR8_STRESS_CLEANUP_LOOP_DELAY;
				if (WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING) then {"cleanup_loop" Call WASP_PR8_STRESS_CLEANUP_NOW};
			};
			["INFORMATION", "CLEANUP_LOOP stopped"] Call WASP_PR8_STRESS_LOG;
		};
	} else {
		WASP_PR8_STRESS_CLEANUP_LOOP_RUNNING = false;
		["INFORMATION", "CLEANUP_LOOP stop requested"] Call WASP_PR8_STRESS_LOG;
	};
};

WASP_PR8_STRESS_WAIT_FOR_HC = {
	Private ["_elapsed","_ids","_required","_timeout"];
	_required = if (isNil "WASP_PR8_STRESS_REQUIRE_HC") then {false} else {WASP_PR8_STRESS_REQUIRE_HC};
	_timeout = if (isNil "WASP_PR8_STRESS_HC_WAIT") then {300} else {WASP_PR8_STRESS_HC_WAIT};
	if (!_required) exitWith {
		["INFORMATION", "HC_WAIT skipped required=false"] Call WASP_PR8_STRESS_LOG;
	};
	_elapsed = 0;
	_ids = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	["INITIALIZATION", Format ["HC_WAIT_BEGIN timeout=%1 currentIds=%2", _timeout, _ids]] Call WASP_PR8_STRESS_LOG;
	while {((count _ids) == 0) && {_elapsed < _timeout}} do {
		sleep 5;
		_elapsed = _elapsed + 5;
		_ids = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	};
	if ((count _ids) > 0) then {
		["INITIALIZATION", Format ["HC_READY ids=%1 waited=%2", _ids, _elapsed]] Call WASP_PR8_STRESS_LOG;
	} else {
		["WARNING", Format ["HC_WAIT_TIMEOUT waited=%1 ids=%2 continuingWithoutHc=true", _elapsed, _ids]] Call WASP_PR8_STRESS_LOG;
	};
};

WASP_PR8_STRESS_CLIENT_COMMAND = [];
"WASP_PR8_STRESS_CLIENT_COMMAND" addPublicVariableEventHandler {(_this select 1) Call WASP_PR8_STRESS_HANDLE_COMMAND};

["INITIALIZATION", "=== harness online - PR8 stress mission ==="] Call WASP_PR8_STRESS_LOG;
[] Call WASP_PR8_STRESS_APPLY_PROFILE;

_gates = [
	["mission-parameters", {(!isNil "WFBE_Parameters_Ready") && {WFBE_Parameters_Ready}}],
	["common", {(!isNil "commonInitComplete") && {commonInitComplete}}],
	["towns", {(!isNil "townInit") && {townInit}}],
	["server", {(!isNil "serverInitFull") && {serverInitFull}}]
];

_budget = 300;
_elapsed = 0;
_reached = [];
_hung = "";

{
	if (_hung == "") then {
		Private ["_label","_condition"];
		_label = _x select 0;
		_condition = _x select 1;
		while {!(call _condition) && (_elapsed < _budget)} do {sleep 2; _elapsed = _elapsed + 2};
		if (call _condition) then {
			_reached set [count _reached, _label];
			["INITIALIZATION", Format ["gate reached: %1 (+%2s)", _label, _elapsed]] Call WASP_PR8_STRESS_LOG;
		} else {
			_hung = _label;
			["WARNING", Format ["INIT HANG before gate %1 reached=%2", _label, _reached]] Call WASP_PR8_STRESS_LOG;
		};
	};
} forEach _gates;

if (_hung != "") exitWith {
	["WARNING", Format ["RESULT FAIL initHang=%1 reached=%2", _hung, _reached]] Call WASP_PR8_STRESS_LOG;
};

missionNamespace setVariable ["PerformanceAuditEnabled", true];
missionNamespace setVariable ["PerformanceAuditFlushInterval", 30];
missionNamespace setVariable ["PerformanceAuditAnchorVersion", "pr8-stress-harness"];

_requiredVars = [
	"WFBE_C_AI_DELEGATION",
	"WFBE_HEADLESSCLIENTS_ID",
	"WFBE_POSITION_ANCHOR_NAMES",
	"WFBE_POSITION_TEMPLATE_MAP",
	"WFBE_C_SUPPLY_HELI_TYPES",
	"WFBE_C_SUPPLY_VEHICLE_TYPES",
	"WFBE_C_SUPPLY_HELI_LOAD_TIME",
	"WFBE_C_SUPPLY_HELI_UNLOAD_TIME",
	"WFBE_C_SUPPLY_INTERDICTION_CUT",
	"WFBE_C_MODULE_WFBE_EASA",
	"WFBE_EASA_Vehicles",
	"WFBE_EASA_Loadouts",
	"WFBE_C_BASE_DEFENSE_MAX_AI",
	"WFBE_C_BASE_DEFENSE_MANNING_RANGE",
	"WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW"
];
_requiredFuncs = [
	"WFBE_CO_FNC_LogContent",
	"WFBE_CO_FNC_GetSideHQ",
	"WFBE_CO_FNC_GetSideLogic",
	"WFBE_CO_FNC_GetSideStructures",
	"WFBE_CO_FNC_OnUnitKilled",
	"WFBE_CO_FNC_ChangeTeamFunds",
	"WFBE_SE_FNC_HandleEmptyVehicle",
	"WFBE_SE_FNC_AwardScorePlayer",
	"WFBE_SE_FNC_ProcessUpgrade",
	"WFBE_SE_FNC_SupplyMissionTimerForTown",
	"Server_ConstructPosition",
	"ConstructDefense",
	"CreateDefenseTemplate",
	"HandleDefense",
	"WFBE_SE_FNC_GetTownGroups",
	"WFBE_SE_FNC_GetTownGroupsDefender",
	"WFBE_SE_FNC_ManageTownDefenses",
	"WFBE_SE_FNC_OperateTownDefensesUnits",
	"WFBE_SE_FNC_SetCampsToSide",
	"ChangeSideSupply",
	"GetSideSupply",
	"GetAICommanderFunds"
];
_missingVars = _requiredVars Call WASP_PR8_STRESS_MISSING;
_missingFuncs = _requiredFuncs Call WASP_PR8_STRESS_MISSING;
["INFORMATION", Format ["LOGICCHECK missingVars=%1 missingFuncs=%2", _missingVars, _missingFuncs]] Call WASP_PR8_STRESS_LOG;
[] Call WASP_PR8_STRESS_WAIT_FOR_HC;
[] Call WASP_PR8_STRESS_AUTORUN_START;

_sides = if (isNil "WFBE_PRESENTSIDES") then {[west,east]} else {WFBE_PRESENTSIDES};
WASP_PR8_STRESS_SIDES = _sides;
_westPos = [west, [4700, 2500, 0]] Call WASP_PR8_STRESS_SAFE_POS;
_eastPos = [east, [5200, 2500, 0]] Call WASP_PR8_STRESS_SAFE_POS;
_resPos = [((_westPos select 0) + 300), ((_westPos select 1) + 300), 0];

_westClass = ["WFBE_WESTSOLDIER", "USMC_Soldier"] Call WASP_PR8_STRESS_GETVAR;
_eastClass = ["WFBE_EASTSOLDIER", "RU_Soldier"] Call WASP_PR8_STRESS_GETVAR;
_resClass = ["WFBE_GUERSOLDIER", "GUE_Soldier_1"] Call WASP_PR8_STRESS_GETVAR;
_groupsPerSide = if (isNil "WASP_PR8_STRESS_GROUPS_PER_SIDE") then {8} else {WASP_PR8_STRESS_GROUPS_PER_SIDE};
_unitsPerGroup = if (isNil "WASP_PR8_STRESS_UNITS_PER_GROUP") then {5} else {WASP_PR8_STRESS_UNITS_PER_GROUP};
_vehiclePairs = if (isNil "WASP_PR8_STRESS_VEHICLE_PAIRS") then {6} else {WASP_PR8_STRESS_VEHICLE_PAIRS};
_sampleCount = if (isNil "WASP_PR8_STRESS_SAMPLE_COUNT") then {24} else {WASP_PR8_STRESS_SAMPLE_COUNT};
_sampleDelay = if (isNil "WASP_PR8_STRESS_SAMPLE_DELAY") then {20} else {WASP_PR8_STRESS_SAMPLE_DELAY};
_phaseDelay = if (isNil "WASP_PR8_STRESS_PHASE_DELAY") then {10} else {WASP_PR8_STRESS_PHASE_DELAY};
_reinforcementInterval = if (isNil "WASP_PR8_STRESS_REINFORCEMENT_INTERVAL") then {6} else {WASP_PR8_STRESS_REINFORCEMENT_INTERVAL};
_reinforcementGroups = if (isNil "WASP_PR8_STRESS_REINFORCEMENT_GROUPS") then {2} else {WASP_PR8_STRESS_REINFORCEMENT_GROUPS};
WASP_PR8_STRESS_WESTPOS = _westPos;
WASP_PR8_STRESS_EASTPOS = _eastPos;
WASP_PR8_STRESS_WESTCLASS = _westClass;
WASP_PR8_STRESS_EASTCLASS = _eastClass;

["INFORMATION", Format ["PROFILE selected=%1 groups=%2 units=%3 vehiclePairs=%4 samples=%5 sampleDelay=%6 phaseDelay=%7 reinforcementEvery=%8 reinforcementGroups=%9 cleanup=%10",
	WASP_PR8_STRESS_PROFILE, _groupsPerSide, _unitsPerGroup, _vehiclePairs, _sampleCount, _sampleDelay, _phaseDelay, _reinforcementInterval, _reinforcementGroups, (if (isNil "WASP_PR8_STRESS_CLEANUP") then {false} else {WASP_PR8_STRESS_CLEANUP})]] Call WASP_PR8_STRESS_LOG;

["00_baseline", _phaseDelay] Call WASP_PR8_STRESS_PHASE;

["INFORMATION", Format ["ACTION_MATRIX hcDelegation=%1 townAI=timedSyntheticWaves townLifecycle=prePressureCapPostRestore townFSM=server_town/server_town_ai/server_town_camp wddm=probeOrBuild hqWalls=probe commanderArtillery=probe supplyHeli=loadedVehicleProbe supplyInterdiction=directTrigger killEHProbe easa=presenceProbe service=presenceProbe killRewards=directDelayedAttribution economy=directSupplyAndFunds icbm=confirmationSmokeProbe buyAutoCrew=staticSmoke autoManning=defenseProbe nonNoise=rpt-error-grep timedSpawns=enabled phaseDelay=%2 reinforcementEvery=%3",
	"WFBE_C_AI_DELEGATION" Call WASP_PR8_STRESS_GETNUM, _phaseDelay, _reinforcementInterval]] Call WASP_PR8_STRESS_LOG;

"auto_baseline_factory" Call WASP_PR8_STRESS_FACTORY_AUDIT;
"auto_baseline_service_supply" Call WASP_PR8_STRESS_SERVICE_SUPPLY_AUDIT;
"auto_baseline_wddm_artillery" Call WASP_PR8_STRESS_WDDM_ARTILLERY_AUDIT;

_westAI = [west, _westPos, _groupsPerSide, _unitsPerGroup, _westClass, _eastPos] Call WASP_PR8_STRESS_SPAWN_AI;
_eastAI = [east, _eastPos, _groupsPerSide, _unitsPerGroup, _eastClass, _westPos] Call WASP_PR8_STRESS_SPAWN_AI;
_resAI = [resistance, _resPos, (_groupsPerSide / 2), _unitsPerGroup, _resClass, _westPos] Call WASP_PR8_STRESS_SPAWN_AI;
["INFORMATION", Format ["SPAWN ai west=%1 east=%2 resistance=%3 groupsTracked=%4", _westAI, _eastAI, _resAI, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
["01_initial_ai_wave", _phaseDelay] Call WASP_PR8_STRESS_PHASE;

[] Spawn WASP_PR8_STRESS_TOWN_LIFECYCLE;
["01b_town_lifecycle", _phaseDelay + (if (isNil "WASP_PR8_STRESS_TOWN_WAIT") then {8} else {WASP_PR8_STRESS_TOWN_WAIT})] Call WASP_PR8_STRESS_PHASE;

_supplyHeliTypes = ["WFBE_C_SUPPLY_HELI_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
_supplyVehicleTypes = ["WFBE_C_SUPPLY_VEHICLE_TYPES", []] Call WASP_PR8_STRESS_GETVAR;
_heliType = if ((typeName _supplyHeliTypes == "ARRAY") && {(count _supplyHeliTypes) > 0}) then {_supplyHeliTypes select 0} else {"MH60S"};
_truckType = if ((typeName _supplyVehicleTypes == "ARRAY") && {(count _supplyVehicleTypes) > 0}) then {_supplyVehicleTypes select 0} else {"WarfareSupplyTruck_USMC"};
for "_i" from 1 to _vehiclePairs do {
	Private ["_h","_t"];
	_h = [_heliType, [(_westPos select 0) + 40 + (_i * 14), (_westPos select 1) + 90, 0], 90] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
	if (!isNull _h) then {
		_h setVariable ["SupplyByHeli", true, true];
		_h setVariable ["SupplyAmount", 250 + (_i * 25), true];
	};
	_t = [_truckType, [(_eastPos select 0) - 40 - (_i * 14), (_eastPos select 1) - 90, 0], 270] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
	if (!isNull _t) then {
		_t setVariable ["SupplyByHeli", false, true];
		_t setVariable ["SupplyAmount", 150 + (_i * 15), true];
	};
};
["INFORMATION", Format ["SPAWN supplyVehicles heliType=%1 truckType=%2 pairs=%3 objectsTracked=%4", _heliType, _truckType, _vehiclePairs, count WASP_PR8_STRESS_OBJECTS]] Call WASP_PR8_STRESS_LOG;
["02_supply_vehicle_load", _phaseDelay] Call WASP_PR8_STRESS_PHASE;

_anchors = ["WFBE_POSITION_ANCHOR_NAMES", []] Call WASP_PR8_STRESS_GETVAR;
_wddmResult = "skipped";
if ((typeName _anchors == "ARRAY") && {(count _anchors) > 0} && {!isNil "Server_ConstructPosition"} && {!isNil "WFBE_CO_FNC_GetSideLogic"}) then {
	Private ["_logic","_areas","_anchor","_area","_buildPos"];
	_logic = west Call WFBE_CO_FNC_GetSideLogic;
	_areas = if (!isNull _logic) then {_logic getVariable ["wfbe_basearea", []]} else {[]};
	if ((typeName _areas == "ARRAY") && {(count _areas) > 0}) then {
		_anchor = _anchors select 0;
		_area = _areas select 0;
		_buildPos = getPos _area;
		[west, _anchor, [(_buildPos select 0) + 35, (_buildPos select 1), 0], 0, true] Spawn Server_ConstructPosition;
		_wddmResult = Format ["requested anchor=%1 baseAreas=%2", _anchor, count _areas];
	} else {
		_wddmResult = "noBaseAreaYet";
	};
};
["INFORMATION", Format ["PROBE wddm result=%1 anchors=%2 mappings=%3 autoManningRange=%4 maxAI=%5", _wddmResult, (if (typeName _anchors == "ARRAY") then {count _anchors} else {-1}), ("WFBE_POSITION_TEMPLATE_MAP" Call WASP_PR8_STRESS_GETNUM), "WFBE_C_BASE_DEFENSE_MANNING_RANGE" Call WASP_PR8_STRESS_GETNUM, "WFBE_C_BASE_DEFENSE_MAX_AI" Call WASP_PR8_STRESS_GETNUM]] Call WASP_PR8_STRESS_LOG;
["03_build_probe", _phaseDelay] Call WASP_PR8_STRESS_PHASE;

{
	Private ["_side","_logic","_hq","_walls","_structs","_arty","_funds","_supply"];
	_side = _x;
	_logic = _side Call WFBE_CO_FNC_GetSideLogic;
	_hq = _side Call WFBE_CO_FNC_GetSideHQ;
	_walls = if (!isNull _hq) then {_hq getVariable ["wfbe_hq_walls", _hq getVariable ["WFBE_Walls", []]]} else {[]};
	_structs = if (!isNull _logic) then {_logic getVariable ["wfbe_structures", []]} else {[]};
	_arty = {(_x getVariable ["WFBE_CommanderArtillery", false]) && {alive _x}} count vehicles;
	_funds = if (!isNil "GetAICommanderFunds") then {_side Call GetAICommanderFunds} else {-1};
	_supply = if (!isNil "GetSideSupply") then {_side Call GetSideSupply} else {[Format ["wfbe_supply_%1", str _side], -1] Call WASP_PR8_STRESS_GETVAR};
	["INFORMATION", Format ["PROBE side=%1 hq=%2 hqWalls=%3 structures=%4 commanderArtillery=%5 aiCommanderFunds=%6 sideSupply=%7", _side Call WASP_PR8_STRESS_SIDETEXT, _hq, (if (typeName _walls == "ARRAY") then {count _walls} else {-1}), (if (typeName _structs == "ARRAY") then {count _structs} else {-1}), _arty, _funds, _supply]] Call WASP_PR8_STRESS_LOG;
} forEach _sides;

_easaVehicles = ["WFBE_EASA_Vehicles", []] Call WASP_PR8_STRESS_GETVAR;
_easaLoadouts = ["WFBE_EASA_Loadouts", []] Call WASP_PR8_STRESS_GETVAR;
["INFORMATION", Format ["PROBE easa module=%1 vehicles=%2 loadouts=%3 serviceRepairTruckFuncs=%4/%5", "WFBE_C_MODULE_WFBE_EASA" Call WASP_PR8_STRESS_GETNUM, (if (typeName _easaVehicles == "ARRAY") then {count _easaVehicles} else {-1}), (if (typeName _easaLoadouts == "ARRAY") then {count _easaLoadouts} else {-1}), !(isNil "WFBE_CL_FNC_CanUseRepairPointEASA"), !(isNil "WFBE_CL_FNC_GetRepairTruckServicePoints")]] Call WASP_PR8_STRESS_LOG;

_killerGrp = createGroup west;
_killerGrp Call WASP_PR8_STRESS_TRACK_GROUP;
_killerGrp setVariable ["wfbe_funds", 0, true];
_killer = _killerGrp createUnit [_westClass, [(_westPos select 0) + 10, (_westPos select 1) + 10, 0], [], 0, "FORM"];
_target = ["BMP2_INS", [(_westPos select 0) + 80, (_westPos select 1) + 10, 0], 0] Call WASP_PR8_STRESS_SPAWN_VEHICLE;
if (!isNull _killer) then {_killer Call WASP_PR8_STRESS_TRACK_OBJECT};
if (!isNull _target) then {
	Private ["_serverKilledHandler"];
	_target setVariable ["wfbe_lasthitby", _killer, true];
	_target setVariable ["wfbe_lasthittime", time, true];
	_serverKilledHandler = Compile preprocessFileLineNumbers "Server\PVFunctions\RequestOnUnitKilled.sqf";
	[_target, objNull, (east Call GetSideID)] Call _serverKilledHandler;
	["INFORMATION", Format ["PROBE delayedKill target=%1 lastHitBy=%2 window=%3", _target, _killer, "WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW" Call WASP_PR8_STRESS_GETNUM]] Call WASP_PR8_STRESS_LOG;
};

[] Call WASP_PR8_STRESS_DIRECT_TRIGGERS;
["04_direct_triggers", _phaseDelay] Call WASP_PR8_STRESS_PHASE;

["INFORMATION", Format ["NOISECHECK grep='WASP-PR8-STRESS' expectedErrorLines=0 expectedWarningsOnlyForSkippedPrereqs=1 objectsTracked=%1 groupsTracked=%2", count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
["INITIALIZATION", "=== performance window begins - grep '[WASP-PR8-STRESS] PERF' ==="] Call WASP_PR8_STRESS_LOG;

_i = 0;
_min = 999;
_max = -1;
_sum = 0;
while {_i < _sampleCount} do {
	_i = _i + 1;
	if ((_reinforcementInterval > 0) && {(_i % _reinforcementInterval) == 0}) then {
		Private ["_rw","_re"];
		_rw = [west, [(_westPos select 0) + 200, (_westPos select 1) - 120, 0], _reinforcementGroups, _unitsPerGroup, _westClass, _eastPos] Call WASP_PR8_STRESS_SPAWN_AI;
		_re = [east, [(_eastPos select 0) - 200, (_eastPos select 1) + 120, 0], _reinforcementGroups, _unitsPerGroup, _eastClass, _westPos] Call WASP_PR8_STRESS_SPAWN_AI;
		["INFORMATION", Format ["SPAWN reinforcement sample=%1 west=%2 east=%3 groupsTracked=%4", _i, _rw, _re, count WASP_PR8_STRESS_GROUPS]] Call WASP_PR8_STRESS_LOG;
		Format ["05_reinforcement_%1", _i] Call WASP_PR8_STRESS_SNAPSHOT;
	};
	_fps = diag_fps;
	_aiCount = {!isPlayer _x} count allUnits;
	if (_aiCount > WASP_PR8_STRESS_MAX_AI) then {WASP_PR8_STRESS_MAX_AI = _aiCount};
	if ((count allUnits) > WASP_PR8_STRESS_MAX_UNITS) then {WASP_PR8_STRESS_MAX_UNITS = count allUnits};
	if ((count vehicles) > WASP_PR8_STRESS_MAX_VEHICLES) then {WASP_PR8_STRESS_MAX_VEHICLES = count vehicles};
	if ((count allGroups) > WASP_PR8_STRESS_MAX_GROUPS) then {WASP_PR8_STRESS_MAX_GROUPS = count allGroups};
	if ((count allDead) > WASP_PR8_STRESS_MAX_DEAD) then {WASP_PR8_STRESS_MAX_DEAD = count allDead};
	if (_fps < _min) then {_min = _fps};
	if (_fps > _max) then {_max = _fps};
	_sum = _sum + _fps;
	["INFORMATION", Format ["PERF #%1 t=%2s fps=%3 units=%4 vehicles=%5 groups=%6 dead=%7 stressObjects=%8 stressGroups=%9 hcIds=%10",
		_i, round time, (round (_fps * 10)) / 10, count allUnits, count vehicles, count allGroups, count allDead, count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS, ["WFBE_HEADLESSCLIENTS_ID", []] Call WASP_PR8_STRESS_GETVAR]] Call WASP_PR8_STRESS_LOG;
	sleep _sampleDelay;
};

_avg = if (_sampleCount > 0) then {(round ((_sum / _sampleCount) * 10)) / 10} else {-1};
"final_perf_window" Call WASP_PR8_STRESS_AI_BEHAVIOR;
"final_ai_delegation" Call WASP_PR8_STRESS_AI_DELEGATION_AUDIT;
"final_bughunt" Call WASP_PR8_STRESS_BUGHUNT_AUDIT;
"final_random_bughunt" Call WASP_PR8_STRESS_RANDOM_BUGHUNT_AUDIT;
["final_perf_burst", 6, 2] Call WASP_PR8_STRESS_PERF_BURST;
if (WASP_PR8_STRESS_QUEUE_ENQUEUES == 0) then {
	["WARNING", "QUEUE_NOT_TRIGGERED totalEnqueues=0 reason=no-client-or-scroll-action; use client auto probes or queue actions for full UI/UX coverage"] Call WASP_PR8_STRESS_LOG;
};
["INITIALIZATION", Format ["EVIDENCE {""schema"":""wasp-pr8-stress-v5"",""run"":""%15"",""perfAuditSid"":""%16"",""gatesReached"":%1,""phases"":6,""directTriggers"":%12,""townLifecycle"":%14,""reinforcementInterval"":%13,""aiBehavior"":true,""aiSpawned"":[%2,%3,%4],""vehiclePairs"":%5,""samples"":%6,""fpsMinAvgMax"":[%7,%8,%9],""objectsTracked"":%10,""groupsTracked"":%11,""maxAiUnitsVehiclesGroupsDead"":[%17,%18,%19,%20,%21]}",
	_reached, _westAI, _eastAI, _resAI, _vehiclePairs, _sampleCount, (round (_min * 10)) / 10, _avg, (round (_max * 10)) / 10, count WASP_PR8_STRESS_OBJECTS, count WASP_PR8_STRESS_GROUPS, (if (isNil "WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS") then {true} else {WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS}), _reinforcementInterval, (if (isNil "WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED") then {true} else {WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED}), WASP_PR8_STRESS_RUN_ID, (if (isNil "PerformanceAuditSessionId") then {"none"} else {PerformanceAuditSessionId}), WASP_PR8_STRESS_MAX_AI, WASP_PR8_STRESS_MAX_UNITS, WASP_PR8_STRESS_MAX_VEHICLES, WASP_PR8_STRESS_MAX_GROUPS, WASP_PR8_STRESS_MAX_DEAD]] Call WASP_PR8_STRESS_LOG;

if (!isNil "WASP_PR8_STRESS_CLEANUP" && {WASP_PR8_STRESS_CLEANUP}) then {
	"final_config" Call WASP_PR8_STRESS_CLEANUP_NOW;
};

["INITIALIZATION", "=== harness window complete ==="] Call WASP_PR8_STRESS_LOG;
