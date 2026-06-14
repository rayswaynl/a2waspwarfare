// Marty: State-audit loop (PERF1 slice A). One diag_log line per minute relating client FPS
// to script count and accumulated state, so a busy session can show whether FPS decay tracks
// the number of scheduled scripts or the amount of retained state (markers, groups, corpses).
// Arma save/load RESUMES suspended scheduled scripts, so save/load FPS-recovery tests do NOT
// isolate VM count; this log plus the PerformanceAuditMarkerScripts counters are the A/B proof.
Private ["_activeScripts","_aarScripts","_budgetServiced","_line","_mapOpen","_markerRegSize","_markerScripts"];

waitUntil {commonInitComplete};

while {!WFBE_GameOver} do {

	// Marty: PR31 review P1 - diag_activeSQFScripts is Arma 3 (1.44+) only; even a
	// call-compile probe evaluates the symbol and errors on OA 1.64 clients. Logged as a
	// constant -1 so the analyzer schema keeps the column; PerformanceAuditMarkerScripts
	// is the script-count proxy on OA.
	_activeScripts = -1;

	_markerScripts = missionNamespace getVariable ["PerformanceAuditMarkerScripts", -1];
	_aarScripts = missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", -1];
	_mapOpen = if (visibleMap) then {1} else {0};
	_markerRegSize = if (isNil "WFBE_CL_UnitMarkerRegistry") then {-1} else {count WFBE_CL_UnitMarkerRegistry};
	_budgetServiced = missionNamespace getVariable ["WFBE_CL_MarkerBudgetLastServiced", -1];

	_line = Format ["STATE-AUDIT: time:%1;fps:%2;activeSQFScripts:%3;allMapMarkers:%4;markerScripts:%5;aarMarkerScripts:%6;allGroups:%7;allDead:%8;mapOpen:%9;markerRegSize:%10;budgetServiced:%11",
		round time, diag_fps, _activeScripts, -1 /* allMapMarkers: Arma-3-only, N/A in A2 OA */, _markerScripts, _aarScripts, count allGroups, count allDead, _mapOpen, _markerRegSize, _budgetServiced];
	diag_log _line;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["state_audit", 0, _line, "CLIENT"] Call PerformanceAudit_Record;
		};
	};

	sleep 60;
};
