/*
	Author: Marty / revised clearer version

	Purpose:
	Try to recover player-owned AI units that stopped moving.

	This script is focused on movement only.
	It does not try to fix target detection or firing behaviour.

	Main idea:
	When a player gives a movement order, the engine may still store a useful
	expected destination even when expectedDestination reports DoNotPlan.
	Therefore, this script evaluates destination usefulness by distance, not by
	destination mode.

	Recovery strategy:

	1. Collect living AI units in the player's group.
	2. Save each unit's current expected destination.
	3. Mark the destination as useful if it exists and is far enough away.
	4. Recover only units that control their movement and have a useful destination.
	5. Briefly reset movement-related AI state and FSM.
	6. Re-issue doMove to the saved destination.
	7. After 5 seconds, check whether the unit moved.
	8. If it did not move, try a stronger second phase with a shifted destination.

	Important:
	This script does not use player regrouping as a fallback.
	Manual recovery has a last-resort vehicle Phase 3 that temporarily uses
	doFollow player, then stops the unit and sends it back to its saved destination.
*/

Private [
	"_action_target",
	"_action_args",
	"_automatic_units",
	"_can_prepare_unit",
	"_can_restart_fsm",
	"_can_send_move_order",
	"_can_use_recovery",
	"_current_time",
	"_current_unit",
	"_destination",
	"_destination_data",
	"_destination_mode",
	"_destination_x",
	"_destination_y",
	"_destination_z",
	"_distance_to_saved_destination",
	"_driver",
	"_has_valid_destination",
	"_has_useful_destination",
	"_is_automatic_recovery",
	"_is_movement_controller",
	"_is_player_ai_unit",
	"_last_use_time",
	"_max_valid_destination_coordinate",
	"_max_valid_destination_z",
	"_min_destination_distance",
	"_movement_can_work",
	"_player",
	"_player_vehicle",
	"_saved_movement_data",
	"_show_success_message",
	"_source_units",
	"_start_position",
	"_units_to_recover",
	"_vehicle"
];

_action_target = _this select 0;
_player = _this select 1;
_action_args = [];

if (count _this > 3) then {
	_action_args = _this select 3;
};

_automatic_units = [];
_is_automatic_recovery = false;

if (count _action_args > 0) then {
	_automatic_units = _action_args select 0;
};

if (count _action_args > 1) then {
	_is_automatic_recovery = _action_args select 1;
};

_show_success_message = true;

if (isNull _player) exitWith {};
if (!alive _player) exitWith {};
_player_vehicle = vehicle _player;

if (leader (group _player) != _player) exitWith {
	"AI recovery is available only to the group leader." Call GroupChatMessage;
};


// ==================================================
// Configuration
// ==================================================
// A saved destination closer than this is considered already reached.
// Marty: keep this low so manual recovery can also help with short movement orders.

_min_destination_distance = 2;

// Automatic recovery must stay conservative to avoid refreshing tiny completed
// vehicle orders and causing repeated "ready" radio replies.
if (_is_automatic_recovery) then {
	_min_destination_distance = 50;
};

// Reject invalid engine sentinel destinations such as [0,0,1e+009].
_max_valid_destination_coordinate = 50000;
_max_valid_destination_z = 10000;


// ==================================================
// Helper: check if a movement order can physically work.
// ==================================================
// Infantry must be able to move.
// Vehicle drivers need a vehicle that can move.

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
// 1. Cooldown
// ==================================================
// Avoid repeated FSM resets through mouse wheel spam.

_can_use_recovery = true;

if (!_is_automatic_recovery) then {
	_current_time = time;
	_last_use_time = missionNamespace getVariable ["Player_AI_Recover_Last_Use", -5000];

	if (_current_time - _last_use_time < 10) then {
		"AI recovery is cooling down." Call GroupChatMessage;
		_can_use_recovery = false;
	};
};

if (!_can_use_recovery) exitWith {};

if (!_is_automatic_recovery) then {
	missionNamespace setVariable ["Player_AI_Recover_Last_Use", _current_time];
};


// ==================================================
// 2. Collect living AI units from the player's group.
// ==================================================
// units (group _player) includes the player himself.
// We only keep living AI subordinates.

_units_to_recover = [];
_source_units = units (group _player);

if (_is_automatic_recovery) then {
	_source_units = _automatic_units;
};

