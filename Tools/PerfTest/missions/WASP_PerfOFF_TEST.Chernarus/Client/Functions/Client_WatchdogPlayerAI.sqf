/*
	Author: Marty

	Purpose:
	Watch player-owned AI units and automatically run the movement recovery
	when a unit appears stuck with a valid saved destination.

	The watchdog does not move units by itself.
	It only detects a likely blocked movement state, then calls
	Client_RecoverPlayerAI.sqf in automatic mode for the affected units.
*/

Private [
	"_can_watch_unit",
	"_check_interval",
	"_current_command",
	"_current_time",
	"_current_unit",
	"_destination",
	"_destination_can_be_used",
	"_destination_change_distance",
	"_destination_data",
	"_destination_mode",
	"_destination_x",
	"_destination_y",
	"_destination_z",
	"_distance_moved",
	"_distance_to_destination",
	"_driver",
	"_has_useful_destination",
	"_is_movement_controller",
	"_is_close_destination",
	"_last_check_time",
	"_last_destination",
	"_last_position",
	"_last_recovery_time",
	"_max_valid_destination_coordinate",
	"_max_valid_destination_z",
	"_min_close_destination_distance",
	"_min_destination_distance",
	"_min_movement_distance",
	"_movement_can_work",
	"_perfGroupUnits",
	"_perfRecovered",
	"_perfStart",
	"_perfWatched",
	"_player",
	"_player_vehicle",
	"_recovery_cooldown",
	"_required_close_stuck_time",
	"_required_stuck_time",
	"_should_recover_unit",
	"_stuck_units_to_recover",
	"_unit_ready",
	"_vehicle"
];

if (missionNamespace getVariable ["Player_AI_Watchdog_Running", false]) exitWith {};
missionNamespace setVariable ["Player_AI_Watchdog_Running", true];


// ==================================================
// Configuration
// ==================================================

_check_interval = 15;
_required_stuck_time = 45;
_required_close_stuck_time = 75;
_recovery_cooldown = 120;
_min_destination_distance = 50;

// Keep automatic recovery away from near-arrival micro-orders.
// Manual recovery still uses a 2m threshold in Client_RecoverPlayerAI.sqf.
_min_close_destination_distance = 50;

_min_movement_distance = 5;
_destination_change_distance = 25;

// Reject invalid engine sentinel destinations such as [0,0,1e+009].
_max_valid_destination_coordinate = 50000;
_max_valid_destination_z = 10000;


// ==================================================
// Helper: check if movement can physically work.
// ==================================================

_movement_can_work = {
	Private [
		"_unit",
		"_vehicle"
	];

	_unit = _this select 0;
	_vehicle = _this select 1;

	if (isNull _unit) exitWith {false};
	if (!alive _unit) exitWith {false};

	if (_vehicle == _unit) exitWith {
		canMove _unit
	};

	if (isNull _vehicle) exitWith {false};
	if (!alive _vehicle) exitWith {false};
	if (!canMove _vehicle) exitWith {false};

	true
};


// ==================================================
// Helper: check if an expectedDestination result is safe to use.
// ==================================================

_destination_can_be_used = {
	if (typeName _destination != "ARRAY") exitWith {false};
	if (count _destination < 2) exitWith {false};

	_destination_x = _destination select 0;
	_destination_y = _destination select 1;
	_destination_z = 0;

	if (count _destination > 2) then {
		_destination_z = _destination select 2;
	};

	if (typeName _destination_x != "SCALAR") exitWith {false};
	if (typeName _destination_y != "SCALAR") exitWith {false};
	if (typeName _destination_z != "SCALAR") exitWith {false};
	if (_destination_x == 0 && _destination_y == 0) exitWith {false};
	if (_destination_x < 0) exitWith {false};
	if (_destination_y < 0) exitWith {false};
	if (_destination_x > _max_valid_destination_coordinate) exitWith {false};
	if (_destination_y > _max_valid_destination_coordinate) exitWith {false};
	if (_destination_z > _max_valid_destination_z) exitWith {false};
	if (_destination_z < -100) exitWith {false};

	true
};


// ==================================================
// Main loop
// ==================================================

sleep 20;

