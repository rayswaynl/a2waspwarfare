Private ['_HQRadio','_base','_buildings','_condition','_get','_idbl','_isDeployed','_oc','_weat','_rearmor','_playerObject','_hasConnectedAtLaunchACK', '_vehiclePlayer'];

["INITIALIZATION", Format ["Init_Client.sqf: Client initialization begins at [%1]", time]] Call WFBE_CO_FNC_LogContent;

sideJoined = side player;
sideJoinedText = str sideJoined;
//--- WF3 Compatible.
WFBE_Client_SideJoined = sideJoined;
WFBE_Client_SideJoinedText = sideJoinedText;
WFBE_Allow_HostileGearSaving = true;

// Set the default target fps to 60
missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", 60];

player call Compile preprocessFileLineNumbers "WASP\rpg_dropping\DropRPG.sqf";
//--- Position the client on the temp spawn (Common is not yet init'd so we call is straigh away).
player setPos ([getMarkerPos Format["%1TempRespawnMarker",sideJoinedText],1,10] Call Compile preprocessFile "Common\Functions\Common_GetRandomPosition.sqf");
(vehicle player) addEventHandler ["Fired",{_this Spawn HandleAT}]; (vehicle player) addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];
// Marty: Only attach the combat marker blinking Fired EH when the mission parameter enables the feature.
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) == 1) then {
	(vehicle player) addEventHandler ["Fired", {
		_u = _this select 0;                 // unit that fired
		_u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
	}];
};

(vehicle player) setVariable ["OriginalMarkerColor", "ColorOrange", false];

_rearmor = {
   				_ammo = _this select 4;
   				_result = 0;

   				switch (_ammo) do {
                    case "B_20mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_23mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HEI" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "Sh_40_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
     				default {_result = _this select 2;};
    			};
   				_result
  			};

player addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
[] execVM "Common\Functions\Common_Bipod.sqf";

UpdateMarker = Compile preprocessFile "Common\Functions\Common_UpdateMarker.sqf";
BoundariesIsOnMap = Compile preprocessFile "Client\Functions\Client_IsOnMap.sqf";
BoundariesHandleOnMap = Compile preprocessFile "Client\Functions\Client_HandleOnMap.sqf";
BuildUnit = Compile preprocessFile "Client\Functions\Client_BuildUnit.sqf";
ChangePlayerFunds = Compile preprocessFile "Client\Functions\Client_ChangePlayerFunds.sqf";
CommandChatMessage = Compile preprocessFile "Client\Functions\Client_CommandChatMessage.sqf";
FX = Compile preprocessFile "Client\Functions\Client_FX.sqf";
GetIncome = Compile preprocessFile "Client\Functions\Client_GetIncome.sqf";
GetPlayerFunds = Compile preprocessFile "Client\Functions\Client_GetPlayerFunds.sqf";
GetRespawnAvailable = Compile preprocessFile "Client\Functions\Client_GetRespawnAvailable.sqf";
GetStructureMarkerLabel = Compile preprocessFile "Client\Functions\Client_GetStructureMarkerLabel.sqf";
GetTime = Compile preprocessFile "Client\Functions\Client_GetTime.sqf";
GroupChatMessage = Compile preprocessFile "Client\Functions\Client_GroupChatMessage.sqf";
HandleHQAction = Compile preprocessFile "Client\Functions\Client_HandleHQAction.sqf";
HandlePVF = Compile preprocessFile "Client\Functions\Client_HandlePVF.sqf";
MarkerAnim = Compile preprocessFile "Client\Functions\Client_MarkerAnim.sqf";
OnRespawnHandler = Compile preprocessFile "Client\Functions\Client_OnRespawnHandler.sqf";
PreRespawnHandler = Compile preprocessFile "Client\Functions\Client_PreRespawnHandler.sqf";
ReplaceArray = Compile preprocessFile "Client\Functions\Client_ReplaceArray.sqf";
RequestFireMission = Compile preprocessFile "Client\Functions\Client_RequestFireMission.sqf";
SetControlFadeAnim = Compile preprocessFile "Client\Functions\Client_SetControlFadeAnim.sqf";
SetControlFadeAnimStop = Compile preprocessFile "Client\Functions\Client_SetControlFadeAnimStop.sqf";
SupportHeal = Compile preprocessFile "Client\Functions\Client_SupportHeal.sqf";
SupportRearm = Compile preprocessFile "Client\Functions\Client_SupportRearm.sqf";
SupportRefuel = Compile preprocessFile "Client\Functions\Client_SupportRefuel.sqf";
SupportRepair = Compile preprocessFile "Client\Functions\Client_SupportRepair.sqf";
// TaskSystem = Compile preprocessFile "Client\Functions\Client_TaskSystem.sqf";
TitleTextMessage = Compile preprocessFile "Client\Functions\Client_TitleTextMessage.sqf";
UIChangeComboBuyUnits = Compile preprocessFile "Client\Functions\Client_UIChangeComboBuyUnits.sqf";
UIFillListBuyUnits = Compile preprocessFile "Client\Functions\Client_UIFillListBuyUnits.sqf";
UIFillListTeamOrders = Compile preprocessFile "Client\Functions\Client_UIFillListTeamOrders.sqf";
UIFindLBValue = Compile preprocessFile "Client\Functions\Client_UIFindLBValue.sqf";


//--- Namespace related (GUI).
BIS_FNC_GUIset = {UInamespace setVariable [_this select 0, _this select 1]};
BIS_FNC_GUIget = {UInamespace getVariable (_this select 0)};

