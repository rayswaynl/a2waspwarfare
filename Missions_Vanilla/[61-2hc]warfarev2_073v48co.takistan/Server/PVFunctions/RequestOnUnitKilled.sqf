/*
	Triggerd upon a unit death.
	 Parameters:
		- Killed
		- Killer
		- Killed side ID.
*/

Private ["_get","_killed","_killed_isplayer","_killed_group","_killed_isman","_killed_side","_killed_type","_killer","_killer_group","_killer_isplayer","_killer_iswfteam","_killer_side","_killer_type","_killer_vehicle","_killer_uid","_killer_award","_last_hit","_last_hit_time","_last_hit_window","_points","_nameOfKilledUnit","_type","_killerVehObj","_isArtyKill","_victimLogik","_artyKillCount","_victimStreak"];

_killed = _this select 0;
_killer = _this select 1;
_killed_side = (_this select 2) Call GetSideFromID;
_type = typeOf _killed;

//--- Card #66 (killstreak bounty): server-authoritative killstreak tracking. Capture the VICTIM's
//--- pre-reset streak (forwarded into the AwardBountyPlayer message below), then UNCONDITIONALLY clear
//--- the killed player's streak for ANY death (enemy, friendly, environment, AI). Placed BEFORE the
//--- killer-dead early exit so a death by drowning/crash/AI still resets the streak. Broadcast (true)
//--- so every machine sees 0; the respawn object defaults to 0, making this JIP-safe. NEVER incremented
//--- client-side - only the server writes wfbe_killstreak.
_victimStreak = 0;
if (isPlayer _killed) then {
	_victimStreak = _killed getVariable ["wfbe_killstreak", 0];
	_killed setVariable ["wfbe_killstreak", 0, true];
};

