if (!isServer || time > 30) exitWith {diag_log Format["[WFBE (WARNING)][frameno:%1 | ticktime:%2] Init_Server: The server initialization cannot be called more than once.",diag_frameno,diag_tickTime]};

["INITIALIZATION", Format ["Init_Server.sqf: Server initialization begins at [%1]", time]] Call WFBE_CO_FNC_LogContent;

//--- Allow resistance group to be spawned without a placeholder.
createCenter resistance;
resistance setFriend [west,0];
resistance setFriend [east,0];
//--- GUER harass: setFriend is one-directional, so WEST/EAST must ALSO treat resistance as hostile or their AI
//--- won't return fire on GUER players. Gated on the GUER param so the base WEST-vs-EAST mission is unchanged when OFF.
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) then {
	west setFriend [resistance, 0];
	east setFriend [resistance, 0];
};

AIBuyUnit = Compile preprocessFile "Server\Functions\Server_BuyUnit.sqf";
if (WF_A2_Vanilla) then {AISquadRespawn = Compile preprocessFile "Server\AI\AI_SquadRespawn.sqf"};
if !(WF_A2_Vanilla) then {AIAdvancedRespawn = Compile preprocessFile "Server\AI\AI_AdvancedRespawn.sqf"};
AIMoveTo = Compile preprocessFile "Server\AI\Orders\AI_MoveTo.sqf";
AIPatrol = Compile preprocessFile "Server\AI\Orders\AI_Patrol.sqf";
//--- NOT WIRED - AITownPatrol is never called anywhere; town patrols run via Server_GetTownPatrol. Compile shelved.
//AITownPatrol = Compile preprocessFile "Server\AI\Orders\AI_TownPatrol.sqf";
AITownResitance = Compile preprocessFile "Server\AI\AI_Resistance.sqf";
AIWPAdd = Compile preprocessFile "Server\AI\Orders\AI_WPAdd.sqf";
AIWPRemove = Compile preprocessFile "Server\AI\Orders\AI_WPRemove.sqf";
BuildingDamaged = Compile preprocessFile "Server\Functions\Server_BuildingDamaged.sqf";
BuildingHandleDamages = Compile preprocessFile "Server\Functions\Server_BuildingHandleDamages.sqf";
BuildingKilled = Compile preprocessFile "Server\Functions\Server_BuildingKilled.sqf";
CanUpdateTeam = Compile preprocessFile "Server\Functions\Server_CanUpdateTeam.sqf";
ChangeAICommanderFunds = Compile preprocessFile "Server\Functions\Server_ChangeAICommanderFunds.sqf";
ConstructDefense = Compile preprocessFile "Server\Construction\Construction_StationaryDefense.sqf";
CreateDefenseTemplate = Compile preprocessFile "Server\Functions\Server_CreateDefenseTemplate.sqf";
Server_ConstructPosition = Compile preprocessFile "Server\Functions\Server_ConstructPosition.sqf";
HandleBuildingRepair = Compile preprocessFile "Server\Functions\Server_HandleBuildingRepair.sqf";
GetAICommanderFunds = Compile preprocessFile "Server\Functions\Server_GetAICommanderFunds.sqf";
HandleBuildingDamage = Compile preprocessFile "Server\Functions\Server_HandleBuildingDamage.sqf";
HandleDefense = Compile preprocessFile "Server\Functions\Server_HandleDefense.sqf";
HandleSpecial = Compile preprocessFile "Server\Functions\Server_HandleSpecial.sqf";
MHQRepair = Compile preprocessFile "Server\Functions\Server_MHQRepair.sqf";
SideMessage = Compile preprocessFile "Server\Functions\Server_SideMessage.sqf";
SetTownPatrols = compile preprocessfilelinenumbers "Server\FSM\server_patrols.sqf";

UpdateTeam = Compile preprocessFile "Server\Functions\Server_UpdateTeam.sqf";
/* UpdateSupplyTruck = Compile preprocessFile "Server\AI\AI_UpdateSupplyTruck.sqf"; */

//--- Support Functions.
KAT_ParaAmmo = Compile preprocessFile "Server\Support\Support_ParaAmmo.sqf";
KAT_Paratroopers = Compile preprocessFile "Server\Support\Support_Paratroopers.sqf";
KAT_ParaVehicles = Compile preprocessFile "Server\Support\Support_ParaVehicles.sqf";
KAT_UAV = Compile preprocessFile "Server\Support\Support_UAV.sqf";

