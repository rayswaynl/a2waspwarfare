/*
	Author: Marty
	Load one selected artillery magazine on a player-owned artillery vehicle.
*/
Private ["_ammoIndex","_artillery","_artilleryIndex","_found","_i","_magazine","_option","_optionIndex","_options","_side","_sideText","_turretPath","_turrets","_weapon"];

_artillery = _this select 0;
_side = _this select 1;
_artilleryIndex = _this select 2;
_ammoIndex = _this select 3;
_sideText = if (typeName _side == "SIDE") then {str _side} else {_side};

if (isNull _artillery) exitWith {false};
if !(alive _artillery) exitWith {false};
if (isNull gunner _artillery) exitWith {false};
if (isPlayer gunner _artillery) exitWith {false};

_options = [_side, _artilleryIndex] Call WFBE_CO_FNC_GetArtilleryAmmoOptions;
_optionIndex = -1;

for "_i" from 0 to (count _options) - 1 do {
	if (_optionIndex < 0) then {
		if (((_options select _i) select 3) == _ammoIndex) then {_optionIndex = _i};
	};
};

if (_optionIndex < 0) exitWith {false};

_option = _options select _optionIndex;
_magazine = _option select 2;
_weapon = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_WEAPONS", _sideText]) select _artilleryIndex;
_turrets = _artillery Call WFBE_CO_FNC_GetVehicleTurretsGear;
_turretPath = [];
_found = false;

for "_i" from 0 to (count _turrets) - 1 do {
	if !(_found) then {
		if (_weapon in ((_turrets select _i) select 0)) then {
			_turretPath = (_turrets select _i) select 2;
			_found = true;
		};
	};
};

if !(_found) exitWith {false};

if !(_magazine in (_artillery magazinesTurret _turretPath)) then {
	_artillery addMagazineTurret [_magazine, _turretPath];
};

_artillery loadMagazine [_turretPath, _weapon, _magazine];
_artillery setVariable ["WFBE_A_ArtilleryAmmoSelection", [_artilleryIndex, _ammoIndex], true];

true
