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
if (isNil "_marker" || {typeName _marker != "STRING"} || {_marker == ""}) exitWith {_unit setVariable ["LFTB", false, false]; };

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

//--- fable/marker-combat-flash (owner 2026-07-09): optional seconds-based override. 0 (default) is
//--- inert and falls through to the existing WFBE_C_PLAYERS_MARKER_BLINKS blink-COUNT below -
//--- byte-identical when the new flag is left at 0. >0 lets an admin dial the flash window in
//--- seconds; the Bookkeep loop ticks ~1/s so 1 blink =~ 1s - round() is an adequate map-icon-pulse
//--- approximation, no sub-second precision needed. A2-OA-1.64-safe.
private ["_flashSecs","_blinkLimit"];
_flashSecs = missionNamespace getVariable ["WFBE_C_MARKER_COMBAT_FLASH_SECS", 0];
_blinkLimit = missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_BLINKS";
if (_flashSecs > 0) then {_blinkLimit = round _flashSecs};

if ((_unit getVariable "Blinks") > _blinkLimit) then {
    _unit setVariable ["LFTB", false, false];
    _marker setMarkerColorLocal _markerColor;
    _unit setVariable ["Blinks", 0, false];
};

if (!alive _unit) then {
    _unit setVariable ["LFTB", false, false];
    _marker setMarkerColorLocal _markerColor;
};