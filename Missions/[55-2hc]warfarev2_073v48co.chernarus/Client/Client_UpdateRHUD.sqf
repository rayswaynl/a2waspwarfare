disableSerialization;

// Marty: Keep the shared OptionsAvailable resource alive for action icons, and show RHUD by default.
if (isNil "RUBHUD") then {RUBHUD = true};
if !(isNil "BIS_CONTROL_CAM") then {RUBHUD = false};
CutRsc["OptionsAvailable","PLAIN",0];

waituntil{!isnil"totalTowns"};

// Marty: Cache RHUD controls and values so hidden/unchanged HUD state does not rewrite UI every second.
private[
	"_total", "_perfStart", "_display", "_lastDisplay", "_controls", "_rhudIDC", "_lastTexts", "_lastColors", "_lastShown", "_lastBackgroundColor",
	"_labelsApplied", "_hiddenApplied", "_hudWasShown", "_lastTownRefresh", "_incomeText", "_supplyText", "_baseText", "_baseColor",
	"_RHUDResetControlCache", "_RHUDSetShow", "_RHUDSetText", "_RHUDSetColor", "_RHUDGetDisplay", "_idx", "_player", "_side", "_bgColor",
	"_status", "_health", "_healthAct", "_healthColor", "_uptime", "_commanderText", "_mbu", "_currentUnitsCount", "_maxUnitsCount",
	"_isCommanderTeam", "_aiText", "_aiColor", "_moneyText", "_baseStructures", "_baseHq", "_baseTotal", "_baseDamaged", "_clientFPS", "_clientFPSColor",
	"_serverFPS", "_serverFPSColor", "_hudFPSColor", "_hudMode", "_lastHudMode", "_RHUDUpdateFPS", "_RHUDUpdateServerFPSRow", "_RHUDSetFPSPosition", "_RHUDSetFullPosition", "_clientLabel", "_serverLabel", "_showMissingServer",
	"_labelX", "_valueX", "_startY", "_rowH", "_labelW", "_valueW", "_lineH", "_rowY", "_layoutPairs",
	"_RHUDUpdateUpgrade", "_RHUD_upgId", "_RHUD_upgEnd", "_cachedEnd",
	"_RHUDUpdateArty"
];

_total = count towns;
_display = displayNull;
_lastDisplay = displayNull;
_controls = [];
_rhudIDC = [1345,1346,1347,1348,1349,1350,1351,1352,1353,1354,1355,1356,1357,1358,1359,1360,1361,1362,1363,1364,1365,1366,1367,1368,1369,1370,1371,1372,1373];
_lastTexts = [];
_lastColors = [];
_lastShown = [];
_lastBackgroundColor = "";
_labelsApplied = false;
_hiddenApplied = false;
_hudWasShown = false;
_lastHudMode = "";
_lastTownRefresh = -999;
_incomeText = "";
_supplyText = "";
_baseText = "";
_baseColor = [0, 1, 0, 1];

_RHUDResetControlCache = {
	_controls = [];
	_lastTexts = [];
	_lastColors = [];
	_lastShown = [];
	{
		_controls set [count _controls, _display displayCtrl _x];
		_lastTexts set [count _lastTexts, "__init__"];
		_lastColors set [count _lastColors, "__init__"];
		_lastShown set [count _lastShown, "__init__"];
	} forEach _rhudIDC;
	_lastBackgroundColor = "__init__";
	_labelsApplied = false;
	_hiddenApplied = false;
	_lastHudMode = "";
};

_RHUDSetShow = {
	private["_idx", "_show", "_showKey"];
	_idx = _this select 0;
	_show = _this select 1;
	_showKey = str _show;
	if ((_lastShown select _idx) == _showKey) exitWith {};
	(_controls select _idx) ctrlShow _show;
	_lastShown set [_idx, _showKey];
};

