/*
	Set a town's camps to a side on a client.
	 Parameters:
		- Town.
		- Old Side.
		- New Side.
*/


//--- Malformed-payload guard: ensure _this is ARRAY with >= 3 elements (town, oldSide, newSide).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 3}) exitWith {};
Private ["_camps","_color","_marker","_side_old","_side_new","_town"];

_town = _this select 0;
_side_old = _this select 1;
_side_new = _this select 2;

//--- Abort if the client is not concerned (3-way).
//--- GUER sees camp recolors on per-camp CampCaptured; legacy AllCampsCaptured must match that FOW
//--- or GUER clients keep stale camp colours after a SetCampsToSide town flip.
if (isNil "WFBE_Client_SideID") exitWith {};
if !((WFBE_Client_SideID in [_side_old, _side_new]) || {WFBE_Client_SideID == WFBE_C_GUER_ID}) exitWith {};
if (isNil "_town" || {typeName _town != "OBJECT"} || {isNull _town}) exitWith {};

_camps = _town getVariable ["camps", []];
if (isNil "_camps") then {_camps = []};
_color = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR",(_side_new) Call WFBE_CO_FNC_GetSideFromID]);

{
	if (!isNull _x) then {
		_marker = _x getVariable "wfbe_camp_marker";
		if (!(isNil "_marker") && {typeName _marker == "STRING"} && {_marker != ""}) then {
			_marker setMarkerColorLocal _color;
		};
	};
} forEach _camps;
