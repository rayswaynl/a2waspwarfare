private["_clear", "_perfActive", "_perfItemStart", "_perfRestored", "_perfScanned", "_perfStart", "_timer"];

_timer = missionNamespace getVariable ["WFBE_C_BUILDING_RESTORER_TIME_PERIOD", 600];

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative restore sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfRestored = 0;
	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7500,7900,0],["WarfareBBaseStructure"],10500];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfScanned = count _clear;
	{
		_perfItemStart = diag_tickTime;
		_x setdamage 0;
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfRestored = _perfRestored + 1;
		sleep 0.5;
	} forEach _clear;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["restorer_buildings", _perfActive, Format["scanned:%1;restored:%2;cycleMs:%3", _perfScanned, _perfRestored, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	uisleep _timer;
};
