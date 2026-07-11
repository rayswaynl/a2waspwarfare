/* server_deleghealth.sqf -- DELEGHEALTH|v2 stateful delegation-health telemetry (fable/deleghealth-v2, 2026-07-10).

   WHY: the legacy DELEGATION-DEAD alert (server_groupsGC.sqf:567) is structurally unfireable - it demands
   _delegRemote == 0 over an allUnits census that INCLUDES players and HC avatar bodies, so equality with 0
   is unreachable while any human is connected, and it only samples once per ~25 min (group-audit throttle).
   The measured 2026-07-09 collapse (both HC connections bounced, engine transferred ~280 units to the
   server, DELEGSTAT remotePct 89 -> 7 inside one window) never fired it. This loop is the truthful
   replacement: an AI-ONLY per-owner ownership tally + HC heartbeat freshness + a hysteretic state machine,
   emitted every 60s on its own thread. TELEMETRY ONLY: it changes no delegation behavior, leaves DELEGSTAT
   and server_groupsGC.sqf untouched, and never escalates beyond the RPT (not a Peach+ wake condition).

   Wire format (ONE always-on line per 60s tick; diag_log so it survives WF_LOG_CONTENT compiled off):
     DELEGHEALTH|v2|aiTot=<n>|srv=<n>[|hc<ownerId>=<n>...]|otherRemote=<n>|hcSharePct=<n>|freshHC=<n>|state=<S>|t=<min>
   - aiTot       : living AI of side WEST/EAST/GUER only. Players (isPlayer), HC avatar bodies (group in
                   WFBE_HEADLESSCLIENTS_ID; also CIV-sided after reseat, so excluded twice over) and ambient
                   CIV never count - the allUnits-including-players mix is exactly the DELEGSTAT mistake.
   - srv         : counted AI with owner <= 2 (server-local).
   - hc<id>      : counted AI per REGISTERED live HC owner id (registry = WFBE_HEADLESSCLIENTS_ID;
                   live = non-null group + alive leader + owner > 2; same filter as the HCDELEG tally in
                   AI_Commander.sqf, hardened with the owner check against the disconnect->owner-2 window).
   - otherRemote : counted AI owned by any other client (players' own squad AI). Kept OUT of the share
                   denominator - a player squad must never mask (or fake) an HC collapse.
   - hcSharePct  : round(100 * sum(hc<id>) / (srv + sum(hc<id>))); 0 when the denominator is 0.
   - freshHC     : registered live HCs whose HCStat heartbeat row (WFBE_HCFPS_REG, stamped by
                   Server\PVFunctions\HCStat.sqf as ["HC-<netId>", fps, time]) is <= 150s old
                   (2.5x the 60s HC_StatLoop cadence - one dropped beat tolerated).
   - state       : IDLE | HEALTHY | DEGRADED | COLLAPSED (below).

   State machine (hysteretic; evaluated only when time > 300 AND aiTot >= 40 AND WFBE_C_AI_DELEGATION == 2;
   otherwise IDLE with all streak counters reset):
     DEGRADED  : hcSharePct < 60 for 3 consecutive samples.
     COLLAPSED : hcSharePct < 25 for 2 consecutive samples OR freshHC == 0 for 2 consecutive samples.
     HEALTHY   : hcSharePct > 75 for 3 consecutive samples (also the arming state when the gate first passes).
   A state CHANGE logs exactly one extra latched line (GRPBUDGET WARN/RECOVER precedent, AI_Commander.sqf):
     DELEGHEALTH|v2|<ARMED|DISARMED|WARN|RECOVER>|<old>-><new>|hcSharePct=..|freshHC=..|aiTot=..|t=..
   Desk-check vs the archived incident (remotePct 89 -> 7 in one window, freshHC stayed 2): COLLAPSED
   latches on the 2nd post-collapse sample (~2 min, vs never for DELEGATION-DEAD); the current healthy
   live profile (remote 84-91%) pins HEALTHY with zero flaps (the 60-75 band changes nothing by design).

   Cost: ONE allUnits pass per 60s tick (same cost class as the HCDELEG tally) + an O(liveHCs x rows)
   heartbeat join. Spawned from Server\Init\Init_Server.sqf only when WFBE_C_DELEGHEALTH > 0
   (default 0 = this file never runs; runtime byte-identical to HEAD).
*/
scriptName "Server\FSM\server_deleghealth.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_DELEGHEALTH", 0]) <= 0) exitWith {};

private ["_state","_cntBelow60","_cntBelow25","_cntNoFresh","_cntAbove75","_hcReg","_hcLive","_hcOwners","_hcCounts","_hcGrp","_hcKey","_fidx","_slot","_fpsReg","_fresh","_srv","_other","_aiTot","_uSide","_o","_hidx","_hcSum","_denom","_sharePct","_hcCsv","_gateOn","_newState","_tok","_oldRank","_newRank"];

_state = "IDLE";
_cntBelow60 = 0; _cntBelow25 = 0; _cntNoFresh = 0; _cntAbove75 = 0;

["INITIALIZATION", "server_deleghealth.sqf: Armed. Emitting DELEGHEALTH|v2 every 60s."] Call WFBE_CO_FNC_LogContent;

