/*
	Author: Marty
	Contributors:
	Name: Client_DayNightCycle.sqf
	Description:
		Client-side day/night smoother for Arma 2 OA multiplayer.

		The server remains authoritative by broadcasting WFBE_DAYNIGHT_DATE.
		The client does not call setDate for every broadcast, because setDate can
		freeze rendering while the environment is recalculated. Instead, the client
		animates time locally with small skipTime steps and uses server broadcasts
		only to calculate a smooth drift correction.
*/

Private [
	"_day_duration_real",
	"_night_duration_real",
	"_day_duration_real_seconds",
	"_night_duration_real_seconds",
	"_day_hours_game",
	"_night_hours_game",
	"_dawn_start",
	"_dawn_end",
	"_dusk_start",
	"_dusk_end",
	"_dawn_hours_game",
	"_dusk_hours_game",
	"_twilight_weight",
	"_day_weighted_hours",
	"_day_hours_per_second",
	"_twilight_hours_per_second",
	"_night_hours_per_second",
	"_tick",
	"_max_correction_hours",
	"_hard_sync_hours",
	"_hour",
	"_hours_to_skip",
	"_server_date",
	"_local_date",
	"_year_delta",
	"_drift_hours",
	"_correction_hours",
	"_correction_step"
];

// This script is for remote clients only. A hosted server player already uses the server clock loop.
if (isDedicated || isServer) exitWith {};
// Marty: Defensive guard in case this script is executed while the mission parameter is disabled.
if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") != 1) exitWith {};

waitUntil {time > 0};
waitUntil {!isNil "WFBE_Parameters_Ready"};

//--- r76b: same duration/tick/weight fail-clean as server (div0 -> frozen or runaway local clock).
_day_duration_real = missionNamespace getVariable ["WFBE_DAY_DURATION", 180];
_night_duration_real = missionNamespace getVariable ["WFBE_NIGHT_DURATION", 30];
if (isNil "_day_duration_real" || {typeName _day_duration_real != "SCALAR"} || {_day_duration_real <= 0}) then {_day_duration_real = 180};
if (isNil "_night_duration_real" || {typeName _night_duration_real != "SCALAR"} || {_night_duration_real <= 0}) then {_night_duration_real = 30};

_day_duration_real_seconds = _day_duration_real * 60;
_night_duration_real_seconds = _night_duration_real * 60;

// Marty: Phase boundaries are estimated for Chernarus on 28 June, the mission's effective date after the month override.
_dawn_start = missionNamespace getVariable ["WFBE_DAYNIGHT_DAWN_START", 4];
_dawn_end = missionNamespace getVariable ["WFBE_DAYNIGHT_DAWN_END", 5];
_dusk_start = missionNamespace getVariable ["WFBE_DAYNIGHT_DUSK_START", 20.5];
_dusk_end = missionNamespace getVariable ["WFBE_DAYNIGHT_DUSK_END", 21.5];
_twilight_weight = missionNamespace getVariable ["WFBE_DAYNIGHT_TWILIGHT_WEIGHT", 3];
if (isNil "_twilight_weight" || {typeName _twilight_weight != "SCALAR"} || {_twilight_weight <= 0}) then {_twilight_weight = 3};

_dawn_hours_game = _dawn_end - _dawn_start;
_day_hours_game = _dusk_start - _dawn_end;
_dusk_hours_game = _dusk_end - _dusk_start;
_night_hours_game = (24 - _dusk_end) + _dawn_start;

// Marty: These rates match the server. Dawn and dusk advance slower than full daylight for smoother visual transitions.
_day_weighted_hours = _day_hours_game + ((_dawn_hours_game + _dusk_hours_game) * _twilight_weight);
_day_hours_per_second = _day_weighted_hours / _day_duration_real_seconds;
_twilight_hours_per_second = _day_weighted_hours / (_day_duration_real_seconds * _twilight_weight);
_night_hours_per_second = _night_hours_game / _night_duration_real_seconds;

_tick = missionNamespace getVariable ["WFBE_DAYNIGHT_CLIENT_TICK", 0.1];
_max_correction_hours = missionNamespace getVariable ["WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION", 0.0005];
_hard_sync_hours = missionNamespace getVariable ["WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT", 6];
if (isNil "_tick" || {typeName _tick != "SCALAR"} || {_tick <= 0}) then {_tick = 0.1};
if (isNil "_max_correction_hours" || {typeName _max_correction_hours != "SCALAR"}) then {_max_correction_hours = 0.0005};
if (isNil "_hard_sync_hours" || {typeName _hard_sync_hours != "SCALAR"}) then {_hard_sync_hours = 6};

// The public variable handler can run before this script reaches the loop, so do not erase a pending sync.
if (isNil "WFBE_DAYNIGHT_PENDING_SYNC") then {WFBE_DAYNIGHT_PENDING_SYNC = false};
if (isNil "WFBE_DAYNIGHT_CORRECTION_HOURS") then {WFBE_DAYNIGHT_CORRECTION_HOURS = 0};

while {(missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1} do {
	// A public variable event only stores the server date. The expensive decision is handled here in one place.
	if (WFBE_DAYNIGHT_PENDING_SYNC) then {
		WFBE_DAYNIGHT_PENDING_SYNC = false;

		if (!isNil "WFBE_DAYNIGHT_SERVER_DATE") then {
			_server_date = WFBE_DAYNIGHT_SERVER_DATE;

			if ((typeName _server_date) == "ARRAY" && (count _server_date >= 5)) then {
				_local_date = date;
				_year_delta = (_server_date select 0) - (_local_date select 0);
				_drift_hours = (((dateToNumber _server_date) - (dateToNumber _local_date)) + _year_delta) * 365 * 24;

				if ((abs _drift_hours) > _hard_sync_hours) then {
					// Huge drift should only happen after a bad JIP sync or a broken local clock.
					// One setDate is acceptable here; regular gameplay sync is handled by skipTime below.
					setDate _server_date;
					WFBE_DAYNIGHT_CORRECTION_HOURS = 0;
				} else {
					// Store the drift and pay it back gradually across future ticks.
					WFBE_DAYNIGHT_CORRECTION_HOURS = WFBE_DAYNIGHT_CORRECTION_HOURS + _drift_hours;
				};
			};
		};
	};

	_hour = daytime;

	// Marty: Night is the wrap-around default; dawn/day/dusk override it when the current hour is inside their ranges.
	_hours_to_skip = _night_hours_per_second * _tick;
	if (_hour >= _dawn_start && _hour < _dawn_end) then {_hours_to_skip = _twilight_hours_per_second * _tick};
	if (_hour >= _dawn_end && _hour < _dusk_start) then {_hours_to_skip = _day_hours_per_second * _tick};
	if (_hour >= _dusk_start && _hour < _dusk_end) then {_hours_to_skip = _twilight_hours_per_second * _tick};

	// Apply only a small portion of any server drift per tick so the correction stays smooth.
	_correction_hours = WFBE_DAYNIGHT_CORRECTION_HOURS;
	if ((abs _correction_hours) > 0.0001) then {
		_correction_step = (_correction_hours max (0 - _max_correction_hours)) min _max_correction_hours;
		_hours_to_skip = _hours_to_skip + _correction_step;
		WFBE_DAYNIGHT_CORRECTION_HOURS = _correction_hours - _correction_step;
	};

	skipTime _hours_to_skip;
	sleep _tick;
};
