/*
	SkinSelector_ApplyGear.sqf
	Re-equips _newUnit with the gear snapshot produced by SkinSelector_CopyGear.sqf.
	Parameters: [_newUnit, _gear]
	  _gear = [primaryWeapon, allWeapons, magazines,
	            backpackClass, backpackWeapons, backpackMagazines]

	cmdcon42 A2-OA-1.64 FIX (Ray 2026-07-02): kept in lockstep with CopyGear's new shape.
	CopyGear now returns the full `weapons` list (index 1) instead of the A3-only
	primaryWeapon/secondaryWeapon/handgunWeapon split, so every carried weapon (rifle,
	launcher, pistol, NVGoggles, binoculars, GPS) is restored. _primary (index 0) is used
	only to re-select the main weapon at the end so the unit spawns holding it.
*/

Private ["_unit","_gear","_primary","_allWeapons","_mags","_bp",
         "_bpWeapons","_bpMags","_bpObj","_w","_i"];

_unit       = _this select 0;
_gear       = _this select 1;

_primary    = _gear select 0;
_allWeapons = _gear select 1;
_mags       = _gear select 2;
_bp         = _gear select 3;
_bpWeapons  = _gear select 4;
_bpMags     = _gear select 5;

//--- Strip default weapons so we have a clean slate.
removeAllWeapons _unit;

//--- Re-add every captured weapon (rifle, launcher, pistol, NVGoggles, binoculars, GPS, ...).
_i = 0;
while {_i < count _allWeapons} do {
	_w = _allWeapons select _i;
	if (_w != "") then {_unit addWeapon _w};
	_i = _i + 1;
};

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
