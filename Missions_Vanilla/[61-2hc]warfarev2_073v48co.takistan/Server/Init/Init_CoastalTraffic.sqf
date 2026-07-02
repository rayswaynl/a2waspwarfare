/* Init_CoastalTraffic.sqf
   Default-off Chernarus coastal traffic hook.

   Server-only neutral water props: no crew, no groups, no patrol AI. The hulls
   are simulation-gated by player proximity because they are ambience, not combat.
*/

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_COASTAL_TRAFFIC_ENABLE", 0]) < 1) exitWith {};
if ((["chernarus"] find (toLower worldName)) < 0) exitWith {
	["INFORMATION", Format ["Init_CoastalTraffic.sqf: worldName [%1] is outside the Chernarus coastal traffic hook.", worldName]] Call WFBE_CO_FNC_LogContent;
};

private ["_defs","_boats","_name","_class","_pos","_dir","_boat","_radius","_interval","_active","_player"];

_defs = [
	["Kamenka", "Fishing_Boat", [1810, 1960, 0], 145],
	["Komarovo", "Smallboat_1", [3430, 2060, 0], 115],
	["Chernogorsk", "Fishing_Boat", [6720, 2150, 0], 95],
	["Elektrozavodsk", "Smallboat_2", [10370, 1740, 0], 70],
	["Solnichniy", "Fishing_Boat", [13480, 5930, 0], 25],
	["Berezino", "PBX", [12630, 9360, 0], 45]
];

_boats = [];

{
	_name = _x select 0;
	_class = _x select 1;
	_pos = _x select 2;
	_dir = _x select 3;

	if !(surfaceIsWater _pos) then {
		["WARNING", Format ["Init_CoastalTraffic.sqf: [%1] %2 skipped, position is not water: %3.", _name, _class, _pos]] Call WFBE_CO_FNC_LogContent;
	} else {
		_boat = createVehicle [_class, _pos, [], 0, "NONE"];
		if (isNull _boat) then {
			["WARNING", Format ["Init_CoastalTraffic.sqf: [%1] %2 failed createVehicle at %3.", _name, _class, _pos]] Call WFBE_CO_FNC_LogContent;
		} else {
			_boat setDir _dir;
			_boat setPosASL [_pos select 0, _pos select 1, 0];
			_boat setFuel 0;
			_boat lock true;
			_boat allowDamage false;
			_boat setVariable ["wfbe_coastal_traffic", true];
			_boat enableSimulation false;
			_boats set [count _boats, _boat];
			diag_log Format ["COASTALTRAFFIC|SPAWN|town=%1|class=%2|pos=%3|dir=%4", _name, _class, _pos, _dir];
		};
	};
} forEach _defs;

missionNamespace setVariable ["WFBE_CoastalTrafficBoats", _boats];
["INITIALIZATION", Format ["Init_CoastalTraffic.sqf: spawned %1 of %2 neutral coastal boats.", count _boats, count _defs]] Call WFBE_CO_FNC_LogContent;

_radius = missionNamespace getVariable ["WFBE_C_COASTAL_TRAFFIC_SIM_RADIUS", 900];
_interval = missionNamespace getVariable ["WFBE_C_COASTAL_TRAFFIC_INTERVAL", 15];
if (_radius < 100) then {_radius = 100};
if (_interval < 5) then {_interval = 5};

while {!(missionNamespace getVariable ["WFBE_GameOver", false])} do {
	_active = false;
	{
		if (isPlayer _x && {alive _x}) then {
			_player = _x;
			{
				if (!isNull _x && {(_player distance _x) < _radius}) then {_active = true};
			} forEach _boats;
		};
	} forEach playableUnits;

	{
		if (!isNull _x) then {_x enableSimulation _active};
	} forEach _boats;

	sleep _interval;
};

{
	if (!isNull _x) then {deleteVehicle _x};
} forEach _boats;

missionNamespace setVariable ["WFBE_CoastalTrafficBoats", []];