_RHUDSetText = {
	private["_idx", "_text"];
	_idx = _this select 0;
	_text = _this select 1;
	if ((_lastTexts select _idx) == _text) exitWith {};
	(_controls select _idx) ctrlSetText _text;
	_lastTexts set [_idx, _text];
};

_RHUDSetColor = {
	private["_idx", "_color", "_colorKey"];
	_idx = _this select 0;
	_color = _this select 1;
	_colorKey = str _color;
	if ((_lastColors select _idx) == _colorKey) exitWith {};
	(_controls select _idx) ctrlSetTextColor _color;
	_lastColors set [_idx, _colorKey];
};

_RHUDGetDisplay = {
	private["_cutDisplay"];
	_cutDisplay = ["currentCutDisplay"] call BIS_FNC_GUIget;
	if (isNull _cutDisplay) then {
		CutRsc["OptionsAvailable","PLAIN",0];
		_cutDisplay = ["currentCutDisplay"] call BIS_FNC_GUIget;
	};
	_cutDisplay
};

_RHUDUpdateFPS = {
	private["_clientLabel", "_serverLabel", "_showMissingServer"];
	_clientLabel = _this select 0;
	_serverLabel = _this select 1;
	_showMissingServer = _this select 2;

	[19, _clientLabel] call _RHUDSetText;
	[21, _serverLabel] call _RHUDSetText;

	_clientFPS = round(diag_fps);
	_clientFPSColor = [0, 1, 0, 1];
	if (_clientFPS < 40) then {_clientFPSColor = [1, 0.8431, 0, 1]};
	if (_clientFPS < 20) then {_clientFPSColor = [1, 0, 0, 1]};
	[20, format ["%1", _clientFPS]] call _RHUDSetText;
	[20, _clientFPSColor] call _RHUDSetColor;

	_serverFPS = missionNamespace getVariable "SERVER_FPS_GUI";
	if (isNil {_serverFPS}) exitWith {
		if (_showMissingServer) then {
			[22, "..."] call _RHUDSetText;
			[22, [0.7, 0.7, 0.7, 1]] call _RHUDSetColor;
		};
	};

	_serverFPSColor = [0, 1, 0, 1];
	if (_serverFPS < 40) then {_serverFPSColor = [1, 0.8431, 0, 1]};
	if (_serverFPS < 20) then {_serverFPSColor = [1, 0, 0, 1]};
	[22, format ["%1", _serverFPS]] call _RHUDSetText;
	[22, _serverFPSColor] call _RHUDSetColor;
};

_RHUDUpdateServerFPSRow = {
	_clientFPS = round(diag_fps);
	_serverFPS = missionNamespace getVariable "SERVER_FPS_GUI";
	if (isNil {_serverFPS}) exitWith {
		_hudFPSColor = [0, 1, 0, 1];
		if (_clientFPS < 40) then {_hudFPSColor = [1, 0.8431, 0, 1]};
		if (_clientFPS < 20) then {_hudFPSColor = [1, 0, 0, 1]};
		[14, format ["%1 / ...  VD %2", _clientFPS, round viewDistance]] call _RHUDSetText;
		[14, _hudFPSColor] call _RHUDSetColor;
	};

	_hudFPSColor = [0, 1, 0, 1];
	if (_clientFPS < 40 || _serverFPS < 40) then {_hudFPSColor = [1, 0.8431, 0, 1]};
	if (_clientFPS < 20 || _serverFPS < 20) then {_hudFPSColor = [1, 0, 0, 1]};
	[14, format ["%1 / %2  VD %3", _clientFPS, _serverFPS, round viewDistance]] call _RHUDSetText;
	[14, _hudFPSColor] call _RHUDSetColor;
};

