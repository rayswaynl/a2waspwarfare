/* 
    Original Author: Marty
    Name: Common_CreateMarker.sqf

    Parameters:
    0 - _markerName            : string - Name of the marker to create.
    1 - _position              : array or object position - Marker position.
    2 - _markerType            : string - Marker type. See CfgMarkers.
    3 - _markerText            : string - Text displayed on the map.
    4 - _markerColor           : string - Marker color. See CfgMarkerColors.
    5 - _side_who_see_marker   : side - Side allowed to see the marker, usually west or east.
    6 - _markerNameElipse      : string - optional - Name of the ellipse marker.
    7 - _markerRadius          : number - optional - Radius of the ellipse marker.

    Description:
    This function creates a marker visible only for a specific side.
    Optional ellipse support is kept backward-compatible with existing calls.

    r73b: map-marker text integrity — pre-delete name collisions, coerce text to STRING,
    fail-clean empty createMarker return, and side-gate with stable WFBE_Client_SideID
    (playerSide drifts on JIP/respawn; mirrors Init_BaseStructure / MARKER_CREATION EH).
*/

private [
    "_MARKER_infos",
    "_markerName",
    "_markerPosition",
    "_markerType",
    "_markerText",
    "_markerColor",
    "_side_who_see_marker",
    "_markerNameElipse",
    "_markerRadius",
    "_hasElipse",
    "_sideMatch",
    "_createdName",
    "_createdEllipse"
];

// Extract required parameters.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 6}) exitWith {};

_markerName            = _this select 0;
_markerPosition        = _this select 1;
_markerType            = _this select 2;
_markerText            = _this select 3;
_markerColor           = _this select 4;
_side_who_see_marker   = _this select 5;

if (isNil "_markerName" || {typeName _markerName != "STRING"} || {_markerName == ""}) exitWith {};
if (isNil "_markerPosition") exitWith {};
if (typeName _markerPosition == "OBJECT") then {
	if (isNull _markerPosition) exitWith {};
	_markerPosition = getPos _markerPosition;
};
if (typeName _markerPosition != "ARRAY" || {count _markerPosition < 2}) exitWith {};

if (isNil "_markerType" || {typeName _markerType != "STRING"} || {_markerType == ""}) then {_markerType = "mil_dot"};
//--- r73b: setMarkerText(Local) requires STRING — coerce numbers/side labels so ARTY/ICBM text never aborts.
if (isNil "_markerText") then {_markerText = ""};
if (typeName _markerText != "STRING") then {_markerText = str _markerText};
if (isNil "_markerColor" || {typeName _markerColor != "STRING"} || {_markerColor == ""}) then {_markerColor = "ColorRed"};

// Optional ellipse parameters.
_hasElipse = false;
_markerNameElipse = "";
_markerRadius = 0;

if (count _this > 7) then 
{
    _markerNameElipse = _this select 6;
    _markerRadius = _this select 7;
    if (!isNil "_markerNameElipse" && {typeName _markerNameElipse == "STRING"} && {_markerNameElipse != ""} && {!isNil "_markerRadius"} && {typeName _markerRadius == "SCALAR"}) then {
		_hasElipse = true;
	};
};

//--- r73b: createMarker on an existing name fails (returns "") and leaves the old marker orphaned with stale text.
//--- Pre-delete main + optional ellipse so a re-call (ICBM same-second, arty re-fire) always repaints cleanly.
if ((markerType _markerName) != "") then {deleteMarker _markerName};
if (_hasElipse && {(markerType _markerNameElipse) != ""}) then {deleteMarker _markerNameElipse};

// Create the main marker globally.
// It must exist globally so that late-joining clients can receive and process it.
_createdName = createMarker [_markerName, _markerPosition];
if (isNil "_createdName" || {_createdName == ""}) exitWith {
	["WARNING", Format ["Common_CreateMarker.sqf: createMarker failed for name [%1] at %2.", _markerName, _markerPosition]] Call WFBE_CO_FNC_LogContent;
};
_markerName = _createdName;

// If an ellipse is requested, create it globally too.
// Its visibility/settings are still applied locally depending on side match.
if (_hasElipse) then 
{
    _createdEllipse = createMarker [_markerNameElipse, _markerPosition];
    if (isNil "_createdEllipse" || {_createdEllipse == ""}) then {
		_hasElipse = false;
		["WARNING", Format ["Common_CreateMarker.sqf: ellipse createMarker failed for name [%1].", _markerNameElipse]] Call WFBE_CO_FNC_LogContent;
	} else {
		_markerNameElipse = _createdEllipse;
	};
};

//--- r73b: stable joined-side id (B62 family). Fall back to playerSide only before client id is known.
_sideMatch = if (!isNil "WFBE_Client_SideID") then {
	(_side_who_see_marker Call GetSideID) == WFBE_Client_SideID
} else {
	(!isNil "playerSide" && {playerSide == _side_who_see_marker})
};

if (_sideMatch) then 
{
    // Main marker local display.
    _markerName setMarkerTypeLocal _markerType;
    if (_markerText != "") then {_markerName setMarkerTextLocal _markerText};
    _markerName setMarkerColorLocal _markerColor;

    // Optional ellipse local display.
    if (_hasElipse) then 
    {
        _markerNameElipse setMarkerShapeLocal "ELLIPSE";
        _markerNameElipse setMarkerSizeLocal [_markerRadius, _markerRadius];
        _markerNameElipse setMarkerColorLocal _markerColor;
        _markerNameElipse setMarkerAlphaLocal 0.5;
        _markerNameElipse setMarkerBrushLocal "Solid";
    };
};

_MARKER_infos = _this;

missionNamespace setVariable ["MARKER_CREATION", _MARKER_infos];
publicVariable "MARKER_CREATION";
