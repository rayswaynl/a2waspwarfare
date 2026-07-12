scriptName "Client\GUI\GUI_UpgradeMenu.sqf";

//--- Register the UI.
uiNamespace setVariable ["wfbe_display_upgrades", _this select 0];

//--- B75 (guer-tech): GUER has no commander and no standard upgrade economy, so the Upgrade Center is repurposed as a
//--- READ-ONLY view of the kill-based field tech (current kills, what's unlocked, the next threshold + reward). This is
//--- a self-contained branch that RETURNS (exitWith) before the commander upgrade machinery below; the purchase/queue
//--- buttons are disabled and the back button still routes to the WF menu. A2-OA safe (lnb*/structuredText only).
if ((side group player) == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) exitWith {
	disableSerialization;
	if (!((missionNamespace getVariable ["WFBE_C_GUER_TECHVIEW_V2", 1]) > 0)) then {
		//--- V1 legacy rendering (WFBE_C_GUER_TECHVIEW_V2 = 0 = byte-identical behavior).
		private ["_disp","_names","_lastKey"];
		_disp = _this select 0;
		ctrlEnable [504007, false]; ctrlEnable [504008, false]; ctrlEnable [504009, false];
		lnbClear 504001;
		_names = ["Tech Kills","Heavy Vehicles","M113 VBIED","Ka-137 Flares","Barracks AI","FOB Field Bases"];
		{ lnbAddRow [504001, ["", _x]] } forEach _names;
		lnbSetCurSelRow [504001, 0];
		((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504006) ctrlSetStructuredText (parseText "<t>GUER FIELD TECH - earned by kills (read-only). Select a line for details.</t>");
		_lastKey = "";
		WFBE_MenuAction = -1;
		while {alive player && dialog} do {
			private ["_kills","_tier","_avail","_k1","_k2","_k3","_m113k","_flare","_capAI","_baseAI","_perKills","_maxAI","_sel","_key","_next","_title","_html","_desc"];
			_kills   = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
			_tier    = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
			_avail   = missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]];
			if (typeName _avail != "ARRAY" || {count _avail < 3}) then {_avail = [0,0,0]};
			_k1 = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_1", 30];
			_k2 = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_2", 80];
			_k3 = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_3", 160];
			_m113k = missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 50];
			_flare = [60,120,240] select (_tier min 2);
			_baseAI   = missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_BASE", 4];
			_perKills = missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_PER_KILLS", 10];
			_maxAI    = missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_MAX", 12];
			_capAI = (_baseAI + floor (_kills / _perKills)) min _maxAI;
			_sel = lnbCurSelRow 504001;
			if (_sel < 0) then {_sel = 0};
			_key = Format ["%1|%2|%3|%4", _sel, _kills, _tier, _avail];
			if (_key != _lastKey) then {
				_lastKey = _key;
				_title = _names select _sel;
				_html = "";
				_desc = "";
				switch (_sel) do {
					case 0: {
						_html = Format ["<t color='#B6F563' size='1.1'>Tech Kills: %1</t>", _kills];
						_desc = "Cumulative kills made by GUER PLAYERS against WEST/EAST. This single number drives every field-tech line below - there is no cash upgrade, you simply fight for it.";
					};
					case 1: {
						//--- tier-3 roster differs by map: Chernarus GUE has T-72 + BMP-2; Takistan GUE caps at a ZU-23 Ural (no T-72/BMP-2).
						private ["_t3"];
						_t3 = if (worldName == "Takistan" || worldName == "Zargabad") then {"ZU-23 Ural (heavy weapons)"} else {"T-72 + BMP-2"};
						_next = if (_tier < 1) then {Format ["%1 kills -> BRDM-2 + T-34", _k1]} else {if (_tier < 2) then {Format ["%1 kills -> T-55", _k2]} else {if (_tier < 3) then {Format ["%1 kills -> %2", _k3, _t3]} else {"all unlocked"}}};
						_html = Format ["<t color='#B6F563' size='1.1'>Heavy Vehicles - Tier %1 / 3</t><br/><t color='#F5D363'>Next: %2</t>", _tier, _next];
						_desc = Format ["Tier 1 (%1 kills): BRDM-2 + T-34.<br/>Tier 2 (%2 kills): T-55.<br/>Tier 3 (%3 kills): %4.<br/>Unlocked vehicles appear in the depot.", _k1, _k2, _k3, _t3];
					};
					case 2: {
						_html = Format ["<t color='#B6F563' size='1.1'>M113 VBIED: %1</t>", if (_kills >= _m113k) then {"UNLOCKED"} else {Format ["locked (%1 / %2 kills)", _kills, _m113k]}];
						_desc = "An unarmed, armoured M113 driven as a suicide VBIED at ~2x its normal top speed. Bought from the depot like the truck VBIED. Tracked + fast, it reaches targets the soft truck can't.";
					};
					case 3: {
						_html = Format ["<t color='#B6F563' size='1.1'>Ka-137 Flares: %1</t>", _flare];
						_desc = "The bought Ka-137 gets countermeasure flares sized by tier: 60 (start) -> 120 (tier 1) -> 240 (tier 2+). Armed automatically when you buy the Ka-137.";
					};
					case 4: {
						_html = Format ["<t color='#B6F563' size='1.1'>Barracks AI cap: %1</t>", _capAI];
						_desc = Format ["Your barracks squad ceiling = %1 + 1 per %2 kills, capped at %3 (the engine group limit). More kills = a bigger fieldable GUER squad.", _baseAI, _perKills, _maxAI];
					};
					case 5: {
						_html = Format ["<t color='#B6F563' size='1.1'>FOB bases available - B %1 | LF %2 | HF %3</t>", _avail select 0, _avail select 1, _avail select 2];
						_desc = "Destroy an enemy Barracks / Light / Heavy factory to earn a FOB delivery truck of that type (buy it in the depot). Drive it to a valid spot and 'Build FOB' to raise a forward factory you can spawn on and produce from.";
					};
					default {};
				};
				((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504003) ctrlSetStructuredText (parseText _html);
				((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504005) ctrlSetStructuredText (parseText (Format ["<t color='#42b6ff' underline='1'>%1</t><br/><br/>%2", _title, _desc]));
			};
			if (WFBE_MenuAction == 1000) exitWith {WFBE_MenuAction = -1; closeDialog 0; createDialog "WF_Menu"};
			WFBE_MenuAction = -1;
			sleep 0.25;
		};
	} else {
		//--- V2 progression-first re-render (WFBE_C_GUER_TECHVIEW_V2 > 0). Phases A + B1 + B3.
		private ["_disp","_lastKey","_t3","_thresholds","_tierNames","_xlink","_xlinkRow","_hintOn","_hintedTier","_approachHinted"];
		_disp = _this select 0;
		ctrlEnable [504007, false]; ctrlEnable [504008, false]; ctrlEnable [504009, false];
		_t3 = if (worldName == "Takistan" || {worldName == "Zargabad"}) then {"ZU-23 Ural"} else {"T-72 + BMP-2"};
		_tierNames = ["Base", "Light Armor", "Main Battle", "Heavy Armor"];
		_thresholds = [0, 0, 0, 0];
		//--- B3: cross-link row to Commissar Panel (WFBE_C_GUER_TECHVIEW_XLINK). Inline default 1 = owner approved tonight.
		_xlink = (missionNamespace getVariable ["WFBE_C_GUER_TECHVIEW_XLINK", 1]) > 0;
		_xlinkRow = 4;
		//--- B1: tier-crossing hints (WFBE_C_GUER_TECHVIEW_HINT). Inline default 1 = owner approved tonight.
		_hintOn = (missionNamespace getVariable ["WFBE_C_GUER_TECHVIEW_HINT", 1]) > 0;
		_hintedTier = -1;
		_approachHinted = [false, false, false];
		lnbClear 504001;
		lnbAddRow [504001, ["[OK]", "Base", "Always active"]];
		lnbAddRow [504001, ["--", "Light Armor (T1)", ""]];
		lnbAddRow [504001, ["--", "Main Battle (T2)", ""]];
		lnbAddRow [504001, ["--", "Heavy Armor (T3)", ""]];
		if (_xlink) then {
			lnbAddRow [504001, [">>", "[ Commission Panel ]", ""]];
		};
		lnbSetCurSelRow [504001, 0];
		((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504006) ctrlSetStructuredText (parseText "<t>GUER FIELD TECH - earned by kills (read-only). Select a tier for details.</t>");
		_lastKey = "";
		WFBE_MenuAction = -1;
		while {alive player && dialog} do {
			private ["_kills","_tier","_k1","_k2","_k3","_sel","_key","_g0","_g1","_g2","_g3","_tierNameCur","_hdrHtml","_barHtml","_detHtml","_selThresh","_toGo","_barFill","_barEmpty","_barStr","_bk","_aIdx","_approachThresh","_m113k"];
			_kills = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
			_tier  = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
			_k1    = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_1", 30];
			_k2    = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_2", 80];
			_k3    = missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_3", 160];
			_m113k = missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 50];
			_thresholds set [1, _k1];
			_thresholds set [2, _k2];
			_thresholds set [3, _k3];
			_sel = lnbCurSelRow 504001;
			if (_sel < 0) then {_sel = 0};
			_key = Format ["%1|%2|%3", _sel, _kills, _tier];
			if (_key != _lastKey) then {
				_lastKey = _key;
				//--- Update tier-ladder glyphs: [OK] = surpassed, >> = current, -- = locked.
				_g0 = if (_tier > 0) then {"[OK]"} else {">>"};
				_g1 = if (_tier > 1) then {"[OK]"} else {if (_tier == 1) then {">>"} else {"--"}};
				_g2 = if (_tier > 2) then {"[OK]"} else {if (_tier == 2) then {">>"} else {"--"}};
				_g3 = if (_tier >= 3) then {">>"} else {"--"};
				lnbSetText [504001, [0, 0], _g0];
				lnbSetText [504001, [1, 0], _g1];
				lnbSetText [504001, [2, 0], _g2];
				lnbSetText [504001, [3, 0], _g3];
				lnbSetText [504001, [1, 2], Format ["%1 kills", _k1]];
				lnbSetText [504001, [2, 2], Format ["%1 kills", _k2]];
				lnbSetText [504001, [3, 2], Format ["%1 kills", _k3]];
				//--- Header bar: current tier name + total kills.
				_tierNameCur = _tierNames select (_tier min 3);
				_hdrHtml = Format ["<t>Field Tech: Tier %1 - %2  *  %3 kills</t>", _tier, _tierNameCur, _kills];
				((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504006) ctrlSetStructuredText (parseText _hdrHtml);
				//--- Detail panes driven by selected row.
				_barHtml = "";
				_detHtml = "";
				if (_xlink && {_sel == _xlinkRow}) then {
					//--- B3: cross-link row selected - enable the Upgrade button as "Open Panel" trigger.
					ctrlEnable [504007, true];
					ctrlSetText [504007, "Open Panel"];
					_barHtml = "<t color='#F5D363'>Double-click or press 'Open Panel' to open the Commissar Panel.</t>";
					_detHtml = "<t color='#42b6ff' underline='1'>Commission Panel</t><br/><br/>Opens the GUER Director town-action panel. Spend kill income on reinforcements, QRF, and supply actions for captured towns.<br/><br/><t color='#F56363'>Requires: GUER Director active and Commissar Panel enabled.</t>";
				} else {
					ctrlEnable [504007, false];
					ctrlSetText [504007, "Upgrade"];
					if (_sel >= 0 && {_sel <= 3}) then {
						_selThresh = _thresholds select _sel;
						if (_sel == 0 || {_tier >= _sel}) then {
							_barHtml = Format ["<t color='#76F563'>[UNLOCKED] %1  *  %2 kills total</t>", (_tierNames select _sel), _kills];
						} else {
							_barFill  = floor ((_kills min _selThresh) * 10 / (_selThresh max 1));
							_barEmpty = 10 - _barFill;
							_barStr = "";
							for "_bk" from 1 to _barFill  do {_barStr = _barStr + "#"};
							for "_bk" from 1 to _barEmpty do {_barStr = _barStr + "-"};
							_toGo = _selThresh - (_kills min _selThresh);
							_barHtml = Format ["<t color='#F5D363'>%1  %2/%3  -  %4 kills to go</t>", _barStr, _kills, _selThresh, _toGo];
						};
						switch (_sel) do {
							case 0: {
								_detHtml = "<t color='#42b6ff' underline='1'>Base Tier</t><br/><br/>Starting state for all GUER players.<br/>- Standard insurgent loadout available in depot<br/>- Ka-137 with 60 countermeasure flares<br/>- Barracks AI cap at base value<br/><br/><t color='#888888'>All kills by GUER players count toward side tech level.</t>";
							};
							case 1: {
								_detHtml = Format ["<t color='#42b6ff' underline='1'>Light Armor (Tier 1 - %1 kills)</t><br/><br/>Status: %2<br/>- BRDM-2 unlocked in depot<br/>- T-34 unlocked in depot<br/>- Ka-137 flares: 120<br/>- M113 VBIED: unlocks at %3 kills (tracked separately)<br/><br/><t color='#888888'>All kills by GUER players count toward side tech level.</t>", _k1, if (_tier >= 1) then {"UNLOCKED"} else {"Locked - keep fighting"}, _m113k];
							};
							case 2: {
								_detHtml = Format ["<t color='#42b6ff' underline='1'>Main Battle (Tier 2 - %1 kills)</t><br/><br/>Status: %2<br/>- T-55 unlocked in depot<br/>- Ka-137 flares: 240<br/><br/><t color='#888888'>All kills by GUER players count toward side tech level.</t>", _k2, if (_tier >= 2) then {"UNLOCKED"} else {"Locked - keep fighting"}];
							};
							case 3: {
								_detHtml = Format ["<t color='#42b6ff' underline='1'>Heavy Armor (Tier 3 - %1 kills)</t><br/><br/>Status: %2<br/>- %3 unlocked in depot<br/>- Ka-137 flares: 240 (sustained)<br/><br/><t color='#888888'>All kills by GUER players count toward side tech level.</t>", _k3, if (_tier >= 3) then {"UNLOCKED"} else {"Locked - keep fighting"}, _t3];
							};
							default {};
						};
					};
				};
				((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504003) ctrlSetStructuredText (parseText _barHtml);
				((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504005) ctrlSetStructuredText (parseText _detHtml);
			};
			//--- B1: tier-crossing and approach hints (single-fire per threshold, client-side only).
			if (_hintOn) then {
				if (_tier > _hintedTier) then {
					_hintedTier = _tier;
					if (_tier > 0) then {
						hint parseText (Format ["<t color='#B6F563' size='1.2'>FIELD TECH UNLOCKED</t><br/><br/>GUER reached <t color='#F5D363'>Tier %1 - %2</t>.<br/>New vehicles are now available in the depot!", _tier, (_tierNames select (_tier min 3))]);
					};
				};
				_aIdx = _tier + 1;
				if (_aIdx <= 3) then {
					if (!(_approachHinted select (_aIdx - 1))) then {
						_approachThresh = floor ((_thresholds select _aIdx) * 9 / 10);
						if (_kills >= _approachThresh && {_tier < _aIdx}) then {
							_approachHinted set [(_aIdx - 1), true];
							hint parseText (Format ["<t color='#F5D363' size='1.2'>APPROACHING TIER %1</t><br/><br/>%2 kills - %3 more to unlock <t color='#B6F563'>%4</t>!", _aIdx, _kills, (_thresholds select _aIdx) - _kills, (_tierNames select _aIdx)]);
						};
					};
				};
			};
			//--- B3: cross-link action - double-click or Upgrade button (MenuAction 1) on the cross-link row.
			if (_xlink && {WFBE_MenuAction == 1}) then {
				if ((lnbCurSelRow 504001) == _xlinkRow) then {
					WFBE_MenuAction = -1;
					if (((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0) && {(missionNamespace getVariable ["AICOMV2_GDIR_PANEL", 0]) > 0}) then {
						closeDialog 0;
						createDialog "WFBE_GDirCommissarMenu";
					} else {
						hint parseText "<t color='#F56363'>Commission Panel is not available (GUER Director inactive).</t>";
					};
				};
			};
			if (WFBE_MenuAction == 1000) exitWith {WFBE_MenuAction = -1; closeDialog 0; createDialog "WF_Menu"};
			WFBE_MenuAction = -1;
			sleep 0.25;
		};
	};
	uiNamespace setVariable ["wfbe_display_upgrades", nil];
};
_upgrade_lastsel = uiNamespace getVariable "wfbe_display_upgrades_sel";
if (isNil '_upgrade_lastsel') then {_upgrade_lastsel = 0; uiNamespace setVariable ["wfbe_display_upgrades_sel", 0]};

_currency_system = missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM";
_upgrade_enabled = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_ENABLED",WFBE_Client_SideJoinedText];
_upgrade_costs = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS",WFBE_Client_SideJoinedText];
_upgrade_descriptions = missionNamespace getVariable "WFBE_C_UPGRADES_DESCRIPTIONS";
_upgrade_images = missionNamespace getVariable "WFBE_C_UPGRADES_IMAGES";
_upgrade_labels = missionNamespace getVariable "WFBE_C_UPGRADES_LABELS";
_upgrade_levels = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS",WFBE_Client_SideJoinedText];
_upgrade_links = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS",WFBE_Client_SideJoinedText];
_upgrade_sorted = missionNamespace getVariable "WFBE_C_UPGRADES_SORTED";
_upgrade_times = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES",WFBE_Client_SideJoinedText];
_upgrade_isupgrading = false;
_upgrade_running_id = -1;

_upgrades = (WFBE_Client_SideJoined) call WFBE_CO_FNC_GetSideUpgrades;
_i = 0;
{
	if (_upgrade_enabled select _x) then {
		//--- Ray B89: 3rd cell = dedicated right-hand Q# column (empty at build; filled on refresh below).
		lnbAddRow [504001, [Format ["%1/%2",_upgrades select _x,_upgrade_levels select _x],_upgrade_labels select _x,""]];
		lnbSetValue [504001, [_i, 0], _x];
		//--- Card #164: paint the upgrade icon into the level cell (column 0), same cell-picture pattern as Client_UI_Gear_FillList. Skip empty image strings for graceful fallback.
		if ((_upgrade_images select _x) != "") then {lnbSetPicture [504001, [_i, 0], (_upgrade_images select _x)]};
		_i = _i + 1;
	};
} forEach _upgrade_sorted;
lnbSetCurSelRow[504001, _upgrade_lastsel];
_upgrades_old = _upgrades;

_purchase = false;
_queue_add = false;
_queue_remove = false;
_queue_old = [];
_queue_footer_old = [];
_update_upgrade = true;
_update_upgrade_details = true;
_update_list = false;
_update_upgrade_lastcheck = -1;

_player_commander = false; //added-MrNiceGuy
if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_player_commander = true}};
if !(_player_commander) then {ctrlEnable [504007, false]};
if !(_player_commander) then {ctrlEnable [504008, false]};
if !(_player_commander) then {ctrlEnable [504009, false]};

WFBE_MenuAction = -1;

// Marty: Keep the countdown display isolated from the main menu loop so the Upgrade button flow stays untouched.
// Ownership: this spawn writes 504006 ONLY while an upgrade is running (running branch below).
// The idle branch no longer blanks 504006 — that would erase the footer's "Queued:" list.
[_upgrade_labels, _upgrade_times] spawn {
	Private ["_html","_labels","_lastRemaining","_remaining","_remainingMinutes","_remainingSeconds","_remainingSecondsText","_runningEndTime","_runningId","_runningLabel","_runningLevel","_runningState","_runningTime","_serverEndTime","_storedEndTime","_storedId","_times","_upgrades"];

	disableSerialization;

	_labels = _this select 0;
	_times = _this select 1;
	_runningEndTime = -1;
	_lastRemaining = -2;

	while {alive player && dialog} do {
		_runningState = WFBE_Client_Logic getVariable ["wfbe_upgrading", false];
		if (isNil "_runningState") then {_runningState = false};

		_runningId = WFBE_Client_Logic getVariable "wfbe_upgrading_id";
		if (isNil "_runningId") then {_runningId = -1};

		if !(_runningState) then {
			_runningEndTime = -1;
			_lastRemaining = -2;
			WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_id", -1, false];
			WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_end_time", -1, false];
			// Marty: Idle branch — do NOT write 504006 here; the footer (main loop) owns it when not upgrading.
			sleep 1;
		};

		if (_runningState) then {
			// Marty: PREFER the server-replicated authoritative end time. Server_ProcessUpgrade.sqf
			// publishes wfbe_upgrading_end_time for EVERY upgrade source (player, queue AND AI), so this is
			// the one value that is correct for queue/AI upgrades too (no local upgrade-started message ever
			// reached this client for those). Use it only when it is still in the future; otherwise fall
			// through to the existing local race-guard / recompute so the recent rework is not regressed.
			_serverEndTime = WFBE_Client_Logic getVariable "wfbe_upgrading_end_time";
			if (isNil "_serverEndTime") then {_serverEndTime = -1};
			if (_serverEndTime > time) then {_runningEndTime = _serverEndTime};

			_storedId = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_id";
			if (isNil "_storedId") then {_storedId = -1};
			_storedEndTime = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_end_time";
			if (isNil "_storedEndTime") then {_storedEndTime = -1};
			if (_serverEndTime <= time && _storedId == _runningId && _storedEndTime > time) then {_runningEndTime = _storedEndTime};

			if (_serverEndTime <= time && (_storedId != _runningId || _runningEndTime < time)) then {
				// Marty: Race guard — re-read the persisted end time first; it may have been
				// written by the Purchase branch (which knows the exact start time). Only
				// recompute from level if the persisted end time is still stale or absent.
				_storedEndTime = WFBE_Client_Logic getVariable "wfbe_upgrading_countdown_end_time";
				if (isNil "_storedEndTime") then {_storedEndTime = -1};
				if (_storedId == _runningId && _storedEndTime > time) then {
					_runningEndTime = _storedEndTime;
				} else {
					// Recompute from level - 1 (pre-completion level) clamped to times-array bounds.
					// Using (level - 1) max 0 avoids the 0:00 flash caused by reading the already-
					// incremented post-completion level during the publicVariable/HandleSpecial race.
					_runningTime = 0;
					_upgrades = (WFBE_Client_SideJoined) call WFBE_CO_FNC_GetSideUpgrades; //--- A2-fix (2026-06-14): assign BEFORE the guard reads count _upgrades (was use-before-definition at the guard).
					if (_runningId >= 0 && {_runningId < count _times} && {_runningId < count _upgrades}) then {
						_runningLevel = ((_upgrades select _runningId) - 1) max 0;
						if (_runningLevel < count (_times select _runningId)) then {
							_runningTime = (_times select _runningId) select _runningLevel;
						};
					};
					_runningEndTime = time + _runningTime;
					WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_id", _runningId, false];
					WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_end_time", _runningEndTime, false];
				};
			};

			_remaining = ceil (_runningEndTime - time);
			if (_remaining < 0) then {_remaining = 0};

			if (_remaining != _lastRemaining) then {
				_lastRemaining = _remaining;
				_runningLabel = if (_runningId >= 0 && _runningId < count _labels) then {_labels select _runningId} else {"An upgrade"};
				_remainingMinutes = floor (_remaining / 60);
				_remainingSeconds = _remaining - (_remainingMinutes * 60);
				_remainingSecondsText = if (_remainingSeconds < 10) then {Format["0%1", _remainingSeconds]} else {str _remainingSeconds};
				_html = Format["<t><t color='#B6F563'>%1</t> is currently running - <t color='#F5D363'>%2:%3</t> remaining</t>", _runningLabel, _remainingMinutes, _remainingSecondsText];

				// Marty: Re-read the display when needed instead of keeping a display variable alive across sleep.
				if !(isNil {uiNamespace getVariable "wfbe_display_upgrades"}) then {((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504006) ctrlSetStructuredText (parseText _html)};
			};

			sleep 1;
		};
	};
};

while {alive player && dialog} do {
	if (WFBE_MenuAction == 1) then {WFBE_MenuAction = -1; if (_player_commander) then {_purchase = true}};
	if (WFBE_MenuAction == 2) then {WFBE_MenuAction = -1;_update_upgrade = true};
	if (WFBE_MenuAction == 3) then {WFBE_MenuAction = -1; if (_player_commander) then {_queue_add = true}};
	if (WFBE_MenuAction == 4) then {WFBE_MenuAction = -1; if (_player_commander) then {_queue_remove = true}};

	_upgrades = (WFBE_Client_SideJoined) call WFBE_CO_FNC_GetSideUpgrades;
	
	if (time - _update_upgrade_lastcheck > 0.5) then {
		_update_list = false;
		_update_upgrade_lastcheck = time;
		for '_i' from 0 to count(_upgrades_old)-1 do {if ((_upgrades_old select _i) != (_upgrades select _i)) exitWith {_update_list = true}};
		_queue_now = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
		if (isNil "_queue_now") then {_queue_now = []};
		if ((str _queue_now) != (str _queue_old)) then {_update_list = true; _update_upgrade = true; _queue_old = + _queue_now};
		if (_update_list) then {
			_update_list = false;
			//--- QoL fix: removed dead raw-index refresh loop (it wrote rows in unsorted order, then was instantly overwritten by the sorted loop below).
			
			_i = 0;
			{
				if (_upgrade_enabled select _x) then {
					//--- Stacking: an id can hold several queue slots; list them all (e.g. " [Q1,3]").
					_qtag = "";
					for "_qk" from 0 to (count _queue_old - 1) do {
						if ((_queue_old select _qk) == _x) then {_qtag = _qtag + (if (_qtag == "") then {""} else {","}) + str (_qk + 1)};
					};
					//--- Ray B89: Q# now lives in the dedicated right column (index 2). Column 0 stays a clean
					//--- level/max string; the queue tag ("Q1,3") is written to column 2 so the commander can read it.
					if (_qtag != "") then {_qtag = Format ["Q%1", _qtag]};
					lnbSetText[504001, [_i, 0], Format ["%1/%2",_upgrades select _x,_upgrade_levels select _x]];
					lnbSetText[504001, [_i, 2], _qtag];
						//--- Card #164: keep the icon painted on refresh (lnbSetText leaves the cell picture intact; repaint guards against reordering).
						if ((_upgrade_images select _x) != "") then {lnbSetPicture [504001, [_i, 0], (_upgrade_images select _x)]};
					_i = _i + 1;
				};
			} forEach _upgrade_sorted;
			
			_ui_lnb_sel = lnbCurSelRow(504001);
			if (_ui_lnb_sel != -1) then {lnbSetCurSelRow[504001, _ui_lnb_sel]};
		};
		_upgrades_old = _upgrades;
	};
	
	if (_update_upgrade) then {
		_update_upgrade = false;
		_ui_lnb_sel = lnbCurSelRow(504001);
		if (_ui_lnb_sel != -1) then {
			_id = lnbValue[504001, [_ui_lnb_sel, 0]];
			uiNamespace setVariable ["wfbe_display_upgrades_sel", _ui_lnb_sel];
			ctrlSetText[504002, if ((_upgrade_images select _id) != "") then {_upgrade_images select _id} else {""}];
			((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504005) ctrlSetStructuredText (parseText (_upgrade_descriptions select _id));
			_qsel = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
			if (isNil "_qsel") then {_qsel = []};
			//--- Stacking: Queue is enabled while levels remain unqueued; "-" while copies are queued.
			_qpending = {_x == _id} count _qsel;
			_qtotal = _qpending;
			if ((WFBE_Client_Logic getVariable ["wfbe_upgrading", false]) && {(WFBE_Client_Logic getVariable "wfbe_upgrading_id") == _id}) then {_qtotal = _qtotal + 1};
			if (_player_commander) then {
				ctrlEnable [504008, ((_upgrades select _id) + _qtotal) < (_upgrade_levels select _id)];
				ctrlEnable [504009, _qpending > 0];
			};
		};
		_update_upgrade_details = true;
	};

	if (_update_upgrade_details) then {
		_update_upgrade_details = false;
		_ui_lnb_sel = lnbCurSelRow(504001);
		if (_ui_lnb_sel != -1) then {
			_id = lnbValue[504001, [_ui_lnb_sel, 0]];
			_upgrade_current = _upgrades select _id;
			_funds = call WFBE_CL_FNC_GetClientFunds;
			_supply = if (_currency_system == 0) then {(WFBE_Client_SideJoined) call WFBE_CO_FNC_GetSideSupply} else {9000000};
			_html = "";
			_html2 = "<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Dependencies:</t><br /><br />";
			if (_upgrade_current < (_upgrade_levels select _id)) then {
				_upgrade_supply = ((_upgrade_costs select _id) select _upgrade_current) select 0;
				_upgrade_price = ((_upgrade_costs select _id) select _upgrade_current) select 1;
				_upgrade_next = _upgrade_current + 1;
				if (_currency_system == 0) then {
					_html = Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>%1:</t><br /><br /><t color='#42b6ff' shadow='1'>Current Level :</t><t shadow='1' align='right'><t color='#F5D363'>%2</t>/<t color='#F5D363'>%3</t></t><br /><t color='#42b6ff' shadow='1'>Next Level :</t><t shadow='1' align='right'><t color='#F5D363'>%4</t></t><br /><t color='#42b6ff' shadow='1'>Needed Funds :</t><t shadow='1' align='right'><t color='#F5D363'>%5</t>/<t color='%6'>%7</t> $</t><br /><t color='#42b6ff' shadow='1'>Needed Supply :</t><t shadow='1' align='right'><t color='#F5D363'>%8</t>/<t color='%9'>%10</t> S</t><br /><t color='#42b6ff' shadow='1'>Needed Time :</t><t shadow='1' align='right'><t color='#F5D363'>%11</t> Seconds</t><br />",_upgrade_labels select _id,_upgrade_current, _upgrade_levels select _id,_upgrade_next,_upgrade_price,if(_funds >= _upgrade_price) then {'#76F563'} else {'#F56363'},_funds,_upgrade_supply,if(_supply >= _upgrade_supply) then {'#76F563'} else {'#F56363'},_supply,(_upgrade_times select _id) select _upgrade_current];
				} else {
					_html = Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>%1:</t><br /><br /><t color='#42b6ff' shadow='1'>Current Level :</t><t shadow='1' align='right'><t color='#F5D363'>%2</t>/<t color='#F5D363'>%3</t></t><br /><t color='#42b6ff' shadow='1'>Next Level :</t><t shadow='1' align='right'><t color='#F5D363'>%4</t></t><br /><t color='#42b6ff' shadow='1'>Needed Funds :</t><t shadow='1' align='right'><t color='#F5D363'>%5</t>/<t color='%6'>%7</t> $</t><br /><br /><t color='#42b6ff' shadow='1'>Needed Time :</t><t shadow='1' align='right'><t color='#F5D363'>%8</t> Seconds</t><br />",_upgrade_labels select _id,_upgrade_current, _upgrade_levels select _id,_upgrade_next,_upgrade_price,if(_funds >= _upgrade_price) then {'#76F563'} else {'#F56363'},_funds,(_upgrade_times select _id) select _upgrade_current];
				};
				_links = (_upgrade_links select _id) select _upgrade_current;
				if (count _links > 0) then {
					if (typeName (_links select 0) == "ARRAY") then {
						_count = count(_links);
						for '_i' from 0 to _count-1 do {
							_coma = if (_i+1 < _count) then {", "} else {""};
							_clink = _links select _i;
							_linkto = _upgrades select (_clink select 0);
							_html2 = _html2 + Format ["<t shadow='1'><t color='%1'>%2 </t><t color='#F5D363'>%3</t>%4</t>",if (_linkto >= (_clink select 1)) then {'#76F563'} else {'#F56363'},_upgrade_labels select (_clink select 0), _clink select 1,_coma];
						};
					} else {
						_linkto = _upgrades select (_links select 0);
						if (_linkto >= (_links select 1)) then {_html2 = _html2 + "<t color='#76F563' shadow='1'>All dependencies are met</t>"} else {_html2 = _html2 + Format ["<t shadow='1'><t color='#F56363'>%1 </t><t color='#F5D363'>%2</t></t>",_upgrade_labels select (_links select 0), _links select 1]};
					};
				} else {
					_html2 = _html2 + "<t color='#76F563' shadow='1'>None</t>";
				};
			} else {
				_html = Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>%1:</t><br /><br /><t color='#76F563' shadow='1'>The maximum upgrade level has been reached.</t>",_upgrade_labels select _id];
				_html2 = _html2 + "<t color='#76F563' shadow='1'>None</t>";
			};
			((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504003) ctrlSetStructuredText (parseText _html);
			((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504004) ctrlSetStructuredText (parseText _html2);
		};
	};
	
	if (_purchase) then {
		_purchase = false;
		_ui_lnb_sel = lnbCurSelRow(504001);
		if (_ui_lnb_sel != -1) then {
			_id = lnbValue[504001, [_ui_lnb_sel, 0]];
			_upgrade_current = _upgrades select _id;
			_funds = call WFBE_CL_FNC_GetClientFunds;
			_supply = if (_currency_system == 0) then {(WFBE_Client_SideJoined) call WFBE_CO_FNC_GetSideSupply} else {9000000};
			if !(WFBE_Client_Logic getVariable ["wfbe_upgrading", false]) then {
				if (_upgrade_current < (_upgrade_levels select _id)) then {
					_upgrade_supply = ((_upgrade_costs select _id) select _upgrade_current) select 0;
					_upgrade_price = ((_upgrade_costs select _id) select _upgrade_current) select 1;
					if(_funds >= _upgrade_price && _supply >= _upgrade_supply) then {
						_links = (_upgrade_links select _id) select _upgrade_current;
						_link_needed = false;
						if (count _links > 0) then {
							if (typeName (_links select 0) == "ARRAY") then {
								_count = count(_links);
								for '_i' from 0 to _count-1 do {
									_clink = _links select _i;
									_linkto = _upgrades select (_clink select 0);
									if (_linkto < (_clink select 1)) exitWith {_link_needed = true};
								};
							} else {
								_linkto = _upgrades select (_links select 0);
								if (_linkto < (_links select 1)) exitWith {_link_needed = true};
							};
						};
						if !(_link_needed) then {
							//--- cmdcon42 BUG-7 FIX (Ray 2026-07-02, "factory upgrade timer keeps resetting"): the cmdcon41-w2
							//--- #125 anti-forge fold rewrote Server\PVFunctions\RequestUpgrade.sqf to a 6-element contract
							//--- ([side,id,level,isplayer,requester,requestTeam] + full server-side validation AND server-side
							//--- payment) but this sender was never updated - it still sent the legacy 4-element payload, so the
							//--- server REJECTED every direct commander upgrade ("rejected short payload"; the WARNING is level-0
							//--- and suppressed by WFBE_LogLevel, hence the silent RPT). Meanwhile this branch had already
							//--- (a) deducted player funds + side supply CLIENT-side and (b) force-broadcast wfbe_upgrading=true,
							//--- which NOTHING ever cleared (only Server_ProcessUpgrade clears it, and it never ran) -> the
							//--- countdown spawn's recompute branch re-armed a full timer every time it expired = the endless
							//--- "timer keeps resetting" + the stuck flag also blocked the upgrade QUEUE worker + resources were
							//--- charged for nothing on every attempt. Fix, matching the #125 server contract exactly:
							//---   1) send the 6-element payload (player/group player = the requester binding the server checks);
							//---   2) NO client-side deduction - RequestUpgrade.sqf:148-151 charges supply + commander-team funds
							//---      authoritatively after every acceptance gate (keeping the client deduction would DOUBLE-charge);
							//---   3) NO optimistic wfbe_upgrading broadcast - the server sets wfbe_upgrading/wfbe_upgrading_id
							//---      (broadcast) on acceptance, so a rejected request can never wedge the side again.
							//--- The funds/supply/link pre-checks above stay: instant UX feedback, server re-validates anyway.
							["RequestUpgrade", [WFBE_Client_SideJoined, _id, _upgrade_current, true, player, group player]] call WFBE_CO_FNC_SendToServer;
							// Marty: Store a local end time so closing and reopening the menu does not reset the displayed countdown.
							//--- (cmdcon42: these seeds are inert until the SERVER flips wfbe_upgrading true - the countdown
							//--- spawn's idle branch clears them - so they are safe to keep for the accepted-request case.)
							_upgrade_time = (_upgrade_times select _id) select _upgrade_current;
							WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_id", _id, false];
							WFBE_Client_Logic setVariable ["wfbe_upgrading_countdown_end_time", time + _upgrade_time, false];
							//todo spawn local upgrade thread & timer & hint
							//--- Pure client, spawn an upgrade thread, which is local to the client in case the client tickrate is above the server tickrate.
							if !(isServer) then {
								[_id, _upgrade_current, _upgrade_time] spawn {
									sleep (_this select 2);
									["RequestSpecial", ["upgrade-sync", WFBE_Client_SideJoined, _this select 0, _this select 1]] Call WFBE_CO_FNC_SendToServer;
								};
							};
							hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Upgrading <t color='#B6F563'>%1</t> to level <t color='#F5D363'>%2</t></t>",_upgrade_labels select _id,_upgrade_current + 1]);
						} else {
							hint parseText("<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>One or more <t color='#F56363'>dependencies</t> are needed in order to process this upgrade.");
						};
					} else {
						hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t> There is not enough resources to process this upgrade (<t color='#F56363'>Funds</t> or <t color='#F56363'>Supply</t>)</t>",_upgrade_labels select _id,_upgrade_current]);
					};
				} else {
					hint parseText("<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>The upgrade has reached it's <t color='#76F563'>maximum level</t></t>");
				};
			} else {
				// Marty: Name the running upgrade when another purchase is attempted.
				_running_id = WFBE_Client_Logic getVariable "wfbe_upgrading_id";
				if (isNil "_running_id") then {_running_id = -1};
				_running_label = if (_running_id >= 0 && _running_id < count _upgrade_labels) then {_upgrade_labels select _running_id} else {"An upgrade"};
				hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t><t color='#B6F563'>%1</t> is already running</t>", _running_label]);
			};
		};
	};

	if (_queue_add) then {
		_queue_add = false;
		_ui_lnb_sel = lnbCurSelRow(504001);
		if (_ui_lnb_sel != -1) then {
			_id = lnbValue[504001, [_ui_lnb_sel, 0]];
			_queue = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
			if (isNil "_queue") then {_queue = []};
			_upgrade_current = _upgrades select _id;
			//--- Stacking: each click queues one more level until done + pending covers the max.
			_qtotal = {_x == _id} count _queue;
			if ((WFBE_Client_Logic getVariable ["wfbe_upgrading", false]) && {(WFBE_Client_Logic getVariable "wfbe_upgrading_id") == _id}) then {_qtotal = _qtotal + 1};
			if (_upgrade_current + _qtotal < (_upgrade_levels select _id)) then {
				["RequestEnqueue", [WFBE_Client_SideJoined, _id]] call WFBE_CO_FNC_SendToServer;
				hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Queued <t color='#B6F563'>%1</t> level <t color='#F5D363'>%2</t></t>", _upgrade_labels select _id, _upgrade_current + _qtotal + 1]);
			} else {
				hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Every remaining level of <t color='#F5D363'>%1</t> is already running, queued or maxed</t>", _upgrade_labels select _id]);
		};
			};
		};

	if (_queue_remove) then {
		_queue_remove = false;
		_ui_lnb_sel = lnbCurSelRow(504001);
		if (_ui_lnb_sel != -1) then {
			_id = lnbValue[504001, [_ui_lnb_sel, 0]];
			_queue = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
			if (isNil "_queue") then {_queue = []};
			if (({_x == _id} count _queue) > 0) then {
				["RequestDequeue", [WFBE_Client_SideJoined, _id]] call WFBE_CO_FNC_SendToServer;
				hint parseText(Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Removed the last queued level of <t color='#F5D363'>%1</t></t>", _upgrade_labels select _id]);
			};
		};
	};

	// Marty: Refresh the running-upgrade status when either the state, active upgrade ID, or queue changes.
	// Ownership: the footer owns 504006 ONLY when not upgrading; the countdown spawn owns it while running.
	_running_id = WFBE_Client_Logic getVariable "wfbe_upgrading_id";
	if (isNil "_running_id") then {_running_id = -1};
	_qlist = WFBE_Client_Logic getVariable "wfbe_upgrade_queue";
	if (isNil "_qlist") then {_qlist = []};
	if ((_upgrade_isupgrading && !(WFBE_Client_Logic getVariable ["wfbe_upgrading", false])) || (!_upgrade_isupgrading && (WFBE_Client_Logic getVariable ["wfbe_upgrading", false])) || (_upgrade_running_id != _running_id) || ((str _qlist) != (str _queue_footer_old))) then {
		_upgrade_isupgrading = (WFBE_Client_Logic getVariable ["wfbe_upgrading", false]);
		_upgrade_running_id = _running_id;
		_running_label = if (_upgrade_running_id >= 0 && _upgrade_running_id < count _upgrade_labels) then {_upgrade_labels select _upgrade_running_id} else {"An upgrade"};
		_queue_footer_old = + _qlist;

		// Footer owns 504006 only when idle (countdown spawn owns it while running).
		if (!_upgrade_isupgrading) then {
			// Build queued list with cumulative ETAs.
			// activeRemaining = 0 (no active upgrade), so ETA for queue[k] is sum of durations[0..k].
			// effective level of queue[j] = (current level of that upgrade) + (count of same ID earlier in queue).
			Private ["_qhtml","_qk","_qId","_qLabel","_qEffLvl","_qPrevCount","_qDurSec","_qTimesArr","_qETA",
			         "_qM","_qS","_qSText","_qj","_qjId","_qAccum"];
			_qhtml = "";
			_qAccum = 0;
			for "_qk" from 0 to (count _qlist - 1) do {
				_qId = _qlist select _qk;
				_qLabel = if (_qId >= 0 && _qId < count _upgrade_labels) then {_upgrade_labels select _qId} else {"?"};
				// Count how many times this ID appears earlier in the queue.
				_qPrevCount = 0;
				for "_qj" from 0 to (_qk - 1) do {
					if ((_qlist select _qj) == _qId) then {_qPrevCount = _qPrevCount + 1};
				};
				// Effective level = current level + prior-in-queue count.
				_qEffLvl = if (_qId >= 0 && {_qId < count _upgrades}) then {(_upgrades select _qId) + _qPrevCount} else {_qPrevCount};
				// Duration at effective level (clamped to times array; out-of-bounds = maxed = skip).
				_qDurSec = -1;
				if (_qId >= 0 && _qId < count _upgrade_times) then {
					_qTimesArr = _upgrade_times select _qId;
					if (_qEffLvl >= 0 && _qEffLvl < count _qTimesArr) then {
						_qDurSec = _qTimesArr select _qEffLvl;
					};
				};
				_qAccum = _qAccum + (if (_qDurSec >= 0) then {_qDurSec} else {0});
				if (_qDurSec >= 0) then {
					_qM = floor (_qAccum / 60);
					_qS = _qAccum - (_qM * 60);
					_qSText = if (_qS < 10) then {Format["0%1", _qS]} else {str _qS};
					_qhtml = _qhtml + (if (_qhtml == "") then {""} else {", "}) + Format ["%1 (%2:%3)", _qLabel, _qM, _qSText];
				} else {
					_qhtml = _qhtml + (if (_qhtml == "") then {""} else {", "}) + _qLabel;
				};
			};
			_html = "";
			if (count _qlist > 0) then {_html = Format["<t>Queued: <t color='#F5D363'>%1</t></t>", _qhtml]};
			((uiNamespace getVariable "wfbe_display_upgrades") displayCtrl 504006) ctrlSetStructuredText (parseText _html);
		};
	};
	
	//--- Go back to the main menu.
	if (WFBE_MenuAction == 1000) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
	
	sleep .01;
};

uiNamespace setVariable ["wfbe_display_upgrades", nil];
