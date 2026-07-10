/*
	WASP lab-only cooperative scheduler prototype.

	This file is copied only into generated proving-ground missions. It is not a
	production scheduler and never runs unless WASP_LAB_SCHEDULER_MODE is
	"shadow" or "active".

	Job record:
	[id,lane,dueAt,interval,maxMs,code,state,enabled,runCount,overrunCount]

	A job receives [state, now] and returns [ok,newState,nextDelay,enabled,error].
	Job code must be bounded and must not sleep. The dispatcher measures elapsed
	wall time and frame crossings, but cannot pre-empt a job already executing in
	Arma's shared scheduled environment.
*/

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WASP_LAB_SCHEDULER_MODE", "off"]) == "off") exitWith {};
if (missionNamespace getVariable ["WASP_SCHED_INITIALIZED", false]) exitWith {};

missionNamespace setVariable ["WASP_SCHED_INITIALIZED", true];
missionNamespace setVariable ["WASP_SCHED_LANES", [[],[],[],[]]];
missionNamespace setVariable ["WASP_SCHED_STOP", false];
missionNamespace setVariable ["WASP_SCHED_HEALTH_AT", diag_tickTime];
missionNamespace setVariable ["WASP_SCHED_CONTROL_AT", diag_tickTime];
missionNamespace setVariable ["WASP_SCHED_RUN_TOTAL", 0];
missionNamespace setVariable ["WASP_SCHED_DEFER_TOTAL", 0];
missionNamespace setVariable ["WASP_SCHED_OVERRUN_TOTAL", 0];
missionNamespace setVariable ["WASP_SCHED_ERROR_TOTAL", 0];
missionNamespace setVariable ["WASP_SCHED_MAX_SPENT_MS", 0];
missionNamespace setVariable ["WASP_SCHED_LAST_SPENT_MS", 0];
missionNamespace setVariable ["WASP_SCHED_LAST_DUE", 0];
missionNamespace setVariable ["WASP_SCHED_LAST_DEFERRED", 0];

WASP_SCHED_FNC_Register = {
	Private ["_id","_lane","_delay","_interval","_maxMs","_code","_state","_lanes","_jobs","_job","_total","_duplicate"];
	if (typeName _this != "ARRAY" || {count _this < 7}) exitWith {false};
	_id = _this select 0;
	_lane = _this select 1;
	_delay = _this select 2;
	_interval = _this select 3;
	_maxMs = _this select 4;
	_code = _this select 5;
	_state = _this select 6;
	if (typeName _id != "STRING" || {typeName _lane != "SCALAR"} || {typeName _delay != "SCALAR"} ||
		{typeName _interval != "SCALAR"} || {typeName _maxMs != "SCALAR"} || {typeName _code != "CODE"}) exitWith {false};
	_lane = (floor _lane) max 0 min 3;
	_delay = _delay max 0;
	_interval = _interval max 0.01;
	_maxMs = _maxMs max 0.1;
	_lanes = missionNamespace getVariable ["WASP_SCHED_LANES", [[],[],[],[]]];
	_total = 0;
	_duplicate = false;
	{
		_jobs = _x;
		{
			if ((_x select 0) == _id && {_x select 7}) then {_duplicate = true};
		} forEach _jobs;
		_total = _total + count _jobs;
	} forEach _lanes;
	if (_duplicate) exitWith {
		missionNamespace setVariable ["WASP_SCHED_ERROR_TOTAL", (missionNamespace getVariable ["WASP_SCHED_ERROR_TOTAL", 0]) + 1];
		diag_log ("WASPSCHED|v1|REJECT|id=" + _id + "|reason=duplicate_id");
		false
	};
	if (_total >= 32) exitWith {
		missionNamespace setVariable ["WASP_SCHED_ERROR_TOTAL", (missionNamespace getVariable ["WASP_SCHED_ERROR_TOTAL", 0]) + 1];
		diag_log ("WASPSCHED|v1|REJECT|id=" + _id + "|reason=queue_cap|cap=32");
		false
	};
	_jobs = _lanes select _lane;
	_job = [_id, _lane, diag_tickTime + _delay, _interval, _maxMs, _code, _state, true, 0, 0];
	_jobs set [count _jobs, _job];
	_lanes set [_lane, _jobs];
	missionNamespace setVariable ["WASP_SCHED_LANES", _lanes];
	true
};

