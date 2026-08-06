/* CounterBatteryFired.sqf — server-side PVF handler.
   Receives a CBR detection request routed from a client (player-crewed arty fires on client locality).
   Delegates to WFBE_SE_FNC_CounterBatteryCheck which runs entirely server-side.

   Parameters (as received via WFBE_SE_FNC_HandlePVF dispatch):
     0 - firing unit (object)
     1 - firing position [x, y, z]
*/
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) == 0) exitWith {};

//--- Fail-clean malformed client PV payloads (null firer mid-burst / non-array / short tuple).
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 2}) exitWith {};
Private ["_unit","_fpos"];
_unit = _this select 0;
_fpos = _this select 1;
if (isNil "_unit" || {typeName _unit != "OBJECT"} || {isNull _unit}) exitWith {};
if (isNil "_fpos" || {typeName _fpos != "ARRAY"} || {count _fpos < 2}) then {_fpos = getPos _unit};
//--- PR #1630: reject non-numeric firing-position elements (forged/short PV tuple) before
//--- WFBE_SE_FNC_CounterBatteryCheck runs distance/vector math on them.
if (typeName (_fpos select 0) != "SCALAR" || {typeName (_fpos select 1) != "SCALAR"}) then {_fpos = getPos _unit};

[_unit, _fpos] Call WFBE_SE_FNC_CounterBatteryCheck;
