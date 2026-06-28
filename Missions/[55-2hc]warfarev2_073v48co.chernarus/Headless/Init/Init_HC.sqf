//--- Headless Client initialization...

//--- Client Functions.
// Marty: HC-local cleanup for delegated town AI groups, required because deleteGroup must run where the group is local.
WFBE_CL_FNC_CleanupDelegatedTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_CleanupDelegatedTownAI.sqf";
WFBE_CL_FNC_DelegateTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateTownAI.sqf";
WFBE_CL_FNC_DelegateAIStaticDefence = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAIStaticDefence.sqf";
WFBE_CL_FNC_HandlePVF = Compile preprocessFileLineNumbers "Client\Functions\Client_HandlePVF.sqf";

["INITIALIZATION", "Init_HC.sqf: Running the headless client initialization."] Call WFBE_CO_FNC_LogContent;

//--- wiki-wins: was a blind `sleep 20` that raced server init. Wait (bounded ~20s) for the player
//--- object instead of always blocking the full interval; proceeds early once seated, never hangs.
private "_hcInitDeadline"; _hcInitDeadline = diag_tickTime + 20;
waitUntil { uiSleep 0.5; (!isNull player) || (diag_tickTime > _hcInitDeadline) };

//--- HC SIDE RESEAT (task #26): A2 OA can auto-seat this -client into a random free playable slot, and one
//--- HC reliably lands on a SYNCHRONIZED WEST warfare slot (mission.sqm id=229, sync 255). That makes the
//--- HC a phantom-WEST PLAYER: it inflates BLUFOR team-balance + vote quorum AND permanently resets the
//--- WEST no-players supply-stagnation timer (Common_StagnateSupplyIncomeNoPlayers) so WEST income never
//--- stagnates on an empty server. forceHeadlessClient=1 exists in A2 OA 1.63+, but it has not been reliable
//--- enough across boot/restart slot races in this mission, so the script reseat remains authoritative.
//--- INVARIANT: each HC must be the SOLE member (hence leader) of its OWN fresh group -
//--- NEVER a shared group - so owner(leader(group)) stays distinct per HC and delegation (owner-routed via
//--- Common_SendToClient.sqf:11) never collapses onto a single HC. This runs HERE, before the connected-hc
//--- notify below, so the server captures THIS civ group when it resolves `group _hc` (no server-side edit).
//--- BOUNDED POLLING LOOP (task #29 follow-up): the single-shot fixed-sleep attempt missed whenever the
//--- engine seated the HC late or locality hadn't transferred at the guard. We now wait for the player
//--- object, then poll for up to ~60s, retrying the reseat until `side group player == civilian`. Idempotent.
waitUntil {uiSleep 0.25; !isNull player}; //--- never run the guard before the player object exists.
//--- TELEMETRY (task #34): make the engine's raw auto-seating server-visible BEFORE we touch it.
["RequestSpecial", ["hc-preseat", [name player, str (side group player)]]] Call WFBE_CO_FNC_SendToServer;

//--- Mark the engine-selected slot group before leaving it. If that group becomes empty before the server's
//--- connected-hc handler runs, leader/UID based pruning can miss it (HC UIDs may be empty/collide). The
//--- server uses this marker to remove only HC magnet groups from WEST/EAST wfbe_teams after CIV reseat.
if (side group player != civilian) then {
	(group player) setVariable ["wfbe_hc_magnet", true, true];
	(group player) setVariable ["wfbe_hc_magnet_name", name player, true];
};