//--- New Fnc.
// Marty: Centralized WF menu action helper. It keeps the mouse wheel WF menu tied to the current player object.
WFBE_CL_FNC_AddWFMenuAction = Compile preprocessFileLineNumbers "Client\Functions\Client_AddWFMenuAction.sqf";
WFBE_CL_FNC_AddPlayerAIActions = Compile preprocessFileLineNumbers "Client\Functions\Client_AddPlayerAIActions.sqf";
WFBE_CL_FNC_ChangeClientFunds = Compile preprocessFileLineNumbers "Client\Functions\Client_ChangePlayerFunds.sqf";
WFBE_CL_FNC_DelegateTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateTownAI.sqf";
WFBE_CL_FNC_DelegateAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAI.sqf";
WFBE_CL_FNC_DelegateAIStaticDefence = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAIStaticDefence.sqf";
WFBE_CL_FNC_GetAIID = Compile preprocessFileLineNumbers "Client\Functions\Client_GetAIID.sqf";
WFBE_CL_FNC_GetBackpackContent = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Client\Functions\Client_GetBackpackContent.sqf"} else {{[[],[]]}};
WFBE_CL_FNC_GetClientFunds = Compile preprocessFileLineNumbers "Client\Functions\Client_GetPlayerFunds.sqf";
// Marty: Condition helper used by Repair Camp addActions so the mouse wheel menu only shows it near destroyed camps.
WFBE_CL_FNC_CanRepairCampNearby = Compile preprocessFileLineNumbers "Client\Functions\Client_CanRepairCampNearby.sqf";
WFBE_CL_FNC_GetClosestAirport = Compile preprocessFileLineNumbers "Client\Functions\Client_GetClosestAirport.sqf";
WFBE_CL_FNC_GetClosestCamp = Compile preprocessFileLineNumbers "Client\Functions\Client_GetClosestCamp.sqf";
WFBE_CL_FNC_GetClosestDepot = Compile preprocessFileLineNumbers "Client\Functions\Client_GetClosestDepot.sqf";
WFBE_CL_FNC_GetGearCargoSize = Compile preprocessFileLineNumbers "Client\Functions\Client_GetGearCargoSize.sqf";
WFBE_CL_FNC_GetMagazinesSize = Compile preprocessFileLineNumbers "Client\Functions\Client_GetMagazinesSize.sqf";
WFBE_CL_FNC_GetParsedGear = Compile preprocessFileLineNumbers "Client\Functions\Client_GetParsedGear.sqf";
WFBE_CL_FNC_GetVehicleCargoSize = Compile preprocessFileLineNumbers "Client\Functions\Client_GetVehicleCargoSize.sqf";
WFBE_CL_FNC_GetVehicleContent = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Client\Functions\Client_GetVehicleContent.sqf"} else {{[[],[],[]]}};
WFBE_CL_FNC_GetUnitBackpack = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Client\Functions\Client_GetUnitBackpack.sqf"} else {{""}};
WFBE_CL_FNC_HandleMapSingleClick = Compile preprocessFileLineNumbers "Client\Functions\Client_HandleMapSingleClick.sqf";
WFBE_CL_FNC_HandlePVF = Compile preprocessFileLineNumbers "Client\Functions\Client_HandlePVF.sqf";
WFBE_CL_FNC_OnKilled = Compile preprocessFileLineNumbers "Client\Functions\Client_OnKilled.sqf";
WFBE_CL_FNC_OperateCargoGear = Compile preprocessFileLineNumbers "Client\Functions\Client_OperateCargoGear.sqf";
WFBE_CL_FNC_ReplaceMagazinesGear = Compile preprocessFileLineNumbers "Client\Functions\Client_ReplaceMagazinesGear.sqf";
WFBE_CL_FNC_RemoveMagazineGear = Compile preprocessFileLineNumbers "Client\Functions\Client_RemoveMagazineGear.sqf";
WFBE_CL_FNC_SendSpawnedUnitsToLeaderWaypoint = Compile preprocessFileLineNumbers "Client\Functions\Client_SendSpawnedUnitsToLeaderWaypoint.sqf";
WFBE_CL_FNC_UI_Gear_AddTemplate = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_AddTemplate.sqf";
WFBE_CL_FNC_UI_Gear_DeleteTemplate = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_DeleteTemplate.sqf";
WFBE_CL_FNC_UI_Gear_DisplayInventory = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_DisplayInventory.sqf";
WFBE_CL_FNC_UI_Gear_FillCargoList = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_FillCargoList.sqf";
WFBE_CL_FNC_UI_Gear_FillList = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_FillList.sqf";
WFBE_CL_FNC_UI_Gear_FillTemplates = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_FillTemplates.sqf";
WFBE_CL_FNC_UI_Gear_ParseTemplateContent = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_ParseTemplateContent.sqf";
WFBE_CL_FNC_UI_Gear_Sanitize = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_Sanitize.sqf";
WFBE_CL_FNC_UI_Gear_UpdatePrice = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_UpdatePrice.sqf";
WFBE_CL_FNC_UI_Gear_UpdateTarget = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_UpdateTarget.sqf";
WFBE_CL_FNC_UI_Gear_UpdateView = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_UpdateView.sqf";
WFBE_CL_FNC_UI_Respawn_Selector = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Respawn_Selector.sqf";
WFBE_CL_FNC_SupplyMissionCompletedMessage = Call Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionCompletedMessage.sqf";
WFBE_CL_FNC_SupplyMissionStart = Call Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionStart.sqf";
WFBE_CL_FNC_TownSupplyStatus = Call Compile preprocessFileLineNumbers "Client\Module\supplyMission\townSupplyStatus.sqf";
WFBE_CL_FNC_CheckCCProximity = Compile preprocessFileLineNumbers "Client\Module\supplyMission\checkCCProximity.sqf";
//WFBE_CL_FNC_ReceiverMASHmarker = Call Compile preprocessFileLineNumbers "Client\Module\MASH\receiverMASHmarker.sqf";
WFBE_CL_PVEH_HasConnectedAtLaunch = Call Compile preprocessFileLineNumbers "Client\Module\AntiStack\hasConnectedAtLaunchACK.sqf";
WFBE_CL_FNC_FindVariableInNestedArray = Compile preprocessFileLineNumbers "Client\Functions\Client_FindVariableInNestedArray.sqf";
WFBE_CL_PV_ReceiveSupplyValue = Call Compile preprocessFileLineNumbers "Client\Functions\Client_ReceiveSupplyValue.sqf";
WFBE_CL_FNC_ReturnAircraftNameFromItsType = Compile preprocessFileLineNumbers "Common\Common_ReturnAircraftNameFromItsType.sqf";
WFBE_CL_FNC_SetMapIconStatusInCombat = Compile preprocessFileLineNumbers "Client\Functions\Client_SetMapIconStatusInCombat.sqf";
// WFBE_CL_FNC_BlinkMapIcons = Compile preprocessFileLineNumbers "Client\Functions\Client_BlinkMapIcons.sqf";
WFBE_CL_FNC_BlinkMapIcon = Compile preprocessFileLineNumbers "Client\Functions\Client_BlinkMapIcon.sqf";
// WFBE_CL_FNC_AddUnitToTrack = Compile preprocessFileLineNumbers "Client\Functions\Client_AddUnitToTrack.sqf";

