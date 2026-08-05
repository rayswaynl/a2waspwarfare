/*
	Author: Marty
	Cleanup locally delegated town AI groups.
	Parameters:
		- Town
		- Side
		- Epoch gate (optional; the town's current epoch at the moment cleanup was requested).
		  When present, only registry entries whose OWN recorded epoch differs from this value are
		  torn down - an entry that matches IS the current, live batch and is left alone (a same-side
		  cleanup broadcast is only ever "stale" relative to an older epoch, never to itself). When
		  absent (legacy senders / real deactivation teardown in server_town_ai.sqf), every matching
		  town+side entry is torn down as before.
*/

Private ["_deadline","_deletedGroups","_deletedUnits","_entry","_entryDrop","_entryEpoch","_entryGroup","_entrySide","_entryTown","_epochGate","_group","_groups","_keptGroups","_keptRegistryGroups","_logGroupCount","_registry","_registryCurrent","_registryNew","_side","_town","_townName","_units"];

_town = _this select 0;
_side = _this select 1;
//--- fix-1375 (codex hold a): -1 means "no epoch gate" (legacy/deactivation callers) - delete every
//--- matching town+side entry as before.
_epochGate = if (count _this > 2) then {_this select 2} else {-1};
_registry = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []];
_groups = [];
_keptRegistryGroups = [];

{
	_entry = _x;
	if (count _entry >= 3) then {
		_entryTown = _entry select 0;
		_entrySide = _entry select 1;
		_entryGroup = _entry select 2;
		_entryEpoch = if (count _entry >= 4) then {_entry select 3} else {-1};
		if (_entryTown == _town && _entrySide == _side && {(_epochGate == -1) || {_entryEpoch != _epochGate}}) then {
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

// Marty: Record local HC/client group counts before and after delegated town AI cleanup.
_logGroupCount = {
	Private ["_event", "_groupCountCiv", "_groupCountEast", "_groupCountGuer", "_groupCountLogic", "_groupCountSide", "_groupCountWest", "_groupCountUnknown", "_groupMachine", "_groupSide"];

	_event = _this select 0;
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
	["INFORMATION", Format ["TOWN_GROUP_COUNT %1 machine:%2 town:%3 side:%4 sideGroups:%5 total:%6 west:%7 east:%8 guer:%9 civ:%10 logic:%11 unknown:%12", _event, _groupMachine, _townName, _side, _groupCountSide, count allGroups, _groupCountWest, _groupCountEast, _groupCountGuer, _groupCountCiv, _groupCountLogic, _groupCountUnknown]] Call WFBE_CO_FNC_LogContent;
};

["cleanup_before"] call _logGroupCount;

{
	_group = _x;
	call {
		if (isNull _group) exitWith {};
		//--- fix(exitWith-control-flow g1606): mismatch exitWith was nested in then{} so it only left the
		//--- then-block and FALLS THROUGH into deleteVehicle (wrong-town/side stamp was ignored).
		if (!(isNil {_group getVariable "WFBE_TownAI_Town"}) && {(_group getVariable "WFBE_TownAI_Town") != _town}) exitWith {_keptRegistryGroups set [count _keptRegistryGroups, _group]};
		if (!(isNil {_group getVariable "WFBE_TownAI_Side"}) && {(_group getVariable "WFBE_TownAI_Side") != _side}) exitWith {_keptRegistryGroups set [count _keptRegistryGroups, _group]};

		_units = +units _group;
		{["hc-townai-cleanup-unit", _x, Format ["town=%1", _townName]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; _deletedUnits = _deletedUnits + 1} forEach _units;

		_deadline = time + 5;
		waitUntil {sleep 0.1; isNull _group || count (units _group) == 0 || time > _deadline};

		if (isNull _group) exitWith {_deletedGroups = _deletedGroups + 1};
		if (count (units _group) > 0) exitWith {
			_keptGroups = _keptGroups + 1;
			_keptRegistryGroups set [count _keptRegistryGroups, _group];
			["WARNING", Format ["TOWN_AI_HC_CLEANUP group_not_empty town:%1 side:%2 group:%3 remainingUnits:%4", _townName, _side, _group, count (units _group)]] Call WFBE_CO_FNC_LogContent;
		};

		deleteGroup _group;
		_deletedGroups = _deletedGroups + 1;
	};
} forEach _groups;

//--- The cleanup loop yields while local deletes settle. Re-read the registry before rebuilding so
//--- a newer delegate-townai batch registered during that wait is retained. Remove only original
//--- cleanup groups; groups that were not actually torn down remain registered.
_registryCurrent = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []];
_registryNew = [];
{
	_entry = _x;
	call {
		if (count _entry < 3) exitWith {};
		_entryTown = _entry select 0;
		_entrySide = _entry select 1;
		_entryGroup = _entry select 2;
		_entryEpoch = if (count _entry >= 4) then {_entry select 3} else {-1};
		if (isNull _entryGroup) exitWith {};
		//--- fix(exitWith-control-flow g1606 follow-up): the drop exitWith was nested two then{}
		//--- levels deep, so it only left the innermost then-block and fell through into the
		//--- unconditional set below - the registry never actually pruned. Compute the drop
		//--- decision as a top-scope boolean and guard the re-add with it so a genuine drop
		//--- really skips the set.
		_entryDrop = false;
		if (_entryGroup in _groups) then {
			if (_entryTown == _town && _entrySide == _side && {(_epochGate == -1) || {_entryEpoch != _epochGate}}) then {
				if !(_entryGroup in _keptRegistryGroups) then {_entryDrop = true};
			};
		};
		if !(_entryDrop) then {_registryNew set [count _registryNew, _entry];};
	};
} forEach _registryCurrent;
missionNamespace setVariable ["WFBE_CL_TownAI_Groups", _registryNew];

// Marty: Log the count after deleteGroup has run locally so the RPT shows whether group slots are recovered.
["cleanup_after"] call _logGroupCount;

["INFORMATION", Format ["TOWN_AI_HC_CLEANUP done town:%1 side:%2 groups:%3 deletedGroups:%4 deletedUnits:%5 keptGroups:%6 registryBefore:%7 registryAfter:%8", _townName, _side, count _groups, _deletedGroups, _deletedUnits, _keptGroups, count _registry, count _registryNew]] Call WFBE_CO_FNC_LogContent;
