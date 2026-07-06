disableSerialization;

/* =====================================================================================
	COMMAND CONSOLE controller (the player <-> AI-commander war room). Production rework
	(claude-gaming 2026-06-28): two states, each with the orders the SERVER actually honours
	in that state, so every control bites end-to-end (no dead sends).

	WHY two control sets: the AI commander's strategic workers (Allocator/Strategy) run only
	when the AI HOLDS command (no human commander). The team Executor runs EVERY tick (human
	or AI). So:
	  STATE A - NOT commander (the AI runs the side): the player ADVISES the still-running AI.
	            -> live AI-INTENT readout (14607, from WFBE_AICOM_*_<sid>) + a POSTURE NUDGE
	               (PUSH/HOLD -> aicom-posture; the Allocator shifts its engage gate while the
	               nudge is fresh) + TAKE COMMAND (14670). These bite because the AI is running.
	  STATE B - commander (commanderTeam == group player): the war room. The AI is a
	            quartermaster (HYBRID-REFILL founds/refills teams) but its strategy is OFF, so
	            the player drives teams DIRECTLY:
	              - per-team map orders Attack/Move, Defend, Patrol, Release (SetTeamMovePos +
	                SetTeamMoveMode -> AI_Commander_Execute turns them into waypoints EVERY tick,
	                regardless of _canBuild) - the reliable direct-task path.
	              - bulk ALL PUSH / ALL HOLD (direct, no allocator dependency).
	              - HYBRID brain orders that still bite under a human commander: Artillery
	                (aicom-arty-here, serviced by the assist-mode arty resolver IF guns exist)
	                and Request-Unit / Build priority (aicom-request-unit, read by the HYBRID-
	                REFILL team-founding worker).
	    Donate is NOT in this console - it lives in the Transfer menu (RequestAIComDonate).

	A2-OA-1.64 safe: no params / isEqualType / remoteExec / worldSize / "str find str" /
	hideObjectGlobal / 3-arg group getVariable / inline private _x. posScreenToWorld and
	uiNamespace ARE valid in this build (engine-proven on this map control). commanderTeam
	tests use == (NOT isEqualTo), null-guarded. switch/case + if/else for bools. The
	SetTeamMovePos / SetTeamMoveMode / posScreenToWorld / MarkerAnim call shapes are copied
	verbatim from the pre-rework controller (79c2f1173~1 GUI_Menu_Command.sqf).
   ===================================================================================== */

MenuAction = -1;
mouseButtonUp = -1;
//--- Seed the shared map-click globals. mouseX/mouseY are written ONLY by the map control's onMouseMoving EH
//--- (Dialogs.hpp 14002); a player who arms an order and clicks WITHOUT first moving the mouse this session would
//--- otherwise read stale coords from a previous dialog (or nil on a fresh client) and the order would land at the
//--- wrong spot / throw. Centre-seed so a no-move click is at worst the map centre, never nil. (mouseButtonUp reset
//--- above covers the cross-dialog stale-click on open.)
if (isNil "mouseX") then {mouseX = 0.5};
if (isNil "mouseY") then {mouseY = 0.5};

private ["_display","_map","_sid","_armed","_lastSend","_cool","_artyOn","_now","_position",
         "_reqTypes","_reqLabels","_selTeam","_lastState","_lastRosterHash","_lastEcon","_lastIntent","_posture","_disbandArm",
         "_disbandSelArm","_focusArmed","_lastDirect","_directCool"];

_display = _this select 0;
_map = _display displayCtrl 14002;
_sid = (sideJoined) Call WFBE_CO_FNC_GetSideID;
_cool = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_COOLDOWN", 8];
//--- Build83 smoother-console (claude-gaming 2026-07-01): the 8s _cool gate belongs ONLY on the RequestSpecial
//--- brain-sends (arty/posture/request-unit/ai-command/disband) which actually cost the server work. The DIRECT
//--- map-click group-var orders (Move/Defend/Patrol/Release/ALL-PUSH/ALL-HOLD) are pure LOCAL setVariable (no
//--- server load), so re-targeting them under an 8s gate feels broken. Gate those on a SEPARATE short cooldown
//--- (WFBE_C_AICOM_DIRECT_COOLDOWN, default 1.5s, defined in Init_CommonConstants) tracked by _lastDirect.
_directCool = missionNamespace getVariable ["WFBE_C_AICOM_DIRECT_COOLDOWN", 1.5];
//--- Artillery enable: a player war-room ARTILLERY-HERE request rides its OWN flag (WFBE_C_AICOM_PLAYER_ARTY),
//--- SEPARATE from the hard-locked AI-autonomous-artillery flag (WFBE_C_AI_COMMANDER_ARTILLERY = 0, Steff). The
//--- player request is serviced by an assist-mode resolver and only fires IF friendly artillery pieces exist; it
//--- never re-enables the AI's own fire cadence or base-gun building. Button greys out when the flag is off.
_artyOn = (missionNamespace getVariable ["WFBE_C_AICOM_PLAYER_ARTY", 0]) > 0;

//--- Request-Unit combo (idc 14640): the type strings sent verbatim as the aicom-request-unit arg.
_reqTypes  = ["infantry","armor","air"];
_reqLabels = ["Infantry","Armor","Air"];
lbClear 14640;
{lbAdd [14640, _x]} forEach _reqLabels;
lbSetCurSel [14640, 0];

_armed = "";
_lastSend = -1000;
_lastDirect = -1000;        //--- Build83 smoother-console: separate short-cooldown timestamp for DIRECT map-click group-var orders (claude-gaming 2026-07-01).
_disbandArm = -1000;        //--- player-commander DISBAND-ALL failsafe: 2-click-arm timestamp (claude-gaming 2026-06-30).
_disbandSelArm = -1000;     //--- Command Console v2: per-team DISBAND-SELECTED 2-click-arm timestamp (claude-gaming 2026-07-01).
_focusArmed = false;        //--- Command Console v2: STATE-A "AI: FOCUS TOWN" armed flag - next map click sets the AI focus (claude-gaming 2026-07-01).
_lastState = -1;        //--- 0 = take-command, 1 = war room, -1 = uninitialised (force first toggle).
_lastRosterHash = "";
_lastEcon = "";
_lastIntent = "";           //--- change-hash for the AI-intent readout (control 14600 in STATE A / 14606 reused), so it updates live without churn.
_posture = "";              //--- last posture the player nudged this session ("PUSH"/"HOLD"/""); reflected in the STATE-A advisory line.
activeAnimMarker = false;

