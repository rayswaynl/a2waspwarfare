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
    "_hasElipse"
];

// Extract required parameters.
_markerName            = _this select 0;
_markerPosition        = _this select 1;
_markerType            = _this select 2;
_markerText            = _this select 3;
_markerColor           = _this select 4;
_side_who_see_marker   = _this select 5;

// Optional ellipse parameters.
_hasElipse = false;

if (count _this > 7) then 
{
    _markerNameElipse = _this select 6;
    _markerRadius = _this select 7;
    _hasElipse = true;
};

// Create the main marker globally.
// It must exist globally so that late-joining clients can receive and process it.
_markerName = createMarker [_markerName, _markerPosition];

// If an ellipse is requested, create it globally too.
// Its visibility/settings are still applied locally depending on playerSide.
if (_hasElipse) then 
{
    _markerNameElipse = createMarker [_markerNameElipse, _markerPosition];
};

if (playerSide == _side_who_see_marker) then 
{
    // Main marker local display.
    _markerName setMarkerTypeLocal _markerType;
    _markerName setMarkerTextLocal _markerText;
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