//--- New Fnc.
WFBE_SE_FNC_AI_SetTownAttackPath = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath.sqf";
WFBE_SE_FNC_AI_SetTownAttackPath_PathIsSafe = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath_PathIsSafe.sqf";
WFBE_SE_FNC_AI_SetTownAttackPath_PosIsSafe = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath_PosIsSafe.sqf";
WFBE_SE_FNC_AI_Com_Upgrade = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_Com_Upgrade.sqf";
//--- feat/ai-commander: revival workers + supervisor.
WFBE_SE_FNC_AI_Com_AssignTypes = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_AssignTypes.sqf";
WFBE_SE_FNC_AI_Com_AssignTowns = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_AssignTowns.sqf";
WFBE_SE_FNC_AI_Com_Produce = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Produce.sqf";
WFBE_SE_FNC_AI_Com_Execute = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Execute.sqf";
WFBE_SE_FNC_AI_Com_Base = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Base.sqf";
WFBE_SE_FNC_AI_Com_Teams = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Teams.sqf";
WFBE_SE_FNC_AI_Com_Strategy = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Strategy.sqf";
WFBE_SE_FNC_AI_Commander = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander.sqf";
WFBE_SE_FNC_AI_Commander_Wildcard = Compile preprocessFileLineNumbers "Server\Functions\AI_Commander_Wildcard.sqf";
WFBE_SE_FNC_GetTownGroups = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownGroups.sqf";
WFBE_SE_FNC_GetTownGroupsDefender = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownGroupsDefender.sqf";
WFBE_SE_FNC_GetTownPatrol = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownPatrol.sqf";
WFBE_SE_FNC_HandleEmptyVehicle = Compile preprocessFileLineNumbers "Server\Functions\Server_HandleEmptyVehicle.sqf";
WFBE_SE_FNC_HandlePVF = Compile preprocessFileLineNumbers "Server\Functions\Server_HandlePVF.sqf";
WFBE_SE_FNC_ManageTownDefenses = Compile preprocessFileLineNumbers "Server\Functions\Server_ManageTownDefenses.sqf";
WFBE_SE_FNC_OnHQKilled = Compile preprocessFileLineNumbers "Server\Functions\Server_OnHQKilled.sqf";
WFBE_SE_FNC_OperateTownDefensesUnits = Compile preprocessFileLineNumbers "Server\Functions\Server_OperateTownDefensesUnits.sqf";
WFBE_SE_FNC_ProcessUpgrade = Compile preprocessFileLineNumbers "Server\Functions\Server_ProcessUpgrade.sqf";
WFBE_SE_FNC_SetCampsToSide = Compile preprocessFileLineNumbers "Server\Functions\Server_SetCampsToSide.sqf";
WFBE_SE_FNC_SetLocalityOwner = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Server\Functions\Server_SetLocalityOwner.sqf"} else {{}};
WFBE_SE_FNC_SpawnTownDefense = Compile preprocessFileLineNumbers "Server\Functions\Server_SpawnTownDefense.sqf";
WFBE_SE_FNC_VoteForCommander = Compile preprocessFileLineNumbers "Server\Functions\Server_VoteForCommander.sqf";
WFBE_SE_FNC_AssignForCommander = Compile preprocessFileLineNumbers "Server\Functions\Server_AssignNewCommander.sqf";
WFBE_CO_FNC_InitAFKkickHandler = Compile preprocessFileLineNumbers "Server\Module\afkKick\initAFKkickHandler.sqf";
WFBE_CO_FNC_LogGameEnd = Compile preprocessFileLineNumbers "Server\Functions\Server_LogGameEnd.sqf";
// WFBE_CO_FNC_monitorServerFPS = Compile preprocessFileLineNumbers "Server\Module\serverFPS\monitorServerFPS.sqf";
WFBE_SE_FNC_SupplyMissionCompleted = Call Compile preprocessFileLineNumbers "Server\Module\supplyMission\supplyMissionCompleted.sqf";
WFBE_SE_FNC_IsSupplyMissionActiveInTown = Call Compile preprocessFileLineNumbers "Server\Module\supplyMission\isSupplyMissionActiveInTown.sqf";
WFBE_SE_FNC_SupplyMissionStarted = Call Compile preprocessFileLineNumbers "Server\Module\supplyMission\supplyMissionStarted.sqf";
WFBE_SE_FNC_PlayerObjectsList = Call Compile preprocessFileLineNumbers "Server\Module\supplyMission\playerObjectsList.sqf";
WFBE_SE_FNC_SupplyMissionTimerForTown = Compile preprocessFileLineNumbers "Server\Module\supplyMission\supplyMissionTimerForTown.sqf";
WFBE_SE_FNC_CallDatabaseRetrieve = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseRetrieve.sqf";
WFBE_SE_FNC_CallDatabaseStore = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseStore.sqf";
WFBE_SE_FNC_CallDatabaseStoreSide = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseStoreSide.sqf";
WFBE_SE_FNC_GetTeamScore = Compile preprocessFileLineNumbers "Server\Module\AntiStack\getTeamScore.sqf";
WFBE_SE_FNC_CountPlayerScores = Compile preprocessFileLineNumbers "Server\Module\AntiStack\countPlayerScores.sqf";
WFBE_SE_FNC_CompareTeamScores = Compile preprocessFileLineNumbers "Server\Module\AntiStack\compareTeamScores.sqf";
WFBE_SE_FNC_CallDatabaseSendPlayerList = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseSendPlayerList.sqf";
WFBE_SE_FNC_GetTeamScoreMonitor = Compile preprocessFileLineNumbers "Server\Module\AntiStack\getTeamScoreMonitor.sqf";
WFBE_SE_PVEH_ClientHasConnectedAtLaunch = Call Compile preprocessFileLineNumbers "Server\Module\AntiStack\clientHasConnectedAtLaunch.sqf";
//--- SM8/XR9: removed dead WFBE_SE_FNC_SupplyMissionActive (supplyMissionActive.sqf) -- compiled, zero callers (superseded by supplyMissionStarted.sqf).
WFBE_SE_FNC_ChangeSideSupply = Call Compile preprocessFileLineNumbers "Server\Functions\Server_ChangeSideSupply.sqf";
WFBE_SE_FNC_AwardScorePlayer = Compile preprocessFileLineNumbers "Server\Functions\Server_AwardScorePlayer.sqf";
WFBE_SE_PV_RequestSupplyValue = Call Compile preprocessFileLineNumbers "Server\Functions\Server_PV_RequestSupplyValue.sqf";
WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseRequestSideTotalSkill.sqf";
WFBE_SE_FNC_CallDatabaseFlushPlayerList = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseFlushPlayerList.sqf";
WFBE_SE_FNC_CallDatabaseSetMap = Compile preprocessFileLineNumbers "Server\Module\AntiStack\callDatabaseSetMap.sqf";
//WFBE_CO_FNC_InitAFKkickHandler = Compile preprocessFileLineNumbers "Server\Module\afkKick\initAFKkickHandler.sqf";
// WFBE_CO_FNC_monitorServerFPS = Compile preprocessFileLineNumbers "Server\Module\serverFPS\monitorServerFPS.sqf";
WFBE_SE_FNC_AttackWave = Call Compile preprocessFileLineNumbers "Server\PVFunctions\AttackWave.sqf";
WFBE_SE_FNC_AttackWavePVEH = Call Compile preprocessFileLineNumbers "Server\Functions\Server_AttackWave.sqf";
WFBE_SE_FNC_CounterBatteryCheck = Compile preprocessFileLineNumbers "Server\Functions\Server_CounterBattery.sqf";
WFBE_SE_FNC_SpawnStructureDressing = Compile preprocessFileLineNumbers "Server\Functions\Server_SpawnStructureDressing.sqf";
WFBE_SE_FNC_BankIncome = Compile preprocessFileLineNumbers "Server\Functions\Server_BankIncome.sqf";
WFBE_SE_FNC_SiteClearance = Compile preprocessFileLineNumbers "Server\Functions\Server_SiteClearance.sqf";
//--- CBR: per-side registries (populated as CBRs are built; pruned lazily during checks).
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0) then {
	missionNamespace setVariable ["WFBE_CBR_WEST", []];
	missionNamespace setVariable ["WFBE_CBR_EAST", []];
};
//--- Bank: per-side single-object registries (set when bank is built, cleared on death).
if ((missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	missionNamespace setVariable ["WFBE_BANK_WEST", objNull];
	missionNamespace setVariable ["WFBE_BANK_EAST", objNull];
};

//--- Least-loaded HC picker (single source of truth for delegation balance). Compiled
//--- unconditionally - the commander/patrol/wildcard delegation sites are not gated by the
//--- version check below, so this must exist whenever any HC delegation can run.
WFBE_CO_FNC_PickLeastLoadedHC = Compile preprocessFileLineNumbers "Server\Functions\Server_PickLeastLoadedHC.sqf";

//--- Define Headless Client functions (server ones).
if (ARMA_VERSION >= 162 && ARMA_RELEASENUMBER >= 101334 || ARMA_VERSION > 162) then {
	WFBE_CO_FNC_DelegateAITownHeadless = Compile preprocessFileLineNumbers "Server\Functions\Server_DelegateAITownHeadless.sqf";
	WFBE_CO_FNC_DelegateAIStaticDefenceHeadless = Compile preprocessFileLineNumbers "Server\Functions\Server_DelegateAIStaticDefenceHeadless.sqf";
};

Call Compile preprocessFileLineNumbers 'Server\Functions\Server_FNC_Delegation.sqf'; //--- FUNCTIONS: Delegation.

//--- Call in NEURO System (Taxi Advanced Script).
[] Call Compile preprocessFile "Server\Module\NEURO\NEURO.sqf";

//--- Headless Clients.
if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") == 2) then {
	missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", []];
};

