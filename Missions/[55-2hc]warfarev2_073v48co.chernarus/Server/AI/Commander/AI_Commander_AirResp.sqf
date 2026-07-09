/*
	AI_Commander_AirResp.sqf - AICOM v2 M6 AIR-RESPONSE closer (organic W/E air support). Server-side, per side.
	Param: _this = side. Runs AFTER the M5 DECAPITATE closer each strategy tick (AI_Commander.sqf:524), reading
	the already-fresh wfbe_aicom2_snap - no new scan cost. Gated by WFBE_C_AICOM2_AIRRESP_ENABLE (owner directive
	2026-07-08: ARMED LIVE, default 1 - NOT the shadow/default-0 convention the design spec proposed; this ships
	armed and changes live AI behaviour once merged+deployed. See PR body: needs a T3 soak before the owner ships it.

	ORGANIC LANE SENSING (design spec docs/design/v2/AICOM-AIR-GROUND-RESPONSE-SPEC-2026-07-07.md SS2.1/2.2, mirrors
	DECAP's proximity+dice+latch template - AI_Commander_Decapitate.sqf:14-24): AIRRESP never scans the whole map
	for players and never invents a new detector. A lane is a candidate ONLY if it is already surfaced by machinery
	that exists independently of this closer - the Allocator's WFBE_SNAP_TGTTOWNOBJS (the ground fist's current 1-2
	target towns) or an owned WFBE_SNAP_OWNTOWNOBJS town already flagged wfbe_active/wfbe_active_air by the town-
	activation FSM (server_town_ai.sqf's own local nearEntities sweep). Among those candidates, AIRRESP runs a
	BOUNDED per-town nearEntities scan (not a global player-list scan) for enemy-side players; the candidate with
	the most in-range enemy players becomes the sense target. A periodic dice roll (AIRRESP_SENSE_INTERVAL strategy
	ticks, chance AIRRESP_SENSE_CHANCE), latched as 'sensed' until contact is lost, must succeed before AIRRESP will
	dispatch - same non-omniscient shape as DECAP: it reacts only to a lane the rest of AICOM has already, locally,
	noticed (spec SS2.2).

	ARMED ACTION: dispatch up to AIRRESP_MAX_AIR side-wide 'response flights' - a single createVehicle attack
	airframe (same allowlist as W13 Gunship Strike, AI_Commander_Wildcard.sqf:1000 - owner Q1 default: reuse, no
	separate curated pool for this first cut) crewed and AIPatrol'd over the sensed lane town, watchdog-refreshed
	while the lane stays hot, self-despawning at AIRRESP_LOITER_TIME or as soon as the lane goes cold. Deliberately
	does NOT found a full AICOM commander team (no wfbe_teammode/Common_RunCommanderTeam/HC-delegation wiring -
	owner Q2 in the spec is open); this first cut reuses W13/W14's proven direct-dispatch idiom instead of extending
	the team registry, to minimise blast radius on a HIGH-RISK core-AICOM lane. Silent (no LocalizeMessage, owner Q3
	default: match DECAP's silent-closer convention for this first cut).

	NEVER touches wfbe_aicom_decap / wfbe_aicom_targets / any ground team's wfbe_aicom_alloc_target - the
	Allocator's fist and DECAP's HQ press stay the sole ground authority (spec SS2.3). AIRRESP tracks its own
	state on separate side-logic vars and a separate team-var pair is never used (no ground team is touched at
	all). DECAP/AIRRESP same-town overlap policy (spec SS2.3/Q7, resolved by construction): AIRRESP only ever
	tracks ONE side-wide sensed lane per tick (mirrors DECAP's single-enHQ shape) and only dispatches a NEW flight
	when no living flight already covers that lane - so if the sensed lane happens to be the same town DECAP has
	COMMITTED against, AIRRESP naturally caps itself to a single flight there instead of double-dispatching.

	State on the side logic: wfbe_aicom2_airresp_sensetick (roll cadence), wfbe_aicom2_airresp_sensed (latch),
	wfbe_aicom2_airresp_lane (current sensed lane town), wfbe_aicom2_airresp_flights (array of [grp, heli,
	laneTown, t0] for each live response flight; server-local, no broadcast needed - the watchdog thread that reads
	it runs server-side same as this script). Telemetry AICOM2|v1|AIRRESP.
	A2-OA-safe: private string-array only; no inline private _x=; no GROUP 2-arg getVariable; no NSSETVAR3; no A3
	commands; >0 numeric-flag guards; if/else booleans (no ==/!= on Bool); outer _x captured into a named local
	before every inner forEach/count block.
*/

private ["_side","_logik","_snap","_sideID","_sideText","_enemySide","_enemyID","_myTowns",
	"_enable","_senseRadius","_senseInterval","_senseChance","_maxAir","_loiterTime","_minTowns",
	"_senseTick","_sensed","_laneTown","_flightsIn","_flights","_f","_fg","_fh",
	"_tgtTowns","_ownTowns","_cands","_x2","_lanePos","_nearCount","_bestTown","_bestCount","_inRange",
	"_rollNow","_covered","_upgrades","_airOK","_townsOK","_canDispatch","_dispatched",
	"_airList","_attackClasses","_pilotClass","_ang","_spawnPos","_class","_heli","_grp","_pilot",
	"_elMin"];

