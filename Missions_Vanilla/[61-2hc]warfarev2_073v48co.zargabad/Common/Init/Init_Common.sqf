["INITIALIZATION", Format ["Init_Common.sqf: Common initialization begins at [%1]", time]] Call WFBE_CO_FNC_LogContent;

Private ['_count'];

// --- additional handlers
HandleRocketTraccer = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleRocketTracer.sqf";
HandleCommanderReload = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleCommanderReload.sqf";
HandleReload = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleReload.sqf";
HandleATReload = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleATReload.sqf";
HandleATMissiles = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleATMissiles.sqf";
HandleAAMissiles = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleAAMissiles.sqf";
HandleJetAADamage = Compile preprocessFileLineNumbers "Common\Functions\Common_JetAADamage.sqf";
HandleAlarm = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleAlarm.sqf";
HandleArty = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleArty.sqf";
HandleAT = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleAT.sqf";
BalanceInit = Compile preprocessFileLineNumbers "Common\Functions\Common_BalanceInit.sqf";
BuildingInRange = Compile preprocessFileLineNumbers "Common\Functions\Common_BuildingInRange.sqf";
ChangeSideSupply = Compile preprocessFileLineNumbers "Common\Functions\Common_ChangeSideSupply.sqf";
ChangeTeamFunds = Compile preprocessFileLineNumbers "Common\Functions\Common_ChangeTeamFunds.sqf";
EquipArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_EquipArtillery.sqf";
EquipLoadout = Compile preprocessFileLineNumbers "Common\Functions\Common_EquipLoadout.sqf";
FireArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_FireArtillery.sqf";
GetAIDigit = Compile preprocessFileLineNumbers "Common\Functions\Common_GetAIDigit.sqf";
GetClosestLocation = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestLocation.sqf";
GetClosestLocationBySide = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestLocationBySide.sqf";
GetClosestFriendlyLocation = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestFriendlyTown.sqf";
GetCommanderTeam = Compile preprocessFileLineNumbers "Common\Functions\Common_GetCommanderTeam.sqf";
GetConfigInfo = Compile preprocessFileLineNumbers "Common\Functions\Common_GetConfigInfo.sqf";
GetFactories = Compile preprocessFileLineNumbers "Common\Functions\Common_GetFactories.sqf";
GetFriendlyCamps = Compile preprocessFileLineNumbers "Common\Functions\Common_GetFriendlyCamps.sqf";
GetHostilesInArea = Compile preprocessFileLineNumbers "Common\Functions\Common_GetHostilesInArea.sqf";
GetLiveUnits = Compile preprocessFileLineNumbers "Common\Functions\Common_GetLiveUnits.sqf";
GetPositionFrom = Compile preprocessFileLineNumbers "Common\Functions\Common_GetPositionFrom.sqf";
GetRandomPosition = Compile preprocessFileLineNumbers "Common\Functions\Common_GetRandomPosition.sqf";
GetRespawnCamps = Compile preprocessFileLineNumbers "Common\Functions\Common_GetRespawnCamps.sqf";
GetRespawnThreeway = Compile preprocessFileLineNumbers "Common\Functions\Common_GetRespawnThreeway.sqf";
GetSideFromID = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideFromID.sqf";
GetSideID = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideID.sqf";
GetSideSupply = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideSupply.sqf";
GetSideUpgrades = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideUpgrades.sqf";
GetSideTowns = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideTowns.sqf";
GetSleepFPS = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSleepFPS.sqf";
// Marty: Load the local Performance Audit helpers before client/server loops start using them.
Call Compile preprocessFileLineNumbers "Common\Functions\Common_PerformanceAudit.sqf";
GetTeamArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamArtillery.sqf";
// Marty: Artillery ammo selector helpers used by the Tactical Center.
WFBE_CO_FNC_GetArtilleryAmmoOptions = Compile preprocessFileLineNumbers "Common\Functions\Common_GetArtilleryAmmoOptions.sqf";
WFBE_CO_FNC_LoadArtilleryAmmo = Compile preprocessFileLineNumbers "Common\Functions\Common_LoadArtilleryAmmo.sqf";
// claude-gaming 2026-06-29: AICOM situational ammo-type selector (gated on WFBE_UP_ARTYAMMO; flag WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE, default OFF).
WFBE_CO_FNC_AICOMArtyPickAmmo = Compile preprocessFileLineNumbers "Common\Functions\Common_AICOMArtyPickAmmo.sqf";
// Marty: Ammo-fraction helper (vehicle current / full complement). Used by proportional rearm pricing.
WFBE_CO_FNC_GetAmmoFraction = Compile preprocessFileLineNumbers "Common\Functions\Common_GetAmmoFraction.sqf";
GetTeamAutonomous = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamAutonomous.sqf";
GetTeamFunds = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamFunds.sqf";
GetTeamMoveMode = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamMoveMode.sqf";
GetTeamMovePos = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamMovePos.sqf";
GetTeamRespawn = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamRespawn.sqf";
GetTeamType = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamType.sqf";
GetTeamVehicles = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamVehicles.sqf";
GetTotalCamps = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTotalCamps.sqf";
GetTotalCampsOnSide = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTotalCampsOnSide.sqf";
GetTotalSupplyValue = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTotalSupplyValue.sqf";
GetTownsHeld = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTownsHeld.sqf";
GetTownsIncome = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTownsIncome.sqf";
GetUnitVehicle = Compile preprocessFileLineNumbers "Common\Functions\Common_GetUnitVehicle.sqf";
HandleIncomingMissile = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleIncomingMissile.sqf";
HandleShootBombs = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleShootBombs.sqf";
HandleShootMissiles = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleShootMissiles.sqf";
IsArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_IsArtillery.sqf";
IsMobileArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_IsMobileArtillery.sqf"; //--- Ray 2026-06-29: TRUE only for tracked/wheeled SELF-PROPELLED arty (GRAD/MLRS), FALSE for static towed/mortar emplacements. AICOM fields/fires SPG only.
MarkerUpdate = Compile preprocessFileLineNumbers "Common\Common_MarkerUpdate.sqf";
WFBE_CL_MarkerLoop = Compile preprocessFileLineNumbers "Common\Common_MarkerLoop.sqf"; // Marty: PERF1 consolidated client marker loop (started by the first MarkerUpdate registration).
PlaceNear = Compile preprocessFileLineNumbers "Common\Functions\Common_PlaceNear.sqf";
PlaceSafe = Compile preprocessFileLineNumbers "Common\Functions\Common_PlaceSafe.sqf";
RearmVehicle = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_RearmVehicleOA.sqf"} else {Compile preprocessFileLineNumbers "Common\Functions\Common_RearmVehicle.sqf"};
RevealArea = Compile preprocessFileLineNumbers "Common\Functions\Common_RevealArea.sqf";
SetCommanderVotes = Compile preprocessFileLineNumbers "Common\Functions\Common_SetCommanderVotes.sqf";
SetTeamAutonomous = Compile preprocessFileLineNumbers "Common\Functions\Common_SetTeamAutonomous.sqf";
SetTeamRespawn = Compile preprocessFileLineNumbers "Common\Functions\Common_SetTeamRespawn.sqf";
SetTeamMoveMode = Compile preprocessFileLineNumbers "Common\Functions\Common_SetTeamMoveMode.sqf";
SetTeamMovePos = Compile preprocessFileLineNumbers "Common\Functions\Common_SetTeamMovePos.sqf";
SetTeamType = Compile preprocessFileLineNumbers "Common\Functions\Common_SetTeamType.sqf";
SpawnTurrets = Compile preprocessFileLineNumbers "Common\Functions\Common_SpawnTurrets.sqf";
SortByDistance = Compile preprocessFileLineNumbers "Common\Functions\Common_SortByDistance.sqf";
UpdateStatistics = Compile preprocessFileLineNumbers "Common\Functions\Common_UpdateStatistics.sqf";
TrashObject = Compile preprocessFile "Common\Functions\Common_TrashObject.sqf";

