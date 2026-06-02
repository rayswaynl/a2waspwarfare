// Common_ReturnAircraftNameFromItsType.sqf

private ["_typeOfObject", "_aircraftName", "_validTypes"];
_typeOfObject = _this select 0; // Taking the first argument passed to the function

_validTypes = ["Su25_Ins", "Su25_TK_EP1", "Su39", "A10", "A10_US_EP1", "AH64D", "AH64D_EP1"];

_aircraftName = [_typeOfObject, 'displayName'] call GetConfigInfo;
if !(_typeOfObject in _validTypes) exitWith {_aircraftName};
switch (_typeOfObject) do {
    case "Su25_Ins": { _aircraftName = "Su-25A"; };
    case "Su25_TK_EP1": { _aircraftName = "Su-25T"; };
    case "Su39": { _aircraftName = "Su-39"; };
    case "A10": { _aircraftName = "A-10A"; };
    case "A10_US_EP1": { _aircraftName = "A-10C"; };
    case "AH64D": { _aircraftName = "AH-64D (TOW)"; };
    case "AH64D_EP1": { _aircraftName = "AH-64D (Hellfire)"; };
};
_aircraftName