{
	_current_unit = _x;

	// Decide if this unit belongs to the player's AI squad.
	// The Call block keeps the refusal reasons easy to scan.
	_is_player_ai_unit = Call {
		if (isNull _current_unit) exitWith {false};
		if (!alive _current_unit) exitWith {false};
		if (isPlayer _current_unit) exitWith {false};
		if (_current_unit == _player) exitWith {false};
		if (_player_vehicle != _player && vehicle _current_unit == _player_vehicle) exitWith {false};

		true
	};

	if (_is_player_ai_unit) then {
		_units_to_recover = _units_to_recover + [_current_unit];
	};
} forEach _source_units;

if (count _units_to_recover == 0) exitWith {
	if (!_is_automatic_recovery) then {
		"No AI units to recover." Call GroupChatMessage;
	};
};

["INFORMATION", Format [
	"AI Recover: Player [%1] started movement recovery for [%2] AI units. automatic [%3].",
	name _player,
	count _units_to_recover,
	_is_automatic_recovery
]] Call WFBE_CO_FNC_LogContent;


// ==================================================
// 3. Save movement data before touching AI state.
// ==================================================
// DoNotPlan is not treated as invalid by itself.
// A destination is useful if it exists and is far enough from the unit.

_saved_movement_data = [];

{
	_current_unit = _x;
	_vehicle = vehicle _current_unit;
	_driver = driver _vehicle;

	_is_movement_controller = false;

	if (_vehicle == _current_unit) then {
		_is_movement_controller = true;
	};

	if (_driver == _current_unit) then {
		_is_movement_controller = true;
	};

	_destination_data = expectedDestination _current_unit;
	_destination = [];
	_destination_mode = "DoNotPlan";

	if (count _destination_data > 0) then {
		_destination = _destination_data select 0;
	};

	if (count _destination_data > 1) then {
		_destination_mode = _destination_data select 1;
	};

	_distance_to_saved_destination = -1;
	_has_valid_destination = false;
	_has_useful_destination = false;

	// Decide if the engine destination can be used safely.
	// Some broken AI states report [0,0,1e+009], which must be rejected.
	_has_valid_destination = Call {
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

	if (_has_valid_destination) then {
		_distance_to_saved_destination = _current_unit distance _destination;

		if (_distance_to_saved_destination > _min_destination_distance) then {
			_has_useful_destination = true;
		};
	};

	_start_position = getPosATL _current_unit;

	_saved_movement_data = _saved_movement_data + [[
		_current_unit,
		_vehicle,
		_driver,
		_is_movement_controller,
		_destination,
		_destination_mode,
		_has_useful_destination,
		_distance_to_saved_destination,
		_start_position
	]];

	["INFORMATION", Format [
		"AI Recover: Saved unit [%1] vehicle [%2] driver [%3] is_movement_controller [%4] local_unit [%5] local_vehicle [%6] destination [%7] mode [%8] distance_to_saved_destination [%9] has_valid_destination [%10] has_useful_destination [%11] start_position [%12].",
		_current_unit,
		_vehicle,
		_driver,
		_is_movement_controller,
		local _current_unit,
		local _vehicle,
		_destination,
		_destination_mode,
		round _distance_to_saved_destination,
		_has_valid_destination,
		_has_useful_destination,
		_start_position
	]] Call WFBE_CO_FNC_LogContent;

} forEach _units_to_recover;


// ==================================================
// 4. Phase 1:
// Reset only recoverable units.
// ==================================================
// Units already near their saved destination are ignored.
// Passengers are ignored because they cannot move the vehicle.

{
	_current_unit = _x select 0;
	_vehicle = _x select 1;
	_driver = _x select 2;
	_is_movement_controller = _x select 3;
	_destination = _x select 4;
	_destination_mode = _x select 5;
	_has_useful_destination = _x select 6;
	_distance_to_saved_destination = _x select 7;

	// Decide if this unit should receive the Phase 1 reset.
	// The Call block allows early exits without leaving the forEach loop.
	_can_prepare_unit = Call {
		if (isNull _current_unit) exitWith {false};
		if (!alive _current_unit) exitWith {false};

		if (!_is_movement_controller) exitWith {
			["INFORMATION", Format [
				"AI Recover: Unit [%1] skipped. It is not the movement controller of vehicle [%2]. Driver is [%3].",
				_current_unit,
				_vehicle,
				_driver
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		if (!_has_useful_destination) exitWith {
			["INFORMATION", Format [
				"AI Recover: Unit [%1] skipped. No useful saved destination. Unit is probably already near its destination or has no recoverable movement order.",
				_current_unit
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {
			["WARNING", Format [
				"AI Recover: Unit [%1] skipped. Movement cannot physically work. Vehicle [%2] canMove_unit [%3] canMove_vehicle [%4].",
				_current_unit,
				_vehicle,
				canMove _current_unit,
				canMove _vehicle
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		true
	};

	if (_can_prepare_unit) then {

		if !(local _current_unit) then {
			["WARNING", Format [
				"AI Recover: Unit [%1] is not local on this client. Recovery may be incomplete.",
				_current_unit
			]] Call WFBE_CO_FNC_LogContent;
		};

		if !(local _vehicle) then {
			["WARNING", Format [
				"AI Recover: Vehicle [%1] is not local on this client. Vehicle recovery may be incomplete.",
				_vehicle
			]] Call WFBE_CO_FNC_LogContent;
		};

		_current_unit enableAI "MOVE";
		_current_unit enableAI "ANIM";
		_current_unit enableAI "TARGET";
		_current_unit enableAI "AUTOTARGET";
		_current_unit setUnitPos "AUTO";
		_current_unit doWatch objNull;

		_current_unit disableAI "FSM";
	};

} forEach _saved_movement_data;

sleep 0.25;

{
	_current_unit = _x select 0;
	_vehicle = _x select 1;
	_is_movement_controller = _x select 3;
	_has_useful_destination = _x select 6;

	// Decide if this unit should receive the FSM restart.
	// The Call block allows early exits without leaving the forEach loop.
	_can_restart_fsm = Call {
		if (isNull _current_unit) exitWith {false};
		if (!alive _current_unit) exitWith {false};
		if (!_is_movement_controller) exitWith {false};
		if (!_has_useful_destination) exitWith {false};
		if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {false};

		true
	};

	if (_can_restart_fsm) then {
		_current_unit enableAI "FSM";
	};

} forEach _saved_movement_data;


// ==================================================
// 5. Phase 1 movement order:
// Re-issue doMove to the saved destination.
// ==================================================
// Only movement controllers with a useful saved destination receive doMove.
// No fallback is used for units without a useful saved destination.

{
	_current_unit = _x select 0;
	_vehicle = _x select 1;
	_driver = _x select 2;
	_is_movement_controller = _x select 3;
	_destination = _x select 4;
	_destination_mode = _x select 5;
	_has_useful_destination = _x select 6;
	_distance_to_saved_destination = _x select 7;

	// Decide if this unit should receive the Phase 1 doMove.
	// The Call block allows early exits without leaving the forEach loop.
	_can_send_move_order = Call {
		if (isNull _current_unit) exitWith {false};
		if (!alive _current_unit) exitWith {false};

		if (!_is_movement_controller) exitWith {
			["INFORMATION", Format [
				"AI Recover: Unit [%1] skipped. It is not the movement controller of vehicle [%2]. Driver is [%3].",
				_current_unit,
				_vehicle,
				_driver
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		if (!_has_useful_destination) exitWith {
			["INFORMATION", Format [
				"AI Recover: Unit [%1] skipped. No useful saved destination. Unit is probably already near its destination or has no recoverable movement order.",
				_current_unit
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {
			["WARNING", Format [
				"AI Recover: Unit [%1] skipped. Movement cannot physically work. Vehicle [%2] canMove_unit [%3] canMove_vehicle [%4].",
				_current_unit,
				_vehicle,
				canMove _current_unit,
				canMove _vehicle
			]] Call WFBE_CO_FNC_LogContent;

			false
		};

		true
	};

	if (_can_send_move_order) then {
		_current_unit doMove _destination;

		["INFORMATION", Format [
			"AI Recover: Phase 1 doMove sent to unit [%1], destination [%2], mode [%3], distance_to_saved_destination [%4].",
			_current_unit,
			_destination,
			_destination_mode,
			round _distance_to_saved_destination
		]] Call WFBE_CO_FNC_LogContent;
	};

} forEach _saved_movement_data;

if (!_is_automatic_recovery) then {
	(Format ["AI movement recovery checked %1 units.", count _saved_movement_data]) Call GroupChatMessage;
};


// ==================================================
// 6. Delayed check and Phase 2 recovery.
// ==================================================
// Phase 2 is only attempted for movement controllers with a useful destination
// that did not move after Phase 1.

[_saved_movement_data, _movement_can_work, _show_success_message, _player, _is_automatic_recovery] Spawn {

	Private [
		"_can_check_phase1",
		"_can_check_phase2_unit",
		"_can_check_phase3_unit",
		"_can_reset_phase2_unit",
		"_can_reset_phase3_unit",
		"_can_send_phase2_move",
		"_can_send_phase3_move",
		"_can_stop_phase2_unit",
		"_can_stop_phase3_unit",
		"_can_try_phase_3",
		"_current_unit",
		"_destination",
		"_destination_mode",
		"_distance_moved",
		"_distance_to_original_destination",
		"_distance_to_saved_destination",
		"_driver",
		"_has_useful_destination",
		"_is_automatic_recovery",
		"_is_movement_controller",
		"_movement_can_work",
		"_new_destination",
		"_phase2_data",
		"_phase3_data",
		"_player",
		"_player_vehicle",
		"_saved_movement_data",
		"_should_try_phase_2",
		"_show_success_message",
		"_start_position",
		"_success_message",
		"_vehicle",
		"_x_offset",
		"_y_offset",
		"_z"
	];

	_saved_movement_data = _this select 0;
	_movement_can_work = _this select 1;
	_show_success_message = _this select 2;
	_player = _this select 3;
	_is_automatic_recovery = _this select 4;
	_player_vehicle = vehicle _player;

	sleep 5;

	_phase2_data = [];
	_phase3_data = [];

	{
		_current_unit = _x select 0;
		_vehicle = _x select 1;
		_driver = _x select 2;
		_is_movement_controller = _x select 3;
		_destination = _x select 4;
		_destination_mode = _x select 5;
		_has_useful_destination = _x select 6;
		_distance_to_saved_destination = _x select 7;
		_start_position = _x select 8;

		// Decide if this unit should be checked after Phase 1.
		// The Call block allows early exits without leaving the forEach loop.
		_can_check_phase1 = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			if (!_has_useful_destination) exitWith {
				["INFORMATION", Format [
					"AI Recover: Phase 1 check skipped for unit [%1]. No useful destination was available.",
					_current_unit
				]] Call WFBE_CO_FNC_LogContent;

				false
			};

			true
		};

		// Handle this unit's Phase 1 result from top to bottom.
		// The Call block keeps the "done" cases close to their reason.
		Call {
			if (!_can_check_phase1) exitWith {true};

			_distance_moved = round (_current_unit distance _start_position);
			_distance_to_original_destination = round (_current_unit distance _destination);

			["INFORMATION", Format [
				"AI Recover: Phase 1 check for unit [%1]: moved [%2]m, destination [%3], mode [%4], distance_to_saved_destination [%5], distance_to_current_destination [%6], current_command [%7], stopped [%8], unit_ready [%9], local_unit [%10], local_vehicle [%11].",
				_current_unit,
				_distance_moved,
				_destination,
				_destination_mode,
				round _distance_to_saved_destination,
				_distance_to_original_destination,
				currentCommand _current_unit,
				stopped _current_unit,
				unitReady _current_unit,
				local _current_unit,
				local _vehicle
			]] Call WFBE_CO_FNC_LogContent;

			if (_distance_moved >= 2) exitWith {
				["INFORMATION", Format [
					"AI Recover: Unit [%1] appears recovered. It moved [%2]m after Phase 1.",
					_current_unit,
					_distance_moved
				]] Call WFBE_CO_FNC_LogContent;

				if (_show_success_message) then {
					_success_message = localize "STR_WF_INFO_AI_Recovered";

					if (_success_message == "") then {
						_success_message = "AI movement recovered: %1.";
					};

					systemChat Format [_success_message, _current_unit];
				};

				true
			};

			// Decide if this unit should receive Phase 2.
			// The Call block allows early exits without leaving the forEach loop.
			_should_try_phase_2 = Call {
				if (!_is_movement_controller) exitWith {false};
				if (!_has_useful_destination) exitWith {false};
				if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {false};

				true
			};

			if (!_should_try_phase_2) exitWith {
				["WARNING", Format [
					"AI Recover: Unit [%1] did not move, but Phase 2 was skipped. is_movement_controller [%2], has_useful_destination [%3].",
					_current_unit,
					_is_movement_controller,
					_has_useful_destination
				]] Call WFBE_CO_FNC_LogContent;

				true
			};

			_x_offset = (random 8) - 4;
			_y_offset = (random 8) - 4;
			_z = 0;

			if (count _destination > 2) then {
				_z = _destination select 2;
			};

			_new_destination = [
				(_destination select 0) + _x_offset,
				(_destination select 1) + _y_offset,
				_z
			];

			_phase2_data = _phase2_data + [[
				_current_unit,
				_vehicle,
				_destination,
				_start_position,
				_new_destination
			]];

			["WARNING", Format [
				"AI Recover: Unit [%1] did not move after Phase 1. Phase 2 starts now. Original destination [%2], shifted destination [%3].",
				_current_unit,
				_destination,
				_new_destination
			]] Call WFBE_CO_FNC_LogContent;

			true
		};

	} forEach _saved_movement_data;

	if (count _phase2_data == 0) exitWith {};

	// Phase 2 is applied to all eligible stuck units as one batch.
	// This avoids waiting several seconds per unit when the player has many AI.
	{
		_current_unit = _x select 0;

		// Decide if this unit can receive the Phase 2 stop command.
		// The Call block allows early exits without leaving the forEach loop.
		_can_stop_phase2_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_stop_phase2_unit) then {
			doStop _current_unit;
		};
	} forEach _phase2_data;

	sleep 0.1;

	{
		_current_unit = _x select 0;

		// Decide if this unit can receive the Phase 2 reset.
		// The Call block allows early exits without leaving the forEach loop.
		_can_reset_phase2_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_reset_phase2_unit) then {
			_current_unit enableAI "MOVE";
			_current_unit enableAI "ANIM";
			_current_unit setUnitPos "AUTO";
			_current_unit doWatch objNull;
			_current_unit disableAI "FSM";
		};
	} forEach _phase2_data;

	sleep 0.15;

	{
		_current_unit = _x select 0;
		_new_destination = _x select 4;

		// Decide if this unit can receive the Phase 2 move order.
		// The Call block allows early exits without leaving the forEach loop.
		_can_send_phase2_move = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_send_phase2_move) then {
			_current_unit enableAI "FSM";
			_current_unit doMove _new_destination;
		};
	} forEach _phase2_data;

	sleep 4;

	{
		_current_unit = _x select 0;
		_vehicle = _x select 1;
		_destination = _x select 2;
		_start_position = _x select 3;

		// Decide if this unit can be checked after Phase 2.
		// The Call block allows early exits without leaving the forEach loop.
		_can_check_phase2_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_check_phase2_unit) then {
			_distance_moved = round (_current_unit distance _start_position);
			_distance_to_original_destination = round (_current_unit distance _destination);

			["INFORMATION", Format [
				"AI Recover: Phase 2 check for unit [%1]: total_moved [%2]m, distance_to_original_destination [%3], current_command [%4], stopped [%5], unit_ready [%6].",
				_current_unit,
				_distance_moved,
				_distance_to_original_destination,
				currentCommand _current_unit,
				stopped _current_unit,
				unitReady _current_unit
			]] Call WFBE_CO_FNC_LogContent;

			if (_distance_moved >= 2) then {
				["INFORMATION", Format [
					"AI Recover: Unit [%1] appears recovered. It moved [%2]m after Phase 2.",
					_current_unit,
					_distance_moved
				]] Call WFBE_CO_FNC_LogContent;

				if (_show_success_message) then {
					_success_message = localize "STR_WF_INFO_AI_Recovered";

					if (_success_message == "") then {
						_success_message = "AI movement recovered: %1.";
					};

					systemChat Format [_success_message, _current_unit];
				};
			} else {
				_player_vehicle = vehicle _player;

				_can_try_phase_3 = Call {
					if (_is_automatic_recovery) exitWith {false};
					if (isNull _player) exitWith {false};
					if (!alive _player) exitWith {false};
					if (isNull _current_unit) exitWith {false};
					if (!alive _current_unit) exitWith {false};
					if (isNull _vehicle) exitWith {false};
					if (_vehicle == _current_unit) exitWith {false};
					if (_player_vehicle != _player && _vehicle == _player_vehicle) exitWith {false};
					if (!local _current_unit) exitWith {false};
					if (!local _vehicle) exitWith {false};
					if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {false};

					true
				};

				if (_can_try_phase_3) then {
					_phase3_data = _phase3_data + [[
						_current_unit,
						_vehicle,
						_destination,
						_start_position
					]];

					["WARNING", Format [
						"AI Recover: Unit [%1] still did not move after Phase 2. Manual vehicle Phase 3 will try a temporary silent doFollow reset before returning to destination [%2].",
						_current_unit,
						_destination
					]] Call WFBE_CO_FNC_LogContent;
				};

				["WARNING", Format [
					"AI Recover: Unit [%1] still did not move after Phase 2. Possible causes: non-local unit or vehicle, invalid path, engine pathfinding failure, blocked vehicle simulation, or corrupted AI state.",
					_current_unit
				]] Call WFBE_CO_FNC_LogContent;
			};
		};
	} forEach _phase2_data;

	if (count _phase3_data == 0) exitWith {};

	// Phase 3 is deliberately manual-only and vehicle-only.
	// It uses doFollow silently to reset formation state, then restores the saved destination.
	{
		_current_unit = _x select 0;
		_vehicle = _x select 1;

		_can_reset_phase3_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};
			if (isNull _player) exitWith {false};
			if (!alive _player) exitWith {false};
			if (isNull _vehicle) exitWith {false};
			if ((vehicle _player) != _player && _vehicle == (vehicle _player)) exitWith {false};
			if (!local _current_unit) exitWith {false};
			if (!local _vehicle) exitWith {false};

			true
		};

		if (_can_reset_phase3_unit) then {
			_current_unit enableAI "MOVE";
			_current_unit enableAI "ANIM";
			_current_unit enableAI "FSM";
			_current_unit setUnitPos "AUTO";
			_current_unit doWatch objNull;
			_current_unit doFollow _player;

			["WARNING", Format [
				"AI Recover: Phase 3 doFollow reset sent to unit [%1], vehicle [%2].",
				_current_unit,
				_vehicle
			]] Call WFBE_CO_FNC_LogContent;
		};
	} forEach _phase3_data;

	sleep 5;

	{
		_current_unit = _x select 0;

		_can_stop_phase3_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_stop_phase3_unit) then {
			doStop _current_unit;
		};
	} forEach _phase3_data;

	sleep 0.2;

	{
		_current_unit = _x select 0;
		_vehicle = _x select 1;
		_destination = _x select 2;

		_can_send_phase3_move = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};
			if (isNull _vehicle) exitWith {false};
			if (!(isNull _player) && alive _player && (vehicle _player) != _player && _vehicle == (vehicle _player)) exitWith {false};
			if (!([_current_unit, _vehicle] Call _movement_can_work)) exitWith {false};

			true
		};

		if (_can_send_phase3_move) then {
			_current_unit enableAI "MOVE";
			_current_unit enableAI "ANIM";
			_current_unit enableAI "FSM";
			_current_unit setUnitPos "AUTO";
			_current_unit doWatch objNull;
			_current_unit doMove _destination;

			["WARNING", Format [
				"AI Recover: Phase 3 doMove sent to unit [%1], vehicle [%2], restored destination [%3].",
				_current_unit,
				_vehicle,
				_destination
			]] Call WFBE_CO_FNC_LogContent;
		};
	} forEach _phase3_data;

	sleep 5;

	{
		_current_unit = _x select 0;
		_vehicle = _x select 1;
		_destination = _x select 2;
		_start_position = _x select 3;

		_can_check_phase3_unit = Call {
			if (isNull _current_unit) exitWith {false};
			if (!alive _current_unit) exitWith {false};

			true
		};

		if (_can_check_phase3_unit) then {
			_distance_moved = round (_current_unit distance _start_position);
			_distance_to_original_destination = round (_current_unit distance _destination);

			["INFORMATION", Format [
				"AI Recover: Phase 3 check for unit [%1]: total_moved [%2]m, distance_to_original_destination [%3], current_command [%4], stopped [%5], unit_ready [%6].",
				_current_unit,
				_distance_moved,
				_distance_to_original_destination,
				currentCommand _current_unit,
				stopped _current_unit,
				unitReady _current_unit
			]] Call WFBE_CO_FNC_LogContent;

			if (_distance_moved >= 2) then {
				["INFORMATION", Format [
					"AI Recover: Unit [%1] appears recovered. It moved [%2]m after Phase 3.",
					_current_unit,
					_distance_moved
				]] Call WFBE_CO_FNC_LogContent;

				if (_show_success_message) then {
					_success_message = localize "STR_WF_INFO_AI_Recovered";

					if (_success_message == "") then {
						_success_message = "AI movement recovered: %1.";
					};

					systemChat Format [_success_message, _current_unit];
				};
			} else {
				["WARNING", Format [
					"AI Recover: Unit [%1] still did not move after Phase 3. Vehicle [%2] may be physically blocked or the vehicle AI state may be corrupted.",
					_current_unit,
					_vehicle
				]] Call WFBE_CO_FNC_LogContent;
			};
		};
	} forEach _phase3_data;
};