//Affichage Rubber maps:
	Local_GUIWorking = false;
	//GPS BASE ZOOM
	zoomgps = 0.025;

	[]spawn{
		while {!WFBE_gameover} do{
			if (/*Local_GUIActive &&*/ !Local_GUIWorking /*&& (isNull Local_Camera)*/ && !(visibleMap) && (isNil "BIS_CONTROL_CAM") /*&& (RUBOSD == 1)*/) then {Local_GUIWorking=true; 1365 cutRsc ["RscOverlay","PLAIN",0]};//if GUI is not working, but it should - restart it
			sleep 0.8;
		};
	};


Call Compile preprocessFileLineNumbers 'Client\Functions\Client_FNC_Groups.sqf'; //--- FUNCTIONS: Groups.
Call Compile preprocessFileLineNumbers 'Client\Functions\Client_FNC_OnFired.sqf'; //--- FUNCTIONS: onFired EH.
Call Compile preprocessFileLineNumbers 'Client\Functions\Client_FNC_Special.sqf'; //--- FUNCTIONS: Specials.



//--- UI Namespace release from previous possible games (only on titles dialog!).
{uiNamespace setVariable [_x, displayNull]} forEach ["wfbe_title_capture"];

//--- Waiting for the common part to be executed.
waitUntil {commonInitComplete};

["INITIALIZATION", Format ["Init_Client.sqf: Common initialization is complete at [%1]", time]] Call WFBE_CO_FNC_LogContent;

if (ARMA_VERSION >= 162 && ARMA_RELEASENUMBER > 97105 || ARMA_VERSION > 162) then {
	//--- Profile namespace related.
	WFBE_CL_FNC_UI_Gear_SaveTemplateProfile = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_SaveTemplateProfile.sqf";
	Call Compile preprocessFileLineNumbers "Client\Init\Init_ProfileVariables.sqf";
};

// Marty : auto distance view feature deactivated at client start.
missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
missionNamespace setVariable ["AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT", false];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", []];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", grpNull];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_TIME", -5000];
// Marty: Timestamp used to distinguish active map commanders from players who only left the map open.
missionNamespace setVariable ["WFBE_CLIENT_LAST_MAP_COMMAND_CLICK_TIME", -5000];
missionNamespace setVariable ["WFBE_CLIENT_LAST_MAP_COMMAND_CLICK_POS", []];
missionNamespace setVariable ["WFBE_CLIENT_COMMAND_AND_CONQUER_WINDOW", 180];
// Marty: State used by Ctrl-click map disband because onMapSingleClick does not expose Ctrl.
missionNamespace setVariable ["WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN", false];

//--- Queue Protection.
missionNamespace setVariable ['WFBE_C_QUEUE_BARRACKS',0];
missionNamespace setVariable ['WFBE_C_QUEUE_BARRACKS_MAX',10];
missionNamespace setVariable ['WFBE_C_QUEUE_LIGHT',0];
missionNamespace setVariable ['WFBE_C_QUEUE_LIGHT_MAX',5];
missionNamespace setVariable ['WFBE_C_QUEUE_HEAVY',0];
missionNamespace setVariable ['WFBE_C_QUEUE_HEAVY_MAX',5];
missionNamespace setVariable ['WFBE_C_QUEUE_AIRCRAFT',0];
missionNamespace setVariable ['WFBE_C_QUEUE_AIRCRAFT_MAX',2];
missionNamespace setVariable ['WFBE_C_QUEUE_AIRPORT',0];
missionNamespace setVariable ['WFBE_C_QUEUE_AIRPORT_MAX',2];
missionNamespace setVariable ['WFBE_C_QUEUE_DEPOT',0];
missionNamespace setVariable ['WFBE_C_QUEUE_DEPOT_MAX',4];

//--- Handle the weather.
// Marty: Accelerated skipTime makes low clouds stutter, so day/night owns the weather and keeps each client sky clear.
Call {
	_weat = missionNamespace getVariable "WFBE_C_ENVIRONMENT_WEATHER";
	if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) exitWith {
		0 setOvercast 0;
		0 setRain 0;
	};
	if (_weat == 3) exitWith {};

	_oc = 0.05;
	switch (_weat) do {
		case 0: {_oc = 0};
		case 1: {_oc = 0.5};
		case 2: {_oc = 1};
	};
	60 setOvercast _oc;
};

// Marty: Volumetric clouds are disabled globally; never start the BIS cloud system on clients.
missionNamespace setVariable ["WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC", 0];

//--- Global Client Variables.
sideID = sideJoined Call GetSideID;
clientTeam = group player;
clientTeams = missionNamespace getVariable Format['WFBE_%1TEAMS',sideJoinedText];
playerType = typeOf player;
playerDead = false;
paramBoundariesRunning = false;

// View distance timer stuff
timerInstanceCount = 0;
newViewDistance = 0;

disableserialization;

keyPressed = compile preprocessFile "Common\Functions\Common_DisableTablock.sqf";
keyPressedForAutoSendSpawnedUnitsToWaypoint = compile preprocessFile "Common\Functions\Common_AutoSendSpawnedUnitsToWaypoint.sqf";
keyPressedForAdjustingViewDistance = compile preprocessFile "Common\Functions\Common_AdjustViewDistance.sqf";
_display = findDisplay 46;
_display displayAddEventHandler ["KeyDown","_this call keyPressed"];
_display displayAddEventHandler ["KeyDown","_this call keyPressedForAutoSendSpawnedUnitsToWaypoint"];
_display displayAddEventHandler ["KeyDown","_this call keyPressedForAdjustingViewDistance"];
// Marty: onMapSingleClick exposes Shift and Alt but not Ctrl, so track Ctrl state separately for map disband.
_display displayAddEventHandler ["KeyDown","if ((_this select 1) in [29,157]) then {missionNamespace setVariable ['WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN', true]}; false"];
_display displayAddEventHandler ["KeyUp","if ((_this select 1) in [29,157]) then {missionNamespace setVariable ['WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN', false]}; false"];
onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};

// Marty: Show the map AI shortcut tip once, the first time the player opens the map.
[] Spawn {
	waitUntil {sleep 0.5; visibleMap};
	titleText [localize "STR_WF_TEAM_MapShortcutTip", "PLAIN DOWN", 5];
};

WFBE_CO_FNC_DisableTabLock = compile preprocessFileLineNumbers "Common\Functions\Common_DisableTablock.sqf";

_display displayAddEventHandler ["KeyDown", "_this call WFBE_CO_FNC_DisableTabLock"];

WFBE_CO_FNC_HandleAFKkeys = compile preprocessFileLineNumbers "Client\Module\AFKkick\handleKeys.sqf";

