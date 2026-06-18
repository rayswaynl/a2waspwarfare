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

private ["_side","_sideID","_sideText","_logik","_teams","_enemySide","_enemyID","_enemyLogik","_myTowns","_enemyTowns","_myStr","_enStr","_team","_alive","_strikeOn","_wasStrike","_enemyHQ","_strikers","_strong","_best","_bestN","_i","_targets","_cands","_t","_score","_bestScore","_bestTown","_dNear","_d","_perTeam","_want","_attacked","_relieved","_town","_free","_freeD","_cd","_artyTgt","_pieces","_p","_idx","_maxR","_fired","_upASel","_relTown","_relAge","_quiet","_strikeCount","_ownNear","_frontRad","_distDiv","_hqDiv","_farPen","_enemyHQForRank","_dHQ","_onFront","_anyFront"];

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
			_score = (_t getVariable ["supplyValue", 0])
			       - (_dNear / _distDiv)
			       + (_t getVariable ["wfbe_aicom_town_weight", 0]);
			if (_hqDiv > 0) then {_score = _score - (_dHQ / _hqDiv)};
			//--- Off-front towns take a flat penalty so a fat deep city can't outrank a
			//--- near contestable one. Towns on the front are unpenalised and win.
			if (_dNear > _frontRad) then {_score = _score - _farPen};
			if (_score > _bestScore) then {_bestScore = _score; _bestTown = _t};
		};
	} forEach _cands;
	if (!isNull _bestTown) then {_targets = _targets + [_bestTown]};
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
						if (isNull (_team getVariable ["wfbe_aicom_relief", objNull]) && {!(_team getVariable ["wfbe_aicom_strike", false])} && {!(_team getVariable ["wfbe_aicom_hc", false])}) then {
							_d = (leader _team) distance _town;
							if (_d < _freeD) then {_freeD = _d; _free = _team};
						};
					};
				};
			} forEach _teams;
			if (!isNull _free) then {
				[_free, "defense"] Call SetTeamMoveMode;
				[_free, getPos _town] Call SetTeamMovePos;
				_free setVariable ["wfbe_aicom_relief", _town];
				_free setVariable ["wfbe_aicom_relief_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_HOLD", 240])]; //--- punchy-AICOM (Ray 2026-06-17): hold-window stamp; released back to offense when it expires.
				_relieved = _relieved + 1;
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] diverted to RELIEVE [%3] (under attack).", _sideText, _free, _town getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RELIEF|" + (_town getVariable ["name", "town"]));
			};
		} else {
			_relieved = _relieved + 1;
		};
	};
} forEach _attacked;

//--- 3) HQ HUNT: strike when clearly winning; stand down when the edge is gone.
_enemyHQ = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
_wasStrike = _logik getVariable ["wfbe_aicom_strike_on", false];
_strikeOn = false;
if (!isNull _enemyHQ && {alive _enemyHQ}) then {
	if (_wasStrike) then {
		_strikeOn = (_myTowns >= _enemyTowns * 1.2) && (_myStr >= _enStr);          //--- hysteresis: stay committed
	} else {
		_strikeOn = (_myTowns >= 3) && (_myTowns >= _enemyTowns * 1.5) && (_myStr >= _enStr * 1.1);
	};
};
if (_strikeOn) then {
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