while {true} do {
	sleep _check_interval;

	Call {
		// Marty: Performance Audit timing for the local player AI watchdog pass.
		_perfStart = diag_tickTime;
		_perfGroupUnits = 0;
		_perfWatched = 0;
		_perfRecovered = 0;
		_player = player;

		if (isNull _player) exitWith {};
		if (!alive _player) exitWith {};
		if (leader (group _player) != _player) exitWith {};

		_player_vehicle = vehicle _player;
		_current_time = time;
		_stuck_units_to_recover = [];

		_perfGroupUnits = count (units (group _player));

		{
			_current_unit = _x;

			// Decide if this unit should even be monitored.
			// The Call block keeps each refusal reason isolated and readable.
			_can_watch_unit = Call {
				if (isNull _current_unit) exitWith {false};
				if (!alive _current_unit) exitWith {false};
				if (isPlayer _current_unit) exitWith {false};
				if (_current_unit == _player) exitWith {false};

				_vehicle = vehicle _current_unit;

				// Do not auto-recover crew inside the player's current vehicle.
				// Recovery orders can conflict with the player's crew commands.
				if (_player_vehicle != _player && _vehicle == _player_vehicle) exitWith {false};

				_driver = driver _vehicle;
				_is_movement_controller = false;

				if (_vehicle == _current_unit) then {
					_is_movement_controller = true;
				};

				if (_driver == _current_unit) then {
					_is_movement_controller = true;
				};

				if (!_is_movement_controller) exitWith {false};
				if (!local _current_unit) exitWith {false};
				if (!local _vehicle) exitWith {false};
				if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {false};

				_current_command = currentCommand _current_unit;
				_unit_ready = unitReady _current_unit;

				// Automatic recovery must not override a deliberate player stop order.
				if (_current_command == "STOP") exitWith {false};

				true
			};

			if (_can_watch_unit) then {
				_perfWatched = _perfWatched + 1;
				_destination_data = expectedDestination _current_unit;
				_destination = [];
				_destination_mode = "DoNotPlan";

				if (count _destination_data > 0) then {
					_destination = _destination_data select 0;
				};

				if (count _destination_data > 1) then {
					_destination_mode = _destination_data select 1;
				};

				_has_useful_destination = false;
				_is_close_destination = false;
				_distance_to_destination = -1;

				if (Call _destination_can_be_used) then {
					_distance_to_destination = _current_unit distance _destination;

					if (_distance_to_destination > _min_destination_distance) then {
						_has_useful_destination = true;
					};

					if (!_has_useful_destination) then {
						if (_distance_to_destination > _min_close_destination_distance) then {
							_has_useful_destination = true;
							_is_close_destination = true;
						};
					};
				};

				_should_recover_unit = Call {
					if (!_has_useful_destination) exitWith {false};

					// Close destinations are risky because they can be formation or micro-position orders.
					// Only recover them if the engine still reports an unfinished MOVE command.
					if (_is_close_destination) then {
						if (_current_command != "MOVE") exitWith {false};
						if (_unit_ready) exitWith {false};
					};

					_last_position = _current_unit getVariable ["Player_AI_Watchdog_Last_Position", []];
					_last_check_time = _current_unit getVariable ["Player_AI_Watchdog_Last_Time", -1];
					_last_destination = _current_unit getVariable ["Player_AI_Watchdog_Last_Destination", []];
					_last_recovery_time = _current_unit getVariable ["Player_AI_Watchdog_Last_Recovery", -5000];

					if (count _last_position < 2) exitWith {
						_current_unit setVariable ["Player_AI_Watchdog_Last_Position", getPosATL _current_unit, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Time", _current_time, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Destination", _destination, false];

						false
					};

					if (count _last_destination < 2) exitWith {
						_current_unit setVariable ["Player_AI_Watchdog_Last_Position", getPosATL _current_unit, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Time", _current_time, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Destination", _destination, false];

						false
					};

					if (_destination distance _last_destination > _destination_change_distance) exitWith {
						_current_unit setVariable ["Player_AI_Watchdog_Last_Position", getPosATL _current_unit, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Time", _current_time, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Destination", _destination, false];

						false
					};

					_distance_moved = _current_unit distance _last_position;

					if (_distance_moved >= _min_movement_distance) exitWith {
						_current_unit setVariable ["Player_AI_Watchdog_Last_Position", getPosATL _current_unit, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Time", _current_time, false];
						_current_unit setVariable ["Player_AI_Watchdog_Last_Destination", _destination, false];

						false
					};

					if (_is_close_destination) then {
						if (_current_time - _last_check_time < _required_close_stuck_time) exitWith {false};
					};

					if (!_is_close_destination) then {
						if (_current_time - _last_check_time < _required_stuck_time) exitWith {false};
					};

					if (_current_time - _last_recovery_time < _recovery_cooldown) exitWith {false};

					true
				};

				if (_should_recover_unit) then {
					_current_unit setVariable ["Player_AI_Watchdog_Last_Recovery", _current_time, false];
					_current_unit setVariable ["Player_AI_Watchdog_Last_Position", getPosATL _current_unit, false];
					_current_unit setVariable ["Player_AI_Watchdog_Last_Time", _current_time, false];
					_current_unit setVariable ["Player_AI_Watchdog_Last_Destination", _destination, false];

					_stuck_units_to_recover = _stuck_units_to_recover + [_current_unit];

					["WARNING", Format [
						"AI Watchdog: Unit [%1] appears stuck. mode [%2], destination [%3], distance_to_destination [%4], close_destination [%5], command [%6], unit_ready [%7]. Automatic recovery will start.",
						_current_unit,
						_destination_mode,
						_destination,
						round _distance_to_destination,
						_is_close_destination,
						_current_command,
						_unit_ready
					]] Call WFBE_CO_FNC_LogContent;
				};
			};

		} forEach units (group _player);

		_perfRecovered = count _stuck_units_to_recover;
		if (count _stuck_units_to_recover > 0) then {
			[objNull, _player, -1, [_stuck_units_to_recover, true]] ExecVM "Client\Functions\Client_RecoverPlayerAI.sqf";
		};

		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["player_ai_watchdog", diag_tickTime - _perfStart, Format["groupUnits:%1;watched:%2;recovered:%3", _perfGroupUnits, _perfWatched, _perfRecovered], "CLIENT"] Call PerformanceAudit_Record;
			};
		};
	};
};
