/*
	Event Handler triggered everytime a player connect to the server, this file handle the first connection along with the JIP connections of a player.
	 Parameters:
		- User ID
		- User Name
*/

Private ['_funds','_get','_id','_jipLogik','_jipSupplyKey','_max','_name','_oldLease','_oldLogic','_prevSideJoined','_sideJoined','_sideOrigin','_team','_uid','_units'];
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
//--- (Server_HandleSpecial; cleared in Server_OnPlayerDisconnected), so a human can NEVER match this regardless
//--- of player name. This is the SOLE HC-identification gate: stamp-based, un-spoofable. (If the connected-hc
//--- PVF hasn't landed yet the HC harmlessly runs the resolver once then re-arms; the stamp-on-demand tier
//--- below also excludes HCs because they never store a RequestJoin body.)
if (!isNil {missionNamespace getVariable [Format ["WFBE_HEADLESS_%1", _uid], nil]}) exitWith {
	diag_log Format ["[WFBE][B761 CONNECT] skip enrollment resolver for headless client [%1] [%2].", _name, _uid];
};

//--- Server-observable fallback event. No client payload or chat hook is involved.
if ((missionNamespace getVariable ["WFBE_C_CHAT_RELAY", 0]) > 0 && {_uid != ""}) then {
	["JOIN", _name, "player joined"] Call WFBE_SE_FNC_ChatRelayEvent;
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

//--- CIV-DRIFT ENROLLMENT SELF-HEAL (fix/civ-drift-enroll-heal, Ray 2026-07-21, live RPT evidence -
//--- player "Zwanon" fought AS WEST per kill log while his resolved team's wfbe_side read CIV, so the
//--- funds guard below deferred forever: "[WFBE][JIPFUNDS] side unresolved (CIV) ... funds block
//--- deferred"). The b761/b762 STAMP-ON-DEMAND above only fires when this WHOLE loop found NOTHING
//--- (isNull _team) - it repairs an UNSTAMPED group. This is the other half of that gap: the loop DID
//--- find a team (via B748.1/B746 above), but that team's GROUP was already EXPLICITLY wfbe_side-
//--- stamped CIV. `side player` cannot be read here (server-side, no local player) and drifts anyway -
//--- we read the player's REAL faction off the same networked body B748.1/b762 already trust
//--- (WFBE_JIP_BODY_<uid>, never a scripted "player" global), via `side _civd_body`. Same 2-poll
//--- stability idea as b762 (WFBE_CIVDRIFT_LASTG_<uid>): this file resolves TWICE per connect
//--- (documented above the JIPFUNDS guard below), so the SECOND pass must reconfirm the SAME
//--- (group, real-side) pair before we commit - a genuinely transient mid-sync CIV read (side not
//--- yet replicated) will not match twice and is left alone for the existing tiers to resolve normally;
//--- a persistent mis-stamp (the live case) matches and heals. Re-stamp mirrors the first-join stamp
//--- (Init_Server.sqf ~883-884): wfbe_side + wfbe_persistent, funds seeded ONLY if nil (never clobbers
//--- an existing wallet - same no-clobber spirit as the JIPFUNDS guard further below), and an append-
//--- once addition to the real side's wfbe_teams (dedup-guarded, mirrors b762's own append exactly).
//--- Idempotent: once healed, wfbe_side is no longer civilian so this whole block no-ops on every later
//--- pass/reconnect. Touches nothing in RequestJoin.sqf, the JIP handshake, or funds math. A2-OA-1.64-
//--- safe: plain single-arg getVariable on the GROUP (_team), array-default getVariable on the LOGIC
//--- object only, 2-element missionNamespace setVariable, array + (no pushBack), private ["_x"] form.
if (!isNull _team && {(missionNamespace getVariable ["WFBE_C_ENROLL_CIVDRIFT_HEAL", 1]) > 0}) then {
	private ["_civd_wside","_civd_body","_civd_real","_civd_key","_civd_logik","_civd_teams"];
	_civd_key = Format ["WFBE_CIVDRIFT_LASTG_%1", _uid];
	_civd_wside = _team getVariable "wfbe_side";
	if (isNil "_civd_wside" || {_civd_wside != civilian}) then {
		missionNamespace setVariable [_civd_key, nil];
	} else {
		_civd_body = missionNamespace getVariable [Format ["WFBE_JIP_BODY_%1", _uid], objNull];
		_civd_real = civilian;
		if (!isNull _civd_body && {alive _civd_body} && {(getPlayerUID _civd_body) == _uid}) then {_civd_real = side _civd_body};
		if (_civd_real in [west, east, resistance]) then {
			if ((missionNamespace getVariable [_civd_key, grpNull]) == _team) then {
				_team setVariable ["wfbe_side", _civd_real];
				_team setVariable ["wfbe_persistent", true];
				if (isNil {_team getVariable "wfbe_funds"}) then {
					_team setVariable ["wfbe_funds", missionNamespace getVariable Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _civd_real], true];
				};
				//--- WALLET-WIPE GUARD (round-2 adversarial review, 2026-07-21): a CIV-drifted player never
				//--- passed the JIPFUNDS CIV-check (further below) on any prior connect, so WFBE_JIP_USER<uid>
				//--- was NEVER created for them. Left alone, THIS SAME healing pass would read `_get` as nil
				//--- and fall into the JIPFUNDS "first join" branch, which does an UNCONDITIONAL
				//--- wfbe_funds = FUNDS_START reset with no no-clobber guard - silently wiping whatever this
				//--- team actually earned while drifted (Common_ChangeTeamFunds.sqf credits funds with no
				//--- wfbe_side check, so a CIV-stamped team keeps earning real money the whole time). Pre-seed
				//--- the record ONLY if genuinely absent (never clobbers a real pre-drift record) so the
				//--- JIPFUNDS section below instead takes its ordinary reconnect-update path: cash = the
				//--- team's ACTUAL current wallet (not FUNDS_START) and sideOrigin == _civd_real so its own
				//--- teamswap check (sideOrigin != sideJoined) can't ALSO reset the funds. Record shape
				//--- matches the first-join write exactly: [uid, cash, sideOrigin, sideJoined, hasConnectedBefore-flag].
				if (isNil {missionNamespace getVariable format ["WFBE_JIP_USER%1", _uid]}) then {
					missionNamespace setVariable [format ["WFBE_JIP_USER%1", _uid], [_uid, (_team getVariable "wfbe_funds"), _civd_real, _civd_real, 1]];
					diag_log Format ["[WFBE][CIVDRIFT HEAL] pre-seeded WFBE_JIP_USER%1 (wallet %2, side %3) so the JIPFUNDS first-join branch does not reset it.", _uid, (_team getVariable "wfbe_funds"), _civd_real];
				};
				_civd_logik = _civd_real Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _civd_logik) then {
					_civd_teams = _civd_logik getVariable ["wfbe_teams", []];
					if (!(_team in _civd_teams)) then {
						_civd_teams = _civd_teams + [_team];
						_civd_logik setVariable ["wfbe_teams", _civd_teams, true];
					};
				};
				missionNamespace setVariable [_civd_key, nil];
				diag_log Format ["[WFBE][CIVDRIFT HEAL] re-stamped [%1] [%2] team %3 CIV -> %4 (real body side, 2-poll confirmed).", _name, _uid, _team, _civd_real];
			} else {
				missionNamespace setVariable [_civd_key, _team];
				diag_log Format ["[WFBE][CIVDRIFT HEAL] observed [%1] [%2] team %3 CIV-stamped while body plays %4 - awaiting stability confirm.", _name, _uid, _team, _civd_real];
			};
		};
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
if (!isNil "AICOMV2_GDIR_JIP_SNAP") then {_id publicVariableClient "AICOMV2_GDIR_JIP_SNAP"}; //--- J10: GUER Director snapshot is not JIP-durable in A2-OA; target the current value to this joiner.
if (!isNil "WFBE_PopTier") then {_id publicVariableClient "WFBE_PopTier"}; //--- B74.2: player-pop tier JIP catch-up (AI cap + RHUD scaling).
//--- fable/fob-polish (2026-07-07): replay ACTIVE GUER FOB markers to a GUER late joiner (#846 known gap).
//--- WildcardMarker creates are fire-and-forget publicVariables, so a client that joined after the broadcast
//--- never saw them. The server-side WFBE_GUER_FOB_ACTIVE ledger (added in RequestFOBStructure, retired in
//--- Server_BuildingKilled's GuerFobCleared branch) is replayed with a TARGETED publicVariableClient of the
//--- same wire payload WFBE_CO_FNC_SendToClients builds, so ONLY the joiner re-receives it (no side-wide
//--- re-create, no repeated command-chat line). The client handler is idempotent (delete-then-create).
//--- Spawned so the connect handler is not delayed; the sleep keeps successive writes to the same PV name
//--- from coalescing into a single delivery. The ledger is copied (+) so a concurrent clear cannot mutate
//--- the array mid-iteration.
if ((_sideJoined == resistance) && {(count (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []])) > 0}) then {
	[_id, _name] Spawn {
		private ["_rid","_rname","_fobReplay"];
		_rid = _this select 0;
		_rname = _this select 1;
		_fobReplay = + (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
		diag_log Format ["[WFBE][FOB-JIP] replaying %1 active FOB marker(s) to joiner %2", count _fobReplay, _rname];
		{
			WFBE_PVF_WildcardMarker = [resistance, "CLTFNCWildcardMarker", ["create", _x select 0, _x select 1, "ColorGreen", "mil_objective", Format ["FOB %1", _x select 2], "forward base active - spawn and resupply here"]];
			_rid publicVariableClient "WFBE_PVF_WildcardMarker";
			sleep 0.5;
		} forEach _fobReplay;
	};
};

//--- B63.2: late joiners also need side logic/object economy state that is only published on change.
//--- wfbe_upgrades lives on the side logic object, so re-setting the same value with public=true dirties the
//--- object var for replication; side supply is a missionNamespace primitive and can be targeted directly.
_jipLogik = _sideJoined Call WFBE_CO_FNC_GetSideLogic;
if !(isNull _jipLogik) then {
	if !(isNil {_jipLogik getVariable "wfbe_upgrades"}) then {
		_jipLogik setVariable ["wfbe_upgrades", (_jipLogik getVariable "wfbe_upgrades"), true];
		diag_log format ["[WFBE][B63.2 JIP-UPGRADES] re-broadcast wfbe_upgrades (count %1) for side %2 to joiner %3", count (_jipLogik getVariable "wfbe_upgrades"), _sideJoined, _name];
	};
};

//--- JIP-replay hardening, Finding #3 (HQ/base snapshot): wfbe_hq/wfbe_hq_deployed/wfbe_startpos/
//--- wfbe_structures/wfbe_basearea are set once at boot (Init_Server.sqf ~762-790) and otherwise only
//--- change on HQ deploy/kill/repair or base-area capture, so they never get an automatic connect-time
//--- catch-up today (only wfbe_teams does, above/below). RequestTeamsResend.sqf's own header documents an
//--- RPT-traced incident proving THIS SAME side-logic object slow-syncs to a late joiner under heavy AI
//--- load - and Init_Client.sqf:1136-1188 waits unbounded on wfbe_startpos/wfbe_hq/wfbe_structures/
//--- wfbe_hq_deployed, with an invalid spawn position as the worst case. Same same-value re-set idiom as
//--- wfbe_upgrades above - re-set marks the object var dirty so the engine re-syncs it to this joiner.
if !(isNull _jipLogik) then {
	if !(isNil {_jipLogik getVariable "wfbe_hq"}) then {
		_jipLogik setVariable ["wfbe_hq", (_jipLogik getVariable "wfbe_hq"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_hq_deployed"}) then {
		_jipLogik setVariable ["wfbe_hq_deployed", (_jipLogik getVariable "wfbe_hq_deployed"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_startpos"}) then {
		_jipLogik setVariable ["wfbe_startpos", (_jipLogik getVariable "wfbe_startpos"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_structures"}) then {
		_jipLogik setVariable ["wfbe_structures", (_jipLogik getVariable "wfbe_structures"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_basearea"}) then {
		_jipLogik setVariable ["wfbe_basearea", (_jipLogik getVariable "wfbe_basearea"), true];
	};
	diag_log format ["[WFBE][JIP-HQSNAP] re-broadcast HQ/base snapshot (hq_deployed=%1) for side %2 to joiner %3", (_jipLogik getVariable ["wfbe_hq_deployed", false]), _sideJoined, _name];
};

//--- JIP-replay hardening, Finding #2 (wfbe_votetime): Init_Client.sqf:1581 waits unbounded on this var;
//--- Server_VoteForCommander.sqf only re-broadcasts it once per second WHILE a vote is actively counting
//--- down, so a joiner arriving between votes (or mid-vote, if the broadcast slow-syncs under load per
//--- the same RPT-traced side-logic replication gap as above) never receives it. Same same-value re-set.
if !(isNull _jipLogik) then {
	if !(isNil {_jipLogik getVariable "wfbe_votetime"}) then {
		_jipLogik setVariable ["wfbe_votetime", (_jipLogik getVariable "wfbe_votetime"), true];
		diag_log format ["[WFBE][JIP-VOTETIME] re-broadcast wfbe_votetime (%1) for side %2 to joiner %3", (_jipLogik getVariable "wfbe_votetime"), _sideJoined, _name];
	};
};

//--- JIP-replay hardening, Finding #4 (upgrade-in-progress replay): wfbe_upgrades (unlocked tiers) is
//--- already re-sent above, but the ACTIVE research/countdown fields are not, so a joiner mid-upgrade
//--- sees "no upgrade running" (a safe default - GUI_UpgradeMenu.sqf/Client_UpdateRHUD.sqf both isNil-guard
//--- these) until the next real upgrade event changes them. Re-sending closes that soft-staleness window.
if !(isNull _jipLogik) then {
	if !(isNil {_jipLogik getVariable "wfbe_upgrading"}) then {
		_jipLogik setVariable ["wfbe_upgrading", (_jipLogik getVariable "wfbe_upgrading"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_upgrading_id"}) then {
		_jipLogik setVariable ["wfbe_upgrading_id", (_jipLogik getVariable "wfbe_upgrading_id"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_upgrading_end_time"}) then {
		_jipLogik setVariable ["wfbe_upgrading_end_time", (_jipLogik getVariable "wfbe_upgrading_end_time"), true];
	};
	if !(isNil {_jipLogik getVariable "wfbe_upgrade_queue"}) then {
		_jipLogik setVariable ["wfbe_upgrade_queue", (_jipLogik getVariable "wfbe_upgrade_queue"), true];
	};
	diag_log format ["[WFBE][JIP-UPGRADESTATE] re-broadcast in-progress upgrade state (upgrading=%1) for side %2 to joiner %3", (_jipLogik getVariable ["wfbe_upgrading", false]), _sideJoined, _name];
};

if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
	_jipSupplyKey = Format ["wfbe_supply_%1", str _sideJoined];
	if !(isNil {missionNamespace getVariable _jipSupplyKey}) then {
		_id publicVariableClient _jipSupplyKey;
		diag_log format ["[WFBE][B63.2 JIP-SUPPLY] pushed %1=%2 to joiner %3", _jipSupplyKey, missionNamespace getVariable _jipSupplyKey, _name];
	};
};
diag_log format ["[WFBE][B63 JIP-MARK] pushed marker feeds to joiner %1 (aicom=%2, patrols=%3)", _name, count (missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []]), count (missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []])];

//--- B74.2: AICOM intent/objective vars are side-keyed and published only on change, so a late joiner can miss
//--- the current command-console/RHUD/objective-marker state until the next strategic change. Seed this joiner
//--- with the current side's primitive AICOM status vars, keeping the publisher itself change-cheap.
if (_sideJoined in [west, east]) then {
	private ["_aiSid","_aiKey","_aiSent"];
	_aiSid = _sideJoined Call WFBE_CO_FNC_GetSideID;
	_aiSent = 0;
	{
		_aiKey = Format [_x, _aiSid];
		if (!isNil {missionNamespace getVariable _aiKey}) then {
			_id publicVariableClient _aiKey;
			_aiSent = _aiSent + 1;
		};
	} forEach ["WFBE_AICOM_INTENT_%1","WFBE_AICOM_OBJNAME_%1","WFBE_AICOM_OBJPOS_%1","WFBE_AICOM_ACTIVE_%1","WFBE_AICOM_FOCUS_NAME_%1","WFBE_AICOM_TEAMS_%1","WFBE_AICOM_FUNDS_%1"];
	if (_aiSent > 0) then {diag_log format ["[WFBE][B74.2 AICOM-JIP] pushed %1 AI intent/status vars to joiner %2 for side %3", _aiSent, _name, _sideJoined]};
};

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

//--- Finding #5 (town/camp ownership replay) REVERTED (review-1253): a per-connect re-dirty of every
//--- town+camp sideID was measured against the actual Chernarus town count - 46 towns + 81 camps = ~127
//--- synchronous global setVariable-broadcasts on EVERY connect. At a round-start burst of 20-40 joins
//--- this is a ~5000-broadcast storm exactly when the server is busiest, and even spawn+throttled
//--- (127 x sleep 0.5 = ~63s) it is SLOWER than the 60s HANGGUARD fallback Init_Markers.sqf already has -
//--- strictly worse than doing nothing. Deferred proper fix: a TARGETED, BATCHED town-ownership snapshot
//--- sent only to the joining client (one publicVariableClient carrying [town,sideID] pairs + a small
//--- client-side applier), not a broadcast to everyone. The existing 60s HANGGUARD covers this window
//--- meanwhile.

//--- We attempt to get the player informations in case that he joined before.
_get = missionNamespace getVariable format["WFBE_JIP_USER%1",_uid];

//--- Scope (orchestrator ruling 2026-07-21, round-3 review): this whole handler - including the
//--- block below - is dedicated-server-scoped by the `local player` exitWith at the top of this
//--- file (line 19); it never runs on a hosted/listen server, same as every other pre-existing path
//--- here. WASP only deploys on dedicated servers (live + test are both dedicated NSSM services;
//--- hosted mode is unsupported), so this is accepted scope, documented rather than compensated for.
//--- On an unsupported hosted/listen server the commander-lease stand-down would rely on the
//--- disconnect-grace path (Server_OnPlayerDisconnected.sqf) only.
//--- C1 stable commander lease (WFBE_C_CMD_LEASE). Owner ruling 2026-07-21: PR #1154's stand-down
//--- enqueue was relocated OFF RequestJoin.sqf (JIP-flow file, never touched by agents) to this
//--- existing connect handler instead. Round-2 adversarial review (2026-07-21, HIGH finding): this
//--- MUST sit ABOVE the JIPFUNDS duplicate-connect latch below - this handler resolves TWICE per
//--- join (see that guard's own comment) and a lease holder reconnecting quickly could have EITHER
//--- resolve pass land inside the latch's 15s window, so a check placed below it could be skipped
//--- entirely on the one connect event where a fast side-swap actually happens. _get (just fetched
//--- above, not yet mutated) still holds the side recorded as of the player's PREVIOUS connect at
//--- index 3; a mismatch against the just-resolved _sideJoined means the reconnecting UID left the
//--- side it is recorded against. Sitting above the latch also means this no longer runs downstream
//--- of the CIV-mid-sync guard further below, so the real-side check is done explicitly here instead
//--- of inheriting it - a mid-sync CIV reading on a duplicate resolve pass must never look like a
//--- side change. The call below only ENQUEUES a versioned stand-down request -
//--- Common_CommanderLease.sqf's per-side executor is the sole writer of lease state and discards
//--- the request if a grant/reclaim has since superseded it, so this is safe to raise unconditionally,
//--- latched or not, duplicate resolve pass or not.
if (!isNil "_get" && {(missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0} && {_sideJoined in [west, east, resistance]}) then {
	_prevSideJoined = _get select 3;
	if (!isNil "_prevSideJoined" && {_prevSideJoined != _sideJoined}) then {
		_oldLogic = (_prevSideJoined) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _oldLogic) then {
			_oldLease = _oldLogic getVariable "wfbe_commander_lease"; if (isNil "_oldLease") then {_oldLease = []};   //--- G1 guard, matches Common_CommanderLease
			if (typeName _oldLease == "ARRAY" && {count _oldLease >= 6} && {(_oldLease select 0) == _uid}) then {
				[_prevSideJoined, (_oldLease select 5)] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown;
			};
		};
	};
};

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

//--- JIPFUNDS GUARDS (2026-07-04, live evidence: connect handler resolves TWICE per join; pass 2 arrives with
//--- side CIV mid-sync, hits the teamswap branch, looks up FUNDS_START_CIVILIAN (absent) and clobbers the fresh
//--- seed with nil/0). Guard 1: per-uid latch - a second resolve within 15s skips the funds block entirely.
//--- Guard 2: an unresolved (CIV) side defers - the resend/heal path re-seeds once the side is real.
private ["_jipLatch"];
_jipLatch = missionNamespace getVariable format["WFBE_JIP_LATCH%1", _uid];
if (!isNil "_jipLatch" && {(time - _jipLatch) < 15}) exitWith {
	diag_log (Format ["[WFBE][JIPFUNDS] duplicate connect-resolve for [%1] within 15s - funds block skipped (latch).", _uid]);
};
if (str _sideJoined == "CIV") exitWith {
	diag_log (Format ["[WFBE][JIPFUNDS] side unresolved (CIV) for [%1] - funds block deferred, nothing written.", _uid]);
};
missionNamespace setVariable [format["WFBE_JIP_LATCH%1", _uid], time];

//--- The player has joined for the first time.
if (isNil '_get') exitWith {
	/*
		UID | Cash | Side | Current Side | flag of first connect on a session
		The JIP system store the main informations about a client, the UID is used to track the player all along the session.
	*/
	missionNamespace setVariable [format["WFBE_JIP_USER%1",_uid], [_uid, (missionNamespace getVariable format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined]), _sideJoined, _sideJoined, 0]];

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

//--- Set the current player funds. NO-CLOBBER (2026-07-04): never overwrite a positive group wallet with
//--- nil/0 at connect - if the computed value is empty but the group already holds money, keep the group's
//--- value and repair the record to match (the record is authoritative only when it is a real number > 0).
private ["_grpCurF"];
_grpCurF = _team getVariable "wfbe_funds";
if ((isNil "_funds" || {_funds <= 0}) && {!isNil "_grpCurF"} && {_grpCurF > 0}) then {
	_funds = _grpCurF;
	_get set [1, _grpCurF];
	missionNamespace setVariable [format["WFBE_JIP_USER%1",_uid], _get];
	diag_log (Format ["[WFBE][JIPFUNDS] no-clobber: kept group wallet %1 for [%2] (computed was 0/nil); record repaired.", _grpCurF, _uid]);
};
_funds = if (isNil "_funds") then {0} else {_funds};
_team setVariable ["wfbe_funds", _funds, true];
	diag_log (Format ["[WFBE][JIPFUNDS] reconnect-path set [%1] side %2 wfbe_funds=%3 (storedCash=%4) - if 0 here on a fresh join, the connect handler resolved twice.", _uid, _sideJoined, _funds, (_get select 1)]);
