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

_day_duration_real = missionNamespace getVariable "WFBE_DAY_DURATION";
_night_duration_real = missionNamespace getVariable "WFBE_NIGHT_DURATION";

_day_duration_real_seconds = _day_duration_real * 60;
_night_duration_real_seconds = _night_duration_real * 60;

// Marty: Phase boundaries are estimated for Chernarus on 28 June, the mission's effective date after the month override.
_dawn_start = missionNamespace getVariable "WFBE_DAYNIGHT_DAWN_START";
_dawn_end = missionNamespace getVariable "WFBE_DAYNIGHT_DAWN_END";
_dusk_start = missionNamespace getVariable "WFBE_DAYNIGHT_DUSK_START";
_dusk_end = missionNamespace getVariable "WFBE_DAYNIGHT_DUSK_END";
_twilight_weight = missionNamespace getVariable "WFBE_DAYNIGHT_TWILIGHT_WEIGHT";

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
_tick = missionNamespace getVariable "WFBE_DAYNIGHT_CLIENT_TICK";
_sync_interval = missionNamespace getVariable "WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL";
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
