/*
	Wildcard map-marker receiver (feature: wildcard events on the map).
	Dispatched server-side by the wildcard workers (AI_Commander_Wildcard.sqf /
	AI_Commander_Wildcard_GUER.sqf) via WFBE_CO_FNC_SendToClients, with the SIDE
	the wildcard belongs to as the destination - so Client_HandlePVF only runs this
	on that side's clients (it matches a SIDE destination against sideJoined). The
	marker is therefore created LOCAL (createMarkerLocal) and is seen ONLY by the
	respective team. No global marker leak to the enemy.

	Two ops, one marker per active event (the server cleans up by name on expiry):
	  ["create", _mkName, _pos, _color, _type, _label]
	  ["delete", _mkName]

	A2 OA 1.64: createMarkerLocal / setMarkerType(Local) / setMarkerColor(Local) /
	setMarkerText(Local) / setMarkerSize(Local) / deleteMarkerLocal all valid.
	 Parameters:
		- _this : ARRAY, [_op, _mkName, ...] as above.
*/

Private ["_op","_mkName","_pos","_color","_type","_label"];

if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}};
if (isDedicated) exitWith {};
if (isNull player) exitWith {};

if (typeName _this != "ARRAY") exitWith {};
if (count _this < 2) exitWith {};

_op     = _this select 0;
_mkName = _this select 1;
if (typeName _op != "STRING" || {typeName _mkName != "STRING"} || {_mkName == ""}) exitWith {};

switch (_op) do {

	case "create": {
		if (count _this < 6) exitWith {};
		_pos   = _this select 2;
		_color = _this select 3;
		_type  = _this select 4;
		_label = _this select 5;
		//--- Idempotent: if a marker by this name already exists locally, drop it first
		//--- so a re-create never stacks (one marker per active event).
		if (markerType _mkName != "") then {deleteMarkerLocal _mkName};
		createMarkerLocal [_mkName, _pos];
		_mkName setMarkerTypeLocal _type;
		_mkName setMarkerColorLocal _color;
		_mkName setMarkerSizeLocal [1, 1];
		_mkName setMarkerTextLocal _label;
	};

	case "delete": {
		if (markerType _mkName != "") then {deleteMarkerLocal _mkName};
	};
};