_RHUDUpdateUpgrade = {
	private ["_up","_id","_labels","_cachedEnd","_serverEnd","_lbl","_remain","_mm","_ss","_txt","_queue","_upgrades"];
	_labels = missionNamespace getVariable "WFBE_C_UPGRADES_LABELS";
	if (isNil "_labels") exitWith {};

	_up = WFBE_Client_Logic getVariable "wfbe_upgrading";
	if (isNil "_up") then {_up = false};
	_id = WFBE_Client_Logic getVariable "wfbe_upgrading_id";
	if (isNil "_id") then {_id = -1};

	//--- Current (indices 23/24).
	if (_up && _id >= 0 && _id < count _labels) then {
		_lbl = _labels select _id;
		// Marty: Read the server-replicated authoritative end time (published by Server_ProcessUpgrade.sqf
		// for player, queue AND AI upgrades) every tick. Re-anchor the HUD when the upgrade id changes,
		// OR when the server end time jumps forward (chained same-id queue upgrades, or the replicated value
		// arriving a tick after the id appeared - which would otherwise leave the HUD frozen at 0:00).
		_serverEnd = WFBE_Client_Logic getVariable "wfbe_upgrading_end_time";
		if (isNil "_serverEnd") then {_serverEnd = -1};
		if (_RHUD_upgId != _id || (_serverEnd > time && _serverEnd > (_RHUD_upgEnd + 1))) then {
			if (_serverEnd > time) then {
				_cachedEnd = _serverEnd;
			} else {
				// Fall back to the local cache from WFBE_CL_FNC_Upgrade_Started (player-initiated path).
				_cachedEnd = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_end_time";
				if (isNil "_cachedEnd" || {_cachedEnd < 0}) then {_cachedEnd = time};
			};
			_RHUD_upgId = _id;
			_RHUD_upgEnd = _cachedEnd;
		};
		_remain = ceil (_RHUD_upgEnd - time);
		if (_remain < 0) then {_remain = 0};
		_mm = floor (_remain / 60);
		_ss = _remain - (_mm * 60);
		_txt = if (_ss < 10) then {Format["%1 %2:0%3", _lbl, _mm, _ss]} else {Format["%1 %2:%3", _lbl, _mm, _ss]};
		[23, "Upgrade:"] call _RHUDSetText;
		[24, _txt] call _RHUDSetText;
	} else {
		_RHUD_upgId = -1;
		[23, ""] call _RHUDSetText;
		[24, ""] call _RHUDSetText;
	};

	//--- Next (indices 25/26).
	_queue = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
	if (isNil "_queue") then {_queue = []};
	if (count _queue > 0 && {(_queue select 0) < count _labels}) then {
		[25, "Next:"] call _RHUDSetText;
		[26, _labels select (_queue select 0)] call _RHUDSetText;
	} else {
		[25, ""] call _RHUDSetText;
		[26, ""] call _RHUDSetText;
	};
};

_RHUDSetFPSPosition = {
	private["_mini", "_labelX", "_valueX", "_row1Y", "_row2Y", "_labelW", "_valueW", "_lineH"];
	_mini = _this;

	if (!_mini) exitWith {
		(_controls select 19) ctrlSetPosition [0.881728 * safezoneW + safezoneX, 0.366000 * safezoneH + safezoneY, 0.1025 * safezoneW, 0.0255556 * safezoneH];
		(_controls select 20) ctrlSetPosition [0.925958 * safezoneW + safezoneX, 0.366000 * safezoneH + safezoneY, 0.4401041 * safezoneW, 0.0255556 * safezoneH];
		(_controls select 21) ctrlSetPosition [0.881728 * safezoneW + safezoneX, 0.386000 * safezoneH + safezoneY, 0.1025 * safezoneW, 0.0255556 * safezoneH];
		(_controls select 22) ctrlSetPosition [0.925958 * safezoneW + safezoneX, 0.386000 * safezoneH + safezoneY, 0.4401041 * safezoneW, 0.0255556 * safezoneH];
		{_x ctrlCommit 0} forEach [(_controls select 19), (_controls select 20), (_controls select 21), (_controls select 22)];
	};

	_labelX = safezoneX + safezoneW - (0.150 * safezoneW);
	_valueX = safezoneX + safezoneW - (0.060 * safezoneW);
	// Marty: Align the FPS-only first row with the full RHUD first row.
	_row1Y = safezoneY + (0.18626 * safezoneH);
	_row2Y = safezoneY + (0.20626 * safezoneH);
	_labelW = 0.085 * safezoneW;
	_valueW = 0.050 * safezoneW;
	_lineH = 0.0255556 * safezoneH;

	(_controls select 19) ctrlSetPosition [_labelX, _row1Y, _labelW, _lineH];
	(_controls select 20) ctrlSetPosition [_valueX, _row1Y, _valueW, _lineH];
	(_controls select 21) ctrlSetPosition [_labelX, _row2Y, _labelW, _lineH];
	(_controls select 22) ctrlSetPosition [_valueX, _row2Y, _valueW, _lineH];
	{_x ctrlCommit 0} forEach [(_controls select 19), (_controls select 20), (_controls select 21), (_controls select 22)];
};

