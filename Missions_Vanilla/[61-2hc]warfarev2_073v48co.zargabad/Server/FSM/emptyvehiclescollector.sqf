// Marty: Performance Audit locals.
private["_vehicles", "_reloaded","_perfStart","_perfHandled","_handled","_cur"];

while {!gameOver} do {
	// Marty: Performance Audit timing for the empty vehicle collector.
	_perfStart = diag_tickTime;
	_perfHandled = 0;

	_vehicles = WF_Logic getVariable "emptyVehicles";

	_handled = [];
	{
		if !(_x in emptyQueu) then {
			// Marty: Performance Audit counter for handled empty vehicles.
			_perfHandled = _perfHandled + 1;
			emptyQueu = emptyQueu + [_x];
			[_x] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_handled = _handled + [_x];
		};
	} forEach _vehicles;

	//--- FPS (Ray-dir 2026-07-24): debounce the shared-queue rebuild to ONE public broadcast per pass
	//--- instead of one per handled vehicle; re-read at write time so vehicles enqueued mid-pass survive
	//--- the subtraction (race-safe vs the old per-item _vehicles2 snapshot). Broadcast only when handled.
	if (count _handled > 0) then {
		_cur = WF_Logic getVariable "emptyVehicles";
		_reloaded = _cur - _handled - [objNull];
		WF_Logic setVariable ["emptyVehicles",_reloaded,true];
	};

	// Marty: Performance Audit record for the empty vehicle collector.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["emptyvehiclescollector", diag_tickTime - _perfStart, Format["queued:%1;handled:%2", count _vehicles, _perfHandled], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep 1
};
