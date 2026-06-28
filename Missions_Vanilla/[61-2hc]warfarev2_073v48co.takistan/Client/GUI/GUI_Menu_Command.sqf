disableSerialization;

/* =====================================================================================
	WAR ROOM controller (commander-only rework).

	CORE FINDING this is built to: when YOU command (assist-mode), the AI allocator is
	SUPPRESSED, so the old aicom-focus/defend/reinforce sends are INERT (nothing reads
	them). The war room therefore tasks teams DIRECTLY via SetTeamMovePos + SetTeamMoveMode
	(broadcast true) -> consumed every supervisor tick by AI_Commander_Execute.sqf (which
	turns them into AIMoveTo waypoints for server-local teams and wfbe_aicom_order for HC
	teams, REGARDLESS of _canBuild). That is the only human-order path that bites while you
	command. Two orders stay HYBRID because they bypass the suppressed allocator: Artillery
	(aicom-arty-here) and Request-Unit (aicom-request-unit). Donate is DROPPED.

	TWO STATES, re-tested every loop so taking/losing command flips the UI live:
	  STATE A - NOT commander (isNull commanderTeam || commanderTeam != group player):
	            show TAKE COMMAND (14670) + an explainer; hide the war-room controls.
	  STATE B - commander (commanderTeam == group player): the war room - economy header,
	            roster listbox (click-to-select), and the direct-task orders.

	A2-OA-1.64 safe: no params / isEqualType / remoteExec / worldSize / "str find str" /
	hideObjectGlobal / 3-arg group getVariable / inline private _x. posScreenToWorld and
	uiNamespace ARE valid in this build (engine-proven on this map control). commanderTeam
	tests use == (NOT isEqualTo), null-guarded. switch/case + if/else for bools. The
	SetTeamMovePos / SetTeamMoveMode / posScreenToWorld / MarkerAnim call shapes are copied
	verbatim from the pre-rework controller (79c2f1173~1 GUI_Menu_Command.sqf).
   ===================================================================================== */

MenuAction = -1;
mouseButtonUp = -1;
WfRosterSel = -1;            //--- set by the roster listbox onLBSelChanged ("WfRosterSel = _this select 1").

private ["_display","_map","_sid","_armed","_lastSend","_cool","_artyOn","_now","_position",
         "_reqTypes","_reqLabels","_selTeam","_lastState","_lastRosterHash","_lastEcon"];

