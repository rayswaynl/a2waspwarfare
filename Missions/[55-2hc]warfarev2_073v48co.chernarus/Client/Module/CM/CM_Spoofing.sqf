Private ["_ammo","_chance","_enemy","_prob","_missile","_vehicle","_deadline","_closeDist"];
_vehicle = _this select 0;
_ammo = _this select 1;
_enemy = _this select 2;
_missile = objNull;

if ((alive _vehicle) && (isEngineOn _vehicle)) then {
	_missile = nearestObject [_enemy,_ammo];
	//--- SCHEDULER-LEAK: bare waitUntil on distance hangs forever if the missile never closes
	//--- (wrong direction, already past, null nearestObject). Bound with sleep + deadline.
	if (isNull _missile) exitWith {};
	_deadline = time + 20;
	_closeDist = ((speed _vehicle) max 5) * 1.5;
	waitUntil {
		sleep 0.05;
		isNull _missile || {!(alive _vehicle)} || {(_missile distance _vehicle) < _closeDist} || {time >= _deadline}
	};
	if (isNull _missile || {!(alive _vehicle)} || {time >= _deadline}) exitWith {};
	_prob = 25 + (random 75);
	_chance = random 100;
	if (_prob > _chance) then {
		_deadline = time + 12;
		while {alive _missile && {time < _deadline}} do {
			_missile setDir ((getDir _missile) + ((random 20) - 10));
			sleep 0.1;
		};
	};
};
