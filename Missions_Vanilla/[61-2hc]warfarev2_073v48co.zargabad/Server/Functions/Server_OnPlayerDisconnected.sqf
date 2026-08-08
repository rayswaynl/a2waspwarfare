/*
	Event Handler triggered everytime a player disconnect from the server, this file handle all the players disconnection.
	 Parameters:
		- User ID
		- User Name
*/

Private ['_buildings','_commander','_funds','_get','_hcGroup','_hcList','_hcKeep','_hq','_id','_isHCDisconnect','_name','_old_unit','_old_unit_group','_respawnLoc','_side','_team','_units','_uid','_playerScore','_oldScore','_playerScoreDiff','_result','_logik','_lease','_leaseExpires','_leaseGen'];
_uid = _this select 0;
_name = _this select 1;
_id = _this select 2;
_lease = [];
_leaseExpires = 0;
_logik = objNull;

sleep 0.5;

//--- Wait for a proper common & server initialization before going any further.
waitUntil {commonInitComplete && serverInitFull};

if (_name == '__SERVER__') exitWith {};

//--- cmdcon30 (Ray's stuck-join, 2026-06-30): clear the UID-keyed enrollment retry counter on disconnect.
//--- WFBE_CONNECT_RETRY_<uid> (Server_OnPlayerConnected) is cleared on enrollment SUCCESS but NEVER on
//--- disconnect - so once a JIP enrollment exhausts its 3 re-arms, a RE-JOIN with the same UID gets only a
//--- single resolver pass with no re-arm safety net (the cap is already maxed) and re-bails -> the player is
//--- permanently stuck (no team / HUD / markers) until a server restart. Clearing it here makes a fresh
//--- re-join always get the full 3-attempt self-heal again. A2-OA-1.64-safe (setVariable nil). HCs skip the
//--- resolver so they never hold this key - the clear is a harmless no-op for them.
if (_uid != "") then {missionNamespace setVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], nil]};