_side    = _this;
_logik   = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_snap = _logik getVariable ["wfbe_aicom2_snap", []];
if (count _snap < 26) exitWith {};

_sideID    = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText  = str _side;
_enemySide = if (_side == west) then {east} else {west};
_enemyID   = (_enemySide) Call WFBE_CO_FNC_GetSideID;
_myTowns   = _snap select WFBE_SNAP_MYTOWNS;

_senseRadius   = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS", 2500];
_senseInterval = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_SENSE_INTERVAL", 3];
_senseChance   = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_SENSE_CHANCE", 0.5];
_maxAir        = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_MAX_AIR", 2];
_loiterTime    = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_LOITER_TIME", 240];
_minTowns      = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3]; //--- reuse W6/W13's established no-early-air gate (default 3, Init_CommonConstants.sqf:370; AI_Commander_Wildcard.sqf:334)

_senseTick = _logik getVariable "wfbe_aicom2_airresp_sensetick";
_senseTick = if (isNil "_senseTick") then {0} else {_senseTick};
_sensed    = _logik getVariable "wfbe_aicom2_airresp_sensed";
_sensed    = if (isNil "_sensed") then {false} else {_sensed};
_laneTown  = _logik getVariable "wfbe_aicom2_airresp_lane";
_laneTown  = if (isNil "_laneTown") then {objNull} else {_laneTown};

//--- Prune the tracked-flights array: drop any entry whose group/heli died or despawned since last tick
//--- (the watchdog thread self-cleans on lane-cold/loiter-expiry, this just keeps our own count accurate).
_flightsIn = _logik getVariable ["wfbe_aicom2_airresp_flights", []];
_flights = [];
{
	_f = _x;
	if (typeName _f == "ARRAY" && {count _f >= 3}) then {
		_fg = _f select 0; _fh = _f select 1;
		if (!isNull _fg && {({alive _x} count (units _fg)) > 0} && {!isNull _fh} && {alive _fh}) then {
			_flights = _flights + [_f];
		};
	};
} forEach _flightsIn;

//--- ORGANIC LANE CANDIDATES (spec SS2.2): the Allocator's current fist target towns, plus any OWNED town the
//--- town-activation FSM has already, independently, flagged under threat. No new detection pass over the map.
_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;
_ownTowns = _snap select WFBE_SNAP_OWNTOWNOBJS;
_cands = [];
{ if (!(_x in _cands)) then {_cands = _cands + [_x]} } forEach _tgtTowns;
{
	_x2 = _x;
	if (((_x2 getVariable ["wfbe_active", false]) || {_x2 getVariable ["wfbe_active_air", false]}) && {!(_x2 in _cands)}) then {
		_cands = _cands + [_x2];
	};
} forEach _ownTowns;

//--- BOUNDED per-town nearEntities scan (not a global player scan) for enemy-side players; the candidate with
//--- the most in-range enemy players becomes this tick's sense target.
_bestTown = objNull; _bestCount = 0;
{
	_x2 = _x;
	_lanePos = getPos _x2;
	_nearCount = {isPlayer _x && {alive _x} && {(side _x) == _enemySide}} count (_lanePos nearEntities [["Man"], _senseRadius]);
	if (_nearCount > _bestCount) then {_bestCount = _nearCount; _bestTown = _x2};
} forEach _cands;
_inRange = _bestCount > 0;

//--- DICE ROLL, LATCHED (mirrors DECAP AI_Commander_Decapitate.sqf:105-118): no roll, no sense - this is what
//--- keeps the mechanism non-omniscient, it does not fire the instant a player appears near a candidate lane.
_rollNow = 0;
if (!_inRange) then {
	_sensed = false;   //--- contact lost -> sensing decays; a fresh roll is required next approach
	_senseTick = 0;
	_laneTown = objNull;
} else {
	if (_bestTown != _laneTown) then {
		_sensed = false;   //--- sensed lane switched while still in range -> latch does not carry to the new lane (mirrors DECAP's contact-lost reset, AI_Commander_Decapitate.sqf:106-108)
		_senseTick = 0;
	};
	_laneTown = _bestTown;   //--- track the currently-best lane even before the roll latches (telemetry-visible)
	if (!_sensed) then {
		_senseTick = _senseTick + 1;
		if (_senseTick >= _senseInterval) then {
			_senseTick = 0;
			_rollNow = 1;
			if ((random 1) < _senseChance) then {_sensed = true};
		};
	};
};

//--- AIRFRAME AVAILABLE (spec condition 3): same air-research + established-towns gate W6/W13 already use.
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_airOK    = !isNil "_upgrades" && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0};
_townsOK  = _myTowns >= _minTowns;

