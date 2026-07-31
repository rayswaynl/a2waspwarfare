private ["_i", "_turrets", "_path", "_vehicle", "_crew", "_team", "_unit"];
_turrets = _this select 0;
_path = _this select 1;
_vehicle = _this select 2;
_crew = _this select 3;
_team = _this select 4;

_i = 0;
while {_i < (count _turrets)} do {
	private ["_turretIndex", "_thisTurret"];
	_turretIndex = _turrets select _i;
	_thisTurret = _path + [_turretIndex];

	if (isNull (_vehicle turretUnit _thisTurret)) then {
		//--- r50 fail-clean: CreateUnit returns objNull at group/unit cap or bad crew class; moveInTurret
		//--- on null throws and aborts the recursive turret walk mid-tree (remaining turrets stay empty).
		_unit = [_crew,_team,getPos _vehicle,side _team] Call WFBE_CO_FNC_CreateUnit;
		if !(isNull _unit) then {
			_unit moveInTurret [_vehicle, _thisTurret];
		};
	};
	
	//Spawn units into subturrets.
	[_turrets select (_i + 1), _thisTurret, _vehicle, _crew, _team] call SpawnTurrets;
	_i = _i + 2;
};