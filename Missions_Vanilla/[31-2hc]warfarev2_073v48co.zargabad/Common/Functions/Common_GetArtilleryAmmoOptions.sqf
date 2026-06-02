/*
	Author: Marty
	Return the artillery ammo choices available for one side and one artillery type.
	Each entry is [display name, projectile class, magazine class, ammo index].
*/
Private ["_ammoIndex","_artilleryAmmos","_artilleryIndex","_candidateAmmo","_candidateMags","_currentUpgrade","_displayName","_extendedIndex","_extendedMags","_extendedMagsByType","_extendedUpgrade","_i","_magazine","_muzzle","_muzzleConfig","_muzzles","_options","_projectile","_projectiles","_side","_sideText","_sideValue","_upgradeByType","_upgradeLevels","_weapon","_weaponConfig","_weaponMags"];

_side = _this select 0;
_artilleryIndex = _this select 1;

_sideText = if (typeName _side == "SIDE") then {str _side} else {_side};
_sideValue = if (typeName _side == "SIDE") then {_side} else {
	switch (_side) do {
		case "WEST": {west};
		case "EAST": {east};
		case "GUER": {resistance};
		case "RESISTANCE": {resistance};
		default {west};
	};
};

_options = [];
_artilleryAmmos = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMOS", _sideText];
if (_artilleryIndex < 0) exitWith {_options};
if (_artilleryIndex >= count _artilleryAmmos) exitWith {_options};

_projectiles = _artilleryAmmos select _artilleryIndex;
_weapon = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_WEAPONS", _sideText]) select _artilleryIndex;
_weaponConfig = configFile >> "CfgWeapons" >> _weapon;
_weaponMags = [];

_muzzles = getArray (_weaponConfig >> "muzzles");
if (count _muzzles == 0) then {_muzzles = ["this"]};

{
	_muzzle = _x;
	_muzzleConfig = if (_muzzle == "this") then {_weaponConfig} else {_weaponConfig >> _muzzle};
	_weaponMags = _weaponMags + getArray (_muzzleConfig >> "magazines");
} forEach _muzzles;

_extendedMagsByType = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_EXTENDED_MAGS", _sideText];
_upgradeByType = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_EXTENDED_MAGS_UPGRADE", _sideText];
_extendedMags = [];
_upgradeLevels = [];

if (_artilleryIndex < count _extendedMagsByType) then {_extendedMags = _extendedMagsByType select _artilleryIndex};
if (_artilleryIndex < count _upgradeByType) then {_upgradeLevels = _upgradeByType select _artilleryIndex};

_candidateMags = _weaponMags + _extendedMags;
_currentUpgrade = (_sideValue Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_ARTYAMMO;

for "_ammoIndex" from 0 to (count _projectiles) - 1 do {
	_projectile = _projectiles select _ammoIndex;
	_magazine = "";

	for "_i" from 0 to (count _candidateMags) - 1 do {
		if (_magazine == "") then {
			_candidateAmmo = getText (configFile >> "CfgMagazines" >> (_candidateMags select _i) >> "ammo");
			if (_candidateAmmo == _projectile) then {_magazine = _candidateMags select _i};
		};
	};

	if (_magazine != "") then {
		_extendedUpgrade = 0;
		_extendedIndex = _extendedMags find _magazine;
		if (_extendedIndex != -1) then {_extendedUpgrade = _upgradeLevels select _extendedIndex};

		if (_currentUpgrade >= _extendedUpgrade) then {
			_displayName = getText (configFile >> "CfgMagazines" >> _magazine >> "displayName");
			if (_displayName == "") then {_displayName = _projectile};
			_options set [count _options, [_displayName, _projectile, _magazine, _ammoIndex]];
		};
	};
};

_options
