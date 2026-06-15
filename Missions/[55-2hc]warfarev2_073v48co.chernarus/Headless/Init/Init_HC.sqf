//--- Headless Client initialization...

//--- Client Functions.
// Marty: HC-local cleanup for delegated town AI groups, required because deleteGroup must run where the group is local.
WFBE_CL_FNC_CleanupDelegatedTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_CleanupDelegatedTownAI.sqf";
WFBE_CL_FNC_DelegateTownAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateTownAI.sqf";
WFBE_CL_FNC_DelegateAI = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAI.sqf";
WFBE_CL_FNC_DelegateAIStaticDefence = Compile preprocessFileLineNumbers "Client\Functions\Client_DelegateAIStaticDefence.sqf";
WFBE_CL_FNC_HandlePVF = Compile preprocessFileLineNumbers "Client\Functions\Client_HandlePVF.sqf";

["INITIALIZATION", "Init_HC.sqf: Running the headless client initialization."] Call WFBE_CO_FNC_LogContent;

//--- We wait for the server full init (just in case!).
sleep 20;

//--- HC SIDE RESEAT (task #26): A2 OA auto-seats this -client into a random free playable slot, and one
//--- HC reliably lands on a SYNCHRONIZED WEST warfare slot (mission.sqm id=229, sync 255). That makes the
//--- HC a phantom-WEST PLAYER: it inflates BLUFOR team-balance + vote quorum AND permanently resets the
//--- WEST no-players supply-stagnation timer (Common_StagnateSupplyIncomeNoPlayers) so WEST income never
//--- stagnates on an empty server. forceHeadlessClient=1 is an A3-only attribute and is INERT in A2 OA, so
//--- we reseat in script. INVARIANT: each HC must be the SOLE member (hence leader) of its OWN fresh group -
//--- NEVER a shared group - so owner(leader(group)) stays distinct per HC and delegation (owner-routed via
//--- Common_SendToClient.sqf:11) never collapses onto a single HC. This runs HERE, before the connected-hc
//--- notify below, so the server captures THIS civ group when it resolves `group _hc` (no server-side edit).
//--- BOUNDED POLLING LOOP (task #29 follow-up): the single-shot fixed-sleep attempt missed whenever the
//--- engine seated the HC late or locality hadn't transferred at the guard. We now wait for the player
//--- object, then poll for up to ~60s, retrying the reseat until `side group player == civilian`. Idempotent.
waitUntil {!isNull player}; //--- never run the guard before the player object exists.
//--- TELEMETRY (task #34): make the engine's raw auto-seating server-visible BEFORE we touch it.
["RequestSpecial", ["hc-preseat", [name player, str (side group player)]]] Call WFBE_CO_FNC_SendToServer;
private "_reseatResult"; _reseatResult = if (side group player == civilian) then {"skipped"} else {"failed"};
private "_deadline"; _deadline = time + 60;
while {side group player != civilian && {time < _deadline}} do {
	private "_g"; _g = grpNull;
	private "_tries"; _tries = 0;
	while {isNull _g && {_tries < 5}} do {
		_g = createGroup civilian; //--- raw createGroup (NOT the WFBE wrapper): keeps the HC infra group off the per-side group-cap/GC sweep.
		if (isNull _g) then {      //--- civilian side hit the ~144 group cap: log + wait + retry, NEVER silently leave the HC on WEST.
			["WARNING", Format ["Init_HC.sqf: createGroup civilian returned grpNull (CIV group cap?), retry %1/5.", _tries + 1]] Call WFBE_CO_FNC_LogContent;
			sleep 3;
		};
		_tries = _tries + 1;
	};
	if (!isNull _g) then {
		[player] joinSilent _g;
		sleep 2; //--- let the group-membership change replicate to the server BEFORE the connect notify, so `group _hc` resolves to the civ group (not the now-vacated WEST slot group).
		private "_ownLeader"; _ownLeader = owner (leader group player);
		["INFORMATION", Format ["Init_HC.sqf: HC %1 reseated onto CIVILIAN (own group %2, side %3, ownerLeader %4).", str player, str _g, str (side group player), _ownLeader]] Call WFBE_CO_FNC_LogContent;
	} else {
		["WARNING", "Init_HC.sqf: HC reseat to CIVILIAN FAILED after 5 retries (CIV group cap) - HC stays on its auto-seated side, will retry until deadline."] Call WFBE_CO_FNC_LogContent;
		sleep 3; //--- back off before the next poll so we don't spin the CIV-cap retry block tight.
	};
};
if (side group player == civilian) then {_reseatResult = "done"};
//--- TELEMETRY (task #34): report whether the reseat converged (done / skipped / failed).
["RequestSpecial", ["hc-reseat-result", [name player, _reseatResult, str (side group player)]]] Call WFBE_CO_FNC_SendToServer;

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
//--- plain setPos on the local HC body, no respawn/slot edits, touches no protected file.
if (side group player == civilian) then {
	private "_dsPos"; _dsPos = getMarkerPos "GuerTempRespawnMarker";
	if (!((_dsPos select 0) == 0 && (_dsPos select 1) == 0)) then {
		player setPos ([_dsPos, 1, 8] Call Compile preprocessFile "Common\Functions\Common_GetRandomPosition.sqf");
		["INFORMATION", Format ["Init_HC.sqf: HC %1 parked in deadspawn (GuerTempRespawnMarker) at %2.", name player, getPos player]] Call WFBE_CO_FNC_LogContent;
	} else {
		["WARNING", "Init_HC.sqf: GuerTempRespawnMarker did not resolve; HC deadspawn park skipped."] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Notify the server that our headless client is here.
["RequestSpecial", ["connected-hc", player]] Call WFBE_CO_FNC_SendToServer;

//--- HC load telemetry: HCSTAT lines on the server RPT (fps + local unit/group counts).
[] ExecVM "Headless\HC_StatLoop.sqf";
