/*
	Author: Marty
	Description:
		Returns true when the given object is close to a valid destroyed camp.
*/

Private ["_bunker","_camp","_camps","_canRepair","_entity","_range"];

_entity = _this;
_canRepair = false;

if (isNull _entity || !(alive _entity)) exitWith {false};
if (isNil "WFBE_Logic_Camp") exitWith {false};
if (isNil {missionNamespace getVariable "WFBE_C_CAMPS_REPAIR_RANGE"}) exitWith {false};

_range = missionNamespace getVariable "WFBE_C_CAMPS_REPAIR_RANGE";
_camps = _entity nearEntities [WFBE_Logic_Camp, _range];

{
	_camp = _x;

	if (!_canRepair && !(isNil {_camp getVariable "sideID"}) && !(isNil {_camp getVariable "wfbe_camp_bunker"})) then {
		_bunker = _camp getVariable "wfbe_camp_bunker";

		if !(alive _bunker) then {_canRepair = true};
	};
} forEach _camps;

_canRepair
