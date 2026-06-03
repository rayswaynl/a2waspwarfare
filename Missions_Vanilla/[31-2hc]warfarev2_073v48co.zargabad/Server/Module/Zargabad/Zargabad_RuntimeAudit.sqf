if (!isServer || !IS_zargabad_lowpop_map) exitWith {};

waitUntil {townInitServer};

Private ["_airports", "_campCount", "_defenseCount", "_maxSV", "_startSV", "_townNames"];

_campCount = 0;
_defenseCount = 0;
_startSV = 0;
_maxSV = 0;
_townNames = [];
{
	_campCount = _campCount + count (_x getVariable ["camps", []]);
	_defenseCount = _defenseCount + count (_x getVariable ["wfbe_town_defenses", []]);
	_startSV = _startSV + (_x getVariable ["startingSupplyValue", 0]);
	_maxSV = _maxSV + (_x getVariable ["maxSupplyValue", 0]);
	_townNames = _townNames + [_x getVariable ["name", "Unknown"]];
} forEach towns;

_airports = [0,0,0] nearEntities [["LocationLogicAirport"], 100000];

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: towns [%1] camps [%2] airports [%3] defenses [%4] startSV [%5] maxSV [%6] townsList [%7].",
	count towns,
	_campCount,
	count _airports,
	_defenseCount,
	_startSV,
	_maxSV,
	_townNames
]] Call WFBE_CO_FNC_LogContent;

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: economy supplyCap [%1] teamSupplyCap [%2] fastTravelMax [%3] respawnCampRange [%4] respawnRanges [%5] supportRange [%6] artilleryIntervals [%7] baseDefenseAI [%8] baseDefenseRange [%9] edgeGuard [%10,%11,%12].",
	missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", -1],
	missionNamespace getVariable ["WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT", -1],
	missionNamespace getVariable ["WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX", -1],
	missionNamespace getVariable ["WFBE_C_RESPAWN_CAMPS_RANGE", -1],
	WFBE_C_RESPAWN_RANGES,
	missionNamespace getVariable ["WFBE_C_UNITS_SUPPORT_RANGE", -1],
	WFBE_C_ARTILLERY_INTERVALS,
	missionNamespace getVariable ["WFBE_C_BASE_DEFENSE_MAX_AI", -1],
	missionNamespace getVariable ["WFBE_C_BASE_DEFENSE_MANNING_RANGE", -1],
	missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_BAND", -1],
	missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_SAFE_RANGE", -1],
	missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_TIMEOUT", -1]
]] Call WFBE_CO_FNC_LogContent;