//--- NEURO: Special Condition.
missionNamespace setVariable["NEURO_TAXI_CONDITION", "isNil {_x getVariable 'WFBE_Taxi_Prohib'} && local _x"];

//--- Server Init is now complete.
serverInitComplete = true;

["INITIALIZATION", "Init_Server.sqf: Functions are loaded."] Call WFBE_CO_FNC_LogContent;

//--- Getting all locations.
startingLocations = [0,0,0] nearEntities ["LocationLogicStart", 100000];

["INITIALIZATION", "Init_Server.sqf: Initializing starting locations."] Call WFBE_CO_FNC_LogContent;

//--- Waiting for the common part to be executed.
waitUntil {commonInitComplete && townInit};

//--- SELFTEST: one-line proof of live tunables, read AFTER params/constants are final (deploy verification).
diag_log ("SELFTEST|v1|townsMax=" + str (missionNamespace getVariable ["WFBE_C_TOWNS_ACTIVE_MAX", -1]) + "|delegation=" + str (missionNamespace getVariable ["WFBE_C_AI_DELEGATION", -1]) + "|aicomLock=" + str (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", -1]) + "|aicomEnabled=" + str (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", -1]) + "|totalAiMax=" + str (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", -1]) + "|wildcardAlways=" + str (missionNamespace getVariable ["WFBE_C_WILDCARD_ALWAYS", 1]) + "|statlog=" + str (missionNamespace getVariable ["WFBE_C_STATLOG", -1]) + "|arm=" + (missionNamespace getVariable ["WFBE_C_AB_ARM", "LEGACY"]) + "|simGating=" + str (missionNamespace getVariable ["WFBE_C_SIM_GATING", 0]));

//--- Side logics.
_present_west = missionNamespace getVariable "WFBE_WEST_PRESENT";
_present_east = missionNamespace getVariable "WFBE_EAST_PRESENT";
_present_res = missionNamespace getVariable "WFBE_GUER_PRESENT";

//--- New Variables.
if ((missionNamespace getVariable "WFBE_C_TOWNS_PATROLS") > 0) then {
	missionNamespace setVariable ["WFBE_C_PATROLS_DELAY_SPAWN", 360];//--- Patrols will be able to respawn after x seconds.
	missionNamespace setVariable ["WFBE_C_PATROLS_TOWNS_REUSABLITY", 0.25];//--- Patrols may patrol a town again after being in 25% of the other towns.
	missionNamespace setVariable ["WFBE_C_PATROLS_TOWNS_LOCK", floor(totalTowns * (missionNamespace getVariable "WFBE_C_PATROLS_TOWNS_REUSABLITY"))];
};

[] Call Compile preprocessFile 'Server\Init\Init_Defenses.sqf';

//--- Weather.
// Marty: Accelerated skipTime makes low clouds stutter, so day/night owns the weather and keeps the server sky clear.
Call {
	_weat = missionNamespace getVariable "WFBE_C_ENVIRONMENT_WEATHER";
	if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) exitWith {
		0 setOvercast 0;
		0 setRain 0;
	};
	if (_weat == 3) exitWith {};
	if (!isDedicated) exitWith {};

	_oc = 0.05;
	switch (_weat) do {
		case 0: {_oc = 0};
		case 1: {_oc = 0.5};
		case 2: {_oc = 1};
	};
	60 setOvercast _oc;
};

["INITIALIZATION", "Init_Server.sqf: Weather module is loaded."] Call WFBE_CO_FNC_LogContent;

//--- Static defenses groups in main towns.
{
	missionNamespace setVariable [Format ["WFBE_%1_DefenseTeam", _x], ([_x, "defense"] Call WFBE_CO_FNC_CreateGroup)];
	(missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _x]) setVariable ["wfbe_persistent", true];
} forEach [west,east,resistance];

//--- Select whether the spawn restriction is enabled or not.
_locationLogics = [];
if ((missionNamespace getVariable "WFBE_C_BASE_START_TOWN") > 0) then {
	{
		_nearLogics = _x nearEntities[["LocationLogicStart"],2000];
		if (count _nearLogics > 0) then {{if !(_x in _locationLogics) then {_locationLogics = _locationLogics + [_x]}} forEach _nearLogics};
	} forEach towns;
	if (count _locationLogics < 3) then {_locationLogics = startingLocations};
	["INITIALIZATION", Format ["Init_Server.sqf: Spawn locations were refined [%1].",count _locationLogics]] Call WFBE_CO_FNC_LogContent;
} else {
	_locationLogics = startingLocations;
};

WF_Logic setVariable ["wfbe_spawnpos", _locationLogics];

Private ["_i", "_maxAttempts", "_minDist", "_rPosE", "_rPosW", "_setEast", "_setGuer", "_setWest", "_startE", "_startG", "_startW", "_egressOK"];
_i = 0;
_maxAttempts = 2000;
_minDist = startingDistance;
_startW = [0,0,0];
_startE = [0,0,0];
_startG = [0,0,0];
_rPosW = [0,0,0];
_rPosE = [0,0,0];
_setWest = if (_present_west) then {true} else {false};
_setEast = if (_present_east) then {true} else {false};
_setGuer = false; //--- B59 (Ray 2026-06-20): was 'if (_present_res) then {true} else {false}'. GUER is base-less/harass-only and is NEVER placed in this loop, so _setGuer=true pinned the exit (L331) open -> the loop always ran to _maxAttempts and force-fell to the FIXED wfbe_default markers (=identical spawn every match). false lets it exit once WEST+EAST are placed = genuine random placement. Rollback: if (_present_res) then {true} else {false}.
_total = count _locationLogics;

_use_random = false;

//--- Egress-quality gate (A2-fix 2026-06-14, EAST-EGRESS): a random start (MODE=2) can box a side
//--- into a map corner with a single egress road, leaving its AI-commander HC route empty and the
//--- teams stalled near base. Before accepting a random candidate, require it to have a usable road
//--- network nearby and to sit clear of the map edges. _this = start location object -> bool.
//--- roadsConnectedTo is OA-only: guarded with the SAME WF_A2_Vanilla idiom as AI_Commander_Base.sqf:99
//--- and degrades to "accept if any road is near" on Vanilla A2 (never throws).
_egressOK = {
	private ["_loc","_pos","_minRoads","_margin","_ws","_roads","_usable","_ok","_road","_conn"];
	_loc = _this;
	if (isNull _loc) exitWith {false};
	_pos = getPos _loc;
	_minRoads = missionNamespace getVariable ["WFBE_C_BASE_MIN_EGRESS_ROADS", 3];
	_margin   = missionNamespace getVariable ["WFBE_C_BASE_EDGE_MARGIN", 400];

	//--- Reject candidates hugging any map edge (corner-box guard).
	_ws = 15360;  //--- A2-fix 2026-06-14: worldSize is A3-only (undefined in A2 OA -> spammed "Undefined variable worldsize"); Chernarus map size = 15360
	if ((_pos select 0) < _margin || (_pos select 0) > (_ws - _margin)) exitWith {false};
	if ((_pos select 1) < _margin || (_pos select 1) > (_ws - _margin)) exitWith {false};

	_roads = _pos nearRoads 250;
	_ok = false;
	if (!isNil {missionNamespace getVariable "WF_A2_Vanilla"} && {!WF_A2_Vanilla}) then {
		//--- OA: count USABLE segments (roadsConnectedTo>=2). Need >= _minRoads to call it an egress.
		_usable = 0;
		{
			_road = _x;
			_conn = _road call {private "_c"; _c = []; if (!isNil {roadsConnectedTo _this}) then {_c = roadsConnectedTo _this}; _c};
			if (count _conn >= 2) then {_usable = _usable + 1};
		} forEach _roads;
		if (_usable >= _minRoads) then {_ok = true};
	} else {
		//--- Vanilla A2 (no roadsConnectedTo): degrade to "accept if any road is near".
		if (count _roads > 0) then {_ok = true};
	};
	_ok
};

