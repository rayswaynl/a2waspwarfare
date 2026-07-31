private["_clear","_mapHalf","_mapSize","_perfActive","_perfDeleted","_perfItemStart","_perfLong","_perfScanned","_perfSmall","_perfStart","_scanCentre","_scanRadius","_timer"];

//--- r54: 2-arg default so a missing cleaner period never leaves _timer nil into sleep.
_timer = missionNamespace getVariable ["WFBE_C_CRATER_CLEANER_TIME_PERIOD", 1800];
if (isNil "_timer") then {_timer = 1800};
if (_timer < 1800) then {_timer = 1800};

_scanCentre = [7000,7500,0];
_scanRadius = 20000;
if ((missionNamespace getVariable ["WFBE_C_CLEANER_MAP_AWARE_ORIGINS", 0]) > 0) then {
	_mapSize = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
	if (_mapSize < 1) then {_mapSize = 15360};
	_mapHalf = _mapSize / 2;
	_scanCentre = [_mapHalf,_mapHalf,0];
	_scanRadius = _mapSize * 0.72;
};

sleep _timer;

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfSmall = 0;
	_perfLong = 0;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["CraterLong_small"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfSmall = count _clear;
	_perfScanned = _perfScanned + _perfSmall;
	{
		_perfItemStart = diag_tickTime;
		//--- r54: nearestObjects snapshot can go stale during the cooperative 0.5s sleep - skip null holes.
		if (!isNull _x) then {
			deleteVehicle _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		sleep 0.5;
	} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["CraterLong"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfLong = count _clear;
	_perfScanned = _perfScanned + _perfLong;
	{
		_perfItemStart = diag_tickTime;
		//--- r54: nearestObjects snapshot can go stale during the cooperative 0.5s sleep - skip null holes.
		if (!isNull _x) then {
			deleteVehicle _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		sleep 0.5;
	} forEach _clear;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_craters", _perfActive, Format["scanned:%1;deleted:%2;small:%3;long:%4;cycleMs:%5", _perfScanned, _perfDeleted, _perfSmall, _perfLong, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};