// Module: Arty
ARTY_HandleILLUM = Compile preprocessFile "Common\Module\Arty\ARTY_HandleILLUM.sqf";
ARTY_HandleSADARM = Compile preprocessFile "Common\Module\Arty\ARTY_HandleSADARM.sqf";
ARTY_Prep = Compile preprocessFile "Common\Module\Arty\ARTY_mobileMissionPrep.sqf";
ARTY_Finish = Compile preprocessFile "Common\Module\Arty\ARTY_mobileMissionFinish.sqf";

//--- New Fnc.
WFBE_CO_FNC_ArrayPush = Compile preprocessFileLineNumbers "Common\Functions\Common_ArrayPush.sqf";
WFBE_CO_FNC_ArrayRemoveIndex = Compile preprocessFileLineNumbers "Common\Functions\Common_ArrayRemoveIndex.sqf";
WFBE_CO_FNC_ArrayShift = Compile preprocessFileLineNumbers "Common\Functions\Common_ArrayShift.sqf";
WFBE_CO_FNC_ArrayShuffle = Compile preprocessFileLineNumbers "Common\Functions\Common_ArrayShuffle.sqf";
WFBE_CO_FNC_ChangeTeamFunds = Compile preprocessFileLineNumbers "Common\Functions\Common_ChangeTeamFunds.sqf";
WFBE_SE_FNC_SyncFundsRecord = Compile preprocessFileLineNumbers "Common\Functions\Common_SyncFundsRecord.sqf"; //--- Ray pick A: server-only lock-step of WFBE_JIP_USER<uid> cash with the group wallet (JIP zero-latch restore provably safe). Common so ChangeTeamFunds resolves the symbol on both sides; the fn itself bails if !isServer.
WFBE_CO_FNC_ChangeUnitGroup = Compile preprocessFileLineNumbers "Common\Functions\Common_ChangeUnitGroup.sqf";
WFBE_CO_FNC_ClearVehicleCargo = if (WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_ClearVehicleCargo.sqf"} else {Compile preprocessFileLineNumbers "Common\Functions\Common_ClearVehicleCargoOA.sqf"};
WFBE_CO_FNC_CreateTeam = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateTeam.sqf";
WFBE_CO_FNC_CreateTownUnits = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateTownUnits.sqf";
WFBE_CO_FNC_RunSidePatrol = Compile preprocessFileLineNumbers "Common\Functions\Common_RunSidePatrol.sqf";
WFBE_CO_FNC_RunCommanderTeam = Compile preprocessFileLineNumbers "Common\Functions\Common_RunCommanderTeam.sqf";
WFBE_CO_FNC_AICOMAirLeg = Compile preprocessFileLineNumbers "Common\Functions\Common_AICOMAirLeg.sqf"; //--- cmdcon42-f AIR-MOBILE: fly an ORDERED leg with the team's own live transport heli + hot-LZ (cold=land, contested=paradrop); transport returns to base + persists. Gate WFBE_C_AICOM_AIRMOBILE.
WFBE_CO_FNC_AICOMAirReturn = Compile preprocessFileLineNumbers "Common\Functions\Common_AICOMAirReturn.sqf"; //--- cmdcon42-f shared post-drop RETURN-TO-BASE-AND-HOLD (the founding WFBE_C_AICOM_AIR_RETAIN path + air-mobile legs call this SAME code - no duplication). Scheduled-context only (it sleeps).
WFBE_CO_FNC_AICOMServiceTick = Compile preprocessFileLineNumbers "Common\Functions\Common_AICOMServiceTick.sqf"; //--- B48 AICOM self-service (default OFF: WFBE_C_AICOM_SERVICE_ENABLED)
WFBE_CO_FNC_AICOMLog = Compile preprocessFileLineNumbers "Common\Functions\Common_AICommanderLog.sqf";
WFBE_CO_FNC_SpawnFactionSmoke = Compile preprocessFileLineNumbers "Common\Functions\Common_SpawnFactionSmoke.sqf"; //--- Cosmetic: server-only triggered faction smoke (gated WFBE_C_FSMOKE_ENABLED; capped+TTL+cooldown).
// Marty: Central createGroup wrapper (LEVER 2) - registered immediately after AICOMLog so the wrapper can call it.
WFBE_CO_FNC_CreateGroup = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateGroup.sqf";
WFBE_CO_FNC_GroupGetBool = Compile preprocessFileLineNumbers "Common\Functions\Common_GroupGetBool.sqf"; //--- G1: safe bool getVariable for GROUP receivers (A2 OA unset->nil trap)
WFBE_CO_FNC_CapLock = Compile preprocessFileLineNumbers "Common\Functions\Common_CapLock.sqf"; //--- capture-churn fix: is this AICOM team mid-capture-drain and thus IMMUNE to re-tasking (GR-2026-07-03a).
WFBE_CO_FNC_SMLCampSplit = Compile preprocessFileLineNumbers "Common\Functions\Common_SMLCampSplit.sqf"; //--- SML-1 (GR-2026-07-03a): camp-split captures; per-unit doStop/doMove with TTL watchdog. Flag WFBE_C_SML_CAMP_SPLIT default 0.
WFBE_CO_FNC_SMLDismounts = Compile preprocessFileLineNumbers "Common\Functions\Common_SMLDismounts.sqf"; //--- SML-2 (GR-2026-07-03a): real dismounts; cargo infantry dismount for foot assault, crew stays mounted for fire support. Flag WFBE_C_SML_DISMOUNTS default 0.
WFBE_CO_FNC_SMLRetreat   = Compile preprocessFileLineNumbers "Common\Functions\Common_SMLRetreat.sqf";   //--- SML-3 (GR-2026-07-03a): graceful retreats; mauled individuals pull back with TTL watchdog. Flag WFBE_C_SML_RETREAT default 0.
WFBE_CO_FNC_SMLOverwatch = Compile preprocessFileLineNumbers "Common\Functions\Common_SMLOverwatch.sqf"; //--- SML-4 (GR-2026-07-03a): AT overwatch; launcher pre-positions on armor approach before assault. Flag WFBE_C_SML_AT_OVERWATCH default 0.
WFBE_CO_FNC_SMLUnstuck   = Compile preprocessFileLineNumbers "Common\Functions\Common_SMLUnstuck.sqf";   //--- SML-5 (GR-2026-07-03a): surgical unstuck; nudge only individually-wedged units (pre-tier). Flag WFBE_C_SML_SURGICAL_UNSTUCK default 0.
WFBE_CO_FNC_CreateUnitForStaticDefence = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateUnitForStaticDefence.sqf";
WFBE_CO_FNC_CreateUnitsForResBases = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateUnitsForResBases.sqf";
WFBE_CO_FNC_CreateVehicle = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateVehicle.sqf";
WFBE_CO_FNC_CreateUnit = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateUnit.sqf";
WFBE_CO_FNC_EquipBackpack = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_EquipBackpack.sqf"} else {{}};
WFBE_CO_FNC_EquipUnit = Compile preprocessFileLineNumbers "Common\Functions\Common_EquipUnit.sqf";
WFBE_CO_FNC_EquipVehicle = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_EquipVehicle.sqf"} else {{}};
WFBE_CO_FNC_FindTurretsRecursive = Compile preprocessFileLineNumbers "Common\Functions\Common_FindTurretsRecursive.sqf";
WFBE_CO_FNC_FireArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_FireArtillery.sqf";
WFBE_CO_FNC_GetAreaEnemiesCount = Compile preprocessFileLineNumbers "Common\Functions\Common_GetAreaEnemiesCount.sqf";
WFBE_CO_FNC_GetCommanderTeam = Compile preprocessFileLineNumbers "Common\Functions\Common_GetCommanderTeam.sqf";
//--- wiki-wins: removed dead compile WFBE_CO_FNC_GetClosestEnemyLocation (zero call sites repo-wide)
WFBE_CO_FNC_GetClosestEntity = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestEntity.sqf";
WFBE_CO_FNC_GetClosestEntity2 = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestEntity2.sqf";
WFBE_CO_FNC_GetClosestEntity3 = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestEntity3.sqf";
WFBE_CO_FNC_GetClosestEntity4 = Compile preprocessFileLineNumbers "Common\Functions\Common_GetClosestEntity4.sqf";
WFBE_CO_FNC_GetAirfieldOwnerSideID = Compile preprocessFileLineNumbers "Common\Functions\Common_GetAirfieldOwnerSideID.sqf"; //--- fable/airfield-ownership-gate: nearest-town ownership proxy for LocationLogicAirport objects.
WFBE_CO_FNC_GetConfigEntry = Compile preprocessFileLineNumbers "Common\Functions\Common_GetConfigEntry.sqf";
WFBE_CO_FNC_GetDirTo = Compile preprocessFileLineNumbers "Common\Functions\Common_GetDirTo.sqf";
WFBE_CO_FNC_GetEmptyPosition = Compile preprocessFileLineNumbers "Common\Functions\Common_GetEmptyPosition.sqf";
WFBE_CO_FNC_GetLiveUnits = Compile preprocessFileLineNumbers "Common\Functions\Common_GetLiveUnits.sqf";
WFBE_CO_FNC_GetRandomPosition = Compile preprocessFileLineNumbers "Common\Functions\Common_GetRandomPosition.sqf";
WFBE_CO_FNC_GetSideFromID = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideFromID.sqf";
WFBE_CO_FNC_GetSideHQDeployStatus = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideHQDeployStatus.sqf";
WFBE_CO_FNC_GetSideHQ = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideHQ.sqf";
WFBE_CO_FNC_GetSideID = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideID.sqf";
WFBE_CO_FNC_GetSideLogic = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideLogic.sqf";
WFBE_CO_FNC_GetSideSupply = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideSupply.sqf";
WFBE_CO_FNC_GetSideStructures = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideStructures.sqf";
WFBE_CO_FNC_HasSideRadioTower = Compile preprocessFileLineNumbers "Common\Functions\Common_HasSideRadioTower.sqf";
WFBE_CO_FNC_GetSideUpgrades = Compile preprocessFileLineNumbers "Common\Functions\Common_GetSideUpgrades.sqf";
WFBE_CO_FNC_GetTeamFunds = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTeamFunds.sqf";
WFBE_CO_FNC_GetTotalCamps = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTotalCamps.sqf";
WFBE_CO_FNC_SanitizeGotoDisp = Compile preprocessFileLineNumbers "Common\Functions\Common_SanitizeGotoDisp.sqf"; //--- cmdcon42-o: enemy-base intel-leak clamp for order-destination DISPLAY surfaces (producer-side).
WFBE_CO_FNC_GetTotalCampsOnSide = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTotalCampsOnSide.sqf";
WFBE_CO_FNC_GetTownsSupply = Compile preprocessFileLineNumbers "Common\Functions\Common_GetTownsSupply.sqf";
WFBE_CO_FNC_GetUnitConfigGear = Compile preprocessFileLineNumbers "Common\Functions\Common_GetUnitConfigGear.sqf";
//--- wiki-wins: removed dead compile WFBE_CO_FNC_GetUnitsPerSide (zero call sites repo-wide)
WFBE_CO_FNC_GetVehicleTurretsGear = Compile preprocessFileLineNumbers "Common\Functions\Common_GetVehicleTurretsGear.sqf";
WFBE_CO_FNC_HandleArtillery = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleArtillery.sqf";
WFBE_CO_FNC_OnUnitHit = Compile preprocessFileLineNumbers "Common\Functions\Common_OnUnitHit.sqf";
WFBE_CO_FNC_OnUnitKilled = Compile preprocessFileLineNumbers "Common\Functions\Common_OnUnitKilled.sqf";
WFBE_CO_FNC_RevealArea = Compile preprocessFileLineNumbers "Common\Functions\Common_RevealArea.sqf";
WFBE_CO_FNC_RemoveAAMissiles = Compile preprocessFileLineNumbers "Common\Functions\Common_RemoveAAMissiles.sqf";
WFBE_CO_FNC_HandleSEADMissile = Compile preprocessFileLineNumbers "Common\Functions\Common_HandleSEADMissile.sqf"; //--- B93 SEAD (GR-2026-07-03a): anti-radar guidance for tier-5 jets; 2-shot limit per spawn; flag WFBE_C_SEAD default 0.
WFBE_CO_FNC_RemoveCountermeasures = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_RemoveCountermeasures.sqf"} else {{}};
WFBE_CO_FNC_SendToClient = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToClient.sqf"} else {{}};
WFBE_CO_FNC_SendToClients = Compile preprocessFileLineNumbers "Common\Functions\Common_SendToClients.sqf";
WFBE_CO_FNC_SendToServer = if (WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToServer.sqf"} else {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToServerOptimized.sqf"};
WFBE_CO_FNC_SetTurretsMagazines = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_SetTurretsMagazines.sqf"} else {{}};
WFBE_CO_FNC_SortByDistance = Compile preprocessFileLineNumbers "Common\Functions\Common_SortByDistance.sqf";
WFBE_CO_FNC_WaypointPatrol = Compile preprocessFileLineNumbers "Common\Functions\Common_WaypointPatrol.sqf";
WFBE_CO_FNC_WaypointPatrolTown = Compile preprocessFileLineNumbers "Common\Functions\Common_WaypointPatrolTown.sqf";
WFBE_CO_FNC_WaypointSimple = Compile preprocessFileLineNumbers "Common\Functions\Common_WaypointSimple.sqf";
WFBE_CO_FNC_WaypointsAdd = Compile preprocessFileLineNumbers "Common\Functions\Common_WaypointsAdd.sqf";
WFBE_CO_FNC_WaypointsRemove = Compile preprocessFileLineNumbers "Common\Functions\Common_WaypointsRemove.sqf";
WFBE_CO_FNC_BuildRoadRoute = Compile preprocessFileLineNumbers "Common\Functions\Common_BuildRoadRoute.sqf"; //--- AICOM road-march helper: road-node-snapped chain shared by AssignTowns (AI-strategy) + Execute (war-room console DIRECT orders).
WF_createMarker = compile preprocessFileLineNumbers "Common\Functions\Common_CreateMarker.sqf";
WFBE_CL_FNC_Delete_Marker = compile preprocessFileLineNumbers "Client\Functions\Client_Delete_Marker.sqf";
WF_sendMessage = compile preprocessFileLineNumbers "Common\Functions\Common_SendMessage.sqf";
WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers = Compile preprocessFileLineNumbers "Common\Functions\Common_StagnateSupplyIncomeNoPlayers.sqf";
// Marty: Defense budget — category helper (used by RequestDefense budget gate and available to client UI).
WFBE_CO_FNC_GetDefenseCategory = Compile preprocessFileLineNumbers "Common\Functions\Common_GetDefenseCategory.sqf";
WFBE_CO_FNC_DeadspawnPenPos = Compile preprocessFileLineNumbers "Common\Functions\Common_DeadspawnPenPos.sqf"; //--- fable/deadspawn-redesign: underwater join-pen position resolver, flag WFBE_C_DEADSPAWN_REDESIGN default 0.

["INITIALIZATION", "Init_Common.sqf: Functions are initialized."] Call WFBE_CO_FNC_LogContent;

varQueu = random(10)+random(100)+random(1000); //clt, to remove with new sys later on.
unitMarker = 0;

//--- Load the profile variables if needed (Requires at least version 1.62 build 97105).
if (ARMA_VERSION >= 162 && ARMA_RELEASENUMBER > 97105 || ARMA_VERSION > 162) then {
	WFBE_CO_FNC_SaveProfile = Compile preprocessFileLineNumbers "Common\Functions\Common_SaveProfile.sqf";
	WFBE_CO_FNC_SetProfileVariable = Compile preprocessFileLineNumbers "Common\Functions\Common_SetProfileVariable.sqf";
};



/* Respawn Markers */
createMarkerLocal ["respawn_east",getMarkerPos "EastTempRespawnMarker"];
"respawn_east" setMarkerColorLocal "ColorGreen";
"respawn_east" setMarkerShapeLocal "RECTANGLE";
"respawn_east" setMarkerBrushLocal "BORDER";
"respawn_east" setMarkerSizeLocal [15,15];
"respawn_east" setMarkerAlphaLocal 0;
createMarkerLocal ["respawn_west",getMarkerPos "WestTempRespawnMarker"];
"respawn_west" setMarkerColorLocal "ColorGreen";
"respawn_west" setMarkerShapeLocal "RECTANGLE";
"respawn_west" setMarkerBrushLocal "BORDER";
"respawn_west" setMarkerSizeLocal [15,15];
"respawn_west" setMarkerAlphaLocal 0;
createMarkerLocal ["respawn_guerrila",getMarkerPos "GuerTempRespawnMarker"];
"respawn_guerrila" setMarkerColorLocal "ColorGreen";
"respawn_guerrila" setMarkerShapeLocal "RECTANGLE";
"respawn_guerrila" setMarkerBrushLocal "BORDER";
"respawn_guerrila" setMarkerSizeLocal [15,15];
"respawn_guerrila" setMarkerAlphaLocal 0;

//--- Types.
WFBE_Logic_Airfield = "LocationLogicAirport";
WFBE_Logic_Camp = "LocationLogicCamp";
WFBE_Logic_Depot = "LocationLogicDepot";

isAutoWallConstructingEnabled = true; //--- legacy global (client CoIn UI still reads this, per-client-side); the per-side server vars below are authoritative for construction
//--- wiki-wins: per-side auto-wall toggle so one commander's toggle no longer flips every side's + the AI's builds. Default true per side.
{ missionNamespace setVariable [Format["WFBE_AUTOWALL_%1", _x], true] } forEach [west, east, resistance];
WFBE_CO_VAR_SupplyMissionRegenInterval = 1800;

/* Wait for BIS Module Init */
waitUntil {!(isNil 'BIS_fnc_init')};
waitUntil {BIS_fnc_init};

/* CORE SYSTEM - Start
	Different Core are added depending on the current ArmA Version running, add yours bellow.
*/
_team_west = "";
_team_east = "";
switch (true) do {
	case WF_A2_CombinedOps: {
		/* Model Core */
		if !(IS_chernarus_map_dependent) then {
			Call Compile preprocessFileLineNumbers 'Common\Config\Core_Models\CombinedOps.sqf';
		} else {
			Call Compile preprocessFileLineNumbers 'Common\Config\Core_Models\CombinedOps_W.sqf';
		};

		/* Gear Core */
		if (local player) then {
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_US.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_TKA.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_BAF.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_GUE.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_PMC.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_RU.sqf";
			Call Compile preprocessFileLineNumbers "Common\Config\Gear\Gear_USMC.sqf";
		};
		/* Class Core */
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_ACR.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_BAF.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_BAFD.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_BAFW.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_CDF.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_DeltaForce.sqf'; //--- B755 (Ray 2026-06-25): Core_DeltaForce.sqf existed but was never loaded by this list -> Delta Force classes had no buy-menu metadata (nil lookups). Loaded like its siblings.
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_CIV.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_FR.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_GUE.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_INS.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_MVD.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_PMC.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_RU.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_Spetsnaz.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_TKA.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_TKCIV.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_TKGUE.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_TKSF.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_US.sqf';
		Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_USMC.sqf';

		/* Call in the teams template - Combined Operations */
		_team_west = if (IS_chernarus_map_dependent) then {'US_Camo'} else {'US'};
		_team_east = if (IS_chernarus_map_dependent) then {'RU'} else {'TKA'};
	};
};

["INITIALIZATION", "Init_Common.sqf: Core Files are loaded."] Call WFBE_CO_FNC_LogContent;

// Reworked to use the the cherno/takistan parameter
_grpWest = (missionNamespace getVariable 'WFBE_C_UNITS_FACTIONS_WEST') select (missionNamespace getVariable 'WFBE_C_UNITS_FACTION_WEST');
_grpEast = (missionNamespace getVariable 'WFBE_C_UNITS_FACTIONS_EAST') select (missionNamespace getVariable 'WFBE_C_UNITS_FACTION_EAST');
_grpRes = (missionNamespace getVariable 'WFBE_C_UNITS_FACTIONS_GUER') select (missionNamespace getVariable 'WFBE_C_UNITS_FACTION_GUER');


["INITIALIZATION", Format["Init_Common.sqf: Using groups - West [%1], East [%2], Resistance [%3].",_grpWest,_grpEast,_grpRes]] Call WFBE_CO_FNC_LogContent;

/* CORE SYSTEM - End */

//--- Determine which logics are defined.
_presents = [];
{
	Private ["_sideIsPresent"];
	_sideIsPresent = if !(isNil (_x select 1)) then {true} else {false};
	missionNamespace setVariable [Format["WFBE_%1_PRESENT", str (_x select 0)], _sideIsPresent];
	if (_sideIsPresent) then {_presents = _presents + [_x select 0]};
} forEach [[west,"WFBE_L_BLU"],[east,"WFBE_L_OPF"],[resistance,"WFBE_L_GUE"]];

WFBE_PRESENTSIDES = _presents;
WFBE_ISTHREEWAY = ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0); //--- GUER Insurgents gate: three-way mode is live only when the playable GUER faction is enabled (else exactly as before)

