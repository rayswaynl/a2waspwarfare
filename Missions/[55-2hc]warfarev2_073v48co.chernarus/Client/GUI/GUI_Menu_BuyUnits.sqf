disableSerialization;

//--- Init.
MenuAction = -1;

_listUnits = [];

_closest = objNull;
_commander = true;
_extracrew = true;
_countAlive = 0;
_currentCost = 0;
_currentIDC = 0;
_disabledColor = [0.7961, 0.8000, 0.7961, 1];
_display = _this select 0;
_enabledColor = [0, 1, 0, 1];
_enabledColor2 = [1, 0, 0, 1]; //---NEW (LOCK)
_gunner = true;
_IDCLock = 12023;
_IDCS = [12005,12006,12007,12008,12020,12021];
_IDCSVehi = [12012,12013,12014,12041];
_isInfantry = false;
_isLocked = true;
_lastCheck = 0;
_lastSel = -1;
_lastType = 'nil';
_listBox = 12001;
_comboFaction = 12026;
_map = _display displayCtrl 12015;
_sorted = [];
_type = 'nil';
_update = true;
_updateDetails = true;
_updateList = true;
_updateMap = true;
_val = 0;
//--- B74.2: per-player AI cap now follows the live pop-tier (WFBE_PopTier is publicVariable'd, read live on the client).
_mbu = missionNamespace getVariable 'WFBE_C_PLAYERS_AI_MAX'; //--- fallback scalar if the tiered array is unset
_mbuByTier = missionNamespace getVariable 'WFBE_C_PLAYERS_AI_MAX_BY_TIER';
if (!isNil '_mbuByTier') then {
	_mbuPT = missionNamespace getVariable ['WFBE_PopTier', 0]; if (_mbuPT < 0) then {_mbuPT = 0};
	if (_mbuPT <= ((count _mbuByTier) - 1)) then {_mbu = _mbuByTier select _mbuPT};
};
//--- Patrols upgrade trades 1 max AI per player for the side's autonomous patrols.
if (count ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) > WFBE_UP_PATROLS && {(((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_PATROLS) > 0}) then {_mbu = (_mbu - 1) max 1};

if (isNil {profileNamespace getVariable "wfbe_c_driver_enabled_by_default"}) then {
	profileNamespace setVariable ["wfbe_c_driver_enabled_by_default", true];
	profileNamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true];
};
_driverEnabledByDefault = profileNamespace getVariable "wfbe_c_driver_enabled_by_default";


ctrlSetText[12025,localize 'STR_WF_UNITS_FactionChoiceLabel' + ":"]; // changed-MrNiceGuy

//--- Get the closest Factory Type in range.
_break = false;
_status = [barracksInRange,lightInRange,heavyInRange,aircraftInRange,depotInRange,hangarInRange];
_statusLabel = ['Barracks','Light','Heavy','Aircraft','Depot','Airport'];
_statusVals = [0,1,2,3,4,3];
for [{_i = 0},{(_i < 6) && !_break},{_i = _i + 1}] do {
	if (_status select _i) then {
		_break = true;
		_currentIDC = _IDCS select _i;
		_type = _statusLabel select _i;
		_val = _statusVals select _i;
	};
};

if (sideJoined == resistance && _type == 'nil') then { _type = 'Depot'; _val = 4; _currentIDC = 12020 }; //--- GUER: base-less, force Depot pool (WFBE_GUERDEPOTUNITS)
if (_type == 'nil') exitWith {closeDialog 0};

//--- Destroy local variables.
_break = nil;
_status = nil;
_statusLabel = nil;
_statusVals = nil;

//--- Enable the current IDC.
_IDCS = _IDCS - [_currentIDC];
{
	_con = _display DisplayCtrl _x;
	_con ctrlSetTextColor [0.4, 0.4, 0.4, 1];
} forEach _IDCS;

