Private ["_loadout", "_vehicle"];

_vehicle = _this select 0;
_loadout = _this select 1;

//--- SEAD opt-in row detach (owner ruling 2026-08-02, flag WFBE_C_SEAD_EASA_ROW default 0): picking any
//--- other loadout row (including the [DEFAULT] factory-loadout sentinel path) counts as "the SEAD row
//--- was removed" - every EASA_Equip.sqf loadout swap and the GUI DEFAULT-restore path both funnel through
//--- this function, so this is the single place that neutralises the guidance EH. Does not touch WFBE_EASA_Setup.
if ((_vehicle getVariable ["WFBE_SEAD_EasaRowActive", false])) then {
	private ["_seadEhIdx"];
	_seadEhIdx = _vehicle getVariable ["WFBE_SEAD_EhIndex", -1];
	if (_seadEhIdx >= 0) then {_vehicle removeEventHandler ["Fired", _seadEhIdx]};
	_vehicle setVariable ["WFBE_SEAD_EasaRowActive", false, true];
	_vehicle setVariable ["WFBE_SEAD_EhIndex", nil, true];
};

if (((typeOf _vehicle) == "AW159_Lynx_BAF") || {(typeOf _vehicle) == "Ka137_MG_PMC"}) then {
    {_vehicle removeMagazineTurret [_x, [-1]]} forEach (_loadout select 1);
    {_vehicle removeWeaponTurret [_x, [-1]]} forEach (_loadout select 0);
} else {
    {_vehicle removeMagazine _x} forEach (_loadout select 1);
    {_vehicle removeWeapon _x} forEach (_loadout select 0);
};
