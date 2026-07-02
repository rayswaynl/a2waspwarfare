/*
	Client helper: controls EASA access at repair-truck-built service points.
*/
Private ["_points","_unit","_vehicle"];

_unit = _this select 0;
_vehicle = _this select 1;

if (WFBE_SK_V_Type != "Engineer") exitWith {false};
if (_vehicle == _unit) exitWith {false};
if (driver _vehicle != _unit) exitWith {false};
if !(typeOf _vehicle in (missionNamespace getVariable "WFBE_EASA_Vehicles")) exitWith {false};
if (time - WFBE_SK_V_LastUse_RepairPointEASA <= WFBE_SK_V_Reload_RepairPointEASA) exitWith {false};

_points = [_vehicle] Call WFBE_CL_FNC_GetRepairTruckServicePoints;

(count _points > 0)