AFKthresholdExceededName = name player;
WFBE_CO_VAR_AFKkickThreshold = 30;
WFBE_CO_VAR_NotAFK_update = false;
// Marty: Separate physical movement from map-command activity for AFK marker text only.
WFBE_CO_VAR_NotAFK_MovementUpdate = false;
// Marty: Keep anti-kick activity and physical movement separate for Command & Conquer marker state.
player setVariable ["lastActionTime", time];
player setVariable ["lastMovementTime", time];
// Marty: Networked marker state for immobile players who are still actively commanding from map clicks.
player setVariable ["WASP_AFK", false, true];
player setVariable ["WASP_CommandAndConquer", false, true];

_display displayAddEventHandler ["KeyDown", "_this call WFBE_CO_FNC_HandleAFKkeys"];

[] execVM "Client\Module\AFKkick\monitorAFK.sqf";

(vehicle player) addEventHandler ["Fired",{_this Spawn HandleAT}];
execVM "WASP\global_marking_monitor.sqf";
WFBE_Client_Logic = (WFBE_Client_SideJoined) Call WFBE_CO_FNC_GetSideLogic;
WFBE_Client_SideID = sideID;
WFBE_Client_Color = switch (WFBE_Client_SideJoined) do { case west: {missionNamespace getVariable "WFBE_C_WEST_COLOR"}; case east: {missionNamespace getVariable "WFBE_C_EAST_COLOR"}; case resistance: {missionNamespace getVariable "WFBE_C_GUER_COLOR"}};
WFBE_Client_Team = clientTeam;
WFBE_Client_Teams = clientTeams;
WFBE_Client_Teams_Count = count WFBE_Client_Teams;
WFBE_Client_IsRespawning = false;
WFBE_Client_LastGroupJoinRequest = -5000;
WFBE_Client_PendingRequests = [];
WFBE_Client_PendingRequests_Accepted = [];
WFBE_Client_SupplyMissionActive = false;
WFBE_C_VAR_FRIENDLYCOMMANDCENTERINPROXIMITY = false;

commanderTeam = objNull;
buildingMarker = 0;
CCMarker = 0;
gearCost = 0;
currentTG = 50;
if (currentTG == 50) then {setTerrainGrid currentTG};
lastBuilt = [];
unitQueu = 0;
fireMissionTime = -1000;
artyRange = 15;
artyPos = [0,0,0];
playerUAV = objNull;
comTask = objNull;
voted = false;
votePopUp = true;
manningDefense = true;
currentFX = 0;
lastParaCall = -1200;
lastSupplyCall = -1200;
canBuildWHQ = true;
WFBE_RespawnDefaultGear = false;
WFBE_ForceUpdate = true;

