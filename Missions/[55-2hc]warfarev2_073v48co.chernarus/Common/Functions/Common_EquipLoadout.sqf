Private['_ammo','_cap','_capped','_mi','_unit','_use','_weapon','_weapons'];

_unit = _this select 0;
_weapons = _this select 1;
_ammo = _this select 2;

removeAllWeapons _unit;
removeAllItems _unit;

//--- Cap magazine count to inventory capacity.
_cap = missionNamespace getVariable ["WFBE_C_GEAR_MAG_SLOTS", 12];
if (count _ammo > _cap) then {
	_capped = [];
	for "_mi" from 0 to _cap - 1 do {_capped set [count _capped, _ammo select _mi]};
	_ammo = _capped;
};

//--- Weapons FIRST so each magazine binds to a matching muzzle (e.g. AT13 -> MetisLauncher); otherwise OA throws "Cannot use magazine X in muzzle Y".
//--- removeAllWeapons also strips the virtual Throw/Put weapons; restore them so grenade/smoke/mine magazines
//--- (HandGrenade_West, SmokeShell*, Mine, PipeBomb) have a muzzle to bind to, otherwise OA spams
//--- "Cannot use magazine SmokeShell in muzzle HandGrenadeMuzzle" / "Mine in muzzle TimeBombMuzzle" etc.
_unit addWeapon "Throw";
_unit addWeapon "Put";
{_unit addWeapon _x} forEach _weapons;
{_unit addMagazine _x} forEach _ammo;

//--- A weapon added BEFORE its magazines spawns UNLOADED in OA (players must hand-reload every gun;
//--- addMagazine afterwards never chambers it). Re-add each weapon now that the magazines are in
//--- inventory so the engine chambers it - all addMagazine calls above already ran with the muzzles
//--- present, so the muzzle-bind RPT stays quiet (preserves the build-31 weapons-first fix).
{_unit removeWeapon _x; _unit addWeapon _x} forEach _weapons;

_use = primaryWeapon _unit;
if (_use == "") then {
	Private ["_kind"];
	{
		_kind = getNumber(configFile >> 'CfgWeapons' >> _x >> "type");
		if (_kind in [1,2,4,5]) exitWith {_use = _x};
	} forEach _weapons;
};

if (_use != "") then {
	Private ["_muzzles"];
	_muzzles = getArray (configFile >> "CfgWeapons" >> _use >> "muzzles"); 
	if !("this" in _muzzles) then {_unit selectWeapon (_muzzles select 0)} else {_unit selectWeapon _use}; 
};