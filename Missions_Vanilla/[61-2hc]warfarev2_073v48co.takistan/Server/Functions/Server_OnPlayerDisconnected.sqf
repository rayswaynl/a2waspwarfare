/*
	Event Handler triggered everytime a player disconnect from the server, this file handle all the players disconnection.
	 Parameters:
		- User ID
		- User Name
*/

Private ['_buildings','_commander','_funds','_get','_hcGroup','_hq','_id','_isHCDisconnect','_name','_old_unit','_old_unit_group','_respawnLoc','_side','_team','_units','_uid','_playerScore','_oldScore','_playerScoreDiff','_result','_logik','_lease','_leaseExpires','_leaseGen'];
_uid = _this select 0;
_name = _this select 1;
_id = _this select 2;
_lease = [];
_leaseExpires = 0;
_logik = objNull;

sleep 0.5;

//--- Wait for a proper common & server initialization before going any further.
waitUntil {commonInitComplete && serverInitFull};

if (_name == '__SERVER__' || local player) exitWith {};

//--- cmdcon30 (Ray's stuck-join, 2026-06-30): clear the UID-keyed enrollment retry counter on disconnect.
//--- WFBE_CONNECT_RETRY_<uid> (Server_OnPlayerConnected) is cleared on enrollment SUCCESS but NEVER on
//--- disconnect - so once a JIP enrollment exhausts its 3 re-arms, a RE-JOIN with the same UID gets only a
//--- single resolver pass with no re-arm safety net (the cap is already maxed) and re-bails -> the player is
//--- permanently stuck (no team / HUD / markers) until a server restart. Clearing it here makes a fresh
//--- re-join always get the full 3-attempt self-heal again. A2-OA-1.64-safe (setVariable nil). HCs skip the
//--- resolver so they never hold this key - the clear is a harmless no-op for them.
if (_uid != "") then {missionNamespace setVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], nil]};

//--- Headless Clients disconnection?.
_isHCDisconnect = false;
_hcGroup = grpNull;
if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") == 2) then {
	if (_uid != "") then {
		_get = missionNamespace getVariable Format["WFBE_HEADLESS_%1", _uid];
		if !(isNil '_get') then {_hcGroup = _get; _isHCDisconnect = true};
	};
	if (!_isHCDisconnect && {_uid == ""}) then {
		_get = missionNamespace getVariable Format["WFBE_HEADLESS_OWNER_%1", _id];
		if !(isNil '_get') then {_hcGroup = _get; _isHCDisconnect = true};
	};
	if (_isHCDisconnect) then {
		missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", (missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID") - [_hcGroup]];
		missionNamespace setVariable [Format["WFBE_HEADLESS_OWNER_%1", _id], nil];
		if (_uid != "") then {
			missionNamespace setVariable [Format["WFBE_HEADLESS_%1", _uid], nil];
		};
		diag_log (Format ["HCSIDE|v1|disconnect|uid=%1|owner=%2|removed=%3", _uid, _id, str _hcGroup]);
		[_uid, _name, _id, _hcGroup] spawn {
			Private ["_uid","_name","_oldOwner","_oldGroup","_delay","_side","_sideText","_logik","_teams","_g","_ldr","_ldrOwner","_last","_age","_hcTeams","_live","_oldOwnerLive","_headingFresh","_headingStale","_headingUnknown"];
			_uid = _this select 0;
			_name = _this select 1;
			_oldOwner = _this select 2;
			_oldGroup = _this select 3;
			{
				_delay = _x;
				sleep _delay;
				{
					_side = _x;
					_sideText = str _side;
					_hcTeams = 0; _live = 0; _oldOwnerLive = 0; _headingFresh = 0; _headingStale = 0; _headingUnknown = 0;
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
										if (_ldrOwner == _oldOwner) then {_oldOwnerLive = _oldOwnerLive + 1};
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
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HCDROP_AICOM_AUDIT|delay=" + str _delay + "|uid=" + _uid + "|name=" + _name + "|owner=" + str _oldOwner + "|group=" + str _oldGroup + "|teams=" + str _hcTeams + "|live=" + str _live + "|oldOwnerLive=" + str _oldOwnerLive + "|headingFresh=" + str _headingFresh + "|headingStale=" + str _headingStale + "|headingUnknown=" + str _headingUnknown);
				} forEach [west, east];
			} forEach [0, 60];
		};
		["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Headless client [%1] [%2] owner [%3] has left the game.", _name, _uid, _id]] Call WFBE_CO_FNC_LogContent;
	};
};
if (_isHCDisconnect) exitWith {};