//--- RESEAT-TO-CIVILIAN, bounded poll (factored to a fn so the persistent watcher below can re-run it).
//--- Returns "done" if the HC ends on civilian, else "failed". Idempotent: a no-op when already CIV.
//--- _this = deadline-seconds for this attempt. HC-local; only touches `player`'s own group.
WFBE_HC_FNC_ReseatCivilian = {
	private "_budget"; _budget = _this;
	private "_deadline"; _deadline = diag_tickTime + _budget;
	while {side group player != civilian && {diag_tickTime < _deadline}} do {
		private "_g"; _g = grpNull;
		private "_tries"; _tries = 0;
		while {isNull _g && {_tries < 5}} do {
			_g = createGroup civilian; //--- raw createGroup (NOT the WFBE wrapper): keeps the HC infra group off the per-side group-cap/GC sweep.
			if (isNull _g) then {      //--- civilian side hit the ~144 group cap: log + wait + retry, NEVER silently leave the HC on WEST.
				["WARNING", Format ["Init_HC.sqf: createGroup civilian returned grpNull (CIV group cap?), retry %1/5.", _tries + 1]] Call WFBE_CO_FNC_LogContent;
				uiSleep 3;
			};
			_tries = _tries + 1;
		};
		if (!isNull _g) then {
			[player] joinSilent _g;
			uiSleep 2; //--- let the group-membership change replicate to the server BEFORE the connect notify, so `group _hc` resolves to the civ group (not the now-vacated WEST slot group).
			private "_ownLeader"; _ownLeader = owner (leader group player);
			["INFORMATION", Format ["Init_HC.sqf: HC %1 reseated onto CIVILIAN (own group %2, side %3, ownerLeader %4).", str player, str _g, str (side group player), _ownLeader]] Call WFBE_CO_FNC_LogContent;
		} else {
			["WARNING", "Init_HC.sqf: HC reseat to CIVILIAN FAILED after 5 retries (CIV group cap) - HC stays on its auto-seated side, will retry until deadline."] Call WFBE_CO_FNC_LogContent;
			uiSleep 3; //--- back off before the next poll so we don't spin the CIV-cap retry block tight.
		};
	};
	if (side group player == civilian) then {"done"} else {"failed"}
};

//--- DEADSPAWN PARK (Steff: "make sure second HC also spawns in deadspawns"): the engine auto-seats
//--- each HC onto a playable slot's spawn position out in the base/playable area; Init_Client.sqf (which
//--- parks joiners onto the side TempRespawnMarker holding area and then escapes them to base via Task-35)
//--- is SKIPPED for HCs (initJIPCompatible.sqf:255 vs :268), so an un-parked HC body just sits visibly at
//--- its old slot. AI-slot bots, by contrast, live inside the ringed deadspawn enclosure
//--- (Server\Init\Init_DeadspawnWall.sqf rings West/East/GuerTempRespawnMarker). We are now CIVILIAN side
//--- with no own TempRespawnMarker, so park the HC body in the GuerTempRespawnMarker holding point - the
//--- centre-most of the three deadspawn markers, inside the H-barrier ring. This is keyed on `player`
//--- (NOT name=="HC"), so BOTH HC1 and HC2 run it identically. Idempotent + harmless if the marker is
//--- missing (getMarkerPos returns [0,0,0] -> Common_GetRandomPosition keeps it off-water). A2-OA-safe:
//--- plain setPos on the local HC body, no respawn/slot edits, touches no protected file. Factored to a fn
//--- so the persistent watcher re-parks after any re-reseat. ORDER INVARIANT: the caller ALWAYS reseats to
//--- civilian FIRST and only parks while civilian, so the park never runs against a WEST/EAST grouping and
//--- thus can never knock the HC off civilian (setPos moves the body only, it does not change side/group).
WFBE_HC_FNC_ParkDeadspawn = {
	if (side group player != civilian) exitWith {}; //--- guard: only park a civilian-seated HC.
	//--- B36.1 (Ray 2026-06-15): PROTECT the HC body. Init_Client.sqf's `player allowDamage false` (:18) is
	//--- SKIPPED for HCs (initJIPCompatible gates client init on !isHeadLessClient), so the HC avatar was the
	//--- LONE unprotected body in the deadspawn ring and was killed by friendly fire. allowDamage false +
	//--- setCaptive true = unkillable + non-hostile. Sticky + idempotent (safe to re-run on every re-park);
	//--- touches ONLY `player`, never the delegated AI groups the HC hosts (they keep their own damage state).
	player allowDamage false;
	player setCaptive true;
	private "_dsPos"; _dsPos = getMarkerPos "GuerTempRespawnMarker";
	if (!((_dsPos select 0) == 0 && (_dsPos select 1) == 0)) then {
		player setPos ([_dsPos, 1, 8] Call Compile preprocessFile "Common\Functions\Common_GetRandomPosition.sqf");
		["INFORMATION", Format ["Init_HC.sqf: HC %1 parked in deadspawn (GuerTempRespawnMarker) at %2.", name player, getPos player]] Call WFBE_CO_FNC_LogContent;
	} else {
		["WARNING", "Init_HC.sqf: GuerTempRespawnMarker did not resolve; HC deadspawn park skipped."] Call WFBE_CO_FNC_LogContent;
	};
};