_spawn_north = objNull;
_spawn_south = objNull;
_spawn_central = objNull;
_skip_w = false;
_skip_e = false;
{
	if (!isNil {_x getVariable "wfbe_spawn"}) then {
		switch (_x getVariable "wfbe_spawn") do {
			case "north": {_spawn_north = _x};
			case "south": {_spawn_south = _x};
			case "central": {_spawn_central = _x};
		};
	};
} forEach startingLocations;

//todo, improve starting locations system.
switch (missionNamespace getVariable "WFBE_C_BASE_STARTING_MODE") do {
	case 0: {
		//--- West north, east south.
		if (isNull _spawn_north || isNull _spawn_south) then {
			_use_random = true;
		} else {
			_startE = _spawn_south;
			_startW = _spawn_north;
			_startG = _spawn_central;
			if (WFBE_ISTHREEWAY) then {_skip_w = true; _skip_e = true; _setWest = false; _setEast = false; _use_random = true};
		};
	};
	case 1: {
		//--- West south, east north.
		if (isNull _spawn_north || isNull _spawn_south) then {
			_use_random = true;
		} else {
			_startE = _spawn_north;
			_startW = _spawn_south;
			_startG = _spawn_central;
			if (WFBE_ISTHREEWAY) then {_skip_w = true; _skip_e = true; _setWest = false; _setEast = false; _use_random = true};
		};
	};
	case 2: {
		_use_random = true;
	};
};

if (_use_random) then {
	//--- B57 START-VARIETY FIX (Ray 2026-06-20): on a dedicated server each mission is a FRESH process, so A2's
	//--- random() starts from the SAME deterministic state every match -> the "Random" start was always identical
	//--- ("HQ always spawns at the same place"). Advance the RNG by a per-match-varying amount (a counter persisted
	//--- in profileNamespace across restarts) so the start actually varies match-to-match. A2-OA-safe.
	private ["_matchN","_dump"];
	_matchN = (profileNamespace getVariable ["WFBE_MATCH_COUNTER", 0]) + 1;
	profileNamespace setVariable ["WFBE_MATCH_COUNTER", _matchN];
	saveProfileNamespace;
	for "_b" from 1 to ((_matchN % 100) + 1) do { _dump = random 1 };
	["INITIALIZATION", Format ["Init_Server.sqf: B57 start-RNG advanced %1 draws (match #%2) for start variety.", (_matchN % 100) + 1, _matchN]] Call WFBE_CO_FNC_LogContent;

	while {true} do {
		if (!_setWest && !_setEast && !_setGuer) exitWith {["INITIALIZATION", "Init_Server.sqf : All sides were placed [Random]."] Call WFBE_CO_FNC_LogContent};

		//--- Determine west starting location if necessary.
		if (_setWest) then {
			_rPosW = _locationLogics select floor(random _total);
			//--- Egress-quality gate (EAST-EGRESS fix): require distance spacing AND a usable egress road
			//--- network clear of the map edges. Symmetric with east. Fallback below still guarantees placement.
			if (_rPosW distance _startE > _minDist && _rPosW distance _startG > _minDist && {_rPosW call _egressOK}) then {_startW = _rPosW; _setWest = false};
		};

		// --- Determine west starting location if necessary.
		if (_setEast) then {
			_rPosE = _locationLogics select floor(random _total);
			if (_rPosE distance _startW > _minDist && _rPosE distance _startG > _minDist && {_rPosE call _egressOK}) then {_startE = _rPosE; _setEast = false};
		};

		_i = _i + 1;

		if (_i >= _maxAttempts) exitWith {
			//--- Get the default locations.
			Private ["_eastDefault", "_westDefault"];
			_eastDefault = objNull;
			_westDefault = objNull;

			{
				if (!isNil {_x getVariable "wfbe_default"}) then {
					switch (_x getVariable "wfbe_default") do {
						case west: {_westDefault = _x};
						case east: {_eastDefault = _x};
					};
				};
			} forEach startingLocations;

			// --- Ensure that everything is set, otherwise we randomly set the spawn.
			if (isNull _eastDefault || isNull _westDefault) then {
				Private ["_tempWork"];
				_tempWork = +(startingLocations) - [_westDefault, _eastDefault];
				if (isNull _eastDefault && _present_east) then {_eastDefault = _tempWork select floor(random _total); _tempWork = _tempWork - [_eastDefault]};
				if (isNull _westDefault && _present_west) then {_westDefault = _tempWork select floor(random _total); _tempWork = _tempWork - [_westDefault]};
			};

			if (_present_east && !_skip_e) then {_startE = _eastDefault};
			if (_present_west && !_skip_w) then {_startW = _westDefault};

			["INITIALIZATION", "Init_Server.sqf : All sides were placed by force after that the attempts limit was reached."] Call WFBE_CO_FNC_LogContent;
		};
	};
};

["INITIALIZATION", Format ["Init_Server.sqf: Starting location mode is on [%1].",missionNamespace getVariable "WFBE_C_BASE_STARTING_MODE"]] Call WFBE_CO_FNC_LogContent;

[] execVM "Server\CallExtensions\GlobalGameStats.sqf";

// Player-stats: define the buffer helper, then launch the RPT flush loop. Both no-op unless WFBE_C_STATS_ENABLED.
call compile preprocessFileLineNumbers "Server\Stats\RecordStat.sqf";
[] execVM "Server\Stats\StatsFlush.sqf";

emptyQueu = [];