//--- jip-funds-latch-disc-clear (r69, 2026-07-31): mirror the CONNECT_RETRY clear above for the JIP
//--- funds latch. WFBE_JIP_LATCH<uid> (Server_OnPlayerConnected) dedupes the TWO funds-block resolve
//--- passes WITHIN A SINGLE join (its 15s window), but it is set on connect and NEVER cleared on
//--- disconnect - so a reconnect within 15s inherits the previous join's latch and SKIPS its funds
//--- reconcile. In the common same-slot case the vacated group still carries the wallet so the skip is
//--- harmless, but a fast reconnect that lands on a DIFFERENT vacated slot (disconnect never zeroes a
//--- group's wfbe_funds) shows that stale positive wallet, never triggers the client B76 funds self-heal
//--- (non-nil funds), and then corrupts the lock-step WFBE_JIP_USER<uid> record downward on the next
//--- RequestFundsRecord spend. Clearing here makes every genuine re-join run its record-authoritative
//--- funds reconcile. SAFE for the double-resolve guard: the re-join's FIRST pass re-sets the latch
//--- fresh, still catching that join's second pass. A2-OA-1.64-safe (setVariable nil). HCs never store
//--- the latch (they exit the connect handler before it is set) - the clear is a harmless no-op for them.
if (_uid != "") then {missionNamespace setVariable [Format ["WFBE_JIP_LATCH%1", _uid], nil]};

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
		//--- r35 HC-lifecycle: bare getVariable can nil-throw and abort the whole disconnect handler
		//--- (UID/OWNER keys never clear, demote spawn never arms). Default [] + prune nulls.
		_hcList = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
		if (typeName _hcList != "ARRAY") then {_hcList = []};
		if (!isNull _hcGroup) then {_hcList = _hcList - [_hcGroup]};
		_hcList = _hcList - [grpNull];
		_hcKeep = [];
		{ if (!isNull _x) then { if (!(_x in _hcKeep)) then {_hcKeep = _hcKeep + [_x]} } } forEach _hcList;
		missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", _hcKeep];
		missionNamespace setVariable [Format["WFBE_HEADLESS_OWNER_%1", _id], nil];
		if (_uid != "") then {
			missionNamespace setVariable [Format["WFBE_HEADLESS_%1", _uid], nil];
		};
		diag_log (Format ["HCSIDE|v1|disconnect|uid=%1|owner=%2|removed=%3", _uid, _id, str _hcGroup]);
		//--- hc-locality-group-owner (2026-07-30): after HC drop the engine transfers unit locality to the
		//--- server, but mission state still believes those groups are HC-resident (wfbe_aicom_hc=true).
		//--- AssignTowns/Execute then only publish wfbe_aicom_order (dead channel - no HC driver) and never
		//--- lay server-local waypoints => AI freeze until orphan-heal recycles (~3+ min later). Demote the
		//--- flag once units are server-local so the server path drives them; keep founded stamp for census.
		//--- Also clear sticky town HC owner for this dead owner so re-activation does not prefer a ghost.
		[_uid, _name, _id, _hcGroup] spawn {
			Private ["_uid","_name","_oldOwner","_oldGroup","_delay","_side","_sideText","_logik","_teams","_g","_ldr","_ldrOwner","_last","_age","_hcTeams","_live","_oldOwnerLive","_headingFresh","_headingStale","_headingUnknown","_demoted","_stickyCleared","_t"];
			_uid = _this select 0;
			_name = _this select 1;
			_oldOwner = _this select 2;
			_oldGroup = _this select 3;
			//--- Short settle so engine ownership transfer completes before we sample locality.
			sleep 2;
			_demoted = 0;
			{
				_side = _x;
				_logik = _side Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _logik && {!(isNil {_logik getVariable "wfbe_teams"})}) then {
					{
						_g = _x;
						if (!isNull _g && {[_g, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}) then {
							_ldr = leader _g;
							//--- r35 HC-lifecycle: demote when server-local OR ownership is dead/orphaned (owner 0 or still
							//--- the dropped HC owner). Local-only left groups stuck wfbe_aicom_hc=true while owner still
							//--- pointed at the dead client -> server path never laid waypoints until orphan-heal.
							if (!isNull _ldr && {alive _ldr} && {local _ldr || {(owner _ldr) == 0} || {(owner _ldr) == _oldOwner}}) then {
								_g setVariable ["wfbe_aicom_hc", false, true];
								if (!([_g, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool)) then {
									_g setVariable ["wfbe_aicom_founded", true, true];
								};
								_demoted = _demoted + 1;
							};
						};
					} forEach (_logik getVariable ["wfbe_teams", []]);
				};
			} forEach [west, east];
			_stickyCleared = 0;
			if ((missionNamespace getVariable ["WFBE_C_HC_DELEGATE_STICKY", 0]) > 0) then {
				if (!isNil "towns") then {
					{
						_t = _x;
						if (!isNull _t && {(_t getVariable ["wfbe_town_hc_owner", -1]) == _oldOwner}) then {
							_t setVariable ["wfbe_town_hc_owner", -1];
							_t setVariable ["wfbe_town_hc_owner_ts", -1];
							_stickyCleared = _stickyCleared + 1;
						};
					} forEach towns;
				};
			};
			diag_log (Format ["HCSIDE|v1|hcdrop-demote|uid=%1|owner=%2|demoted=%3|stickyCleared=%4", _uid, _oldOwner, _demoted, _stickyCleared]);
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

if (_uid == '' || _uid == '0') exitWith {};

//--- r84 enroll-abort-on-disconnect: bump this uid's disconnect sequence so any in-flight
//--- Server_OnPlayerConnected resolution loop (120s window, plus its re-arm chain) breaks early and
//--- does NOT re-arm for a session that has already ended. Placed ahead of the ghost/normal paths so
//--- even a pre-enrollment quit (nil WFBE_JIP_USER) is observed. A2-OA-1.64-safe 2-arg get/setVariable.
private "_dcSeq"; _dcSeq = missionNamespace getVariable [Format ["WFBE_CONNECT_DCSEQ_%1", _uid], 0];
missionNamespace setVariable [Format ["WFBE_CONNECT_DCSEQ_%1", _uid], _dcSeq + 1];

if ((missionNamespace getVariable ["WFBE_C_CHAT_RELAY", 0]) > 0) then {
	["LEAVE", _name, "player left"] Call WFBE_SE_FNC_ChatRelayEvent;
};

["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has left the game", _name, _uid]] Call WFBE_CO_FNC_LogContent;

//--- wiring-sweep 2026-07-22: WFBE_CLIENT_%1_OBJECTS cleanup removed - the only writer (the dead
//--- "track-playerobject" HandleSpecial case, zero senders) was removed with it; _get was always nil here.

//--- We attempt to get the player information in case that he joined before.
_get = missionNamespace getVariable format["WFBE_JIP_USER%1",_uid];
//--- r69b ghost-slot-on-pre-funds-disconnect (2026-07-31): a CIV-deferred / incomplete enroll can
//--- stamp wfbe_uid + teamleader (and possibly a wallet) BEFORE WFBE_JIP_USER is created. The old
//--- early-exit left that stamp forever -> ghost ownership blocks reclaim and leftover funds feed
//--- the vacated-wallet mint. Scan + release + zero; do not delete units here (no full team path).
if (isNil '_get') exitWith {
Private ["_ghostTeam"];
_ghostTeam = grpNull;
{
{
if !(isNil {_x getVariable "wfbe_uid"}) then {if ((_x getVariable "wfbe_uid") == _uid) then {_ghostTeam = _x}};
if !(isNull _ghostTeam) exitWith {};
} forEach ((_x Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_teams", []]);
if !(isNull _ghostTeam) exitWith {};
} forEach WFBE_PRESENTSIDES;
if !(isNull _ghostTeam) then {
_ghostTeam setVariable ["wfbe_uid", nil];
_ghostTeam setVariable ["wfbe_teamleader", nil];
_ghostTeam setVariable ["wfbe_funds", 0, true];
};
missionNamespace setVariable [Format ["WFBE_JIP_BODY_%1", _uid], nil];
["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] don't have any information stored (ghost uid released if present)", _name, _uid]] Call WFBE_CO_FNC_LogContent
};

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
//--- mission-core disconnect bughunt 2026-07-30: NEVER fall back to leader _team as the
//--- delete target. After sleep 0.5 the engine has usually already removed the player;
//--- wfbe_teamleader is often nil/dead, and leader _team is then an AI subordinate. Under
//--- WFBE_C_AI_TEAMS_JIP_PRESERVE=1 (param default 1) that AI is the unit we must KEEP -
//--- deleteVehicle on it wiped the preserved squad's leader and left orphaned AI.
_old_unit = _team getVariable "wfbe_teamleader";
if (isNil '_old_unit') then {
	_old_unit = objNull;
} else {
	if (isNull _old_unit) then {_old_unit = objNull} else {
		if !(alive _old_unit) then {_old_unit = objNull};
	};
};

//--- Prefer a unit still tagged isPlayer (narrow race before engine removal finishes).
if (isNull _old_unit) then {
	{
		if (isPlayer _x) exitWith {_old_unit = _x};
	} forEach (units _team);
};

if (isNull _old_unit) then {
	["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] body already gone (team [%3]); skip body teardown - do not delete AI leader.", _name, _uid, _team]] Call WFBE_CO_FNC_LogContent;
	//--- Drop stale JIP body binding when the unit is already gone (deleted refs still compare poorly on reconnect).
	missionNamespace setVariable [Format ["WFBE_JIP_BODY_%1", _uid], nil];
} else {
	_old_unit_group = group _old_unit;

	//--- We make sure that our disconnected player group was the same as the original, we simply set him back to his group otherwise).
	if (_old_unit_group != _team) then {
		//todo, check if we have at least 1 unit in the old squad.
		Private ["_entitie","_fillerClass"];
		_entitie = objNull;
		_fillerClass = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
		if ((count (units _old_unit_group)) < 2 && {!isNil "_fillerClass"} && {typeName _fillerClass == "STRING"}) then {
			_entitie = [_fillerClass, _old_unit_group, [0,0,0], _side] Call WFBE_CO_FNC_CreateUnit;
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
};

//--- If we choose not to keep the current units during this session, then we simply remove them.
//--- HQ handle always needed for preserve==0 vehicle scrub (body-teardown path may have skipped it).
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;

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

//--- r69b vacated-wallet-bleed (2026-07-31): the disconnect snapshot above wrote cash into
//--- WFBE_JIP_USER<uid> but historically LEFT the group's wfbe_funds untouched. A later joiner
//--- landing on that vacated slot with a nil/0 record (legit spend-to-0, or first-join race)
//--- hit Server_OnPlayerConnected's no-clobber path (or RequestFundsResend branch-2 rebroadcast)
//--- and MINTED the leftover into their wallet/record. Zero AFTER uid release so ChangeTeamFunds
//--- lock-step cannot re-enter SyncFundsRecord against this uid; same player reconnects from the
//--- record (authoritative). A2-OA-1.64-safe public setVariable.
_team setVariable ["wfbe_funds", 0, true];

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
			_lease = _logik getVariable "wfbe_commander_lease"; if (isNil "_lease") then {_lease = []};   //--- G1 guard, matches Common_CommanderLease
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
				[_side, (if (isNil {_logik getVariable "wfbe_commander_lease_gen"}) then {0} else {_logik getVariable "wfbe_commander_lease_gen"})] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown;
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

//--- r78: force-flush pending WASPSTAT buffer for this UID on disconnect. The periodic StatsFlush
//--- loop only emits on interval; a disconnect mid-window left deltas resident until the next tick
//--- (or forever if the round ended inside ENDGAME_HOLD < interval). Stamp the disconnect name so
//--- the segment still carries a display name after the unit object is gone. No-op when stats off
//--- or the UID is not dirty. Shared path with ROUNDEND terminal flush (RecordStat.sqf).
if (_uid != "" && {!isNil "WFBE_SE_FNC_FlushStatsDirty"}) then {
	if (!isNil "WFBE_STATS_DIRTY_UIDS" && {_uid in WFBE_STATS_DIRTY_UIDS}) then {
		[_uid, _name] call WFBE_SE_FNC_FlushStatsDirty;
	};
};

// Marty: When AntiStack is disabled, the score sampling loop is not running; skip DB persistence to avoid false missing-score errors.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	//--- object-var-namespace: still drop UID-keyed transient missionNamespace keys (FPV/auth).
	if (_uid != "") then {
		{
			missionNamespace setVariable [Format [_x, _uid], nil];
		} forEach [
			"wfbe_fpv_active_%1",
			"wfbe_fpv_next_%1",
			"wfbe_fpv_cap_server_%1",
			"wfbe_fpv_purchase_inflight_%1",
			"wfbe_fpv_purchase_result_server_%1",
			"wfbe_fpv_auth_last_%1",
			"WFBE_CO_CURRENT_SCORE_PLAYER_%1"
		];
	};
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

//--- object-var-namespace bughunt: CURRENT score is re-stamped every sample while online; keep OLD
//--- (used for next-join delta) but nil CURRENT so departed UIDs do not permanently occupy
//--- missionNamespace. Also drop FPV per-UID server keys that would otherwise linger all match.
if (_uid != "") then {
	missionNamespace setVariable [format ["WFBE_CO_CURRENT_SCORE_PLAYER_%1", _uid], nil];
	{
		missionNamespace setVariable [Format [_x, _uid], nil];
	} forEach [
		"wfbe_fpv_active_%1",
		"wfbe_fpv_next_%1",
		"wfbe_fpv_cap_server_%1",
		"wfbe_fpv_purchase_inflight_%1",
		"wfbe_fpv_purchase_result_server_%1",
		"wfbe_fpv_auth_last_%1"
	];
};

["INFORMATION", Format ["Server_PlayerDisconnected.sqf: Player [%1] [%2] has disconnected.", _name, _uid]] Call WFBE_CO_FNC_LogContent;
