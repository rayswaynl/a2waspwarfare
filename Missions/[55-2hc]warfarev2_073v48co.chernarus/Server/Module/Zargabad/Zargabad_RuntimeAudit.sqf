if (!isServer || !IS_zargabad_lowpop_map) exitWith {};

waitUntil {townInitServer};

Private ["_airports", "_campCount", "_cfg", "_centralWallGaps", "_defenseCount", "_eastAircraft", "_eastAirport", "_eastHeavy", "_eastLight", "_eastBasePos", "_forbiddenNormal", "_forbiddenPresent", "_maxSV", "_priceSamples", "_startSV", "_townNames", "_westAircraft", "_westAirport", "_westBasePos", "_westHeavy", "_westLight"];

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

_westBasePos = missionNamespace getVariable ["WFBE_ZARGABAD_BASE_POS_WEST", [0,0,0]];
_eastBasePos = missionNamespace getVariable ["WFBE_ZARGABAD_BASE_POS_EAST", [0,0,0]];
_centralWallGaps = missionNamespace getVariable ["WFBE_ZARGABAD_CENTRAL_WALL_GAPS", []];

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: bases WEST %1 EAST %2 distance [%3] westStatic [%4] eastStatic [%5] baseWalls [%6] centralWallPieces [%7] centralWallOrigin [3425,3375] centralWallDir [316] centralWallGaps %8.",
	_westBasePos,
	_eastBasePos,
	round (_westBasePos distance _eastBasePos),
	missionNamespace getVariable ["WFBE_ZARGABAD_BASE_STATIC_COUNT_WEST", -1],
	missionNamespace getVariable ["WFBE_ZARGABAD_BASE_STATIC_COUNT_EAST", -1],
	missionNamespace getVariable ["WFBE_ZARGABAD_BASE_WALL_COUNT", -1],
	count (missionNamespace getVariable ["WFBE_ZARGABAD_CENTRAL_WALL", []]),
	_centralWallGaps
]] Call WFBE_CO_FNC_LogContent;

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: baseStaticTemplates WEST %1 EAST %2.",
	missionNamespace getVariable ["WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_WEST", []],
	missionNamespace getVariable ["WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_EAST", []]
]] Call WFBE_CO_FNC_LogContent;

_westLight = missionNamespace getVariable ["WFBE_WESTLIGHTUNITS", []];
_westHeavy = missionNamespace getVariable ["WFBE_WESTHEAVYUNITS", []];
_westAircraft = missionNamespace getVariable ["WFBE_WESTAIRCRAFTUNITS", []];
_westAirport = missionNamespace getVariable ["WFBE_WESTAIRPORTUNITS", []];
_eastLight = missionNamespace getVariable ["WFBE_EASTLIGHTUNITS", []];
_eastHeavy = missionNamespace getVariable ["WFBE_EASTHEAVYUNITS", []];
_eastAircraft = missionNamespace getVariable ["WFBE_EASTAIRCRAFTUNITS", []];
_eastAirport = missionNamespace getVariable ["WFBE_EASTAIRPORTUNITS", []];
_forbiddenNormal = ["M1A1","M1A1_US_DES_EP1","MLRS","MLRS_DES_EP1","M1A2_TUSK_MG","M1A2_US_TUSK_MG_EP1","M6_EP1","ZSU_INS","ZSU_TK_EP1","T55_TK_EP1","T72_RU","T72_TK_EP1","T90","2S6M_Tunguska","AW159_Lynx_BAF","Mi24_D_CZ_ACR","Mi24_D_TK_EP1","Mi24_P","Mi24_V","Ka52","Ka52Black","AH64D","AH64D_EP1","BAF_Apache_AH1_D","AH1Z","L39_TK_EP1","Su25_Ins","Su25_TK_EP1","Su39","Su34","A10","A10_US_EP1","AV8B","AV8B2","F35B","C130J_US_EP1"];
_forbiddenPresent = [];
{if ((_x in _westHeavy) || (_x in _westAircraft) || (_x in _eastHeavy) || (_x in _eastAircraft)) then {_forbiddenPresent = _forbiddenPresent + [_x]}} forEach _forbiddenNormal;

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: factoryCounts WEST L/H/A/AP [%1,%2,%3,%4] EAST L/H/A/AP [%5,%6,%7,%8] forbiddenNormal %9.",
	count _westLight, count _westHeavy, count _westAircraft, count _westAirport,
	count _eastLight, count _eastHeavy, count _eastAircraft, count _eastAirport,
	_forbiddenPresent
]] Call WFBE_CO_FNC_LogContent;

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: factoryLists WEST H %1 A %2 EAST H %3 A %4.",
	_westHeavy, _westAircraft, _eastHeavy, _eastAircraft
]] Call WFBE_CO_FNC_LogContent;

_priceSamples = [];
{
	_cfg = missionNamespace getVariable _x;
	_priceSamples = _priceSamples + [[_x, if (isNil "_cfg") then {-1} else {_cfg select QUERYUNITPRICE}]];
} forEach ["US_Soldier_EP1","M1126_ICV_M2_EP1","M2A2_EP1","MH6J_EP1","C130J_US_EP1"];

["INFORMATION", Format [
	"Zargabad_RuntimeAudit.sqf: priceMultipliers %1 priceSamples %2.",
	missionNamespace getVariable ["WFBE_ZARGABAD_PRICE_MULTIPLIERS", []],
	_priceSamples
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
