/*
	Fill a special ListBox with the gear templates.
	 Parameters:
		- IDC Listbox
		- Templates
*/

Private ["_ct","_gear_level","_lb","_template","_u","_upgrade_level"];
_lb = _this select 0;
_template = _this select 1;

_upgrade_level = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
_gear_level = _upgrade_level select WFBE_UP_GEAR;

//--- GUER-BUYMENU (2026-07-02): GUER has no upgrade system (zero array) - show all templates regardless of
//--- tier for the playable GUER side (see Client_UI_Gear_FillList.sqf for the full rationale).
if ((sideJoined == resistance) && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {_gear_level = 99};

_u = 0;
for '_i' from 0 to count(_template)-1 do {
	_ct = _template select _i;
	if ((_ct select 3) <= _gear_level) then {
		lnbAddRow[_lb, [Format ["$%1.", _ct select 2], _ct select 1]];
		if ((_ct select 0) != "") then {lnbSetPicture[_lb,[_u,0],(_ct select 0)]};
		lnbSetValue[_lb,[_u,0],_i];
		_u = _u + 1;
	};
};