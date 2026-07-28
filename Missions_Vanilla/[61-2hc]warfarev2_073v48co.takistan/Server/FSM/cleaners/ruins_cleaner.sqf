private["_clear","_mapHalf","_mapSize","_perfActive","_perfDeleted","_perfItemStart","_perfScanned","_perfStart","_scanCentre","_scanRadius","_timer"];

_timer = missionNamespace getVariable "WFBE_C_RUINS_CLEANER_TIME_PERIOD";
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
	_perfDeleted = 0;
	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [_scanCentre,["Ruins"],_scanRadius];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfScanned = count _clear;
	{
		_perfItemStart = diag_tickTime;
		//--- fable/cleanup-locality-2: deleteVehicle on a NON-local object silently no-ops (same A2
		//--- rule as the weaponholder cleaner) - guard + count honestly instead of pretending.
		if (local _x) then {
			deleteVehicle _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		sleep 0.5;
	} forEach _clear;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_ruins", _perfActive, Format["scanned:%1;deleted:%2;cycleMs:%3", _perfScanned, _perfDeleted, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	sleep _timer;
};
