/*
	Create units in towns.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_built", "_builtveh", "_crews", "_groupCountCiv", "_groupCountEast", "_groupCountGuer", "_groupCountLogic", "_groupCountSide", "_groupCountWest", "_groupCountUnknown", "_groupMachine", "_groupSide", "_groups", "_i", "_lock", "_position", "_positions", "_retVal", "_side", "_sideID", "_team", "_teams", "_town", "_town_teams", "_town_vehicles", "_units", "_vehicles"];

_town = _this select 0;
_side = _this select 1;
_groups = _this select 2;
_positions = _this select 3;
_teams = _this select 4;
_sideID = (_side) call WFBE_CO_FNC_GetSideID;

_built = 0;
_builtveh = 0;
_town_teams = [];
_town_vehicles = [];

//--- Task 34: resistance vehicles are always unlocked when the resistance side is inactive (WFBE_C_TOWNS_DEFENDER == 0).
//--- When resistance IS active the existing WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER parameter governs the lock state
//--- (default=0 in Parameters.hpp, meaning unlocked; set to 1 in the lobby to require lockpick).
_lock = if (_side == WFBE_DEFENDER && (missionNamespace getVariable ["WFBE_C_TOWNS_DEFENDER", 1]) == 0) then {
	false  //--- Resistance AI disabled: nothing to fight — unlock vehicles for everyone.
} else {
	if ((missionNamespace getVariable "WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER") == 0 && _side == WFBE_DEFENDER) then {false} else {true}
};

for '_i' from 0 to count(_groups)-1 do {
	_position = _positions select _i;
	_team = _teams select _i;
	
	["INFORMATION", Format["Common_CreateTownUnits.sqf: Town [%1] [%2] will create a team template %3 at %4", _town, _side, _groups select _i,_position]] Call WFBE_CO_FNC_LogContent;
	
	_retVal = [_groups select _i, _position, _side, _lock, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
	_units = _retVal select 0;
	_vehicles = _retVal select 1;
	// Marty: Track the actual group returned by CreateTeam, because delegated HC creation may replace grpNull locally.
	_team = _retVal select 2;
	_crews = if (count _retVal > 3) then {_retVal select 3} else {[]};

	//--- Defender classification: tag everything this town spawned. PUBLIC tag (3rd arg true) -
	//--- town AI may be created on an HC while the activation scan that must ignore these runs
	//--- on the server, so a local-only tag would be invisible where it matters.
	{if (!isNull _x) then {_x setVariable ["WFBE_IsTownDefenderAI", true, true]}} forEach (_units + _crews + _vehicles);
	_built = _built + count _units;
	_builtveh = _builtveh + (count _vehicles);

	// Marty: Skip tracking/patrol work when no valid group could be created on this machine.
	if (isNull _team || {((count _units) + (count _vehicles)) == 0}) then {
		["WARNING", Format["Common_CreateTownUnits.sqf: Town [%1] [%2] skipped patrol setup for template %3 because no valid team assets were created.", _town, _side, _groups select _i]] Call WFBE_CO_FNC_LogContent;
	} else {
		_team setVariable ["WFBE_TownAI_Town", _town, false];
		_team setVariable ["WFBE_TownAI_Side", _side, false];
		_team setVariable ["WFBE_TownAI_Group", true, false];
		[_town, _team, _sideID] execVM "Server\FSM\server_town_patrol.sqf";
		[_team, 400, _position] spawn WFBE_CO_FNC_RevealArea;
		[_town_teams, _team] call WFBE_CO_FNC_ArrayPush;
		_team allowFleeing 0; //--- Make the units brave.
	};

	{
		[_town_vehicles, _x] call WFBE_CO_FNC_ArrayPush;
		if (isServer) then {
			[_x] spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_x setVariable ["WFBE_Taxi_Prohib", true];
		};
	} forEach _vehicles;
};

if (_built > 0) then {[str _side,'UnitsCreated',_built] call UpdateStatistics};
if (_builtveh > 0) then {[str _side,'VehiclesCreated',_builtveh] call UpdateStatistics};

// Marty: When a town activates empty, print the machine-side group counts near the failure.
if ((_built + _builtveh) == 0) then {
	_groupCountWest = 0;
	_groupCountEast = 0;
	_groupCountGuer = 0;
	_groupCountCiv = 0;
	_groupCountLogic = 0;
	_groupCountUnknown = 0;
	{
		_groupSide = side _x;
		switch (_groupSide) do {
			case west: {_groupCountWest = _groupCountWest + 1};
			case east: {_groupCountEast = _groupCountEast + 1};
			case resistance: {_groupCountGuer = _groupCountGuer + 1};
			case civilian: {_groupCountCiv = _groupCountCiv + 1};
			case sideLogic: {_groupCountLogic = _groupCountLogic + 1};
			default {_groupCountUnknown = _groupCountUnknown + 1};
		};
	} forEach allGroups;
	_groupCountSide = switch (_side) do {
		case west: {_groupCountWest};
		case east: {_groupCountEast};
		case resistance: {_groupCountGuer};
		case civilian: {_groupCountCiv};
		case sideLogic: {_groupCountLogic};
		default {_groupCountUnknown};
	};
	_groupMachine = if (isServer) then {"SERVER"} else {if (hasInterface) then {"CLIENT"} else {"HC"}};
	["WARNING", Format ["TOWN_GROUP_COUNT town_empty machine:%1 town:%2 side:%3 sideGroups:%4 total:%5 west:%6 east:%7 guer:%8 civ:%9 logic:%10 unknown:%11", _groupMachine, _town getVariable "name", _side, _groupCountSide, count allGroups, _groupCountWest, _groupCountEast, _groupCountGuer, _groupCountCiv, _groupCountLogic, _groupCountUnknown]] Call WFBE_CO_FNC_LogContent;
};

["INFORMATION", Format["Common_CreateTownUnits.sqf: Town [%1] held by [%2] was activated witha total of [%3] units.", _town, _side, _built + _builtveh]] Call WFBE_CO_FNC_LogContent;

[_town_teams, _town_vehicles]
