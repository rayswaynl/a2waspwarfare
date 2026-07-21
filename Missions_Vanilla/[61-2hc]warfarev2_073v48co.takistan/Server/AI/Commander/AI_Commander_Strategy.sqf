/*
	AI Commander - war strategy worker. feat/ai-commander V0.5.
	Server-side, full-command mode only. Parameter: _this = side.

	Runs every WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL and decides WHERE the war goes:
	1) SPEARHEADS: scores enemy/neutral towns (value vs distance to our front) and
	   publishes wfbe_aicom_targets - AssignTowns concentrates teams on these few
	   towns (WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN per target) instead of
	   scattering one team at every nearest town.
	2) REACTIVE DEFENSE: own towns under attack (wfbe_active) get the nearest free
	   team diverted to relieve them (explicit defense order; released when quiet).
	3) HQ HUNT: when clearly winning (towns + strength), peels the strongest teams
	   into a strike force on the enemy HQ so AI-vs-AI rounds actually END.
	4) ARTILLERY: fires the base guns (built by the Base worker) at the spearhead
	   town or the enemy HQ - only when no friendlies are near the impact zone.
*/

private ["_side","_sideID","_sideText","_logik","_teams","_enemySide","_enemyID","_enemyLogik","_snap","_snapOk","_myTowns","_enemyTowns","_ownTownObjs","_candTowns","_townSide","_myStr","_enStr","_team","_alive","_strikeOn","_wasStrike","_enemyHQ","_strikers","_strong","_best","_bestN","_i","_targets","_cands","_t","_score","_bestScore","_bestTown","_dNear","_d","_perTeam","_want","_attacked","_relieved","_town","_free","_freeD","_cd","_artyTgt","_pieces","_p","_idx","_maxR","_fired","_inRange","_upASel","_relTown","_relAge","_quiet","_strikeCount","_ownNear","_frontRad","_distDiv","_hqDiv","_farPen","_enemyHQForRank","_dHQ","_onFront","_anyFront","_wTeam","_wMode","_wLdr","_wBc","_wBcPos","_wBcT","_wMoved","_lastStand","_stratMode","_spBl","_spBlTowns","_spBlKeep","_spBlCd","_spPrevPrim","_spApproach","_spBest","_spLast","_spStall","_pdTown","_pdT0","_perfStart"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
_perfStart = diag_tickTime;

//--- Primary foe = the other commanding side (the defender never gets HQ-hunted).
_enemySide = if (_side == west) then {east} else {west};
if (!(_enemySide in WFBE_PRESENTSIDES)) exitWith {};
_enemyID = (_enemySide) Call WFBE_CO_FNC_GetSideID;
_enemyLogik = (_enemySide) Call WFBE_CO_FNC_GetSideLogic;

//--- War state metrics. AICOM2_Snapshot is refreshed immediately before Strategy in
//--- AI_Commander.sqf; consume its town census here so legacy Strategy no longer
//--- recomputes the same ownership split. Direct/manual calls fall back to the old scan.
_snap = _logik getVariable ["wfbe_aicom2_snap", []];
_snapOk = ((count _snap) >= 26) && {(_snap select WFBE_SNAP_SIDEID) == _sideID} && {(time - (_snap select WFBE_SNAP_TIME)) <= ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL", 60]) + 5)};
if (_snapOk) then {
	_myTowns    = _snap select WFBE_SNAP_MYTOWNS;
	_enemyTowns = _snap select WFBE_SNAP_ENTOWNS;
	_ownTownObjs = _snap select WFBE_SNAP_OWNTOWNOBJS;
	_candTowns   = _snap select WFBE_SNAP_TGTTOWNOBJS;
} else {
	_myTowns = 0; _enemyTowns = 0; _ownTownObjs = []; _candTowns = [];
	{
		_townSide = _x getVariable ["sideID", -1];
		if (_townSide == _sideID) then {
			_myTowns = _myTowns + 1;
			_ownTownObjs set [count _ownTownObjs, _x];
		} else {
			_candTowns set [count _candTowns, _x];
		};
		if (_townSide == _enemyID) then {_enemyTowns = _enemyTowns + 1};
	} forEach towns;
};
//--- B68 (Ray 2026-06-21) ATTACK-BIAS: _myStr is the MANEUVER strength that gates LAST-STAND (and the HQ-strike).
//--- Exclude stranded lone-survivor remnants (alive < N AND far from HQ) and in-refit teams so a few far-flung
//--- survivors do not deflate strength below the enemy and falsely trip the defensive gates (the b67 "EAST amasses
//--- but never attacks" stall). A2-OA: plain get + isNil for the GROUP refit var ([name,default] is unreliable on groups).
private ["_myHQ","_loneAlive","_loneFar","_tAlive","_rf","_isRemnant"];
_myHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
_loneAlive = missionNamespace getVariable ["WFBE_C_AICOM_STR_LONE_ALIVE", 2];
_loneFar   = missionNamespace getVariable ["WFBE_C_AICOM_STR_LONE_FARHQ", 1500];
_myStr = 0;
{
	if (!isNull _x) then {
		_tAlive = {alive _x} count (units _x);
		if (_tAlive > 0) then {
			_isRemnant = false;
			_rf = _x getVariable "wfbe_aicom_refit";
			if (!isNil "_rf" && {_rf}) then {_isRemnant = true};
			if (!_isRemnant && {_tAlive < _loneAlive} && {_loneFar > 0} && {!isNull (leader _x)} && {!isNull _myHQ} && {((leader _x) distance _myHQ) > _loneFar}) then {_isRemnant = true};
			if (!_isRemnant) then {_myStr = _myStr + _tAlive};
		};
	};
} forEach _teams;
_enStr = 0;
{ if (!isNull _x) then {_enStr = _enStr + ({alive _x} count (units _x))} } forEach (_enemyLogik getVariable ["wfbe_teams", []]);

//--- 0) LAST-STAND: fewer than 2 own towns AND clearly outnumbered - recall all, skip attack.
//--- AICOM v2 M3 (Ray "almost never defensive"): gate last-stand on EFFECTIVE strength (maneuver + held-town credit), NOT raw maneuver _myStr - so a territory-leader that garrisons towns never trips the recall-all-to-HQ (the dominant-but-passive STALL the 18h soak showed). Last-stand now fires only at <=1 town AND genuinely effectively-crushed = base under real threat.
private ["_lsTS","_lsMyEff","_lsEnEff"]; _lsTS = missionNamespace getVariable ["WFBE_C_AICOM_TOWN_STRENGTH", 2]; _lsMyEff = _myStr + (_myTowns * _lsTS); _lsEnEff = _enStr + (_enemyTowns * _lsTS);
_lastStand = (_myTowns <= (missionNamespace getVariable [format ["WFBE_C_AICOM_LASTSTAND_TOWNS_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_LASTSTAND_TOWNS", 1]])) && (_lsMyEff < (_lsEnEff * (missionNamespace getVariable [format ["WFBE_C_AICOM_LASTSTAND_RATIO_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_LASTSTAND_RATIO", 0.45]]))); //--- B68 attack-bias (Ray 2026-06-21): last-stand only when <=1 town AND <45% of enemy maneuver strength (was <2 towns AND <70% = too eager). Defense rare; attack default.
//--- Owner ruling: suppress the legacy last-stand/HQ-defend posture; AssignTowns keeps selecting enemy towns.
if ((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) > 0) then {_lastStand = false};
_stratMode = "spearhead"; //--- default; overridden below
_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
if (_lastStand) then {
	_stratMode = "laststand";
	_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
	//--- Only set the flag the first time we enter last-stand.
	if (!(_logik getVariable ["wfbe_aicom_laststand", false])) then {
		_logik setVariable ["wfbe_aicom_laststand", true];
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] LAST-STAND - towns %2 strength %3v%4 - recalling all teams to HQ.", _sideText, _myTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
	};
	//--- Recall every non-garrison, non-player AI team to HQ in defense posture.
	private ["_lsHqPos"];
	_lsHqPos = getPos ((_side) Call WFBE_CO_FNC_GetSideHQ);
	{
		_team = _x;
		if (!isNull _team && {!isPlayer (leader _team)}) then {
			//--- Clear relief and strike flags.
			_team setVariable ["wfbe_aicom_relief", objNull];
			_team setVariable ["wfbe_aicom_strike", false];
			_team setVariable ["wfbe_aicom_townorder", []];
			[_team, "defense"] Call SetTeamMoveMode;
			[_team, _lsHqPos] Call SetTeamMovePos;
			if (!(isNil {_team getVariable "wfbe_aicom_hc"}) && {_team getVariable "wfbe_aicom_hc"}) then {
				_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "defense", _lsHqPos], true];
			};
		};
	} forEach _teams;
	_logik setVariable ["wfbe_aicom_strike_on", false];
} else {
	//--- Clear the last-stand flag once we recover above the threshold.
	if (_logik getVariable ["wfbe_aicom_laststand", false]) then {
		_logik setVariable ["wfbe_aicom_laststand", false];
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] last-stand lifted - towns %2 strength %3v%4.", _sideText, _myTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
	};
};

//--- (Skipped while in last-stand posture - teams are defending HQ.)
if (_lastStand) exitWith {};

//--- fable/alife-arty-dwell (2026-07-08): snapshot the LIVE published fist/target BEFORE this worker's own
//--- SPEARHEAD scorer (below) and Allocate.sqf (which runs right after this worker each tick, per the call
//--- order in AI_Commander.sqf) overwrite wfbe_aicom_targets. At this exact point it still holds whatever
//--- AssignTowns/Execute dispatched teams against THIS tick (Allocate's fist when WFBE_C_AICOM2_ALLOCATE_ENABLE
//--- is on, else this worker's own prior-tick pick) - i.e. the town actually under assault right now. The
//--- ARTILLERY block (4, below) targets THIS instead of the freshly-rescored local _targets, which nobody has
//--- acted on yet this tick and can diverge from the live fist under AICOM2 (the V1-vs-Allocate mismatch).
private "_liveFistSnap";
_liveFistSnap = _logik getVariable ["wfbe_aicom_targets", []];
if (typeName _liveFistSnap != "ARRAY") then {_liveFistSnap = []};

//--- perf/aicom-strategy-towncache (draft PR, flag default 0): per-call memoization for the
//--- "nearest own town" distance (_dNear) that 4 sites below independently recompute via a
//--- nested forEach _ownTownObjs (spearhead scorer x2 - initial pick + stall re-pick -, front
//--- telemetry, AICOMDBG trace). _ownTownObjs and this side's HQ are never reassigned after
//--- this point in the call, so memoizing _dNear by candidate-town identity for the rest of
//--- THIS call is byte-identical to recomputing it fresh every time. Flag OFF (default) takes
//--- the untouched original computation at every site - byte-identical mission. Flag ON is for
//--- the matched before/after PerformanceAudit A/B only (see PR body).
private ["_twCacheOn","_twCacheTowns","_twCacheDNear"];
_twCacheOn = (missionNamespace getVariable ["WFBE_C_AICOM_STRATEGY_TOWNCACHE", 0]) > 0;
_twCacheTowns = [];
_twCacheDNear = [];

