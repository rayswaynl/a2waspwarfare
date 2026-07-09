disableSerialization;

private ["_display","_units","_upgLevel","_presets","_i","_slot","_preset","_badge","_desc","_finalNumber","_isInVehicle","_descVehi","_targetUnit","_vehicle","_liveCrew","_destroy","_hitPoints","_hitCfg","_hitName","_curUnitSel","_need_save","_tier","_topTier","_weapons","_mags","_bp","_bpContent","_combo","_x","_crewList","_repairTimer","_udTemplates","_udActive","_udSlotIdx","_udTemplate","_udWList","_udMList","_udBpCls","_udBpCnt","_udWpCombined","_udCleanWeps","_udCleanMags","_udCleanBp","_udCleanBpCnt","_udCost","_udItem","_udNameIDCs","_udActiveIDCs","_udPresetIDCs","_udUDIDCs","_udSN","_udSW","_udSWItem"];

_display = _this select 0;
MenuAction = -1;
_need_save = false;

//--- Income readout.
ctrlSetText [13010, Format [localize "STR_WF_Income", Call GetPlayerFunds, (sideJoined) Call GetIncome]];

//--- FX / vote-popup / high-climb initial state (kept from V1).
if (votePopUp) then {
	ctrlSetText [13019, localize "STR_WF_VOTING_PopUpOffButton"];
} else {
	ctrlSetText [13019, localize "STR_WF_VOTING_PopUpOnButton"];
};
if (missionNamespace getVariable ["WFBE_HighClimbingDefaultEnabled", false]) then {
	ctrlSetText [13020, localize "STR_WF_TEAM_HighClimbingDefaultOn"];
} else {
	ctrlSetText [13020, localize "STR_WF_TEAM_HighClimbingDefaultOff"];
};
{lbAdd [13018, _x]} forEach ["None","FX 1","FX 2","FX 3","FX 4","FX 5"];
lbSetCurSel [13018, currentFX];

