// Marty: Performance Audit locals.
private["_toggle_auto_distance_view","_lastCommanderTeam","_changeCommander","_timer", "_sideHQ", "_perfLoopStart", "_perfAFKStart", "_perfAFKBroadcasts","_countDownKick"];

commanderTeam = (sideJoined) Call WFBE_CO_FNC_GetCommanderTeam;

_lastCommanderTeam = commanderTeam;
_changeCommander = false;
_timer = 0;

// Marty : SEND_MESSAGE Event Handler 
onEventHandler_SEND_MESSAGE = compile preprocessFileLineNumbers "Client\Functions\Client_onEventHandler_SEND_MESSAGE.sqf";
"SEND_MESSAGE" addPublicVariableEventHandler {_this call onEventHandler_SEND_MESSAGE};

// Marty : MARKER_CREATION Event Handler 
onEventHandler_MARKER_CREATION = compile preprocessFileLineNumbers "Client\Functions\Client_onEventHandler_MARKER_CREATION.sqf";
"MARKER_CREATION" addPublicVariableEventHandler {_this call onEventHandler_MARKER_CREATION};

// Marty : ICBM Event Handler
OnEventHandler_ICBM_Launch = Compile preprocessFileLineNumbers "Client\Module\Nuke\OnEventHandler_ICBM_Launch.sqf";
"ICBM_launched" addPublicVariableEventHandler {_this call OnEventHandler_ICBM_Launch};

// Marty : player radiated Event Handler
OnEventHandler_player_radiated = Compile preprocessFileLineNumbers "Client\Module\Nuke\OnEventHandler_player_radiated.sqf";
"PLAYER_RADIATED" addPublicVariableEventHandler {_this call OnEventHandler_player_radiated};

//marty : initialize AFK kick time by default
if !(isMultiplayer) then {missionNamespace setVariable ["WFBE_C_AFK_TIME", 10]}; // useful when testing solo.
_inactivityTimeout = missionNamespace getVariable "WFBE_C_AFK_TIME";
_inactivityTimeout = _inactivityTimeout * 60; // Convert the given time from minutes to seconds.

if (WF_Debug) then {_inactivityTimeout = _inactivityTimeout * 99999};

AutomaticViewDistance = compile preprocessFile "Common\Functions\Common_AutomaticViewDistance.sqf";