//--- 1) SPEARHEADS: COHERENT FRONT (V0.8, claude-gaming 2026-06-14). Rank enemy/neutral
//--- towns by NEAREST-TO-OUR-FRONT first, with a small pull toward the enemy HQ, so the
//--- army advances as a wave onto achievable nearby objectives instead of cherry-picking
//--- the enemy's rich rear 7-8km away (the STUCKSTAT distTgt=8122 piecemeal bug).
//---   score = supplyValue                 (town value: prefer richer of the NEARBY towns)
//---         - dFront / DISTANCE_DIVISOR    (distance-to-front DOMINATES; divisor 50, was 150)
//---         - dEnemyHQ / HQ_PULL_DIVISOR   (small spearhead bias toward the enemy capital)
//---         - FAR_PENALTY if dFront > FRONTIER_RADIUS (deep towns can't buy their way over a near one)
//--- GUARDRAIL: the far penalty is a deprioritiser, not a ban - if NO town is on the front
//--- (front fully owned / island target), the deep towns still score and get picked, so
//--- teams always have a valid target and never idle.
_cands = +_candTowns;
//--- B61 (Ray 2026-06-21) SPEARHEAD RE-PICK: side-level stall-blacklist. The picker re-scores
//--- deterministically every ~60s with no progress memory, so it re-targets the SAME town forever
//--- (live: EAST froze on one town for hours). Read this side's spearhead blacklist off the side LOGIC
//--- (the [name,default] getVariable form is valid on the LOGIC object, unlike on a GROUP); prune expired
//--- [town,expiry] entries; exclude live ones from the candidate set so the picker chooses the next-best
//--- eligible town. GUARDRAIL (reuse of AssignTowns:290-295): if excluding the blacklist would EMPTY the
//--- candidate set, clear the blacklist and fall back to the full list so a target ALWAYS exists.
_spBl = _logik getVariable ["wfbe_aicom_spearhead_bl", []];
_spBlKeep = [];
_spBlTowns = [];
{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_spBlKeep set [count _spBlKeep, _x]; _spBlTowns set [count _spBlTowns, (_x select 0)]} } forEach _spBl;
_logik setVariable ["wfbe_aicom_spearhead_bl", _spBlKeep];
if (count _spBlTowns > 0) then {
	private ["_candsF"];
	_candsF = _cands - _spBlTowns;
	if (count _candsF == 0) then {
		//--- every eligible town is blacklisted: clear it so the picker is never left without a target.
		_logik setVariable ["wfbe_aicom_spearhead_bl", []];
		_spBlTowns = [];
	} else {
		_cands = _candsF;
	};
};
//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): precompute live grudge sites once for both spearhead scorer copies below
private ["_grudgeTowns","_grudgeBonus"];
_grudgeTowns = []; _grudgeBonus = 0;
if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0) then {
	_grudgeBonus = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_BONUS", 400];
	{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_grudgeTowns set [count _grudgeTowns, (_x select 0)]} } forEach (_logik getVariable ["wfbe_aicom_grudge", []]);
};
_frontRad = missionNamespace getVariable ["WFBE_C_AICOM_FRONTIER_RADIUS", 3000];
_distDiv  = missionNamespace getVariable ["WFBE_C_AICOM_DISTANCE_DIVISOR", 50];
if (_distDiv <= 0) then {_distDiv = 1};
_hqDiv    = missionNamespace getVariable ["WFBE_C_AICOM_HQ_PULL_DIVISOR", 250];
_farPen   = missionNamespace getVariable ["WFBE_C_AICOM_FAR_PENALTY", 1000];
//--- Enemy HQ for the directional pull (cached once; nil-safe - 0 pull if no HQ object).
_enemyHQForRank = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
//--- Concentrate force: split across FEW towns (cap via SPEARHEAD_TOWNS_MAX), not the old
//--- ceil(teams / per-town) which scattered into 3+ cities at one effective team each.
_want = 1 max (missionNamespace getVariable [format ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX", 2]]);
_want = _want min (count _cands);
_targets = [];
for "_i" from 1 to _want do {
	_bestScore = -1e9; _bestTown = objNull;
	{
		_t = _x;
		if (!(_t in _targets)) then {
			//--- Frontline distance = to our nearest OWN town (fallback: our HQ) = the
			//--- coherent-front / adjacency signal. Small dNear = borders owned territory.
			if (_twCacheOn) then {
				_dNear = -1;
				{ if (_x == _t) exitWith {_dNear = _twCacheDNear select _forEachIndex} } forEach _twCacheTowns;
				if (_dNear < 0) then {
					_dNear = 1e9;
					{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
					if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
					_twCacheTowns set [count _twCacheTowns, _t];
					_twCacheDNear set [count _twCacheDNear, _dNear];
				};
			} else {
				_dNear = 1e9;
				{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
				if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
			};
			//--- Distance toward the ENEMY HQ (avoid binary getDir per A2 rules - plain distance).
			_dHQ = if (!isNull _enemyHQForRank) then {_t distance _enemyHQForRank} else {0};
			//--- V0.6 task 49a: town weight hook (nil-safe, zero on this mission).
			//--- A8 SOFT/VALUE PREFERENCE (claude-gaming): at COMPARABLE distance prefer softer +
			//--- higher-value towns. Distance still dominates (FAR_PENALTY + divisor unchanged) so the
			//--- coherent-front guardrail holds. hardness tier from wfbe_town_type (0 soft..4 hard) is
			//--- SUBTRACTED (soft wins, and it cancels the accidental pro-Huge bias supplyValue added);
			//--- the previously-dead _townValue (now wfbe_town_value) is ADDED to reward rich towns.
			private ["_hardTier","_softW","_valDiv"];
			_softW = missionNamespace getVariable ["WFBE_C_AICOM_SOFT_WEIGHT", 12];
			_valDiv = missionNamespace getVariable ["WFBE_C_AICOM_VALUE_DIVISOR", 50];
			if (_valDiv <= 0) then {_valDiv = 1};
			_hardTier = switch (_t getVariable ["wfbe_town_type", ""]) do {
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
			_score = (_t getVariable ["supplyValue", 0])
			       - (_dNear / _distDiv)
			       + (_t getVariable ["wfbe_aicom_town_weight", 0])
			       - (_hardTier * _softW)
			       + ((_t getVariable ["wfbe_town_value", 0]) / _valDiv);
			if (_hqDiv > 0) then {_score = _score - (_dHQ / _hqDiv)};
			//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): draw the AI back to a live grudge site
			if (_grudgeBonus > 0 && {_t in _grudgeTowns}) then {_score = _score + _grudgeBonus};
			//--- Off-front towns take a flat penalty so a fat deep city can't outrank a
			//--- near contestable one. Towns on the front are unpenalised and win.
			if (isNil "_score") then {
				diag_log ("CAPDBG|SCORE|" + (_t getVariable ["name","?"]) + "|dNear=" + str(isNil "_dNear") + "|residual");
			};
			_score = if (isNil "_score") then {-99999} else {_score};
			if (_dNear > _frontRad) then {_score = _score - _farPen};
			if (_score > _bestScore) then {_bestScore = _score; _bestTown = _t};
		};
	} forEach _cands;
	if (!isNull _bestTown) then {_targets = _targets + [_bestTown]};
};
//--- B61 (Ray 2026-06-21) SPEARHEAD RE-PICK: per-side progress memory + stall detection on the PRIMARY.
//--- PROGRESS SIGNAL = the ASSAULTING TEAMS' best (min) approach to the primary target town - NOT raw
//--- distFront (distance-to-OWN-town), which stays flat while a town is being contested and would yank the
//--- fist off a town it is about to take. A team is "committed" if it is an alive AI team in offense posture
//--- (towns/"" mode, not garrison/relief/strike). If the best approach has NOT improved by >= REPICK_MIN_GAIN
//--- (~150m) for >= REPICK_STALL_EVALS (N>=4) consecutive evaluations, the primary is STALLED: blacklist it
//--- (side-level wfbe_aicom_spearhead_bl, cooldown ~600s) and force the picker to choose the next-best eligible
//--- town this same tick (selection/logging ONLY - this never changes how AI MOVES; AssignTowns reads the new
//--- _targets next cycle). Empty-set guardrail above guarantees a target survives the blacklist.
if (count _targets > 0) then {
	private ["_prim","_spMinGain","_spEvals"];
	_prim = _targets select 0;
	_spMinGain = missionNamespace getVariable ["WFBE_C_AICOM_REPICK_MIN_GAIN", 150];
	_spEvals   = missionNamespace getVariable ["WFBE_C_AICOM_REPICK_STALL_EVALS", 4];
	_spBlCd    = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600];
	//--- Best (min) approach of this side's COMMITTED offense teams to the primary town.
	//--- B66 STALL FALSE-POSITIVE: also track whether ANY offense team is actually committed to the
	//--- primary this eval. When nothing is committed _spApproach stays 1e9 (sentinel) and the no-progress
	//--- branch below would bump the stall counter every tick + eventually blacklist a good town for a
	//--- NON-stall (no team had been dispatched yet). Only accrue stall when _anyCommitted is true;
	//--- otherwise HOLD the counter (and skip re-baselining off the sentinel).
	private ["_anyCommitted"]; //--- B66
	_anyCommitted = false;     //--- B66
	_spApproach = 1e9;
	{
		_team = _x;
		if (!isNull _team && {!isPlayer (leader _team)} && {({alive _x} count (units _team)) > 0}) then {
			_wMode = toLower ([_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
			//--- offense only: skip relief ("defense"), HQ-strike ("move") and the garrison team.
			if ((_wMode == "towns" || {_wMode == ""}) && {(_logik getVariable ["wfbe_aicom_garrison", grpNull]) != _team}) then {
				_wLdr = leader _team;
				if (!isNull _wLdr) then {_anyCommitted = true; _d = _wLdr distance _prim; if (_d < _spApproach) then {_spApproach = _d}}; //--- B66 mark committed
			};
		};
	} forEach _teams;
	//--- Compare against the stored memory for this side: [primTown, bestApproach, sameCount].
	_spPrevPrim = _logik getVariable ["wfbe_aicom_spear_prim", objNull];
	_spBest     = _logik getVariable ["wfbe_aicom_spear_bestapproach", 1e9];
	_spLast     = _logik getVariable ["wfbe_aicom_spear_stallcount", 0];
	_spStall    = false;
	if (isNull _spPrevPrim || {_spPrevPrim != _prim}) then {
		//--- Primary changed (or first sighting): reset the progress baseline, no stall yet.
		_logik setVariable ["wfbe_aicom_spear_prim", _prim];
		_logik setVariable ["wfbe_aicom_spear_bestapproach", _spApproach];
		_logik setVariable ["wfbe_aicom_spear_stallcount", 0];
	} else {
		//--- Same primary as last eval. B66 STALL FALSE-POSITIVE: only judge progress/stall when an offense
		//--- team is actually committed to the primary (_anyCommitted). With nothing committed _spApproach is
		//--- the 1e9 sentinel, so the old unconditional code bumped the stall counter every tick and blacklisted
		//--- a good town for a non-stall. When uncommitted we HOLD the counter (no progress test, no accrual).
		if (_anyCommitted) then { //--- B66
			if ((_spBest - _spApproach) >= _spMinGain) then {
				//--- progress: record the improved approach, reset the stall counter.
				_logik setVariable ["wfbe_aicom_spear_bestapproach", _spApproach];
				_logik setVariable ["wfbe_aicom_spear_stallcount", 0];
			} else {
				//--- no meaningful progress this eval: bump the consecutive-stall counter.
				_spLast = _spLast + 1;
				_logik setVariable ["wfbe_aicom_spear_stallcount", _spLast];
				if (_spLast >= _spEvals) then {_spStall = true};
			};
		}; //--- B66 (else: uncommitted -> hold the stall counter)
	};
	if (_spStall) then {
		//--- STALLED: blacklist the frozen primary (reuse the AssignTowns:208-219 [town,expiry] idiom) and
		//--- re-pick the next-best eligible town RIGHT NOW (selection only - AI movement is untouched).
		_spBl = _logik getVariable ["wfbe_aicom_spearhead_bl", []];
		_spBlKeep = [];
		{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _prim}) then {_spBlKeep set [count _spBlKeep, _x]} } forEach _spBl;
		_spBlKeep set [count _spBlKeep, [_prim, time + _spBlCd]];
		_logik setVariable ["wfbe_aicom_spearhead_bl", _spBlKeep];
		//--- Rebuild the candidate set MINUS the live blacklist (same empty-set guardrail as AssignTowns:290-295).
		_spBlTowns = [];
		{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_spBlTowns set [count _spBlTowns, (_x select 0)]} } forEach _spBlKeep;
		_cands = +_candTowns;
		private ["_candsF"];
		_candsF = _cands - _spBlTowns;
		if (count _candsF == 0) then {
			//--- only the just-blacklisted town was eligible: clear it so a target ALWAYS exists.
			_logik setVariable ["wfbe_aicom_spearhead_bl", []];
		} else {
			_cands = _candsF;
		};
		_want = 1 max (missionNamespace getVariable [format ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX", 2]]);
		_want = _want min (count _cands);
		//--- Re-run the SAME scorer (identical weights) over the trimmed candidate set.
		_targets = [];
		for "_i" from 1 to _want do {
			_bestScore = -1e9; _bestTown = objNull;
			{
				_t = _x;
				if (!(_t in _targets)) then {
					if (_twCacheOn) then {
						_dNear = -1;
						{ if (_x == _t) exitWith {_dNear = _twCacheDNear select _forEachIndex} } forEach _twCacheTowns;
						if (_dNear < 0) then {
							_dNear = 1e9;
							{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
							if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
							_twCacheTowns set [count _twCacheTowns, _t];
							_twCacheDNear set [count _twCacheDNear, _dNear];
						};
					} else {
						_dNear = 1e9;
						{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
						if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
					};
					_dHQ = if (!isNull _enemyHQForRank) then {_t distance _enemyHQForRank} else {0};
					private ["_hardTier","_softW","_valDiv"];
					_softW = missionNamespace getVariable ["WFBE_C_AICOM_SOFT_WEIGHT", 12];
					_valDiv = missionNamespace getVariable ["WFBE_C_AICOM_VALUE_DIVISOR", 50];
					if (_valDiv <= 0) then {_valDiv = 1};
					_hardTier = switch (_t getVariable ["wfbe_town_type", ""]) do {
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
					_score = (_t getVariable ["supplyValue", 0])
					       - (_dNear / _distDiv)
					       + (_t getVariable ["wfbe_aicom_town_weight", 0])
					       - (_hardTier * _softW)
					       + ((_t getVariable ["wfbe_town_value", 0]) / _valDiv);
					if (_hqDiv > 0) then {_score = _score - (_dHQ / _hqDiv)};
					//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): draw the AI back to a live grudge site
					if (_grudgeBonus > 0 && {_t in _grudgeTowns}) then {_score = _score + _grudgeBonus};
					if (_dNear > _frontRad) then {_score = _score - _farPen};
					if (_score > _bestScore) then {_bestScore = _score; _bestTown = _t};
				};
			} forEach _cands;
			if (!isNull _bestTown) then {_targets = _targets + [_bestTown]};
		};
		//--- Re-seed the progress memory on the NEW primary so we start fresh against it.
		private ["_newPrim"];
		_newPrim = if (count _targets > 0) then {_targets select 0} else {objNull};
		_logik setVariable ["wfbe_aicom_spear_prim", _newPrim];
		_logik setVariable ["wfbe_aicom_spear_stallcount", 0];
		//--- best approach of committed teams to the NEW primary (fresh baseline; 1e9 if none committed).
		private ["_newApproach"];
		_newApproach = 1e9;
		if (!isNull _newPrim) then {
			{
				_team = _x;
				if (!isNull _team && {!isPlayer (leader _team)} && {({alive _x} count (units _team)) > 0}) then {
					_wMode = toLower ([_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
					if ((_wMode == "towns" || {_wMode == ""}) && {(_logik getVariable ["wfbe_aicom_garrison", grpNull]) != _team}) then {
						_wLdr = leader _team;
						if (!isNull _wLdr) then {_d = _wLdr distance _newPrim; if (_d < _newApproach) then {_newApproach = _d}};
					};
				};
			} forEach _teams;
		};
		_logik setVariable ["wfbe_aicom_spear_bestapproach", _newApproach];
		diag_log ("AICOMSTAT|v1|SPEARHEAD_REPICK|" + _sideText + "|" + str (round (time / 60)) + "|stalled=" + (_prim getVariable ["name","?"]) + "|approach=" + str (round _spApproach) + "|evals=" + str _spLast + "|newPrimary=" + (if (isNull _newPrim) then {"none"} else {_newPrim getVariable ["name","?"]}) + "|cooldown=" + str _spBlCd);
	};
};
//--- cmdcon41-w2 FRONT/SPEARHEAD HYSTERESIS (Fable F2; flag WFBE_C_AICOM_FRONT_DWELL default 480s). The picker re-scores
//--- the primary spearhead every ~60s, so the FRONT target flipped ~every 4 min (122 EAST changes in a 7h soak) and
//--- 20-min journeys died administratively on each flip. Once a primary is chosen, DWELL on it: keep the same primary
//--- (skip the re-scoring flip) until the dwell elapses OR the town flips to us / becomes null. The stall-blacklist
//--- re-pick above still overrides (a genuinely stuck primary gets blacklisted, invalidating the dwell next tick).
//--- Selection-only: this reorders _targets before publish; it never moves a unit. A2-OA-safe: OBJECT/time/getVariable,
//--- ==/!= only on the sideID scalar + object-null via isNull, string mode literals untouched.
private ["_fhDwell","_fhPrim","_fhT0","_fhFresh","_fhValid"];
_fhDwell = missionNamespace getVariable [format ["WFBE_C_AICOM_FRONT_DWELL_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_FRONT_DWELL", 480]];
if (_fhDwell > 0 && {count _targets > 0}) then {
	_fhFresh = _targets select 0;
	_fhPrim = _logik getVariable "wfbe_aicom_front_prim";
	_fhT0   = _logik getVariable "wfbe_aicom_front_t0";
	//--- Is the stored dwell pick still a VALID enemy/neutral target (not null, not captured by us)?
	_fhValid = false;
	if (!isNil "_fhPrim" && {!isNull _fhPrim} && {!isNil "_fhT0"}) then {
		//--- Lane-323: reject neutralised towns (sideID -1) as dwell targets — a recaptured-neutral
		//--- town has no enemy affiliation and must not be kept as the active front priority.
		//--- Review note (PR #530): cache sideID once to avoid double-read in the lazy-and expression.
		private "_fhSID"; _fhSID = _fhPrim getVariable ["sideID", -1];
		if (_fhSID != _sideID && {_fhSID != -1}) then {_fhValid = true};
	};
	if (_fhValid && {(time - _fhT0) < _fhDwell}) then {
		//--- Dwell still active + pick still valid: keep it as primary. If it is not already the scored primary,
		//--- move it to slot 0 (drop any duplicate, prepend) so AssignTowns keeps concentrating on the dwelled town.
		if (_fhFresh != _fhPrim) then {
			_targets = _targets - [_fhPrim];
			_targets = [_fhPrim] + _targets;
			diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FRONT_DWELL_HOLD|kept=" + (_fhPrim getVariable ["name","?"]) + "|scored=" + (_fhFresh getVariable ["name","?"]) + "|age=" + str (round (time - _fhT0)));
		};
	} else {
		//--- No valid dwell (first pick, elapsed, or invalidated): adopt the freshly-scored primary + restamp the clock.
		_logik setVariable ["wfbe_aicom_front_prim", _fhFresh];
		_logik setVariable ["wfbe_aicom_front_t0", time];
	};
};
//--- Telemetry: is the chosen primary actually on the front (vs a deep fallback)?
_anyFront = false;
if (count _targets > 0) then {
	_t = _targets select 0;
	if (_twCacheOn) then {
		_dNear = -1;
		{ if (_x == _t) exitWith {_dNear = _twCacheDNear select _forEachIndex} } forEach _twCacheTowns;
		if (_dNear < 0) then {
			_dNear = 1e9;
			{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
			if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
			_twCacheTowns set [count _twCacheTowns, _t];
			_twCacheDNear set [count _twCacheDNear, _dNear];
		};
	} else {
		_dNear = 1e9;
		{ _d = _t distance _x; if (_d < _dNear) then {_dNear = _d} } forEach _ownTownObjs;
		if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
	};
	_anyFront = (_dNear <= _frontRad);
};

//--- AICOMDBG (claude-gaming 2026-06-13): trace the commander's spearhead target choices
//--- (town + supply + distance-to-front + force) for the A/B ledger + debugging. Strategy
//--- runs on a ~60s cadence so this is paced, not hot-loop spam.
private ["_tDbg", "_dDbg", "_dd"];
{
	_tDbg = _x;
	if (_twCacheOn) then {
		_dDbg = -1;
		{ if (_x == _tDbg) exitWith {_dDbg = _twCacheDNear select _forEachIndex} } forEach _twCacheTowns;
		if (_dDbg < 0) then {
			_dDbg = 1e9;
			{ _dd = _tDbg distance _x; if (_dd < _dDbg) then {_dDbg = _dd} } forEach _ownTownObjs;
			if (_dDbg > 1e8) then {_dDbg = _tDbg distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
			_twCacheTowns set [count _twCacheTowns, _tDbg];
			_twCacheDNear set [count _twCacheDNear, _dDbg];
		};
	} else {
		_dDbg = 1e9;
		{ _dd = _tDbg distance _x; if (_dd < _dDbg) then {_dDbg = _dd} } forEach _ownTownObjs;
		if (_dDbg > 1e8) then {_dDbg = _tDbg distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};   //--- match the real scorer's HQ fallback (no 1e9 sentinel in telemetry)
	};
	diag_log ("AICOMDBG|v1|SPEARHEAD|" + (str _side) + "|" + str (round (time / 60)) + "|town=" + (_tDbg getVariable ["name", "?"]) + "|supply=" + str (_tDbg getVariable ["supplyValue", 0]) + "|distFront=" + str (round _dDbg) + "|onFront=" + str (_dDbg <= _frontRad) + "|teams=" + str (count _teams) + "|want=" + str _want + "|conc=" + str (missionNamespace getVariable ["WFBE_C_AICOM_CONCENTRATION", 3]));
} forEach _targets;

_logik setVariable ["wfbe_aicom_targets", _targets];

//--- 2) REACTIVE DEFENSE: relieve own towns under attack; release quiet reliefs.
{
	_team = _x;
	if (!isNull _team) then {
		_relTown = [_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
		if (!isNull _relTown) then {
			_quiet = !(_relTown getVariable ["wfbe_active", false]);
			private ["_relUnderAttack","_relEnemyDist"];
			_relUnderAttack = false;
			if ((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) > 0) then {
				_relEnemyDist = missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_ENEMY_DIST_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500]];
				if (!_quiet && {(_relTown getVariable ["sideID", -1]) == _sideID} && {({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _relTown) nearEntities [["Man","LandVehicle","Air"], _relEnemyDist])) > 0}) then {_relUnderAttack = true};
				_quiet = !_relUnderAttack;
			};
			//--- punchy-AICOM RELIEF-TIMEOUT (Ray 2026-06-17): also release once the hold window
			//--- has elapsed, so a diverted team returns to OFFENSE instead of idling on a town that
			//--- is no longer actively contested. SetTeamMoveMode "towns" immediately re-tasks it
			//--- (AssignTowns gives it a fresh attack order next cycle) - never a standing-still AI.
			private ["_relUntil","_relExpired","_relLost"];
			_relUntil = _team getVariable "wfbe_aicom_relief_until";
			if (isNil "_relUntil") then {_relUntil = 0};
			_relExpired = (_relUntil > 0) && {time > _relUntil};
			_relLost = (_relTown getVariable "sideID") != _sideID;
			if (_quiet || {_relLost} || {_relExpired && {!_relUnderAttack}}) then {
				//--- Town safe / lost / hold expired: release back to offense.
				_team setVariable ["wfbe_aicom_relief", objNull];
				_team setVariable ["wfbe_aicom_relief_until", 0];
				if (_relLost) then {
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RELIEF_TOWN_LOST|team=" + (str _team) + "|town=" + (_relTown getVariable ["name","town"]));
					//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): optional: also grudge a town lost despite a relief attempt (WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER, default 0)
					if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0 && {(missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER", 0]) > 0}) then {
											private ["_grDecay","_grMax","_grList","_grKeep","_grTrim","_grIdx"];
											_grDecay = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_DECAY", 2400];
											_grMax   = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_MAX_SITES", 3];
											_grList  = _logik getVariable ["wfbe_aicom_grudge", []];
											_grKeep  = [];
											{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _relTown}) then {_grKeep set [count _grKeep, _x]} } forEach _grList;
											if (count _grKeep >= _grMax) then {
												_grTrim = [];
												for "_grIdx" from ((count _grKeep) - _grMax + 1) to ((count _grKeep) - 1) do {_grTrim set [count _grTrim, _grKeep select _grIdx]};
												_grKeep = _grTrim;
											};
											_grKeep set [count _grKeep, [_relTown, time + _grDecay, false]];
											_logik setVariable ["wfbe_aicom_grudge", _grKeep];
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GRUDGE_STAMP|town=" + (_relTown getVariable ["name","town"]) + "|source=relief_lost|decay=" + str _grDecay);
					};
				};
				[_team, "towns"] Call SetTeamMoveMode;
			_team setVariable ["wfbe_aicom_foot_stage", false];
			_team setVariable ["wfbe_aicom_foot_stage_pos", []];
				_team setVariable ["wfbe_aicom_townorder", []];
				//--- WAVE-1 A3 (c): an HC team reads ONLY wfbe_aicom_order, not wfbe_teammode, so flip its order
				//--- back to a fresh "towns" seq here; AssignTowns then re-issues a real attack target next cycle.
				//--- Server-local teams ignore the order var and are driven by SetTeamMoveMode above (harmless).
				if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
					_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns", getPos (leader _team)], true];
				};
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] released from relief duty at [%3]%4.", _sideText, _team, _relTown getVariable ["name", "town"], if (_relExpired) then {" (hold expired -> offense)"} else {""}]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
} forEach _teams;

_attacked = [];
private ["_atkTownCheck","_reliefEnemyDist","_reliefMax"];
	_reliefEnemyDist = missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_ENEMY_DIST_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500]];
	//--- B74.1 (Ray 2026-06-23): only DEFEND a town that is ACTUALLY under attack, not merely "active". wfbe_active =
	//--- "town near the front/players" (server_town_ai.sqf:182), NOT "enemy attacking" - so the old gate yanked up to
	//--- RELIEF_MAX teams off offense to sit in QUIET front towns ("too defensive", Ray). Require a live hostile (enemy
	//--- side OR resistance, not civilian) within _reliefEnemyDist of the town centre. _atkTownCheck captures the outer
	//--- _x because the nearEntities count below rebinds _x. A2-OA-safe (nearEntities/side/alive/count).
	{
		_atkTownCheck = _x;
		if ((_atkTownCheck getVariable "sideID") == _sideID && {_atkTownCheck getVariable ["wfbe_active", false]}) then {
			if (({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _atkTownCheck) nearEntities [["Man","LandVehicle","Air"], _reliefEnemyDist])) > 0) then {_attacked = _attacked + [_atkTownCheck]};
		};
	} forEach towns;
//--- COMMAND-CENTER INSTRUCTION PANEL (PR1): honour a player-set DEFEND-town order from the command center. While
//--- the order is fresh (WFBE_C_AICOM_DEFEND_TTL) treat that town as "under attack" so the relief loop below diverts
//--- a reliever to it (additive + reversible + TTL-gated; offensive logic above is untouched). Server_HandleSpecial.sqf
//--- "aicom-defend" stamps wfbe_aicom_defend_focus + _t0. A2-OA-safe: plain getVariable + isNil + time math, no A3 prims.
_pdTown = _logik getVariable "wfbe_aicom_defend_focus";
_pdT0   = _logik getVariable "wfbe_aicom_defend_focus_t0";
if ((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) <= 0 && {!isNil "_pdTown"} && {!isNull _pdTown} && {!isNil "_pdT0"}
    && {(time - _pdT0) < (missionNamespace getVariable ["WFBE_C_AICOM_DEFEND_TTL", 300])}
    && {(_pdTown getVariable ["sideID", -1]) == _sideID}) then {
	if !(_pdTown in _attacked) then {_attacked = [_pdTown] + _attacked};
};
_relieved = 0;
{
	_town = _x;
	_reliefMax = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_RELIEF_MAX", 2];
	if (_relieved < _reliefMax) then {
		//--- Already has a reliever?
		_free = grpNull;
		{ if (!isNull _x && {([_x, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool) == _town}) exitWith {_free = _x} } forEach _teams;
		if (isNull _free) then {
			//--- Nearest eligible team: AI-led, alive, plain towns-mode (not garrison/strike/relief/HC).
			_freeD = 1e9;
			{
				_team = _x;
				if (!isNull _team && {!isPlayer (leader _team)} && {({alive _x} count (units _team)) > 0}) then {
					//--- B69 (relief-reliever-strength-gate): strength floor. Count alive bodies; exempt MBT/attack-heli
					//--- teams (vehicle is the punch). A2-OA safe: classname-literal isKindOf + getNumber transportSoldier
					//--- (no A3 primitives), classified off the team's LIVE assigned vehicles (mirror AssignTowns:275 idiom).
					private ["_relMinAlive","_relAlive","_relIsBigVeh","_veh"];
					_relMinAlive = missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_MIN_ALIVE_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_MIN_ALIVE", 4]];
					_relAlive    = {alive _x} count (units _team);
					_relIsBigVeh = false;
					{
						if (alive _x) then {
							_veh = vehicle _x;
							if (_veh != _x) then {
								if (_veh isKindOf "Tank") exitWith {_relIsBigVeh = true};
								if ((_veh isKindOf "Helicopter") && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _veh) >> "transportSoldier")) == 0}) exitWith {_relIsBigVeh = true};
							};
						};
					} forEach (units _team);
					if (_relIsBigVeh || {_relAlive >= _relMinAlive}) then {
						if ((toLower ([_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool)) == "towns") then {
							//--- WAVE-1 A3 (a): HC teams ARE now eligible for relief (the old !wfbe_aicom_hc exclusion made
							//--- relief dead - every commander team is HC-resident). HC dispatch handled below via the order var.
							//--- CAPTURE LOCK (GR-2026-07-03a): never DIVERT a mid-capture-drain team to relief (it would abandon a near-complete drain). CapLock
							//--- returns a plain BOOL and auto-clears once the town is captured/dead/TTL/flips-to-us, so the team becomes relief-eligible again.
							if (isNull ([_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool) && {!([_team, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team] Call WFBE_CO_FNC_CapLock)}) then { //--- fix(hunt): G1-safe (unstamped teams nil-poisoned the chain and were unpickable)
								_d = (leader _team) distance _town;
								if (_d < _freeD) then {_freeD = _d; _free = _team};
							};
						};
					}; //--- B69: close strength-floor if
				};
			} forEach _teams;
			if (!isNull _free) then {
				[_free, "defense"] Call SetTeamMoveMode;
				[_free, getPos _town] Call SetTeamMovePos;
				//--- WAVE-1 A3 (b): SetTeamMoveMode/MovePos only write wfbe_teammode/wfbe_teamgoto, which the HC
				//--- driver loop does NOT read - it reads ONLY wfbe_aicom_order. So for an HC team ALSO broadcast
				//--- a "defense" order at the town (mirror the HQ-strike order idiom below). Server-local teams
				//--- ignore the order var and use the SetTeamMove* writes above, so both paths stay covered.
				if ([_free, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
					_free setVariable ["wfbe_aicom_order", [(if (isNil {_free getVariable "wfbe_aicom_order"}) then {-1} else {(_free getVariable "wfbe_aicom_order") select 0}) + 1, "defense", getPos _town], true];
				};
				_free setVariable ["wfbe_aicom_relief", _town];
				_free setVariable ["wfbe_aicom_relief_until", time + (missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_HOLD_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_HOLD", 240]])]; //--- punchy-AICOM (Ray 2026-06-17): hold-window stamp; released back to offense when it expires.
				_relieved = _relieved + 1;
				_stratMode = "relief";
				_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] diverted to RELIEVE [%3] (under attack).", _sideText, _free, _town getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RELIEF|" + (_town getVariable ["name", "town"]));
			};
		} else {
			_relieved = _relieved + 1;
		};
	} else {
		diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RELIEF_CAP_SKIP|town=" + (_town getVariable ["name", "town"]) + "|relieved=" + str _relieved + "|cap=" + str _reliefMax);
	};
} forEach _attacked;

//--- WAVE-1 CAUSE-4 RELIEF/STRIKE WEDGE WATCHDOG (2026-06-19): teams in "defense" (relief) or "move"
//--- (HQ-strike) are EXCLUDED from the AssignTowns stuck detector (that only watches "towns"/"" mode),
//--- so a relief/strike team that physically wedges en route sits forever. Per team, keep a breadcrumb
//--- [leaderPos, time]; if it has not moved > WFBE_C_AICOM_STUCK_MOVED in > WFBE_C_AICOM_STUCK_SECS while
//--- NOT in COMBAT (a firefight is legit stationary), RELEASE it back to "towns" + clear relief/strike +
//--- refresh the HC order seq, so AssignTowns retargets it next cycle (never a standing-still AI).
{
	_wTeam = _x;
	if (!isNull _wTeam && {!isPlayer (leader _wTeam)} && {({alive _x} count (units _wTeam)) > 0}) then {
		_wMode = toLower ([_wTeam, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
		private "_wWatched";
		_wWatched = false;
		if (!([_wTeam, "wfbe_aicom_foot_stage", false] Call WFBE_CO_FNC_GroupGetBool)) then {
			switch (_wMode) do {
				case "defense": {_wWatched = true};
				case "move": {_wWatched = true};
			};
		};
		//--- Lane-325: last-stand recall deliberately parks defenders at HQ; do not let the
		//--- wedge watchdog release them back to offense while that round-state is active.
		if (_wWatched && {
			(!_lastStand) || {(missionNamespace getVariable ["WFBE_C_AICOM_WATCHDOG_LASTSTAND_SKIP", 1]) <= 0}
		}) then {
			_wLdr = leader _wTeam;
			if (!isNull _wLdr && {alive _wLdr} && {behaviour _wLdr != "COMBAT"}) then {
				//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
				_wBc = _wTeam getVariable "wfbe_aicom_wedge_bc";
				if (isNil "_wBc") then {
					//--- First sighting in this mode: drop a breadcrumb, judge next pass.
					_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos _wLdr, time]];
				} else {
					_wBcPos = _wBc select 0;
					_wBcT   = _wBc select 1;
					_wMoved = _wLdr distance _wBcPos;
					if (_wMoved > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_MOVED", 200])) then {
						//--- It moved: refresh the breadcrumb, not wedged.
						_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos _wLdr, time]];
					} else {
						if ((time - _wBcT) > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_SECS", 210])) then {
							//--- Wedged in defense/move with no progress + no contact: release back to offense.
							_wTeam setVariable ["wfbe_aicom_relief", objNull];
							_wTeam setVariable ["wfbe_aicom_relief_until", 0];
							_wTeam setVariable ["wfbe_aicom_strike", false];
							[_wTeam, "towns"] Call SetTeamMoveMode;
							_wTeam setVariable ["wfbe_aicom_foot_stage", false];
							_wTeam setVariable ["wfbe_aicom_foot_stage_pos", []];
							_wTeam setVariable ["wfbe_aicom_townorder", []];
							_wTeam setVariable ["wfbe_aicom_wedge_bc", nil];
							//--- cmdcon41-w2 (wedge-watchdog-resync-stuckstrikes): also clear the AssignTowns strike ladder.
							//--- A team that wedged in defense/move and is now released back to offense carries a stale
							//--- wfbe_aicom_stuckstrikes count from a PRIOR leg; leaving it set resumes the ladder mid-tier
							//--- (or trips a teleport recovery) on the fresh towns dispatch. Reset to 0 so the offense leg
							//--- starts the ladder clean. A2-OA-safe: plain setVariable on the group.
							_wTeam setVariable ["wfbe_aicom_stuckstrikes", 0];
							if ([_wTeam, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
								_wTeam setVariable ["wfbe_aicom_order", [(if (isNil {_wTeam getVariable "wfbe_aicom_order"}) then {-1} else {(_wTeam getVariable "wfbe_aicom_order") select 0}) + 1, "towns", getPos _wLdr], true];
							};
							["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] WEDGE-WATCHDOG released from %3 (no move %4m in %5s, not in contact) -> offense.", _sideText, _wTeam, _wMode, round _wMoved, round (time - _wBcT)]] Call WFBE_CO_FNC_AICOMLog;
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|WEDGE_RELEASE|team=" + (str _wTeam) + "|mode=" + _wMode + "|moved=" + str (round _wMoved));
						};
					};
				};
			} else {
				//--- In COMBAT or null leader: reset the breadcrumb so a post-firefight stall is judged fresh.
				_wTeam setVariable ["wfbe_aicom_wedge_bc", [getPos (leader _wTeam), time]];
			};
		} else {
			//--- Not watched right now (or last-stand skip is shielding HQ defenders): clear any stale breadcrumb.
			if (!isNil {_wTeam getVariable "wfbe_aicom_wedge_bc"}) then {_wTeam setVariable ["wfbe_aicom_wedge_bc", nil]};
		};
	};
} forEach _teams;

//--- cmdcon41-w2 GRACEFUL WITHDRAWAL EVALUATOR (Fable F3/graceful-withdrawal-evaluator-replaces-hc-blindspot).
//--- The Produce retreat/cull is gated !isPlayer && !wfbe_aicom_hc, so it NEVER runs for HC-resident teams (~100%
//--- of live teams in this 2-HC mission). A bled-out HC assault squad thus has no withdrawal path and dies on the
//--- march. This pass catches an HC team that is either (a) below WITHDRAW_MIN_ALIVE (3) live bodies and NOT already
//--- rallying, or (b) has had its driver raise wfbe_aicom_wantrally, and pulls it back to the NEAREST friendly rally
//--- (our HQ or an OWN-side town centre) via a fresh [seq+1,"rally",pos] HC order (the driver executes "rally" as a
//--- fighting bounding withdrawal, then re-engages). MBT / attack-heli teams are EXEMPT (the vehicle IS the punch;
//--- exemption idiom mirrors the relief big-veh detect ~L466-475). Flag WFBE_C_AICOM_WITHDRAW_EVAL default 1.
//--- A2-OA-safe: plain get + isNil for GROUP vars, classname-literal isKindOf + getNumber transportSoldier for the
//--- exemption, the proven seq-bump order idiom, lowercase exact-case mode literal "rally", no A3 primitives.
if ((missionNamespace getVariable ["WFBE_C_AICOM_WITHDRAW_EVAL", 1]) > 0) then {
	private ["_gwMinAlive","_gwHQ"];
	_gwMinAlive = missionNamespace getVariable ["WFBE_C_AICOM_WITHDRAW_MIN_ALIVE", 3];
	_gwHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
	{
		private ["_gwTeam","_gwHc","_gwLdr","_gwAlive","_gwWant","_gwRallying","_gwExempt","_gwVeh","_gwTrigger"];
		_gwTeam = _x;
		_gwHc = _gwTeam getVariable "wfbe_aicom_hc";
		if (!isNull _gwTeam && {!isNil "_gwHc"} && {_gwHc} && {!isPlayer (leader _gwTeam)}) then {
			_gwLdr = leader _gwTeam;
			if (!isNull _gwLdr && {alive _gwLdr}) then {
				_gwAlive = {alive _x} count (units _gwTeam);
				_gwWant = _gwTeam getVariable "wfbe_aicom_wantrally";
				if (isNil "_gwWant") then {_gwWant = false};
				_gwRallying = _gwTeam getVariable "wfbe_aicom_rallying";
				if (isNil "_gwRallying") then {_gwRallying = false};
				//--- MBT / attack-heli exemption (mirror the relief big-veh detect): a Tank, or a Helicopter whose
				//--- config transportSoldier == 0 (a gunship, not a transport). Never withdraw the vehicle punch.
				_gwExempt = false;
				{
					if (alive _x) then {
						_gwVeh = vehicle _x;
						if (_gwVeh != _x) then {
							if (_gwVeh isKindOf "Tank") exitWith {_gwExempt = true};
							if ((_gwVeh isKindOf "Helicopter") && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _gwVeh) >> "transportSoldier")) == 0}) exitWith {_gwExempt = true};
						};
					};
				} forEach (units _gwTeam);
				//--- Trigger: driver explicitly asked to rally, OR (understrength AND not already rallying). Exempt teams never trigger.
				_gwTrigger = false;
				if (!_gwExempt) then {
					if (_gwWant) then {_gwTrigger = true};
					private ["_gwCoolUntil"]; _gwCoolUntil = _gwTeam getVariable "wfbe_aicom_rally_cooldown_until"; if (isNil "_gwCoolUntil") then {_gwCoolUntil = 0}; //--- claude/aicom-west-stuck: rally re-arm cooldown (bug M) - group-safe 1-arg get + isNil (2-arg group default is the GROUPGETVAR trap)
					if (!_gwTrigger && {_gwAlive > 0} && {_gwAlive < _gwMinAlive} && {!_gwRallying} && {time >= _gwCoolUntil}) then {_gwTrigger = true}; //--- claude/aicom-west-stuck: cooldown-gated (was ungated) - blocks instant re-rally of a still-understrength team; the explicit driver wantrally arm one line above stays ungated
				};
				if (_gwTrigger) then {
					//--- Rally = NEAREST of [own HQ pos] + every OWN-side town centre. Hand-rolled scalar min (no A3 sort).
					private ["_gwRallyPos","_gwBestD","_gwLdrPos","_gwD"];
					_gwLdrPos = getPos _gwLdr;
					_gwRallyPos = [];
					_gwBestD = 1e9;
					if (!isNull _gwHQ) then {_gwRallyPos = getPos _gwHQ; _gwBestD = _gwLdr distance _gwHQ};
					{
						if ((_x getVariable ["sideID", -1]) == _sideID) then {
							_gwD = _gwLdr distance _x;
							if (_gwD < _gwBestD) then {_gwBestD = _gwD; _gwRallyPos = getPos _x};
						};
					} forEach towns;
					//--- Fallback: no HQ and no own town -> rally on our own current pos (never leave the team orderless).
					if (count _gwRallyPos == 0) then {_gwRallyPos = _gwLdrPos};
					//--- Broadcast a fresh rally order (seq-bump idiom, exact-case lowercase "rally"); clear want; mark rallying.
					_gwTeam setVariable ["wfbe_aicom_order", [(if (isNil {_gwTeam getVariable "wfbe_aicom_order"}) then {-1} else {(_gwTeam getVariable "wfbe_aicom_order") select 0}) + 1, "rally", _gwRallyPos], true];
					_gwTeam setVariable ["wfbe_aicom_wantrally", false, true];
					_gwTeam setVariable ["wfbe_aicom_rallying", true, true];
					//--- claude/aicom-west-stuck: stamp the per-team rally re-arm cooldown at ISSUE time (bug M root-cause). 2-arg server-local write, read only by this same server-side evaluator - the auto understrength trigger above cannot re-fire for WFBE_C_AICOM_WITHDRAW_COOLDOWN seconds, so a still-understrength team gets a bounded assault window under AssignTowns before it can be pulled back, ending the rally-arrive-rally livelock. Explicit driver wantrally requests bypass the gate and are never delayed. Not broadcast on purpose: only this server-side evaluator consults it, so no NSSETVAR3/cross-machine concern.
					_gwTeam setVariable ["wfbe_aicom_rally_cooldown_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_WITHDRAW_COOLDOWN", 240])];
					["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] GRACEFUL-WITHDRAW (%3 alive) -> rally at %4.", _sideText, _gwTeam, _gwAlive, _gwRallyPos]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RALLY_ORDER|team=" + (str _gwTeam) + "|alive=" + str _gwAlive + "|want=" + str _gwWant);
				};
			};
		};
	} forEach _teams;
};

