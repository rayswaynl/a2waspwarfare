Private ["_loadout", "_vehicle"];

_vehicle = _this select 0;
_loadout = _this select 1;

if ((typeOf _vehicle) == "AW159_Lynx_BAF") then {
    {_vehicle removeMagazineTurret [_x, [-1]]} forEach (_loadout select 1);
    {_vehicle removeWeaponTurret [_x, [-1]]} forEach (_loadout select 0);
} else {
    {_vehicle removeMagazine _x} forEach (_loadout select 1);
    {_vehicle removeWeapon _x} forEach (_loadout select 0);
};
