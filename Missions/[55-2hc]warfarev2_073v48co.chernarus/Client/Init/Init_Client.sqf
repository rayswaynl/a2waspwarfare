Private ['_HQRadio','_base','_buildings','_condition','_get','_idbl','_isDeployed','_oc','_weat','_rearmor','_playerObject','_hasConnectedAtLaunchACK', '_vehiclePlayer'];

["INITIALIZATION", Format ["Init_Client.sqf: Client initialization begins at [%1]", time]] Call WFBE_CO_FNC_LogContent;
diag_log format ["Init_Client.sqf: Client initialization begins at [%1]", time];

//--- JOIN ROBUSTNESS (B49 2026-06-19): a stalled client init must NEVER leave the player on a permanent
//--- black screen. The BLACK FADED fade (layer 12452, set in initJIPCompatible) is normally cleared at
//--- ~L849 (BLACK IN). If client init stalls before that, this watchdog force-clears the fade after 45s
//--- and logs it (so a recurring stall is visible in the client RPT). Happy-path joins set
//--- clientInitComplete (~L1032) long after the fade clears, so this only fires on a genuine stall.
//--- JIP FADE FIX v4 (2026-06-20): the v2/v3 watchdogs FROZE - they gated on waitUntil/sleep/clientInitComplete
//--- before clearing, but while a JIP client sits on the stuck loading/black screen the SIM IS PAUSED: `sleep`
//--- suspends, mission `time` never advances, and clientInitComplete never sets -> the gate never opens -> the
//--- clear never runs (this is why B49/B52/B53 silently did nothing). v4 clears layer 12452 IMMEDIATELY and
//--- repeatedly with `uiSleep` (real-time, keeps ticking while the sim is paused) and NO gate, so a
//--- black-stranded JIP player is freed within ~1s even through the ~25x re-init churn. Harmless on healthy
//--- joins. (Root cause - the re-init churn from the [55] name vs 34-role mismatch + HC-without-identity loop -
//--- is a separate server-side fix; this frees the screen regardless.)
[] spawn {
	for "_fk" from 1 to 90 do {
		12452 cutText ["", "PLAIN", 0];
		uiSleep 1;
	};
};

//--- JOIN ROBUSTNESS (B49): if this client landed on a deleted/shell slot, `player` is null and
//--- `side player` below would silently break the whole init -> permanent black. Bail gracefully
//--- (the watchdog above still clears the fade so the player can respawn/retry instead of staring at black).
if (isNull player) exitWith {["ERROR", "Init_Client.sqf: player is NULL at init (joined a deleted/shell slot?) - aborting client init gracefully; fade watchdog clears the screen."] Call WFBE_CO_FNC_LogContent};

sideJoined = side player;
//--- CIV-SIDE GUARD (B76 2026-06-29): on a reconnect/JIP the engine can briefly report `side player == civilian`
//--- (HC seat-magnet + in-place restart re-slot churn). `sideJoined` is read ONCE here and never re-derived, so a
//--- transient CIVILIAN sticks forever -> WFBE_Client_Logic resolves to objNull -> the EARLYHEAL poller spins ~30min
//--- and Client_UpdateRHUD's GetSideUpgrades select indexes objNull (per-tick RPT error). Every PLAYABLE slot is a
//--- military unit, so a civilian `side player` is always wrong: re-derive the real side from the unit's class config
//--- (mirrors the proven AI_AdvancedRespawn.sqf:14-16 pattern). A normal player (west/east/resistance) skips this
//--- entirely - behaviour is unchanged. A2-OA-1.64 safe: getNumber / configFile >> / typeOf / switch / case are core.
if (sideJoined == civilian) then {
	sideJoined = switch (getNumber (configFile >> "CfgVehicles" >> (typeOf player) >> "side")) do {case 0: {east}; case 1: {west}; case 2: {resistance}; default {civilian}};
	diag_log format ["CLIENTTEAMS|CIV-GUARD|re-derived sideJoined from class %1 -> %2 at=%3s", typeOf player, str sideJoined, round time];
};
sideJoinedText = str sideJoined;
//--- WF3 Compatible.
WFBE_Client_SideJoined = sideJoined;
WFBE_Client_SideJoinedText = sideJoinedText;
WFBE_Allow_HostileGearSaving = true;

//--- DEADSPAWN SAFETY (2026-06-14): the joining player is parked on the side TempRespawnMarker /
//--- deadspawn holding area (among the AI-slot bots) until the Task-35 logic below relocates them
//--- to base. Make them INVULNERABLE for that whole transit so a holding-area bot can't kill them
//--- ("AI killed <player> in the deadspawn" bug). Re-enabled once they've escaped to base (flag set
//--- after the final move) OR after a hard 120s timeout - so a stalled join never leaves the player
//--- permanently invulnerable. Initial join + JIP rejoin both pass through here; respawns do not.
player allowDamage false;
missionNamespace setVariable ["WFBE_Client_DeadspawnEscaped", false];
[] spawn {
	private ["_t0"];
	_t0 = time;
	waitUntil { sleep 0.5; (missionNamespace getVariable ["WFBE_Client_DeadspawnEscaped", false]) || (time - _t0 > 120) };
	sleep 3;
	if (alive player) then { player allowDamage true };
};

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

//--- Command Deck: store _rearmor code in a global so SkinSelector_Apply.sqf can re-attach it post-swap.
WFBE_CL_VAR_ReArmorCode = _rearmor;

player addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
[] execVM "Common\Functions\Common_Bipod.sqf";

UpdateMarker = Compile preprocessFile "Common\Functions\Common_UpdateMarker.sqf";
//--- OPTIONAL CLIENT MODS (cmdcon42-m): detect curated sound/visual/HUD mods on THIS client and cache
//--- flags (WFBE_HAS_FX_MOD / WFBE_HAS_SOUND_MOD / WFBE_HAS_HUD_MOD) that the FX-suppression hooks read.
//--- Whole feature gated by WFBE_C_MODHOOKS (default 1). Safe no-op for players without any mod.
WFBE_CL_FNC_ModDetect = Compile preprocessFileLineNumbers "Client\Functions\Client_ModDetect.sqf";
BoundariesIsOnMap = Compile preprocessFile "Client\Functions\Client_IsOnMap.sqf";
BoundariesHandleOnMap = Compile preprocessFile "Client\Functions\Client_HandleOnMap.sqf";
BuildUnit = Compile preprocessFile "Client\Functions\Client_BuildUnit.sqf";
ChangePlayerFunds = Compile preprocessFile "Client\Functions\Client_ChangePlayerFunds.sqf";
//--- cmdcon43-d (Build 88 FIX): refund helper that mirrors the commander defense CHARGE currency.
//--- A commander (commanderTeam == group player) building a defense is charged from side SUPPLY under
//--- WFBE_C_CMD_DEF_SUPPLY + dual-currency (coin_interface.sqf "//--- Defense." block); everyone else and the
//--- funds-only currency system are charged funds. On a server-side reject the refund MUST return the pool
//--- that was charged, so LocalizeMessage.sqf routes all defense refunds through here. _this = amount (>0).
//--- A2-OA-safe: group player / getVariable / == / ChangeSideSupply|ChangePlayerFunds only.
WFBE_CMD_DEF_SUPPLY_REFUND = {
	private ["_amt"];
	_amt = _this;
	if (isNil "_amt" || {typeName _amt != "SCALAR"} || {_amt <= 0}) exitWith {};
	//--- WFBE_LastDefenseChargeSupply is stamped by coin_interface.sqf at the moment of charge (true =
	//--- side supply via the MCoin commander console, false = player funds). Refund the SAME pool. Defense
	//--- place -> server-reject is sequential per client, so the last stamp reliably identifies the pending
	//--- charge. Default false (funds) if never stamped this session (pre-any-placement / legacy behaviour).
	if (!isNil "WFBE_LastDefenseChargeSupply" && {WFBE_LastDefenseChargeSupply}) then {
		[sideJoined, _amt, "Commander defense refund.", false] Call ChangeSideSupply;
	} else {
		_amt Call ChangePlayerFunds;
	};
};
if (isNil "WFBE_LastDefenseChargeSupply") then {WFBE_LastDefenseChargeSupply = false};
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

