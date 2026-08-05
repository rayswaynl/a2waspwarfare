private["_clear", "_keptMines", "_mineObj", "_mine_timer", "_perfActive", "_perfDeleted", "_perfDispatched", "_perfItemStart", "_perfScanned", "_perfStart", "_timer"];

mines = [];
_timer = missionNamespace getVariable "WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD";

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative per-mine sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfDispatched = 0;
	//--- r52: never mutate `mines` inside forEach (A2 skips the next element after each removal).
	//--- Rebuild a kept list, null-guard the mine object, and assign once after the scan.
	_keptMines = [];
	{
		_perfItemStart = diag_tickTime;
		if (typeName _x == "ARRAY" && {count _x >= 2}) then {
			_mineObj = _x select 0;
			_mine_timer = _x select 1;
			if ((time - _mine_timer) >= _timer) then {
				if (isNull _mineObj) then {
					_perfDeleted = _perfDeleted + 1;
				} else {
					//--- A2 deleteVehicle is locality-bound. Player-fired Mine/MineE objects are
					//--- local to the shooter, while this server-owned registry is populated through
					//--- register-mine. Keep a non-local entry until its owner executes the guarded
					//--- cleanup only when the OA owner route is enabled; the rollback flag and the
					//--- A2-Vanilla build retain the legacy delete attempt instead of creating an
					//--- undrainable registry entry (SendToClient is intentionally stubbed there).
					if (local _mineObj || {(missionNamespace getVariable ["WFBE_C_TRASH_REMOTE_DELETE", 0]) <= 0} || {(missionNamespace getVariable ["WF_A2_Vanilla", false])}) then {
						deleteVehicle _mineObj;
						_perfDeleted = _perfDeleted + 1;
					} else {
						_mineObj setVariable ["wfbe_mine_reap", true, true];
						[_mineObj, "HandleSpecial", ["cleanup-mine", _mineObj]] Call WFBE_CO_FNC_SendToClient;
						_keptMines = _keptMines + [_x];
						_perfDispatched = _perfDispatched + 1;
					};
				};
			} else {
				_keptMines = _keptMines + [_x];
			};
		};
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		_perfScanned = _perfScanned + 1;
		sleep 0.5;
	} forEach mines;
	mines = _keptMines;
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["cleaner_mines", _perfActive, Format["tracked:%1;scanned:%2;deleted:%3;dispatched:%4;cycleMs:%5", count mines, _perfScanned, _perfDeleted, _perfDispatched, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};
	if(!(isNil "_timer"))then{
		sleep _timer;
	}else{
		sleep 600;
	};
};
