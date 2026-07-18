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
//--- AICOM HIGH-CLIMB (claude-gaming 2026-07-01): give AI-commander tanks the Valhalla low-gear terrain
//--- assist on the SERVER, where server-local founded commander teams are local (the player client assist
//--- never runs here). The manager self-gates OFF unless WFBE_C_AICOM_HIGHCLIMB==1 and enumerates only the
//--- side-logic wfbe_teams (bounded, no allUnits). Each HC starts its own copy from Init_HC.sqf.
if (isServer) then { [] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_HighClimb.sqf" };
if (isServer) then { [] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_AutoFlip.sqf" };  //--- Build84 (Ray): auto-right flipped AICOM ground vehicles (server-local founded teams).
if (WF_A2_Vanilla) then {AISquadRespawn = Compile preprocessFile "Server\AI\AI_SquadRespawn.sqf"};
if !(WF_A2_Vanilla) then {AIAdvancedRespawn = Compile preprocessFile "Server\AI\AI_AdvancedRespawn.sqf"};
AIMoveTo = Compile preprocessFile "Server\AI\Orders\AI_MoveTo.sqf";
AIPatrol = Compile preprocessFile "Server\AI\Orders\AI_Patrol.sqf";
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
GetAICommanderFunds = Compile preprocessFile "Server\Functions\Server_GetAICommanderFunds.sqf";
//--- B74.2 (Ray 2026-06-24, directive #5): AI-commander structure-sell / recycle worker (dark by default, see WFBE_C_AICOM_BASE_SELL_ENABLE).
WFBE_SE_FNC_AI_Com_BaseSell = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_BaseSell.sqf";
//--- FUNDS-SINK (claude-gaming 2026-06-29, SYSTEM 1): drain a rich AICOM hoard into offense (dark by default, see WFBE_C_AICOM_FUNDS_SINK_ENABLE). Called from updateresources.sqf on the income cadence.
WFBE_SE_FNC_AI_Com_FundsSink = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_FundsSink.sqf";
HandleBuildingDamage = Compile preprocessFile "Server\Functions\Server_HandleBuildingDamage.sqf";
HandleDefense = Compile preprocessFile "Server\Functions\Server_HandleDefense.sqf";
HandleSpecial = Compile preprocessFile "Server\Functions\Server_HandleSpecial.sqf";
MHQRepair = Compile preprocessFile "Server\Functions\Server_MHQRepair.sqf";
SideMessage = Compile preprocessFile "Server\Functions\Server_SideMessage.sqf";

UpdateTeam = Compile preprocessFile "Server\Functions\Server_UpdateTeam.sqf";
/* UpdateSupplyTruck = Compile preprocessFile "Server\AI\AI_UpdateSupplyTruck.sqf"; */

//--- Support Functions.
KAT_ParaAmmo = Compile preprocessFile "Server\Support\Support_ParaAmmo.sqf";
KAT_Paratroopers = Compile preprocessFile "Server\Support\Support_Paratroopers.sqf";
KAT_GuerHeliDrop = Compile preprocessFile "Server\Support\Support_GuerHeliDrop.sqf";	//--- fable/guer-barrelbomb
KAT_ParaVehicles = Compile preprocessFile "Server\Support\Support_ParaVehicles.sqf";
KAT_UAV = Compile preprocessFile "Server\Support\Support_UAV.sqf";
KAT_FPV = Compile preprocessFile "Server\Support\Support_FPV.sqf";
KAT_FPVDetonate = Compile preprocessFile "Server\Support\Support_FPV_Detonate.sqf";

//--- NAVAL HVT: SCUD strike handler (feat/naval-hvt-objectives). Feature-flagged behind WFBE_C_NAVAL_HVT.
if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) == 1) then {
	KAT_ScudStrike = Compile preprocessFile "Server\Support\Support_ScudStrike.sqf";
	["INITIALIZATION", "Init_Server.sqf: KAT_ScudStrike compiled (WFBE_C_NAVAL_HVT=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- New Fnc.
WFBE_SE_FNC_AI_SetTownAttackPath = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath.sqf";
WFBE_SE_FNC_StructureCapAdmit = Compile preprocessFileLineNumbers "Server\Functions\Server_StructureCapAdmit.sqf"; //--- P0 atomic structure cap (single admission gate, all AICOM build paths)
WFBE_SE_FNC_AI_SetTownAttackPath_PathIsSafe = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath_PathIsSafe.sqf";
WFBE_SE_FNC_AI_SetTownAttackPath_PosIsSafe = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_SetTownAttackPath_PosIsSafe.sqf";
WFBE_SE_FNC_AI_Com_Upgrade = Compile preprocessFileLineNumbers "Server\Functions\Server_AI_Com_Upgrade.sqf";
//--- feat/ai-commander: revival workers + supervisor.
WFBE_SE_FNC_AI_Com_AssignTypes = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_AssignTypes.sqf";
WFBE_SE_FNC_AI_Com_AssignTowns = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_AssignTowns.sqf";
WFBE_SE_FNC_AI_Com_Produce = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Produce.sqf";
WFBE_SE_FNC_AI_Com_DisbandLowTier = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_DisbandLowTier.sqf";
WFBE_SE_FNC_AI_Com_Execute = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Execute.sqf";
WFBE_SE_FNC_AI_Com_Base = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Base.sqf";
WFBE_SE_FNC_AI_Com_Beacon = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Beacon.sqf"; //--- AICOM FORWARD SPAWN-BEACON (Approach A): forward ambulance as a mobile spawn point (flag WFBE_C_AICOM_SPAWNBEACON_ENABLE, default 0 = inert).
WFBE_SE_FNC_AI_Com_Teams = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Teams.sqf";
WFBE_SE_FNC_AI_Com_Strategy = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Strategy.sqf";
WFBE_SE_FNC_AICOM2_Snapshot = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Snapshot.sqf"; //--- AICOM v2 rebuild (M0): world-model snapshot builder.
WFBE_SE_FNC_AICOM2_Allocate = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Allocate.sqf"; //--- AICOM v2 rebuild (M1): single offensive authority (flag WFBE_C_AICOM2_ALLOCATE_ENABLE).
WFBE_SE_FNC_AICOM2_Decapitate = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Decapitate.sqf"; //--- AICOM v2 rebuild (M5): DECAPITATE closer (flag WFBE_C_AICOM2_DECAP_ENABLE, default 0).
WFBE_SE_FNC_AICOM2_AirResp = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_AirResp.sqf"; //--- AICOM v2 rebuild (M6): AIRRESP organic W/E air-response closer (flag WFBE_C_AICOM2_AIRRESP_ENABLE, default 1 - ARMED live per owner directive 2026-07-08; see PR body).
WFBE_SE_FNC_AI_Com_MHQReloc = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_MHQReloc.sqf";
WFBE_SE_FNC_AI_Com_PlayerArty = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PlayerArty.sqf"; //--- COMMAND CONSOLE: assist-mode resolver for a player war-room ARTILLERY-HERE request (runs every tick, even under a human commander; fires only existing friendly guns).
WFBE_SE_FNC_AI_Com_Paratroops = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Paratroops.sqf"; //--- AICOM PARATROOPS: tier+structure-gated AI paratroop reinforcement drop, reuses the player KAT_Paratroopers support fn (flag WFBE_C_AICOM_PARATROOPS_ENABLE, default 0 = inert).
WFBE_SE_FNC_AI_Commander = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander.sqf";
WFBE_SE_FNC_AI_Commander_Wildcard = Compile preprocessFileLineNumbers "Server\Functions\AI_Commander_Wildcard.sqf";
WFBE_SE_FNC_AI_Commander_Wildcard_GUER = Compile preprocessFileLineNumbers "Server\Functions\AI_Commander_Wildcard_GUER.sqf";
WFBE_SE_FNC_GetTownGroups = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownGroups.sqf";
WFBE_SE_FNC_GetTownGroupsDefender = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownGroupsDefender.sqf";
WFBE_SE_FNC_GetTownPatrol = Compile preprocessFileLineNumbers "Server\Functions\Server_GetTownPatrol.sqf";
WFBE_SE_FNC_HandleEmptyVehicle = Compile preprocessFileLineNumbers "Server\Functions\Server_HandleEmptyVehicle.sqf";
WFBE_SE_FNC_HandlePVF = Compile preprocessFileLineNumbers "Server\Functions\Server_HandlePVF.sqf";
WFBE_SE_FNC_ManageTownDefenses = Compile preprocessFileLineNumbers "Server\Functions\Server_ManageTownDefenses.sqf";
WFBE_SE_FNC_OnHQKilled = Compile preprocessFileLineNumbers "Server\Functions\Server_OnHQKilled.sqf";
WFBE_SE_FNC_OperateTownDefensesUnits = Compile preprocessFileLineNumbers "Server\Functions\Server_OperateTownDefensesUnits.sqf";
WFBE_SE_FNC_ProcessUpgrade = Compile preprocessFileLineNumbers "Server\Functions\Server_ProcessUpgrade.sqf";
WFBE_SE_FNC_ProvisionAirfieldHangar = Compile preprocessFileLineNumbers "Server\Functions\Server_ProvisionAirfieldHangar.sqf";
WFBE_SE_FNC_SetCampsToSide = Compile preprocessFileLineNumbers "Server\Functions\Server_SetCampsToSide.sqf";
WFBE_SE_FNC_NavalHVT_BubbleComplete = Compile preprocessFileLineNumbers "Server\Functions\Server_NavalHVT_BubbleComplete.sqf"; //--- fable/radius-hold-primitive (GR-2026-07-08a): onComplete callback for a RadiusHold-registered carrier bubble (Init_NavalHVT.sqf, flag WFBE_C_NAVALHVT_BUBBLE_ENABLE).
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
//--- Radio Tower: per-side registry + public alive-flag consumed client-side by WASP\Radio\Radio_Manager.sqf to gate playback.
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER", 0]) > 0) then {
	missionNamespace setVariable ["WFBE_RADIOTOWER_WEST", []];
	missionNamespace setVariable ["WFBE_RADIOTOWER_EAST", []];
	WFBE_RADIOTOWER_WEST_ALIVE = false; publicVariable "WFBE_RADIOTOWER_WEST_ALIVE";
	WFBE_RADIOTOWER_EAST_ALIVE = false; publicVariable "WFBE_RADIOTOWER_EAST_ALIVE";
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

//--- MATCH|v1|START|: one-shot match-identity line; feeds Stats V2 match-report pipeline.
//--- Emitted here (after params + constants are final, before side-init) so every key lobby value
//--- is readable. Gated on WFBE_C_MATCH_TELEMETRY (default 1 = additive telemetry ON).
if ((missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0) then {
	private ["_mtStartTowns","_mtDelegation","_mtMaxPlayers","_mtAiEnabled","_mtStatlog","_mtGuer","_mtNaval","_mtOilfield","_mtBuild"];
	_mtStartTowns  = missionNamespace getVariable ["WFBE_C_TOWNS_ACTIVE_MAX", -1];
	_mtDelegation  = missionNamespace getVariable ["WFBE_C_AI_DELEGATION", -1];
	_mtMaxPlayers  = getNumber (missionConfigFile >> "Header" >> "maxPlayers"); //--- A2-OA runtime read: WF_MAXPLAYERS is a preprocessor define (version.sqf) not included in Init_Server.sqf; missionConfigFile>>Header>>maxPlayers is compiled from Rsc/Header.hpp at preprocess time and yields the real slot count.
	_mtAiEnabled   = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", -1];
	_mtStatlog     = missionNamespace getVariable ["WFBE_C_STATLOG", -1];
	_mtGuer        = missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0];
	_mtNaval       = missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 0];
	_mtOilfield    = missionNamespace getVariable ["WFBE_C_OILFIELD_ENABLE", 0];
	//--- Build id: pipe-free short token (same token WASPSCALE uses); avoids the full
	//--- WF_RELEASE_MARKER string which contains pipe chars that would shatter pipe-split parsers.
	_mtBuild       = "build89-cmdcon44";
	diag_log ("MATCH|v1|START|world=" + worldName
		+ "|build=" + _mtBuild
		+ "|towns=" + str _mtStartTowns
		+ "|maxPlayers=" + str _mtMaxPlayers
		+ "|aiEnabled=" + str _mtAiEnabled
		+ "|delegation=" + str _mtDelegation
		+ "|statlog=" + str _mtStatlog
		+ "|guer=" + str _mtGuer
		+ "|naval=" + str _mtNaval
		+ "|oilfield=" + str _mtOilfield);
	["INITIALIZATION", "Init_Server.sqf: MATCH|v1|START| emitted (WFBE_C_MATCH_TELEMETRY=1)."] Call WFBE_CO_FNC_LogContent;
};

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
	if (_weat == 2) then {60 setRain 0.5}; //--- lane199(e): Rainy lobby option now actually sets rain.
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

//--- B62 (Ray 2026-06-21) AIRFIELD FILTER (Bug B): 3 of the 19 LocationLogicStart sit on airfields
//--- (id 278/279=NWAF, id 300=NE) -> HQ/base spawning ON the runway. Drop any candidate within ~1500m of
//--- a map airport anchor, terrain-independent (LocationLogicAirport). A2-OA-safe. GUARD: if the filter
//--- empties the set, keep the unfiltered set (never zero candidates).
//--- Build84 (backlog#2): SKIPPED when WFBE_C_BASE_RANDOM_PURE==1 (Miksuu-original unfiltered pure-random).
if ((missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 0) then {
private ["_b62_airports","_b62_filtered","_s"];
_b62_airports = nearestObjects [[7680,7680,0], ["LocationLogicAirport"], 99999];
//--- A2-OA 1.64: 'ARRAY select {CODE}' is A3-only (see Server_CounterBattery.sqf:101) -> explicit filter loop.
_b62_filtered = [];
{
	_s = _x;
	if (({ (getPos _s) distance (getPos _x) < 1500 } count _b62_airports) == 0) then {
		_b62_filtered set [count _b62_filtered, _s];
	};
} forEach _locationLogics;
if (count _b62_filtered > 0) then {
	_locationLogics = _b62_filtered;
	["INITIALIZATION", Format ["Init_Server.sqf: B62 airfield filter kept %1 start candidates (dropped %2 on/near airfields).", count _b62_filtered, count _b62_airports]] Call WFBE_CO_FNC_LogContent;
} else {
	["WARNING", "Init_Server.sqf: B62 airfield filter emptied the candidate set - keeping the unfiltered starts."] Call WFBE_CO_FNC_LogContent;
};
};

//--- B66 (Ray 2026-06-21) STABLE ROTATION KEY: the B62 rotation keyed on `str _x` of an unnamed
//--- LocationLogicStart - the engine's str of an editor logic embeds a TRANSIENT object id that differs
//--- every fresh dedicated process, so the persisted WFBE_LAST_START_W/E never matched the next match's
//--- objects = the exclusion was a no-op (same dead spawn the B62 marker fix already saw). Key instead on
//--- the start's ROUNDED map position: LocationLogicStart objects are static editor placements, so their
//--- position is byte-identical every match = a durable cross-restart key. A2-OA-safe (plain str/round/+).
WFBE_FNC_B66_StartKey = {
	private ["_p"];
	//--- A2-OA: getPos on a non-object array throws (MEMORY gotcha). Accept only real objects; the
	//--- absent-side placeholder _startW/_startE = [0,0,0] (an ARRAY) and any nil/null return "" (never matched).
	if (typeName _this != "OBJECT") exitWith {""};
	if (isNull _this) exitWith {""};
	_p = getPos _this;
	if (typeName _p != "ARRAY" || {count _p < 2}) exitWith {""};
	(str (round (_p select 0))) + "_" + (str (round (_p select 1)))
};

//--- B62/B66 ROTATION: exclude the WEST/EAST start keys used last match (persisted in profileNamespace as
//--- the stable rounded-position key above) so the random draw varies match-to-match beyond the B57
//--- RNG-advance. Fall back to the full filtered set if exclusion would empty it.
//--- A2-OA-safe: plain string-compare via the stable key + == (no A3-only equality/search/random commands).
//--- Build84 (backlog#2): SKIPPED when WFBE_C_BASE_RANDOM_PURE==1 (Miksuu-original unfiltered pure-random).
if ((missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 0) then {
private ["_b62_lastW","_b62_lastE","_b62_rotPool","_id"];
_b62_lastW = profileNamespace getVariable ["WFBE_LAST_START_W", ""];
_b62_lastE = profileNamespace getVariable ["WFBE_LAST_START_E", ""];
//--- A2-OA 1.64: 'ARRAY select {CODE}' is A3-only -> explicit filter loop.
_b62_rotPool = [];
{
	_id = _x call WFBE_FNC_B66_StartKey; //--- B66: stable rounded-pos key (was `str _x` transient id)
	if (!((_id == _b62_lastW) || (_id == _b62_lastE))) then {
		_b62_rotPool set [count _b62_rotPool, _x];
	};
} forEach _locationLogics;
if (count _b62_rotPool > 1) then {
	_locationLogics = _b62_rotPool;
	["INITIALIZATION", Format ["Init_Server.sqf: B62/B66 rotation excluded last-used starts -> %1 candidates remain.", count _b62_rotPool]] Call WFBE_CO_FNC_LogContent;
};
};

//--- BUILD88 (cmdcon43-f, Ray 2026-07-02) TOWN-CLEARANCE FILTER: Build86's spawn rework validated pair
//--- separation/egress but NOT town-radius clearance, so some LocationLogicStart candidates sit INSIDE a
//--- town's own range (600m, see Common\Init\Init_Town.sqf) -> the match-start HQ deploys on top of a town
//--- (Ray live-report B87, both maps). Drop any start candidate whose distance to the NEAREST town centre is
//--- below (townRange + WFBE_C_BASE_TOWN_CLEAR_MARGIN). Margin default 120 = WFBE_C_BASE_HQ_BUILD_RANGE, so
//--- the HQ's close build ring clears the town zone; threshold 600+120 = 720m. Modelled on the B62 airfield
//--- filter idiom: explicit loops (no A3 'select {CODE}'/isEqualTo), and the SAME never-empty GUARD - if the
//--- filter would empty the candidate set, keep the unfiltered set (placement > perfect clearance). Uses the
//--- live 'towns' array + each town's per-object "range" var (nil-safe fallback 600), so it is authoritative
//--- on BOTH maps from this one mirror-managed change. Skipped under WFBE_C_BASE_RANDOM_PURE==1 (Miksuu-
//--- original unfiltered pure-random), consistent with the B62/B66 filters above.
if ((missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 0) then {
	private ["_tcMargin","_tcFiltered","_s","_sPos","_tooClose","_tw","_twPos","_twRange","_twClear"];
	_tcMargin = missionNamespace getVariable ["WFBE_C_BASE_TOWN_CLEAR_MARGIN", 120];
	_tcFiltered = [];
	{
		_s = _x;
		_sPos = getPos _s;
		_tooClose = false;
		{
			_tw = _x;
			if (isNil {_tw getVariable "wfbe_inactive"} || {!(_tw getVariable "wfbe_inactive")}) then {
				_twPos = getPos _tw;
				_twRange = _tw getVariable "range";
				if (isNil "_twRange") then {_twRange = 600};
				_twClear = _twRange + _tcMargin;
				if ((_sPos distance _twPos) < _twClear) then {_tooClose = true};
			};
		} forEach towns;
		if (!_tooClose) then {_tcFiltered set [count _tcFiltered, _s]};
	} forEach _locationLogics;
	if (count _tcFiltered > 0) then {
		["INITIALIZATION", Format ["Init_Server.sqf: BUILD88 town-clearance filter kept %1 start candidates (dropped %2 within townRange+%3m of a town centre).", count _tcFiltered, (count _locationLogics) - (count _tcFiltered), _tcMargin]] Call WFBE_CO_FNC_LogContent;
		diag_log format ["## SPAWNCHK: town-clearance filter kept %1 of %2 start candidates (margin=%3, drop<townRange+margin).", count _tcFiltered, count _locationLogics, _tcMargin];
		_locationLogics = _tcFiltered;
	} else {
		["WARNING", "Init_Server.sqf: BUILD88 town-clearance filter emptied the candidate set - keeping the unfiltered starts (placement > clearance)."] Call WFBE_CO_FNC_LogContent;
		diag_log "## SPAWNCHK: town-clearance filter would EMPTY the pool - kept unfiltered starts (check start layout vs towns).";
	};
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
	//--- B66: default LOWERED 3->2 (the Constants owner sets WFBE_C_BASE_MIN_EGRESS_ROADS=2) so the egress
	//--- gate stops collapsing the candidate pool to a single corner. If a later relaxation pass (below) finds
	//--- too few candidates even at 2, WFBE_B66_EGRESS_RELAX drops the requirement by a further step so the
	//--- pool is NEVER reduced to 1 (start variety > strict egress on a thin map). Server-local, never broadcast.
	_minRoads = missionNamespace getVariable ["WFBE_C_BASE_MIN_EGRESS_ROADS", 2];
	_minRoads = _minRoads - (missionNamespace getVariable ["WFBE_B66_EGRESS_RELAX", 0]);
	if (_minRoads < 1) then {_minRoads = 1};
	_margin   = missionNamespace getVariable ["WFBE_C_BASE_EDGE_MARGIN", 400];

	//--- Reject candidates hugging any map edge (corner-box guard).
	_ws = 15360;  //--- Legacy default: A2 OA has no dynamic map-size command, and Chernarus map size is 15360.
	if ((missionNamespace getVariable ["WFBE_C_BASE_EGRESS_MAP_BOUNDS", 0]) > 0) then {
		_ws = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
		if (_ws < 1) then {_ws = 15360};
	};
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

//--- B66 (Ray 2026-06-21) POOL MEASURE + ANTI-COLLAPSE: count how many of the filtered start candidates
//--- actually survive the egress gate, log it (so the RPT shows the real usable pool - the diagnostic Ray
//--- asked for), and if FEWER THAN 2 distinct candidates pass we cannot even form a WEST/EAST pair -> relax
//--- the egress requirement one step at a time (re-counting) until at least 2 pass or the requirement
//--- bottoms out. This guarantees the random placement loop is never handed a pool of 1 (= identical spawn
//--- every match, the very bug we are fixing). startingDistance(7500) spacing is also large on Chernarus, so
//--- a thin egress-passing pool is realistic. A2-OA-safe (explicit count loop, no A3 commands).
missionNamespace setVariable ["WFBE_B66_EGRESS_RELAX", 0];
//--- Build84 (backlog#2): the egress pool-measure + relax pass is a no-op under WFBE_C_BASE_RANDOM_PURE==1
//--- (the draw-loop egress clauses auto-pass), so SKIP the whole measure/relax to keep the pure path unfiltered.
if ((missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 0) then {
private ["_b66_egressPass","_b66_relax"];
_b66_relax = 0;
_b66_egressPass = 0;
{ if (_x call _egressOK) then {_b66_egressPass = _b66_egressPass + 1} } forEach _locationLogics;
diag_log format ["## B67SPAWN: egress pool measure -> %1 of %2 candidates pass (relax=%3).", _b66_egressPass, count _locationLogics, _b66_relax];
["INITIALIZATION", Format ["Init_Server.sqf: B66 egress pool measure -> %1 of %2 start candidates pass the egress gate (minRoads relax=%3).", _b66_egressPass, count _locationLogics, _b66_relax]] Call WFBE_CO_FNC_LogContent;
while {_b66_egressPass < 2 && {_b66_relax < 2}} do {
	_b66_relax = _b66_relax + 1;
	missionNamespace setVariable ["WFBE_B66_EGRESS_RELAX", _b66_relax];
	_b66_egressPass = 0;
	{ if (_x call _egressOK) then {_b66_egressPass = _b66_egressPass + 1} } forEach _locationLogics;
	["WARNING", Format ["Init_Server.sqf: B66 egress pool too thin - relaxed minRoads by %1 -> now %2 candidates pass (never collapse to 1).", _b66_relax, _b66_egressPass]] Call WFBE_CO_FNC_LogContent;
};
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

//--- B67 (Ray 2026-06-21) PHANTOM-GUER-ORIGIN FIX: in MODE 2 (Random, the live param default) _startG is
//--- never assigned a real position (GUER is base-less; it is only set to _spawn_central in MODE 0/1), so it
//--- stays [0,0,0]. The West/East placement checks below then require EVERY candidate to be >startingDistance
//--- (7500m) from the MAP CORNER [0,0,0] = a whole SW quadrant sterilised, collapsing the viable pool to ~1-2
//--- logics = "always the same 2 spots" (and frequent force-fall to the fixed wfbe_default markers). This is
//--- the real cause behind the 3 prior blind fixes; it WORSENED in B66 because GUER-playable made three-way
//--- active. _guerReal gates the _startG distance check so it only applies when GUER actually has a base.
//--- A2-OA-safe: no isEqualTo; explicit origin test; lazy || {CODE} short-circuit.
private ["_guerReal"];
_guerReal = false;
if (typeName _startG == "OBJECT") then { _guerReal = !(isNull _startG) };
if (typeName _startG == "ARRAY" && {count _startG >= 2}) then { _guerReal = !(((_startG select 0) == 0) && {(_startG select 1) == 0}) };
diag_log format ["## B67SPAWN: mode=%1 threeway=%2 present[W,E,G]=[%3,%4,%5] minDist=%6 candidates=%7 guerReal=%8", missionNamespace getVariable "WFBE_C_BASE_STARTING_MODE", WFBE_ISTHREEWAY, _present_west, _present_east, _present_res, _minDist, _total, _guerReal];

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
		if (!_setWest && !_setEast && !_setGuer) exitWith {diag_log format ["## B67SPAWN: all sides placed [random] after %1 attempts.", _i]; ["INITIALIZATION", "Init_Server.sqf : All sides were placed [Random]."] Call WFBE_CO_FNC_LogContent};

		//--- Determine west starting location if necessary.
		if (_setWest) then {
			_rPosW = _locationLogics select floor(random _total);
			//--- Egress-quality gate (EAST-EGRESS fix): require distance spacing AND a usable egress road
			//--- network clear of the map edges. Symmetric with east. Fallback below still guarantees placement.
			if (_rPosW distance _startE > _minDist && {!_guerReal || {_rPosW distance _startG > _minDist}} && {(missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 1 || {_rPosW call _egressOK}}) then {_startW = _rPosW; _setWest = false};
		};

		// --- Determine west starting location if necessary.
		if (_setEast) then {
			_rPosE = _locationLogics select floor(random _total);
			if (_rPosE distance _startW > _minDist && {!_guerReal || {_rPosE distance _startG > _minDist}} && {(missionNamespace getVariable ["WFBE_C_BASE_RANDOM_PURE", 0]) == 1 || {_rPosE call _egressOK}}) then {_startE = _rPosE; _setEast = false};
		};

		_i = _i + 1;

		if (_i >= _maxAttempts) exitWith {
			//--- B67 (Ray 2026-06-21) NON-DEGENERATE FORCE-FALL: the legacy fallback picks the two FIXED
			//--- wfbe_default markers (id297/id300) = the exact "same 2 spots" we are fixing, so an unlucky
			//--- 2000-attempt seed could still reproduce the bug. First try to draw a spaced, egress-OK pair
			//--- from the live filtered pool so even a force-fall varies match-to-match; the fixed wfbe_default
			//--- markers stay the last resort. A2-OA-safe (explicit loops, isNull guards, no A3 commands).
			private ["_ffPool","_ffW","_ffE"];
			_ffPool = [];
			{ if (_x call _egressOK) then { _ffPool set [count _ffPool, _x] } } forEach _locationLogics;
			if (count _ffPool < 2) then { _ffPool = +_locationLogics }; //--- never operate on an empty pool
			_ffW = objNull;
			_ffE = objNull;
			if (count _ffPool > 0) then {
				_ffW = _ffPool select floor(random (count _ffPool));
				_ffPool = _ffPool - [_ffW];
			};
			//--- partner spaced >_minDist from _ffW; accept any remaining if none is spaced.
			{
				if (isNull _ffE && {!(isNull _ffW)} && {_x distance _ffW > _minDist}) then { _ffE = _x };
			} forEach _ffPool;
			if (isNull _ffE && {count _ffPool > 0}) then { _ffE = _ffPool select floor(random (count _ffPool)) };

			//--- Get the default locations (legacy last-resort).
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

			//--- B67: prefer the varied pool draw over the fixed wfbe_default markers when available.
			if (!(isNull _ffW)) then { _westDefault = _ffW };
			if (!(isNull _ffE)) then { _eastDefault = _ffE };

			// --- Ensure that everything is set, otherwise we randomly set the spawn.
			if (isNull _eastDefault || isNull _westDefault) then {
				Private ["_tempWork"];
				_tempWork = +(startingLocations) - [_westDefault, _eastDefault];
				//--- B62 (Ray 2026-06-21) INDEX BUG: index _tempWork by (count _tempWork), NOT _total
					//--- (=count _locationLogics) - a size mismatch that could index out of range / pick a filtered-out start.
					if (isNull _eastDefault && _present_east) then {_eastDefault = _tempWork select floor(random (count _tempWork)); _tempWork = _tempWork - [_eastDefault]};
				if (isNull _westDefault && _present_west) then {_westDefault = _tempWork select floor(random (count _tempWork)); _tempWork = _tempWork - [_westDefault]};
			};

			if (_present_east && !_skip_e) then {_startE = _eastDefault};
			if (_present_west && !_skip_w) then {_startW = _westDefault};

			diag_log format ["## B67SPAWN: FORCE-FALL after %1 attempts; varied-pool used W=%2 E=%3 (fixed wfbe_default avoided when pool usable).", _i, !(isNull _ffW), !(isNull _ffE)];
			["INITIALIZATION", "Init_Server.sqf : All sides were placed by force after that the attempts limit was reached."] Call WFBE_CO_FNC_LogContent;
		};
	};
};

//--- B62/B66 (Ray 2026-06-21) ROTATION persist: store the chosen WEST/EAST start keys (STABLE rounded-pos
//--- key via WFBE_FNC_B66_StartKey, matching the exclusion filter above) so NEXT match's draw avoids them =
//--- guaranteed match-to-match start variety. saveProfileNamespace is already used in the random block above.
//--- A2-OA-safe. NOTE: _startW/_startE are LocationLogicStart objects when randomly placed; in MODE 0/1 they
//--- can be the named spawn logics, which also resolve to a stable position key.
//--- B66: gate on the (object-safe) key being non-empty rather than isNull - _startW/_startE may be the
//--- [0,0,0] ARRAY placeholder for an absent side, and isNull on an array is unsafe in A2-OA.
private ["_keyW","_keyE"];
_keyW = _startW call WFBE_FNC_B66_StartKey;
_keyE = _startE call WFBE_FNC_B66_StartKey;
if (_keyW != "") then { profileNamespace setVariable ["WFBE_LAST_START_W", _keyW] };
if (_keyE != "") then { profileNamespace setVariable ["WFBE_LAST_START_E", _keyE] };
saveProfileNamespace;
diag_log format ["## B67SPAWN: chosen start keys W=%1 E=%2 (rounded map pos; should vary match-to-match).", _keyW, _keyE];

//--- 185 (HQ repair scaling): read rolling avg round length from profileNamespace and broadcast.
private ["_rpavg185","_rpN185","_rpTotal185"];
_rpavg185 = profileNamespace getVariable ["WFBE_RPAVG", [0, 0]];
_rpN185     = _rpavg185 select 0;
_rpTotal185 = _rpavg185 select 1;
WFBE_HQ_REPAIR_AVG_SEC = if (_rpN185 > 0) then {_rpTotal185 / _rpN185} else {21600};
publicVariable "WFBE_HQ_REPAIR_AVG_SEC";
["INITIALIZATION", Format ["Init_Server.sqf: HQ repair avg = %1s from %2 recorded rounds (seed 21600 when none).", round WFBE_HQ_REPAIR_AVG_SEC, _rpN185]] Call WFBE_CO_FNC_LogContent;


//--- BUILD88 (cmdcon43-f, Ray 2026-07-02) SPAWNCHK REGRESSION GUARD: the town-clearance filter above should
//--- have kept every chosen start clear of town ranges, but a force-fall / pure-random / MODE 0-1 named-spawn
//--- path can still hand back an inside-town start. Log a permanent WARNING line for the ACTUALLY CHOSEN WEST
//--- and EAST starts if either sits within (townRange + margin) of a town centre, so any future regression is
//--- visible in the RPT forever (SPAWNCHK|start=SIDE|town=NAME|dist=D|clear=C). Report-only, never blocks the
//--- match. A2-OA-safe: getPos guarded on OBJECT only (the [0,0,0] absent-side placeholder is skipped).
{
	private ["_sideName","_chosen","_cPos","_tcMargin","_nrTown","_nrDist","_nrRange","_tw","_twPos","_twRange"];
	_sideName = _x select 0;
	_chosen   = _x select 1;
	if (typeName _chosen == "OBJECT" && {!(isNull _chosen)}) then {
		_cPos = getPos _chosen;
		_tcMargin = missionNamespace getVariable ["WFBE_C_BASE_TOWN_CLEAR_MARGIN", 120];
		_nrTown = "?"; _nrDist = 1e12; _nrRange = 600;
		{
			_tw = _x;
			if (isNil {_tw getVariable "wfbe_inactive"} || {!(_tw getVariable "wfbe_inactive")}) then {
				_twPos = getPos _tw;
				_twRange = _tw getVariable "range";
				if (isNil "_twRange") then {_twRange = 600};
				if ((_cPos distance _twPos) < _nrDist) then {
					_nrDist = _cPos distance _twPos;
					_nrRange = _twRange;
					_nrTown = _tw getVariable "name";
					if (isNil "_nrTown") then {_nrTown = "?"};
				};
			};
		} forEach towns;
		if (_nrDist < (_nrRange + _tcMargin)) then {
			["WARNING", Format ["Init_Server.sqf: SPAWNCHK - chosen %1 start is INSIDE town range! start=%1|town=%2|dist=%3|clear=%4", _sideName, _nrTown, round _nrDist, _nrRange + _tcMargin]] Call WFBE_CO_FNC_LogContent;
			diag_log format ["## SPAWNCHK|start=%1|town=%2|dist=%3|clear=%4", _sideName, _nrTown, round _nrDist, _nrRange + _tcMargin];
		} else {
			diag_log format ["## SPAWNCHK|start=%1|town=%2|dist=%3|clear=%4|OK", _sideName, _nrTown, round _nrDist, _nrRange + _tcMargin];
		};
	};
} forEach [["WEST", _startW], ["EAST", _startE]];

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
		_syncAicomState = (missionNamespace getVariable ["WFBE_C_AICOM_PUBLIC_STATE_SYNC", 0]) > 0;
		_logik setVariable ["wfbe_aicom_running", false, _syncAicomState];
		//--- V0.4.1: synthetic MONEY is fine (PvE pacing) - synthetic SUPPLY is not.
		//--- Funds seed = commander start funds x FUNDS_MULT; supply spending stays 100% real.
		_logik setVariable ["wfbe_aicom_funds", (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_START_FUNDS", 200000]), _syncAicomState]; //--- B36 hotfix (Ray): flat 200k AI-commander start cash (was FUNDS_START x FUNDS_MULT)
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
		if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {_vehicle setVariable ["wfbe_balance_side", _side]; (_vehicle) Call BalanceInit};
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
		if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {_vehicle setVariable ["wfbe_balance_side", _side]; (_vehicle) Call BalanceInit};

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
		//--- B74.2.3 TELEMETRY: raw diag_log of the per-side player-team registration count (LogContent is
		//--- filtered on public builds, so the per-team init logs above are invisible). Lets us tell whether
		//--- an empty client clientTeams is because registration produced 0 server-side, or a sync gap.
		diag_log format ["TEAMREG|side=%1|registered=%2|syncedUnits=%3", _side, count _teams, count (synchronizedObjects _logik)];
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

			//--- Radio announcer for playable GUER (claude/guer-radio-announcer). The main sides loop above only
			//--- builds the wfbe_radio_hq speaker for west/east (base-less GUER is registered in this separate block),
			//--- so resistance players never heard the town/camp/hostiles radio calls that BLUFOR/OPFOR get. Mirror the
			//--- west/east announcer setup here on the GUER side logic (WFBE_L_GUE) so Server_SideMessage's kbTell has a
			//--- valid speaker for resistance. Gated identically to the player-team registration (PLAYERSIDE>0 + logic
			//--- present) so it exists exactly when a human GUER player can be listening; the null-speaker guard in
			//--- Server_SideMessage.sqf stays as a safety net. Two Logic units (speaker + receiver), a random announcer
			//--- identity from WFBE_GUER_RadioAnnouncers, and the shared hq.bikb topic - byte-for-byte the same recipe.
			private ["_guer_radio_hq1","_guer_radio_hq2","_guer_announcers","_guer_radio_hq_id"];
			_guer_radio_hq1 = (createGroup sideLogic) createUnit ["Logic",[0,0,0],[],0,"NONE"];
			_guer_radio_hq2 = (createGroup sideLogic) createUnit ["Logic",[0,0,0],[],0,"NONE"];
			[_guer_radio_hq1] joinSilent ([resistance, "misc"] Call WFBE_CO_FNC_CreateGroup);
			[_guer_radio_hq2] joinSilent ([resistance, "misc"] Call WFBE_CO_FNC_CreateGroup);
			_guerLogic setVariable ["wfbe_radio_hq", _guer_radio_hq1, true];
			_guerLogic setVariable ["wfbe_radio_hq_rec", _guer_radio_hq2];

			_guer_announcers = missionNamespace getVariable Format ["WFBE_%1_RadioAnnouncers", resistance];
			_guer_radio_hq_id = (_guer_announcers) select floor(random (count _guer_announcers));
			_guer_radio_hq1 setIdentity _guer_radio_hq_id;
			_guer_radio_hq1 setRank 'COLONEL';
			_guer_radio_hq1 setGroupId ["HQ"];
			_guer_radio_hq1 kbAddTopic [_guer_radio_hq_id, "Client\kb\hq.bikb","Client\kb\hq.fsm", {call compile preprocessFileLineNumbers "Client\kb\hq.sqf"}];
			_guerLogic setVariable ["wfbe_radio_hq_id", _guer_radio_hq_id, true];
			["INITIALIZATION", Format ["Init_Server.sqf: GUER radio announcer initialized [%1] (identity: %2).", _guer_radio_hq1, _guer_radio_hq_id]] Call WFBE_CO_FNC_LogContent;

			//--- B74.2: the GUER stipend/economy execVM was MOVED out of this team-registration block to its own
			//--- isServer+WFBE_C_GUER_PLAYERSIDE gate below (beside the air-def launch). Rationale: the economy loop
			//--- must NOT be coupled to the registration forEach above - a future registration change that errors
			//--- mid-loop would otherwise silently suppress the entire GUER economy (no stipend, no vehicle tiers).
			//--- The stipend self-gates (isServer + PLAYERSIDE) and self-waits (towns + WFBE_L_GUE) internally,
			//--- exactly like Server_GuerAirDef.sqf, so launching it independently is safe and strictly more robust.
			//--- B62 (Ray 2026-06-21): the GUER air-def execVM was likewise moved out of this block to its own gate
			//--- below (keyed on isServer + WFBE_C_GUER_AIRDEF_ENABLE) - GUER is ALWAYS the AI town-defender, so its
			//--- air must run even when the playable-side param is 0.
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

//--- B62 (Ray 2026-06-21): GUER AIR DEFENSE (moved out of the WFBE_C_GUER_PLAYERSIDE block). GUER is always
//--- the AI town-defender (the script loop is keyed off town sideID==GUER), so this must run in production
//--- where the playable-side param is 0. Gated only on isServer (this file already runs server-side) +
//--- WFBE_C_GUER_AIRDEF_ENABLE. The loop self-guards isServer/AIRDEF_ENABLE internally too. A2-OA-safe.
if (isServer && {(missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_ENABLE", 1]) > 0}) then {
	[] execVM "Server\Server_GuerAirDef.sqf";
	["INITIALIZATION", "Init_Server.sqf: B62 GUER air-def loop launched (un-gated from PLAYERSIDE)."] Call WFBE_CO_FNC_LogContent;
};

//--- TOWN GARRISON DRESSING (lane 241, fable/qol-recycle-pick): ZU-23 dressing on active
//--- contested GUER-held towns. Server-only, default 0 = worker not launched.
if (isServer && {(missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING", 0]) > 0}) then {
	[] execVM "Server\Server_TownGarrisonDressing.sqf";
	["INITIALIZATION", "Init_Server.sqf: GUER garrison dressing loop launched."] Call WFBE_CO_FNC_LogContent;
};

//--- B74.2: GUER player ECONOMY (per-minute stipend + vehicle-tier broadcast). MOVED here from the GUER
//--- team-registration block above so a registration error can't silently suppress the economy (same decoupling
//--- rationale as the air-def launch). Gated on isServer + WFBE_C_GUER_PLAYERSIDE (the playable-side param); the
//--- loop self-waits for towns + WFBE_L_GUE internally, so it is safe to launch independently of registration.
if (isServer && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {
	[] execVM "Server\Server_GuerStipend.sqf";
	["INITIALIZATION", "Init_Server.sqf: B74.2 GUER stipend/economy loop launched (decoupled from team-registration)."] Call WFBE_CO_FNC_LogContent;
};

//--- EDITOR-SLOT SWEEP (2026-06-15; group-cap reclaim 2026-06-29): the 27 WEST + 27 EAST editor-placed
//--- player-slot groups in mission.sqm are born by the engine at load with no createGroup, so
//--- WFBE_CO_FNC_CreateGroup never tags them and they show as "untagged" in the server_groupsGC audit -
//--- indistinguishable from genuinely leaked groups. Of those, ~13/side are "overflow" slots whose unit
//--- self-deletes at load (mission.sqm init="... deleteVehicle this"), leaving an EMPTY group that still
//--- permanently occupies one of the 144 per-side group slots. One-shot sweep: REAP the empty overflow
//--- groups (reclaim ~13/side headroom; they are unsynced + never enter wfbe_teams, so nothing references
//--- them) and TAG the remaining active player-slot groups "editor-player-slot" (broadcast) so the audit
//--- can tell them from leaks. Active groups carry wfbe_persistent=true so the GC never reaps them; the
//--- tag is audit-only. The isNil guard skips any runtime group the wrapper already tagged. GUER included.
if (isNil "WFBE_EDITOR_GROUPS_TAGGED") then {
	missionNamespace setVariable ["WFBE_EDITOR_GROUPS_TAGGED", true];
	{
		Private ["_src"];
		_src = _x getVariable "wfbe_group_src";
		if (isNil "_src" && {(side _x == west) || (side _x == east) || (side _x == resistance)}) then {
			//--- cmdcon30 (Ray 2026-06-30): the PR#122 reap (deleteGroup of EMPTY WEST/EAST/resistance editor
			//--- groups for group-cap headroom) deleted empty-but-JIP-SELECTABLE player-slot groups -> a joiner
			//--- landed in a deleted group -> no wfbe_side -> enrollment exhausted (B746 x3) -> DEADSPAWN.
			//--- REMOVED entirely (back to pre-PR122 audit-only tagging): the empty overflow slots ran the whole
			//--- pre-PR122 history with no group-cap problem, and the only safe reap would skip them anyway (they
			//--- carry wfbe_persistent). Never delete a JIP-selectable slot group at boot.
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

//--- fable/deadspawn-redesign (landlocked follow-up): build the sealed landlocked-pen cell
//--- IF this map's resolved pen point is dry (Takistan/Zargabad; no-op + log-only on a water
//--- map like Chernarus). Flag-gated so this never runs while the redesign is off - the wall-
//--- pen call above is untouched and remains the unconditional flag-off baseline.
if ((missionNamespace getVariable ["WFBE_C_DEADSPAWN_REDESIGN", 0]) > 0) then {
	[] execVM "Server\Init\Init_DeadspawnPenEnclosure.sqf";
};

//--- NAVAL HVT: spawn offshore assets + register towns + start CAP loops (feat/naval-hvt-objectives).
//--- Runs AFTER townInit (it calls waitUntil {townInit} internally), so no ordering conflict.
if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) == 1) then {
	[] execVM "Server\Init\Init_NavalHVT.sqf";
	["INITIALIZATION", "Init_Server.sqf: Init_NavalHVT.sqf launched (WFBE_C_NAVAL_HVT=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- USV FLOTILLA: 3-boat GUER coastal flotilla (AA/Rocket/HMG), gated on coastal-town-active OR
//--- naval-HVT-carrier-approach (fable/usv-flotilla, owner 2026-07-08). Own flag, independent of
//--- WFBE_C_NAVAL_HVT so it can be reverted without touching the carrier feature.
if ((missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_ENABLE", 0]) == 1) then {
	[] execVM "Server\Server_USVFlotilla.sqf";
	["INITIALIZATION", "Init_Server.sqf: Server_USVFlotilla.sqf launched (WFBE_C_USV_FLOTILLA_ENABLE=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02): compiles the TEL spawn/fire functions + gates on
//--- WFBE_C_ICBM_TEL. Same launch pattern as Init_NavalHVT above. The TEL itself is spawned per side when that
//--- side COMPLETES the ICBM upgrade (hook in Server_ProcessUpgrade.sqf), NOT at boot, so it appears with the tech.
if ((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) == 1) then {
	[] execVM "Server\Init\Init_IcbmTel.sqf";
	["INITIALIZATION", "Init_Server.sqf: Init_IcbmTel.sqf launched (WFBE_C_ICBM_TEL=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- ZG KOTH (fable/radius-hold-primitive consumer, GR-2026-07-08a, stacked on PR #916): Zargabad-only
//--- King-of-the-Hill city-core radius-hold. Feature-flagged behind WFBE_C_ZG_KOTH_ENABLE (default 0);
//--- additionally map-gated to Zargabad inside Init_ZgKoth.sqf itself. Same launch pattern as the
//--- NAVAL_HVT/ICBM_TEL blocks above.
if ((missionNamespace getVariable ["WFBE_C_ZG_KOTH_ENABLE", 0]) == 1) then {
	[] execVM "Server\Init\Init_ZgKoth.sqf";
	["INITIALIZATION", "Init_Server.sqf: Init_ZgKoth.sqf launched (WFBE_C_ZG_KOTH_ENABLE=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- OILFIELDS (Ray 2026-07-01, Takistan): neutral capturable resource node (NOT a town — no town FSM).
//--- Map-gated to Takistan inside the file (worldName check), plus the WFBE_C_OILFIELD_ENABLE flag (default 1).
//--- The file self-waits townInit and self-gates internally, so launching it here is safe + strictly additive.
if ((missionNamespace getVariable ["WFBE_C_OILFIELD_ENABLE", 1]) == 1 && {toLower worldName == "takistan"}) then {
	[] execVM "Server\Server_Oilfields.sqf";
	["INITIALIZATION", "Init_Server.sqf: Server_Oilfields.sqf launched (WFBE_C_OILFIELD_ENABLE=1, Takistan)."] Call WFBE_CO_FNC_LogContent;
};

//--- Lane 180 ambient skirmish cells: default-off, server-only flavor loop with a hard cap of one active
//--- WEST/EAST foot skirmish. The worker self-waits for towns and self-cleans its groups.
if ((missionNamespace getVariable ["WFBE_C_AMBIENT_SKIRMISH", 0]) > 0) then {
	[] execVM "Server\Server_AmbientSkirmish.sqf";
	["INITIALIZATION", "Init_Server.sqf: Server_AmbientSkirmish.sqf launched (WFBE_C_AMBIENT_SKIRMISH=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- AICOM V2 Lane 800: GUER Director (virtual resistance ledger + lightweight brain).
//--- Gated on AICOMV2_LANE_GUER_DIRECTOR (default 0 = inert). With flag 0 this launch block is byte-identical to V1.
if (isServer && {(missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0}) then {
	[] execVM "Server\AI\Server_GuerDirector.sqf";
	["INITIALIZATION", "Init_Server.sqf: GUER Director (lane 800) launched (AICOMV2_LANE_GUER_DIRECTOR=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- Commander Town Ledger (fable/ctl-impl-v1): virtual per-town strength ledger + paid
//--- AI investment for WEST/EAST towns. Gated on AICOMV2_LANE_CMD_TOWN_LEDGER (default 0).
if (isServer && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
	[] execVM "Server\AI\Server_CmdTownLedger.sqf";
	["INITIALIZATION", "Init_Server.sqf: Commander Town Ledger launched (AICOMV2_LANE_CMD_TOWN_LEDGER=1)."] Call WFBE_CO_FNC_LogContent;
};

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
[] ExecVM "Server\server_heli_terrain_guard.sqf"; //--- qol-polish-pack: AI-heli terrain look-ahead climb (self-gates on WFBE_C_AIHELI_TERRAIN_GUARD, default ON) - SERVER-LOCAL air incl. non-team paradrop/supply/GUER/W13.
//--- AICOM HELI TERRAIN-GUARD twin (cmdcon41-w3j 2026-07-02): the bounded wfbe_teams-scoped guard covering AICOM
//--- helicopter TEAMS wherever they are local. On the server this catches server-local founded air teams (no-HC
//--- fallback); the same file is spawned on each HC (Init_HC.sqf) for the delegated teams that are the live case.
//--- Reuses the server guard's look-ahead climb verbatim; shares WFBE_C_AIHELI_TERRAIN_GUARD (default ON). A hull
//--- covered by both server loops is harmless (both only raise flyInHeight, never lower it).
[] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_HeliTerrainGuard.sqf";

//--- AICOM SMALL-ARMS x AIR ENGAGEMENT ENVELOPE (fable/smallarms-air-envelope): per-machine steering loop that
//--- clears a NON-AA unit's lock on an aircraft it cannot damage when the aircraft is beyond the effective range
//--- (WFBE_C_SMALLARMS_AIR_ENVELOPE, default 0 = OFF -> self-exits, byte-identical to HEAD). Runs on server + each
//--- HC (same file, Init_HC.sqf) touching only LOCAL units. NOT sim-gating: unit<->target range, sim never frozen.
[] spawn Compile preprocessFileLineNumbers "Common\Functions\Common_AICOM_SmallArmsAirEnvelope.sqf";

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
			+ "|permDay=" + str (missionNamespace getVariable ["WFBE_C_PERMANENT_DAY", 0])
			+ "|daytime=" + str (round (daytime * 100) / 100)
			+ "|sun=" + str (round (sunOrMoon * 100) / 100)
			+ "|srvFps=" + str (round diag_fps)
			+ "|t=" + str (round (time / 60))
			+ "|name=" + (_d select 1));
	};
	["INITIALIZATION", "Init_Server.sqf: Client FPS telemetry receiver armed (WFBE_C_CLIENT_FPS_REPORT=1)."] Call WFBE_CO_FNC_LogContent;
};

//--- B74.2 (Ray 2026-06-23): OWN-SIDE MARKER FEED-GAP RECOVERY (the recurring "my player marker gone").
//--- A publicVariable is NOT JIP-durable in A2-OA, and the B63 connect catch-up (Server_OnPlayerConnected
//--- targeted publicVariableClient) can be MISSED on some joins (it races the connect/init path). When that
//--- happens the joiner's WFBE_ACTIVE_AICOM_TEAMS / WFBE_ACTIVE_PATROLS stay empty for the first ~60s and the
//--- own-side commander-team + patrol arrows never draw. updateaicommarkers.sqf now REQUESTS a rebroadcast when
//--- its feed is still empty after the init gate (publicVariableServer "WFBE_ReqAicomFeed" carrying the player
//--- object). Resolve `owner _player` to the network id and push BOTH feeds straight back to exactly that client -
//--- the SAME proven targeted-reply pattern as REQUEST_SUPPLY_VALUE (Server_PV_RequestSupplyValue.sqf). Unconditional
//--- (always armed); server_side_patrols also re-broadcasts every ~20s as a safety net.
"WFBE_ReqAicomFeed" addPublicVariableEventHandler {
	private ["_player","_id"];
	_player = _this select 1;
	if (isNull _player) exitWith {};
	_id = owner _player;
	if (!isNil "WFBE_ACTIVE_AICOM_TEAMS") then {_id publicVariableClient "WFBE_ACTIVE_AICOM_TEAMS"};
	if (!isNil "WFBE_ACTIVE_PATROLS") then {_id publicVariableClient "WFBE_ACTIVE_PATROLS"};
	diag_log format ["[WFBE][B74.2 REQ-MARK] rebroadcast marker feeds to requester %1 (aicom=%2, patrols=%3).", _id, count (missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []]), count (missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []])];
};
["INITIALIZATION", "Init_Server.sqf: B74.2 WFBE_ReqAicomFeed handler armed (own-side marker feed-gap recovery)."] Call WFBE_CO_FNC_LogContent;

//--- fable/marker-classtag-jip (owner 2026-07-09): wfbe_player_class is broadcast once (client-side
//--- setVariable [...,true] in Skill_Init / SkinSelector_Apply / Client_PreRespawnHandler) and is NOT
//--- JIP-durable in A2-OA, so a joiner permanently reads "" for every player who set their class BEFORE
//--- the join -> the "[ENG]" class tag silently vanishes on those players' map markers (name tags read
//--- incomplete). Mirror the proven WFBE_ReqAicomFeed catch-up: on request, re-assert every connected
//--- player's class globally so the requester (and everyone) re-receives it. Rare (JIP feed-gap only);
//--- a handful of small object-var writes. The server holds each value (setVariable-true reaches it too).
"WFBE_ReqPlayerClasses" addPublicVariableEventHandler {
	private "_n";
	_n = 0;
	{
		if (isPlayer _x) then {
			_x setVariable ["wfbe_player_class", (_x getVariable ["wfbe_player_class", ""]), true];
			_n = _n + 1;
		};
	} forEach playableUnits;
	diag_log format ["[WFBE][classtag-jip] re-broadcast %1 player classes on request.", _n];
};
["INITIALIZATION", "Init_Server.sqf: fable classtag-jip WFBE_ReqPlayerClasses handler armed (marker class-tag JIP recovery)."] Call WFBE_CO_FNC_LogContent;

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

//--- DELEGHEALTH v2 (fable/deleghealth-v2, 2026-07-10): stateful AI-only delegation-health telemetry.
//--- Truthful replacement for the structurally-unfireable DELEGATION-DEAD predicate (server_groupsGC.sqf,
//--- which stays untouched): 60s AI-only per-owner tally + HCStat heartbeat freshness + hysteretic
//--- HEALTHY/DEGRADED/COLLAPSED states, RPT lines only. Flag default 0 = the loop never spawns.
if ((missionNamespace getVariable ["WFBE_C_DELEGHEALTH", 0]) > 0) then {
	[] execVM "Server\FSM\server_deleghealth.sqf";
	["INITIALIZATION", "Init_Server.sqf: Delegation-health telemetry FSM is initialized."] Call WFBE_CO_FNC_LogContent;
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
	["SET_MAP", 3] call WFBE_SE_FNC_CallDatabaseSetMap;
};

_logMatchWinPlayerCountThreshold = 10;

//--- Default so low-pop/AI rounds don't leave it undefined (Server_LogGameEnd reads it at every match end); the >=threshold path overwrites it later.
WFBE_Server_LogMatchWin = false;

[_logMatchWinPlayerCountThreshold] execVM "Server\MonitorPlayerCount.sqf";

WFBE_SE_PLAYERLIST = [[objNull, "0"]];

{_x Spawn WFBE_SE_FNC_VoteForCommander} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: harass-only, no commander election

//--- feat/ai-commander: one always-running supervisor per side (self-gates on enabled + no player commander).
{
	private ["_aicomID","_aicomOwnerKey","_aicomOwnerSeq","_aicomHandle"];
	_aicomID = _x Call WFBE_CO_FNC_GetSideID;
	_aicomOwnerKey = Format ["wfbe_aicom_owner_%1", _aicomID];
	_aicomOwnerSeq = (missionNamespace getVariable [_aicomOwnerKey, 0]) + 1;
	missionNamespace setVariable [_aicomOwnerKey, _aicomOwnerSeq];
	_aicomHandle = [_x, _aicomOwnerSeq] Spawn WFBE_SE_FNC_AI_Commander;
	missionNamespace setVariable [Format ["wfbe_aicom_handle_%1", _aicomID], _aicomHandle];
} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: no HQ, loop was inert (perf win)

//--- B69 AICOM SUPERVISOR WATCHDOG: a single standalone loop that re-Spawns a per-side
//--- supervisor whose heartbeat has gone stale (uncaught error killed its while-loop).
//--- Self-limiting against double-spawn: watchdog terminates the stored stale handle, then
//--- bumps a per-side owner generation before restart. Any stale supervisor that somehow
//--- resumes sees the newer owner and exits before its next tick. A per-side cooldown also
//--- bars a second restart inside the recovery window.
if ((missionNamespace getVariable ["WFBE_C_AICOM_WATCHDOG", 1]) > 0) then {
	[] Spawn {
		private ["_scan","_cool","_stale","_x","_myID","_hb","_lastR","_thresh","_age","_ownerKey","_ownerSeq","_hKey","_oldHandle","_newHandle"];
		waitUntil {sleep 1; !(isNil "serverInitFull")};
		_scan = missionNamespace getVariable ["WFBE_C_AICOM_WATCHDOG_SCAN", 30];
		_cool = missionNamespace getVariable ["WFBE_C_AICOM_WATCHDOG_COOLDOWN", 120];
		//--- generous threshold: 3 healthy ticks + 30s margin (75s at default TICK=15). No
		//--- healthy tick blocks >TICK, so this never false-trips on a normal slow tick.
		_thresh = (3 * (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TICK", 15])) + 30;
		while {!gameOver} do {
			sleep _scan;
			{
				_myID = _x Call WFBE_CO_FNC_GetSideID;
				_hb   = missionNamespace getVariable [Format ["wfbe_aicom_hb_%1", _myID], -1];
				//--- _hb > 0 means the supervisor has stamped at least once: never fire during
				//--- the boot / serverInitFull wait (the loop hasn't reached its first stamp yet).
				if (_hb > 0) then {
					_age   = time - _hb;
					_stale = _age > _thresh;
					_lastR = missionNamespace getVariable [Format ["wfbe_aicom_wd_restart_%1", _myID], -1e9];
					if (_stale && {(time - _lastR) > _cool}) then {
						missionNamespace setVariable [Format ["wfbe_aicom_wd_restart_%1", _myID], time];
						_ownerKey = Format ["wfbe_aicom_owner_%1", _myID];
						_ownerSeq = (missionNamespace getVariable [_ownerKey, 0]) + 1;
						missionNamespace setVariable [_ownerKey, _ownerSeq];
						_hKey = Format ["wfbe_aicom_handle_%1", _myID];
						_oldHandle = missionNamespace getVariable _hKey;
						if (!isNil "_oldHandle") then {
							if !(scriptDone _oldHandle) then {terminate _oldHandle};
						};
						_newHandle = [_x, _ownerSeq] Spawn WFBE_SE_FNC_AI_Commander;
						missionNamespace setVariable [_hKey, _newHandle];
						diag_log ("AICOMSTAT|v1|EVENT|" + (str _x) + "|" + str (round (time / 60)) + "|WATCHDOG|restart-stale-hb age=" + str (round _age) + "|owner=" + str _ownerSeq);
						["WARNING", Format ["AICOM watchdog: %1 supervisor heartbeat stale (%2s) - restarting with owner generation %3.", str _x, round _age, _ownerSeq]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			} forEach (WFBE_PRESENTSIDES - [resistance]);
		};
	};
	["INITIALIZATION", "Init_Server.sqf: AICOM supervisor watchdog started (B69)."] Call WFBE_CO_FNC_AICOMLog;
};

//--- V0.6: AI Commander Wildcard events (one free random event per AI side per interval).
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD", 1]) == 1 && {(missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0}) then {
	{_x Spawn WFBE_SE_FNC_AI_Commander_Wildcard} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER runs its OWN base-less deck below (AI_Commander_Wildcard_GUER), not this HQ/funds-based worker
	["INITIALIZATION", Format ["Init_Server.sqf: AI Commander Wildcard workers started for %1 sides (interval=%2s).", count WFBE_PRESENTSIDES, missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL", 1800]]] Call WFBE_CO_FNC_AICOMLog;
};

//--- GUER (resistance) Wildcard events — base-less insurgent deck (Ray 2026-06-27). Independent of the
//--- AI-commander gate (GUER has no commander); needs only resistance present + the toggle. Pays GUER
//--- PLAYERS directly (see AI_Commander_Wildcard_GUER.sqf). All server-side; no client files added.
if ((missionNamespace getVariable ["WFBE_C_GUER_WILDCARD", 1]) == 1 && {resistance in WFBE_PRESENTSIDES}) then {
	[] Spawn WFBE_SE_FNC_AI_Commander_Wildcard_GUER;
	["INITIALIZATION", Format ["Init_Server.sqf: GUER Wildcard worker started (interval=%1s).", missionNamespace getVariable ["WFBE_C_GUER_WILDCARD_INTERVAL", 1800]]] Call WFBE_CO_FNC_AICOMLog;
};

// Marty: Start the accelerated day/night cycle only when the mission parameter enables it.
if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) then {
	[] execVM "Server\Functions\Server_DayNightCycle.sqf";
};

["INITIALIZATION", Format ["Init_Server.sqf: Server initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;

//--- HC CIV cosmetic reslot safe-window (flag WFBE_C_HC_CIV_RESLOT, fable/hc-civ-reslot, GR-2026-07-03a).
//--- When the flag is on, publish WFBE_HC_RESLOT_SAFE = (zero real players connected) on a 5s server loop so a
//--- box-side HC controller can bounce-reslot the HCs onto CIVILIAN slots ONLY inside an empty-server window
//--- (the browser then shows the HCs as CIV, never as an occupied WEST player slot). HCs are excluded by name,
//--- so the count is real players only. Flag-off (default 0): this block never runs, no PV is ever published
//--- and no worker spawns -> byte-identical to HEAD.
if ((missionNamespace getVariable ["WFBE_C_HC_CIV_RESLOT", 0]) > 0) then {
	WFBE_HC_RESLOT_SAFE = false;
	publicVariable "WFBE_HC_RESLOT_SAFE";
	[] Spawn {
		private ["_hcNames"];
		_hcNames = ["HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3"];
		while {true} do {
			private ["_real"];
			_real = { (isPlayer _x) && {!((name _x) in _hcNames)} } count allUnits;
			WFBE_HC_RESLOT_SAFE = (_real == 0);
			publicVariable "WFBE_HC_RESLOT_SAFE";
			sleep 5;
		};
	};
};