//--- Load Terrain grid if it wasn't loaded from the profile.
if (isNil 'currentTG') then {
	currentTG = if ((missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_CLUTTER") < 25) then {missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_CLUTTER"} else {25};
	setTerrainGrid currentTG;
};

hqInRange = false;
barracksInRange = false;
gearInRange = false;
lightInRange = false;
heavyInRange = false;
aircraftInRange = false;
serviceInRange = false;
commandInRange = false;
depotInRange = false;
antiAirRadarInRange = false;
hangarInRange = false;

enableTeamSwitch false;

//--- Import the client side upgrade informations.
ExecVM "Common\Config\Core_Upgrades\Labels_Upgrades.sqf";

//--- Update the player.
if (isMultiplayer) then {["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer};

/* HUD ON/OFF VALUE */
// Marty: Start RHUD hidden; players can still toggle it from the menu.
if (isNil "RUBHUD") then {RUBHUD = false};
// Marty: Separate lightweight FPS-only HUD toggle, hidden by default.
if (isNil "RUBFPSHUD") then {RUBFPSHUD = false};
if (isNil "RUBGPS") then {RUBGPS = 1};
if (isNil "RUBOSD") then {RUBOSD = 1};

/* HUD MODULE */
ExecVM "Client\Client_UpdateRHUD.sqf";

// Marty: Start the local client Performance Audit writer; metrics stay local and are written to the client RPT.
[] Spawn {
	waitUntil {!isNil "PerformanceAudit_Run"};
	["CLIENT"] Spawn PerformanceAudit_Run;
};

//--- Disable Artillery Computer.
Call Compile "enableEngineArtillery false;";

//--- Commander % stock init.
if ((missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM") in [3,4]) then {
	if (isNil {WFBE_Client_Logic getVariable "wfbe_commander_percent"}) then {WFBE_Client_Logic setVariable ["wfbe_commander_percent", 70]};
};

/* Exec SQF|FSM Misc stuff. */
if ((missionNamespace getVariable "WFBE_C_UNITS_TRACK_LEADERS") > 0) then {[] execVM "Client\FSM\updateteamsmarkers.sqf"};
[] execFSM "Client\FSM\updateactions.fsm";
/* Don't pause the client initialization process. */
[] Spawn {
	waitUntil {townInit};
	/* Handle the capture GUI */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Town Capture FSM"] Call WFBE_CO_FNC_LogContent;
	[] execVM "Client\FSM\client_title_capture.sqf";
	/* Handle the map town markers */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Towns Marker FSM"] Call WFBE_CO_FNC_LogContent;
	[] execVM "Client\FSM\updatetownmarkers.sqf";
	waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_structures"}};
	if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
		waitUntil {!isNil {missionNamespace getVariable format ["wfbe_supply_%1", sideJoinedText]}};
	};
	missionNamespace setVariable ["wfbe_supply", missionNamespace getVariable Format ["wfbe_supply_%1", sideJoinedText]];
	/* Handle the client actions */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Available Actions FSM"] Call WFBE_CO_FNC_LogContent;
	[] execFSM "Client\FSM\updateavailableactions.fsm";
	/* Resources Handler */
	if !((missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM") in [3,4]) then {
		["INITIALIZATION", "Init_Client.sqf: Initializing the Resources SQF"] Call WFBE_CO_FNC_LogContent;
		(sideJoined) execVM "Client\FSM\resources_cli.sqf";
	};
};

[] Spawn {
	Private ["_commanderTeam"];
	waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_commander"}};
	/* Commander Handling */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Commander Update FSM"] Call WFBE_CO_FNC_LogContent;
	[] ExecVM "Client\FSM\updateclient.sqf";
};

//--- Add the briefing (notes).
[] Call Compile preprocessFile "briefing.sqf";

//--- HQ Radio system.
waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_radio_hq"}};
_HQRadio = WFBE_Client_Logic getVariable "wfbe_radio_hq";
["INITIALIZATION", Format["Init_Client.sqf: Initialized the Radio Announcer [%1]", _HQRadio]] Call WFBE_CO_FNC_LogContent;
waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_radio_hq_id"}};
WFBE_V_HQTopicSide = WFBE_Client_Logic getVariable "wfbe_radio_hq_id";
["INITIALIZATION", Format["Init_Client.sqf: Initializing the Radio Announcer Identity [%1]", WFBE_V_HQTopicSide]] Call WFBE_CO_FNC_LogContent;
_HQRadio setIdentity WFBE_V_HQTopicSide;
_HQRadio setRank "COLONEL";
_HQRadio setGroupId ["HQ"];
_HQRadio kbAddTopic [WFBE_V_HQTopicSide,"Client\kb\hq.bikb","Client\kb\hq.fsm",{call compile preprocessFileLineNumbers "Client\kb\hq.sqf"}];
player kbAddTopic [WFBE_V_HQTopicSide,"Client\kb\hq.bikb","Client\kb\hq.fsm",{call compile preprocessFileLineNumbers "Client\kb\hq.sqf"}];
sideHQ = _HQRadio;

["INITIALIZATION", "Init_Client.sqf: Radio announcer is initialized."] Call WFBE_CO_FNC_LogContent;

/* Wait for a valid signal (Teamswaping) with failover */
if (isMultiplayer && ((missionNamespace getVariable "WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE") > 0 && !WF_Debug) && time > 7) then {
	Private ["_get","_timelaps"];
	_get = true;

	sleep (random 0.1);

	["RequestJoin", [player, sideJoined]] Call WFBE_CO_FNC_SendToServer;

	_timelaps = 0;
	while {true} do {
		sleep 0.1;
		_get = missionNamespace getVariable 'WFBE_P_CANJOIN';
		if !(isNil '_get') exitWith {["INITIALIZATION", Format["Init_Client.sqf: [%1] Client [%2], Can join? [%3]",sideJoined,name player,_get]] Call WFBE_CO_FNC_LogContent};

		_timelaps = _timelaps + 0.1;
		if (_timelaps > 30) then {
			_timelaps = 0;
			["WARNING", Format["Init_Client.sqf: [%1] Client [%2] join is pending... no ACK was received from the server, a new request will be submitted.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;
			["RequestJoin", [player, sideJoined]] Call WFBE_CO_FNC_SendToServer;
		};
	};

	if !(_get) exitWith {
		["WARNING", Format["Init_Client.sqf: [%1] Client [%2] has teamswapped/STACKED and is now being sent back to the lobby.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;

		12452 cutText [(localize 'STR_WF_CHAT_TeamstackOrTeamSwap'),"BLACK FADED",50000];
		sleep 12;
		failMission "END1";
	};
} else {
	Private ["_hasConnectedAtLaunchACK","_timelaps"];
	_timelaps = 0;
	WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player;
	publicVariableServer "WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH";
	while {true} do {
		sleep 0.1;
		_hasConnectedAtLaunchACK = missionNamespace getVariable 'WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK';
		if !(isNil '_hasConnectedAtLaunchACK') exitWith {["INITIALIZATION", Format["Init_Client.sqf: [%1] Client [%2], Can join? [%3]",sideJoined,name player,_hasConnectedAtLaunchACK]] Call WFBE_CO_FNC_LogContent};

		_timelaps = _timelaps + 0.1;
		if (_timelaps > 30) then {
			_timelaps = 0;
			["WARNING", Format["Init_Client.sqf: [%1] Client [%2] join is pending... no 'has connected at launch' ACK was received from the server, a new request will be submitted.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;
			WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player;
			publicVariableServer "WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH";
		};
	};
};

/* Get the client starting location */
["INITIALIZATION", "Init_Client.sqf: Retrieving the client spawn location."] Call WFBE_CO_FNC_LogContent;
_base = objNull;
if (time < 30) then {
	waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_startpos"}};
	_base = WFBE_Client_Logic getVariable "wfbe_startpos";
} else {
	waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_hq"}};
	waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_structures"}};
	_base = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
	_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;

    // Spawn joining client at newest Barracks, Light Factory, Heavy Factory or Air Factory, whichever is the newest
    if (count _buildings > 0) then {
	    for "_i" from ((count _buildings) - 1) to 0 do {
	        _structureType = (_buildings select _i) getVariable "wfbe_structure_type";
	        if (_structureType == "Barracks" || _structureType == "Light" || _structureType == "Heavy" || _structureType == "Aircraft") exitWith {
	            _base = _buildings select _i;
			};
		};
	};

    // if (count _buildings > 0) then {_base = _buildings select ((count _buildings) - 1)};
};

["INITIALIZATION", Format["Init_Client.sqf: Client spawn location has been determined at [%1].", _base]] Call WFBE_CO_FNC_LogContent;

/* Position the client at the previously defined location */
player setPos ([_base,20,30] Call GetRandomPosition);

/* HQ Building Init. */
waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_hq_deployed"}};
["INITIALIZATION", "Init_Client.sqf: Initializing COIN Module."] Call WFBE_CO_FNC_LogContent;
_isDeployed = (sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus;
if (_isDeployed) then {
	[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED",true,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
} else {
	[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED",false,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
};

//--- Add Killed EH to the HQ on each client if needed (JIP), skip LAN host.
if (!isServer && !_isDeployed) then {
	[] spawn {
		waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_hq"}};
		(WFBE_Client_SideJoined Call WFBE_CO_FNC_GetSideHQ) addEventHandler ["killed", {["RequestSpecial", ["process-killed-hq", _this]] Call WFBE_CO_FNC_SendToServer}];
	};
};

_greenList = [];
{_greenList = _greenList + [missionNamespace getVariable Format ["%1%2",WFBE_Client_SideJoinedText,_x]]} forEach ["BAR","LVF","HEAVY","AIR"];
missionNamespace setVariable ["COIN_UseHelper", _greenList];

/* Options menu. */
// Marty: Add the WF menu through a helper so the action ID is stored on player instead of only in a global variable.
player Call WFBE_CL_FNC_AddWFMenuAction;
player Call WFBE_CL_FNC_AddPlayerAIActions;
[] Spawn Compile preprocessFileLineNumbers "Client\Functions\Client_WatchdogPlayerAI.sqf";
// Marty: Refresh the native command bar when dead AI subordinates are not yet known by the local leader.
[] Spawn Compile preprocessFileLineNumbers "Client\Functions\Client_WatchdogCommandBarDeadUnits.sqf";

// Marty: Safety refresh for the WF menu.
// If another script removes the action by mistake, it comes back without waiting for respawn.
[] Spawn {
	Private ["_isRespawning"];

	while {!gameOver} do {
		_isRespawning = false;
		if !(isNil "WFBE_Client_IsRespawning") then {_isRespawning = WFBE_Client_IsRespawning};

		if (alive player && vehicle player == player && !_isRespawning) then {
			player Call WFBE_CL_FNC_AddWFMenuAction;
		};

		sleep 15;
	};
};

/* Zeta Cargo Lifter. */
[] Call Compile preprocessFile "Client\Module\ZetaCargo\Zeta_Init.sqf";
/* Set Groups ID. */
[] Call Compile preprocessFile "Client\Functions\Client_SetGroupsID.sqf";

sleep 1;

//--- Make sure that player is always the leader.
if (leader(group player) != player) then {(group player) selectLeader player};

/* Override player's Gear.*/
// [player,Format ["WFBE_%1DEFAULTWEAPONS",sideJoinedText] Call GetNamespace,Format ["WFBE_%1DEFAULTAMMO",sideJoinedText] Call GetNamespace] Call EquipLoadout;
/* Skill Module. */
[] Call Compile preprocessFile "Client\Module\Skill\Skill_Init.sqf";


_default = [];
switch (WFBE_SK_V_Type) do {
case "Spotter": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearSpot", WFBE_Client_SideJoinedText]};
case "Officer": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearOfficer", WFBE_Client_SideJoinedText]};
case "Soldier": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearSoldier", WFBE_Client_SideJoinedText]};
case "Engineer": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearEngineer", WFBE_Client_SideJoinedText]};
case "SpecOps": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearLock", WFBE_Client_SideJoinedText]};
case "Medic": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearMedic", WFBE_Client_SideJoinedText]};
};

//_default = missionNamespace getVariable Format["WFBE_%1_DefaultGear", WFBE_Client_SideJoinedText];
if (count _default <= 3) then {
	[player, _default select 0, _default select 1, _default select 2] Call WFBE_CO_FNC_EquipUnit;
} else {
	[player, _default select 0, _default select 1, _default select 2, _default select 3, _default select 4] Call WFBE_CO_FNC_EquipUnit;
};

/* Default gear menu filler. */
WF_Logic setVariable ['filler','primary'];

/* Skill Module. */
[] Call Compile preprocessFile "Client\Module\Skill\Skill_Init.sqf";
(player) Call WFBE_SK_FNC_Apply;

[] execVM "WASP\baserep\init.sqf";
[] execVM "WASP\actions\AddActions.sqf";

// Marty: Start a light client-side watcher that rights nearby flipped cars and tanks after they remain stuck.
[] execVM "Client\Module\AutoFlip\AutoFlip.sqf";

/* Debug System - Client */
if (WF_Debug) then {
	//player addEventHandler ["HandleDamage", {false}];
	// player setCaptive true;
	// player addEventHandler ["HandleDamage", {false;if (player != (_this select 3)) then {(_this select 3) setDammage 1}}]; //--- God-Slayer mode.
};
execVM "limitThirdPersonView.sqf";

if ((missionNamespace getVariable "WFBE_C_ARTILLERY_UI") > 0) then {[] ExecVM "ca\modules\ARTY\data\scripts\init.sqf"}; //--- Artillery UI.
if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_EASA") > 0) then {Call Compile preprocessFileLineNumbers "Client\Module\EASA\EASA_Init.sqf"}; //--- EASA.
if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") > 0 && WF_A2_Vanilla) then {Call Compile preprocessFileLineNumbers "Client\Module\CM\CM_Init.sqf"}; //--- Countermeasures.

/* Key Binding */
[] Call Compile preprocessFile "Client\Init\Init_Keybind.sqf";

/* JIP Handler */
waitUntil {townInit};
["INITIALIZATION", "Init_Client.sqf: Towns are initialized."] Call WFBE_CO_FNC_LogContent;

//--- Define the CoIn placement method.
switch (missionNamespace getVariable "WFBE_C_STRUCTURES_COLLIDING") do {
    //--- Smooth.
    case 1: {
		missionNamespace setVariable ["WFBE_C_STRUCTURES_PLACEMENT_METHOD",{
           		 Private ["_color","_itemcategory","_preview","_area","_eside"];
			_itemcategory = _this select 0;
			_preview = _this select 1;
			_color = _this select 2;
            _eside = if (side commanderTeam == west) then {east} else {west};
            	_affected = ["Warfare_HQ_base_unfolded","Base_WarfareBBarracks","Base_WarfareBLightFactory","Base_WarfareBHeavyFactory",
            					"Base_WarfareBAircraftFactory","Base_WarfareBUAVterminal","Base_WarfareBVehicleServicePoint","BASE_WarfareBAntiAirRadar"];
			_area = [_preview,((sidejoined) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity2;

            	if(_area getVariable 'avail' <= 0) then { _color = _colorRed };
           		if (surfaceIsWater(position _preview)) then { _color = _colorRed };

			if ({_preview isKindOf _x} count _affected != 0) then {
                	Private["_building","_sort","_strs","_lax","_lay"];
                	_strs = ((position _preview) nearObjects ["House",25]) - [_preview];
               		if (count _strs == 0) exitWith {};
                	_sort = [_preview,_strs] Call SortByDistance;
                	_building = _sort select 0;
                	_lax=((boundingBox _building) select 1) select 0;
                	_lay=((boundingBox _building) select 1) select 1;
                	if(_preview distance _building < 1.5*(_lax max _lay)) then {
				_color = _colorRed
			} else{
				_color = _colorGreen
			};
            	};

			if (_itemcategory == 2) then {

                	Private["_i","_factory","_sorted","_walls","_factories","_area","_lx","_ly","_type","_p","_entities"];

                	_color = _colorGreen;
                	_walls = nearestObjects [_preview,[typeOf _preview],2];

                	if(count _walls > 1) then {_color = _colorRed} else{_color = _colorGreen};
                if(count (nearestObjects [_preview,missionNamespace getVariable (Format["WFBE_%1DEFENSENAMES",sideJoined]),((((boundingbox _preview) select 1) select 0) max (((boundingbox _preview) select 1) select 1)) max 2] - [_preview]) > 0) then {_color = _colorRed} else{_color = _colorGreen};
				_entities = (position _preview) nearEntities [['Man','Car','Motorcycle','Tank','Air','Ship'],12];
				if ((count _entities > 0) && {side _x != sideJoined} count _entities !=0) then {_color = _colorRed};
                _factories =	 nearestObjects[_preview,["Warfare_HQ_base_unfolded","WarfareBBaseStructure","Base_WarfareBContructionSite"],25];
				if (count _factories == 0) exitWith {};
                _sorted = [_preview,_factories] Call SortByDistance;
                _factory = _sorted select 0;
                _type=typeOf _factory;
                _lx=((boundingbox _factory) select 1) select 0;
                _ly=((boundingbox _factory) select 1) select 1;

                switch (true) do {
					case ( _factory isKindOf "Warfare_HQ_base_unfolded"):{_p=0.6};
					case ( _factory isKindOf "Base_WarfareBBarracks"):{_p=0.57};
					case ( _factory isKindOf "Base_WarfareBLightFactory"):{_p=0.6};
					case ( _factory isKindOf "Base_WarfareBHeavyFactory"):{_p=0.54};
					case ( _factory isKindOf "Base_WarfareBAircraftFactory"):{_p=0.74};
					case ( _factory isKindOf "Base_WarfareBUAVterminal"):{_p=1};
					case ( _factory isKindOf "Base_WarfareBContructionSite"):{_p=12};

					default {_p=1};
				};

                	if(_preview distance _factory < _p*(_lx min _ly)) then {_color = _colorRed};

			}else{
				private ["_objects","_sideEfacs","_object"];
				_sideEfacs = if (side commanderTeam == west) then {east} else {west};
				_objects = nearestObjects [_preview,["WarfareBBaseStructure","Base_WarfareBContructionSite"],25];
				if (count _objects > 0) then {
					if (side (_objects select 0) == _sideEfacs && _preview distance (_objects select 0) < 10)then {_color = _colorRed};
				};
			};

			if (_itemcategory == 3) then {
				Private["_camos"];
				_color = _colorGreen;
                _camos = nearestObjects [_preview,[typeOf _preview],25];

                	if(count _camos > 1) then {
                    	_color = _colorRed
                    } else{
                	_color = _colorGreen};
			};

			if (typeOf _preview == "Sign_Danger" && !isNull ([_preview,((sidejoined) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity2)) then {
				_color = _colorRed;
				hintsilent "Minefields are not allowed at base!";
			};
            	if (_itemcategory != 0 && typeOf _preview isKindOf "Base_WarfareBVehicleServicePoint") then {
                	_color = _colorGreen;
            	};

            	if ((typeOf _preview) isKindOf "StaticWeapon") then { _color = _colorGreen; };

			if (_itemcategory == 0) then {
				Private ["_town","_townside","_eArea"];
				_town = [_preview] Call GetClosestLocation;
			    _townside =  (_town getVariable "sideID") Call GetSideFromID;
			    _eArea = [_preview,((_eside) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity3;
	            if ((_preview distance _town < 600 && _townside != sideJoined) || !isNull _eArea) then {
					_color = _colorRed;
					 hintSilent parseText "<t color='#fb0808'> You have entered a restricted area ! Impossible to build here! </t>";
				};
	        };

            	if( !((typeOf _preview) iskindOf "Warfare_HQ_base_unfolded"))then{
                    _current_side  = side commanderTeam;
                    _opposite_side = east;

                    if(_current_side == west)then{
                        _opposite_side = east;
	} else{
                        _opposite_side = west;
	};

            		_detected = (_area nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], missionNamespace getVariable "WFBE_C_BASE_AREA_RANGE"]) unitsBelowHeight 20;
            		{
            			if(_itemcategory !=0 && side _x == _opposite_side)exitwith{
            				_color = _colorRed;
            				hintSilent parseText "<t color='#fb0808'> Enemies are detected near your base! </t>";
            			};

            		}foreach _detected;
};

			_color
		}];
	};
};

sleep 3;
/* JIP System, initialize the camps and towns properly. */
[] Spawn {
	sleep 2;
	["INITIALIZATION", "Init_Client.sqf: Updating JIP Markers."] Call WFBE_CO_FNC_LogContent;
	Call Compile preprocessFileLineNumbers "Client\Init\Init_Markers.sqf";
};

/* Repair Truck CoIn Handling. */
[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_REPAIR",false,RCoin,"REPAIR"] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";

/* A new player come to reinforce the battlefield */
[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;

/* Towns Task System */
// ["TownAddComplete"] Spawn TaskSystem;

/* Client death handler. */
WFBE_PLAYERKEH = player addEventHandler ['Killed', {[_this select 0,_this select 1] Spawn WFBE_CL_FNC_OnKilled; [_this select 0,_this select 1, sideID] Spawn WFBE_CO_FNC_OnUnitKilled}];

//--- Valhalla init.
[] Spawn {
	[] Call Compile preprocessFile "Client\Module\Valhalla\Init_Valhalla.sqf";
};

//if (!WF_Debug) then {playMusic "Track11_Large_Scale_Assault";};


waitUntil {!(isNull player)};

WFBE_C_PLAYER_OBJECT = [player, getPlayerUID player];
publicVariableServer "WFBE_C_PLAYER_OBJECT";

{

	_town = _x;

	missionNamespace setVariable ["WFBE_Client_PV_IsSupplyMissionActiveInTown", [player, _town]];
			
	publicVariableServer "WFBE_Client_PV_IsSupplyMissionActiveInTown";

} forEach towns;


/* Client Init Done - Remove the blackout */
12452 cutText [(localize 'STR_WF_Loading')+"...","BLACK IN",1];

player setVariable ["score", 0];

// Marty: Do not start the blinking marker bookkeeping loop unless the global mission parameter enables it.
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) == 1) then {
	[] execVM "Client\Functions\Client_BookkeepBlinkingIcons.sqf";
};
// [] execVM "Client\Functions\Client_BlinkMapIcons.sqf";

_video = ["Videos\intro720p.ogv"] call BIS_fnc_playVideo;

/* Vote System, define whether a vote is already running or not */
waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_votetime"}};
["INITIALIZATION", "Init_Client.sqf: Vote system is initialized."] Call WFBE_CO_FNC_LogContent;
if ((WFBE_Client_Logic getVariable "wfbe_votetime") > 0) then {createDialog "WFBE_VoteMenu"};

//--- Marty: missile terrain masking pre-shot warning.
//--- Runs once per client and warns the player while the current aimed/locked target is masked by terrain.
//--- The actual missile blocking is still handled by the Fired eventHandler.

[] spawn {
	private [
		"_toleranceAboveGround",
		"_lastLockSoundTime",
		"_lockSoundInterval",
		"_isRestrictedMissileAmmo"
	];

	_toleranceAboveGround = 2.5;

	_lastLockSoundTime = 0;

	// Adjust this value according to the real duration of your sound file.
	// Keep the sound short to avoid long audio tails after the terrain masking state changes.
	_lockSoundInterval = 1.0;

	// Restricted missile ammo detection for terrain-masking missile glitch prevention.
	// This automatically detects missile-like guided / lockable ammo from CfgAmmo.
	_isRestrictedMissileAmmo = {
		private [
			"_ammo",
			"_ammoCfg",
			"_simulation",
			"_irLock",
			"_laserLock",
			"_airLock",
			"_manualControl",
			"_isMissileOrRocket",
			"_isGuided"
		];

		_ammo = _this select 0;
		_ammoCfg = configFile >> "CfgAmmo" >> _ammo;

		if !(isClass _ammoCfg) exitWith {false};

		_simulation = getText (_ammoCfg >> "simulation");

		_irLock = getNumber (_ammoCfg >> "irLock");
		_laserLock = getNumber (_ammoCfg >> "laserLock");
		_airLock = getNumber (_ammoCfg >> "airLock");
		_manualControl = getNumber (_ammoCfg >> "manualControl");

		/*
			Most missiles / rockets in Arma 2 use missile-like or rocket-like simulations.
			We do not want bullets, shells, grenades or bombs to be affected.
		*/
		_isMissileOrRocket = _simulation in [
			"shotMissile",
			"shotRocket"
		];

		/*
			Guided / lockable missiles usually expose one or more of these config values.
			manualControl covers wire-guided / SACLOS style missiles.
			
			canLock is intentionally not used here because it can be too broad and may create false positives.
		*/
		_isGuided = (
			_irLock > 0 ||
			_laserLock > 0 ||
			_airLock > 0 ||
			_manualControl > 0
		);

		(_isMissileOrRocket && _isGuided)
	};

	while {!WFBE_gameover} do {
		call {
			private [
				"_vehicle",
				"_currentWeapon",
				"_currentWeaponMagazines",
				"_currentWeaponIsRestrictedMissile",
				"_ammo",
				"_unit_targeted",
				"_fromPos",
				"_targetPos",
				"_terrainMasked"
			];

			_vehicle = vehicle player;

			if (_vehicle == player) exitWith {};
			if !(player in crew _vehicle) exitWith {};

			// Check if the currently selected vehicle weapon uses a restricted missile ammo.
			_currentWeapon = currentWeapon _vehicle;
			if (_currentWeapon == "") exitWith {};

			_currentWeaponMagazines = getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines");
			_currentWeaponIsRestrictedMissile = false;

			{
				_ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");

				if ([_ammo] call _isRestrictedMissileAmmo) exitWith {
					_currentWeaponIsRestrictedMissile = true;
				};

			} forEach _currentWeaponMagazines;

			if !(_currentWeaponIsRestrictedMissile) exitWith {};

			// Retrieve the currently aimed / targeted object.
			// cursorTarget is used because Arma 2 OA does not provide a reliable command
			// to retrieve the player's actual missile lock target for all relevant vehicle weapons.
			// Note: cursorTarget can also return objects simply looked at by the player.
			_unit_targeted = cursorTarget;

			if (isNull _unit_targeted) exitWith {
				_lastLockSoundTime = 0;
			};

			// Only vehicles are relevant targets here.
			if !(_unit_targeted isKindOf "LandVehicle" || _unit_targeted isKindOf "Air") exitWith {
				_lastLockSoundTime = 0;
			};

			// Check if terrain blocks the line between the firing vehicle and the target.
			// A small vertical tolerance is added to avoid false terrain masking detection.
			_fromPos = getPosASL _vehicle;
			_fromPos set [2, (_fromPos select 2) + _toleranceAboveGround];

			_targetPos = getPosASL _unit_targeted;
			_targetPos set [2, (_targetPos select 2) + _toleranceAboveGround];

			_terrainMasked = terrainIntersectASL [_fromPos, _targetPos];

			if (_terrainMasked) then {

				// Target is locked but terrain masking is detected:
				// missile launch is not authorized.
				titleText [localize "STR_WF_MESSAGE_MissileTerrainMaskingWarning", "PLAIN DOWN", 0.2];

				// Reset lock sound timer so the lock tone can play immediately
				// when the line of sight becomes clear again.
				_lastLockSoundTime = 0;

			} else {

				// Target is locked and no terrain masking is detected:
				// missile launch is authorized.
				titleText [localize "STR_WF_MESSAGE_MissileTerrainMaskingLockAuthorized", "PLAIN", 0.2];

				if ((time - _lastLockSoundTime) > _lockSoundInterval) then {
					playSound "SidewinderLock";
					_lastLockSoundTime = time;
				};
			};
		};

		sleep 0.5;
	};
};
// Marty: end of glitch missiles warning script.

// Marty : initialise the low gear assist for local AI-driven tanks controlled by the player's group
[] spawn Compile preprocessFileLineNumbers "Client\Module\Valhalla\Func_Client_AI_LowGear_Manager.sqf";

clientInitComplete = true;

hint parseText "v16052026 <br/><br/> <t color='#28ff14'>If you're a new player:</t> <br/><br/>Read the instructions on map (press 'M' key) on the 'Notes' tab. <br/><br/>Our Discord server: <br/><br/><t color='#28ff14'>discord.me/warfare</t>  <br/><br/>(Open the link with a web browser like Chrome) <br/><br/>Ask in chat or on our Discord server if you want to know how something works. <br/><br/>You and your units are marked with <t color='#FFAC1C'>orange</t> color on map. <br/><br/>Friendly towns are marked with <t color='#1ff026'>green</t> color. <t color='#000bde'>Blue</t> and <t color='#de0300'>red</t> towns are controlled by enemy. <br/><br/>Note that you see friendly players and vehicles on map. <br/><br/><t color='#42b6ff'>WF menu</t> is important. You can open it by using action menu (mouse scroll). <br/><br/>Welcome and good luck, soldier! :)";

CLIENT_INIT_READY = player;

publicVariableServer "CLIENT_INIT_READY";

["INITIALIZATION", Format ["Init_Client.sqf: Client initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;
