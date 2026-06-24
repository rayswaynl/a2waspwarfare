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

_driverEnabledByDefault = true;
profileNamespace setVariable ["wfbe_c_driver_enabled_by_default", true];
profileNamespace setVariable ["WFBE_C_DRIVER_ENABLED_BY_DEFAULT", true];


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
		_currentCost = round (((_currentUnit select QUERYUNITPRICE) * ATTACK_WAVE_PRICE_MODIFIER) * UNIT_COST_MODIFIER);
		_cpt = 1;
		_isInfantry = if (_unit isKindOf 'Man') then {true} else {false};
		if !(_isInfantry) then {
			_extra = 0;
			if (profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ) then {_extra = _extra + 1};
			if (_gunner) then {_extra = _extra + 1};
			if (_commander) then {_extra = _extra + 1};
			if (_extracrew) then {_extra = _extra + ((_currentUnit select QUERYUNITCREW) select 3)};
			_currentCost = _currentCost + ((missionNamespace getVariable "WFBE_C_UNITS_CREW_COST") * _extra);
		};
		if ((_currentRow) != -1) then {
			_funds = Call GetPlayerFunds;
			_skip = false;

			Private ["_currentUnitLabelForFundsMissing"];
            _currentUnitLabelForFundsMissing = _currentUnit select QUERYUNITLABEL;

			if (_funds < _currentCost) then {_skip = true;hint parseText(Format[localize 'STR_WF_INFO_Funds_Missing',_currentCost - _funds,_currentUnitLabelForFundsMissing])};
			//--- Make sure that we own all camps before being able to purchase infantry.
			if (_type == "Depot" && _isInfantry && sideJoined != resistance) then {
				_totalCamps = _closest Call GetTotalCamps;
				_campsSide = [_closest,sideJoined] Call GetTotalCampsOnSide;
				if (_totalCamps != _campsSide) then {_skip = true; hint parseText(localize 'STR_WF_INFO_Camps_Purchase')};
			};
			if !(_skip) then {
				_size = Count ((Units (group player)) Call GetLiveUnits);
				//--- Get the infantry limit based off the infantry upgrade.
				_realSize = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
				switch (_realSize) do {
					case 0: {_realSize = round(_mbu / 4)};
					case 1: {_realSize = round(_mbu / 4)*2};
					case 2: {_realSize = round(_mbu / 4)*3};
					case 3: {_realSize = _mbu};
					default {_realSize = _mbu};
				};
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
				if ((missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_type]) < (missionNamespace getVariable Format["WFBE_C_QUEUE_%1_MAX",_type])) then {
					missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_type],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_type])+1];
					Private ["_currentUnitLabel"];
                    _currentUnitLabel = _currentUnit select QUERYUNITLABEL;

					_queu = _closest getVariable 'queu';
					_txt = parseText(Format [localize 'STR_WF_INFO_BuyEffective',_currentUnitLabel]);
					if (!isNil '_queu') then {if (count _queu > 0) then {_txt = parseText(Format [localize 'STR_WF_INFO_Queu',_currentUnitLabel])}};
					hint _txt;
					_params = if (_isInfantry) then {[_closest,_unit,[],_type,_cpt,_currentCost]} else {[_closest,_unit,[profilenamespace getvariable "wfbe_c_driver_enabled_by_default" ,_gunner,_commander,_extracrew,_isLocked],_type,_cpt,_currentCost]};
					_params Spawn BuildUnit;
					-(_currentCost) Call ChangePlayerFunds;
					//--- QoL trio feat.3: stamp last-purchase time for advisor nudge.
					if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) > 0) then {
						WFBE_QOL_LAST_PURCHASE_TIME = time;
					};
					_updateDetails = true; //--- Task 33: refresh queue list panel after purchase.
				} else {
					hint parseText(Format [localize 'STR_WF_INFO_Queu_Max',missionNamespace getVariable Format["WFBE_C_QUEUE_%1_MAX",_type]]);
				};
			};
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
		//--- Find the LAST entry belonging to this player.
		_idx33 = -1;
		{if ([_x, _uid33] call _uidPrefix33) then {_idx33 = _forEachIndex}} forEach _q33;
		if (_idx33 == -1) exitWith {hint parseText "<t color='#ff9900'>You have no unit queued in this factory.</t>"};
		_paidCost33 = if (_idx33 < count _qc33) then {_qc33 select _idx33} else {0};
		_cpt33      = if (_idx33 < count _qp33) then {_qp33 select _idx33} else {1};
		_refund33   = _paidCost33;
		if (ATTACK_WAVE_PRICE_MODIFIER < 1.0 && UNIT_COST_MODIFIER > 0) then {
			_basePrice33 = _paidCost33 / (ATTACK_WAVE_PRICE_MODIFIER * UNIT_COST_MODIFIER);
			_maxRefund33 = round (_basePrice33 * 0.5);
			if (_refund33 > _maxRefund33) then {_refund33 = _maxRefund33};
		};
		//--- Remove from all parallel arrays by index.
		_q33 = _q33 - [_q33 select _idx33];
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
	
	//--- Player funds.
	ctrlSetText [12019,Format [localize 'STR_WF_UNITS_Cash',Call GetPlayerFunds]];

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
	
	//--- Display Factory Queu.
	_queu = _closest getVariable "queu";
	_value = if (isNil '_queu') then {0} else {count (_closest getVariable "queu")};
	//--- WFBE_C_FACTORY_QUEUE_LIMITS=1: append /CAP to the queue count so players can see the limit.
	//--- Falls back to plain count if WFBE_C_FACTORY_QUEUE_LIMITS=0 or the cap var is missing/zero.
	//--- Cross-ref: cap formula lives in the WFBE_C_FACTORY_QUEUE_LIMITS block above this loop.
	if ((missionNamespace getVariable ["WFBE_C_FACTORY_QUEUE_LIMITS",0]) > 0) then {
		private ["_qCap"];
		_qCap = missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1_MAX",_type], -1];
		if (_qCap > 0) then {
			ctrlSetText[12024,Format[localize 'STR_WF_UNITS_QueuedLabel', str _value + "/" + str _qCap]];
		} else {
			ctrlSetText[12024,Format[localize 'STR_WF_UNITS_QueuedLabel',str _value]];
		};
	} else {
		ctrlSetText[12024,Format[localize 'STR_WF_UNITS_QueuedLabel',str _value]];
	};
	
	//--- List selection changed.
	if (_updateDetails) then {
		_currentRow = lnbCurSelRow _listBox;
		//--- Our list is not empty.
		if (_currentRow != -1) then {
			_currentValue = lnbValue[_listBox,[_currentRow,0]];
			_unit = _listUnits select _currentValue;
			_currentUnit = missionNamespace getVariable _unit;
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
						_currentCost = _currentCost + ((missionNamespace getVariable "WFBE_C_UNITS_CREW_COST") * _extra);
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
						_currentCost = _currentCost + ((missionNamespace getVariable "WFBE_C_UNITS_CREW_COST") * _extra);
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
					if (_unit in (missionNamespace getVariable Format ["WFBE_%1REPAIRTRUCKS", sideJoinedText])) then {
						hintSilent parseText "Repair trucks are special vehicles that can be used to build static structures and weapons. They are especially useful for advanced tactics. <br/> <br/>Get in driver seat of your repair truck and open action menu (mouse scroll). You should see the repair truck build menu option, select it and start building!";
					};
					if (_unit in (missionNamespace getVariable Format ["WFBE_%1SUPPLYTRUCKS", sideJoinedText])) then {
						hintSilent parseText "Supply trucks can be used to boost the supply income of your team. <br/> <br/>You can collect extra supply by driving to friendly town center (next to main depot of town), getting out of your supply truck, aiming at it and using action menu (mouse scroll) -> LOAD SUPPLIES... Then just drive next to friendly Command Center (marked with C) on map. <br/> <br/> Note that you need to have selected Support slot/class in server lobby. There also needs to be [+SUPPLY] mark after town name for you to be able to collect the extra supply.";
					};
					if (_unit in WFBE_C_SUPPLY_HELI_TYPES) then {
						hintSilent parseText "Supply helicopters work like supply trucks but deliver supply by air. <br/> <br/>Requires the Aircraft Factory at level 3. At Air level 4, deliveries become CASH RUNS straight to the commander's funds. Air delivery pays the pilot a larger reward. <br/> <br/>Aim at a friendly [+SUPPLY] town's helicopter, use LOAD SUPPLIES, then fly to your Command Center (marked C). A loaded helicopter shot down hands the enemy a share of the cargo.";
					};
					if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_unit == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])}) then {
						hintSilent parseText "VBIED - driver-detonated suicide truck. <br/> <br/>Buy it, drive it into a packed enemy position, then action menu (mouse scroll) -> <t color='#ff3333'>Detonate VBIED</t>. After a short arm delay it explodes and your GUER team is paid for the kills. One-shot - truck + driver are lost.";
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
			};
			
			ctrlSetText [12034,Format ["$ %1",_currentCost]];
			_updateDetails = false;
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
