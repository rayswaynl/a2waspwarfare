/*
	WASP Vehicle Radio - does this side have >=1 alive Radio Tower?
	 Parameters:
		- Side.
	Reads the public alive-flag maintained by Server_Init/Construction_SmallSite/Server_BuildingKilled
	(WFBE_RADIOTOWER_WEST_ALIVE / WFBE_RADIOTOWER_EAST_ALIVE) - no per-frame nearObjects scan, no
	extra registry walk client-side. Feature-off (WFBE_C_STRUCTURES_RADIOTOWER == 0) always returns
	false, so the Radio actions/manager stay inert with the flag at its default. West/East only
	(matches the CBRadar / Radio Tower construction scope - no resistance-side structure).
*/

private ["_side"];
_side = _this;

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER", 0]) <= 0) exitWith {false};

switch (_side) do {
	case west: {missionNamespace getVariable ["WFBE_RADIOTOWER_WEST_ALIVE", false]};
	case east: {missionNamespace getVariable ["WFBE_RADIOTOWER_EAST_ALIVE", false]};
	default {false};
}
