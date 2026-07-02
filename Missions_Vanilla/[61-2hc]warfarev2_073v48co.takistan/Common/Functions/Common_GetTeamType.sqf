Private ["_value"];

if (isNull _this) exitWith {0};

_value = _this getVariable "wfbe_teamtype";
if (isNil "_value") exitWith {0};
_value