//--- Todo, dynamic (if logic is present or not).
WFBE_DEFENDER = resistance;
WFBE_DEFENDER_ID = (WFBE_DEFENDER) Call WFBE_CO_FNC_GetSideID;

//--- Import the desired global side variables.
Call Compile preprocessFileLineNumbers Format["Common\Config\Core_Root\Root_%1.sqf",_grpRes];
Call Compile preprocessFileLineNumbers Format["Common\Config\Core_Root\Root_%1.sqf", _team_west];
Call Compile preprocessFileLineNumbers Format["Common\Config\Core_Root\Root_%1.sqf", _team_east];

//--- Common Exec.
Call Compile preprocessFileLineNumbers "Common\Init\Init_PublicVariables.sqf";

//--- B67 (guer-reward): register the GuerVbiedBounty client receiver, mirroring exactly how AwardBounty is
//--- registered by the Init_PublicVariables.sqf _clientCommandPV forEach loop (compile CLTFNC<name> from
//--- Client\PVFunctions\<name>.sqf + add the WFBE_PVF_<name> addPublicVariableEventHandler on clients/HC-host).
//--- Done here (not in Init_PublicVariables) to keep the change inside the B67 edit-scope; identical effect.
CLTFNCGuerVbiedBounty = compile preprocessFileLineNumbers "Client\PVFunctions\GuerVbiedBounty.sqf";
if (!isNil "WFBE_CL_PVF_ALLOWED") then {WFBE_CL_PVF_ALLOWED = WFBE_CL_PVF_ALLOWED + ["CLTFNCGuerVbiedBounty"]};
if (!isServer || local player) then {"WFBE_PVF_GuerVbiedBounty" addPublicVariableEventHandler {(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}};

//--- pvf-allowlist (claude-gaming 2026-07-01): several server paths (RequestOnUnitKilled/Server_BuildingKilled/
//--- Server_OnHQKilled/Server_HandleSpecial) re-dispatch the score handler directly with the UPPERCASE spelling
//--- 'SRVFNCREQUESTCHANGESCORE' via Spawn WFBE_SE_FNC_HandlePVF. The standard loop registers it mixed-case as
//--- "SRVFNCRequestChangeScore", and the new Server_HandlePVF allowlist gate uses case-SENSITIVE array `in`, so
//--- without this alias those score awards would be silently rejected. Add the exact uppercase alias too.
if (!isNil "WFBE_SE_PVF_ALLOWED") then {WFBE_SE_PVF_ALLOWED = WFBE_SE_PVF_ALLOWED + ["SRVFNCREQUESTCHANGESCORE"]};

//--- Import the desired defenses. (todo, Replace the old defense init by this one).
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpWest];
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpEast];
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpRes];

