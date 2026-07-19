/*
	Shared UAV2 Forward FOB eligibility gate.
	_this = [player, repairTruck]. Returns Boolean only; it never mutates state.
	The server calls this again before entering its reservation/debit transaction.
*/
private ["_args","_player","_truck","_side","_engineers","_repairTypes","_upgrades","_level"];

_args = _this;
if (typeName _args != "ARRAY" || {count _args < 2}) exitWith {false};
_player = _args select 0;
_truck = _args select 1;
if (typeName _player != "OBJECT" || {isNull _player} || {!alive _player}) exitWith {false};
if (typeName _truck != "OBJECT" || {isNull _truck} || {!alive _truck}) exitWith {false};

_side = side (group _player);
if (_side != west && {_side != east}) exitWith {false};
_engineers = missionNamespace getVariable ["WFBE_C_UAV2_FOB_ENGINEERS", []];
if !((typeOf _player) in _engineers) exitWith {false};

_repairTypes = missionNamespace getVariable [Format ["WFBE_%1REPAIRTRUCKS", str _side], []];
if !((typeOf _truck) in _repairTypes) exitWith {false};
if (side _truck != _side) exitWith {false};
if ((_player distance _truck) > (missionNamespace getVariable ["WFBE_C_UAV2_FOB_TRUCK_RANGE", 18])) exitWith {false};

_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
if (typeName _upgrades != "ARRAY" || {count _upgrades <= WFBE_UP_UAV}) exitWith {false};
_level = missionNamespace getVariable ["WFBE_C_UAV2_LEVEL", 2];
if ((_upgrades select WFBE_UP_UAV) < _level) exitWith {false};

true
