/*
	Event Handler triggered everytime a player connect to the server, this file handle the first connection along with the JIP connections of a player.
	 Parameters:
		- User ID
		- User Name
*/

Private ['_funds','_get','_id','_max','_name','_sideJoined','_sideOrigin','_team','_uid','_units'];
_uid = _this select 0;
_name = _this select 1;
_id = _this select 2;

//--- Wait for a proper common & server initialization before going any further.
waitUntil {commonInitComplete && serverInitFull};

["INFORMATION", Format ["Server_PlayerConnected.sqf: Player [%1] [%2] has joined the game", _name, _uid]] Call WFBE_CO_FNC_LogContent;

//--- Skip this script if the server is trying to run this.
if (_name == '__SERVER__' || _uid == '' || local player) exitWith {};

//--- b761 (Ray 2026-06-26): a headless client is NOT a warfare player and must never run the human enrollment
//--- resolver - it reseats itself to a civilian group (Init_HC) so it always bails the 3-retry self-heal and
//--- adds fresh-round seat-magnet churn. Skip it once registered. WFBE_HEADLESS_<uid> is set ONLY for HCs
//--- (Server_HandleSpecial; cleared in Server_OnPlayerDisconnected), so a human can NEVER match this. (If the
//--- connected-hc PVF hasn't landed yet the HC harmlessly runs the resolver once; the stamp-on-demand tier
//--- below also excludes HCs because they never store a RequestJoin body.)
if (!isNil {missionNamespace getVariable [Format ["WFBE_HEADLESS_%1", _uid], nil]}) exitWith {
	diag_log Format ["[WFBE][B761 CONNECT] skip enrollment resolver for headless client [%1] [%2].", _name, _uid];
};

//--- We try to get the player and it's group from the playableUnits.
//--- B74.2.2: was 10 (a 5s ceiling). Widened to 60 (30s) so a JIP seat under heavy-AI / low-server-FPS
//--- load has time to surface in playableUnits with a resolved getPlayerUID before we bail. 30s matches
//--- the client-side join-retry cadence in Init_Client.sqf. Pure integer; the sleep 0.5 below is unchanged.
_max = 240;
_team = grpNull;

