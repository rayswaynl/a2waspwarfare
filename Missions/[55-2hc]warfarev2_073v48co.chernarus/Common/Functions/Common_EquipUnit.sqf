/*
	Equip a unit with a defined loadout.
	 Parameters:
		- Unit
		- Weapons
		- Magazines
		- Selectable weapons (Priority).
		- {Backpack}
		- {Backpack content}
*/

Private ["_backpack","_backpack_content","_cap","_capped","_eligible","_magazines","_mi","_muzzles","_unit","_use","_weapons"];

_unit = _this select 0;
_weapons = _this select 1;
_magazines = _this select 2;
_eligible = _this select 3;
_backpack = if (count _this > 4) then {_this select 4} else {""};
_backpack_content = if (count _this > 5) then {_this select 5} else {[]};

//--- Cap magazine count to inventory capacity.
_cap = missionNamespace getVariable ["WFBE_C_GEAR_MAG_SLOTS", 12];
if (count _magazines > _cap) then {
	_capped = [];
	for "_mi" from 0 to _cap - 1 do {_capped set [count _capped, _magazines select _mi]};
	_magazines = _capped;
};

//--- Equip with default stuff.
removeAllWeapons _unit;
removeAllItems _unit;

{_unit addMagazine _x} forEach _magazines;
{_unit addWeapon _x} forEach _weapons;

//--- Get a proper muzzle.
_use = "";
{if (_x != "") exitWith {_use = _x}} forEach _eligible;

if (_use != "") then { 
	_muzzles = getArray (configFile >> "CfgWeapons" >> _use >> "muzzles"); 
	if !("this" in _muzzles) then {_unit selectWeapon (_muzzles select 0)} else {_unit selectWeapon _use}; 
};

//--- Backpack handling.
[_unit, _backpack, _backpack_content] Call WFBE_CO_FNC_EquipBackpack;