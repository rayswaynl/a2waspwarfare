private["_clear","_perfActive","_perfDeleted","_perfItemStart","_perfLong","_perfScanned","_perfSmall","_perfStart","_timer"];

_timer = missionNamespace getVariable "WFBE_C_CRATER_CLEANER_TIME_PERIOD";

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfSmall = 0;
	_perfLong = 0;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["CraterLong_small"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfSmall = count _clear;
	_perfScanned = _perfScanned + _perfSmall;
	{
		_perfItemStart = diag_tickTime;
		deleteVehicle _x;
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfDeleted = _perfDeleted + 1;
		sleep 0.5;
	} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["CraterLong"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfLong = count _clear;
	_perfScanned = _perfScanned + _perfLong;
	{
		_perfItemStart = diag_tickTime;
		deleteVehicle _x;
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfDeleted = _perfDeleted + 1;
		sleep 0.5;
	} forEach _clear;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_craters", _perfActive, Format["scanned:%1;deleted:%2;small:%3;long:%4;cycleMs:%5", _perfScanned, _perfDeleted, _perfSmall, _perfLong, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	if(!(isNil "_timer"))then{
		sleep _timer;
	}else{
		sleep 600;
	}
};
