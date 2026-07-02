/* 
	Original Author: Marty
	Name: Common_UpdateMarker.sqf

	Parameters:
	0 - _markerObject 	: object - object to track.
	1 - _markerName		: string - marker name.
	2 - _markerType		: string - marker type.
	3 - _markerText		: string - marker text.
	4 - _markerColor	: string - marker color.

	Description:
	Creates the marker locally if needed, then updates its position.
	This is intended for client-side team-only markers.
*/

Private ["_markerObject", "_markerName", "_markerType", "_markerText", "_markerColor", "_markerPosition"];

_markerObject 	= _this select 0;
_markerName		= _this select 1;
_markerType 	= _this select 2;
_markerText		= _this select 3;
_markerColor 	= _this select 4;

if (isNull _markerObject) exitWith {};

// Create the marker locally if it does not exist yet on this client.
if ((getMarkerType _markerName) == "") then {
	createMarkerLocal [_markerName, getPos _markerObject];
};

_markerName setMarkerTypeLocal _markerType; 
_markerName setMarkerTextLocal _markerText;
_markerName setMarkerColorLocal _markerColor;

_markerPosition = getPos _markerObject;
_markerName setMarkerPosLocal _markerPosition;