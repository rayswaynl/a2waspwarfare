private["_clear", "_perfActive", "_perfDeleted", "_perfItemStart", "_perfMines", "_perfMineE", "_perfScanned", "_perfStart", "_perfWeaponholders", "_timer"];

_timer = missionNamespace getVariable "WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD";
while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfWeaponholders = 0;
	_perfMines = 0;
	_perfMineE = 0;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["weaponholder"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfWeaponholders = count _clear;
	_perfScanned = _perfScanned + _perfWeaponholders;
	{_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;sleep 0.5;} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["Mine"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfMines = count _clear;
	_perfScanned = _perfScanned + _perfMines;
	{_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;sleep 0.5;} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = nearestObjects [[7000,7500,0],["MineE"],20000];
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfMineE = count _clear;
	_perfScanned = _perfScanned + _perfMineE;
	{_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;sleep 0.5;} forEach _clear;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_droppeditems", _perfActive, Format["scanned:%1;deleted:%2;weaponholders:%3;mines:%4;mineE:%5;cycleMs:%6", _perfScanned, _perfDeleted, _perfWeaponholders, _perfMines, _perfMineE, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	if(!(isNil "_timer"))then{
		sleep _timer;
	}else{
		sleep 600;
	}
};
