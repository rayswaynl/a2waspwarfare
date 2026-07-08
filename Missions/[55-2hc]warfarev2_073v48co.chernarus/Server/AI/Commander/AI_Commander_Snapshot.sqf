/*
	AI Commander v2 (rebuild) - WORLD MODEL SNAPSHOT. Milestone M0.
	Server-side, full-command mode. Parameter: _this = side.

	Builds ONE immutable, server-authoritative snapshot of the war state per side per
	strategy tick (~60s) and caches it on the side logic under "wfbe_aicom2_snap". Every
	v2 brain layer (stance machine, objective allocation, closer) reads THIS snapshot
	instead of recomputing town/strength/HQ facts piecemeal - killing the duplicate scans
	and split-brain reads of the legacy Strategy/AssignTowns pair.

	LOCALITY CONTRACT (the #1 correctness rule of the rebuild):
	  - This worker only captures SERVER-AUTHORITATIVE facts: town ownership, side maneuver
	    + effective strength, funds/supply, the HQ objects+positions, human-player counts,
	    and a COARSE per-team digest (alive count, leader pos, role flags, owns-a-drivable-
	    hull). These are reliable when read on the server.
	  - It does NOT trust frame-accurate per-team EXECUTION facts (wedged? at-objective?
	    sieging?) for HC-owned teams - those lag/return stale through remote group proxies.
	    Each team digest carries a WFBE_SNT_REPORT slot that the HC driver fills from its
	    OWN locality via the upward team-status channel (added in M1). Until then the slot
	    is [] and consumers fall back to the coarse server view.

	M0 is behaviour-neutral: nothing reads the snapshot yet (legacy Strategy/AssignTowns
	still drive the war). This worker only POPULATES the cache and emits AICOM2 telemetry.

	A2-OA-safe: reuses the legacy _myStr remnant-exclusion idiom (Strategy.sqf:45-63),
	WFBE_CO_FNC_GroupGetBool for group bools, plain-get+isNil for group vars, no A3 commands.
*/

