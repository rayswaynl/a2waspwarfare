/*
	Return side's supply.
	 Parameters:
		- Side.
*/

private ["_supplyTeam", "_timeout"];

switch (_this) do {
	case west: {
		_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];

		if (isNil "_supplyTeam") then {
			REQUEST_SUPPLY_VALUE = player;
			publicVariableServer "REQUEST_SUPPLY_VALUE";

			//--- Bounded wait: a lost JIP packet must NOT hang this loop forever. Sleep-poll for up
			//--- to ~10s, then fall back to a sane 0 default so callers never block indefinitely.
			_timeout = 0;
			while {isNil "_supplyTeam" && _timeout < 100} do {
				sleep 0.1;
				_timeout = _timeout + 1;
				_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];
			};
			if (isNil "_supplyTeam") then {_supplyTeam = 0};
		};

		_supplyTeam
	};
	case east: {
		_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];

		if (isNil "_supplyTeam") then {
			REQUEST_SUPPLY_VALUE = player;
			publicVariableServer "REQUEST_SUPPLY_VALUE";

			//--- Bounded wait: a lost JIP packet must NOT hang this loop forever. Sleep-poll for up
			//--- to ~10s, then fall back to a sane 0 default so callers never block indefinitely.
			_timeout = 0;
			while {isNil "_supplyTeam" && _timeout < 100} do {
				sleep 0.1;
				_timeout = _timeout + 1;
				_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];
			};
			if (isNil "_supplyTeam") then {_supplyTeam = 0};
		};

		_supplyTeam
	};
	case resistance: {
		//--- GUER/resistance is funds-only (no supply economy); wfbe_supply_resistance is never published.
		//--- Non-blocking 0-default read so a GUER player NEVER hits the publicVariableServer+waitUntil path
		//--- (that errors "Suspending not allowed" from unscheduled client loops and hangs "Receiving mission").
		missionNamespace getVariable [format ["wfbe_supply_%1", str _this], 0]
	};
	default {objNull};
}