while {_max > 0 && isNull _team} do {
	//--- B748.1 PRIMARY (Ray 2026-06-24, the 6th-time fix): use the body the CLIENT handed us via RequestJoin
	//--- (Init_Client sends [player, side]; RequestJoin stores WFBE_JIP_BODY_<uid> = the real networked unit).
	//--- This ELIMINATES the playableUnits/wfbe_teams find-race that intermittently bailed "unresolved" -> no team/markers.
	private "_clientBody"; _clientBody = missionNamespace getVariable [Format ["WFBE_JIP_BODY_%1", _uid], objNull];
	if (!isNull _clientBody && {alive _clientBody} && {!isNil {(group _clientBody) getVariable "wfbe_side"}}) then {_team = group _clientBody};

	//--- Fallback A: find the seat in playableUnits by UID.
	if (isNull _team) then {
		{
			if (!isNull _x && {(getPlayerUID _x) == _uid} && {!isNil {(group _x) getVariable "wfbe_side"}}) exitWith {_team = group _x};
		} forEach playableUnits;
	};

	//--- B746 fallback (ROOT-CAUSE FIX for EAST mid-game JIP: no team / no money): under heavy AI a freshly
	//--- seated body can live in its registered wfbe_teams slot group before it surfaces in playableUnits, so
	//--- the old playableUnits-only lookup bailed and skipped team/funds/roster-push. Scan the side-logic slot
	//--- groups directly - mirrors Server_OnPlayerDisconnected.sqf (UID match here, wfbe_uid not stamped yet).
	if (isNull _team) then {
		{
			{
				{ if ((getPlayerUID _x) == _uid) exitWith {_team = group _x}; } forEach (units _x);
				if !(isNull _team) exitWith {};
			} forEach ((_x Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_teams", []]);
			if !(isNull _team) exitWith {};
		} forEach WFBE_PRESENTSIDES;
	};

	//--- b761 (Ray 2026-06-26) STAMP-ON-DEMAND: fresh-round HC seat-magnet churn (Init_HC reseat) can land a
		//--- human's body in a REAL synchronized editor slot whose GROUP was never wfbe_side-stamped at boot
		//--- (Init_Server ~718 stamps the boot-time group object only; nothing re-binds a connecting human), so
		//--- all three lookups above miss and the handler bails forever on a fresh round (mature rounds inherit a
		//--- bot's already-stamped slot and resolve instantly). Self-heal: if the RequestJoin body (humans only -
		//--- HCs never RequestJoin, so this excludes them) is genuinely one of the side-logic's synchronizedObjects
		//--- editor slots, re-stamp its CURRENT group in place (mirrors Init_Server 718-719) and adopt it into the
		//--- side's wfbe_teams (append, no-dup, broadcast). Guarded on isNull _team so a normal/mature join never
		//--- reaches here. A2-OA-1.64-safe: synchronizedObjects/side/group/getVariable/setVariable are all core.
		if (isNull _team && {(missionNamespace getVariable ["WFBE_C_ENROLL_STAMP_ON_DEMAND", 1]) > 0}) then {
			private ["_sod_body","_sod_g","_sod_side","_sod_logik","_sod_teams"];
			_sod_body = missionNamespace getVariable [Format ["WFBE_JIP_BODY_%1", _uid], objNull];
			if (!isNull _sod_body && {alive _sod_body} && {(getPlayerUID _sod_body) == _uid}) then {
				_sod_side = side _sod_body;
				_sod_logik = _sod_side Call WFBE_CO_FNC_GetSideLogic;
				//--- b762: v1 keyed on synchronizedObjects membership, but the LIVE RPT proved a JIP body is NOT a
				//--- synced editor object (it is a fresh controlled unit) so v1 MISSed. v2: the human's body sits in
				//--- a STABLE, real, unstamped group of his side; make THAT group his team. Gate: real side + side
				//--- logic exists + the body's group held identical for 2 consecutive checks (rides out the HC churn).
				if (!isNull _sod_logik && {(side _sod_body) in [west, east, resistance]} && {(group _sod_body) == (missionNamespace getVariable [Format ["WFBE_SOD_LASTG_%1", _uid], grpNull])}) then {
					_sod_g = group _sod_body;
					if (isNil {_sod_g getVariable "wfbe_side"}) then {
						_sod_g setVariable ["wfbe_side", _sod_side];
						_sod_g setVariable ["wfbe_persistent", true];
							_sod_g setVariable ["wfbe_funds", missionNamespace getVariable Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sod_side], true];
							_sod_g setVariable ["wfbe_queue", []];
							_sod_g setVariable ["wfbe_vote", -1, true];
							[_sod_g, false] Call SetTeamAutonomous;
							[_sod_g, ""] Call SetTeamRespawn;
							[_sod_g, -1] Call SetTeamType;
							[_sod_g, "towns"] Call SetTeamMoveMode;
							[_sod_g, [0,0,0]] Call SetTeamMovePos;
					};
					_sod_teams = _sod_logik getVariable ["wfbe_teams", []];
					if (!(_sod_g in _sod_teams)) then {
						_sod_teams = _sod_teams + [_sod_g];
						_sod_logik setVariable ["wfbe_teams", _sod_teams, true];
					};
					_team = _sod_g;
					missionNamespace setVariable [Format ["WFBE_SOD_LASTG_%1", _uid], nil]; diag_log Format ["[WFBE][B762 STAMP-ON-DEMAND] adopted [%1] [%2] OWN stable group as %3 team; wfbe_teams now %4", _name, _uid, _sod_side, count _sod_teams];
				} else {
					missionNamespace setVariable [Format ["WFBE_SOD_LASTG_%1", _uid], group _sod_body]; if (_max <= 1) then {diag_log Format ["[WFBE][B762 STAMP-ON-DEMAND] MISS [%1] [%2]: own group never stabilised / no side logic after window - escalate.", _name, _uid, _sod_side]};
				};
			};
		};

		if (isNull _team) then {sleep 0.5};
		_max = _max - 1;
};
if (!isNull _team) then {diag_log Format ["[WFBE][B746 CONNECT] team resolved for [%1] [%2] (%3 budget left)", _name, _uid, _max]};

//--- Make sure that we've found a team, otherwise we simply exit.
if (isNull _team) exitWith {
	diag_log Format ["[WFBE][B746 CONNECT] BAIL: [%1] [%2] unresolved after playableUnits + wfbe_teams fallback window.", _name, _uid];
	["WARNING", Format ["Server_PlayerConnected.sqf: Player [%1] [%2] not in warfare teams after the lookup window - re-arming enrollment.", _name, _uid]] Call WFBE_CO_FNC_LogContent;
	//--- B74.2.2: self-heal instead of abandoning the player forever. onPlayerConnected fires only ONCE with
	//--- no retry, so a JIP seat that was still slow to surface after 30s used to be stranded (no team / no
	//--- money / no vote / no marker feed). Re-dispatch the handler, UID-keyed and capped at 3 attempts so it
	//--- recovers a slow seat without ever looping forever. WFBE_SE_FNC_OnPlayerConnected is the compiled handler.
	private "_reTry"; _reTry = missionNamespace getVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], 0];
	if (_reTry < 3) then {
		diag_log Format ["[WFBE][B746 CONNECT] re-arming enrollment for [%1] [%2] (attempt %3/3).", _name, _uid, _reTry + 1];
		missionNamespace setVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], _reTry + 1];
		[_uid, _name, _id] spawn WFBE_SE_FNC_OnPlayerConnected;
	};
};