//--- All war-room controls (shown only in the commander STATE B). Roster, order buttons, request combo+label, lines.
private "_warCtrls";
//--- Command Console v2 (claude-gaming 2026-07-01): +14627 DISBAND SELECTED (per-team teardown beside DISBAND ALL 14626).
//--- cmdcon41-w3d COMMAND-MENU V2: +14628/14629/14630 STEERING VERBS (RALLY/REFIT/HOLD) appended below when flag on.
_warCtrls = [14660,14661,14620,14621,14622,14623,14624,14625,14626,14627,14610,14611,14640,14641,14642,14690,14691];
if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {_warCtrls = _warCtrls + [14628,14629,14630]};
//--- cmdcon41-w3i (Ray 2026-07-02) UI CONSOLIDATION: the SCUD (14631) + TEL SATURATE/RECON (14632/14633) war-room buttons
//--- were REMOVED — all SCUD/TEL fire now lives in the Tactical menu (GUI_Menu_Tactical.sqf) beside the classic ICBM/NUKE.
//--- So they are no longer added to _warCtrls (and their gating/arm/fire blocks below were deleted). idcs 14631/14632/14633 free.
//--- STATE-A (NOT commander) advisory controls: the live AI-intent readout + the PUSH/HOLD posture nudge. Shown
//--- only when the AI runs the side (so the nudge actually bites the brain) - hidden in STATE B.
private "_adviseCtrls";
//--- cmdcon27 THREAD C: +4 field-order nudges (SPLIT UP / PUSH TOGETHER / HARASS / FALL BACK).
//--- Command Console v2 (claude-gaming 2026-07-01): +14617 "AI: FOCUS TOWN" (map-click advisory focus).
//--- cmdcon41-w3d COMMAND-MENU V2: +14618 REQUEST AI SUPPORT (non-commander nudge), shown in STATE A when the flag is on.
_adviseCtrls = [14606,14607,14608,14609,14612,14613,14614,14615,14616,14617];
if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {_adviseCtrls = _adviseCtrls + [14618]};

(_display displayCtrl 14650) ctrlSetStructuredText (parseText "Opening the war room...");