//--- Server Exec.
if (isServer) then {
	//--- Import the desired town groups.
	Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpWest];
	Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpEast];
	Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpRes];
};

//--- Airports Init.
ExecVM "Common\Init\Init_Airports.sqf";

["INITIALIZATION", "Init_Common.sqf: Config Files are loaded."] Call WFBE_CO_FNC_LogContent;

//--- Boundaries, use setPos to find the perfect spot on other islands and worldName to determine the island name (editor: diag_log worldName; player setPos [0,5120,0]; ).
Call Compile preprocessFileLineNumbers "Common\Init\Init_Boundaries.sqf";
["INITIALIZATION", "Init_Common.sqf: Boundaries are loaded."] Call WFBE_CO_FNC_LogContent;

if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_ICBM") > 0) then {Call Compile preprocessFileLineNumbers "Client\Module\Nuke\ICBM_Init.sqf"}; //--- ICBM.
if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_IRSMOKE") > 0) then {Call Compile preprocessFileLineNumbers "Common\Module\IRS\IRS_Init.sqf"}; //--- IR Smoke.

//--- CIPHER Module - Functions.
Call Compile preprocessFileLineNumbers "Common\Module\CIPHER\CIPHER_Init.sqf";

//--- Longest vehicles purchase (+ extra processing).
_balancePrice = missionNamespace getVariable "WFBE_C_UNITS_PRICING";
{
	Private ["_longest","_structure"];
	_structure = _x;

	//--- Get the longest build time per structure.
	_longest = 0;
	{
		_type = missionNamespace getVariable Format ["WFBE_%1%2UNITS", _x, _structure];
		if !(isNil '_type') then {
			{
				_c = missionNamespace getVariable _x;
				if !(isNil '_c') then {
					if ((_c select QUERYUNITTIME) > _longest) then {_longest = (_c select QUERYUNITTIME)};
					if (_structure in ["LIGHT", "HEAVY"]) then {if (_balancePrice in [1,3]) then {_c set [QUERYUNITPRICE, (_c select QUERYUNITPRICE)*2]}};
					if (_structure in ["AIRCRAFT", "AIRPORT"]) then {if (_balancePrice in [1,2]) then {_c set [QUERYUNITPRICE, (_c select QUERYUNITPRICE)*2]}};
				};
			} forEach _type;
		};
	} forEach WFBE_PRESENTSIDES;

	missionNamespace setVariable [Format ["WFBE_LONGEST%1BUILDTIME",_structure], _longest];
} forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT","AIRPORT","DEPOT"];

