Private['_args'];

_args = _this;

switch (_args select 0) do {
	case "update-teamleader": {
		Private ["_leader","_team","_side"];
		_team = _args select 1;
		_leader = _args select 2;
		_side = civilian;

		//--- SG-forge (mission-core-squad-membership r41): RequestSpecial is an UNAUTHENTICATED command
		//--- bus (RequestSpecial.sqf:3,20-21 - the same threat model the repair-camp guard closes), so a
		//--- forged ["RequestSpecial",["update-teamleader", <anyGroup>, <anyUnit>]] would otherwise stamp
		//--- ANY team's stored leader to an ARBITRARY unit. The disconnect handler consumes that stamp
		//--- (Server_OnPlayerDisconnected.sqf:175) and, when the stamped unit sits in another group,
		//--- joinSilent's it into the team, selectLeader's it, ejects it from its vehicle/HQ and
		//--- deleteVehicle's it (:198-244) - a remote forced-regroup + unit-delete grief on any player.
		//--- Authorise the write: the reported leader must be a real PLAYER member of the reported team
		//--- (both legit senders pass `player` + their own WFBE_Client_Team, where player is always in
		//--- units of its own group). A rejected forge leaves wfbe_teamleader unchanged, so the disconnect
		//--- handler falls back to the live `leader _team` (:183) - always safe.
		if (!isNull _team && {isPlayer _leader} && {_leader in units _team}) then {
			_team setVariable ["wfbe_teamleader", _leader];
		} else {
			["WARNING", Format ["Server_HandleSpecial.sqf: rejected update-teamleader - leader [%1] not a player-member of team [%2] (forged/stale RequestSpecial).", _leader, _team]] Call WFBE_CO_FNC_LogContent;
		};

		//--- TEAMBAR server probe (card wasp-player-group-rank-order-diagnosis-20260718): the client
		//--- pings this at init + every respawn. Round-2 review PHASE NOTE: this observation is
		//--- taken when the ping ARRIVES - i.e. BEFORE the client's slot1-rejoin dance has
		//--- necessarily run - so it is phase-stamped pre-client-rejoin and correlates with the
		//--- client-side rejoin-check/rejoin-done lines by uid + t, never read as post-state alone.
		if ((missionNamespace getVariable ["WFBE_C_TEAMBAR_PROBE", 0]) > 0) then {
			if (!isNull _team && {!isNull _leader}) then {
				diag_log Format ["TEAMBAR|v2|SVPROBE|evt=update-teamleader|phase=pre-client-rejoin|t=%1|uid=%2|groupId=%3|leaderIsPlayer=%4|leaderIsGrpLeader=%5|leaderRankId=%6|units=%7",
					round time, getPlayerUID _leader, str _team, isPlayer _leader, (leader _team == _leader), rank _leader, count (units _team)];
			};
		};

		//--- C1 lease reclaim (WFBE_C_CMD_LEASE): a respawning/JIP-reconnecting client always pings
		//--- update-teamleader (Init_Client / Client_OnKilled). Round-3 review (P1-1/P1-2): this
		//--- receiver no longer mutates lease state itself - it only ENQUEUES a reclaim request; the
		//--- single per-side executor re-validates UID+group+eligibility fresh at processing time and
		//--- is the sole writer, closing the "writer publish and lease grant remain separate
		//--- statements" and "reclaim can interleave with the stand-down executor" races. The executor
		//--- path deliberately does not touch per-team autonomous/respawn state either: during grace
		//--- the teams were never freed, so there is nothing to re-lock - a blanket
		//--- SetTeamAutonomous/SetTeamRespawn here would wipe the commander's own per-team choices on
		//--- reconnect (the same blanket-reset anti-pattern C5 removed from AI_Commander).
		if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
			_side = _team getVariable "wfbe_side";
			if (!isNil "_side" && {_side != civilian} && {isPlayer _leader}) then {
				[_side, getPlayerUID _leader, _team] Call WFBE_CO_FNC_CommanderLeaseRequestReclaim;
			};
		};
	};
	case "Paratroops": {
		//--- supportgate SECURITY (2026-07-24): server-authoritative cost + rate gate.
		//--- Flag WFBE_C_SUPPORT_SERVER_AUTH (default 0): at 0 unconditional spawn (client debit is sole fee).
		//--- failure-signalling r38: when AUTH is armed and Authorize returns false, notify the caller
		//--- (previously silent deny after client stamped lastParaCall / may have already debited).
		Private ["_authOk","_callerTeam","_callerLead","_denyMsg"];
		_authOk = true;
		if ((missionNamespace getVariable ["WFBE_C_SUPPORT_SERVER_AUTH", 0]) > 0) then {
			_authOk = ["Paratroops", _args, 8500, missionNamespace getVariable ["WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY", 1200]] Call WFBE_SE_FNC_AuthorizeSupportCallin;
			if (!_authOk) then {
				_callerTeam = if (count _args > 3) then {_args select 3} else {grpNull};
				_callerLead = if (!isNull _callerTeam) then {leader _callerTeam} else {objNull};
				_denyMsg = "Paratroop call denied by server (funds or cooldown). No charge was taken server-side.";
				if (!isNull _callerLead && {isPlayer _callerLead}) then {
					if (WF_A2_Vanilla) then {
						[getPlayerUID _callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClients;
					} else {
						[_callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClient;
					};
				};
			};
		};
		if (_authOk) then {_args spawn KAT_Paratroopers};
	};


case "ParaVehi": {
		//--- supportgate SECURITY + failure-signalling r38 deny notify (see Paratroops case).
		Private ["_authOk","_callerTeam","_callerLead","_denyMsg"];
		_authOk = true;
		if ((missionNamespace getVariable ["WFBE_C_SUPPORT_SERVER_AUTH", 0]) > 0) then {
			_authOk = ["ParaVehi", _args, 3500, 600] Call WFBE_SE_FNC_AuthorizeSupportCallin;
			if (!_authOk) then {
				_callerTeam = if (count _args > 3) then {_args select 3} else {grpNull};
				_callerLead = if (!isNull _callerTeam) then {leader _callerTeam} else {objNull};
				_denyMsg = "Vehicle paradrop denied by server (funds or cooldown). No charge was taken server-side.";
				if (!isNull _callerLead && {isPlayer _callerLead}) then {
					if (WF_A2_Vanilla) then {
						[getPlayerUID _callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClients;
					} else {
						[_callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClient;
					};
				};
			};
		};
		if (_authOk) then {_args spawn KAT_ParaVehicles};
	};


case "ParaAmmo": {
		//--- supportgate SECURITY + failure-signalling r38 deny notify (see Paratroops case).
		Private ["_authOk","_callerTeam","_callerLead","_denyMsg"];
		_authOk = true;
		if ((missionNamespace getVariable ["WFBE_C_SUPPORT_SERVER_AUTH", 0]) > 0) then {
			_authOk = ["ParaAmmo", _args, 9500, 800] Call WFBE_SE_FNC_AuthorizeSupportCallin;
			if (!_authOk) then {
				_callerTeam = if (count _args > 3) then {_args select 3} else {grpNull};
				_callerLead = if (!isNull _callerTeam) then {leader _callerTeam} else {objNull};
				_denyMsg = "Ammo paradrop denied by server (funds or cooldown). No charge was taken server-side.";
				if (!isNull _callerLead && {isPlayer _callerLead}) then {
					if (WF_A2_Vanilla) then {
						[getPlayerUID _callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClients;
					} else {
						[_callerLead, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClient;
					};
				};
			};
		};
		if (_authOk) then {_args spawn KAT_ParaAmmo};
	};

case "RespawnST": {
		//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
		//--- FINDING (101-endpoint PV audit): unguarded, this force-kills (setDammage 1) EVERY AI supply
		//--- truck + driver for a client-named side - no type/side/requester/cooldown check at all. Trace:
		//--- the ONLY legitimate caller is the commander's "Respawn Supply Trucks" button
		//--- (GUI_Menu_Economy.sqf, MenuAction 4), which only ENABLES client-side for that side's own
		//--- seated commander (ctrlEnable gated on `commanderTeam == group player`, 5s throttle) - cosmetic
		//--- only, since the server never re-checked it and the PVEH carries no trusted sender.
		//---
		//--- HONEST SCOPE (review 2026-07-25, see memory a2-pvf-fake-identity-binding): the requester
		//--- check below is NOT identity binding. `WFBE_CO_FNC_GetCommanderTeam` is a Common function -
		//--- callable client-side for ANY side - so it returns the publicly-broadcast commander group. A
		//--- forger reads `leader ([_side] Call WFBE_CO_FNC_GetCommanderTeam)` and passes that object as
		//--- element 2; it satisfies isPlayer/alive/side/group without the forger ever controlling that
		//--- seat. This guard genuinely closes only two cases: (a) AI-commanded or uncommandered sides,
		//--- where no isPlayer object exists at that group to borrow, so the isPlayer check itself
		//--- rejects; (b) cross-side forgery (naming a side the requester isn't even a member of). It does
		//--- NOT close the case of a forger impersonating a real human-commanded side's commander - that
		//--- requires a value the client cannot compute or observe (a server-minted one-shot capability
		//--- token, per the Init_IcbmTel/Support_FPV pattern), tracked as branch
		//--- claude/u3-capability-helper-20260725. Until that lands, treat this as identity-narrowing +
		//--- rate limiting, not authentication.
		//---
		//--- What IS real here: explicit side-type validation (below - a malformed/non-SIDE payload used
		//--- to fall through to an implicit type-mismatch compare instead of an explicit, logged reject),
		//--- the per-side cooldown as genuine repeat-abuse mitigation (raised 30s -> 120s: this force-kills
		//--- a side's ENTIRE supply-truck fleet, and legitimate use of the button is rare/deliberate, not a
		//--- 30s-cadence action), and UID capture in the rejection log for post-hoc abuse identification
		//--- even though UID is not itself checked against anything (spoofable, so not a gate).
		Private ["_side","_st","_rSTRejected","_rSTRequester"];
		_side = _args select 1;
		_rSTRejected = false;
		if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
			if (typeName _side != "SIDE" || {!(_side in [west, east, resistance])}) then {
				_rSTRejected = true;
				["WARNING", Format ["Server_HandleSpecial.sqf: RespawnST rejected - side has type [%1] or is not playable.", typeName _side]] Call WFBE_CO_FNC_LogContent;
			};
			_rSTRequester = objNull;
			if (!_rSTRejected) then {
				if (count _args > 2) then {_rSTRequester = _args select 2};
				if (isNull _rSTRequester || {!isPlayer _rSTRequester} || {!alive _rSTRequester}) then {
					_rSTRejected = true;
					["WARNING", Format ["Server_HandleSpecial.sqf: RespawnST rejected - missing/invalid requester for side [%1].", str _side]] Call WFBE_CO_FNC_LogContent;
				};
			};
			if (!_rSTRejected && {side (group _rSTRequester) != _side}) then {
				_rSTRejected = true;
				["WARNING", Format ["Server_HandleSpecial.sqf: RespawnST rejected - requester [%1|%2] side does not match requested side [%3].", name _rSTRequester, getPlayerUID _rSTRequester, str _side]] Call WFBE_CO_FNC_LogContent;
			};
			if (!_rSTRejected && {(group _rSTRequester) != ((_side) Call WFBE_CO_FNC_GetCommanderTeam)}) then {
				_rSTRejected = true;
				["WARNING", Format ["Server_HandleSpecial.sqf: RespawnST rejected - requester [%1|%2] is not the publicly-broadcast commander for side [%3] (identity NOT cryptographically bound - see capability-helper lane).", name _rSTRequester, getPlayerUID _rSTRequester, str _side]] Call WFBE_CO_FNC_LogContent;
			};
			if (!_rSTRejected) then {
				Private ["_rSTLogik","_rSTCd","_rSTNow","_rSTLast"];
				_rSTLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
				if (isNull _rSTLogik) then {
					_rSTRejected = true;
				} else {
					_rSTCd = missionNamespace getVariable ["WFBE_C_RESPAWNST_COOLDOWN", 120];
					_rSTNow = time;
					_rSTLast = _rSTLogik getVariable ["wfbe_respawnst_last", -1e9];
					if (_rSTCd > 0 && {(_rSTNow - _rSTLast) < _rSTCd}) then {
						_rSTRejected = true;
						["WARNING", Format ["Server_HandleSpecial.sqf: RespawnST rejected - cooldown active for side [%1] (%2s remaining).", str _side, round (_rSTCd - (_rSTNow - _rSTLast))]] Call WFBE_CO_FNC_LogContent;
					} else {
						_rSTLogik setVariable ["wfbe_respawnst_last", _rSTNow];
					};
				};
			};
		};
		if (_rSTRejected) exitWith {};
		_st = (_side call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_ai_supplytrucks";
		{if (!isNull (driver _x)) then {driver _x setDammage 1};_x setDammage 1} forEach _st;
		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Supply Trucks were forced respawn.", str _side]] Call WFBE_CO_FNC_LogContent;
	};

	case "uav": {
		//--- supportgate SECURITY: same server-authoritative gate as "Paratroops" above (flag
		//--- WFBE_C_SUPPORT_SERVER_AUTH, default 0 = byte-identical unconditional spawn). Cost 12500
		//--- mirrors Client\Module\UAV\uav.sqf:50. No client-side call interval exists (the client only
		//--- gates on "!(alive playerUAV)", itself spoofable) - 60s is a flood-prevention floor only,
		//--- independent of live-UAV timing.
		if ((missionNamespace getVariable ["WFBE_C_SUPPORT_SERVER_AUTH", 0]) <= 0 || {["uav", _args, 12500, 60] Call WFBE_SE_FNC_AuthorizeSupportCallin}) then {
			_args spawn KAT_UAV;
		};
	};

	//--- fable/fpv-strike-drone: lifecycle watchdog for the player-piloted FPV drone.
	case "fpv": {
		_args spawn KAT_FPV;
	};

	//--- fable/fpv-strike-drone: server-side warhead detonation (Killed EH -> server). SCUD pattern.
	//--- Payload: ["fpv-detonate", [_drone, _privateCapability, [x,y,z]]]. Flag gate inside KAT_FPVDetonate.
	case "fpv-detonate": {
		if (!isNil "KAT_FPVDetonate") then {
			_args spawn KAT_FPVDetonate;
		} else {
			["WARNING", "Server_HandleSpecial.sqf: fpv-detonate received but KAT_FPVDetonate is nil."] Call WFBE_CO_FNC_LogContent;
		};
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
	case "salvage-delete-wreck": {
		//--- LOCALITY: client salvager found a non-local wreck. Re-dispatch cleanup-trash-object
		//--- to the owning machine (same stamp + channel as Common_TrashObject remote delete).
		Private ["_wreck"];
		if (count _args < 1) exitWith {};
		_wreck = _args select 0;
		if (isNull _wreck) exitWith {};
		if (alive _wreck) exitWith {}; //--- only dead hulls; refuse live deletes
		_wreck setVariable ["wfbe_trash_reap", true, true];
		if (local _wreck) then {
			deleteVehicle _wreck;
		} else {
			[_wreck, "HandleSpecial", ["cleanup-trash-object", _wreck]] Call WFBE_CO_FNC_SendToClient;
		};
	};
	case "update-town-delegation": {
		Private ["_currentEpoch","_currentSide","_delegatedSide","_isCurrent","_reportedEpoch","_reportedSide","_teams","_town","_vehicles"];
		_town = _args select 1;
		_teams = [];
		_vehicles = [];
		_reportedSide = sideUnknown;
		_reportedEpoch = -1;

		// Marty: New delegated town AI reports include local HC/client groups before vehicles; keep old vehicle-only format compatible.
		if (count _args > 3) then {
			_teams = _args select 2;
			_vehicles = _args select 3;
		} else {
			_vehicles = _args select 2;
		};

		//--- fix-1342-1343 (reconciles #1342+#1343): both mode-1 (Server_FNC_Delegation.sqf) and mode-2
		//--- (Server_DelegateAITownHeadless.sqf) senders now append [side, epoch] as elements 4/5.
		//--- Legacy 4-element payloads (pre-fix senders, should not exist post-mirror-sync but guarded
		//--- for safety) fall through to sideUnknown/-1, which never equals a real current epoch/side
		//--- and is therefore treated as stale rather than silently trusted.
		if (count _args > 5) then {
			_reportedSide = _args select 4;
			_reportedEpoch = _args select 5;
		};
		_currentSide = (_town getVariable ["sideID", WFBE_C_UNKNOWN_ID]) Call WFBE_CO_FNC_GetSideFromID;
		_currentEpoch = _town getVariable ["wfbe_town_ai_epoch", 0];
		//--- fix-1375 (codex hold b): do not trust the reported side/epoch as self-certifying just because
		//--- they happen to match the town's live state - cross-check against the server's OWN record of
		//--- which side it last delegated this town to (stamped at dispatch time by
		//--- Server_DelegateAITownHeadless.sqf / Server_FNC_Delegation.sqf), not only the args the
		//--- ack itself carries.
		_delegatedSide = _town getVariable ["wfbe_town_ai_delegated_side", sideUnknown];
		_isCurrent = (_reportedSide == _currentSide) && {_reportedEpoch == _currentEpoch} && {_reportedSide == _delegatedSide};

		if (_isCurrent) then {
		// Marty: Track the real delegated groups so server-side state and cleanup requests reference the same town assets.
		{
			if !(isNull _x) then {
				if !(_x in (_town getVariable "wfbe_town_teams")) then {
					_town setVariable ['wfbe_town_teams', (_town getVariable "wfbe_town_teams") + [_x]];
				};
			};
		} forEach _teams;

		//--- Commander Town Ledger (fable/ctl-impl-v1) unit-count fix v2 (PR #886 review: crew
		//--- undercounting): this is the ONLY point the server learns about client/HC-delegated
		//--- group creation (Client_DelegateTownAI.sqf already ran Common_CreateTownUnits.sqf
		//--- remotely and reports the real, fully-crewed groups back here). Add their REAL
		//--- Man-unit count (units _x already includes auto-crew) into ledger field [3], mirroring
		//--- the server-direct contribution in server_town_ai.sqf. Side is derived from the town's
		//--- own sideID (a town belongs to exactly one CTL ledger at a time - Server_CmdTownLedger.sqf
		//--- keys records the same way), so the message format needs no changes. Ground-only
		//--- (wfbe_ctl_ground_wave, set alongside the wave in server_town_ai.sqf) and flag-gated:
		//--- byte-identical to HEAD when AICOMV2_LANE_CMD_TOWN_LEDGER=0.
		//--- WAVE-SCOPED CREDIT FIX (owner order 2026-07-17, round-2 bughunt item 4): the gate below used to
		//--- read the town's LIVE wfbe_ctl_ground_wave flag - HC/client delegation reports land async, so if the
		//--- town's wave state flips (a newer wave dispatched, or the flag reset) between wave dispatch and this
		//--- report arriving, an in-flight ground-wave report was silently dropped here (undercount), never credited
		//--- to any record. Same fix shape as the New-Bug-A per-group stamp (server_town_ai.sqf:372-380): each group
		//--- in _teams already carries its OWN wfbe_ctl_ground_wave snapshot from the wave that actually created it -
		//--- check that per-group tag instead of the town-level flag, both for whether to run this block at all and
		//--- for which individual groups in this report to credit.
		if ((count _teams > 0) && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
			private ["_ctlSide7"];
			//--- New-Bug-B fix (fable/ctl-survivor-bugs): read the side SNAPSHOTTED at wave-creation time
			//--- (server_town_ai.sqf: wfbe_ctl_wave_side, set alongside wfbe_ctl_ground_wave), not the
			//--- town's LIVE sideID. HC/client-delegated group creation is async - if the town is
			//--- captured in the window between wave dispatch and this report landing, the live sideID
			//--- has already flipped to the NEW owner, and the old code credited that owner's
			//--- freshly-seeded ledger record (_captureSeed=0.25, lastSpawnUnits=0) with a stray unit
			//--- count from a wave it never fielded. sideUnknown default => the existing west/east
			//--- guard right below already skips the credit entirely when there's no valid snapshot
			//--- (unset, or the town changed hands again since) - same 'no valid record => no credit'
			//--- posture as the _ctlFound7 guard further down; no new branch needed.
			_ctlSide7 = _town getVariable ["wfbe_ctl_wave_side", sideUnknown];
			if (_ctlSide7 == west || {_ctlSide7 == east}) then {
				private ["_ctlUnits7"];
				_ctlUnits7 = 0;
				{ if (!isNull _x && {_x getVariable ["wfbe_ctl_ground_wave", false]}) then {_ctlUnits7 = _ctlUnits7 + (count units _x)} } forEach _teams;
				//--- CTL single-writer (fable/ctl-readback-singlewriter): accumulate the HC/client-delegated
				//--- Man-unit count into the per-town spawn scalar (per-town, so the wave-side snapshot only
				//--- gates WHETHER to credit - no valid snapshot => skip - not which record to touch).
				_town setVariable ["wfbe_ctl_lastspawn", (_town getVariable ["wfbe_ctl_lastspawn", 0]) + _ctlUnits7];
			};
		};

		_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + _vehicles];
		// Marty: Log the server acknowledgement of delegated town assets for production RPT diagnosis.
		["INFORMATION", Format ["TOWN_AI_HC_CLEANUP server_update town:%1 teams:%2 vehicles:%3 totalTeams:%4 totalVehicles:%5", _town getVariable "name", count _teams, count _vehicles, count (_town getVariable "wfbe_town_teams"), count (_town getVariable 'wfbe_active_vehicles')]] Call WFBE_CO_FNC_LogContent;
		{
			[_x] spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_x setVariable ["WFBE_Taxi_Prohib", true];
		} forEach _vehicles;
		} else {
			//--- Stale ack: the town changed owner (or completed another lifecycle) before this HC/client
			//--- batch reported back. Do not append its groups/vehicles into the current owner's registry.
			//--- Only the reporting machine can safely delete units that are local to it, so broadcast the
			//--- existing cleanup-townai path (same mechanism server_town_ai.sqf/server_town.sqf already use
			//--- for HC-local teardown) scoped to the REPORTED side, not the new current side.
			//--- fix-1375 (codex hold a): pass the town's CURRENT epoch along with the cleanup dispatch.
			//--- Without it, an A->B->A recapture where this stale ack is from an old side-A batch (epoch N-2)
			//--- broadcasts a side-scoped cleanup that a receiving HC/client would otherwise match against
			//--- EVERY locally-registered side-A batch it holds - including a freshly delegated, fully current
			//--- side-A batch from epoch N if the town has already flipped back to A again. Client_CleanupDelegatedTownAI.sqf
			//--- now only deletes entries whose OWN epoch differs from the one carried here, so the current
			//--- batch is left alone (stale epoch relative to itself = no-op).
			if (_reportedSide != sideUnknown) then {
				[nil, "HandleSpecial", ["cleanup-townai", _town, _reportedSide, _currentEpoch]] Call WFBE_CO_FNC_SendToClients;
			};
			["WARNING", Format ["Server_HandleSpecial.sqf: TOWN_AI_HC_CLEANUP stale_ack town:%1 reportedSide:%2 reportedEpoch:%3 currentSide:%4 currentEpoch:%5 groups:%6 vehicles:%7", _town getVariable ["name","?"], _reportedSide, _reportedEpoch, _currentSide, _currentEpoch, count _teams, count _vehicles]] Call WFBE_CO_FNC_LogContent;
		};
	};
	//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02): the commander's ICBM fire, intercepted client-side
	//--- (GUI_Menu_Tactical.sqf when WFBE_C_ICBM_TEL=1) and routed here. Server-authoritative gate lives in
	//--- WFBE_SE_FNC_IcbmTelFire (TEL alive + shared cooldown + range + funds); it spawns/refuses accordingly.
	//--- Payload: ["icbm-tel-fire", side, target, munition, playerTeam, fee, platformHint?]. Fn-guarded (Init_IcbmTel compiles it).
	//--- cmdcon42-j (Ray 2026-07-02): optional 7th element = a specific bought-SCUD platform hint (from the vehicle action).
	//--- The server re-validates it (ignored for NUKE; only honoured if an alive side platform) — never trusted blindly.
	case "icbm-tel-auth": {
		if (count _args != 4) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: icbm-tel-auth received malformed payload (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		if (!isNil "WFBE_SE_FNC_IcbmTelAuth") then {
			private ["_tAuthPlayer","_tChallenge","_tPurpose"];
			_tPurpose = _args select 1;
			_tAuthPlayer = _args select 2;
			_tChallenge = _args select 3;
			[_tPurpose, _tAuthPlayer, _tChallenge] Call WFBE_SE_FNC_IcbmTelAuth;
		};
	};
	case "icbm-tel-fire": {
		if (count _args != 9) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: icbm-tel-fire received malformed payload (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		if (!isNil "WFBE_SE_FNC_IcbmTelFire") then {
			private ["_tFee","_tMuni","_tPlat","_tPlayer","_tSide","_tTarget","_tTeam","_tToken"];
			_tSide = _args select 1;
			_tTarget = _args select 2;
			_tMuni = _args select 3;
			_tTeam = _args select 4;
			_tFee = _args select 5;
			_tPlat = _args select 6;
			_tPlayer = if (count _args > 7) then {_args select 7} else {objNull};
			_tToken = if (count _args > 8) then {_args select 8} else {""};
			[_tSide, _tTarget, _tMuni, _tTeam, _tFee, _tPlat, sideUnknown, _tPlayer, _tToken] Spawn WFBE_SE_FNC_IcbmTelFire;
		} else {
			["WARNING", "Server_HandleSpecial.sqf: icbm-tel-fire received but WFBE_SE_FNC_IcbmTelFire is nil (WFBE_C_ICBM_TEL=0?)."] Call WFBE_CO_FNC_LogContent;
		};
	};
	//--- A purchase proof is issued before the client build and privately returned to that player.
	case "icbm-tel-purchase-auth": {
		if (count _args != 6) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: icbm-tel-purchase-auth malformed (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		if (!isNil "WFBE_SE_FNC_IcbmTelPurchaseAuth") then {
			[_args select 1, _args select 2, _args select 3, _args select 4, _args select 5] Call WFBE_SE_FNC_IcbmTelPurchaseAuth;
		};
	};
	//--- Registration can only consume the privately delivered, server-stored purchase proof.
	case "icbm-tel-register": {
		if (count _args != 6) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: icbm-tel-register malformed (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		if (!isNil "WFBE_SE_FNC_TkScudRegister") then {
			[_args select 1, _args select 2, _args select 3, _args select 4, _args select 5] Call WFBE_SE_FNC_TkScudRegister;
		};
	};
	//--- icbmlegacy SECURITY (kimi 2026-07-24, fleet wasp-icbm-legacy-handler-unvalidated-20260724, audit
	//--- SEC-PVF-2): the legacy ICBM case ran with ZERO validation - any client could broadcast
	//--- ["RequestSpecial",["ICBM",...]] and get a free, repeatable, unlimited-range area-wipe. Flag
	//--- WFBE_C_ICBM_LEGACY_SERVER_AUTH (default 0): at 0 the ORIGINAL unvalidated block runs, byte-identical
	//--- to HEAD - the exploit stays OPEN until the owner arms this (same posture as the sibling
	//--- WFBE_C_SUPPORT_SERVER_AUTH gate). At 1 the case becomes server-authoritative, mirroring
	//--- Support_ScudStrike.sqf + WFBE_SE_FNC_IcbmTelFire:
	//---   * TEL-mode refuse: with WFBE_C_ICBM_TEL=1 (default) NO legit classic sender exists (the tactical
	//---     menu routes NUKE fire through the hardened icbm-tel-fire path), so every request is refused.
	//---   * payload shape: exactly ["ICBM", SIDE, OBJECT, OBJECT, GROUP].
	//---   * module gate (WFBE_C_MODULE_WFBE_ICBM) + playable side + team-side match.
	//---   * commander role: the requesting team must BE the side wfbe_commander team (the SEC-PVF-2 fix).
	//---   * SCUD research >= 2 (the NUKE tier - same gate as the client enable + the TEL NUKE path).
	//---   * per-side shared cooldown, stamped BEFORE the cruise-death wait (anti machine-gun race).
	//---   * server-authoritative funds: while armed the classic client no longer debits at click
	//---     (GUI_Menu_Tactical.sqf MenuAction 8) - the WFBE_C_ICBM_COST fee is charged HERE at launch.
	//---   NUKE range stays unlimited by design (parity with the TEL NUKE); refusal reasons are WARNING-logged.
	case "ICBM": {
		if ((missionNamespace getVariable ["WFBE_C_ICBM_LEGACY_SERVER_AUTH", 0]) <= 0) then {
			Private ["_base","_playerTeam","_side","_target"];

			_side = _args select 1;
			_base = _args select 2;
			_target = _args select 3;
			_playerTeam = _args select 4;

			["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in an ICBM Nuke.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;

			if (isNull _target || !alive _target) exitWith {};

			//--- r60 waitUntil: cruise-death wait had no sleep/timeout; a stuck-alive cruise hung this PVF thread forever.
			private ["_cruiseDeadline"];
			_cruiseDeadline = time + (missionNamespace getVariable ["WFBE_C_ICBM_CRUISE_WAIT", 600]);
			waitUntil {
				sleep 1;
				!alive _target || {isNull _target} || {time > _cruiseDeadline}
			};
			if (alive _target && {!isNull _target}) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM cruise wait timeout (%1s) - nuke aborted.", missionNamespace getVariable ["WFBE_C_ICBM_CRUISE_WAIT", 600]]] Call WFBE_CO_FNC_LogContent;
			};

//--- failure-signalling r38: unvalidated legacy path still must not Spawn Nuke on null anchor.
if (isNull _base) exitWith {
["WARNING", "Server_HandleSpecial.sqf: ICBM legacy path aborted - null base after cruise death."] Call WFBE_CO_FNC_LogContent;
};
[_base] Spawn NukeDammage;
} else {
			Private ["_base","_cdKey","_cool","_cost","_funds","_last","_lvl","_playerTeam","_side","_target","_upg"];

			//--- TEL mode (default): no classic-path sender can be legitimate.
			if ((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) > 0) exitWith {
				["WARNING", "Server_HandleSpecial.sqf: ICBM refused - WFBE_C_ICBM_TEL=1 routes NUKE fire via icbm-tel-fire; no legit classic sender exists."] Call WFBE_CO_FNC_LogContent;
			};
			if (count _args != 5) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - malformed payload (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
			};

			_side = _args select 1;
			_base = _args select 2;
			_target = _args select 3;
			_playerTeam = _args select 4;

			if (typeName _side != "SIDE") exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - side has type [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
			};
			if (typeName _base != "OBJECT") exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - target anchor has type [%1].", typeName _base]] Call WFBE_CO_FNC_LogContent;
			};
			if (typeName _target != "OBJECT") exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - cruise has type [%1].", typeName _target]] Call WFBE_CO_FNC_LogContent;
			};
			if (typeName _playerTeam != "GROUP") exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - team has type [%1].", typeName _playerTeam]] Call WFBE_CO_FNC_LogContent;
			};
			if ((missionNamespace getVariable ["WFBE_C_MODULE_WFBE_ICBM", 1]) <= 0) exitWith {
				["WARNING", "Server_HandleSpecial.sqf: ICBM refused - ICBM module disabled (WFBE_C_MODULE_WFBE_ICBM=0)."] Call WFBE_CO_FNC_LogContent;
			};
			if !(_side in [west, east, resistance]) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - non-playable side [%1].", str _side]] Call WFBE_CO_FNC_LogContent;
			};
			if (isNull _playerTeam || {(side _playerTeam) != _side}) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - null team or team/side mismatch (side %1).", str _side]] Call WFBE_CO_FNC_LogContent;
			};
			//--- SEC-PVF-2 recommended check: the requesting team must hold the side commander role.
			if (_playerTeam != (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - team [%1] is not the [%2] commander team.", _playerTeam, str _side]] Call WFBE_CO_FNC_LogContent;
			};

			//--- SCUD research >= 2 (NUKE tier). Flat guard AFTER the read (an exitWith nested inside a then{}
			//--- would only exit that block), same pattern WFBE_SE_FNC_IcbmTelFire uses for its own level gate.
			_lvl = 0;
			if (!isNil "WFBE_UP_ICBM") then {
				_upg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
				if (typeName _upg == "ARRAY" && {WFBE_UP_ICBM < count _upg}) then {_lvl = _upg select WFBE_UP_ICBM};
			};
			if (_lvl < 2) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - [%1] SCUD level %2 < 2.", str _side, _lvl]] Call WFBE_CO_FNC_LogContent;
			};

			//--- Per-side shared cooldown (the stamp is written at the last AUTHORISED launch, below).
			_cool = missionNamespace getVariable ["WFBE_C_ICBM_LEGACY_COOLDOWN", 300];
			_cdKey = Format ["WFBE_ICBM_LEGACY_LASTFIRE_%1", str _side];
			_last = missionNamespace getVariable [_cdKey, -99999];
			if ((time - _last) < _cool) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - [%1] cooldown (%2s left).", str _side, round (_cool - (time - _last))]] Call WFBE_CO_FNC_LogContent;
			};

			//--- Server-authoritative funds (G1-safe group read: 1-arg getVariable + isNil/typeName guard).
			_cost = missionNamespace getVariable ["WFBE_C_ICBM_COST", 75000];
			_funds = _playerTeam getVariable "wfbe_funds";
			if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
			if (_funds < _cost) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM refused - [%1] insufficient funds (%2 < %3).", str _side, _funds, _cost]] Call WFBE_CO_FNC_LogContent;
			};

			["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in an ICBM Nuke.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;

			if (isNull _target || !alive _target) exitWith {};

			//--- All gates passed: charge + stamp BEFORE the cruise-death wait (anti double-fire race, same
			//--- ordering as Support_ScudStrike.sqf). Funds-record lock-step mirrors Common_ChangeTeamFunds pick A.
			_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true];
			[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord;
			missionNamespace setVariable [_cdKey, time];

			//--- r60 waitUntil: cruise-death wait sleep+timeout (same shape as legacy branch above).
			private ["_cruiseDeadline"];
			_cruiseDeadline = time + (missionNamespace getVariable ["WFBE_C_ICBM_CRUISE_WAIT", 600]);
			waitUntil {
				sleep 1;
				!alive _target || {isNull _target} || {time > _cruiseDeadline}
			};
			if (alive _target && {!isNull _target}) exitWith {
				["WARNING", Format ["Server_HandleSpecial.sqf: ICBM cruise wait timeout (%1s) - nuke aborted.", missionNamespace getVariable ["WFBE_C_ICBM_CRUISE_WAIT", 600]]] Call WFBE_CO_FNC_LogContent;
			};

		//--- The HeliHEmpty anchor can be deleted mid-flight (GC); never nuke a null position.
		//--- failure-signalling r38: charge+cooldown already committed above - refund + unstamp on abort
		//--- so the commander is not left paying for a silent no-op.
		if (isNull _base) exitWith {
			private ["_curFunds"];
			_curFunds = _playerTeam getVariable "wfbe_funds";
			if (isNil "_curFunds" || {typeName _curFunds != "SCALAR"}) then {_curFunds = 0};
			_playerTeam setVariable ["wfbe_funds", (_curFunds + _cost), true];
			if (!isNil "WFBE_SE_FNC_SyncFundsRecord") then {[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord};
			missionNamespace setVariable [_cdKey, _last];
			["WARNING", Format ["Server_HandleSpecial.sqf: ICBM aborted - null base after cruise death; refunded $%1 to team %2 and restored cooldown.", _cost, _playerTeam]] Call WFBE_CO_FNC_LogContent;
		};

		[_base] Spawn NukeDammage;
		};
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

	case "ArtySharedCooldown": {
		Private ["_side","_team","_logik"];
		if ((missionNamespace getVariable ["WFBE_C_ARTY_SHARED_COOLDOWN", 0]) <= 0) exitWith {};
		if (count _args < 3) exitWith {};
		_side = _args select 1;
		_team = _args select 2;
		if !(_side in [west, east, resistance]) exitWith {};
		if (isNull _team) exitWith {};
		if ((side _team) != _side) exitWith {};
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (isNull _logik) exitWith {};
		_logik setVariable ["wfbe_arty_last_fire", time, true];
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
		//--- HARDENING (unauthenticated-PV audit, highest severity): this case used to forward a raw
		//--- client-supplied [structure, killer] pair straight into WFBE_SE_FNC_OnHQKilled, whose ONLY
		//--- guard is a one-shot idempotency flag (wfbe_hq_killed_done) - it never checked the reported
		//--- structure was alive, that it was actually the side's registered HQ, or that the killer was
		//--- a real player. A forged report naming the REAL (still-alive) enemy HQ plus the attacker's
		//--- own player object credited ~30000 score + $30,000 funds to the attacker's group AND force-
		//--- flipped IS_<SIDE>_HQ_ALIVE to false (false "HQ destroyed" state) while the HQ was standing.
		//---
		//--- Server-side is authoritative independent of this relay: every HQ/MHQ object also carries
		//--- its OWN server-local 'killed' EH (Construction_HQSite.sqf, Server_MHQRepair.sqf,
		//--- Init_Server.sqf) which Spawns WFBE_SE_FNC_OnHQKilled directly with zero network latency -
		//--- that path is untouched by this guard. The client relay (DR-20 comment in
		//--- Server_OnHQKilled.sqf) is a redundant backup only: for any genuine kill the trusted
		//--- server-local EH already wins the wfbe_hq_killed_done idempotency race, so narrowing THIS
		//--- ingress to reject forgeries costs the honest path nothing.
		//---
		//--- Unflagged (not gated on WFBE_C_SEC_HARDENING): every check below is satisfied automatically
		//--- by any genuine HQ death report and rejects only data a legitimate report could never
		//--- contain - same "reject only illegitimate input" class as RequestMHQRepair.sqf/#1361.
		Private ["_reportedArgs","_reportedStructure","_reportedKiller","_reportedSide","_registeredHQ"];
		_reportedArgs = _args select 1;
		if !((typeName _reportedArgs == "ARRAY") && {(count _reportedArgs) > 1}) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: process-killed-hq rejected - malformed payload [%1].", _reportedArgs]] Call WFBE_CO_FNC_LogContent;
		};
		_reportedStructure = _reportedArgs select 0;
		_reportedKiller = _reportedArgs select 1;
		if !((typeName _reportedStructure == "OBJECT") && {!isNull _reportedStructure}) exitWith {
			["WARNING", "Server_HandleSpecial.sqf: process-killed-hq rejected - null/invalid reported structure."] Call WFBE_CO_FNC_LogContent;
		};
		if !((typeName _reportedKiller == "OBJECT") && {!isNull _reportedKiller} && {isPlayer _reportedKiller} && {alive _reportedKiller}) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: process-killed-hq rejected - killer [%1] is not a live player.", _reportedKiller]] Call WFBE_CO_FNC_LogContent;
		};
		//--- Resolve the CURRENT registered HQ for the reported structure's own claimed side and require
		//--- an exact object match - a forger can name a real object, but cannot make it equal the
		//--- side-logic's live wfbe_hq reference unless it genuinely is that side's HQ.
		_reportedSide = _reportedStructure getVariable ["wfbe_side", sideUnknown];
		_registeredHQ = objNull;
		if (_reportedSide in [west, east, resistance]) then {_registeredHQ = (_reportedSide) Call WFBE_CO_FNC_GetSideHQ};
		if !(!isNull _registeredHQ && {_reportedStructure == _registeredHQ}) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: process-killed-hq rejected - structure [%1] is not the registered HQ for side [%2].", _reportedStructure, _reportedSide]] Call WFBE_CO_FNC_LogContent;
		};
		//--- The load-bearing check: the report must describe a HQ that is ACTUALLY dead right now.
		if (alive _reportedStructure) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: process-killed-hq rejected - structure [%1] is still alive.", _reportedStructure]] Call WFBE_CO_FNC_LogContent;
		};
		_reportedArgs Spawn WFBE_SE_FNC_OnHQKilled;
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
	//--- WASPSCALE HC-locality relay: missionNamespace counters are local to the executing
	//--- machine, so delegated commander work sends a one-count delta through the already
	//--- allowlisted RequestSpecial PVF. Never public-broadcast missionNamespace counters.
	case "waspscale-counter-delta": {
		private ["_wsCounter"];
		if (count _args != 2) exitWith {};
		_wsCounter = _args select 1;
		if (_wsCounter in ["wfbe_waspscale_recov", "wfbe_waspscale_mhqrel"]) then {
			missionNamespace setVariable [_wsCounter, (missionNamespace getVariable [_wsCounter, 0]) + 1];
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
		//--- TP-13 SERVER-SIDE RATE LIMIT (WFBE_C_TEAM_FOCUS_COOLDOWN, 0 disables): the only guard was the
		//--- CLIENT cooldown in GUI_Menu_Command (_lastSend) - a modified client could spam this case every
		//--- frame and whipsaw the Allocator fist. UID-keyed on the side logic, mirroring the CMD_NUDGE
		//--- cooldown idiom below; legacy/malicious 3-arg senders (no player appended) share ONE "anon" key
		//--- per side = the side-wide backstop a spoofed sender cannot bypass by omitting the arg.
		private ["_fSide","_fTown","_fLogik","_fPlayer","_fUID","_fKey","_fCd","_fNow","_fLast"];
		_fSide = _args select 1;
		_fTown = _args select 2;
		if (!isNil "_fTown" && {!isNull _fTown} && {_fSide in [west, east]}) then {
			_fLogik = (_fSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _fLogik) then {
				_fNow = time;
				_fCd  = missionNamespace getVariable ["WFBE_C_TEAM_FOCUS_COOLDOWN", 120];
				if (count _args > 3) then {_fPlayer = _args select 3};
				_fUID = "anon";
				//--- TP-13 stack-pass: only a REAL player on THIS side earns a per-UID key. A spoofed sender passing an
				//--- arbitrary object (str-of-object = fresh key per object) would otherwise bypass the limit; such
				//--- senders now fall through to the shared "anon" side key (throttled). No str-of-object fallback.
				if (!isNil "_fPlayer" && {!isNull _fPlayer} && {isPlayer _fPlayer} && {side (group _fPlayer) == _fSide}) then {
					private "_u"; _u = getPlayerUID _fPlayer;
					if (!isNil "_u" && {_u != ""}) then {_fUID = _u};
				};
				_fKey = "wfbe_cmd_focus_" + _fUID;
				_fLast = _fLogik getVariable [_fKey, -1e9];
				if ((_fNow - _fLast) >= _fCd) then {
					_fLogik setVariable [_fKey, _fNow];
					_fLogik setVariable ["wfbe_aicom_focus", _fTown];
					_fLogik setVariable ["wfbe_aicom_focus_t0", time];
					diag_log ("AICOM2|v1|FOCUS|" + str _fSide + "|" + str (round (time / 60)) + "|set=" + (_fTown getVariable ["name", "?"]) + "|uid=" + _fUID);
				} else {
					diag_log ("AICOM2|v1|FOCUS|REJECT|" + str _fSide + "|uid=" + _fUID + "|cdLeft=" + str (round (_fCd - (_fNow - _fLast))));
				};
			};
		};
	};
	case "aicom-defend": {
		//--- COMMAND-CENTER INSTRUCTION PANEL (PR1): a player set a DEFEND town for the AI commander (modeled
		//--- EXACTLY on aicom-focus). Stamp it (+ a t0 timestamp) on the side logic; AI_Commander_Strategy.sqf
		//--- reads it (TTL'd by WFBE_C_AICOM_DEFEND_TTL) and biases a reliever team to that town. side validated west/east.
		//--- TP-20 SERVER-SIDE RATE LIMIT (WFBE_C_CMD_VERB_COOLDOWN, 0 disables): defend/reinforce/posture/fieldorder each
		//--- had only a client-side cooldown gate; a modified client could spam them server-side. UID-keyed on the side
		//--- logic (wfbe_cmd_ prefix) identical to the aicom-focus guard (TP-13); legacy/anon senders share one side key.
		private ["_dSide","_dTown","_dLogik","_dPlayer","_dUID","_dKey","_dCd","_dNow","_dLast"];
		_dSide = _args select 1;
		_dTown = _args select 2;
		if (!isNil "_dTown" && {!isNull _dTown} && {_dSide in [west, east]}) then {
			_dLogik = (_dSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _dLogik) then {
				_dNow = time;
				_dCd  = missionNamespace getVariable ["WFBE_C_CMD_VERB_COOLDOWN", 60];
				if (count _args > 3) then {_dPlayer = _args select 3};
				_dUID = "anon";
				if (!isNil "_dPlayer" && {!isNull _dPlayer} && {isPlayer _dPlayer} && {side (group _dPlayer) == _dSide}) then {
					private "_u"; _u = getPlayerUID _dPlayer;
					if (!isNil "_u" && {_u != ""}) then {_dUID = _u};
				};
				_dKey  = "wfbe_cmd_defend_" + _dUID;
				_dLast = _dLogik getVariable [_dKey, -1e9];
				if (_dCd <= 0 || {(_dNow - _dLast) >= _dCd}) then {
					_dLogik setVariable [_dKey, _dNow];
					_dLogik setVariable ["wfbe_aicom_defend_focus", _dTown];
					_dLogik setVariable ["wfbe_aicom_defend_focus_t0", time];
					diag_log ("AICOM2|v1|DEFEND|" + str _dSide + "|" + str (round (time / 60)) + "|set=" + (_dTown getVariable ["name", "?"]) + "|uid=" + _dUID);
				} else {
					diag_log ("AICOM2|v1|DEFEND|REJECT|" + str _dSide + "|uid=" + _dUID + "|cdLeft=" + str (round (_dCd - (_dNow - _dLast))));
				};
			};
		};
	};
	case "aicom-arty-here": {
		//--- COMMAND CONSOLE: a player called an ARTILLERY-HERE strike from the war room. We stamp a fresh [pos,time]
		//--- request on the side logic; the assist-mode resolver (AI_Com_PlayerArty, every supervisor tick) consumes it
		//--- fire-once - so it works even under a HUMAN commander, where the brain's own Strategy arty block is dormant.
		//--- PRODUCTION FIX (claude-gaming 2026-06-28): gate on the SEPARATE player-arty flag (WFBE_C_AICOM_PLAYER_ARTY),
		//--- NOT WFBE_C_AI_COMMANDER_ARTILLERY (the AI's OWN fire/build gate - default ON since 2026-07-08
		//--- fable/alife-arty-dwell, was Steff-hard-locked to 0 before that; see Init_CommonConstants.sqf).
		//--- The player request is serviced in assist-mode by AI_Com_PlayerArty and only ever fires friendly pieces
		//--- that already exist (it never builds guns), so it stays independent of the AI's own arty state either way.
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
		private ["_rSide","_rTown","_rLogik","_rCmd","_rHuman","_rRun","_rSID","_rPlayer","_rUID","_rKey","_rCd","_rNow","_rLast"];
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
					_rNow = time;
					_rCd  = missionNamespace getVariable ["WFBE_C_CMD_VERB_COOLDOWN", 60];
					if (count _args > 3) then {_rPlayer = _args select 3};
					_rUID = "anon";
					if (!isNil "_rPlayer" && {!isNull _rPlayer} && {isPlayer _rPlayer} && {side (group _rPlayer) == _rSide}) then {
						private "_u"; _u = getPlayerUID _rPlayer;
						if (!isNil "_u" && {_u != ""}) then {_rUID = _u};
					};
					_rKey  = "wfbe_cmd_reinforce_" + _rUID;
					_rLast = _rLogik getVariable [_rKey, -1e9];
					if (_rCd <= 0 || {(_rNow - _rLast) >= _rCd}) then {
						_rLogik setVariable [_rKey, _rNow];
						_rLogik setVariable ["wfbe_aicom_reinforce", [_rTown, time]];
						diag_log ("AICOM2|v1|ORDER|aicom-reinforce|" + str _rSide + "|" + str (round (time / 60)) + "|town=" + (_rTown getVariable ["name", "?"]) + "|uid=" + _rUID);
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-reinforce|REJECT|" + str _rSide + "|uid=" + _rUID + "|cdLeft=" + str (round (_rCd - (_rNow - _rLast))));
					};
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
		private ["_pSide","_pPos","_pLogik","_pCmd","_pHuman","_pRun","_pPlayer","_pUID","_pKey","_pCd","_pNow","_pLast","_pOk"];
		_pSide = _args select 1;
		_pPos  = _args select 2;
		//--- COMMAND V2 pillar (b), side scope: the whitelist gains a third value GARRISON behind
		//--- WFBE_C_CMD_POSTURE_GARRISON (default 0). At flag-off the accepted set is exactly PUSH/HOLD,
		//--- i.e. behaviourally identical to HEAD - a "GARRISON" payload is simply not accepted and the
		//--- consumer in AI_Commander_Allocate.sqf can therefore never observe the new string.
		_pOk = false;
		if (typeName _pPos == "STRING") then {
			_pOk = (_pPos == "PUSH") || {_pPos == "HOLD"};
			if (!_pOk && {(missionNamespace getVariable ["WFBE_C_CMD_POSTURE_GARRISON", 0]) > 0}) then {_pOk = (_pPos == "GARRISON")};
		};
		if (_pOk && {_pSide in [west, east]}) then {
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
					_pNow = time;
					_pCd  = missionNamespace getVariable ["WFBE_C_CMD_VERB_COOLDOWN", 60];
					if (count _args > 3) then {_pPlayer = _args select 3};
					_pUID = "anon";
					if (!isNil "_pPlayer" && {!isNull _pPlayer} && {isPlayer _pPlayer} && {side (group _pPlayer) == _pSide}) then {
						private "_u"; _u = getPlayerUID _pPlayer;
						if (!isNil "_u" && {_u != ""}) then {_pUID = _u};
					};
					_pKey  = "wfbe_cmd_posture_" + _pUID;
					_pLast = _pLogik getVariable [_pKey, -1e9];
					if (_pCd <= 0 || {(_pNow - _pLast) >= _pCd}) then {
						_pLogik setVariable [_pKey, _pNow];
						_pLogik setVariable ["wfbe_aicom_player_posture", _pPos];
						_pLogik setVariable ["wfbe_aicom_player_posture_t0", time];
						diag_log ("AICOM2|v1|ORDER|aicom-posture|" + str _pSide + "|" + str (round (time / 60)) + "|posture=" + _pPos + "|uid=" + _pUID);
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-posture|REJECT|" + str _pSide + "|uid=" + _pUID + "|cdLeft=" + str (round (_pCd - (_pNow - _pLast))));
					};
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
		private ["_pSide","_pPos","_pLogik","_pCmd","_pHuman","_pRun","_pPlayer","_pUID","_pKey","_pCd","_pNow","_pLast"];
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
					_pNow = time;
					_pCd  = missionNamespace getVariable ["WFBE_C_CMD_VERB_COOLDOWN", 60];
					if (count _args > 3) then {_pPlayer = _args select 3};
					_pUID = "anon";
					if (!isNil "_pPlayer" && {!isNull _pPlayer} && {isPlayer _pPlayer} && {side (group _pPlayer) == _pSide}) then {
						private "_u"; _u = getPlayerUID _pPlayer;
						if (!isNil "_u" && {_u != ""}) then {_pUID = _u};
					};
					_pKey  = "wfbe_cmd_fieldorder_" + _pUID;
					_pLast = _pLogik getVariable [_pKey, -1e9];
					if (_pCd <= 0 || {(_pNow - _pLast) >= _pCd}) then {
						_pLogik setVariable [_pKey, _pNow];
						_pLogik setVariable ["wfbe_aicom_player_fieldorder", _pPos];
						_pLogik setVariable ["wfbe_aicom_player_fieldorder_t0", time];
						diag_log ("AICOM2|v1|ORDER|aicom-fieldorder|" + str _pSide + "|" + str (round (time / 60)) + "|order=" + _pPos + "|uid=" + _pUID);
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-fieldorder|REJECT|" + str _pSide + "|uid=" + _pUID + "|cdLeft=" + str (round (_pCd - (_pNow - _pLast))));
					};
				};
			};
		};
	};
	case "aicom-team-disband": {
		//--- COMMAND CONSOLE (claude-gaming 2026-06-30, Ray): player-commander FAILSAFE - disband the side's AI field
		//--- teams. Unlike the posture/fieldorder NUDGES (which gate on !_pHuman = AI-runs), this is a DIRECT action FOR
		//--- the human commander, so it REQUIRES a human commander on the side. We only FLAG each team (wfbe_aicom_disband,
		//--- the proven retire path); the HC-local executor in Common_RunCommanderTeam.sqf destroys a team's units
		//--- unconditionally (owner ruling 2026-07-22: destructive retire - vehicles explode, infantry grenade-drop). A2-OA-safe: object getVariable [k,d] (side logic), group setVariable [k,v,true]
		//--- (no A3-only group getVariable [k,d]); count _args / typeName for the optional arg (no params / isEqualType).
		//--- Command Console v2 (claude-gaming 2026-07-01): OPTIONAL arg[2] = a team INDEX into this side's wfbe_teams. When
		//--- present + valid -> disband ONLY that team (a precision action; NO 15-min cooldown, and it does NOT stamp the
		//--- per-side cooldown clock). When ABSENT -> the original ALL-teams sweep (15-min per-side cooldown, unchanged).
		private ["_dSide","_dLogik","_dCmd","_dHuman","_dTeams","_dN","_dHasIdx","_dIdx","_dDispatch","_dPlayer","_dAuth"];
		_dDispatch = {
			private ["_dTeam","_dLeader"];
			_dTeam = _this select 0;
			if (!isNull _dTeam) then {
				_dLeader = leader _dTeam;
				if (!isNull _dLeader) then {
					if (local _dLeader) then {
						[_dTeam] Spawn WFBE_CO_FNC_AICOMDisbandTeam;
					} else {
						[_dLeader, "HandleSpecial", ["aicom-team-disband-execute", _dTeam]] Call WFBE_CO_FNC_SendToClient;
					};
				};
			};
		};
		_dSide = _args select 1;
		_dHasIdx = false; _dIdx = -1;
		if (count _args >= 3) then {
			private "_dRaw"; _dRaw = _args select 2;
			if (!isNil "_dRaw" && {typeName _dRaw == "SCALAR"}) then {_dHasIdx = true; _dIdx = _dRaw};
		};
		//--- SENDER IDENTITY (card wasp-aicom-disband-no-sender-identity-20260725): the client appends the acting player -
		//--- select 3 when a team index is present, else select 2. ALWAYS-ON per the owner C4/C2 ruling (RequestAIComDonate.sqf):
		//--- the sole honest caller GUI_Menu_Command.sqf always sends the live local player, so a real order never trips it; a
		//--- forged or legacy RequestSpecial that omits or spoofs the player is rejected by the authority bind below.
		_dPlayer = objNull;
		if (_dHasIdx) then {if (count _args >= 4) then {_dPlayer = _args select 3}} else {if (count _args >= 3) then {_dPlayer = _args select 2}};
		if (_dSide in [west, east]) then {
			_dLogik = (_dSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _dLogik) then {
				_dCmd = (_dSide) Call WFBE_CO_FNC_GetCommanderTeam; _dHuman = false;
				if (!isNull _dCmd) then {if (isPlayer (leader _dCmd)) then {_dHuman = true}};
				_dTeams = _dLogik getVariable ["wfbe_teams", []];
				//--- Authority bind (same card): the acting player must be alive, a real player, on _dSide, and IN this side
				//--- commander team (group == wfbe_commander). Mirrors the aicom-support side-membership gate; cross-side or spoofed callers fail.
				_dAuth = (!isNull _dPlayer) && {alive _dPlayer} && {isPlayer _dPlayer} && {!isNull _dCmd} && {side (group _dPlayer) == _dSide} && {group _dPlayer == _dCmd};
				if (_dHasIdx) then {
					//--- SPECIFIC-TEAM disband: human commander required, but no side cooldown (single, deliberate stand-down).
					if (_dHuman && {_dAuth} && {_dIdx >= 0} && {_dIdx < (count _dTeams)}) then {
						private "_dTeam"; _dTeam = _dTeams select _dIdx;
						if (!isNull _dTeam && {!isPlayer (leader _dTeam)}) then {
							_dTeam setVariable ["wfbe_aicom_disband", true, true];
							_dTeam setVariable ["wfbe_aicom_disband_cmd", true, true]; //--- Build84: explicit human console order -> bypass the player-proximity veto in the HC executor
							[_dTeam] Call _dDispatch;
							diag_log ("AICOM2|v1|ORDER|aicom-team-disband|" + str _dSide + "|" + str (round (time / 60)) + "|specific=" + str _dIdx + "|team=" + str _dTeam);
						} else {
							diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT-SPECIFIC|" + str _dSide + "|idx=" + str _dIdx + "|nullOrPlayer");
						};
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT-SPECIFIC|" + str _dSide + "|human=" + str _dHuman + "|auth=" + str _dAuth + "|idx=" + str _dIdx + "|teams=" + str (count _dTeams));
					};
				} else {
					//--- ALL-teams sweep (original behaviour): human commander + 15-min per-side cooldown.
					private ["_dLast","_dCool"];
					_dLast = _dLogik getVariable ["wfbe_aicom_last_disband", -1e10];
					_dCool = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_COOLDOWN", 900];
					if (_dHuman && {_dAuth} && {(time - _dLast) >= _dCool}) then {
						_dLogik setVariable ["wfbe_aicom_last_disband", time, true];
						_dN = 0;
						{ if (!isNull _x && {!isPlayer (leader _x)}) then {_x setVariable ["wfbe_aicom_disband", true, true]; _x setVariable ["wfbe_aicom_disband_cmd", true, true]; [_x] Call _dDispatch; _dN = _dN + 1} } forEach _dTeams;
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|" + str _dSide + "|" + str (round (time / 60)) + "|flagged=" + str _dN + "|teams=" + str (count _dTeams));
					} else {
						diag_log ("AICOM2|v1|ORDER|aicom-team-disband|REJECT|" + str _dSide + "|human=" + str _dHuman + "|auth=" + str _dAuth + "|cdLeft=" + str (_dCool - (time - _dLast)));
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
	case "aicom-manualpin": {
		//--- Direct map/ALL-HOLD UI orders originate on a client, whose mission clock may differ after JIP/load.
		//--- Resolve and stamp the pin server-side so AssignTowns compares two values from the same clock.
		private ["_mpSide","_mpTeam","_mpPlayer","_mpLogik","_mpCmd","_mpTeams","_mpAuth"];
		_mpSide = _args select 1;
		_mpTeam = grpNull;
		_mpPlayer = objNull;
		if (count _args > 2) then {_mpTeam = _args select 2};
		if (count _args > 3) then {_mpPlayer = _args select 3};
		if (_mpSide in [west, east] && {typeName _mpTeam == "GROUP"} && {!isNull _mpTeam}) then {
			_mpLogik = (_mpSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _mpLogik) then {
				_mpCmd = (_mpSide) Call WFBE_CO_FNC_GetCommanderTeam;
				_mpTeams = _mpLogik getVariable ["wfbe_teams", []];
				_mpAuth = (!isNull _mpPlayer) && {alive _mpPlayer} && {isPlayer _mpPlayer} && {!isNull _mpCmd} && {group _mpPlayer == _mpCmd} && {_mpTeam in _mpTeams};
				if (_mpAuth) then {
					_mpTeam setVariable ["wfbe_aicom_manualpin", time, true];
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
		private ["_ryEnabled","_rySide","_ryIdx","_ryLogik","_ryCmd","_ryHuman","_ryTeams","_ryTeam","_ryHQ","_ryPos","_ryBest","_rySID","_ryPlayer","_ryAuth"];
		_ryEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_rySide = _args select 1;
		_ryIdx  = -1;
		if (count _args >= 3) then {private "_ryRaw"; _ryRaw = _args select 2; if (!isNil "_ryRaw" && {typeName _ryRaw == "SCALAR"}) then {_ryIdx = _ryRaw}};
		_ryPlayer = objNull; if (count _args >= 4) then {_ryPlayer = _args select 3}; //--- card wasp-aicom-disband-no-sender-identity: acting player appended by GUI_Menu_Command.sqf
		if (_ryEnabled && {_rySide in [west, east]} && {_ryIdx >= 0}) then {
			_ryLogik = (_rySide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _ryLogik) then {
				_ryCmd = (_rySide) Call WFBE_CO_FNC_GetCommanderTeam; _ryHuman = false;
				if (!isNull _ryCmd) then {if (isPlayer (leader _ryCmd)) then {_ryHuman = true}};
				_ryTeams = _ryLogik getVariable ["wfbe_teams", []];
				_ryAuth = (!isNull _ryPlayer) && {alive _ryPlayer} && {isPlayer _ryPlayer} && {!isNull _ryCmd} && {side (group _ryPlayer) == _rySide} && {group _ryPlayer == _ryCmd}; //--- caller must be IN this side commander team
				if (_ryHuman && {_ryAuth} && {_ryIdx < (count _ryTeams)}) then {
					_ryTeam = _ryTeams select _ryIdx;
					if (!isNull _ryTeam && {({alive _x} count units _ryTeam) > 0} && {!isPlayer (leader _ryTeam)}) then {
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
					diag_log ("AICOM2|v1|ORDER|aicom-rally|REJECT|" + str _rySide + "|human=" + str _ryHuman + "|auth=" + str _ryAuth + "|idx=" + str _ryIdx + "|teams=" + str (count _ryTeams));
				};
			};
		};
	};
	//--- fix (PR #1251 bounce): server-side landing for HC-originated AI top-up refunds
	//--- (Common_RunCommanderTeam.sqf stale-TTL + partial-spawn refunds; ChangeAICommanderFunds only exists
	//--- on the server). Forgeable-bus residual matches the documented cleanup-* precedent; mitigations:
	//--- side index validated, amount clamped to the maximum legitimate charge (4 units x TOPUP_UNIT_COST,
	//--- +50% slack), never negative or non-scalar.
	case "aicom-topup-refund": {
		private ["_trSideID","_trAmt","_trCap"];
		if ((count _args) < 3) exitWith {};
		_trSideID = _args select 1;
		_trAmt = _args select 2;
		if ((typeName _trSideID) != "SCALAR" || {(typeName _trAmt) != "SCALAR"}) exitWith {};
		if (!(_trSideID in [0,1]) || {_trAmt <= 0}) exitWith {};
		_trCap = 4 * (missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_UNIT_COST", 1000]) * 1.5;
		if (_trAmt > _trCap) then {_trAmt = _trCap};
		[([west, east] select _trSideID), _trAmt] Call ChangeAICommanderFunds;
		diag_log ("AICOMSTAT|v1|EVENT|" + str _trSideID + "|" + str (round (time / 60)) + "|TOPUP_REFUND_LANDED|amount=" + str _trAmt);
	};
	case "aicom-refit": {
		//--- cmdcon41-w3d COMMAND-MENU V2 (REFIT): the human commander requested a funds-charged infantry TOP-UP for ONE
		//--- team - the exact same consumer path Produce's auto top-up uses (wfbe_aicom_topup_req [count,pos,classes,issuedTime] on the
		//--- team; the owning HC/server driver spawns the bodies in Common_RunCommanderTeam). We mirror Produce's cost +
		//--- rate-limit gates: flat WFBE_C_AICOM_TOPUP_UNIT_COST per missing man toward 6 (cap 4), charged from the AI
		//--- commander treasury up front; one refit per team per WFBE_C_AICOM_TOPUP_COOLDOWN via the SAME wfbe_aicom_topup_stamp
		//--- Produce stamps. NEVER trust the client: human commander required, side + team validated, funds re-checked here.
		private ["_rfEnabled","_rfSide","_rfIdx","_rfLogik","_rfCmd","_rfHuman","_rfTeams","_rfTeam","_rfAlive","_rfNow","_rfLast","_rfCd","_rfMissing","_rfSText","_rfBarr","_rfCls","_rfCost","_rfCharge","_rfFunds","_rfCostOn","_rfAfford","_rfChargedAmt","_rfPlayer","_rfAuth"];
		_rfEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_rfSide = _args select 1;
		_rfIdx  = -1;
		if (count _args >= 3) then {private "_rfRaw"; _rfRaw = _args select 2; if (!isNil "_rfRaw" && {typeName _rfRaw == "SCALAR"}) then {_rfIdx = _rfRaw}};
		_rfPlayer = objNull; if (count _args >= 4) then {_rfPlayer = _args select 3}; //--- card wasp-aicom-disband-no-sender-identity: acting player appended by GUI_Menu_Command.sqf
		if (_rfEnabled && {_rfSide in [west, east]} && {_rfIdx >= 0}) then {
			_rfLogik = (_rfSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _rfLogik) then {
				_rfCmd = (_rfSide) Call WFBE_CO_FNC_GetCommanderTeam; _rfHuman = false;
				if (!isNull _rfCmd) then {if (isPlayer (leader _rfCmd)) then {_rfHuman = true}};
				_rfTeams = _rfLogik getVariable ["wfbe_teams", []];
				_rfAuth = (!isNull _rfPlayer) && {alive _rfPlayer} && {isPlayer _rfPlayer} && {!isNull _rfCmd} && {side (group _rfPlayer) == _rfSide} && {group _rfPlayer == _rfCmd}; //--- caller must be IN this side commander team
				if (_rfHuman && {_rfAuth} && {_rfIdx < (count _rfTeams)}) then {
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
									//--- REFIT COST TOGGLE (Ray 2026-07-04): WFBE_C_CMD_REFIT_COST default 0 = FREE. When the flag is
									//--- off (<= 0) the player-commander REFIT verb charges nothing and is NEVER blocked by low funds:
									//--- skip the treasury debit AND the affordability gate, issue the top-up unconditionally. When the
									//--- flag is > 0 the legacy behaviour is restored (flat WFBE_C_AICOM_TOPUP_UNIT_COST per missing man,
									//--- debited up front, refit denied if the war chest cannot cover it). Cooldown + mechanics unchanged.
									_rfCostOn = (missionNamespace getVariable ["WFBE_C_CMD_REFIT_COST", 0]) > 0;
									_rfCost   = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_UNIT_COST", 300];
									_rfCharge = _rfCost * _rfMissing;
									_rfFunds  = (_rfSide) Call GetAICommanderFunds;
									_rfAfford = true;
									if (_rfCostOn) then {_rfAfford = (_rfFunds >= _rfCharge)};
									if (_rfAfford) then {
										_rfChargedAmt = 0;
										if (_rfCostOn) then {[_rfSide, -_rfCharge] Call ChangeAICommanderFunds; _rfChargedAmt = _rfCharge};
										//--- fable/aicom-topup-refund-on-stale: store the ACTUAL charged amount (0 on the
										//--- free/cost-off path) as element 4 so the consumer (Common_RunCommanderTeam.sqf)
										//--- can refund it exactly if this request ages out unfilled, mirroring Produce.sqf.
										_rfTeam setVariable ["wfbe_aicom_topup_req", [_rfMissing, getPosATL (leader _rfTeam), _rfCls, _rfNow, _rfChargedAmt], true];
										_rfTeam setVariable ["wfbe_aicom_topup_stamp", _rfNow, false];
										diag_log ("AICOM2|v1|ORDER|aicom-refit|" + str _rfSide + "|" + str (round (time / 60)) + "|idx=" + str _rfIdx + "|missing=" + str _rfMissing + "|cost=" + str _rfChargedAmt);
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
					diag_log ("AICOM2|v1|ORDER|aicom-refit|REJECT|" + str _rfSide + "|human=" + str _rfHuman + "|auth=" + str _rfAuth + "|idx=" + str _rfIdx + "|teams=" + str (count _rfTeams));
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
		private ["_hdEnabled","_hdSide","_hdIdx","_hdLogik","_hdCmd","_hdHuman","_hdTeams","_hdTeam","_hdSID","_hdTown","_hdBest","_hdSecs","_hdPlayer","_hdAuth"];
		_hdEnabled = (missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0;
		_hdSide = _args select 1;
		_hdIdx  = -1;
		if (count _args >= 3) then {private "_hdRaw"; _hdRaw = _args select 2; if (!isNil "_hdRaw" && {typeName _hdRaw == "SCALAR"}) then {_hdIdx = _hdRaw}};
		_hdPlayer = objNull; if (count _args >= 4) then {_hdPlayer = _args select 3}; //--- card wasp-aicom-disband-no-sender-identity: acting player appended by GUI_Menu_Command.sqf
		if (_hdEnabled && {_hdSide in [west, east]} && {_hdIdx >= 0}) then {
			_hdLogik = (_hdSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _hdLogik) then {
				_hdCmd = (_hdSide) Call WFBE_CO_FNC_GetCommanderTeam; _hdHuman = false;
				if (!isNull _hdCmd) then {if (isPlayer (leader _hdCmd)) then {_hdHuman = true}};
				_hdTeams = _hdLogik getVariable ["wfbe_teams", []];
				_hdAuth = (!isNull _hdPlayer) && {alive _hdPlayer} && {isPlayer _hdPlayer} && {!isNull _hdCmd} && {side (group _hdPlayer) == _hdSide} && {group _hdPlayer == _hdCmd}; //--- caller must be IN this side commander team
				if (_hdHuman && {_hdAuth} && {_hdIdx < (count _hdTeams)}) then {
					_hdTeam = _hdTeams select _hdIdx;
					if (!isNull _hdTeam && {({alive _x} count units _hdTeam) > 0} && {!isPlayer (leader _hdTeam)}) then {
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
					diag_log ("AICOM2|v1|ORDER|aicom-hold|REJECT|" + str _hdSide + "|human=" + str _hdHuman + "|auth=" + str _hdAuth + "|idx=" + str _hdIdx + "|teams=" + str (count _hdTeams));
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
	case "aicom-town-nudge": {
		//--- COMMAND V2 pillar (a) - SOFT WEIGHTED TOWN SUGGESTION (design docs/design/COMMAND-V2-NUDGE-SYSTEM-DESIGN.md section 3).
		//--- Deliberately NOT aicom-focus: focus is a commander-only HARD override that pins the fist every tick. This verb
		//--- appends a TTL-decayed vote to a bounded per-side ring which AI_Commander_Allocate.sqf folds into its town score
		//--- as one additive term. The AI commander stays the commander: the nudge can break a near-tie, never force a target.
		//--- Payload ["aicom-town-nudge", side, town, player, scope] with scope in {"side","team"}.
		//--- Per-case validation audit (design section 7): live player on the claimed side (1); per-UID cooldown key (2); never pins
		//--- or overrides a commander order (3 - we only write our own ring); payload shape/type checked incl. town-registry
		//--- membership (4); accept AND reject telemetry, no silent drop (5); whole case behind a default-0 flag (6).
		private ["_tnSide","_tnTown","_tnPlayer","_tnScope","_tnLogik","_tnNow","_tnCd","_tnUID","_tnKey","_tnLast","_tnSID","_tnRing","_tnKeep","_tnTtl","_tnMax","_tnTeam","_tnRange","_tnBest","_tnScopeVal","_tnAgg","_tnDrop","_tnTrim","_tnRej"];
		if ((missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE", 0]) > 0 && {count _args >= 5}) then {
			_tnSide   = _args select 1;
			_tnTown   = _args select 2;
			_tnPlayer = _args select 3;
			_tnScope  = _args select 4;
			_tnRej = "";
			if (!(_tnSide in [west, east])) then {_tnRej = "badside"};
			if (_tnRej == "" && {isNil "_tnTown"}) then {_tnRej = "niltown"};
			if (_tnRej == "" && {typeName _tnTown != "OBJECT"}) then {_tnRej = "badtown"};
			if (_tnRej == "" && {isNull _tnTown}) then {_tnRej = "nulltown"};
			//--- town-registry membership: the client may only nudge an object the mission actually registered as a town.
			if (_tnRej == "" && {isNil "towns"}) then {_tnRej = "notownlist"};
			if (_tnRej == "" && {!(_tnTown in towns)}) then {_tnRej = "unregistered"};
			if (_tnRej == "" && {typeName _tnScope != "STRING"}) then {_tnRej = "badscope"};
			if (_tnRej == "" && {!(_tnScope in ["side","team"])}) then {_tnRej = "badscope"};
			if (_tnRej == "" && {isNil "_tnPlayer"}) then {_tnRej = "nilplayer"};
			if (_tnRej == "" && {isNull _tnPlayer}) then {_tnRej = "nullplayer"};
			if (_tnRej == "" && {!(alive _tnPlayer)}) then {_tnRej = "deadplayer"};
			if (_tnRej == "" && {!(isPlayer _tnPlayer)}) then {_tnRej = "notaplayer"};
			if (_tnRej == "" && {(side (group _tnPlayer)) != _tnSide}) then {_tnRej = "wrongside"};
			if (_tnRej != "") then {
				diag_log ("AICOM2|v1|ORDER|TOWN_NUDGE|reject|" + str _tnSide + "|why=" + _tnRej);
			} else {
				_tnLogik = (_tnSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _tnLogik) then {
					_tnSID = (_tnSide) Call WFBE_CO_FNC_GetSideID;
					_tnNow = time;
					_tnUID = getPlayerUID _tnPlayer; if (isNil "_tnUID" || {_tnUID == ""}) then {_tnUID = str _tnPlayer};
					//--- you cannot suggest a town you already hold into the OFFENSIVE fist (it is not a capture candidate).
					if ((_tnTown getVariable ["sideID", -1]) == _tnSID) then {
						diag_log ("AICOM2|v1|ORDER|TOWN_NUDGE|reject|" + str _tnSide + "|uid=" + _tnUID + "|why=ownTown|town=" + (_tnTown getVariable ["name", "?"]));
						[_tnPlayer, "HandleSpecial", ["cmdv2-receipt", ["We already hold " + (_tnTown getVariable ["name", "that town"]) + " - suggest an enemy or neutral town."]]] Call WFBE_CO_FNC_SendToClient;
					} else {
						_tnCd   = missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE_COOLDOWN", 90];
						_tnKey  = "wfbe_cmd_townnudge_" + _tnUID;
						_tnLast = _tnLogik getVariable [_tnKey, -1e9];
						if (_tnCd > 0 && {(_tnNow - _tnLast) < _tnCd}) then {
							diag_log ("AICOM2|v1|ORDER|TOWN_NUDGE|cooldown|" + str _tnSide + "|uid=" + _tnUID + "|cdLeft=" + str (round (_tnCd - (_tnNow - _tnLast))));
							[_tnPlayer, "HandleSpecial", ["cmdv2-receipt", ["Town suggestion on cooldown - " + str (round (_tnCd - (_tnNow - _tnLast))) + "s left."]]] Call WFBE_CO_FNC_SendToClient;
						} else {
							//--- SCOPE. "side" biases the whole fist scorer. "team" resolves ONE nearby AI-led team and biases only
							//--- that team's target pick, so a squad can pull THEIR attached team without redirecting the side.
							_tnScopeVal = "side";
							_tnTeam = grpNull;
							if (_tnScope == "team") then {
								_tnRange = missionNamespace getVariable ["WFBE_C_CMD_NUDGE_RANGE", 1500];
								_tnBest  = _tnRange;
								{
									//--- CAPTURE the outer _x FIRST: the inner units forEach below permanently rebinds it.
									//--- Guard isNil "_x" BEFORE the bare read - a nil hole in wfbe_teams must never be dereferenced.
									private ["_tnTm","_alv","_d"];
									if (!isNil "_x") then {
										_tnTm = _x;
										if (!isNull _tnTm && {!isPlayer (leader _tnTm)}) then {
											_alv = {alive _x} count (units _tnTm);
											if (_alv > 0 && {!isNull (leader _tnTm)}) then {
												_d = _tnPlayer distance (leader _tnTm);
												if (_d < _tnBest) then {_tnBest = _d; _tnTeam = _tnTm};
											};
										};
									};
								} forEach (_tnLogik getVariable ["wfbe_teams", []]);
								if (!isNull _tnTeam) then {_tnScopeVal = _tnTeam};
							};
							if (_tnScope == "team" && {isNull _tnTeam}) then {
								diag_log ("AICOM2|v1|ORDER|TOWN_NUDGE|reject|" + str _tnSide + "|uid=" + _tnUID + "|why=noTeamInRange|range=" + str (missionNamespace getVariable ["WFBE_C_CMD_NUDGE_RANGE", 1500]));
								[_tnPlayer, "HandleSpecial", ["cmdv2-receipt", ["No AI team close enough to take a team suggestion."]]] Call WFBE_CO_FNC_SendToClient;
							} else {
								//--- RING WRITE: prune expired records and this issuer's previous vote for the same town (refresh,
								//--- never stack), append, then bound to WFBE_C_CMD_TOWN_NUDGE_RING by dropping the OLDEST entries.
								_tnTtl  = missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE_TTL", 240];
								_tnMax  = missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE_RING", 16];
								_tnRing = _tnLogik getVariable ["wfbe_aicom_town_nudges", []];
								_tnKeep = [];
								{
									if (!isNil "_x") then {
										if ((typeName _x == "ARRAY") && {(count _x) >= 6}) then {
											private ["_keep"];
											_keep = ((_tnNow - (_x select 5)) < _tnTtl);
											if (_keep && {(_x select 3) == _tnUID} && {(_x select 2) == _tnTown}) then {_keep = false};
											if (_keep) then {_tnKeep set [count _tnKeep, _x]};
										};
									};
								} forEach _tnRing;
								//--- unified nudge record: [type, scope, target, issuerUID, priority, t0]. priority 1 = a normal soft
								//--- player vote (the field is carried so a future commander-issued weighting needs no shape change).
								_tnKeep set [count _tnKeep, ["town", _tnScopeVal, _tnTown, _tnUID, 1, _tnNow]];
								if ((count _tnKeep) > _tnMax) then {
									private ["_i"];
									_tnDrop = (count _tnKeep) - _tnMax;
									_tnTrim = [];
									for "_i" from _tnDrop to ((count _tnKeep) - 1) do {_tnTrim set [count _tnTrim, _tnKeep select _i]};
									_tnKeep = _tnTrim;
								};
								//--- server-local: the Allocator that consumes this runs on the SERVER, so no publicVariable and no
								//--- extra net traffic (budget conservation). Same for the cooldown stamp below.
								_tnLogik setVariable ["wfbe_aicom_town_nudges", _tnKeep];
								_tnLogik setVariable [_tnKey, _tnNow];
								_tnAgg = [_tnTown, _tnKeep, _tnScopeVal] Call WFBE_CO_FNC_TownNudgeWeight;
								diag_log ("AICOM2|v1|ORDER|TOWN_NUDGE|accept|" + str _tnSide + "|" + str (round (time / 60)) + "|town=" + (_tnTown getVariable ["name", "?"]) + "|scope=" + _tnScope + "|uid=" + _tnUID + "|agg=" + str _tnAgg + "|ring=" + str (count _tnKeep));
								[_tnPlayer, "HandleSpecial", ["cmdv2-receipt", ["Suggested " + (_tnTown getVariable ["name", "target"]) + " to the AI commander (" + _tnScope + " scope). It weighs your suggestion; it is not an order."]]] Call WFBE_CO_FNC_SendToClient;
							};
						};
					};
				};
			};
		};
	};
	case "aicom-team-doctrine": {
		//--- COMMAND V2 pillar (b), PER-TEAM scope (design section 4.2). Owner decision packet 2026-07-18 item 3: there is
		//--- deliberately NO leader-only gate - ANY eligible nearby player may nudge a team's doctrine, held in check by
		//--- an anti-spam per-UID cooldown, a proximity gate and a receipt back to the issuer. The stamp is ADVISORY and
		//--- TTL'd: it never manual-pins, so relief / last-stand / HQ-strike allocator decisions still win.
		//--- Payload ["aicom-team-doctrine", side, teamIndex, stance, player], stance in {aggressive,defensive,garrison}.
		private ["_tdSide","_tdIdx","_tdStance","_tdPlayer","_tdLogik","_tdTeams","_tdTeam","_tdNow","_tdCd","_tdUID","_tdKey","_tdLast","_tdRange","_tdRej"];
		if ((missionNamespace getVariable ["WFBE_C_CMD_TEAM_DOCTRINE", 0]) > 0 && {count _args >= 5}) then {
			_tdSide   = _args select 1;
			_tdIdx    = _args select 2;
			_tdStance = _args select 3;
			_tdPlayer = _args select 4;
			_tdRej = "";
			if (!(_tdSide in [west, east])) then {_tdRej = "badside"};
			if (_tdRej == "" && {isNil "_tdIdx"}) then {_tdRej = "nilidx"};
			if (_tdRej == "" && {typeName _tdIdx != "SCALAR"}) then {_tdRej = "badidx"};
			if (_tdRej == "" && {typeName _tdStance != "STRING"}) then {_tdRej = "badstance"};
			if (_tdRej == "" && {!(_tdStance in ["aggressive","defensive","garrison"])}) then {_tdRej = "badstance"};
			if (_tdRej == "" && {isNil "_tdPlayer"}) then {_tdRej = "nilplayer"};
			if (_tdRej == "" && {isNull _tdPlayer}) then {_tdRej = "nullplayer"};
			if (_tdRej == "" && {!(alive _tdPlayer)}) then {_tdRej = "deadplayer"};
			if (_tdRej == "" && {!(isPlayer _tdPlayer)}) then {_tdRej = "notaplayer"};
			if (_tdRej == "" && {(side (group _tdPlayer)) != _tdSide}) then {_tdRej = "wrongside"};
			if (_tdRej != "") then {
				diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|reject|" + str _tdSide + "|why=" + _tdRej);
			} else {
				_tdLogik = (_tdSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _tdLogik) then {
					_tdTeams = _tdLogik getVariable ["wfbe_teams", []];
					_tdNow   = time;
					_tdUID   = getPlayerUID _tdPlayer; if (isNil "_tdUID" || {_tdUID == ""}) then {_tdUID = str _tdPlayer};
					_tdTeam  = grpNull;
					if (_tdIdx >= 0 && {_tdIdx < (count _tdTeams)}) then {_tdTeam = _tdTeams select _tdIdx};
					_tdRange = missionNamespace getVariable ["WFBE_C_CMD_NUDGE_RANGE", 1500];
					if (isNull _tdTeam) then {
						diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|" + _tdStance + "|reject|" + str _tdSide + "|uid=" + _tdUID + "|why=badTeamIdx|idx=" + str _tdIdx + "|teams=" + str (count _tdTeams));
					} else {
						if (isPlayer (leader _tdTeam)) then {
							//--- a player-led squad is not an AI team; never let a nudge write doctrine onto another human's group.
							diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|" + _tdStance + "|reject|" + str _tdSide + "|uid=" + _tdUID + "|why=playerLedTeam|idx=" + str _tdIdx);
						} else {
							if (isNull (leader _tdTeam) || {(_tdPlayer distance (leader _tdTeam)) > _tdRange}) then {
								//--- ELIGIBILITY (owner 2026-07-18): "any eligible NEARBY player" - eligibility is proximity, not rank.
								diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|" + _tdStance + "|reject|" + str _tdSide + "|uid=" + _tdUID + "|why=tooFar|idx=" + str _tdIdx + "|range=" + str _tdRange);
								[_tdPlayer, "HandleSpecial", ["cmdv2-receipt", ["That AI team is too far away to take a doctrine suggestion."]]] Call WFBE_CO_FNC_SendToClient;
							} else {
								_tdCd   = missionNamespace getVariable ["WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN", 90];
								_tdKey  = "wfbe_cmd_doctrine_" + _tdUID;
								_tdLast = _tdLogik getVariable [_tdKey, -1e9];
								if (_tdCd > 0 && {(_tdNow - _tdLast) < _tdCd}) then {
									diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|" + _tdStance + "|cooldown|" + str _tdSide + "|uid=" + _tdUID + "|cdLeft=" + str (round (_tdCd - (_tdNow - _tdLast))));
									[_tdPlayer, "HandleSpecial", ["cmdv2-receipt", ["Doctrine suggestion on cooldown - " + str (round (_tdCd - (_tdNow - _tdLast))) + "s left."]]] Call WFBE_CO_FNC_SendToClient;
								} else {
									_tdLogik setVariable [_tdKey, _tdNow];
									//--- [stance, t0, issuerUID]. Broadcast so an HC-delegated team sees the same stamp the server wrote
									//--- (two-HC locality); this is one setVariable per accepted nudge, rate-limited by the cooldown above.
									_tdTeam setVariable ["wfbe_aicom_team_doctrine", [_tdStance, _tdNow, _tdUID], true];
									diag_log ("AICOM2|v1|ORDER|TEAM_DOCTRINE|" + _tdStance + "|accept|" + str _tdSide + "|" + str (round (time / 60)) + "|idx=" + str _tdIdx + "|uid=" + _tdUID + "|dist=" + str (round (_tdPlayer distance (leader _tdTeam))));
									[_tdPlayer, "HandleSpecial", ["cmdv2-receipt", ["Suggested " + _tdStance + " doctrine to AI team " + str _tdIdx + ". Advisory only - the AI commander may still retask it."]]] Call WFBE_CO_FNC_SendToClient;
								};
							};
						};
					};
				};
			};
		};
	};
	case "aicom-support-air": {
		//--- COMMAND V2 pillar (c) - REQUEST AN AI HELI TEAM AS SUPPORT (design section 5).
		//--- Owner decision packet 2026-07-18 item 1: this is a FREE LOAN of an airframe the side ALREADY
		//--- OWNS. No requisition fee is charged, so there is no refund path to audit; abuse is bounded by
		//--- the per-UID cooldown, the side-wide concurrency cap, one-grant-per-UID, and full telemetry.
		//--- Payload ["aicom-support-air", side, player, playerPos, kind].
		//---   kind "transport" -> a troop-carrying heli (transportSoldier > 0) escorts/stands off.
		//---   kind "cas-heli"  -> a gunship (transportSoldier == 0) orbits and answers DIRECT threats.
		//---   kind "cas-jet"/"transport-jet" -> PARSED AND REJECTED. WFBE_C_CMD_SUPPORT_JET is reserved
		//---   and there is NO jet grant path in this build; the explicit reject exists so the UI can grey
		//---   the option instead of silently dropping the request (design section 5.1).
		private ["_saSide","_saPlayer","_saPos","_saKind","_saLogik","_saNow","_saCd","_saUID","_saKey","_saLast","_saTeams","_saTeam","_saHull","_saMax","_saActive","_saRej","_saWantTrans","_saBestD","_saRange","_saRecallUntil","_saMine"];
		if ((missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR", 0]) > 0 && {count _args >= 5}) then {
			_saSide   = _args select 1;
			_saPlayer = _args select 2;
			_saPos    = _args select 3;
			_saKind   = _args select 4;
			_saWantTrans = false; //--- A2/OA: keep the nested team/unit scan comparison type-safe before kind derivation.
			_saRej = "";
			if (!(_saSide in [west, east])) then {_saRej = "badside"};
			if (_saRej == "" && {isNil "_saPlayer"}) then {_saRej = "nilplayer"};
			if (_saRej == "" && {isNull _saPlayer}) then {_saRej = "nullplayer"};
			if (_saRej == "" && {!(alive _saPlayer)}) then {_saRej = "deadplayer"};
			if (_saRej == "" && {!(isPlayer _saPlayer)}) then {_saRej = "notaplayer"};
			if (_saRej == "" && {(side (group _saPlayer)) != _saSide}) then {_saRej = "wrongside"};
			if (_saRej == "" && {typeName _saPos != "ARRAY"}) then {_saRej = "badpos"};
			if (_saRej == "" && {(count _saPos) < 2}) then {_saRej = "badpos"};
			//--- server-side proximity sanity check: never trust a client-supplied position (same guard the
			//--- ground aicom-support case applies).
			if (_saRej == "" && {(_saPlayer distance _saPos) >= 200}) then {_saRej = "posmismatch"};
			if (_saRej == "" && {typeName _saKind != "STRING"}) then {_saRej = "badkind"};
			if (_saRej == "" && {_saKind in ["cas-jet","transport-jet"]}) then {_saRej = "jet-disabled"};
			if (_saRej == "" && {!(_saKind in ["transport","cas-heli"])}) then {_saRej = "badkind"};
			if (_saRej != "") then {
				diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|REJECT|" + str _saSide + "|why=" + _saRej + "|kind=" + (if (typeName _saKind == "STRING") then {_saKind} else {"?"}));
				if (_saRej == "jet-disabled" && {!isNil "_saPlayer"} && {!isNull _saPlayer} && {isPlayer _saPlayer}) then {
					[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["Fixed-wing support is not implemented in this build."]]] Call WFBE_CO_FNC_SendToClient;
				};
			} else {
				_saLogik = (_saSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _saLogik) then {
					_saNow = time;
					_saUID = getPlayerUID _saPlayer; if (isNil "_saUID" || {_saUID == ""}) then {_saUID = str _saPlayer};
					_saCd  = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_COOLDOWN", 180];
					_saKey = "wfbe_cmd_supportair_" + _saUID;
					_saLast = _saLogik getVariable [_saKey, -1e9];
					diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|REQUEST|" + str _saSide + "|" + str (round (time / 60)) + "|kind=" + _saKind + "|uid=" + _saUID);
					_saRecallUntil = _saLogik getVariable ["wfbe_cmd_support_recall_until", -1e9];
					_saMax    = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE", 1];
					_saActive = _saLogik getVariable ["wfbe_cmd_support_active", 0];
					if (_saCd > 0 && {(_saNow - _saLast) < _saCd}) then {
						diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|REJECT|" + str _saSide + "|uid=" + _saUID + "|why=cooldown|cdLeft=" + str (round (_saCd - (_saNow - _saLast))));
						[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["Heli support on cooldown - " + str (round (_saCd - (_saNow - _saLast))) + "s left."]]] Call WFBE_CO_FNC_SendToClient;
					} else {
						if (_saNow < _saRecallUntil) then {
							//--- HYSTERESIS (owner 2026-07-18 item 5): the AI just recalled an airframe for a
							//--- last-stand / HQ emergency. Refuse to re-lend one until the dwell window closes.
							diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|NONE|" + str _saSide + "|uid=" + _saUID + "|why=recall-hysteresis|left=" + str (round (_saRecallUntil - _saNow)));
							_saLogik setVariable [_saKey, _saNow];
							[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["The AI commander needs every airframe right now - no support available."]]] Call WFBE_CO_FNC_SendToClient;
						} else {
							if (_saActive >= _saMax) then {
								diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|NONE|" + str _saSide + "|uid=" + _saUID + "|why=sideCapReached|active=" + str _saActive + "|max=" + str _saMax);
								_saLogik setVariable [_saKey, _saNow];   //--- start the cooldown on NONE too, so a denied request cannot be re-spammed.
								[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["No heli support free - another squad already has it."]]] Call WFBE_CO_FNC_SendToClient;
							} else {
								//--- SEARCH: this side's AI teams for an idle one flying a live, crewed, movable heli of
								//--- the requested kind. transportSoldier is the codebase-wide transport-vs-gunship test.
								//--- One grant per UID is enforced by rejecting any team already stamped with a holder,
								//--- plus the explicit _saMine scan below.
								_saWantTrans = (_saKind == "transport");
								//--- Defensive recovery: a nested forEach must never compare transportSoldier to an undefined value.
								if (isNil "_saWantTrans") then {_saWantTrans = false; diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|WARNING|" + str _saSide + "|uid=" + _saUID + "|why=wantTransportUndefined|kind=" + _saKind)};
								_saRange = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_RANGE", 6000];
								_saTeams = _saLogik getVariable ["wfbe_teams", []];
								_saTeam  = grpNull; _saHull = objNull; _saBestD = _saRange; _saMine = false;
								{
									//--- CAPTURE the outer _x FIRST: the inner units forEach below permanently rebinds it.
									private ["_tm","_alv","_busy","_hol","_h","_str","_ral","_hld","_d"];
									//--- Guard isNil "_x" BEFORE the bare read - a nil hole in wfbe_teams must never be dereferenced.
									//--- The old `_tm = _x` assignment threw on a nil slot itself, so the isNil "_tm" test below it was
									//--- unreachable. Identical guard-first shape to the aicom-town-nudge team scan above.
									if (!isNil "_x") then {
										_tm = _x;
										if (!isNull _tm && {!isPlayer (leader _tm)}) then {
											_alv = {alive _x} count (units _tm);
											if (_alv > 0) then {
												_busy = false;
												_hol = _tm getVariable "wfbe_aicom_support_holder";
												if (!isNil "_hol") then {
													_busy = true;
													//--- already lent out: if it is lent to THIS player, remember that so we answer
													//--- "you already have one" instead of a generic NONE.
													if ((typeName _hol == "ARRAY") && {(count _hol) >= 1}) then {
														if ((_hol select 0) == _saPlayer) then {_saMine = true};
													};
												};
												if (!_busy) then {_str = _tm getVariable "wfbe_aicom_strike"; _busy = (!isNil "_str" && {_str})};
												if (!_busy) then {_ral = _tm getVariable "wfbe_aicom_rallying"; _busy = (!isNil "_ral" && {_ral})};
												if (!_busy) then {_hld = _tm getVariable "wfbe_aicom_holding_town"; _busy = (!isNil "_hld" && {!isNull _hld})};
												if (!_busy) then {
													_h = objNull;
													{
														if (isNull _h && {alive _x} && {(vehicle _x) != _x} && {(vehicle _x) isKindOf "Helicopter"} && {canMove (vehicle _x)}
														    && {!isNull (driver (vehicle _x))} && {alive (driver (vehicle _x))}
														    && {if (_saWantTrans) then {(getNumber (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "transportSoldier")) > 0} else {(getNumber (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "transportSoldier")) <= 0}}) then {   //--- BOOLCMP fix: boolean == is an A2 runtime error, was live-firing (wave0722g)
															_h = vehicle _x;
														};
													} forEach (units _tm);
													if (!isNull _h) then {
														_d = _h distance _saPos;
														if (_d < _saBestD) then {_saBestD = _d; _saTeam = _tm; _saHull = _h};
													};
												};
											};
										};
									};
								} forEach _saTeams;
								if (_saMine) then {
									diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|REJECT|" + str _saSide + "|uid=" + _saUID + "|why=alreadyHolding");
									[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["You already have a support heli on station."]]] Call WFBE_CO_FNC_SendToClient;
								} else {
									if (isNull _saTeam) then {
										diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|NONE|" + str _saSide + "|uid=" + _saUID + "|kind=" + _saKind + "|why=noEligibleHeli|range=" + str _saRange);
										_saLogik setVariable [_saKey, _saNow];   //--- cooldown starts on NONE as well (design section 5.2 step 1).
										[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["No " + (if (_saWantTrans) then {"transport"} else {"gunship"}) + " heli is available for support."]]] Call WFBE_CO_FNC_SendToClient;
									} else {
										//--- GRANT. Book the slot + cooldown, stamp the holder, and hand the lifecycle to the
										//--- escort worker. No funds move in either direction: the loan is free by owner ruling.
										_saLogik setVariable [_saKey, _saNow];
										_saLogik setVariable ["wfbe_cmd_support_active", _saActive + 1];
										_saTeam setVariable ["wfbe_aicom_support_holder", [_saPlayer, _saKind, _saNow], true];
										_saTeam setVariable ["wfbe_aicom_support_release", nil, true];
										diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|GRANT|" + str _saSide + "|" + str (round (time / 60)) + "|uid=" + _saUID + "|kind=" + _saKind + "|heli=" + (typeOf _saHull) + "|ferry=" + str (round _saBestD));
										[_saTeam, _saHull, _saPlayer, _saKind, _saSide, _saUID] Spawn WFBE_SE_FNC_CmdSupportAir;
											diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|FULFIL|" + str _saSide + "|uid=" + _saUID + "|kind=" + _saKind + "|heli=" + (typeOf _saHull) + "|state=worker-spawned");
										[_saPlayer, "HandleSpecial", ["cmdv2-receipt", ["Support heli inbound (" + _saKind + "). It stays on station for " + str (missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_TTL", 300]) + "s or until you release it."]]] Call WFBE_CO_FNC_SendToClient;
									};
								};
							};
						};
					};
				};
			};
		};
	};
	case "aicom-support-air-release": {
		//--- COMMAND V2 pillar (c): the holder hands the airframe back early. We only STAMP the request;
		//--- the escort worker sees it on its next interval and runs the single shared RETURN path, so
		//--- there is exactly one place that un-books the grant and flies the heli home (no duplicate
		//--- teardown, no race with the worker). Only the actual holder may release their own grant.
		private ["_srSide","_srPlayer","_srLogik","_srTeams","_srFound"];
		if ((missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR", 0]) > 0 && {count _args >= 3}) then {
			_srSide   = _args select 1;
			_srPlayer = _args select 2;
			if (_srSide in [west, east] && {!isNil "_srPlayer"} && {!isNull _srPlayer} && {isPlayer _srPlayer} && {(side (group _srPlayer)) == _srSide}) then {
				_srLogik = (_srSide) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _srLogik) then {
					_srTeams = _srLogik getVariable ["wfbe_teams", []];
					_srFound = false;
					{
						private ["_tm","_hol"];
						_tm = _x;
						if (!_srFound && {!isNil "_tm"} && {!isNull _tm}) then {
							_hol = _tm getVariable "wfbe_aicom_support_holder";
							if (!isNil "_hol" && {typeName _hol == "ARRAY"} && {(count _hol) >= 1} && {(_hol select 0) == _srPlayer}) then {
								_tm setVariable ["wfbe_aicom_support_release", true, true];
								_srFound = true;
							};
						};
					} forEach _srTeams;
					if (_srFound) then {
						diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|RELEASE|" + str _srSide + "|" + str (round (time / 60)) + "|uid=" + (getPlayerUID _srPlayer) + "|reason=player-request");
					} else {
						diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|REJECT|" + str _srSide + "|uid=" + (getPlayerUID _srPlayer) + "|why=noGrantHeld");
						[_srPlayer, "HandleSpecial", ["cmdv2-receipt", ["You have no support heli to release."]]] Call WFBE_CO_FNC_SendToClient;
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
		Private ["_csideID","_cteam","_clogik","_caicomList","_caicomNew","_cteams","_cregistered"];
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
				_cteams = _clogik getVariable ["wfbe_teams", []];
				_cregistered = false;
				{
					if (_x == _cteam) exitWith {_cregistered = true};
				} forEach _cteams;
				if (_cregistered) then {
					_clogik setVariable ["wfbe_teams", _cteams - [_cteam], true];
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
					//--- Smallest angular distance old<->new heading (0..180). SQF % keeps the
					//--- dividend sign, so normalise into 0..360 BEFORE the 180 fold or a small
					//--- change across the 0/360 (north) boundary reads as ~360 and PV-spams.
					_hdelta = (_hdir - _hold) % 360;
					if (_hdelta < 0) then {_hdelta = _hdelta + 360};
					if (_hdelta > 180) then {_hdelta = 360 - _hdelta};
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
		Private ["_rSideID","_rSide","_rCost","_rType","_rUD","_rRealCost","_rCeiling","_rClamped"];
		_rSideID = _args select 1;
		_rCost   = _args select 2;
		//--- D4-FIX(c): hull type (4th payload element) lets the server RE-DERIVE the real build price from its own
		//--- unit-data table (same QUERYUNITPRICE lookup Common_RunCommanderTeam.sqf uses) instead of trusting the
		//--- network-supplied dollar figure. Count-guarded: an old/short payload (pre-fix HC or a forged short array)
		//--- degrades to the flat fallback ceiling below, never to unlimited trust.
		_rType   = if (count _args > 3) then {_args select 3} else {""};
		_rUD     = if (typeName _rType == "STRING" && {_rType != ""}) then {missionNamespace getVariable [_rType, []]} else {[]};
		_rRealCost = 0;
		if (typeName _rUD == "ARRAY" && {(count _rUD) > QUERYUNITPRICE}) then {_rRealCost = _rUD select QUERYUNITPRICE};
		_rSide   = (_rSideID) Call WFBE_CO_FNC_GetSideFromID;
		//--- _rSide is a Side (not an Object) so isNull is the wrong test and throws; validate it is a real combatant treasury side instead.
		if ((_rSide in [east,west,resistance]) && {_rCost > 0}) then {
			//--- resolved real price wins outright; an unresolvable type falls back to a flat, generous ceiling (never
			//--- zero) so a lookup miss never silently denies a legitimate refund - it just bounds it.
			_rCeiling = if (_rRealCost > 0) then {_rRealCost} else {missionNamespace getVariable ["WFBE_C_AICOM_HELI_REFUND_MAX", 40000]};
			_rClamped = (_rCost min _rCeiling) max 0;
			[_rSide, _rClamped] Call ChangeAICommanderFunds;
			["INFORMATION", Format ["Server_HandleSpecial.sqf: aicom-heli-refunded $%1 (claimed %2, real %3, type %4) to [%5] AI-commander treasury (transport flew off-map).", _rClamped, _rCost, _rRealCost, _rType, str _rSide]] Call WFBE_CO_FNC_AICOMLog;
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
	//--- fable/patrol-reimagine (owner 2026-07-28): the convoy payout case that lived here is
	//--- REMOVED with the patrol money rewards. Its replacement is the T3/T4 off-map air pass:
	//--- server-authoritative chance roll + per-side cooldown, then Server_PatrolAirPass flies
	//--- one (L3) or two (L4) attack aircraft in from off-map for a single pass over the town
	//--- and exits them via the nearest map edge. Sender: Common_RunSidePatrol.sqf arrival hook.
	case "sidepatrol-airpass": {
		Private ["_apSideID","_apTown","_apLvl","_apSide","_apLast","_apCd"];
		_apSideID = _args select 1;
		_apTown   = _args select 2;
		_apLvl    = if (count _args > 3) then {_args select 3} else {3};
		_apSide   = (_apSideID) Call WFBE_CO_FNC_GetSideFromID;
		if ((missionNamespace getVariable ["WFBE_C_PATROL_AIR_TIER", 0]) > 0
			&& {!isNull _apTown}
			&& {(_apSide == west) || {_apSide == east}}
			&& {!isNil "WFBE_SE_FNC_PatrolAirPass"}) then {
			_apCd   = missionNamespace getVariable ["WFBE_C_PATROL_AIR_COOLDOWN", 300];
			_apLast = missionNamespace getVariable [Format ["wfbe_patrolair_last_%1", str _apSide], -99999];
			if ((time - _apLast) >= _apCd && {(random 1) < (missionNamespace getVariable ["WFBE_C_PATROL_AIR_CHANCE", 0.35])}) then {
				missionNamespace setVariable [Format ["wfbe_patrolair_last_%1", str _apSide], time];
				[_apSide, _apSideID, _apTown, _apLvl] Spawn WFBE_SE_FNC_PatrolAirPass;
			};
		};
	};
	//--- fable/cleanup-locality-2 (PVF-class hunt, HIGH): server-side registration for PLAYER-placed
	//--- mines. DropRPG.sqf's Fired EH runs on the placing player's CLIENT where the `mines` global
	//--- (seeded only by the server-only mines_cleaner.sqf) is nil - so on every dedicated server the
	//--- registration silently no-oped and player mines were never age-reaped. typeOf-validated:
	//--- worst a forged dispatch can do is enroll a real mine for its normal timed deletion.
	case "register-mine": {
		Private ["_rmMine"];
		_rmMine = _args select 1;
		if (!isNil "mines" && {!isNull _rmMine} && {(typeOf _rmMine) in ["Mine","MineE"]}) then {
			mines set [count mines, [_rmMine, time]];
		};
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
	//--- wiring-sweep 2026-07-22: dead "track-playerobject" case removed - zero senders anywhere in the
	//--- tree, so its only consumer (the WFBE_CLIENT_%1_OBJECTS disconnect cleanup in
	//--- Server_OnPlayerDisconnected.sqf) could never run either; removed together.
	case "repair-camp": {
		Private ["_camp_sideID","_logic","_repairSideID","_townModel","_campXY"];
		_logic = _args select 1;
		_repairSideID = _args select 2;

		//--- harden-repair-camp (2026-07-25): reentrancy guard, mirrors Server_MHQRepair.sqf's
		//--- precedent (PR #1361) - check+set BEFORE the alive read so two near-simultaneous
		//--- requests for the same camp cannot both pass the alive-check and double-spawn a bunker.
		//--- Caller-agnostic: both the PVF-gated paid player repair (RequestSpecial.sqf) and the
		//--- server-internal presence-repair `call HandleSpecial` (server_town_camp.sqf) hit this
		//--- safely. Released on every exit branch below.
		if (_logic getVariable ["wfbe_camp_repairing", false]) exitWith {
			["WARNING", "Server_HandleSpecial.sqf/repair-camp: rejected - repair already in progress."] Call WFBE_CO_FNC_LogContent;
		};
		_logic setVariable ["wfbe_camp_repairing", true, true];

		if (alive (_logic getVariable 'wfbe_camp_bunker')) exitWith {
			_logic setVariable ["wfbe_camp_repairing", false, true];
		};

		//--- fable/fix-camp-placement (2026-07-08): same ATL ground-snap as Init_Town.sqf's seeder - a
		//--- repaired camp must not re-bury itself on ZG (see Init_Town.sqf for full rationale + citations).
		_campXY = getPos _logic;
		_townModel = (missionNamespace getVariable "WFBE_C_CAMP") createVehicle [_campXY select 0, _campXY select 1, 0];
		_townModel setDir ((getDir _logic) + (missionNamespace getVariable "WFBE_C_CAMP_RDIR"));
		//--- kimi/naval-deckcamp-repair (2026-07-20): naval deck camps (HeliHEmpty stand-in logics,
		//--- Init_NavalHVT.sqf) carry wfbe_camp_deckz - reseat the revived bunker ON the deck
		//--- (setPosASL), not at ATL z=0 (sea surface inside the hull = camp still unusable,
		//--- capture still deadlocked). Land camps keep the proven ATL ground-snap.
		if (!isNil {_logic getVariable "wfbe_camp_deckz"}) then {
			_townModel setPosASL [_campXY select 0, _campXY select 1, _logic getVariable "wfbe_camp_deckz"];
		} else {
			_townModel setPos [_campXY select 0, _campXY select 1, 0];
		};
			/*--- wiki-wins: removed killed EH calling undefined WFBE_SE_FNC_OnBuildingKilled (threw a swallowed error on every bunker death); bunker dead-state is already polled via alive (_logic getVariable 'wfbe_camp_bunker') ---*/
		_townModel addEventHandler ["handleDamage",{getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))}];
		_logic setVariable ["wfbe_camp_bunker", _townModel, true];

		//--- r69 camp SV heal: ALWAYS restore supplyValue after a successful rebuild (paid repair +
		//--- presence-repair). Residual vs bulk/ownership-flip heal: same-side rebuild previously left a
		//--- mid-drain SV on the revived bunker so the next camp tick re-flipped it almost immediately.
		Private ["_town","_repairStartSV","_repairFlag"];
		_town = _logic getVariable "town";
		_repairStartSV = 30;
		if (!isNil "_town" && {typeName _town == "OBJECT"} && {!isNull _town}) then {
			_repairStartSV = _town getVariable ["startingSupplyValue", 30];
			if (isNil "_repairStartSV" || {typeName _repairStartSV != "SCALAR"}) then {_repairStartSV = 30};
		};
		_logic setVariable ["supplyValue", _repairStartSV, true];

		//--- Do we have to update the camp SID ?
		_camp_sideID = _logic getVariable ["sideID", WFBE_DEFENDER_ID];
		if (_camp_sideID != _repairSideID) then {
			_logic setVariable ["sideID", _repairSideID, true];

			//--- wiki-wins: also fly the new side's flag (mirrors Server_SetCampsToSide.sqf:22); the side change set sideID but never the world flag texture.
			//--- Null-guard flag pole: deleted/missing poles must not throw on setFlagTexture (A2 isNull trap).
			_repairFlag = _logic getVariable ["wfbe_flag", objNull];
			if (!isNull _repairFlag) then {
				_repairFlag setFlagTexture (missionNamespace getVariable Format["WFBE_%1FLAG", (_repairSideID) Call WFBE_CO_FNC_GetSideFromID]);
				_repairFlag setVehicleInit (Format ["this setFlagTexture '%1'", missionNamespace getVariable Format["WFBE_%1FLAG", (_repairSideID) Call WFBE_CO_FNC_GetSideFromID]]);
				processInitCommands; //--- qol-polish-pack: JIP-safe flag (bake into object init so late joiners replay it)
			};

			//--- Notify / update map if needed.
			[nil, "CampCaptured", [_logic, _repairSideID, _camp_sideID, true]] Call WFBE_CO_FNC_SendToClients;
		};

		//--- harden-repair-camp: release the reentrancy flag taken above now the repair is complete.
		_logic setVariable ["wfbe_camp_repairing", false, true];
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
		Private ["_driver","_requestToken","_vbiedMsg","_vbiedOK","_veh"];
		_veh = objNull;
		_driver = objNull;
		_requestToken = "";
		if ((count _args) > 1 && {typeName (_args select 1) == "OBJECT"}) then {_veh = _args select 1};
		if ((count _args) > 2 && {typeName (_args select 2) == "OBJECT"}) then {_driver = _args select 2};
		if ((count _args) > 3 && {typeName (_args select 3) == "STRING"}) then {_requestToken = _args select 3};
		_vbiedOK = false;
		_vbiedMsg = "VBIED detonation denied; you must still be driving a live GUER VBIED.";
		if (_requestToken != "" && {!isNull _veh} && {alive _veh} && {!isNull _driver} && {isPlayer _driver} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0} && {driver _veh == _driver} && {side _driver == resistance} && {(typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])) || (typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])) || (((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) && {typeOf _veh == (missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Ins"])})}) then {  //--- B75: accept either VBIED type (hilux/datsun truck OR the kill-gated M113 APC). fable/guer-suicide-bike: OR the flag-gated suicide motorcycle -- SAME body below keeps the established attribution/reward flow.
			if (_veh getVariable ["wfbe_vbied_server_fired", false]) then {
				_vbiedMsg = "VBIED detonation was already accepted.";
			} else {
				//--- Server-local receipt closes the public-variable duplicate window before any scheduled blast work.
				_veh setVariable ["wfbe_vbied_server_fired", true];
				_vbiedOK = true;
				_vbiedMsg = "VBIED detonation accepted.";
			};
		};
		if (!isNull _driver && {isPlayer _driver}) then {
			if (WF_A2_Vanilla) then {
				[getPlayerUID _driver, "HandleSpecial", ["guer-vbied-result", _vbiedOK, _vbiedMsg, _veh, _requestToken]] Call WFBE_CO_FNC_SendToClients;
			} else {
				[_driver, "HandleSpecial", ["guer-vbied-result", _vbiedOK, _vbiedMsg, _veh, _requestToken]] Call WFBE_CO_FNC_SendToClient;
			};
		};
		diag_log Format ["GUERVBIED|v2|request|result=%1|driver=%2", if (_vbiedOK) then {"accepted"} else {"denied"}, if (isNull _driver) then {"?"} else {name _driver}];
		if (_vbiedOK) then {
			[_veh, _driver] spawn {
				Private ["_veh","_driver","_drvGrp","_drvUID","_p","_radius","_coef","_victims","_payout","_get","_persBounty","_persScore","_get2","_cand","_structVictims","_sStructs","_struct","_facBounty","_facScore","_fobIdx","_fobAvail","_vbClass","_wsk_victimUID","_wsk_sideNum","_wsk_victimSide","_wsk_dist","_wsk_cat","_wsk_hw","_wsk_kUID"];
				_veh = _this select 0;
				_driver = _this select 1;
				_drvGrp = group _driver;   //--- capture before the blast: the suicide driver dies in it.
				//--- B67 (guer-reward): also pay the DETONATOR personally (cash bounty + score) alongside the
				//--- team payout below. Capture the driver object + its UID NOW, while still alive, because the
				//--- suicide driver is gone by the time we settle (getPlayerUID on a dead/deleted unit is unreliable).
				_drvUID = getPlayerUID _driver;
				_vbClass = typeOf _veh; //--- fable/vbied-kill-visibility: capture PRE-blast - the hull is a wreck (typeOf can go "") or deleted by settle time.
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
				//--- fable/fix-vbied-attribution REWORK (#924, 2026-07-09): NO pre-blast wfbe_lasthitby stamp here
				//--- (reverted). The earlier attempt stamped _driver as the last-hitter so RequestOnUnitKilled's
				//--- delayed-hit fallback (RequestOnUnitKilled.sqf:53, requires "alive _last_hit") could attribute
				//--- these kills - but _driver IS the suicide bomber inside _veh, guaranteed dead by "_veh setDamage 1"
				//--- below at the SAME instant as these victims, so "alive _last_hit" can never be true and the
				//--- fallback never actually fired for a single VBIED kill. Kill credit for this snapshot is applied
				//--- directly after the settle instead (see the WFBE_GUER_PLAYER_KILLS block below) - matching the
				//--- guer-mortar-strike / Support_GuerHeliDrop.sqf idiom already used for instigator-less ordnance.
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
							//--- fable/fix-vbied-attribution REWORK (#924, 2026-07-09): idempotent GUER kill-tier tech credit -
							//--- ONE increment per confirmed-dead snapshot victim, this single settle pass only (can't double-count).
							//--- The earlier attempt routed this through RequestOnUnitKilled's delayed-hit fallback via a pre-blast
							//--- wfbe_lasthitby = _driver stamp (see the reverted snapshot-loop comment above) - that fallback
							//--- requires "alive _last_hit" (RequestOnUnitKilled.sqf:53), which _driver (this same suicide bomber)
							//--- can never satisfy, so it never attributed a single kill and WFBE_GUER_PLAYER_KILLS never advanced
							//--- from a VBIED kill. Crediting it here directly (mirrors Support_GuerHeliDrop.sqf's own
							//--- WFBE_C_GUER_HELIDROP_CREDIT_KILLS block for the identical "instigator dies with the ordnance"
							//--- shape) is what actually gates the M113/BRDM/T-tier depot unlocks - GUI_UpgradeMenu.sqf,
							//--- Root_GUE_PlayerOverlay.sqf and Client_UpdateRHUD.sqf all read WFBE_GUER_PLAYER_KILLS directly.
							//--- fable/vbied-kill-visibility (owner 2026-07-27 "add vbied to the same concept"): the FPV
							//--- blast-ledger route is IMPOSSIBLE here by design - the detonation gate above requires the
							//--- detonator to be DRIVING the live hull, and _veh setDamage 1 kills them the same instant as
							//--- their victims, so any alive-killer path (stamp OR ledger) can never fire (#924 proved and
							//--- reverted the stamp for exactly this). Credit is already paid death-proof below; what VBIED
							//--- kills lacked was VISIBILITY - no WASPSTAT|KILL row, so no dashboard/leaderboard/recap entry.
							//--- Emit the row here from the settled snapshot, replicating RequestOnUnitKilled.sqf:241-300
							//--- field-for-field (fixed field count - box parser folds killerSide; no extra fields).
							//--- Traps handled: a DEAD unit's side collapses to CIV, so victimSide comes from config side
							//--- (same idiom as the renegade fallback at RequestOnUnitKilled.sqf:107); victim UID is left
							//--- blank because getPlayerUID on a dead/deleted unit is unreliable (this file's own _drvUID
							//--- comment); killer weapon is the pre-blast _vbClass. Gated on WFBE_C_STATLOG like every
							//--- other WASPSTAT emit; telemetry only, independent of the CREDIT_KILLS reward gate below.
							if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
								_wsk_kUID = _drvUID;
								if (!isNil "WFBE_SE_FNC_IsHeadlessUid") then {
									if (_wsk_kUID call WFBE_SE_FNC_IsHeadlessUid) then {_wsk_kUID = ""};
								};
								_wsk_sideNum = getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "side");
								_wsk_victimSide = switch (_wsk_sideNum) do {case 0: {"EAST"}; case 1: {"WEST"}; case 2: {"GUER"}; default {"CIV"}};
								_wsk_dist = round (_x distance _p);
								_wsk_cat = "INF";
								if (!(_x isKindOf "Man")) then {
									if (_x isKindOf "Air") then {_wsk_cat = "AIR"} else {
										if (_x isKindOf "StaticWeapon") then {_wsk_cat = "STATIC"} else {_wsk_cat = "VEH"};
									};
								};
								_wsk_hw = "";
								if (!(_x isKindOf "Man")) then {
									_wsk_hw = if (_x isKindOf "Helicopter") then {"HELI"} else {
										if (_x isKindOf "Plane") then {"JET"} else {
											if (_x isKindOf "Tank") then {"ARMOR"} else {
												if (_x isKindOf "Ship") then {"SHIP"} else {
													if (_x isKindOf "Car") then {"CAR"} else {"OTHER"}
												}
											}
										}
									};
								};
								if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
								WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
								diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|KILL|" + _wsk_kUID + "||GUER|" + _wsk_victimSide + "|" + _vbClass + "|" + str _wsk_dist + "|" + _wsk_cat + "|hw=" + _wsk_hw + "|vc=" + (typeOf _x) + "|t=" + str (round time));
							};
							if ((missionNamespace getVariable ["WFBE_C_GUER_VBIED_CREDIT_KILLS", 1]) > 0) then {
								//--- Driver dies with the VBIED before RequestOnUnitKilled reaches its stats path, so mirror its category-aware stat credit here.
								if (_drvUID != "") then {
									private ["_vStat"];
									_vStat = WFBE_STAT_KILLS_INFANTRY;
									if !(_x isKindOf "Man") then {
										if (_x isKindOf "Air") then {_vStat = WFBE_STAT_KILLS_AIR} else {
											if (_x isKindOf "StaticWeapon") then {_vStat = WFBE_STAT_KILLS_STATIC} else {_vStat = WFBE_STAT_KILLS_VEHICLE};
										};
									};
									[_drvUID, _vStat, 1] Call WFBE_SE_FNC_RecordStat;
									if (isPlayer _x) then {[_drvUID, WFBE_STAT_PVP_KILLS, 1] Call WFBE_SE_FNC_RecordStat};
								};
								WFBE_GUER_PLAYER_KILLS = (missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0]) + 1;
								publicVariable "WFBE_GUER_PLAYER_KILLS";
								//--- Same milestone/unlock table RequestOnUnitKilled.sqf:152-157 uses - keep in sync manually if
								//--- those tiers ever change (same accepted duplication Support_GuerHeliDrop.sqf already carries).
								private ["_vMilestones","_vMsg"];
								_vMilestones = [
									[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_1", 15], "BRDM-2 + T-34 unlocked  -  Ka-137 flares up to 120"],
									[missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 25], "M113 VBIED unlocked  -  armoured suicide APC at ~1.5x speed"],
									[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_2", 40], "T-55 unlocked  -  Ka-137 flares up to 240"],
									[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_3", 80], "T-72 + BMP-2 unlocked"]
								];
								//--- guer-tech: barrel-bomb unlock toast - see RequestOnUnitKilled.sqf. Flag-guarded append so the
								//--- announcement fires when a VBIED kill crosses WFBE_C_GUER_KILLTIER_HELIBOMB (dead in Support_GuerHeliDrop).
								if ((missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_ENABLE", 1]) > 0) then {
									_vMilestones set [count _vMilestones, [missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_HELIBOMB", 60], "Barrel Bomb unlocked  -  heli-delivered call-in strike"]];
								};
								_vMsg = "";
								{ if (WFBE_GUER_PLAYER_KILLS == (_x select 0)) then {_vMsg = _x select 1} } forEach _vMilestones;
								if (_vMsg != "") then {
									WFBE_GUER_UNLOCK_MSG = [WFBE_GUER_PLAYER_KILLS, _vMsg];
									publicVariable "WFBE_GUER_UNLOCK_MSG";
								};
							};
						};
					} forEach _victims;
					if (_payout > 0) then {
						//--- fable/fix-vbied-attribution (owner pick A3, 2026-07-08): STAYS false BY DESIGN, not stale.
						//--- Verified against DIAGNOSES-AND-SPECS.md Bug 2: once the pre-blast wfbe_lasthitby /
						//--- wfbe_explosivesupportkill stamping above (this case) + the SCOPED RequestOnUnitKilled.sqf:44
						//--- Man-class fallback land, RequestOnUnitKilled's own GUER kill-bounty block (coef 0.5 default,
						//--- :167-189) starts paying TEAM funds for these same VBIED-killed Man victims for the FIRST TIME
						//--- via the now-working last-hit attribution path -- THAT is the team-funds re-enable (a payout-
						//--- composition change, not a gap). Restoring the old ChangeTeamFunds call here on top of that
						//--- would DOUBLE-PAY every victim (this coef 0.5 payout + RequestOnUnitKilled's own coef 0.5
						//--- payout for the identical kill set). Ray's original 2026-06-27 rationale (group captured
						//--- PRE-suicide) is superseded by this payout-composition reasoning; the functional no-op is
						//--- correct either way. Wallet/UID path below (_persBounty/_drvUID) is the unaffected personal-
						//--- payout channel. was: [_drvGrp, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
						false;
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
					//--- fable/vbied-respawn-payout (owner 2026-07-28 "still no reward on VBIED - you die to the
					//--- explosion yourself"): the J1 pay-the-pre-blast-group assumption is FALSE under respawn
					//--- re-homing - Client_OnRespawnHandler.sqf documents that a respawned player lands in a
					//--- DIFFERENT group and re-points clientTeam at it, so the credit parked in the orphaned old
					//--- group where no wallet ever reads it (live-proven: GUERVBIED|v1 persBounty=266 computed +
					//--- paid, owner wallet unchanged). Defer instead: resolve the detonator's LIVE body by UID
					//--- (up to 10 min - deadspawn + respawn UI), then credit THAT body's current group. If they
					//--- never return, fall back to the old group (exactly today's behaviour, loses nothing).
					[_drvUID, _persBounty, _drvGrp] spawn {
						private ["_uid","_amt","_fallbackGrp","_deadline","_target","_u"];
						_uid = _this select 0;
						_amt = _this select 1;
						_fallbackGrp = _this select 2;
						_deadline = time + 600;
						_target = grpNull;
						while {isNull _target && {time < _deadline}} do {
							{
								_u = _x;
								if (!isNull _u && {alive _u} && {isPlayer _u} && {getPlayerUID _u == _uid}) exitWith {_target = group _u};
							} forEach playableUnits;
							if (isNull _target) then {sleep 5};
						};
						if (isNull _target) then {_target = _fallbackGrp};
						if (!isNull _target) then {
							[_target, _amt] Call WFBE_CO_FNC_ChangeTeamFunds;
							diag_log ("GUERVBIED|v3|paid|uid=" + _uid + "|amount=" + str _amt);
						} else {
							diag_log ("GUERVBIED|v3|pay-failed|uid=" + _uid + "|amount=" + str _amt);
						};
					};
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

	//--- GUER BARREL BOMB (fable/guer-barrelbomb): a GUER player at a friendly town center designated a drop
	//--- point on the map (Action_GuerHeliBombCall.sqf already validated side + range client-side, mirroring
	//--- guer-mortar-strike exactly); here the SERVER re-validates the kill-tier gate (never trust the
	//--- client's addAction visibility check), debits cost, and spawns the heli via Support_GuerHeliDrop.sqf
	//--- (KAT_GuerHeliDrop) - flight, arrival, release, kill-credit, and return are ALL handled there
	//--- (mirrors the "guer-mortar-strike" case's own shape: this case only owns validation, cost, dispatch).
	case "guer-heli-bomb": {
		Private ["_pos","_player","_team","_cost","_kills","_tier","_receiptKey"];
		if (count _args < 3) exitWith {
			["WARNING", Format ["Server_HandleSpecial.sqf: guer-heli-bomb received a short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
		};
		_pos    = _args select 1;
		_player = _args select 2;
		if ((missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_ENABLE", 0]) > 0 && {typeName _pos == "ARRAY"} && {!isNull _player} && {side _player == resistance} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {  //--- sweep-fix: master-flag re-check server-side so the feature is truly inert when WFBE_C_GUER_HELIBOMB_ENABLE=0 (a client can send the request even with its addAction hidden).
			//--- KILL-TIER GATE (server-authoritative re-check): the addAction's own condition string already
			//--- hides this from a not-yet-unlocked player client-side, but that is a UX convenience, not a
			//--- trust boundary - re-check here before any funds move.
			_kills = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
			_tier  = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_HELIBOMB", 60];
			if (_kills < _tier) exitWith {
				if (WF_A2_Vanilla) then {
					[getPlayerUID _player, "HandleSpecial", ["guer-helibomb-result", false, Format ["Barrel Bomb needs %1 GUER kills - the cell isn't ready.", _tier]]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[_player, "HandleSpecial", ["guer-helibomb-result", false, Format ["Barrel Bomb needs %1 GUER kills - the cell isn't ready.", _tier]]] Call WFBE_CO_FNC_SendToClient;
				};
				["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER heli-bomb DENIED (kill-tier %1/%2) for [%3].", _kills, _tier, name _player]] Call WFBE_CO_FNC_LogContent;
			};

			//--- COST: debit the GUER player's team funds before dispatch. Same funds-holding team + refund-on-
			//--- deny shape as guer-mortar-strike (Server_HandleSpecial.sqf "guer-mortar-strike" above).
			_team = group _player;
			_cost = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_COST", 3000];
			if (isNull _team || {(_team Call WFBE_CO_FNC_GetTeamFunds) < _cost}) exitWith {
				if (WF_A2_Vanilla) then {
					[getPlayerUID _player, "HandleSpecial", ["guer-helibomb-result", false, Format ["Barrel Bomb needs $%1 - the cell is broke.", _cost]]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[_player, "HandleSpecial", ["guer-helibomb-result", false, Format ["Barrel Bomb needs $%1 - the cell is broke.", _cost]]] Call WFBE_CO_FNC_SendToClient;
				};
				["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER heli-bomb DENIED (insufficient funds) for [%1] team [%2].", name _player, _team]] Call WFBE_CO_FNC_LogContent;
			};
			//--- Bind the debit to a server-local one-shot receipt before any funds move. The support worker may
			//--- refund only this exact team/cost if transport setup or the inbound flight fails before a shell exists.
			_receiptKey = Format ["wfbe_guer_helibomb_receipt_%1_%2", floor (diag_tickTime * 1000), floor (random 1000000000)];
			missionNamespace setVariable [_receiptKey, [0, _team, _cost, _player]];
			[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;

			["INFORMATION", Format ["Server_HandleSpecial.sqf: GUER Barrel Bomb called by [%1] at %2 (cost %3).", name _player, _pos, _cost]] Call WFBE_CO_FNC_LogContent;
			[nil, resistance, _pos, _team, _receiptKey] Spawn KAT_GuerHeliDrop;
		};
	};
	default {
		//--- HS-TRACE (picklist 4 phase 1): an unknown request type previously fell through this
		//--- switch with zero trace. Always-on WARNING, same envelope idiom as the RequestSpecial
		//--- Block E guards; healthy cases never reach here.
		["WARNING", Format ["Server_HandleSpecial.sqf: unknown request type [%1] (argc %2) - dispatch ignored.", _args select 0, count _args]] Call WFBE_CO_FNC_LogContent;
	};
};
