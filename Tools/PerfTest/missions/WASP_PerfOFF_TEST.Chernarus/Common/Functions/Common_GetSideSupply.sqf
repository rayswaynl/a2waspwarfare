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

			//--- cmdcon44m: NON-BLOCKING like the resistance case below. The old sleep-poll threw
			//--- "Generic error" from every unscheduled caller (victory/upgrade FSMs, PVFs) whenever
			//--- the var was nil - A2 cannot suspend there. Return 0 now; the PV answer lands for the
			//--- next read (all callers poll on a cadence).
			_supplyTeam = 0;
		};

		_supplyTeam
	};
	case east: {
		_supplyTeam = missionNamespace getVariable format ["wfbe_supply_%1", str _this];

		if (isNil "_supplyTeam") then {
			REQUEST_SUPPLY_VALUE = player;
			publicVariableServer "REQUEST_SUPPLY_VALUE";

			//--- cmdcon44m: NON-BLOCKING like the resistance case below. The old sleep-poll threw
			//--- "Generic error" from every unscheduled caller (victory/upgrade FSMs, PVFs) whenever
			//--- the var was nil - A2 cannot suspend there. Return 0 now; the PV answer lands for the
			//--- next read (all callers poll on a cadence).
			_supplyTeam = 0;
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