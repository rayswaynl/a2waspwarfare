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
			for "_hi" from 0 to (count _haicomList - 1) do {
				_hentry = _haicomList select _hi;
				if ((_hentry select 3) == _hteam) then {
					//--- B66: ARROW-VANISH FIX. slot0 (leader) was captured ONCE at aicom-team-created and
					//--- never refreshed; when the original leader died (team still alive) the client keyed
					//--- liveness/position on a dead/null unit and dropped the arrow. Re-resolve the CURRENT
					//--- leader from the live team (slot3) and write it back whenever it changed, so a leader
					//--- swap keeps the arrow alive.
					_hldr = leader _hteam;
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
		// Marty: Spawned so the 3-second cold-start retry doesn't block the PVF dispatcher.
		_args Spawn {
			Private ["_hc","_id","_retries","_uid","_hcOld","_hcList","_hcValid"];
			_hc = _this select 1;
			_uid = getPlayerUID _hc;

			["INFORMATION", Format["Server_HandleSpecial.sqf: Headless client is now connected [%1] [%2] with Owner ID [%3] (pre-retry).", _hc, _uid, owner _hc]] Call WFBE_CO_FNC_LogContent;

			//--- HC cold-start slot-race: the engine owner ID may be 0 for a brief window
			//--- after the PVF fires. Retry up to 3 times (3 s total) before giving up.
			_retries = 0;
			waitUntil {sleep 1; _retries = _retries + 1; (owner _hc != 0) || (_retries >= 3)};

			//--- Re-read the owner ID after the wait; the pre-spawn value is stale.
			_id = owner _hc;

			["INFORMATION", Format["Server_HandleSpecial.sqf: Headless client [%1] [%2] Owner ID after retry [%3] (retries:%4).", _hc, _uid, _id, _retries]] Call WFBE_CO_FNC_LogContent;
			diag_log (Format ["HCSIDE|v1|connect|uid=%1|owner=%2|side=%3", _uid, _id, str (side _hc)]); //--- diagnostic: is the HC actually mis-seated (WEST) or already CIV (cosmetic BLUFOR)?

			if (_id != 0) then {
				//--- Registry hygiene: an HC re-registers after every reconnect, and the old append-only
				//--- list kept dead groups forever - delegation could then pick a corpse and the town AI
				//--- silently vanished. Drop this UID's previous group and prune any dead entries.
				_hcList = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
				_hcOld = missionNamespace getVariable Format["WFBE_HEADLESS_%1", _uid];
				if (!isNil "_hcOld") then {_hcList = _hcList - [_hcOld]};
				_hcValid = [];
				{
					if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_hcValid = _hcValid + [_x]};
				} forEach _hcList;
				if (count _hcValid != count _hcList) then {
					["INFORMATION", Format["Server_HandleSpecial.sqf: Pruned [%1] dead headless client entries from the registry.", (count _hcList) - (count _hcValid)]] Call WFBE_CO_FNC_LogContent;
				};
				//--- Add the Headless client to our candidates.
				missionNamespace setVariable [Format["WFBE_HEADLESS_%1", _uid], group _hc];
				missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", _hcValid + [group _hc]];
			} else {
				["WARNING", Format["Server_HandleSpecial.sqf: Headless client [%1] Owner ID is still [0] after %2 retries, it is server controlled.",_hc, _retries]] Call WFBE_CO_FNC_LogContent;
			};
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
				(_logic getVariable "wfbe_flag") setFlagTexture (missionNamespace getVariable Format["WFBE_%1FLAG", (_repairSideID) Call WFBE_CO_FNC_GetSideFromID]);

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
		if (!isNull _veh && {alive _veh} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0} && {driver _veh == _driver} && {side _driver == resistance} && {typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])}) then {
			[_veh, _driver] spawn {
				Private ["_veh","_driver","_drvGrp","_drvUID","_p","_radius","_coef","_victims","_payout","_get","_persBounty","_persScore","_get2","_cand"];
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
							if ((typeOf _x) isKindOf "Man") then {
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
						[_drvGrp, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
						["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER VBIED cash-for-kills paid [%1] to [%2] (%3 targets in radius).", _payout, _drvGrp, count _victims]] Call WFBE_CO_FNC_LogContent;
					};
				};
				//--- B67: pay the detonator personally (cash to their wallet via the new client receiver, dispatched
				//--- to the captured UID) + apply the accumulated score to the captured driver object if still valid.
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
};