while {!WFBE_GameOver} do {
	sleep 60;

	//--- Registered live HCs (registry appended by the Server_HandleSpecial connected-hc registration).
	//--- Same liveness filter as the HCDELEG tally, PLUS owner > 2: a leader whose HC just disconnected
	//--- can read owner 2 (server) before body deletion and must not masquerade as an HC bucket.
	_hcReg = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_hcLive = []; _hcOwners = []; _hcCounts = [];
	{
		if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 2}) then {
			_hcLive set [count _hcLive, _x];
			_hcOwners set [count _hcOwners, owner (leader _x)];
			_hcCounts set [count _hcCounts, 0];
		};
	} forEach _hcReg;

	//--- ONE allUnits pass: AI-only per-owner ownership tally. WEST/EAST/GUER sides only (GUER AI is
	//--- delegable and counts; ambient CIV does not); players and HC avatar bodies excluded - the two
	//--- populations that made the legacy remote==0 predicate structurally unreachable.
	_srv = 0; _other = 0; _aiTot = 0;
	{
		if (alive _x && {!isPlayer _x} && {!((group _x) in _hcLive)}) then {
			_uSide = side _x;
			if ((_uSide == west) || {_uSide == east} || {_uSide == resistance}) then {
				_aiTot = _aiTot + 1;
				_o = owner _x;
				if (_o <= 2) then {
					_srv = _srv + 1;
				} else {
					_hidx = _hcOwners find _o;
					if (_hidx >= 0) then {
						_hcCounts set [_hidx, (_hcCounts select _hidx) + 1];
					} else {
						_other = _other + 1; //--- player-owned squad AI (or unregistered remote) - never HC health.
					};
				};
			};
		};
	} forEach allUnits;

	_hcSum = 0;
	{ _hcSum = _hcSum + _x } forEach _hcCounts;
	_denom = _srv + _hcSum;
	_sharePct = 0;
	if (_denom > 0) then { _sharePct = round ((_hcSum / _denom) * 100) };

	//--- Heartbeat freshness join: WFBE_HCFPS_REG rows are [name, fps, timeStamp] keyed "HC-<netId>"
	//--- (HC_StatLoop.sqf builds the key from netId player on the HC; netId is the network-global object
	//--- id, so the server recomputes the identical key from the registered leader). <= 150s = fresh.
	_fpsReg = missionNamespace getVariable ["WFBE_HCFPS_REG", []];
	_fresh = 0;
	{
		_hcGrp = _x; //--- capture before the inner forEach rebinds _x.
		_hcKey = Format ["HC-%1", netId (leader _hcGrp)];
		_fidx = -1;
		{ if ((_x select 0) == _hcKey) exitWith {_fidx = _forEachIndex} } forEach _fpsReg;
		if (_fidx >= 0) then {
			_slot = _fpsReg select _fidx;
			if ((time - (_slot select 2)) <= 150) then { _fresh = _fresh + 1 };
		};
	} forEach _hcLive;

	//--- Hysteretic state machine. Gate: warmup done, enough AI for the share to mean anything, and HC
	//--- delegation actually configured. Outside the gate the machine is IDLE and every streak resets.
	_gateOn = (time > 300) && {_aiTot >= 40} && {(missionNamespace getVariable ["WFBE_C_AI_DELEGATION", 0]) == 2};
	_newState = _state;
	if (_gateOn) then {
		if (_sharePct < 60) then {_cntBelow60 = _cntBelow60 + 1} else {_cntBelow60 = 0};
		if (_sharePct < 25) then {_cntBelow25 = _cntBelow25 + 1} else {_cntBelow25 = 0};
		if (_fresh == 0) then {_cntNoFresh = _cntNoFresh + 1} else {_cntNoFresh = 0};
		if (_sharePct > 75) then {_cntAbove75 = _cntAbove75 + 1} else {_cntAbove75 = 0};
		if (_newState == "IDLE") then {_newState = "HEALTHY"}; //--- arm optimistic; demotion needs 2-3 samples anyway.
		if ((_cntBelow25 >= 2) || {_cntNoFresh >= 2}) then {
			_newState = "COLLAPSED";
		} else {
			if (_cntBelow60 >= 3) then {
				_newState = "DEGRADED";
			} else {
				if (_cntAbove75 >= 3) then {_newState = "HEALTHY"};
			};
		};
	} else {
		_cntBelow60 = 0; _cntBelow25 = 0; _cntNoFresh = 0; _cntAbove75 = 0;
		_newState = "IDLE";
	};

	//--- Always-on tally line (diag_log, NOT LogContent: WF_LOG_CONTENT is compiled off on live builds).
	_hcCsv = "";
	{ _hcCsv = _hcCsv + "|hc" + str (_hcOwners select _forEachIndex) + "=" + str _x } forEach _hcCounts;
	diag_log ("DELEGHEALTH|v2|aiTot=" + str _aiTot + "|srv=" + str _srv + _hcCsv + "|otherRemote=" + str _other + "|hcSharePct=" + str _sharePct + "|freshHC=" + str _fresh + "|state=" + _newState + "|t=" + str (round (time / 60)));

	//--- Latched transition line (GRPBUDGET WARN/RECOVER precedent): exactly one extra line per state
	//--- CHANGE, never repeated while a state holds. RPT-only by design - not a Peach+ wake condition.
	if (_newState != _state) then {
		_oldRank = 0; if (_state == "DEGRADED") then {_oldRank = 1}; if (_state == "COLLAPSED") then {_oldRank = 2};
		_newRank = 0; if (_newState == "DEGRADED") then {_newRank = 1}; if (_newState == "COLLAPSED") then {_newRank = 2};
		_tok = "RECOVER";
		if (_newRank > _oldRank) then {_tok = "WARN"};
		if (_state == "IDLE") then {_tok = "ARMED"};
		if (_newState == "IDLE") then {_tok = "DISARMED"};
		diag_log ("DELEGHEALTH|v2|" + _tok + "|" + _state + "->" + _newState + "|hcSharePct=" + str _sharePct + "|freshHC=" + str _fresh + "|aiTot=" + str _aiTot + "|t=" + str (round (time / 60)));
	};
	_state = _newState;
};
