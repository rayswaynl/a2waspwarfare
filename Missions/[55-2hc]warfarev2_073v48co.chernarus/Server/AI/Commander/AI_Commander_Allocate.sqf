/*
	AI_Commander_Allocate.sqf - AICOM v2 SINGLE OFFENSIVE AUTHORITY (M1 + M2). Server-side, per side.
	Param: _this = side. Runs AFTER the M0 snapshot + the legacy Strategy worker each strategy tick
	(so its target choice WINS), gated by WFBE_C_AICOM2_ALLOCATE_ENABLE (0 = inert -> the legacy
	Strategy/AssignTowns targeting runs unchanged = instant rollback on a live server, no redeploy).

	WHAT IT FIXES (from the 18h soak): split-brain targeting (force never concentrated) + foot teams
	stranding on long legs. It CONCENTRATES force on ONE front "fist" (Ray: steamroller, WFBE_C_AICOM2_FIST_TOWNS
	default 1 - the top capturable town(s) nearest our front) and assigns EVERY eligible team to it, reach-aware.

	M2 HARASS: a LIGHT mounted detachment (WFBE_C_AICOM2_HARASS_TEAMS, default 1) peels off to raid the enemy's
	DEEPEST capturable town (their rear / supply hub) - forcing them to pull defenders off the front. The rest
	stay on the fist.

	Mechanism: per-team `wfbe_aicom_alloc_target` (a town) that AssignTowns then executes (road-route / dispatch /
	stuck-detection all reused). Publishes the fist into `wfbe_aicom_targets` (MHQReloc + the intent HUD read it).

	OFFENSE-ONLY (Ray "almost never defensive"): never recalls or defends. RESPECTS the legacy Strategy's relief /
	last-stand / HQ-strike by SKIPPING any team Strategy flagged (read LIVE, not from the one-tick-stale snapshot),
	and skips the base garrison, player-led teams, and teams under an explicit human order.

	A2-OA-safe: snapshot for tick-stable town data; live group reads for per-team state; GroupGetBool for the A2
	group-bool trap; no A3 commands.
*/

private ["_side","_sideID","_enemyID","_logik","_snap","_tgtTowns","_ownTowns","_myHQ","_teams","_fist","_garGrp","_harassTgt","_harassN"];
_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) <= 0) exitWith {};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_snap = _logik getVariable ["wfbe_aicom2_snap", []];
if (count _snap < 26) exitWith {};   //--- no / short snapshot yet (the array carries 26 fields, indices 0..25)
_sideID   = _snap select WFBE_SNAP_SIDEID;
_enemyID  = _snap select WFBE_SNAP_ENID;
_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;   //--- capturable enemy/neutral towns
_ownTowns = _snap select WFBE_SNAP_OWNTOWNOBJS;
_myHQ     = _snap select WFBE_SNAP_MYHQ;
_teams    = _logik getVariable ["wfbe_teams", []];
if (count _tgtTowns == 0) exitWith { _logik setVariable ["wfbe_aicom_targets", []] };   //--- nothing to take

