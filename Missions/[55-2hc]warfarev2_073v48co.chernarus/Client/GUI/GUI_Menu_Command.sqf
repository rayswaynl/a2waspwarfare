disableSerialization;

/* =====================================================================================
	COMMAND CONSOLE controller (full rework).

	The old squad-order Command Center is gutted. This dialog is now the player -> AI
	commander "Command" console: it reads the AI commander's published intent and lets a
	(non-commander) player hand it strategic orders. All orders ride the existing
	RequestSpecial / Server_HandleSpecial bus; the backend owns the handlers (the SHARED
	CONTRACT). The embedded map (idc 14002) shows the AI objective + the player's last order.

	A2-OA-1.64 safe: no params / isEqualType / remoteExec / posScreenToWorld-via-A3 etc.
	posScreenToWorld is used EXACTLY as the old map-click block did (engine-proven on this
	map control); typeName== for type tests; private "_x";_x=... declarations; switch/case.

	Order buttons set MenuAction (armed); the loop does press -> click-map -> snap-nearest-town
	-> send. The map-click read mirrors the old code: _position = _map posScreenToWorld[mouseX,mouseY].
   ===================================================================================== */

MenuAction = -1;
mouseButtonUp = -1;

private ["_display","_map","_sid","_active","_artyOn","_armed",
         "_lastSend","_lastIntent","_lastEnable","_reqTypes","_reqLabels","_now","_position",
         "_fTown","_fD","_fd2","_okSend","_funds","_donateAmt","_cool","_reqType","_reqSel",
         "_orderBtns","_btn","_amt"];

_display = _this select 0;
_map = _display displayCtrl 14002;

_sid = (sideJoined) Call WFBE_CO_FNC_GetSideID;

//--- Request-Unit combo (idc 14640): the type strings sent verbatim as the aicom-request-unit arg.
_reqTypes  = ["infantry","armor","air"];
_reqLabels = ["Infantry","Armor","Air"];
lbClear 14640;
{lbAdd [14640, _x]} forEach _reqLabels;
lbSetCurSel [14640, 0];

//--- Order buttons that are disabled when no AI commander runs the player's side.
_orderBtns = [14610,14611,14620,14621,14622,14623,14630,14640,14641];

