/*
	AI_Commander_Allocate.sqf - AICOM v2 SINGLE OFFENSIVE AUTHORITY (M1 + M2 + M4 + M5). Server-side, per side.
	Param: _this = side. Runs AFTER the M0 snapshot + the legacy Strategy worker each strategy tick (so its
	target choice WINS), gated by WFBE_C_AICOM2_ALLOCATE_ENABLE (0 = inert -> legacy path = instant rollback).

	It CONCENTRATES force on ONE front "fist" (Ray steamroller, WFBE_C_AICOM2_FIST_TOWNS default 1) and assigns
	EVERY eligible team to it, reach-aware. The fist is chosen by PRECEDENCE:
	  1) M4 COMMANDER FOCUS  - if the human commander set a fresh side focus town, that IS the fist (override).
	  2) M5 SUPPORT-PUSH     - else if humans are on this side, bias the fist toward where they are massed
	                           (support the players' advance, not auto-pick the geometric front).
	  3) AUTO                - else the top capturable town(s) nearest our front (coherent-front concentration).
	M2 HARASS: a light MOUNTED detachment (WFBE_C_AICOM2_HARASS_TEAMS) peels to the enemy's DEEPEST capturable
	town (rear / supply hub), forcing them to cover their back-line; the rest stay on the fist.

	Mechanism: per-team `wfbe_aicom_alloc_target` (a town) that AssignTowns then executes (route/dispatch/stuck
	reused). Publishes the fist into `wfbe_aicom_targets` (MHQReloc + intent HUD read it).

	OFFENSE-ONLY: never recalls/defends. RESPECTS Strategy's relief/last-stand/strike (skips flagged teams, read
	LIVE) + the base garrison + player-led + explicit-human-mode teams. A2-OA-safe (snapshot for tick-stable town
	data; live group reads per-team; GroupGetBool for the A2 group-bool trap; no A3 commands).
*/

private ["_side","_sideID","_enemyID","_logik","_snap","_tgtTowns","_ownTowns","_myHQ","_teams","_fist","_garGrp","_harassTgt","_harassN","_frontDist","_expandN","_neutTowns","_expandCount","_myTowns","_engageMin","_expandFirst","_concentrate"];
_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) <= 0) exitWith {};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_snap = _logik getVariable ["wfbe_aicom2_snap", []];
if (count _snap < 26) exitWith {};   //--- no / short snapshot yet (26 fields, indices 0..25)
_sideID   = _snap select WFBE_SNAP_SIDEID;
_enemyID  = _snap select WFBE_SNAP_ENID;
_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;   //--- capturable enemy/neutral towns
_ownTowns = _snap select WFBE_SNAP_OWNTOWNOBJS;
_myHQ     = _snap select WFBE_SNAP_MYHQ;
_teams    = _logik getVariable ["wfbe_teams", []];
if (count _tgtTowns == 0) exitWith { _logik setVariable ["wfbe_aicom_targets", []] };   //--- nothing to take

