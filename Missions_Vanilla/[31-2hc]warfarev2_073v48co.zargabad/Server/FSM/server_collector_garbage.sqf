// Marty: Performance Audit locals.
private["_whq","_ehq","_perfStart","_perfDead","_perfSpawned"];

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing for the dead object garbage collector.
	_perfStart = diag_tickTime;
	_perfDead = count allDead;
	_perfSpawned = 0;

	_whq = (west) Call WFBE_CO_FNC_GetSideHQ;
	_ehq = (east) Call WFBE_CO_FNC_GetSideHQ;

	if (isNil "gc_collector") then { gc_collector = []; };

	gc_collector = gc_collector - [objNull];
	{
		if (isNil {_x getVariable "wfbe_trashable"} && !(_x in gc_collector)  && (_x != _whq) && (_x != _ehq)) then {
			// Marty: Performance Audit counter for trash handlers spawned by the garbage collector.
			_perfSpawned = _perfSpawned + 1;
			_x spawn TrashObject;
			gc_collector = gc_collector + [_x];
		};
	} forEach allDead;

	// Marty: Performance Audit record for the dead object garbage collector.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["server_garbage_collector", diag_tickTime - _perfStart, Format["dead:%1;tracked:%2;spawned:%3", _perfDead, count gc_collector, _perfSpawned], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep 0.5;
};
