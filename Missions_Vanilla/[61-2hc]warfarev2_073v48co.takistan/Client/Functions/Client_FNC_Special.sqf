/*
	Client Special Handled events (HandleSpecial.sqf)
	 Scope: Client.
*/

WFBE_CL_FNC_Commander_Assigned = {
	Private["_commanderTeam","_text"];
	_commanderTeam = _this select 0;
	_text = Localize "STR_WF_CHAT_AI_Commander";

	if (!isNull _commanderTeam) then {
		_text = Format[localize "STR_WF_CHAT_VoteForNewCommander",name (leader _commanderTeam)];
		if (group player == _commanderTeam) then {_text = localize "STR_WF_CHAT_PlayerCommanderTitleText"};
	}else{
		_logic = (side group player) Call WFBE_CO_FNC_GetSideLogic;
		_logic setVariable ["wfbe_commander", _commanderTeam, true];
	};

	[_text] Call TitleTextMessage;
};


WFBE_CL_FNC_Commander_VoteEnd = {
	Private["_commanderTeam","_text"];
	_commanderTeam = _this select 0;
	_text = Localize "STR_WF_CHAT_AI_Commander";

	if (!isNull _commanderTeam) then {
		_text = Format[localize "STR_WF_CHAT_VoteForNewCommander",name (leader _commanderTeam)];
		if (group player == _commanderTeam) then {_text = localize "STR_WF_CHAT_PlayerCommanderTitleText"};
	};

	[_text] Call TitleTextMessage;
};

WFBE_CL_FNC_Commander_VoteStart = {
	Private ["_name"];
	_name = _this select 0;

	if (votePopUp) then {
		waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_votetime"}};
		if ((WFBE_Client_Logic getVariable "wfbe_votetime") > 0 && !voted) then {
			createDialog "WFBE_VoteMenu"
		};
		if (voted) then {voted = false};
	};

	if (isMultiplayer) then {[Format[localize "STR_WF_CHAT_HasVotedForNewCommander", _name]] Call TitleTextMessage};
};

WFBE_CL_FNC_Display_ICBM = {
	Private ["_cruise", "_obj"];
	_obj = _this select 0;
	_cruise = _this select 1;

	waitUntil {!alive _cruise};

	[_obj] Spawn Nuke;
};

WFBE_CL_FNC_EndGame = {
	Private["_sideValue"];
	_sideValue = _this select 0;
	gameOver = true;
	WFBE_GameOver = true;

	(_sideValue Call WFBE_CO_FNC_GetSideFromID) ExecVM "Client\Client_EndGame.sqf";
};

