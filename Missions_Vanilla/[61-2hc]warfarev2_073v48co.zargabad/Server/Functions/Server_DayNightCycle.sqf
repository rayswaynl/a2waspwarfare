/*
    Author : Marty 
	Contributors :
	Name: daynight_cycle.sqf
    Description:
        Server-side authoritative accelerated day/night cycle.
        Day and night real-life durations are configurable through mission parameters.

    Mission parameters:
        WFBE_DAY_DURATION   - Real-life duration of daytime in minutes.
        WFBE_NIGHT_DURATION - Real-life duration of nighttime in minutes.
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
    "_sync_interval",
    "_sync_elapsed",
    "_hour",
    "_hours_to_add"
];

if (!isServer) exitWith {};
// Marty: Defensive guard in case this script is executed while the mission parameter is disabled.
if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") != 1) exitWith {};

//--- r76b: duration/tick/weight nil or 0 => scalar divide-by-zero NaN rates (clock freezes / runaway).
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

// Marty: The day duration covers dawn + full daylight + dusk, with twilight slowed down for smoother visuals.
_day_weighted_hours = _day_hours_game + ((_dawn_hours_game + _dusk_hours_game) * _twilight_weight);
_day_hours_per_second = _day_weighted_hours / _day_duration_real_seconds;
_twilight_hours_per_second = _day_weighted_hours / (_day_duration_real_seconds * _twilight_weight);
_night_hours_per_second = _night_hours_game / _night_duration_real_seconds;

// Marty: Small server-side skipTime steps reduce visible shadow and star movement jumps.
_tick = missionNamespace getVariable ["WFBE_DAYNIGHT_CLIENT_TICK", 0.1];
_sync_interval = missionNamespace getVariable ["WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL", 30];
if (isNil "_tick" || {typeName _tick != "SCALAR"} || {_tick <= 0}) then {_tick = 0.1};
if (isNil "_sync_interval" || {typeName _sync_interval != "SCALAR"} || {_sync_interval <= 0}) then {_sync_interval = 30};
_sync_elapsed = _sync_interval;

while {(missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1} do {

    _hour = daytime;

    // Marty: Night is the wrap-around default; dawn/day/dusk override it when the current hour is inside their ranges.
    _hours_to_add = _night_hours_per_second * _tick;
    if (_hour >= _dawn_start && _hour < _dawn_end) then {_hours_to_add = _twilight_hours_per_second * _tick};
    if (_hour >= _dawn_end && _hour < _dusk_start) then {_hours_to_add = _day_hours_per_second * _tick};
    if (_hour >= _dusk_start && _hour < _dusk_end) then {_hours_to_add = _twilight_hours_per_second * _tick};

    // Marty: This skipTime runs only the server clock forward. Clients animate locally and only use server dates as drift references.
    skipTime _hours_to_add;

    _sync_elapsed = _sync_elapsed + _tick;
    if (_sync_elapsed >= _sync_interval) then {
        // Marty: Publish an absolute date for JIP and drift correction, without forcing clients to call setDate every tick.
        WFBE_DAYNIGHT_DATE = date;
        publicVariable "WFBE_DAYNIGHT_DATE";
        _sync_elapsed = 0;
    };

    sleep _tick;
};