//--- Gear tier gate level.
_upgLevel = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_GEAR;
if ((sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {_upgLevel = 99};

//--- WFBE_TM2_Presets: array of 4 slots, each slot is [] or [weapons,mags,bp,bpContent,[p,s,l]].
//--- Loaded in Init_ProfileVariables.sqf from profileNamespace; we work with a local copy.
_presets = missionNamespace getVariable ["WFBE_TM2_Presets", [[],[],[],[]]];
if (count _presets != 4) then {_presets = [[],[],[],[]]};

//--- Helper: compute gear badge string from preset slot (_slot = index 0..3).
//--- Returns "---" for empty slot, or "[T0]".."[T4]" for highest tier item in the preset.
//--- We compute once per refresh; wfbe_custom_gear format: [weapons,mags,bp,bpContent,[p,s,l]].
//--- Item data lookup: missionNamespace getVariable classname -> [icon,name,cost,tier,...].
//--- We check every weapon + backpack classname found in the slot for their registered tier.

//--- Fill unit combo (squad AI only, no player).
_units = ((units group player) Call GetLiveUnits) - [player];
{
	_desc = [typeOf _x, 'displayName'] Call GetConfigInfo;
	_finalNumber = (_x) Call GetAIDigit;
	_isInVehicle = "";
	if (_x != vehicle _x) then {
		_descVehi = [typeOf (vehicle _x), 'displayName'] Call GetConfigInfo;
		_isInVehicle = " [" + _descVehi + "] ";
	};
	//--- Out-of-fuel hint: mark units in low-fuel owned vehicles.
	private ["_fuelHint"];
	_fuelHint = "";
	if (_x != vehicle _x) then {
		if ((fuel (vehicle _x)) < 0.05) then {_fuelHint = " [NO FUEL]"};
	};
	lbAdd [13071, "[" + _finalNumber + "] " + _desc + _isInVehicle + _fuelHint];
} forEach _units;
lbSetCurSel [13071, 0];

//--- Local helper: compute badge for a preset slot array.
//--- Returns string: "---" empty, "[T0]".."[T4]" otherwise.

//--- Badge refresh sub (run on open + after save).
//--- IDC badge controls: slots 1-4 = IDC 13051, 13055, 13059, 13063.
private ["_badgeIDCs"];
_badgeIDCs = [13051, 13055, 13059, 13063];

{
	_slot = _presets select _forEachIndex;
	_badge = "---";
	if (count _slot > 0) then {
		_topTier = 0;
		//--- weapons array (index 0), backpack classname (index 2).
		private ["_slotWeps","_slotBp","_itemData","_itemTier"];
		_slotWeps = _slot select 0;
		_slotBp   = _slot select 2;
		{
			_itemData = missionNamespace getVariable _x;
			if !(isNil "_itemData") then {
				_itemTier = _itemData select 3;
				if (_itemTier > _topTier) then {_topTier = _itemTier};
			};
		} forEach _slotWeps;
		if (_slotBp != "") then {
			_itemData = missionNamespace getVariable _slotBp;
			if !(isNil "_itemData") then {
				_itemTier = _itemData select 3;
				if (_itemTier > _topTier) then {_topTier = _itemTier};
			};
		};
		_badge = "[T" + str _topTier + "]";
	};
	ctrlSetText [_badgeIDCs select _forEachIndex, _badge];
} forEach _presets;

//--- Helper macro: apply/rebuy button grey-out based on tier gate + slot content.
//--- Apply IDCs: 13053 13057 13061 13065 | Save IDCs: 13052 13056 13060 13064 | Rebuy IDCs: 13054 13058 13062 13066.
private ["_applyIDCs","_rebuyIDCs"];
_applyIDCs = [13053, 13057, 13061, 13065];
_rebuyIDCs = [13054, 13058, 13062, 13066];

{
	_slot = _presets select _forEachIndex;
	private ["_isEmpty","_topTier2","_canApply"];
	_isEmpty = (count _slot == 0);
	_topTier2 = 0;
	if (!_isEmpty) then {
		private ["_sw","_sb","_id","_it"];
		_sw = _slot select 0;
		_sb = _slot select 2;
		{
			_id = missionNamespace getVariable _x;
			if !(isNil "_id") then {
				_it = _id select 3;
				if (_it > _topTier2) then {_topTier2 = _it};
			};
		} forEach _sw;
		if (_sb != "") then {
			_id = missionNamespace getVariable _sb;
			if !(isNil "_id") then {
				_it = _id select 3;
				if (_it > _topTier2) then {_topTier2 = _it};
			};
		};
	};
	_canApply = (!_isEmpty) && {_topTier2 <= _upgLevel};
	ctrlEnable [_applyIDCs select _forEachIndex, _canApply];
	ctrlEnable [_rebuyIDCs select _forEachIndex, _canApply];
} forEach _presets;

//--- ============================================================
//--- Main event loop.
//--- ============================================================
//--- ── UNIT DESIGNER init (WFBE_C_UNIT_DESIGNER, default 1) ────────────────
//--- Tab buttons (IDC 13080-13081) + UD controls (IDC 13100-13117) hidden on open.
//--- Presets tab is shown by default.
_udPresetIDCs = [13049,13051,13052,13053,13054,13055,13056,13057,13058,13059,13060,13061,13062,13063,13064,13065,13066];
_udUDIDCs     = [13100,13101,13102,13103,13104,13105,13106,13107,13108,13109,13110,13111,13112,13113,13114,13115,13116,13117];
{(_display displayCtrl _x) ctrlShow false} forEach ([13080,13081] + _udUDIDCs);
if ((missionNamespace getVariable ["WFBE_C_UNIT_DESIGNER", 1]) > 0) then {
	(_display displayCtrl 13080) ctrlShow true;
	(_display displayCtrl 13081) ctrlShow true;
	_udTemplates = missionNamespace getVariable ["WFBE_UD_Templates", [[],[],[],[]]];
	_udActive    = missionNamespace getVariable ["WFBE_UD_Active", -1];
	_udNameIDCs   = [13102,13106,13110,13114];
	_udActiveIDCs = [13104,13108,13112,13116];
	{
		_udTemplate = _udTemplates select _forEachIndex;
		_udSN = "--- Slot " + str (_forEachIndex + 1) + " empty ---";
		if (count _udTemplate > 0) then {
			_udSW = _udTemplate select 0;
			if (count _udSW > 0) then {
				_udSWItem = missionNamespace getVariable (_udSW select 0);
				if !(isNil "_udSWItem") then {
					_udSN = "Slot " + str (_forEachIndex + 1) + ": " + (_udSWItem select 1);
				} else {
					_udSN = "Slot " + str (_forEachIndex + 1) + ": (custom)";
				};
			};
		};
		ctrlSetText [_udNameIDCs select _forEachIndex, _udSN];
		if (_forEachIndex == _udActive) then {
			ctrlSetText [_udActiveIDCs select _forEachIndex, "* Active " + str (_forEachIndex + 1)];
		} else {
			ctrlSetText [_udActiveIDCs select _forEachIndex, "Activate " + str (_forEachIndex + 1)];
		};
	} forEach _udTemplates;
	if (_udActive >= 0 && {_udActive <= 3}) then {
		(_display displayCtrl 13101) ctrlSetText Format ["Active: Slot %1  (template applied on AI buys)", _udActive + 1];
	} else {
		(_display displayCtrl 13101) ctrlSetText "Active: None  (no template applied on AI buys)";
	};
	//--- fable/respawn-menu-shortcuts (owner 2026-07-09): "Customise AI Soldier" respawn-menu
	//--- button sets WFBE_TM2_OpenToUD before createDialog - jump straight to the Unit
	//--- Designer tab on open. Mirrors the exact show/hide toggle the Units tab button
	//--- already uses (MenuAction 1200 below). No-op whenever Team Menu is opened any other
	//--- way (WFBE_TM2_OpenToUD stays nil).
	if (!(isNil "WFBE_TM2_OpenToUD") && {WFBE_TM2_OpenToUD}) then {
		WFBE_TM2_OpenToUD = nil;
		{(_display displayCtrl _x) ctrlShow false} forEach _udPresetIDCs;
		{(_display displayCtrl _x) ctrlShow true } forEach _udUDIDCs;
	};
};

_repairTimer = 0; //--- used to pace the "repair in progress" hint.

while {alive player && dialog} do {
	sleep 0.05;

	if (side group player != sideJoined) exitWith {closeDialog 0};
	if (!dialog) exitWith {};

	//--- Periodic income readout refresh (every ~2s).
	_repairTimer = _repairTimer + 0.05;
	if (_repairTimer > 2) then {
		ctrlSetText [13010, Format [localize "STR_WF_Income", Call GetPlayerFunds, (sideJoined) Call GetIncome]];
		_repairTimer = 0;
	};

	//--- ── GEAR PRESET SAVE (slots 1-4 = MenuAction 1001-1004) ──────────────────
	if (MenuAction >= 1001 && {MenuAction <= 1004}) then {
		private ["_slotIdx","_gear","_saveOk"];
		_slotIdx = MenuAction - 1001; //--- 0..3
		MenuAction = -1;
		_gear = player getVariable "wfbe_custom_gear";
		_saveOk = false;
		if !(isNil "_gear") then {
			if (typeName _gear == "ARRAY" && {count _gear == 5}) then {
				_presets set [_slotIdx, +_gear]; //--- deep copy
				_saveOk = true;
			};
		};
		if (!_saveOk) then {
			hint Format ["Slot %1: no gear purchased yet. Buy a loadout first.", _slotIdx + 1];
		} else {
			//--- Save to profileNamespace.
			missionNamespace setVariable ["WFBE_TM2_Presets", _presets];
			if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
				[Format ["WFBE_PERSISTENT_TM2_PRESETS_%1", WFBE_Client_SideJoinedText], _presets] Call WFBE_CO_FNC_SetProfileVariable;
				_need_save = true;
			} else {
				profileNamespace setVariable [Format ["WFBE_PERSISTENT_TM2_PRESETS_%1", WFBE_Client_SideJoinedText], _presets];
				saveProfileNamespace;
			};
			//--- Refresh badges and button state.
			{
				private ["_s2","_b2","_t2","_sw2","_sb2","_id2","_it2","_ca2"];
				_s2 = _presets select _forEachIndex;
				_b2 = "---";
				if (count _s2 > 0) then {
					_t2 = 0;
					_sw2 = _s2 select 0;
					_sb2 = _s2 select 2;
					{_id2 = missionNamespace getVariable _x; if !(isNil "_id2") then {_it2 = _id2 select 3; if (_it2 > _t2) then {_t2 = _it2}}} forEach _sw2;
					if (_sb2 != "") then {_id2 = missionNamespace getVariable _sb2; if !(isNil "_id2") then {_it2 = _id2 select 3; if (_it2 > _t2) then {_t2 = _it2}}};
					_b2 = "[T" + str _t2 + "]";
					_ca2 = (_t2 <= _upgLevel);
					ctrlEnable [_applyIDCs select _forEachIndex, _ca2];
					ctrlEnable [_rebuyIDCs select _forEachIndex, _ca2];
				} else {
					ctrlEnable [_applyIDCs select _forEachIndex, false];
					ctrlEnable [_rebuyIDCs select _forEachIndex, false];
				};
				ctrlSetText [_badgeIDCs select _forEachIndex, _b2];
			} forEach _presets;
			hint Format ["Preset %1 saved.", _slotIdx + 1];
		};
	};

	//--- ── GEAR PRESET APPLY (slots 1-4 = MenuAction 1011-1014) ─────────────────
	if (MenuAction >= 1011 && {MenuAction <= 1014}) then {
		private ["_slotIdx2","_gear2","_upgNow","_topT","_sw3","_sb3","_id3","_it3"];
		_slotIdx2 = MenuAction - 1011;
		MenuAction = -1;
		_gear2 = _presets select _slotIdx2;
		if (count _gear2 == 0) exitWith {hint Format ["Slot %1 is empty.", _slotIdx2 + 1]};
		//--- Re-check tier gate at apply time.
		_upgNow = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_GEAR;
		if ((sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {_upgNow = 99};
		_topT = 0;
		_sw3 = _gear2 select 0;
		_sb3 = _gear2 select 2;
		{_id3 = missionNamespace getVariable _x; if !(isNil "_id3") then {_it3 = _id3 select 3; if (_it3 > _topT) then {_topT = _it3}}} forEach _sw3;
		if (_sb3 != "") then {_id3 = missionNamespace getVariable _sb3; if !(isNil "_id3") then {_it3 = _id3 select 3; if (_it3 > _topT) then {_topT = _it3}}};
		if (_topT > _upgNow) exitWith {hint Format ["Slot %1 requires gear tier %2 (you have %3). Upgrade first.", _slotIdx2 + 1, _topT, _upgNow]};
		//--- Validate classnames against the item registry; reject non-strings and unknowns.
		//--- Collect clean weapons / mags / bp from the preset, skipping anything not in the registry.
		private ["_wList","_mList","_bpCls","_bpCnt","_wpCombined","_cleanWeps","_cleanMags","_cleanBp","_dItem"];
		_wList      = _gear2 select 0;
		_mList      = _gear2 select 1;
		_bpCls      = _gear2 select 2;
		_bpCnt      = _gear2 select 3;
		_wpCombined = _gear2 select 4; //--- [primary, pistol, secondary]
		//--- Weapons: keep only registered strings.
		_cleanWeps = [];
		{
			if (typeName _x == "STRING") then {
				_dItem = missionNamespace getVariable _x;
				if !(isNil "_dItem") then {_cleanWeps = _cleanWeps + [_x]};
			};
		} forEach _wList;
		//--- Magazines: keep only registered strings.
		_cleanMags = [];
		{
			if (typeName _x == "STRING") then {
				_dItem = missionNamespace getVariable ("Mag_" + _x);
				if !(isNil "_dItem") then {_cleanMags = _cleanMags + [_x]};
			};
		} forEach _mList;
		//--- Backpack: validate string + registered.
		_cleanBp = _bpCls;
		if (_bpCls != "") then {
			if (typeName _bpCls != "STRING") then {_cleanBp = ""} else {
				_dItem = missionNamespace getVariable _bpCls;
				if (isNil "_dItem") then {_cleanBp = ""};
			};
		};
		//--- Compute preset price from item registry (no BuyGear dialog dependency).
		//--- Weapons: look up by classname; Magazines: use "Mag_" prefix; Backpack + contents: same.
		private ["_presetCost","_costItem"];
		_presetCost = 0;
		{
			_costItem = missionNamespace getVariable _x;
			if !(isNil "_costItem") then {_presetCost = _presetCost + (_costItem select 2)};
		} forEach _cleanWeps;
		{
			_costItem = missionNamespace getVariable ("Mag_" + _x);
			if !(isNil "_costItem") then {_presetCost = _presetCost + (_costItem select 2)};
		} forEach _cleanMags;
		if (_cleanBp != "") then {
			_costItem = missionNamespace getVariable _cleanBp;
			if !(isNil "_costItem") then {_presetCost = _presetCost + (_costItem select 2)};
		};
		//--- Backpack contents pricing: _bpCnt = [[bpWeaponNames,bpWeaponCounts],[bpMagNames,bpMagCounts]].
		//--- k=0 prefix "" (bp weapons), k=1 prefix "Mag_" (bp mags), matching Client_UI_Gear_UpdatePrice.sqf.
		if !(WF_A2_Vanilla) then {
			if (typeName _bpCnt == "ARRAY" && {count _bpCnt >= 2}) then {
				private ["_bpK","_bpKNames","_bpKCounts","_bpKPrefix","_bpKi","_bpKItem"];
				_bpKPrefix = "";
				for "_bpK" from 0 to 1 do {
					_bpKNames  = (_bpCnt select _bpK) select 0;
					_bpKCounts = (_bpCnt select _bpK) select 1;
					for "_bpKi" from 0 to ((count _bpKNames) - 1) do {
						if (typeName (_bpKNames select _bpKi) == "STRING") then {
							_bpKItem = missionNamespace getVariable (_bpKPrefix + (_bpKNames select _bpKi));
							if !(isNil "_bpKItem") then {_presetCost = _presetCost + ((_bpKItem select 2) * (_bpKCounts select _bpKi))};
						};
					};
					_bpKPrefix = "Mag_";
				};
			};
		};
		//--- Build cleaned _bpCnt: filter each sub-array against the item registry.
		//--- Prevents injected classnames in a hand-edited profile from reaching EquipUnit.
		private ["_cleanBpCnt","_cbpK","_cbpNames","_cbpCounts","_cbpCleanNames","_cbpCleanCounts","_cbpPrefix","_cbpI","_cbpItem"];
		_cleanBpCnt = [];
		if (typeName _bpCnt == "ARRAY" && {count _bpCnt >= 2}) then {
			_cbpPrefix = "";
			for "_cbpK" from 0 to 1 do {
				_cbpNames  = (_bpCnt select _cbpK) select 0;
				_cbpCounts = (_bpCnt select _cbpK) select 1;
				_cbpCleanNames  = [];
				_cbpCleanCounts = [];
				for "_cbpI" from 0 to ((count _cbpNames) - 1) do {
					if (typeName (_cbpNames select _cbpI) == "STRING") then {
						_cbpItem = missionNamespace getVariable (_cbpPrefix + (_cbpNames select _cbpI));
						if !(isNil "_cbpItem") then {
							_cbpCleanNames  = _cbpCleanNames  + [_cbpNames  select _cbpI];
							_cbpCleanCounts = _cbpCleanCounts + [_cbpCounts select _cbpI];
						};
					};
				};
				_cleanBpCnt = _cleanBpCnt + [[_cbpCleanNames, _cbpCleanCounts]];
				_cbpPrefix = "Mag_";
			};
		} else {
			_cleanBpCnt = _bpCnt;
		};
		//--- Check funds before equipping (Apply = buy the loadout now).
		if ((Call GetPlayerFunds) < _presetCost) exitWith {
			hint Format ["Preset %1: insufficient funds ($%2 needed, $%3 available).", _slotIdx2 + 1, _presetCost, Call GetPlayerFunds];
		};
		//--- Charge funds (same idiom as GUI_BuyGearMenu.sqf line 484).
		-(_presetCost) Call WFBE_CL_FNC_ChangeClientFunds;
		//--- Apply: equip via WFBE_CO_FNC_EquipUnit (same call as respawn path).
		//--- EquipUnit signature: [unit, weapons, magazines, weaponCombined, backpack, backpackContent].
		[player, _cleanWeps, _cleanMags, _wpCombined, _cleanBp, _cleanBpCnt] Call WFBE_CO_FNC_EquipUnit;
		//--- Write wfbe_custom_gear with cleaned arrays so respawn handler receives only valid classnames.
		player setVariable ["wfbe_custom_gear", [_cleanWeps, _cleanMags, _cleanBp, _cleanBpCnt, _wpCombined]];
		player setVariable ["wfbe_custom_gear_cost", _presetCost];
		hint Format ["Preset %1 applied ($%2 charged).", _slotIdx2 + 1, _presetCost];
	};

	//--- ── GEAR PRESET REBUY (set as rebuy-on-death kit: 1021-1024) ─────────────
	if (MenuAction >= 1021 && {MenuAction <= 1024}) then {
		private ["_slotIdx3","_gear3","_upgNow3","_topT3","_sw4","_sb4","_id4","_it4"];
		_slotIdx3 = MenuAction - 1021;
		MenuAction = -1;
		_gear3 = _presets select _slotIdx3;
		if (count _gear3 == 0) exitWith {hint Format ["Slot %1 is empty.", _slotIdx3 + 1]};
		_upgNow3 = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_GEAR;
		if ((sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {_upgNow3 = 99};
		_topT3 = 0;
		_sw4 = _gear3 select 0;
		_sb4 = _gear3 select 2;
		{_id4 = missionNamespace getVariable _x; if !(isNil "_id4") then {_it4 = _id4 select 3; if (_it4 > _topT3) then {_topT3 = _it4}}} forEach _sw4;
		if (_sb4 != "") then {_id4 = missionNamespace getVariable _sb4; if !(isNil "_id4") then {_it4 = _id4 select 3; if (_it4 > _topT3) then {_topT3 = _it4}}};
		if (_topT3 > _upgNow3) exitWith {hint Format ["Slot %1 requires gear tier %2 (you have %3). Cannot set as rebuy kit.", _slotIdx3 + 1, _topT3, _upgNow3]};
		//--- Validate classnames against the item registry (same pattern as Apply path).
		//--- Prevents injected non-strings/unknown classnames reaching wfbe_custom_gear on the respawn path.
		private ["_rebuyCost","_rcItem","_rwList","_rmList","_rbpCls","_rbpCnt","_rbpWpCombined"];
		private ["_rCleanWeps","_rCleanMags","_rCleanBp","_rDItem"];
		_rwList        = _gear3 select 0;
		_rmList        = _gear3 select 1;
		_rbpCls        = _gear3 select 2;
		_rbpCnt        = _gear3 select 3;
		_rbpWpCombined = _gear3 select 4;
		//--- Weapons: keep only registered strings.
		_rCleanWeps = [];
		{
			if (typeName _x == "STRING") then {
				_rDItem = missionNamespace getVariable _x;
				if !(isNil "_rDItem") then {_rCleanWeps = _rCleanWeps + [_x]};
			};
		} forEach _rwList;
		//--- Magazines: keep only registered strings.
		_rCleanMags = [];
		{
			if (typeName _x == "STRING") then {
				_rDItem = missionNamespace getVariable ("Mag_" + _x);
				if !(isNil "_rDItem") then {_rCleanMags = _rCleanMags + [_x]};
			};
		} forEach _rmList;
		//--- Backpack: validate string + registered.
		_rCleanBp = _rbpCls;
		if (_rbpCls != "") then {
			if (typeName _rbpCls != "STRING") then {_rCleanBp = ""} else {
				_rDItem = missionNamespace getVariable _rbpCls;
				if (isNil "_rDItem") then {_rCleanBp = ""};
			};
		};
		//--- Compute preset cost from validated arrays.
		_rebuyCost = 0;
		{
			_rcItem = missionNamespace getVariable _x;
			if !(isNil "_rcItem") then {_rebuyCost = _rebuyCost + (_rcItem select 2)};
		} forEach _rCleanWeps;
		{
			_rcItem = missionNamespace getVariable ("Mag_" + _x);
			if !(isNil "_rcItem") then {_rebuyCost = _rebuyCost + (_rcItem select 2)};
		} forEach _rCleanMags;
		if (_rCleanBp != "") then {
			_rcItem = missionNamespace getVariable _rCleanBp;
			if !(isNil "_rcItem") then {_rebuyCost = _rebuyCost + (_rcItem select 2)};
		};
		//--- Backpack contents pricing: _rbpCnt = [[bpWeaponNames,bpWeaponCounts],[bpMagNames,bpMagCounts]].
		//--- k=0 prefix "" (bp weapons), k=1 prefix "Mag_" (bp mags).
		private ["_rCleanBpCnt","_rbpK","_rbpKNames","_rbpKCounts","_rbpKPrefix","_rbpKi","_rbpKItem"];
		private ["_rcbpCleanNames","_rcbpCleanCounts"];
		_rCleanBpCnt = [];
		if !(WF_A2_Vanilla) then {
			if (typeName _rbpCnt == "ARRAY" && {count _rbpCnt >= 2}) then {
				_rbpKPrefix = "";
				for "_rbpK" from 0 to 1 do {
					_rbpKNames  = (_rbpCnt select _rbpK) select 0;
					_rbpKCounts = (_rbpCnt select _rbpK) select 1;
					_rcbpCleanNames  = [];
					_rcbpCleanCounts = [];
					for "_rbpKi" from 0 to ((count _rbpKNames) - 1) do {
						if (typeName (_rbpKNames select _rbpKi) == "STRING") then {
							_rbpKItem = missionNamespace getVariable (_rbpKPrefix + (_rbpKNames select _rbpKi));
							if !(isNil "_rbpKItem") then {
								_rebuyCost = _rebuyCost + ((_rbpKItem select 2) * (_rbpKCounts select _rbpKi));
								_rcbpCleanNames  = _rcbpCleanNames  + [_rbpKNames  select _rbpKi];
								_rcbpCleanCounts = _rcbpCleanCounts + [_rbpKCounts select _rbpKi];
							};
						};
					};
					_rCleanBpCnt = _rCleanBpCnt + [[_rcbpCleanNames, _rcbpCleanCounts]];
					_rbpKPrefix = "Mag_";
				};
			} else {
				_rCleanBpCnt = _rbpCnt;
			};
		} else {
			_rCleanBpCnt = _rbpCnt;
		};
		//--- Set wfbe_custom_gear with cleaned arrays; respawn handler reads these on death.
		player setVariable ["wfbe_custom_gear", [_rCleanWeps, _rCleanMags, _rCleanBp, _rCleanBpCnt, _rbpWpCombined]];
		player setVariable ["wfbe_custom_gear_cost", _rebuyCost];
		hint Format ["Preset %1 set as rebuy-on-death kit (cost: $%2).", _slotIdx3 + 1, _rebuyCost];
	};

	//--- ── SQUAD: DISBAND (MenuAction 3 — reuses existing disband logic from V1) ──
	if (MenuAction == 3) then {
		MenuAction = -1;
		titleText [localize "STR_WF_TEAM_MapShortcutDisbandTip", "PLAIN DOWN", 3];
		_curUnitSel = lbCurSel 13071;
		if (_curUnitSel != -1) then {
			private ["_tgt","_veh2","_lc2","_des2"];
			_tgt  = _units select _curUnitSel;
			_veh2 = vehicle _tgt;
			_des2 = [_tgt];
			if (_veh2 != _tgt) then {
				_lc2 = [];
				{
					if (alive _x || isPlayer _x) then {
						if (_x != _tgt) then {_lc2 = _lc2 + [_x]};
					};
				} forEach crew _veh2;
				if (count _lc2 == 0) then {_des2 = _des2 + [_veh2]};
			};
			{
				if !(isPlayer _x) then {
					if (_x isKindOf 'Man') then {removeAllWeapons _x};
					_x setDammage 1;
				};
			} forEach _des2;
			//--- Refresh unit combo.
			_units = ((units group player) Call GetLiveUnits) - [player];
			lbClear 13071;
			{
				private ["_d2","_fn2","_iv2","_dv2","_fh2"];
				_d2  = [typeOf _x, 'displayName'] Call GetConfigInfo;
				_fn2 = (_x) Call GetAIDigit;
				_iv2 = "";
				_fh2 = "";
				if (_x != vehicle _x) then {
					_dv2 = [typeOf (vehicle _x), 'displayName'] Call GetConfigInfo;
					_iv2 = " [" + _dv2 + "] ";
					if ((fuel (vehicle _x)) < 0.05) then {_fh2 = " [NO FUEL]"};
				};
				lbAdd [13071, "[" + _fn2 + "] " + _d2 + _iv2 + _fh2];
			} forEach _units;
			lbSetCurSel [13071, 0];
		};
	};

	//--- ── SQUAD: EJECT (MenuAction 2001) ───────────────────────────────────────
	if (MenuAction == 2001) then {
		MenuAction = -1;
		_curUnitSel = lbCurSel 13071;
		if (_curUnitSel != -1 && {_curUnitSel < count _units}) then {
			private ["_ejUnit","_ejVeh"];
			_ejUnit = _units select _curUnitSel;
			_ejVeh  = vehicle _ejUnit;
			if (_ejVeh != _ejUnit) then {
				//--- Eject: action on the unit itself. Local only - works for HC-owned crew too (unit is local on HC).
				_ejUnit action ["Eject", _ejVeh];
				hint Format ["Ejecting %1 from %2.", [typeOf _ejUnit, 'displayName'] Call GetConfigInfo, [typeOf _ejVeh, 'displayName'] Call GetConfigInfo];
			} else {
				hint "Unit is not in a vehicle.";
			};
		};
	};

	//--- ── SQUAD: GET-OUT-AND-REPAIR (MenuAction 2002) ──────────────────────────
	//--- All crew of the selected unit's vehicle dismount, repair mobility-only
	//--- hitpoints (wheels/tracks/engine), then remount.
	//--- INTENTIONALLY FREE: field-recovery QoL, not a purchase (no WFBE_CL_FNC_ChangeClientFunds call).
	if (MenuAction == 2002) then {
		MenuAction = -1;
		_curUnitSel = lbCurSel 13071;
		if (_curUnitSel != -1 && {_curUnitSel < count _units}) then {
			private ["_repUnit","_repVeh"];
			_repUnit = _units select _curUnitSel;
			_repVeh  = vehicle _repUnit;
			if (_repVeh == _repUnit) exitWith {hint "Unit is not in a vehicle."};
			if (_repVeh getVariable ["wfbe_tm2_repair_lock", false]) exitWith {hint "Repair already in progress on this vehicle."};
			_repVeh setVariable ["wfbe_tm2_repair_lock", true, true]; //--- sweep-fix #932: broadcast so other clients see the lock (was local-only -> cross-client double-repair race).
			closeDialog 0;
			//--- Spawn so the dialog can close cleanly before the sleep-loop runs.
			[_repVeh, _units] Spawn {
				private ["_rv","_sqUnits","_crewList","_cu","_hp","_hpCfg","_hn","_repTime","_j"];
				_rv       = _this select 0;
				_sqUnits  = _this select 1;
				_crewList = crew _rv;
				//--- Dismount crew (AI only — do not eject the player).
				{
					if !(isPlayer _x) then {
						_x action ["GetOut", _rv];
					};
				} forEach _crewList;
				sleep 2;
				hint "Crew dismounted. Repairing mobility...";
				//--- Mobility-only repair: wheels/tracks/engine hitpoints only.
				_repTime = 8;
				_j = 0;
				while {_j < _repTime} do {
					sleep 1;
					_j = _j + 1;
				};
				_hp = configFile >> "CfgVehicles" >> (typeOf _rv) >> "HitPoints";
				if (isClass _hp && {(count _hp) > 0}) then {
					for "_hi" from 0 to ((count _hp) - 1) do {
						_hpCfg = _hp select _hi;
						_hn = getText (_hpCfg >> "name");
						//--- Only fix mobility hitpoints: wheel/track/engine/motor.
						if ((_hn != "") && {((_hn find "wheel") >= 0) || {((_hn find "track") >= 0) || {((_hn find "engine") >= 0) || {(_hn find "motor") >= 0}}}}) then {
							_rv setHit [_hn, 0];
						};
					};
				};
				hint "Mobility restored. Remounting...";
				sleep 2;
				//--- Remount: role-based seats (moveInAny is A3-only; use moveInDriver/moveInGunner/moveInCargo).
				if (!isNull _rv && {alive _rv}) then {
					private ["_mu","_mounted"];
					_mounted = 0;
					{
						_mu = _x;
						if (alive _mu && !(isPlayer _mu) && (vehicle _mu == _mu)) then {
							[_mu] allowGetIn true;
							if (isNull (driver _rv)) then {
								_mu moveInDriver _rv;
								_mounted = _mounted + 1;
							} else {
								if (isNull (gunner _rv)) then {
									_mu moveInGunner _rv;
									_mounted = _mounted + 1;
								} else {
									if (_rv emptyPositions "cargo" > 0) then {
										_mu moveInCargo _rv;
										_mounted = _mounted + 1;
									};
								};
							};
						};
					} forEach _crewList;
					if (_mounted > 0) then {
						hint "Crew remounted.";
					} else {
						hint "Crew dismounted — no free seats to remount.";
					};
				} else {
					hint "Vehicle lost during repair — remount aborted.";
				};
				if (!isNull _rv) then {_rv setVariable ["wfbe_tm2_repair_lock", false, true]};
			};
		};
	};

	//--- ── FX / vote / high-climb (same as V1) ─────────────────────────────────
	if (MenuAction == 6) then {
		MenuAction = -1;
		currentFX = lbCurSel 13018;
		[currentFX] Spawn FX;
	};

	if (MenuAction == 13) then {
		MenuAction = -1;
		if (votePopUp) then {
			votePopUp = false;
			ctrlSetText [13019, localize "STR_WF_VOTING_PopUpOnButton"];
		} else {
			votePopUp = true;
			ctrlSetText [13019, localize "STR_WF_VOTING_PopUpOffButton"];
		};
	};

	if (MenuAction == 14) then {
		MenuAction = -1;
		WFBE_HighClimbingDefaultEnabled = !(missionNamespace getVariable ["WFBE_HighClimbingDefaultEnabled", false]);
		missionNamespace setVariable ["WFBE_HighClimbingDefaultEnabled", WFBE_HighClimbingDefaultEnabled];
		if (WFBE_HighClimbingDefaultEnabled) then {
			ctrlSetText [13020, localize "STR_WF_TEAM_HighClimbingDefaultOn"];
		} else {
			ctrlSetText [13020, localize "STR_WF_TEAM_HighClimbingDefaultOff"];
		};
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
			["WFBE_HIGH_CLIMBING_DEFAULT_ENABLED", WFBE_HighClimbingDefaultEnabled] Call WFBE_CO_FNC_SetProfileVariable;
			_need_save = true;
		} else {
			profileNamespace setVariable ["WFBE_HIGH_CLIMBING_DEFAULT_ENABLED", WFBE_HighClimbingDefaultEnabled];
			saveProfileNamespace;
		};
	};

	//--- ── TRANSFER FUNDS (MenuAction 101 — reuses V1's advanced transfer dialog) ──
	//--- V2 dropped the inline money-transfer controls (see the Dialogs.hpp comment on
	//--- RscMenu_TeamV2) and never re-added an entry point (DIAG-WFMENU-UX finding #2).
	//--- Re-wires the EXISTING WFBE_TransferMenu dialog + its ChangeTeamFunds /
	//--- ChangePlayerFunds backend -- same MenuAction code and same createDialog call
	//--- as V1's GUI_Menu_Team.sqf MenuAction==101 handler. No transfer logic here.
	if (MenuAction == 101) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "WFBE_TransferMenu";
	};

	//--- ── BACK (MenuAction 8) ──────────────────────────────────────────────────

	//--- ── UNIT DESIGNER handlers (WFBE_C_UNIT_DESIGNER) ──────────────────────
	if ((missionNamespace getVariable ["WFBE_C_UNIT_DESIGNER", 1]) > 0) then {

		//--- Tab switch: Presets (1100) / Units (1200).
		if (MenuAction == 1100) then {
			MenuAction = -1;
			{(_display displayCtrl _x) ctrlShow true } forEach _udPresetIDCs;
			{(_display displayCtrl _x) ctrlShow false} forEach _udUDIDCs;
		};
		if (MenuAction == 1200) then {
			MenuAction = -1;
			{(_display displayCtrl _x) ctrlShow false} forEach _udPresetIDCs;
			{(_display displayCtrl _x) ctrlShow true } forEach _udUDIDCs;
		};

		//--- UD Save (2101-2104): capture player loadout into template slot.
		if (MenuAction >= 2101 && {MenuAction <= 2104}) then {
			_udSlotIdx = MenuAction - 2101;
			MenuAction = -1;
			_udTemplates = missionNamespace getVariable ["WFBE_UD_Templates", [[],[],[],[]]];
			_udWList = player getVariable "wfbe_custom_gear";
			if (isNil "_udWList") then {
				hint Format ["UD Slot %1: no loadout to save. Buy a loadout first.", _udSlotIdx + 1];
			} else {
				if (typeName _udWList == "ARRAY" && {count _udWList == 5}) then {
					_udTemplates set [_udSlotIdx, +_udWList];
					missionNamespace setVariable ["WFBE_UD_Templates", _udTemplates];
					if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
						[Format ["WFBE_PERSISTENT_UD_TEMPLATES_%1", WFBE_Client_SideJoinedText], _udTemplates] Call WFBE_CO_FNC_SetProfileVariable;
						_need_save = true;
					} else {
						profileNamespace setVariable [Format ["WFBE_PERSISTENT_UD_TEMPLATES_%1", WFBE_Client_SideJoinedText], _udTemplates];
						saveProfileNamespace;
					};
					_udNameIDCs = [13102,13106,13110,13114];
					_udTemplate = _udTemplates select _udSlotIdx;
					_udSN = "Slot " + str (_udSlotIdx + 1) + ": (custom)";
					_udSW = _udTemplate select 0;
					if (count _udSW > 0) then {
						_udSWItem = missionNamespace getVariable (_udSW select 0);
						if !(isNil "_udSWItem") then {_udSN = "Slot " + str (_udSlotIdx + 1) + ": " + (_udSWItem select 1)};
					};
					ctrlSetText [_udNameIDCs select _udSlotIdx, _udSN];
					hint Format ["UD Slot %1 saved.", _udSlotIdx + 1];
				} else {
					hint "UD: Invalid loadout format -- buy a loadout via Buy Gear first.";
				};
			};
		};

		//--- UD Activate/toggle (2111-2114): set or clear active template slot.
		if (MenuAction >= 2111 && {MenuAction <= 2114}) then {
			_udSlotIdx = MenuAction - 2111;
			MenuAction = -1;
			_udTemplates = missionNamespace getVariable ["WFBE_UD_Templates", [[],[],[],[]]];
			_udTemplate  = _udTemplates select _udSlotIdx;
			if (count _udTemplate == 0) exitWith {hint Format ["UD Slot %1 is empty -- save a loadout first.", _udSlotIdx + 1]};
			_udActive = missionNamespace getVariable ["WFBE_UD_Active", -1];
			if (_udActive == _udSlotIdx) then {
				_udActive = -1;
			} else {
				_udActive = _udSlotIdx;
			};
			missionNamespace setVariable ["WFBE_UD_Active", _udActive];
			_udActiveIDCs = [13104,13108,13112,13116];
			{
				if (_forEachIndex == _udActive) then {
					ctrlSetText [_udActiveIDCs select _forEachIndex, "* Active " + str (_forEachIndex + 1)];
				} else {
					ctrlSetText [_udActiveIDCs select _forEachIndex, "Activate " + str (_forEachIndex + 1)];
				};
			} forEach _udTemplates;
			if (_udActive >= 0 && {_udActive <= 3}) then {
				(_display displayCtrl 13101) ctrlSetText Format ["Active: Slot %1  (template applied on AI buys)", _udActive + 1];
				hint Format ["UD Slot %1 activated.", _udActive + 1];
			} else {
				(_display displayCtrl 13101) ctrlSetText "Active: None  (no template applied on AI buys)";
				hint "UD: Template deactivated.";
			};
		};

		//--- UD Delete (2121-2124): clear template slot.
		if (MenuAction >= 2121 && {MenuAction <= 2124}) then {
			_udSlotIdx = MenuAction - 2121;
			MenuAction = -1;
			_udTemplates = missionNamespace getVariable ["WFBE_UD_Templates", [[],[],[],[]]];
			_udTemplates set [_udSlotIdx, []];
			missionNamespace setVariable ["WFBE_UD_Templates", _udTemplates];
			_udActive = missionNamespace getVariable ["WFBE_UD_Active", -1];
			if (_udActive == _udSlotIdx) then {
				_udActive = -1;
				missionNamespace setVariable ["WFBE_UD_Active", -1];
			};
			if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
				[Format ["WFBE_PERSISTENT_UD_TEMPLATES_%1", WFBE_Client_SideJoinedText], _udTemplates] Call WFBE_CO_FNC_SetProfileVariable;
				_need_save = true;
			} else {
				profileNamespace setVariable [Format ["WFBE_PERSISTENT_UD_TEMPLATES_%1", WFBE_Client_SideJoinedText], _udTemplates];
				saveProfileNamespace;
			};
			_udNameIDCs = [13102,13106,13110,13114];
			_udActiveIDCs = [13104,13108,13112,13116];
			ctrlSetText [_udNameIDCs select _udSlotIdx, "--- Slot " + str (_udSlotIdx + 1) + " empty ---"];
			ctrlSetText [_udActiveIDCs select _udSlotIdx, "Activate " + str (_udSlotIdx + 1)];
			if (_udActive >= 0 && {_udActive <= 3}) then {
				(_display displayCtrl 13101) ctrlSetText Format ["Active: Slot %1  (template applied on AI buys)", _udActive + 1];
			} else {
				(_display displayCtrl 13101) ctrlSetText "Active: None  (no template applied on AI buys)";
			};
			hint Format ["UD Slot %1 deleted.", _udSlotIdx + 1];
		};

	}; //--- end WFBE_C_UNIT_DESIGNER block

	if (MenuAction == 8) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
};

if (_need_save) then {
	if !(isNil "WFBE_CO_FNC_SaveProfile") then {Call WFBE_CO_FNC_SaveProfile};
};
