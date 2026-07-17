/*
	J1 funds authority (2026-07-13): unit-kill bounty math, extracted VERBATIM from
	Client/PVFunctions/AwardBounty.sqf (lines 20-48 + the :54 assist coefficient) so the SERVER
	can compute the same amount it now credits (RequestOnUnitKilled.sqf); the client handler keeps
	the identical inline math only as a legacy-payload display fallback.
	Order preserved exactly: per-kind round -> Ka-137 nerf round -> assist coefficient WITHOUT a
	final round (assists can legitimately credit fractional amounts, same as the client always did).
	 Parameters:
		0 - killed classname (STRING, the price-registry key)
		1 - isAssist (BOOL)
	 Returns: SCALAR bounty (0 when the type has no price-registry entry - the Build83 guard).
	A2-OA-1.64 safe: getVariable / isNil / isKindOf on CfgVehicles classnames / switch / round.
*/
Private ["_type","_assist","_get","_bounty"];

_type = _this select 0;
_assist = _this select 1;

_get = missionNamespace getVariable _type;
if (isNil "_get") exitWith {0}; //--- Build83 guard: no price-registry entry = no bounty.

_bounty = switch (true) do {
	case (_type isKindOf "Man"): {round((_get select QUERYUNITPRICE) *0.7* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Car"): {round((_get select QUERYUNITPRICE) *0.45* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Ship"): {round((_get select QUERYUNITPRICE) *0.4* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Motorcycle"): {round((_get select QUERYUNITPRICE) *0.7* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Tank"): {round((_get select QUERYUNITPRICE) *0.4* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Helicopter"): {round((_get select QUERYUNITPRICE) *0.4*(missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "Plane"): {round((_get select QUERYUNITPRICE) *0.35* (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "StaticWeapon"): {round((_get select QUERYUNITPRICE)*0.5*(missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	case (_type isKindOf "WarfareBBaseStructure"): {2000;};
	case (_type isKindOf "building"): {round((_get select QUERYUNITPRICE)*0.55*(missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));};
	default {0}; //--- unmatched (e.g. mod-added) classes pay nothing, same as the client math.
};

//--- Ka-137 reward nerf: a killed Ka-137 (all PMC variants) pays only the coef (default 0.4) of normal.
if ((_type isKindOf "Ka137_MG_PMC") || (_type isKindOf "Ka137_PMC")) then {
	_bounty = round(_bounty * (missionNamespace getVariable ["WFBE_C_KA137_REWARD_COEF", 0.4]));
};

//--- Assist coefficient last, NO final round (client parity - AwardBounty.sqf:54).
if (_assist) then {
	_bounty = _bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF");
};

_bounty