if (!(_killed isKindOf "Man") && (_killer == _killed || isNull _killer || !alive _killer)) then { //--- Vehicles may crash or burn out after a valid hit.
	_last_hit = _killed getVariable ["wfbe_lasthitby", objNull];
	// A2 OA: deleted objects can return nil even with a default; guard before isNull.
	if (isNil "_last_hit") then { _last_hit = objNull };
	_last_hit_time = _killed getVariable ["wfbe_lasthittime", -1];
	if (isNil "_last_hit_time") then { _last_hit_time = -1 };
	_last_hit_window = missionNamespace getVariable ["WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW", 60];

	if !(isNull _last_hit) then {
		if (alive _last_hit && side _last_hit != _killed_side && _last_hit_time >= 0 && (time - _last_hit_time) <= _last_hit_window) then {
			_killer = _last_hit;
			["INFORMATION", Format ["RequestOnUnitKilled.sqf: [%1] Vehicle [%2] delayed kill attributed to last hitter [%3] after [%4] seconds.", _killed_side, _killed, _killer, round(time - _last_hit_time)]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

["INFORMATION", Format ["RequestOnUnitKilled.sqf: [%1] [%2] has been killed by [%3].", _killed_side, _killed, _killer]] Call WFBE_CO_FNC_LogContent;

if !(alive _killer) exitWith {}; //--- Killer is null or dead, nothing to see here.

//--- Retrieve basic information.
_killed_group = group _killed;
_killed_isman = if (_killed isKindOf "Man") then {true} else {false};
_killed_type = typeOf _killed;
_killer_group = group _killer;
_killer_isplayer = if (isPlayer _killer) then {true} else {false};
_killed_isplayer = if (isPlayer _killed) then {true} else {false};
_killer_iswfteam = if !(isNil {_killer_group getVariable "wfbe_funds"}) then {true} else {false};
_killer_side = side _killer;
_killer_type = typeOf _killer;
_killer_vehicle = vehicle _killer;
_killer_uid = getPlayerUID (leader _killer_group);


if (_killer_side == sideEnemy) then { //--- Make sure the killer is not renegade, if so, get the side from the config.
	if !(_killer isKindOf "Man") then {_killer_type = typeOf effectiveCommander(vehicle _killer)};
	_killer_side = switch (getNumber(configFile >> "CfgVehicles" >> _killer_type >> "side")) do {case 0: {east}; case 1: {west}; case 2: {resistance}; default {civilian}};
};

if (_killer_side == civilian) exitWith {}; //--- Side couldn't be determined? exit.

//--- Condition (a): own-side unit killed by enemy artillery.
//--- Arm wfbe_aicom_arty_threat on the VICTIM side's logic after >= 2 arty kills.
//--- Nil-guard the killer vehicle: disconnected/deleted killers are nil-prone.
if (_killer_side != _killed_side) then {
	_killerVehObj = if (!isNil "_killer") then {vehicle _killer} else {objNull};
	_isArtyKill = false;
	if (!isNull _killerVehObj) then {
		_isArtyKill = ([typeOf _killerVehObj, _killer_side] Call IsArtillery) >= 0;
	};
	if (_isArtyKill) then {
		_victimLogik = _killed_side Call WFBE_CO_FNC_GetSideLogic;
		if (!isNil "_victimLogik") then {
			_artyKillCount = _victimLogik getVariable ["wfbe_aicom_arty_kill_count", 0] + 1;
			_victimLogik setVariable ["wfbe_aicom_arty_kill_count", _artyKillCount];
			if (_artyKillCount >= 2 && {!(_victimLogik getVariable ["wfbe_aicom_arty_threat", false])}) then {
				_victimLogik setVariable ["wfbe_aicom_arty_threat", true];
				["INFORMATION", Format ["RequestOnUnitKilled.sqf: [%1] wfbe_aicom_arty_threat ARMED (cond-a: %2 units killed by enemy arty [%3]).", str _killed_side, _artyKillCount, typeOf _killerVehObj]] Call WFBE_CO_FNC_LogContent;
				diag_log ("AICOMSTAT|v1|EVENT|" + (str _killed_side) + "|" + str (round (time / 60)) + "|ARTY_THREAT_ARMED|cond-a|count=" + str _artyKillCount);
			};
		};
	};
};

//--- GUER "Insurgents" towns-denied (harass board): a GUER player killing an enemy within a GUER-held
//--- town's range "denies" that town. Per-player object accumulator (broadcast), emitted by the playerstat loop.
if (((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) && {_killer_side == resistance} && {_killer_isplayer} && {_killer_side != _killed_side}) then {
	private ["_kpos","_denied"];
	_kpos = getPosATL _killed;
	_denied = false;
	{
		if (((_x getVariable ["sideID", -1]) == WFBE_C_GUER_ID) && {(_kpos distance _x) < ((_x getVariable ["range", 300]) max 300)}) then {_denied = true};
	} forEach towns;
	if (_denied) then {_killer setVariable ["wfbe_guer_td", (_killer getVariable ["wfbe_guer_td", 0]) + 1, true]};
};

//--- B75 (guer-tech): cumulative GUER PLAYER-KILL counter. A resistance PLAYER killing a WEST/EAST unit advances
//--- the whole GUER side's kill-based tech (barracks AI cap, M113 VBIED, BRDM/T-34/T-55/T-72 tier, Ka-137 flares) -
//--- this REPLACES the old elapsed-time tier. Server-authoritative; publicVariable so every client (incl. the buy
//--- overlay + RHUD) reads it live. A2-OA publicVariable is NOT JIP-replayed, so Server_OnPlayerConnected.sqf seeds
//--- joiners and Server_GuerStipend.sqf re-broadcasts as a safety net. Same gate as the towns-denied block above.
if (((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) && {_killer_side == resistance} && {_killer_isplayer} && {_killer_side != _killed_side}) then {
	WFBE_GUER_PLAYER_KILLS = (missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0]) + 1;
	publicVariable "WFBE_GUER_PLAYER_KILLS";
	["INFORMATION", Format ["RequestOnUnitKilled.sqf: GUER tech kill credited (player [%1] killed [%2]). Total GUER kills = %3.", name _killer, _killed_type, WFBE_GUER_PLAYER_KILLS]] Call WFBE_CO_FNC_LogContent;
	//--- B75 (guer-tech): UNLOCK notifications. Kills increment by exactly 1 here, so an exact == threshold fires each
	//--- unlock once. Broadcast [seq, text]; the GUER overlay watcher (Root_GUE_PlayerOverlay.sqf) shows it.
	private ["_gMilestones","_gMsg"];
	_gMilestones = [
		[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_1", 15], "BRDM-2 + T-34 unlocked  -  Ka-137 flares up to 120"],
		[missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 25], "M113 VBIED unlocked  -  armoured suicide APC at 2x speed"],
		[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_2", 40], "T-55 unlocked  -  Ka-137 flares up to 240"],
		[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_3", 80], "T-72 + BMP-2 unlocked"]
	];
	_gMsg = "";
	{ if (WFBE_GUER_PLAYER_KILLS == (_x select 0)) then {_gMsg = _x select 1} } forEach _gMilestones;
	if (_gMsg != "") then {
		WFBE_GUER_UNLOCK_MSG = [WFBE_GUER_PLAYER_KILLS, _gMsg];
		publicVariable "WFBE_GUER_UNLOCK_MSG";
		["INFORMATION", Format ["RequestOnUnitKilled.sqf: GUER tech UNLOCK at %1 kills - %2.", WFBE_GUER_PLAYER_KILLS, _gMsg]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- GUER kill bounty: credit the killer's GUER team for WEST/EAST kills (server-side; bypasses the WFBE_C_UNITS_BOUNTY coef gate).
	if (((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) && {_killer_side == resistance} && {_killer_side != _killed_side} && {_killer_iswfteam}) then {
		private ["_guerKillGet","_guerBounty","_guerCoef","_iedRecent","_isIedKill"];
		//--- B67 (Ray 2026-06-21) item #3: IED anti-farm. If this kill was tagged as an IED kill by the killer's
		//--- Fired EH (Client_OnRespawnHandler.sqf stamps wfbe_ied_recent = time on a BAF_ied detonation), and that
		//--- stamp is within ~6s of now, pay only WFBE_C_GUER_IED_KILL_COEF (0.30) instead of the normal coef.
		//--- Null-safe: _killer already gated alive above (line 34); explicit isNull guard + nil-check on the stamp read.
		_isIedKill = false;
		if (!isNull _killer) then {
			_iedRecent = _killer getVariable ["wfbe_ied_recent", -1];
			if (isNil "_iedRecent") then {_iedRecent = -1};
			if (_iedRecent >= 0 && {(time - _iedRecent) <= 6}) then {_isIedKill = true};
		};
		_guerCoef = if (_isIedKill) then {
			missionNamespace getVariable ["WFBE_C_GUER_IED_KILL_COEF", 0.30]
		} else {
			missionNamespace getVariable ["WFBE_C_GUER_KILL_BOUNTY_COEF", 0.5]
		};
		_guerKillGet = missionNamespace getVariable _killed_type;
		_guerBounty = 0;
		if !(isNil "_guerKillGet") then { _guerBounty = round ((_guerKillGet select QUERYUNITPRICE) * _guerCoef) };
		if (_guerBounty > 0) then { [_killer_group, _guerBounty] Call WFBE_CO_FNC_ChangeTeamFunds };
	};

	// Player-stats: record resolved enemy kills after delayed vehicle attribution. No-op unless stats are enabled.
if (!(isNil "WFBE_C_STATS_ENABLED")) then {
	if (WFBE_C_STATS_ENABLED && (_killer_side != _killed_side)) then {
		private ["_attrUid","_idx"];
		_attrUid = if (_killer_isplayer) then {getPlayerUID _killer} else {getPlayerUID (leader _killer_group)};
		if (_attrUid != "") then {
			_idx = WFBE_STAT_KILLS_INFANTRY;
			if (!_killed_isman) then {
				if (_killed isKindOf "Air") then {
					_idx = WFBE_STAT_KILLS_AIR;
				} else {
					if (_killed isKindOf "StaticWeapon") then {_idx = WFBE_STAT_KILLS_STATIC} else {_idx = WFBE_STAT_KILLS_VEHICLE};
				};
			};
			[_attrUid, _idx, 1] call WFBE_SE_FNC_RecordStat;
			if (_killed_isplayer) then {[_attrUid, WFBE_STAT_PVP_KILLS, 1] call WFBE_SE_FNC_RecordStat};
		};
	};
	//--- B74.2: credit the DEATH to the killed player's own UID (any death cause; side-independent, so outside the enemy-only kills gate above).
	if (WFBE_C_STATS_ENABLED && _killed_isplayer) then {private "_deadUid"; _deadUid = getPlayerUID _killed; if (_deadUid != "") then {[_deadUid, WFBE_STAT_DEATHS, 1] call WFBE_SE_FNC_RecordStat}};
};

// WASPSTAT KILL telemetry (Task 10). Gate: WFBE_C_STATLOG must be 1.
if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
	private ["_wsk_killerUID","_wsk_victimUID","_wsk_killerSide","_wsk_victimSide","_wsk_weapon","_wsk_dist","_wsk_cat","_wsk_line","_wsk_hw"];
	_wsk_killerUID = if (_killer_isplayer) then {getPlayerUID _killer} else {""};
	_wsk_victimUID = if (_killed_isplayer) then {getPlayerUID _killed} else {""};
	_wsk_killerSide = str _killer_side;
	_wsk_victimSide = str _killed_side;
	// Weapon/vehicle class: what killed. Use typeOf the killing vehicle (may differ from killer's unit class).
	_wsk_weapon = typeOf (vehicle _killer);
	if (_wsk_weapon == "") then { _wsk_weapon = _killer_type };
	// Distance: guard against null killer (delayed attribution already resolved above).
	_wsk_dist = if !(isNull _killer) then { round(_killer distance _killed) } else { -1 };
	// Category based on killed unit type.
	_wsk_cat = "INF";
	if (!_killed_isman) then {
		if (_killed isKindOf "Air") then {
			_wsk_cat = "AIR";
		} else {
			if (_killed isKindOf "StaticWeapon") then {
				_wsk_cat = "STATIC";
			} else {
				if (_killed isKindOf "Building") then {
					// HQ vs generic structure distinguished by wfbe_structure_type
					if ((_killed getVariable ["wfbe_structure_type","NONE"]) == "Headquarters") then {
						_wsk_cat = "HQ";
					} else {
						_wsk_cat = "STRUCT";
					};
				} else {
					_wsk_cat = "VEH";
				};
			};
		};
	};
	// Hardware bucket of the DESTROYED object (free: _killed already in hand). Empty for infantry.
	// Lets the stats page show tanks/helis/jets/cars/ships destroyed without any new scan.
	_wsk_hw = "";
	if (!_killed_isman) then {
		_wsk_hw = if (_killed isKindOf "Helicopter") then {"HELI"} else {
			if (_killed isKindOf "Plane") then {"JET"} else {
				if (_killed isKindOf "Tank") then {"ARMOR"} else {
					if (_killed isKindOf "Ship") then {"SHIP"} else {
						if (_killed isKindOf "Car") then {"CAR"} else {"OTHER"}
					}
				}
			}
		};
	};
	if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
	WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
	_wsk_line = "WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|KILL|" + _wsk_killerUID + "|" + _wsk_victimUID + "|" + _wsk_killerSide + "|" + _wsk_victimSide + "|" + _wsk_weapon + "|" + str _wsk_dist + "|" + _wsk_cat + "|hw=" + _wsk_hw + "|vc=" + _killed_type;
	diag_log _wsk_line;
};

if (WF_A2_Vanilla) then { //--- Garbage Collector.
	if (!isServer || local player) then {_objects = (WF_Logic getVariable "trash") + [_killed];	WF_Logic setVariable ["trash",_objects,true];} else {_killed setVariable ["wfbe_trashed", true];_killed Spawn TrashObject};
} else {
	if (isServer) then {_killed setVariable ["wfbe_trashed", true];	_killed Spawn TrashObject};
	if (_killed_isplayer) then {_killed setVariable ["wfbe_trashed", true];	_killed Spawn TrashObject};
};

if (_killed_side in WFBE_PRESENTSIDES) then { //--- Update the statistics if needed.
	if (_killed_isman) then {[str _killed_side,'Casualties',1] Call UpdateStatistics} else {[str _killed_side,'VehiclesLost',1] Call UpdateStatistics};
};

//--- B35 (claude-gaming 2026-06-15): kill-exchange attribution. Credit the KILLER side when it downs an
//--- enemy (man or vehicle), so COMBATSTAT can report a per-side exchange ratio (killed/cas). Free counter,
//--- same UpdateStatistics path as the casualties write above; guarded so neutral/friendly-fire isn't counted.
if (_killer_iswfteam && {_killer_side in WFBE_PRESENTSIDES} && {_killer_side != _killed_side}) then {
	[str _killer_side,'KilledEnemy',1] Call UpdateStatistics;
};

_get = missionNamespace getVariable _killed_type; //--- Get the killed informations.

if (!isNil '_get' && _killer_iswfteam) then { //--- Make sure that type killed type is defined in the core files and that the killer is a WF team.
	if (_killer_side != _killed_side) then { //--- Normal kill.
		if (isPlayer (leader _killer_group)) then { //--- The team is lead by a player.
			_killer_award = objNull;
			if !(_killer_isplayer) then { //--- An AI is the killer.
				_killer_award = _killer;
                };

				_points = [_killed_type, _get] call WFBE_SE_FNC_AwardScorePlayer;

				_nameOfKilledUnit = _get select QUERYUNITLABEL;
				["INFORMATION", Format["Player %1 got %2 points for neutralizing %3", _killer, _points, _nameOfKilledUnit]] Call WFBE_CO_FNC_LogContent;
				// [_killer_uid, "AwardScore", [_points, _get]] Call WFBE_CO_FNC_SendToClients;

				if (isServer) then {
                	['SRVFNCREQUESTCHANGESCORE',[leader _killer_group, (score leader _killer_group) + _points]] Spawn WFBE_SE_FNC_HandlePVF;
                } else {
                	["RequestChangeScore", [leader _killer_group, (score leader _killer_group) + _points]] Call WFBE_CO_FNC_SendToServer;
                };

			if ((missionNamespace getVariable "WFBE_C_UNITS_BOUNTY") > 0) then {
			//--- Award the bounty if needed.
			if (_killed_isplayer && _killer_isplayer) then {
				//--- Card #66 (killstreak bounty): confirmed enemy player-vs-player kill. Increment the
				//--- KILLER's streak server-side (broadcast), and forward the VICTIM's pre-reset streak so
				//--- the client bounty award can multiply the payout by the killed player's streak.
				_killer setVariable ["wfbe_killstreak", (_killer getVariable ["wfbe_killstreak", 0]) + 1, true];
				[_killer_uid, "AwardBountyPlayer", [_killed, _victimStreak]] Call WFBE_CO_FNC_SendToClients;
			};

			[_killer_uid, "AwardBounty", [_killed_type, false, _killer_award]] Call WFBE_CO_FNC_SendToClients;

			if (vehicle _killed != _killed && alive _killed) then { //--- Kill assist (players in the same vehicle).
				{if (alive _x && isPlayer _x) then {[getPlayerUID(_x), "AwardBounty", [_killed_type, true]] Call WFBE_CO_FNC_SendToClients}} forEach ((crew (vehicle _killed)) - [_killer, player]);
			};

			};
		} else { //--- The team is lead by an AI.
			if ((missionNamespace getVariable "WFBE_C_AI_TEAMS_ENABLED") > 0 && isServer) then { //--- Award the kill to the AI team.
				_bounty = (_get select QUERYUNITPRICE) * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF");
				_bounty = _bounty - (_bounty % 1);
				[_killer_group, _bounty] Call ChangeTeamFunds;
				//--- punchy-AICOM KILL-REWARD (Ray 2026-06-17): unconditionally trickle the kill bounty
				//--- into the COMMANDER treasury (wfbe_aicom_funds) too. Separate bucket from the team
				//--- wallet (wfbe_funds) above - NOT a double-credit. Already server-gated (:229) and
				//--- enemy-only (:196). Credits any AI-led WF team (server-authoritative, enemy-only),
				//--- so the AI commander banks for kills its squads make, every kill.
				[_killer_side, _bounty] Call ChangeAICommanderFunds;
				//--- W12 Spoils of War: EXTRA bonus bounty into the war chest while the flag is active.
				private ["_w12Key","_w12Exp","_w12KillerSideText"];
				_w12KillerSideText = str _killer_side;
				_w12Key  = Format ["wfbe_aicom_spoils_%1", _w12KillerSideText];
				_w12Exp  = missionNamespace getVariable _w12Key;
				if (!isNil "_w12Exp" && {_w12Exp > time}) then {
					[_killer_side, _bounty] Call ChangeAICommanderFunds;
				};
			};
		};
	} else { //--- Teamkill.
		if (isPlayer (leader _killer_group) && _killer != _killed && !(_killed_type isKindOf "Building")) then {

		//--- Only applies to player groups.
			[_killer_uid, "LocalizeMessage", ['Teamkill']] Call WFBE_CO_FNC_SendToClients;
		};
	};
};

if(!isPlayer(_killed) && _killed_type isKindOf "Infantry")then{
	//--- D5 2026-06-19: index 0 is safe here. A2 OA EH indices are PER-TYPE, so this removes the
	//--- FIRST "killed" handler regardless of any Fired/incomingMissile EHs on the unit. AI-created
	//--- infantry get exactly one "killed" EH (Common_CreateUnit.sqf:125, added at creation), so
	//--- index 0 is always the correct (and only) one. Left as-is to avoid shifting behaviour.
	_killed removeEventHandler ["killed", 0];
};
