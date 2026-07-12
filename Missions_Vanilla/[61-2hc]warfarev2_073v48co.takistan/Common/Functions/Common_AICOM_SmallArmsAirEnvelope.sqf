/*
	Common_AICOM_SmallArmsAirEnvelope.sqf

	Author: fable (fable/smallarms-air-envelope, GR-2026-07-08a)

	Description:
		Effectiveness-scaled small-arms x AIR engagement-envelope manager - the
		per-machine steering loop for WFBE_C_SMALLARMS_AIR_ENVELOPE. It clears a
		NON-AA (small-arms) unit's lock on an aircraft it cannot damage ONLY when the
		aircraft is BEYOND the effective envelope (WFBE_C_SMALLARMS_AIR_ENVELOPE_RANGE,
		default 300 m). Within the envelope nothing happens - a point-blank heli still
		draws fire from everyone, which is both realistic and correct-feeling.

		Locality: doTarget / doWatch must run where the unit is LOCAL. AICOM commander
		teams + delegated town-AI are local to the HC that founded them (server when no
		HC / mode 0). So this manager - cloned structurally from
		Common_AICOM_HeliTerrainGuard.sqf - runs on BOTH server and HC and touches ONLY
		local units (the Steer helper's `local _u` guard), enumerating both the AICOM
		wfbe_teams (per side) and the town-AI registries (server: each town's
		wfbe_town_teams; HC: WFBE_CL_TownAI_Groups).

		The effectiveness classifier is stamped ONCE at spawn (WFBE_effAntiAir, via
		WFBE_CO_FNC_SmallArmsEffAntiAir in Common_CreateUnit / Common_CreateTownUnits) so
		the per-tick cost is an O(1) cached bool read; the manager lazy-computes + caches
		for any unit that reaches it unstamped. AA units are NEVER steered.

		Cost is bounded the way every sibling AICOM manager bounds it: an air-presence
		gate (skip the whole sweep when no enemy aircraft is alive - one cheap `count
		vehicles` scan, the Server_GuerAirDef.sqf idiom), a cached classifier, and a 4-8 s
		cadence. It never doStop / disableAI / freezes a unit - it clears one lock and the
		unit returns to its move and re-engages anything it can actually hurt.

		FENCE: this is NOT the owner-rejected sim/distance-gating (WFBE_C_SIM_GATING). The
		distance compared is unit <-> its AIR TARGET, never unit <-> player; the simulation
		is never reduced or frozen. It is an engagement-RANGE knob by weapon effectiveness -
		the same shipped, default-ON class as the B60 HELI CANNON-NUDGE
		(Common_RunCommanderTeam.sqf), whose header states "no disableAI, no sim-gating."

		Flag: WFBE_C_SMALLARMS_AIR_ENVELOPE (default 0 = OFF; loop never starts, no spawn
		stamp, runtime byte-identical to HEAD). Tunables: WFBE_C_SMALLARMS_AIR_ENVELOPE_RANGE
		(300 m), WFBE_C_SMALLARMS_AIR_ENVELOPE_TICK (5 s).
*/

//--- Master gate. 0 = OFF (default) = byte-identical to HEAD: the loop never starts. Numeric guard, A2-OA-safe.
if ((missionNamespace getVariable ["WFBE_C_SMALLARMS_AIR_ENVELOPE", 0]) < 1) exitWith {};

//--- Only the server and headless clients host AICOM / town-AI local units (sibling-manager gate).
if (!isServer && {!isHeadLessClient}) exitWith {};

private ["_machineTag", "_range", "_tick", "_steerTotal", "_lastTelemetry"];
_machineTag    = if (isServer) then {"SERVER"} else {"HC"};
_range         = missionNamespace getVariable ["WFBE_C_SMALLARMS_AIR_ENVELOPE_RANGE", 300];
_tick          = missionNamespace getVariable ["WFBE_C_SMALLARMS_AIR_ENVELOPE_TICK", 5];
_steerTotal    = 0;
_lastTelemetry = diag_tickTime;