//--- BOUNDED POLLING LOOP (task #29 follow-up): the single-shot fixed-sleep attempt missed whenever the
//--- engine seated the HC late or locality hadn't transferred at the guard. We wait for the player object
//--- (above), then poll for up to ~60s, retrying the reseat until `side group player == civilian`.
private "_reseatResult"; _reseatResult = if (side group player == civilian) then {"skipped"} else {60 Call WFBE_HC_FNC_ReseatCivilian};
//--- TELEMETRY (task #34): report whether the reseat converged (done / skipped / failed).
["RequestSpecial", ["hc-reseat-result", [name player, _reseatResult, str (side group player)]]] Call WFBE_CO_FNC_SendToServer;
//--- Park AFTER the reseat has converged (park is a no-op unless we are civilian).
[] Call WFBE_HC_FNC_ParkDeadspawn;

//--- PERSISTENT RESEAT WATCHER (post-restart re-grab fix): a one-shot reseat exits permanently the moment
//--- the HC first reaches CIVILIAN. But an in-place MISSION RESTART (a 2nd MISSINIT on the same server
//--- process - see the repeated "Player without identity HC" churn + a fresh PreInit in the server RPT)
//--- re-seats every still-connected client into a random playable slot, and the HC reliably lands back on
//--- the synchronized WEST slot (id=229) - the original task-26 bug returning AFTER boot, invisible to the
//--- one-shot loop. So we keep a lightweight watcher running for the whole session: every 15s, if the HC
//--- has been re-grabbed onto WEST/EAST (anything not civilian), re-reseat to civilian and re-park, then
//--- emit an hc-reseat-result tagged `rewatch` so the slip is server-visible. Idempotent (the inner loop is
//--- a no-op while already CIV) and HC-local. A2-OA-1.64-safe: spawn + side/createGroup/joinSilent/setPos.
[] Spawn {
	while {true} do {
		uiSleep 15;
		if (!isNull player && {side group player != civilian}) then {
			["WARNING", Format ["Init_HC.sqf: HC %1 was re-grabbed onto %2 after reseat (mission-restart re-slot?) - re-reseating.", name player, str (side group player)]] Call WFBE_CO_FNC_LogContent;
			private "_r"; _r = 30 Call WFBE_HC_FNC_ReseatCivilian;
			["RequestSpecial", ["hc-reseat-result", [name player, "rewatch:" + _r, str (side group player)]]] Call WFBE_CO_FNC_SendToServer;
			[] Call WFBE_HC_FNC_ParkDeadspawn;
			//--- re-announce so the server re-resolves `group _hc` onto the fresh civ group after a re-reseat.
			if (side group player == civilian) then {
				["RequestSpecial", ["connected-hc", player]] Call WFBE_CO_FNC_SendToServer;
			};
		};
	};
};

//--- Notify the server that our headless client is here.
["RequestSpecial", ["connected-hc", player]] Call WFBE_CO_FNC_SendToServer;

//--- Cold-start insurance: if the first connected-hc PV arrives while the server still sees owner 0 or the
//--- pre-reseat slot group, repeat a few times. Server registration is owner-keyed and idempotent.
[] Spawn {
	private "_i";
	_i = 0;
	while {_i < 6} do {
		uiSleep 15;
		if (!isNull player && {side group player == civilian}) then {
			["RequestSpecial", ["connected-hc", player]] Call WFBE_CO_FNC_SendToServer;
		};
		_i = _i + 1;
	};
};

//--- HC load telemetry: HCSTAT lines on the server RPT (fps + local unit/group counts).
[] ExecVM "Headless\HC_StatLoop.sqf";

//--- claude-gaming (2026-06-15): HC-LOCAL empty-group reaper. The HC owns ~12-16 delegated
//--- commander-team/town groups that are local to it. Their self-reap in
//--- Common_RunCommanderTeam.sqf:789 (deleteGroup _team on GetLiveUnits==0) NO-OPs whenever
//--- dead-but-not-yet-engine-collected corpses still sit in `units _team`, leaving an empty
//--- HC-local husk that NOTHING else reaps (server_groupsGC.sqf deleteGroup no-ops on
//--- non-server-local groups; the player-client reaper used to be hasInterface-gated OFF here).
//--- That is a direct leak toward the 144/side group cap. Client_GroupsGC.sqf's start gate is
//--- now broadened to also run on a headless client; its body is HC-safe (skips `group player`
//--- = the HC civ infra group, plus persistent/town-tracked/debounce guards). Launched AFTER the
//--- reseat-to-civilian above so `group player` already resolves to the civilian group it must
//--- protect. Reaps client-LOCAL empty, non-persistent, non-player, non-town-tracked groups once
//--- per 60s and logs a CLIENT_EMPTY_GROUP_CLEANUP wire line tagged HC-<netId> for visibility.
[] ExecVM "Client\Functions\Client_GroupsGC.sqf";
