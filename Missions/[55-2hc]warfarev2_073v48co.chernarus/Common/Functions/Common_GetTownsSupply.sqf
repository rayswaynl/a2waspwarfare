Private ["_income","_side","_sid"];

_side = (_this) Call GetSideID;

_income = 0;
{
	//--- 2-arg sideID: unset ownership never matches a real side (no wrong-side credit). Avoids
	//--- 1-arg nil reads aborting the economy forEach mid-list on poison towns.
	_sid = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID];
	if (!(isNil "_sid") && {_sid == _side}) then {_income = _income + (_x getVariable ["supplyValue", 0])};
} forEach towns;

_income