//--- EXPANSION-FIRST GATE (Ray 2026-06-28): until this side OWNS >= WFBE_C_AICOM_ENGAGE_MIN_TOWNS towns it does NOT
//--- attack the enemy - the fist + rear-harass target NEUTRAL towns only, so both commanders build an empire before
//--- they clash (stops the early enemy-rush that ends matches prematurely). ANTI-STALL: if no neutral town remains
//--- capturable it falls through and engages the enemy (never idle). The HQ-strike round-ender keeps its own gate.
_myTowns   = _snap select WFBE_SNAP_MYTOWNS;
_engageMin = missionNamespace getVariable ["WFBE_C_AICOM_ENGAGE_MIN_TOWNS", 10];
//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) POSTURE HOOK: a fresh player PUSH/HOLD biases the ENGAGE gate only (small).
private ["_psPair","_psPos","_psT0","_psDelta"];
_psPair = _logik getVariable "wfbe_aicom_player_posture";
_psT0   = _logik getVariable "wfbe_aicom_player_posture_t0";
if (!isNil "_psPair" && {typeName _psPair == "STRING"} && {!isNil "_psT0"} && {(time - _psT0) < (missionNamespace getVariable ["WFBE_C_AICOM_POSTURE_TTL", 300])}) then {
	_psDelta = missionNamespace getVariable ["WFBE_C_AICOM_POSTURE_ENGAGE_DELTA", 4];
	if (_psPair == "PUSH") then {_engageMin = (_engageMin - _psDelta) max 0};
	if (_psPair == "HOLD") then {_engageMin = _engageMin + _psDelta};
};
//--- cmdcon27 THREAD C FIELD-ORDER HOOK: read the ONE consolidated player field-order stamp once (string + t0),
//--- fresh within WFBE_C_AICOM_POSTURE_TTL (reused). _foPos in SPLIT/MASS/HARASS/FALLBACK; levers applied in
//--- ORDER below (engage here, _fistMax before its :129 consumption, expand/harass/concentrate after :160).
private ["_foPos","_foT0","_foFresh"];
_foFresh = false; _foPos = "";
_foPos = _logik getVariable "wfbe_aicom_player_fieldorder";
_foT0  = _logik getVariable "wfbe_aicom_player_fieldorder_t0";
if (!isNil "_foPos" && {typeName _foPos == "STRING"} && {!isNil "_foT0"} && {(time - _foT0) < (missionNamespace getVariable ["WFBE_C_AICOM_POSTURE_TTL", 300])}) then {
	_foFresh = true;
} else {
	_foPos = "";
};
//--- FALLBACK engage lever (lands between the posture engage bias and the :54 _engageMin consumption): push the
//--- engage threshold UP so the side stops clashing and pulls back to owned towns.
if (_foFresh && {_foPos == "FALLBACK"}) then {_engageMin = _engageMin + (missionNamespace getVariable ["WFBE_C_AICOM_NUDGE_FALLBACK_DELTA", 20])};
_expandFirst = false;
if (_engageMin > 0 && {_myTowns < _engageMin}) then {
		private ["_neutPool","_sid","_guerID","_softPool"];
		_neutPool = [];
		_softPool = [];
		_guerID = WFBE_C_GUER_ID;   //--- GUER/resistance own-id (towns held/garrisoned by GUER carry this sideID)
		{
			_sid = _x getVariable ["sideID", -1];
			if (_sid != _sideID && {_sid != _enemyID}) then {
				_neutPool set [count _neutPool, _x];
				if (_sid != _guerID) then {_softPool set [count _softPool, _x]};
			};
		} forEach _tgtTowns;
		//--- PREFER NEUTRAL (Ray 2026-06-28): target SOFT (GUER-free) neutral towns first so the concentrate fist
		//--- never pins on a reinforcing GUER fortress (e.g. Berezino) while easy towns sit free; fall back to the
		//--- GUER-inclusive pool only when no soft neutral remains, so it still never idles.
		if (count _softPool > 0) then {_tgtTowns = _softPool; _expandFirst = true} else {
			if (count _neutPool > 0) then {_tgtTowns = _neutPool; _expandFirst = true};
		};
		diag_log ("AICOM2|v1|FISTPOOL|" + str _side + "|soft=" + str (count _softPool) + "|neutInclGuer=" + str (count _neutPool) + "|using=" + (if (count _softPool > 0) then {"soft"} else {"neut"}));
};