if (_uid == '') exitWith {};

if ((missionNamespace getVariable ["WFBE_C_CHAT_RELAY", 0]) > 0) then {
	["LEAVE", _name, "player left"] Call WFBE_SE_FNC_ChatRelayEvent;
};

["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has left the game", _name, _uid]] Call WFBE_CO_FNC_LogContent;

//--- Player had any objects created?
_get = missionNamespace getVariable Format ["WFBE_CLIENT_%1_OBJECTS", _uid];
if !(isNil '_get') then {
	{if !(isNil '_x') then {deleteVehicle _x}} forEach _get;
	missionNamespace setVariable [Format ["WFBE_CLIENT_%1_OBJECTS", _uid], nil];
};

//--- We attempt to get the player information in case that he joined before.
_get = missionNamespace getVariable format["WFBE_JIP_USER%1",_uid];
if (isNil '_get') exitWith {["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] don't have any information stored", _name, _uid]] Call WFBE_CO_FNC_LogContent};

//--- Determine the root team.
_side = _get select 3;

_team = grpNull;
{
	{
		if !(isNil {_x getVariable "wfbe_uid"}) then {if ((_x getVariable "wfbe_uid") == _uid) then {_team = _x}};
		if !(isNull _team) exitWith {};
	//--- kimi/bughunt-mission-core (2026-07-20): 2-arg default - the resistance logic only gets
	//--- wfbe_teams inside the WFBE_C_GUER_PLAYERSIDE gate (Init_Server.sqf:910), so with the faction
	//--- gated off this read was nil and forEach nil errored before the graceful null-team bail
	//--- below (mirrors the connect-side twin Server_OnPlayerConnected.sqf:63, already 2-arg).
	} forEach ((_x Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_teams", []]);
	if !(isNull _team) exitWith {};
} forEach WFBE_PRESENTSIDES;

if (isNull _team) exitWith {["WARNING", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] team is null", _name, _uid]] Call WFBE_CO_FNC_LogContent};

//--- We attempt to fetch the client old unit, we need to check if it's group is the right one (on the fly group swapping).
_old_unit = _team getVariable "wfbe_teamleader";
if (isNil '_old_unit') then {
	_old_unit = objNull;
} else {
	if !(alive _old_unit) then {_old_unit = objNull};
};

if (isNull _old_unit) then {
	_old_unit = leader _team;
	["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] current team leader is dead or nil, using original team leader [%3].", _name, _uid, _team]] Call WFBE_CO_FNC_LogContent;
};
_old_unit_group = group _old_unit;

//--- Make sure that our disconnected player group was the same as the original, we simply set him back to his group otherwise).
if (_old_unit_group != _team) then {
	//todo, check if we have at least 1 unit in the old squad.
	Private ["_entitie"];
	_entitie = objNull;
	if ((count (units _old_unit_group)) < 2) then {
		_entitie = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side], _old_unit_group, [0,0,0], _side] Call WFBE_CO_FNC_CreateUnit;
	};

	[_old_unit] joinSilent _team;

	if !(isNull _entitie) then {deleteVehicle _entitie};

	["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] was in team [%3] and has been transfered to it's source team [%4].", _name, _uid, _old_unit_group, _team]] Call WFBE_CO_FNC_LogContent;

	//--- Make sure that the disconnected unit is the leader of it's group now.
	if (leader _team != _old_unit) then {
		_team selectLeader _old_unit;
		["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has been set as the leader of it's source team [%3].", _name, _uid, _team]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- We force the unit out of it's vehicle.
if !(isNull(assignedVehicle _old_unit)) then {
	unassignVehicle _old_unit;
	[_old_unit] orderGetIn false;
	[_old_unit] allowGetIn false;
};

//--- Eject the unit if it's in the HQ.
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (vehicle _old_unit == _hq) then {_old_unit action ["EJECT", _hq]};

//--- JIP-replay hardening, Finding #1 (stale WFBE_JIP_BODY_<uid> on rapid reconnect): RequestJoin.sqf
//--- stores this binding on join but never clears it on disconnect, and this handler's own 0.5s sleep at
//--- the top of the file (before commonInitComplete/serverInitFull) leaves a ~0.5-1s window where a fast
//--- same-UID reconnect can resolve into (and re-stamp) this about-to-be-deleted body via
//--- Server_OnPlayerConnected.sqf's PRIMARY resolver tier, only to have it deleted out from under the
//--- reconnected player a moment later. IDENTITY-GATED: only clear the binding if it still points at the
//--- EXACT unit we are tearing down (_old_unit) - if a reconnect already landed and rebound it to a NEW
//--- body, the stored reference no longer equals _old_unit and this leaves that newer binding untouched.
//--- Pure addition; does not touch RequestJoin.sqf or the connect-side resolver.
//--- REACH NOTE (review-1253): _old_unit is the CURRENT wfbe_teamleader, which is re-stamped on every
//--- respawn (Server_HandleSpecial.sqf:12), but WFBE_JIP_BODY_<uid> is stamped ONLY once, at the initial
//--- RequestJoin. So for any player who has respawned at least once (the normal case in a live match),
//--- stored != _old_unit here and this clear is a no-op on their disconnect - not a regression (that
//--- stale first-join body was already excluded by the connect resolver's alive-check), just a narrower
//--- practical reach than the fix name implies: it only protects "disconnect while still on the
//--- first-ever join body, before any respawn." Closing the general reconnect race for a
//--- since-respawned player needs the generation/token variant, which requires stamping RequestJoin.sqf -
//--- owner-locked, out of scope here.
if ((missionNamespace getVariable [Format ["WFBE_JIP_BODY_%1", _uid], objNull]) == _old_unit) then {
	missionNamespace setVariable [Format ["WFBE_JIP_BODY_%1", _uid], nil];
};

deleteVehicle _old_unit;

//--- If we choose not to keep the current units during this session, then we simply remove them.
if ((missionNamespace getVariable "WFBE_C_AI_TEAMS_JIP_PRESERVE") == 0) then {
	["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] units are now being removed for AI Team [%3].", _name, _uid, _team]] Call WFBE_CO_FNC_LogContent;
	_units = units _team;
	_units = _units + ([_team,false] Call GetTeamVehicles) - [_hq];
	{if (!isPlayer _x && !(_x in playableUnits)) then {deleteVehicle _x}} forEach _units;
} else {
	//--- Preserve==1: AI subordinates remain. Stamp the team so the GC reaper can
	//--- reclaim it if the player never reconnects within the zombie timeout.
	_team setVariable ["wfbe_orphaned_at", time];
};