["INFORMATION", Format ["Common_AICOM_SmallArmsAirEnvelope.sqf: small-arms air-envelope ARMED (%1, envelope %2m, tick %3s).", _machineTag, _range, _tick]] Call WFBE_CO_FNC_AICOMLog;

//--- Publish a running steer counter (this machine) so a probe / soak can sample steer activity between
//--- the 300s telemetry lines. Local write (no public arg); inside the flag+machine gate = inert when off.
missionNamespace setVariable ["WFBE_AIRENV_STEERS", 0];

//--- ============================================================================
//--- Per-unit steer test. Clears a NON-AA unit's air lock beyond the envelope; leaves
//--- everything else untouched. Returns 1 if it cleared a lock this call, else 0.
//--- _this = [unit, range]. Acts only where the unit is LOCAL (guarded).
//--- ============================================================================
WFBE_CO_FNC_AICOM_AirEnvelope_Steer = {
	private ["_u", "_rng", "_veh", "_effAA", "_tgt"];
	_u   = _this select 0;
	_rng = _this select 1;

	if (isNull _u) exitWith {0};
	if (!alive _u) exitWith {0};
	//--- doTarget / doWatch only apply where the unit is local to this machine.
	if (!local _u) exitWith {0};

	//--- Mounted units are left alone: their weapon is the hull's, AA-vehicle / AA-static
	//--- gunners MUST keep engaging air, and a transport passenger's rifle is a non-issue.
	_veh = vehicle _u;
	if (_veh != _u) exitWith {0};

	//--- Cached effectiveness classifier (stamped at spawn); lazy-compute + cache if unstamped
	//--- (e.g. a loadout that gained an AA magazine after the spawn-time stamp).
	_effAA = _u getVariable "WFBE_effAntiAir";
	if (isNil "_effAA") then {
		_effAA = [_u] Call WFBE_CO_FNC_SmallArmsEffAntiAir;
		_u setVariable ["WFBE_effAntiAir", _effAA, false];
	};
	//--- AA-capable units are NEVER steered off, at any range.
	if (_effAA) exitWith {0};

	//--- Act only on a live AIR lock beyond the effective envelope.
	_tgt = assignedTarget _u;
	if (isNull _tgt) exitWith {0};
	if (!(_tgt isKindOf "Air")) exitWith {0};
	if ((_u distance _tgt) <= _rng) exitWith {0};

	//--- Beyond the envelope: clear the lock + watch. One-shot; the unit stays AWARE, keeps its
	//--- move, and re-detects / re-engages anything it can actually hurt (incl. this heli in < _rng).
	_u doTarget objNull;
	_u doWatch objNull;

	//--- Verbose per-steer line (WF_LOG_CONTENT-gated via LogContent; always-on on the HC).
	["INFORMATION", Format ["Common_AICOM_SmallArmsAirEnvelope.sqf: cleared %1 off air %2 @ %3m (envelope %4m).", typeOf _u, typeOf _tgt, round (_u distance _tgt), _rng]] Call WFBE_CO_FNC_LogContent;
	1
};

//--- ============================================================================
//--- Walk one group's units, steering each eligible one. _seen dedupes across the whole
//--- sweep (arrays are by-reference, so the shared _seen accumulates). _this = [group,
//--- range, seen]. Returns the number of locks cleared in this group.
//--- ============================================================================
WFBE_CO_FNC_AICOM_AirEnvelope_WalkTeam = {
	private ["_team", "_rng", "_seen", "_n"];
	_team = _this select 0;
	_rng  = _this select 1;
	_seen = _this select 2;
	_n    = 0;
	if (isNull _team) exitWith {_n};
	{
		if (!(_x in _seen)) then {
			_seen set [count _seen, _x];
			_n = _n + ([_x, _rng] Call WFBE_CO_FNC_AICOM_AirEnvelope_Steer);
		};
	} forEach (units _team);
	_n
};