//--- If money is the only resource, multiply the building cost.
if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 1) then {
	Private ["_list"];
	{
		_list = missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS", _x];
		for '_i' from 0 to count(_list)-1 do {_list set [_i, round((_list select _i) * 5)]};
	} forEach WFBE_PRESENTSIDES;
};

//--- Make a global array of miscelleanous stuff.

_repairs = [];
{
	_repairs = _repairs + (missionNamespace getVariable Format["WFBE_%1REPAIRTRUCKS", _x]);
} forEach WFBE_PRESENTSIDES;

missionNamespace setVariable ["WFBE_REPAIRTRUCKS", _repairs];


//--- Task 12: Airfield-exclusive aircraft roster.  Populated on all machines so
//--- the hangar buy menu can use it without a server round-trip.
//--- WFBE_AIRFIELD_UNITS      = generic list shared by ALL captured airfields (both sides).
//--- WFBE_AIRFIELD_UNITS_SPECIAL = per-airfield extras: [[townName, [classnames]], ...].
//---   At menu-fill time the nearest town name is resolved from the airport logic object
//---   and any matching entry's classes are appended to the generic list.
//---   Add new per-airfield specials by appending a pair — no other file changes needed.
if ((missionNamespace getVariable ["WFBE_C_AIRFIELDS", 0]) > 0) then {
	WFBE_AIRFIELD_UNITS = if (IS_chernarus_map_dependent) then {
		//--- L-39C removed (Balota-only via special); Mi-171Sh rocket gunship added for early-game support.
		//--- Amendment 2026-06-12: light jets added — Su25_Ins (EAST, gun+S-5 default) and L159_ACR (WEST,
		//---   Hydra/Maverick default) — priced between Mi-171Sh (24000) and cheapest factory jet.
		//---   Cross-faction listing is intentional (soft-faction-walls precedent).
		//---   NOTE: Su25_Ins also appears in Core_INS factory; L159_ACR also in Core_USMC AF3.
		//---   Owner ruling 2026-06-12: dual availability confirmed — Su25_Ins and L159_ACR stay in both airfield pool AND factory lists.
		["An2_TK_EP1","Mi17_Ins","Mi171Sh_rockets_CZ_EP1","Su25_Ins","L159_ACR"]
	} else {
		//--- Takistan generic list: L-39C not present here; leave as-is.
		["An2_TK_EP1","Mi17_TK_EP1"]
	};

	//--- Per-airfield specials: units added ONLY at the named airfield.
	//--- Chernarus: L-39C is exclusive to Balota (closest prestige-aviation context).
	//--- Takistan (cmdcon42-i): the two REAL TK airfields Rasman + Loy Manara (exact town names from the
	//---   Takistan mission.sqm) gain the TOP-tier (level-5, airfield-exclusive) TK-EASA air variant rows,
	//---   so owning a TK airfield finally unlocks the heaviest warloads (audit item #4). Cross-faction
	//---   listing is intentional (same soft-faction-walls precedent as Su25_Ins/L159_ACR above): the
	//---   airfield capture IS the unlock, and the buy pipeline resolves each token's own faction tuple.
	//---   The exclusive rows are collected from the catalog (isAirfieldExclusive flag), which self-gates on
	//---   worldName + WFBE_C_TK_EASA_ROSTER -> [] when the flag is off, leaving the TK airfields plain.
	WFBE_AIRFIELD_UNITS_SPECIAL = if (IS_chernarus_map_dependent) then {
		[
			["Balota", ["L39_TK_EP1"]]
		]
	} else {
		private ["_tkeExclusive"];
		_tkeExclusive = [];
		{ if (_x select 6) then {_tkeExclusive = _tkeExclusive + [_x select 0]}; } forEach (Call Compile preprocessFile "Common\Functions\Common_TKEasaRoster.sqf");
		[
			["Rasman",      _tkeExclusive],
			["Loy Manara",  _tkeExclusive]
		]
	};
};

//--- Data-driven special-unit info popups.
//--- Each entry: [classname, stringtable-key].  The buy menu reads this on selection
//--- and shows hintSilent parseText (localize key) when a match is found.
//--- To add a new special: append ["ClassName","STR_WF_HINT_..."] to the array.
WFBE_SPECIAL_UNIT_HINTS = [
	// Marty: WEST salvage heli (UH1H_EP1) removed - invalid class on live box; re-add with validated airframe (claude-inbox#2 item 1).
	["Mi17_medevac_CDF","STR_WF_HINT_SalvageHeli"]
];

//--- ASR AI (optional 3rd-party mod) fired-handler null-shooter guard: fixes the once-per-session
//--- "nearEntities [_shooter,_k]" RPT error (deleted-shooter race in the mod's sys_aiskill fired
//--- handler). One-line no-op on machines without the mod. See Common_AsrFiredGuard.sqf.
Call Compile preprocessFileLineNumbers "Common\Functions\Common_AsrFiredGuard.sqf";

//--- Common initilization is complete at this point.
["INITIALIZATION", Format ["Init_Common.sqf: Common initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;
commonInitComplete = true;
