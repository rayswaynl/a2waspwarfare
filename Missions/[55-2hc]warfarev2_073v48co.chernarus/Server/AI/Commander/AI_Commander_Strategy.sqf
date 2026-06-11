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

private ["_side","_sideID","_sideText","_logik","_teams","_enemySide","_enemyID","_enemyLogik","_myTowns","_enemyTowns","_myStr","_enStr","_team","_alive","_strikeOn","_wasStrike","_enemyHQ","_strikers","_strong","_best","_bestN","_i","_targets","_cands","_t","_score","_bestScore","_bestTown","_dNear","_d","_perTeam","_want","_attacked","_relieved","_town","_free","_freeD","_cd","_artyTgt","_pieces","_p","_idx","_maxR","_fired","_upASel","_relTown","_relAge","_quiet","_strikeCount","_ownNear"];

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

//--- 1) SPEARHEADS: score every town we do not own; value high, far-from-front low.
_cands = [];
{ if ((_x getVariable "sideID") != _sideID) then {_cands = _cands + [_x]} } forEach towns;
_want = 1 max (ceil ((count _teams) / (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN", 3])));
_want = _want min 5 min (count _cands);
_targets = [];
for "_i" from 1 to _want do {
	_bestScore = -1e9; _bestTown = objNull;
	{
		_t = _x;
		if (!(_t in _targets)) then {
			//--- Frontline distance = to our nearest OWN town (fallback: our HQ).
			_dNear = 1e9;
			{ if ((_x getVariable "sideID") == _sideID) then {_d = _t distance _x; if (_d < _dNear) then {_dNear = _d}} } forEach towns;
			if (_dNear > 1e8) then {_dNear = _t distance ((_side) Call WFBE_CO_FNC_GetSideHQ)};
			//--- V0.6 task 49a: town weight hook (nil-safe, zero on this mission;
			//--- experital's airfield init can set wfbe_aicom_town_weight on a town object).
			_score = (_t getVariable ["supplyValue", 0]) - (_dNear / 150) + (_t getVariable ["wfbe_aicom_town_weight", 0]);
			if (_score > _bestScore) then {_bestScore = _score; _bestTown = _t};
		};
	} forEach _cands;
	if (!isNull _bestTown) then {_targets = _targets + [_bestTown]};
};
_logik setVariable ["wfbe_aicom_targets", _targets];

//--- 2) REACTIVE DEFENSE: relieve own towns under attack; release quiet reliefs.
{
	_team = _x;
	if (!isNull _team) then {
		_relTown = _team getVariable ["wfbe_aicom_relief", objNull];
		if (!isNull _relTown) then {
			_quiet = !(_relTown getVariable ["wfbe_active", false]);
			if (_quiet || {(_relTown getVariable "sideID") != _sideID}) then {
				//--- Town safe (or lost - it becomes an attack target again): release.
				_team setVariable ["wfbe_aicom_relief", objNull];
				[_team, "towns"] Call SetTeamMoveMode;
				_team setVariable ["wfbe_aicom_townorder", []];
				["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] released from relief duty at [%3].", _sideText, _team, _relTown getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
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
			_best setVariable ["wfbe_aicom_order", [((_best getVariable ["wfbe_aicom_order", [-1]]) select 0) + 1, "towns-target", getPos _enemyHQ], true];
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

//--- 4) ARTILLERY: soften the spearhead town or the enemy HQ - never near friendlies.
if ((missionNamespace getVariable "WFBE_C_ARTILLERY") > 0) then {
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
