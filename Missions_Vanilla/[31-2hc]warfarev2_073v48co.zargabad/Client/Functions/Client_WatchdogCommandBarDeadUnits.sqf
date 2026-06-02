/*
	Author: Marty

	Purpose:
	Keep the local command bar in sync when one of the player's AI subordinates
	dies outside the leader's knowledge.

	The script updates local knowledge, detaches destroyed assigned vehicles,
	and silently removes dead AI from the player's group. It does not delete bodies
	or change the server-side cleanup flow.
*/

Private [
	"_checkInterval",
	"_cleanupRequestTime",
	"_cleanupRequestCount",
	"_currentUnits",
	"_deadUnits",
	"_detachedLogged",
	"_detectedLogged",
	"_group",
	"_knownUnits",
	"_lastVehicle",
	"_player",
	"_shouldReveal",
	"_unit",
	"_unitGroup",
	"_vehicle"
];

if (missionNamespace getVariable ["CommandBar_DeadUnits_Watchdog_Running", false]) exitWith {};
missionNamespace setVariable ["CommandBar_DeadUnits_Watchdog_Running", true];

_checkInterval = 1;
_knownUnits = [];

sleep 5;

while {!gameOver} do {
	sleep _checkInterval;

	Call {
		_player = player;

		if (isNull _player) exitWith {};
		if (!alive _player) exitWith {};

		_group = group _player;

		if (isNull _group) exitWith {};
		if (leader _group != _player) exitWith {};

		// Marty: Remember current AI subordinates so a dead unit can still be handled after a manual disband.
		_currentUnits = units _group;
		_knownUnits = _knownUnits - [objNull];
		_deadUnits = [];

		{
			_unit = _x;

			if (!isPlayer _unit && _unit != _player) then {
				if !(_unit in _knownUnits) then {_knownUnits = _knownUnits + [_unit]};

				_vehicle = assignedVehicle _unit;
				if (isNull _vehicle) then {_vehicle = vehicle _unit};

				if (!isNull _vehicle && _vehicle != _unit) then {
					_unit setVariable ["CommandBar_DeadUnits_LastVehicle", _vehicle, false];

					if (!alive _vehicle) then {
						_group reveal _vehicle;
						_player reveal _vehicle;
						_group leaveVehicle _vehicle;
					};
				};
			};
		} forEach _currentUnits;

		{
			_unit = _x;

			_shouldReveal = Call {
				if (isNull _unit) exitWith {false};
				if (alive _unit) exitWith {false};
				if (_unit == _player) exitWith {false};
				if (isPlayer _unit) exitWith {false};
				if (_unit in playableUnits) exitWith {false};

				true
			};

			if (_shouldReveal) then {_deadUnits = _deadUnits + [_unit]};
		} forEach _knownUnits;

		// Marty: Force the local command bar to forget dead subordinates without deleting their bodies.
		{
			_unit = _x;
			_detectedLogged = _unit getVariable ["CommandBar_DeadUnits_ClientDetectedLogged", false];
			if !(_detectedLogged) then {
				_unit setVariable ["CommandBar_DeadUnits_ClientDetectedLogged", true, false];
				["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_DETECTED player:%1 side:%2 unit:%3 type:%4 unitGroup:%5 playerGroup:%6 localUnit:%7 currentUnits:%8 knownUnits:%9", name _player, side _player, _unit, typeOf _unit, group _unit, _group, local _unit, count _currentUnits, count _knownUnits]] Call WFBE_CO_FNC_LogContent;
			};

			_group reveal _unit;
			_player reveal _unit;

			_vehicle = assignedVehicle _unit;
			_lastVehicle = _unit getVariable ["CommandBar_DeadUnits_LastVehicle", objNull];
			if (isNull _vehicle) then {_vehicle = _lastVehicle};
			if (isNull _vehicle) then {_vehicle = vehicle _unit};

			if (!isNull _vehicle && _vehicle != _unit) then {
				_group leaveVehicle _vehicle;
				_group reveal _vehicle;
				_player reveal _vehicle;
			};

			_unitGroup = group _unit;
			if (_unitGroup != _group) then {
				_detachedLogged = _unit getVariable ["CommandBar_DeadUnits_ClientDetachedLogged", false];
				if !(_detachedLogged) then {
					_unit setVariable ["CommandBar_DeadUnits_ClientDetachedLogged", true, false];
					["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_DETACHED_OBSERVED player:%1 unit:%2 unitGroup:%3 playerGroup:%4 localUnit:%5", name _player, _unit, _unitGroup, _group, local _unit]] Call WFBE_CO_FNC_LogContent;
				};
			};

			if (_unitGroup == _group) then {
				_cleanupRequestTime = _unit getVariable ["CommandBar_DeadUnits_ServerCleanupRequestTime", -1000];
				if ((time - _cleanupRequestTime) > 10) then {
					// Marty: Ask the server periodically to make group removal authoritative when locality blocks local cleanup.
					_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRequestTime", time, false];
					_cleanupRequestCount = _unit getVariable ["CommandBar_DeadUnits_ServerCleanupRequestCount", 0];
					_cleanupRequestCount = _cleanupRequestCount + 1;
					_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRequestCount", _cleanupRequestCount, false];

					if (WF_Debug) then {
						["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_REQUEST_SERVER_CLEANUP player:%1 unit:%2 requestCount:%3 unitGroup:%4 localUnit:%5 vehicle:%6 vehicleAlive:%7 vehicleLocal:%8", name _player, _unit, _cleanupRequestCount, _unitGroup, local _unit, _vehicle, alive _vehicle, local _vehicle]] Call WFBE_CO_FNC_LogContent;
					};
					if (_cleanupRequestCount == 3) then {
						["WARNING", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_STILL_STUCK player:%1 unit:%2 requestCount:%3 unitGroup:%4 localUnit:%5", name _player, _unit, _cleanupRequestCount, _unitGroup, local _unit]] Call WFBE_CO_FNC_LogContent;
					};

					["RequestSpecial", ["commandbar-cleanup-dead-unit", _player, _unit]] Call WFBE_CO_FNC_SendToServer;
				};

				// Marty: Keep this cleanup silent; production MP can leak or loop custom radio speech across clients.
				player groupSelectUnit [_unit, false];
				[_unit] joinSilent grpNull;
			};

			_knownUnits = _knownUnits - [_unit];
		} forEach _deadUnits;
	};
};
