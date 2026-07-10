/*
	Author: Marty / revised clearer version

	Purpose:
	Write movement diagnostic information to the RPT log for all living AI units
	in the player's group.

	This script does not modify anything.
	It only logs information.

	It helps answer questions like:
	- Is the AI unit local?
	- Is its vehicle local?
	- Is the AI unit the driver?
	- Does the engine still know a destination for this unit?
	- Is the unit stopped?
	- Did the unit receive a movement command?
*/

Private [
	"_action_target",
	"_current_unit",
	"_current_waypoint",
	"_destination",
	"_destination_data",
	"_destination_mode",
	"_distance_to_destination",
	"_driver",
	"_group",
	"_is_movement_controller",
	"_is_valid_ai_unit",
	"_player",
	"_units_to_check",
	"_vehicle",
	"_waypoint_position"
];

_action_target = _this select 0;
_player = _this select 1;

if (isNull _player) exitWith {};
if (!alive _player) exitWith {};

if (leader (group _player) != _player) exitWith {
	"AI diagnostic is available only to the group leader." Call GroupChatMessage;
};


// ==================================================
// Helper: check if a unit is a living AI subordinate.
// ==================================================

_is_valid_ai_unit = {
	Private [
		"_player",
		"_unit"
	];

	_unit = _this select 0;
	_player = _this select 1;

	if (isNull _unit) exitWith {false};
	if (!alive _unit) exitWith {false};
	if (isPlayer _unit) exitWith {false};
	if (_unit == _player) exitWith {false};

	true
};


// ==================================================
// Collect living AI units from the player's group.
// ==================================================
// units (group _player) includes the player himself.
// We only keep living AI subordinates.

_units_to_check = [];

{
	_current_unit = _x;

	if ([_current_unit, _player] Call _is_valid_ai_unit) then {
		_units_to_check = _units_to_check + [_current_unit];
	};
} forEach units (group _player);

if (count _units_to_check == 0) exitWith {
	"No AI units to diagnose." Call GroupChatMessage;
};

["INFORMATION", Format [
	"AI Diagnose: Player [%1] group [%2] AI count [%3].",
	name _player,
	group _player,
	count _units_to_check
]] Call WFBE_CO_FNC_LogContent;


// ==================================================
// Diagnose each AI unit.
// ==================================================

{
	_current_unit = _x;

	if (!isNull _current_unit) then {
		if (alive _current_unit) then {

			_group = group _current_unit;
			_vehicle = vehicle _current_unit;
			_driver = driver _vehicle;

			// The movement controller is the unit that can actually move:
			// - an infantry unit on foot;
			// - the driver of a vehicle.
			_is_movement_controller = false;

			if (_vehicle == _current_unit) then {
				_is_movement_controller = true;
			};

			if (_driver == _current_unit) then {
				_is_movement_controller = true;
			};

			// expectedDestination tells what destination the engine currently
			// thinks this unit is trying to reach.
			_destination_data = expectedDestination _current_unit;
			_destination = [];
			_destination_mode = "unknown";

			if (count _destination_data > 0) then {
				_destination = _destination_data select 0;
			};

			if (count _destination_data > 1) then {
				_destination_mode = _destination_data select 1;
			};

			_distance_to_destination = -1;

			if (typeName _destination == "ARRAY") then {
				if (count _destination > 1) then {
					_distance_to_destination = round (_current_unit distance _destination);
				};
			};

			_current_waypoint = currentWaypoint _group;
			_waypoint_position = [];

			if (_current_waypoint < count (waypoints _group)) then {
				_waypoint_position = waypointPosition [_group, _current_waypoint];
			};


			// --------------------------------------------------
			// Identity and locality
			// --------------------------------------------------

			["INFORMATION", Format [
				"AI Diagnose: Unit [%1] type [%2] local_unit [%3] alive [%4] damage [%5] can_move_unit [%6] position [%7] velocity [%8] distance_to_player [%9].",
				_current_unit,
				typeOf _current_unit,
				local _current_unit,
				alive _current_unit,
				damage _current_unit,
				canMove _current_unit,
				getPosATL _current_unit,
				velocity _current_unit,
				round (_current_unit distance _player)
			]] Call WFBE_CO_FNC_LogContent;


			// --------------------------------------------------
			// Vehicle state
			// --------------------------------------------------

			["INFORMATION", Format [
				"AI Diagnose: Vehicle [%1] type [%2] in_vehicle [%3] local_vehicle [%4] can_move_vehicle [%5] fuel [%6] driver [%7] driver_alive [%8] is_movement_controller [%9].",
				_vehicle,
				typeOf _vehicle,
				_vehicle != _current_unit,
				local _vehicle,
				canMove _vehicle,
				fuel _vehicle,
				_driver,
				alive _driver,
				_is_movement_controller
			]] Call WFBE_CO_FNC_LogContent;


			// --------------------------------------------------
			// Movement state
			// --------------------------------------------------

			["INFORMATION", Format [
				"AI Diagnose: Movement state: current_command [%1] stopped [%2] unit_ready [%3].",
				currentCommand _current_unit,
				stopped _current_unit,
				unitReady _current_unit
			]] Call WFBE_CO_FNC_LogContent;


			// --------------------------------------------------
			// Destination state
			// --------------------------------------------------

			["INFORMATION", Format [
				"AI Diagnose: Destination: expected_destination [%1] destination_mode [%2] distance_to_destination [%3].",
				_destination,
				_destination_mode,
				_distance_to_destination
			]] Call WFBE_CO_FNC_LogContent;


			// --------------------------------------------------
			// Group state
			// --------------------------------------------------

			["INFORMATION", Format [
				"AI Diagnose: Group state: behaviour [%1] combat_mode [%2] speed_mode [%3] formation [%4] current_waypoint [%5] waypoint_position [%6].",
				behaviour _current_unit,
				combatMode _group,
				speedMode _group,
				formation _group,
				_current_waypoint,
				_waypoint_position
			]] Call WFBE_CO_FNC_LogContent;
		};
	};

} forEach _units_to_check;

(Format ["AI diagnostic written to RPT for %1 units.", count _units_to_check]) Call GroupChatMessage;
