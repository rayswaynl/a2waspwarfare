/*
	AI_Commander_Decapitate.sqf - AICOM v2 M5 DECAPITATE CLOSER. Server-side, per side.
	Param: _this = side. Runs AFTER the M0 snapshot + the M1 Allocator each strategy tick
	(so its HQ-commit override is the LAST write to wfbe_aicom_targets / per-team alloc), gated
	by WFBE_C_AICOM2_DECAP_ENABLE (0 = inert -> reads snapshot + emits telemetry ONLY, no writes,
	byte-identical behaviour to HEAD; instant rollback).

	THE MISSING KILL-MOVE. Live evidence 2026-07-04 (ZG, players): the dominant side (EAST, 7 towns
	vs 2, strike posture, armour) ran 116 orders -> 50 arrivals -> 1 begin_capture over 90 min and
	produced ZERO base overruns - froze 2-7-2 because the strike verb RALLIES-AND-HOLDS near the HQ
	instead of pressing onto it. The Allocator concentrates the fist on the nearest capturable TOWN;
	nothing ever commits the army to the enemy HQ itself. This closer is that commit.

	DURABILITY LATCH (the anti-flap core): ARM only after WFBE_C_AICOM2_DECAP_ARM_TICKS consecutive
	dominant ticks (myEff >= enEff*DOM_RATIO AND enemy down to <= MAX_ENTOWNS AND enemy HQ alive) ->
	COMMITTED. Once COMMITTED it STOPS re-evaluating entry; the only exits are enemy-HQ-dead (win) or
	a deliberately-hard ABORT (myEff < enEff*ABORT_RATIO sustained, and only after MIN_COMMIT seconds).
	Wide hysteresis a momentary garrison dip cannot cross - the leader own garrisoning briefly lowers
	_myStr and the legacy strike auto-recalled on exactly that; this does not.

	COMMIT ACTION: publish the enemy HQ as the side main effort (wfbe_aicom_targets = [enHQ]) and
	stamp every eligible offensive team wfbe_aicom_decap = enHQpos + wfbe_aicom_alloc_target = the
	enemy town nearest the HQ (real town object AssignTowns already executes -> collapses the fist onto
	the HQ approach). The driver reads wfbe_aicom_decap to PRESS onto the HQ pos + assault there rather
	than rally-hold at the arrival gate (driver hook, WFBE_C_AICOM2_DECAP_ENABLE-gated). Feeds the
	existing overrun razer, which razes HQ + factories -> server_victory_threeway.sqf win fires.

	State on the side logic: wfbe_aicom2_decap_streak (consecutive dominant ticks),
	wfbe_aicom2_decap_committed (bool), wfbe_aicom2_decap_t0 (commit time). Telemetry AICOM2|v1|DECAP.
	A2-OA-safe: snapshot for tick-stable facts; plain-get + isNil heals (no GROUP 2-arg getVariable, no
	NSSETVAR3, no A3 commands); >0 numeric-flag guards; if/else booleans (no ==/!= on Bool).
*/

private ["_side","_logik","_snap","_myEff","_enEff","_enTowns","_myTowns","_enHQ","_enHQPos","_enHQAlive",
	"_domRatio","_abortRatio","_maxEnTowns","_armTicks","_minCommit","_dominant","_streak","_committed",
	"_t0","_state","_tgtTowns","_teams","_nearTown","_bestD","_d","_t","_stamped","_sideText","_elMin"];

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
_maxEnTowns = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_MAX_ENTOWNS", 2];
_armTicks   = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ARM_TICKS", 3];
_minCommit  = missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_MIN_COMMIT", 300];

_streak    = _logik getVariable "wfbe_aicom2_decap_streak";
_streak    = if (isNil "_streak") then {0} else {_streak};
_committed = _logik getVariable "wfbe_aicom2_decap_committed";
_committed = if (isNil "_committed") then {false} else {_committed};
_t0        = _logik getVariable "wfbe_aicom2_decap_t0";
_t0        = if (isNil "_t0") then {0} else {_t0};

_dominant = _enHQAlive
	&& {_enTowns <= _maxEnTowns}
	&& {(_enEff <= 0 && {_myEff > 0}) || {_enEff > 0 && {_myEff >= (_enEff * _domRatio)}}};

if (_committed) then {
	if (!_enHQAlive) then {
		_committed = false; _streak = 0;
		_state = "WON-HQDEAD";
	} else {
		if ((time - _t0) > _minCommit && {_enEff > 0} && {_myEff < (_enEff * _abortRatio)}) then {
			_committed = false; _streak = 0;
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

if ((missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) > 0 && {_committed} && {_enHQAlive}) then {
	_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS;
	_nearTown = objNull; _bestD = 1e12;
	{
		_d = (getPos _x) distance _enHQPos;
		if (_d < _bestD) then {_bestD = _d; _nearTown = _x};
	} forEach _tgtTowns;
	_logik setVariable ["wfbe_aicom_targets", [_enHQ]];
	_teams = _logik getVariable ["wfbe_teams", []];
	_stamped = 0;
	{
		_t = _x;
		if (!isNull _t && {({alive _x} count (units _t)) > 0}) then {
			if (isNil {_t getVariable "wfbe_aicom_base_garrison"} && {isNil {_t getVariable "wfbe_aicom_hold"}}) then {
				_t setVariable ["wfbe_aicom_decap", _enHQPos];
				if (!isNull _nearTown) then {_t setVariable ["wfbe_aicom_alloc_target", _nearTown]};
				_stamped = _stamped + 1;
			};
		};
	} forEach _teams;
} else {
	_teams = _logik getVariable ["wfbe_teams", []];
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
	+ "|stamped=" + str _stamped
	+ "|flag=" + str (missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]));