//--- helper: a town's distance to OUR nearest front (own town, else our HQ) = how deep/forward it is.
//--- (inlined twice below; kept as a small private fn for clarity.)
private "_frontDist";
_frontDist = {
	private ["_tt","_dNear","_d"];
	_tt = _this; _dNear = 1e9;
	{ _d = _tt distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTowns;
	if (_dNear > 1e8) then { _dNear = if (!isNull _myHQ) then {_tt distance _myHQ} else {0} };
	_dNear
};

//--- PICK THE FIST: the top N capturable towns nearest OUR front (coherent-front concentration).
private ["_fistMax","_frontRad","_distDiv","_farPen","_scored","_i"];
_fistMax  = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_TOWNS", 1];
_frontRad = missionNamespace getVariable ["WFBE_C_AICOM_FRONTIER_RADIUS", 3000];
_distDiv  = missionNamespace getVariable ["WFBE_C_AICOM_DISTANCE_DIVISOR", 50]; if (_distDiv <= 0) then {_distDiv = 1};
_farPen   = missionNamespace getVariable ["WFBE_C_AICOM_FAR_PENALTY", 1000];
_scored = [];
{
	private ["_tt","_dNear","_sc"];
	_tt = _x; _dNear = _tt Call _frontDist;
	_sc = (_tt getVariable ["supplyValue", 0]) - (_dNear / _distDiv);
	if (_dNear > _frontRad) then {_sc = _sc - _farPen};
	_scored set [count _scored, [_sc, _tt]];
} forEach _tgtTowns;
_fist = [];
for "_i" from 1 to (_fistMax min (count _tgtTowns)) do {
	private ["_best","_bestSc"]; _best = objNull; _bestSc = -1e9;
	{ if (!((_x select 1) in _fist) && {(_x select 0) > _bestSc}) then {_bestSc = _x select 0; _best = _x select 1} } forEach _scored;
	if (!isNull _best) then {_fist set [count _fist, _best]};
};
if (count _fist == 0) exitWith {};
_logik setVariable ["wfbe_aicom_targets", _fist];   //--- the fist is the side's published main effort

//--- M2 HARASS TARGET: the enemy's DEEPEST capturable town (max front-distance), enemy-held weighted over
//--- neutral, excluding the fist. A light mounted detachment raids it to pressure their rear / supply hub.
_harassN  = missionNamespace getVariable ["WFBE_C_AICOM2_HARASS_TEAMS", 1];
_harassTgt = objNull;
if (_harassN > 0) then {
	private ["_harassFar"];
	_harassFar = -1;
	{
		private ["_tt","_depth"];
		_tt = _x;
		_depth = (_tt Call _frontDist) + (if ((_tt getVariable ["sideID", -1]) == _enemyID) then {3000} else {0});
		if (_depth > _harassFar && {!(_tt in _fist)}) then {_harassFar = _depth; _harassTgt = _tt};
	} forEach _tgtTowns;
};

//--- ASSIGN every ELIGIBLE team: a light MOUNTED detachment to the rear harass target (M2), the rest
//--- concentrated on the fist (reach-aware; never idle).
private ["_assigned","_harassAssigned"];
_garGrp = _logik getVariable ["wfbe_aicom_garrison", grpNull];
_assigned = 0; _harassAssigned = 0;
{
	private ["_grp","_ldr","_alive","_mode","_relief","_strike","_hasVeh","_reach","_tgt","_tgtD","_ldrPos","_v"];
	_grp = _x;
	if (!isNull _grp) then {
		_alive  = {alive _x} count (units _grp);
		_ldr    = leader _grp;
		_mode   = toLower (_grp getVariable ["wfbe_teammode", "towns"]);
		_relief = _grp getVariable ["wfbe_aicom_relief", objNull];
		_strike = _grp getVariable ["wfbe_aicom_strike", false];
		//--- ELIGIBILITY: an offensive founded/HC team Strategy hasn't claimed (relief/strike), not the base
		//--- garrison, not player-led, not under an explicit human order (move/patrol/defense).
		if (_alive > 0 && {!isNull _ldr} && {!isPlayer _ldr} && {_grp != _garGrp}
		    && {isNull _relief} && {!_strike} && {!(_mode in ["move","patrol","defense"])}
		    && {([_grp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_grp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
			_ldrPos = getPos _ldr;
			_hasVeh = false;
			{ if (alive _x && {(vehicle _x) != _x} && {canMove (vehicle _x)} && {!((vehicle _x) isKindOf "Air")}) exitWith {_hasVeh = true} } forEach (units _grp);
			_reach = if (_hasVeh) then {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED", 9000]} else {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_FOOT", 3500]};
			_tgt = objNull; _tgtD = 1e9;
			//--- M2: the first few MOUNTED teams take the rear harass target (the long rear leg needs wheels).
			if (!isNull _harassTgt && {_harassAssigned < _harassN} && {_hasVeh}) then {
				_tgt = _harassTgt; _harassAssigned = _harassAssigned + 1;
			} else {
				//--- concentrate on the fist: nearest in reach; else nearest outright (stay offensive, never idle).
				{ _v = _ldrPos distance _x; if (_v <= _reach && {_v < _tgtD}) then {_tgtD = _v; _tgt = _x} } forEach _fist;
				if (isNull _tgt) then { { _v = _ldrPos distance _x; if (_v < _tgtD) then {_tgtD = _v; _tgt = _x} } forEach _fist };
			};
			if (!isNull _tgt) then {
				_grp setVariable ["wfbe_aicom_alloc_target", _tgt];
				_grp setVariable ["wfbe_aicom_alloc_tick", time];
				_assigned = _assigned + 1;
			};
		};
	};
} forEach _teams;

diag_log ("AICOM2|v1|ALLOC|" + str _side + "|" + str (round (time / 60)) + "|fist=" + str (count _fist) + "|primary=" + ((_fist select 0) getVariable ["name","?"]) + "|harassTo=" + (if (!isNull _harassTgt) then {_harassTgt getVariable ["name","?"]} else {"none"}) + "|assigned=" + str _assigned + "|harass=" + str _harassAssigned + "|teams=" + str (count _teams));