//--- ============================================================================
//--- Manager loop. Air-presence gated (skip the whole sweep when no enemy air is alive).
//--- Enumerates AICOM wfbe_teams (both machines, local-only via the Steer guard) + the
//--- town-AI registries (server: towns' wfbe_town_teams; HC: WFBE_CL_TownAI_Groups).
//--- ============================================================================
private ["_perfStart", "_perfGroups", "_perfSteers", "_seen", "_anyEnemyAir", "_side", "_logik", "_team"];

while {!WFBE_gameover} do {

	//--- AIR-PRESENCE GATE (cheap global count): mirrors Server_GuerAirDef.sqf's
	//--- `{... isKindOf "Air" ...} count vehicles`. No enemy air alive => nothing to steer.
	_anyEnemyAir = {alive _x && {_x isKindOf "Air"} && {((side _x) == west) || {(side _x) == east} || {(side _x) == resistance}}} count vehicles;

	if (_anyEnemyAir > 0) then {

		_perfStart  = diag_tickTime;
		_perfGroups = 0;
		_perfSteers = 0;
		_seen       = [];

		//--- AICOM commander teams (per side wfbe_teams). Runs on both machines; the Steer
		//--- helper no-ops on any unit not local here, so each machine touches only its own.
		{
			_side  = _x;
			_logik = _side Call WFBE_CO_FNC_GetSideLogic;
			if (!isNil "_logik" && {!isNull _logik}) then {
				{
					_team = _x;
					if (!isNull _team) then {
						_perfGroups = _perfGroups + 1;
						_perfSteers = _perfSteers + ([_team, _range, _seen] Call WFBE_CO_FNC_AICOM_AirEnvelope_WalkTeam);
					};
				} forEach (_logik getVariable ["wfbe_teams", []]);
			};
		} forEach [west, east, resistance];

		//--- Town-defence AI. Server owns the no-HC fallback set in each town's wfbe_town_teams;
		//--- each HC owns its delegated town groups in WFBE_CL_TownAI_Groups ([town, side, group]).
		if (isServer) then {
			{
				//--- _x = town; (_x getVariable ...) is read before the inner forEach rebinds _x.
				{
					_team = _x;
					if (!isNull _team) then {
						_perfGroups = _perfGroups + 1;
						_perfSteers = _perfSteers + ([_team, _range, _seen] Call WFBE_CO_FNC_AICOM_AirEnvelope_WalkTeam);
					};
				} forEach (_x getVariable ["wfbe_town_teams", []]);
			} forEach towns;
		} else {
			{
				//--- _x = [town, side, group]; the group is index 2.
				_team = _x select 2;
				if (!isNull _team) then {
					_perfGroups = _perfGroups + 1;
					_perfSteers = _perfSteers + ([_team, _range, _seen] Call WFBE_CO_FNC_AICOM_AirEnvelope_WalkTeam);
				};
			} forEach (missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []]);
		};

		_steerTotal = _steerTotal + _perfSteers;
		missionNamespace setVariable ["WFBE_AIRENV_STEERS", _steerTotal];

		//--- Performance Audit record (tag "aicom_airenvelope"), same guard idiom as the sibling managers.
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["aicom_airenvelope", diag_tickTime - _perfStart, Format["groups:%1;units:%2;steers:%3", _perfGroups, count _seen, _perfSteers], _machineTag] Call PerformanceAudit_Record;
			};
		};
	};

	//--- ALWAYS-ON 300s telemetry heartbeat (fires even when idle, so a soak can tell ARMED-IDLE
	//--- from BROKEN). AIRENV|v1| line carries the running steer total for the probe + soaks.
	if ((diag_tickTime - _lastTelemetry) > 300) then {
		_lastTelemetry = diag_tickTime;
		diag_log (Format ["AIRENV|v1|EVENT|%1|%2|SWEEP|machine=%3|steersTotal=%4|range=%5|air=%6", str isServer, round (time / 60), _machineTag, _steerTotal, _range, _anyEnemyAir]);
	};

	sleep _tick;
};
