/*
	Common_HasLoadedSecondaryWeapon.sqf

	Returns true only when a living unit carries a secondary-slot launcher AND at
	least one magazine accepted by that launcher.  A launcher remains equipped
	after its rockets are spent, so checking secondaryWeapon alone overstates
	the team's anti-armour capability.

	A2-OA safe: secondaryWeapon/magazines/getArray only; no A3 type helpers.
	_this = [_unit]. Returns BOOL.
*/

private ["_unit","_weapon","_launcherMags","_unitMags","_hasLoaded","_mag"];

_unit = _this select 0;
_hasLoaded = false;

if (isNull _unit || {!alive _unit}) exitWith {false};

_weapon = secondaryWeapon _unit;
if (_weapon == "") exitWith {false};

_launcherMags = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
_unitMags = magazines _unit;

{
	_mag = _x;
	if (!_hasLoaded && {_mag in _unitMags}) then {_hasLoaded = true};
} forEach _launcherMags;

_hasLoaded