//--- We save the disconnect client funds.
_funds = _team Call GetTeamFunds;
_get set [1,_funds];

//--- wiki-wins: removed dead block — _old_unit was already deleteVehicle'd above (~line 102), so this
//--- setPos (and the GetClosestEntity it fed with the now-null _old_unit) were no-ops. The B74.1
//--- "_buildings undefined" guard was only masking that dead path.

//--- Update the new informations.
missionNamespace setVariable [format["WFBE_JIP_USER%1",_uid], _get];

//--- wiki-wins: prune the departing player's row from the supply player-list (it was never removed; the list grew with stale/null refs over a long session).
if !(isNil "WFBE_SE_PLAYERLIST") then {
	private "_prunedPL"; _prunedPL = [];
	{ if ((_x select 1) != _uid) then {_prunedPL set [count _prunedPL, _x]} } forEach WFBE_SE_PLAYERLIST;
	WFBE_SE_PLAYERLIST = _prunedPL;
};

//--- Release the UID.
_team setVariable ["wfbe_uid", nil];
_team setVariable ["wfbe_teamleader", nil];

//--- If AI delegation is enabled, we remove the player's variable.
if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") == 1) then {
	missionNamespace setVariable [format["WFBE_AI_DELEGATION_%1", _uid], nil];
};

