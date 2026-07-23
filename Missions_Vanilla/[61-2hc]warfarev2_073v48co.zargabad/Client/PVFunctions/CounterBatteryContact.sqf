/* CounterBatteryContact.sqf — client-side PVF handler.
   Creates a local timed map marker showing detected enemy artillery position.

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - firing position [x, y, z]
     1 - time string "HH:MM"

   The PVF is addressed to a specific side (WFBE_CO_FNC_SendToClients side parameter),
   so only clients on the detecting side receive it.
*/

//--- Malformed-payload guard: ensure _this is ARRAY with >= 2 elements (position, timeString).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 2}) exitWith {};
Private ["_pos","_tStr","_markerName","_markerText"];

if (isNil "WFBE_Client_SideID") exitWith {};

_pos  = _this select 0;
_tStr = _this select 1;

_markerName = Format ["WFBE_CBR_%1", diag_tickTime];
_markerText = Format ["%1 %2", localize "STR_WF_CBR_Contact", _tStr];

createMarkerLocal [_markerName, _pos];
_markerName setMarkerTypeLocal "mil_destroy";
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerTextLocal _markerText;
_markerName setMarkerSizeLocal [0.8, 0.8];

//--- Auto-delete after 75 seconds.
[_markerName, 75] call WFBE_CL_FNC_Delete_Marker;
