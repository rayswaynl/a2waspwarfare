Private['_args'];

_args = _this;

switch (_args select 0) do {
	case "update-teamleader": {
		Private ["_leader","_team"];
		_team = _args select 1;
		_leader = _args select 2;

		_team setVariable ["wfbe_teamleader", _leader];
	};
	case "group-query": {
		Private ["_group","_player","_side"];
		//--- GUARD (claude-gaming): a malformed/short request (count _args <= 3) used to crash here at
		//--- "_args select 2/3" ("Error in expression <[_player = _args select 2"). A console action that
		//--- mis-built its RequestSpecial payload was observed firing this. Bail safely on a short payload
		//--- rather than select-crash; the valid 4-arg [_,grp,player,side] path is unchanged below.
		if (count _args < 4) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: group-query received a short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		_group = _args select 1;
		_player = _args select 2;
		_side = _args select 3;

		if (alive _player) then {
			if (alive leader _group) then {
				if (isPlayer leader _group) then {
					//--- Player, forward the request.
					if (WF_A2_Vanilla) then {
						[getPlayerUID (leader _group), "HandleSpecial", ["group-join-request", _player]] Call WFBE_CO_FNC_SendToClients;
					} else {
						[leader _group, "HandleSpecial", ["group-join-request", _player]] Call WFBE_CO_FNC_SendToClient;
					};
				} else {
					if (isNil {_group getVariable "wfbe_uid"}) then { //--- Ensure that the group is ai-controlled.
						[_player, _group, _side] Call WFBE_CO_FNC_ChangeUnitGroup;

						//--- Tell the player that his request is granted.
						if (WF_A2_Vanilla) then {
							[getPlayerUID (_player), "HandleSpecial", ["group-join-accept", _group]] Call WFBE_CO_FNC_SendToClients;
						} else {
							[_player, "HandleSpecial", ["group-join-accept", _group]] Call WFBE_CO_FNC_SendToClient;
						};
					};
				};
			};
		};
	};
	case "Paratroops": {
		_args spawn KAT_Paratroopers;
	};

	case "ParaVehi": {
		_args spawn KAT_ParaVehicles;
	};

	case "ParaAmmo": {
		_args spawn KAT_ParaAmmo;
	};

	case "RespawnST": {
		Private ["_side","_st"];
		_side = _args select 1;
		_st = (_side call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_ai_supplytrucks";
		{if (!isNull (driver _x)) then {driver _x setDammage 1};_x setDammage 1} forEach _st;
		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Supply Trucks were forced respawn.", str _side]] Call WFBE_CO_FNC_LogContent;
	};

	case "uav": {
		_args spawn KAT_UAV;
	};

	//--- NAVAL HVT: SCUD saturation strike (feat/naval-hvt-objectives).
	//--- Server validates ownership + cooldown inside KAT_ScudStrike before firing.
	case "ScudStrike": {
		if (!isNil "KAT_ScudStrike") then {
			_args spawn KAT_ScudStrike;
		} else {
			["WARNING", "Server_HandleSpecial.sqf: ScudStrike received but KAT_ScudStrike is nil (WFBE_C_NAVAL_HVT=0?)."] Call WFBE_CO_FNC_LogContent;
		};
	};

	case "upgrade-sync": {
		Private ["_side","_upgrade_id","_upgrade_level"];
		_side = _args select 1;
		_upgrade_id = _this select 2;
		_upgrade_level = _this select 3;

		if !(isNil {missionNamespace getVariable Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level]}) then {missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], true]};
	};
	case "update-clientfps": {
		Private ["_fps","_uid"];
		_uid = _args select 1;
		_fps = _args select 2;

		_get = missionNamespace getVariable format["WFBE_AI_DELEGATION_%1", _uid];
		if !(isNil "_get") then {
			_get set [0, _fps];
			missionNamespace setVariable [format["WFBE_AI_DELEGATION_%1", _uid], _get];
		};
	};
	case "update-town-delegation": {
		Private ["_teams","_town","_vehicles"];
		_town = _args select 1;
		_teams = [];
		_vehicles = [];

		// Marty: New delegated town AI reports include local HC/client groups before vehicles; keep old vehicle-only format compatible.
		if (count _args > 3) then {
			_teams = _args select 2;
			_vehicles = _args select 3;
		} else {
			_vehicles = _args select 2;
		};

		// Marty: Track the real delegated groups so server-side state and cleanup requests reference the same town assets.
		{
			if !(isNull _x) then {
				if !(_x in (_town getVariable "wfbe_town_teams")) then {
					_town setVariable ['wfbe_town_teams', (_town getVariable "wfbe_town_teams") + [_x]];
				};
			};
		} forEach _teams;

		_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + _vehicles];
		// Marty: Log the server acknowledgement of delegated town assets for production RPT diagnosis.
		["INFORMATION", Format ["TOWN_AI_HC_CLEANUP server_update town:%1 teams:%2 vehicles:%3 totalTeams:%4 totalVehicles:%5", _town getVariable "name", count _teams, count _vehicles, count (_town getVariable "wfbe_town_teams"), count (_town getVariable 'wfbe_active_vehicles')]] Call WFBE_CO_FNC_LogContent;
		{
			[_x] spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_x setVariable ["WFBE_Taxi_Prohib", true];
		} forEach _vehicles;
	};
	//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02): the commander's ICBM fire, intercepted client-side
	//--- (GUI_Menu_Tactical.sqf when WFBE_C_ICBM_TEL=1) and routed here. Server-authoritative gate lives in
	//--- WFBE_SE_FNC_IcbmTelFire (TEL alive + shared cooldown + range + funds); it spawns/refuses accordingly.
	//--- Payload: ["icbm-tel-fire", side, target, munition, playerTeam, fee, platformHint?]. Fn-guarded (Init_IcbmTel compiles it).
	//--- cmdcon42-j (Ray 2026-07-02): optional 7th element = a specific bought-SCUD platform hint (from the vehicle action).
	//--- The server re-validates it (ignored for NUKE; only honoured if an alive side platform) — never trusted blindly.
	case "icbm-tel-fire": {
		if (!isNil "WFBE_SE_FNC_IcbmTelFire") then {
			private ["_tSide","_tTarget","_tMuni","_tTeam","_tFee","_tPlat"];
			_tSide   = _args select 1;
			_tTarget = _args select 2;
			_tMuni   = _args select 3;
			_tTeam   = _args select 4;
			_tFee    = if (count _args > 5) then {_args select 5} else {0};
			_tPlat   = if (count _args > 6) then {_args select 6} else {objNull};
			[_tSide, _tTarget, _tMuni, _tTeam, _tFee, _tPlat] Spawn WFBE_SE_FNC_IcbmTelFire;
		} else {
			["WARNING", "Server_HandleSpecial.sqf: icbm-tel-fire received but WFBE_SE_FNC_IcbmTelFire is nil (WFBE_C_ICBM_TEL=0?)."] Call WFBE_CO_FNC_LogContent;
		};
	};
	//--- cmdcon42-j (Ray 2026-07-02): PRODUCIBLE SCUD (Takistan) registration. Payload: ["tk-scud-register", vehicle, side, team, paidCost].
	//--- Sent by the buyer's client (Client_BuildUnit) right after a SCUD is bought at the HF. Server-authoritative: enforces
	//--- the per-side live cap (deletes + refunds the exact paid amount on a surplus purchase), tags the hull, registers it.
	case "tk-scud-register": {
		if (!isNil "WFBE_SE_FNC_TkScudRegister") then {
			private ["_sVeh","_sSide","_sTeam","_sCost"];
			_sVeh  = _args select 1;
			_sSide = _args select 2;
			_sTeam = if (count _args > 3) then {_args select 3} else {grpNull};
			_sCost = if (count _args > 4) then {_args select 4} else {-1};
			[_sVeh, _sSide, _sTeam, _sCost] Call WFBE_SE_FNC_TkScudRegister;
		} else {
			["WARNING", "Server_HandleSpecial.sqf: tk-scud-register received but WFBE_SE_FNC_TkScudRegister is nil (WFBE_C_ICBM_TEL=0 / WFBE_C_TK_SCUD_HF=0?)."] Call WFBE_CO_FNC_LogContent;
		};
	};
	case "ICBM": {
		Private ["_base","_playerTeam","_side","_target"];

		_side = _args select 1;
		_base = _args select 2;
		_target = _args select 3;
		_playerTeam = _args select 4;

		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in an ICBM Nuke.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;

		if (isNull _target || !alive _target) exitWith {};

		waitUntil {!alive _target || isNull _target};

		[_base] Spawn NukeDammage;
	};

	//--- Marty (Trello #171): Server-side timed removal of the player-called artillery barrage markers.
	//--- The markers are created globally on the caller's client (WF_createMarker), but the deletion used
	//--- to be a client-local timed spawn that never ran if the caller disconnected, leaking the markers
	//--- on everyone else. The server owns the delayed delete so it survives the caller leaving.
	case "ArtyMarkerCleanup": {
		Private ["_markerNames","_removeDelay"];
		_markerNames = _args select 1;
		_removeDelay = _args select 2;
		if (typeName _markerNames != "ARRAY") exitWith {};
		[_markerNames, _removeDelay] spawn {
			Private ["_names","_delay"];
			_names = _this select 0;
			_delay = _this select 1;
			sleep _delay;
			{ if (typeName _x == "STRING") then { deleteMarker _x }; } forEach _names;
		};
	};

	//--- lane202: ArtySharedCooldown - stamp the side logic with the last-fire time and
	//--- broadcast to all clients (setVariable ..., true) so JIP / multi-player same-side
	//--- clients can read the real cooldown. Flag-gated: inert when WFBE_C_ARTY_SHARED_COOLDOWN is 0.
	case "ArtySharedCooldown": {
		//--- GUARD (lane202-review): a short/malformed PVF payload crashes at select 1/2.
		//--- Matches the group-query and guer-mortar-strike guard idiom already in this file.
		if (count _args < 3) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: ArtySharedCooldown received a short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		if ((missionNamespace getVariable ["WFBE_C_ARTY_SHARED_COOLDOWN", 0]) > 0) then {
			private ["_artyStampSide","_artyStampTime","_artyStampLogik"];
			_artyStampSide = _args select 1;
			_artyStampTime = _args select 2;
			_artyStampLogik = (_artyStampSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _artyStampLogik) then {
				//--- HIGH (lane202-review): never trust the client-supplied time; stamp server's own `time`
				//--- so a debug-console exploit cannot broadcast a far-future value and lock arty for the side.
				_artyStampLogik setVariable ["wfbe_arty_last_fire", time, true];
			};
		};
	};

	//--- N-FEATUREBUG-4: server-side artillery ammo load. addMagazineTurret/loadMagazine only take
	//--- effect where the vehicle is local; AI artillery is server-local, so the commanding player's
	//--- client forwards the load request here (see Common_LoadArtilleryAmmo.sqf locality gate). We
	//--- re-run the same loader on the server, where `local _arty` is true and the ops actually apply.
	case "LoadArtilleryAmmo": {
		Private ["_arty","_sideText","_artilleryIndex","_ammoIndex"];
		_arty = _args select 1;
		_sideText = _args select 2;
		_artilleryIndex = _args select 3;
		_ammoIndex = _args select 4;
		if (isNull _arty) exitWith {};
		if !(local _arty) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: LoadArtilleryAmmo arty [%1] is not server-local; load skipped.", _arty]] Call WFBE_CO_FNC_LogContent;
		};
		[_arty, _sideText, _artilleryIndex, _ammoIndex] Call WFBE_CO_FNC_LoadArtilleryAmmo;
	};
	case "process-killed-hq": {
		(_args select 1) Spawn WFBE_SE_FNC_OnHQKilled;
	};
	// Marty: Authoritative cleanup for dead player AI that can remain in the command bar on dedicated servers.
	case "commandbar-cleanup-dead-unit": {
		_args Spawn {
			Private ["_acceptedLogged","_alreadyDetachedLogged","_attempt","_requester","_requesterGroup","_successLogged","_unit","_warningLogged"];

			_requester = _this select 1;
			_unit = _this select 2;

			if (isNull _requester) exitWith {};
			if (isNull _unit) exitWith {};
			if (!alive _requester) exitWith {};
			if (alive _unit) exitWith {};
			if (isPlayer _unit) exitWith {};
			if (_unit in playableUnits) exitWith {};

			_requesterGroup = group _requester;
			if (isNull _requesterGroup) exitWith {};
			if (leader _requesterGroup != _requester) exitWith {};
			if ((group _unit) != _requesterGroup) exitWith {
				_alreadyDetachedLogged = _unit getVariable ["CommandBar_DeadUnits_ServerAlreadyDetachedLogged", false];
				if !(_alreadyDetachedLogged) then {
					_unit setVariable ["CommandBar_DeadUnits_ServerAlreadyDetachedLogged", true, false];
					["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_ALREADY_DETACHED requester:%1 unit:%2 unitGroup:%3 requesterGroup:%4 localUnit:%5 unitOwner:%6 requesterOwner:%7", name _requester, _unit, group _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
				};
				[_requester, "HandleSpecial", ["commandbar-force-dead-cleanup", _unit]] Call WFBE_CO_FNC_SendToClient;
			};

			if (_unit getVariable ["CommandBar_DeadUnits_ServerCleanupRunning", false]) exitWith {};
			_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRunning", true, false];
			_acceptedLogged = _unit getVariable ["CommandBar_DeadUnits_ServerAcceptedLogged", false];
			if !(_acceptedLogged) then {
				_unit setVariable ["CommandBar_DeadUnits_ServerAcceptedLogged", true, false];
				["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_ACCEPTED requester:%1 unit:%2 type:%3 unitGroup:%4 localUnit:%5 unitOwner:%6 requesterOwner:%7", name _requester, _unit, typeOf _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
			};

			for "_attempt" from 0 to 20 do {
				if (isNull _unit) exitWith {};
				if (alive _unit) exitWith {};
				if ((group _unit) != _requesterGroup) exitWith {};

				if (local _unit) then {
					if (WF_Debug) then {
						["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT SERVER_JOIN_ATTEMPT attempt:%1 requester:%2 unit:%3 localUnit:%4 unitOwner:%5", _attempt, name _requester, _unit, local _unit, owner _unit]] Call WFBE_CO_FNC_LogContent;
					};
					[_unit] joinSilent grpNull;
				} else {
					if !(WF_A2_Vanilla) then {_unit setOwner (owner _requester)};
					if ((_attempt mod 4) == 0) then {
						if (WF_Debug) then {
							["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT SERVER_TRANSFER_REQUEST attempt:%1 requester:%2 unit:%3 localUnit:%4 unitOwner:%5 requesterOwner:%6", _attempt, name _requester, _unit, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
						};
						[_requester, "HandleSpecial", ["commandbar-force-dead-cleanup", _unit]] Call WFBE_CO_FNC_SendToClient;
					};
				};

				sleep 0.25;
			};

			if (!isNull _unit) then {
				if (!alive _unit && (group _unit) != _requesterGroup) then {
					_successLogged = _unit getVariable ["CommandBar_DeadUnits_ServerSuccessLogged", false];
					if !(_successLogged) then {
						_unit setVariable ["CommandBar_DeadUnits_ServerSuccessLogged", true, false];
						["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_DETACHED requester:%1 unit:%2 finalGroup:%3 requesterGroup:%4 localUnit:%5 unitOwner:%6", name _requester, _unit, group _unit, _requesterGroup, local _unit, owner _unit]] Call WFBE_CO_FNC_LogContent;
					};
				};
				if (!alive _unit && (group _unit) == _requesterGroup) then {
					_warningLogged = _unit getVariable ["CommandBar_DeadUnits_ServerCleanupWarningLogged", false];
					if !(_warningLogged) then {
						_unit setVariable ["CommandBar_DeadUnits_ServerCleanupWarningLogged", true, false];
						["WARNING", Format ["COMMAND_BAR_DEAD_UNIT SERVER_STILL_STUCK requester:%1 unit:%2 requesterGroup:%3 localUnit:%4 unitOwner:%5 requesterOwner:%6", name _requester, _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};

			if (!isNull _unit) then {_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRunning", false, false]};
		};
	};
	case "aicom-team-created": {
		Private ["_csideID","_cteam","_clogik","_caicomList","_cdir","_cldr"];
		_csideID = _args select 1;
		_cteam = _args select 2;
		_clogik = ((_csideID) Call WFBE_CO_FNC_GetSideFromID) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _clogik) then {
			_clogik setVariable ["wfbe_aicom_pending", ((_clogik getVariable ["wfbe_aicom_pending", 1]) - 1) max 0];
			if ((_clogik getVariable ["wfbe_aicom_pending", 0]) <= 0) then {_clogik setVariable ["wfbe_aicom_pending_since", -1]};
			if (!isNull _cteam) then {
				_clogik setVariable ["wfbe_teams", (_clogik getVariable ["wfbe_teams", []]) + [_cteam], true];
				//--- Direction-arrow marker feed (mirrors WFBE_ACTIVE_PATROLS): register
				//--- [leader, sideID, dir, team] so every client can draw a side-coloured
				//--- mil_arrow2 at the commander team's leader. dir is patched later by the
				//--- aicom-team-heading case once the HC's heading loop reports a bearing.
				_cldr = leader _cteam;
				if (!isNull _cldr) then {
					_cdir = getDir _cldr;
					_caicomList = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
					missionNamespace setVariable ["WFBE_ACTIVE_AICOM_TEAMS", _caicomList + [[_cldr, _csideID, _cdir, _cteam]]];
					publicVariable "WFBE_ACTIVE_AICOM_TEAMS";
				};
				["INFORMATION", Format ["Server_HandleSpecial.sqf: [sideID %1] HC commander team %2 registered (%3 units).", _csideID, _cteam, count units _cteam]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
	case "aicom-focus": {
		//--- AICOM v2 M4: the human commander set a side FOCUS town from the command center ("Move All"
		//--- doubles as the AI focus). Stamp it on the side logic; the Allocator reads it (TTL'd) and makes
		//--- it the side's fist - honoured every tick. side validated west/east (the command menu is commander-only).
		private ["_fSide","_fTown","_fLogik"];
		_fSide = _args select 1;
		_fTown = _args select 2;
		if (!isNil "_fTown" && {!isNull _fTown} && {_fSide in [west, east]}) then {
			_fLogik = (_fSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _fLogik) then {
				_fLogik setVariable ["wfbe_aicom_focus", _fTown];
				_fLogik setVariable ["wfbe_aicom_focus_t0", time];
				diag_log ("AICOM2|v1|FOCUS|" + str _fSide + "|" + str (round (time / 60)) + "|set=" + (_fTown getVariable ["name", "?"]));
			};
		};
	};
	case "aicom-defend": {
		//--- COMMAND-CENTER INSTRUCTION PANEL (PR1): a player set a DEFEND town for the AI commander (modeled
		//--- EXACTLY on aicom-focus). Stamp it (+ a t0 timestamp) on the side logic; AI_Commander_Strategy.sqf
		//--- reads it (TTL'd by WFBE_C_AICOM_DEFEND_TTL) and biases a reliever team to that town. side validated west/east.
		private ["_dSide","_dTown","_dLogik"];
		_dSide = _args select 1;
		_dTown = _args select 2;
		if (!isNil "_dTown" && {!isNull _dTown} && {_dSide in [west, east]}) then {
			_dLogik = (_dSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _dLogik) then {
				_dLogik setVariable ["wfbe_aicom_defend_focus", _dTown];
				_dLogik setVariable ["wfbe_aicom_defend_focus_t0", time];
				diag_log ("AICOM2|v1|DEFEND|" + str _dSide + "|" + str (round (time / 60)) + "|set=" + (_dTown getVariable ["name", "?"]));
			};
		};
	};
	case "aicom-arty-here": {
		//--- COMMAND CONSOLE: a player called an ARTILLERY-HERE strike from the war room. We stamp a fresh [pos,time]
		//--- request on the side logic; the assist-mode resolver (AI_Com_PlayerArty, every supervisor tick) consumes it
		//--- fire-once - so it works even under a HUMAN commander, where the brain's own Strategy arty block is dormant.
		//--- PRODUCTION FIX (claude-gaming 2026-06-28): gate on the SEPARATE player-arty flag (WFBE_C_AICOM_PLAYER_ARTY),
		//--- NOT WFBE_C_AI_COMMANDER_ARTILLERY (which Steff hard-locks to 0 to keep the AI from using/building artillery).
		//--- The player request is serviced in assist-mode by AI_Com_PlayerArty and only ever fires friendly pieces that
		//--- already exist (it never builds guns), so it does not reopen the locked AI-autonomous-artillery behaviour.
		private ["_aSide","_aPos","_aLogik"];
		_aSide = _args select 1;
		_aPos  = _args select 2;
		if ((typeName _aPos == "ARRAY") && {_aSide in [west, east]} && {(missionNamespace getVariable ["WFBE_C_AICOM_PLAYER_ARTY", 0]) > 0}) then {
			_aLogik = (_aSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _aLogik) then {
				_aLogik setVariable ["wfbe_aicom_arty_request", [_aPos, time]];
				diag_log ("AICOM2|v1|ARTYREQ|" + str _aSide + "|" + str (round (time / 60)) + "|pos=" + str _aPos);
			};
		};
	};
	case "aicom-reinforce": {
		//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28): a player ordered the AI commander to REINFORCE one
		//--- of its OWN towns (modeled on aicom-defend, but offensive-leaning). Stamp [town,time] on the side logic; the
		//--- Allocator (AI_Commander_Allocate.sqf) reads it while fresh (WFBE_C_AICOM_REINFORCE_TTL) and routes ONE eligible
		//--- team into that town as part of the fist/expand set - additive, reversible, TTL-clears. AI-commander-run gate +
		//--- west/east validation; the reinforced town must currently be OURS (you reinforce what you hold).
		private ["_rSide","_rTown","_rLogik","_rCmd","_rHuman","_rRun","_rSID"];
		_rSide = _args select 1;
		_rTown = _args select 2;
		if (!isNil "_rTown" && {!isNull _rTown} && {_rSide in [west, east]}) then {
			_rLogik = (_rSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _rLogik) then {
				_rRun = false;
				if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0 && {alive ((_rSide) Call WFBE_CO_FNC_GetSideHQ)}) then {
					_rCmd = (_rSide) Call WFBE_CO_FNC_GetCommanderTeam; _rHuman = false;
					if (!isNull _rCmd) then {if (isPlayer (leader _rCmd)) then {_rHuman = true}};
					if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_rHuman = false};
					_rRun = !_rHuman;
				};
				_rSID = (_rSide) Call WFBE_CO_FNC_GetSideID;
				if (_rRun && {(_rTown getVariable ["sideID", -1]) == _rSID}) then {
					_rLogik setVariable ["wfbe_aicom_reinforce", [_rTown, time]];
					diag_log ("AICOM2|v1|ORDER|aicom-reinforce|" + str _rSide + "|" + str (round (time / 60)) + "|town=" + (_rTown getVariable ["name", "?"]));
				} else {
					diag_log ("AICOM2|v1|ORDER|aicom-reinforce|REJECT|" + str _rSide + "|run=" + str _rRun + "|ownsTown=" + str ((_rTown getVariable ["sideID", -1]) == _rSID));
				};
			};
		};
	};
	case "aicom-posture": {
		//--- COMMAND CONSOLE (PR backend): a player set a strategic POSTURE - "PUSH" (lean aggressive) or "HOLD" (lean
		//--- consolidate). Stamp the string + a t0 on the side logic; the brain reads it (TTL WFBE_C_AICOM_POSTURE_TTL) and
		//--- applies a SMALL bias only - it never hard-overrides the stance machine. AI-commander-run gate + west/east + a
		//--- string whitelist so a malformed arg cannot poison the read.
		private ["_pSide","_pPos","_pLogik","_pCmd","_pHuman","_pRun"];
		_pSide = _args select 1;
		_pPos  = _args select 2;
		if ((typeName _pPos == "STRING") && {(_pPos == "PUSH") || (_pPos == "HOLD")} && {_pSide in [west, east]}) then {
			_pLogik = (_pSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _pLogik) then {
				_pRun = false;
				if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0 && {alive ((_pSide) Call WFBE_CO_FNC_GetSideHQ)}) then {
					_pCmd = (_pSide) Call WFBE_CO_FNC_GetCommanderTeam; _pHuman = false;
					if (!isNull _pCmd) then {if (isPlayer (leader _pCmd)) then {_pHuman = true}};
					if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_pHuman = false};
					_pRun = !_pHuman;
				};
				if (_pRun) then {
					_pLogik setVariable ["wfbe_aicom_player_posture", _pPos];
					_pLogik setVariable ["wfbe_aicom_player_posture_t0", time];
					diag_log ("AICOM2|v1|ORDER|aicom-posture|" + str _pSide + "|" + str (round (time / 60)) + "|posture=" + _pPos);
				};
			};
		};
	};
	case "aicom-fieldorder": {
		//--- cmdcon27 THREAD C (COMMAND CONSOLE): a player set a FIELD ORDER - one of SPLIT / MASS / HARASS / FALLBACK.
		//--- One consolidated stamp (string + t0) on the side logic; the Allocator reads it ONCE per cycle, TTL
		//--- WFBE_C_AICOM_POSTURE_TTL (reused), and shifts its levers while fresh. Same AI-commander-run gate +
		//--- west/east + string whitelist as aicom-posture so a malformed arg cannot poison the read. Cloned from
		//--- "aicom-posture" above.
		private ["_pSide","_pPos","_pLogik","_pCmd","_pHuman","_pRun"];
		_pSide = _args select 1;
		_pPos  = _args select 2;
		if ((typeName _pPos == "STRING") && {_pPos in ["SPLIT","MASS","HARASS","FALLBACK"]} && {_pSide in [west, east]}) then {
			_pLogik = (_pSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _pLogik) then {
				_pRun = false;
				if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0 && {alive ((_pSide) Call WFBE_CO_FNC_GetSideHQ)}) then {
					_pCmd = (_pSide) Call WFBE_CO_FNC_GetCommanderTeam; _pHuman = false;
					if (!isNull _pCmd) then {if (isPlayer (leader _pCmd)) then {_pHuman = true}};
					if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_pHuman = false};
					_pRun = !_pHuman;
				};
				if (_pRun) then {
					_pLogik setVariable ["wfbe_aicom_player_fieldorder", _pPos];
					_pLogik setVariable ["wfbe_aicom_player_fieldorder_t0", time];
					diag_log ("AICOM2|v1|ORDER|aicom-fieldorder|" + str _pSide + "|" + str (round (time / 60)) + "|order=" + _pPos);
				};
			};
		};
	};
	case "aicom-team-disband": {
		//--- COMMAND CONSOLE (claude-gaming 2026-06-30, Ray): player-commander FAILSAFE - disband the side's AI field
		//--- teams. Unlike the posture/fieldorder NUDGES (which gate on !_pHuman = AI-runs), this is a DIRECT action FOR
		//--- the human commander, so it REQUIRES a human commander on the side. We only FLAG each team (wfbe_aicom_disband,
		//--- the proven retire path); the HC-local executor in Common_RunCommanderTeam.sqf deletes a team's units ONLY when
		//--- no player is within DISBAND_SAFE_DIST and it is not in COMBAT - so nothing vanishes in a player's view (honours
		//--- the no-vanish-in-view rule). A2-OA-safe: object getVariable [k,d] (side logic), group setVariable [k,v,true]
		//--- (no A3-only group getVariable [k,d]); count _args / typeName for the optional arg (no params / isEqualType).
		//--- Command Console v2 (claude-gaming 2026-07-01): OPTIONAL arg[2] = a team INDEX into this side's wfbe_teams. When
		//--- present + valid -> disband ONLY that team (a precision action; NO 15-min cooldown, and it does NOT stamp the
		//--- per-side cooldown clock). When ABSENT -> the original ALL-teams sweep (15-min per-side cooldown, unchanged).
		private ["_dSide","_dLogik","_dCmd","_dHuman","_dTeams","_dN","_dHasIdx","_dIdx"];
		_dSide = _args select 1;
		_dHasIdx = false; _dIdx = -1;
		if (count _args >= 3) then {
			private "_dRaw"; _dRaw = _args select 2;
			if (!isNil "_dRaw" && {typeName _dRaw == "SCALAR"}) then {_dHasIdx = true; _dIdx = _dRaw};
		};
		if (_dSide in [west, east]) then {
			_dLogik = (_dSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _dLogik) then {
				_dCmd = (_dSide) Call WFBE_CO_FNC_GetCommanderTeam; _dHuman = false;
				if (!isNull _dCmd) then {if (isPlayer (leader _dCmd)) then {_dHuman = true}};
				_dTeams = _dLogik getVariable ["wfbe_teams", []];
				if (_dHasIdx) then {
					//--- SPECIFIC-TEAM disband: human commander required, but no side cooldown (single, deliberate stand-down).
					if (_dHuman && {_dIdx >= 0} && {_dIdx < (count _dTeams)}) then {
						private "_dTeam"; _dTeam = _dTeams select _dIdx;
						if (!isNull _dTeam && {!isPlayer (leader _dTeam)}) then {
							_dTeam setVariable ["wfbe_aicom_disband", true, true];
							_dTeam setVariable ["wfbe_aicom_disband_cmd", true, true]; //--- Build84: explicit human console order -> bypass the player-proximity veto in the HC executor
							diag_log ("AICOM2|v1|ORDER|aicom-team-disband|" + str _dSide + "|" + str (round (time / 60)) + "|specific=" + str _dIdx + "|team=" + str _dTeam);
						} else {
							diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT-SPECIFIC|" + str _dSide + "|idx=" + str _dIdx + "|nullOrPlayer");
						};
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT-SPECIFIC|" + str _dSide + "|human=" + str _dHuman + "|idx=" + str _dIdx + "|teams=" + str (count _dTeams));
					};
				} else {
					//--- ALL-teams sweep (original behaviour): human commander + 15-min per-side cooldown.
					private ["_dLast","_dCool"];
					_dLast = _dLogik getVariable ["wfbe_aicom_last_disband", -1e10];
					_dCool = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_COOLDOWN", 900];
					if (_dHuman && {(time - _dLast) >= _dCool}) then {
						_dLogik setVariable ["wfbe_aicom_last_disband", time, true];
						_dN = 0;
						{ if (!isNull _x && {!isPlayer (leader _x)}) then {_x setVariable ["wfbe_aicom_disband", true, true]; _x setVariable ["wfbe_aicom_disband_cmd", true, true]; _dN = _dN + 1} } forEach _dTeams;
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|" + str _dSide + "|" + str (round (time / 60)) + "|flagged=" + str _dN + "|teams=" + str (count _dTeams));
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT|" + str _dSide + "|human=" + str _dHuman + "|cdLeft=" + str (_dCool - (time - _dLast)));
					};
				};
			};
		};
	};
	case "aicom-ai-command": {
		//--- COMMAND CONSOLE (claude-gaming 2026-06-29): the human commander toggled SQUAD-COMMAND MODE from the war
		//--- room - "ON" (delegate squad MANEUVER to the AI: it runs Strategy + AssignTowns UNDER the human while the
		//--- player keeps the economy) or "OFF" (today's DIRECT player control). Stamp a BROADCAST bool on the side
		//--- logic; AI_Commander.sqf reads it to widen the strategy gate (_aiStrategy = _canBuild || _aiDelegate) and
		//--- the war-room client reads it back to label the toggle. Default-ABSENT reads as direct-ON everywhere.
		//--- DELIBERATELY no human-commander gate: this flag's whole purpose is to change whether the AI strategy runs
		//--- UNDER a human commander. Modeled on aicom-posture: ENABLED + HQ-alive + west/east + string whitelist.
		private ["_dSide","_dVal","_dLogik"];
		_dSide = _args select 1;
		_dVal  = _args select 2;
		if ((typeName _dVal == "STRING") && {(_dVal == "ON") || (_dVal == "OFF")} && {_dSide in [west, east]}) then {
			if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0 && {alive ((_dSide) Call WFBE_CO_FNC_GetSideHQ)}) then {
				_dLogik = (_dSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _dLogik) then {
					_dLogik setVariable ["wfbe_aicom_player_delegate", (_dVal == "ON"), true];
					diag_log ("AICOM2|v1|ORDER|aicom-ai-command|" + str _dSide + "|" + str (round (time / 60)) + "|delegate=" + _dVal);
				};
			};
		};
	};
	case "aicom-request-unit": {
		//--- COMMAND CONSOLE (PR backend): a player asked the AI commander to favour a UNIT CLASS next time it founds a
		//--- team - "armor" / "air" / "infantry". Stamp [type,time]; AssignTypes + Teams nudge the next founding type pick
		//--- toward that class (a weight bias, NOT a hard force). Reuses the POSTURE TTL. AI-commander-run gate + west/east +
		//--- class whitelist.
		//--- PRODUCTION FIX (claude-gaming 2026-06-28): the client sends aicom-request-unit ONLY from the war room
		//--- (the player IS the commander). The old _uRun=!_uHuman gate rejected EXACTLY that case, so every Build
		//--- press was silently dropped (a root cause of ORDERS(war-room)=0). The consumer is SELF-PROTECTING and
		//--- reachable under a human commander: the HYBRID-REFILL team-founding worker (AI_Commander_Teams.sqf:467)
		//--- reads this [type,time] stamp TTL-gated (WFBE_C_AICOM_POSTURE_TTL) and applies only a SOFT weight bias,
		//--- so a player order can neither pin nor destabilise the brain. We therefore gate only on ENABLED + HQ-alive
		//--- + side + class whitelist - no human-commander gate. The TTL ages the stamp out on its own.
		private ["_uSide","_uType","_uLogik"];
		_uSide = _args select 1;
		_uType = _args select 2;
		if ((typeName _uType == "STRING") && {(_uType == "armor") || (_uType == "air") || (_uType == "infantry")} && {_uSide in [west, east]}) then {
			_uLogik = (_uSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _uLogik) then {
				if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0 && {alive ((_uSide) Call WFBE_CO_FNC_GetSideHQ)}) then {
					_uLogik setVariable ["wfbe_aicom_request_type", [_uType, time]];
					diag_log ("AICOM2|v1|ORDER|aicom-request-unit|" + str _uSide + "|" + str (round (time / 60)) + "|type=" + _uType);
				};
			};
		};
	};
	case "aicom-rally": {
		//--- cmdcon41-w3d COMMAND-MENU V2 (RALLY): the human commander ordered ONE team to pull back to the nearest own
		//--- HQ / OWN-side town centre. Client sends [side, teamIdx] (index into this side's wfbe_teams, resolved the SAME
		//--- way as aicom-team-disband). NEVER trust the client: require a HUMAN commander on the side, validate west/east,
		//--- and validate the team object (non-null, AI-led). We stamp the DIRECT order via the codebase-standard broadcast
		//--- setters (SetTeamMoveMode "move" + SetTeamMovePos rallyPos) so AI_Commander_Execute lays the road-aware
		//--- waypoints (server-local) or re-publishes wfbe_aicom_order (HC) every tick, exactly like the console's own
		//--- map-click Move. A short manualpin keeps AssignTowns off it until it arrives; the pin TTL-expires so it is
		//--- re-taskable afterwards (normal towns re-entry). Flag-gated (WFBE_C_CMD_MENU_V2).
		private ["_ryEnabled","_rySide","_ryIdx","_ryLogik","_ryCmd","_ryHuman","_ryTeams","_ryTeam","_ryHQ","_ryPos","_ryBest","_rySID"];
		_ryEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_rySide = _args select 1;
		_ryIdx  = -1;
		if (count _args >= 3) then {private "_ryRaw"; _ryRaw = _args select 2; if (!isNil "_ryRaw" && {typeName _ryRaw == "SCALAR"}) then {_ryIdx = _ryRaw}};
		if (_ryEnabled && {_rySide in [west, east]} && {_ryIdx >= 0}) then {
			_ryLogik = (_rySide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _ryLogik) then {
				_ryCmd = (_rySide) Call WFBE_CO_FNC_GetCommanderTeam; _ryHuman = false;
				if (!isNull _ryCmd) then {if (isPlayer (leader _ryCmd)) then {_ryHuman = true}};
				_ryTeams = _ryLogik getVariable ["wfbe_teams", []];
				if (_ryHuman && {_ryIdx < (count _ryTeams)}) then {
					_ryTeam = _ryTeams select _ryIdx;
					if (!isNull _ryTeam && {!isPlayer (leader _ryTeam)}) then {
						//--- Nearest own rally point: own HQ, else nearest OWN-side town centre (fall back to HQ).
						_rySID = (_rySide) Call WFBE_CO_FNC_GetSideID;
						_ryHQ  = (_rySide) Call WFBE_CO_FNC_GetSideHQ;
						_ryPos = if (!isNull _ryHQ) then {getPos _ryHQ} else {getPos (leader _ryTeam)};
						_ryBest = 1e12;
						{ if ((_x getVariable ["sideID", -1]) == _rySID) then {private "_d"; _d = (leader _ryTeam) distance _x; if (_d < _ryBest) then {_ryBest = _d; _ryPos = getPos _x}} } forEach towns;
						[_ryTeam, _ryPos]  Call SetTeamMovePos;
						[_ryTeam, "move"]  Call SetTeamMoveMode;
						[_ryTeam, false]   Call SetTeamAutonomous;
						_ryTeam setVariable ["wfbe_aicom_manualpin", time, true];
						diag_log ("AICOM2|v1|ORDER|aicom-rally|" + str _rySide + "|" + str (round (time / 60)) + "|idx=" + str _ryIdx + "|pos=" + str [round (_ryPos select 0), round (_ryPos select 1)]);
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-rally|REJECT|" + str _rySide + "|idx=" + str _ryIdx + "|nullOrPlayer");
					};
				} else {
					diag_log ("AICOM2|v1|ORDER|aicom-rally|REJECT|" + str _rySide + "|human=" + str _ryHuman + "|idx=" + str _ryIdx + "|teams=" + str (count _ryTeams));
				};
			};
		};
	};
	case "aicom-refit": {
		//--- cmdcon41-w3d COMMAND-MENU V2 (REFIT): the human commander requested a funds-charged infantry TOP-UP for ONE
		//--- team - the exact same consumer path Produce's auto top-up uses (wfbe_aicom_topup_req [count,pos,classes] on the
		//--- team; the owning HC/server driver spawns the bodies in Common_RunCommanderTeam). We mirror Produce's cost +
		//--- rate-limit gates: flat WFBE_C_AICOM_TOPUP_UNIT_COST per missing man toward 6 (cap 4), charged from the AI
		//--- commander treasury up front; one refit per team per WFBE_C_AICOM_TOPUP_COOLDOWN via the SAME wfbe_aicom_topup_stamp
		//--- Produce stamps. NEVER trust the client: human commander required, side + team validated, funds re-checked here.
		private ["_rfEnabled","_rfSide","_rfIdx","_rfLogik","_rfCmd","_rfHuman","_rfTeams","_rfTeam","_rfAlive","_rfNow","_rfLast","_rfCd","_rfMissing","_rfSText","_rfBarr","_rfCls","_rfCost","_rfCharge","_rfFunds"];
		_rfEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_rfSide = _args select 1;
		_rfIdx  = -1;
		if (count _args >= 3) then {private "_rfRaw"; _rfRaw = _args select 2; if (!isNil "_rfRaw" && {typeName _rfRaw == "SCALAR"}) then {_rfIdx = _rfRaw}};
		if (_rfEnabled && {_rfSide in [west, east]} && {_rfIdx >= 0}) then {
			_rfLogik = (_rfSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _rfLogik) then {
				_rfCmd = (_rfSide) Call WFBE_CO_FNC_GetCommanderTeam; _rfHuman = false;
				if (!isNull _rfCmd) then {if (isPlayer (leader _rfCmd)) then {_rfHuman = true}};
				_rfTeams = _rfLogik getVariable ["wfbe_teams", []];
				if (_rfHuman && {_rfIdx < (count _rfTeams)}) then {
					_rfTeam = _rfTeams select _rfIdx;
					if (!isNull _rfTeam && {!isPlayer (leader _rfTeam)}) then {
						_rfAlive = {alive _x} count (units _rfTeam);
						_rfNow   = time;
						_rfLast  = _rfTeam getVariable "wfbe_aicom_topup_stamp"; if (isNil "_rfLast") then {_rfLast = -1e9};
						_rfCd    = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_COOLDOWN", 240];
						if ((_rfNow - _rfLast) >= _rfCd) then {
							_rfMissing = (6 - _rfAlive) min 4;
							if (_rfMissing > 0) then {
								//--- Resolve up to 3 basic infantry classnames (same source + naming as Produce's rally top-up: str _side).
								_rfSText = str _rfSide;
								_rfBarr  = missionNamespace getVariable [Format ["WFBE_%1BARRACKSUNITS", _rfSText], []];
								_rfCls   = [];
								{ if ((count _rfCls) < 3 && {_x isKindOf "Man"}) then {_rfCls = _rfCls + [_x]} } forEach _rfBarr;
								if (count _rfCls > 0) then {
									_rfCost   = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_UNIT_COST", 300];
									_rfCharge = _rfCost * _rfMissing;
									_rfFunds  = (_rfSide) Call GetAICommanderFunds;
									if (_rfFunds >= _rfCharge) then {
										[_rfSide, -_rfCharge] Call ChangeAICommanderFunds;
										_rfTeam setVariable ["wfbe_aicom_topup_req", [_rfMissing, getPosATL (leader _rfTeam), _rfCls], true];
										_rfTeam setVariable ["wfbe_aicom_topup_stamp", _rfNow, false];
										diag_log ("AICOM2|v1|ORDER|aicom-refit|" + str _rfSide + "|" + str (round (time / 60)) + "|idx=" + str _rfIdx + "|missing=" + str _rfMissing + "|cost=" + str _rfCharge);
									} else {
										diag_log ("AICOM2|v1|ORDER|aicom-refit|REJECT|" + str _rfSide + "|idx=" + str _rfIdx + "|funds=" + str (round _rfFunds) + "|need=" + str _rfCharge);
									};
								};
							} else {
								diag_log ("AICOM2|v1|ORDER|aicom-refit|SKIP|" + str _rfSide + "|idx=" + str _rfIdx + "|fullstrength=" + str _rfAlive);
							};
						} else {
							diag_log ("AICOM2|v1|ORDER|aicom-refit|REJECT|" + str _rfSide + "|idx=" + str _rfIdx + "|cdLeft=" + str (round (_rfCd - (_rfNow - _rfLast))));
						};
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-refit|REJECT|" + str _rfSide + "|idx=" + str _rfIdx + "|nullOrPlayer");
					};
				} else {
					diag_log ("AICOM2|v1|ORDER|aicom-refit|REJECT|" + str _rfSide + "|human=" + str _rfHuman + "|idx=" + str _rfIdx + "|teams=" + str (count _rfTeams));
				};
			};
		};
	};
	case "aicom-hold": {
		//--- cmdcon41-w3d COMMAND-MENU V2 (HOLD): the human commander ordered ONE team to garrison the town it is IN /
		//--- nearest to. Client sends [side, teamIdx]. We resolve the nearest OWN-side town, stamp the SAME hold latch the
		//--- auto capture-hold uses (town var wfbe_aicom_hold_until = now+HOLD_SECS; team var wfbe_aicom_holding_town = the
		//--- town) so AssignTowns' holder-skip (AI_Commander_AssignTowns.sqf:253-263) leaves the team garrisoning it, plus
		//--- a "defense" order at the town centre via the broadcast setters (Execute HOLDs it). NEVER trust the client:
		//--- human commander required, side + team validated, and the held town must currently be OURS. Flag-gated.
		private ["_hdEnabled","_hdSide","_hdIdx","_hdLogik","_hdCmd","_hdHuman","_hdTeams","_hdTeam","_hdSID","_hdTown","_hdBest","_hdSecs"];
		_hdEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_hdSide = _args select 1;
		_hdIdx  = -1;
		if (count _args >= 3) then {private "_hdRaw"; _hdRaw = _args select 2; if (!isNil "_hdRaw" && {typeName _hdRaw == "SCALAR"}) then {_hdIdx = _hdRaw}};
		if (_hdEnabled && {_hdSide in [west, east]} && {_hdIdx >= 0}) then {
			_hdLogik = (_hdSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _hdLogik) then {
				_hdCmd = (_hdSide) Call WFBE_CO_FNC_GetCommanderTeam; _hdHuman = false;
				if (!isNull _hdCmd) then {if (isPlayer (leader _hdCmd)) then {_hdHuman = true}};
				_hdTeams = _hdLogik getVariable ["wfbe_teams", []];
				if (_hdHuman && {_hdIdx < (count _hdTeams)}) then {
					_hdTeam = _hdTeams select _hdIdx;
					if (!isNull _hdTeam && {!isPlayer (leader _hdTeam)}) then {
						_hdSID = (_hdSide) Call WFBE_CO_FNC_GetSideID;
						_hdTown = objNull; _hdBest = 1e12;
						{ if ((_x getVariable ["sideID", -1]) == _hdSID) then {private "_d"; _d = (leader _hdTeam) distance _x; if (_d < _hdBest) then {_hdBest = _d; _hdTown = _x}} } forEach towns;
						if (!isNull _hdTown) then {
							_hdSecs = missionNamespace getVariable ["WFBE_C_AICOM_HOLD_SECS", 180];
							_hdTown setVariable ["wfbe_aicom_hold_until", time + _hdSecs, true];
							[_hdTeam, "defense"]      Call SetTeamMoveMode;
							[_hdTeam, getPos _hdTown] Call SetTeamMovePos;
							[_hdTeam, false]          Call SetTeamAutonomous;
							_hdTeam setVariable ["wfbe_aicom_holding_town", _hdTown, true];
							_hdTeam setVariable ["wfbe_aicom_manualpin", time, true];
							diag_log ("AICOM2|v1|ORDER|aicom-hold|" + str _hdSide + "|" + str (round (time / 60)) + "|idx=" + str _hdIdx + "|town=" + (_hdTown getVariable ["name", "?"]));
						} else {
							diag_log ("AICOM2|v1|ORDER|aicom-hold|REJECT|" + str _hdSide + "|idx=" + str _hdIdx + "|noOwnTownNear");
						};
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-hold|REJECT|" + str _hdSide + "|idx=" + str _hdIdx + "|nullOrPlayer");
					};
				} else {
					diag_log ("AICOM2|v1|ORDER|aicom-hold|REJECT|" + str _hdSide + "|human=" + str _hdHuman + "|idx=" + str _hdIdx + "|teams=" + str (count _hdTeams));
				};
			};
		};
	};
	case "aicom-support": {
		//--- cmdcon41-w3d COMMAND-MENU V2 (REQUEST AI SUPPORT, non-commander): ANY player asks the nearest same-side AI
		//--- team to move to them. Client sends [side, player, playerPos]. We NEVER trust the client for identity beyond the
		//--- side membership check + a server-side proximity sanity check (the passed player must be alive, on the side, and
		//--- actually near the passed pos). Pick the nearest AI-led team NOT mid-capture/strike/rally and within
		//--- WFBE_C_CMD_NUDGE_RANGE, issue a road-aware DIRECT move via the broadcast setters (Execute road-routes it), and
		//--- leave it AUTONOMOUS + UNPINNED so AssignTowns re-tasks it normally after arrival (commander never overridden).
		//--- Per-player cooldown WFBE_C_CMD_NUDGE_COOLDOWN keyed by player UID on the side logic. Flag-gated.
		private ["_spEnabled","_spSide","_spPlayer","_spPos","_spLogik","_spNow","_spCd","_spUID","_spKey","_spLast","_spBest","_spTeam","_spTeams","_spRange"];
		_spEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		if (_spEnabled && {count _args >= 4}) then {
			_spSide   = _args select 1;
			_spPlayer = _args select 2;
			_spPos    = _args select 3;
			if (_spSide in [west, east] && {!isNil "_spPlayer"} && {!isNull _spPlayer} && {alive _spPlayer} && {side (group _spPlayer) == _spSide} && {typeName _spPos == "ARRAY"} && {count _spPos >= 2} && {(_spPlayer distance _spPos) < 200}) then {
				_spLogik = (_spSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _spLogik) then {
					_spNow = time;
					_spCd  = missionNamespace getVariable ["WFBE_C_CMD_NUDGE_COOLDOWN", 180];
					_spUID = getPlayerUID _spPlayer; if (isNil "_spUID" || {_spUID == ""}) then {_spUID = str _spPlayer};
					_spKey = "wfbe_cmd_nudge_" + _spUID;
					_spLast = _spLogik getVariable [_spKey, -1e9];
					if ((_spNow - _spLast) >= _spCd) then {
						_spRange = missionNamespace getVariable ["WFBE_C_CMD_NUDGE_RANGE", 1500];
						_spTeams = _spLogik getVariable ["wfbe_teams", []];
						_spBest  = _spRange; _spTeam = objNull;
						{
							if (!isNull _x && {!isPlayer (leader _x)}) then {
								private "_alv"; _alv = {alive _x} count (units _x);
								if (_alv > 0) then {
									//--- skip teams mid-capture/strike, rallying, or on an active hold latch (leave the AI's own
									//--- priorities alone). A team on a strike mission is "capturing"; there is no separate
									//--- capturing flag in this build. A2-OA: plain single-arg getVariable on the GROUP + isNil.
									private ["_busy","_str","_ral","_hld"];
									_str = _x getVariable "wfbe_aicom_strike"; _busy = (!isNil "_str" && {_str});
									if (!_busy) then {_ral = _x getVariable "wfbe_aicom_rallying"; _busy = (!isNil "_ral" && {_ral})};
									if (!_busy) then {_hld = _x getVariable "wfbe_aicom_holding_town"; _busy = (!isNil "_hld" && {!isNull _hld})};
									if (!_busy) then {
										private "_d"; _d = _spPos distance (getPos (leader _x));
										if (_d < _spBest) then {_spBest = _d; _spTeam = _x};
									};
								};
							};
						} forEach _spTeams;
						if (!isNull _spTeam) then {
							[_spTeam, _spPos] Call SetTeamMovePos;
							[_spTeam, "move"] Call SetTeamMoveMode;
							[_spTeam, true]   Call SetTeamAutonomous;                 //--- stay autonomous: AssignTowns re-tasks it after arrival (commander not overridden)
							_spTeam setVariable ["wfbe_aicom_manualpin", nil, true];  //--- no manual pin -> normal towns re-entry
							_spLogik setVariable [_spKey, _spNow, false];
							diag_log ("AICOM2|v1|ORDER|CMD_NUDGE|" + str _spSide + "|" + str (round (time / 60)) + "|uid=" + str _spUID + "|dist=" + str (round _spBest));
						} else {
							diag_log ("AICOM2|v1|ORDER|CMD_NUDGE|NONE|" + str _spSide + "|uid=" + str _spUID + "|noTeamInRange=" + str _spRange);
						};
					} else {
						diag_log ("AICOM2|v1|ORDER|CMD_NUDGE|REJECT|" + str _spSide + "|uid=" + str _spUID + "|cdLeft=" + str (round (_spCd - (_spNow - _spLast))));
					};
				};
			};
		};
	};
	//--- NOTE (claude-gaming 2026-06-28): the orphaned "aicom-donate" HandleSpecial case was REMOVED here. It had no
	//--- client sender (the command console does not host donate) and carried the same inverted run-gate the other
	//--- handlers had. The CANONICAL, live donate-to-AI-commander path is the RequestAIComDonate.sqf PVF, driven by
	//--- the Transfer menu (GUI_TransferMenu.sqf) - it shares the same "aicom-donate-confirm" client confirm. Donating
	//--- to the AI treasury only makes sense while the AI runs the side, which that path already enforces.
	case "aicom-team-ended": {
		Private ["_csideID","_cteam","_clogik","_caicomList","_caicomNew"];
		_csideID = _args select 1;
		_cteam = _args select 2;
		//--- Drop this team's arrow-marker entry (match slot 3 == team) and any null leftovers,
		//--- then re-broadcast so every client deletes the marker. Mirrors sidepatrol-ended.
		_caicomList = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
		_caicomNew = [];
		{
			if (!isNull (_x select 0) && {(_x select 3) != _cteam}) then {_caicomNew = _caicomNew + [_x]};
		} forEach _caicomList;
		missionNamespace setVariable ["WFBE_ACTIVE_AICOM_TEAMS", _caicomNew];
		publicVariable "WFBE_ACTIVE_AICOM_TEAMS";
		_clogik = ((_csideID) Call WFBE_CO_FNC_GetSideFromID) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _clogik) then {
			if (isNull _cteam) then {
				//--- Creation failed before registration: just release the pending slot.
				_clogik setVariable ["wfbe_aicom_pending", ((_clogik getVariable ["wfbe_aicom_pending", 1]) - 1) max 0];
				if ((_clogik getVariable ["wfbe_aicom_pending", 0]) <= 0) then {_clogik setVariable ["wfbe_aicom_pending_since", -1]};
			} else {
				_clogik setVariable ["wfbe_teams", (_clogik getVariable ["wfbe_teams", []]) - [_cteam], true];
				//--- GROUP-CAP LEAK FIX (claude-gaming 2026-06-13): founded + W8 Motor Pool teams carry
				//--- wfbe_persistent=true so the GC will not reap them during the empty-while-FILLING window.
				//--- But on team-END (wiped) the group was only DEREGISTERED, never deleted - leaving a
				//--- permanent empty GC-EXEMPT husk that accumulates toward the 144/side cap on every team
				//--- death (the dominant unbounded group leak). Now that the team is ended, clear the flag so
				//--- the existing 60s server_groupsGC reaps the empty husk (locality-safe; avoids the A2 trap
				//--- of `local` on a Group). Gameplay-transparent: the team already has zero living units.
				if ((count units _cteam) == 0) then {_cteam setVariable ["wfbe_persistent", false]};
				if ((_clogik getVariable ["wfbe_aicom_garrison", grpNull]) == _cteam) then {
					_clogik setVariable ["wfbe_aicom_garrison", grpNull];
				};
				["INFORMATION", Format ["Server_HandleSpecial.sqf: [sideID %1] HC commander team %2 wiped and deregistered.", _csideID, _cteam]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
	//--- Patch a commander team's arrow heading. The HC's heading loop (Common_RunCommanderTeam.sqf)
	//--- pushes [team, dir] whenever its objective bearing changes; we update the entry's slot 2 and
	//--- only re-broadcast WFBE_ACTIVE_AICOM_TEAMS when the arrow actually moved >7 deg (cuts PV spam).
	case "aicom-team-heading": {
		Private ["_hteam","_hdir","_haicomList","_hentry","_hold","_hdelta","_hchanged","_hi","_hldr"]; //--- B66 +_hldr
		_hteam = (_args select 1) select 0;
		_hdir  = (_args select 1) select 1;
		if (!isNull _hteam) then {
			_haicomList = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
			_hchanged = false;
			_hldr = leader _hteam;
			_hteam setVariable ["wfbe_aicom_last_heading_t", time, false];
			if (!isNull _hldr) then {_hteam setVariable ["wfbe_aicom_last_heading_owner", owner _hldr, false]};
			for "_hi" from 0 to (count _haicomList - 1) do {
				_hentry = _haicomList select _hi;
				if ((_hentry select 3) == _hteam) then {
					//--- B66: ARROW-VANISH FIX. slot0 (leader) was captured ONCE at aicom-team-created and
					//--- never refreshed; when the original leader died (team still alive) the client keyed
					//--- liveness/position on a dead/null unit and dropped the arrow. Re-resolve the CURRENT
					//--- leader from the live team (slot3) and write it back whenever it changed, so a leader
					//--- swap keeps the arrow alive.
					if (!isNull _hldr && {(_hentry select 0) != _hldr}) then {
						_hentry set [0, _hldr];
						_haicomList set [_hi, _hentry];
						_hchanged = true;
					};
					_hold = _hentry select 2;
					//--- Smallest signed angle between old and new heading (handles 0/360 wrap).
					_hdelta = abs (((_hdir - _hold) + 180) % 360 - 180);
					if (_hdelta > 7) then {
						_hentry set [2, _hdir];
						_haicomList set [_hi, _hentry];
						_hchanged = true;
					};
				};
			};
			if (_hchanged) then {
				missionNamespace setVariable ["WFBE_ACTIVE_AICOM_TEAMS", _haicomList];
				publicVariable "WFBE_ACTIVE_AICOM_TEAMS";
			};
		};
	};
	//--- HUSK-COLLECTOR (tasks #16/#2): a commander team abandoned a hull (truck-abandon
	//--- at rally, or an immobile vehicle). Enroll it with the empty-vehicle collector so
	//--- the existing delete timer reaps it. ENROLL UNCONDITIONALLY for any alive hull:
	//--- do NOT gate on crew==0 — the HC-local dismount races this server read, so a
	//--- crew==0 gate would let a still-replicating hull slip through and leak. WFBE_SE_FNC_
	//--- HandleEmptyVehicle is crew-safe (its delete timer only advances while crew is 0),
	//--- so enrolling a still-replicating hull is safe and self-corrects.
	case "aicom-vehicle-abandoned": {
		Private ["_avVeh","_avList"];
		_avVeh = _args select 1;
		//--- BUG FIX (claude-gaming 2026-06-14): the empty-vehicle collector (Server\FSM\
		//--- emptyvehiclescollector.sqf) iterates the WF_Logic "emptyVehicles" PRODUCER list, NOT the
		//--- emptyQueu de-dupe SET. This handler previously appended only to emptyQueu and spawned the
		//--- handler inline, so the collector loop never saw the hull and the abandoned-hull enrollment
		//--- never actually went through the collector. Retarget to enroll into "emptyVehicles" exactly
		//--- like every other producer (Client_BuildUnit.sqf:314-315); the collector then owns dedupe
		//--- (emptyQueu), the WFBE_SE_FNC_HandleEmptyVehicle spawn, and removal from the list - keeping
		//--- the crew-safe delete timer authoritative and avoiding a double-spawn. The emptyQueu guard
		//--- still skips a hull already in flight from a previous enrollment.
		_avList = WF_Logic getVariable "emptyVehicles";
		if (isNil "_avList") then {_avList = []};
		if (!isNull _avVeh && {alive _avVeh} && {!(_avVeh in _avList)} && {!(_avVeh in emptyQueu)}) then {
			WF_Logic setVariable ["emptyVehicles", _avList + [_avVeh], true];
			["INFORMATION", Format ["Server_HandleSpecial.sqf: aicom-vehicle-abandoned enrolled hull [%1] type [%2] into empty-collector.", _avVeh, typeOf _avVeh]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	//--- HELI FLY-OFF REFUND (user request): a commander team's empty AIR transport flew off
	//--- the map edge ALIVE and was deleted by Common_RunCommanderTeam.sqf. Refund its build
	//--- cost to that side's server-authoritative AI-commander treasury. Server-routed so the
	//--- treasury write is authoritative; mirrors AI_Commander_Wildcard salvage payback
	//--- ([_side, _wkTotal] Call ChangeAICommanderFunds, L726).
	case "aicom-heli-refunded": {
		Private ["_rSideID","_rSide","_rCost"];
		_rSideID = _args select 1;
		_rCost   = _args select 2;
		_rSide   = (_rSideID) Call WFBE_CO_FNC_GetSideFromID;
		//--- _rSide is a Side (not an Object) so isNull is the wrong test and throws; validate it is a real combatant treasury side instead.
		if ((_rSide in [east,west,resistance]) && {_rCost > 0}) then {
			[_rSide, _rCost] Call ChangeAICommanderFunds;
			["INFORMATION", Format ["Server_HandleSpecial.sqf: aicom-heli-refunded $%1 to [%2] AI-commander treasury (transport flew off-map).", _rCost, str _rSide]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	case "sidepatrol-started": {
		Private ["_psideID","_punit","_plist"];
		_psideID = _args select 1;
		_punit = _args select 2;
		if (!isNull _punit) then {
			_plist = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];
			missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _plist + [[_punit, _psideID]]];
			publicVariable "WFBE_ACTIVE_PATROLS";
		};
	};
	case "sidepatrol-ended": {
		Private ["_psideID","_punit","_plogik","_plist","_pnew"];
		_psideID = _args select 1;
		_punit = _args select 2;
		_plogik = ((_psideID) Call WFBE_CO_FNC_GetSideFromID) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _plogik) then {
			//--- Release the slot and re-arm the spawn cooldown.
			_plogik setVariable ["wfbe_side_patrols", ((_plogik getVariable ["wfbe_side_patrols", 1]) - 1) max 0];
			_plogik setVariable ["wfbe_side_patrol_last", time];
		};
		_plist = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];
		_pnew = [];
		{
			//--- Drop the ended patrol's entry and any null leftovers while we're here.
			if (!isNull (_x select 0) && {(_x select 0) != _punit}) then {_pnew = _pnew + [_x]};
		} forEach _plist;
		missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _pnew];
		publicVariable "WFBE_ACTIVE_PATROLS";
	};
	//--- Task 41: convoy reached a town — pay the owning side.
	case "sidepatrol-convoy-stop": {
		Private ["_cSideID","_cTown","_cSide","_cPool","_cShare","_cCount"];
		_cSideID = _args select 1;
		_cTown   = _args select 2;
		_cSide   = (_cSideID) Call WFBE_CO_FNC_GetSideFromID;
		_cPool   = if (isNil "WFBE_C_PATROL_CONVOY_PAY") then {750} else {WFBE_C_PATROL_CONVOY_PAY};

		_cCount = 0;
		{if ((isPlayer _x) && (alive _x) && (side _x == _cSide)) then {_cCount = _cCount + 1}} forEach playableUnits;
		_cShare = round (_cPool / (_cCount max 1));

		[_cSide, "BankPayout", [_cShare]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] convoy payout $%2 x %3 players at [%4].", str _cSide, _cShare, _cCount, if (!isNull _cTown) then {_cTown getVariable ["name","?"]} else {"?"}]] Call WFBE_CO_FNC_LogContent;
	};
	//--- HC SEATING TELEMETRY (task #34): pure RPT logging, no gameplay effect. Mirrors the HCSIDE|v1|connect
	//--- line below so "did an HC land on WEST this boot, and did the script reseat fix it" is directly
	//--- observable on the server RPT instead of inferred. _args select 1 is a 2/3-element sub-array packed
	//--- by Init_HC.sqf (same shape as update-town-delegation / aicom-team-heading pack their payloads).
	case "hc-preseat": {
		Private ["_pName","_engineSide"];
		_pName = (_args select 1) select 0;
		_engineSide = (_args select 1) select 1;
		diag_log (Format ["HCSIDE|v1|preseat|name=%1|engineSide=%2", _pName, _engineSide]);
	};
	case "hc-reseat-result": {
		Private ["_rName","_rResult","_rSideNow"];
		_rName = (_args select 1) select 0;
		_rResult = (_args select 1) select 1;
		_rSideNow = (_args select 1) select 2;
		diag_log (Format ["HCSIDE|v1|reseat|name=%1|result=%2|sideNow=%3", _rName, _rResult, _rSideNow]);
	};
	case "connected-hc": {
		// Marty: Spawned so the cold-start retry doesn't block the PVF dispatcher.
		_args Spawn {
			Private ["_hc","_id","_retries","_sideRetries","_uid","_hcOwnerKey","_hcGroup","_hcOld","_hcOldUid","_hcList","_hcValid"];
			_hc = _this select 1;
			_uid = getPlayerUID _hc;

			["INFORMATION", Format["Server_HandleSpecial.sqf: Headless client is now connected [%1] [%2] with Owner ID [%3] (pre-retry).", _hc, _uid, owner _hc]] Call WFBE_CO_FNC_LogContent;

			//--- HC cold-start slot-race: the engine owner ID may be 0 for a brief window
			//--- after the PVF fires. Retry up to 60 times (60 s total) before giving up.
			_retries = 0;
			waitUntil {sleep 1; _retries = _retries + 1; (isNull _hc) || (owner _hc != 0) || (_retries >= 60)};

			//--- Re-read the owner ID after the wait; the pre-spawn value is stale.
			if (isNull _hc) exitWith {
				["WARNING", "Server_HandleSpecial.sqf: Headless client object went null before registration could resolve owner."] Call WFBE_CO_FNC_LogContent;
			};
			_id = owner _hc;

			["INFORMATION", Format["Server_HandleSpecial.sqf: Headless client [%1] [%2] Owner ID after retry [%3] (retries:%4).", _hc, _uid, _id, _retries]] Call WFBE_CO_FNC_LogContent;
			if (_id == 0) exitWith {
				diag_log (Format ["HCSIDE|v1|connect-failed|uid=%1|owner=0|side=%2|retries=%3", _uid, str (side group _hc), _retries]);
				["WARNING", Format["Server_HandleSpecial.sqf: Headless client [%1] Owner ID is still [0] after %2 retries; waiting for the HC reannounce.", _hc, _retries]] Call WFBE_CO_FNC_LogContent;
			};

			//--- The HC sends connected-hc after reseat, but group membership can replicate to the server late.
			//--- Never register a WEST/EAST magnet group as a live HC endpoint; wait for CIV or let a later
			//--- reannounce try again.
			_sideRetries = 0;
			waitUntil {sleep 1; _sideRetries = _sideRetries + 1; (isNull _hc) || (side group _hc == civilian) || (_sideRetries >= 30)};
			if (isNull _hc) exitWith {
				["WARNING", "Server_HandleSpecial.sqf: Headless client object went null before CIV reseat replicated."] Call WFBE_CO_FNC_LogContent;
			};
			if (side group _hc != civilian) exitWith {
				diag_log (Format ["HCSIDE|v1|connect-deferred|uid=%1|owner=%2|side=%3|sideRetries=%4", _uid, _id, str (side group _hc), _sideRetries]);
				["WARNING", Format["Server_HandleSpecial.sqf: Headless client [%1] owner [%2] is still on [%3] after CIV wait; registration deferred until reannounce.", _hc, _id, str (side group _hc)]] Call WFBE_CO_FNC_LogContent;
			};

			diag_log (Format ["HCSIDE|v1|connect|uid=%1|owner=%2|side=%3|ownerRetries=%4|sideRetries=%5", _uid, _id, str (side group _hc), _retries, _sideRetries]); //--- diagnostic: did reseat converge before registry capture?

			//--- Registry hygiene: an HC re-registers after every reconnect/reseat, and the old append-only
			//--- list kept dead groups forever - delegation could then pick a corpse and the town AI silently
			//--- vanished. Key by owner, not UID: A2 HCs can report an empty/shared UID, while owner is the
			//--- actual publicVariableClient routing key used by Common_SendToClient.sqf.
			_hcOwnerKey = Format["WFBE_HEADLESS_OWNER_%1", _id];
			_hcGroup = group _hc;
			_hcList = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
			_hcOld = missionNamespace getVariable _hcOwnerKey;
			if (!isNil "_hcOld") then {_hcList = _hcList - [_hcOld]};
			if (_uid != "") then {
				_hcOldUid = missionNamespace getVariable Format["WFBE_HEADLESS_%1", _uid];
				if (!isNil "_hcOldUid") then {_hcList = _hcList - [_hcOldUid]};
			};

			_hcValid = [];
			{
				if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {owner (leader _x) != _id}) then {
					if (!(_x in _hcValid)) then {_hcValid = _hcValid + [_x]};
				};
			} forEach _hcList;
			if (count _hcValid != count _hcList) then {
				["INFORMATION", Format["Server_HandleSpecial.sqf: Pruned [%1] stale/duplicate headless client entries from the registry.", (count _hcList) - (count _hcValid)]] Call WFBE_CO_FNC_LogContent;
			};
			if (!(_hcGroup in _hcValid)) then {_hcValid = _hcValid + [_hcGroup]};

			//--- Add the Headless client to our candidates.
			missionNamespace setVariable [_hcOwnerKey, _hcGroup];
			if (_uid != "") then {missionNamespace setVariable [Format["WFBE_HEADLESS_%1", _uid], _hcGroup]};
			missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", _hcValid];
			[_uid, _id, _hcGroup] spawn {
				Private ["_uid","_ownerID","_hcGroup","_side","_sideText","_logik","_teams","_g","_ldr","_ldrOwner","_last","_age","_hcTeams","_live","_newOwnerLive","_headingFresh","_headingStale","_headingUnknown"];
				_uid = _this select 0;
				_ownerID = _this select 1;
				_hcGroup = _this select 2;
				sleep 5;
				{
					_side = _x;
					_sideText = str _side;
					_hcTeams = 0; _live = 0; _newOwnerLive = 0; _headingFresh = 0; _headingStale = 0; _headingUnknown = 0;
					_logik = _side Call WFBE_CO_FNC_GetSideLogic;
					if (!isNull _logik && {!(isNil {_logik getVariable "wfbe_teams"})}) then {
						_teams = _logik getVariable "wfbe_teams";
						{
							_g = _x;
							if (!isNull _g) then {
								if ([_g, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
									_hcTeams = _hcTeams + 1;
									_ldr = leader _g;
									if (!isNull _ldr && {alive _ldr}) then {
										_live = _live + 1;
										_ldrOwner = owner _ldr;
										if (_ldrOwner == _ownerID) then {_newOwnerLive = _newOwnerLive + 1};
									};
									if (isNil {_g getVariable "wfbe_aicom_last_heading_t"}) then {
										_headingUnknown = _headingUnknown + 1;
									} else {
										_last = _g getVariable "wfbe_aicom_last_heading_t";
										_age = time - _last;
										if (_age <= 30) then {_headingFresh = _headingFresh + 1} else {_headingStale = _headingStale + 1};
									};
								};
							};
						} forEach _teams;
					};
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HCRECON_AICOM_AUDIT|uid=" + _uid + "|owner=" + str _ownerID + "|group=" + str _hcGroup + "|teams=" + str _hcTeams + "|live=" + str _live + "|newOwnerLive=" + str _newOwnerLive + "|headingFresh=" + str _headingFresh + "|headingStale=" + str _headingStale + "|headingUnknown=" + str _headingUnknown);
				} forEach [west, east];
			};

			//--- b763 (Ray 2026-06-26): PRUNE the HC's boot-orphaned magnet slot-team from each player side's
			//--- wfbe_teams. The engine seat-magnets an HC onto a synchronized WEST/EAST playable slot BEFORE
			//--- Init_Server's team loop, which stamps that slot-group into wfbe_teams (~L743); the connect-resolver
			//--- then resolves the HC as a player-team and the roster-push lists it in the commander vote (an HC
			//--- body returns isPlayer==true). Init_HC reseats the HC out to a civilian group but nothing removes
			//--- the vacated slot-group -> it lingers in the vote roster / tally. Race-free: this runs in the
			//--- connected-hc handler (post owner-retry), discriminating by the HC BODY _hc, the slot's
			//--- wfbe_uid==this HC's UID, or the HC-local wfbe_hc_magnet marker set before reseat. A real player
			//--- team is NEVER matched (its leader is a live human != _hc, and an emptied real team carries the
			//--- PLAYER's wfbe_uid, not the HC's). A2-OA-safe: GetSideLogic OBJECT, plain group getVariable
			//--- (no [name,default] on a group), forEach, ==, typeName.
			{
				private ["_sd","_slog","_st","_keep","_lead","_drop","_us","_magnet"];
				_sd = _x;
				_slog = _sd Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _slog && {!isNil {_slog getVariable "wfbe_teams"}}) then {
					_st = _slog getVariable "wfbe_teams";
					if (typeName _st == "ARRAY") then {
						_keep = [];
						{
							_lead = leader _x;
							_drop = false;
							if (!isNull _lead && {_lead == _hc}) then {_drop = true};
							if (isNull _lead && {_uid != ""}) then {_us = _x getVariable "wfbe_uid"; if (!isNil "_us" && {_us == _uid}) then {_drop = true}};
							_magnet = false;
							if !(isNil {_x getVariable "wfbe_hc_magnet"}) then {_magnet = _x getVariable "wfbe_hc_magnet"};
							if (_magnet && {isNull _lead || {_lead == _hc} || {!isPlayer _lead}}) then {_drop = true};
							if (!_drop) then {_keep = _keep + [_x]};
						} forEach _st;
						if (count _keep != count _st) then {
							_slog setVariable ["wfbe_teams", _keep, true];
							_slog setVariable ["wfbe_teams_count", count _keep];
							diag_log (Format ["HCSIDE|v1|teamprune|uid=%1|side=%2|removed=%3", _uid, str _sd, (count _st) - (count _keep)]);
						};
					};
				};
			} forEach [west, east];
		};
	};
	case "track-playerobject": {
		Private ["_get","_object","_uid"];
		_uid = _args select 1;
		_object = _args select 2;

		_get = missionNamespace getVariable Format ["WFBE_CLIENT_%1_OBJECTS", _uid];

		if (isNil '_get') then {
			missionNamespace setVariable [Format ["WFBE_CLIENT_%1_OBJECTS", _uid], [_object]];
		} else {
			_get = _get - [objNull] + [_object];
			missionNamespace setVariable [Format ["WFBE_CLIENT_%1_OBJECTS", _uid], _get];
		};
	};
	case "repair-camp": {
		Private ["_camp_sideID","_logic","_repairSideID","_townModel"];
		_logic = _args select 1;
		_repairSideID = _args select 2;

		if (alive (_logic getVariable 'wfbe_camp_bunker')) exitWith {};

		_townModel = (missionNamespace getVariable "WFBE_C_CAMP") createVehicle (getPos _logic);
		_townModel setDir ((getDir _logic) + (missionNamespace getVariable "WFBE_C_CAMP_RDIR"));
		_townModel setPos (getPos _logic);
			/*--- wiki-wins: removed killed EH calling undefined WFBE_SE_FNC_OnBuildingKilled (threw a swallowed error on every bunker death); bunker dead-state is already polled via alive (_logic getVariable 'wfbe_camp_bunker') ---*/
		_townModel addEventHandler ["handleDamage",{getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))}];
		_logic setVariable ["wfbe_camp_bunker", _townModel, true];

		//--- Do we have to update the camp SID ?
		_camp_sideID = _logic getVariable "sideID";
		if (_camp_sideID != _repairSideID) then {
			Private ["_town"];
			_logic setVariable ["sideID", _repairSideID, true];

				//--- wiki-wins: also fly the new side's flag (mirrors Server_SetCampsToSide.sqf:22); the side change set sideID but never the world flag texture.
				(_logic getVariable "wfbe_flag") setFlagTexture (missionNamespace getVariable Format["WFBE_%1FLAG", (_repairSideID) Call WFBE_CO_FNC_GetSideFromID]); (_logic getVariable "wfbe_flag") setVehicleInit (Format ["this setFlagTexture '%1'", missionNamespace getVariable Format["WFBE_%1FLAG", (_repairSideID) Call WFBE_CO_FNC_GetSideFromID]]); processInitCommands; //--- qol-polish-pack: JIP-safe flag (bake into object init so late joiners replay it)

			//--- Notify / update map if needed.
			[nil, "CampCaptured", [_logic, _repairSideID, _camp_sideID, true]] Call WFBE_CO_FNC_SendToClients;
		};
	};

	//--- GUER PLAYER VBIED manual detonation (Feature B player-side, Ray 2026-06-16). The GUER player driver
	//--- requested detonation (the client already did the confirm + arm countdown). Mirror the AI wildcard W21
	//--- blast EXACTLY: setDamage 1 on the truck + 3x stacked "Sh_122_HE" at its pos (122mm HE, the only HE round
	//--- confirmed loaded on BOTH maps via the artillery configs - never Sh_125_HE/Bo_GBU12). CASH-FOR-KILLS
	//--- (Ray's intent): snapshot the living WEST/EAST units in lethal radius BEFORE the blast, then after the HE
	//--- resolves, credit the driver's GUER team funds for each one the blast killed = unit price x
	//--- WFBE_C_GUER_KILL_BOUNTY_COEF, the SAME formula + WFBE_CO_FNC_ChangeTeamFunds path as the RequestOnUnitKilled
	//--- GUER kill-bounty block (the blast shells have no instigator, so RequestOnUnitKilled never double-pays).
	//--- Gate-guarded; the client only sends this for a GUER VBIED driver, so gate-OFF is a byte-for-byte no-op.
	case "guer-vbied-detonate": {
		Private ["_veh","_driver"];
		_veh = _args select 1;
		_driver = _args select 2;
		if (!isNull _veh && {alive _veh} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0} && {driver _veh == _driver} && {side _driver == resistance} && {(typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])) || (typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"]))}) then {  //--- B75: accept either VBIED type (hilux/datsun truck OR the kill-gated M113 APC).
			[_veh, _driver] spawn {
				Private ["_veh","_driver","_drvGrp","_drvUID","_p","_radius","_coef","_victims","_payout","_get","_persBounty","_persScore","_get2","_cand","_structVictims","_sStructs","_struct","_facBounty","_facScore","_fobIdx","_fobAvail"];
				_veh = _this select 0;
				_driver = _this select 1;
				_drvGrp = group _driver;   //--- capture before the blast: the suicide driver dies in it.
				//--- B67 (guer-reward): also pay the DETONATOR personally (cash bounty + score) alongside the
				//--- team payout below. Capture the driver object + its UID NOW, while still alive, because the
				//--- suicide driver is gone by the time we settle (getPlayerUID on a dead/deleted unit is unreliable).
				_drvUID = getPlayerUID _driver;
				_p = getPosATL _veh;
				_radius = missionNamespace getVariable ["WFBE_C_GUER_VBIED_BLAST_RADIUS", 30];
				_coef = missionNamespace getVariable ["WFBE_C_GUER_KILL_BOUNTY_COEF", 0.5];
				//--- C5 (over-pay bound): snapshot only living enemy WEST/EAST MAN-class targets in lethal radius.
				//--- The old snapshot also captured LandVehicle/Air/Ship hulls, so any vehicle that died for ANY
				//--- reason during the 4s settle window (or an already-wreck/empty hull) paid the driver's team -
				//--- a large over-pay. Crediting infantry kills only keeps the cash-for-kills bounded + blast-caused.
				_victims = [];
				//--- B74.1 (Ray 2026-06-23): pay for ANY kill, not just infantry ("grant money whenever something is
				//--- killed"). Snapshot living enemy MEN + CREWED vehicles in the (now FAB-250-sized) radius; crewed/alive
				//--- only so empty wrecks never pay (keeps the C5 over-pay bound). _cand captures the outer _x because the
				//--- crew-count below rebinds _x.
				{
					_cand = _x;
					if (alive _cand && {(side _cand == east) || (side _cand == west)}) then {
						if (_cand isKindOf "Man") then {
							_victims = _victims + [_cand];
						} else {
							if (({alive _x} count (crew _cand)) > 0) then {_victims = _victims + [_cand]};
						};
					};
				} forEach (nearestObjects [_p, ["Man","LandVehicle","Air"], _radius]);
				//--- B75 (guer-reward): also snapshot living ENEMY (WEST/EAST) base structures (factories/barracks/etc.)
				//--- in the blast radius, taken from each enemy side logic's authoritative wfbe_structures list. After the
				//--- blast settles we pay the detonator the SAME per-type bounty + score a normal building kill grants
				//--- (Server_BuildingKilled.sqf). PROXIMITY is required: the FAB-250 blast carries NO instigator, so the
				//--- structure's own "killed" EH fires with a null killer and pays nothing - and the suicide driver is dead
				//--- by settle time, so we must capture the credit here (folded into the death-proof personal payout below).
				_structVictims = [];
				{
					_sStructs = (_x Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_structures";   //--- _x = enemy side; plain getVariable (logic may be a Group - no [name,default] form).
					if (!isNil "_sStructs") then {
						{
							if (!isNull _x && {alive _x} && {(_x distance _p) <= _radius}) then {_structVictims = _structVictims + [_x]};   //--- _x = structure here (inner forEach rebinds it).
						} forEach _sStructs;
					};
				} forEach [west, east];
				//--- BLAST (AI W21 idiom): pop the truck, then stack 3x 122mm HE for a large lethal crater.
				_veh setDamage 1;
				//--- B74.1 (Ray 2026-06-23): 3x Sh_122_HE -> 3x Bo_FAB_250 (the FAB-250 aerial bomb the EASA plane
				//--- loadouts already carry, so it is loaded on both maps). Far bigger crater than the 122mm shell.
				"Bo_FAB_250" createVehicle _p;
				"Bo_FAB_250" createVehicle _p;
				"Bo_FAB_250" createVehicle _p;
				//--- let the HE resolve kills, then pay the GUER driver's team for each victim the blast killed.
				sleep 4;
				//--- B67 (guer-reward): accumulate the detonator's PERSONAL bounty + score per dead enemy Man
				//--- victim, mirroring the RequestOnUnitKilled personal path (AwardBounty.sqf Man formula):
				//---   bounty = round(unitprice * 0.7 * WFBE_C_UNITS_BOUNTY_COEF), score = ceil(bounty / 100).
				//--- Only Man victims count toward the personal reward (the snapshot is already Man-only).
				_persBounty = 0;
				_persScore = 0;
				if (!isNull _drvGrp) then {
					_payout = 0;
					{
						if (!alive _x) then {
							_get = missionNamespace getVariable (typeOf _x);
							if (!isNil "_get") then {_payout = _payout + round ((_get select QUERYUNITPRICE) * _coef)};
							//--- B67: personal detonator reward (Man-class only victims).
							if (!isNull _x) then {  //--- Ray 2026-06-27 DEFINITIVE GUER VBIED reward: was isKindOf "Man" -> now also pay the detonator WALLET for crewed-VEHICLE kills (VBIEDing a convoy paid the wallet nothing). _get2 reads the vehicle/unit config price.
								_get2 = missionNamespace getVariable (typeOf _x);
								if (!isNil "_get2") then {
									private ["_b"];
									_b = round ((_get2 select QUERYUNITPRICE) * 0.7 * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF"));
									_persBounty = _persBounty + _b;
									_persScore = _persScore + (ceil (_b / 100));
								};
							};
						};
					} forEach _victims;
					if (_payout > 0) then {
						false; //--- Ray 2026-06-27: team-funds path DISABLED (paid group _driver captured PRE-suicide; never reaches the respawned base-less GUER detonator). Wallet/UID path below is the single channel. was: [_drvGrp, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
						["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER VBIED cash-for-kills paid [%1] to [%2] (%3 targets in radius).", _payout, _drvGrp, count _victims]] Call WFBE_CO_FNC_LogContent;
					};
				};
				//--- B75 (guer-reward): FACTORY/STRUCTURE kill credit. Any enemy base structure that was alive in the
				//--- blast radius before detonation and is now dead was levelled by THIS VBIED. Credit the detonator the
				//--- SAME per-type bounty + score a normal building kill grants (mirror Server_BuildingKilled.sqf), folded
				//--- into _persBounty/_persScore so it rides the death-proof payout below (cash by UID, score on driver).
				{
					_struct = _x;
					if (isNull _struct || {!alive _struct}) then {
						_facBounty = switch (true) do {
							case (_struct isKindOf "Base_WarfareBBarracks"):{3000};
							case (_struct isKindOf "Base_WarfareBLightFactory"):{4500};
							case (_struct isKindOf "Base_WarfareBHeavyFactory"):{7000};
							case (_struct isKindOf "Base_WarfareBAircraftFactory"):{8000};
							case (_struct isKindOf "Base_WarfareBUAVterminal"):{5000};
							case (_struct isKindOf "Base_WarfareBVehicleServicePoint"):{3000};
							case (_struct isKindOf "BASE_WarfareBAntiAirRadar"):{8000};
							default {3000};
						};
						//--- score mirrors Server_BuildingKilled.sqf: bounty * WFBE_C_UNITS_BOUNTY_COEF / 100, then x3.
						_facScore = (_facBounty * (missionNamespace getVariable ["WFBE_C_UNITS_BOUNTY_COEF", 1]) / 100) * 3;
						_persBounty = _persBounty + _facBounty;
						_persScore = _persScore + _facScore;
						//--- leaderboard FACTORY-kill credit (same structure set Server_BuildingKilled.sqf records) to the detonator UID.
						if (((_struct isKindOf "Base_WarfareBLightFactory") || (_struct isKindOf "Base_WarfareBHeavyFactory") || (_struct isKindOf "Base_WarfareBAircraftFactory") || (_struct isKindOf "Base_WarfareBBarracks")) && {_drvUID != ""}) then {
							[_drvUID, WFBE_STAT_KILLS_FACTORY, 1] Call WFBE_SE_FNC_RecordStat;
						};
						//--- B75 (guer-tech FOB): PATH B. A VBIED-levelled enemy Barracks/Light/Heavy also grants a GUER FOB
						//--- build token of that type. The owning side is guaranteed WEST/EAST (the snapshot iterated only
						//--- [west,east] logics) and the destroyer is guaranteed resistance (case guard), so no side gate is
						//--- needed. The null-instigator blast never reaches Server_BuildingKilled's resistance gate, so this
						//--- is the ONLY place a VBIED factory kill is credited toward FOB availability (no double count).
						_fobIdx = -1;
						if (_struct isKindOf "Base_WarfareBBarracks") then {_fobIdx = 0};
						if (_struct isKindOf "Base_WarfareBLightFactory") then {_fobIdx = 1};
						if (_struct isKindOf "Base_WarfareBHeavyFactory") then {_fobIdx = 2};
						if (_fobIdx >= 0) then {
							_fobAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
							_fobAvail set [_fobIdx, (_fobAvail select _fobIdx) + 1];
							missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _fobAvail];
							publicVariable "WFBE_GUER_FOB_AVAIL";
							["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER FOB token granted via VBIED (enemy %1 destroyed). Avail now [B %2 | LF %3 | HF %4].", typeOf _struct, _fobAvail select 0, _fobAvail select 1, _fobAvail select 2]] Call WFBE_CO_FNC_LogContent;
						};
					};
				} forEach _structVictims;
				//--- B67: pay the detonator personally (cash to their wallet via the new client receiver, dispatched
				//--- to the captured UID) + apply the accumulated score to the captured driver object if still valid.
				diag_log ("GUERVBIED|v1|drvUID=" + (str _drvUID) + "|victims=" + (str (count _victims)) + "|payout=" + (str _payout) + "|persBounty=" + (str _persBounty) + "|persScore=" + (str _persScore)); //--- Ray 2026-06-27: definitive trace of a GUER VBIED payout (always-on).
					if (_drvUID != "" && {_persBounty > 0}) then {
					[_drvUID, "GuerVbiedBounty", _persBounty] Call WFBE_CO_FNC_SendToClients;
					["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER VBIED personal bounty [%1] + score [%2] paid to detonator UID [%3].", _persBounty, _persScore, _drvUID]] Call WFBE_CO_FNC_LogContent;
				};
				if (!isNull _driver && {_persScore > 0}) then {
					if (isServer) then {
						['SRVFNCREQUESTCHANGESCORE',[_driver, (score _driver) + _persScore]] Spawn WFBE_SE_FNC_HandlePVF;
					} else {
						["RequestChangeScore", [_driver, (score _driver) + _persScore]] Call WFBE_CO_FNC_SendToServer;
					};
				};
			};
		};
	};

	//--- GUER PLAYER MORTAR STRIKE (improvised indirect fire). A GUER player driving a V3S_Gue designated an impact
	//--- point on the map (Action_GuerMortarStrike.sqf already validated driver-only + within-range on the client);
	//--- here the SERVER spawns a small scripted 82mm-HE barrage at that position. We reuse the SAME scripted-ordnance
	//--- building block the VBIED case above proved out (createVehicle of a vanilla HE round at a position), just
	//--- spread over a few shells with a small spread + short inter-shell delay so it reads as a barrage rather than a
	//--- single blast. Sh_82_HE is the 82mm mortar HE round the mission's own GUER/INS artillery configs already load
	//--- on BOTH maps (Common\Config\Core_Artillery\Artillery_*GUE*.sqf), so it is guaranteed present. Server-side, so
	//--- kill credit + createVehicle damage behave normally. Gate-guarded; the client only sends this for a resistance
	//--- V3S_Gue driver, so gate-OFF is a byte-for-byte no-op.
	case "guer-mortar-strike": {
		Private ["_pos","_player","_team","_cost","_funds"];
		//--- GUARD (claude-gaming): mirror the group-query guard - a short payload (count _args <= 2) used to
		//--- crash at "_player = _args select 2". The valid sender is a 3-arg ["guer-mortar-strike",_pos,_player];
		//--- bail safely on anything shorter rather than select-crash.
		if (count _args < 3) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: guer-mortar-strike received a short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		_pos    = _args select 1;
		_player = _args select 2;
		if ((typeName _pos == "ARRAY") && {!isNull _player} && {side _player == resistance} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {
			//--- COST: debit the GUER player's team funds before firing. The funds-holding team is `group _player`
			//--- (the SAME team the VBIED case pays via WFBE_CO_FNC_ChangeTeamFunds). If the team cannot afford the
			//--- call-in fee we DON'T fire, DON'T let the cooldown burn (the client optimistically stamped it before
			//--- sending), and tell the player why via the guer-mortar-result client receiver.
			_team = group _player;
			_cost = missionNamespace getVariable ["WFBE_C_GUER_MORTAR_COST", 200];
			_funds = _team Call WFBE_CO_FNC_GetTeamFunds;
			if (isNull _team || {_funds < _cost}) exitWith {
				//--- Refund cooldown + notify the caller (dual path: object send on non-vanilla, UID send on vanilla).
				if (WF_A2_Vanilla) then {
					[getPlayerUID _player, "HandleSpecial", ["guer-mortar-result", [false, Format ["Mortar strike needs $%1 - the cell is broke.", _cost]]]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[_player, "HandleSpecial", ["guer-mortar-result", [false, Format ["Mortar strike needs $%1 - the cell is broke.", _cost]]]] Call WFBE_CO_FNC_SendToClient;
				};
				["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER mortar strike DENIED (insufficient funds) for [%1] team [%2] (have %3, need %4).", name _player, _team, _funds, _cost]] Call WFBE_CO_FNC_LogContent;
			};
			//--- Affordable: debit now (negative delta = spend), then fire.
			[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;

			//--- INCOMING WARNING (counter-play + atmosphere): drop a cheap GLOBAL "Incoming" marker at the impact
			//--- point so EVERYONE (incl. the targeted enemy) gets a fair chance to scatter. Plain createMarker on the
			//--- server replicates to all clients (incl. JIP). A server-side timed spawn deletes it after a few seconds
			//--- (mirrors the ArtyMarkerCleanup case), so it survives the caller disconnecting and never leaks.
			Private ["_mname"];
			_mname = Format ["wfbe_guermortar_%1", round (diag_tickTime * 1000)];
			createMarker [_mname, _pos];
			_mname setMarkerType "mil_destroy";
			_mname setMarkerColor "ColorRed";
			_mname setMarkerText "Incoming";
			_mname setMarkerSize [1, 1];
			[_mname] spawn {
				Private ["_m"];
				_m = _this select 0;
				sleep 12;
				deleteMarker _m;
			};

			//--- BARRAGE: walk the shells in over a few seconds. Tier-scaled spread tightens the grouping as the GUER
			//--- faction levels up (its WFBE_GUER_VEHICLE_TIER). Each shell is created at a +/-_spread 2D offset, then
			//--- lifted 120m ABOVE GROUND at that offset (setPosATL z is above-terrain) so it falls correctly onto the
			//--- actual terrain instead of a flat sea-level Z (which mis-impacts on hills). Sh_82_HE is the GUER 82mm
			//--- mortar HE round loaded on both maps. Server-side, so kill credit + createVehicle damage behave normally.
			[_pos, _team] spawn {
				Private ["_pos","_team","_shells","_tier","_spread","_radius","_coef","_i","_off2d","_sp","_victims","_cand","_payout","_get"];
				_pos = _this select 0;
				_team = _this select 1;
				_shells = missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SHELLS", 6];
				if (_shells < 1) then {_shells = 1};
				//--- TIER-SCALED SPREAD: base spread minus tier*step, floored at the minimum.
				_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
				if (_tier < 0) then {_tier = 0};
				_spread = (missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SPREAD", 25]) - (_tier * (missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SPREAD_TIERSTEP", 4]));
				if (_spread < (missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SPREAD_MIN", 8])) then {_spread = missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SPREAD_MIN", 8]};

				//--- KILL CREDIT (mirror the VBIED cash-for-kills): snapshot living enemy WEST/EAST Men + crewed
				//--- vehicles within the impact radius BEFORE the barrage, then after it resolves pay the GUER team
				//--- unitprice * WFBE_C_GUER_KILL_BOUNTY_COEF for each one now dead. Same WFBE_CO_FNC_ChangeTeamFunds
				//--- path + bounty coef the VBIED case uses; the shells carry no instigator so RequestOnUnitKilled
				//--- never double-pays. _cand captures the outer _x because the crew-count test below rebinds _x.
				_radius = _spread + 30;   //--- lethal snapshot a bit wider than the shell grouping (HE splash).
				_coef = missionNamespace getVariable ["WFBE_C_GUER_KILL_BOUNTY_COEF", 0.5];
				_victims = [];
				{
					_cand = _x;
					if (alive _cand && {(side _cand == east) || (side _cand == west)}) then {
						if (_cand isKindOf "Man") then {
							_victims = _victims + [_cand];
						} else {
							if (({alive _x} count (crew _cand)) > 0) then {_victims = _victims + [_cand]};
						};
					};
				} forEach (nearestObjects [_pos, ["Man","LandVehicle","Air"], _radius]);

				for "_i" from 1 to _shells do {
					_off2d = [(_pos select 0) + (-_spread + random (2 * _spread)), (_pos select 1) + (-_spread + random (2 * _spread))];
					_sp = "Sh_82_HE" createVehicle _off2d;
					_sp setPosATL [(_off2d select 0), (_off2d select 1), 120];   //--- 120m ABOVE GROUND so it falls onto terrain.
					sleep (0.4 + random 0.6);
				};

				//--- settle, then pay the GUER team for each snapshot victim the barrage killed.
				sleep 4;
				if (!isNull _team) then {
					_payout = 0;
					{
						if (!alive _x) then {
							_get = missionNamespace getVariable (typeOf _x);
							if (!isNil "_get") then {_payout = _payout + round ((_get select QUERYUNITPRICE) * _coef)};
						};
					} forEach _victims;
					if (_payout > 0) then {
						[_team, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
						["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER mortar cash-for-kills paid [%1] to [%2] (%3 targets snapshotted).", _payout, _team, count _victims]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
			["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER mortar strike called by [%1] at %2 (%3 shells, cost %4).", name _player, _pos, missionNamespace getVariable ["WFBE_C_GUER_MORTAR_SHELLS", 6], _cost]] Call WFBE_CO_FNC_LogContent;
		};
	};
};
