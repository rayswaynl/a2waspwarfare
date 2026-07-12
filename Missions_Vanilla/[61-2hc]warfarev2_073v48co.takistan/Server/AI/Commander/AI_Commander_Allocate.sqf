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

private ["_side","_sideID","_enemyID","_logik","_snap","_tgtTowns","_ownTowns","_myHQ","_teams","_fist","_garGrp","_harassTgt","_harassFar","_harassN","_frontDist","_expandN","_neutTowns","_expandCount","_expandWarnTown","_expandWarnDist","_myTowns","_engageMin","_expandFirst","_concentrate","_pfEnTowns","_pfMyEff","_pfEnEff","_pfDominant"];
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
//--- FIX C: DOMINANT-SIDE PRESS FLOOR V2 (fable, GR-2026-07-08a; own-metrics; design ASSAULT-DYNTIMEOUT-DESIGN.md
//--- + ADDENDUM 1 S3). Computed here, before any BUG-1/BUG-2/WO-6 block below, so it has zero ordering
//--- dependency on them - own _pfEnTowns local, not a reuse of BUG-1's _enTownsSnap further down.
_pfEnTowns  = _snap select WFBE_SNAP_ENTOWNS;
_pfMyEff    = _snap select WFBE_SNAP_MYEFF;
_pfEnEff    = _snap select WFBE_SNAP_ENEFF;
_pfDominant = ((missionNamespace getVariable ["WFBE_C_AICOM_PRESS_FLOOR_V2", 0]) > 0) && {_myTowns >= _pfEnTowns} && {_pfMyEff >= (_pfEnEff * (missionNamespace getVariable ["WFBE_C_AICOM2_PRESS_DOM_RATIO", 1.15]))};   //--- ratio read deferred into the lazy && {} term so it is NEVER read at flag-off (inertness).
if (_pfDominant) then {
	diag_log ("AICOMSTAT|v2|EVENT|" + str _side + "|" + str (round (time / 60)) + "|DOMPRESS_V2|myTowns=" + str _myTowns + "|enTowns=" + str _pfEnTowns + "|myEff=" + str _pfMyEff + "|enEff=" + str _pfEnEff + "|ratio=" + str (missionNamespace getVariable ["WFBE_C_AICOM2_PRESS_DOM_RATIO", 1.15]));   //--- re-read for logging only - this branch only runs when _pfDominant is already true (flag already on), so this does not affect flag-off inertness.
};
//--- WO-6 SOFTEST-LANE PUSH (fable, GR-2026-07-07a): after a detected town LOSS for this side, temporarily
//--- ADD AICOMV2_SOFTLANE_BONUS to neutral/GUER-only capturable towns' scores in the AUTO scorer below for
//--- AICOMV2_SOFTLANE_TICKS strategy ticks, so the fist leans toward the least-defended next target instead
//--- of the obvious counter-attack on the town just lost (owner intent, V2 doc AICOM-V2-UNIT-MICRO-LAYER-SPEC
//--- WO-6 "softest-lane push"). Loss = this tick's MYTOWNS below the cached previous-tick count; the window
//--- is stamped on the side logic and consumed by the scorer forEach below. Distinct lever from BUG-2
//--- REPICK-PENALTY just below: REPICK discourages re-picking ANY recently-published fist primary; this ADDS
//--- score to SOFT (non-enemy) towns broadly. The lost town itself may carry both a repick penalty (if it was
//--- the recent primary) and, once reverted to neutral, the soft bonus - they partially offset there, which
//--- matches the "no auto-recapture" spec intent while other soft towns still gain the full bonus. Default
//--- AICOMV2_SOFTLANE_BONUS 0 = fully inert: no state read/write beyond the one getVariable below.
private ["_softlaneBonus"];
_softlaneBonus = missionNamespace getVariable ["AICOMV2_SOFTLANE_BONUS", 0];
if (_softlaneBonus > 0) then {
	private ["_slPrevTowns","_slTicks","_slUntil"];
	_slPrevTowns = _logik getVariable ["wfbe_aicom_softlane_prevtowns", _myTowns];
	if (_myTowns < _slPrevTowns) then {
		_slTicks = missionNamespace getVariable ["AICOMV2_SOFTLANE_TICKS", 3];
		_slUntil = time + (_slTicks * (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL", 60]));
		_logik setVariable ["wfbe_aicom_softlane_until", _slUntil];
		diag_log ("AICOM2|v1|SOFTLANE|" + str _side + "|loss=" + str _slPrevTowns + "->" + str _myTowns + "|until=" + str _slUntil);
	};
	_logik setVariable ["wfbe_aicom_softlane_prevtowns", _myTowns];
};
_engageMin = missionNamespace getVariable ["WFBE_C_AICOM_ENGAGE_MIN_TOWNS", 10];
//--- BUG-1 CONTESTED-ENGAGE (fable, GR-2026-07-03a): the expansion-first gate below pins this side to NEUTRAL-only
//--- targets until it owns _engageMin towns. A side that stalls BELOW that count while the enemy holds towns then
//--- targets neutral towns forever and NEVER attacks the enemy (the 9.6h ZG soak: WEST published ZERO capture orders
//--- vs EAST-held towns for 9.5h). Lift the gate when the enemy is at town-parity-or-ahead AND holds >=1 town, so a
//--- side that is behind/contested fights the enemy instead of wandering the rear. WEST=0-safe: only COUNT (>=)
//--- compares, never a side-ID truthiness test. Flag WFBE_C_AICOM_ENGAGE_CONTESTED default 1 (0 = legacy, instant rollback).
private ["_enTownsSnap","_engContested"];
_enTownsSnap = _snap select WFBE_SNAP_ENTOWNS;
_engContested = ((missionNamespace getVariable ["WFBE_C_AICOM_ENGAGE_CONTESTED", 1]) > 0) && {_enTownsSnap > 0} && {_enTownsSnap >= _myTowns};
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
if (_engageMin > 0 && {_myTowns < _engageMin} && {!_engContested} && {!(_pfDominant && {(missionNamespace getVariable ["WFBE_C_AICOM2_PRESS_ENGAGE_BYPASS", 1]) > 0})}) then {   //--- FIX C (fable, GR-2026-07-08a): OR-compose with BUG-1 - bypass the neutral-only gate when EITHER the enemy is contested-ahead OR we are dominant.
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
	//--- AUTO scorer: nearest-front + value, with optional support-push and default-off garrison softness terms.
	private ["_fistMax","_frontRad","_distDiv","_farPen","_supDiv","_scored","_i","_nearBand","_nearBandDist","_nearBandBonus","_garPen"];
	_fistMax  = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_TOWNS", 1];
	if (_pfDominant) then {   //--- FIX C Tier 2 (fable, GR-2026-07-08a, optional/dark). Read gated behind _pfDominant so PRESS_FIST_BONUS is never read at flag-off/non-dominant (inertness).
		private "_pfFistBonus"; _pfFistBonus = missionNamespace getVariable ["WFBE_C_AICOM2_PRESS_FIST_BONUS", 0];
		if (_pfFistBonus > 0) then {_fistMax = _fistMax + _pfFistBonus};   //--- default 0 = no-op.
	};
	_frontRad = missionNamespace getVariable ["WFBE_C_AICOM_FRONTIER_RADIUS", 3000];
	_distDiv  = missionNamespace getVariable ["WFBE_C_AICOM_DISTANCE_DIVISOR", 50]; if (_distDiv <= 0) then {_distDiv = 1};
	_farPen   = missionNamespace getVariable ["WFBE_C_AICOM_FAR_PENALTY", 1000];
	_supDiv        = missionNamespace getVariable ["WFBE_C_AICOM2_SUPPORT_DIVISOR", 50]; if (_supDiv <= 0) then {_supDiv = 1};
	_nearBand      = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND", 0];
	_nearBandDist  = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND_DIST", 2000];
	_nearBandBonus = missionNamespace getVariable ["WFBE_C_AICOM_NEAR_BAND_BONUS", 300];
	_garPen        = missionNamespace getVariable ["WFBE_C_AICOM_GARRISON_PENALTY", 0];
	//--- BUG-2 REPICK-PENALTY (fable, GR-2026-07-03a): read+prune the recent-primary memory so towns picked as the
	//--- fist primary within the last WFBE_C_AICOM_REPICK_MEMORY_MIN minutes score lower (rotate pressure, no dogpile).
	private ["_repickPen","_repickMem","_repickKeep","_repickTowns"];
	_repickPen   = missionNamespace getVariable ["WFBE_C_AICOM_REPICK_PENALTY", 500];
	_repickMem   = _logik getVariable ["wfbe_aicom_repick_mem", []];
	_repickKeep  = [];
	_repickTowns = [];
	{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_repickKeep set [count _repickKeep, _x]; _repickTowns set [count _repickTowns, (_x select 0)]} } forEach _repickMem;
	_logik setVariable ["wfbe_aicom_repick_mem", _repickKeep];
	//--- WO-6 SOFTEST-LANE: resolve once whether the loss window (stamped near the top of the script) is still
	//--- active this tick, before the scorer forEach below consumes it per-town. Off (bonus<=0 or window
	//--- expired) = _softlaneActive false = zero score change, zero extra getVariable calls per town.
	private ["_softlaneActive"];
	_softlaneActive = (_softlaneBonus > 0) && {time < (_logik getVariable ["wfbe_aicom_softlane_until", -1])};
	_softlaneActive = _softlaneActive && {!_pfDominant};   //--- FIX C x WO-6 (fable, GR-2026-07-08a, ADDENDUM 1 S1): a dominant side is not "reeling" - PRESS suppresses softlane outright. No-op at either flag off (see design).
	//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): precompute live grudge sites for the AUTO fist scorer below - this is the LIVE authority (Allocate overwrites Strategy's wfbe_aicom_targets by default)
	private ["_grudgeTowns","_grudgeBonus"];
	_grudgeTowns = []; _grudgeBonus = 0;
	if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0) then {
			_grudgeBonus = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_BONUS", 400];
			{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_grudgeTowns set [count _grudgeTowns, (_x select 0)]} } forEach (_logik getVariable ["wfbe_aicom_grudge", []]);
	};
	_scored = [];
	{
		private ["_tt","_dNear","_sc","_garTier"];
		_tt = _x; _dNear = _tt Call _frontDist;
		_sc = (_tt getVariable ["supplyValue", 0]) - (_dNear / _distDiv);
		if (_garPen > 0) then {
			_garTier = switch (_tt getVariable ["wfbe_town_type", ""]) do {
				case "TinyTown1":   {0};
				case "SmallTown1":  {1};
				case "SmallTown2":  {1};
				case "MediumTown1": {2};
				case "MediumTown2": {2};
				case "LargeTown1":  {3};
				case "LargeTown2":  {3};
				case "HugeTown1":   {4};
				case "HugeTown2":   {4};
				case "PMCAirfield": {2};
				default {1};
			};
			_sc = _sc - (_garTier * _garPen);
		};
		if (_dNear > _frontRad) then {_sc = _sc - _farPen};
		if (_nearBand > 0 && {_dNear < _nearBandDist}) then {_sc = _sc + _nearBandBonus};   //--- F5: near-band bonus for towns immediately adjacent to our front (re-ranks; does not change eligibility).
		if (_supportOn) then {_sc = _sc - ((_tt distance _supportCen) / _supDiv)};   //--- pull toward the players
		if (_repickPen > 0 && {_tt in _repickTowns}) then {_sc = _sc - _repickPen};   //--- BUG-2 anti-dogpile: recently-picked primary is deprioritised so the fist rotates.
		//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): draw the AUTO fist back to a live grudge site
		if (_grudgeBonus > 0 && {_tt in _grudgeTowns}) then {_sc = _sc + _grudgeBonus};
		if (_softlaneActive) then {
			private ["_tsid"];
			_tsid = _tt getVariable ["sideID", -1];
			if (_tsid != _sideID && {_tsid != _enemyID}) then {_sc = _sc + _softlaneBonus};   //--- WO-6 softest-lane: boost neutral/GUER-only towns over contested enemy towns during the post-loss window.
		};
		if (_pfDominant) then {   //--- FIX C (fable, GR-2026-07-08a): enemy-held score bonus. Disjoint sideID filter vs WO-6 softlane above (never double-boosts the same town); placed after WO-6 per ADDENDUM 1 S3(c).
			private "_pfBonus"; _pfBonus = missionNamespace getVariable ["WFBE_C_AICOM2_PRESS_ENEMY_BONUS", 400];
			if (_pfBonus > 0 && {(_tt getVariable ["sideID", -1]) == _enemyID}) then {_sc = _sc + _pfBonus};
		};
		if (isNil "_sc") then {
		};
		_sc = if (isNil "_sc") then {-99999} else {_sc};
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
//--- BUG-2 REPICK-MEMORY STAMP (fable, GR-2026-07-03a): remember this tick's fist primary for WFBE_C_AICOM_REPICK_MEMORY_MIN
//--- minutes so the anti-dogpile penalty above deprioritises it on the next picks. Append-and-dedup on the side logic.
if ((missionNamespace getVariable ["WFBE_C_AICOM_REPICK_PENALTY", 500]) > 0 && {count _fist > 0}) then {
	private ["_rpPrim","_rpMin","_rpMem","_rpOut"];
	_rpPrim = _fist select 0;
	_rpMin  = missionNamespace getVariable ["WFBE_C_AICOM_REPICK_MEMORY_MIN", 5];
	_rpMem  = _logik getVariable ["wfbe_aicom_repick_mem", []];
	_rpOut  = [];
	{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _rpPrim}) then {_rpOut set [count _rpOut, _x]} } forEach _rpMem;
	_rpOut set [count _rpOut, [_rpPrim, time + (_rpMin * 60)]];
	_logik setVariable ["wfbe_aicom_repick_mem", _rpOut];
};
//--- BUG-1 PROOF LINE (fable, GR-2026-07-03a): ALWAYS-ON telemetry - is the published fist primary an ENEMY-HELD town?
//--- The next soak greps AICOMSTAT|v2|EVENT|<side>|<min>|ENEMY_TOWN_TARGET to PROVE each side (esp. WEST) now attacks the enemy.
if (count _fist > 0) then {
	private ["_etPrim","_etIsEnemy"];
	_etPrim = _fist select 0;
	_etIsEnemy = (_etPrim getVariable ["sideID", -1]) == _enemyID;
	diag_log ("AICOMSTAT|v2|EVENT|" + str _side + "|" + str (round (time / 60)) + "|ENEMY_TOWN_TARGET|primary=" + (_etPrim getVariable ["name","?"]) + "|enemyHeld=" + (if (_etIsEnemy) then {"yes"} else {"no"}) + "|myTowns=" + str _myTowns + "|enTowns=" + str (_snap select WFBE_SNAP_ENTOWNS) + "|contested=" + (if (_engContested) then {"1"} else {"0"}) + "|expandFirst=" + (if (_expandFirst) then {"1"} else {"0"}));
};

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
_harassTgt = objNull; _harassFar = -1;
if (_harassN > 0) then {
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
				_hfMode   = toLower ([_hfGrp, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool); //--- fix(hunt): G1-safe group reads (2-arg [name,default] getVariable returns nil on GROUPs when unset; helper is type-generic)
				_hfRelief = [_hfGrp, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
				_hfStrike = [_hfGrp, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool;
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
			//--- Once a target is picked the guard makes remaining iterations no-ops (a bare
			//--- exitWith inside then{} is invalid A2 grammar and broke this file's compile).
			if (isNull _harassTgt) then {
				_hfReach = false;
				{ _hfPos = _x; if ((_hfPos distance _hfTown) <= _hfMntReach) exitWith {_hfReach = true} } forEach _hfMntPos;
				if (_hfReach) then {
					_harassTgt = _hfTown; _harassFar = _hfDepth;
				} else {
					if (isNull _hfFirst) then {_hfFirst = _hfTown; _hfSkip = true};
				};
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
_expandWarnTown = objNull; _expandWarnDist = 1e9;
_expandClaimed = [];   //--- DEDUP (block-m): neutral towns already claimed by an expand-lane team this tick
//--- SPREAD (cmdcon41, claude-gaming 2026-07-02): per-fist-town load counter + cap. With a widened fist
//--- (WFBE_C_AICOM2_FIST_TOWNS>1) the L268-272 nearest pick otherwise funnels every team onto the single
//--- closest fist town = the dogpile. _fistCounts/_fistCaps are index-aligned with _fist; tier caps
//--- opt into the AssignTowns town-type quota shape while preserving the flat legacy cap by default.
private ["_fistCounts","_fistCaps","_capPerFist","_tierCapOn"];
_fistCounts = []; _fistCaps = [];
_capPerFist = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_PERTOWN", 4];
_tierCapOn = (missionNamespace getVariable ["WFBE_C_AICOM_SPREAD_TIERCAP", 0]) > 0;
{
	private ["_ft","_ftCap"];
	_ft = _x; _ftCap = _capPerFist;
	if (_tierCapOn) then {
		switch (_ft getVariable ["wfbe_town_type", ""]) do {
			case "TinyTown1":   {_ftCap = (_capPerFist - 1) max 1};
			case "SmallTown1":  {_ftCap = _capPerFist};
			case "SmallTown2":  {_ftCap = _capPerFist};
			case "MediumTown1": {_ftCap = _capPerFist + 1};
			case "MediumTown2": {_ftCap = _capPerFist + 1};
			case "LargeTown1":  {_ftCap = _capPerFist + 2};
			case "LargeTown2":  {_ftCap = _capPerFist + 2};
			case "HugeTown1":   {_ftCap = _capPerFist + 2};
			case "HugeTown2":   {_ftCap = _capPerFist + 2};
			default {_ftCap = _capPerFist};
		};
	};
	_fistCounts set [_forEachIndex, 0];
	_fistCaps set [_forEachIndex, _ftCap];
} forEach _fist;
_dedupOn = (missionNamespace getVariable ["WFBE_C_AICOM_EXPAND_DEDUP", 0]) > 0;
{
	private ["_grp","_ldr","_alive","_mode","_relief","_strike","_hasVeh","_reach","_tgt","_tgtD","_ldrPos","_v"];
	_grp = _x;
	if (!isNull _grp) then {
		_alive  = {alive _x} count (units _grp);
		_ldr    = leader _grp;
		_mode   = toLower ([_grp, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool); //--- fix(hunt): G1-safe - nil reads here nil-poisoned the eligibility chain so EVERY unstamped team failed eligibility every tick
		_relief = [_grp, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
		_strike = [_grp, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool;
		//--- ELIGIBILITY: an offensive founded/HC team Strategy hasn't claimed (relief/strike), not the base
		//--- garrison, not player-led, not under an explicit human order (move/patrol/defense).
		if (_alive > 0 && {!isNull _ldr} && {!isPlayer _ldr} && {_grp != _garGrp}
		    && {isNull _relief} && {!_strike} && {!(_mode in ["move","patrol","defense"])}
		    && {!([_grp] Call WFBE_CO_FNC_CapLock)}   //--- CAPTURE LOCK (GR-2026-07-03a): skip a mid-capture-drain team so the Allocator does not re-aim it off a near-complete drain (plain BOOL, self-clears on captured/dead/TTL/town-ours).
		    && {([_grp, "wfbe_aicom_feint_expiry", 0] Call WFBE_CO_FNC_GroupGetBool) <= 0}   //--- FIX(review CRITICAL): skip feint-tagged teams so the feint alloc_target survives across ticks
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
						{ _ev = _ldrPos distance _x; if (_ev < _expandWarnDist) then {_expandWarnDist = _ev; _expandWarnTown = _x}; if (_ev <= _reach && {_ev < _eD} && {!(_x in _expandClaimed)}) then {_eD = _ev; _eTgt = _x} } forEach _neutTowns;
					} else {
						{ _ev = _ldrPos distance _x; if (_ev < _expandWarnDist) then {_expandWarnDist = _ev; _expandWarnTown = _x}; if (_ev <= _reach && {_ev < _eD}) then {_eD = _ev; _eTgt = _x} } forEach _neutTowns;
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
							if (_v <= _reach && {_v < _tgtD} && {(_fistCounts select _forEachIndex) < (_fistCaps select _forEachIndex)}) then {_tgtD = _v; _tgt = _x; _bestIdx = _forEachIndex};
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

if (_harassN > 0 && {_harassAssigned == 0} && {!isNull _harassTgt}) then {
	diag_log ("AICOM2|WARN|HARASS_UNMET|" + str _side + "|harassN=" + str _harassN + "|harassTgt=" + (_harassTgt getVariable ["name","?"]) + "|harassFar=" + str (round _harassFar));
};

if (_expandN > 0 && {_expandCount == 0} && {(count _neutTowns) > 0} && {!isNull _expandWarnTown}) then {
	diag_log ("AICOM2|WARN|EXPAND_UNREACHABLE|" + str _side + "|expandN=" + str _expandN + "|neutTowns=" + str (count _neutTowns) + "|nearest=" + (_expandWarnTown getVariable ["name","?"]) + "|nearestDist=" + str (round _expandWarnDist));
};

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
		_feintExpiry = [_feintGrp, "wfbe_aicom_feint_expiry", 0] Call WFBE_CO_FNC_GroupGetBool;
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
				_feintMode   = toLower ([_feintGrp, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
				_feintRelief = [_feintGrp, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
				_feintStrike = [_feintGrp, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool;
				_feintExpiry = [_feintGrp, "wfbe_aicom_feint_expiry", 0] Call WFBE_CO_FNC_GroupGetBool;
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
		private ["_riBest","_riBestD","_riExisting","_riExistingD","_riTownSide","_riNeutral","_riGrp","_riLdr","_riAlive","_riMode","_riRelief","_riStrike"];
		_riBest = grpNull; _riBestD = 1e9; _riExisting = grpNull; _riExistingD = 1e9;
		_riTownSide = _riTown getVariable ["sideID", -1];
		_riNeutral = (_riTownSide != _sideID) && {_riTownSide != _enemyID};
		{
			_riGrp = _x;
			if (!isNull _riGrp) then {
				_riAlive  = {alive _x} count (units _riGrp);
				_riLdr    = leader _riGrp;
				_riMode   = toLower ([_riGrp, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
				_riRelief = [_riGrp, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
				_riStrike = [_riGrp, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool;
				if (_riAlive > 0 && {!isNull _riLdr} && {!isPlayer _riLdr} && {_riGrp != _garGrp}
				    && {isNull _riRelief} && {!_riStrike} && {!(_riMode in ["move","patrol","defense"])}
				    && {([_riGrp, "wfbe_aicom_feint_expiry", 0] Call WFBE_CO_FNC_GroupGetBool) <= 0}
				    && {([_riGrp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool) || {[_riGrp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}}) then {
					private ["_riD"]; _riD = (getPos _riLdr) distance _riTown;
					if (_riD < _riBestD) then {_riBestD = _riD; _riBest = _riGrp};
					if (_riNeutral && {([_riGrp, "wfbe_aicom_alloc_target", objNull] Call WFBE_CO_FNC_GroupGetBool) == _riTown} && {_riD < _riExistingD}) then {_riExistingD = _riD; _riExisting = _riGrp};
				};
			};
		} forEach _teams;
		//--- NEUTRAL REUSE (lane222): expansion may already have one team on this town; treat that as the reinforce team.
		if (!isNull _riExisting) then {_riBest = _riExisting};
		if (!isNull _riBest) then {
			_riBest setVariable ["wfbe_aicom_alloc_target", _riTown];
			_riBest setVariable ["wfbe_aicom_alloc_tick", time];
			diag_log ("AICOM2|v1|REINFORCE|" + str _side + "|" + str (round (time / 60)) + "|town=" + (_riTown getVariable ["name","?"]) + "|team=" + str _riBest);
		};
	};
};

diag_log ("AICOM2|v1|ALLOC|" + str _side + "|" + str (round (time / 60)) + "|fist=" + str (count _fist) + "|primary=" + ((_fist select 0) getVariable ["name","?"]) + "|src=" + (if (_fromFocus) then {"FOCUS"} else {"auto"}) + "|harassTo=" + (if (!isNull _harassTgt) then {_harassTgt getVariable ["name","?"]} else {"none"}) + "|assigned=" + str _assigned + "|harass=" + str _harassAssigned + "|expand=" + str _expandCount + "|teams=" + str (count _teams) + "|myTowns=" + str _myTowns + "|expandFirst=" + str _expandFirst + "|concentrate=" + str _concentrate);
