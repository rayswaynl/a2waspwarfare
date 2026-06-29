/*
	SkinSelector_ApplyGear.sqf
	Re-equips _newUnit with the gear snapshot produced by SkinSelector_CopyGear.sqf.
	Parameters: [_newUnit, _gear]
	  _gear = [primaryWeapon, secondaryWeapon, handgunWeapon, magazines,
	            backpackClass, backpackWeapons, backpackMagazines]
*/

Private ["_unit","_gear","_primary","_secondary","_handgun","_mags","_bp",
         "_bpWeapons","_bpMags","_bpObj","_w","_m","_i"];

_unit      = _this select 0;
_gear      = _this select 1;

_primary   = _gear select 0;
_secondary = _gear select 1;
_handgun   = _gear select 2;
_mags      = _gear select 3;
_bp        = _gear select 4;
_bpWeapons = _gear select 5;
_bpMags    = _gear select 6;

//--- Strip default weapons so we have a clean slate.
removeAllWeapons _unit;

//--- Re-add weapons.
if (_primary   != "") then {_unit addWeapon _primary};
if (_secondary != "") then {_unit addWeapon _secondary};
if (_handgun   != "") then {_unit addWeapon _handgun};

//--- Re-add magazines.
_i = 0;
while {_i < count _mags} do {
	_unit addMagazine (_mags select _i);
	_i = _i + 1;
};

//--- Backpack.
if (_bp != "") then {
	_unit addBackpack _bp;
	_bpObj = unitBackpack _unit;
	if (!(isNull _bpObj)) then {
		_i = 0;
		while {_i < count _bpWeapons} do {
			_bpObj addWeaponCargo [(_bpWeapons select _i), 1];
			_i = _i + 1;
		};
		_i = 0;
		while {_i < count _bpMags} do {
			_bpObj addMagazineCargo [(_bpMags select _i), 1];
			_i = _i + 1;
		};
	};
};

//--- Select primary weapon if present so the unit spawns holding it.
if (_primary != "") then {_unit selectWeapon _primary};
