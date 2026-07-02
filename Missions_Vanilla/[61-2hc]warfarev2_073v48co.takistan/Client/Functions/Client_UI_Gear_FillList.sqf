/*
	Fill a special ListBox with the gear.
	 Parameters:
		- IDC Listbox
		- Gear
*/

Private ["_gear","_get","_j","_lb","_prefix","_upgrade_level","_values"];
_lb = _this select 0;
_gear = _this select 1;

_upgrade_level = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_GEAR;

//--- GUER-BUYMENU (2026-07-02): playable GUER has NO upgrade system (GetSideUpgrades returns a zero array for
//--- resistance), so the tier filter below permanently hid every item priced above gear level 0 - in practice
//--- ALL rifles (shared classnames like AK_47_M are first-registered by Gear_US/Gear_TKA at tier >= 1, and
//--- Config_Weapons.sqf is first-wins), leaving only the RPG18/Makarov/items subset. The curated
//--- Loadout_GUE/TKGUE list + prices are the real GUER gate: unlock all gear tiers for the playable GUER side.
if ((sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {_upgrade_level = 99};

_j = 0;
for '_i' from 0 to count(_gear)-1 do {
	_values = (_gear select _i) select 0;
	_prefix = if (count (_gear select _i) > 1) then {(_gear select _i) select 1} else {""};
	{
		_get = missionNamespace getVariable Format ["%1%2",_prefix,_x];
		if !(isNil '_get') then {
			if ((_get select 3) <= _upgrade_level) then {
				lnbAddRow[_lb, [Format ["$%1.", _get select 2], _get select 1]];
				lnbSetPicture[_lb,[_j,0],_get select 0];
				lnbSetData[_lb,[_j,0],Format ["%1%2",_prefix,_x]];
				_j = _j + 1;
			};
		} else {
			["ERROR", Format["Client_UI_Gear_FillList.sqf : Weapon/Magazine [%1] is not a valid class (defined in Team_x.sqf files)",_x]] Call WFBE_CO_FNC_LogContent;
		};
	} forEach _values;
};