private ["_side","_sideID","_sideText","_logik","_teams","_enemySide","_enemyID","_enemyLogik",
	"_myTowns","_enemyTowns","_neutTowns","_totTowns","_ownTownObjs","_tgtTownObjs",
	"_myHQ","_enemyHQ","_myStr","_enStr","_loneAlive","_loneFar","_townStr","_myEff","_enEff",
	"_funds","_supply","_players","_myPlayers","_hcUnits","_teamDigests","_team","_tAlive",
	"_isRemnant","_rf","_ldr","_ldrPos","_isHC","_isFound","_isGar","_mode","_strikeFlag",
	"_reliefTown","_hasGndVeh","_mountedNow","_hasHeavy","_veh","_garGrp","_snap","_elMin"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
if (isNil "towns") exitWith {["WARNING", "AI_Commander_Snapshot: towns global is nil or empty; snapshot skipped."] Call WFBE_CO_FNC_AICOMLog};
if ((count towns) < 1) exitWith {["WARNING", "AI_Commander_Snapshot: towns global is nil or empty; snapshot skipped."] Call WFBE_CO_FNC_AICOMLog};

_enemySide = if (_side == west) then {east} else {west};
if (!(_enemySide in WFBE_PRESENTSIDES)) exitWith {};
_enemyID = (_enemySide) Call WFBE_CO_FNC_GetSideID;
_enemyLogik = (_enemySide) Call WFBE_CO_FNC_GetSideLogic;

//--- TOWN CENSUS: my / enemy / neutral counts + the two candidate lists the allocator needs.
_myTowns = 0; _enemyTowns = 0; _neutTowns = 0; _totTowns = 0;
_ownTownObjs = []; _tgtTownObjs = [];
//--- AI-BEHAVIOR-LOOP-DESIGN.md sec6.1: TEST-ONLY scoping filter, first N towns (stable array-index order) feeding this census loop so AI_Commander_Allocate.sqf's _tgtTowns (reads the snapshot, not towns directly) sees the identical capped pool as AI_Commander_AssignTowns.sqf's _uncaptured truncation. -1 = off (byte-identical; full towns array in play as today).
private ["_townsCapped"]; _townsCapped = towns;
if ((missionNamespace getVariable ["WFBE_C_TEST_TOWN_CAP", -1]) >= 0) then {
	private ["_ttcN","_ttcOut","_ttcI"];
	_ttcN = missionNamespace getVariable ["WFBE_C_TEST_TOWN_CAP", -1];
	if (_ttcN < count towns) then {
		_ttcOut = [];
		for "_ttcI" from 0 to (_ttcN - 1) do {_ttcOut set [_ttcI, towns select _ttcI]};
		_townsCapped = _ttcOut;
	};
};
{
	_totTowns = _totTowns + 1;
	if ((_x getVariable "sideID") == _sideID) then {
		_myTowns = _myTowns + 1;
		_ownTownObjs set [count _ownTownObjs, _x];
	} else {
		//--- capturable (enemy- or neutral-held) - the allocator's CAPTURE candidate set.
		_tgtTownObjs set [count _tgtTownObjs, _x];
		if ((_x getVariable "sideID") == _enemyID) then {_enemyTowns = _enemyTowns + 1} else {_neutTowns = _neutTowns + 1};
	};
} forEach _townsCapped;
if (_totTowns == 0 && {!isNil "towns"} && {(count towns) > 0}) then {
	["WARNING", Format ["AI_Commander_Snapshot: census totTowns=0 but towns array has %1 entries - town sideID vars may not be initialised yet.", count towns]] Call WFBE_CO_FNC_AICOMLog;
};

//--- HQ OBJECTS (server-authoritative).
_myHQ    = (_side)      Call WFBE_CO_FNC_GetSideHQ;
_enemyHQ = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;

//--- MANEUVER STRENGTH: alive bodies in this side's founded/HC teams, EXCLUDING stranded lone
//--- remnants (alive < N AND far from HQ) and in-refit teams, so a few far-flung survivors do not
//--- deflate strength (legacy idiom, Strategy.sqf:45-63 - kept identical so M3 swaps cleanly).
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

//--- EFFECTIVE STRENGTH = maneuver + held-town credit. This (NOT raw _myStr) is what the v2
//--- stance machine and closer decide on, so a territory-winning side never flips itself into
//--- DEFEND when its leader garrisons towns (the legacy STALL bug).
_townStr = missionNamespace getVariable ["WFBE_C_AICOM_TOWN_STRENGTH", 2];
_myEff = _myStr + (_myTowns * _townStr);
_enEff = _enStr + (_enemyTowns * _townStr);

_funds  = (_side) Call GetAICommanderFunds;
_supply = if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {0};

//--- HUMAN-PLAYER COUNT (drives player-scaled closer pacing). EXCLUDE headless-client bodies
//--- (they report isPlayer=true but are not real humans) by filtering out units owned by any
//--- registered HC group, so an AI-vs-AI soak correctly reads players=0.
_hcUnits = [];
{ if (!isNull _x) then { { _hcUnits set [count _hcUnits, _x] } forEach (units _x) } } forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
_players = 0; _myPlayers = 0;
{
	if (isPlayer _x && {!(_x in _hcUnits)}) then {
		_players = _players + 1;
		if ((side _x) == _side) then {_myPlayers = _myPlayers + 1};
	};
} forEach playableUnits;

//--- PER-TEAM DIGEST: coarse, server-reliable facts the allocator needs. Execution facts that
//--- need frame accuracy are left to the HC driver's upward report (WFBE_SNT_REPORT, M1).
_garGrp = _logik getVariable ["wfbe_aicom_garrison", grpNull];
_teamDigests = [];
{
	_team = _x;
	if (!isNull _team) then {
		_isFound = ([_team, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool);
		_isHC    = ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool);
		//--- only commander combat teams (founded or HC) enter the digest; skip stray player groups.
		if (_isFound || _isHC) then {
			_tAlive = {alive _x} count (units _team);
			_ldr = leader _team;
			_ldrPos = if (!isNull _ldr) then {getPos _ldr} else {[0,0,0]};
			_isGar = (_team == _garGrp);
			_mode = _team getVariable "wfbe_teammode";
			if (isNil "_mode") then {_mode = "towns"};
			_mode = toLower _mode;
			_strikeFlag = _team getVariable "wfbe_aicom_strike";
			if (isNil "_strikeFlag") then {_strikeFlag = false};
			_reliefTown = _team getVariable "wfbe_aicom_relief";
			if (isNil "_reliefTown") then {_reliefTown = objNull};
			//--- transport state: owns a drivable ground hull (reach-IF-remounted), anyone mounted now,
			//--- and has a heavy punch vehicle. Classname-literal isKindOf only (A2-OA-safe).
			_hasGndVeh = false; _mountedNow = false; _hasHeavy = false;
			{
				if (alive _x) then {
					_veh = vehicle _x;
					if (_veh != _x) then {
						_mountedNow = true;
						if ((canMove _veh) && {!(_veh isKindOf "Air")}) then {_hasGndVeh = true};
						if ((_veh isKindOf "Tank") || {_veh isKindOf "APC"} || {_veh isKindOf "Air"}) then {_hasHeavy = true};
					};
				};
			} forEach (units _team);
			_teamDigests set [count _teamDigests, [_team, _tAlive, _ldrPos, _isHC, _isFound, _isGar, _mode, _strikeFlag, _reliefTown, _hasGndVeh, _mountedNow, _hasHeavy, []]];
		};
	};
} forEach _teams;

//--- ASSEMBLE + CACHE (one atomic setVariable; indices are the WFBE_SNAP_* constants).
_snap = [];
_snap set [WFBE_SNAP_TIME,      time];
_snap set [WFBE_SNAP_SIDE,      _side];
_snap set [WFBE_SNAP_SIDEID,    _sideID];
_snap set [WFBE_SNAP_ENSIDE,    _enemySide];
_snap set [WFBE_SNAP_ENID,      _enemyID];
_snap set [WFBE_SNAP_MYTOWNS,   _myTowns];
_snap set [WFBE_SNAP_ENTOWNS,   _enemyTowns];
_snap set [WFBE_SNAP_NEUTOWNS,  _neutTowns];
_snap set [WFBE_SNAP_TOTTOWNS,  _totTowns];
_snap set [WFBE_SNAP_MYSTR,     _myStr];
_snap set [WFBE_SNAP_ENSTR,     _enStr];
_snap set [WFBE_SNAP_MYEFF,     _myEff];
_snap set [WFBE_SNAP_ENEFF,     _enEff];
_snap set [WFBE_SNAP_MYHQ,      _myHQ];
_snap set [WFBE_SNAP_MYHQPOS,   (if (!isNull _myHQ) then {getPos _myHQ} else {[0,0,0]})];
_snap set [WFBE_SNAP_MYHQALIVE, (!isNull _myHQ && {alive _myHQ})];
_snap set [WFBE_SNAP_ENHQ,      _enemyHQ];
_snap set [WFBE_SNAP_ENHQPOS,   (if (!isNull _enemyHQ) then {getPos _enemyHQ} else {[0,0,0]})];
_snap set [WFBE_SNAP_ENHQALIVE, (!isNull _enemyHQ && {alive _enemyHQ})];
_snap set [WFBE_SNAP_FUNDS,     _funds];
_snap set [WFBE_SNAP_SUPPLY,    _supply];
_snap set [WFBE_SNAP_PLAYERS,   _players];
_snap set [WFBE_SNAP_MYPLAYERS, _myPlayers];
_snap set [WFBE_SNAP_TEAMS,     _teamDigests];
_snap set [WFBE_SNAP_OWNTOWNOBJS, _ownTownObjs];
_snap set [WFBE_SNAP_TGTTOWNOBJS, _tgtTownObjs];
_logik setVariable ["wfbe_aicom2_snap", _snap];

//--- AICOM2 TELEMETRY: one greppable per-side digest line per strategy tick. Mirrors the
//--- analyze.py parsing pattern so soak analysis of the rebuild is first-class from day one.
_elMin = round (time / 60);
diag_log ("AICOM2|v1|SNAP|" + _sideText + "|" + str _elMin
	+ "|myTowns=" + str _myTowns + "|enTowns=" + str _enemyTowns + "|neut=" + str _neutTowns + "|total=" + str _totTowns
	+ "|myStr=" + str _myStr + "|enStr=" + str _enStr + "|myEff=" + str _myEff + "|enEff=" + str _enEff
	+ "|funds=" + str _funds + "|supply=" + str _supply
	+ "|players=" + str _players + "|myPlayers=" + str _myPlayers
	+ "|teams=" + str (count _teamDigests)
	+ "|enHQ=" + (if (!isNull _enemyHQ && {alive _enemyHQ}) then {"alive"} else {"dead"}));
