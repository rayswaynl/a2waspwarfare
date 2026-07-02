// Marty: Performance Audit locals.
private["_vehicles", "_vehicles2","_reloaded","_perfStart","_perfHandled"];

while {!gameOver} do {
	// Marty: Performance Audit timing for the empty vehicle collector.
	_perfStart = diag_tickTime;
	_perfHandled = 0;

	_vehicles = WF_Logic getVariable "emptyVehicles";

	{
		if !(_x in emptyQueu) then {
			// Marty: Performance Audit counter for handled empty vehicles.
			_perfHandled = _perfHandled + 1;
			_vehicles2 = WF_Logic getVariable "emptyVehicles";
			emptyQueu = emptyQueu + [_x];
			[_x] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_reloaded = _vehicles2 - [_x] - [objNull];
			WF_Logic setVariable ["emptyVehicles",_reloaded,true];
		};
	} forEach _vehicles;

	// Marty: Performance Audit record for the empty vehicle collector.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["emptyvehiclescollector", diag_tickTime - _perfStart, Format["queued:%1;handled:%2", count _vehicles, _perfHandled], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep 0.5
};