//--- Make sure that our client is a warfare client, the side variable is only defined for warfare slots, otherwise we simply exit.
_sideJoined = _team getVariable "wfbe_side";
if (isNil '_sideJoined') exitWith {
	diag_log Format ["[WFBE][B747.2 CONNECT] BAIL: [%1] [%2] resolved team %3 has nil wfbe_side (transient/non-slot group) - re-arming.", _name, _uid, _team];
	private "_reTryS"; _reTryS = missionNamespace getVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], 0];
	if (_reTryS < 3) then {missionNamespace setVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], _reTryS + 1]; [_uid, _name, _id] spawn WFBE_SE_FNC_OnPlayerConnected};
	["WARNING", Format ["Server_PlayerConnected.sqf: Player [%1] [%2] side couldn't be determined from team [%3].", _name, _uid, _team]] Call WFBE_CO_FNC_LogContent;
};

//--- B74.2.2: enrollment reached - clear the connect-retry budget so a later reconnect starts fresh.
missionNamespace setVariable [Format ["WFBE_CONNECT_RETRY_%1", _uid], nil];
missionNamespace setVariable [Format ["WFBE_SOD_LASTG_%1", _uid], nil]; //--- b762: clear the stamp-on-demand stability tracker on enrollment success.

//--- B63 (Ray 2026-06-21): INSTANT JIP catch-up for the own-side MARKER feeds. In A2-OA a
//--- publicVariable is not replayed to a client that joined after the broadcast, so a fresh
//--- joiner's WFBE_ACTIVE_AICOM_TEAMS / WFBE_ACTIVE_PATROLS are empty and their own commander-team
//--- + patrol arrows never draw (the long-standing "OPFOR can't see own team markers" bug). Push the
//--- current lists straight to THIS client so its marker loops paint at once. Placed BEFORE the
//--- first-join exitWith below so it runs for every warfare joiner. server_side_patrols re-broadcasts
//--- every ~20s as a safety net. (_id = this client's network id, valid for publicVariableClient.)
if (!isNil "WFBE_ACTIVE_AICOM_TEAMS") then {_id publicVariableClient "WFBE_ACTIVE_AICOM_TEAMS"};
if (!isNil "WFBE_ACTIVE_PATROLS") then {_id publicVariableClient "WFBE_ACTIVE_PATROLS"};
if (!isNil "WFBE_ACTIVE_GUER_AIR") then {_id publicVariableClient "WFBE_ACTIVE_GUER_AIR"}; //--- B67: GUER air-defense marker feed JIP catch-up.
if (!isNil "WFBE_GUER_PLAYER_KILLS") then {_id publicVariableClient "WFBE_GUER_PLAYER_KILLS"}; //--- B75: GUER kill-based tech counter JIP catch-up (drives buy pool + barracks AI cap + RHUD).
if (!isNil "WFBE_GUER_VEHICLE_TIER") then {_id publicVariableClient "WFBE_GUER_VEHICLE_TIER"}; //--- B75: GUER vehicle tier JIP catch-up (kill-derived).
if (!isNil "WFBE_GUER_FOB_AVAIL") then {_id publicVariableClient "WFBE_GUER_FOB_AVAIL"}; //--- B75: GUER FOB availability JIP catch-up (depot FOB trucks + RHUD).
diag_log format ["[WFBE][B63 JIP-MARK] pushed marker feeds to joiner %1 (aicom=%2, patrols=%3)", _name, count (missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []]), count (missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []])];

