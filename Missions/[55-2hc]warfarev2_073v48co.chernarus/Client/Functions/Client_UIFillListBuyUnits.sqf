Private ['_description','_addin','_c','_currentUpgrades','_filler','_filter','_i','_listBox','_listNames','_u','_value','_unitCostUpgradeLevel','_funds','_price','_unlockList','_lockIdx','_lockEntry','_outerX','_reqTown','_townObj'];
_listNames = _this select 0;
_filler = _this select 1;
_listBox = _this select 2;
_value = _this select 3;

_unitCostUpgradeLevel = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_UNITCOST;

UNIT_COST_MODIFIER = 1; //--- wiki-wins: reset to 1 each fill so a stale 0.75/0.5 discount does not persist when the unit-cost upgrade is at level 0
if (_unitCostUpgradeLevel > 0) then {
	if (_unitCostUpgradeLevel == 1) then {
		UNIT_COST_MODIFIER = 0.75;
	};
	if (_unitCostUpgradeLevel == 2) then {
		UNIT_COST_MODIFIER = 0.5;
	};
};

_u = 0;
_i = 0;

_UpAirlift = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIRLIFT;


_currentUpgrades = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
_filter = missionNamespace getVariable Format["WFBE_%1%2CURRENTFACTIONSELECTED",sideJoinedText,_filler];
if (isNil '_filter') then {_filter = "nil"} else {
	if (_filter == 0) then {
		_filter = 'nil';
	} else {
		_filter = ((missionNamespace getVariable Format["WFBE_%1%2FACTIONS",sideJoinedText,_filler]) select _filter);
	};
};

_funds = Call GetPlayerFunds; //--- QoL: affordability reference (base price vs current funds)
lnbClear _listBox;