WASP_SCHED_FNC_Disable = {
	Private ["_id","_lanes","_jobs","_job"];
	_id = _this;
	if (typeName _id != "STRING") exitWith {false};
	_lanes = missionNamespace getVariable ["WASP_SCHED_LANES", [[],[],[],[]]];
	{
		_jobs = _x;
		{
			_job = _x;
			if ((_job select 0) == _id) then {_job set [7, false]};
		} forEach _jobs;
	} forEach _lanes;
	true
};

// Separate minimal heartbeat: it cannot reserve engine time, but a bad work job
// cannot trap this script inside its call stack. PVEH ACK handlers also remain
// outside the work dispatcher.
[] Spawn {
	while {!(missionNamespace getVariable ["WASP_SCHED_STOP", false]) && {!(missionNamespace getVariable ["WASP_LAB_STOP", false])}} do {
		missionNamespace setVariable ["WASP_SCHED_CONTROL_AT", diag_tickTime];
		sleep 1;
	};
};

[] Spawn {
	Private ["_lanes","_jobs","_job","_lane","_i","_now","_passStart","_spentMs","_budgetMs",
		"_due","_deferred","_oldestMs","_ran","_enabled","_dueAt","_canRun","_jobStart","_runtimeMs",
		"_code","_state","_result","_ok","_error","_nextDelay","_keep","_maxMs","_warnKey","_warnAt","_healthNext",
		"_queued","_mode","_passFrameStart","_frameStart","_frameDelta","_compactNext","_newLanes","_newJobs"];
	_healthNext = diag_tickTime;
	_compactNext = diag_tickTime + 5;
	while {!(missionNamespace getVariable ["WASP_SCHED_STOP", false]) && {!(missionNamespace getVariable ["WASP_LAB_STOP", false])}} do {
		_passStart = diag_tickTime;
		_passFrameStart = diag_frameno;
		_now = _passStart;
		// Advisory launch budget only. OA shares roughly 3 ms/frame across all scheduled scripts.
		_budgetMs = if (diag_fps >= 42) then {1} else {if (diag_fps >= 32) then {0.75} else {if (diag_fps >= 25) then {0.5} else {0.25}}};
		_due = 0;
		_deferred = 0;
		_oldestMs = 0;
		_ran = 0;
		_queued = 0;
		_lanes = missionNamespace getVariable ["WASP_SCHED_LANES", [[],[],[],[]]];
		for "_lane" from 0 to 3 do {
			_jobs = _lanes select _lane;
			for "_i" from 0 to ((count _jobs) - 1) do {
				_job = _jobs select _i;
				_enabled = _job select 7;
				if (_enabled) then {
					_queued = _queued + 1;
					_dueAt = _job select 2;
					if (_dueAt <= _now) then {
						_due = _due + 1;
						_oldestMs = _oldestMs max ((_now - _dueAt) * 1000);
						_spentMs = (diag_tickTime - _passStart) * 1000;
						_canRun = (_spentMs < _budgetMs) && {_ran < 16};
						if (_canRun) then {
							_jobStart = diag_tickTime;
							_frameStart = diag_frameno;
							_code = _job select 5;
							_state = _job select 6;
							_result = [_state, _now] Call _code;
							_runtimeMs = (diag_tickTime - _jobStart) * 1000;
							_frameDelta = diag_frameno - _frameStart;
							_nextDelay = _job select 3;
							_keep = false;
							_ok = false;
							_error = "invalid_result";
							if (typeName _result == "ARRAY" && {count _result >= 5}) then {
								if (typeName (_result select 0) == "BOOL") then {_ok = _result select 0};
								_state = _result select 1;
								if (typeName (_result select 2) == "SCALAR") then {_nextDelay = (_result select 2) max 0.01};
								if (typeName (_result select 3) == "BOOL") then {_keep = _result select 3};
								if (typeName (_result select 4) == "STRING") then {_error = _result select 4};
							};
							if !(_ok) then {
								_keep = false;
								missionNamespace setVariable ["WASP_SCHED_ERROR_TOTAL", (missionNamespace getVariable ["WASP_SCHED_ERROR_TOTAL", 0]) + 1];
								diag_log ("WASPSCHED|v1|JOB|id=" + (_job select 0) + "|state=DISABLED|error=" + _error);
							};
							_job set [2, diag_tickTime + _nextDelay];
							_job set [6, _state];
							_job set [7, _keep];
							_job set [8, (_job select 8) + 1];
							_maxMs = _job select 4;
							if (_runtimeMs > _maxMs) then {
								_job set [9, (_job select 9) + 1];
								missionNamespace setVariable ["WASP_SCHED_OVERRUN_TOTAL", (missionNamespace getVariable ["WASP_SCHED_OVERRUN_TOTAL", 0]) + 1];
								_warnKey = "WASP_SCHED_WARN_" + (_job select 0);
								_warnAt = missionNamespace getVariable [_warnKey, -9999];
								if ((diag_tickTime - _warnAt) >= 60) then {
									missionNamespace setVariable [_warnKey, diag_tickTime];
									diag_log ("WASPSCHED|v1|JOB|id=" + (_job select 0) + "|elapsedMs=" + str (round (_runtimeMs * 10) / 10) +
										"|frameDelta=" + str _frameDelta + "|maxMs=" + str _maxMs + "|state=OVERRUN");
								};
							};
							_ran = _ran + 1;
						} else {
							_deferred = _deferred + 1;
						};
					};
				};
			};
		};
		_spentMs = (diag_tickTime - _passStart) * 1000;
		_frameDelta = diag_frameno - _passFrameStart;
		missionNamespace setVariable ["WASP_SCHED_HEALTH_AT", diag_tickTime];
		missionNamespace setVariable ["WASP_SCHED_RUN_TOTAL", (missionNamespace getVariable ["WASP_SCHED_RUN_TOTAL", 0]) + _ran];
		missionNamespace setVariable ["WASP_SCHED_DEFER_TOTAL", (missionNamespace getVariable ["WASP_SCHED_DEFER_TOTAL", 0]) + _deferred];
		missionNamespace setVariable ["WASP_SCHED_MAX_SPENT_MS", (missionNamespace getVariable ["WASP_SCHED_MAX_SPENT_MS", 0]) max _spentMs];
		missionNamespace setVariable ["WASP_SCHED_LAST_SPENT_MS", _spentMs];
		missionNamespace setVariable ["WASP_SCHED_LAST_DUE", _due];
		missionNamespace setVariable ["WASP_SCHED_LAST_DEFERRED", _deferred];
		if (diag_tickTime >= _healthNext) then {
			_mode = missionNamespace getVariable ["WASP_LAB_SCHEDULER_MODE", "unknown"];
			diag_log ("WASPSCHED|v1|HEALTH|proc=server|mode=" + _mode + "|fps=" + str (round (diag_fps * 10) / 10) +
				"|budgetMs=" + str _budgetMs + "|elapsedMs=" + str (round (_spentMs * 10) / 10) + "|frameDelta=" + str _frameDelta + "|ran=" + str _ran +
				"|deferred=" + str _deferred + "|due=" + str _due + "|queued=" + str _queued +
				"|oldestMs=" + str (round (_oldestMs * 10) / 10) + "|overruns=" + str (missionNamespace getVariable ["WASP_SCHED_OVERRUN_TOTAL", 0]));
			diag_log ("WASPLAB|v1|SCHED|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "pending"]) +
				"|mode=" + _mode + "|budgetMs=" + str _budgetMs + "|elapsedMs=" + str (round (_spentMs * 10) / 10) + "|frameDelta=" + str _frameDelta +
				"|ran=" + str _ran + "|deferred=" + str _deferred + "|due=" + str _due + "|queued=" + str _queued +
				"|oldestMs=" + str (round (_oldestMs * 10) / 10) + "|overruns=" + str (missionNamespace getVariable ["WASP_SCHED_OVERRUN_TOTAL", 0]));
			_healthNext = diag_tickTime + 10;
		};
		if (diag_tickTime >= _compactNext) then {
			_newLanes = [[],[],[],[]];
			for "_lane" from 0 to 3 do {
				_newJobs = [];
				{if (_x select 7) then {_newJobs set [count _newJobs, _x]}} forEach (_lanes select _lane);
				_newLanes set [_lane, _newJobs];
			};
			missionNamespace setVariable ["WASP_SCHED_LANES", _newLanes];
			_compactNext = diag_tickTime + 5;
		};
		sleep 0.01;
	};
};

diag_log ("WASPSCHED|v1|START|proc=server|mode=" + (missionNamespace getVariable ["WASP_LAB_SCHEDULER_MODE", "unknown"]) + "|queueCap=32");