_RHUDSetFullPosition = {
	private["_labelX", "_valueX", "_startY", "_rowH", "_labelW", "_valueW", "_lineH", "_rowY", "_layoutPairs"];
	_labelX = safezoneX + safezoneW - (0.185 * safezoneW);
	_valueX = safezoneX + safezoneW - (0.095 * safezoneW);
	// Marty: Keep the full RHUD first row at its original vertical position to avoid vehicle ammo overlays.
	_startY = safezoneY + (0.18626 * safezoneH);
	_rowH = 0.020 * safezoneH;
	_labelW = 0.088 * safezoneW;
	_valueW = 0.090 * safezoneW;
	_lineH = 0.0255556 * safezoneH;

	(_controls select 0) ctrlSetPosition [_labelX, _startY + (0.021 * safezoneH), 0.145 * safezoneW, 0.001 * safezoneH];

	_layoutPairs = [[1,2],[3,4],[5,6],[7,8],[9,10],[11,12],[13,14],[23,24],[25,26],[27,28]];
	for "_idx" from 0 to ((count _layoutPairs) - 1) do {
		_rowY = _startY + (_idx * _rowH);
		(_controls select ((_layoutPairs select _idx) select 0)) ctrlSetPosition [_labelX, _rowY, _labelW, _lineH];
		(_controls select ((_layoutPairs select _idx) select 1)) ctrlSetPosition [_valueX, _rowY, _valueW, _lineH];
	};

	{
		_x ctrlCommit 0;
	} forEach _controls;
};

// Card #219: artillery cooldown row (indices 27 label / 28 value).
// Client-local only: reads the global fireMissionTime (set in GUI_Menu_Tactical on request,
// initialised to -1000 in Init_Client) and the upgrade-scaled reload interval that the fire
// action itself uses to gate cooldown. No server round-trip, no publicVariable.
_RHUDUpdateArty = {
	private ["_fireTime", "_intervals", "_ups", "_elapsed", "_remain", "_last", "_valTxt", "_valColor"];
	//--- Only show the row when this side actually fields artillery.
	if ((missionNamespace getVariable ["WFBE_C_ARTILLERY", 0]) <= 0) exitWith {
		[27, ""] call _RHUDSetText;
		[28, ""] call _RHUDSetText;
	};

	_intervals = missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS";
	if (isNil "_intervals") exitWith {
		[27, ""] call _RHUDSetText;
		[28, ""] call _RHUDSetText;
	};
	_ups = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
	_fireTime = _intervals select (_ups select WFBE_UP_ARTYTIMEOUT);

	_last = fireMissionTime;
	if (isNil "_last") then {_last = -1000};
	_elapsed = time - _last;

	[27, "Arty:"] call _RHUDSetText;
	if (_elapsed > _fireTime) then {
		_valTxt = localize "STR_WF_TACTICAL_Available";
		_valColor = [0.451, 1, 0.278, 1];
	} else {
		_remain = round (_fireTime - _elapsed);
		if (_remain < 0) then {_remain = 0};
		_valTxt = Format ["%1 %2", _remain, localize "STR_WF_Seconds"];
		_valColor = [0.278, 0.510, 1, 1];
	};
	[28, _valTxt] call _RHUDSetText;
	[28, _valColor] call _RHUDSetColor;
};