//--- B74.2.4 (Ray 2026-06-24, P0): re-broadcast the side's wfbe_teams to re-trigger object-state replication to
//--- THIS joiner. The team roster lives on the side logic (object setVariable, broadcast) but under heavy AI load
//--- it can be slow/stuck reaching a JIP/lobby client, leaving clientTeams empty (no funds/marker/vote-menu =
//--- unplayable). A same-value re-set with the public flag marks the variable dirty so the engine re-syncs it; the
//--- client's persistent B74.2.4 heal then applies it the moment it lands. A2-OA-safe: GetSideLogic -> side-logic
//--- OBJECT, plain getVariable. Runs before the first-join exitWith, so it fires for every warfare joiner.
private "_tlog"; _tlog = _sideJoined Call WFBE_CO_FNC_GetSideLogic;
if (!isNull _tlog && {!isNil {_tlog getVariable "wfbe_teams"}}) then {
	_tlog setVariable ["wfbe_teams", (_tlog getVariable "wfbe_teams"), true];
	diag_log format ["[WFBE][B74.2.4 TEAMS-REBC] re-broadcast wfbe_teams (count %1) for side %2 on connect of %3", count (_tlog getVariable "wfbe_teams"), _sideJoined, _name];
};

//--- B74.2.5 (Ray 2026-06-24, P0): PRIMITIVE ROSTER PUSH. Object setVariable-broadcast of wfbe_teams is NOT
//--- JIP-durable in A2-OA AND the array holds GROUP OBJECTS that arrive as broken/NULL refs on a late joiner,
//--- so the client's vote roster (isPlayer leader / name leader) and every wfbe_teams heal read nil/broken
//--- forever. Deliver a SIDE-KEYED PRIMITIVE roster the client can render WITHOUT group objects, over a channel
//--- A2-OA guarantees to a connected client: publicVariableClient of a missionNamespace var. Per player-led team:
//--- [leaderName(string), isPlayer(0/1), funds(number), groupId(string)]. Payload = [count, rows]. The client's
//--- EARLY addPublicVariableEventHandler (initJIPCompatible Part I) consumes it; the vote menus render rows from
//--- it and upgrade to live groups once wfbe_teams replicates (for vote CASTING). PRIMITIVES ONLY -> replicate
//--- cleanly. _id = this client's network id (valid here). Only WEST and EAST have a commander vote; GUER/
//--- resistance has no vote menu so no roster push is needed (also avoids a mismatched GUER key). A2-OA-1.64-safe:
//--- GetSideLogic OBJECT, plain getVariable, typeName ==, forEach, str; no isEqualType/findIf/pushBack.
if (_sideJoined in [west, east]) then {
	private ["_rlog","_rteams","_rows","_lead","_keyName"];
	_rlog = _sideJoined Call WFBE_CO_FNC_GetSideLogic;
	_rows = [];
	if (!isNull _rlog && {!isNil {_rlog getVariable "wfbe_teams"}}) then {
		_rteams = _rlog getVariable "wfbe_teams";
		if ((typeName _rteams) == "ARRAY") then {
			{
				if (!isNull _x) then {
					_lead = leader _x;
					if (!isNull _lead && {isPlayer _lead}) then {
						_rows = _rows + [[name _lead, 1, (_x getVariable ["wfbe_funds", 0]), str _x]];
					};
				};
			} forEach _rteams;
		};
	};
	_keyName = Format ["WFBE_JIP_ROSTER_%1", _sideJoined];
	missionNamespace setVariable [_keyName, [count _rows, _rows]];
	_id publicVariableClient _keyName;
	diag_log format ["[WFBE][B74.2.5 ROSTER-PUSH] pushed %1 player-team rows to joiner %2 (key %3, side %4)", count _rows, _name, _keyName, _sideJoined];
};

