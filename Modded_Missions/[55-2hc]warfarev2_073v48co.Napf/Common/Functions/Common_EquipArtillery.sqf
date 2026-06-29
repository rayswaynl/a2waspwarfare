Private ['_ammo','_currentUpgrades','_extMagUpgr','_i','_index','_side','_sideText','_sideValue','_unit'];
_unit = _this select 0;
_index = _this select 1;
_side = _this select 2;

// Marty: Callers use either a side value (west/east/resistance) or side text ("WEST"/"EAST"/"GUER").
// Config variables need side text, while GetSideUpgrades needs the side value.
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

//--- Browse for extended Mags (WP, SADARM... )
_ammo = (missionNamespace getVariable Format['WFBE_%1_ARTILLERY_EXTENDED_MAGS',_sideText]) select _index;
if (count _ammo == 0) exitWith {};

_extMagUpgr = missionNamespace getVariable Format['WFBE_%1_ARTILLERY_EXTENDED_MAGS_UPGRADE',_sideText];

//--- Retrieve the Artillery upgrade level.
_currentUpgrades = ((_sideValue) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_ARTYAMMO;

for [{_i = 0},{_i < count(_ammo)},{_i = _i + 1}] do {
	if (_currentUpgrades >= ((_extMagUpgr select _index) select _i)) then {
		_unit addMagazine (_ammo select _i);
	};
};
