Private ["_value"];

if (isNull _this) exitWith {""};

_value = _this getVariable "wfbe_respawn";
if (isNil "_value") exitWith {""};
_value