//--- We attempt to get the player informations in case that he joined before.
_get = missionNamespace getVariable format["WFBE_JIP_USER%1",_uid];

//--- We force the unit out of it's vehicle.
if !(isNull(assignedVehicle (leader _team))) then {
	unassignVehicle (leader _team);
	[leader _team] orderGetIn false;
	[leader _team] allowGetIn false;
};

//--- If we choose not to keep the current units during this session, then we simply remove them.
if ((missionNamespace getVariable "WFBE_C_AI_TEAMS_JIP_PRESERVE") == 0) then {
	["INFORMATION", Format ["Server_PlayerConnected.sqf: Team [%1] units are now being removed for player [%1] [%2].", _team, _name, _uid]] Call WFBE_CO_FNC_LogContent;
	_units = units _team;
	_units = _units + ([_team,false] Call GetTeamVehicles);
	{if (!isPlayer _x && !(_x in playableUnits)) then {deleteVehicle _x}} forEach _units;
};

//--- We 'Sanitize' the player, we remove the waypoints and we heal him.
_team Call WFBE_CO_FNC_WaypointsRemove;
(leader _team) setDammage 0;


//--- We store the player UID over the group, this allows us to easily fetch the disconnecting client original group.
_team setVariable ["wfbe_uid", _uid];
_team setVariable ["wfbe_teamleader", leader _team];
//--- Clear any orphan stamp so the GC reaper does not reclaim a reclaimed team.
_team setVariable ["wfbe_orphaned_at", nil];

//--- If AI delegation is enabled, we create a special variable for player based on his UID and ID.  FPS | Groups handled | Session ID.
if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") == 1) then {
	missionNamespace setVariable [format["WFBE_AI_DELEGATION_%1", _uid], [0,0,_id]];
};

//--- The player has joined for the first time.
if (isNil '_get') exitWith {
	/*
		UID | Cash | Side | Current Side | flag of first connect on a session
		The JIP system store the main informations about a client, the UID is used to track the player all along the session.
	*/
	missionNamespace setVariable [format["WFBE_JIP_USER%1",_uid], [_uid, 0, _sideJoined, _sideJoined, 0]];

	_team setVariable ["wfbe_funds", missionNamespace getVariable format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined], true];
	["INFORMATION", Format ["Server_PlayerConnected.sqf: Team [%1] Leader [%2] JIP Information have been stored for the first time.", _team, _uid]] Call WFBE_CO_FNC_LogContent;
};

//--- The player has already joined the session previously, we just need to update the informations.
_get set [3, _sideJoined];

//--- Get the previous informations.
_funds = _get select 1;
_sideOrigin = _get select 2;
_get set [4,1];
//--- Update the new informations.
missionNamespace setVariable [format["WFBE_JIP_USER%1",_uid], _get];

//--- Make sure that the player didn't teamswap.
if (_sideOrigin != _sideJoined) then {
	_funds = missionNamespace getVariable Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined];
};

//--- Set the current player funds.
_team setVariable ["wfbe_funds", _funds, true];