//--- Global sides initialization.
{
	Private["_side"];
	_side = _x select 1;
	_wasptmpFun = compile preprocessFile "Wasp\unsort\StartVeh.sqf";
	//--- Only use those variable if the side logic is present in the editor.
	if (_x select 0) then {
		_pos = _x select 2;
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		_sideID = (_side) Call WFBE_CO_FNC_GetSideID;

		//--- HQ init.
		_hq = [missionNamespace getVariable Format["WFBE_%1MHQNAME", _side], _pos, _sideID, getDir _pos, true, false, true] Call WFBE_CO_FNC_CreateVehicle;
		_hq setVariable ["WFBE_Taxi_Prohib", true];
		_hq setVariable ["wfbe_side", _side];
		_hq setVariable ["wfbe_trashable", false];
		_hq setVariable ["wfbe_structure_type", "Headquarters"];
		_hq addEventHandler ['killed', {_this Spawn WFBE_SE_FNC_OnHQKilled}];
		_hq addEventHandler ["hit",{_this Spawn BuildingDamaged}];

        if (_side == west && !(IS_chernarus_map_dependent))then{
	        _hq setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]";
	        _hq setVehicleInit "this setObjectTexture [1,""Textures\lavbody2_coD.paa""]";
	        _hq setVehicleInit "this setObjectTexture [2,""Textures\lav_hq_coD.paa""]";
			processinitcommands;
		};

		//--- HQ Friendly Fire handler.
		//if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE") > 0) then {_hq addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3] Call BuildingHandleDamages}]};

		//--- Get upgrade clearance for side.
		_clearance = missionNamespace getVariable "WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE";
		_upgrades = false;
		if (_clearance != 0) then {
			_upgrades = switch (true) do {
				case (_clearance in [1,4,5,7] && _side == west): {true};
				case (_clearance in [2,4,6,7] && _side == east): {true};
				case (_clearance in [3,5,6,7] && _side == resistance): {true};
				default {false};
			};
		};

		if !(_upgrades) then {
			_upgrades = [];
			for '_i' from 0 to count(missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", _side])-1 do {[_upgrades, 0] Call WFBE_CO_FNC_ArrayPush};
		} else {
			// Marty: Copy the configured max-level array before changing debug upgrade state, otherwise SQF mutates the config by reference.
			_upgrades = +(missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", _side]);
		};

		// Marty: In debug, leave Artillery Ammunition locked so the one-level ammo unlock and refresh flow can be tested.
		if (WF_Debug) then {_upgrades set [WFBE_UP_ARTYAMMO, 0]};

		//--- Logic init.
		_logik setVariable ["wfbe_commander", objNull, true];
		_logik setVariable ["wfbe_hq", _hq, true];
		_logik setVariable ["wfbe_hq_deployed", false, true];
		_logik setVariable ["wfbe_hq_repair_count", 1, true];
		_logik setVariable ["wfbe_hq_repairing", false, true];
		_logik setVariable ["wfbe_startpos", _pos, true];
		_logik setVariable ["wfbe_structure_lasthit", 0];
		_logik setVariable ["wfbe_structures", [], true];
		_logik setVariable ["wfbe_aicom_running", false];
		//--- V0.4.1: synthetic MONEY is fine (PvE pacing) - synthetic SUPPLY is not.
		//--- Funds seed = commander start funds x FUNDS_MULT; supply spending stays 100% real.
		_logik setVariable ["wfbe_aicom_funds", (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_START_FUNDS", 200000])]; //--- B36 hotfix (Ray): flat 200k AI-commander start cash (was FUNDS_START x FUNDS_MULT)
		_logik setVariable ["wfbe_upgrades", _upgrades, true];
		_logik setVariable ["wfbe_upgrading", false, true];
		// Marty: Track the running upgrade ID so clients can display the upgrade name in the menu.
		_logik setVariable ["wfbe_upgrading_id", -1, true];
		_logik setVariable ["wfbe_upgrade_queue", [], true];
		_logik setVariable ["wfbe_votetime", missionNamespace getVariable "WFBE_C_GAMEPLAY_VOTE_TIME", true];
		_logik setVariable ["wfbe_hqinuse",false];

		//todo improve.
		WF_Logic setVariable [Format["%1UnitsCreated",_side],0,true];
		WF_Logic setVariable [Format["%1Casualties",_side],0,true];
		WF_Logic setVariable [Format["%1VehiclesCreated",_side],0,true];
		WF_Logic setVariable [Format["%1VehiclesLost",_side],0,true];
		WF_Logic setVariable [Format["%1KilledEnemy",_side],0,true]; //--- B35 (claude-gaming 2026-06-15): kill-exchange counter (enemies downed by this side); feeds COMBATSTAT.

		//--- Parameters specific.
		if ((missionNamespace getVariable "WFBE_C_BASE_AREA") > 0) then {_logik setVariable ["wfbe_basearea", [], true]};
		if ((missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM") == 0 && (missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0) then {
			_logik setVariable ["wfbe_ai_supplytrucks", []];
			["WARNING", Format ["Init_Server.sqf: AI supply-truck logistics are disabled for [%1]; legacy UpdateSupplyTruck depends on missing Server\FSM\supplytruck.fsm.", _side]] Call WFBE_CO_FNC_LogContent;
		};
		if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {missionNamespace setVariable [format ["wfbe_supply_%1", str _side], missionNamespace getVariable Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]]};
		if ((missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM") in [3,4]) then {
			_logik setVariable ["wfbe_commander_percent", if ((missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_PERCENT_MAX") < 70) then {missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_PERCENT_MAX"} else {70}, true];
		};

		//--- Structures limit (live).
		_str = [];
		for '_i' from 0 to count(missionNamespace getVariable Format["WFBE_%1STRUCTURES",_side])-2 do {_str set [_i, 0]};
		_logik setVariable ["wfbe_structures_live", _str, true];

		//--- Radio: Initialize the announcers entities.
		_radio_hq1 = (createGroup sideLogic) createUnit ["Logic",[0,0,0],[],0,"NONE"];
		_radio_hq2 = (createGroup sideLogic) createUnit ["Logic",[0,0,0],[],0,"NONE"];
		[_radio_hq1] joinSilent ([_side, "misc"] Call WFBE_CO_FNC_CreateGroup);
		[_radio_hq2] joinSilent ([_side, "misc"] Call WFBE_CO_FNC_CreateGroup);
		_logik setVariable ["wfbe_radio_hq", _radio_hq1, true];
		_logik setVariable ["wfbe_radio_hq_rec", _radio_hq2];

		//--- Radio: Pick a random announcer.
		_announcers = missionNamespace getVariable Format ["WFBE_%1_RadioAnnouncers", _side];
		_radio_hq_id = (_announcers) select floor(random (count _announcers));

		//--- Radio: Apply an identity.
		_radio_hq1 setIdentity _radio_hq_id;
		_radio_hq1 setRank 'COLONEL';
		_radio_hq1 setGroupId ["HQ"];
		_radio_hq1 kbAddTopic [_radio_hq_id, "Client\kb\hq.bikb","Client\kb\hq.fsm", {call compile preprocessFileLineNumbers "Client\kb\hq.sqf"}];
		_logik setVariable ["wfbe_radio_hq_id", _radio_hq_id, true];

		//--- Starting vehicles.
		{
			_vehicle = [_x, getPos _hq, _sideID, 0, false] Call WFBE_CO_FNC_CreateVehicle;
			[_vehicle, getPos _hq, 45, 60, true, false, true] Call PlaceNear;
			_vehicle setVariable ["WFBE_Taxi_Prohib", true];
			(_vehicle) call WFBE_CO_FNC_ClearVehicleCargo;
			emptyQueu = emptyQueu + [_vehicle];
			[_vehicle] spawn WFBE_SE_FNC_HandleEmptyVehicle;
		} forEach (missionNamespace getVariable Format ['WFBE_%1STARTINGVEHICLES', _side]);

		//--- WASP additional vehiecles

		switch _side do{
		case west: {
		call _wasptmpFun;
		_tVeh = WEST_StartVeh select floor(random (count WEST_StartVeh));
		_vehicle = [_tVeh, getPos _hq, west, 0, false] Call WFBE_CO_FNC_CreateVehicle;
		[_vehicle,getPos _hq,45,60,true,false,true] Call PlaceNear;
		_vehicle setVariable ["WFBE_Taxi_Prohib", true];
		_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];
		clearWeaponCargoGlobal _vehicle;
		clearMagazineCargoGlobal _vehicle;
		emptyQueu = emptyQueu + [_vehicle];
		[_vehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
		if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {(_vehicle) Call BalanceInit};
if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];};
if ({(typeOf _vehicle) isKindOf _x} count ["LAV25_Base","M2A2_Base","BMP2_Base"] != 0) then {_vehicle addeventhandler ["fired",{_this spawn HandleReload;}];};
if({(_vehicle isKindOf _x)} count ["Tank","Wheeled_APC"] !=0) then {_vehicle addeventhandler ['Engine',{_this execVM "Client\Module\Engines\Engine.sqf"}];
_vehicle addAction ["<t color='"+"#00E4FF"+"'>STEALTH ON</t>","Client\Module\Engines\Stopengine.sqf", [], 7,false, true,"","alive _target &&(isEngineOn _target)"];};
		};
		case east:{
		call _wasptmpFun;
		_tVeh = EAST_StartVeh select floor(random (count EAST_StartVeh));
		_vehicle = [_tVeh, getPos _hq, east, 0, false] Call WFBE_CO_FNC_CreateVehicle;
		[_vehicle,getPos _hq,45,60,true,false,true] Call PlaceNear;
		_vehicle setVariable ["WFBE_Taxi_Prohib", true];
		_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];
		clearWeaponCargoGlobal _vehicle;
		clearMagazineCargoGlobal _vehicle;
		emptyQueu = emptyQueu + [_vehicle];
		[_vehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
		if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {(_vehicle) Call BalanceInit};

if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];};
if ({(typeOf _vehicle) isKindOf _x} count ["LAV25_Base","M2A2_Base","BMP2_Base"] != 0) then {_vehicle addeventhandler ["fired",{_this spawn HandleReload;}];};
if({(_vehicle isKindOf _x)} count ["Tank","Wheeled_APC"] !=0) then {_vehicle addeventhandler ['Engine',{_this execVM "Client\Module\Engines\Engine.sqf"}];
_vehicle addAction ["<t color='"+"#00E4FF"+"'>STEALTH ON</t>","Client\Module\Engines\Stopengine.sqf", [], 7,false, true,"","alive _target &&(isEngineOn _target)"];};
		};
		};

		//--- Groups init.
		_teams = [];
		{
			if !(isNil '_x') then {
				if (_x isKindOf "Man") then {
					Private ["_group"];
					_group = group _x;
					[_teams, _group] Call WFBE_CO_FNC_ArrayPush;

					if (isNil {_group getVariable "wfbe_funds"}) then {_group setVariable ["wfbe_funds", missionNamespace getVariable Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], true]};
					_group setVariable ["wfbe_side", _side];
					_group setVariable ["wfbe_persistent", true];
					_group setVariable ["wfbe_queue", []];
					_group setVariable ["wfbe_vote", -1, true];
					[_group, false]	Call SetTeamAutonomous;
					[_group, ""] Call SetTeamRespawn;
					[_group, -1] Call SetTeamType;
					[_group, "towns"] Call SetTeamMoveMode;
					[_group, [0,0,0]] Call SetTeamMovePos;


					if(isPlayer (leader (group _x)))then{
						_procedureName = "INSERT_PLAYER";
						_nickname = name (leader (group _x));
						_game_guid = getPlayerUID (leader (group _x));
						_side = side (leader (group _x));
						_money = _group getVariable "wfbe_funds";
					};

					["INITIALIZATION", Format["Init_Server.sqf: [%1] Team [%2] was initialized.", _side, _group]] Call WFBE_CO_FNC_LogContent;
				};

			};
		} forEach (synchronizedObjects _logik);

		_logik setVariable ["wfbe_teams", _teams, true];
		_logik setVariable ["wfbe_teams_count", count _teams];
	};
} forEach [[_present_east, east, _startE],[_present_west, west, _startW]];

