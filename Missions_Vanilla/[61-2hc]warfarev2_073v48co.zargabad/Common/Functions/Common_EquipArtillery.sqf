Private ['_ammo','_currentUpgrades','_extMagUpgr','_i','_index','_magsByType','_need','_side','_sideText','_sideValue','_unit','_upgrades'];
_unit = _this select 0;
_index = _this select 1;
_side = _this select 2;

//--- r76b: extended shell-type equip must fail-clean — select on nil tables / null hull throws mid-buy.
if (isNull _unit || {!alive _unit}) exitWith {};
if (isNil "_index" || {typeName _index != "SCALAR"}) exitWith {};

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
_magsByType = missionNamespace getVariable Format['WFBE_%1_ARTILLERY_EXTENDED_MAGS',_sideText];
if (isNil "_magsByType" || {typeName _magsByType != "ARRAY"}) exitWith {};
if (_index < 0 || {_index >= count _magsByType}) exitWith {};
_ammo = _magsByType select _index;
if (isNil "_ammo" || {typeName _ammo != "ARRAY"} || {count _ammo == 0}) exitWith {};

_extMagUpgr = missionNamespace getVariable Format['WFBE_%1_ARTILLERY_EXTENDED_MAGS_UPGRADE',_sideText];
if (isNil "_extMagUpgr" || {typeName _extMagUpgr != "ARRAY"}) exitWith {};
if (_index >= count _extMagUpgr) exitWith {};

//--- Retrieve the Artillery upgrade level.
_upgrades = (_sideValue) Call WFBE_CO_FNC_GetSideUpgrades;
if (isNil "_upgrades" || {typeName _upgrades != "ARRAY"} || {count _upgrades <= WFBE_UP_ARTYAMMO}) exitWith {};
_currentUpgrades = _upgrades select WFBE_UP_ARTYAMMO;
if (isNil "_currentUpgrades" || {typeName _currentUpgrades != "SCALAR"}) then {_currentUpgrades = 0};

for [{_i = 0},{_i < count(_ammo)},{_i = _i + 1}] do {
	_need = if (_i < count (_extMagUpgr select _index)) then {(_extMagUpgr select _index) select _i} else {999};
	if (typeName _need != "SCALAR") then {_need = 999};
	if (_currentUpgrades >= _need) then {
		_unit addMagazine (_ammo select _i);
	};
};
