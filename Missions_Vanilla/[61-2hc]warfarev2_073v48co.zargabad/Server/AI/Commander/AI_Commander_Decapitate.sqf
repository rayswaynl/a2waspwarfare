/*
	AI_Commander_Decapitate.sqf - AICOM v2 M5 DECAPITATE CLOSER. Server-side, per side.
	Param: _this = side. Runs AFTER the M0 snapshot + the M1 Allocator each strategy tick
	(it NEVER writes wfbe_aicom_targets - the Allocator's town-first fist stays authoritative), gated
	by WFBE_C_AICOM2_DECAP_ENABLE (0 = inert -> reads snapshot + emits telemetry ONLY, no writes,
	byte-identical behaviour to HEAD; instant rollback).

	THE MISSING KILL-MOVE. Live evidence 2026-07-04 (ZG, players): the dominant side (EAST, 7 towns
	vs 2, strike posture, armour) ran 116 orders -> 50 arrivals -> 1 begin_capture over 90 min and
	produced ZERO base overruns - froze 2-7-2 because the strike verb RALLIES-AND-HOLDS near the HQ
	instead of pressing onto it. The Allocator concentrates the fist on the nearest capturable TOWN;
	nothing ever commits the army to the enemy HQ itself. This closer is that commit.

	ORGANIC BASE SENSING (owner Q1, 2026-07-06): the commander must not ACT on global HQ knowledge.
	ARM requires all three, sustained across WFBE_C_AICOM2_DECAP_ARM_TICKS net ticks (the streak
	decays by 1 on failing ticks rather than resetting - brief sensor blips do not zero progress): (a) PROXIMITY - at
	least one eligible offensive team leader within DECAP_SENSE_RADIUS (per-map) of the enemy HQ;
	(b) a periodic DICE ROLL - every DECAP_SENSE_INTERVAL strategy ticks, chance DECAP_SENSE_CHANCE,
	latched as 'sensed' until contact is lost; (c) DOMINANCE - myEff >= enEff*DOM_RATIO (a weak side
	that stumbles onto the HQ does not commit). MAX_ENTOWNS is demoted to a secondary safety. Then ->
	COMMITTED. Once COMMITTED it STOPS re-evaluating entry; the only exits are enemy-HQ-dead (win) or
	a deliberately-hard ABORT (myEff < enEff*ABORT_RATIO sustained, and only after MIN_COMMIT seconds).
	Wide hysteresis a momentary garrison dip cannot cross - the leader own garrisoning briefly lowers
	_myStr and the legacy strike auto-recalled on exactly that; this does not.

	COMMIT ACTION (scoped): stamp wfbe_aicom_decap = enHQpos + wfbe_aicom_alloc_target = the enemy town
	nearest the HQ ONLY on teams whose leader is within DECAP_COMMIT_RADIUS of the HQ - nearby teams
	press while the REST OF THE ARMY KEEPS CAPTURING TOWNS (wfbe_aicom_targets is never overwritten;
	distant teams keep their town orders untouched). The driver-press hook consuming the stamp is the
	NEXT increment. Feeds the existing overrun razer -> server_victory_threeway.sqf win = real overrun.

	State on the side logic: wfbe_aicom2_decap_streak, wfbe_aicom2_decap_sensetick (roll cadence),
	wfbe_aicom2_decap_sensed (latch), wfbe_aicom2_decap_committed, wfbe_aicom2_decap_t0. Telemetry AICOM2|v1|DECAP.
	A2-OA-safe: snapshot for tick-stable facts; plain-get + isNil heals (no GROUP 2-arg getVariable, no
	NSSETVAR3, no A3 commands); >0 numeric-flag guards; if/else booleans (no ==/!= on Bool).
*/

