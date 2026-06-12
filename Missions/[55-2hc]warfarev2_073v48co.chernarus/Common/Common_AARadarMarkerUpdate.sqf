// Marty: PERF1 - this file used to run one scheduled VM per tracked enemy aircraft.
// It is now a registrar: same marker creation and audit records, but the periodic AAR
// work (visibleMap/range/altitude gating, upgrade-tiered refresh, cached text/pos/dir
// writes) moved to the consolidated loop in Common_MarkerLoop.sqf. Call site unchanged.
Private ["_aarEntry","_markerName","_object","_oppositeSide","_side","_sideID"];

_object = _this select 0;
_side = _this select 1;
_sideID = _this select 2;

unitMarker = unitMarker + 1;
_markerName = Format ["unitMarker%1",unitMarker];

createMarkerLocal [_markerName,[0,0,0]];
_markerName setMarkerTypeLocal "mil_arrow2"; 	//Marty : draw marker as a filled arrow
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerSizeLocal [0.5, 0.5];
_markerName setMarkerAlphaLocal 0;

// Marty: Performance Audit active AAR marker counter - now counts registry entries.
if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
	if !(isNil "PerformanceAuditAARMarkerScripts") then {
		missionNamespace setVariable ["PerformanceAuditAARMarkerScripts", (missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0]) + 1];
	};
};
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["aar_marker_start", 0, Format["type:%1;side:%2;activeAAR:%3", typeOf _object, _sideID, missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0]], "CLIENT"] Call PerformanceAudit_Record;
	};
};

// Marty: Default to the local player side for non-standard side ids, then preserve the two-team opposite-side behavior.
_oppositeSide = sideJoined;
if (_sideID == 0) then {
    _oppositeSide = (1) Call GetSideFromID;
};
if (_sideID == 1) then {
    _oppositeSide = (0) Call GetSideFromID;
};

// Marty: Registry entry consumed by Common_MarkerLoop.sqf.
// [object, name, sideID, oppositeSide, lastVisible, lastText, lastPos, lastDir, forceRefresh, reserved, reserved, nextDue]
if (isNil "WFBE_CL_AARMarkerRegistry") then {WFBE_CL_AARMarkerRegistry = []};
if (isNil "WFBE_CL_UnitMarkerLedger") then {WFBE_CL_UnitMarkerLedger = []};
_aarEntry = [_object, _markerName, _sideID, _oppositeSide, false, "", [0,0,0], -1, true, 0, 0, time];
WFBE_CL_AARMarkerRegistry = WFBE_CL_AARMarkerRegistry + [_aarEntry];
WFBE_CL_UnitMarkerLedger = WFBE_CL_UnitMarkerLedger + [_markerName];

// Marty: First registration starts the consolidated loop; exactly one per client.
if (isNil "WFBE_CL_MarkerLoopHandle") then {
	WFBE_CL_MarkerLoopHandle = [] Spawn WFBE_CL_MarkerLoop;
};
