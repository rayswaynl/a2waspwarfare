/*
	Build a ROAD-NODE-SNAPPED waypoint chain between two positions.
	feat/ai-commander road-march helper (extracted from AI_Commander_AssignTowns.sqf L437-462
	so the war-room console DIRECT-order path — AI_Commander_Execute.sqf — routes AI-led teams
	road-aware exactly like the AI-strategy town-assignment path, instead of laying a single
	cross-country MOVE that A2 OA pathfinding stutters through on multi-km legs).

	 Parameters:
		0 - _origin  : Position array (e.g. getPos (leader _team)).
		1 - _dest    : Position array (the order destination).
		2 - _laneOff : Scalar lateral lane offset in metres (0 = straight snap; the caller
		               manages any per-team jitter, e.g. wfbe_aicom_lanejit * WFBE_C_AICOM_LANE_OFFSET (CH 120 / TK 60), so several
		               teams sent to the same place don't funnel down one road).
		3 - _hops    : Max intermediate road hops to attempt (AssignTowns uses 8).

	Returns: an array of road-node positions (a base-egress node, if any road lies within
	300m of _origin, followed by up to _hops snapped fraction points). May be empty when no
	road is near a guess — the caller then falls back to a direct MOVE for that segment.

	A2-OA-1.64-legal: nearRoads / WFBE_CO_FNC_GetClosestEntity / getPos only. NO distance gate
	inside — the caller applies the >700m long-leg gate (AssignTowns / Execute both do).
*/

private ["_origin","_dest","_laneOff","_hops","_route","_egRds","_egNode","_laneDX","_laneDY","_laneLEN","_lanePX","_lanePY","_rmI","_rmFrac","_rmGuess","_rmTaper","_rmRds","_rmNode"];
_origin  = _this select 0;
_dest    = _this select 1;
_laneOff = _this select 2;
_hops    = _this select 3;

_route = [];

//--- Base-egress road node so a team escapes a boxed/corner base onto the road net first.
_egRds = _origin nearRoads 300;
if (count _egRds > 0) then {
	_egNode = [_origin, _egRds] Call WFBE_CO_FNC_GetClosestEntity;
	if (!isNull _egNode) then {_route = _route + [getPos _egNode]};
};

//--- Perpendicular unit vector for the per-team lateral lane (so concentrated teams don't
//--- funnel one road). Tapers to ~0 at the ends, max at mid-route.
_laneDX = (_dest select 0) - (_origin select 0);
_laneDY = (_dest select 1) - (_origin select 1);
_laneLEN = sqrt ((_laneDX * _laneDX) + (_laneDY * _laneDY));
_lanePX = 0; _lanePY = 0;
if (_laneLEN > 1) then {_lanePX = - _laneDY / _laneLEN; _lanePY = _laneDX / _laneLEN};

for "_rmI" from 1 to _hops do {
	_rmFrac  = _rmI / (_hops + 1);
	_rmGuess = [(_origin select 0) + ((_dest select 0) - (_origin select 0)) * _rmFrac,
	            (_origin select 1) + ((_dest select 1) - (_origin select 1)) * _rmFrac, 0];
	_rmTaper = sin (_rmFrac * 180);  //--- ~0 at route ends, max at mid: teams diverge into their own lane mid-route, converge at the dest.
	_rmGuess set [0, (_rmGuess select 0) + (_lanePX * _laneOff * _rmTaper)];
	_rmGuess set [1, (_rmGuess select 1) + (_lanePY * _laneOff * _rmTaper)];
	_rmRds = _rmGuess nearRoads (missionNamespace getVariable ["WFBE_C_AICOM_ROUTE_SNAP_RADIUS", 250]);  //--- Build84: wider snap (was 120) so long-leg hops find a road node instead of being silently dropped into beeline gaps.
	if (count _rmRds > 0) then {
		_rmNode = [_rmGuess, _rmRds] Call WFBE_CO_FNC_GetClosestEntity;
		if (!isNull _rmNode) then {_route = _route + [getPos _rmNode]};
	};
};

_route
