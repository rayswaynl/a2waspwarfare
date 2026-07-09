private["_clear", "_mapHalf", "_mapSize", "_perfActive", "_perfItemStart", "_perfRestored", "_perfScanned", "_perfStart", "_scanCentre", "_scanRadius", "_timer"];

_timer = missionNamespace getVariable ["WFBE_C_BUILDING_RESTORER_TIME_PERIOD", 600];
if (_timer < 1800) then {_timer = 1800};

_scanCentre = [7500,7900,0];
_scanRadius = 10500;
if ((missionNamespace getVariable ["WFBE_C_CLEANER_MAP_AWARE_ORIGINS", 0]) > 0) then {
	_mapSize = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
	if (_mapSize < 1) then {_mapSize = 15360};
	_mapHalf = _mapSize / 2;
	_scanCentre = [_mapHalf,_mapHalf,0];
	_scanRadius = _mapSize * 0.72;
};

uisleep _timer;

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative restore sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfRestored = 0;
	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["WarfareBBaseStructure"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfScanned = count _clear;
	{
		if ((damage _x) > 0) then {
			_perfItemStart = diag_tickTime;
			_x setDamage 0;
			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
			_perfRestored = _perfRestored + 1;
			sleep 0.5;
		};
	} forEach _clear;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["restorer_buildings", _perfActive, Format["scanned:%1;restored:%2;cycleMs:%3", _perfScanned, _perfRestored, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	uisleep _timer;
};