//--- Artillery gate (same gate the brain + Server_HandleSpecial use). Hidden+disabled when off.
_artyOn = (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0;
ctrlShow [14623, _artyOn];

_donateAmt = missionNamespace getVariable ["WFBE_C_AICOM_DONATE_AMOUNT", 10000];
_cool = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_COOLDOWN", 8];

//--- "armed" = which map-click order is waiting for a map click: "" / "focus" / "defend" / "reinforce" / "arty".
_armed = "";
_lastSend = -1000;
_lastIntent = "<none>";
_lastEnable = -1;
activeAnimMarker = false;

ctrlSetStructuredText [14650, parseText "Read the AI commander's intent, then issue an order. Map-orders: press a button, then click the map."];

while {alive player && dialog} do {
	if (side group player != sideJoined) exitWith {activeAnimMarker = false; closeDialog 0};
	if (!dialog) exitWith {activeAnimMarker = false};

	_now = time;

	//--- ===== AI INTENT refresh (read the side-keyed published vars; cheap, only re-renders on change). =====
	_active = missionNamespace getVariable [format ["WFBE_AICOM_ACTIVE_%1", _sid], false];

	private ["_intent","_objNm","_focusNm","_teams","_funds2","_txt","_postureNow","_pT0","_pTtl"];
	_intent  = missionNamespace getVariable [format ["WFBE_AICOM_INTENT_%1", _sid], ""];
	_objNm   = missionNamespace getVariable [format ["WFBE_AICOM_OBJNAME_%1", _sid], ""];
	_focusNm = missionNamespace getVariable [format ["WFBE_AICOM_FOCUS_NAME_%1", _sid], ""];
	_teams   = missionNamespace getVariable [format ["WFBE_AICOM_TEAMS_%1", _sid], -1];
	_funds2  = missionNamespace getVariable [format ["WFBE_AICOM_FUNDS_%1", _sid], -1];

	//--- Local echo of the player's own last posture (so the panel reflects a just-sent PUSH/HOLD before the next strat tick).
	_postureNow = uiNamespace getVariable ["wfbe_cmd_posture", ""];
	_pT0 = uiNamespace getVariable ["wfbe_cmd_posture_t0", -1000];
	_pTtl = missionNamespace getVariable ["WFBE_C_AICOM_POSTURE_TTL", 300];
	if (_postureNow != "" && {(_now - _pT0) > _pTtl}) then {_postureNow = ""};

	if (!_active) then {
		_txt = "<t color='#F8D664'>AI COMMANDER</t><br/><br/><t color='#ff9966'>(no AI commander on your side)</t><br/><br/>A human is commanding this side - your orders are theirs to give.";
	} else {
		_txt = "<t color='#85B5FA'>Posture:</t> " + (if (_intent != "") then {_intent} else {"(thinking...)"}) + "<br/>";
		_txt = _txt + "<t color='#85B5FA'>Objective:</t> " + (if (_objNm != "") then {_objNm} else {"-"}) + "<br/>";
		_txt = _txt + "<t color='#85B5FA'>Your focus:</t> " + (if (_focusNm != "") then {_focusNm} else {"-"}) + "<br/>";
		if (_teams >= 0) then {_txt = _txt + "<t color='#85B5FA'>Teams:</t> " + str (round _teams) + "<br/>"};
		if (_funds2 >= 0) then {_txt = _txt + "<t color='#85B5FA'>Funds:</t> $" + str (round _funds2) + "<br/>"};
		if (_postureNow != "") then {_txt = _txt + "<br/><t color='#A0E060'>You ordered: " + _postureNow + "</t>"};
	};
	if (_txt != _lastIntent) then {
		ctrlSetStructuredText [14600, parseText _txt];
		_lastIntent = _txt;
	};

	//--- Enable/disable the order controls on AI-active transitions only (cheap; avoids per-frame ctrlEnable churn).
	if ((if (_active) then {1} else {0}) != _lastEnable) then {
		_lastEnable = if (_active) then {1} else {0};
		{ctrlEnable [_x, _active]} forEach _orderBtns;
	};

	//--- ===== POSTURE: PUSH / HOLD ===== (no map click).
	if (MenuAction == 710 || MenuAction == 711) then {
		_btn = MenuAction;
		MenuAction = -1;
		if (_active) then {
			if ((_now - _lastSend) >= _cool) then {
				private ["_pose"];
				_pose = if (_btn == 710) then {"PUSH"} else {"HOLD"};
				["RequestSpecial", ["aicom-posture", sideJoined, _pose]] Call WFBE_CO_FNC_SendToServer;
				uiNamespace setVariable ["wfbe_cmd_posture", _pose];
				uiNamespace setVariable ["wfbe_cmd_posture_t0", _now];
				_lastSend = _now;
				_lastIntent = "<force>";
				hintSilent parseText ("<t color='#A0E060'>AI Commander: posture set to " + _pose + ".</t>");
			} else {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
			};
		};
	};

	//--- ===== ARM a map-click order (Focus / Defend / Reinforce / Artillery) =====
	if (MenuAction == 720 || MenuAction == 721 || MenuAction == 722 || MenuAction == 723) then {
		_btn = MenuAction;
		MenuAction = -1;
		if (_active) then {
			switch (_btn) do {
				case 720: {_armed = "focus";     hintSilent parseText "<t color='#85B5FA'>Focus Attack:</t> click the target town on the map."};
				case 721: {_armed = "defend";    hintSilent parseText "<t color='#85B5FA'>Defend Town:</t> click the town to defend on the map."};
				case 722: {_armed = "reinforce"; hintSilent parseText "<t color='#85B5FA'>Reinforce Here:</t> click the town to reinforce on the map."};
				case 723: {
					if (_artyOn) then {
						_armed = "arty";
						hintSilent parseText "<t color='#85B5FA'>Artillery Here:</t> click the target spot on the map.";
					} else {
						hintSilent parseText "<t color='#F8D664'>Artillery is not enabled on this server.</t>";
					};
				};
			};
		};
	};

	//--- ===== MAP CLICK: resolve the armed order ===== (mirrors the old block's posScreenToWorld read).
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		if (_armed != "" && _active) then {
			_position = _map posScreenToWorld [mouseX, mouseY];

			if ((_now - _lastSend) < _cool) then {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
			} else {
				_okSend = false;

				if (_armed == "arty") then {
					//--- Confirm-before-fire (two-click) using the existing client confirm helper when present.
					private ["_confirmed"];
					_confirmed = true;
					if (!isNil "WFBE_CL_FNC_ConfirmAction") then {
						_confirmed = ["aicom-arty-here", "<t color='#F8D664'>Confirm AI artillery strike?</t><br/>Click the map again at the target to fire."] Call WFBE_CL_FNC_ConfirmAction;
					};
					if (_confirmed) then {
						["RequestSpecial", ["aicom-arty-here", sideJoined, [_position select 0, _position select 1, 0]]] Call WFBE_CO_FNC_SendToServer;
						["TempAnim", _position, "selector_selectedMission", 1, "ColorRed", 1, 1.2] Spawn MarkerAnim;
						hintSilent parseText "<t color='#A0E060'>AI Commander: artillery requested at that spot.</t>";
						_okSend = true;
					};
				} else {
					//--- Town orders: snap to the nearest town to the click (engine-proven nearest-pick, same as the
					//--- old "Move All -> AI focus" block at the bottom of the legacy controller).
					_fTown = objNull; _fD = 1e9;
					{ _fd2 = _position distance _x; if (_fd2 < _fD) then {_fD = _fd2; _fTown = _x} } forEach towns;
					if (!isNull _fTown) then {
						private ["_case","_color","_tnm"];
						_tnm = _fTown getVariable ["name", "?"];
						switch (_armed) do {
							case "focus":     {_case = "aicom-focus";     _color = "ColorBlue"};
							case "defend":    {_case = "aicom-defend";    _color = "ColorGreen"};
							case "reinforce": {_case = "aicom-reinforce"; _color = "ColorOrange"};
							default           {_case = "aicom-focus";     _color = "ColorBlue"};
						};
						["RequestSpecial", [_case, sideJoined, _fTown]] Call WFBE_CO_FNC_SendToServer;
						["TempAnim", getPos _fTown, "selector_selectedMission", 1, _color, 1, 1.2] Spawn MarkerAnim;
						hintSilent parseText ("<t color='#A0E060'>AI Commander: " + _armed + " -> " + _tnm + ".</t>");
						_okSend = true;
					} else {
						hintSilent parseText "<t color='#F8D664'>No town near that click - try again on a town.</t>";
					};
				};

				if (_okSend) then {
					_lastSend = _now;
					_lastIntent = "<force>";
					_armed = "";
				};
			};
			//--- (a stray map click with nothing armed simply does nothing).
		};
	};

	//--- ===== DONATE ===== (no map click). Affordability checked client-side, re-validated server-side.
	if (MenuAction == 730) then {
		MenuAction = -1;
		if (_active) then {
			_funds = (clientTeam) Call GetTeamFunds;
			if (_funds < _donateAmt) then {
				hintSilent parseText (format ["<t color='#F8D664'>Not enough funds to donate $%1 (you have $%2).</t>", str _donateAmt, str (round _funds)]);
			} else {
				if ((_now - _lastSend) >= _cool) then {
					_amt = _donateAmt;
					["RequestSpecial", ["aicom-donate", sideJoined, _amt, player]] Call WFBE_CO_FNC_SendToServer;
					_lastSend = _now;
					_lastIntent = "<force>";
					hintSilent parseText (format ["<t color='#A0E060'>Donated $%1 to the AI commander.</t>", str _amt]);
				} else {
					hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
				};
			};
		};
	};

	//--- ===== REQUEST UNIT ===== (combo type; no map click).
	if (MenuAction == 740) then {
		MenuAction = -1;
		if (_active) then {
			if ((_now - _lastSend) >= _cool) then {
				_reqSel = lbCurSel 14640;
				if (_reqSel == -1) then {_reqSel = 0};
				_reqType = _reqTypes select _reqSel;
				["RequestSpecial", ["aicom-request-unit", sideJoined, _reqType]] Call WFBE_CO_FNC_SendToServer;
				_lastSend = _now;
				_lastIntent = "<force>";
				hintSilent parseText (format ["<t color='#A0E060'>AI Commander: requested more %1.</t>", _reqType]);
			} else {
				hintSilent parseText "<t color='#F8D664'>Orders on cooldown - wait a moment.</t>";
			};
		};
	};

	//--- ===== Bottom status line: cooldown + funds. =====
	private ["_cdLeft","_funds3","_status"];
	_funds3 = (clientTeam) Call GetTeamFunds;
	_cdLeft = _cool - (_now - _lastSend);
	_status = "<t color='#85B5FA'>Your funds:</t> $" + str (round _funds3) + "<br/>";
	if (_cdLeft > 0) then {
		_status = _status + "<t color='#F8D664'>Orders ready in " + str (ceil _cdLeft) + "s</t>";
	} else {
		if (_armed != "") then {
			_status = _status + "<t color='#A0E060'>Armed: " + _armed + " - click the map.</t>";
		} else {
			_status = _status + "<t color='#A0E060'>Orders ready.</t>";
		};
	};
	ctrlSetStructuredText [14650, parseText _status];

	//--- ===== Back button -> return to the main WF menu (preserved return path). =====
	if (MenuAction == 4) exitWith {
		MenuAction = -1;
		activeAnimMarker = false;
		closeDialog 0;
		createDialog "WF_Menu";
	};

	sleep 0.1;
};

activeAnimMarker = false;
