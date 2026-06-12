private ["_unitsFiring", "_markerColor", "_unit", "_marker", "_flashRed", "_blinks", "_LFTB"];

_unit = _this select 0;
_flashRed = _this select 1;
_marker = _unit getVariable "unitMarkerBlink";
_markerColor = _unit getVariable "OriginalMarkerColor";
_blinks = _unit getVariable "Blinks";
_LFTB = _unit getVariable "LFTB";

if (isNil "_blinks") then {
    _blinks = 0;
    _unit setVariable ["Blinks", 0, false];
};

if (isNull _unit) exitWith {_unit setVariable ["LFTB", false, false]; };

if (_flashRed) then {
    _marker setMarkerColorLocal "ColorRed";    
    // test if variable assignment works without global flag set to true
    _blinks = _blinks + 1;
    _unit setVariable ["Blinks", _blinks, false];
} else {
    _marker setMarkerColorLocal _markerColor;
    _blinks = _blinks + 1;
    // test if variable assignment works without global flag set to true
    _unit setVariable ["Blinks", _blinks, false];
};

if ((_unit getVariable "Blinks") > (missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_BLINKS")) then {
    _unit setVariable ["LFTB", false, false];
    _marker setMarkerColorLocal _markerColor;
    _unit setVariable ["Blinks", 0, false];
};

if (!alive _unit) then {
    _unit setVariable ["LFTB", false, false];
    _marker setMarkerColorLocal _markerColor;
};