//--- If the player was the commander, we warn the team and sanitize the commander informations.
_commander = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
if !(isNull (_commander)) then {
	if (_team == _commander) then {
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
			_lease = _logik getVariable ["wfbe_commander_lease", []];
			if (typeName _lease == "ARRAY" && {count _lease >= 6} && {(_lease select 0) == _uid} && {(_lease select 1) == _side} && {(_lease select 2) == (str _team)}) then {
				_leaseGen = _lease select 5;
				_leaseExpires = time + (missionNamespace getVariable ["WFBE_C_CMD_LEASE_GRACE", 90]);
				_logik setVariable ["wfbe_commander_lease_expires", _leaseExpires];
				[_side, _leaseExpires, _leaseGen] Spawn WFBE_CO_FNC_CommanderLeaseGraceCheck;
			} else {
				//--- Round-3 review (P1-3): the lease-mismatch case no longer nulls state directly here -
				//--- it ENQUEUES a stand-down targeting the CURRENT generation so the single executor
				//--- remains the sole effects writer. If something newer has already superseded this
				//--- state by the time the executor processes it, the request is a safe no-op.
				[_side, (_logik getVariable ["wfbe_commander_lease_gen", 0])] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown;
			};
		} else {
			Private ["_logik"];
			_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
			_logik setVariable ["wfbe_commander", objNull, true];

			[_side, "LocalizeMessage", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;

			//--- AI Can move freely now & respawn at the default location.
			{[_x,false] Call SetTeamAutonomous;[_x, ""] Call SetTeamRespawn} forEach (_logik getVariable "wfbe_teams");
		};
	};
};

// Marty: When AntiStack is disabled, the score sampling loop is not running; skip DB persistence to avoid false missing-score errors.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", Format ["Server_PlayerDisconnected.sqf: AntiStack is disabled; skipped score DB save for player [%1] [%2].", _name, _uid]] Call WFBE_CO_FNC_LogContent;
};

//--- Save the player stats to database.
_playerScore = missionNamespace getVariable format ["WFBE_CO_CURRENT_SCORE_PLAYER_%1", _uid];

if (isNil "_playerScore") then {
	_playerScore = 0;
	["ERROR", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has no score to be saved upon disconnection. This can be caused by immediate disconnection from the match after joining, or it can be something fishy.", _name, _uid]] Call WFBE_CO_FNC_LogContent;
};

_oldScore = missionNamespace getVariable format ["WFBE_CO_OLD_SCORE_PLAYER_%1", _uid];

if (isNil "_oldScore") then {
	_oldScore = 0;
};

missionNamespace setVariable [format["WFBE_CO_OLD_SCORE_PLAYER_%1", _uid], _playerScore];

_playerScoreDiff = _playerScore - _oldScore;

_result = ["STORE", [_uid, _playerScoreDiff]] call WFBE_SE_FNC_CallDatabaseStore;
_result = ["STORE_SIDE", [_uid, "NONE"]] call WFBE_SE_FNC_CallDatabaseStoreSide;

["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has disconnected.", _name, _uid]] Call WFBE_CO_FNC_LogContent;
