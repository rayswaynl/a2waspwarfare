/*
	Return side's supply.
	 Parameters:
		- Side.
*/

private ["_supplyTeam"];

switch (_this) do {
	case west: {
		_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];

		if (isNil "_supplyTeam") then {
			REQUEST_SUPPLY_VALUE = player;
			publicVariableServer "REQUEST_SUPPLY_VALUE";

			waitUntil {!isNil {missionNamespace getVariable format ["wfbe_supply_%1", str _this];}};
			_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];
		};

		_supplyTeam
	};
	case east: {
		_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];

		if (isNil "_supplyTeam") then {
			REQUEST_SUPPLY_VALUE = player;
			publicVariableServer "REQUEST_SUPPLY_VALUE";

			waitUntil {!isNil {missionNamespace getVariable format ["wfbe_supply_%1", str _this];}};
			_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];
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