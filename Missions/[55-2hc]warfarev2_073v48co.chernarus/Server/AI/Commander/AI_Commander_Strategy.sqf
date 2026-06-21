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

private ["_side","_sideID","_sideText","_logik","_teams","_enemySide","_enemyID","_enemyLogik","_myTowns","_enemyTowns","_myStr","_enStr","_team","_alive","_strikeOn","_wasStrike","_enemyHQ","_strikers","_strong","_best","_bestN","_i","_targets","_cands","_t","_score","_bestScore","_bestTown","_dNear","_d","_perTeam","_want","_attacked","_relieved","_town","_free","_freeD","_cd","_artyTgt","_pieces","_p","_idx","_maxR","_fired","_upASel","_relTown","_relAge","_quiet","_strikeCount","_ownNear","_frontRad","_distDiv","_hqDiv","_farPen","_enemyHQForRank","_dHQ","_onFront","_anyFront","_wTeam","_wMode","_wLdr","_wBc","_wBcPos","_wBcT","_wMoved","_lastStand","_stratMode","_spBl","_spBlTowns","_spBlKeep","_spBlCd","_spPrevPrim","_spApproach","_spBest","_spLast","_spStall"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

//--- Primary foe = the other commanding side (the defender never gets HQ-hunted).
_enemySide = if (_side == west) then {east} else {west};
if (!(_enemySide in WFBE_PRESENTSIDES)) exitWith {};
_enemyID = (_enemySide) Call WFBE_CO_FNC_GetSideID;
_enemyLogik = (_enemySide) Call WFBE_CO_FNC_GetSideLogic;

//--- War state metrics.
_myTowns = 0; _enemyTowns = 0;
{
	if ((_x getVariable "sideID") == _sideID) then {_myTowns = _myTowns + 1};
	if ((_x getVariable "sideID") == _enemyID) then {_enemyTowns = _enemyTowns + 1};
} forEach towns;
_myStr = 0;
{ if (!isNull _x) then {_myStr = _myStr + ({alive _x} count (units _x))} } forEach _teams;
_enStr = 0;
{ if (!isNull _x) then {_enStr = _enStr + ({alive _x} count (units _x))} } forEach (_enemyLogik getVariable ["wfbe_teams", []]);

//--- 0) LAST-STAND: fewer than 2 own towns AND clearly outnumbered - recall all, skip attack.
_lastStand = (_myTowns < 2) && (_myStr < (_enStr * 0.7));
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
	//--- Recall every non-garrison, non-HC AI team to HQ in defense posture.
	{
		_team = _x;
		if (!isNull _team && {!isPlayer (leader _team)}) then {
			//--- Clear relief and strike flags.
			_team setVariable ["wfbe_aicom_relief", objNull];
			_team setVariable ["wfbe_aicom_strike", false];
			_team setVariable ["wfbe_aicom_townorder", []];
			[_team, "defense"] Call SetTeamMoveMode;
			[_team, getPos ((_side) Call WFBE_CO_FNC_GetSideHQ)] Call SetTeamMovePos;
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
_cands = [];
{ if ((_x getVariable "sideID") != _sideID) then {_cands = _cands + [_x]} } forEach towns;
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
_frontRad = missionNamespace getVariable ["WFBE_C_AICOM_FRONTIER_RADIUS", 3000];
_distDiv  = missionNamespace getVariable ["WFBE_C_AICOM_DISTANCE_DIVISOR", 50];
if (_distDiv <= 0) then {_distDiv = 1};
_hqDiv    = missionNamespace getVariable ["WFBE_C_AICOM_HQ_PULL_DIVISOR", 250];
_farPen   = missionNamespace getVariable ["WFBE_C_AICOM_FAR_PENALTY", 1000];
//--- Enemy HQ for the directional pull (cached once; nil-safe - 0 pull if no HQ object).
_enemyHQForRank = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
//--- Concentrate force: split across FEW towns (cap via SPEARHEAD_TOWNS_MAX), not the old
//--- ceil(teams / per-town) which scattered into 3+ cities at one effective team each.
_want = 1 max (missionNamespace getVariable ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX", 2]);
_want = _want min (count _cands);
_targets = [];
for "_i" from 1 to _want do {
	_bestScore = -1e9; _bestTown = objNull;
	{
		_t = _x;
		if (!(_t in _targets)) then {
			//--- Frontline distance = to our nearest OWN town (fallback: our HQ) = the
			//--- coherent-front / adjacency signal. Small dNear = borders owned territory.
			_dNear = 1e9;
			{ if ((_x getVariable "sideID") == _sideID) then {_d = _t distance _x; if (_d < _dNear) then {_dNear = _d}} } forEach towns;
			if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
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
			//--- Off-front towns take a flat penalty so a fat deep city can't outrank a
			//--- near contestable one. Towns on the front are unpenalised and win.
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
			_wMode = toLower (_team getVariable ["wfbe_teammode", "towns"]);
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
		_cands = [];
		{ if ((_x getVariable "sideID") != _sideID) then {_cands = _cands + [_x]} } forEach towns;
		private ["_candsF"];
		_candsF = _cands - _spBlTowns;
		if (count _candsF == 0) then {
			//--- only the just-blacklisted town was eligible: clear it so a target ALWAYS exists.
			_logik setVariable ["wfbe_aicom_spearhead_bl", []];
		} else {
			_cands = _candsF;
		};
		_want = 1 max (missionNamespace getVariable ["WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX", 2]);
		_want = _want min (count _cands);
		//--- Re-run the SAME scorer (identical weights) over the trimmed candidate set.
		_targets = [];
		for "_i" from 1 to _want do {
			_bestScore = -1e9; _bestTown = objNull;
			{
				_t = _x;
				if (!(_t in _targets)) then {
					_dNear = 1e9;
					{ if ((_x getVariable "sideID") == _sideID) then {_d = _t distance _x; if (_d < _dNear) then {_dNear = _d}} } forEach towns;
					if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
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
					_wMode = toLower (_team getVariable ["wfbe_teammode", "towns"]);
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
//--- Telemetry: is the chosen primary actually on the front (vs a deep fallback)?
_anyFront = false;
if (count _targets > 0) then {
	_t = _targets select 0;
	_dNear = 1e9;
	{ if ((_x getVariable "sideID") == _sideID) then {_d = _t distance _x; if (_d < _dNear) then {_dNear = _d}} } forEach towns;
	if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
	_anyFront = (_dNear <= _frontRad);
};

//--- AICOMDBG (claude-gaming 2026-06-13): trace the commander's spearhead target choices
//--- (town + supply + distance-to-front + force) for the A/B ledger + debugging. Strategy
//--- runs on a ~60s cadence so this is paced, not hot-loop spam.
private ["_tDbg", "_dDbg", "_dd"];
{
	_tDbg = _x;
	_dDbg = 1e9;
	{ if ((_x getVariable "sideID") == _sideID) then {_dd = _tDbg distance _x; if (_dd < _dDbg) then {_dDbg = _dd}} } forEach towns;
	if (_dDbg > 1e8) then {_dDbg = _tDbg distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};   //--- match the real scorer's HQ fallback (no 1e9 sentinel in telemetry)
	diag_log ("AICOMDBG|v1|SPEARHEAD|" + (str _side) + "|" + str (round (time / 60)) + "|town=" + (_tDbg getVariable ["name", "?"]) + "|supply=" + str (_tDbg getVariable ["supplyValue", 0]) + "|distFront=" + str (round _dDbg) + "|onFront=" + str (_dDbg <= _frontRad) + "|teams=" + str (count _teams) + "|want=" + str _want + "|conc=" + str (missionNamespace getVariable ["WFBE_C_AICOM_CONCENTRATION", 3]));
} forEach _targets;

_logik setVariable ["wfbe_aicom_targets", _targets];

//--- 2) REACTIVE DEFENSE: relieve own towns under attack; release quiet reliefs.
{
	_team = _x;
	if (!isNull _team) then {
		_relTown = _team getVariable ["wfbe_aicom_relief", objNull];
		if (!isNull _relTown) then {
			_quiet = !(_relTown getVariable ["wfbe_active", false]);
			//--- punchy-AICOM RELIEF-TIMEOUT (Ray 2026-06-17): also release once the hold window
			//--- has elapsed, so a diverted team returns to OFFENSE instead of idling on a town that
			//--- is no longer actively contested. SetTeamMoveMode "towns" immediately re-tasks it
			//--- (AssignTowns gives it a fresh attack order next cycle) - never a standing-still AI.
			private ["_relUntil","_relExpired"];
			_relUntil = _team getVariable "wfbe_aicom_relief_until";
			if (isNil "_relUntil") then {_relUntil = 0};
			_relExpired = (_relUntil > 0) && {time > _relUntil};
			if (_quiet || {(_relTown getVariable "sideID") != _sideID} || _relExpired) then {
				//--- Town safe / lost / hold expired: release back to offense.
				_team setVariable ["wfbe_aicom_relief", objNull];
				_team setVariable ["wfbe_aicom_relief_until", 0];
				[_team, "towns"] Call SetTeamMoveMode;
				_team setVariable ["wfbe_aicom_townorder", []];
				//--- WAVE-1 A3 (c): an HC team reads ONLY wfbe_aicom_order, not wfbe_teammode, so flip its order
				//--- back to a fresh "towns" seq here; AssignTowns then re-issues a real attack target next cycle.
				//--- Server-local teams ignore the order var and are driven by SetTeamMoveMode above (harmless).
				if (_team getVariable ["wfbe_aicom_hc", false]) then {
					_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns", getPos (leader _team)], true];
				};
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] released from relief duty at [%3]%4.", _sideText, _team, _relTown getVariable ["name", "town"], if (_relExpired) then {" (hold expired -> offense)"} else {""}]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
} forEach _teams;

_attacked = [];
{ if ((_x getVariable "sideID") == _sideID && {_x getVariable ["wfbe_active", false]}) then {_attacked = _attacked + [_x]} } forEach towns;
_relieved = 0;
{
	_town = _x;
	if (_relieved < (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_RELIEF_MAX", 2])) then {
		//--- Already has a reliever?
		_free = grpNull;
		{ if (!isNull _x && {(_x getVariable ["wfbe_aicom_relief", objNull]) == _town}) exitWith {_free = _x} } forEach _teams;
		if (isNull _free) then {
			//--- Nearest eligible team: AI-led, alive, plain towns-mode (not garrison/strike/relief/HC).
			_freeD = 1e9;
			{
				_team = _x;
				if (!isNull _team && {!isPlayer (leader _team)} && {({alive _x} count (units _team)) > 0}) then {
					if ((toLower (_team getVariable ["wfbe_teammode", "towns"])) == "towns") then {
						//--- WAVE-1 A3 (a): HC teams ARE now eligible for relief (the old !wfbe_aicom_hc exclusion made
						//--- relief dead - every commander team is HC-resident). HC dispatch handled below via the order var.
						if (isNull (_team getVariable ["wfbe_aicom_relief", objNull]) && {!(_team getVariable ["wfbe_aicom_strike", false])}) then {
							_d = (leader _team) distance _town;
							if (_d < _freeD) then {_freeD = _d; _free = _team};
						};
					};
				};
			} forEach _teams;
			if (!isNull _free) then {
				[_free, "defense"] Call SetTeamMoveMode;
				[_free, getPos _town] Call SetTeamMovePos;
				//--- WAVE-1 A3 (b): SetTeamMoveMode/MovePos only write wfbe_teammode/wfbe_teamgoto, which the HC
				//--- driver loop does NOT read - it reads ONLY wfbe_aicom_order. So for an HC team ALSO broadcast
				//--- a "defense" order at the town (mirror the HQ-strike order idiom below). Server-local teams
				//--- ignore the order var and use the SetTeamMove* writes above, so both paths stay covered.
				if (_free getVariable ["wfbe_aicom_hc", false]) then {
					_free setVariable ["wfbe_aicom_order", [(if (isNil {_free getVariable "wfbe_aicom_order"}) then {-1} else {(_free getVariable "wfbe_aicom_order") select 0}) + 1, "defense", getPos _town], true];
				};
				_free setVariable ["wfbe_aicom_relief", _town];
				_free setVariable ["wfbe_aicom_relief_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_HOLD", 240])]; //--- punchy-AICOM (Ray 2026-06-17): hold-window stamp; released back to offense when it expires.
				_relieved = _relieved + 1;
				_stratMode = "relief";
				_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] diverted to RELIEVE [%3] (under attack).", _sideText, _free, _town getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RELIEF|" + (_town getVariable ["name", "town"]));
			};
		} else {
			_relieved = _relieved + 1;
		};
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
		_wMode = toLower (_wTeam getVariable ["wfbe_teammode", "towns"]);
		if (_wMode == "defense" || {_wMode == "move"}) then {
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
							_wTeam setVariable ["wfbe_aicom_townorder", []];
							_wTeam setVariable ["wfbe_aicom_wedge_bc", nil];
							if (_wTeam getVariable ["wfbe_aicom_hc", false]) then {
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
			//--- Not in defense/move (back on towns/patrol/etc): clear any stale breadcrumb.
			if (!isNil {_wTeam getVariable "wfbe_aicom_wedge_bc"}) then {_wTeam setVariable ["wfbe_aicom_wedge_bc", nil]};
		};
	};
} forEach _teams;

//--- 3) HQ HUNT: strike when clearly winning; stand down when the edge is gone.
_enemyHQ = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
_wasStrike = _logik getVariable ["wfbe_aicom_strike_on", false];
_strikeOn = false;
if (!isNull _enemyHQ && {alive _enemyHQ}) then {
	if (_wasStrike) then {
		_strikeOn = (_myTowns > 8) && (_myTowns >= _enemyTowns * 1.2) && (_myStr >= _enStr);          //--- hysteresis: stay committed; gate: must still own >8 towns
	} else {
		_strikeOn = (_myTowns > 8) && (_myTowns >= _enemyTowns * 1.5) && (_myStr >= _enStr * 1.1);   //--- Steff's rule: never HQ-rush while behind on towns
	};
};
if (_strikeOn) then {
	_stratMode = "strike";
	_logik setVariable ["wfbe_aicom_strat_mode", _stratMode];
	if (!_wasStrike) then {
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] WAR STATE: winning (towns %2v%3, strength %4v%5) - HQ STRIKE launched.", _sideText, _myTowns, _enemyTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HQ_STRIKE|launched");
	};
	//--- Keep up to 3 strongest field teams on the strike (refill as strikers die).
	_strikeCount = 0;
	{ if (!isNull _x && {_x getVariable ["wfbe_aicom_strike", false]} && {({alive _x} count (units _x)) > 0}) then {_strikeCount = _strikeCount + 1} } forEach _teams;
	while {_strikeCount < 3} do {
		_best = grpNull; _bestN = 1; //--- need at least 2 men to be worth sending
		{
			_team = _x;
			if (!isNull _team && {!isPlayer (leader _team)} && {!(_team getVariable ["wfbe_aicom_strike", false])}) then {
				if (isNull (_team getVariable ["wfbe_aicom_relief", objNull]) && {(_logik getVariable ["wfbe_aicom_garrison", grpNull]) != _team}) then {
					_alive = {alive _x} count (units _team);
					if (_alive > _bestN) then {_bestN = _alive; _best = _team};
				};
			};
		} forEach _teams;
		if (isNull _best) exitWith {};
		_best setVariable ["wfbe_aicom_strike", true];
		[_best, "move"] Call SetTeamMoveMode;
		[_best, getPos _enemyHQ] Call SetTeamMovePos;
		if (_best getVariable ["wfbe_aicom_hc", false]) then {
			_best setVariable ["wfbe_aicom_order", [(if (isNil {_best getVariable "wfbe_aicom_order"}) then {-1} else {(_best getVariable "wfbe_aicom_order") select 0}) + 1, "towns-target", getPos _enemyHQ], true];
		};
		_strikeCount = _strikeCount + 1;
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] (%3 men) joins the HQ strike.", _sideText, _best, _bestN]] Call WFBE_CO_FNC_AICOMLog;
	};
} else {
	if (_wasStrike) then {
		["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] WAR STATE: edge lost (towns %2v%3, strength %4v%5) - strike recalled.", _sideText, _myTowns, _enemyTowns, _myStr, _enStr]] Call WFBE_CO_FNC_AICOMLog;
		{
			_team = _x;
			if (!isNull _team && {_team getVariable ["wfbe_aicom_strike", false]}) then {
				_team setVariable ["wfbe_aicom_strike", false];
				[_team, "towns"] Call SetTeamMoveMode;
				_team setVariable ["wfbe_aicom_townorder", []];
			};
		} forEach _teams;
	};
};
_logik setVariable ["wfbe_aicom_strike_on", _strikeOn];

//--- POSTURE + FRONT telemetry (claude-gaming 2026-06-15): the commander's strategic STANCE and
//--- the war-state numbers that drive it. All metrics (_myTowns/_enemyTowns/_myStr/_enStr/_strikeOn/
//--- _attacked/_anyFront/_targets) are already computed this tick, so these are pure string builds -
//--- ZERO extra scan. POSTURE derives a 3-state stance from the already-computed ratios so the WHY
//--- (pressing vs consolidating vs defending) is explicit; FRONT reconstructs the front line (held /
//--- contested counts + the primary target's name and whether it borders our territory). Both ride
//--- the existing AI_Commander_Strategy worker (per side / ~60s; gated in AI_Commander.sqf:133-134).
private ["_posture","_primT"];
_posture = if (_strikeOn) then {"HQ_STRIKE"} else {
	if (_myTowns < _enemyTowns || {_myStr < _enStr}) then {"DEFEND"} else {
		if (_myTowns >= (_enemyTowns * 1.2) && {_myStr >= _enStr}) then {"PRESS"} else {"HOLD"}
	}
};
diag_log ("AICOMSTAT|v1|POSTURE|" + _sideText + "|" + str (round (time / 60)) + "|" + _posture + "|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|myStr=" + str _myStr + "|enStr=" + str _enStr + "|strikeOn=" + str _strikeOn);
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
if ((_enemyTowns > 0) && {_myTowns >= (_enemyTowns * 2)} && {_posture != "PRESS"} && {!_strikeOn}) then {
	diag_log ("AICOMSTAT|v1|STALL|" + _sideText + "|" + str (round (time / 60)) + "|posture=" + _posture + "|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|myStr=" + str _myStr + "|enStr=" + str _enStr);
};
// END POSTURE + FRONT

//--- 4) ARTILLERY: soften the spearhead town or the enemy HQ - never near friendlies.
//--- V0.6.3: OFF by default (owner call) - opt back in via WFBE_C_AI_COMMANDER_ARTILLERY = 1.
if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0) && {(missionNamespace getVariable "WFBE_C_ARTILLERY") > 0}) then {
	_upASel = (_logik getVariable ["wfbe_upgrades", [0,0,0,0,0,0,0,0,0,0,0]]) select WFBE_UP_ARTYTIMEOUT;
	_cd = (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select (_upASel min ((count (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS")) - 1));
	if (time - (_logik getVariable ["wfbe_aicom_arty_last", -1e6]) > _cd) then {
		//--- Target: enemy HQ during a strike, else the top spearhead town.
		_artyTgt = [];
		if (_strikeOn && {!isNull _enemyHQ} && {alive _enemyHQ}) then {_artyTgt = getPos _enemyHQ};
		if (count _artyTgt == 0 && {count _targets > 0}) then {_artyTgt = getPos (_targets select 0)};
		if (count _artyTgt > 0) then {
			//--- Friendly-fire guard: no own troops near the impact zone.
			_ownNear = 0;
			{ if (side _x == _side && {alive _x}) then {_ownNear = _ownNear + 1} } forEach (_artyTgt nearEntities [["Man","Car","Tank","Air"], 400]);
			if (_ownNear == 0) then {
				//--- Our base guns (built by the Base worker, tagged by Construction_StationaryDefense).
				_pieces = (getPos ((_side) Call WFBE_CO_FNC_GetSideHQ)) nearEntities [["StaticWeapon","Tank","Car"], 250];
				_fired = false;
				{
					_p = _x;
					if (!_fired && {alive _p} && {(_p getVariable ["WFBE_CommanderArtillery", false])} && {(_p getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {!isNull (gunner _p)} && {alive (gunner _p)} && {someAmmo _p}) then {
						_idx = [typeOf _p, _side] Call IsArtillery;
						if (_idx >= 0) then {
							_maxR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _sideText]) select _idx) / (missionNamespace getVariable "WFBE_C_ARTILLERY");
							if (_p distance _artyTgt <= _maxR) then {
								[_p, _artyTgt, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;
								_logik setVariable ["wfbe_aicom_arty_last", time];
								_fired = true;
								["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] FIRE MISSION [%2] at %3 (cooldown %4s).", _sideText, typeOf _p, _artyTgt, _cd]] Call WFBE_CO_FNC_AICOMLog;
						diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FIRE_MISSION|" + (typeOf _p));
							};
						};
					};
				} forEach _pieces;
			};
		};
	};
};