private ["_side","_logik","_snap","_myEff","_enEff","_enTowns","_myTowns","_enHQ","_enHQPos","_enHQAlive",
	"_domRatio","_abortRatio","_maxEnTowns","_armTicks","_minCommit","_dominant","_streak","_committed",
	"_t0","_state","_tgtTowns","_teams","_nearTown","_bestD","_d","_t","_stamped","_sideText","_elMin",
	"_senseRadius","_senseInterval","_senseChance","_commitRadius","_senseTick","_sensed","_inRange","_rollNow","_ldr"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_snap = _logik getVariable ["wfbe_aicom2_snap", []];
if (count _snap < 26) exitWith {};

_myEff     = _snap select WFBE_SNAP_MYEFF;
_enEff     = _snap select WFBE_SNAP_ENEFF;
_enTowns   = _snap select WFBE_SNAP_ENTOWNS;
_myTowns   = _snap select WFBE_SNAP_MYTOWNS;
_enHQ      = _snap select WFBE_SNAP_ENHQ;
_enHQPos   = _snap select WFBE_SNAP_ENHQPOS;
_enHQAlive = _snap select WFBE_SNAP_ENHQALIVE;

_domRatio   = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_DOM_RATIO", 1.5];
_abortRatio = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ABORT_RATIO", 0.9];
_maxEnTowns = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_MAX_ENTOWNS", 5];
_armTicks   = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ARM_TICKS", 3];
_minCommit  = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_MIN_COMMIT", 300];
_senseRadius   = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_SENSE_RADIUS", 3000];
_senseInterval = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_SENSE_INTERVAL", 4];
_senseChance   = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_SENSE_CHANCE", 0.35];
_commitRadius  = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_COMMIT_RADIUS", _senseRadius];

_streak    = _logik getVariable "wfbe_aicom2_decap_streak";
_streak    = if (isNil "_streak") then {0} else {_streak};
_committed = _logik getVariable "wfbe_aicom2_decap_committed";
_committed = if (isNil "_committed") then {false} else {_committed};
_t0        = _logik getVariable "wfbe_aicom2_decap_t0";
_t0        = if (isNil "_t0") then {0} else {_t0};
_senseTick = _logik getVariable "wfbe_aicom2_decap_sensetick";
_senseTick = if (isNil "_senseTick") then {0} else {_senseTick};
_sensed    = _logik getVariable "wfbe_aicom2_decap_sensed";
_sensed    = if (isNil "_sensed") then {false} else {_sensed};

//--- ORGANIC BASE SENSING (owner Q1 2026-07-06): no acting on global HQ knowledge. Count eligible
//--- offensive team leaders within SENSE_RADIUS of the HQ - same team list + same strategy-tick
//--- cadence the stamp loop below already walks (no new scan cost). Then the periodic dice roll:
//--- every SENSE_INTERVAL ticks, chance SENSE_CHANCE, latches _sensed until contact is lost.
//--- No roll, no ARM progress: _sensed=false blocks the streak entirely.
_teams = _logik getVariable ["wfbe_teams", []];
_inRange = 0;
if (_enHQAlive) then {
	{
		_t = _x;
		if (!isNull _t && {({alive _x} count (units _t)) > 0}) then {
			if (isNil {_t getVariable "wfbe_aicom_base_garrison"} && {isNil {_t getVariable "wfbe_aicom_hold"}}) then {
				_ldr = leader _t;
				if (!isNull _ldr && {alive _ldr} && {((getPos _ldr) distance _enHQPos) <= _senseRadius}) then {_inRange = _inRange + 1};
			};
		};
	} forEach _teams;
};
_rollNow = 0;
if (_inRange == 0) then {
	_sensed = false;   //--- contact lost -> sensing decays; a fresh roll is required next approach
	_senseTick = 0;
} else {
	if (!_sensed) then {
		_senseTick = _senseTick + 1;
		if (_senseTick >= _senseInterval) then {
			_senseTick = 0;
			_rollNow = 1;   //--- telemetry: a roll was DUE and evaluated this tick (success = sensed flips 0->1 same tick -> SENSE_CHANCE validatable on soak)
			if ((random 1) < _senseChance) then {_sensed = true};
		};
	};
};

_dominant = _enHQAlive
	&& {_sensed}
	&& {_inRange > 0}
	&& {_enTowns <= _maxEnTowns}
	&& {(_enEff <= 0 && {_myEff > 0}) || {_enEff > 0 && {_myEff >= (_enEff * _domRatio)}}};

if (_committed) then {
	if (!_enHQAlive) then {
		_committed = false; _streak = 0; _sensed = false; _senseTick = 0;
		_state = "WON-HQDEAD";
	} else {
		if ((time - _t0) > _minCommit && {_enEff > 0} && {_myEff < (_enEff * _abortRatio)}) then {
			_committed = false; _streak = 0; _sensed = false; _senseTick = 0;
			_state = "ABORT";
		} else {
			_state = "COMMITTED";
		};
	};
} else {
	if (_dominant) then {
		_streak = _streak + 1;
		if (_streak >= _armTicks) then {
			_committed = true; _t0 = time;
			_state = "COMMIT";
		} else {
			_state = "ARMING";
		};
	} else {
		if (_streak > 0) then {_streak = _streak - 1};
		_state = "IDLE";
	};
};

_logik setVariable ["wfbe_aicom2_decap_streak", _streak];
_logik setVariable ["wfbe_aicom2_decap_committed", _committed];
_logik setVariable ["wfbe_aicom2_decap_t0", _t0];
_logik setVariable ["wfbe_aicom2_decap_sensetick", _senseTick];
_logik setVariable ["wfbe_aicom2_decap_sensed", _sensed];

if ((missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) > 0 && {_committed} && {_enHQAlive}) then {
	_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;
	_nearTown = objNull; _bestD = 1e12;
	{
		_d = (getPos _x) distance _enHQPos;
		if (_d < _bestD) then {_bestD = _d; _nearTown = _x};
	} forEach _tgtTowns;
	_stamped = 0;
	{
		_t = _x;
		if (!isNull _t && {({alive _x} count (units _t)) > 0}) then {
			if (isNil {_t getVariable "wfbe_aicom_base_garrison"} && {isNil {_t getVariable "wfbe_aicom_hold"}}) then {
				//--- SCOPED COMMIT (owner Q1): only teams already NEAR the HQ press; the rest keep their towns.
				_ldr = leader _t;
				if (!isNull _ldr && {alive _ldr} && {((getPos _ldr) distance _enHQPos) <= _commitRadius}) then {
					_t setVariable ["wfbe_aicom_decap", _enHQPos];
					if (!isNull _nearTown) then {_t setVariable ["wfbe_aicom_alloc_target", _nearTown]};
					_stamped = _stamped + 1;
				} else {
					//--- drifted out of the press radius -> clear the stale stamp; its TOWN orders are untouched.
					if (!isNil {_t getVariable "wfbe_aicom_decap"}) then {_t setVariable ["wfbe_aicom_decap", nil]};
				};
			} else {
				//--- became garrison/hold while committed -> the press stamp no longer applies; clear it (latent-consumer guard).
				if (!isNil {_t getVariable "wfbe_aicom_decap"}) then {_t setVariable ["wfbe_aicom_decap", nil]};
			};
		} else {
			if (!isNull _t && {!isNil {_t getVariable "wfbe_aicom_decap"}}) then {_t setVariable ["wfbe_aicom_decap", nil]};
		};
	} forEach _teams;
} else {
	{ if (!isNull _x && {!isNil {_x getVariable "wfbe_aicom_decap"}}) then {_x setVariable ["wfbe_aicom_decap", nil]} } forEach _teams;
	_stamped = 0;
};

_sideText = str _side;
_elMin = round (time / 60);
diag_log ("AICOM2|v1|DECAP|" + _sideText + "|" + str _elMin
	+ "|state=" + _state
	+ "|streak=" + str _streak
	+ "|committed=" + (if (_committed) then {"1"} else {"0"})
	+ "|myEff=" + str _myEff + "|enEff=" + str _enEff
	+ "|enTowns=" + str _enTowns + "|myTowns=" + str _myTowns
	+ "|enHQ=" + (if (_enHQAlive) then {"alive"} else {"dead"})
	+ "|inRange=" + str _inRange
	+ "|roll=" + str _rollNow
	+ "|sensed=" + (if (_sensed) then {"1"} else {"0"})
	+ "|stamped=" + str _stamped
	+ "|flag=" + str (missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]));
