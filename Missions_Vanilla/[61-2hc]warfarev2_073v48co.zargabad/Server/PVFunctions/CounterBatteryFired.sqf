/* CounterBatteryFired.sqf — server-side PVF handler.
   Receives a CBR detection request routed from a client (player-crewed arty fires on client locality).
   Delegates to WFBE_SE_FNC_CounterBatteryCheck which runs entirely server-side.

   Parameters (as received via WFBE_SE_FNC_HandlePVF dispatch):
     0 - firing unit (object)
     1 - firing position [x, y, z]
*/
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) == 0) exitWith {};

Private ["_unit","_fpos"];
_unit = _this select 0;
_fpos = _this select 1;

[_unit, _fpos] Call WFBE_SE_FNC_CounterBatteryCheck;