//--- 3) HQ HUNT: strike when clearly winning; stand down when the edge is gone.
_enemyHQ = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
_wasStrike = _logik getVariable ["wfbe_aicom_strike_on", false];
_strikeOn = false;
//--- STEP 2 DECAP GATE (cutover build, GR-2026-07-03a): when WFBE_C_AICOM2_DECAP_ENABLE > 0, V2 Decapitate is the HQ-closer; suppress the V1 HQ-strike launch block so both do not run simultaneously. Flag-off (default 0) = byte-identical to HEAD.
if ((missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) <= 0) then {
//--- B69 (hqstrike-town-gate-fraction): scale the HQ-strike town gate to the live town count (was a dead literal _myTowns > 8). count towns = all capturable towns (40+ on live Chernarus).
private ["_hqFrac","_hqFloor","_strikeMinTowns"];
_hqFrac = missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_TOWN_FRAC", 0.5];
_hqFloor = missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_TOWN_FLOOR", 3];
_strikeMinTowns = missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS", 12]]; //--- B74.1 (Ray 2026-06-23): was ceil((count towns)*0.5) = ~20 on Chernarus (40+ towns) = UNREACHABLE, so the HQ-strike NEVER fired and the round never ended. Launch at an ABSOLUTE 12+ towns. The _hqFrac/_hqFloor lines around this are now inert (the floor clamp below is a no-op since 12 > 3).
if (_strikeMinTowns < _hqFloor) then {_strikeMinTowns = _hqFloor};
if (!isNull _enemyHQ && {alive _enemyHQ}) then {
	if (_wasStrike) then {
		_strikeOn = (_myTowns >= _strikeMinTowns) && (_myTowns >= _enemyTowns * 1.2) && (_myStr >= _enStr);          //--- B69 hysteresis: stay committed; gate now scales to ~half the map (was >8)
	} else {
		_strikeOn = (_myTowns >= _strikeMinTowns) && (_myTowns >= _enemyTowns * 1.5) && (_myStr >= _enStr * 1.1);   //--- B69 entry; Steff's rule: never HQ-rush while behind on towns (gate was >8, now ~half-map fraction)
	};
};
//--- B754 (Ray 2026-06-25) RELATIVE ROUND-CLOSER GATE + STALL OVERRIDE. The absolute 12-town gate (above) is
//--- unreachable in a lopsided game: the b753 soak had WEST hold 11 towns vs EAST's dug-in 2 (myEff 70 vs 53) yet
//--- never hit 12, so HQ-strike NEVER armed and the round ran 8.4h with no winner. Let a runaway leader close BELOW
//--- the absolute gate: fire when we out-town the enemy AND dominate on EFFECTIVE strength (maneuver + held-town
//--- credit) AND (enemy collapsed to <= ENEMY_MAX towns OR we hold a >= TOWN_RATIO town lead); plus a stall-override
//--- after STALL_OVERRIDE consecutive dominant-but-passive stalls. Effective strength is recomputed locally (the
//--- POSTURE block's _myEff/_enEff is computed later in the worker). Never fires while behind on towns/strength.
if (!isNull _enemyHQ && {alive _enemyHQ} && {_myTowns > _enemyTowns}) then {
	private ["_rTownStr","_rMyEff","_rEnEff"];
	_rTownStr = missionNamespace getVariable ["WFBE_C_AICOM_TOWN_STRENGTH", 2];
	_rMyEff = _myStr + (_myTowns * _rTownStr);
	_rEnEff = _enStr + (_enemyTowns * _rTownStr);
	if (_rMyEff >= _rEnEff) then {
		if ((_enemyTowns <= (missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_ENEMY_MAX_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_ENEMY_MAX", 2]])) || {_myTowns >= (_enemyTowns * (missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_TOWN_RATIO_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_TOWN_RATIO", 3]]))}) then {_strikeOn = true};
	};
	//--- D2 (cmdcon28): STALL-OVERRIDE now fires OUTSIDE the _rMyEff>=_rEnEff gate (was inside, which made it dead -
	//--- the streak only builds while town-dominant-but-strength-deficit, exactly the case that gate excluded). The
	//--- override breaks a frozen front the territorial leader can't convert (assault-reach ceiling). The streak only
	//--- accrues at >= STALL_TOWN_RATIO x towns and we're inside _myTowns>_enemyTowns, so it can never fire from behind.
	//--- Master flag WFBE_C_AICOM_STALL_OVERRIDE_ENABLE (default 1) for a clean one-switch revert.
	if (((missionNamespace getVariable ["WFBE_C_AICOM_STALL_OVERRIDE_ENABLE", 1]) > 0) && {(_logik getVariable ["wfbe_aicom_stall_streak", 0]) >= (missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_STALL_OVERRIDE_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_STALL_OVERRIDE", 5]])}) then {
		_strikeOn = true;
	};
};
//--- B752 (Ray 2026-06-25): STICKY STRIKE. The recall gate used RAW maneuver _myStr, which dips below the concentrated
//--- enemy the moment the leader garrisons towns -> the strike flapped off after ~30min (27x dominant-but-passive stall,
//--- 0 round-enders in the 12h soak). Keep it committed while EFFECTIVE strength (maneuver + held-town credit) still
//--- dominates, AND for a MIN_HOLD after launch regardless, so it can't abort mid-assault before the strikers reach the base.
if (_wasStrike && !_strikeOn && {!isNull _enemyHQ} && {alive _enemyHQ}) then {
	private ["_sTownStr","_sMyEff","_sEnEff"];
	_sTownStr = missionNamespace getVariable ["WFBE_C_AICOM_TOWN_STRENGTH", 2];
	_sMyEff = _myStr + (_myTowns * _sTownStr);
	_sEnEff = _enStr + (_enemyTowns * _sTownStr);
	if ((_myTowns >= _strikeMinTowns) && {_myTowns >= _enemyTowns * 1.2} && {_sMyEff >= _sEnEff}) then {_strikeOn = true};
	if (time - (_logik getVariable ["wfbe_aicom_strike_t0", -1e10]) < (missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_MIN_HOLD_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_MIN_HOLD", 600]])) then {_strikeOn = true};
};
}; //--- end DECAP GATE (V1 HQ-strike block)
if (_strikeOn) then {
	_stratMode = "strike";
	_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
	if (!_wasStrike) then {
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] WAR STATE: winning (towns %2v%3, strength %4v%5) - HQ STRIKE launched.", _sideText, _myTowns, _enemyTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
		_logik setVariable ["wfbe_aicom_strike_t0", time];
		_logik setVariable ["wfbe_aicom_stall_streak", 0]; //--- Lane-324: belt-and-suspenders guard (review: the else-branch at line ~1037 already zeros streak on every strike tick via !_strikeOn; this entry-only reset is redundant but harmless).
	};
	//--- cmdcon41-w2 STAGING-MASS (Fable F4/hqstrike-staging-rally-mass-before-assault; flag WFBE_C_AICOM_STRIKE_STAGE
	//--- default 1). Rather than trickle strikers onto the enemy HQ one team at a time (piecemeal, chewed up by the home
	//--- garrison), first MASS them at a rally point ~STRIKE_STAGE_DIST (800m) SHORT of the enemy HQ, then release the
	//--- whole fist onto the HQ once enough bodies have gathered OR a timeout elapses. While staging, strikers are issued
	//--- to the rally pos; on release every striker is re-issued to the enemy HQ (the existing strike order). Flag off ->
	//--- _strikeDest stays the enemy HQ from the first tick (legacy behaviour). A2-OA-safe: plain component segment math
	//--- (no BIS_fnc, no vectorNormalized reliance), scalar/time state on the side logic, string mode literals.
	private ["_strikeDest","_stgRallyPos"];
	_strikeDest = getPos _enemyHQ;
	_stgRallyPos = [];
	if ((missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_STAGE", 1]) > 0) then {
		private ["_stgDist","_stgBodiesNeed","_stgTimeout","_stgHQ","_stgEHQ","_stgHXpos","_stgEXpos","_stgDX","_stgDY","_stgLen","_stgUX","_stgUY","_stgReleased","_stgT0","_stgBodies"];
		_stgDist       = missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_STAGE_DIST", 800];
		_stgBodiesNeed = missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_STAGE_BODIES", 14];
		_stgTimeout    = missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT", 240];
		_stgHQ  = (_side) Call WFBE_CO_FNC_GetSideHQ;
		_stgEHQ = _enemyHQ;
		if (!isNull _stgEHQ && {!isNull _stgHQ}) then {
			_stgEXpos = getPos _stgEHQ;
			_stgHXpos = getPos _stgHQ;
			//--- Unit vector from our HQ toward the enemy HQ (plain components; guard zero length).
			_stgDX = (_stgEXpos select 0) - (_stgHXpos select 0);
			_stgDY = (_stgEXpos select 1) - (_stgHXpos select 1);
			_stgLen = sqrt ((_stgDX * _stgDX) + (_stgDY * _stgDY));
			if (_stgLen > _stgDist) then {
				_stgUX = _stgDX / _stgLen;
				_stgUY = _stgDY / _stgLen;
				//--- Rally = enemy HQ pulled back _stgDist along the line toward our HQ (i.e. _stgDist SHORT of the HQ).
				_stgRallyPos = [(_stgEXpos select 0) - (_stgUX * _stgDist), (_stgEXpos select 1) - (_stgUY * _stgDist), 0];
			} else {
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|STRIKE_STAGE_SKIP|reason=HQ_WITHIN_STAGE_DIST|dist=" + str (round _stgLen) + "|stageDist=" + str _stgDist);
			};
		};
		if (count _stgRallyPos > 0) then {
			_stgReleased = _logik getVariable ["wfbe_aicom_strike_staged", false];
			if (!_stgReleased) then {
				//--- Baseline the staging clock on the first staging tick of this strike.
				_stgT0 = _logik getVariable "wfbe_aicom_strike_stage_t0";
				if (isNil "_stgT0") then {_stgT0 = time; _logik setVariable ["wfbe_aicom_strike_stage_t0", _stgT0]};
				//--- Count alive striker bodies already gathered within STAGE_ARRIVE (400m) of the rally.
				private ["_stgArrive"]; _stgArrive = missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_STAGE_ARRIVE", 400];
				_stgBodies = 0;
				{ if (!isNull _x && {[_x, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool}) then { { if (alive _x && {(_x distance _stgRallyPos) < _stgArrive}) then {_stgBodies = _stgBodies + 1} } forEach (units _x) } } forEach _teams;
				if ((_stgBodies >= _stgBodiesNeed) || {(time - _stgT0) >= _stgTimeout}) then {
					//--- RELEASE: enough mass (or timed out). Re-issue EVERY striker to the enemy HQ and mark released.
					_logik setVariable ["wfbe_aicom_strike_staged", true];
					{
						_team = _x;
						if (!isNull _team && {[_team, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool} && {({alive _x} count (units _team)) > 0}) then {
							[_team, "move"] Call SetTeamMoveMode;
							_team setVariable ["wfbe_aicom_foot_stage", false];
							_team setVariable ["wfbe_aicom_foot_stage_pos", []];
							[_team, getPos _enemyHQ] Call SetTeamMovePos;
							if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
								_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "goto", getPos _enemyHQ], true];
							};
						};
					} forEach _teams;
				} else {
					//--- Still massing: newly-recruited strikers below are pointed at the rally, not the HQ.
					_strikeDest = _stgRallyPos;
				};
			};
		};
	};
	//--- Keep up to 3 strongest field teams on the strike (refill as strikers die).
	_strikeCount = 0;
	{ if (!isNull _x && {[_x, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool} && {({alive _x} count (units _x)) > 0}) then {_strikeCount = _strikeCount + 1} } forEach _teams;
	//--- B74.1 (Ray 2026-06-23): commit HALF the side's live field teams (was a flat 3) so a dominant side throws
		//--- real weight at the enemy base instead of a 3-team poke that never razed it. Floor at 3 for a small army.
		private ["_strikeLive","_strikeTarget"];
		_strikeLive = 0;
		{ if (!isNull _x && {!isPlayer (leader _x)} && {({alive _x} count (units _x)) > 0}) then {_strikeLive = _strikeLive + 1} } forEach _teams;
		_strikeTarget = ceil (_strikeLive * (missionNamespace getVariable [format ["WFBE_C_AICOM_HQSTRIKE_CAP_FRAC_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_HQSTRIKE_CAP_FRAC", 0.5]]));
		if (_strikeTarget < 3) then {_strikeTarget = 3};
		while {_strikeCount < _strikeTarget} do {
		_best = grpNull; _bestN = 1; //--- need at least 2 men to be worth sending
		{
			_team = _x;
			//--- CAPTURE LOCK (GR-2026-07-03a): do not GRAB a mid-capture-drain team for the HQ strike (it would abandon a near-complete drain).
			//--- WFBE_CO_FNC_CapLock is a plain BOOL and self-clears (captured/dead/TTL/town-ours), so the team is strike-eligible again after.
			if (!isNull _team && {!isPlayer (leader _team)} && {!([_team, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team] Call WFBE_CO_FNC_CapLock)}) then { //--- fix(hunt): G1-safe - freshly founded teams (no arrival yet) were silently unpickable for the HQ strike
				if (isNull ([_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool) && {(_logik getVariable ["wfbe_aicom_garrison", grpNull]) != _team}) then {
					_alive = {alive _x} count (units _team);
					if (_alive > 0) then {
						//--- F2 (fable/aicom-f2-strike-commit-f6, 2026-07-02): STRIKE-COMMIT guard. When WFBE_C_AICOM_STRIKE_COMMIT=1,
						//--- a team with an OPEN dispatch that is PROGRESSING toward its target (closed >=150m) is skipped for the
						//--- HQ strike-grab so an active journey is not killed. Default 0 = exact pre-F2 behaviour (nothing skipped).
						//--- Exemptions: recycle-flagged teams and genuinely-stuck teams (stuckstrikes >= WFBE_C_AICOM_STUCK_ABANDON).
						//--- Group-var idiom (fix(hunt) 2026-07-06): GROUP reads routed through WFBE_CO_FNC_GroupGetBool - the 2-arg
						//--- [name,default] form returns nil (not the default) on GROUP receivers when the var is unset (G1 trap),
						//--- which nil-poisoned these chains for never-stamped teams.
						//--- A2-OA 1.64: plain getVariable 2-arg + isNil, typeName OBJECT, numeric compare only, no Boolean ==/!=.
						private ["_scSkip","_scRecycle","_scStrk","_scOrd","_scTgt","_scBc","_scProg"];
						_scSkip = false;
						if ((missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_COMMIT", 0]) > 0) then {
							_scRecycle = [_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool;
							_scStrk = [_team, "wfbe_aicom_stuckstrikes", 0] Call WFBE_CO_FNC_GroupGetBool;
							if (isNil "_scStrk") then {_scStrk = 0};
							if (!_scRecycle && {_scStrk < (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_ABANDON", 4])}) then {
								if ([_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool) then {
									_scOrd = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
									if (count _scOrd >= 3) then {
										_scTgt = _scOrd select 0;
										_scBc  = _scOrd select 2;
										if (typeName _scTgt == "OBJECT" && {!isNull _scTgt}) then {
											if ((_scTgt getVariable ["sideID", -1]) != _sideID) then {
												_scProg = (_scBc distance _scTgt) - ((leader _team) distance _scTgt);
												if (_scProg >= 150) then {_scSkip = true};
											};
										};
									};
								};
							};
						};
						if (!_scSkip) then {
							//--- B69 (hqstrike-picker-weight-vehicle-punch): rank by PUNCH score, not raw bodycount. Heavy-detect idiom matches Common_AICOMServiceTick.sqf:103 (A2-OA-safe). _bestN now carries a score; inf 2 scores 2>1 (passes), 1-man remnant scores 1 (rejected), armour/attack-heli gets +bonus and outranks infantry.
							private ["_hasHeavy","_score"];
							_hasHeavy = {alive _x && {(vehicle _x) != _x} && {((vehicle _x) isKindOf "Tank") || {(vehicle _x) isKindOf "APC"} || {(vehicle _x) isKindOf "Air"}}} count (units _team);
							_score = _alive;
							if (_hasHeavy > 0) then {_score = _score + (missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_VEH_BONUS", 100])};
							//--- STRIKE AT BONUS (cmdcon43-pack2, WFBE_C_AICOM_STRIKE_AT_BONUS): extra score for launcher-carrying teams
							//--- so the AI prefers to send armed anti-tank teams at the enemy HQ.
							//--- Idiom from Common_RunCommanderTeam.sqf (RICH_GEAR scan ~L452): secondaryWeapon is the launcher slot for
							//--- AT/AA infantry in A2-OA; non-empty string = unit carries a launcher. Flag-off (0) adds 0 - fully inert.
							if ((missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_AT_BONUS", 0]) > 0) then {
								private ["_hasLauncher","_atBns"];
								_hasLauncher = 0;
								{ if (alive _x && {!(secondaryWeapon _x == "")}) then {_hasLauncher = _hasLauncher + 1} } forEach (units _team);
								if (_hasLauncher > 0) then {
									_atBns = missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_AT_BONUS", 0];
									_score = _score + _atBns;
								};
							};
							if (_score > _bestN) then {_bestN = _score; _best = _team};
						};
					};
				};
			};
		} forEach _teams;
		if (isNull _best) exitWith {};
		private "_bestAlive"; _bestAlive = {alive _x} count (units _best);
			_best setVariable ["wfbe_aicom_strike", true];
		[_best, "move"] Call SetTeamMoveMode;
		_best setVariable ["wfbe_aicom_foot_stage", false];
		_best setVariable ["wfbe_aicom_foot_stage_pos", []];
		//--- cmdcon41-w2 STAGING-MASS: while massing, point new strikers at the rally (_strikeDest = rally pos); once released it equals the enemy HQ.
		[_best, _strikeDest] Call SetTeamMovePos;
		if ([_best, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
			_best setVariable ["wfbe_aicom_order", [(if (isNil {_best getVariable "wfbe_aicom_order"}) then {-1} else {(_best getVariable "wfbe_aicom_order") select 0}) + 1, "goto", _strikeDest], true]; //--- HQ-STRIKE PRESS FIX (Ray): "defense" made the HC striker HOLD near the enemy HQ; "goto" routes through the driver else-branch (Common_RunCommanderTeam.sqf ~L749 = assault SAD WFBE_C_AICOM_ASSAULT_SAD onto _dest), so it PRESSES onto the HQ. Not "towns-target" (that triggers the town-depot capture phase, wrong for a base).
		};
		_strikeCount = _strikeCount + 1;
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] (%3 men) joins the HQ strike.", _sideText, _best, _bestAlive]] Call WFBE_CO_FNC_AICOMLog;
	};
} else {
	//--- cmdcon41-w2 STAGING-MASS: strike is OFF this tick - clear the staging state so the NEXT strike stages fresh
	//--- (rally-then-release from the top) instead of inheriting a stale released/timer from the previous strike.
	_logik setVariable ["wfbe_aicom_strike_staged", false];
	_logik setVariable ["wfbe_aicom_strike_stage_t0", nil];
	if (_wasStrike) then {
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] WAR STATE: edge lost (towns %2v%3, strength %4v%5) - strike recalled.", _sideText, _myTowns, _enemyTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
		{
			_team = _x;
			if (!isNull _team && {[_team, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool}) then {
				_team setVariable ["wfbe_aicom_strike", false];
				[_team, "towns"] Call SetTeamMoveMode;
			_team setVariable ["wfbe_aicom_foot_stage", false];
			_team setVariable ["wfbe_aicom_foot_stage_pos", []];
				_team setVariable ["wfbe_aicom_townorder", []];
			};
		} forEach _teams;
	};
};
_logik setVariable ["wfbe_aicom_strike_on", _strikeOn];

//--- B74.1 (Ray 2026-06-23) BASE OVERRUN -> makes the HQ-strike round-ender actually CLOSE the match. The win is the
//--- EXISTING supremacy condition (server_victory_threeway: enemy HQ dead + 0 factories), but A2 AI won't reliably
//--- shoot empty buildings, so a strike could besiege the base forever without winning. When our strikers have
//--- physically OVERRUN the enemy base - a striker unit on top of the enemy HQ AND the enemy cleared from it - raze the
//--- HQ + its production structures so the supremacy win fires next victory tick. NOT a new victory mode (Ray's
//--- constraint): it only destroys the structures the existing win already checks. A2-OA-safe (nearEntities/distance/setDamage).
if (_strikeOn && {!isNull _enemyHQ} && {alive _enemyHQ}) then {
	private ["_ovrDist","_ovrClear","_ovrRaze","_eHQpos","_ovrStrikers","_ovrEnemies"];
	_ovrDist  = missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_DIST", 250];
	_ovrClear = missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_CLEAR", 200];
	_ovrRaze  = missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_RAZE", 400];
	_eHQpos = getPos _enemyHQ;
	_ovrStrikers = 0;
	{ if (!isNull _x && {[_x, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool}) then { { if (alive _x && {(_x distance _eHQpos) < _ovrDist}) then {_ovrStrikers = _ovrStrikers + 1} } forEach (units _x) } } forEach _teams;
	_ovrEnemies = {alive _x && {(side _x) == _enemySide}} count (_eHQpos nearEntities [["Man","LandVehicle","Air"], _ovrClear]);
	//--- B752 (Ray 2026-06-25): the old "0 enemy within 200m" razing gate was UNSATISFIABLE vs an entrenched/respawning
	//--- home garrison (56-59 bodies) so a dominant strike besieged the base forever and the round NEVER closed (0 overruns
	//--- in the 12h soak). Now raze on: cleared OR an overwhelming striker:enemy ratio OR a SUSTAINED SIEGE (strikers held
	//--- at the base for N strategy ticks). A2-OA-safe (siege counter on the logik var); BASE_OVERRUN log records which path.
	private ["_ovrRatio","_ovrSiege","_ovrSiegeNeed","_ovrVia"];
	_ovrRatio = missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_RATIO", 2];
	_ovrSiegeNeed = missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_SIEGE_TICKS", 5];
	//--- cmdcon41 (REAL-BASE-ASSAULT P0-1 SIEGE DECAY): the legacy hard reset to 0 on ANY 0-striker tick meant
	//--- one momentary gap (a striker briefly leaving the _ovrDist radius, or all dying/reviving) wiped the whole
	//--- accumulated siege. When WFBE_C_AICOM_OVERRUN_SIEGE_DECAY (default 1) is on, DECAY by 1 (floored at 0)
	//--- instead of zeroing, so a sustained-but-flickering presence still counts up. Flag off -> legacy reset.
	if (_ovrStrikers > 0) then {
		_ovrSiege = (_logik getVariable ["wfbe_aicom_overrun_siege", 0]) + 1;
	} else {
		if ((missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_SIEGE_DECAY", 1]) > 0) then {
			_ovrSiege = ((_logik getVariable ["wfbe_aicom_overrun_siege", 0]) - 1) max 0;
		} else {
			_ovrSiege = 0;
		};
	};
	_logik setVariable ["wfbe_aicom_overrun_siege", _ovrSiege];
	_ovrVia = if (_ovrEnemies == 0) then {"clear"} else {if (_ovrStrikers >= (_ovrEnemies * _ovrRatio)) then {"ratio"} else {"siege"}};
	if (_ovrStrikers > 0 && {(_ovrEnemies == 0) || {_ovrStrikers >= (_ovrEnemies * _ovrRatio)} || {_ovrSiege >= _ovrSiegeNeed}}) then {
		//--- cmdcon41 (REAL-BASE-ASSAULT part 3): the win must come from REAL destruction (driver fire-phase + the now-
		//--- unblocked handleDamage). The scripted setDamage-1 raze is demoted to a FALLBACK gated by
		//--- WFBE_C_AICOM_OVERRUN_SCRIPTRAZE (default 0 = OFF). With scriptraze off we keep the SIEGE TELEMETRY (the
		//--- BASE_OVERRUN AICOMSTAT line) as info-only (via=assault-progress) so the soak still shows siege pressure,
		//--- but do NOT manufacture the base death. The existing victory FSM (server_victory_threeway) reads the real
		//--- HQ/factory state (!alive HQ && factories==0) and fires the win when units actually destroy them - that read
		//--- is untouched here (we only stop faking the state). Flag on -> legacy raze restored (one-flip rollback).
		if ((missionNamespace getVariable ["WFBE_C_AICOM_OVERRUN_SCRIPTRAZE", 0]) > 0) then {
			_enemyHQ setDamage 1;
			{ if (!isNull _x && {alive _x} && {(_x distance _eHQpos) < _ovrRaze}) then {_x setDamage 1} } forEach ((_enemySide) Call WFBE_CO_FNC_GetSideStructures);
			diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|BASE_OVERRUN|enemy HQ+factories razed|strikers=" + str _ovrStrikers + "|enemies=" + str _ovrEnemies + "|via=" + _ovrVia + "|siege=" + str _ovrSiege);
			["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] ENEMY BASE OVERRUN - razed enemy HQ + structures (strikers on objective, enemy cleared) -> supremacy win imminent.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
		} else {
			diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|BASE_OVERRUN|siege pressure at enemy base (no script-raze)|strikers=" + str _ovrStrikers + "|enemies=" + str _ovrEnemies + "|via=assault-progress|siege=" + str _ovrSiege);
			["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] ENEMY BASE UNDER SIEGE - strikers on objective (via=assault-progress); real weapon destruction earns the supremacy win, no script-raze.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
};

//--- POSTURE + FRONT telemetry (claude-gaming 2026-06-15): the commander's strategic STANCE and
//--- the war-state numbers that drive it. All metrics (_myTowns/_enemyTowns/_myStr/_enStr/_strikeOn/
//--- _attacked/_anyFront/_targets) are already computed this tick, so these are pure string builds -
//--- ZERO extra scan. POSTURE derives a 3-state stance from the already-computed ratios so the WHY
//--- (pressing vs consolidating vs defending) is explicit; FRONT reconstructs the front line (held /
//--- contested counts + the primary target's name and whether it borders our territory). Both ride
//--- the existing AI_Commander_Strategy worker (per side / ~60s; gated in AI_Commander.sqf:133-134).
private ["_posture","_postureReason","_primT","_townStr","_myEff","_enEff","_garBodies","_garTeams","_losingPress"];
//--- B69 territory-credited-press-gate: effective strength credits held towns (garrison bodies never counted in _myStr).
//--- POSTURE-gate ONLY; last-stand (l.66) + HQ-strike keep reading raw _myStr (those are maneuver-commit gates).
_townStr = missionNamespace getVariable ["WFBE_C_AICOM_TOWN_STRENGTH", 2];
_myEff = _myStr + (_myTowns * _townStr);
_enEff = _enStr + (_enemyTowns * _townStr);
if (_strikeOn) then {
	_posture = "HQ_STRIKE";
	_postureReason = "hq-strike";
} else {
	if (_myTowns < _enemyTowns) then {
		_posture = "DEFEND";
		_postureReason = "behind-towns";
	} else {
		if (_myEff < _enEff) then {
			_posture = "DEFEND";
			_postureReason = "behind-strength";
		} else {
			if (_myTowns >= (_enemyTowns * 1.2)) then {
				_posture = "PRESS";
				_postureReason = "winning";
			} else {
				_posture = "HOLD";
				_postureReason = "balanced";
			};
		};
	};
};
_losingPress = false;
//--- cmdcon41-w2 LOSING-SIDE PRESS FLOOR (Fable F7; flag WFBE_C_AICOM_LOSING_PRESS default 1). A losing side with an
//--- intact army must NOT park in DEFEND (the EAST-sat-in-DEFEND-min201-415 pattern). When we are BEHIND on territory
//--- (myTowns < enemyTowns) yet at rough strength parity (myEff >= 0.8 * enEff), NOT in last-stand, AND our own base is
//--- not itself under direct attack, floor the posture at PRESS so the commander keeps attacking to claw territory back.
//--- Never overrides HQ_STRIKE. A2-OA-safe: scalar math + nearEntities/side/alive/count for the base-threat probe; ==/!=
//--- only on string/scalar operands (posture strings), never on Booleans.
if (((missionNamespace getVariable ["WFBE_C_AICOM_LOSING_PRESS", 1]) > 0) && {!_strikeOn} && {!_lastStand} && {_myTowns < _enemyTowns} && {_myEff >= (_enEff * 0.8)}) then {
	private ["_lpBaseThreat","_lpHQ","_lpDist"];
	_lpBaseThreat = false;
	_lpHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
	_lpDist = missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_ENEMY_DIST_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500]];
	if (!isNull _lpHQ) then {
		if (({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _lpHQ) nearEntities [["Man","LandVehicle","Air"], _lpDist])) > 0) then {_lpBaseThreat = true};
	};
	if (!_lpBaseThreat) then {
		_posture = "PRESS";
		_postureReason = "losing-press-floor";
		_losingPress = true;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|LOSING_PRESS_FLOOR|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|myEff=" + str _myEff + "|enEff=" + str _enEff);
	};
};
//--- B69 garrison-body telemetry (stall-telemetry-add-garrison-bodies): how many bodies the leader has tied up in
//--- town OCCUPATION vs its maneuver _myStr. Pure observation, no behaviour change. Mirrors the existing _myStr idiom
//--- (L52): {alive _x} count (units _x), guarded by !isNull. One forEach over towns (~30) per side per ~60s strategy
//--- tick - negligible, server-side, paced. wfbe_town_teams may briefly hold null/empty groups -> guarded by !isNull.
_garBodies = 0;
{
	if ((_x getVariable "sideID") == _sideID) then {
		_garTeams = _x getVariable ["wfbe_town_teams", []];
		{
			if (!isNull _x) then { _garBodies = _garBodies + ({alive _x} count (units _x)) };
		} forEach _garTeams;
	};
} forEach towns;
diag_log ("AICOMSTAT|v1|POSTURE|" + _sideText + "|" + str (round (time / 60)) + "|" + _posture + "|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|myStr=" + str _myStr + "|enStr=" + str _enStr + "|myEff=" + str _myEff + "|enEff=" + str _enEff + "|townStr=" + str _townStr + "|garBodies=" + str _garBodies + "|reason=" + _postureReason + "|strikeOn=" + str _strikeOn);
_primT = if (count _targets > 0) then {_targets select 0} else {objNull};
diag_log ("AICOMSTAT|v1|FRONT|" + _sideText + "|" + str (round (time / 60)) + "|held=" + str _myTowns + "|enemyHeld=" + str _enemyTowns + "|contested=" + str (count _attacked) + "|primary=" + (if (isNull _primT) then {"none"} else {_primT getVariable ["name","?"]}) + "|onFront=" + str _anyFront);
//--- B58 SOAK DRAFT (2026-06-21, claude-gaming, propose-only): surface the DOMINANT-BUT-PASSIVE stall.
//--- The live soak FROZE at WEST 6 towns vs EAST 1 for ~5.5h with BOTH sides in DEFEND and ZERO new
//--- captures. Mechanism: the territorial leader garrisons many towns, so its MANEUVER strength (_myStr)
//--- dribbles BELOW the concentrated enemy's, which trips the "_myStr < _enStr -> DEFEND" gate above and
//--- PRESS never fires - the side that is WINNING on holdings goes passive. This is telemetry-ONLY (no
//--- behaviour change): emit a STALL flag whenever a side holds >=2x the enemy's towns yet is not PRESSing
//--- and is not under HQ strike, so future soak ticks make the freeze greppable and we can size the real
//--- fix (territory-weighted aggression / garrison-vs-maneuver strength split - see B57-SOAK-PROPOSALS.md).
//--- A2-OA-safe: pure diag_log, all operands already computed this tick; no sim/distance-gating; no antistack.
//--- D2 (cmdcon28, Ray 2026-06-30): ROUND-ENDER STALL-OVERRIDE FIX. The override counter must build whenever a side
//--- holds a sustained TOWN lead (>= STALL_TOWN_RATIO x enemy) and is NOT already striking - REGARDLESS of posture.
//--- Old bug: gated on (_posture != "PRESS"), so it reset on every PRESS tick AND only counted myEff<enEff stalls, which
//--- the override gate (myEff>=enEff, line ~579) then excluded - making the override structurally unreachable (live: EAST
//--- stalled 17x, 0 round-enders). Now: count sustained territory dominance; emit the STALL telemetry only for the
//--- PASSIVE subset (posture != PRESS) so the greppable signal keeps its original "dominant but idle" meaning.
//--- Lane 328: losing-press-floor ticks are recovery aggression, not dominant-side stall evidence.
private "_stallRatio"; _stallRatio = missionNamespace getVariable ["WFBE_C_AICOM_STALL_TOWN_RATIO", 2];
if ((_enemyTowns > 0) && {_myTowns >= (_enemyTowns * _stallRatio)} && {!_strikeOn} && {!_losingPress}) then {
	_logik setVariable ["wfbe_aicom_stall_streak", (_logik getVariable ["wfbe_aicom_stall_streak", 0]) + 1];
	if (_posture != "PRESS") then {
		diag_log ("AICOMSTAT|v1|STALL|" + _sideText + "|" + str (round (time / 60)) + "|posture=" + _posture + "|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|myStr=" + str _myStr + "|enStr=" + str _enStr + "|garBodies=" + str _garBodies + "|myEff=" + str _myEff + "|enEff=" + str _enEff + "|streak=" + str (_logik getVariable ["wfbe_aicom_stall_streak", 0]));
	};
} else {
	_logik setVariable ["wfbe_aicom_stall_streak", 0];
};
// END POSTURE + FRONT

//--- 4) ARTILLERY: soften the spearhead town or the enemy HQ - never near friendlies.
//--- fable/alife-arty-dwell (2026-07-08, owner request "enable the max 2 tracked artillery per AI commander
//--- idea... make sure it's used"): default flipped ON (was V0.6.3 owner-locked OFF; full history in
//--- Init_CommonConstants.sqf). DWELL-AGED SOFTENING added below: the longer the current front primary has
//--- been dwelled on, the shorter the cooldown - see WFBE_C_AICOM_ARTY_DWELL.
if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0) && {(missionNamespace getVariable "WFBE_C_ARTILLERY") > 0}) then {
	_upASel = (_logik getVariable ["wfbe_upgrades", [0,0,0,0,0,0,0,0,0,0,0]]) select WFBE_UP_ARTYTIMEOUT;
	_cd = (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select (_upASel min ((count (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS")) - 1));
	//--- fable/alife-arty-dwell DWELL TEMPO: shave WFBE_C_AICOM_ARTY_DWELL_K seconds off the cooldown per second
	//--- of front-dwell age (wfbe_aicom_front_t0, stamped unconditionally by the FRONT_DWELL hysteresis block
	//--- above - L375-410 - regardless of whether artillery is even enabled), floored at
	//--- WFBE_C_AICOM_ARTY_DWELL_FLOOR so it never becomes full-auto spam. Dwell age is naturally bounded by
	//--- WFBE_C_AICOM_FRONT_DWELL (~480s default - the hysteresis block restamps t0 once it elapses), so the max
	//--- shrink is bounded too. Flag-gated (WFBE_C_AICOM_ARTY_DWELL, default ON) - one flip reverts to the
	//--- legacy flat per-upgrade-tier cooldown.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_DWELL", 1]) > 0) then {
		private ["_dwT0","_dwAge","_dwK","_dwFloor"];
		_dwT0 = _logik getVariable "wfbe_aicom_front_t0";
		if (!isNil "_dwT0") then {
			_dwAge   = (time - _dwT0) max 0;
			_dwK     = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_DWELL_K", 0.5];
			_dwFloor = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_DWELL_FLOOR", 120];
			_cd = (_cd - (_dwAge * _dwK)) max _dwFloor;
		};
	};
	//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) ARTY HOOK: a player ARTILLERY-HERE request
	//--- (Server_HandleSpecial "aicom-arty-here" stamps wfbe_aicom_arty_request=[pos,time]). When fresh it
	//--- targets the requested pos AND bypasses the AI's own fire cooldown so the call-in actually fires; the
	//--- request is CLEARED after this block so it fires exactly once. Additive, reversible, TTL-gated.
	private ["_riArtyReq","_riArtyPos","_riArtyT0","_riArtyFresh","_riArtyX","_riArtyY","_grudgeArtyReq","_grudgeArtyPos","_grudgeArtyT0","_grudgeArtyFresh","_grudgeArtyX","_grudgeArtyY","_grudgeArtyUse"];
	_riArtyReq = _logik getVariable "wfbe_aicom_arty_request";
	_riArtyPos = []; _riArtyFresh = false;
	if (!isNil "_riArtyReq" && {typeName _riArtyReq == "ARRAY"} && {count _riArtyReq == 2}) then {
		_riArtyPos = _riArtyReq select 0; _riArtyT0 = _riArtyReq select 1;
		if ((typeName _riArtyPos == "ARRAY") && {count _riArtyPos >= 2} && {typeName _riArtyT0 == "SCALAR"}) then {
			_riArtyX = _riArtyPos select 0; _riArtyY = _riArtyPos select 1;
			if ((typeName _riArtyX == "SCALAR") && {typeName _riArtyY == "SCALAR"} && {(time - _riArtyT0) < (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_REQUEST_TTL", 120])}) then {_riArtyFresh = true};
		};
	};
	//--- GRUDGE BARRAGE: consume the dedicated server-local request through this AI-only
	//--- artillery block. Keeping it off the player request key preserves the AI artillery gates.
	_grudgeArtyReq = _logik getVariable "wfbe_aicom_grudge_barrage_request";
	_grudgeArtyPos = []; _grudgeArtyFresh = false;
	if (!isNil "_grudgeArtyReq" && {typeName _grudgeArtyReq == "ARRAY"} && {count _grudgeArtyReq == 2}) then {
		_grudgeArtyPos = _grudgeArtyReq select 0; _grudgeArtyT0 = _grudgeArtyReq select 1;
		if ((typeName _grudgeArtyPos == "ARRAY") && {count _grudgeArtyPos >= 2} && {typeName _grudgeArtyT0 == "SCALAR"}) then {
			_grudgeArtyX = _grudgeArtyPos select 0; _grudgeArtyY = _grudgeArtyPos select 1;
			if ((typeName _grudgeArtyX == "SCALAR") && {typeName _grudgeArtyY == "SCALAR"} && {(time - _grudgeArtyT0) < (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_REQUEST_TTL", 120])}) then {_grudgeArtyFresh = true};
		};
	};
	//--- An explicit player call keeps priority; leave a simultaneous grudge request for the next tick.
	_grudgeArtyUse = _grudgeArtyFresh && {!_riArtyFresh};
	if ((time - (_logik getVariable ["wfbe_aicom_arty_last", -1e6]) > _cd) || _riArtyFresh || _grudgeArtyUse) then {
		//--- Target: enemy HQ during a strike, else the LIVE fist Allocate/AssignTowns are actually pressing
		//--- this tick (_liveFistSnap, captured at the top of this worker before it gets overwritten - see the
		//--- fable/alife-arty-dwell note there), falling back to this worker's own freshly-scored _targets only
		//--- if no live fist is published yet (first tick, or AICOM2_ALLOCATE_ENABLE is off and this is the
		//--- very first Strategy pass this side). Fixes the V1-scorer-vs-Allocate-fist divergence: previously
		//--- this could shell a DIFFERENT town than the one teams were actually assaulting.
		_artyTgt = [];
		if (_strikeOn && {!isNull _enemyHQ} && {alive _enemyHQ}) then {_artyTgt = getPos _enemyHQ};
		if (count _artyTgt == 0 && {count _liveFistSnap > 0}) then {_artyTgt = getPos (_liveFistSnap select 0)};
		if (count _artyTgt == 0 && {count _targets > 0}) then {_artyTgt = getPos (_targets select 0)};
		//--- Request hooks: grudge overrides the auto target; an explicit player call wins if both are fresh.
		if (_grudgeArtyUse) then {_artyTgt = _grudgeArtyPos};
		if (_riArtyFresh) then {_artyTgt = _riArtyPos};
		if (count _artyTgt > 0) then {
			//--- Friendly-fire guard: no own troops near the impact zone.
			_ownNear = 0;
			{ if (side _x == _side && {alive _x}) then {_ownNear = _ownNear + 1} } forEach (_artyTgt nearEntities [["Man","Car","Tank","Air"], 400]);
			if (_ownNear == 0) then {
				//--- Our base guns (built by the Base worker, tagged by Construction_StationaryDefense).
				//--- Ray 2026-06-29 SELF-PROPELLED-ONLY: scan only vehicle hulls (Tank/Car/Wheeled/Tracked APC), NOT
				//--- StaticWeapon - the AI fires only tracked/wheeled self-propelled artillery, never a static gun.
				private "_ech2"; _ech2 = (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ECHELON", 0]) > 0; //--- claude 2026-07-18 forward-arty echelon; 0 = original near-HQ discovery + no reposition (byte-identical to HEAD).
				if (_ech2) then {
					//--- ECHELON: discover via the explicit registry - a gun that repositioned forward is no longer within 250m
					//--- of HQ, so the near-HQ scan would silently lose it. Prune to live / tagged / own-side pieces.
					private ["_reg3","_regLive3"];
					_reg3 = _logik getVariable ["wfbe_aicom_arty_reg", []];
					if (typeName _reg3 != "ARRAY") then {_reg3 = []};
					_regLive3 = [];
					{ if (!isNull _x && {alive _x} && {(_x getVariable ["WFBE_CommanderArtillery", false])} && {(_x getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText}) then {_regLive3 set [count _regLive3, _x]} } forEach _reg3;
					_logik setVariable ["wfbe_aicom_arty_reg", _regLive3];
					_pieces = _regLive3;
				} else {
					_pieces = (getPos ((_side) Call WFBE_CO_FNC_GetSideHQ)) nearEntities [["Tank","Car","Wheeled_APC","Tracked_APC"], 250];
				};
				_fired = false;
				{
					_p = _x;
					if (alive _p && {[_p, _side] Call IsMobileArtillery} && {(_p getVariable ["WFBE_CommanderArtillery", false])} && {(_p getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {!isNull (gunner _p)} && {alive (gunner _p)} && {someAmmo _p}) then {
						_idx = [typeOf _p, _side] Call IsArtillery;
						if (_idx >= 0) then {
							_maxR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _sideText]) select _idx) / (missionNamespace getVariable "WFBE_C_ARTILLERY");
							_inRange = (_p distance _artyTgt <= _maxR) && {((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_REQUIRE_TOWN", 0]) <= 0) || {({(_p distance _x) <= (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_TOWN_RANGE", 300])} count _ownTownObjs) > 0}}; //--- Ray 2026-06-29: AICOM arty fires only when SUPPORTED from a captured town (gun within ARTY_TOWN_RANGE of a friendly town centre); flag-gated WFBE_C_AICOM_ARTY_REQUIRE_TOWN (default 0=off/inert).
							if (_inRange) then { //--- review-fix (fable 2026-07-21, PR #1159 drain): reposition must be evaluated even when another gun already fired this cycle - only the FIRE action itself stays single-fire-gated.
								if (!_fired) then {
									//--- AMMO-TYPE SELECT (claude-gaming 2026-06-29, flag WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE default OFF):
									//--- load a situational round (illum at night, cluster vs armour) chosen ONLY from the types the side has
									//--- researched (helper gates on WFBE_UP_ARTYAMMO via GetArtilleryAmmoOptions). Off / HE-only -> default HE.
									[_p, _side, _idx, _artyTgt] Call WFBE_CO_FNC_AICOMArtyPickAmmo;
									[_p, _artyTgt, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;
									_logik setVariable ["wfbe_aicom_arty_last", time];
									_fired = true;
									if (_ech2) then {_p setVariable ["wfbe_arty_state", "firing"]};
									["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] FIRE MISSION [%2] at %3 (cooldown %4s).", _sideText, typeOf _p, _artyTgt, _cd]] Call WFBE_CO_FNC_AICOMLog;
							diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FIRE_MISSION|" + (typeOf _p));
								};
							} else {
								//--- ECHELON REPOSITION: the gun cannot service this target from here (out of range or unsupported).
								//--- Rather than silently poll, redeploy it via PlaceSafe (the shipped relocation primitive, same as the
								//--- tactical travel-with teleport) to a SAFE owned-town anchor in range + behind the front, emitting ONE
								//--- explicit transition. Base guns are gunner-only emplacements (no driver), so a road-march is unavailable.
								if (_ech2) then {
									private ["_reCd","_reLast","_anchor","_enemyClose"];
									_reCd = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ECHELON_REPOS_CD", 180];
									_reLast = _p getVariable ["wfbe_arty_repos_last", -1e9];
									if ((time - _reLast) > _reCd) then {
										_p setVariable ["wfbe_arty_repos_last", time]; //--- stamp regardless of outcome: bounds the owned-town scan to once per cooldown.
										_anchor = [_side, _p, _artyTgt, _maxR, _ownTownObjs] Call WFBE_CO_FNC_AICOMArtySafeAnchor;
										if (count _anchor > 0) then {
											//--- never redeploy a gun that is in contact (mirror the ServiceTick never-out-of-fight guard).
											//--- review-fix (codex reject 2026-07-19, HIGH): was `side _x == _enemySide` - _enemySide is the
											//--- SINGLE strategy-target enemy (binary WEST/EAST, set at file top for the town-targeting loop -
											//--- intentional there, NOT touched here), so a GUER unit standing next to the gun never counted
											//--- as "in contact" and the gun could be redeployed OUT of a live GUER fight. Use the repo-wide
											//--- any-hostile idiom (Common_RunCommanderTeam.sqf threat checks, AI_Commander_DisbandLowTier.sqf,
											//--- AI_Commander_Teams.sqf: side!=own && side!=civilian) instead - counts EVERY hostile faction.
											_enemyClose = {alive _x && {side _x != _side} && {side _x != civilian}} count ((getPos _p) nearEntities [["Man","LandVehicle"], (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ECHELON_SAFE_DIST", 400])]);
											if (_enemyClose == 0) then {
												[_p, _anchor, 40] Call PlaceSafe;
												if ((_p getVariable ["wfbe_arty_state", ""]) != "repositioning") then {
													_p setVariable ["wfbe_arty_state", "repositioning"];
													["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] ARTY REPOSITION [%2] to safe anchor %3 (target %4 out of range/support, maxR %5m).", _sideText, typeOf _p, _anchor, _artyTgt, round _maxR]] Call WFBE_CO_FNC_AICOMLog;
													diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ARTY_REPOSITION|" + (typeOf _p) + "|d=" + str (round (_p distance _artyTgt)));
												};
											};
										} else {
											//--- no safe in-range owned-town anchor exists -> emit ONE no-anchor transition (debounced) so out-of-range is never silent.
											if ((_p getVariable ["wfbe_arty_state", ""]) != "noanchor") then {
												_p setVariable ["wfbe_arty_state", "noanchor"];
												diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ARTY_NO_ANCHOR|" + (typeOf _p) + "|tgtd=" + str (round (_p distance _artyTgt)) + "|maxR=" + str (round _maxR));
											};
										};
									};
								};
							};
						};
					};
				} forEach _pieces;
			};
		};
	};
	//--- GRUDGE BARRAGE: consume the selected request once, even when no gun can service it.
	if (_grudgeArtyUse) then {
		_logik setVariable ["wfbe_aicom_grudge_barrage_request", []];
		_logik setVariable ["wfbe_aicom_arty_last", time];
	};
	//--- COMMAND CONSOLE ARTY HOOK: consume the player request (fire-once) - clear it whether or not a gun was in range.
	if (_riArtyFresh) then {
		_logik setVariable ["wfbe_aicom_arty_request", []];
		//--- Lane-326: stamp cooldown timer at the request-clear point so that when no gun is
		//--- in range the next cadence tick cannot fire a free salvo on an unstamped timer.
		_logik setVariable ["wfbe_aicom_arty_last", time];
	};
};

if !(isNil "PerformanceAudit_Record") then {
	["aicom_strategy", diag_tickTime - _perfStart, Format["side:%1;teams:%2;myTowns:%3;enemyTowns:%4;targets:%5;attacked:%6;posture:%7;strike:%8;myStr:%9;enStr:%10;garBodies:%11;onFront:%12", _sideText, count _teams, _myTowns, _enemyTowns, count _targets, count _attacked, _posture, _strikeOn, _myStr, _enStr, _garBodies, _anyFront], "SERVER"] Call PerformanceAudit_Record;
};
