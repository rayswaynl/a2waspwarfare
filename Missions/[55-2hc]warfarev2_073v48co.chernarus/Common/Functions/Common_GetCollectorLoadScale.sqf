//--- Perf (2026-07-25, Grok idea #24): scales a collector's between-pass sleep by current server
//--- load when WFBE_C_COLLECTOR_LOAD_SCALE is armed (default 0 = inert, returns _baseDelay
//--- unchanged, never reads diag_fps). Used by Server\FSM\emptyvehiclescollector.sqf and
//--- Server\FSM\server_collector_garbage.sqf so both back off their fixed 1s/5s cadence under load
//--- and snap back to the base cadence once fps recovers, instead of hammering a struggling server
//--- on a fixed schedule. Ceiling is 2.5x _baseDelay - never longer, so worst-case per-item
//--- collection latency is bounded (both callers fully drain their current snapshot every pass,
//--- so a longer sleep only delays the NEXT sweep; it cannot grow an unbounded backlog).
//--- Emits ONE diag_log line on engage and ONE on disengage (shared transition flag across both
//--- collectors, not per pass) so live RPT shows exactly when scaling kicked in/out.
//---
//--- Params: [_baseDelay] (number, seconds)
//--- Returns: scaled delay (number, seconds)

Private ["_baseDelay","_armed","_fps","_multiplier","_wasEngaged","_delay"];

_baseDelay = _this;

_armed = (missionNamespace getVariable ["WFBE_C_COLLECTOR_LOAD_SCALE", 0]) > 0;
if !(_armed) exitWith {
	//--- Disarmed mid-round after having engaged: clear the flag and log the disengage once.
	if (missionNamespace getVariable ["WFBE_CollectorLoadScaleEngaged", false]) then {
		WFBE_CollectorLoadScaleEngaged = false;
		diag_log "WFBE_COLLECTOR_LOAD_SCALE: disengaged (flag disarmed)";
	};
	_baseDelay
};

_fps = diag_fps;
_wasEngaged = missionNamespace getVariable ["WFBE_CollectorLoadScaleEngaged", false];
_multiplier = 1;
if (_fps <= 20 && _fps > 15) then {_multiplier = 1.2};
if (_fps <= 15 && _fps > 10) then {_multiplier = 1.5};
if (_fps <= 10 && _fps > 5)  then {_multiplier = 2.0};
if (_fps <= 5)                then {_multiplier = 2.5};
//--- Hysteresis: after shedding engages at <=20 fps, retain the light back-off until the server
//--- clears 22 fps. Without this gap, a 20/21 fps sample sawtooths the collectors every pass.
if (_wasEngaged && {_fps > 20} && {_fps <= 22}) then {_multiplier = 1.2};

if (_multiplier > 1 && !_wasEngaged) then {
	WFBE_CollectorLoadScaleEngaged = true;
	diag_log Format ["WFBE_COLLECTOR_LOAD_SCALE: engaged (fps:%1 multiplier:%2)", round _fps, _multiplier];
};
if (_multiplier <= 1 && _wasEngaged) then {
	WFBE_CollectorLoadScaleEngaged = false;
	diag_log "WFBE_COLLECTOR_LOAD_SCALE: disengaged (fps recovered)";
};

_delay = _baseDelay * _multiplier;
_delay
