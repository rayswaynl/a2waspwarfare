private["_clear","_perfActive","_perfDeleted","_perfItemStart","_perfScanned","_perfStart","_timer"];

_timer = missionNamespace getVariable "WFBE_C_RUINS_CLEANER_TIME_PERIOD";
while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfDeleted = 0;
	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["Ruins"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfScanned = count _clear;
	{
		_perfItemStart = diag_tickTime;
		deleteVehicle _x;
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfDeleted = _perfDeleted + 1;
		sleep 0.5;
	} forEach _clear;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_ruins", _perfActive, Format["scanned:%1;deleted:%2;cycleMs:%3", _perfScanned, _perfDeleted, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	if(!(isNil "_timer"))then{
		sleep _timer;
	}else{
		sleep 600;
	}
};