sleep 10;

_RHUD_upgId = -1;
_RHUD_upgEnd = 0;

while {true} do {
	sleep 1;

	// Marty: Performance Audit timing for the local HUD refresh.
	_perfStart = diag_tickTime;

	// Marty: Resolve the shared cut display once per loop and rebuild RHUD control cache only after recreation.
	_display = call _RHUDGetDisplay;
	if (!isNull _display) then {
		if (_display != _lastDisplay) then {
			_lastDisplay = _display;
			call _RHUDResetControlCache;
		};
	};

	if (isNull _display) then {
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["client_rhud", diag_tickTime - _perfStart, Format["enabled:%1;visibleMap:%2;display:null", RUBHUD, visibleMap], "CLIENT"] Call PerformanceAudit_Record;
			};
		};
	} else {
		_hudMode = "hidden";
		if (RUBHUD) then {_hudMode = "full"};

		switch (_hudMode) do {
			case "hidden": {
				if (_lastHudMode != _hudMode) then {
					for "_idx" from 0 to ((count _rhudIDC) - 1) do {
						[_idx, false] call _RHUDSetShow;
					};
					_labelsApplied = false;
					_hudWasShown = false;
					_lastHudMode = _hudMode;
				};
			};
			case "full": {
				if (_lastHudMode != _hudMode) then {
					// Marty: Keep the full RHUD anchored near the same upper-right area as FPS-only mode.
					call _RHUDSetFullPosition;
					_labelsApplied = false;
					_lastHudMode = _hudMode;
				};

			// Marty: Show fixed RHUD labels once per display/toggle instead of rewriting them every refresh.
			if (!_labelsApplied) then {
				for "_idx" from 0 to ((count _rhudIDC) - 1) do {
					[_idx, true] call _RHUDSetShow;
				};
				{[_x, false] call _RHUDSetShow} forEach [15,16,17,18,19,20,21,22];
				[1, "Health:"] call _RHUDSetText;
				[3, "Commander:"] call _RHUDSetText;
				[5, "AI:"] call _RHUDSetText;
				[7, "Money:"] call _RHUDSetText;
				[9, "Supply:"] call _RHUDSetText;
				[11, "Base:"] call _RHUDSetText;
				[13, "FPS C/S:"] call _RHUDSetText;
				_labelsApplied = true;
				_hiddenApplied = false;
			};

			if (!_hudWasShown) then {
				_lastTownRefresh = -999;
				_hudWasShown = true;
			};

			_player = Leader player;
			_side = side group player;

			_bgColor = [1,0.2,0,1];
			if (_side == WEST) then {_bgColor = [0,0.4,1,1]};
			if (_lastBackgroundColor != str _bgColor) then {
				(_controls select 0) CtrlSetBackgroundColor _bgColor;
				_lastBackgroundColor = str _bgColor;
			};

			//HEALTH
			_status = damage _player;
			_health = 1 - _status;
			_healthAct = _health * 100;
			_healthColor = [0, 1, 0, 1];
			if (_health <= 0.89) then {_healthColor = [1, 0.8831, 0, 1]};
			if (_health <= 0.79) then {_healthColor = [1, 0.65, 0, 1]};
			if (_health <= 0.60) then {_healthColor = [1, 0.15, 0, 1]};
			if (_health <= 0.08) then {_healthColor = [0.45, 0.25, 0.25, 1]};
			[2, Format ["%1/100",str(round _healthAct)]] call _RHUDSetText;
			[2, _healthColor] call _RHUDSetColor;

			//COMMANDER
			_commanderText = " No Commander";
			if (!isNull commanderTeam) then {_commanderText = Format [" %1", name (leader commanderTeam)]};
			[4, [0.85, 0, 0, 1]] call _RHUDSetColor;
			[4, _commanderText] call _RHUDSetText;

			//AI COUNT
			_mbu = missionNamespace getVariable 'WFBE_C_PLAYERS_AI_MAX';
			//--- Patrols upgrade trades 1 max AI per player for the side's autonomous patrols.
			if (count ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) > WFBE_UP_PATROLS && {(((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_PATROLS) > 0}) then {_mbu = (_mbu - 1) max 1};
			_currentUnitsCount = Count ((Units (group player)) Call GetLiveUnits);
			_maxUnitsCount = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
			switch (_maxUnitsCount) do {
				case 0: {_maxUnitsCount = round(_mbu / 4)};
				case 1: {_maxUnitsCount = round(_mbu / 4)*2};
				case 2: {_maxUnitsCount = round(_mbu / 4)*3};
				case 3: {_maxUnitsCount = _mbu};
				default {_maxUnitsCount = _mbu};
			};
			_isCommanderTeam = false;
			if (!isNull commanderTeam) then {_isCommanderTeam = commanderTeam == group player};
			if (_isCommanderTeam) then {_maxUnitsCount = _maxUnitsCount + 10};

			_aiText = format ["%1 / %2", _currentUnitsCount, _maxUnitsCount];
			_aiColor = [0, 1, 0, 1];
			if (_currentUnitsCount >= _maxUnitsCount/2) then {_aiColor = [1, 0.8431, 0, 1]};
			if (_currentUnitsCount >= _maxUnitsCount) then {_aiColor = [1, 0, 0, 1]};
			[6, _aiText] call _RHUDSetText;
			[6, _aiColor] call _RHUDSetColor;

			// Marty: Town/economy aggregates walk the towns array, so refresh them less often than volatile HUD values.
			if (time - _lastTownRefresh > 3) then {
				_incomeText = Format ["+ %1 $",sideJoined Call GetIncome];
				_supplyText = Format ["%1",(sideJoined) Call GetSideSupply];
				_baseStructures = sideJoined Call WFBE_CO_FNC_GetSideStructures;
				_baseHq = sideJoined Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _baseHq) then {_baseStructures = _baseStructures + [_baseHq]};
				_baseTotal = 0;
				_baseDamaged = 0;
				{
					if (!isNull _x && {alive _x}) then {
						_baseTotal = _baseTotal + 1;
						if (damage _x > 0.10) then {_baseDamaged = _baseDamaged + 1};
					};
				} forEach _baseStructures;
				_baseText = Format ["%1 ok", _baseTotal];
				_baseColor = [0, 1, 0, 1];
				if (_baseDamaged > 0) then {
					_baseText = Format ["%1 ok | D%2", _baseTotal, _baseDamaged];
					_baseColor = [1, 0.8431, 0, 1];
				};
				if (_baseTotal == 0) then {_baseColor = [1, 0, 0, 1]};
				_lastTownRefresh = time;
			};

			//MONEY / INCOME
			_moneyText = Format ["%1 $ | %2", Call GetPlayerFunds, _incomeText];
			[8, _moneyText] call _RHUDSetText;
			[8, [0, 0.825294, 0.449803, 1]] call _RHUDSetColor;
			[10, _supplyText] call _RHUDSetText;
			[10, [1, 0.8831, 0, 1]] call _RHUDSetColor;
			[12, _baseText] call _RHUDSetText;
			[12, _baseColor] call _RHUDSetColor;

			call _RHUDUpdateServerFPSRow;
			call _RHUDUpdateUpgrade;
			call _RHUDUpdateArty;
			};
		};

		// Marty: Performance Audit record for the local HUD refresh.
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["client_rhud", diag_tickTime - _perfStart, Format["enabled:%1;visibleMap:%2", RUBHUD, visibleMap], "CLIENT"] Call PerformanceAudit_Record;
			};
		};
	};
};
