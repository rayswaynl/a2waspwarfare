// Server_FpsGovernor.sqf
// FPS-adaptive AI governor (fable/fps-governor, NEXT-WAVE, owner direction 2026-08-08): samples
// live server diag_fps on an EMA and derives ONE shared [MULT_FLOOR..1.0] budget multiplier
// (WFBE_FpsGovMultiplier) that AI_Commander_Produce.sqf, AI_Commander_Teams.sqf,
// Server_GetTownGroups.sqf, Server_GetTownGroupsDefender.sqf and AI_Commander_HCTopUp.sqf scale
// their side AI-commander / town-garrison / HC-top-up budgets by when WFBE_C_FPS_GOVERNOR is
// armed. Server FPS is a single shared resource (not sampled per side), so one governor loop
// drives every consumer identically - "per side" in the owner ask means each SIDE'S OWN budget is
// scaled by this shared signal, not that the signal itself differs by side.
//
// Flag-off (default 0): this script exits at line 1 and is never even execVM'd (Init_Server.sqf
// gates the launch on the same flag) - byte-identical to HEAD.
//
// Never deletes/disbands a live AI unit or group - purely a forward-looking throttle on the five
// existing production/founding/garrison/top-up choke points listed above. See
// docs/Reports/AICAP-MIDHIGH-SCATTER-2026-07-22.md for the FPS-vs-AI_TOT knee data the default
// WFBE_C_FPS_GOVERNOR_FPS_CEIL/FLOOR bands are derived from.
//
// A2 OA 1.64 compliant: private [...] declared upfront, lazy && {} / || {}, no exitWith inside
// forEach, plain `sleep` - this script is launched via execVM (a scheduled environment); uiSleep
// is for unscheduled/event-handler contexts only and would be wrong here.

if (!((missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR", 0]) > 0)) exitWith {};

//--- Singleton guard (Server_CmdTownLedger.sqf precedent): a duplicate instance would double-drive
//--- the EMA and the ramp step, corrupting the published multiplier.
if ((missionNamespace getVariable ["WFBE_FPSGOV_INSTANCE", 0]) > 0) exitWith {
	diag_log "FPSGOV|v1|DUPLICATE_BLOCKED";
};
WFBE_FPSGOV_INSTANCE = 1;

//--- diag_fps on a listen/SP host reflects that host's own client frame, not an authoritative
//--- server tick - governing off it would mis-throttle every side. Dedicated-only, same guard
//--- serverFpsGUI.sqf uses (Server\GUI\serverFpsGUI.sqf:4).
if (!isDedicated) exitWith {};

private ["_tickSec","_emaSec","_alpha","_fpsCeil","_fpsFloor","_multFloor","_stepMax","_deadband",
         "_ema","_emaSeeded","_fpsNow","_target","_delta","_mult","_prevMult",
         "_tierArr","_tierIdx","_tierCap","_budgetWE"];

_tickSec   = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_TICK_SEC",   10];
_emaSec    = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_EMA_SEC",    90];
_fpsCeil   = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_FPS_CEIL",   40];
_fpsFloor  = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_FPS_FLOOR",  20];
_multFloor = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_MULT_FLOOR", 0.5];
_stepMax   = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_STEP_MAX",   0.1];
_deadband  = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_DEADBAND",   0.02];

//--- alpha for a tick-interval EMA over an _emaSec window: alpha = tick/window, clamped to (0,1].
_alpha = _tickSec / _emaSec;
if (_alpha > 1) then {_alpha = 1};
if (_alpha <= 0) then {_alpha = 1};

_ema = 0;
_emaSeeded = false;
_prevMult = missionNamespace getVariable ["WFBE_FpsGovMultiplier", 1]; //--- Init_CommonConstants.sqf seeds this to 1; ramp continues from there (single writer here, so no race).

["INITIALIZATION", Format ["Server_FpsGovernor.sqf: FPS governor ARMED - tick=%1s ema=%2s fpsCeil=%3 fpsFloor=%4 multFloor=%5 stepMax=%6 deadband=%7.", _tickSec, _emaSec, _fpsCeil, _fpsFloor, _multFloor, _stepMax, _deadband]] Call WFBE_CO_FNC_LogContent;

while {true} do {
	//--- HP-01 supervisor heartbeat idiom (same first-statement-of-iteration convention every other
	//--- coreloop worker uses) - written defensively for a future server_coreloop_supervisor.sqf
	//--- registration; this worker is NOT registered with the supervisor in this PR (scope boundary,
	//--- see PR body), so a stalled governor is not yet auto-restarted.
	missionNamespace setVariable ["wfbe_coreloop_hb_fpsgov", time];

	_fpsNow = diag_fps;
	if (!_emaSeeded) then {_ema = _fpsNow; _emaSeeded = true} else {_ema = _ema + ((_fpsNow - _ema) * _alpha)};

	//--- Linear map: EMA >= ceil -> 1.0 (full budget); EMA <= floor -> _multFloor; straight-line
	//--- between. A misconfigured override (ceil <= floor) collapses to a flat _multFloor instead of
	//--- dividing by zero.
	if (_fpsCeil <= _fpsFloor) then {
		_target = _multFloor;
	} else {
		if (_ema >= _fpsCeil) then {
			_target = 1;
		} else {
			if (_ema <= _fpsFloor) then {
				_target = _multFloor;
			} else {
				_target = _multFloor + (((_ema - _fpsFloor) / (_fpsCeil - _fpsFloor)) * (1 - _multFloor));
			};
		};
	};

	//--- Ramp + hysteresis: only move toward _target, capped at _stepMax per tick (never jumps), and
	//--- only PUBLISH when the move clears _deadband (a sub-deadband move is computed but dropped) -
	//--- keeps every consumer's budget from chattering tick-to-tick on ordinary FPS jitter.
	_delta = _target - _prevMult;
	if (_delta > _stepMax) then {_delta = _stepMax};
	if (_delta < (-1 * _stepMax)) then {_delta = -1 * _stepMax};
	_mult = _prevMult + _delta;
	if (_mult > 1) then {_mult = 1};
	if (_mult < _multFloor) then {_mult = _multFloor};

	if (abs (_mult - _prevMult) >= _deadband) then {
		WFBE_FpsGovMultiplier = _mult;
		_prevMult = _mult;
	};

	//--- Resolved WEST/EAST budget at the CURRENT pop tier, for soak-readable telemetry (GUER/town
	//--- defenders don't share this tier array - Server_GetTownGroupsDefender.sqf's own diag_log
	//--- lines carry the per-town figure when the CTL garrison-link is armed).
	_tierArr = missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", [180,170,150,120]];
	_tierIdx = ((missionNamespace getVariable ["WFBE_PopTier", 0]) max 0) min ((count _tierArr) - 1);
	_tierCap = _tierArr select _tierIdx;
	_budgetWE = floor (_tierCap * WFBE_FpsGovMultiplier);

	diag_log Format ["FPSGOV|v1|fps=%1|ema=%2|target=%3|mult=%4|tier=%5|capBase=%6|budgetWE=%7", round _fpsNow, (round (_ema * 10)) / 10, (round (_target * 100)) / 100, (round (WFBE_FpsGovMultiplier * 100)) / 100, _tierIdx, _tierCap, _budgetWE];

	sleep _tickSec;
};
