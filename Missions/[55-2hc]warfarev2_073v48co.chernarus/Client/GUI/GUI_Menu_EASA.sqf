MenuAction = -1;

_type = (missionNamespace getVariable 'WFBE_EASA_Vehicles') find (typeOf (vehicle player));
if (_type == -1) exitWith {["ERROR", Format ["GUI_Menu_EASA.sqf: Player vehicle [%1] was not found within the list.", vehicle player]] Call WFBE_CO_FNC_LogContent};
_data = ((missionNamespace getVariable 'WFBE_EASA_Loadouts') select _type);
_repairPointEASA = if (isNil "WFBE_CL_V_RepairPointEASAActive") then {false} else {WFBE_CL_V_RepairPointEASAActive};

_listBox = 23003;

_u = 0;
_upgrades = sideJoined Call WFBE_CO_FNC_GetSideUpgrades;

//--- QoL: [DEFAULT] sentinel row always at top (index 0, sentinel value -1).
lnbAddRow [_listBox, ["$0.", "[DEFAULT] Factory loadout"]];
lnbSetValue [_listBox, [_u, 0], -1];
_u = _u + 1;

for '_i' from 0 to count(_data)-1 do {
	_row = _data select _i;
	// _add = if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") < 1 && (_row select 3)) then {false} else {true};
	_add = true;
	switch (missionNamespace getVariable "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") do {
		case 0: {if (_row select 3) then {_add = false}};
		case 1: {
			if ((_upgrades select WFBE_UP_AIRAAM) == 0 && (_row select 3)) then {_add = false};
		};
	};

	if (_add) then {
		//--- EASA category tags: prefix each loadout label with [AA], [AG], or [MR].
		//--- Categorise once at fill time; WFBE_EASA_CatCache prevents repeated walks.
		private ["_rowLabel","_catTag"];
		_rowLabel = _row select 1;
		if (WFBE_C_EASA_CATEGORIES == 1 && !(isNil "WFBE_EASA_FNC_LoadoutCat")) then {
			_catTag = (_row select 2) call WFBE_EASA_FNC_LoadoutCat;
			_rowLabel = _catTag + " " + _rowLabel;
		};
		lnbAddRow [_listBox, [Format["$%1.", _row select 0], _rowLabel]];
		lnbSetValue[_listBox, [_u, 0], _i];
		_u = _u + 1;
	};
};

//--- QoL: mark and pre-select the loadout currently equipped on the vehicle.
private ["_active","_rows","_activeRow"];
_active = (vehicle player) getVariable ["WFBE_EASA_Setup", -1];
_rows = (lnbSize _listBox) select 0;
_activeRow = -1;
for "_r" from 0 to (_rows - 1) do {
	if ((lnbValue [_listBox, [_r, 0]]) == _active) then {
		_activeRow = _r;
		lnbSetColor [_listBox, [_r, 1], [0.5, 1, 0.5, 1]]; //--- green = currently equipped
	};
};
if (_rows > 0) then {lnbSetCurSelRow [_listBox, (if (_activeRow != -1) then {_activeRow} else {0})]} else {lnbSetCurSelRow [_listBox, -1]};

while {alive player && dialog} do {
	sleep 0.1;
	
	if (side group player != sideJoined) exitWith {closeDialog 0};
	if !(dialog) exitWith {};
	
	//--- Command AI.
	if (MenuAction == 101) then {
		MenuAction = -1;
		_funds = Call GetPlayerFunds;
		
		_index = lnbCurSelRow _listBox;
		if (_index != -1 && ((lnbSize _listBox) select 0) > 0) then {
			_index = lnbValue[_listBox, [_index, 0]]; //--- Retrieve the real index.

			//--- [DEFAULT] sentinel: restore factory loadout at no cost.
			if (_index == -1) then {
				private ["_vType","_currentSetup","_currentLoadout","_defaultLoadout"];
				_vType = (missionNamespace getVariable 'WFBE_EASA_Vehicles') find (typeOf (vehicle player));
				if (_vType != -1) then {
					_currentSetup = (vehicle player) getVariable ['WFBE_EASA_Setup', -2];
					_defaultLoadout = (missionNamespace getVariable 'WFBE_EASA_Default') select _vType;
					if (_currentSetup != -2) then {
						_currentLoadout = (((missionNamespace getVariable 'WFBE_EASA_Loadouts') select _vType) select _currentSetup) select 2;
						[vehicle player, _currentLoadout] Call EASA_RemoveLoadout;
					} else {
						//--- No EASA setup means the FACTORY weapons are still mounted: strip them
						//--- before re-adding, or the default loadout double-stacks (mirrors EASA_Equip.sqf).
						[vehicle player, _defaultLoadout] Call EASA_RemoveLoadout;
					};
					if ((typeOf (vehicle player)) == "AW159_Lynx_BAF") then {
						{(vehicle player) addMagazineTurret [_x, [-1]]} forEach (_defaultLoadout select 1);
						{(vehicle player) addWeaponTurret [_x, [-1]]} forEach (_defaultLoadout select 0);
					} else {
						{(vehicle player) addMagazine _x} forEach (_defaultLoadout select 1);
						{(vehicle player) addWeapon _x} forEach (_defaultLoadout select 0);
					};
					(vehicle player) setVariable ["WFBE_EASA_Setup", nil, true];
					hint "Factory loadout restored.";
				};
				closeDialog 0;
			} else {

			_row = _data select _index; //--- Get the row from the data array.
			_canUseEASA = true;
			if (_repairPointEASA) then {
				_canUseEASA = false;
				if (time - WFBE_SK_V_LastUse_RepairPointEASA <= WFBE_SK_V_Reload_RepairPointEASA) then {
					hint Format ["Repair point EASA is cooling down. Wait %1 seconds.", ceil(WFBE_SK_V_Reload_RepairPointEASA - (time - WFBE_SK_V_LastUse_RepairPointEASA))];
					closeDialog 0;
				} else {
					if !(isNil "WFBE_CL_FNC_CanUseRepairPointEASA") then {
						_canUseEASA = [player, vehicle player] Call WFBE_CL_FNC_CanUseRepairPointEASA;
					};
				};
				if (!_canUseEASA && dialog) then {
					hint "Only Engineers can use EASA at repair-truck service points.";
					closeDialog 0;
				};
			};
			if (_canUseEASA) then {
				if (_funds >= (_row select 0)) then {
					[vehicle player, _index, true] Call EASA_Equip;
					-(_row select 0) Call ChangePlayerFunds;
					if (_repairPointEASA) then {
						WFBE_SK_V_LastUse_RepairPointEASA = time;
						WFBE_CL_V_RepairPointEASAActive = false;
					};
					hint parseText(Format[localize 'STR_WF_INFO_EASA_Purchase', _row select 1]);
					closeDialog 0;
				} else {
					hint parseText(Format[localize 'STR_WF_INFO_Funds_Missing',(_row select 0) - _funds, _row select 1]);
				};
			};
			}; //--- end else (normal purchase path)
		};
	};
};
