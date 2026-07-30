/*
	author: Net_2
	description: none
	returns: nothing
*/

private ["_killed_type", "_get", "_coef", "_bcoef", "_points", "_price"];

_killed_type = _this select 0;

if (count _this > 1) then {
    _get = _this select 1;
} else {
    _get = missionNamespace getVariable _killed_type;
};

//--- r54: unknown / non-bought classnames leave _get nil; bare select QUERYUNITPRICE throws.
//--- Default bounty coefs so missing missionNamespace keys never poison the arithmetic.
if (isNil "_get" || {typeName _get != "ARRAY"} || {count _get <= QUERYUNITPRICE}) exitWith {2};

_coef = missionNamespace getVariable ["WFBE_C_UNITS_BOUNTY_COEF", 100];
_bcoef = missionNamespace getVariable ["WFBE_C_BUILDINGS_SCORE_COEF", 1];
_price = _get select QUERYUNITPRICE;

_points = switch (true) do {
    case (_killed_type isKindOf "Man"): {ceil((_price) *0.7* _coef / 100);};
	case (_killed_type isKindOf "Car"): {round((_price) *0.45* _coef / 100);};
	case (_killed_type isKindOf "Ship"): {round((_price) *0.4* _coef / 100);};
	case (_killed_type isKindOf "Motorcycle"): {round((_price) *0.7* _coef / 100);};
    case (_killed_type isKindOf "Tank"): {round((_price) *0.4* _coef / 100);};
	case (_killed_type isKindOf "Helicopter"): {round((_price) *0.4* _coef / 100);};
	case (_killed_type isKindOf "Plane"): {round((_price) *0.35* _coef / 100);};
	case (_killed_type isKindOf "StaticWeapon"): {round((_price) *0.5* _coef / 100);};
	case (_killed_type isKindOf "Building"): {round((_price) *0.55* _coef / 100 * _bcoef);};
	default {2};
};


_points;