_display = _this select 0;
_map = _display displayCtrl 14002;
_sid = (sideJoined) Call WFBE_CO_FNC_GetSideID;
_cool = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_COOLDOWN", 8];
_artyOn = (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0;

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
activeAnimMarker = false;

//--- All war-room controls (shown only in the commander state). Roster, order buttons, request combo, lines.
private "_warCtrls";
_warCtrls = [14660,14661,14620,14621,14622,14623,14624,14610,14611,14640,14641,14690,14691];

ctrlSetStructuredText [14650, parseText "Opening the war room..."];

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

	//--- Set visibility + subtitle EVERY loop (display-scoped ctrlShow = the most engine-proven A2-OA
	//--- form; robust to a missed change-edge). The heavier reset stays gated on a real state change.
	private "_stateNow"; _stateNow = if (_isCmd) then {1} else {0};
	{(_display displayCtrl _x) ctrlShow _isCmd} forEach _warCtrls;
	(_display displayCtrl 14670) ctrlShow (!_isCmd);                 //--- TAKE COMMAND only when NOT commander
	(_display displayCtrl 14605) ctrlSetText (if (_isCmd) then {"WAR ROOM"} else {"COMMAND"});
	if (_stateNow != _lastState) then {
		_lastState = _stateNow;
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
		if (_msg != _lastEcon) then {ctrlSetStructuredText [14600, parseText _msg]; _lastEcon = _msg};
		ctrlSetStructuredText [14650, parseText "<t color='#85B5FA'>You are not commanding this side.</t>"];

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

		//--- Back / Exit still work in this state.
		if (MenuAction == 4) exitWith {MenuAction = -1; activeAnimMarker = false; closeDialog 0; createDialog "WF_Menu"};
		sleep 0.2;
	} else {
	//--- ====================================================================
	//--- STATE B: COMMANDER -> the war room.
	//--- ====================================================================

		//--- ----- ECONOMY header (14600): funds / supply / income / towns. All client-readable, non-blocking. -----
		private ["_funds","_supply","_income","_held","_total","_econ"];
		_funds  = (clientTeam) Call GetTeamFunds;
		_supply = missionNamespace getVariable [format ["wfbe_supply_%1", sideJoined], 0]; //--- DIRECT read (never GetSideSupply in a UI loop).
		if (isNil "_supply") then {_supply = 0};
		_income = (sideJoined) Call GetIncome;
		_total  = if (isNil "towns") then {0} else {count towns};
		_held   = if (_total > 0) then {sideJoined Call GetTownsHeld} else {0};
		_econ = "<t color='#85B5FA'>Funds:</t> $" + str (round _funds)
		      + "   <t color='#85B5FA'>Supply:</t> " + str (round _supply)
		      + "<br/><t color='#85B5FA'>Income:</t> $" + str (round _income) + "/tick"
		      + "   <t color='#85B5FA'>Towns:</t> " + str _held + "/" + str _total;
		if (_econ != _lastEcon) then {ctrlSetStructuredText [14600, parseText _econ]; _lastEcon = _econ};

		//--- ----- ROSTER (14661): one row per AI-led team: "leader | role | town | order". -----
		//--- clientTeams is the own-side team registry; only NON-player-led, alive teams are commandable.
		private ["_rows","_cmdTeams","_hash"];
		_rows = []; _cmdTeams = []; _hash = "";
		{
			if (!isNull _x && {!isPlayer (leader _x)} && {({alive _y} count units _x) > 0}) then {
				private ["_ld","_role","_tn","_td","_md","_ord","_lbl","_pos"];
				_ld = leader _x;
				_role = [typeOf _ld, "displayName"] Call GetConfigInfo;
				if (_role == "") then {_role = "Team"};
				//--- nearest town name (engine-proven nearest-pick; inner forEach rebinds _x to the town, then restores).
				_pos = getPos _ld; _tn = "field"; _td = 1e9;
				{
					private "_d"; _d = _pos distance _x;
					if (_d < _td) then {_td = _d; _tn = _x getVariable ["name", "?"]};
				} forEach towns;
				//--- current order from wfbe_teammode (default "towns" = autonomous). Proven group [name,default] read (executor line 27).
				_md = _x getVariable ["wfbe_teammode", "towns"];
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
				_cmdTeams = _cmdTeams + [_x];
				_hash = _hash + _lbl + "#";
			};
		} forEach clientTeams;
		//--- Repaint only on a content change (preserve selection; no per-frame lbClear churn).
		if (_hash != _lastRosterHash) then {
			_lastRosterHash = _hash;
			private "_keep"; _keep = lbCurSel 14661;
			lbClear 14661;
			{lbAdd [14661, _x]} forEach _rows;
			if (_keep >= 0 && _keep < (count _rows)) then {lbSetCurSel [14661, _keep]};
		};

		//--- Resolve the currently selected team (roster row -> _cmdTeams), else objNull.
		_selTeam = objNull;
		private "_sel"; _sel = lbCurSel 14661;
		if (_sel >= 0 && _sel < (count _cmdTeams)) then {_selTeam = _cmdTeams select _sel};

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
								if (!isNull _x && {!isPlayer (leader _x)} && {({alive _y} count units _x) > 0}) then {
									private "_d"; _d = _position distance (getPos (leader _x));
									if (_d < _bd) then {_bd = _d; _team = _x};
								};
							} forEach clientTeams;
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
					if (!isNull _x && {!isPlayer (leader _x)} && {({alive _y} count units _x) > 0}) then {
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
				} forEach clientTeams;
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
		ctrlSetStructuredText [14650, parseText _st];

		//--- Back.
		if (MenuAction == 4) exitWith {MenuAction = -1; activeAnimMarker = false; closeDialog 0; createDialog "WF_Menu"};
		sleep 0.1;
	};
};

activeAnimMarker = false;
