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
	case "delegate-townai": {_args spawn WFBE_CL_FNC_DelegateTownAI};
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
	case "drone-strike-fx": {
		_args spawn {
			private ["_pos","_strikeSide","_m"];
			_pos = _this select 0;
			_strikeSide = _this select 1;
			if (playerSide == _strikeSide) then {
				_m = Format ["WFBE_DRONE_FX_%1", str (round (time * 10))];
				createMarkerLocal [_m, _pos];
				_m setMarkerTypeLocal "mil_destroy";
				_m setMarkerColorLocal (if (_strikeSide == west) then {"ColorBlue"} else {"ColorRed"});
				_m setMarkerTextLocal "Drone strike";
				playSound "commanderNotification";
				systemChat "Drone strike package inbound -- target grid painted.";
				sleep 35;
				deleteMarkerLocal _m;
			} else {
				playSound "inbound";
				systemChat "WARNING: hostile drone activity detected in your sector.";
			};
		};
	};
	case "drone-fx": {
		_args spawn {
			private ["_t","_o","_src","_li"];
			_t = _this select 0;
			_o = _this select 1;
			if (isNull _o) exitWith {};
			switch (_t) do {
				case "trail": {
					_src = "#particlesource" createVehicleLocal (getPosASL _o);
					_src setDropInterval 0.04;
					_src setParticleParams [["\ca\Data\ParticleEffects\Universal\Universal", 16, 0, 1], "", "Billboard", 0.1, 1.4, [0,0,0], [0, 0, 4], 0, 12, 7.9, 0.07, [0.35], [[1,1,1,0.55],[1,1,1,0]], [0], 1, 0, "\CA\Data\ParticleEffects\SCRIPTS\WPTrail.sqf", "", _o];
					_src setParticleRandom [0.1, [0.25, 0.25, 0], [6, 6, 3], 0, 0.15, [0, 0, 0, 0], 0, 0];
					[_src, _o] spawn { waitUntil {sleep 1.5; isNull (_this select 1) || !alive (_this select 1)}; deleteVehicle (_this select 0); };
				};
				case "flame": {
					_li = "#lightpoint" createVehicleLocal (getPosASL _o);
					_li setLightBrightness 1.1; _li setLightAmbient [1,0.5,0.15]; _li setLightColor [1,0.55,0.2];
					_li lightAttachObject [_o, [0,0,0]];
					[_li, _o] spawn { waitUntil {sleep 0.4; isNull (_this select 1) || !alive (_this select 1)}; deleteVehicle (_this select 0); };
				};
				case "flarepop": {
					_li = "#lightpoint" createVehicleLocal (getPosASL _o);
					_li setLightBrightness 1.4; _li setLightAmbient [1,0.92,0.6]; _li setLightColor [1,0.95,0.7];
					[_li] spawn { sleep 2.5; deleteVehicle (_this select 0); };
				};
			};
		};
	};
	case "upgrade-started": {_args spawn WFBE_CL_FNC_Upgrade_Started};
	case "upgrade-complete": {_args spawn WFBE_CL_FNC_Upgrade_Complete};
	case "building-started": {_args spawn WFBE_CL_FNC_Building_Started};
	case "set-hq-killed-eh": {if !(isServer) then {(_args select 0) addEventHandler ["killed", {["RequestSpecial", ["process-killed-hq", _this]] Call WFBE_CO_FNC_SendToServer}]};};
	case "auto-wall-constructing-changed":{ isAutoWallConstructingEnabled = (_args select 0)};
	case "attack-wave": {ATTACK_WAVE_PRICE_MODIFIER = (_args select 0);};
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
