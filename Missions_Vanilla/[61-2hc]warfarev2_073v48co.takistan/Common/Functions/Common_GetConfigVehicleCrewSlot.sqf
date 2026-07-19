/* Adapted from BIS turret's function. */
private ['_entry','_extraTurrets','_isPrimaryPath','_path','_pathIndex','_samePath','_turrestcount','_turrets'];
_entry = configFile >> 'CfgVehicles' >> _this >> 'Turrets';

vhasCommander = false;
vhasGunner = false;
tmp_primary = [];
_turrets = [_entry, [], true] Call Compile preprocessFile "Common\Functions\Common_GetConfigVehicleTurretsReturn.sqf";

tmp_overall = [];

if (count _turrets > 0) then {
	[_turrets, []] Call Compile preprocessFile "Common\Functions\Common_GetConfigVehicleTurrets.sqf";
};

_extraTurrets = [];
{
	_path = _x;
	_isPrimaryPath = false;
	{
		if ((count _path) == (count _x)) then {
			_samePath = true;
			for "_pathIndex" from 0 to ((count _path) - 1) do {
				if ((_path select _pathIndex) != (_x select _pathIndex)) then {_samePath = false};
			};
			if (_samePath) then {_isPrimaryPath = true};
		};
	} forEach tmp_primary;
	if (!_isPrimaryPath) then {_extraTurrets = _extraTurrets + [_path];};
} forEach tmp_overall;

_turrestcount = count(_extraTurrets);

[[vhasCommander,vhasGunner,count(tmp_overall)+1,_turrestcount], _extraTurrets]