//--- Loop.
//--- QoL: cache the factory-tab base labels so we can append live queue counts without losing them.
	private ["_tabIDC","_tabKey","_tabBase","_tabLast","_tabI"];
	_tabIDC = [12005,12006,12007,12008,12020,12021];
	_tabKey = ["Barracks","Light","Heavy","Aircraft","Depot","Airport"];
	_tabBase = [];
	{_tabBase set [count _tabBase, ctrlText (_display displayCtrl _x)]} forEach _tabIDC;
	_tabLast = ["","","","","",""];

	while {alive player && dialog} do {
	//--- Nothing in range? exit!.
	if (sideJoined != resistance && !barracksInRange && !lightInRange && !heavyInRange && !aircraftInRange && !hangarInRange && !depotInRange) exitWith {closeDialog 0};
	if (side group player != sideJoined || !dialog) exitWith {closeDialog 0};
	
	//--- Purchase.
	if (MenuAction == 1) then {
		MenuAction = -1;
		_currentRow = lnbCurSelRow _listBox;
		_currentValue = lnbValue[_listBox,[_currentRow,0]];
		_unit = _listUnits select _currentValue;
		_currentUnit = missionNamespace getVariable _unit;
		//--- fable/fix-unit-purchase-nil-guards: guard nil _currentUnit (unregistered classname) before the select-chain below - matches a55605e10/#1003 shape. Nil = skip the whole purchase (no charge, no spawn).
		if !(isNil "_currentUnit") then {
		_currentCost = round (((_currentUnit select QUERYUNITPRICE) * ATTACK_WAVE_PRICE_MODIFIER) * UNIT_COST_MODIFIER);
		_baseHullCost = _currentCost;
		_cpt = 1;
		_isInfantry = if (_unit isKindOf 'Man') then {true} else {false};
		if !(_isInfantry) then {
			_extra = 0;
			if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
			if (_gunner) then {_extra = _extra + 1};
			if (_commander) then {_extra = _extra + 1};
			if (_extracrew) then {_extra = _extra + ((_currentUnit select QUERYUNITCREW) select 3)};
			//--- P5 crew-cost tier-scale (fable/crew-cost-tierscale, owner economy pick GR-2026-07-08a): crew-replacement
			//--- cost now scales with the crewed vehicle's own buy-price, reusing the same QUERYUNITPRICE lookup the
			//--- _currentCost formula above already reads off _currentUnit - no new vehicle-cost table needed. The flat
			//--- WFBE_C_UNITS_CREW_COST stays the floor; the tier bonus only adds on top and is capped (TIERSCALE_CAP)
			//--- so even the priciest air/armor never gets punitive. Flag-off (TIERSCALE=0, default) = byte-identical
			//--- flat WFBE_C_UNITS_CREW_COST per head (see also the two analogous charge points below in this file).
			_crewCostPerHead = missionNamespace getVariable "WFBE_C_UNITS_CREW_COST";
			if ((missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE", 0]) > 0) then {
				_crewCostPerHead = (_crewCostPerHead + ((_currentUnit select QUERYUNITPRICE) * (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_COEF", 0.03]))) min (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_CAP", 400]);
			};
			_currentCost = _currentCost + (_crewCostPerHead * _extra);
		};
		if ((_currentRow) != -1) then {
			_funds = Call GetPlayerFunds;
			_skip = false;

			Private ["_currentUnitLabelForFundsMissing"];
            _currentUnitLabelForFundsMissing = _currentUnit select QUERYUNITLABEL;

			if (_funds < _currentCost) then {_skip = true;hint parseText(Format[localize 'STR_WF_INFO_Funds_Missing',_currentCost - _funds,_currentUnitLabelForFundsMissing])};
			//--- GUER DEPOT SPAWN FIX (fable/guer-vehicle-spawn 2026-07-03): a Depot buy whose depot logic did not resolve
			//--- (_closest == objNull) was still CHARGED here and spawned to Client_BuildUnit with _building = objNull, which
			//--- takes the top-scope `isNull _building` exit (Client_BuildUnit.sqf:314) -> silent refund, NOTHING spawns and
			//--- NO player feedback + NO always-on RPT line. That is the 'GUER buys a car, nothing appears' report: GUER is
			//--- base-less and buys EVERYTHING from the town-center depot (line 68 forces _type='Depot'), so a stale/unresolved
			//--- _closest (walked out of WFBE_C_TOWNS_PURCHASE_RANGE, or standing at a WEST/EAST-held town = deny-cap) hits this
			//--- every time. Refuse UP FRONT (before charging), tell the player why, and log one always-on WARNING breadcrumb so
			//--- the next 'still broken' report has evidence. WEST/EAST are unaffected: they buy vehicles at FACTORIES (a real
			//--- _building), never reaching a null-depot buy - and the guard is Depot-scoped.
			if (!_skip && {_type == 'Depot'} && {isNull _closest}) then {
				_skip = true;
				hint parseText "<t color='#ff9060'>No friendly town center in range. GUER buys vehicles at a town center you hold or that is neutral (not held by BLUFOR/OPFOR) - move to one and try again.</t>";
				//--- depot-buy-round3 (diagnostic, ALWAYS-ON): PR #654 logged this refusal ONLY via WFBE_CO_FNC_LogContent,
				//--- which is compiled out on release player clients (WF_LOG_CONTENT undefined; only HCs force it on), so the
				//--- up-front null-depot refusal never reached ANY RPT - a whole night of failed buys logged nothing. This
				//--- plain diag_log makes the refusal observable in the buyer's OWN client RPT (BUYTRACE-tagged, one line).
				diag_log Format ["BUYTRACE|v1|depot-refused|side=%1|class=%2|range=%3|reason=null-depot-in-range", sideJoinedText, _unit, (missionNamespace getVariable ["WFBE_C_TOWNS_PURCHASE_RANGE", 60])];
				["WARNING", Format ["GUI_Menu_BuyUnits.sqf: DEPOT buy of [%1] refused up-front - no depot resolved in range %2 (side=%3). Buy NOT charged (prevents the silent charge-then-refund).", _unit, (missionNamespace getVariable ["WFBE_C_TOWNS_PURCHASE_RANGE", 60]), sideJoinedText]] Call WFBE_CO_FNC_LogContent;
			};
			//--- Bought SCUD preflight: refuse at the live cap, and require an empty Heavy Factory queue so the
			//--- server-issued proof's bounded build window covers the exact purchase being certified. The server
			//--- independently rechecks factory ownership/type/range, cap, build time, class, team, side, and funds.
			if (!_skip && {(missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0} && {worldName == "Takistan" || {(missionNamespace getVariable ["WFBE_C_SCUD_DRIVABLE_ALLMAPS", 1]) > 0}} && {_unit == (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])}) then {
				private ["_scudArr","_scudLive","_scudMax","_scudQueue"];
				_scudArr = missionNamespace getVariable [format ["WFBE_TK_SCUD_PLATFORMS_%1", str sideJoined], []];
				_scudLive = 0;
				if (typeName _scudArr == "ARRAY") then {
					{ if (!isNull _x && {alive _x}) then {_scudLive = _scudLive + 1} } forEach _scudArr;
				};
				_scudMax = missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_MAX", 2];
				//--- owner refinement 2026-07-08 (fable/scud-chernarus-artillery): one-per-side clamp. Does NOT touch WFBE_C_TK_SCUD_HF_MAX's own default (2) - just caps the effective ceiling read here. Server-side WFBE_SE_FNC_TkScudRegister applies the identical clamp as the authority.
				if ((missionNamespace getVariable ["WFBE_C_SCUD_ONE_PER_SIDE", 1]) > 0) then {_scudMax = _scudMax min 1};
				if (_scudLive >= _scudMax) then {
					_skip = true;
					hint parseText (Format ["<t color='#ff5a5a'>SCUD refused: your side already fields %1 launchers (max %2).</t>", _scudLive, _scudMax]);
				};
				_scudQueue = if (isNull _closest) then {[]} else {_closest getVariable ["queu", []]};
				if (!_skip && {typeName _scudQueue == "ARRAY"} && {count _scudQueue > 0}) then {
					_skip = true;
					hint parseText "<t color='#ffb050'>SCUD requires an empty Heavy Factory queue. Let the current build finish, then order the launcher.</t>";
				};
			};
			if (!_skip && {_type == "Airport"} && {isNull _closest}) then {
				_skip = true;
				hint parseText "<t color='#ff9060'>No airport in range. Move closer to an airfield hangar and try again.</t>";
			};
			//--- AIRFIELD-OWNERSHIP GATE (fable/airfield-ownership-gate, GR-2026-07-06a):
			//--- Block aircraft purchase at an airfield the buyer's side does not hold.
			//--- Ownership: WFBE_CO_FNC_GetAirfieldOwnerSideID finds the nearest entry in the towns
			//--- array (which includes the airfield depot logic with wfbe_is_airfield=true) and reads
			//--- its sideID. sideID -1 means no town in radius -> treat as neutral -> ALLOWED.
			//--- Only ENEMY-owned airfields are denied; own/neutral = allowed. Players only; AI uses
			//--- Server_BuyUnit directly (WFBE_PVF_BuyUnit on the server, not this client gate).
			if (!_skip && {_type == "Airport"} && {(missionNamespace getVariable ["WFBE_C_AIRFIELD_OWNERSHIP_GATE", 0]) > 0}) then {
				private ["_afSideID","_afLastLog"];
				_afSideID = [_closest] Call WFBE_CO_FNC_GetAirfieldOwnerSideID;
				if !(_afSideID == sideID || {_afSideID == -1}) then {
					_skip = true;
					hint parseText "<t color='#ff9060'>Airfield not owned. Capture this airfield before buying aircraft here.</t>";
					_afLastLog = missionNamespace getVariable ["WFBE_AFGATE_LAST_LOG", -999];
					if ((diag_tickTime - _afLastLog) > 30) then {
						diag_log Format ["BUYTRACE|v2|af-gate-denied|side=%1|class=%2|afSideID=%3|afLogic=%4", sideJoinedText, _unit, _afSideID, _closest];
						missionNamespace setVariable ["WFBE_AFGATE_LAST_LOG", diag_tickTime];
					};
				};
			};
			//--- Make sure that we own all camps before being able to purchase infantry.
			if (_type == "Depot" && _isInfantry && sideJoined != resistance) then {
				_totalCamps = _closest Call GetTotalCamps;
				_campsSide = [_closest,sideJoined] Call GetTotalCampsOnSide;
				if (_totalCamps != _campsSide) then {_skip = true; hint parseText(localize 'STR_WF_INFO_Camps_Purchase')};
			};
			if !(_skip) then {
				_size = Count ((Units (group player)) Call GetLiveUnits);
				//--- Get the infantry limit based off the infantry upgrade.
				//--- B750 (Ray 2026-06-24): RESTORE the infantry squad-cap regression. round(_mbu/4) gave only 4 at barracks
				//--- lvl 0 once _mbu (GroupSizePlayer) was pop-tiered down to 16 -> player capped at 4 AI ("max 4/10, can't
				//--- build more"). Intent: START at 10 (lvl 0) and rise +2 per barracks level, clamped to the param (_mbu).
				//--- The per-FACTORY QUEUE rate-caps (WFBE_C_QUEUE_*_MAX = barracks 10 / light 5 / heavy-air 3, below) are separate.
				_realSize = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
				_realSize = (10 + (_realSize * 2)) min _mbu;
						if (!isNull(commanderTeam)) then {
			  if (commanderTeam == group player) then {
              _realSize = _realSize + 10;
			  
              };
			};
				//--- B75 (guer-tech): GUER barracks AI cap scales with cumulative GUER player kills, not the (always-0)
				//--- Barracks production upgrade. GUER is base-less/commander-less so the upgrade switch above always hits
				//--- case 0 (round mbu/4). Override here: base + one slot per N kills, clamped to the A2 12-per-group ceiling.
				//--- Reads the server-broadcast WFBE_GUER_PLAYER_KILLS (RequestOnUnitKilled.sqf). Placed AFTER the upgrade
				//--- switch + commander bonus so the kill-scaled value wins for resistance.
				if (sideJoined == resistance) then {
					private ["_guerKills","_guerCap"];
					_guerKills = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
					_guerCap = (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_BASE", 4]) + floor (_guerKills / (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_PER_KILLS", 10]));
					_realSize = _guerCap min (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_MAX", 12]);
				};
				if (_isInfantry) then {if ((unitQueu + _size + 1) > _realSize) then {_skip = true;hint parseText(Format [localize 'STR_WF_INFO_MaxGroup',_realSize])}};

				if (!_isInfantry && !_skip) then {
					_cpt = 0;
					if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_cpt = _cpt + 1};
					if (_gunner) then {_cpt = _cpt + 1};
					if (_commander) then {_cpt = _cpt + 1};
					if (_extracrew) then {_cpt = _cpt + ((_currentUnit select QUERYUNITCREW) select 3)};
					if ((unitQueu + _size + _cpt) > _realSize && _cpt != 0) then {_skip = true;hint parseText(Format [localize 'STR_WF_INFO_MaxGroup',_realSize])};
				};
			};
			if !(_skip) then {
				//--- Check the max queu.
				//--- Depot 4/4 hard-cap (claude/depot-queue-cap): the legacy gate keys ONLY on the per-CLIENT
				//--- counter WFBE_C_QUEUE_<type> (missionNamespace = per machine). The number the player SEES as
				//--- "N/CAP" (and the FIFO the units really build from) is the per-BUILDING PUBLIC "queu" array that
				//--- every co-op player's Client_BuildUnit appends to. On GUER's base-less town depots - shared by
				//--- several resistance players - each client stayed within its own 4 budget while the shared "queu"
				//--- ran past it, so the readout showed "5/4"/"6/4" and a T-34 + infantry built at the same time.
				//--- For DEPOT, additionally require the LIVE shared queue to have room so CAP is a true ceiling
				//--- (isNull guard => treat as empty). This can only ever be MORE restrictive; base factories are
				//--- left untouched EXCEPT when only one live factory of the type remains (fable/ew-economy:
				//--- _countAlive == 1, set/refreshed by the switch(_type) block above) - with a single instance,
				//--- that building's queu array IS the side's whole per-type queue, so the same true-ceiling gate
				//--- applies safely. The orphan-reaper in the display loop below keeps this
				//--- shared-queue gate from ever soft-locking a depot (or single-factory type) whose head was orphaned by a disconnect.
				private ["_depotQueueBlocked"];
				_depotQueueBlocked = false;
				if ((_type == "Depot" || _countAlive == 1) && {!isNull _closest}) then {
					if ((count (_closest getVariable ["queu", []])) >= (missionNamespace getVariable Format["WFBE_C_QUEUE_%1_MAX",_type])) then {
						_depotQueueBlocked = true;
						if (WF_Debug) then {["INFORMATION", Format ["GUI_Menu_BuyUnits.sqf: DEPOT buy blocked - shared queue full (%1/%2).", count (_closest getVariable ["queu", []]), missionNamespace getVariable Format["WFBE_C_QUEUE_%1_MAX",_type]]] Call WFBE_CO_FNC_LogContent};
					};
				};
				if (((missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_type]) < (missionNamespace getVariable Format["WFBE_C_QUEUE_%1_MAX",_type])) && {!_depotQueueBlocked}) then {
					missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_type],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_type])+1];
					Private ["_currentUnitLabel"];
                    _currentUnitLabel = _currentUnit select QUERYUNITLABEL;

					_queu = _closest getVariable 'queu';
					_txt = parseText(Format [localize 'STR_WF_INFO_BuyEffective',_currentUnitLabel]);
					if (!isNil '_queu') then {if (count _queu > 0) then {_txt = parseText(Format [localize 'STR_WF_INFO_Queu',_currentUnitLabel])}};
					hint _txt;
					_isScudPurchase = ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0 && {worldName == "Takistan" || {(missionNamespace getVariable ["WFBE_C_SCUD_DRIVABLE_ALLMAPS", 1]) > 0}} && {_unit == (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])});
					_clientPaidCost = _currentCost;
					if (_isScudPurchase) then {_clientPaidCost = (_currentCost - _baseHullCost) max 0};
					_params = if (_isInfantry) then {[_closest,_unit,[],_type,_cpt,_clientPaidCost]} else {[_closest,_unit,[profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ,_gunner,_commander,_extracrew,_isLocked],_type,_cpt,_clientPaidCost]};
					//--- depot-buy-round3 (diagnostic, ALWAYS-ON): charge-time trace. Pairs with the spawn-position
					//--- BUYTRACE in Client_BuildUnit so the next failed buy's client RPT pinpoints where the flow died.
					diag_log Format ["BUYTRACE|v1|charge|side=%1|factory=%2|class=%3|cost=%4|cpt=%5|depot=%6|depotNull=%7", sideJoinedText, _type, _unit, _currentCost, _cpt, _closest, isNull _closest];
					if (_isScudPurchase) then {
						[_params, _closest, _unit, sideJoined, group player, _clientPaidCost] Spawn WFBE_CO_FNC_RequestIcbmTelPurchase;
					} else {
						_params Spawn BuildUnit;
						-(_currentCost) Call ChangePlayerFunds;
					};
					//--- QoL trio feat.3: stamp last-purchase time for advisor nudge.
					if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) > 0) then {
						WFBE_QOL_LAST_PURCHASE_TIME = time;
					};
					_updateDetails = true; //--- Task 33: refresh queue list panel after purchase.
				} else {
					private ["_queueCap","_queueCount"];
					_queueCap = missionNamespace getVariable [Format["WFBE_C_QUEUE_%1_MAX",_type], 0];
					_queueCount = missionNamespace getVariable [Format["WFBE_C_QUEUE_%1",_type], 0];
					if (_depotQueueBlocked && {!isNull _closest}) then {
						_queueCount = count (_closest getVariable ["queu", []]);
					};
					hintSilent parseText ((Format [localize 'STR_WF_INFO_Queu_Max',_queueCap]) + Format [" (%1/%2)", _queueCount, _queueCap]);
				};
			};
		};
		} else {
			["WARNING", Format ["GUI_Menu_BuyUnits.sqf: purchase classname [%1] not registered in missionNamespace; skipping buy (nil-poison guard, matches a55605e10/#1003).", _unit]] Call WFBE_CO_FNC_LogContent;
		};
	};
	
	//--- Tabs selection.
	if (MenuAction == 101) then {MenuAction = -1;if (barracksInRange) then {_currentIDC = 12005;_type = 'Barracks';_val = 0;_update = true}};
	if (MenuAction == 102) then {MenuAction = -1;if (lightInRange) then {_currentIDC = 12006;_type = 'Light';_val = 1;_update = true}};
	if (MenuAction == 103) then {MenuAction = -1;if (heavyInRange) then {_currentIDC = 12007;_type = 'Heavy';_val = 2;_update = true}};
	if (MenuAction == 104) then {MenuAction = -1;if (aircraftInRange) then {_currentIDC = 12008;_type = 'Aircraft';_val = 3;_update = true}};
	if (MenuAction == 105) then {MenuAction = -1;if (depotInRange) then {_currentIDC = 12020;_type = 'Depot';_val = 4;_update = true}};
	if (MenuAction == 106) then {MenuAction = -1;if (hangarInRange) then {_currentIDC = 12021;_type = 'Airport';_val = 3;_update = true}};
	
	//--- driver-gunner-commander icons.
	if (MenuAction == 201) then {
		MenuAction = -1;
		_driverEnabledByDefault = !(profileNamespace getVariable "wfbe_c_driver_enabled_by_default");
		profileNamespace setVariable ["wfbe_c_driver_enabled_by_default", _driverEnabledByDefault];
		profileNamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", _driverEnabledByDefault];
		_updateDetails = true;
	};
	if (MenuAction == 202) then {MenuAction = -1;_gunner = if (_gunner) then {false} else {true};_updateDetails = true};
	if (MenuAction == 203) then {MenuAction = -1;_commander = if (_commander) then {false} else {true};_updateDetails = true};
	if (MenuAction == 204) then {MenuAction = -1;_extracrew = if (_extracrew) then {false} else {true};_updateDetails = true};

	//--- Factory DropDown list value has changed.
	// Marty: Guard against the no-range state - the cleared combo can still fire onLBSelChanged
	// (MenuAction 301) with lbCurSel -1 or a stale index; indexing _sorted then recreates the
	// RPT error the empty-range dropdown guard removed. Only select with a valid live entry.
	if (MenuAction == 301) then {MenuAction = -1;_factSel = lbCurSel 12018;if (_factSel >= 0 && {_factSel < count _sorted} && {!(isNull (_sorted select _factSel))}) then {_closest = _sorted select _factSel;_updateMap = true} else {_closest = objNull}};
	
	//--- Selection change, we update the details.
	if (MenuAction == 302) then {MenuAction = -1;_updateDetails = true};
	
	//--- Faction Filter changed.
	if (MenuAction == 303) then {MenuAction = -1;_update = true;missionNamespace setVariable [Format["WFBE_%1%2CURRENTFACTIONSELECTED",sideJoinedText,_type],(lbCurSel _comboFaction)]};
	
	//--- Lock icon.
	if (MenuAction == 401) then {MenuAction = -1;_isLocked = if (_isLocked) then {false} else {true};_updateDetails = true};

	//--- Task 33: cancel last queued order for this player in the current factory.
	if (MenuAction == 501) then {
		MenuAction = -1;
		private ["_uid33","_q33","_qc33","_qp33","_ql33","_idx33","_paidCost33","_cpt33","_basePrice33","_refund33","_maxRefund33","_newArr33","_i33","_uidPrefix33"];
		if (isNull _closest) exitWith {hint parseText "<t color='#ff9900'>No factory is selected for queue cancellation.</t>"};
		_uid33 = getPlayerUID player;
		//--- A2-safe "token starts with UID" test. `string find string` is ARMA 3-only and
		//--- throws "Type String, expected Array" on A2 OA; compare leading bytes via toArray.
		_uidPrefix33 = {
			private ["_tokA","_uidA","_ul","_ok","_j"];
			_tokA = toArray (_this select 0);
			_uidA = toArray (_this select 1);
			_ul = count _uidA;
			_ok = (_ul > 0) && (_ul <= count _tokA);
			if (_ok) then {
				for "_j" from 0 to (_ul - 1) do {
					if ((_tokA select _j) != (_uidA select _j)) exitWith {_ok = false};
				};
			};
			_ok
		};
		_q33   = _closest getVariable ["queu",        []];
		_qc33  = _closest getVariable ["queu_costs",  []];
		_qp33  = _closest getVariable ["queu_cpts",   []];
		_ql33  = _closest getVariable ["queu_labels",  []];
		if (typeName _q33 != "ARRAY" || {typeName _qc33 != "ARRAY"} || {typeName _qp33 != "ARRAY"} || {typeName _ql33 != "ARRAY"}) exitWith {hint parseText "<t color='#ff9900'>Queue data is unavailable. No order was cancelled.</t>"};
		if (count _q33 == 0) exitWith {hint parseText "<t color='#ff9900'>You have no unit queued in this factory.</t>"};
		if ((count _q33) != (count _qc33) || {(count _q33) != (count _qp33)} || {(count _q33) != (count _ql33)}) exitWith {hint parseText "<t color='#ff9900'>Queue data is incomplete. No order was cancelled.</t>"};
		//--- Find the LAST entry belonging to this player.
		_idx33 = -1;
		{if (!isNil "_x") then {if (typeName _x == "STRING") then {if ([_x, _uid33] call _uidPrefix33) then {_idx33 = _forEachIndex}}}} forEach _q33;
		if (_idx33 == -1) exitWith {hint parseText "<t color='#ff9900'>You have no unit queued in this factory.</t>"};
		_paidCost33 = _qc33 select _idx33;
		_cpt33      = _qp33 select _idx33;
		if (typeName _paidCost33 != "SCALAR" || {typeName _cpt33 != "SCALAR"}) exitWith {hint parseText "<t color='#ff9900'>Queue data is invalid. No order was cancelled.</t>"};
		_refund33   = _paidCost33;
		if (ATTACK_WAVE_PRICE_MODIFIER < 1.0 && UNIT_COST_MODIFIER > 0) then {
			_basePrice33 = _paidCost33 / (ATTACK_WAVE_PRICE_MODIFIER * UNIT_COST_MODIFIER);
			_maxRefund33 = round (_basePrice33 * 0.5);
			if (_refund33 > _maxRefund33) then {_refund33 = _maxRefund33};
		};
		//--- Remove exactly one entry by index from every parallel queue array. Value-based subtraction would remove every equal token.
		_newArr33 = []; _i33 = 0; {if (_i33 != _idx33) then {_newArr33 = _newArr33 + [_x]}; _i33 = _i33 + 1} forEach _q33; _q33 = _newArr33;
		_newArr33 = []; _i33 = 0; {if (_i33 != _idx33) then {_newArr33 = _newArr33 + [_x]}; _i33 = _i33 + 1} forEach _qc33; _qc33 = _newArr33;
		_newArr33 = []; _i33 = 0; {if (_i33 != _idx33) then {_newArr33 = _newArr33 + [_x]}; _i33 = _i33 + 1} forEach _qp33; _qp33 = _newArr33;
		_newArr33 = []; _i33 = 0; {if (_i33 != _idx33) then {_newArr33 = _newArr33 + [_x]}; _i33 = _i33 + 1} forEach _ql33; _ql33 = _newArr33;
		_closest setVariable ["queu",        _q33,  true];
		_closest setVariable ["queu_costs",  _qc33, true];
		_closest setVariable ["queu_cpts",   _qp33, true];
		_closest setVariable ["queu_labels", _ql33, true];
		//--- Decrement queue counters.
		unitQueu = (unitQueu - _cpt33) max 0;
		missionNamespace setVariable [
			Format ["WFBE_C_QUEUE_%1", _type],
			((missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1", _type], 0]) - 1) max 0
		];
		//--- Refund.
		if (_refund33 > 0) then {(_refund33) Call ChangePlayerFunds};
		hint parseText Format [
			"<t color='#00e83e'>Queue cancelled.</t><br/>Refunded: <t color='#ffe066'>$%1</t>%2",
			_refund33,
			if (_paidCost33 != _refund33) then {Format [" (capped from $%1 — attack-wave)", _paidCost33]} else {""}
		];
		_updateDetails = true;
	};
	
	//--- Player funds + QoL item1 live squad cap counter (client-qol-batch2).
	//--- Mirrors _realSize formula from the purchase guard; same vars already in scope.
	private ["_capSize","_capAlive","_capUsed"];
	_capSize = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
	_capSize = (10 + (_capSize * 2)) min _mbu;
	if (!isNull(commanderTeam) && {commanderTeam == group player}) then {_capSize = _capSize + 10};
	if (sideJoined == resistance) then {
		private ["_capGK","_capGC"];
		_capGK = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
		_capGC = (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_BASE", 4]) + floor (_capGK / (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_PER_KILLS", 10]));
		_capSize = _capGC min (missionNamespace getVariable ["WFBE_C_GUER_BARRACKS_AI_MAX", 12]);
	};
	_capAlive = count ((units (group player)) Call GetLiveUnits);
	_capUsed = unitQueu + _capAlive;
	ctrlSetText [12019, Format [localize 'STR_WF_UNITS_Cash', Call GetPlayerFunds] + "   Squad: " + str _capUsed + "/" + str _capSize];

	//--- WFBE_C_FACTORY_QUEUE_LIMITS=1: recompute per-factory caps from current upgrade levels each tick.
	//--- Formula: max(FLOOR, level+offset) — floors prevent early-game starvation.
	//--- Floors: Barracks=10, Light=5, Heavy=3, Aircraft/Airport=3 (aircraft floor tentative, pending owner sign-off).
	//--- Cross-ref: same formula used in the queue-display below (search "Queue: N/CAP").
	//--- When WFBE_C_FACTORY_QUEUE_LIMITS=0 the _MAX variables retain Init_Client.sqf static defaults.
	if ((missionNamespace getVariable ["WFBE_C_FACTORY_QUEUE_LIMITS",0]) > 0) then {
		private ["_upg"];
		_upg = sideJoined Call WFBE_CO_FNC_GetSideUpgrades;
		missionNamespace setVariable ["WFBE_C_QUEUE_BARRACKS_MAX", 10 max ((_upg select WFBE_UP_BARRACKS) + 2)];
		missionNamespace setVariable ["WFBE_C_QUEUE_LIGHT_MAX",     5 max ((_upg select WFBE_UP_LIGHT)    + 1)];
		missionNamespace setVariable ["WFBE_C_QUEUE_HEAVY_MAX",     3 max ((_upg select WFBE_UP_HEAVY)    + 1)];
		missionNamespace setVariable ["WFBE_C_QUEUE_AIRCRAFT_MAX",  3 max ((_upg select WFBE_UP_AIR)      + 1)];
		missionNamespace setVariable ["WFBE_C_QUEUE_AIRPORT_MAX",   3 max ((_upg select WFBE_UP_AIR)      + 1)];
	};

		//--- QoL: live queue count on factory tabs (change-detected to avoid per-tick UI churn).
		_tabI = 0;
		{
			private ["_q","_m","_txt"];
			_q = missionNamespace getVariable [format ["WFBE_C_QUEUE_%1", _tabKey select _tabI], -1];
			_m = missionNamespace getVariable [format ["WFBE_C_QUEUE_%1_MAX", _tabKey select _tabI], -1];
			_txt = _tabBase select _tabI;	//--- FIX: never append text to the tab control — it is an RscClickableText whose text is a .paa ICON path; appending "(q/max)" corrupted it to "con_barracks.paa (0/10)" (engine "picture not found", tab icons vanished, only Barracks visible). Queue total still shows in the header.
			if (_txt != (_tabLast select _tabI)) then {(_display displayCtrl _x) ctrlSetText _txt; _tabLast set [_tabI, _txt]};
			_tabI = _tabI + 1;
		} forEach _tabIDC;
	
	//--- Update tabs.
	if (_update) then {
		_listUnits = missionNamespace getVariable Format ['WFBE_%1%2UNITS',sideJoinedText,_type];

		[_comboFaction,_type] Call UIChangeComboBuyUnits;
		[_listUnits,_type,_listBox, (if (sideJoined == resistance) then {999} else {_val})] Call UIFillListBuyUnits; //--- GUER: bypass upgrade-gate (funds + time-tier, no upgrades)
		
		//--- Update tabs icons.
		_IDCS = [12005,12006,12007,12008,12020,12021];
		_IDCS = _IDCS - [_currentIDC];
		_con = _display DisplayCtrl _currentIDC;
		_con ctrlSetTextColor [1, 1, 1, 1];
		{_con = _display DisplayCtrl _x;_con ctrlSetTextColor [0.4, 0.4, 0.4, 1]} forEach _IDCS;
		
		_update = false;
		_updateList = true;
		_updateDetails = true;
	};
	
	//--- Update factories.
	if (_updateList) then {
		switch (_type) do {
			//--- Specials.
			case 'Depot': {
				_sorted = [[vehicle player, missionNamespace getVariable "WFBE_C_TOWNS_PURCHASE_RANGE"] Call WFBE_CL_FNC_GetClosestDepot];
				_closest = _sorted select 0;
			};
			case 'Airport': {
				_sorted = [[vehicle player, missionNamespace getVariable "WFBE_C_UNITS_PURCHASE_HANGAR_RANGE"] Call WFBE_CL_FNC_GetClosestAirport];
				_closest = _sorted select 0;
				//--- Task 12: If the nearest hangar is a captured airfield, show the exclusive roster instead of the faction airport list.
				if ((missionNamespace getVariable ["WFBE_C_AIRFIELDS", 0]) > 0 && !(isNull _closest) && {((_closest getVariable ["wfbe_hangar", objNull]) getVariable ["wfbe_is_airfield_hangar", false])}) then {
					_listUnits = if (sideJoined == resistance) then {missionNamespace getVariable ["WFBE_GUERAIRPORTUNITS", []]} else {missionNamespace getVariable ["WFBE_AIRFIELD_UNITS", []]}; //--- GUER: own air roster at held airfields

					//--- Per-airfield specials: augment generic list with any classes mapped to this airfield's town.
					//--- Resolve the airfield town name by finding the closest town to the airport logic object.
					private ["_airfTownObj","_airfTownName","_airfSpecials","_airfIdx","_airfEntry"];
					_airfTownObj  = [_closest, towns] Call WFBE_CO_FNC_GetClosestEntity;
					_airfTownName = if (isNull _airfTownObj) then {""} else {_airfTownObj getVariable ["name",""]};
					_airfSpecials = missionNamespace getVariable ["WFBE_AIRFIELD_UNITS_SPECIAL", []];
					_airfIdx = -1;
					{
						if ((_x select 0) == _airfTownName) exitWith { _airfIdx = _forEachIndex };
					} forEach _airfSpecials;
					if (_airfIdx >= 0) then {
						_airfEntry = _airfSpecials select _airfIdx;
						_listUnits = _listUnits + (_airfEntry select 1);
					};

					//--- fable/scud-showpiece: the SCUD showpiece carrier is HELI-ONLY - the twin launchers
					//--- + dressing occupy the fixed-wing deck run. Other carriers/airfields keep full lists.
					//--- Gate: flag on AND this hangar's town carries the SCUD pad ref (only the middle carrier does).
					if ((missionNamespace getVariable ["WFBE_C_NAVAL_SCUD_SHOWPIECE", 0]) > 0 && {!isNull _airfTownObj} && {!isNull (_airfTownObj getVariable ["wfbe_scud_pad_ref", objNull])}) then {
						private ["_heliOnly"];
						_heliOnly = [];
						{ if (_x isKindOf "Helicopter") then {_heliOnly = _heliOnly + [_x]} } forEach _listUnits;
						_listUnits = _heliOnly;
					};

					//--- Task 36 (live "empty airshop" fix): the roster is CROSS-FACTION
					//--- (Takistani/Insurgent classes) and deliberately airfield-gated, so two
					//--- standard filters must not apply here:
					//---  1. reset the saved faction filter to "All" or every row is dropped;
					//---  2. pass sentinel 999 as the upgrade index — the airfield capture IS
					//---     the unlock; UIFillListBuyUnits treats out-of-range as "no gate".
					missionNamespace setVariable [Format["WFBE_%1%2CURRENTFACTIONSELECTED",sideJoinedText,_type], 0];
					[_listUnits,_type,_listBox,999] Call UIFillListBuyUnits;
				};
			};
			//--- Factories
			default {
				_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
				_factories = [sideJoined,missionNamespace getVariable Format ['WFBE_%1%2TYPE',sideJoinedText,_type],_buildings] Call GetFactories;
				_sorted = [vehicle player,_factories] Call SortByDistance;
				_closest = _sorted select 0;
				_countAlive = count _factories;
			};
		};

		//--- Refresh the Factory DropDown list.
		lbClear 12018;
		if (count _sorted > 0 && {!(isNull (_sorted select 0))}) then {
			{
				_nearTown = ([_x, towns] Call WFBE_CO_FNC_GetClosestEntity) getVariable 'name';
				_txt = _type + ' ' + _nearTown + ' ' + str (round((vehicle player) distance _x)) + 'M';
				lbAdd[12018,_txt];
			} forEach _sorted;
			lbSetCurSel [12018,0];
		};
		
		_updateList = false;
		_updateMap = true;
	};
	
	//--- Depot orphan-reaper (claude/depot-queue-cap): the count(queu) buy-gate above must never SOFT-LOCK a
		//--- depot whose head token was orphaned - e.g. a buyer disconnected mid-build, so their Client_BuildUnit
		//--- loop died and never removed its token (and the client-side stuck-head purge is inert: WFBE_LONGEST
		//--- <Type>BUILDTIME is stored UPPERCASE but looked up mixed-case in Client_BuildUnit, so _longest is nil).
		//--- While ANY player has this buy menu open, drain a head that has sat unchanged longer than the depot's
		//--- longest build time + a generous 60s margin (so a legitimately-building head is NEVER reaped). Time-
		//--- based, removes at most one head per deadline, converges, and only ever REMOVES a genuine orphan.
		//--- wfbe_queu_head_seen is a LOCAL object var (each client times independently); the queu REMOVAL is
		//--- public. Depot, plus any other factory type currently down to its last live instance
		//--- (_countAlive == 1) - see the matching widening on the buy-gate above; factories with 2+
		//--- live instances keep their exact current behaviour (per-building queues aren't the whole picture there).
		if ((_type == "Depot" || _countAlive == 1) && {!isNull _closest}) then {
			private ["_rQueu","_rLongest","_rHead","_rSeen"];
			_rQueu = _closest getVariable ["queu", []];
			if (count _rQueu > 0) then {
				_rLongest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME", toUpper _type];
				if (isNil "_rLongest" || {_rLongest <= 0}) then {_rLongest = 60};
				_rHead = _rQueu select 0;
				_rSeen = _closest getVariable ["wfbe_queu_head_seen", ["", -1]];
				if (((_rSeen select 0) != _rHead) || {(_rSeen select 1) < 0}) then {
					//--- New/changed head => (re)start its stagnation timer.
					_closest setVariable ["wfbe_queu_head_seen", [_rHead, time]];
				} else {
					if ((time - (_rSeen select 1)) > (_rLongest + 60)) then {
						_rQueu = _closest getVariable ["queu", []];
						if ((count _rQueu > 0) && {(_rQueu select 0) == _rHead}) then {
							_rQueu = _rQueu - [_rHead];
							_closest setVariable ["queu", _rQueu, true];
							_closest setVariable ["wfbe_queu_head_seen", ["", -1]];
							["INFORMATION", Format ["GUI_Menu_BuyUnits.sqf: reaped orphaned DEPOT queue head after ~%1s stagnation (%2 order(s) left).", (_rLongest + 60), count _rQueu]] Call WFBE_CO_FNC_LogContent;
						};
					};
				};
			} else {
				//--- Empty queue => clear any stale marker so the next order starts a fresh timer.
				if (((_closest getVariable ["wfbe_queu_head_seen", ["", -1]]) select 1) >= 0) then {
					_closest setVariable ["wfbe_queu_head_seen", ["", -1]];
				};
			};
		};

		//--- Display Factory Queu.
	_queu = _closest getVariable "queu";
	_value = if (isNil '_queu') then {0} else {count (_closest getVariable "queu")};
	private ["_qCap","_qLabel"];
	_qCap = missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1_MAX",_type], -1];
	_qLabel = _display DisplayCtrl 12024;
	_qLabel ctrlSetTextColor [0.2588, 0.7137, 1, 0.9];
	//--- WFBE_C_FACTORY_QUEUE_LIMITS=1: append /CAP to the queue count so players can see the limit.
	//--- The color warning uses the current cap either way so cap-full state stays visible when /CAP text is disabled.
	if ((missionNamespace getVariable ["WFBE_C_FACTORY_QUEUE_LIMITS",0]) > 0 && {_qCap > 0}) then {
		ctrlSetText[12024,Format[localize 'STR_WF_UNITS_QueuedLabel', str _value + "/" + str _qCap]];
	} else {
		ctrlSetText[12024,Format[localize 'STR_WF_UNITS_QueuedLabel',str _value]];
	};
	if (_qCap > 0 && {_value >= _qCap}) then {
		_qLabel ctrlSetTextColor [1, 0.58, 0.05, 1];
	};
	
	//--- List selection changed.
	if (_updateDetails) then {
		_currentRow = lnbCurSelRow _listBox;
		//--- Our list is not empty.
		if (_currentRow != -1) then {
			_currentValue = lnbValue[_listBox,[_currentRow,0]];
			_unit = _listUnits select _currentValue;
			_currentUnit = missionNamespace getVariable _unit;
			//--- fable/fix-unit-purchase-nil-guards: guard nil _currentUnit (unregistered classname) before the select-chain below - matches a55605e10/#1003 shape. Nil = skip the panel refresh (stale/blank display, harmless).
			if !(isNil "_currentUnit") then {
			ctrlSetText [12009,_currentUnit select QUERYUNITPICTURE];
			ctrlSetText [12033,_currentUnit select QUERYUNITFACTION];
			ctrlSetText [12035,str (_currentUnit select QUERYUNITTIME)];
			_currentCost = round (((_currentUnit select QUERYUNITPRICE) * ATTACK_WAVE_PRICE_MODIFIER) * UNIT_COST_MODIFIER); //--- QoL: match the list/purchase formula (incl. unit-cost upgrade discount)
			
			_isInfantry = if (_unit isKindOf 'Man') then {true} else {false};
			
			//--- Update driver-gunner-commander icons.
			if !(_isInfantry) then {
				ctrlSetText [12036,"N/A"];
				ctrlSetText [12037,str (getNumber (configFile >> 'CfgVehicles' >> _unit >> 'transportSoldier'))];
				ctrlSetText [12038,str (getNumber (configFile >> 'CfgVehicles' >> _unit >> 'maxSpeed'))];
				ctrlSetText [12039,str (getNumber (configFile >> 'CfgVehicles' >> _unit >> 'armor'))];
				if (_type != 'Depot') then {
					_slots = _currentUnit select QUERYUNITCREW;
					
					if (typeName _slots == "ARRAY") then {
						_hasCommander = _slots select 0;
						_hasGunner = _slots select 1;
						_turretsCount = _slots select 3;
						_extra = 0;
						
						_maxOut = false;
						if (_lastType != _type || _lastSel != _currentRow) then {_maxOut = true};

						if (_maxOut) then {
							profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", true];
							profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true];
							_gunner = true;
							_commander = true;
							_extracrew = true;
						};
						
						if !(_hasGunner) then {_gunner = false};
						
						if !(_hasCommander) then {_commander = false};
						
						if (_turretsCount == 0) then {_extracrew = false};
						
						ctrlShow[_IDCSVehi select 0, true];
						ctrlShow[_IDCSVehi select 1, _hasGunner];
						ctrlShow[_IDCSVehi select 2, _hasCommander];
						ctrlShow[_IDCSVehi select 3, if (_turretsCount == 0) then {false} else {true}];
						
						_c = 0;
						{
							_color = if (_x) then {_enabledColor} else {_disabledColor};
							_con = _display displayCtrl (_IDCSVehi select _c);
							_con ctrlSetTextColor _color;

							_c = _c + 1;
						} forEach [profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ,_gunner,_commander,_extracrew];
						
						if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
						if (_gunner) then {_extra = _extra + 1};
						if (_commander) then {_extra = _extra + 1};
						if (_extracrew) then {_extra = _extra + _turretsCount};
						
						//--- Set the 'extra' price.
						//--- P5 crew-cost tier-scale (fable/crew-cost-tierscale, GR-2026-07-08a): ARRAY-crew (typeName ARRAY) branch - see the
						//--- single-unit purchase charge point above (~line 114) for the full rationale. Flag-off = byte-identical.
						_crewCostPerHead = missionNamespace getVariable "WFBE_C_UNITS_CREW_COST";
						if ((missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE", 0]) > 0) then {
							_crewCostPerHead = (_crewCostPerHead + ((_currentUnit select QUERYUNITPRICE) * (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_COEF", 0.03]))) min (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_CAP", 400]);
						};
						_currentCost = _currentCost + (_crewCostPerHead * _extra);
					} else {//--- Backward compability.
						_c = 0;
						_extra = 0;
						
						//--- Enabled AI by default.
						_extracrew = false;
						_maxOut = false;
						if (_lastType != _type || _lastSel != _currentRow) then {_maxOut = true};
						
						switch (_slots) do {
							case 1: {
								if (_maxOut) then {profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", true];profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true]};
								if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
								_gunner = false;
								_commander = false;
							};
							case 2: {
								if (_maxOut) then {profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", true];profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true];_gunner = true};
								if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
								if (_gunner) then {_extra = _extra + 1};
								_commander = false;
							};
							case 3: {
								if (_maxOut) then {profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", true];profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true];_gunner = true;_commander = true};
								if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
								if (_gunner) then {_extra = _extra + 1};
								if (_commander) then {_extra = _extra + 1};					
							};
						};
						
						//--- Show the icons.
						{
							_show = false;
							if (_c < _slots) then {_show = true};
							ctrlShow [_x,_show];
							_c = _c + 1;
						} forEach _IDCSVehi;
						
						//--- Mask extra crew.
						ctrlShow[_IDCSVehi select 3, false];
						
						_i = 0;
						
						//--- Set the icons.
						{
							_color = if (_x) then {_enabledColor} else {_disabledColor};
							_con = _display displayCtrl (_IDCSVehi select _i);
							_con ctrlSetTextColor _color;
							_i = _i + 1;
						} forEach [profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ,_gunner,_commander,_extracrew];

						//--- Set the 'extra' price.
						//--- P5 crew-cost tier-scale (fable/crew-cost-tierscale, GR-2026-07-08a): backward-compatibility (scalar _slots) branch - see the
						//--- single-unit purchase charge point above (~line 114) for the full rationale. Flag-off = byte-identical.
						_crewCostPerHead = missionNamespace getVariable "WFBE_C_UNITS_CREW_COST";
						if ((missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE", 0]) > 0) then {
							_crewCostPerHead = (_crewCostPerHead + ((_currentUnit select QUERYUNITPRICE) * (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_COEF", 0.03]))) min (missionNamespace getVariable ["WFBE_C_UNITS_CREW_COST_TIERSCALE_CAP", 400]);
						};
						_currentCost = _currentCost + (_crewCostPerHead * _extra);
					};
				} else {
					{ctrlShow [_x,false]} forEach (_IDCSVehi);
					profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", false];
					profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", false];
					_gunner = false;
					_commander = false;
					_extracrew = false;
				};
			} else {
				ctrlSetText [12036,Format ["%1/100",(_currentUnit select QUERYUNITSKILL) * 100]];
				ctrlSetText [12037,"N/A"];
				ctrlSetText [12038,"N/A"];
				ctrlSetText [12039,"N/A"];
			
				{ctrlShow [_x,false]} forEach (_IDCSVehi);
				profilenamespace setVariable ["wfbe_c_driver_enabled_by_default", false];
				profilenamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", false];
				_gunner = false;
				_commander = false;
				_extracrew = false;
				
				//--- Display a unit's loadout.
				_weapons = (getArray (configFile >> 'CfgVehicles' >> _unit >> 'weapons')) - ['Put','Throw'];
				_magazines = getArray (configFile >> 'CfgVehicles' >> _unit >> 'magazines');

				//--- Trello #91: gear/ammo preview fix for special AT soldiers whose actual loadout is
				//--- re-armed at unit creation (Common\Functions\Common_CreateUnit.sqf), so the raw config
				//--- class loadout shown here is wrong. Mirror those same removals/adds onto the preview
				//--- arrays (client display only — no gameplay/PV/authority change). Data-driven: each entry
				//--- is [classname,[wepRemove],[wepAdd],[[mag,count]...remove],[[mag,count]...add]].
				private ["_gearFix","_gearIdx","_gearEntry","_drop","_amt","_n2"];
				_gearFix = [
					["Ins_Soldier_AT", ["RPG7V"], ["M47Launcher_EP1"], [["PG7VL",3]], [["Dragon_EP1",2]]],
					["MVD_Soldier_AT", [], [], [["PG7VL",2],["OG7",1]], [["PG7VR",2]]]
				];
				_gearIdx = -1;
				{ if ((_x select 0) == _unit) exitWith { _gearIdx = _forEachIndex } } forEach _gearFix;
				if (_gearIdx >= 0) then {
					_gearEntry = _gearFix select _gearIdx;
					//--- Weapons: remove then add (preview launcher swap).
					_weapons = _weapons - (_gearEntry select 1);
					{ _weapons = _weapons + [_x] } forEach (_gearEntry select 2);
					//--- Magazines: remove N single instances of each (one per pass, mirroring the
					//--- per-call removeMagazine at creation), then append M instances of each.
					{
						_drop = _x select 0; _amt = _x select 1;
						for "_n2" from 1 to _amt do {
							if (_drop in _magazines) then {
								_magazines set [_magazines find _drop, "wfbe_geardisplay_void"];
								_magazines = _magazines - ["wfbe_geardisplay_void"];
							};
						};
					} forEach (_gearEntry select 3);
					{
						_drop = _x select 0; _amt = _x select 1;
						for "_n2" from 1 to _amt do { _magazines = _magazines + [_drop] };
					} forEach (_gearEntry select 4);
				};

				_classMags = [];
				_classMagsAmount = [];
				_MagsLabel = [];
				
				{
					_findAt = _classMags find _x;
					if (_findAt == -1) then {
						_classMags = _classMags + [_x];
						_classMagsAmount = _classMagsAmount + [1];
						_MagsLabel = _MagsLabel + [[_x,'displayName','CfgMagazines'] Call GetConfigInfo];
					} else {
						_classMagsAmount set [_findAt, (_classMagsAmount select _findAt) + 1];
					};
				} forEach _magazines;
				_txt = "<t color='#42b6ff' shadow='1'>" + (localize 'STR_WF_UNITS_Weapons') + ":</t><br />";
				for [{_i = 0},{_i < count _weapons},{_i = _i + 1}] do {
					_txt = _txt + "<t color='#eee58b' shadow='2'>" + ([(_weapons select _i),'displayName','CfgWeapons'] Call GetConfigInfo) + "</t>";
					if ((_i+1) < count _weapons) then {_txt = _txt + "<t color='#D3A119' shadow='2'>,</t> "}; 
				};
				_txt = _txt + "<t color='#D3A119' shadow='2'></t><br /><br />";
				_txt = _txt + "<t color='#42b6ff' shadow='1'>" + (localize 'STR_WF_UNITS_Magazines') + ":</t><br />";
				for [{_i = 0},{_i < count _MagsLabel},{_i = _i + 1}] do {
					_txt = _txt + "<t color='#eee58b' shadow='2'>" + ((_MagsLabel select _i) + "</t> <t color='#42b6ff' shadow='1'>x</t><t color='#42b6ff' shadow='1'>" + str (_classMagsAmount select _i)) + "</t>";
					if ((_i+1) < count _MagsLabel) then {_txt = _txt + "<t color='#D3A119' shadow='2'>,</t> "}; 
				};
				_txt = _txt + "<t color='#D3A119' shadow='2'></t>";
				
				(_display displayCtrl 12022) ctrlSetStructuredText (parseText _txt);
			};
				//--- Spotter infantry (claude-gaming): coloured-name partner in the buy list now gets a matching on-select explainer.
				//--- Mirrors the vehicle-specials hint convention (hintSilent parseText). Keyed on every selectable faction's spotter class (must match the buy-list tint in Client_UIFillListBuyUnits.sqf: live Chernarus WEST=USMC, EAST=RU; US/CDF/TK cover the rest + the Takistan mirror).
				if (_unit in ["USMC_SoldierS_Spotter","RU_Soldier_Spotter","US_Soldier_Spotter_EP1","CDF_Soldier_Spotter","TK_Soldier_Spotter_EP1"]) then {
					hintSilent parseText "<t color='#ffcc00'>Spotter</t> - a recon and target-spotting specialist, not a frontline fighter. <br/> <br/>Equipped with binoculars/optics to scout ahead, locate enemy positions and call out targets for your squad, snipers and artillery. <br/> <br/>Keep it back from direct contact and use it to reveal the enemy before you commit - eyes on, then strike.";
				} else {
					//--- Any OTHER infantry selection clears a lingering spotter hint (vehicles clear via the !(_isInfantry) Library block below).
					if (_isInfantry) then {hintSilent ""};
				};
			
			//--- QoL: show the full purchase cost (base + crew) in the dialog's price field (idc 12034).
			ctrlSetText [12034, format ["$%1", _currentCost]];

			//--- Lock Icon.
			if !(_isInfantry) then {
				ctrlShow[_IDCLock,true];
				_color = if (_isLocked) then {_enabledColor2} else {_disabledColor};
				_con = _display displayCtrl _IDCLock;
				_con ctrlSetTextColor _color;
			} else {
				ctrlShow[_IDCLock,false];
			};

			//--- Long description.
			if !(_isInfantry) then {
				if (isClass (configFile >> 'CfgVehicles' >> _unit >> 'Library')) then {
					_txt = getText (configFile >> 'CfgVehicles' >> _unit >> 'Library' >> 'libTextDesc');
					(_display displayCtrl 12022) ctrlSetStructuredText (parseText _txt);

					hintSilent "";

					if (_unit in (missionNamespace getVariable Format ["WFBE_%1AMBULANCES", sideJoinedText])) then {
						hintSilent parseText "Ambulances are important vehicles because they can be used as mobile respawn points. <br/> <br/>You can see the current maximum allowed respawn range from any friendly ambulance from >> WF Menu -> Factory Upgrade -> Ambulance Range upgrade."
					};
					//--- Medic Redeployment Truck (claude-gaming): missing explainer added. Keyed on the same WFBE_%1REDEPLOYTRUCKS side-list (and the same WFBE_C_UNITS_REDEPLOYTRUCK gate) the violet buy-menu row tint uses. Sits right after the ambulance hint so the medical vehicles group together.
					if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0 && {_unit in (missionNamespace getVariable [Format ["WFBE_%1REDEPLOYTRUCKS", sideJoinedText], []])}) then {
						hintSilent parseText "<t color='#b266ff'>Medic Redeployment Truck</t> - a mobile forward field-aid and respawn point for your MEDICS. <br/> <br/>Drive it up behind the front line and park it. Only the MEDIC class can redeploy (respawn) at this truck, letting your medics return to the fight close to the action and keep the squad patched up - no long run back from base. <br/> <br/>Note: you need the MEDIC slot/class selected in the server lobby to spawn here. Keep the truck alive and reasonably safe - if it is destroyed the forward medic spawn is lost.";
					};
					if (_unit in (missionNamespace getVariable Format ["WFBE_%1REPAIRTRUCKS", sideJoinedText])) then {
						hintSilent parseText "Repair trucks are special vehicles that can be used to build static structures and weapons. They are especially useful for advanced tactics. <br/> <br/>Get in driver seat of your repair truck and open action menu (mouse scroll). You should see the repair truck build menu option, select it and start building!";
					};
					if (_unit in (missionNamespace getVariable Format ["WFBE_%1SUPPLYTRUCKS", sideJoinedText])) then {
						hintSilent parseText "Supply trucks can be used to boost the supply income of your team. <br/> <br/>You can collect extra supply by driving to friendly town center (next to main depot of town), getting out of your supply truck, aiming at it and using action menu (mouse scroll) -> LOAD SUPPLIES... Then just drive next to friendly Command Center (marked with C) on map. <br/> <br/> Note that you need to have selected Support slot/class in server lobby. There also needs to be [+SUPPLY] mark after town name for you to be able to collect the extra supply.";
					};
					//--- Salvage truck (claude-gaming): missing explainer added. Matches the side-list convention above (WFBE_%1SALVAGETRUCK is the same list the green buy-menu row tint keys on).
					if (_unit in (missionNamespace getVariable Format ["WFBE_%1SALVAGETRUCK", sideJoinedText])) then {
						hintSilent parseText "<t color='#00ff00'>Salvage Truck</t> - turns enemy and neutral wrecks into cash for your team. <br/> <br/>Drive it (a crew must be aboard) near any destroyed vehicle, ship, aircraft or static weapon. While the truck is parked nearby, eligible wrecks in range are automatically recovered and DELETED, paying your team a share of each wreck's value. <br/> <br/>Keep it close to where hostile vehicles are dying - frontlines, contested towns, and enemy pushes - to keep the salvage income flowing.";
					};
					//--- Utility / rearm (ammo) truck (claude-gaming): missing explainer added. Keyed on the same WFBE_%1AMMOTRUCKS side-list the red buy-menu row tint uses.
					//--- GUER MARKER FIX (claude 2026-07-01): nil-guard with [Format[...], []] - WFBE_GUERAMMOTRUCKS is undefined for the
					//--- playable GUER faction, so the bare read threw `_unit in nil` here and aborted the rest of this selection handler
					//--- (the GUER VBIED / mortar-truck / special-unit hints below never ran). Matches the L696 nil-safe form.
					if (_unit in (missionNamespace getVariable [Format ["WFBE_%1AMMOTRUCKS", sideJoinedText], []])) then {
						hintSilent parseText "<t color='#ff5555'>Utility / Ammunition Truck</t> - a mobile rearm and resupply point for your forces. <br/> <br/>Park it near friendly units and vehicles that have run dry, get in the driver seat and open the action menu (mouse scroll) to resupply ammunition, or have nearby allies rearm from it. <br/> <br/>Use it to keep an advancing push topped up on ammo without driving all the way back to base.";
					};
					if (_unit in WFBE_C_SUPPLY_HELI_TYPES) then {
						hintSilent parseText "Supply helicopters work like supply trucks but deliver supply by air. <br/> <br/>Requires the Aircraft Factory at level 3. At Air level 4, deliveries become CASH RUNS straight to the commander's funds. Air delivery pays the pilot a larger reward. <br/> <br/>Aim at a friendly [+SUPPLY] town's helicopter, use LOAD SUPPLIES, then fly to your Command Center (marked C). A loaded helicopter shot down hands the enemy a share of the cargo.";
					};
					if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_unit == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])} && {(side group player) == resistance}) then {
						hintSilent parseText "VBIED - driver-detonated suicide truck. <br/> <br/>Buy it, drive it into a packed enemy position, then action menu (mouse scroll) -> <t color='#ff3333'>Detonate VBIED</t>. After a short arm delay it explodes and your GUER team is paid for the kills. One-shot - truck + driver are lost.";
					};
					//--- GUER improvised mortar truck (V3S_Gue): explain the driver call-in strike. Runs AFTER the ambulance hint so it overrides (V3S_Gue is the GUER ambulance class).
					if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_unit == "V3S_Gue"}) then {
						hintSilent parseText "<t color='#33ccff'>Improvised Mortar Truck</t> - a mobile call-in barrage. <br/> <br/>Drive it near the front, then as the DRIVER use the action menu (mouse scroll) -> <t color='#33ccff'>Call mortar strike</t>. Click the map within range to mark the impact point and a short barrage drops there. <br/> <br/>A cooldown and a small per-strike fee apply; accuracy tightens as your GUER vehicle tier rises. (This same truck also doubles as your ambulance / mobile respawn.)";
					};
					//--- B75 (guer-tech): kill-unlocked SECOND VBIED — the armoured M113 variant (~2x speed, no weapons).
					if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_unit == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])} && {(side group player) == resistance}) then {
						hintSilent parseText "VBIED (APC) - an unarmoured-crew but TRACKED suicide M113 that drives at roughly DOUBLE its normal top speed. <br/> <br/>Same one-shot use as the truck VBIED: drive into a packed enemy position, then action menu (mouse scroll) -> <t color='#ff3333'>Detonate VBIED</t>. Its armour + speed let it punch through to a target the soft truck can't reach. Unlocked by GUER kills.";
					};
					//--- fable/guer-suicide-bike (flag WFBE_C_GUER_SUICIDE_BIKE, default 0): THIRD VBIED variant, a fast small suicide motorcycle.
					if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {(missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0} && {_unit == (missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Ins"])} && {(side group player) == resistance}) then {
						hintSilent parseText "VBIED (Bike) - a fast, small suicide motorcycle. <br/> <br/>Buy it, ride it into a packed enemy position, then action menu (mouse scroll) -> <t color='#ff3333'>Detonate VBIED</t>. Its small silhouette and speed let it slip through where the truck can't. Same one-shot use: rider + bike are lost, and your GUER team is paid for the kills.";
					};
					
					if (!(_unit in WFBE_C_SUPPLY_HELI_TYPES) && {_unit in (missionNamespace getVariable [format ["WFBE_%1LIFTVEHICLE", sideJoinedText], []])}) then {
						hintSilent parseText "Lift-capable helicopter. <br/> <br/>Can sling-load vehicles and objects once the Airlift upgrade is unlocked. (Not a supply helicopter.)";
					};

					//--- Data-driven special-unit info popup (WFBE_SPECIAL_UNIT_HINTS).
					//--- Format: [[classname, stringtable-key], ...].  Append pairs to add new specials.
					private ["_wfbeSpecialHints","_wfbeHintIdx","_wfbeHintKey"];
					_wfbeSpecialHints = missionNamespace getVariable ["WFBE_SPECIAL_UNIT_HINTS", []];
					_wfbeHintIdx = -1;
					{
						if ((_x select 0) == _unit) exitWith { _wfbeHintIdx = _forEachIndex };
					} forEach _wfbeSpecialHints;
					if (_wfbeHintIdx >= 0) then {
						_wfbeHintKey = (_wfbeSpecialHints select _wfbeHintIdx) select 1;
						hintSilent parseText (localize _wfbeHintKey);
					};

					_artyClassnames = missionNamespace getVariable Format ['WFBE_%1_ARTILLERY_CLASSNAMES', sideJoinedText];
					_varPosInNestedArray = [_artyClassnames, _unit] call WFBE_CL_FNC_FindVariableInNestedArray;
					_isNotArtillery = [_varPosInNestedArray, -1] call BIS_fnc_areEqual;
					
					if (!(_isNotArtillery)) then {
						hintSilent parseText "Artillery units can be used by placing AI in artillery unit's gunner seat. <br/> <br/>For your convenience, there will be an AI in gunner seat in vehicles that you buy, unless you change the default selections. <br/> <br/>You can call an artillery strike via >> WF menu -> Tactical Center. <br/> <br/>You need to select the correct artillery type, set target radius, set the arty strike center point (within allowed range) and finally, call the arty strike. <br/><br/>Note that there are static arty units as well. You can build them with repair truck or as the commander of your side."
					};

				} else {
					(_display displayCtrl 12022) ctrlSetStructuredText (parseText '');
				};
				//--- PR #846 follow-up (fable/fob-polish): FOB delivery truck explainer. Placed OUTSIDE the Library-gated
				//--- block above: Ural_INS / UralOpen_INS (CH) and the TK/ZG FOB trucks have NO CfgVehicles Library class
				//--- (config-reference verified; only GAZ_Vodnik has one), so a hint inside that block never fires for them.
				if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_unit in (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []])}) then {
					hintSilent parseText "<t color='#76F563'>FOB Delivery Truck</t> - deploys a forward operating base. <br/> <br/>Buy it, drive it to where you want your forward base (not too close to enemy towns or the enemy base), then as the DRIVER use the action menu (mouse scroll) -> <t color='#76F563'>Build FOB</t>. The truck is consumed and the FOB factory is built in front of it - a GUER respawn point and forward production point. <br/> <br/>Listed in the depot only while your side holds the matching FOB token (earned by destroying enemy factories).";
				};
			};
			
			ctrlSetText [12034,Format ["$ %1",_currentCost]];
			_updateDetails = false;
			} else {
				["WARNING", Format ["GUI_Menu_BuyUnits.sqf: preview classname [%1] not registered in missionNamespace; skipping detail-panel refresh (nil-poison guard, matches a55605e10/#1003).", _unit]] Call WFBE_CO_FNC_LogContent;
				_updateDetails = false;
			};
		} else {
			{ctrlSetText [_x , ""]} forEach [12009,12033,12034,12035,12036,12037,12038,12039];
			//--- Task 33: show queue list in the description panel when no unit is selected.
			private ["_qLabels33","_qTokens33","_uid33","_qTxt33","_qEntry33","_uidPrefix33b"];
			_qTokens33 = _closest getVariable ["queu", []];
			_qLabels33 = _closest getVariable ["queu_labels", []];
			_uid33 = getPlayerUID player;
			//--- A2-safe "token starts with UID" test (string find is A3-only, throws on A2 OA).
			_uidPrefix33b = {
				private ["_tokA","_uidA","_ul","_ok","_j"];
				_tokA = toArray (_this select 0);
				_uidA = toArray (_this select 1);
				_ul = count _uidA;
				_ok = (_ul > 0) && (_ul <= count _tokA);
				if (_ok) then {
					for "_j" from 0 to (_ul - 1) do {
						if ((_tokA select _j) != (_uidA select _j)) exitWith {_ok = false};
					};
				};
				_ok
			};
			if (count _qTokens33 > 0) then {
				_qTxt33 = "<t color='#42b6ff' shadow='1'>Queue (oldest first):</t><br/>";
				{
					_qEntry33 = if (_forEachIndex < count _qLabels33) then {_qLabels33 select _forEachIndex} else {"?"};
					private "_mark33";
					_mark33 = if ([_x, _uid33] call _uidPrefix33b) then {"<t color='#ffe066'>YOU</t>  "} else {"          "};
					_qTxt33 = _qTxt33 + Format ["%1<t color='#eee58b'>%2. %3</t><br/>", _mark33, (_forEachIndex + 1), _qEntry33];
				} forEach _qTokens33;
				_qTxt33 = _qTxt33 + "<br/><t color='#aaaaaa' size='0.85'>Press 'Cancel Last' to remove your last order and get a refund.</t>";
				(_display displayCtrl 12022) ctrlSetStructuredText (parseText _qTxt33);
			} else {
				(_display displayCtrl 12022) ctrlSetStructuredText (parseText "<t color='#aaaaaa'>Queue is empty. Select a unit to buy it.</t>");
			};
		};
	};
	
	//--- Update the Factory Minimap position.
	if (_updateMap) then {
		if !(isNull _closest) then {
			ctrlMapAnimClear _map;
			_map ctrlMapAnimAdd [2,.075,getPos _closest];
			ctrlMapAnimCommit _map;
		};
		_updateMap = false;
	};
	
	//--- Check that the factories of the current type are still alive.
	_lastCheck = _lastCheck + 0.1;
	if (_lastCheck > 2 && _type != 'Depot' && _type != 'Airport') then {
		_lastCheck = 0;
		_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
		_factories = [sideJoined,missionNamespace getVariable Format ['WFBE_%1%2TYPE',sideJoinedText,_type],_buildings] Call GetFactories;
		if (count _factories != _countAlive) then {_updateList = true};
	};
	
	_lastSel = lnbCurSelRow _listBox;
	_lastType = _type;
	sleep 0.1;
	
	//--- Back Button.
	if (MenuAction == 2) exitWith { //---added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
};
