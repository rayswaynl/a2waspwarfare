Private ["_value"];

if (isNull _this) exitWith {"towns"};

_value = _this getVariable "wfbe_teammode";
if (isNil "_value") exitWith {"towns"};
_value
