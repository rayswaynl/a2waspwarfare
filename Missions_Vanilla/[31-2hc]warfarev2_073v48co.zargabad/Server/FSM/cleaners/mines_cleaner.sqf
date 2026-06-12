private["_clear", "_mine_timer", "_perfActive", "_perfDeleted", "_perfItemStart", "_perfScanned", "_perfStart", "_timer"];

mines = [];
_timer = missionNamespace getVariable "WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD";

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative per-mine sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	{
		_perfItemStart = diag_tickTime;
		_mine_timer = _x select 1;
		if((time - _mine_timer) >= _timer) then{
			deleteVehicle (_x select 0);
			mines = mines - _x;
			_perfDeleted = _perfDeleted + 1;
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfScanned = _perfScanned + 1;
		sleep 0.5;
	} forEach mines;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_mines", _perfActive, Format["tracked:%1;scanned:%2;deleted:%3;cycleMs:%4", count mines, _perfScanned, _perfDeleted, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	if(!(isNil "_timer"))then{
		sleep _timer;
	}else{
		sleep 600;
	};
};
