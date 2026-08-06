/*
	Order newly spawned AI units toward the team leader's active destination.
	Parameters:
		- Team.
		- Spawned units array.
*/

Private ["_currentWaypoint","_destinationData","_destinationMode","_destinationPosition","_destinationSource","_leader","_member","_orderedUnits","_orderedVehicles","_spawnedUnits","_storedMapOrderGroup","_storedMapOrderPosition","_team","_unit","_vehicle","_waypointCount"];

if (typeName _this != "ARRAY" || {count _this < 2}) exitWith {false};
_team = _this select 0;
_spawnedUnits = _this select 1;

if (!(missionNamespace getVariable ["AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT", false])) exitWith {
	false
};
if (isNull _team) exitWith {
	false
};
if (typeName _spawnedUnits != "ARRAY") exitWith {
	false
};

_leader = leader _team;
if (isNull _leader) exitWith {false};
_destinationPosition = [];
_destinationSource = "none";

_storedMapOrderGroup = missionNamespace getVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", grpNull];
_storedMapOrderPosition = missionNamespace getVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", []];

if (!isNull _storedMapOrderGroup && {_storedMapOrderGroup == _team} && {count _storedMapOrderPosition > 1}) then {
	if (_leader distance _storedMapOrderPosition > 25) then {
		_destinationPosition = _storedMapOrderPosition;
		_destinationSource = "stored shift-click map order";
	} else {
		missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", []];
		missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", grpNull];
		missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_TIME", -5000];
	};
};

//--- r79: completed / residual A2 waypoints report currentWaypoint past the last index or return
//--- map-origin [0,0,*]. Treat origin as "no destination" (parity with Common_GetTeamMarkerDestPos).
_waypointCount = count (waypoints _team);
_currentWaypoint = currentWaypoint _team;
if (count _destinationPosition == 0 && {_waypointCount > 0} && {_currentWaypoint >= 0} && {_currentWaypoint < _waypointCount}) then {
	_destinationPosition = waypointPosition [_team, _currentWaypoint];
	if (typeName _destinationPosition != "ARRAY" || {count _destinationPosition < 2}) then {
		_destinationPosition = [];
	} else {
		if (((_destinationPosition select 0) == 0) && {(_destinationPosition select 1) == 0}) then {
			_destinationPosition = [];
		} else {
			_destinationSource = Format ["group waypoint [%1/%2]", _currentWaypoint, _waypointCount];
		};
	};
};

if (count _destinationPosition == 0) then {
	{
		_member = _x;
		if (!isNull _member && {alive _member} && {_member != _leader}) then {
			_destinationData = expectedDestination _member;
			//--- r79: short/empty expectedDestination used to throw on select 1 and abort the whole send.
			if (typeName _destinationData == "ARRAY" && {count _destinationData > 1}) then {
				_destinationMode = _destinationData select 1;
				if (_destinationMode != "DoNotPlan") exitWith {
					_destinationPosition = _destinationData select 0;
					_destinationSource = Format ["member expectedDestination [%1] from %2", _destinationMode, _member];
				};
			};
		};
	} forEach units _team;
};

_destinationData = expectedDestination _leader;
_destinationMode = "DoNotPlan";
if (typeName _destinationData == "ARRAY" && {count _destinationData > 1}) then {
	_destinationMode = _destinationData select 1;
};
if (count _destinationPosition == 0 && {_destinationMode != "DoNotPlan"}) then {
	_destinationPosition = _destinationData select 0;
	if (typeName _destinationPosition != "ARRAY" || {count _destinationPosition < 2}) then {
		_destinationPosition = [];
	} else {
		if (((_destinationPosition select 0) == 0) && {(_destinationPosition select 1) == 0}) then {
			_destinationPosition = [];
		} else {
			_destinationSource = Format ["leader expectedDestination [%1]", _destinationMode];
		};
	};
};

if (count _destinationPosition == 0) exitWith {
	false
};

_orderedUnits = [];
_orderedVehicles = [];

{
	_unit = _x;

	if (!isNull _unit && alive _unit) then {
		_vehicle = vehicle _unit;

		if (_vehicle == _unit) then {
			_unit commandMove _destinationPosition;
			_orderedUnits = _orderedUnits + [_unit];
		} else {
			if (_unit == driver _vehicle) then {
				if ((_orderedVehicles find _vehicle) == -1) then {
					_unit commandMove _destinationPosition;
					_orderedUnits = _orderedUnits + [_unit];
					_orderedVehicles = _orderedVehicles + [_vehicle];
				};
			};
		};
	};
} forEach _spawnedUnits;

true