while {!gameOver} do {

	// Marty: Performance Audit timing for the full client update tick.
	_perfLoopStart = diag_tickTime;
	_perfAFKBroadcasts = 0;

	// Marty : update HQ wreck marker on map in case a player join after the game already begin or if the wreck is moved.
	if (playerSide == west) then 
	{
		_is_west_hq_alive = missionNamespace getVariable ["IS_WEST_HQ_ALIVE", true];

		if (_is_west_hq_alive) then 
		{
			deleteMarkerLocal "HQ_WRECK_WEST";
		}
		else
		{
			_MARKER_infos = missionNamespace getVariable ["HQ_WEST_MARKER_INFOS", []];

			if ((count _MARKER_infos) >= 7) then 
			{
				_markerName 			= _MARKER_infos select 0;
				_markerPosition			= _MARKER_infos select 1;
				_markerType				= _MARKER_infos select 2;
				_markerText				= _MARKER_infos select 3;
				_markerColor			= _MARKER_infos select 4;
				_side_who_see_marker 	= _MARKER_infos select 5;
				_hq 					= _MARKER_infos select 6;

				if (!isNull _hq) then 
				{
					[_hq, _markerName, _markerType, _markerText, _markerColor] call UpdateMarker;
				};
			};
		};
	};

	if (playerSide == east) then 
	{
		_is_east_hq_alive = missionNamespace getVariable ["IS_EAST_HQ_ALIVE", true];

		if (_is_east_hq_alive) then 
		{
			deleteMarkerLocal "HQ_WRECK_EAST";
		}
		else
		{
			_MARKER_infos = missionNamespace getVariable ["HQ_EAST_MARKER_INFOS", []];

			if ((count _MARKER_infos) >= 7) then 
			{
				_markerName 			= _MARKER_infos select 0;
				_markerPosition			= _MARKER_infos select 1;
				_markerType				= _MARKER_infos select 2;
				_markerText				= _MARKER_infos select 3;
				_markerColor			= _MARKER_infos select 4;
				_side_who_see_marker 	= _MARKER_infos select 5;
				_hq 					= _MARKER_infos select 6;

				if (!isNull _hq) then 
				{
					[_hq, _markerName, _markerType, _markerText, _markerColor] call UpdateMarker;
				};
			};
		};
	};
	
	//Marty : automatic adjusting distance view. The distance view of the client is adjusted automatically to reach the fps target.
	_toggle_auto_distance_view = missionNamespace getVariable "TOOGLE_AUTO_DISTANCE_VIEW";
	if (_toggle_auto_distance_view && !visibleMap) then 
	{
		call AutomaticViewDistance; 
	};

	//Marty : check the inactivity (AFK, Away From Keyboard) and kick the player after too long time elapsed
	// Marty: Performance Audit timing for the legacy AFK block.
	_perfAFKStart = diag_tickTime;

	// calculate the elapsed time from last action of the player 
	_currentTime = time ;
	_lastActionTime = player getVariable ["lastActionTime", time];
	_elapsedTime = _currentTime - _lastActionTime ;
	_countDownKick =round(_inactivityTimeout - _elapsedTime);
	//player sideChat format ["Elapsed Time: %1 seconds", _elapsedTime]; // Display the inacticity time of the player for testing purpose	

	// Marty: Kick warning follows actual activity, so recent command-map clicks do not show a false kick countdown.
	if (_countDownKick < 600) then {
		call {
			if (_countDownKick <= 120) exitWith {
				hint format ["You are AFK. If you don't move or command on the map you will be kicked in %1 seconds.", _countDownKick];
			};
			if ((_countDownKick % 30) != 0) exitWith {};
			hint format ["You are AFK. If you don't move or command on the map you will be kicked in %1 minutes.", round (_countDownKick / 60)];
		};
	};


	// Check if the player has been inactive for more than the specified duration, if so he's ejected from the mission.
    if (_elapsedTime > _inactivityTimeout) then {
        
		// Creation of a publicVariable named "kickAFK" that will be detected by BattleEye (customized filter) and will kick the client (=the player) that is using the kickAFK variable.
		// BattleEye is used with publicVariable in order to kick player because the serverCommand has been deactivated by Bohemia since the arma2OA updated for security reason. But Weirdly they didnt mention it clearly.
		// DON'T FORGET TO CREATE THE TEXT FILE FOR BATTLEYE. This text file must be located in the BattlEye folder where the server.cfg of the mission is. This file is called publicVariable.txt and contain the instruction : 5 "kickAFK" 
		_namePlayer = name player ;
		["KICK", format["%1 Kicked for AFKing", _namePlayer]] Call WFBE_CO_FNC_LogContent;

		kickAFK = format["%1 Kicked for AFKing", _namePlayer];
		publicVariable "kickAFK";
	
		//endMission "END1"; //not good. The player stays in the slot. Must be kicked using BattlEye Filter.

    };
	
	// Verify if the player moved since the last check position
	_currentPosition 	= getPos player;
	_lastPosition 		= player getVariable ["lastPosition", getPos player] ;
      
	// Marty: Preserve the original command-client AFK activity behavior; Command & Conquer marker state is handled in monitorAFK.sqf.
	if (str(_currentPosition) != str(_lastPosition)) then {            	 
		player setVariable ["lastActionTime", time];
    };

	player setVariable ["lastPosition", position player]; // Saving the last position of the player with the current one.
	// Marty. 

	// Marty: Performance Audit record for the legacy AFK block.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["updateclient_afk", diag_tickTime - _perfAFKStart, Format["afkBroadcasts:%1;countDown:%2", _perfAFKBroadcasts, _countDownKick], "CLIENT"] Call PerformanceAudit_Record;
		};
	};

	commanderTeam = (sideJoined) Call WFBE_CO_FNC_GetCommanderTeam;
	if (IsNull commanderTeam && !IsNull _lastCommanderTeam) then {_changeCommander = true};
	if (!IsNull commanderTeam && IsNull _lastCommanderTeam) then {_changeCommander = true};
	if (!isNull commanderTeam && !isNull _lastCommanderTeam) then {
		if (commanderTeam != _lastCommanderTeam) then {_changeCommander = true};
	};

	if(_changeCommander && !gameOver) then {
		_changeCommander = false;
		_lastCommanderTeam = commanderTeam;
		_MHQ = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;

		if (IsNull commanderTeam) then {
			if (!IsNull _MHQ) then {
				_MHQ RemoveAction 0;
				_MHQ RemoveAction 1;
				_MHQ RemoveAction 2;
				_MHQ RemoveAction 3;
			};
			if (!isNil "HQAction") then {player removeAction HQAction};
			if (count (hcAllGroups player) > 0) then {HCRemoveAllGroups player};
			{[_x,false] Call SetTeamAutonomous} forEach clientTeams;
		};

		if (!isNull(commanderTeam)) then {
			if (commanderTeam == Group player) then {
				if (!IsNull _MHQ) then {
					_MHQ addAction [localize "STR_WF_Unlock_MHQ","Client\Action\Action_ToggleLock.sqf", [], 95, false, true, '', 'alive _target && locked _target'];
					_MHQ addAction [localize "STR_WF_Lock_MHQ","Client\Action\Action_ToggleLock.sqf", [], 94, false, true, '', 'alive _target && !(locked _target)'];
				};
				_deployed = (sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus;
				if (_deployed) then {
					[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED",true,MCoin] Call Compile PreprocessFile "Client\Init\Init_Coin.sqf";
				} else {
					[missionNamespace getVariable "WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED",false,MCoin] Call Compile PreprocessFile "Client\Init\Init_Coin.sqf";
				};
				HQAction = leader(group player) addAction [localize "STR_WF_BuildMenu","Client\Action\Action_Build.sqf", [_MHQ], 100, false, true, "", "hqInRange && canBuildWHQ && (_target == player)"];
				[Localize "STR_WF_CHAT_PlayerCommanderTitleText"] Call TitleTextMessage;
				hint parseText format ["<t color='fff700'>%1</t>", localize "STR_WF_CHAT_PlayerCommander"];
				playSound ["commanderNotification", true];
				playSound ["newCommander",true];
				["INFORMATION", Format ["Player %1 has become a new commander in %2 team).", name player, side player]] Call WFBE_CO_FNC_LogContent;
			} else {
				if (!isNil "HQAction") then {player removeAction HQAction};
				if (count (hcAllGroups player) > 0) then {HCRemoveAllGroups player};
			};
		};

	};

	if (!isNull commanderTeam) then {
		if (commanderTeam == Group player) then {
			_sideHQ = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
			SideHQAttack = _sideHQ;
			_actionAttached = SideHQAttack getVariable "actionAttached";
			if (isNil "_actionAttached") then {
				_sideHQ addAction ["<t color='#ff6a00'>HEAVY ATTACK MODE</t>","Common\Functions\Common_AttackWaveActivate.sqf", [(sideJoined) call GetSideSupply, sideJoined], 1.5, false, false, "", "(((sideJoined) Call GetSideSupply) >= 25000) && (cursorTarget distance player < 50)"];
				_sideHQ setVariable ["actionAttached", true];
			};
		};
	};

	// Marty: Performance Audit record for the full client update tick.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["updateclient_total", diag_tickTime - _perfLoopStart, Format["afkBroadcasts:%1;clientTeams:%2", _perfAFKBroadcasts, count clientTeams], "CLIENT"] Call PerformanceAudit_Record;
		};
	};

	sleep 1;
};