WFBE_CL_FNC_HQ_SetStatus = {
	if (_this select 0) then {
		[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED",true,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
	} else {
		[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED",false,MCoin] Call Compile preprocessFile "Client\Init\Init_Coin.sqf";
	};
};

WFBE_CL_FNC_Perform_Action = {
	Private ['_action','_from','_unit'];
	_unit = _this select 0;
	_action = _this select 1;
	_from = _this select 2;

	_unit action [_action, _from];

	switch (_action) do {
		case "EJECT": {unassignVehicle _unit};
	};
};

WFBE_CL_FNC_Reveal_UAV = {
	Private ['_marker','_size','_target','_uav'];
	_uav = _this select 0;
	_target = _this select 1;

	if (typeName _uav != 'OBJECT' || typeName _target != 'OBJECT') exitWith {["ERROR", Format ["uav-reveal: An object is expected for both parameters given (UAV: [%1]  Target: [%2]).",_uav,_target]] Call WFBE_CO_FNC_LogContent};

	_size = round((_uav distance _target) / 16);
	_marker = Format["WFBE_UAV_SPOTTED_%1",unitMarker];
	unitMarker = unitMarker + 1;
	createMarkerLocal [_marker,[(getPos _target select 0) - random(_size) + random(_size),(getPos _target select 1) - random(_size) + random(_size),0]];
	_marker setMarkerShapeLocal "Ellipse";
	_marker setMarkerColorLocal "ColorOrange";
	_marker setMarkerSizeLocal [_size,_size];

	sleep ((missionNamespace getVariable "WFBE_C_PLAYERS_UAV_SPOTTING_DELAY")*3);

	deleteMarkerLocal _marker;
};

WFBE_CL_FNC_Upgrade_Started = {
	Private ["_storedEndTime","_storedId","_upgrade","_level", "_upgradeCost","_upgradeTime"];
	_upgrade = _this select 0;
	_level = _this select 1;

	_upgradeCost = (missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", (sideJoined)]) select _upgrade select (_level - 1) select 0;
	if (commanderTeam == group player) then {
		["RequestChangeScore", [player, (score player + (round ((_upgradeCost / 100) * WFBE_UPGRADE_SCORE_COEF)))]] Call WFBE_CO_FNC_SendToServer;
	};

	// Marty: Cache the started upgrade ID and local countdown end time so reopening the menu keeps the remaining time stable.
	_upgradeTime = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES", WFBE_Client_SideJoinedText]) select _upgrade) select (_level - 1);
	WFBE_Client_Logic setVariable ["wfbe_upgrading_id", _upgrade];
	_storedId = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_id";
	if (isNil "_storedId") then {_storedId = -1};
	_storedEndTime = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_end_time";
	if (isNil "_storedEndTime") then {_storedEndTime = -1};
	if (_storedId != _upgrade || _storedEndTime < time) then {
		WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_id", _upgrade, false];
		WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_end_time", time + _upgradeTime, false];
	};
	(Format [Localize "STR_WF_CHAT_Upgrade_Started_Message",(missionNamespace getVariable "WFBE_C_UPGRADES_LABELS") select _upgrade, _level]) Call CommandChatMessage;
	// Marty: Notify side players that their upgrade has started.
	//--- Task 29: dedicated quiet alias (same ogg, volume 2.5) — commanderNotification (10)
	//--- is shared by other notifications and stays loud for those.
	playSound "upgradeStartedSound";
};

WFBE_CL_FNC_Building_Started = {
	Private ["_building", "_localisedBuilding", "_position"];
	_building = _this select 0;
	_position = _this select 1;

	_localisedBuilding = "";

	switch (_building) do {
		case "Barracks": {
			_localisedBuilding = localize "RB_Barracks";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["barracksBuildSound",true]}; //--- B751d: opt-in audio cue (Settings menu); default OFF (was removed 2026-06-11 as too intrusive).
		};
		case "Light": {
			_localisedBuilding = localize "RB_Light_Factory";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["lightFactoryBuildSound",true]};
		};
		case "CommandCenter": {
			_localisedBuilding = localize "RB_Command_Center";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["commandCenterBuildSound",true]};
		};
		case "Heavy": {
			_localisedBuilding = localize "RB_Heavy_Factory";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["heavyFactoryBuildSound",true]};
		};
		case "Aircraft": {
			_localisedBuilding = localize "RB_Aircraft_factory";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["aircraftFactoryBuildSound",true]};
		};
		case "ServicePoint": {
			_localisedBuilding = localize "RB_Service_Point";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["servicePointBuildSound",true]};
		};
		case "AARadar": {
			_localisedBuilding = localize "STR_WF_UPGRADE_AntiAirRadar";
			if (missionNamespace getVariable ["WFBE_AUDIO_CUES", false]) then {playSound ["aaRadarBuildSound",true]};
		};
		case "ArtilleryRadar": {
			_localisedBuilding = localize "RB_Artillery_Radar";
		};
		case "Reserve": {
			_localisedBuilding = localize "RB_Reserve";
		};
		default {
			_localisedBuilding = "Unknown";
		};
	};

	if (_localisedBuilding != "Unknown") then {
		["DEBUG (Client_FNC_Special.sqf)", Format ["Building: %1", _localisedBuilding]] Call WFBE_CO_FNC_LogContent;
		Format[Localize "STR_WF_CHAT_Building_Started_Message", _localisedBuilding, ([_position, towns] Call GetClosestLocation)] Call CommandChatMessage;
	};
};