//--- helper: a town's distance to OUR nearest front (own town, else our HQ) = how forward it is.
_frontDist = {
	private ["_tt","_dNear","_d"];
	_tt = _this; _dNear = 1e9;
	{ _d = _tt distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTowns;
	if (_dNear > 1e8) then { _dNear = if (!isNull _myHQ) then {_tt distance _myHQ} else {0} };
	_dNear
};

//--- BUILD THE FIST by precedence: M4 commander focus -> M5 support-push -> AUTO nearest-front.
_fist = [];
private ["_fromFocus","_focusTgt","_focusT0"];
_fromFocus = false;
_focusTgt = _logik getVariable "wfbe_aicom_focus";
_focusT0  = _logik getVariable "wfbe_aicom_focus_t0";
//--- M4: a fresh, still-capturable commander focus town overrides everything (honoured EVERY tick because
//--- the Allocator is the single author - this is what makes the command center actually steer the AI).
if (!isNil "_focusTgt" && {!isNull _focusTgt} && {!isNil "_focusT0"}
    && {(time - _focusT0) < (missionNamespace getVariable ["WFBE_C_AICOM2_FOCUS_TTL", 600])}
    && {(_focusTgt getVariable ["sideID", _sideID]) != _sideID}) then {
	_fist = [_focusTgt]; _fromFocus = true;
};

if (!_fromFocus) then {
	//--- M5 SUPPORT-PUSH: if humans are on this side, pull the fist toward where they are massed (HC bodies
	//--- are CIV-sided so the west/east side test excludes them). Supports the players' axis, not the geometry.
	private ["_supportOn","_supportCen","_hN","_hx","_hy","_hcU"];
	_supportOn = false; _supportCen = [0,0,0];
	//--- M5 FIX (wiki cross-check): HC bodies report isPlayer=true + side west/east on this 2-HC mission, so
	//--- the raw scan folded a parked HC into the support centroid and steered the fist toward it even on an
	//--- AI-vs-AI round. Gate on the snapshot's HC-FILTERED myPlayers AND exclude HC unit bodies from the scan.
	if ((missionNamespace getVariable ["WFBE_C_AICOM2_SUPPORT_PUSH", 1]) > 0 && {(_snap select WFBE_SNAP_MYPLAYERS) > 0}) then {
		_hcU = [];
		{ if (!isNull _x) then { { _hcU set [count _hcU, _x] } forEach (units _x) } } forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
		_hN = 0; _hx = 0; _hy = 0;
		{ if (isPlayer _x && {(side _x) == _side} && {alive _x} && {!(_x in _hcU)}) then {_hx = _hx + ((getPos _x) select 0); _hy = _hy + ((getPos _x) select 1); _hN = _hN + 1} } forEach playableUnits;
		if (_hN > 0) then {_supportCen = [_hx / _hN, _hy / _hN, 0]; _supportOn = true};
	};
	//--- AUTO scorer: nearest-front + value, with an optional support-push pull toward the human axis.
	private ["_fistMax","_frontRad","_distDiv","_farPen","_supDiv","_scored","_i","_nearBand","_nearBandDist","_nearBandBonus"];
	_fistMax  = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_TOWNS", 1];
	_frontRad = missionNamespace getVariable ["WFBE_C_AICOM_FRONTIER_RADIUS", 3000];
	_distDiv  = missionNamespace getVariable ["WFBE_C_AICOM_DISTANCE_DIVISOR", 50]; if (_distDiv <= 0) then {_distDiv = 1};
	_farPen   = missionNamespace getVariable ["WFBE_C_AICOM_FAR_PENALTY", 1000];
	_supDiv        = missionNamespace getVariable ["WFBE_C_AICOM2_SUPPORT_DIVISOR", 50]; if (_supDiv <= 0) then {_supDiv = 1};
	_nearBand      = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND", 0];
	_nearBandDist  = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND_DIST", 2000];
	_nearBandBonus = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND_BONUS", 300];
	_scored = [];
	{
		private ["_tt","_dNear","_sc"];
		_tt = _x; _dNear = _tt Call _frontDist;
		_sc = (_tt getVariable ["supplyValue", 0]) - (_dNear / _distDiv);
		if (_dNear > _frontRad) then {_sc = _sc - _farPen};
		if (_nearBand > 0 && {_dNear < _nearBandDist}) then {_sc = _sc + _nearBandBonus};   //--- F5: near-band bonus for towns immediately adjacent to our front (re-ranks; does not change eligibility).
		if (_supportOn) then {_sc = _sc - ((_tt distance _supportCen) / _supDiv)};   //--- pull toward the players
		_scored set [count _scored, [_sc, _tt]];
	} forEach _tgtTowns;
	//--- cmdcon27 THREAD C: _fistMax field-order lever - MUST land before its consumption just below.
	if (_foFresh) then {
		if (_foPos == "SPLIT") then {_fistMax = _fistMax max (missionNamespace getVariable ["WFBE_C_AICOM_NUDGE_SPLIT_FIST", 3])};
		if (_foPos == "MASS" || _foPos == "FALLBACK") then {_fistMax = 1};
	};
	for "_i" from 1 to (_fistMax min (count _tgtTowns)) do {
		private ["_best","_bestSc"]; _best = objNull; _bestSc = -1e9;
		{ if (!((_x select 1) in _fist) && {(_x select 0) > _bestSc}) then {_bestSc = _x select 0; _best = _x select 1} } forEach _scored;
		if (!isNull _best) then {_fist set [count _fist, _best]};
	};
};
if (count _fist == 0) exitWith {};

//--- CONSOLIDATE (Ray): when the AUTO fist advances OFF a town we now own (= a fresh capture), stamp a hold
//--- window so AssignTowns pauses re-tasking ~WFBE_C_AICOM2_CONSOLIDATE_SECS (teams regroup at the just-taken
//--- town before pushing the next). Skipped under a commander FOCUS (they want the move now).
if (!_fromFocus) then {
	private ["_autoPrim","_prevAuto"];
	_autoPrim = _fist select 0;
	_prevAuto = _logik getVariable "wfbe_aicom_auto_primary";
	if (!isNil "_prevAuto" && {!isNull _prevAuto} && {_prevAuto != _autoPrim} && {(_prevAuto getVariable ["sideID", -1]) == _sideID}) then {
		_logik setVariable ["wfbe_aicom_consolidate_until", time + (missionNamespace getVariable ["WFBE_C_AICOM2_CONSOLIDATE_SECS", 60])];
	};
	_logik setVariable ["wfbe_aicom_auto_primary", _autoPrim];
};

_logik setVariable ["wfbe_aicom_targets", _fist];   //--- the fist is the side's published main effort

//--- M2 HARASS TARGET: the enemy's DEEPEST capturable town (max front-distance), enemy-held weighted over
//--- neutral, excluding the fist. A light mounted detachment raids it to pressure their rear / supply hub.
_harassN  = missionNamespace getVariable ["WFBE_C_AICOM2_HARASS_TEAMS", 1];
if (_expandFirst) then {_harassN = 0};   //--- expansion-first: no enemy-rear raid until the engage threshold
_expandN  = missionNamespace getVariable ["WFBE_C_AICOM2_EXPAND_TEAMS", 3];
//--- CONCENTRATE-FIRST (Ray 2026-06-28): until we own WFBE_C_AICOM_CONCENTRATE_TOWNS towns, put FULL strength on the ONE fist
//--- town - no expand/harass split (opening steamroller). After that the normal spread resumes. Layered under the engage gate.
_concentrate = (_myTowns < (missionNamespace getVariable ["WFBE_C_AICOM_CONCENTRATE_TOWNS", 4]));
if (_concentrate) then {_expandN = 0; _harassN = 0};
//--- cmdcon27 THREAD C: field-order spread levers (applied AFTER the concentrate gate so they win). _fistMax was
//--- already shifted before its :129 consumption above; here we steer the expand/harass/concentrate split.
if (_foFresh) then {
	switch (_foPos) do {
		case "SPLIT": {
			_expandN = _expandN max (missionNamespace getVariable ["WFBE_C_AICOM_NUDGE_SPLIT_EXPAND", 4]);
			_harassN = _harassN max 1;
			_concentrate = false;
		};
		case "MASS": {
			_expandN = 0; _harassN = 0; _concentrate = true;
		};
		case "HARASS": {
			//--- send many mounted rear-raid teams; keep the main fist/concentrate as-is (do NOT zero them).
			_harassN = _harassN max (missionNamespace getVariable ["WFBE_C_AICOM_NUDGE_HARASS_TEAMS", 4]);
		};
		case "FALLBACK": {
			//--- stop clashing / pull back to owned towns (engage already raised; _fistMax already forced to 1).
			_expandN = 0; _harassN = 0;
		};
	};
};
_harassTgt = objNull;
if (_harassN > 0) then {
	private ["_harassFar"];
	_harassFar = -1;
	if ((missionNamespace getVariable ["WFBE_C_AICOM_HARASS_FALLBACK", 0]) > 0) then {
		//--- HARASS FALLBACK (block-m): pick deepest town reachable by >=1 mounted eligible team.
		//--- Pre-scan: collect positions of eligible mounted teams so we can test reachability upfront.
		private ["_hfMntPos","_hfMntReach","_hfGrp","_hfLdr","_hfMode","_hfRelief","_hfStrike","_hfHasVeh","_hfGar"];
		_hfMntPos   = [];
		_hfMntReach = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED", 9000];
		_hfGar      = _logik getVariable ["wfbe_aicom_garrison", grpNull];
		{
			_hfGrp = _x;
			if (!isNull _hfGrp) then {
				_hfLdr    = leader _hfGrp;
				_hfMode   = toLower (_hfGrp getVariable ["wfbe_teammode", "towns"]);
				_hfRelief = _hfGrp getVariable ["wfbe_aicom_relief", objNull];
				_hfStrike = _hfGrp getVariable ["wfbe_aicom_strike", false];
				_hfHasVeh = false;
				{ if (alive _x && {(vehicle _x) != _x} && {canMove (vehicle _x)} && {!((vehicle _x) isKindOf "Air")}) exitWith {_hfHasVeh = true} } forEach (units _hfGrp);
				if (_hfHasVeh && {({alive _x} count (units _hfGrp)) > 0} && {!isNull _hfLdr} && {!isPlayer _hfLdr}
				    && {_hfGrp != _hfGar} && {isNull _hfRelief} && {!_hfStrike}
				    && {!(_hfMode in ["move","patrol","defense"])}
				    && {([_hfGrp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_hfGrp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
					_hfMntPos set [count _hfMntPos, getPos _hfLdr];
				};
			};
		} forEach _teams;
		//--- Build depth-scored list, then insertion-sort descending (deepest first). A2-OA safe (no apply/sort).
		private ["_hfCands","_hfI","_hfJ","_hfTmp","_hfPair","_hfDepth","_hfTown","_hfReach","_hfPos","_hfSkip","_hfFirst"];
		_hfCands = [];
		{
			private ["_tt","_depth"];
			_tt = _x;
			_depth = (_tt Call _frontDist) + (if ((_tt getVariable ["sideID", -1]) == _enemyID) then {3000} else {0});
			if (!(_tt in _fist)) then {_hfCands set [count _hfCands, [_depth, _tt]]};
		} forEach _tgtTowns;
		_hfI = 1;
		while {_hfI < (count _hfCands)} do {
			_hfJ   = _hfI;
			_hfTmp = _hfCands select _hfI;
			while {_hfJ > 0 && {((_hfCands select (_hfJ - 1)) select 0) < (_hfTmp select 0)}} do {
				_hfCands set [_hfJ, _hfCands select (_hfJ - 1)];
				_hfJ = _hfJ - 1;
			};
			_hfCands set [_hfJ, _hfTmp];
			_hfI = _hfI + 1;
		};
		//--- Walk sorted candidates; pick deepest with >= 1 mounted team in reach.
		_hfSkip  = false; _hfFirst = objNull;
		{
			_hfPair  = _x;
			_hfDepth = _hfPair select 0;
			_hfTown  = _hfPair select 1;
			_hfReach = false;
			{ _hfPos = _x; if ((_hfPos distance _hfTown) <= _hfMntReach) exitWith {_hfReach = true} } forEach _hfMntPos;
			if (_hfReach) then {
				if (isNull _harassTgt) then {_harassTgt = _hfTown; _harassFar = _hfDepth; exitWith {}};
			} else {
				if (isNull _hfFirst && {isNull _harassTgt}) then {_hfFirst = _hfTown; _hfSkip = true};
			};
		} forEach _hfCands;
		if (_hfSkip) then {
			diag_log ("AICOMSTAT|v2|EVENT|HARASS_SKIP|" + str _side + "|skipped=" + (_hfFirst getVariable ["name","?"]) + "|pickedReachable=" + (if (!isNull _harassTgt) then {_harassTgt getVariable ["name","?"]} else {"none"}));
		};
	} else {
		//--- legacy path (WFBE_C_AICOM_HARASS_FALLBACK=0): byte-identical simple deepest pick.
		{
			private ["_tt","_depth"];
			_tt = _x;
			_depth = (_tt Call _frontDist) + (if ((_tt getVariable ["sideID", -1]) == _enemyID) then {3000} else {0});
			if (_depth > _harassFar && {!(_tt in _fist)}) then {_harassFar = _depth; _harassTgt = _tt};
		} forEach _tgtTowns;
	};
};

//--- M? EXPANSION LANE (Ray, Issue 5): the capturable list includes ~42 NEUTRAL/uncaptured towns the all-in
//--- fist ignores. Build _neutTowns = capturable towns whose sideID is NEITHER mine NOR the enemy's (so truly
//--- neutral) and that are NOT the fist; up to _expandN teams peel off to take their nearest REACHABLE one.
_neutTowns = [];
{
	private ["_tt","_sid"];
	_tt = _x;
	_sid = _tt getVariable ["sideID", -1];
	if (_sid != _sideID && {_sid != _enemyID} && {!(_tt in _fist)}) then {
		_neutTowns set [count _neutTowns, _tt];
	};
} forEach _tgtTowns;

//--- ASSIGN every ELIGIBLE team: a light MOUNTED detachment to the rear harass target (M2), up to _expandN
//--- teams to capture NEUTRAL towns (expansion lane), the rest concentrated on the fist (reach-aware; never idle).
private ["_assigned","_harassAssigned","_expandClaimed","_dedupOn"];
_garGrp = _logik getVariable ["wfbe_aicom_garrison", grpNull];
_assigned = 0; _harassAssigned = 0; _expandCount = 0;
_expandClaimed = [];   //--- DEDUP (block-m): neutral towns already claimed by an expand-lane team this tick
//--- SPREAD (cmdcon41, claude-gaming 2026-07-02): per-fist-town load counter + cap. With a widened fist
//--- (WFBE_C_AICOM2_FIST_TOWNS>1) the L268-272 nearest pick otherwise funnels every team onto the single
//--- closest fist town = the dogpile. _fistCounts is index-aligned with _fist; _capPerFist caps stacking
//--- per fist town before teams spill onto the next. A2-OA-safe (count / array set-select / getVariable).
private ["_fistCounts","_capPerFist"];
_fistCounts = []; { _fistCounts set [_forEachIndex, 0] } forEach _fist;
_capPerFist = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_PERTOWN", 4];
_dedupOn = (missionNamespace getVariable ["WFBE_C_AICOM_EXPAND_DEDUP", 0]) > 0;
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
		    && {(_grp getVariable ["wfbe_aicom_feint_expiry", 0]) <= 0}   //--- FIX(review CRITICAL): skip feint-tagged teams so the feint alloc_target survives across ticks
		    && {([_grp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_grp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
			_ldrPos = getPos _ldr;
			_hasVeh = false;
			{ if (alive _x && {(vehicle _x) != _x} && {canMove (vehicle _x)} && {!((vehicle _x) isKindOf "Air")}) exitWith {_hasVeh = true} } forEach (units _grp);
			_reach = if (_hasVeh) then {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED", 9000]} else {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_FOOT", 3500]};
			_tgt = objNull; _tgtD = 1e9;
			//--- M2: the first few MOUNTED teams take the rear harass target (the long rear leg needs wheels).
			//--- REACH GATE (Ray): only take the harass target if it is within _reach of the team leader; otherwise
			//--- fall through to the fist else-branch (stay offensive on a REACHABLE town). Without this a mounted team
			//--- could be sent on a cross-map death-march to the enemy's deepest town.
			if (!isNull _harassTgt && {_harassAssigned < _harassN} && {_hasVeh} && {(_ldrPos distance _harassTgt) <= _reach}) then {
				_tgt = _harassTgt; _harassAssigned = _harassAssigned + 1;
			} else {
				//--- EXPANSION LANE (Issue 5): up to _expandN teams grab their NEAREST REACHABLE neutral town
				//--- (manual min loop - no A3 sort/apply). Capped by _expandCount; falls through to the fist if
				//--- this team has no reachable neutral town or the expansion quota is already spent.
				if (_expandCount < _expandN) then {
					private ["_eTgt","_eD","_ev"];
					_eTgt = objNull; _eD = 1e9;
					//--- DEDUP (block-m, WFBE_C_AICOM_EXPAND_DEDUP): skip towns already claimed this tick
					if (_dedupOn) then {
						{ _ev = _ldrPos distance _x; if (_ev <= _reach && {_ev < _eD} && {!(_x in _expandClaimed)}) then {_eD = _ev; _eTgt = _x} } forEach _neutTowns;
					} else {
						{ _ev = _ldrPos distance _x; if (_ev <= _reach && {_ev < _eD}) then {_eD = _ev; _eTgt = _x} } forEach _neutTowns;
					};
					if (!isNull _eTgt) then {
						_tgt = _eTgt; _expandCount = _expandCount + 1;
						if (_dedupOn) then {
							_expandClaimed set [count _expandClaimed, _eTgt];
						};
					};
				};
				if (isNull _tgt) then {
					//--- concentrate on the fist. SPREAD (cmdcon41): cap-aware nearest pick so teams fan across the
					//--- widened fist instead of dogpiling the single closest town. Legacy (SPREAD_MODE=0) keeps the
					//--- verbatim uncapped nearest-then-nearest pick = instant rollback. Never idle: if every reachable
					//--- fist town is capped we spill onto the LEAST-LOADED fist town outright.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_SPREAD_MODE", 1]) > 0) then {
						private ["_bestIdx"];
						//--- pass 1: nearest in-reach fist town whose count is still below the per-town cap.
						_bestIdx = -1;
						{
							_v = _ldrPos distance _x;
							if (_v <= _reach && {_v < _tgtD} && {(_fistCounts select _forEachIndex) < _capPerFist}) then {_tgtD = _v; _tgt = _x; _bestIdx = _forEachIndex};
						} forEach _fist;
						//--- fall-through: everything in reach is capped (or nothing in reach) -> pick the LEAST-LOADED
						//--- fist town outright so no team idles (preserves the never-idle SAD guarantee).
						if (isNull _tgt) then {
							private ["_leastLoad"];
							_leastLoad = 1e9;
							{
								if ((_fistCounts select _forEachIndex) < _leastLoad) then {_leastLoad = _fistCounts select _forEachIndex; _tgt = _x; _bestIdx = _forEachIndex};
							} forEach _fist;
						};
						//--- book the chosen fist town so the next team sees the updated load.
						if (_bestIdx >= 0) then {_fistCounts set [_bestIdx, (_fistCounts select _bestIdx) + 1]};
					} else {
						//--- concentrate on the fist: nearest in reach; else nearest outright (stay offensive, never idle).
						{ _v = _ldrPos distance _x; if (_v <= _reach && {_v < _tgtD}) then {_tgtD = _v; _tgt = _x} } forEach _fist;
						if (isNull _tgt) then { { _v = _ldrPos distance _x; if (_v < _tgtD) then {_tgtD = _v; _tgt = _x} } forEach _fist };
					};
				};
			};
			if (!isNull _tgt) then {
				_grp setVariable ["wfbe_aicom_alloc_target", _tgt];
				_grp setVariable ["wfbe_aicom_alloc_tick", time];
				_assigned = _assigned + 1;
			};
		};
	};
} forEach _teams;

//--- D7 AICOM FEINT: optional feint dispatch. Self-contained, flag-gated (WFBE_C_AICOM_FEINT_ENABLE).
//--- Runs AFTER the main ASSIGN loop so the feint write is the LAST write to wfbe_aicom_alloc_target this tick (wins).
//--- Recall pass runs every tick (clears expired feint tags -> main fist/loop picks up the team next tick).
//--- Dispatch pass runs when the per-side cooldown has elapsed and conditions are met.
//--- HARD-COLLISION NOTE: this entire block is a new addition; no existing line is modified.
//--- Rebase after PR #286 (F5) which modifies AI_Commander_Allocate.sqf.
if ((missionNamespace getVariable ["WFBE_C_AICOM_FEINT_ENABLE", 0]) > 0 && {!_expandFirst} && {!_concentrate}) then {
	private ["_feintTgt","_feintTeam","_feintT0","_feintDur","_feintInterval","_feintGrp","_feintLdr","_feintAlive","_feintMode","_feintRelief","_feintStrike","_feintHasVeh","_feintExpiry","_feintRecalled","_feintFar","_feintD","_feintI","_feintGarGrp"];
	_feintGarGrp   = _logik getVariable ["wfbe_aicom_garrison", grpNull];   //--- FIX(review HIGH): read garrison before team-picker uses it
	_feintInterval = missionNamespace getVariable ["WFBE_C_AICOM_FEINT_INTERVAL", 600];
	_feintDur      = missionNamespace getVariable ["WFBE_C_AICOM_FEINT_DUR", 120];
	_feintT0       = _logik getVariable ["wfbe_aicom_feint_t0", -1e9];

	//--- RECALL PASS: on every tick check all teams for an EXPIRED feint tag and redirect to the fist.
	_feintRecalled = false;
	{
		_feintGrp    = _x;
		_feintExpiry = _feintGrp getVariable ["wfbe_aicom_feint_expiry", 0];
		if (!isNull _feintGrp && {_feintExpiry > 0} && {time > _feintExpiry}) then {
			_feintGrp setVariable ["wfbe_aicom_feint_expiry", 0];
			if (count _fist > 0) then {
				_feintGrp setVariable ["wfbe_aicom_alloc_target", (_fist select 0)];
				_feintGrp setVariable ["wfbe_aicom_alloc_tick", time];
				diag_log ("AICOM2|v1|FEINT|RECALL|" + str _side + "|" + str (round (time / 60)) + "|team=" + str _feintGrp + "|returnTo=" + ((_fist select 0) getVariable ["name","?"]));
			};
			_feintRecalled = true;
		};
	} forEach _teams;

	//--- DISPATCH PASS: only when cooldown elapsed AND no recall happened this tick (FIX(review LOW): skip same-tick re-dispatch after a recall).
	if ((time - _feintT0) >= _feintInterval && {!_feintRecalled}) then {
		//--- Pick feint target: enemy-held, NOT in _fist, NOT the harass target, nearest front (most shallow = most visible distraction).
		_feintTgt  = objNull;
		_feintFar  = 1e9;
		{
			_feintD = _x Call _frontDist;
			if ((_x getVariable ["sideID", -1]) == _enemyID
				&& {!(_x in _fist)}
				&& {!(!isNull _harassTgt && {_x == _harassTgt})}
				&& {_feintD < _feintFar}) then {
				_feintFar = _feintD;
				_feintTgt = _x;
			};
		} forEach _tgtTowns;

		if (!isNull _feintTgt) then {
			//--- Pick feint team: first eligible MOUNTED team not already feint-tagged, not harass/relief/strike/garrison.
			_feintTeam = grpNull;
			_feintI    = 0;
			while {isNull _feintTeam && {_feintI < (count _teams)}} do {
				_feintGrp    = _teams select _feintI;
				_feintAlive  = {alive _x} count (units _feintGrp);
				_feintLdr    = leader _feintGrp;
				_feintMode   = toLower (_feintGrp getVariable ["wfbe_teammode", "towns"]);
				_feintRelief = _feintGrp getVariable ["wfbe_aicom_relief", objNull];
				_feintStrike = _feintGrp getVariable ["wfbe_aicom_strike", false];
				_feintExpiry = _feintGrp getVariable ["wfbe_aicom_feint_expiry", 0];
				_feintHasVeh = false;
				{ if (alive _x && {(vehicle _x) != _x} && {canMove (vehicle _x)} && {!((vehicle _x) isKindOf "Air")}) exitWith {_feintHasVeh = true} } forEach (units _feintGrp);
				if (!isNull _feintGrp && {_feintAlive > 0} && {!isNull _feintLdr} && {!isPlayer _feintLdr}
					&& {_feintGrp != _feintGarGrp} && {isNull _feintRelief} && {!_feintStrike}
					&& {!(_feintMode in ["move","patrol","defense"])}
					&& {_feintExpiry <= 0}
					&& {_feintHasVeh}
					&& {([_feintGrp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_feintGrp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
					_feintTeam = _feintGrp;
				};
				_feintI = _feintI + 1;
			};

			if (!isNull _feintTeam) then {
				_feintTeam setVariable ["wfbe_aicom_feint_expiry", time + _feintDur];
				_feintTeam setVariable ["wfbe_aicom_alloc_target", _feintTgt];
				_feintTeam setVariable ["wfbe_aicom_alloc_tick", time];
				_logik setVariable ["wfbe_aicom_feint_t0", time];
				diag_log ("AICOM2|v1|FEINT|DISPATCH|" + str _side + "|" + str (round (time / 60)) + "|feintTo=" + (_feintTgt getVariable ["name","?"]) + "|team=" + str _feintTeam + "|dur=" + str _feintDur);
			};
		};
	};
};


//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) REINFORCE HOOK: a fresh player REINFORCE order routes ONE
//--- eligible team to that town (single-team alloc_target override; reversible; auto-clears at WFBE_C_AICOM_REINFORCE_TTL).
private ["_riPair","_riTown","_riT0"];
_riPair = _logik getVariable "wfbe_aicom_reinforce";
if (!isNil "_riPair" && {typeName _riPair == "ARRAY"} && {count _riPair == 2}) then {
	_riTown = _riPair select 0;
	_riT0   = _riPair select 1;
	if (!isNull _riTown && {(time - _riT0) < (missionNamespace getVariable ["WFBE_C_AICOM_REINFORCE_TTL", 300])}) then {
		private ["_riBest","_riBestD","_riGrp","_riLdr","_riAlive","_riMode","_riRelief","_riStrike"];
		_riBest = grpNull; _riBestD = 1e9;
		{
			_riGrp = _x;
			if (!isNull _riGrp) then {
				_riAlive  = {alive _x} count (units _riGrp);
				_riLdr    = leader _riGrp;
				_riMode   = toLower (_riGrp getVariable ["wfbe_teammode", "towns"]);
				_riRelief = _riGrp getVariable ["wfbe_aicom_relief", objNull];
				_riStrike = _riGrp getVariable ["wfbe_aicom_strike", false];
				if (_riAlive > 0 && {!isNull _riLdr} && {!isPlayer _riLdr} && {_riGrp != _garGrp}
				    && {isNull _riRelief} && {!_riStrike} && {!(_riMode in ["move","patrol","defense"])}
				    && {(_riGrp getVariable ["wfbe_aicom_feint_expiry", 0]) <= 0}
				    && {([_riGrp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_riGrp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
					private ["_riD"]; _riD = (getPos _riLdr) distance _riTown;
					if (_riD < _riBestD) then {_riBestD = _riD; _riBest = _riGrp};
				};
			};
		} forEach _teams;
		if (!isNull _riBest) then {
			_riBest setVariable ["wfbe_aicom_alloc_target", _riTown];
			_riBest setVariable ["wfbe_aicom_alloc_tick", time];
			diag_log ("AICOM2|v1|REINFORCE|" + str _side + "|" + str (round (time / 60)) + "|town=" + (_riTown getVariable ["name","?"]) + "|team=" + str _riBest);
		};
	};
};

diag_log ("AICOM2|v1|ALLOC|" + str _side + "|" + str (round (time / 60)) + "|fist=" + str (count _fist) + "|primary=" + ((_fist select 0) getVariable ["name","?"]) + "|src=" + (if (_fromFocus) then {"FOCUS"} else {"auto"}) + "|harassTo=" + (if (!isNull _harassTgt) then {_harassTgt getVariable ["name","?"]} else {"none"}) + "|assigned=" + str _assigned + "|harass=" + str _harassAssigned + "|expand=" + str _expandCount + "|teams=" + str (count _teams) + "|myTowns=" + str _myTowns + "|expandFirst=" + str _expandFirst + "|concentrate=" + str _concentrate);
