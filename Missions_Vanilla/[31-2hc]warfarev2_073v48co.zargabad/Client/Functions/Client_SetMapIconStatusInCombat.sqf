// Marty: Performance Audit locals.
private ["_unit", "_hasFired", "_dt", "_vehicleUnit", "_hasFiredVehicle", "_perfStart", "_perfNetworkSetVars"];

_unit = _this;
_vehicleUnit = vehicle _unit;

// Marty: Radical mission-parameter off switch; no LFTB network write if combat icon blinking is disabled.
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) != 1) exitWith {};

// Marty: Performance Audit timing for combat marker activation.
_perfStart = diag_tickTime;
_perfNetworkSetVars = 0;

_hasFired = _unit getVariable "LFTB";
_hasFiredVehicle = _vehicleUnit getVariable "LFTB";

if (!isNil { _hasFired }) then {
    if (!_hasFired) then {
        // Marty: Performance Audit counter for networked combat marker writes.
        _perfNetworkSetVars = _perfNetworkSetVars + 1;
        _unit setVariable ["LFTB", true, true];
        _unit setVariable ["Blinks", 0, false];
    }
} else {
    // Marty: Performance Audit counter for networked combat marker writes.
    _perfNetworkSetVars = _perfNetworkSetVars + 1;
    _unit setVariable ["LFTB", true, true];
    _unit setVariable ["Blinks", 0, false];
};

if (!isNil { _hasFiredVehicle }) then {
    if (!_hasFiredVehicle) then {
        _vehicleUnit setVariable ["LFTB", true, false];
        _vehicleUnit setVariable ["Blinks", 0, false];
    }
} else {
    _vehicleUnit setVariable ["LFTB", true, false];
    _vehicleUnit setVariable ["Blinks", 0, false];
};

// Marty: Performance Audit record for combat marker activation.
if !(isNil "PerformanceAudit_Record") then {
    if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
    	["combat_marker_fired", diag_tickTime - _perfStart, Format["networkSetVars:%1;vehicle:%2", _perfNetworkSetVars, _vehicleUnit != _unit], "CLIENT"] Call PerformanceAudit_Record;
    };
};
