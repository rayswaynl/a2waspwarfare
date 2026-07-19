//--- ===================================================================
//--- Server_CmdSupportAir.sqf  (WFBE_SE_FNC_CmdSupportAir)
//--- COMMAND V2 pillar (c) - the granted heli-support ESCORT LIFECYCLE.
//--- Design: docs/design/COMMAND-V2-NUDGE-SYSTEM-DESIGN.md section 5.2.
//--- Owner decision packet 2026-07-18:
//---   (1) FREE loan of an ALREADY-OWNED AICOM airframe. No requisition fee is charged and no
//---       refund path exists - anti-abuse is purely cooldown + caps + telemetry.
//---   (4) CAS rules of engagement = the SAFE default: escort/orbit the holder, and respond only
//---       to a DIRECT threat (a live hostile inside WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE of the
//---       holder). The heli never free-hunts the map. Widen only from telemetry.
//---   (5) AICOM MAY recall the airframe for a last-stand / HQ emergency, gated by HYSTERESIS
//---       (the emergency must be CONTINUOUSLY true for WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST
//---       seconds) and always logged with a reason token.
//---
//--- WHY A PERIODIC RE-ISSUE AND NOT doFollow: the escort re-publishes the team goto every
//--- WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT seconds through the SAME broadcast setters the AI
//--- commander uses (SetTeamMovePos / SetTeamMoveMode). That keeps two-HC authority intact - for
//--- an HC-resident team AI_Commander_Execute.sqf turns the stamp into a wfbe_aicom_order tuple
//--- that the HC-local driver consumes, exactly as for any other order - and it survives a holder
//--- disconnect. There is NO per-frame work and NO engine attach to a player object.
//---
//--- The team is NEVER manual-pinned. It is excluded from allocator re-tasking only because its
//--- wfbe_teammode is an explicit order ("move"/"patrol"), which AI_Commander_Allocate.sqf already
//--- treats as ineligible; on every exit path the mode is restored to "towns" so the AI commander
//--- reclaims the team cleanly. The AI stays the commander.
//---
//--- MUST be Spawned (it sleeps, and it Calls WFBE_CO_FNC_AICOMAirReturn which needs a scheduled
//--- context). ARGS: [_team, _hull, _holder, _kind, _side, _uid].
//--- A2-OA-1.64 safe: no params/pushBack/findIf/selectRandom, 1-arg getVariable on GROUP receivers,
//--- lazy && {} short-circuits, numeric flags guarded with > 0, no Boolean equality compares.
//--- ===================================================================

private ["_team","_hull","_holder","_kind","_side","_uid","_logik","_ttl","_int","_casRange","_hyst","_recallOn","_alt","_t0","_end","_reason","_emergSince","_running","_pos","_tPos","_mode","_held"];
_team   = _this select 0;
_hull   = _this select 1;
_holder = _this select 2;
_kind   = _this select 3;
_side   = _this select 4;
_uid    = _this select 5;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};
if (isNull _team) exitWith {};