//--- OPTIONAL CLIENT MODS (cmdcon42-m) — HOOK 3: run detection ONCE and, if any curated optional mod is
//--- loaded on this client, emit a single friendly ack (systemChat + RPT line). Read-only, per-client, no
//--- gameplay effect. Players without any optional mod: WFBE_CL_FNC_ModDetect returns [] -> no chat, no log,
//--- behaviour identical to today. Gated by WFBE_C_MODHOOKS inside the helper.
if (!isNil "WFBE_CL_FNC_ModDetect") then {
	private ["_mods"];
	_mods = [] call WFBE_CL_FNC_ModDetect;
	if (count _mods > 0) then {
		private ["_names"];
		_names = _mods select 0;
		{ if (_forEachIndex > 0) then { _names = _names + ", " + _x }; } forEach _mods;
		systemChat (Format ["[WASP] Optional mods detected: %1 - enjoy!", _names]);
		diag_log (Format ["MODHOOKS|ACK|optional client mods detected on this client: %1", _mods]);
		["INFORMATION", Format ["Init_Client.sqf: optional client mods detected: %1", _mods]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Namespace related (GUI).
BIS_FNC_GUIset = {UInamespace setVariable [_this select 0, _this select 1]};
BIS_FNC_GUIget = {UInamespace getVariable (_this select 0)};

//--- New Fnc.
// Marty: Centralized WF menu action helper. It keeps the mouse wheel WF menu tied to the current player object.
WFBE_CL_FNC_AddWFMenuAction = Compile preprocessFileLineNumbers "Client\Functions\Client_AddWFMenuAction.sqf";
WFBE_CL_FNC_AddPlayerAIActions = Compile preprocessFileLineNumbers "Client\Functions\Client_AddPlayerAIActions.sqf";
WFBE_CL_FNC_ChangeClientFunds = Compile preprocessFileLineNumbers "Client\Functions\Client_ChangePlayerFunds.sqf";
// Marty: Local cleanup for town AI delegated to this client or headless client.
WFBE_CL_FNC_CleanupDelegatedTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_CleanupDelegatedTownAI.sqf";
WFBE_CL_FNC_DelegateTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateTownAI.sqf";
WFBE_CL_FNC_DelegateAIStaticDefence = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAIStaticDefence.sqf";
WFBE_CL_FNC_GetAIID = Compile preprocessFileLineNumbers "Client\Functions\Client_GetAIID.sqf";
WFBE_CL_FNC_GetBackpackContent = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Client\Functions\Client_GetBackpackContent.sqf"} else {{[[],[]]}};
WFBE_CL_FNC_GetClientFunds = Compile preprocessFileLineNumbers "Client\Functions\Client_GetPlayerFunds.sqf";
WFBE_CL_FNC_ConfirmAction = Compile preprocessFileLineNumbers "Client\Functions\Client_ConfirmAction.sqf";
// Marty: Condition helper used by Repair Camp addActions so the mouse wheel menu only shows it near destroyed camps.
WFBE_CL_FNC_CanRepairCampNearby = Compile preprocessFileLineNumbers "Client\Functions\Client_CanRepairCampNearby.sqf";
WFBE_CL_FNC_GetRepairTruckServicePoints = Compile preprocessFileLineNumbers "Client\Functions\Client_GetRepairTruckServicePoints.sqf";
WFBE_CL_FNC_CanUseRepairPointEASA = Compile preprocessFileLineNumbers "Client\Functions\Client_CanUseRepairPointEASA.sqf";
WFBE_CL_FNC_CanUseTownCenterEASA = Compile preprocessFileLineNumbers "Client\Functions\Client_CanUseTownCenterEASA.sqf";	//--- GUER-only: EASA at friendly town centers (base-less faction has no service points)
WFBE_CL_FNC_CanUseTownCenterBarrelBomb = Compile preprocessFileLineNumbers "Client\Functions\Client_CanUseTownCenterBarrelBomb.sqf";	//--- fable/guer-barrelbomb: GUER-only, same town-center idiom as the EASA check above - "Call Barrel Bomb" addAction condition.
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
WFBE_CL_FNC_SupplyMissionStart = Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionStart.sqf";
WFBE_CL_FNC_SupplyMissionUnload = Compile preprocessFileLineNumbers "Client\Module\supplyMission\supplyMissionUnload.sqf";
WFBE_CL_FNC_TownSupplyStatus = Call Compile preprocessFileLineNumbers "Client\Module\supplyMission\townSupplyStatus.sqf";
//--- SM9/XR2: removed dead WFBE_CL_FNC_CheckCCProximity (checkCCProximity.sqf) -- compiled, zero callers.
WFBE_CL_PVEH_HasConnectedAtLaunch = Call Compile preprocessFileLineNumbers "Client\Module\AntiStack\hasConnectedAtLaunchACK.sqf";
WFBE_CL_FNC_FindVariableInNestedArray = Compile preprocessFileLineNumbers "Client\Functions\Client_FindVariableInNestedArray.sqf";
WFBE_CL_PV_ReceiveSupplyValue = Call Compile preprocessFileLineNumbers "Client\Functions\Client_ReceiveSupplyValue.sqf";
WFBE_CL_FNC_ReturnAircraftNameFromItsType = Compile preprocessFileLineNumbers "Common\Common_ReturnAircraftNameFromItsType.sqf";
WFBE_CL_FNC_SetMapIconStatusInCombat = Compile preprocessFileLineNumbers "Client\Functions\Client_SetMapIconStatusInCombat.sqf";
WFBE_CL_FNC_BlinkMapIcon = Compile preprocessFileLineNumbers "Client\Functions\Client_BlinkMapIcon.sqf";

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
//--- QoL trio feat.3: advisor nudge function.
WFBE_CL_FNC_QOL_Advisor = Compile preprocessFileLineNumbers 'Client\Functions\Client_QOL_Advisor.sqf';



//--- UI Namespace release from previous possible games (only on titles dialog!).
{uiNamespace setVariable [_x, displayNull]} forEach ["wfbe_title_capture"];

//--- Waiting for the common part to be executed.
waitUntil {commonInitComplete};

["INITIALIZATION", Format ["Init_Client.sqf: Common initialization is complete at [%1]", time]] Call WFBE_CO_FNC_LogContent;

//--- qol-polish-pack: friendly name-tag overlay, toggled from the WF menu "TAGS" button (MenuAction 25). Client-side, friendly-PLAYERS only,
//--- distance-scaled, pooled controls (no per-frame create). A2-safe: worldToScreen / visiblePosition / ctrlSetStructuredText, no A3 commands.
if (isNil "WFBE_NameTagsEnabled") then {WFBE_NameTagsEnabled = false};
[] spawn {
	disableSerialization; //--- cmdcon42 (Ray 2026-07-02): this scheduled loop holds display/control handles (_disp, _ctrl) across waitUntil/sleep suspensions. Without disableSerialization the scheduler tries to serialise _disp when the script suspends and throws "variable '_disp' does not support serialization" the moment the TAGS button (MenuAction 25) enables the overlay. Must live in THIS script body (same scope as the display var), not a parent.
	private ["_max","_disp","_shown","_pp","_scr","_ctrl","_d","_sz"];
	_max = 18;
	while {!WFBE_gameover} do {
		waitUntil {WFBE_NameTagsEnabled || WFBE_gameover};
		if (WFBE_gameover) exitWith {};
		12461 cutRsc ["WFBE_NameTagOverlay","PLAIN",0];
		waitUntil {(!isNull (uiNamespace getVariable ["wfbe_nametag_display", displayNull])) || (!WFBE_NameTagsEnabled)};
		_disp = uiNamespace getVariable ["wfbe_nametag_display", displayNull];
		while {WFBE_NameTagsEnabled && {!WFBE_gameover} && {!isNull _disp}} do {
			_shown = 0;
			{
				if (_shown < _max && {isPlayer _x} && {_x != player} && {alive _x} && {side _x == side player}) then {
					_pp = visiblePosition _x; //--- cmdcon30: getPosVisual is Arma-3-only (undefined in A2-OA 1.64); visiblePosition is the A2 equivalent.
					_scr = worldToScreen [_pp select 0, _pp select 1, (_pp select 2) + 1.9];
					if (count _scr == 2 && {(_scr select 0) > 0} && {(_scr select 0) < 1} && {(_scr select 1) > 0} && {(_scr select 1) < 1}) then {
						_d = _x distance player;
						_sz = 0.018 + (0.016 * (1 - (_d / 120)));
						_ctrl = _disp displayCtrl (62000 + _shown);
						_ctrl ctrlSetStructuredText (parseText (Format ["<t align='center' shadow='1' size='%2' color='#d6ecff'>%1</t>", name _x, _sz]));
						_ctrl ctrlSetPosition [(_scr select 0) - 0.1, (_scr select 1) - 0.025, 0.2, 0.03];
						_ctrl ctrlCommit 0;
						_ctrl ctrlShow true;
						_shown = _shown + 1;
					};
				};
			} forEach (player nearEntities [["Man"], 120]);
			//--- WFBE_C_TAGS_AI: friendly AI infantry tags (same-side, within 150m, #b0ffb0 green).
			if ((missionNamespace getVariable ["WFBE_C_TAGS_AI", 0]) > 0) then {
				{
					private ["_aiunit","_aipp","_aiscr","_aid","_aisz"];
					_aiunit = _x;
					if (_shown < _max && {!isPlayer _aiunit} && {alive _aiunit} && {side _aiunit == side player}) then {
						_aipp = visiblePosition _aiunit;
						_aiscr = worldToScreen [_aipp select 0, _aipp select 1, (_aipp select 2) + 1.9];
						if (count _aiscr == 2 && {(_aiscr select 0) > 0} && {(_aiscr select 0) < 1} && {(_aiscr select 1) > 0} && {(_aiscr select 1) < 1}) then {
							_aid = _aiunit distance player;
							_aisz = 0.016 + (0.012 * (1 - (_aid / 150)));
							_ctrl = _disp displayCtrl (62000 + _shown);
							_ctrl ctrlSetStructuredText (parseText (Format ["<t align='center' shadow='1' size='%2' color='#b0ffb0'>%1</t>", name _aiunit, _aisz]));
							_ctrl ctrlSetPosition [(_aiscr select 0) - 0.1, (_aiscr select 1) - 0.025, 0.2, 0.03];
							_ctrl ctrlCommit 0;
							_ctrl ctrlShow true;
							_shown = _shown + 1;
						};
					};
				} forEach (player nearEntities [["Man"], 150]);
			};
			//--- WFBE_C_TAGS_AI: friendly AI vehicle tags (same-side, pure-AI crew, within 200m, #ffffa0 yellow). Height 3.0m separates from kill-tally tags at 2.6m.
			if ((missionNamespace getVariable ["WFBE_C_TAGS_AI", 0]) > 0) then {
				{
					private ["_vhc","_vcnt","_vtxt","_vpp","_vscr","_vd","_vsz"];
					_vhc = _x;
					_vcnt = count crew _vhc;
					if (_shown < _max && {alive _vhc} && {_vhc != vehicle player} && {_vcnt > 0} && {side _vhc == side player} && {({isPlayer _x} count (crew _vhc)) == 0}) then {
						_vtxt = format ["%1 [%2]", getText (configFile >> "CfgVehicles" >> (typeOf _vhc) >> "displayName"), _vcnt];
						_vpp = visiblePosition _vhc;
						_vscr = worldToScreen [_vpp select 0, _vpp select 1, (_vpp select 2) + 3.0];
						if (count _vscr == 2 && {(_vscr select 0) > 0} && {(_vscr select 0) < 1} && {(_vscr select 1) > 0} && {(_vscr select 1) < 1}) then {
							_vd = _vhc distance player;
							_vsz = 0.015 + (0.012 * (1 - (_vd / 200)));
							_ctrl = _disp displayCtrl (62000 + _shown);
							_ctrl ctrlSetStructuredText (parseText (Format ["<t align='center' shadow='1' size='%2' color='#ffffa0'>%1</t>", _vtxt, _vsz]));
							_ctrl ctrlSetPosition [(_vscr select 0) - 0.1, (_vscr select 1) - 0.025, 0.2, 0.03];
							_ctrl ctrlCommit 0;
							_ctrl ctrlShow true;
							_shown = _shown + 1;
						};
					};
				} forEach (player nearEntities [["LandVehicle","Air","Ship"], 200]);
			};
			//--- cmdcon44m (Ray pick C 2026-07-04): vehicle kill tallies ride the same TAGS toggle and the same
			//--- control pool - no lightpoint, no extra rsc. Friendly-crewed or EMPTY hulls within 200m that have
			//--- scored kills show a heat-coloured 'N KILLS' tag (amber -> orange -> red -> white-hot, the retired
			//--- glow's ramp). Crewless side resolves to CIV in A2, so empty hulls pass by crew-count, NOT side;
			//--- enemy CREWED vehicles never tag (no intel leak). Own vehicle excluded (tag would sit mid-screen).
			{
				private ['_tcnt','_tclr','_tpp','_tscr','_td','_tsz'];
				_tcnt = _x getVariable ['wfbe_kill_tally', 0];
				if (_shown < _max && {_tcnt > 0} && {alive _x} && {_x != vehicle player} && {(count crew _x == 0) || {side _x == side player}}) then {
					_tpp = visiblePosition _x;
					_tscr = worldToScreen [_tpp select 0, _tpp select 1, (_tpp select 2) + 2.6];
					if (count _tscr == 2 && {(_tscr select 0) > 0} && {(_tscr select 0) < 1} && {(_tscr select 1) > 0} && {(_tscr select 1) < 1}) then {
						_td = _x distance player;
						_tsz = 0.016 + (0.014 * (1 - (_td / 200)));
						_tclr = '#ffb040'; if (_tcnt >= 3) then {_tclr = '#ff7a20'}; if (_tcnt >= 6) then {_tclr = '#ff2a10'}; if (_tcnt >= 10) then {_tclr = '#ffe8c0'};
						_ctrl = _disp displayCtrl (62000 + _shown);
						_ctrl ctrlSetStructuredText (parseText (Format ["<t align='center' shadow='1' size='%2' color='%3'>%1 %4</t>", _tcnt, _tsz, _tclr, if (_tcnt == 1) then {'KILL'} else {'KILLS'}]));
						_ctrl ctrlSetPosition [(_tscr select 0) - 0.1, (_tscr select 1) - 0.025, 0.2, 0.03];
						_ctrl ctrlCommit 0;
						_ctrl ctrlShow true;
						_shown = _shown + 1;
					};
				};
			} forEach (player nearEntities [['LandVehicle','Air','Ship'], 200]);
			for "_i" from _shown to (_max - 1) do {(_disp displayCtrl (62000 + _i)) ctrlShow false};
			sleep 0.1;
		};
		12461 cutText ["","PLAIN",0];
	};
};

// Marty: Show the test build marker once in debug mode so testers can confirm the running PBO version.
if (WF_Debug) then {
	systemChat "TD Debug build: 2026-06-09 01:56";
};


if (ARMA_VERSION >= 162 && ARMA_RELEASENUMBER > 97105 || ARMA_VERSION > 162) then {
	//--- Profile namespace related.
	WFBE_CL_FNC_UI_Gear_SaveTemplateProfile = Compile preprocessFileLineNumbers "Client\Functions\Client_UI_Gear_SaveTemplateProfile.sqf";
	Call Compile preprocessFileLineNumbers "Client\Init\Init_ProfileVariables.sqf";
};

// Marty : auto distance view feature deactivated at client start.
missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
//--- FPS picker (2026): default OFF, but restore the player's saved on/off choice if one was persisted.
if (typeName (profileNamespace getVariable ["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", false]) == "BOOL") then {
	missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", profileNamespace getVariable ["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", false]];
	if (missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false]) then {missionNamespace setVariable ["SAVED_VIEW_DISTANCE", viewDistance]};
};
missionNamespace setVariable ["AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT", false];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", []];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", grpNull];
missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_TIME", -5000];
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
clientTeams = missionNamespace getVariable [Format['WFBE_%1TEAMS',sideJoinedText], []]; //--- B74.2.5: default [] not nil. For a broken-JIP client WFBE_%1TEAMS is unset; the ungated vote-tally `forEach WFBE_Client_Teams` (GUI_VoteMenu) + the own-marker `forEach clientTeams` would `forEach nil` = THROW in A2-OA (count nil is 0 and safe, but forEach nil is not). [] makes them safe 0-iteration no-ops and still triggers the primitive-roster path (count 0). The two isNil "clientTeams" readers are diagnostics only.
//--- B74.2.3 TELEMETRY: raw diag_log of the client's own-side team list AT INIT (the source of the no-cash/
//--- no-vote cascade when it is empty). Pairs with the server TEAMREG log + the HEAL log below.
diag_log format ["CLIENTTEAMS|atInit|side=%1|count=%2|isNil=%3", sideJoinedText, count (if (isNil "clientTeams") then {[]} else {clientTeams}), (isNil "clientTeams")];
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
	//--- Debug teleport rebind: press "[" (DIK 0x1A=26) to ARM, then the next plain map-click teleports you (was: every click teleported under WF_Debug, which ate the sell/ICBM confirm clicks).
	_display displayAddEventHandler ["KeyDown","if ((_this select 1) == 26 && WF_Debug) then {missionNamespace setVariable ['WFBE_DEBUG_TELEPORT_ARMED', true]; hintSilent 'Debug teleport ARMED - next map click teleports you.'; true} else {false}"];
// Marty: onMapSingleClick exposes Shift and Alt but not Ctrl, so track Ctrl state separately for map disband.
_display displayAddEventHandler ["KeyDown","if ((_this select 1) in [29,157]) then {missionNamespace setVariable ['WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN', true]; missionNamespace setVariable ['WFBE_CLIENT_MAP_DISBAND_CTRL_TS', time]}; false"];
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
// Marty: Start the AFK timer immediately, even if the player never moves after joining.
player setVariable ["lastActionTime", time];
player setVariable ["lastPosition", position player];
["INFORMATION", Format ["AFK Diagnostic: initialized for player [%1]. time [%2] position [%3].", name player, time, position player]] Call WFBE_CO_FNC_LogContent;

_display displayAddEventHandler ["KeyDown", "_this call WFBE_CO_FNC_HandleAFKkeys"];

//--- ============================================================================
//--- b67 item #3 (claude-gaming 2026-06-21): VEHICLE-TINT LEGEND (top-right pop-up).
//--- Explains the faction body TINTS set in Common_AddVehicleTexture.sqf (WEST/BLUFOR = matte black,
//--- EAST/OPFOR = dark olive, GUER = desert tan). Those tints are CHEAP one-shot setObjectTexture
//--- colour strings gated by WFBE_C_VEHICLE_TINTS (default 1, ON) - DECOUPLED from the expensive
//--- #lightpoint markings (WFBE_C_VEHICLE_MARKINGS, default 0) - so the coloured hulls are ALREADY
//--- live with zero FPS cost; this just teaches players what the colours mean. Shown ONCE on first
//--- spawn (per session) + toggled with "]" (DIK 0x1B = 27), mirroring the raw-DIK _display KeyDown
//--- handlers above (the "[" debug-teleport key sits right next to it). Pure client cosmetic. Enabled
//--- only when BOTH WFBE_C_VEHICLE_TINT_LEGEND (nil-guarded in Init_CommonConstants, A/B'able) AND the
//--- tints themselves are ON. A2-OA 1.64 safe (no isEqualType/findIf/selectRandom/pushBack/select {CODE}).
WFBE_CL_VAR_TintLegendLayer     = 12460; //--- dedicated cut layer (distinct from 1365/12450/12451/12452/600200).
WFBE_CL_VAR_TintLegendVisible   = false;
WFBE_CL_VAR_TintLegendAutoToken = 0;     //--- bumped by a manual toggle so the first-spawn auto-clear can stand down.
//--- Resource guard: ALSO require the RscTitle to be registered in this mission's config. A partial /
//--- overlay build can ship this script (the cutRsc call) WITHOUT the updated Rsc\Titles.hpp that
//--- defines WFBE_VehicleTintLegend -> cutRsc would then throw "Resource WFBE_VehicleTintLegend not
//--- found". Gating on isClass makes the whole legend (keydown handler + first-spawn auto-show) stand
//--- down silently when the class is missing, so a desynced build degrades gracefully instead of erroring.
//--- isClass / missionConfigFile are A2-OA 1.64 safe.
WFBE_CL_VAR_TintLegendEnabled   = ((missionNamespace getVariable ["WFBE_C_VEHICLE_TINT_LEGEND", 1]) > 0) && {(missionNamespace getVariable ["WFBE_C_VEHICLE_TINTS", 1]) > 0} && {isClass (missionConfigFile >> "RscTitles" >> "WFBE_VehicleTintLegend")};

WFBE_CL_FNC_ShowTintLegend = {
	//--- _this: true = show, false = hide. cutRsc/cutText share the dedicated layer.
	if (_this) then {
		WFBE_CL_VAR_TintLegendLayer cutRsc ["WFBE_VehicleTintLegend", "PLAIN", 0.3];
		WFBE_CL_VAR_TintLegendVisible = true;
	} else {
		WFBE_CL_VAR_TintLegendLayer cutText ["", "PLAIN", 0.3];
		WFBE_CL_VAR_TintLegendVisible = false;
	};
};

WFBE_CL_FNC_ToggleTintLegend = {
	private ["_key"];
	_key = _this select 1;
	//--- "]" = DIK 0x1B (27). Swallow the key (return true) only when we actually handle it.
	if (_key == 27 && WFBE_CL_VAR_TintLegendEnabled) then {
		WFBE_CL_VAR_TintLegendAutoToken = WFBE_CL_VAR_TintLegendAutoToken + 1; //--- cancel any pending auto-clear.
		(!WFBE_CL_VAR_TintLegendVisible) call WFBE_CL_FNC_ShowTintLegend;
		true
	} else {
		false
	};
};

if (WFBE_CL_VAR_TintLegendEnabled) then {
	_display displayAddEventHandler ["KeyDown", "_this call WFBE_CL_FNC_ToggleTintLegend"];

	//--- First-spawn auto-show (once per session). uiSleep is real-time so it still fires even if a JIP
	//--- client's sim is briefly paused; auto-clears after a few seconds UNLESS the player toggled it in
	//--- the meantime (token mismatch => stand down, don't fight a manual toggle).
	[] spawn {
		private ["_tok"];
		waitUntil {uiSleep 1; !isNull player && {alive player}};
		if !(missionNamespace getVariable ["WFBE_CL_VAR_TintLegendAutoShown", false]) then {
			missionNamespace setVariable ["WFBE_CL_VAR_TintLegendAutoShown", true];
			uiSleep 6;                              //--- let the join / BLACK-IN loading titles clear first.
			true call WFBE_CL_FNC_ShowTintLegend;
			_tok = WFBE_CL_VAR_TintLegendAutoToken;
			uiSleep 15;                             //--- linger, then auto-dismiss the first-spawn pop-up.
			if (WFBE_CL_VAR_TintLegendVisible && {_tok == WFBE_CL_VAR_TintLegendAutoToken}) then {
				false call WFBE_CL_FNC_ShowTintLegend;
			};
		};
	};
};
//--- ============================================================================

[] execVM "Client\Module\AFKkick\monitorAFK.sqf";

//--- wiki-wins: removed duplicate HandleAT Fired EH (already added near the top of Init_Client); was double-spawning HandleAT per AT rocket
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
//--- SM9: removed dead WFBE_Client_SupplyMissionActive (set, never read).
WFBE_C_VAR_FRIENDLYCOMMANDCENTERINPROXIMITY = false;

commanderTeam = objNull;
buildingMarker = 0;
CCMarker = 0;
CBRCircleMarker = 0;
gearCost = 0;
//--- PR #40: removed the unconditional `currentTG = 50; setTerrainGrid 50` override that used to sit here, so
//--- the profile-aware fallback below governs instead: it no longer clobbers a player's saved terrain-grid
//--- value, and a profile-less player gets the mission's designed default (isNil 'currentTG' ->
//--- min(WFBE_C_ENVIRONMENT_MAX_CLUTTER,25) = 25). NB: 25 is a FINER grid than 50 (intended look), not an FPS cut.
lastBuilt = [];
unitQueu = 0;
fireMissionTime = -1000;
artyRange = 15;
artyPos = [0,0,0];
playerUAV = objNull;
playerFPV = objNull;
comTask = objNull;
voted = false;
votePopUp = true;
manningDefense = true;
currentFX = 0;
lastParaCall = -1200;
lastSupplyCall = -1200;
canBuildWHQ = true;
WFBE_RespawnDefaultGear = false;
WFBE_LastSelectedSpawn = objNull; //--- respawn-ui-v2: remember last chosen spawn across deaths.
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
// Marty: Start RHUD visible; the WF menu HUD button is now opt-out.
if (isNil "RUBHUD") then {RUBHUD = true};
if (isNil "RUBGPS") then {RUBGPS = 1};
if (isNil "RUBOSD") then {RUBOSD = 1};

/* HUD MODULE */
ExecVM "Client\Client_UpdateRHUD.sqf";

// Marty: Start the local client Performance Audit writer; metrics stay local and are written to the client RPT.
[] Spawn {
	waitUntil {!isNil "PerformanceAudit_Run"};
	["CLIENT"] Spawn PerformanceAudit_Run;
};

// Marty: State-audit loop (PERF1 slice A) - 60s RPT line of script count vs accumulated state vs FPS.
[] execVM "Client\Functions\Client_StateAudit.sqf";

// Marty/claude-gaming: client-local empty-group reaper - each player client deletes its OWN orphaned empty groups
// (deleteGroup only reaps EMPTY+LOCAL groups; the server/HC GC cannot reach client-owned husks against the 144/side cap).
[] execVM "Client\Functions\Client_GroupsGC.sqf";

//--- Disable Artillery Computer.
Call Compile "enableEngineArtillery false;";

//--- Commander % stock init.
if ((missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM") in [3,4]) then {
	if (isNil {WFBE_Client_Logic getVariable "wfbe_commander_percent"}) then {WFBE_Client_Logic setVariable ["wfbe_commander_percent", 70]};
};

/* Exec SQF|FSM Misc stuff. */
if ((missionNamespace getVariable "WFBE_C_UNITS_TRACK_LEADERS") > 0) then {[] execVM "Client\FSM\updateteamsmarkers.sqf"};
if ((missionNamespace getVariable ["WFBE_C_GUER_LOCKOUT_MIN", 0]) > 0) then {[] execVM "Client\Functions\Client_GuerLockout.sqf"}; //--- fable/guer-lockout: resistance activation delay
if ((missionNamespace getVariable ["WFBE_C_GUER_PATROL_MARKERS", 1]) > 0) then {[] execVM "Client\Functions\Client_GuerPatrolMarkers.sqf"}; //--- fable/guer-patrol-markers: resistance-only friendly AI map dots
[] execVM "Client\FSM\updatepatrolmarkers.sqf"; //--- Friendly side-patrol markers (Patrols upgrade).
[] execVM "Client\FSM\updateaicommarkers.sqf"; //--- AI-commander team direction arrows (task #3).
if ((missionNamespace getVariable ["WFBE_C_AWACS", 0]) > 0) then {[] execVM "Client\Module\AWACS\awacs_pilot_watch.sqf"}; //--- fable/awacs-radar: AWACS pilot watch (ground MTI sweep). Flag default 0 = never launched.

//--- B62 (Ray 2026-06-21): OWN-SIDE MARKER RECONCILIATION / SELF-HEAL.
//--- THE BUG (Ray RPT, OPFOR/insurgent JIP join): own-side FACTORY/structure markers AND own-side HQ-team
//--- arrows were missing. Two slow-sync misses: (a) Init_BaseStructure is a ONE-SHOT setVehicleInit, so a
//--- structure whose marker was skipped (side not settled / the find=-1 crash) is NEVER retried; (b) the B56
//--- bounded JIP wait in initJIPCompatible can proceed WITHOUT wfbe_teams ("not synced in time"), leaving
//--- WFBE_%1TEAMS / WFBE_Client_Teams empty so the team data the HQ arrows rely on is absent.
//--- This bounded client loop re-checks AFTER init until the data lands, then (re)populates the own-side team
//--- arrays and rescans WarfareBBaseStructure own-side objects to (re)create any MISSED structure marker. A
//--- slow-sync/JIP/respawn miss therefore self-heals. A2-OA 1.64 safe (no isEqualType/findIf/pushBack; getPos
//--- of objects only; groups read via plain getVariable). No frozen AI / no sim-gating touched.
[] spawn {
	private ["_t0","_logik","_teams","_sideText","_structures","_x","_built","_sideID2","_didTeams","_hqObj","_loggedStructs"];
	//--- B64 (Ray 2026-06-21): BOUNDED gate (B63 left this reconciliation on an unbounded
	//--- clientInitComplete wait, so a stalled init suppressed the structure self-heal entirely).
	//--- Proceed after 90s in-game at the latest, mirroring the B63 arrow-loop fix.
	_t0 = time;
	waitUntil {(!isNil "clientInitComplete" && {clientInitComplete}) || ((time - _t0) > 90)};
	diag_log format ["[WFBE][B64 RECON] reconciliation live after %1s cic=%2", round (time - _t0), (!isNil "clientInitComplete" && {clientInitComplete})];
	waitUntil {!isNil "WFBE_Client_SideID"};
	_sideText = WFBE_Client_SideJoinedText;
	_logik = WFBE_Client_Logic;
	_didTeams = false;
	_loggedStructs = false;
	_t0 = time;
	//--- Re-check for ~120s after init (covers a slow JIP team-sync); cheap idle cadence.
	while {(time - _t0) < 120} do {
		//--- (b) HEAL OWN-SIDE TEAM DATA. If the B56 wait skipped wfbe_teams, WFBE_%1TEAMS is empty/nil here.
		//--- Repopulate it (and the WFBE_Client_Teams mirror init_client captured at startup) once the side
		//--- logic finally carries wfbe_teams. resistance/GUER is harass-only and may never resolve teams - that
		//--- is expected, the loop simply never fires this branch for it (no block, no error).
		if (!_didTeams && {!isNull _logik} && {!isNil {_logik getVariable "wfbe_teams"}}) then {
			_teams = _logik getVariable "wfbe_teams";
			if (!isNil "_teams") then {
				missionNamespace setVariable [Format ["WFBE_%1TEAMS", _sideText], _teams];
				WFBE_Client_Teams = _teams;
				clientTeams = _teams;
				WFBE_Client_Teams_Count = count _teams;
				_didTeams = true;
				["INITIALIZATION", Format ["Init_Client.sqf: B62 reconciliation populated own-side teams (count %1) after JIP slow-sync.", count _teams]] Call WFBE_CO_FNC_LogContent;
				//--- B74.2.3 TELEMETRY: raw diag_log when the self-heal repopulates clientTeams (absence of this +
				//--- atInit count=0 means the side-logic wfbe_teams never synced to this JIP client).
				diag_log format ["CLIENTTEAMS|HEAL|side=%1|count=%2", _sideText, count _teams];
			};
		};

		//--- (a) HEAL MISSED STRUCTURE MARKERS. Walk the side logic's own-side structure registry (broadcast,
		//--- so JIP clients receive it) and re-trigger Init_BaseStructure for any LIVE structure that never had
		//--- a marker built (no wfbe_b62_marker_built flag). The re-run sets the flag itself, so this is
		//--- idempotent and will not duplicate markers for structures that already painted theirs.
		//--- B64 (Ray 2026-06-21) CAUSE A2 FIX: the own-side HQ is the "HQ marker (UNDEPLOYED)" Ray
		//--- still cannot see. The HQ object lives ONLY in wfbe_hq - it is NEVER pushed into
		//--- wfbe_structures, and the boot/mobilized MHQ fires NO setVehicleInit running
		//--- Init_BaseStructure (only the DEPLOY branch does), so the wfbe_structures walk below skips
		//--- it entirely. Heal it explicitly: re-fire Init_BaseStructure for wfbe_hq with isHQ=true
		//--- (literal true, because wfbe_structure_type is set WITHOUT broadcast = nil on a JIP client)
		//--- and the stable WFBE_Client_SideID. Idempotent via the wfbe_b62_marker_built claim; on
		//--- deploy/undeploy wfbe_hq swaps to a fresh unflagged object so the next ~5s tick re-fires.
		_hqObj = WFBE_Client_Logic getVariable ["wfbe_hq", objNull];
		if (!isNull _hqObj && {alive _hqObj} && {!(_hqObj getVariable ["wfbe_b62_marker_built", false])}) then {
			[_hqObj, true, WFBE_Client_SideID] ExecVM "Client\Init\Init_BaseStructure.sqf";
			diag_log format ["[WFBE][B64 HQ-MARK] reconciliation re-fired Init_BaseStructure for own HQ type=%1 deployed=%2 pos=%3", typeOf _hqObj, (WFBE_Client_Logic getVariable ["wfbe_hq_deployed", false]), getPos _hqObj];
			sleep 0.1;
		};

		_structures = (WFBE_Client_SideJoined) Call WFBE_CO_FNC_GetSideStructures;
		//--- B64 (Ray 2026-06-21) factory diagnostic: log the own-side structure count ONCE so the next
		//--- RPT proves whether the JIP client actually RECEIVES the factory objects in wfbe_structures
		//--- (the prime remaining suspect if factory markers still miss after the gate-bounding).
		if (!_loggedStructs) then {
			_loggedStructs = true;
			diag_log format ["[WFBE][B64 RECON-STRUCTS] own-side (%1) structure count on this client = %2", _sideText, (if (isNil "_structures") then {-1} else {count _structures})];
		};
		if (!isNil "_structures" && {typeName _structures == "ARRAY"}) then {
			{
				if (!isNull _x && {alive _x}) then {
					_built = _x getVariable ["wfbe_b62_marker_built", false];
					if (!_built) then {
						_sideID2 = (WFBE_Client_SideJoined) Call GetSideID;
						//--- Re-fire the SAME one-shot script; its compare-and-claim guard (wfbe_b62_marker_built)
						//--- makes this idempotent - if the original spawn claims first, this re-run exits without
						//--- drawing, and vice-versa, so no duplicate BaseMarker is ever created.
						[_x, ((_x getVariable ["wfbe_structure_type", ""]) == "Headquarters"), _sideID2] ExecVM "Client\Init\Init_BaseStructure.sqf";
						["INITIALIZATION", Format ["Init_Client.sqf: B62 reconciliation re-fired Init_BaseStructure for a possibly-missed own-side structure [%1].", typeOf _x]] Call WFBE_CO_FNC_LogContent;
						sleep 0.1; //--- let the re-fired spawn reach its claim before this loop re-reads the registry.
					};
				};
			} forEach _structures;
		};

		sleep 5;
	};
};

//--- cmdcon26 (Game 2026-06-29) HQ-MARKER HEAL. THE GAP: the B62/B64 reconciliation above re-fires
//--- Init_BaseStructure for wfbe_hq, but ONLY while the ~120s window runs AND only while the claim flag
//--- wfbe_b62_marker_built is still false. Init_BaseStructure SETS that claim flag (line 37) BEFORE it has
//--- actually painted the marker (it then sleeps 2s, and earlier it sat behind a 90s gate + a side-ID check
//--- that exitWiths WITHOUT clearing the flag). Under JIP slow-sync the own HQ marker can therefore latch
//--- "claimed" yet never render if wfbe_hq / WFBE_Client_SideID arrived late, and once the 120s window closes
//--- nothing retries - the HQ icon stays missing (RPT "Zwanon": MARKERS=3, no own HQ). This dedicated bounded
//--- loop keeps RETRYING past that window: it verifies an ACTUAL own-side "Headquarters" marker exists near the
//--- live wfbe_hq position; if not, it CLEARS the stale claim flag and re-fires Init_BaseStructure so the draw
//--- runs again. It stops the instant the HQ marker is present (a healthy join sends ZERO re-fires). Idempotent
//--- via the same wfbe_b62_marker_built compare-and-claim. A2-OA-1.64 safe (cmdcon28: dropped allMapMarkers — Arma-3-only): markerType /
//--- markerPos / getPos / distance2D-free (uses distance on getPos) / getVariable / setVariable; no A3 commands.
[] spawn {
	private ["_n","_done","_hqObj","_hqPos","_hqPosValid","_found","_mPos","_x","_grace"];
	waitUntil {(!isNil "WFBE_Client_SideID") && {!isNil "WFBE_Client_Logic"}};
	//--- Civilian clients have no own HQ; never spin (mirrors the EARLYHEAL CIV bail-out).
	if (sideJoined == civilian) exitWith { diag_log "[WFBE][cmdcon26 HQ-MARK] CIV-ABORT: skipped on civilian client."; };
	_done = false;
	_n = 0;
	//--- ~200 polls x ~3s = ~10min ceiling, comfortably past the 120s reconciliation window.
	while {!_done && {_n < 200} && {sideJoined != civilian}} do {
		_hqObj = WFBE_Client_Logic getVariable ["wfbe_hq", objNull];
		if (!isNull _hqObj && {alive _hqObj}) then {
			_hqPos = getPos _hqObj;
			//--- cmdcon26 (Game 2026-06-29) JIP DEGENERATE-POS GUARD. On a JIP client getPos on a not-yet-streamed
			//--- HQ returns [0,0,0]/degenerate; feeding that to (markerPos _x) distance _hqPos for EVERY marker threw
			//--- once per poll (200x = the _n<200 ceiling). Only run the allMapMarkers scan when _hqPos is a real
			//--- 2+ element non-[0,0] position; otherwise SKIP this poll (do NOT set _done) so the next 3s tick
			//--- retries silently until wfbe_hq streams in. A2-OA-1.64 safe: typeName / count / select.
			_hqPosValid = (typeName _hqPos == "ARRAY") && {count _hqPos >= 2} && {!((_hqPos select 0) == 0 && {(_hqPos select 1) == 0})};
			if (_hqPosValid) then {
			//--- Look for any LOCAL "Headquarters"-type marker already painted near the live HQ (Init_BaseStructure
			//--- draws BaseMarker<N> with type "Headquarters" for the HQ). 150m tolerance covers a mobilized/redeployed
			//--- HQ that moved slightly between the draw and this check.
			_found = false;
			{
				if (!_found && {(markerType _x) == "Headquarters"}) then {
					_mPos = markerPos _x;
					if ((_mPos distance _hqPos) < 150) then {_found = true};
				};
			} forEach (if ((_hqObj getVariable ["wfbe_hq_marker_name", ""]) == "") then {[]} else {[_hqObj getVariable ["wfbe_hq_marker_name", ""]]});	//--- cmdcon28: allMapMarkers is Arma-3-only (it threw 'undefined variable' EVERY poll => 200x/join + heal never fired). A2-OA has no marker enumeration, so check the HQ's OWN stamped marker by name (markerType/markerPos are A2-valid on a named marker). _x in the body is now that one marker name.
			if (_found) then {
				_done = true;
				if (_n > 0) then { diag_log format ["[WFBE][cmdcon26 HQ-MARK] own HQ marker present after %1 poll(s); heal complete.", _n]; };
			} else {
				//--- No HQ marker yet. Clear any stale claim and re-fire the one-shot draw. A small grace on the very
				//--- first poll lets the original B62 reconciliation re-fire land its own marker before we intervene.
				_grace = (_n == 0);
				if (!_grace) then {
					_hqObj setVariable ["wfbe_b62_marker_built", false];
					[_hqObj, true, WFBE_Client_SideID] ExecVM "Client\Init\Init_BaseStructure.sqf";
					diag_log format ["[WFBE][cmdcon26 HQ-MARK] no own HQ marker (poll %1) - cleared claim and re-fired Init_BaseStructure for type=%2 pos=%3.", _n, typeOf _hqObj, _hqPos];
				};
			};
			};
		};
		_n = _n + 1;
		sleep 3;
	};
	if (!_done) then { diag_log format ["[WFBE][cmdcon26 HQ-MARK] GAVE UP after %1 polls; own HQ marker never confirmed.", _n]; };
};

//--- B74.2.4 (Ray 2026-06-24, P0 — lobby joiners get NO funds / NO marker / NOT in the commander-vote menu =
//--- empty clientTeams = mission UNPLAYABLE). The B62/B64 reconciliation above only re-reads wfbe_teams for ~120s
//--- AFTER a ~90s gate (~210s total) then GIVES UP. Under heavy AI load the side-logic wfbe_teams can take longer
//--- than that to replicate to a client, so clientTeams stays empty PERMANENTLY. This dedicated spawn populates
//--- the own-side team mirror EARLY (no 90s gate) and KEEPS polling (~2s cadence) until the data lands (cap ~30min)
//--- so a client ALWAYS recovers whenever wfbe_teams arrives, however slow. Idempotent same-value writes with the
//--- heal above; the WAIT/EARLYHEAL diag_logs prove (on the client RPT) whether the data arrives late vs never.
//--- A2-OA-1.64 safe: plain getVariable on the logic OBJECT, typeName ==, count, mod; no A3 commands.
[] spawn {
	private ["_logik","_sideText","_teams","_n","_done","_lg","_sentAny"];
	waitUntil {(!isNil "WFBE_Client_SideJoinedText") && {!isNil "WFBE_Client_Logic"} && {!isNil "WFBE_Client_SideID"}};
	_sideText = WFBE_Client_SideJoinedText;
	_done = false;
	_sentAny = false;
	_n = 0;
	//--- B76 CIV bail-out: never spin on a civilian client (WFBE_Client_Logic is objNull for civilian so this would
	//--- otherwise poll the full ~30min cap logging WAIT|logikNull=true every tick). The CIV-side guard at L30 should
	//--- already have re-derived a real side; this is a belt-and-braces stop in case a civilian slips through.
	if (sideJoined == civilian) exitWith { diag_log "CLIENTTEAMS|CIV-ABORT|EARLYHEAL skipped on civilian client"; };
	while {!_done && {_n < 900} && {sideJoined != civilian}} do {
		_logik = WFBE_Client_Logic;
		if (!isNull _logik && {!isNil {_logik getVariable "wfbe_teams"}}) then {
			_teams = _logik getVariable "wfbe_teams";
			if (!isNil "_teams" && {(typeName _teams) == "ARRAY"} && {(count _teams) > 0}) then {
				missionNamespace setVariable [Format ["WFBE_%1TEAMS", _sideText], _teams];
				WFBE_Client_Teams = _teams;
				clientTeams = _teams;
				WFBE_Client_Teams_Count = count _teams;
				_done = true;
				diag_log format ["CLIENTTEAMS|EARLYHEAL|side=%1|count=%2|at=%3s", _sideText, count _teams, round time];
			};
		};
		if (!_done) then {
			if ((_n mod 15) == 0) then {
				_lg = WFBE_Client_Logic;
				diag_log format ["CLIENTTEAMS|WAIT|side=%1|n=%2|t=%3s|logikNull=%4|teamsNil=%5", _sideText, _n, round time, (isNull _lg), (isNil {_lg getVariable "wfbe_teams"})];
			};
			//--- cmdcon26 (Game 2026-06-29) TEAMS RE-BROADCAST REQUEST (mirrors the B76 funds self-heal). The
			//--- side-logic wfbe_teams broadcast may never have been replayed to this late joiner (A2-OA does not
			//--- replay object setVariable-broadcasts to post-join clients). Beyond passively polling, ask the
			//--- server to RE-broadcast its authoritative side-logic roster (+ HQ/structures) so the data gap
			//--- closes actively. Throttle the PVF to ~every 10s (every 5th 2s tick) while still polling locally
			//--- each tick; stops the instant wfbe_teams lands (_done). Server side is idempotent (same-value
			//--- re-set, never mutates the roster), so redundant requests are harmless.
			if ((_n mod 5) == 0) then {
				["RequestTeamsResend", [player, WFBE_Client_SideJoined]] Call WFBE_CO_FNC_SendToServer;
				_sentAny = true;
				diag_log format ["CLIENTTEAMS|RESEND-REQ|side=%1|n=%2|t=%3s", _sideText, _n, round time];
			};
			_n = _n + 1;
			sleep 2;
		};
	};
	if (!_done) then { diag_log format ["CLIENTTEAMS|EARLYHEAL-GAVEUP|side=%1|afterPolls=%2|sentResend=%3", _sideText, _n, _sentAny]; };
};

//--- B76 (Ray 2026-06-29) JIP FUNDS SELF-HEAL. THE BUG (client-main.rpt, "Zwanon"): a JIP joiner whose own-side
//--- wfbe_teams slow-synced under heavy AI ended up with NO money - and a slot-switch "fixed" it. The funds live
//--- on the player's GROUP as wfbe_funds, set by Server_OnPlayerConnected with a broadcast (true) setVariable. In
//--- A2-OA an object setVariable-broadcast is NOT replayed to a late joiner and can reach it slowly/never under
//--- load - the SAME failure mode as the team-sync heals above. The B62/B64/B74.2 reconciliation only re-pulls
//--- wfbe_teams + structure markers; NOTHING re-applied the player's own-group funds, so GetTeamFunds read nil ->
//--- "$0". This loop closes exactly that gap: once it can read its own team, if that group has NO numeric
//--- wfbe_funds it asks the server (RequestFundsResend) to re-broadcast the AUTHORITATIVE value - the explicit
//--- mirror of the slot-switch recovery, WITHOUT forcing a reconnect. It STOPS the instant funds land, so a
//--- normal fast join (funds already present) sends ZERO requests. The server side is idempotent (re-broadcasts an
//--- absolute stored value, never adds), so even a redundant request cannot duplicate money. Covers WEST/EAST/GUER
//--- (all three keep wfbe_funds on the group). A2-OA-1.64 safe: group player / getVariable / typeName == / mod;
//--- no A3 commands. No frozen AI / no sim-gating touched.
[] spawn {
	private ["_grp","_f","_n","_done","_sentAny","_t0","_grace"];
	waitUntil {(!isNil "WFBE_Client_SideJoinedText") && {!isNil "WFBE_Client_SideJoined"}};
	//--- Let the normal connect-handler funds broadcast have a moment to land first (avoids a needless request on
	//--- a healthy fast join). Re-resolve group player each tick: a JIP/respawn can swap the player's group.
	sleep 8;
	_done = false;
	_sentAny = false;
	_n = 0;
	//--- Ray pick A (2026-07-03) ZERO-LATCH GRACE: within the first N seconds of the heal do NOT accept a
	//--- 0 balance as "healed" - a transient 0 from a slow object-state sync was the exact value the old loop
	//--- latched forever. Keep re-requesting so the server-side lock-step record restore (RequestFundsResend
	//--- case-1) has time to land the real value. After the grace a genuine 0 (a real spend) is accepted.
	//--- WFBE_C_FUNDS_HEAL_ZERO_GRACE (default 90s) is tunable; the record fix alone should already converge.
	_t0 = time;
	_grace = missionNamespace getVariable ["WFBE_C_FUNDS_HEAL_ZERO_GRACE", 90];
	//--- ~300 polls x ~3s = ~15min ceiling; matches the team-heal's generous JIP window. Cheap idle cadence.
	while {!_done && {_n < 300}} do {
		_grp = group player;
		if (!isNull _grp) then {
			_f = _grp getVariable "wfbe_funds";
			if (!isNil "_f" && {typeName _f == "SCALAR"} && {_f > 0 || {(time - _t0) >= _grace}}) then {
				//--- Funds are present: a positive value, OR a 0 that has survived past the zero-grace window (a real
				//--- spend-to-0, not a transient sync artifact). Done; stop asking. Within grace a 0 is treated as
				//--- still-missing (falls to the else) so we keep requesting the server lock-step record restore.
				_done = true;
				if (_sentAny) then {
					diag_log format ["[WFBE][B76 FUNDS-HEAL] own-group funds=%1 landed after %2 request(s); self-heal complete.", _f, _n];
				};
			} else {
				//--- No numeric wfbe_funds on our own group yet -> ask the server to (re)broadcast it. Throttle the
				//--- actual PVF to every ~9s (every 3rd ~3s tick) so a slow server-side resolve is not spammed,
				//--- while still polling locally each tick so we react the instant funds arrive.
				if ((_n mod 3) == 0) then {
					["RequestFundsResend", [player, WFBE_Client_SideJoined]] Call WFBE_CO_FNC_SendToServer;
					_sentAny = true;
					diag_log format ["[WFBE][B76 FUNDS-HEAL] own-group has no wfbe_funds (poll %1); requested server re-broadcast.", _n];
				};
			};
		};
		_n = _n + 1;
		sleep 3;
	};
	if (!_done && _sentAny) then { diag_log format ["[WFBE][B76 FUNDS-HEAL] GAVE UP after %1 polls; funds never landed on own group.", _n]; };
};

[] execFSM "Client\FSM\updateactions.fsm";
//--- QoL trio feat.3: spawn advisor nudge loop after common init is done.
[] spawn WFBE_CL_FNC_QOL_Advisor;
/* Don't pause the client initialization process. */
[] Spawn {
	waitUntil {townInit};
	/* Handle the capture GUI */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Town Capture FSM"] Call WFBE_CO_FNC_LogContent;
	[] execVM "Client\FSM\client_title_capture.sqf";
	/* Handle the map town markers */
	["INITIALIZATION", "Init_Client.sqf: Initializing the Towns Marker FSM"] Call WFBE_CO_FNC_LogContent;
	[] execVM "Client\FSM\updatetownmarkers.sqf";
	if (sideJoined != resistance) then {
waitUntil {(sideJoined == civilian) || {!isNil {WFBE_Client_Logic getVariable "wfbe_structures"}}}; //--- B76: || civilian so a CIV client (objNull logic) never hangs here
	if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
		waitUntil {(sideJoined == civilian) || {!isNil {missionNamespace getVariable format ["wfbe_supply_%1", sideJoinedText]}}}; //--- B76: || civilian bail
	};
};
	missionNamespace setVariable ["wfbe_supply", missionNamespace getVariable [Format ["wfbe_supply_%1", sideJoinedText], 0]];
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
//--- claude/guer-radio-announcer: BLUFOR/OPFOR always register the radio kb topic here so they hear the
//--- town/camp/hostiles announcer voices; resistance was hard-excluded, so playable GUER players got none of
//--- them. Include resistance when the GUER faction is playable (WFBE_C_GUER_PLAYERSIDE>0) - the server now
//--- builds the matching wfbe_radio_hq speaker on WFBE_L_GUE under the same gate (Init_Server.sqf), so the
//--- waitUntil below resolves. west/east and the civilian pass-through keep their exact previous behaviour;
//--- resistance stays skipped (sideHQ=objNull) when GUER is AI-defender-only (no human resistance slots exist).
if ((sideJoined != resistance) || {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {
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
} else { sideHQ = objNull; };

["INITIALIZATION", "Init_Client.sqf: Radio announcer is initialized."] Call WFBE_CO_FNC_LogContent;

/* Wait for a valid signal (Teamswaping) with failover */
if (isMultiplayer && ((missionNamespace getVariable "WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE") > 0 && !WF_Debug) && time > 7) then {
	Private ["_get","_timelaps","_totalWait"];
	_get = true;

	sleep (random 0.1);

	["RequestJoin", [player, sideJoined]] Call WFBE_CO_FNC_SendToServer;

	_timelaps = 0;
	_totalWait = 0;
	while {true} do {
		sleep 0.1;
		_get = missionNamespace getVariable 'WFBE_P_CANJOIN';
		if !(isNil '_get') exitWith {["INITIALIZATION", Format["Init_Client.sqf: [%1] Client [%2], Can join? [%3]",sideJoined,name player,_get]] Call WFBE_CO_FNC_LogContent};

		_timelaps = _timelaps + 0.1;
		_totalWait = _totalWait + 0.1;
		//--- B74.2.2: HARD failover. This loop was while{true} with only a 30s re-request and NO total timeout,
		//--- so if the server join-ACK never arrived (handshake stuck under heavy-AI load) Init_Client hung here
		//--- forever -> clientInitComplete never set -> no team/vote/money/own-marker. After 120s, proceed
		//--- (treat as can-join) so the client always finishes init rather than stalling permanently.
		if (_totalWait > 120) exitWith {
			_get = true;
			["WARNING", Format["Init_Client.sqf: [%1] Client [%2] no join ACK after 120s - proceeding to avoid a permanent client stall.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;
		};
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
	Private ["_hasConnectedAtLaunchACK","_timelaps","_totalWait"];
	_timelaps = 0;
	_totalWait = 0;
	WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player;
	publicVariableServer "WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH";
	while {true} do {
		sleep 0.1;
		_hasConnectedAtLaunchACK = missionNamespace getVariable 'WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK';
		if !(isNil '_hasConnectedAtLaunchACK') exitWith {["INITIALIZATION", Format["Init_Client.sqf: [%1] Client [%2], Can join? [%3]",sideJoined,name player,_hasConnectedAtLaunchACK]] Call WFBE_CO_FNC_LogContent};

		_timelaps = _timelaps + 0.1;
		_totalWait = _totalWait + 0.1;
		//--- B74.2.2: HARD failover (same rationale as the RequestJoin branch) - never hang Init_Client on a
		//--- missing connect-ACK; after 120s proceed so clientInitComplete is always reached.
		if (_totalWait > 120) exitWith {
			["WARNING", Format["Init_Client.sqf: [%1] Client [%2] no connect ACK after 120s - proceeding to avoid a permanent client stall.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;
		};
		if (_timelaps > 30) then {
			_timelaps = 0;
			["WARNING", Format["Init_Client.sqf: [%1] Client [%2] join is pending... no 'has connected at launch' ACK was received from the server, a new request will be submitted.",sideJoined,name player]] Call WFBE_CO_FNC_LogContent;
			WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player;
			publicVariableServer "WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH";
		};
	};
};

/* Get the client starting location */
//--- Task 35: escape the deadspawn holding area IMMEDIATELY after the join gate. The final
//--- position is refined below (newest live factory / HQ); this interim move covers any
//--- stall in that determination so mid-game (re)joiners never sit visibly at the
//--- TempRespawnMarker parking area. (The other half of this fix: the stats-DB guards —
//--- the join gate used to block up to 54s in DB retry loops on a DB-less server.)
if (!isNil {WFBE_Client_Logic getVariable "wfbe_startpos"}) then {
	player setPos ([WFBE_Client_Logic getVariable "wfbe_startpos", 10, 25] Call GetRandomPosition);
};
["INITIALIZATION", "Init_Client.sqf: Retrieving the client spawn location."] Call WFBE_CO_FNC_LogContent;
_base = objNull;
if (sideJoined == resistance) then {
	private ["_fr"]; _fr = [];
	{ if (((_x getVariable ["sideID",-1]) != WFBE_C_WEST_ID) && {(_x getVariable ["sideID",-1]) != WFBE_C_EAST_ID}) then {_fr = _fr + [_x]} } forEach towns;
	if (count _fr == 0) then {_fr = towns};
	_base = if (count _fr > 0) then { getPos (_fr select (floor (random (count _fr)))) } else { getMarkerPos "GuerTempRespawnMarker" };
} else {
if (time < 30) then {
	waitUntil {(sideJoined == civilian) || {!isNil {WFBE_Client_Logic getVariable "wfbe_startpos"}}}; //--- B76: || civilian so a CIV client never hangs on objNull logic
	_base = WFBE_Client_Logic getVariable "wfbe_startpos";
} else {
	waitUntil {(sideJoined == civilian) || {!isNil {WFBE_Client_Logic getVariable "wfbe_hq"}}};       //--- B76: || civilian bail
	waitUntil {(sideJoined == civilian) || {!isNil {WFBE_Client_Logic getVariable "wfbe_structures"}}}; //--- B76: || civilian bail
	_base = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
	_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;

    // Spawn joining client at newest Barracks, Light Factory, Heavy Factory or Air Factory, whichever is the newest
    if (count _buildings > 0) then {
	    for "_i" from ((count _buildings) - 1) to 0 step -1 do {
	        _structureType = (_buildings select _i) getVariable ["wfbe_structure_type", ""];
	        if ((_structureType == "Barracks" || _structureType == "Light" || _structureType == "Heavy" || _structureType == "Aircraft") && alive (_buildings select _i)) exitWith {	//--- FIX(deadspawn): only pick a LIVE factory, never a destroyed wreck
	            _base = _buildings select _i;
			};
		};
	};

	    //--- FIX(deadspawn): if no live factory was found and the HQ is dead, fall back to the side start position instead of spawning on a wreck.
	    if (isNull _base || {!alive _base}) then { _base = WFBE_Client_Logic getVariable "wfbe_startpos" };
};
};

["INITIALIZATION", Format["Init_Client.sqf: Client spawn location has been determined at [%1].", _base]] Call WFBE_CO_FNC_LogContent;

/* Position the client at the previously defined location */
player setPos ([_base,20,30] Call GetRandomPosition);
missionNamespace setVariable ["WFBE_Client_DeadspawnEscaped", true]; //--- DEADSPAWN SAFETY: escaped the holding area to base - let the spawn-protection watchdog re-enable damage.

/* HQ Building Init. */
_isDeployed = true; //--- B751: default so resistance/GUER (which skips the block below) never reads an undefined _isDeployed at the `!isServer && !_isDeployed` HQ-killed-EH guard (~L824). WEST/EAST reassign the real status below.
if (sideJoined != resistance) then {
waitUntil {(sideJoined == civilian) || !isNil {WFBE_Client_Logic getVariable "wfbe_hq_deployed"}};
["INITIALIZATION", "Init_Client.sqf: Initializing COIN Module."] Call WFBE_CO_FNC_LogContent;
_isDeployed = (sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus;
if (_isDeployed) then {
	[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED",true,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
} else {
	[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED",false,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
};
};

//--- Add Killed EH to the HQ on each client if needed (JIP), skip LAN host.
if (!isServer && !_isDeployed) then {
	[] spawn {
		waitUntil {(sideJoined == civilian) || !isNil {WFBE_Client_Logic getVariable "wfbe_hq"}};
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

waitUntil {!isNull group player};

//--- Make sure that player is always the leader.
if (leader(group player) != player) then {(group player) selectLeader player};

//--- TEAMBAR-FIRST (fable/player-teambar-slot): A2 command bar ranks units by RANK then join-order.
//--- Set the player to COLONEL so they always render at slot 1 regardless of AI subordinate rank.
if ((missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0) then {
	player setRank "COLONEL";
	diag_log "[WFBE|TEAMBAR] Init_Client: player rank set to COLONEL for command-bar slot 1.";
};

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

//--- GUER-GEARFIX (2026-07-02): never equip from an empty/undefined role loadout. WFBE_SK_V_Type can be ""
//--- (playerType not registered in any WFBE_SK_V_* list) and the per-role WFBE_%1_DefaultGearXXX can be nil
//--- (the GUER overlay defines only Engineer/Spot/Medic) - both used to strip the player NAKED (no ItemMap
//--- = fully black map). Fall back to the faction-wide WFBE_%1_DefaultGear (defined in every Root_*.sqf)
//--- and warn in the RPT; if even that is missing, skip the equip so the unit keeps its config gear.
if (isNil '_default' || {count _default == 0}) then {
	["WARNING", Format ["Init_Client.sqf : No role default gear for type [%1] (playerType [%2]) - falling back to WFBE_%3_DefaultGear.", WFBE_SK_V_Type, playerType, WFBE_Client_SideJoinedText]] Call WFBE_CO_FNC_LogContent;
	_default = missionNamespace getVariable Format["WFBE_%1_DefaultGear", WFBE_Client_SideJoinedText];
};
if (!isNil '_default' && {count _default >= 3}) then {
	if (count _default <= 3) then {
		[player, _default select 0, _default select 1, _default select 2] Call WFBE_CO_FNC_EquipUnit;
	} else {
		[player, _default select 0, _default select 1, _default select 2, _default select 3, _default select 4] Call WFBE_CO_FNC_EquipUnit;
	};
} else {
	["WARNING", Format ["Init_Client.sqf : WFBE_%1_DefaultGear is missing/short too - keeping the unit's config gear.", WFBE_Client_SideJoinedText]] Call WFBE_CO_FNC_LogContent;
};

/* Default gear menu filler. */
WF_Logic setVariable ['filler','primary'];

(player) Call WFBE_SK_FNC_Apply;

[] execVM "WASP\baserep\init.sqf";
[] execVM "WASP\actions\AddActions.sqf";

// Marty: Start a light client-side watcher that rights nearby flipped cars and tanks after they remain stuck.
[] execVM "Client\Module\AutoFlip\AutoFlip.sqf";

/* Debug System - Client */
if (WF_Debug) then {
	//player addEventHandler ["HandleDamage", {false}];
	// player setCaptive true;
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
           		 Private ["_color","_itemcategory","_preview","_area","_eside","_restricted"];
			_restricted = false;
			_itemcategory = _this select 0;
			_preview = _this select 1;
			_color = _this select 2;
            _eside = if (side commanderTeam == west) then {east} else {west};
            	_affected = ["Warfare_HQ_base_unfolded","Base_WarfareBBarracks","Base_WarfareBLightFactory","Base_WarfareBHeavyFactory",
            					"Base_WarfareBAircraftFactory","Base_WarfareBUAVterminal","Base_WarfareBVehicleServicePoint","BASE_WarfareBAntiAirRadar"];
			_area = [_preview,((sidejoined) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity2;

            	if (!isNull _area && {(_area getVariable ['avail', 0]) <= 0}) then { _color = _colorRed }; //--- cmdcon33: guard objNull _area (no base area before first HQ deploy -> nil<=0 falsely reddened the HQ ghost)
           		if (surfaceIsWater(position _preview)) then { _color = _colorRed }; if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_CHECK", 1]) > 0 && {({_preview isKindOf _x} count _affected) != 0} && {!(_preview isKindOf "Warfare_HQ_base_unfolded")} && {count ((position _preview) isFlatEmpty [(missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10]), 0, (missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_GRAD", 0.5]), 10, 0, false, objNull]) == 0}) then { _color = _colorRed }; //--- qol-polish-pack: reject too-steep ground for base structures (players lacked the slope check the AI commander already has)
           		if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_TREE_CLEAR", 0]) > 0 && {({_preview isKindOf _x} count _affected) != 0} && {!(_preview isKindOf "Warfare_HQ_base_unfolded")} && {count (nearestObjects [position _preview, ["Tree","SmallTree"], (missionNamespace getVariable ["WFBE_C_STRUCTURES_TREE_CLEAR", 0])]) != 0}) then { _color = _colorRed }; //--- fable/player-build-placement-gate: reject placement near trees for base structures (parity with the AI commander's _treeClearOK gate, PR #733 TP-19; nearestObjects not nearestTerrainObjects - the latter is A3-only, hotfixed out of the AI-side gate after a live RPT crash - see AI_Commander_Base.sqf:244)

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
				_restricted = true;
				hintsilent "Minefields are not allowed at base!";
			};
            	if (_itemcategory != 0 && typeOf _preview isKindOf "Base_WarfareBVehicleServicePoint") then {
                	_color = _colorGreen;
            	};


			if (_itemcategory == 0) then {
				Private ["_town","_townside","_eArea"];
				_town = [_preview] Call GetClosestLocation;
			    _townside =  (_town getVariable "sideID") Call GetSideFromID;
			    _eArea = [_preview,((_eside) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity3;
	            if ((_preview distance _town < 600 && _townside != sideJoined) || !isNull _eArea) then {
					_color = _colorRed;
					_restricted = true;
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
            		if (missionNamespace getVariable ["WFBE_C_DEFENSE_CLIENT_GATE_ALIGN", 0] > 0) then {
            			if (_itemcategory != 0 && ({side _x == _opposite_side} count _detected) >= (missionNamespace getVariable ["WFBE_C_DEFENSE_THREAT_MIN", 3])) then {
            				_color = _colorRed;
            				if (!((typeOf _preview) isKindOf "StaticWeapon")) then { hintSilent parseText "<t color='#fb0808'> Enemies are detected near your base! </t>"; };
            			};
            		} else {
            			{
            				if(_itemcategory !=0 && side _x == _opposite_side)exitwith{
            					_color = _colorRed;
            					if (!((typeOf _preview) isKindOf "StaticWeapon")) then { hintSilent parseText "<t color='#fb0808'> Enemies are detected near your base! </t>"; };
            				};

            			}foreach _detected;
            		};
};

            	if (((typeOf _preview) isKindOf "StaticWeapon") && {!_restricted}) then { _color = _colorGreen; };

			_color
		}];
	};
};

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

/* Lane 51: optional round-start music hook. Default-off until WFBE_C_MUSIC_ENABLE is set and soundtrack files are present. */
if ((missionNamespace getVariable ["WFBE_C_MUSIC_ENABLE", 0]) > 0) then {
	_introTrack = missionNamespace getVariable ["WFBE_C_MUSIC_MATCH_START_TRACK", missionNamespace getVariable ["WFBE_C_INTRO_MUSIC_TRACK", ""]];
	if ((count (toArray _introTrack)) > 0) then {playMusic _introTrack;};
};


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

//--- B745 (Ray 2026-06-24): intro video removed (Videos\intro720p.ogv deleted, ~2.3MB mission shrink). Playback line disabled.

/* Vote System, define whether a vote is already running or not */
if (sideJoined != resistance) then {
waitUntil {(sideJoined == civilian) || !isNil {WFBE_Client_Logic getVariable "wfbe_votetime"}};
["INITIALIZATION", "Init_Client.sqf: Vote system is initialized."] Call WFBE_CO_FNC_LogContent;
if ((WFBE_Client_Logic getVariable "wfbe_votetime") > 0) then {createDialog "WFBE_VoteMenu"};
};

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

//--- Trello #106: flashing center-screen warning when a restricted bomb (FAB-250 / Mk82) is the
//--- selected weapon while the aircraft is at or above the bomb altitude limit. Pre-emptive only:
//--- the actual drop is still deleted post-fire by Common_HandleShootBombs.sqf. Independent of the
//--- missile terrain-masking loop above (its ammo filter excludes bombs by design). The short
//--- re-issued titleText each tick produces the flashing effect.
[] spawn {
	private ["_bombAmmo"];

	// Same restricted-bomb ammo set used in Common\Functions\Common_HandleShootBombs.sqf.
	_bombAmmo = ["Bo_FAB_250","Bo_Mk82"];

	while {!WFBE_gameover} do {
		call {
			private [
				"_limit",
				"_vehicle",
				"_currentWeapon",
				"_currentWeaponMagazines",
				"_isBombSelected",
				"_ammo"
			];

			_limit = missionNamespace getVariable "WFBE_C_GAMEPLAY_BOMBS_ALTITUDE";

			// _limit 0 = param "Disabled"; nothing to warn about.
			if (isNil "_limit") exitWith {};
			if (_limit <= 0) exitWith {};

			//--- B748: per-player Settings opt-out of the COSMETIC warning only. Server/Fired-EH anti-exploit bomb deletion (Common_HandleShootBombs.sqf) is unaffected.
			if !(missionNamespace getVariable ["WFBE_BOMB_WARNING_ENABLED", true]) exitWith {};

			_vehicle = vehicle player;

			if (_vehicle == player) exitWith {};
			if !(player in crew _vehicle) exitWith {};

			// Only warn while a restricted bomb is the currently selected weapon.
			_currentWeapon = currentWeapon _vehicle;
			if (_currentWeapon == "") exitWith {};

			_currentWeaponMagazines = getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines");
			_isBombSelected = false;

			{
				_ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
				if (_ammo in _bombAmmo) exitWith {
					_isBombSelected = true;
				};
			} forEach _currentWeaponMagazines;

			if !(_isBombSelected) exitWith {};

			// Above (or at) the altitude limit: warn the player not to drop.
			if (((getPos _vehicle) select 2) >= _limit) then {
				titleText [localize "STR_WF_MESSAGE_BombAltitudeWarning", "PLAIN DOWN", 0.2];
			};
		};

		sleep 0.5;
	};
};
//--- Trello #106: end of bomb altitude warning script.

// Marty : initialise the low gear assist for local AI-driven tanks controlled by the player's group
[] spawn Compile preprocessFileLineNumbers "Client\Module\Valhalla\Func_Client_AI_LowGear_Manager.sqf";

clientInitComplete = true;

if ((missionNamespace getVariable ["WFBE_C_ONBOARDING_ENABLE", 1]) < 1) then { hint parseText "v16052026 <br/><br/> <t color='#28ff14'>If you're a new player:</t> <br/><br/>Read the instructions on map (press 'M' key) on the 'Notes' tab. <br/><br/>Our Discord server: <br/><br/><t color='#28ff14'>discord.me/warfare</t>  <br/><br/>(Open the link with a web browser like Chrome) <br/><br/>Ask in chat or on our Discord server if you want to know how something works. <br/><br/>You and your units are marked with <t color='#FFAC1C'>orange</t> color on map. <br/><br/>Friendly towns are marked with <t color='#1ff026'>green</t> color. <t color='#000bde'>Blue</t> and <t color='#de0300'>red</t> towns are controlled by enemy. <br/><br/>Note that you see friendly players and vehicles on map. <br/><br/><t color='#42b6ff'>WF menu</t> is important. You can open it by using action menu (mouse scroll). <br/><br/>Welcome and good luck, soldier! :)"; };

CLIENT_INIT_READY = player;

publicVariableServer "CLIENT_INIT_READY";

//--- Client FPS telemetry (staged-deploy day/night perf study, 2026-06-15). Self-gates on the
//--- WFBE_C_CLIENT_FPS_REPORT lobby param; players only. Reports avg/min FPS to the server.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_FpsReport.sqf";

//--- Ambulance / medic-redeploy range circles (Trello #76). Local map Ellipses around friendly
//--- ambulances and redeploy trucks showing the mobile-respawn radius. Self-gates on WFBE_C_RESPAWN_MOBILE.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_AmbulanceRedeployCircles.sqf";
//--- Artillery range rings (Trello #90). Client-local orange Ellipses around friendly arty pieces
//--- showing their WFBE_%1_ARTILLERY_RANGES_MAX firing radius. Self-gates on WFBE_C_ARTY_RING.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_ArtyRangeRings.sqf";

//--- New-player onboarding cards (claude-gaming 2026-06-29). Once-per-session, skippable structuredText
//--- hint sequence (what WASP is + win goal + 3 core actions + scroll-menu + JIP cue + respawn legend).
//--- Self-gates on WFBE_C_ONBOARDING_ENABLE (default 1) and a uiNamespace once-flag inside the function;
//--- detects JIP from mission time. Spawned (never blocks input/enrollment), placed after init completes.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Common_Onboarding.sqf";

//--- Rotating gameplay-tip feed (cmdcon42-q, claude-gaming 2026-07-02). Ray: "add 50 more hints
//--- that come by on rotation in the chat". Pure client cosmetic: posts one short tip via
//--- systemChat every WFBE_C_TIPS_PERIOD seconds from a 50-tip pool; each feature-tip is gated on
//--- its own feature flag so it auto-hides when Ray shelves the feature (or the feature's PR is
//--- unmerged). Self-gates on WFBE_C_TIPS_ENABLE (default 1) and uiSleep's WFBE_C_TIPS_INITIAL
//--- first so a fresh joiner isn't spammed over the onboarding cards. Spawned (never blocks input),
//--- placed after init completes - same guarded-spawn pattern as the onboarding call above.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_TipRotation.sqf";

//--- Late-join catch-up card. Self-gates on WFBE_C_JIP_CATCHUP_BRIEFING and reads only local or join-seeded state.
[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_JIPCatchupBriefing.sqf";

["INITIALIZATION", Format ["Init_Client.sqf: Client initialization ended at [%1]", time]] Call WFBE_CO_FNC_LogContent;
