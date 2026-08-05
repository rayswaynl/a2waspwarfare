Private ['_artyNames','_retVal','_side','_unit'];
_unit = _this select 0;
_side = _this select 1;

_retVal = -1;
//--- Civilian/caster clients and other unsupported sides have no artillery registry.
_artyNames = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_CLASSNAMES",_side], []];
if (typeName _artyNames != "ARRAY") then {_artyNames = []};

for '_i' from 0 to (count _artyNames)-1 do {
	if (_unit in (_artyNames select _i)) exitWith {_retVal = _i};
};

_retVal