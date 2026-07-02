//--- Init_CivilianCoastalTraffic.sqf
//--- Default-off ambient coastal boat dressing for unused civilian/naval boat classes.
//--- Server-only, neutral props only: no crews, no patrol groups, no objective logic.

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC", 0]) < 1) exitWith {
	["INFORMATION", "Init_CivilianCoastalTraffic.sqf : WFBE_C_CIV_COASTAL_TRAFFIC=0 - feature is OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

private ["_max","_probe","_radius","_tick","_classes","_probeDirs","_fnFindWater","_candidates","_candidate","_boats","_idx","_entry","_town","_townName","_pos","_dir","_class","_boat","_near"];

_max = missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC_MAX", 4];
_probe = missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC_PROBE_R", 700];
_radius = missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC_RADIUS", 1400];
_tick = missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC_TICK", 30];

if (_max < 1) exitWith {
	["INFORMATION", Format ["Init_CivilianCoastalTraffic.sqf : max=%1, nothing to spawn.", _max]] Call WFBE_CO_FNC_LogContent;
};

//--- Classes are already present in live mission core rosters but dormant on non-naval shop paths.
_classes = ["Fishing_Boat","Smallboat_1","Smallboat_2","PBX","Zodiac"];
_probeDirs = [0,45,90,135,180,225,270,315];

_fnFindWater = {
	private ["_town","_range","_dirs","_base","_found","_dir","_cand"];
	_town = _this select 0;
	_range = _this select 1;
	_dirs = _this select 2;
	_base = getPos _town;
	_found = [];

	{
		_dir = _x;
		_cand = [
			(_base select 0) + ((sin _dir) * _range),
			(_base select 1) + ((cos _dir) * _range),
			0
		];
		if (surfaceIsWater _cand) exitWith {_found = [_town, _cand, _dir]};
	} forEach _dirs;

	_found
};

["INITIALIZATION", Format ["Init_CivilianCoastalTraffic.sqf : enabled max=%1 probe=%2 radius=%3 tick=%4.", _max, _probe, _radius, _tick]] Call WFBE_CO_FNC_LogContent;

waitUntil { !isNil "townInit" && {townInit} };
waitUntil { !isNil "towns" };

_candidates = [];
{
	if ((count _candidates) < _max) then {
		_candidate = [_x, _probe, _probeDirs] Call _fnFindWater;
		if ((count _candidate) > 0) then {_candidates set [count _candidates, _candidate]};
	};
} forEach towns;

if ((count _candidates) < 1) exitWith {
	["INFORMATION", Format ["Init_CivilianCoastalTraffic.sqf : no coastal town water candidates found on worldName=%1.", worldName]] Call WFBE_CO_FNC_LogContent;
};

_boats = [];
_idx = 0;
{
	_entry = _x;
	_town = _entry select 0;
	_pos = _entry select 1;
	_dir = _entry select 2;
	_townName = _town getVariable ["name", str _town];
	_class = _classes select (_idx mod (count _classes));
	_boat = createVehicle [_class, [_pos select 0, _pos select 1, 0], [], 0, "NONE"];

	if (isNull _boat) then {
		diag_log (Format ["CIVCOAST-SPAWNFAIL: class '%1' failed to createVehicle near town '%2' at %3.", _class, _townName, _pos]);
	} else {
		_boat setPosASL [_pos select 0, _pos select 1, 0];
		_boat setDir (_dir + 90);
		_boat setFuel 0;
		_boat setVelocity [0,0,0];
		_boat allowDamage false;
		_boat enableSimulation false;
		_boat setVariable ["wfbe_civ_coastal_traffic", true];
		_boat setVariable ["wfbe_civ_coastal_source_town", _townName];
		_boats set [count _boats, _boat];
		diag_log (Format ["CIVCOAST-SPAWN: class=%1 town=%2 pos=%3 dir=%4.", _class, _townName, _pos, _dir]);
	};

	_idx = _idx + 1;
} forEach _candidates;

missionNamespace setVariable ["WFBE_CIV_COASTAL_TRAFFIC_BOATS", _boats];
["INITIALIZATION", Format ["Init_CivilianCoastalTraffic.sqf : spawned %1 neutral coastal boats.", count _boats]] Call WFBE_CO_FNC_LogContent;

while {(missionNamespace getVariable ["WFBE_C_CIV_COASTAL_TRAFFIC", 0]) > 0} do {
	{
		_boat = _x;
		if !(isNull _boat) then {
			_near = false;
			{
				if (isPlayer _x && {alive _x} && {(_x distance _boat) < _radius}) exitWith {_near = true};
			} forEach playableUnits;

			if (_near) then {
				_boat enableSimulation true;
			} else {
				_boat setVelocity [0,0,0];
				_boat enableSimulation false;
			};
		};
	} forEach _boats;

	sleep _tick;
};

{
	if !(isNull _x) then {deleteVehicle _x};
} forEach _boats;

missionNamespace setVariable ["WFBE_CIV_COASTAL_TRAFFIC_BOATS", []];
["INFORMATION", "Init_CivilianCoastalTraffic.sqf : feature flag disabled at runtime; coastal boats cleaned up."] Call WFBE_CO_FNC_LogContent;
