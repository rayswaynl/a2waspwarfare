/*
	Author: Marty
	Cleanup locally delegated town AI groups.
	Parameters:
		- Town
		- Side
*/

Private ["_deadline","_deletedGroups","_deletedUnits","_entry","_entryGroup","_entrySide","_entryTown","_group","_groups","_keptGroups","_registry","_registryNew","_side","_town","_townName","_units"];

_town = _this select 0;
_side = _this select 1;
_registry = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []];
_groups = [];

{
	_entry = _x;
	if (count _entry >= 3) then {
		_entryTown = _entry select 0;
		_entrySide = _entry select 1;
		_entryGroup = _entry select 2;
		if (_entryTown == _town && _entrySide == _side) then {
			if !(isNull _entryGroup) then {
				if !(_entryGroup in _groups) then {_groups set [count _groups, _entryGroup]};
			};
		};
	};
} forEach _registry;

if (count _groups == 0) exitWith {};

_deletedUnits = 0;
_deletedGroups = 0;
_keptGroups = 0;
_townName = _town getVariable "name";

{
	_group = _x;
	call {
		if (isNull _group) exitWith {};
		if !(isNil {_group getVariable "WFBE_TownAI_Town"}) then {
			if ((_group getVariable "WFBE_TownAI_Town") != _town) exitWith {};
		};
		if !(isNil {_group getVariable "WFBE_TownAI_Side"}) then {
			if ((_group getVariable "WFBE_TownAI_Side") != _side) exitWith {};
		};

		_units = +units _group;
		{deleteVehicle _x; _deletedUnits = _deletedUnits + 1} forEach _units;

		_deadline = time + 5;
		waitUntil {sleep 0.1; isNull _group || count (units _group) == 0 || time > _deadline};

		if (isNull _group) exitWith {_deletedGroups = _deletedGroups + 1};
		if (count (units _group) > 0) exitWith {
			_keptGroups = _keptGroups + 1;
			["WARNING", Format ["TOWN_AI_HC_CLEANUP group_not_empty town:%1 side:%2 group:%3 remainingUnits:%4", _townName, _side, _group, count (units _group)]] Call WFBE_CO_FNC_LogContent;
		};

		deleteGroup _group;
		_deletedGroups = _deletedGroups + 1;
	};
} forEach _groups;

_registryNew = [];
{
	_entry = _x;
	call {
		if (count _entry < 3) exitWith {};
		_entryTown = _entry select 0;
		_entrySide = _entry select 1;
		_entryGroup = _entry select 2;
		if (isNull _entryGroup) exitWith {};
		if (_entryTown == _town && _entrySide == _side) exitWith {};
		_registryNew set [count _registryNew, _entry];
	};
} forEach _registry;
missionNamespace setVariable ["WFBE_CL_TownAI_Groups", _registryNew];

["INFORMATION", Format ["TOWN_AI_HC_CLEANUP done town:%1 side:%2 groups:%3 deletedGroups:%4 deletedUnits:%5 keptGroups:%6 registryBefore:%7 registryAfter:%8", _townName, _side, count _groups, _deletedGroups, _deletedUnits, _keptGroups, count _registry, count _registryNew]] Call WFBE_CO_FNC_LogContent;
