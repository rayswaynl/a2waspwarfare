Private ["_value"];

if (isNull _this) exitWith {false};

_value = _this getVariable "wfbe_autonomous";
if (isNil "_value") exitWith {false};
_value
