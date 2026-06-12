Private['_args', '_request'];

_request = _this select 0;
_args = +_this;
_args set [0, "**NIL**"];
_args = _args - ["**NIL**"]; //--- Strip the action request from the arguments.

switch (_request) do {
	case "action-perform": {_args spawn WFBE_CL_FNC_Perform_Action};
	case "commander-vote": {_args spawn WFBE_CL_FNC_Commander_VoteEnd};
	case "commander-vote-start": {_args spawn WFBE_CL_FNC_Commander_VoteStart};
	case "new-commander-assigned": {_args spawn WFBE_CL_FNC_Commander_Assigned};
	// Marty: Run delegated town AI cleanup on the machine that owns the local groups.
	case "cleanup-townai": {_args spawn WFBE_CL_FNC_CleanupDelegatedTownAI};
	// Item 1: Delete airfield garrison units that are local to this machine.
	// Each machine (server, client, HC) deletes its own locally-owned garrison units.
	case "cleanup-airfield-garrison": {
		Private ["_garLoc","_garUnits","_garUnit"];
		_garLoc = _args select 0;
		if (isNull _garLoc) exitWith {};
		//--- Primary: use the server-maintained array if available.
		_garUnits = _garLoc getVariable "wfbe_airfield_garrison_units";
		if (isNil "_garUnits") then {_garUnits = []};
		{
			_garUnit = _x;
			if !(isNull _garUnit) then {
				if (alive _garUnit && local _garUnit) then {deleteVehicle _garUnit};
			};
		} forEach _garUnits;
		//--- Fallback: scan local AI units for the wfbe_airfield_garrison tag (covers HC-delegated units
		//--- created locally but not in the server array). allUnits = men only; vehicles is separate.
		{
			_garUnit = _x;
			if (local _garUnit && alive _garUnit && !isPlayer _garUnit) then {
				if (_garUnit getVariable ["wfbe_airfield_garrison", false]) then {
					deleteVehicle _garUnit;
				};
			};
		} forEach allUnits;
		{
			_garUnit = _x;
			if (local _garUnit && alive _garUnit) then {
				if (_garUnit getVariable ["wfbe_airfield_garrison", false]) then {
					deleteVehicle _garUnit;
				};
			};
		} forEach vehicles;
	};
	case "delegate-townai": {_args spawn WFBE_CL_FNC_DelegateTownAI};
	case "delegate-sidepatrol": {_args spawn WFBE_CO_FNC_RunSidePatrol};
	case "delegate-aicom-team": {_args spawn WFBE_CO_FNC_RunCommanderTeam};
	case "delegate-ai": {_args spawn WFBE_CL_FNC_DelegateAI};
	case "delegate-ai-static-defence": {_args spawn WFBE_CL_FNC_DelegateAIStaticDefence};
	case "endgame": {_args spawn WFBE_CL_FNC_EndGame};
	case "group-join-accept": {_args call WFBE_CL_FNC_Groups_JoinAccepted};
	case "group-join-deny": {_args call WFBE_CL_FNC_Groups_JoinDenied};
	case "group-kick": {_args call WFBE_CL_FNC_Groups_KickedOff};
	case "group-join-request": {_args call WFBE_CL_FNC_Groups_ReceiveRequest};
	case "hq-setstatus": {_args spawn WFBE_CL_FNC_HQ_SetStatus};
	case "icbm-display": {_args spawn WFBE_CL_FNC_Display_ICBM};
	case "irsmoke-createfx": {{_x spawn WFBE_CO_MOD_IRS_CreateSmoke} forEach (_args select 0)};
	case "join-answer": 
	{
		missionNamespace setVariable ['WFBE_P_CANJOIN', (_args select 0)]; 
		missionNamespace setVariable ['WFBE_BLUFOR_SCORE_JOIN', (_args select 1)];
		missionNamespace setVariable ['WFBE_OPFOR_SCORE_JOIN', (_args select 2)]
	};
	case "uav-reveal": {_args spawn WFBE_CL_FNC_Reveal_UAV};
	case "upgrade-started": {_args spawn WFBE_CL_FNC_Upgrade_Started};
	case "upgrade-complete": {_args spawn WFBE_CL_FNC_Upgrade_Complete};
	case "building-started": {_args spawn WFBE_CL_FNC_Building_Started};
	case "set-hq-killed-eh": {if !(isServer) then {(_args select 0) addEventHandler ["killed", {["RequestSpecial", ["process-killed-hq", _this]] Call WFBE_CO_FNC_SendToServer}]};};
	case "auto-wall-constructing-changed":{ isAutoWallConstructingEnabled = (_args select 0)};
	case "attack-wave": {ATTACK_WAVE_PRICE_MODIFIER = (_args select 0);};
	//--- Marty: Vote-skip-night: server has already advanced its clock and publicVariable'd WFBE_DAYNIGHT_DATE.
	//--- The DAYNIGHT_DATE PVEH only flags PENDING_SYNC (not a direct setDate); do it explicitly here.
	case "vote-skip-night": {
		Private ["_newDate"];
		_newDate = _args select 0;
		if ((typeName _newDate) == "ARRAY" && {count _newDate >= 5}) then {
			setDate _newDate;
		};
	};
	//--- Marty: Vote-weather-apply: engine does NOT auto-sync weather to clients.
	case "vote-weather-apply": {
		Private ["_ov","_ra"];
		_ov = _args select 0;
		_ra = _args select 1;
		60 setOvercast _ov;
		60 setRain     _ra;
	};
	//--- AI Commander donation confirmation: show hint to the donor.
	case "aicom-donate-confirm": {
		Private ["_dAmount"];
		_dAmount = _args select 0;
		hint parseText Format [localize "STR_WF_INFO_Funds_Sent_AICom", _dAmount];
	};
	// Marty: Server-side command bar cleanup can transfer dead AI locality back to the player for final detachment.
	case "commandbar-force-dead-cleanup": {
		_args Spawn {
			Private ["_deadline","_unit"];

			_unit = _this select 0;
			if (isNull _unit) exitWith {};

			["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_FORCE_RECEIVED player:%1 unit:%2 unitGroup:%3 playerGroup:%4 localUnit:%5", name player, _unit, group _unit, group player, local _unit]] Call WFBE_CO_FNC_LogContent;

			_deadline = time + 3;
			waitUntil {sleep 0.05; isNull _unit || local _unit || time > _deadline};

			if (isNull _unit) exitWith {};
			if (alive _unit) exitWith {};
			if (isPlayer _unit) exitWith {};
			if (_unit in playableUnits) exitWith {};
			if ((group _unit) != (group player)) exitWith {};
			if !(local _unit) then {
				["WARNING", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_FORCE_NOT_LOCAL player:%1 unit:%2 unitGroup:%3 localUnit:%4", name player, _unit, group _unit, local _unit]] Call WFBE_CO_FNC_LogContent;
			};
			if (WF_Debug) then {
				["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT CLIENT_FORCE_JOIN player:%1 unit:%2 unitGroup:%3 localUnit:%4", name player, _unit, group _unit, local _unit]] Call WFBE_CO_FNC_LogContent;
			};

			player groupSelectUnit [_unit, false];
			[_unit] joinSilent grpNull;
		};
	};
};