//--- wiki-wins: hoist the 8 per-side classlist lookups out of the per-row forEach (loop-invariant; sideJoinedText is constant during the fill)
private ["_wlRepair","_wlAmmo","_wlLift","_wlAmbu","_wlRedeploy","_wlSalvage","_wlArty","_wlSupply"];
_wlRepair   = missionNamespace getVariable [format["WFBE_%1REPAIRTRUCKS", sideJoinedText], []];
_wlAmmo     = missionNamespace getVariable [format["WFBE_%1AMMOTRUCKS", sideJoinedText], []];
_wlLift     = missionNamespace getVariable [format["WFBE_%1LIFTVEHICLE", sideJoinedText], []];
_wlAmbu     = missionNamespace getVariable [format["WFBE_%1AMBULANCES", sideJoinedText], []];
_wlRedeploy = missionNamespace getVariable [format["WFBE_%1REDEPLOYTRUCKS", sideJoinedText], []];
_wlSalvage  = missionNamespace getVariable [format["WFBE_%1SALVAGETRUCK", sideJoinedText], []];
_wlArty     = missionNamespace getVariable [format["WFBE_%1ARTYVEHICLE", sideJoinedText], []];
_wlSupply   = missionNamespace getVariable [Format ["WFBE_%1SUPPLYTRUCKS", sideJoinedText], []];
{
	_addin = true;
	_c = missionNamespace getVariable _x;
	if (_filter != "nil") then {
		if (isNil "_c") then {_addin = false} else {if ((_c select QUERYUNITFACTION) != _filter) then {_addin = false}}; //--- B751: guard nil _c (unregistered roster classname) before the faction-filter select.
	};

	_addit = false;
		if(_filler == 'Depot') then
		{
		    _UpBar = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
			if ((_x in ['Ins_Soldier_MG', 'TK_Soldier_MG_EP1', 'USMC_Soldier_MG', 'US_Soldier_MG_EP1']) && _UpBar>=1)then{_addit  = true;};
			if ((_x in ['RU_Soldier_AT', 'TK_Soldier_AT_EP1', 'USMC_Soldier_LAT']) && _UpBar>=1)then{_addit = true;};
			if ((_x in ['TK_Soldier_Engineer_EP1', 'BAF_Soldier_EN_W']) && _UpBar>=1)then{_addit = true;};
			if ((_x in ['RU_Soldier_Sniper', 'TK_Soldier_Sniper_EP1', 'USMC_SoldierS_Sniper', 'US_Soldier_Sniper_EP1']) && _UpBar>=2)then{_addit = true;};
			if ((_x in ['RU_Soldier_AA','USMC_Soldier_AA']) && _UpBar>=3)then{_addit = true;};
		};

        if !(isNil "_c") then {
            _description = _c select QUERYUNITLABEL;
        } else {
            _description = "undefined";
        };

	// Capture-to-unlock gate: suppress any unit in the side's CAPTURE_UNLOCKS list
	// unless the required trigger town is currently held by this side.
	// A2OA lacks findIf; forEach/exitWith is used to locate entries by classname.
	if ((missionNamespace getVariable ["WFBE_C_CAPTURE_UNLOCKS", 0]) > 0) then {
		_unlockList = missionNamespace getVariable [Format["WFBE_%1_CAPTURE_UNLOCKS", sideJoinedText], []];
		_outerX = _x; // save outer-forEach _x before it is shadowed by the inner scan
		_lockIdx = -1;
		{
			if ((_x select 0) == _outerX) exitWith { _lockIdx = _forEachIndex };
		} forEach _unlockList;
		if (_lockIdx >= 0) then {
			_lockEntry = _unlockList select _lockIdx;
			_reqTown   = _lockEntry select 1;
			_townObj   = objNull;
			{ if ((_x getVariable ["name",""]) == _reqTown) exitWith { _townObj = _x } } forEach towns;
			if (isNull _townObj) then {
				_addin = false; // town not yet initialised — hide until ready
			} else {
				if ((_townObj getVariable ["sideID",-1]) != WFBE_Client_SideID) then {
					_addin = false;
				};
			};
		};
	};

	//--- Task 36: _value >= array length is the "no upgrade gate" sentinel (airfield hangar
	//--- roster — the capture itself is the unlock; indexing past the array would error).
	private "_upgradePass";
	//--- B750 (2026-06-24): guard a nil _c (a roster classname with no registered unit data). The bare if/then/else
	//--- returned nil and stranded _upgradePass -> "Undefined variable: _upgradepass" on the next line, then silently
	//--- dropped that row (caught live in Ray's b749 client RPT). Default hide; only a real data array can pass.
	_upgradePass = false;
	if (!isNil "_c") then {
		_upgradePass = if (_value >= count _currentUpgrades) then {true} else {(_c select QUERYUNITUPGRADE) <= (_currentUpgrades select _value)};
	};
	if ((_upgradePass && _addin) || (_addit&&_addin)) then {
		_price = round (((_c select QUERYUNITPRICE) * ATTACK_WAVE_PRICE_MODIFIER) * UNIT_COST_MODIFIER);
		lnbAddRow [_listBox,['$'+str _price,_description]];
		lnbSetData [_listBox,[_i,0],_filler];
		lnbSetValue [_listBox,[_i,0],_u];




	if(_x in _wlRepair) then {
		lnbSetColor [_listBox,[_i,1],[0.33, 0.33, 0.10, 1.0]]
	};

	if(_x in _wlAmmo) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.0, 0.0, 0.6]]
	};


	if (_UpAirlift > 0) then {

		if(_x in _wlLift) then {
			lnbSetColor [_listBox,[_i,1],[0.0, 0.26, 1.0, 1.0]]
		};
	};

	if(_x in _wlAmbu) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 1.0, 0.0, 0.6]]

	};

	//--- Medic redeployment truck: violet tint (unique — ambulance=yellow, salvage=green) + medic-flavored label.
	if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0) then {
		if(_x in _wlRedeploy) then {
			lnbSetColor [_listBox,[_i,1],[0.7, 0.4, 1.0, 0.6]];
			lnbSetText [_listBox,[_i,1],_description + " [Medic Redeploy,Spawn]"];
		};
	};


	if(_x in _wlSalvage) then {
		lnbSetColor [_listBox,[_i,1],[0.0, 1.0, 0.0, 0.6]]

	};

	if(_x in _wlArty) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.3, 1.0, 0.4]]
	};

	if (_x in _wlSupply) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.5, 0.25, 1.0]]
	};

	if (_x in WFBE_C_SUPPLY_HELI_TYPES) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.5, 0.25, 1.0]]
	};

	//--- GUER VBIED suicide truck: red name + [VBIED] tag so it reads as a weapon, not a civ car. Keyed off live WFBE_C_GUER_VBIED_TYPE (hilux CH / datsun TK).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_x == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])}) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.2, 0.2, 1.0]];
		lnbSetText  [_listBox,[_i,1],_description + " [VBIED - Suicide Truck]"];
	};
	//--- B75 (guer-tech): SECOND VBIED — the kill-gated unarmed M113 (~2x speed). Same red weapon styling as the hilux, distinct tag.
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_x == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])}) then {
		lnbSetColor [_listBox,[_i,1],[1.0, 0.2, 0.2, 1.0]];
		lnbSetText  [_listBox,[_i,1],_description + " [VBIED - APC, 2x Speed]"];
	};
	//--- B75 (guer-tech FOB): relabel the FOB delivery trucks "FOB (Barracks/Light Factory/Heavy Factory)" in the GUER
	//--- buy list ONLY. The trucks ride their canonical (shared) registration to avoid clobbering the AI/EAST factions
	//--- (see Core_GUE.sqf), so their displayed name would otherwise be the donor truck's. Resistance-gated so an EAST
	//--- player who buys the same class (e.g. GAZ_Vodnik) still sees the real name. Index in WFBE_C_GUER_FOB_TRUCKS = type.
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {(side group player) == resistance}) then {
		private ["_fobI"];
		_fobI = (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []]) find _x;
		if (_fobI >= 0) then {
			lnbSetColor [_listBox,[_i,1],[0.46, 0.85, 0.46, 1.0]];
			lnbSetText  [_listBox,[_i,1], ["FOB (Barracks)","FOB (Light Factory)","FOB (Heavy Factory)"] select _fobI];
		};
	};

		if (_price > _funds) then {lnbSetColor [_listBox,[_i,0],[1,0.4,0.4,1]]}; //--- QoL: red price = can't afford base cost
		_i = _i + 1;
	};
	_u = _u + 1;
} forEach _listNames;

if (_i > 0) then {lnbSetCurSelRow [_listBox,0]} else {lnbSetCurSelRow [_listBox,-1]};