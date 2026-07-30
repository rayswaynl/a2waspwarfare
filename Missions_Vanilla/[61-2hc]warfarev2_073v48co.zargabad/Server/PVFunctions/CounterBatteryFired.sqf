/* CounterBatteryFired.sqf — server-side PVF handler.
   Receives a CBR detection request routed from a client (player-crewed arty fires on client locality).
   Delegates to WFBE_SE_FNC_CounterBatteryCheck which runs entirely server-side.

   Parameters (as received via WFBE_SE_FNC_HandlePVF dispatch):
     0 - firing unit (object)
     1 - firing position [x, y, z]
*/
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) == 0) exitWith {};

Private ["_unit","_fpos"];

//--- Envelope: short / wrong-type payloads must not reach CounterBatteryCheck
//--- (side _unit / distance / fire-mission counter can error or arm forged threat).
if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["CounterBatteryFired.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 2) exitWith {
	["WARNING", Format ["CounterBatteryFired.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_unit = _this select 0;
_fpos = _this select 1;

if (typeName _unit != "OBJECT" || {isNull _unit}) exitWith {
	["WARNING", Format ["CounterBatteryFired.sqf: rejected invalid firing unit [%1].", _unit]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _fpos != "ARRAY" || {count _fpos < 2}) exitWith {
	["WARNING", Format ["CounterBatteryFired.sqf: rejected invalid firing position [%1].", _fpos]] Call WFBE_CO_FNC_LogContent;
};
if (typeName (_fpos select 0) != "SCALAR" || {typeName (_fpos select 1) != "SCALAR"}) exitWith {
	["WARNING", Format ["CounterBatteryFired.sqf: rejected non-numeric firing position [%1].", _fpos]] Call WFBE_CO_FNC_LogContent;
};

[_unit, _fpos] Call WFBE_SE_FNC_CounterBatteryCheck;
