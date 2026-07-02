Private ["_destination","_maxWaypoints","_pos","_radius","_rand1","_rand2","_team","_type","_update","_wps","_z",
	"_rbEnabled","_rbSideID","_rbOwned","_rbOrigin","_rbDest","_rbHQ","_rbA","_rbB","_rbLane","_rbHops","_rbRoute","_rbNodeCount","_rbI","_rbNode","_rbType"];
_team = _this select 0;
_destination = _this select 1;
_radius = if (count _this > 2) then {_this select 2} else {30};
if (typeName _destination == 'OBJECT') then {_destination = getPos _destination};

_team setCombatMode "YELLOW";
_team setBehaviour "AWARE";
_team setFormation "COLUMN";
_team setSpeedMode "NORMAL";

_update = true;
if (side _team == west || side _team == east) then {
	_update = (_team) Call CanUpdateTeam;
};

//--- Override.
if (_update) then {_team Call UpdateTeam};

_maxWaypoints = 8;
_wps = [];

//--- ROAD-BIASED PATROLS (cmdcon41-w3, Ray pick #2). When WFBE_C_PATROLS_ROADBIAS==1 the patrol
//--- waypoint chain follows ROAD nodes along a corridor between two of the side's OWNED towns
//--- (or its HQ + a front-adjacent owned town), swept via the shared WFBE_CO_FNC_BuildRoadRoute
//--- helper, instead of laying random cross-country points around _destination. The pair is chosen
//--- fresh each patrol cycle so successive patrols sweep DIFFERENT corridors. Posture is unchanged
//--- (YELLOW/AWARE/COLUMN set above). On ANY failure (feature off, <2 owned towns with no HQ, no
//--- road near either end, helper returns <2 nodes) it FALLS THROUGH to the legacy random-point
//--- block below so a patrol is NEVER left without a live order (never-frozen mandate). Bounded:
//--- one BuildRoadRoute call (its own hop loop is <=8) + one linear waypoint lay, no per-frame work.
//--- A2-OA-1.64-safe: plain getVariable/count/select, if/else on side-ID !=, no A3 commands.
_rbEnabled = (missionNamespace getVariable ["WFBE_C_PATROLS_ROADBIAS", 1]) > 0;
if (_rbEnabled) then {
	_rbSideID = (side _team) Call WFBE_CO_FNC_GetSideID;
	_rbOwned = [];
	{if ((_x getVariable ["sideID", -1]) == _rbSideID) then {_rbOwned = _rbOwned + [_x]}} forEach towns;

	_rbOrigin = objNull;
	_rbDest   = objNull;
	if (count _rbOwned >= 2) then {
		//--- Two DIFFERENT owned towns: random origin, then a different random dest (vary the corridor each cycle).
		_rbA = _rbOwned select (floor (random (count _rbOwned)));
		_rbB = _rbA;
		//--- Bounded re-roll for a distinct partner (owned>=2 guarantees one exists; cap iterations for safety).
		_rbI = 0;
		while {_rbB == _rbA && _rbI < 8} do {
			_rbB = _rbOwned select (floor (random (count _rbOwned)));
			_rbI = _rbI + 1;
		};
		if (_rbB != _rbA) then {_rbOrigin = _rbA; _rbDest = _rbB};
	} else {
		//--- Fewer than 2 owned towns: run HQ -> the single owned town (or HQ -> passed destination) as the corridor.
		_rbHQ = (side _team) Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _rbHQ && count _rbOwned > 0) then {_rbOrigin = _rbHQ; _rbDest = (_rbOwned select 0)};
	};

	if (!isNull _rbOrigin && !isNull _rbDest) then {
		//--- Small lane jitter (like the AICOM path) so concentrated patrols don't funnel one road; hops<=maxWaypoints.
		_rbLane  = (random 240) - 120;
		_rbHops  = _maxWaypoints;
		_rbRoute = [getPos _rbOrigin, getPos _rbDest, _rbLane, _rbHops] Call WFBE_CO_FNC_BuildRoadRoute;
		_rbNodeCount = count _rbRoute;
		if (_rbNodeCount >= 2) then {
			//--- Lay MOVE waypoints along the road-node chain, CYCLE on the last so the patrol re-runs the corridor.
			for [{_rbI = 0},{_rbI < _rbNodeCount},{_rbI = _rbI + 1}] do {
				_rbNode = _rbRoute select _rbI;
				_rbType = if (_rbI != (_rbNodeCount - 1)) then {'MOVE'} else {'CYCLE'};
				_wps = _wps + [[_rbNode,_rbType,35,40,"",[]]];
			};
			["INFORMATION", Format ["AI_Patrol.sqf: [%1] Team [%2] ROAD-BIASED patrol [%3] -> [%4] (%5 road nodes).", side _team, _team, _rbOrigin getVariable ["name","origin"], _rbDest getVariable ["name","dest"], _rbNodeCount]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

//--- If the road-biased path laid a chain, ship it and stop; otherwise fall through to the legacy
//--- random-point block (never-idle guarantee for every failure mode above).
if (count _wps > 0) exitWith {[_team, true, _wps] Call AIWPAdd;};

for [{_z=0},{_z<=_maxWaypoints},{_z=_z+1}] do {
	_rand1 = random _radius - random _radius;
	_rand2 = random _radius - random _radius;
	_pos = [(_destination select 0)+_rand1,(_destination select 1)+_rand2,0];
	_wtr = 0;
	while {surfaceIsWater _pos && _wtr < 20} do {
		_rand1 = random _radius - random _radius;
		_rand2 = random _radius - random _radius;
		_pos = [(_destination select 0)+_rand1,(_destination select 1)+_rand2,0];
		_wtr = _wtr + 1;
	};
	if (surfaceIsWater _pos) then {_pos = [_destination select 0, _destination select 1, 0]};
	_type = if (_z != _maxWaypoints) then {'MOVE'} else {'CYCLE'};
	_wps = _wps + [[_pos,_type,35,40,"",[]]];
};

["INFORMATION", Format ["AI_Patrol.sqf: [%1] Team [%2] is patrolling at [%3].", side _team,_team,_destination]] Call WFBE_CO_FNC_LogContent;

[_team, true, _wps] Call AIWPAdd;