WFBE_CL_FNC_Upgrade_Complete = {
	Private ["_artilleryIndex","_artilleryTypes","_artilleryTypesByIndex","_artilleryVehicles","_level","_upgrade","_upgradeCost","_vehicle"];
	//--- QoL trio feat.2 private vars.
	Private ["_qolFactoryKey","_qolUnitList","_qolUnlocks","_qolC","_qolLabel","_qolBanner"];
	//--- _upgrade_isplayer: true when a human commander triggered this upgrade (passed from
	//--- Server_ProcessUpgrade.sqf). False/missing for AI-commander upgrades. Used to suppress
	//--- audio+banner so players do not hear unexplained sounds when the AI silently researches.
	Private ["_upgrade_isplayer"];
	_upgrade = _this select 0;
	_level = _this select 1;
	_upgrade_isplayer = if (count _this > 2) then {_this select 2} else {false};

	(Format [Localize "STR_WF_CHAT_Upgrade_Complete_Message",(missionNamespace getVariable "WFBE_C_UPGRADES_LABELS") select _upgrade, _level]) Call CommandChatMessage;

	//--- Trello #107: follow the opaque "Level N" line with the CONCRETE resulting value for the
	//--- upgrade types that map to a clean client-side scalar array (same arrays the upgrade-menu
	//--- descriptions use in Labels_Upgrades.sqf). The arrays are indexed by the stored upgrade
	//--- level, and _level here is that new stored level (Server_ProcessUpgrade passes level+1),
	//--- so a direct lookup gives the value now in effect. Conservative: only the two cleanly
	//--- resolvable types are handled; every other upgrade keeps the level-only message untouched.
	Private ["_artyIntervals","_respawnRanges"];
	switch (_upgrade) do {
		case WFBE_UP_ARTYTIMEOUT: {
			_artyIntervals = missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS";
			if (!isNil "_artyIntervals" && {_level < count _artyIntervals}) then {
				(Format [Localize "STR_WF_CHAT_Upgrade_Value_ArtyReload", _artyIntervals select _level]) Call CommandChatMessage;
			};
		};
		case WFBE_UP_RESPAWNRANGE: {
			_respawnRanges = missionNamespace getVariable "WFBE_C_RESPAWN_RANGES";
			if (!isNil "_respawnRanges" && {_level < count _respawnRanges}) then {
				(Format [Localize "STR_WF_CHAT_Upgrade_Value_RespawnRange", _respawnRanges select _level]) Call CommandChatMessage;
			};
		};
		default {};
	};

	//--- QoL trio feat.2: upgrade-complete banner with top-3 unit unlocks.
	//--- BUG-FIX (build5 regression): banner is side-wide — shows for ALL of the player's own
	//--- side's completed upgrades regardless of who triggered it.
	//--- Only the SOUND stays gated to player-initiated upgrades (avoids "sounds out of nowhere").
	//--- Only attempt for the four factory upgrade types (BARRACKS/LIGHT/HEAVY/AIR = IDs 0-3).
	if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) > 0 && _upgrade <= 3) then {
		_qolFactoryKey = (["BARRACKSUNITS","LIGHTUNITS","HEAVYUNITS","AIRCRAFTUNITS"] select _upgrade);
		_qolUnitList = missionNamespace getVariable [Format ["WFBE_%1%2", WFBE_Client_SideJoinedText, _qolFactoryKey], []];
		_qolUnlocks = [];
		{
			if (count _qolUnlocks < 3) then {
				_qolC = missionNamespace getVariable _x;
				if !(isNil "_qolC") then {
					if ((_qolC select QUERYUNITUPGRADE) == _level) then {
						_qolLabel = _qolC select QUERYUNITLABEL;
						if (_qolLabel == "") then {_qolLabel = [_x, "displayName"] Call GetConfigInfo};
						if (_qolLabel != "") then {
							_qolUnlocks = _qolUnlocks + [_qolLabel];
						};
					};
				};
			};
		} forEach _qolUnitList;
		_qolBanner = Format ["%1 upgraded to level %2!", (missionNamespace getVariable "WFBE_C_UPGRADES_LABELS") select _upgrade, _level];
		if (count _qolUnlocks > 0) then {
			_qolBanner = _qolBanner + (Format [" New: %1", _qolUnlocks select 0]);
			if (count _qolUnlocks > 1) then {_qolBanner = _qolBanner + (Format [", %1", _qolUnlocks select 1])};
			if (count _qolUnlocks > 2) then {_qolBanner = _qolBanner + (Format [", %1", _qolUnlocks select 2])};
		};
		hintSilent _qolBanner;
	};

	//--- Sound only: still gated to player-initiated upgrades.
	//--- AI-commander upgrades (prime suspect for "sounds out of nowhere") remain silent.
	if (_upgrade_isplayer) then {
		// Marty: Notify side players that their upgrade has completed.
		playSound "ARTY_cooldown_over";
	}; //--- end _upgrade_isplayer guard
	// Marty: Clear the local cached upgrade ID and countdown when completion is announced.
	WFBE_Client_Logic setVariable ["wfbe_upgrading_id", -1];
	WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_id", -1, false];
	WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_end_time", -1, false];

	// Marty: Refresh local artillery vehicles after Artillery Ammunition unlocks new special rounds.
	// Existing empty artillery is equipped only when it is bought, built or rearmed, so scanning group units is not enough.
	// Each machine refreshes only vehicles local to it, which avoids duplicate magazines while covering client-created artillery.
	if (_upgrade == WFBE_UP_ARTYAMMO) then {
		_artilleryVehicles = [];
		_artilleryTypesByIndex = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES", WFBE_Client_SideJoinedText];

		for "_artilleryIndex" from 0 to (count _artilleryTypesByIndex)-1 do {
			_artilleryTypes = _artilleryTypesByIndex select _artilleryIndex;
			{
				_vehicle = _x;
				if ((local _vehicle) && ((typeOf _vehicle) in _artilleryTypes) && !(_vehicle in _artilleryVehicles) && isNil {_vehicle getVariable "wfbe_arty_ammo_refreshed"}) then {
					// Marty: EquipArtillery reads the current side upgrade level and adds any newly unlocked special artillery magazines.
					[_vehicle, _artilleryIndex, WFBE_Client_SideJoined] Call EquipArtillery;
					_vehicle setVariable ["wfbe_arty_ammo_refreshed", true, true];
					_artilleryVehicles = _artilleryVehicles + [_vehicle];

					// Marty: Rebuild the BIS artillery command menu from the refreshed magazines for already-existing guns.
					if ((missionNamespace getVariable "WFBE_C_ARTILLERY_UI") > 0) then {
						clearVehicleInit _vehicle;
						_vehicle setVehicleInit "[this] ExecVM 'Common\Common_InitArtillery.sqf'";
						processInitCommands;
						clearVehicleInit _vehicle;
					};
				};
			} forEach vehicles;
		};

		// Marty: Always log the local refresh count so artillery ammo upgrade tests can confirm whether this client owned any artillery vehicles.
		["INFORMATION", Format ["Client_FNC_Special.sqf: Refreshed [%1] local artillery pieces after Artillery Ammunition upgrade.", count _artilleryVehicles]] Call WFBE_CO_FNC_LogContent;
	};

	if (!isNil "commanderTeam" && {!(isNull commanderTeam)}) then { //--- Commander reward (if the player is the commander). Guard: commanderTeam is undefined for a JIP joiner before the commander FSM sets it -> "Undefined variable commanderteam" (Ray client RPT 2026-06-27).
		if (commanderTeam == group player) then {
		};
	};
};