_ttl      = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_TTL", 300];
_int      = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT", 20];
if (_int < 5) then {_int = 5};                 //--- floor: never turn the escort into a hot loop.
_casRange = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE", 500];
_hyst     = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST", 60];
_recallOn = (missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_RECALL", 1]) > 0;
_alt      = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_MIN_ALT", 120];

_t0     = time;
_end    = _t0 + _ttl;
_reason = "timeout";
_emergSince = -1;
_running    = true;

if (!isNull _hull && {alive _hull}) then {_hull flyInHeight _alt};
diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|GRANT|" + str _side + "|" + str (round (time / 60)) + "|kind=" + _kind + "|uid=" + _uid + "|heli=" + (typeOf _hull) + "|ttl=" + str _ttl);
["INFORMATION", Format ["Server_CmdSupportAir.sqf: [%1] heli support GRANTED to uid %2 (kind %3, airframe %4, ttl %5s).", _side, _uid, _kind, typeOf _hull, _ttl]] Call WFBE_CO_FNC_LogContent;

while {_running} do {
	//--- ---------- TERMINATION CHECKS (ordered cheapest-first) ----------
	if (time >= _end) then {_running = false; _reason = "timeout"};
	if (_running && {isNull _team}) then {_running = false; _reason = "team-lost"};
	if (_running && {({alive _x} count (units _team)) == 0}) then {_running = false; _reason = "team-lost"};
	if (_running && {isNull _hull || {!alive _hull}}) then {_running = false; _reason = "airframe-lost"};
	if (_running && {isNull _holder || {!alive _holder} || {!isPlayer _holder}}) then {_running = false; _reason = "holder-gone"};
	if (_running && {(side (group _holder)) != _side}) then {_running = false; _reason = "holder-sidechange"};
	//--- player pressed RELEASE (the aicom-support-air-release verb stamps this on the team).
	if (_running) then {
		private "_rel";
		_rel = _team getVariable "wfbe_aicom_support_release";        //--- 1-arg + isNil: GROUP receiver.
		if (!isNil "_rel" && {_rel}) then {_running = false; _reason = "release"};
	};
	//--- ---------- AICOM EMERGENCY RECALL, WITH HYSTERESIS (owner 2026-07-18 item 5) ----------
	//--- The emergency must hold CONTINUOUSLY for _hyst seconds before the airframe is taken back.
	//--- A blinking last-stand flag therefore cannot flap a grant on and off; _emergSince resets to
	//--- -1 the moment the side recovers, so the dwell restarts from scratch.
	if (_running && {_recallOn}) then {
		private ["_emerg","_hq"];
		_emerg = ((_logik getVariable ["wfbe_aicom_strat_mode", "spearhead"]) == "laststand");
		if (!_emerg) then {
			_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
			if (isNull _hq || {!alive _hq}) then {_emerg = true};
		};
		if (_emerg) then {
			if (_emergSince < 0) then {
				_emergSince = time;
				diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|RECALL|" + str _side + "|" + str (round (time / 60)) + "|state=armed|uid=" + _uid + "|hyst=" + str _hyst + "|reason=laststand-or-hq");
			};
			if ((time - _emergSince) >= _hyst) then {_running = false; _reason = "recall-emergency"};
		} else {
			if (_emergSince >= 0) then {
				diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|RECALL|" + str _side + "|" + str (round (time / 60)) + "|state=cleared|uid=" + _uid + "|dwell=" + str (round (time - _emergSince)));
			};
			_emergSince = -1;
		};
	};
	//--- ---------- ESCORT RE-ISSUE ----------
	if (_running) then {
		_pos  = getPos _holder;
		_tPos = _pos;
		_mode = "move";                            //--- escort / standoff on the holder (Execute -> MOVE waypoint)
		if (_kind == "cas-heli") then {
			//--- DIRECT-THREAT RESPONSE ONLY (owner-chosen SAFE ROE). We look for the nearest live
			//--- hostile inside _casRange OF THE HOLDER - not of the heli, and not map-wide - and only
			//--- then switch to a SAD sweep on that contact. With no threat in that band the heli goes
			//--- straight back to orbiting the holder. One bounded nearEntities per interval, never per
			//--- frame, and only while a grant is actually active.
			private ["_near","_best","_bestD"];
			_best = objNull; _bestD = _casRange;
			_near = _pos nearEntities [["Man","LandVehicle","Air"], _casRange];
			{
				if (!isNil "_x" && {!isNull _x} && {alive _x} && {(side _x) != _side} && {(side _x) != civilian}) then {
					private "_d";
					_d = _x distance _pos;
					if (_d < _bestD) then {_bestD = _d; _best = _x};
				};
			} forEach _near;
			if (!isNull _best) then {
				_mode = "patrol";                      //--- Execute maps "patrol" -> SAD waypoint = engage in that area
				_tPos = getPos _best;
				//--- Verbose per-interval dump. WF_LOG_CONTENT is a PREPROCESSOR DEFINE, not a namespace
				//--- variable - it cannot be read with getVariable. WFBE_CO_FNC_LogContent already self-gates
				//--- on it (LOG_CONTENT_STATE) and is forced always-on for every HC, so calling it directly is
				//--- the correct gating. The always-on state transitions are the diag_log AICOM2 lines instead.
				["INFORMATION", Format ["Server_CmdSupportAir.sqf: [%1] CAS direct-threat at %2m from holder uid %3 - SAD sweep.", _side, round _bestD, _uid]] Call WFBE_CO_FNC_LogContent;
			};
		};
		//--- Publish through the SAME broadcast setters the AI commander uses. Execute debounces by
		//--- WFBE_C_AICOM_ORDER_DELTA / _MININT, so a stationary holder costs no re-order at all.
		[_team, _tPos] Call SetTeamMovePos;
		[_team, _mode] Call SetTeamMoveMode;
		[_team, false] Call SetTeamAutonomous;
		sleep _int;
	};
};

//--- ---------- RETURN ----------
_held = round (time - _t0);
diag_log ("AICOM2|v1|ORDER|CMD_SUPPORT|RELEASE|" + str _side + "|" + str (round (time / 60)) + "|kind=" + _kind + "|uid=" + _uid + "|reason=" + _reason + "|heldSecs=" + str _held);
["INFORMATION", Format ["Server_CmdSupportAir.sqf: [%1] heli support ENDED for uid %2 after %3s (reason %4).", _side, _uid, _held, _reason]] Call WFBE_CO_FNC_LogContent;

//--- Free the SIDE-WIDE grant slot immediately: the player-facing loan is over, so another player
//--- may request a DIFFERENT airframe right away. The team itself stays marked held (below) until
//--- it has actually flown home, so the same team can never be double-granted mid-return.
_logik setVariable ["wfbe_cmd_support_active", ((_logik getVariable ["wfbe_cmd_support_active", 1]) - 1) max 0];
if (_reason == "recall-emergency") then {
	//--- HYSTERESIS, second half: hold off new grants on this side for the same dwell, so the next
	//--- request cannot immediately re-lend the airframe the AI just took back for its emergency.
	_logik setVariable ["wfbe_cmd_support_recall_until", time + _hyst];
};
if (!isNull _holder && {alive _holder} && {isPlayer _holder}) then {
	[_holder, "HandleSpecial", ["cmdv2-receipt", ["Heli support ended - " + _reason + "."]]] Call WFBE_CO_FNC_SendToClient;
};

//--- Fly the airframe home on the SHARED return-to-base-and-hold path (one implementation, also used
//--- by the founding AIR_RETAIN and air-mobile leg paths). We are inside a Spawn, so the scheduled-
//--- context precondition holds. The team keeps its explicit "move" mode for the duration, which is
//--- what keeps the allocator from fighting the return leg; it is handed back right after.
if (!isNull _hull && {alive _hull} && {!isNull (driver _hull)} && {alive (driver _hull)}) then {
	[_hull, _team, _side] Call WFBE_CO_FNC_AICOMAirReturn;
};

//--- Hand the team back to the AI commander: clear the grant stamps and restore the default
//--- "towns" mode + autonomy so AI_Commander_Allocate.sqf treats it as eligible again next tick.
if (!isNull _team) then {
	_team setVariable ["wfbe_aicom_support_holder", nil, true];
	_team setVariable ["wfbe_aicom_support_release", nil, true];
	[_team, "towns"] Call SetTeamMoveMode;
	[_team, true]    Call SetTeamAutonomous;
};
