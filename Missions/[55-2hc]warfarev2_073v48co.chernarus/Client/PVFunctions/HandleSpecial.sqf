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
	// B69 AICOM HC top-up: merge a depleted donor team (B) into a keeper team (A) of the same side.
	// Contract: _args = [A, B] (two GROUPS). Self-gate on BOTH leaders being local to THIS machine
	// (joinSilent is locality-sensitive). If both local -> (units B) joinSilent A; the now-empty B is
	// reaped by existing GC. If not both local -> no-op (another HC owns it / self-heals next cadence).
	// Default-OFF via WFBE_C_AICOM_HC_MERGE_ENABLE (no-op until the constant is defined).
	case "aicom-team-merge": {
		Private ["_grpA","_grpB","_moved"];
		if ((missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_ENABLE", 0]) <= 0) exitWith {}; //--- B69 fix: flag ships as Number 0/1; !(Number) is an A2-OA type error.
		_grpA = _args select 0;
		_grpB = _args select 1;
		if (isNull _grpA) exitWith {};
		if (isNull _grpB) exitWith {};
		if ((local (leader _grpA)) && (local (leader _grpB))) then {
			_moved = count (units _grpB); //--- capture donor size BEFORE the join empties B.
			(units _grpB) joinSilent _grpA;
			diag_log Format ["AICOMHCMERGE keeperA:%1 donorB:%2 movedUnits:%3 keeperSize:%4", _grpA, _grpB, _moved, count (units _grpA)];
		};
	};
	/*--- wiki-wins: removed dead "delegate-ai" case (no server sender repo-wide; superseded by delegate-townai / delegate-ai-static-defence) ---*/
	case "delegate-ai-static-defence": {_args spawn WFBE_CL_FNC_DelegateAIStaticDefence};
	case "endgame": {if !(isNil "WFBE_CL_FNC_EndGame") then {_args spawn WFBE_CL_FNC_EndGame}};
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
	//--- Accept the ICBM/TEL token only when it echoes this client's private challenge.
	case "icbm-tel-auth-token": {
		Private ["_telChallenge","_telChallengeKey","_telExpires","_telPurpose","_telToken"];
		if (count _args != 4) exitWith {};
		_telPurpose = _args select 0;
		_telToken = _args select 1;
		_telExpires = _args select 2;
		_telChallenge = _args select 3;
		if (typeName _telPurpose != "STRING" || {!(_telPurpose in ["fire","purchase"])}) exitWith {};
		_telChallengeKey = Format ["wfbe_icbm_tel_%1_auth_challenge_%2", _telPurpose, getPlayerUID player];
		if (typeName _telToken != "STRING" || {_telToken == ""}) exitWith {};
		if (typeName _telExpires != "SCALAR" || {_telExpires <= time}) exitWith {};
		if (typeName _telChallenge != "STRING" || {_telChallenge != (missionNamespace getVariable [_telChallengeKey, ""])}) exitWith {};
		missionNamespace setVariable [Format ["wfbe_icbm_tel_%1_cap_client_%2", _telPurpose, getPlayerUID player], [_telToken, _telExpires]];
	};

	//--- Accept a purchase proof (or immediate denial reason) only for this client's challenge.
	case "icbm-tel-purchase-token": {
		Private ["_buyChallenge","_buyChallengeKey","_buyExpires","_buyMessage","_buyToken"];
		if (count _args != 4) exitWith {};
		_buyToken = _args select 0;
		_buyExpires = _args select 1;
		_buyChallenge = _args select 2;
		_buyMessage = _args select 3;
		_buyChallengeKey = Format ["wfbe_icbm_tel_purchase_challenge_%1", getPlayerUID player];
		if (typeName _buyToken != "STRING") exitWith {};
		if (typeName _buyExpires != "SCALAR") exitWith {};
		if (typeName _buyMessage != "STRING") exitWith {};
		if (typeName _buyChallenge != "STRING" || {_buyChallenge != (missionNamespace getVariable [_buyChallengeKey, ""])}) exitWith {};
		missionNamespace setVariable [Format ["wfbe_icbm_tel_purchase_cap_client_%1", getPlayerUID player], [_buyToken, _buyExpires, _buyMessage]];
	};

	//--- The auth response is accepted only when it echoes the private client challenge.
	case "fpv-auth-token": {
		Private ["_fpvAuthChallenge","_fpvChallengeKey","_fpvExpires","_fpvToken"];
		if (count _args < 3) exitWith {};
		_fpvToken = _args select 0;
		_fpvExpires = _args select 1;
		_fpvAuthChallenge = _args select 2;
		_fpvChallengeKey = Format ["wfbe_fpv_auth_challenge_%1", getPlayerUID player];
		if (typeName _fpvToken != "STRING" || {_fpvToken == ""}) exitWith {};
		if (typeName _fpvExpires != "SCALAR" || {_fpvExpires <= time}) exitWith {};
		if (typeName _fpvAuthChallenge != "STRING" || {_fpvAuthChallenge != (missionNamespace getVariable [_fpvChallengeKey, ""])}) exitWith {};
		missionNamespace setVariable [Format ["wfbe_fpv_cap_client_%1", getPlayerUID player], [_fpvToken, _fpvExpires]];
	};
	//--- Purchase results carry the private capability and exact objects. Fake/stale client-bus
	//--- packets cannot change stats, cooldown, or tear down a newer flight.
	case "fpv-purchase-result": {
		Private ["_fpvDriver","_fpvDrone","_fpvExpectedToken","_fpvGroup","_fpvMsg","_fpvNext","_fpvNextKey","_fpvOK","_fpvResultKey","_fpvStatusKey","_fpvToken","_fpvTokenAccepted"];
		if (count _args < 6) exitWith {};
		_fpvOK = _args select 0;
		_fpvNext = _args select 1;
		_fpvMsg = _args select 2;
		_fpvDrone = _args select 3;
		_fpvDriver = _args select 4;
		_fpvToken = _args select 5;
		if (typeName _fpvOK != "BOOL" || {typeName _fpvToken != "STRING"}) exitWith {};
		_fpvResultKey = Format ["wfbe_fpv_purchase_token_%1", getPlayerUID player];
		_fpvTokenAccepted = false;
		isNil {
			_fpvExpectedToken = missionNamespace getVariable [_fpvResultKey, ""];
			if (_fpvExpectedToken != "" && {_fpvToken == _fpvExpectedToken}) then {
				missionNamespace setVariable [_fpvResultKey, ""];
				_fpvTokenAccepted = true;
			};
		};
		if (!_fpvTokenAccepted) exitWith {};
		_fpvStatusKey = Format ["wfbe_fpv_purchase_status_%1", getPlayerUID player];
		missionNamespace setVariable [_fpvStatusKey, if (_fpvOK) then {1} else {-1}];
		_fpvNextKey = Format ["wfbe_fpv_next_%1", getPlayerUID player];
		if (typeName _fpvNext == "SCALAR") then {missionNamespace setVariable [_fpvNextKey, _fpvNext]};
		if (_fpvOK) then {
			[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
			[sideJoinedText,'VehiclesCreated',1] Call UpdateStatistics;
		} else {
			//--- fix(fpv-handoff-race): the one-shot token compare-consume above already proved this
			//--- deny belongs to THIS client's pending purchase, and playerFPV IS that purchase's drone.
			//--- Gating teardown on the echoed drone reference leaked a still-armed drone whenever the
			//--- purchase PV outran createVehicle replication (server bound objNull, deny "FPV drone no
			//--- longer exists.") - the armed airframe then fell and self-detonated on ground impact.
			if (!isNull playerFPV) then {
				_fpvGroup = grpNull;
				_fpvDriver = driver playerFPV;
				if (!isNull _fpvDriver && {!isPlayer _fpvDriver}) then {
					_fpvGroup = group _fpvDriver;
					deleteVehicle _fpvDriver;
				};
				playerFPV setVariable ["wfbe_fpv_armed", false];
				deleteVehicle playerFPV;
				playerFPV = objNull;
				if (!isNull _fpvGroup && {count units _fpvGroup == 0}) then {deleteGroup _fpvGroup};
			};
		};
		if (typeName _fpvMsg == "STRING" && {_fpvMsg != ""}) then {hint _fpvMsg};
	};
	//--- task46 (claude) N-FEAT-1: register the SCUD-strike addAction on the CLIENT.
	//--- The server (Init_NavalHVT.sqf) does the proximity/leader/owner-side gate, then sends this
	//--- signal to the player's UID; the action must live in the player's LOCAL space to be visible
	//--- (a server-side addAction on a remote player unit is invisible on a dedicated server).
	case "scud-action-add": {
		if (isDedicated) exitWith {};
		if (isNil "player") exitWith {};
		if (player getVariable ["wfbe_scud_action_armed", false]) exitWith {}; //--- already added locally
		player setVariable ["wfbe_scud_action_armed", true];
		player addAction [
			localize "STR_WF_SCUD_ACTION",
			{
				private ["_caller","_cost","_funds","_token"];
				_caller = _this select 1;
				//--- fable/guer-client-startup-mapcancel: re-select guard, mirrors Action_GuerHeliBombCall.sqf - do
				//--- not stack a second onMapSingleClick while a designation is already pending on this player.
				if (player getVariable ["wfbe_scud_designating", false]) exitWith { hint localize "STR_WF_SCUD_SELECT_TARGET"; };
				_cost   = WFBE_C_SCUD_COST;
				_funds  = (group _caller) getVariable "wfbe_funds"; //--- fix(hunt): G1 trap - the 2-arg [name,default] form returns nil (NOT the default) on a GROUP receiver when unset; nil < cost threw and silently killed this action
				if (isNil "_funds") then {_funds = 0};
				if (_funds < _cost) exitWith { hint localize "STR_WF_SCUD_NO_FUNDS"; };
				hint localize "STR_WF_SCUD_SELECT_TARGET";
				player setVariable ["wfbe_scud_designating", true];
				_token = diag_tickTime;
				player setVariable ["wfbe_scud_design_token", _token];
				openMap true;
				//--- fable/guer-client-startup-mapcancel: ESC / map-close cancel watcher (same pattern as the
				//--- barrel-bomb designator) - without it, ESCing out of SCUD targeting left the latch set and
				//--- the armed onMapSingleClick live, so the player's next unrelated map click fired a live SCUD
				//--- strike. "_token" pins the watcher to THIS designation instance.
				[player, _token] spawn {
					private ["_p","_myToken"];
					_p = _this select 0;
					_myToken = _this select 1;
					waitUntil {!visibleMap || {isNull _p} || {!(_p getVariable ["wfbe_scud_designating", false])}};
					if ((_p getVariable ["wfbe_scud_designating", false]) && {(_p getVariable ["wfbe_scud_design_token", -1]) == _myToken}) then {
						_p setVariable ["wfbe_scud_designating", false];
						onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
					};
				};
				onMapSingleClick {
					onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
					openMap false;
					player setVariable ["wfbe_scud_designating", false];
					["RequestSpecial", ["ScudStrike", playerSide, _pos, group player]] Call WFBE_CO_FNC_SendToServer;
					hint localize "STR_WF_SCUD_LAUNCHED";
					false
				};
			},
			[], 6, true, true, "", "alive _target && isPlayer _this"
		];
	};
	//--- cmdcon41 SCUD THEATRICS (feature 1, Ray 2026-07-02): base-under-attack KLAXON to the OWNING side on a SCUD
	//--- launch. The server (Support_ScudStrike.sqf) side-scopes this send ([_side,...]) so Client_HandlePVF already
	//--- delivered it ONLY to owning-side clients -> no extra side check here. "inbound" is the registered CfgSound
	//--- alarm alias base-under-attack uses (Common_HandleAlarm.sqf:11, CampCaptured.sqf:50). Skip on the HC/dedicated
	//--- (no interface), mirroring the scud-action-add guard below.
	case "scud-klaxon": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		playSound ["inbound", true];
	};
	//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02) — client presentation cases.
	//--- All are delivered side-scoped by Client_HandlePVF (the server sends [_side/nil, "HandleSpecial", ...]) so no
	//--- extra side check is needed here. Guard the HC/dedicated (no interface), mirroring scud-klaxon/scud-action-add.
	//---
	//--- scud-klaxon-all: NUKE detonation alarm to EVERYONE (server sends nil-destination => all clients).
	case "scud-klaxon-all": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		playSound ["inbound", true];
	};
	//--- icbm-tel-msg: a plain side-scoped chat announcement (systemChat). _args select 0 = the text.
	case "icbm-tel-msg": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_msg"];
		_msg = _args select 0;
		if (typeName _msg == "STRING" && {_msg != ""}) then {systemChat _msg};
	};
	//--- zg-koth-announce (fable/radius-hold-primitive consumer, GR-2026-07-08a): plain public announcement
	//--- for the Zargabad KotH hold, mirrors icbm-tel-msg verbatim (systemChat, no side-scoping needed - the
	//--- server sends this with a nil destination so every client gets it). _args select 0 = the text.
	case "zg-koth-announce": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_msg"];
		_msg = _args select 0;
		if (typeName _msg == "STRING" && {_msg != ""}) then {systemChat _msg};
	};
	//--- icbm-tel-marker: FRIENDLY-ONLY TEL map marker. _args = [_tel, _sideText]. mil_triangle in side colour,
	//--- text "ICBM TEL". A tiny local watcher deletes it when the TEL dies (server re-sends this on each respawn).
	case "icbm-tel-marker": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_tel","_sideText","_mkr","_col"];
		_tel = _args select 0;
		_sideText = _args select 1;
		if (isNull _tel) exitWith {};
		_col = missionNamespace getVariable [Format ["WFBE_C_%1_COLOR", _sideText], "ColorGreen"];
		_mkr = createMarkerLocal [Format ["wfbe_icbmtel_mkr_%1", _sideText], getPosATL _tel];
		_mkr setMarkerTypeLocal "mil_triangle";
		_mkr setMarkerColorLocal _col;
		_mkr setMarkerTextLocal "ICBM TEL";
		[_tel, _mkr] spawn {
			private ["_t","_m"];
			_t = _this select 0; _m = _this select 1;
			waitUntil {sleep 2; isNull _t || {!alive _t}};
			deleteMarkerLocal _m;
		};
	};
	//--- icbm-tel-enemy-ping: FUZZY enemy intel ping for the NUKE countdown. _args = [_pos, _secs]. Auto-deletes.
	case "icbm-tel-enemy-ping": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_pos","_secs","_mkr"];
		_pos  = _args select 0;
		_secs = _args select 1;
		_mkr = createMarkerLocal [Format ["wfbe_icbmtel_ping_%1", round (diag_tickTime * 1000)], _pos];
		_mkr setMarkerTypeLocal "mil_warning";
		_mkr setMarkerColorLocal "ColorRed";
		_mkr setMarkerTextLocal "ICBM (approx)";
		[_mkr, _secs] spawn { sleep (_this select 1); deleteMarkerLocal (_this select 0) };
	};
	//--- icbm-tel-recon-markers: RECON FLASH map dots for the FIRING side's players. _args = [_posList, _secs].
	//--- One mil_dot per enemy position (already capped server-side at ~40); all auto-delete after the window.
	case "icbm-tel-recon-markers": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_posList","_secs","_i","_mkr"];
		_posList = _args select 0;
		_secs    = _args select 1;
		if (typeName _posList != "ARRAY") exitWith {};
		_i = 0;
		{
			_mkr = createMarkerLocal [Format ["wfbe_icbmtel_recon_%1_%2", round (diag_tickTime * 1000), _i], [_x select 0, _x select 1, 0]];
			_mkr setMarkerTypeLocal "mil_dot";
			_mkr setMarkerColorLocal "ColorRed";
			_mkr setMarkerSizeLocal [0.6, 0.6];
			[_mkr, _secs] spawn { sleep (_this select 1); deleteMarkerLocal (_this select 0) };
			_i = _i + 1;
		} forEach _posList;
	};
	//--- pack-missiles F1 (ICBM countdown, WFBE_C_ICBM_COUNTDOWN=1) + F2 (missile warning, WFBE_C_MISSILE_WARNING=1).
	//--- _args = [launchTime, impactTime]. Sent at NUKE launch: TEL path from Init_IcbmTel.sqf (server);
	//--- classic path from nukeincoming.sqf (commander client). Guards: isDedicated + nil/null player.
	//--- F1: hintSilent M:SS every 5s (mirrors Client_GuerLockout.sqf pattern); clears on impact.
	//--- F2: titleText "PLAIN DOWN" + playSound "inbound" on first trigger; "inbound" every 10s after.
	//---     Reuses existing "inbound" CfgSounds alarm (same as scud-klaxon-all / base-under-attack).
	case "icbm-countdown": {
		if (isDedicated) exitWith {};
		if (isNil "player" || {isNull player}) exitWith {};
		private ["_launchTime","_impactTime","_left","_m","_s"];
		_launchTime = _args select 0;
		_impactTime = _args select 1;
		_left = _impactTime - time;
		if (_left <= 0) exitWith {};
		//--- F1: countdown HUD (hintSilent M:SS every 5s).
		if ((missionNamespace getVariable ["WFBE_C_ICBM_COUNTDOWN", 1]) > 0) then {
			[_impactTime] spawn {
				private ["_iT","_left","_m","_s"];
				_iT = _this select 0;
				_left = _iT - time;
				if (_left > 0) then {
					_m = floor (_left / 60);
					_s = floor (_left - (_m * 60));
					hintSilent Format ["ICBM IMPACT IN %1:%2", _m, if (_s < 10) then {"0" + str _s} else {str _s}];
				};
				while {time < _iT} do {
					sleep 5;
					_left = _iT - time;
					if (_left > 0) then {
						_m = floor (_left / 60);
						_s = floor (_left - (_m * 60));
						hintSilent Format ["ICBM IMPACT IN %1:%2", _m, if (_s < 10) then {"0" + str _s} else {str _s}];
					};
				};
				hintSilent "";
			};
		};
		//--- F2: periodic audio alarm.
		if ((missionNamespace getVariable ["WFBE_C_MISSILE_WARNING", 1]) > 0) then {
			titleText ["! INCOMING ICBM !", "PLAIN DOWN", 5];
			playSound "inbound";
			[_impactTime] spawn {
				private ["_iT"];
				_iT = _this select 0;
				while {time < _iT} do {
					sleep 10;
					if (time < _iT) then { playSound "inbound" };
				};
			};
		};
	};

	//--- cmdcon41-w2 (Ray 2026-07-02) NAVAL HVT: the server (server_town.sqf) broadcasts this on every
	//--- carrier flip, but the client case was MISSING so the flip notification was silently dropped. Add it,
	//--- mirroring the neighbouring case style (hint + city-marker recolor). Payload after the request-strip:
	//--- _args = [_location, _newSID, _hvtName]. The marker name matches updatetownmarkers.sqf / TownCaptured.sqf
	//--- (WFBE_%1_CityMarker keyed on the town logic). setMarkerColorLocal is client-local (A2-OA-safe).
	case "naval-hvt-captured": {
		if (isDedicated) exitWith {};
		private ["_navLoc","_navNewSID","_navName","_navSide","_navColor","_navMkr"];
		_navLoc    = _args select 0;
		_navNewSID = _args select 1;
		_navName   = _args select 2;
		if (isNull _navLoc) exitWith {};
		_navSide  = _navNewSID Call WFBE_CO_FNC_GetSideFromID;
		//--- Recolor the carrier's city marker to the new owner (same lookup TownCaptured uses).
		_navColor = missionNamespace getVariable [Format ["WFBE_C_%1_COLOR", _navSide], "ColorGreen"];
		_navMkr   = Format ["WFBE_%1_CityMarker", _navLoc];
		_navMkr setMarkerColorLocal _navColor;
		//--- Flip notification hint (localized). Prefix the carrier name so players know which one flipped.
		//--- Guard on a real player (skip the HC, which has no interface) - mirrors the scud-action-add guard.
		if (!isNil "player" && {!isNull player}) then {
			hint parseText Format ["%1<br/>%2", _navName, localize "STR_WF_NAVAL_HVT_CAPTURED"];
		};
	};
	case "upgrade-started": {_args spawn WFBE_CL_FNC_Upgrade_Started};
	case "upgrade-complete": {_args spawn WFBE_CL_FNC_Upgrade_Complete};
	case "building-started": {_args spawn WFBE_CL_FNC_Building_Started};
	case "set-hq-killed-eh": {if !(isServer) then {(_args select 0) addEventHandler ["killed", {["RequestSpecial", ["process-killed-hq", _this]] Call WFBE_CO_FNC_SendToServer}]};};
	case "auto-wall-constructing-changed":{ isAutoWallConstructingEnabled = (_args select 0)};
	case "attack-wave": {ATTACK_WAVE_PRICE_MODIFIER = (_args select 0);};
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
	//--- GUER Barrel Bomb result (server -> caller). The server rejected the call-in (insufficient
	//--- funds, or the kill-tier gate was not actually met server-side), so refund the client's
	//--- optimistic cooldown stamp and tell the player why. (Note: the sibling "guer-mortar-result"
	//--- case this originally mirrored was removed by fable/guer-mortar-dedup's owner de-dup
	//--- decision - Action_GuerMortarStrike.sqf no longer exists - so only the barrel-bomb case
	//--- survives the merge here.)
	case "guer-helibomb-result": {
		Private ["_ok","_msg"];
		_ok  = _args select 0;
		_msg = _args select 1;
		if (!_ok) then {
			player setVariable ["wfbe_helibomb_last", -9999];   //--- un-stamp: the drop never fired.
		};
		if (typeName _msg == "STRING" && {_msg != ""}) then {hint _msg};
	};
	//--- GUER FOB build outcome (server -> caller). The client starts with an optimistic titleText, but the
	//--- authoritative handler can reject a raced token or blocked placement. Keep the truck/token unchanged and
	//--- tell only the caller why it did not become a FOB.
	case "guer-fob-result": {
		Private ["_fobOk","_fobMsg"];
		_fobOk  = _args select 0;
		_fobMsg = _args select 1;
		if (!_fobOk && {typeName _fobMsg == "STRING"} && {_fobMsg != ""}) then {hint _fobMsg};
	};
	//--- GUER VBIED result (server -> requesting driver). The detonation action remains retryable until the
	//--- server accepts the exact pending receipt; stale/foreign replies cannot consume or clear a newer request.
	case "guer-vbied-result": {
		Private ["_vbiedExpected","_vbiedMsg","_vbiedOK","_vbiedToken","_vbiedVeh"];
		if (count _args != 4) exitWith {};
		_vbiedOK = _args select 0;
		_vbiedMsg = _args select 1;
		_vbiedVeh = _args select 2;
		_vbiedToken = _args select 3;
		if (typeName _vbiedOK != "BOOL" || {typeName _vbiedMsg != "STRING"} || {typeName _vbiedVeh != "OBJECT"} || {typeName _vbiedToken != "STRING"} || {isNull _vbiedVeh}) exitWith {};
		_vbiedExpected = _vbiedVeh getVariable ["wfbe_vbied_pending_token", ""];
		if (_vbiedExpected != _vbiedToken) exitWith {};
		_vbiedVeh setVariable ["wfbe_vbied_pending_token", ""];
		if (_vbiedOK) then {
			_vbiedVeh setVariable ["wfbe_vbied_fired", true];
		} else {
			if (_vbiedMsg != "") then {hint _vbiedMsg};
		};
	};
};