while {alive player && dialog} do {
	if (side group player != sideJoined) exitWith {activeAnimMarker = false; closeDialog 0};
	if (!dialog) exitWith {activeAnimMarker = false};

	_now = time;

	//--- ===== STATE GATE ===== am I the commander right now? (canonical null-guarded == idiom). =====
	private "_isCmd";
	_isCmd = false;
	private "_ct"; _ct = commanderTeam;                                 //--- snapshot; guard an unset/nil global on a slow JIP client
	if (!isNil "_ct") then {if (!isNull _ct) then {if (_ct == group player) then {_isCmd = true}}};
	private "_seatEmpty"; _seatEmpty = (isNil "_ct") || {isNull _ct};
	private "_lockOn"; _lockOn = (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0;

	//--- Set visibility + subtitle EVERY loop. ROOT-CAUSE FIX (2026-06-29): use the GLOBAL idc form
	//--- `ctrlShow [idc,bool]`, NOT the display-scoped `(_display displayCtrl idc) ctrlShow bool`. Against an
	//--- idd createDialog menu in A2-OA-1.64 the display-scoped setter silently no-ops, so neither control set
	//--- was ever hidden and both STATEs rendered on top of each other (the Ray screenshot). The global form
	//--- resolves the idc against the engine's top dialog and is the idiom every other idd menu uses
	//--- (GUI_Menu_BuyUnits.sqf:467-470, GUI_Menu_Economy.sqf:20) and that THIS controller already uses
	//--- working for 14670 below (lines 126/130/133). Fires on the very first loop; no change-edge dependency.
	private "_stateNow"; _stateNow = if (_isCmd) then {1} else {0};
	{ctrlShow [_x, _isCmd]} forEach _warCtrls;
	{ctrlShow [_x, !_isCmd]} forEach _adviseCtrls;                   //--- STATE-A advisory readout + posture nudge
	ctrlShow [14670, !_isCmd];                                       //--- TAKE COMMAND only when NOT commander
	ctrlSetText [14605, (if (_isCmd) then {"WAR ROOM"} else {"COMMAND"})];
	//--- The posture nudge only BITES the brain when the AI actually holds command of the side (the server handler
	//--- honours it iff no human commander, treating LOCK as no-human). Mirror that: it bites when the seat is empty
	//--- (AI runs it) OR the side is AI-LOCKED. Shown only in STATE A; greyed when a DIFFERENT human commands.
	private "_postureBites"; _postureBites = (!_isCmd) && (_seatEmpty || _lockOn);
	ctrlEnable [14609, _postureBites];                               //--- global idc form (same reason as the ctrlShow fix above)
	ctrlEnable [14612, _postureBites];
	{ctrlEnable [_x, _postureBites]} forEach [14613,14614,14615,14616]; //--- cmdcon27 THREAD C: field-order nudges bite only when the AI runs the side
	ctrlEnable [14617, _postureBites];                               //--- Command Console v2: AI FOCUS-TOWN bites only when the AI runs the side (same gate as the nudges)
	if (_stateNow != _lastState) then {
		_lastState = _stateNow;
		diag_log (format ["CMDCON-DBG state=%1 isCmd=%2 | war660=%3 roster661=%4 | takecmd670=%5 intent606=%6 posture608=%7", _stateNow, _isCmd, ctrlShown (_display displayCtrl 14660), ctrlShown (_display displayCtrl 14661), ctrlShown (_display displayCtrl 14670), ctrlShown (_display displayCtrl 14606), ctrlShown (_display displayCtrl 14608)]); //--- CONSOLE PROBE: log real per-state control visibility so any overlap is diagnosable from the RPT.
		_armed = "";
		_focusArmed = false;                                          //--- Command Console v2: clear any armed FOCUS on state entry
		_lastRosterHash = ""; _lastEcon = "";                         //--- force a panel redraw on state entry
		if (!_isCmd) then {lbClear 14661};
	};

	//--- ====================================================================
	//--- STATE A: NOT commander -> Take-Command panel.
	//--- ====================================================================
	if (!_isCmd) then {
		private "_msg";
		if (_lockOn) then {
			_msg = "<t color='#F8D664'>AI COMMAND LOCKED</t><br/><br/>The AI permanently commands this side on this server. You cannot take command.";
			ctrlShow [14670, false];
		} else {
			if (_seatEmpty) then {
				_msg = "<t color='#85B5FA'>This side has NO commander.</t><br/><br/>Take command to run the war yourself: the AI becomes your quartermaster (it founds and refills teams), and you direct every team from this war room.<br/><br/>Press <t color='#A0E060'>TAKE COMMAND</t> below.";
				ctrlShow [14670, true];
			} else {
				_msg = "<t color='#85B5FA'>A human already commands this side.</t><br/><br/>Only the commander can use the war room. Win a commander vote (Voting tab) to take over.";
				ctrlShow [14670, false];
			};
		};
		if (_msg != _lastEcon) then {(_display displayCtrl 14600) ctrlSetStructuredText (parseText _msg); _lastEcon = _msg};

		//--- ----- LIVE AI-INTENT READOUT (14607): read the side-keyed WFBE_AICOM_*_<sid> vars the server publishes
		//--- every strategy tick (mirrors the RHUD idiom; reuses the cached _sid - never GetSideID per frame). PV-on-
		//--- change means a JIP/pre-first-tick client reads "" -> render a neutral placeholder, never a blank panel. -----
		private ["_aiInt","_aiObj","_aiActive","_aiFocus","_intentTxt"];
		_aiInt    = missionNamespace getVariable [format ["WFBE_AICOM_INTENT_%1", _sid], ""];
		_aiObj    = missionNamespace getVariable [format ["WFBE_AICOM_OBJNAME_%1", _sid], ""];
		_aiActive = missionNamespace getVariable [format ["WFBE_AICOM_ACTIVE_%1", _sid], false];
		_aiFocus  = missionNamespace getVariable [format ["WFBE_AICOM_FOCUS_NAME_%1", _sid], ""];
		if (_aiInt == "") then {
			if (typeName _aiActive == "BOOL" && {_aiActive}) then {
				_intentTxt = "<t color='#85B5FA'>AI commander:</t> assessing the front...";
			} else {
				_intentTxt = "<t color='#85B5FA'>AI commander:</t> standing up...";
			};
		} else {
			_intentTxt = "<t color='#A0E060'>" + _aiInt + "</t>";
			if (_aiObj != "") then {_intentTxt = _intentTxt + "<br/><t color='#85B5FA'>Objective:</t> " + _aiObj};
			if (_aiFocus != "") then {_intentTxt = _intentTxt + "<br/><t color='#85B5FA'>Focus town:</t> " + _aiFocus};
		};
		if (_posture != "") then {
			_intentTxt = _intentTxt + "<br/><t color='#F8D664'>Your nudge:</t> " + _posture;
		};
		//--- change-hash so the readout updates live without per-frame churn.
		if (_intentTxt != _lastIntent) then {(_display displayCtrl 14607) ctrlSetStructuredText (parseText _intentTxt); _lastIntent = _intentTxt};

		(_display displayCtrl 14650) ctrlSetStructuredText (parseText "<t color='#85B5FA'>You are not commanding this side. Nudge the AI's posture below, or take command.</t>");

		//--- TAKE COMMAND press -> claim the empty AI commander seat (server re-validates every guard).
		if (MenuAction == 750) then {
			MenuAction = -1;
			if (!_lockOn && _seatEmpty) then {
				["RequestClaimCommander", [sideJoined, group player]] Call WFBE_CO_FNC_SendToServer;
				hintSilent parseText "<t color='#A0E060'>Claiming command...</t>";
			} else {
				hintSilent parseText "<t color='#F8D664'>The commander seat is not available to claim.</t>";
			};
		};

		//--- ----- POSTURE NUDGE (PUSH / HOLD): steer the still-running AI's expansion-vs-consolidate bias. Sends
		//--- aicom-posture; the server handler honours it ONLY while no human commands (exactly this STATE A), TTL'd.
		//--- Same per-order cooldown as the war-room sends so it can't spam the brain. -----
		//--- cmdcon27 THREAD C: MenuAction 760/761 = posture (PUSH/HOLD, aicom-posture); 762-765 = field orders
		//--- (SPLIT/MASS/HARASS/FALLBACK, aicom-fieldorder). Same STATE-A gate + per-order cooldown for both.
		if (MenuAction >= 760 && MenuAction <= 765) then {
			private "_pb"; _pb = MenuAction; MenuAction = -1;
			if (_seatEmpty || _lockOn) then {
				if ((_now - _lastSend) >= _cool) then {
					if (_pb == 760 || _pb == 761) then {
						private "_pv"; _pv = if (_pb == 760) then {"PUSH"} else {"HOLD"};
						["RequestSpecial", ["aicom-posture", sideJoined, _pv, player]] Call WFBE_CO_FNC_SendToServer; //--- TP-20: player appended so the server can key its per-UID rate limit (server count-guards for legacy 3-arg senders).
						_posture = _pv; _lastSend = _now; _lastIntent = "";   //--- force the readout to repaint with the new nudge line
						hintSilent parseText (format ["<t color='#A0E060'>Posture nudge sent: %1.</t>", _pv]);
					} else {
						private "_pv"; _pv = switch (_pb) do {case 762:{"SPLIT"};case 763:{"MASS"};case 764:{"HARASS"};default{"FALLBACK"}};
						["RequestSpecial", ["aicom-fieldorder", sideJoined, _pv, player]] Call WFBE_CO_FNC_SendToServer; //--- TP-20: player appended so the server can key its per-UID rate limit (server count-guards for legacy 3-arg senders).
						_posture = _pv; _lastSend = _now; _lastIntent = "";   //--- force the readout to repaint with the new field-order line
						hintSilent parseText (format ["<t color='#A0E060'>Field order sent: %1.</t>", _pv]);
					};
				} else {
					hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
				};
			} else {
				hintSilent parseText "<t color='#F8D664'>Posture only steers the AI when it holds command of this side.</t>";
			};
		};

		//--- ----- AI: FOCUS TOWN (Command Console v2, claude-gaming 2026-07-01) -----
		//--- STATE-A advisory: ARM on MenuAction 766, then the NEXT map click resolves the nearest town and sends
		//--- aicom-focus (the SAME side-focus mechanism the M4-key / command-center focus uses -> the Allocator makes it
		//--- the side's fist, TTL'd). The player does NOT take command. Same _seatEmpty/_lockOn AI-runs gate as the nudges
		//--- (a focus on a side a DIFFERENT human commands would be inert - strategy is off), and the same per-order cooldown.
		if (MenuAction == 766) then {
			MenuAction = -1;
			if (_seatEmpty || _lockOn) then {
				_focusArmed = true;
				hintSilent parseText "<t color='#85B5FA'>AI focus:</t> click the town on the map to point the AI commander at it.";
			} else {
				hintSilent parseText "<t color='#F8D664'>Focus only steers the AI when it holds command of this side.</t>";
			};
		};

		//--- Map click while a FOCUS is armed -> resolve the nearest town to the click and send aicom-focus (town OBJECT
		//--- at arg[2], exactly what the server handler expects). towns is populated on every client (Init_Town.sqf).
		if (mouseButtonUp == 0) then {
			mouseButtonUp = -1;
			if (_focusArmed) then {
				if (!(_seatEmpty || _lockOn)) then {
					_focusArmed = false;
					hintSilent parseText "<t color='#F8D664'>Focus only steers the AI when it holds command of this side.</t>";
				} else {
					private "_focusCool"; _focusCool = _cool max (missionNamespace getVariable ["WFBE_C_TEAM_FOCUS_COOLDOWN", 120]); //--- TP-13 stack-pass: the SERVER rate-limits focus at WFBE_C_TEAM_FOCUS_COOLDOWN (120s); gate the client to the same so it never shows a false "focus set" hint the server silently rejects.
					if ((_now - _lastSend) < _focusCool) then {
						hintSilent parseText "<t color='#F8D664'>AI focus on cooldown - wait a moment.</t>";
					} else {
						_position = _map posScreenToWorld [mouseX, mouseY];
						private "_fT"; _fT = objNull;
						if (!isNil "towns" && {count towns > 0}) then {_fT = [_position, towns] Call WFBE_CO_FNC_GetClosestEntity};
						if (!isNull _fT) then {
							["RequestSpecial", ["aicom-focus", sideJoined, _fT, player]] Call WFBE_CO_FNC_SendToServer; //--- TP-13: send player so the server can key its per-UID rate limit (server count-guards for legacy 3-arg senders)
							["TempAnim", getPos _fT, "selector_selectedMission", 1, "ColorYellow", 1, 1.2] Spawn MarkerAnim;
							_lastSend = _now; _focusArmed = false; _lastIntent = "";   //--- repaint the intent readout with the new focus town
							hintSilent parseText (format ["<t color='#A0E060'>AI focus set: %1.</t>", _fT getVariable ["name", "?"]]);
						} else {
							hintSilent parseText "<t color='#F8D664'>No town near that click - try again.</t>";
						};
					};
				};
			};
		};

		//--- ----- REQUEST AI SUPPORT (cmdcon41-w3d COMMAND-MENU V2, non-commander) -----
		//--- Any player (even under a HUMAN commander, where the posture/focus nudges are inert) calls the nearest free
		//--- same-side AI team to their position. Send [side, player, getPos player]; the server validates the sender is
		//--- alive/on-side/near the pos, picks ONE nearby non-busy team within range, road-moves it, and enforces the
		//--- per-player cooldown. Left autonomous server-side so AssignTowns re-tasks it after arrival (commander not
		//--- overridden). Client shows a soft local echo on the shared _cool clock so a double-tap is not spammed.
		if (MenuAction == 767) then {
			MenuAction = -1;
			if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {
				if ((_now - _lastSend) >= _cool) then {
					["RequestSpecial", ["aicom-support", sideJoined, player, getPos player]] Call WFBE_CO_FNC_SendToServer;
					_lastSend = _now;
					hintSilent parseText "<t color='#A0E060'>Support requested - the nearest free AI team is inbound (if one is in range).</t>";
				} else {
					hintSilent parseText "<t color='#F8D664'>Support request on cooldown - wait a moment.</t>";
				};
			};
		};

		//--- Back / Exit still work in this state.
		if (MenuAction == 4) exitWith {MenuAction = -1; activeAnimMarker = false; closeDialog 0; createDialog "WF_Menu"};
		sleep 0.2;
	} else {
	//--- ====================================================================
	//--- STATE B: COMMANDER -> the war room.
	//--- ====================================================================

		//--- ----- ECONOMY header (14600): funds / supply / income / towns. All client-readable, non-blocking. -----
		private ["_funds","_supply","_income","_held","_total","_econ","_cmdW"];
		//--- Show the SIDE COMMANDER treasury (the wallet the war effort actually spends from), not the player's own
		//--- group wallet - they can diverge once a human has taken command. Fall back to clientTeam if the seat is null.
		_cmdW = commanderTeam;
		_funds  = if (!isNull _cmdW) then {_cmdW Call GetTeamFunds} else {(clientTeam) Call GetTeamFunds};
		_supply = missionNamespace getVariable [format ["wfbe_supply_%1", sideJoined], 0]; //--- DIRECT read (never GetSideSupply in a UI loop).
		if (isNil "_supply") then {_supply = 0};
		_income = (sideJoined) Call GetIncome;
		_total  = if (isNil "towns") then {0} else {count towns};
		_held   = if (_total > 0) then {sideJoined Call GetTownsHeld} else {0};
		_econ = "<t color='#85B5FA'>Funds:</t> $" + str (round _funds)
		      + "   <t color='#85B5FA'>Supply:</t> " + str (round _supply)
		      + "<br/><t color='#85B5FA'>Income:</t> $" + str (round _income) + "/tick"
		      + "   <t color='#85B5FA'>Towns:</t> " + str _held + "/" + str _total;
		if (_econ != _lastEcon) then {(_display displayCtrl 14600) ctrlSetStructuredText (parseText _econ); _lastEcon = _econ};

		//--- ----- ROSTER (14661): one row per AI-led team: "Squad type | Target | Alive" (Command Console v2,
		//--- claude-gaming 2026-07-01, was "leader | role | town | order"). Squad type = the SAME INF/LGHT/HVY/AIR
		//--- classifier the map team markers use (updateaicommarkers.sqf); Target = the team's objective/destination
		//--- town (from the broadcast wfbe_teamgoto); Alive = "alive/total". -----
		//--- clientTeams is the own-side team registry; only NON-player-led, alive teams are commandable.
		private ["_rows","_cmdTeams","_hash","_srcTeams"];
		//--- FIX 1a (claude-gaming 2026-06-29): the roster MUST iterate the live side-logic team registry, not the
		//--- FROZEN boot snapshot clientTeams (Init_Client.sqf:294 captures ~15 playable slot-groups ONCE; the runtime
		//--- AI squads are appended only to the side-logic wfbe_teams - AI_Commander_Teams.sqf - and broadcast). So
		//--- clientTeams NEVER contains a single founded AI squad -> the war-room roster was always empty. Resolve the
		//--- live array from WFBE_Client_Logic.wfbe_teams (null-guarded; fall back to clientTeams if the logic/var is
		//--- not yet replicated on a fresh JIP client). The two fallback "nearest idle team" loops below repoint to
		//--- this same _srcTeams.
		_srcTeams = clientTeams;
		if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
			private "_lt"; _lt = WFBE_Client_Logic getVariable "wfbe_teams";
			if (!isNil "_lt" && {(typeName _lt) == "ARRAY"}) then {_srcTeams = _lt};
		};
		_rows = []; _cmdTeams = []; _hash = "";
		{
			private "_grp"; _grp = _x;                                    //--- FIX (clobber): capture the TEAM group into a stable local. The inner nearest-town forEach below rebinds _x to TOWN objects and A2-OA forEach does NOT save/restore _x, so every read after that loop must use _grp, not _x. Reading _x there stamped TOWN objects into _cmdTeams - the exact bug that made selected-team orders land on a town the Executor never reads.
			//--- FIX 1b (claude-gaming 2026-06-29): A2-OA `count` provides _x to the condition, NOT _y. The old
			//--- {alive _y} read an undefined _y -> THREW every iteration (22,529 RPT errors on cmdcon25) AND the
			//--- failing count broke the filter so no row ever passed. Use {alive _x}; _grp already holds the team.
			if (!isNull _grp && {!isPlayer (leader _grp)} && {({alive _x} count units _grp) > 0}) then {
				private ["_tn","_td","_lbl","_typeTag","_goto","_gotoTown","_alive","_total","_verb"];
				//--- SQUAD TYPE: the SAME heaviest-hull classifier the map team markers use (updateaicommarkers.sqf:118-128).
				//--- Priority: any Air hull -> AIR; else any Tank (tracked armour/IFV) -> HVY; else any wheeled APC/Car -> LGHT;
				//--- else INF. The inner forEach rebinds _x to the team's UNITS, so keep using _grp for the team afterwards.
				_typeTag = "INF";
				{
					if (!isNull _x && {alive _x}) then {
						private "_veh"; _veh = vehicle _x;
						if (_veh != _x) then {
							if (_veh isKindOf "Air") exitWith {_typeTag = "AIR"};
							if (_veh isKindOf "Tank") then {if (_typeTag != "AIR") then {_typeTag = "HVY"}};
							if ((_veh isKindOf "Wheeled_APC") || {_veh isKindOf "Car"}) then {if (_typeTag == "INF") then {_typeTag = "LGHT"}};
						};
					};
				} forEach units _grp;
				//--- TARGET: the team's objective/destination town. wfbe_teamgoto is BROADCAST (SetTeamMovePos / AssignTowns
				//--- L412), so it is client-readable: a town OBJECT (AI town assignment) OR a position (player DIRECT order).
				//--- Resolve to a town name; if unset / autonomous with no goto -> "auto". The inner forEach rebinds _x to towns.
				//--- cmdcon42-o ENEMY-BASE INTEL-LEAK CLAMP (Ray 2026-07-02): if the SERVER/HC published a display clamp for
				//--- this team (wfbe_teamgoto_disp = [ clampPos, clampTownName ], set producer-side by Common_SetTeamMovePos
				//--- ONLY when the true destination is inside an enemy base), render THAT enemy-held town + "(advancing)"
				//--- instead of the real destination - the player sees the push toward enemy lines but gets no base pin. The
				//--- clamp carries no HQ coordinates, so nothing here can be script-sniffed back to the hidden base.
				private "_disp"; _disp = _grp getVariable "wfbe_teamgoto_disp";
				if (!isNil "_disp" && {typeName _disp == "ARRAY"} && {count _disp >= 2}) then {
					_tn = (_disp select 1) + " (advancing)";
				} else {
				_goto = _grp getVariable ["wfbe_teamgoto", objNull];
				_tn = "auto";
				if (!isNil "_goto") then {
					if (typeName _goto == "OBJECT") then {
						if (!isNull _goto) then {_tn = _goto getVariable ["name", "?"]};
					} else {
						if (typeName _goto == "ARRAY" && {count _goto >= 2}) then {
							_gotoTown = objNull; _td = 1e9;
							{
								private "_d"; _d = _goto distance _x;
								if (_d < _td) then {_td = _d; _gotoTown = _x};
							} forEach towns;
							if (!isNull _gotoTown) then {_tn = _gotoTown getVariable ["name", "?"]};
						};
					};
				};
				};   //--- cmdcon42-o: close the display-clamp else-branch (true-goto path when not clamped).
				//--- ALIVE: alive/total members (e.g. 6/8).
				_alive = {alive _x} count units _grp;
				_total = count units _grp;
				//--- cmdcon41-w3d COMMAND-MENU V2 (UX): show the team's current ORDER VERB. Priority: HOLD latch > rally >
				//--- strike/capture > the broadcast wfbe_teammode (move/patrol/defense) > "towns" (autonomous). A2-OA: groups
				//--- take plain single-arg getVariable + isNil (NOT the [name,default] form). Flag-gated - falls back to the
				//--- pre-w3d 3-column label when WFBE_C_CMD_MENU_V2 is off.
				_verb = "";
				if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {
					private ["_hg","_rg","_sg","_mg"];
					_verb = "towns";
					_hg = _grp getVariable "wfbe_aicom_holding_town";
					_rg = _grp getVariable "wfbe_aicom_rallying";
					_sg = _grp getVariable "wfbe_aicom_strike";
					_mg = _grp getVariable "wfbe_teammode";
					if (!isNil "_mg" && {typeName _mg == "STRING"}) then {
						private "_mgL"; _mgL = toLower _mg;
						if (_mgL == "move" || _mgL == "patrol" || _mgL == "defense") then {_verb = _mgL};
					};
					if (!isNil "_sg" && {_sg}) then {_verb = "strike"};
					if (!isNil "_rg" && {_rg}) then {_verb = "rally"};
					if (!isNil "_hg" && {!isNull _hg}) then {_verb = "hold"};
				};
				if (_verb != "") then {
					_lbl = _typeTag + "  |  " + _tn + "  |  " + str _alive + "/" + str _total + "  |  " + _verb;
				} else {
					_lbl = _typeTag + "  |  " + _tn + "  |  " + str _alive + "/" + str _total;
				};
				_rows = _rows + [_lbl];
				_cmdTeams = _cmdTeams + [_grp];
				_hash = _hash + _lbl + "#";
			};
		} forEach _srcTeams;
		//--- Repaint only on a content change (preserve selection BY TEAM IDENTITY, not row index; no per-frame lbClear churn).
		if (_hash != _lastRosterHash) then {
			_lastRosterHash = _hash;
			//--- Capture the currently-selected TEAM object before the repaint, so if rows reorder (teams die/spawn)
			//--- selection follows the same team rather than whatever now sits at the old index.
			private ["_keepTeam","_keepIdx"];
			_keepTeam = objNull;
			private "_oldSel"; _oldSel = lbCurSel 14661;
			if (_oldSel >= 0 && _oldSel < (count _cmdTeams)) then {_keepTeam = _cmdTeams select _oldSel};
			lbClear 14661;
			{lbAdd [14661, _x]} forEach _rows;
			//--- Re-find the kept team in the freshly-built _cmdTeams; restore its new index, or clear if it died.
			_keepIdx = -1;
			if (!isNull _keepTeam) then {
				private "_ci"; _ci = 0;
				{ if (_x == _keepTeam) exitWith {_keepIdx = _ci}; _ci = _ci + 1 } forEach _cmdTeams;
			};
			if (_keepIdx >= 0) then {lbSetCurSel [14661, _keepIdx]};
		};

		//--- Resolve the currently selected team (roster row -> _cmdTeams), else objNull.
		_selTeam = objNull;
		private "_sel"; _sel = lbCurSel 14661;
		if (_sel >= 0 && _sel < (count _cmdTeams)) then {_selTeam = _cmdTeams select _sel};

		//--- ----- VIEW TEAM camera (Command Console v2, claude-gaming 2026-07-01): double-click a roster row (onLBDblClick
		//--- -> MenuAction 726) opens the EXISTING unit camera (RscMenu_UnitCamera / GUI_Menu_UnitCamera.sqf) focused on the
		//--- selected team's leader. Seed WFBE_CmdCon_CamUnit with the leader; the camera reads it on load as its start unit
		//--- (the camera's own player-team list is unchanged). Close this console first, then open the camera dialog. -----
		if (MenuAction == 726) then {
			MenuAction = -1;
			if (!isNull _selTeam && {alive (leader _selTeam)}) then {
				WFBE_CmdCon_CamUnit = leader _selTeam;
				activeAnimMarker = false;
				closeDialog 0;
				createDialog "RscMenu_UnitCamera";
			} else {
				hintSilent parseText "<t color='#F8D664'>Select a live team in the roster first.</t>";
			};
		};

		//--- ----- SQUAD-COMMAND MODE TOGGLE (14625): DIRECT (player maneuvers) <-> AI STRATEGY
		//--- (the AI maneuver-brain runs Strategy+AssignTowns UNDER the human commander while the player keeps the
		//--- economy). Reads the server-broadcast delegate flag. cmdcon27 THREAD B: the server delegate now defaults
		//--- TRUE (AI keeps pushing towns by default when a human takes command), so the client default with the var
		//--- ABSENT must match => _directOn default FALSE = "AI STRATEGY" shown. The button TEXT shows the CURRENT mode;
		//--- pressing it sends the OPPOSITE. MAPPING: wire arg = "delegate to AI"; _directOn==true means we are about
		//--- to turn direct OFF -> send "ON" (delegate ON). -----
		private "_directOn"; _directOn = false;
		if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
			private "_dv"; _dv = WFBE_Client_Logic getVariable "wfbe_aicom_player_delegate";
			if (!isNil "_dv" && {typeName _dv == "BOOL"}) then {_directOn = !_dv};
		};
		ctrlSetText [14625, (if (_directOn) then {"Squad command: DIRECT"} else {"Squad command: AI STRATEGY"})];
		if (MenuAction == 730) then {
			MenuAction = -1;
			if ((_now - _lastSend) >= _cool) then {
				private "_send"; _send = if (_directOn) then {"ON"} else {"OFF"};
				["RequestSpecial", ["aicom-ai-command", sideJoined, _send]] Call WFBE_CO_FNC_SendToServer;
				_lastSend = _now;
				hintSilent parseText "<t color='#A0E060'>Command mode change sent.</t>";
			} else {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
			};
		};

		//--- ----- ARM a map-click order ----- (Move / Defend / Patrol / Artillery).
		if (MenuAction == 720 || MenuAction == 721 || MenuAction == 722 || MenuAction == 723) then {
			private "_b"; _b = MenuAction; MenuAction = -1;
			switch (_b) do {
				case 720: {_armed = "move";    hintSilent parseText "<t color='#85B5FA'>Attack/Move:</t> click the destination on the map."};
				case 721: {_armed = "defense"; hintSilent parseText "<t color='#85B5FA'>Defend:</t> click the point to hold on the map."};
				case 722: {_armed = "patrol";  hintSilent parseText "<t color='#85B5FA'>Patrol:</t> click the area to patrol on the map."};
				case 723: {
					if (_artyOn) then {
						_armed = "arty";
						hintSilent parseText "<t color='#85B5FA'>Artillery:</t> click the target spot.";
					} else {
						hintSilent parseText "<t color='#F8D664'>Artillery is not enabled.</t>";
					};
				};
			};
		};

		//--- cmdcon41-w3i (Ray 2026-07-02) UI CONSOLIDATION: the SCUD-carrier + TEL SATURATE/RECON war-room button
		//--- gating (idc 14631/14632/14633) and their MenuAction 770/771/772 arm blocks were REMOVED. All SCUD/TEL fire
		//--- now lives in the Tactical menu (GUI_Menu_Tactical.sqf). The carrier-ownership + TEL-alive gates moved there.

		//--- ----- RELEASE selected team to autonomous (mode "towns"). -----
		if (MenuAction == 724) then {
			MenuAction = -1;
			if (!isNull _selTeam) then {
				[_selTeam, "towns"] Call SetTeamMoveMode;
				[_selTeam, true]    Call SetTeamAutonomous;          //--- let AssignTowns re-grab it
				_selTeam setVariable ["wfbe_aicom_manualpin", nil, true]; //--- MANUAL-PIN (Build83): RELEASE clears the pin (broadcast) so AssignTowns is free to re-grab this team immediately.
				_lastDirect = _now;                                  //--- DIRECT group-var order: stamp the short-cooldown clock (Build83 smoother-console).
				hintSilent parseText ("<t color='#A0E060'>" + (name (leader _selTeam)) + " released to auto.</t>");
			} else {
				hintSilent parseText "<t color='#F8D664'>Select a team in the roster first.</t>";
			};
		};

		//--- ----- MAP CLICK -> resolve the armed order (DIRECT team task; copied shape from the old controller). -----
		if (mouseButtonUp == 0) then {
			mouseButtonUp = -1;
			if (_armed != "") then {
				_position = _map posScreenToWorld [mouseX, mouseY];
				if (_armed == "arty") then {
					//--- ARTY is a RequestSpecial brain-send -> keep it on the 8s _lastSend / _cool gate.
					if ((_now - _lastSend) < _cool) then {
						hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
					} else {
						//--- HYBRID: artillery still rides the brain (works in assist-mode) via the RequestSpecial bus.
						["RequestSpecial", ["aicom-arty-here", sideJoined, [_position select 0, _position select 1, 0]]] Call WFBE_CO_FNC_SendToServer;
						["TempAnim", _position, "selector_selectedMission", 1, "ColorRed", 1, 1.2] Spawn MarkerAnim;
						hintSilent parseText "<t color='#A0E060'>Artillery requested.</t>";
						_lastSend = _now; _armed = "";
					};
				} else {
					//--- cmdcon41-w3i (Ray 2026-07-02): the SCUD + TEL (telsat/telrecon) map-click FIRE branches were REMOVED here;
					//--- all SCUD/TEL fire now goes through the Tactical menu. Only ARTY (above) + the DIRECT team order (below) remain.
					//--- DIRECT map-click order (Move/Defend/Patrol) = pure LOCAL setVariable, no server load ->
					//--- gate on the SHORT _lastDirect / _directCool. Within that window do NOT clear _armed (leave the
					//--- order armed so the very next click lands without re-arming) and show a soft "ready in Ns" hint.
					if ((_now - _lastDirect) < _directCool) then {
						private "_dcd"; _dcd = _directCool - (_now - _lastDirect);
						hintSilent parseText (format ["<t color='#F8D664'>Ready in %1s - click again.</t>", (ceil _dcd)]);
					} else {
						//--- DIRECT TEAM TASK. Target = selected roster team, else nearest idle AI team to the click.
						private "_team"; _team = _selTeam;
						if (isNull _team) then {
							private "_bd"; _bd = 1e9;
							{
								if (!isNull _x && {!isPlayer (leader _x)} && {({alive _x} count units _x) > 0}) then {  //--- FIX 1b: {alive _x} (A2-OA count provides _x, not _y); FIX 1a: _srcTeams (live registry, not frozen clientTeams).
									private "_d"; _d = _position distance (getPos (leader _x));
									if (_d < _bd) then {_bd = _d; _team = _x};
								};
							} forEach _srcTeams;
						};
						if (!isNull _team) then {
							private "_col";
							_col = switch (_armed) do {
								case "move":    {"ColorBlue"};
								case "defense": {"ColorGreen"};
								case "patrol":  {"ColorOrange"};
								default {"ColorBlue"};
							};
							//--- THE working order path (copied verbatim from the old controller, lines 299-300/305-306):
							//--- stamp mode+goto; AI_Commander_Execute turns it into waypoints (AIMoveTo for server-local
							//--- teams, wfbe_aicom_order for HC teams) EVERY tick while you command.
							[_team, _position] Call SetTeamMovePos;
							[_team, _armed]    Call SetTeamMoveMode;
							[_team, false]     Call SetTeamAutonomous; //--- pin under manual order (don't let AssignTowns re-grab it)
							_team setVariable ["wfbe_aicom_manualpin", time, true]; //--- MANUAL-PIN (Build83): stamp the human order time so AssignTowns treats this team as explicit for WFBE_C_AICOM_MANUALPIN_TTL (600s) and does not re-grab it on the next 120s tick. Broadcast so the SERVER's AssignTowns reads it.
							["TempAnim", _position, "selector_selectedMission", 1, _col, 1, 1.2] Spawn MarkerAnim;
							hintSilent parseText ("<t color='#A0E060'>" + (name (leader _team)) + " -> " + (toUpper _armed) + ".</t>");
							_lastDirect = _now; _armed = "";
						} else {
							hintSilent parseText "<t color='#F8D664'>No AI team available to task.</t>";
						};
					};
				};
			};
		};

		//--- ----- ALL PUSH / ALL HOLD (bulk; no allocator dependency). -----
		//--- Build83 smoother-console (claude-gaming 2026-07-01): these are DIRECT group-var orders (pure local
		//--- setVariable, no server load), so gate them on the SHORT _lastDirect / _directCool, not the 8s _lastSend.
		if (MenuAction == 710 || MenuAction == 711) then {
			private "_b"; _b = MenuAction; MenuAction = -1;
			if ((_now - _lastDirect) >= _directCool) then {
				private "_n"; _n = 0;
				{
					if (!isNull _x && {!isPlayer (leader _x)} && {({alive _x} count units _x) > 0}) then {  //--- FIX 1b: {alive _x} (count provides _x); FIX 1a: iterate _srcTeams below.
						if (_b == 710) then {
							[_x, "towns"] Call SetTeamMoveMode;
							[_x, true]    Call SetTeamAutonomous;
							_x setVariable ["wfbe_aicom_manualpin", nil, true]; //--- MANUAL-PIN (Build83): ALL-PUSH releases every team to auto, so clear each pin (broadcast) - AssignTowns re-grabs them freely.
						} else {
							//--- Build83 smoother-console CHANGE 2 (claude-gaming 2026-07-01): a bulk HOLD must not freeze a team
							//--- off-road mid-march. Pull each team's hold point to the nearest road node before stamping defense
							//--- (nearRoads / WFBE_CO_FNC_GetClosestEntity - the same A2-safe snap the AICOM route builder uses).
							//--- The SINGLE-team Defend (exact map click) is left untouched.
							private "_hp"; _hp = getPos (leader _x);
							private "_rd"; _rd = _hp nearRoads 200;
							if (count _rd > 0) then {
								private "_rn"; _rn = [_hp, _rd] Call WFBE_CO_FNC_GetClosestEntity;
								if (!isNull _rn) then {_hp = getPos _rn};
							};
							[_x, _hp]       Call SetTeamMovePos;
							[_x, "defense"] Call SetTeamMoveMode;
							[_x, false]     Call SetTeamAutonomous;
							_x setVariable ["wfbe_aicom_manualpin", time, true]; //--- MANUAL-PIN (Build83): ALL-HOLD is a human DIRECT defense order, so pin each team (broadcast) - AssignTowns won't re-grab it for WFBE_C_AICOM_MANUALPIN_TTL (600s).
						};
						_n = _n + 1;
					};
				} forEach _srcTeams;
				_lastDirect = _now;
				hintSilent parseText (format ["<t color='#A0E060'>%1: %2 teams.</t>", (if (_b == 710) then {"ALL PUSH"} else {"ALL HOLD"}), _n]);
			} else {
				private "_bcd"; _bcd = _directCool - (_now - _lastDirect);
				hintSilent parseText (format ["<t color='#F8D664'>Ready in %1s.</t>", (ceil _bcd)]);
			};
		};

		//--- ----- REQUEST UNIT (HYBRID: the B67 refill block runs in assist-mode, so this bites). -----
		if (MenuAction == 740) then {
			MenuAction = -1;
			if ((_now - _lastSend) >= _cool) then {
				private "_rs"; _rs = lbCurSel 14640; if (_rs == -1) then {_rs = 0};
				["RequestSpecial", ["aicom-request-unit", sideJoined, _reqTypes select _rs]] Call WFBE_CO_FNC_SendToServer;
				_lastSend = _now;
				hintSilent parseText (format ["<t color='#A0E060'>Prioritising %1 production.</t>", _reqTypes select _rs]);
			} else {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown.</t>";
			};
		};

		//--- ----- DISBAND ALL AI TEAMS (claude-gaming 2026-06-30, Ray): player-commander FAILSAFE, two-click confirm.
		//--- Server re-validates a human commander + enforces the 15-min per-side cooldown; the HC deletes each team
		//--- only when no player is within SAFE_DIST and it is not in combat (no vanish-in-view). -----
		if (MenuAction == 745) then {
			MenuAction = -1;
			if (!_isCmd) then {
				hintSilent parseText "<t color='#F8D664'>Only the commander can disband AI teams.</t>";
			} else {
				if ((_now - _disbandArm) <= 5) then {
					_disbandArm = -1000;
					["RequestSpecial", ["aicom-team-disband", sideJoined]] Call WFBE_CO_FNC_SendToServer;
					hintSilent parseText "<t color='#F89060'>Disband order sent - all AI field teams will stand down where safe.</t>";
				} else {
					_disbandArm = _now;
					hintSilent parseText "<t color='#F85050'>DISBAND ALL AI teams? Click again within 5s to confirm. (~15-min cooldown)</t>";
				};
			};
		};

		//--- ----- DISBAND SELECTED AI TEAM (Command Console v2, claude-gaming 2026-07-01): stand down ONLY the highlighted
		//--- roster team, two-click confirm. Same player-safe teardown as DISBAND ALL (flags wfbe_aicom_disband; the HC
		//--- deletes it only when no player is near + not in combat). The server 'aicom-team-disband' handler is EXTENDED to
		//--- accept an optional team INDEX (arg[2]) into the side logic's wfbe_teams; we resolve _selTeam's index in the SAME
		//--- broadcast registry the server reads (WFBE_Client_Logic getVariable "wfbe_teams" == _dLogik wfbe_teams, both via
		//--- WFBE_CO_FNC_GetSideLogic - Init_Client.sqf:455). Guard: only send when that registry is live AND the selected
		//--- team is found in it (else the index would not match the server). No per-side cooldown on a single-team disband
		//--- (server-side: the specific-team path skips the 15-min gate; that gate guards the all-teams sweep). -----
		if (MenuAction == 746) then {
			MenuAction = -1;
			if (!_isCmd) then {
				hintSilent parseText "<t color='#F8D664'>Only the commander can disband AI teams.</t>";
			} else {
				if (isNull _selTeam) then {
					hintSilent parseText "<t color='#F8D664'>Select a team in the roster first.</t>";
				} else {
					//--- Resolve the selected team's index in the broadcast wfbe_teams registry (server-matching order).
					private ["_regTeams","_tIdx"];
					_regTeams = []; _tIdx = -1;
					if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
						private "_rt"; _rt = WFBE_Client_Logic getVariable "wfbe_teams";
						if (!isNil "_rt" && {(typeName _rt) == "ARRAY"}) then {_regTeams = _rt};
					};
					{ if (_x == _selTeam) exitWith {_tIdx = _forEachIndex} } forEach _regTeams;
					if (_tIdx < 0) then {
						hintSilent parseText "<t color='#F8D664'>Cannot target that team yet - try again in a moment.</t>";
					} else {
						if ((_now - _disbandSelArm) <= 5) then {
							_disbandSelArm = -1000;
							["RequestSpecial", ["aicom-team-disband", sideJoined, _tIdx]] Call WFBE_CO_FNC_SendToServer;
							hintSilent parseText (format ["<t color='#F89060'>Disband order sent - %1 will stand down where safe.</t>", (name (leader _selTeam))]);
						} else {
							_disbandSelArm = _now;
							hintSilent parseText (format ["<t color='#F85050'>DISBAND %1? Click again within 5s to confirm.</t>", (name (leader _selTeam))]);
						};
					};
				};
			};
		};

		//--- ----- STEERING VERBS (cmdcon41-w3d COMMAND-MENU V2): RALLY (727) / REFIT (728) / HOLD (729) on the SELECTED
		//--- roster team. Each resolves _selTeam's index in the broadcast wfbe_teams registry (the SAME server-matching
		//--- idiom as DISBAND SELECTED above) and sends a RequestSpecial the server re-validates (commander-only, side,
		//--- team-valid). All the real work (rally pos / funds charge / hold latch) is server-side; the client only sends
		//--- the index. Gated on the 8s brain-send cooldown (_lastSend). Flag-gated via WFBE_C_CMD_MENU_V2. -----
		if (MenuAction == 727 || MenuAction == 728 || MenuAction == 729) then {
			private "_vb"; _vb = MenuAction; MenuAction = -1;
			if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) <= 0) then {
				//--- flag off: swallow the press (buttons are hidden anyway).
			} else {
				if (isNull _selTeam) then {
					hintSilent parseText "<t color='#F8D664'>Select a team in the roster first.</t>";
				} else {
					//--- item5 (client-qol-batch2): RALLY/REFIT/HOLD are direct war-room verbs with fast
					//--- per-order latency; gate on the short _lastDirect/_directCool (1.5s) not the 8s brain send.
					if ((_now - _lastDirect) < _directCool) then {
						private "_dcd5"; _dcd5 = _directCool - (_now - _lastDirect);
						hintSilent parseText (format ["<t color='#F8D664'>Ready in %1s - wait a moment.</t>", (ceil _dcd5)]);
					} else {
						//--- Resolve the selected team's index in the broadcast wfbe_teams registry (server-matching order).
						private ["_vRegTeams","_vIdx"];
						_vRegTeams = []; _vIdx = -1;
						if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
							private "_vrt"; _vrt = WFBE_Client_Logic getVariable "wfbe_teams";
							if (!isNil "_vrt" && {(typeName _vrt) == "ARRAY"}) then {_vRegTeams = _vrt};
						};
						{ if (_x == _selTeam) exitWith {_vIdx = _forEachIndex} } forEach _vRegTeams;
						if (_vIdx < 0) then {
							hintSilent parseText "<t color='#F8D664'>Cannot target that team yet - try again in a moment.</t>";
						} else {
							private ["_vSpecial","_vLabel"];
							_vSpecial = switch (_vb) do {case 727:{"aicom-rally"};case 728:{"aicom-refit"};default{"aicom-hold"}};
							_vLabel   = switch (_vb) do {case 727:{"Rally"};case 728:{"Refit"};default{"Hold"}};
							["RequestSpecial", [_vSpecial, sideJoined, _vIdx]] Call WFBE_CO_FNC_SendToServer;
							_lastSend = _now;      //--- still stamp _lastSend (brain send costs server work)
							_lastDirect = _now;    //--- also stamp _lastDirect so rapid re-press is throttled
							hintSilent parseText (format ["<t color='#A0E060'>%1 order sent - %2.</t>", _vLabel, (name (leader _selTeam))]);
						};
					};
				};
			};
		};

		//--- ----- Bottom status line: cooldown + armed hint. -----
		//--- Build83 smoother-console (claude-gaming 2026-07-01): a DIRECT order (move/defense/patrol) is armed and
		//--- gated on the SHORT _lastDirect clock, so it must not be masked by the long _lastSend brain-send countdown.
		//--- Show the armed-DIRECT prompt whenever such an order is armed; otherwise fall back to the _lastSend readout.
		private ["_cd","_st"];
		if (_armed != "" && {_armed != "arty"}) then {
			private "_dcd"; _dcd = _directCool - (_now - _lastDirect);
			_st = if (_dcd > 0) then {
				"<t color='#F8D664'>" + (toUpper _armed) + " armed - ready in " + str (ceil _dcd) + "s</t>"
			} else {
				"<t color='#A0E060'>Armed: " + (toUpper _armed) + " - click the map.</t>"
			};
		} else {
			_cd = _cool - (_now - _lastSend);
			_st = if (_cd > 0) then {
				"<t color='#F8D664'>Orders ready in " + str (ceil _cd) + "s</t>"
			} else {
				if (_armed != "") then {
					"<t color='#A0E060'>Armed: " + (toUpper _armed) + " - click the map.</t>"
				} else {
					"<t color='#A0E060'>Pick a team, pick an order, click the map.</t>"
				};
			};
		};
		(_display displayCtrl 14650) ctrlSetStructuredText (parseText _st);

		//--- Back.
		if (MenuAction == 4) exitWith {MenuAction = -1; activeAnimMarker = false; closeDialog 0; createDialog "WF_Menu"};
		sleep 0.1;
	};
};

activeAnimMarker = false;
