private["_capacity","_clear","_mapHalf","_mapSize","_maxPerCycle","_perfActive","_perfDeleted","_perfItemStart","_perfLong","_perfProcessed","_perfScanned","_perfSmall","_perfStart","_perfDeferred","_scanCentre","_scanRadius","_timer"];

//--- r54: 2-arg default so a missing cleaner period never leaves _timer nil into sleep.
_timer = missionNamespace getVariable ["WFBE_C_CRATER_CLEANER_TIME_PERIOD", 1800];
if (isNil "_timer") then {_timer = 1800};
if (_timer < 1800) then {_timer = 1800};
//--- Bound one maintenance pass so a crater storm cannot hold the scheduled lane indefinitely.
//--- The 150 default matches droppeditems_cleaner; normal passes below this stay unchanged.
_maxPerCycle = missionNamespace getVariable ["WFBE_C_CRATER_CLEANER_MAX_PER_CYCLE", 150];
if (_maxPerCycle < 1) then {_maxPerCycle = 150};

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
	_perfProcessed = 0;
	_perfDeferred = 0;
	_capacity = _maxPerCycle;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["CraterLong_small"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfSmall = count _clear;
	_perfScanned = _perfScanned + _perfSmall;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;
		//--- r54: nearestObjects snapshot can go stale during the cooperative 0.5s sleep - skip null holes.
		if (!isNull _x) then {
			deleteVehicle _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfProcessed = _perfProcessed + 1;
		_capacity = _capacity - 1;
		sleep 0.5;
	} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["CraterLong"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfLong = count _clear;
	_perfScanned = _perfScanned + _perfLong;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;
		//--- r54: nearestObjects snapshot can go stale during the cooperative 0.5s sleep - skip null holes.
		if (!isNull _x) then {
			deleteVehicle _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfProcessed = _perfProcessed + 1;
		_capacity = _capacity - 1;
		sleep 0.5;
	} forEach _clear;
	_perfDeferred = (_perfScanned - _perfProcessed) max 0;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_craters", _perfActive, Format["scanned:%1;deleted:%2;small:%3;long:%4;cap:%5;processed:%6;deferred:%7;cycleMs:%8", _perfScanned, _perfDeleted, _perfSmall, _perfLong, _maxPerCycle, _perfProcessed, _perfDeferred, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};
