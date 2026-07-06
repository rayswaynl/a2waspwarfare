/*
	Given a LocationLogicAirport object, return the sideID of the nearest town/depot
	logic (from the global towns array) within WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS.

	Ownership proxy: the airfield depot logic (wfbe_is_airfield=true) is always the
	closest town entry to its companion LocationLogicAirport (measured distances:
	CH Balota 11m, NWAF 10m, NEAF 76m; TK Loy Manara AF 77m, Rasman AF 79m;
	ZG Zargabad AF 0m). Any radius < 500m binds only the depot airfield logic;
	the default 500m is deliberately narrower than the nearest non-airfield town
	(865m on CH, 679m on TK) to avoid cross-binding.

	Parameters:
		_this select 0  - LocationLogicAirport object (from WFBE_CL_FNC_GetClosestAirport)

	Returns:
		sideID (numeric) of the owning town logic, or -1 if no town is within radius.
		-1 means "no owner / neutral" which the gate treats as ALLOWED.

	fable/airfield-ownership-gate, GR-2026-07-06a
*/

private [_afLogic,_radius,_best,_bestDist,_d,_sid];

_afLogic = _this select 0;
_radius  = missionNamespace getVariable [WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS, 500];
_best     = objNull;
_bestDist = _radius + 1;

{
	_d = _x distance _afLogic;
	if (_d < _bestDist) then {_best = _x; _bestDist = _d};
} forEach towns;

_sid = -1;
if !(isNull _best) then {
	if (_bestDist <= _radius) then {_sid = _best getVariable [sideID, -1]};
};

_sid