//--- GUER "Insurgents" player faction team-registration + economy (gated on WFBE_C_GUER_PLAYERSIDE).
//--- The 4 RESISTANCE player slots are synced to LocationLogicOwnerResistance (WFBE_L_GUE); register each as a
//--- zero-fund harass team (stipend, not commander economy), then start the GUER economy loop.
if (((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) && {!isNil "WFBE_L_GUE"}) then {
	private ["_guerLogic","_guerTeams","_group"];
	_guerLogic = missionNamespace getVariable "WFBE_L_GUE";
	if (!(isNull _guerLogic)) then {
		_guerTeams = [];
		{
			if (!(isNull _x) && {_x isKindOf "Man"}) then {
				_group = group _x;
				[_guerTeams, _group] Call WFBE_CO_FNC_ArrayPush;
				_group setVariable ["wfbe_funds", 50000, true]; //--- GUER starting funds
				_group setVariable ["wfbe_side", resistance, true];
				_group setVariable ["wfbe_persistent", true];
				_group setVariable ["wfbe_queue", []];
				_group setVariable ["wfbe_vote", -1, true];
				[_group, false] Call SetTeamAutonomous;
				[_group, ""] Call SetTeamRespawn;
				[_group, -1] Call SetTeamType;
				[_group, "towns"] Call SetTeamMoveMode;
				[_group, [0,0,0]] Call SetTeamMovePos;
				["INITIALIZATION", Format ["Init_Server.sqf: GUER player team [%1] initialized.", _group]] Call WFBE_CO_FNC_LogContent;
			};
		} forEach (synchronizedObjects _guerLogic);
		diag_log format ["[WFBE] GUER playable faction: registered %1 player teams (INITIALIZATION LogContent is filtered on this build, so this diag_log is the visibility).", count _guerTeams];
		_guerLogic setVariable ["wfbe_teams", _guerTeams, true];
		_guerLogic setVariable ["wfbe_teams_count", count _guerTeams];
		[] execVM "Server\Server_GuerStipend.sqf";
	} else {
		["WARNING", "Init_Server.sqf: WFBE_L_GUE is null - GUER player teams not initialized (LocationLogicOwnerResistance missing in mission.sqm?)."] Call WFBE_CO_FNC_LogContent;
	};
};

//--- GUER gate OFF: delete the synced GUER player-slot units so nobody can join a non-functional insurgent
//--- (no economy / no team-reg). Done server-side here where WFBE_C_GUER_PLAYERSIDE is reliably readable
//--- (unlike .sqm init fields), so it can never wrongly fire while the gate is ON.
if (!((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) && {!isNil "WFBE_L_GUE"}) then {
	private ["_guerLogicOff"];
	_guerLogicOff = missionNamespace getVariable "WFBE_L_GUE";
	if (!(isNull _guerLogicOff)) then {
		{ if (!(isNull _x)) then { deleteVehicle _x }; } forEach (synchronizedObjects _guerLogicOff);
	};
};

//--- EDITOR-SLOT TAGGING (2026-06-15): the 27 WEST + 27 EAST editor-placed player-slot groups in
//--- mission.sqm are born by the engine at load with no createGroup, so WFBE_CO_FNC_CreateGroup never
//--- tags them and they show as "untagged" in the server_groupsGC per-source audit - indistinguishable
//--- from genuinely leaked groups. One-shot sweep tagging every still-untagged WEST/EAST group as
//--- "editor-player-slot" (broadcast). They already carry wfbe_persistent=true (set above) so the GC
//--- never reaps them; this is audit-only. The isNil guard skips any runtime group the wrapper already
//--- tagged. GUER's 4 player-slot editor groups are now included so they tag as editor-player-slot too.
if (isNil "WFBE_EDITOR_GROUPS_TAGGED") then {
	missionNamespace setVariable ["WFBE_EDITOR_GROUPS_TAGGED", true];
	{
		Private ["_src"];
		_src = _x getVariable "wfbe_group_src";
		if (isNil "_src" && {(side _x == west) || (side _x == east) || (side _x == resistance)}) then {
			_x setVariable ["wfbe_group_src", "editor-player-slot", true];
		};
	} forEach allGroups;
};

[] Call Compile preprocessFile "Server\Config\Config_GUE.sqf";

serverInitFull = true;

//--- DEADSPAWN PHYSICAL PROTECTION (claude-gaming 2026-06-14): ring each per-side
//--- TempRespawnMarker with tall H-barriers so an enemy-side AI-slot bot cannot shoot
//--- a HUMAN parked on an adjacent side's holding marker during join (Smarty deadspawn
//--- kill). One-shot, server-only, purely additive; players are teleported out by
//--- Task-35 so the sealed ring never traps them, and the allowDamage-false transit
//--- protection in Init_Client.sqf is left intact as the first layer.
[] execVM "Server\Init\Init_DeadspawnWall.sqf";

//--- AIRFIELD ON-LAND PROBE (claude-gaming 2026-06-14): DIAGNOSTIC ONLY.
//--- One-shot server-only grid scan that logs surfaceIsWater + nearRoads for a
//--- 5x5 grid of candidate camp positions around each airfield's
//--- LocationLogicAirport (Balota id=7, NWAF id=8). Reads AIRFIELD_PROBE|... in
//--- the RPT to pick a verified on-land, off-road apron. Changes NO coordinates.
[] execVM "Server\Init\Init_AirfieldProbe.sqf";

// run one global server town script to process supply updates in each town
[] Spawn {[] execVM 'Server\FSM\server_town.sqf'};

[] Spawn {
	if ((missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER") > 0 || (missionNamespace getVariable "WFBE_C_TOWNS_OCCUPATION") > 0) then {
		[] execVM 'Server\FSM\server_town_ai.sqf';
	};
};

//--- Town starting mode.
if ((missionNamespace getVariable "WFBE_C_TOWNS_STARTING_MODE") != 0 || (missionNamespace getVariable "WFBE_C_TOWNS_PATROLS") > 0) then {[] Call Compile preprocessFile "Server\Init\Init_Towns.sqf"} else {townInitServer = true};

//--- Pre-initialization of the Garbage Collector & Empty vehicle collector.
if (WF_A2_Vanilla) then {WF_Logic setVariable ["trash",[],true]};
WF_Logic setVariable ["emptyVehicles",[],true];

//--- Don't pause the server init script.
[] Spawn {
	waitUntil {townInit};
		[] execVM "Server\FSM\server_victory_threeway.sqf";
		["INITIALIZATION", "Init_Server.sqf: Victory Condition FSM is initialized."] Call WFBE_CO_FNC_LogContent;

	[] ExecVM "Server\FSM\updateresources.sqf";
	[] ExecVM "Server\FSM\upgradeQueue.sqf";
	[] ExecVM "Server\FSM\server_side_patrols.sqf";
	["INITIALIZATION", "Init_Server.sqf: Resources FSM is initialized."] Call WFBE_CO_FNC_LogContent;
};

[] ExecVM "Server\FSM\server_collector_garbage.sqf";
["INITIALIZATION", "Init_Server.sqf: Garbage Collector is defined."] Call WFBE_CO_FNC_LogContent;
[] ExecVM "Server\FSM\emptyvehiclescollector.sqf";
["INITIALIZATION", "Init_Server.sqf: Empty Vehicle Collector is defined."] Call WFBE_CO_FNC_LogContent;
[] ExecVM "Server\FSM\server_groupsGC.sqf";
["INITIALIZATION", "Init_Server.sqf: Group GC is defined."] Call WFBE_CO_FNC_LogContent;

//--- Client FPS telemetry receiver (2026-06-15, Net_2 request).
//--- Each PLAYER client publishes [uid, name, avgFps, minFps] every WFBE_C_CLIENT_FPS_REPORT_INTERVAL s
//--- when the WFBE_C_CLIENT_FPS_REPORT lobby param is ON. We stamp it server-side with what the client
//--- can't cheaply know - live player count + HC count - so the RPT can be bucketed. Raw diag_log so it
//--- lands regardless of LOG_CONTENT_STATE; the lobby param is the single on/off gate. Name is logged
//--- LAST so a '|' in a player name can't corrupt the earlier pipe-delimited fields.
if ((missionNamespace getVariable ["WFBE_C_CLIENT_FPS_REPORT", 0]) == 1) then {
	"WFBE_FPS_REPORT" addPublicVariableEventHandler {
		private ["_d", "_players", "_hc"];
		_d = _this select 1;
		_players = { isPlayer _x } count playableUnits;
		//--- hc= the live headless-client count (registry filtered to non-null, alive-leader HCs), so the
		//--- planned 0-HC / 1-HC / 2-HC comparison days bucket cleanly even when an RPT spans several launches.
		_hc = { !isNull _x && {!isNull leader _x} && {alive leader _x} } count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
		diag_log ("FPSREPORT|v1|uid=" + str (_d select 0)
			+ "|fps=" + str (_d select 2)
			+ "|fpsMin=" + str (_d select 3)
			+ "|players=" + str _players
			+ "|hc=" + str _hc
			+ "|dnMode=" + str (missionNamespace getVariable ["WFBE_DAYNIGHT_ENABLED", 1])
			+ "|daytime=" + str (round (daytime * 100) / 100)
			+ "|sun=" + str (round (sunOrMoon * 100) / 100)
			+ "|srvFps=" + str (round diag_fps)
			+ "|t=" + str (round (time / 60))
			+ "|name=" + (_d select 1));
	};
	["INITIALIZATION", "Init_Server.sqf: Client FPS telemetry receiver armed (WFBE_C_CLIENT_FPS_REPORT=1)."] Call WFBE_CO_FNC_LogContent;
};

/////////////////////////////////////////////////////////////////////////////////// map cleaners

// weaponholder cleaner
[] ExecVM "Server\FSM\cleaners\droppeditems_cleaner.sqf";
["INITIALIZATION", "droppeditems_cleaner.sqf: cleaner for dropped items is defined."] Call WFBE_CO_FNC_LogContent;

// crater cleaner
[] ExecVM "Server\FSM\cleaners\crater_cleaner.sqf";
["INITIALIZATION", "crater_cleaner.sqf: cleaner for craters is defined."] Call WFBE_CO_FNC_LogContent;

// ruins cleaner
[] ExecVM "Server\FSM\cleaners\ruins_cleaner.sqf";
["INITIALIZATION", "ruins_cleaner.sqf: cleaner for ruins is defined."] Call WFBE_CO_FNC_LogContent;

// building restorer
[] ExecVM "Server\FSM\restorers\buildings_restorer.sqf";
["INITIALIZATION", "buildings_restorer.sqf: restorer for damaged structures is defined."] Call WFBE_CO_FNC_LogContent;

// mines cleaner
[] ExecVM "Server\FSM\cleaners\mines_cleaner.sqf";
["INITIALIZATION", "mines_cleaner.sqf: cleaner for mines is defined."] Call WFBE_CO_FNC_LogContent;

/////////////////////////////////////////////////////////////////////////////////// end of map cleaners

//--- Base Area (grouped base)
if ((missionNamespace getVariable "WFBE_C_BASE_AREA") > 0) then {[] execVM "Server\FSM\basearea.sqf"};

//if (LOG_CONTENT_STATE == "ACTIVATED") then {[] execVM "Server\FSM\groupsMonitor.sqf"};

//--- ALICE Module.
if ((missionNamespace getVariable "WFBE_C_MODULE_BIS_ALICE") > 0) then {
	_type = if (WF_A2_Vanilla) then {'AliceManager'} else {'Alice2Manager'};
	_alice = (createGroup sideLogic) createUnit [_type,[0,0,0],[],0,"NONE"];

	["INITIALIZATION", "Init_Server.sqf: BIS ALICE is defined."] Call WFBE_CO_FNC_LogContent;
};

// Execute the server fps script on a seperate thread
[] ExecVM "Server\GUI\serverFpsGUI.sqf";

["INITIALIZATION", Format ["Init_Server.sqf: Server initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;

//--- Waiting until that the game is launched.
waitUntil {time > 0};

//--- In-game restart announcer (work-order item 15): server-only countdown that warns every
//--- player once per minute over the final WFBE_C_RESTART_WARN_MIN minutes before the scheduled
//--- restart. Self-gates again internally, but we also gate the spawn here to avoid the thread.
if ((missionNamespace getVariable ["WFBE_C_RESTART_ENABLED", 1]) == 1) then {
	[] execVM "Server\FSM\server_restart_announcer.sqf";
	["INITIALIZATION", "Init_Server.sqf: Restart announcer FSM is initialized."] Call WFBE_CO_FNC_LogContent;
};

//--- Dashboard-link announcer (claude-gaming 2026-06-14): every WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL
//--- seconds, broadcast the public live-stats URL to general chat so players know where to find updates.
if ((missionNamespace getVariable ["WFBE_C_DASHBOARD_ANNOUNCE_ENABLED", 1]) == 1) then {
	[] execVM "Server\FSM\server_dashboard_announcer.sqf";
	["INITIALIZATION", "Init_Server.sqf: Dashboard-link announcer FSM is initialized."] Call WFBE_CO_FNC_LogContent;
};

//--- Top-Players leaderboard emitter (claude-gaming 2026-06-14): every WFBE_C_PLAYERSTAT_INTERVAL
//--- seconds, emit one PLAYERSTAT row per connected human player (name/uid/side/score). This is the
//--- only telemetry carrying the display name, so it powers the public Top-Players leaderboard tab.
if ((missionNamespace getVariable ["WFBE_C_PLAYERSTAT_ENABLED", 1]) == 1) then {
	[] execVM "Server\FSM\server_playerstat_loop.sqf";
	["INITIALIZATION", "Init_Server.sqf: Player-stat leaderboard emitter FSM is initialized."] Call WFBE_CO_FNC_LogContent;
};

//--- FPS PROFILING (claude-gaming 2026-06-13): enable the PerformanceAudit framework SERVER-SIDE ONLY so we
//--- MEASURE where server frametime goes (uncached per-town capture scans suspected). Marty kept the GLOBAL
//--- param off due to CLIENT-side AFK/commander regressions, so we force it here on the server only - clients
//--- keep the param default (0) and never run the client audit. Server-local set, never broadcast.
WFBE_C_PERFORMANCE_AUDIT_ENABLED = 1;
PerformanceAuditEnabled = true;

// Marty: Start the local server Performance Audit writer; metrics stay local and are written to the server RPT.
[] Spawn {
	waitUntil {!isNil "PerformanceAudit_Run"};
	["SERVER"] Spawn PerformanceAudit_Run;
};

call WFBE_CO_FNC_InitAFKkickHandler;


// [removed in release fix #7] monitorServerFPS.sqf was a redundant second FPS publisher: its PV
// "WFBE_VAR_SERVER_FPS" has no reader anywhere (the live HUD reads SERVER_FPS_GUI from serverFpsGUI.sqf).
// The file has been deleted; serverFpsGUI.sqf remains the single publisher.

// Marty: AntiStack remains compiled for dependencies, but its scheduled loops and DB session state are optional for controlled ON/OFF audits.
_antiStackEnabled = ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 1);
["INFORMATION", Format ["Init_Server.sqf: AntiStack is [%1] for this session.", if (_antiStackEnabled) then {"ENABLED"} else {"DISABLED"}]] Call WFBE_CO_FNC_LogContent;
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["antistack_state", 0, Format ["enabled:%1;state:%2", missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1], if (_antiStackEnabled) then {"enabled"} else {"disabled"}], "SERVER"] Call PerformanceAudit_Record;
	};
};
if (_antiStackEnabled) then {
	[] execVM "Server\Module\AntiStack\countPlayerScores.sqf";
	[] execVM "Server\Module\AntiStack\monitorTeamToJoin.sqf";
	[] execVM "Server\Module\AntiStack\skillDiffCompensation.sqf";

	// 0 = NONE
	// 1 = CHERNARUS
	// 2 = TAKISTAN
	["SET_MAP", 1] call WFBE_SE_FNC_CallDatabaseSetMap;
};

_logMatchWinPlayerCountThreshold = 10;

[_logMatchWinPlayerCountThreshold] execVM "Server\MonitorPlayerCount.sqf";

WFBE_SE_PLAYERLIST = [[objNull, "0"]];

{_x Spawn WFBE_SE_FNC_VoteForCommander} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: harass-only, no commander election

//--- feat/ai-commander: one always-running supervisor per side (self-gates on enabled + no player commander).
{_x Spawn WFBE_SE_FNC_AI_Commander} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: no HQ, loop was inert (perf win)

//--- V0.6: AI Commander Wildcard events (one free random event per AI side per interval).
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD", 1]) == 1 && {(missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0}) then {
	{_x Spawn WFBE_SE_FNC_AI_Commander_Wildcard} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: base-less, no wildcard events
	["INITIALIZATION", Format ["Init_Server.sqf: AI Commander Wildcard workers started for %1 sides (interval=%2s).", count WFBE_PRESENTSIDES, missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL", 1800]]] Call WFBE_CO_FNC_AICOMLog;
};

// Marty: Start the accelerated day/night cycle only when the mission parameter enables it.
if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) then {
	[] execVM "Server\Functions\Server_DayNightCycle.sqf";
};

["INITIALIZATION", Format ["Init_Server.sqf: Server initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;
