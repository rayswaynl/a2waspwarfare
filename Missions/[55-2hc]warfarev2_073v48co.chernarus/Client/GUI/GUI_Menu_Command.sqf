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
         "_reqTypes","_reqLabels","_selTeam","_lastState","_lastRosterHash","_lastEcon","_lastIntent","_posture"];

_display = _this select 0;
_map = _display displayCtrl 14002;
_sid = (sideJoined) Call WFBE_CO_FNC_GetSideID;
_cool = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_COOLDOWN", 8];
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
_lastState = -1;        //--- 0 = take-command, 1 = war room, -1 = uninitialised (force first toggle).
_lastRosterHash = "";
_lastEcon = "";
_lastIntent = "";           //--- change-hash for the AI-intent readout (control 14600 in STATE A / 14606 reused), so it updates live without churn.
_posture = "";              //--- last posture the player nudged this session ("PUSH"/"HOLD"/""); reflected in the STATE-A advisory line.
activeAnimMarker = false;

//--- All war-room controls (shown only in the commander STATE B). Roster, order buttons, request combo+label, lines.
private "_warCtrls";
_warCtrls = [14660,14661,14620,14621,14622,14623,14624,14625,14610,14611,14640,14641,14642,14690,14691];
//--- STATE-A (NOT commander) advisory controls: the live AI-intent readout + the PUSH/HOLD posture nudge. Shown
//--- only when the AI runs the side (so the nudge actually bites the brain) - hidden in STATE B.
private "_adviseCtrls";
_adviseCtrls = [14606,14607,14608,14609,14612];

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
	if (_stateNow != _lastState) then {
		_lastState = _stateNow;
		diag_log (format ["CMDCON-DBG state=%1 isCmd=%2 | war660=%3 roster661=%4 | takecmd670=%5 intent606=%6 posture608=%7", _stateNow, _isCmd, ctrlShown (_display displayCtrl 14660), ctrlShown (_display displayCtrl 14661), ctrlShown (_display displayCtrl 14670), ctrlShown (_display displayCtrl 14606), ctrlShown (_display displayCtrl 14608)]); //--- CONSOLE PROBE: log real per-state control visibility so any overlap is diagnosable from the RPT.
		_armed = "";
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
		if (MenuAction == 760 || MenuAction == 761) then {
			private "_pb"; _pb = MenuAction; MenuAction = -1;
			if (_seatEmpty || _lockOn) then {
				if ((_now - _lastSend) >= _cool) then {
					private "_pv"; _pv = if (_pb == 760) then {"PUSH"} else {"HOLD"};
					["RequestSpecial", ["aicom-posture", sideJoined, _pv]] Call WFBE_CO_FNC_SendToServer;
					_posture = _pv; _lastSend = _now; _lastIntent = "";   //--- force the readout to repaint with the new nudge line
					hintSilent parseText (format ["<t color='#A0E060'>Posture nudge sent: %1.</t>", _pv]);
				} else {
					hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
				};
			} else {
				hintSilent parseText "<t color='#F8D664'>Posture only steers the AI when it holds command of this side.</t>";
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

		//--- ----- ROSTER (14661): one row per AI-led team: "leader | role | town | order". -----
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
				private ["_ld","_role","_tn","_td","_md","_ord","_lbl","_pos"];
				_ld = leader _grp;
				_role = [typeOf _ld, "displayName"] Call GetConfigInfo;
				if (_role == "") then {_role = "Team"};
				//--- nearest town name (engine-proven nearest-pick; the inner forEach rebinds _x to the town - we keep using _grp for the team afterwards).
				_pos = getPos _ld; _tn = "field"; _td = 1e9;
				{
					private "_d"; _d = _pos distance _x;
					if (_d < _td) then {_td = _d; _tn = _x getVariable ["name", "?"]};
				} forEach towns;
				//--- current order from wfbe_teammode (default "towns" = autonomous). Proven group [name,default] read (executor line 27).
				_md = _grp getVariable ["wfbe_teammode", "towns"];
				if (isNil "_md") then {_md = "towns"};
				_md = toLower _md;
				_ord = switch (_md) do {
					case "move":    {"ATTACK"};
					case "defense": {"DEFEND"};
					case "patrol":  {"PATROL"};
					default {"auto"};
				};
				_lbl = (name _ld) + "  |  " + _role + "  |  " + _tn + "  |  " + _ord;
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

		//--- ----- SQUAD-COMMAND MODE TOGGLE (14625): DIRECT (player maneuvers, today's default) <-> AI STRATEGY
		//--- (the AI maneuver-brain runs Strategy+AssignTowns UNDER the human commander while the player keeps the
		//--- economy). Reads the server-broadcast delegate flag (default ABSENT => direct ON). The button TEXT shows
		//--- the CURRENT mode; pressing it sends the OPPOSITE. MAPPING: wire arg = "delegate to AI"; _directOn==true
		//--- means we are about to turn direct OFF -> send "ON" (delegate ON). -----
		private "_directOn"; _directOn = true;
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

		//--- ----- RELEASE selected team to autonomous (mode "towns"). -----
		if (MenuAction == 724) then {
			MenuAction = -1;
			if (!isNull _selTeam) then {
				[_selTeam, "towns"] Call SetTeamMoveMode;
				[_selTeam, true]    Call SetTeamAutonomous;          //--- let AssignTowns re-grab it
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
				if ((_now - _lastSend) < _cool) then {
					hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
				} else {
					if (_armed == "arty") then {
						//--- HYBRID: artillery still rides the brain (works in assist-mode) via the RequestSpecial bus.
						["RequestSpecial", ["aicom-arty-here", sideJoined, [_position select 0, _position select 1, 0]]] Call WFBE_CO_FNC_SendToServer;
						["TempAnim", _position, "selector_selectedMission", 1, "ColorRed", 1, 1.2] Spawn MarkerAnim;
						hintSilent parseText "<t color='#A0E060'>Artillery requested.</t>";
						_lastSend = _now; _armed = "";
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
							["TempAnim", _position, "selector_selectedMission", 1, _col, 1, 1.2] Spawn MarkerAnim;
							hintSilent parseText ("<t color='#A0E060'>" + (name (leader _team)) + " -> " + (toUpper _armed) + ".</t>");
							_lastSend = _now; _armed = "";
						} else {
							hintSilent parseText "<t color='#F8D664'>No AI team available to task.</t>";
						};
					};
				};
			};
		};

		//--- ----- ALL PUSH / ALL HOLD (bulk; no allocator dependency). -----
		if (MenuAction == 710 || MenuAction == 711) then {
			private "_b"; _b = MenuAction; MenuAction = -1;
			if ((_now - _lastSend) >= _cool) then {
				private "_n"; _n = 0;
				{
					if (!isNull _x && {!isPlayer (leader _x)} && {({alive _x} count units _x) > 0}) then {  //--- FIX 1b: {alive _x} (count provides _x); FIX 1a: iterate _srcTeams below.
						if (_b == 710) then {
							[_x, "towns"] Call SetTeamMoveMode;
							[_x, true]    Call SetTeamAutonomous;
						} else {
							[_x, getPos (leader _x)] Call SetTeamMovePos;
							[_x, "defense"]          Call SetTeamMoveMode;
							[_x, false]              Call SetTeamAutonomous;
						};
						_n = _n + 1;
					};
				} forEach _srcTeams;
				_lastSend = _now;
				hintSilent parseText (format ["<t color='#A0E060'>%1: %2 teams.</t>", (if (_b == 710) then {"ALL PUSH"} else {"ALL HOLD"}), _n]);
			} else {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown.</t>";
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

		//--- ----- Bottom status line: cooldown + armed hint. -----
		private ["_cd","_st"];
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
		(_display displayCtrl 14650) ctrlSetStructuredText (parseText _st);

		//--- Back.
		if (MenuAction == 4) exitWith {MenuAction = -1; activeAnimMarker = false; closeDialog 0; createDialog "WF_Menu"};
		sleep 0.1;
	};
};

activeAnimMarker = false;