//--- BUDGET + one-flight-per-lane de-dup (spec condition 4 + SS2.3/Q7 overlap policy, resolved by construction:
//--- see file header). A lane already covered by a living flight never gets a second dispatch.
_covered = false;
{ if ((_x select 2) == _laneTown) then {_covered = true} } forEach _flights;

_canDispatch = _sensed && {_inRange} && {_airOK} && {_townsOK} && {!_covered} && {(count _flights) < _maxAir} && {!isNull _laneTown};

_dispatched = 0;
if ((missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_ENABLE", 1]) > 0 && {_canDispatch}) then {
	_airList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
	_attackClasses = [];
	{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Mi24_D","Mi24_V","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su34"]) then {_attackClasses = _attackClasses + [_x]} } forEach _airList;
	_pilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
	if (count _attackClasses > 0 && {_pilotClass != ""}) then {
		_lanePos = getPos _laneTown;
		_ang = random 360;
		_spawnPos = [(_lanePos select 0) + 2500 * sin _ang, (_lanePos select 1) + 2500 * cos _ang, 300];
		_class = _attackClasses select floor(random count _attackClasses);
		_heli = [_class, _spawnPos, _side, random 360, true, true] Call WFBE_CO_FNC_CreateVehicle;
		if (!isNull _heli) then {
			_grp = [_side, "aicom-airresp"] Call WFBE_CO_FNC_CreateGroup;
			if (!isNull _grp) then {
				_pilot = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _pilot) then {
					_pilot moveInDriver _heli;
					_heli flyInHeight 200;
					//--- N5 fix (MORE-FIXES-AND-IDEAS): AIPatrol (AI_Patrol.sqf:8-9) unconditionally resets
					//--- the group to AWARE/YELLOW as its first act, so setting COMBAT/RED BEFORE calling it
					//--- was immediately clobbered - the dispatched response aircraft silently downgraded to
					//--- passive patrol. Reorder: lay the patrol first, THEN set the aggressive posture -
					//--- same pattern already proven correct in this file's siblings (W17/W18, AI_Commander_Wildcard.sqf).
					[_grp, _lanePos, 250] Call AIPatrol;
					_grp setBehaviour "COMBAT"; _grp setCombatMode "RED";
					_flights = _flights + [[_grp, _heli, _laneTown, time]];
					_dispatched = 1;
					//--- WATCHDOG (owner Q7 default + spec SS2.1 'flexible, re-orderable' behaviour): polls the side's
					//--- CURRENT sensed lane every 15s; keeps patrolling while this flight's lane stays the live sense
					//--- target, self-despawns the moment the lane goes cold or AIRRESP_LOITER_TIME elapses - whichever
					//--- first. Runs server-side (spawn stays on the calling machine, same as every other AICOM worker).
					[_grp, _heli, _laneTown, _side] spawn {
						private ["_g","_h","_lane","_sd","_elapsed","_loiter","_poll","_hot","_logikW","_curLane"];
						_g = _this select 0; _h = _this select 1; _lane = _this select 2; _sd = _this select 3;
						_loiter = missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_LOITER_TIME", 240];
						_poll = 15; _elapsed = 0; _hot = true;
						_logikW = (_sd) Call WFBE_CO_FNC_GetSideLogic;
						while {_hot && {_elapsed < _loiter} && {!isNull _g} && {({alive _x} count (units _g)) > 0} && {!isNull _h} && {alive _h}} do {
							sleep _poll;
							_elapsed = _elapsed + _poll;
							_curLane = objNull;
							if (!isNil "_logikW") then {_curLane = _logikW getVariable ["wfbe_aicom2_airresp_lane", objNull]};
							if (isNull _curLane || {_curLane != _lane}) then {_hot = false};
						};
						{deleteVehicle _x} forEach (crew _h);
						if (!isNull _h) then {deleteVehicle _h};
						if (!isNull _g) then {deleteGroup _g};
					};
				} else {
					deleteVehicle _heli; deleteGroup _grp;
				};
			} else {
				deleteVehicle _heli;
			};
		};
	};
};

_logik setVariable ["wfbe_aicom2_airresp_sensetick", _senseTick];
_logik setVariable ["wfbe_aicom2_airresp_sensed", _sensed];
_logik setVariable ["wfbe_aicom2_airresp_lane", _laneTown];
_logik setVariable ["wfbe_aicom2_airresp_flights", _flights];

_elMin = round (time / 60);
diag_log ("AICOM2|v1|AIRRESP|" + _sideText + "|" + str _elMin
	+ "|inRange=" + str _bestCount
	+ "|roll=" + str _rollNow
	+ "|sensed=" + (if (_sensed) then {"1"} else {"0"})
	+ "|lane=" + (if (isNull _laneTown) then {"none"} else {str (_laneTown getVariable ["name","?"])})
	+ "|flights=" + str (count _flights)
	+ "|dispatched=" + str _dispatched
	+ "|myTowns=" + str _myTowns
	+ "|airOK=" + (if (_airOK) then {"1"} else {"0"})
	+ "|flag=" + str (missionNamespace getVariable ["WFBE_C_AICOM2_AIRRESP_ENABLE", 1]));
