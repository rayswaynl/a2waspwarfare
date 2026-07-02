// Marty: PERF1 - this file used to BE the per-unit marker loop (one scheduled VM per
// tracked unit, 150-400 concurrent per client at peak; a player memory-dump test
// confirmed the client-side cost). It is now a registrar: same parameters, same marker
// creation, but the periodic work moved to the single consolidated loop in
// Common_MarkerLoop.sqf. Call sites are unchanged.
Private ["_deathMarkerColor","_deathMarkerSize","_deathMarkerType","_deletePrevious","_entry","_initialPos","_isHQ","_markerColor","_markerName","_markerSize","_markerText","_markerType","_refreshRate","_side","_trackDeath","_tracked","_trackedKind","_trackedType"];

waitUntil {commonInitComplete};

_markerType = _this select 0;
_markerColor = _this select 1;
_markerSize = _this select 2;
_markerText = _this select 3;
_markerName = _this select 4;
_tracked = _this select 5;
_refreshRate = _this select 6;
_trackDeath = _this select 7;
_deathMarkerType = _this select 8;
_deathMarkerColor = _this select 9;
_deletePrevious = _this select 10;
_side = _this select 11;
_deathMarkerSize = [1,1];
if (count _this > 12) then {_deathMarkerSize = _this select 12};

if (_side != side group player || isNull _tracked || !(alive _tracked)) exitWith {};
if (_deletePrevious) then {deleteMarkerLocal _markerName};

// Marty: Performance Audit metadata lets us separate infantry, vehicles, HQ, and paratrooper marker entries.
_trackedType = typeOf _tracked;
_trackedKind = "object";
if (_tracked isKindOf "Man") then {_trackedKind = "man"};
if (_tracked isKindOf "Car") then {_trackedKind = "car"};
if (_tracked isKindOf "Tank") then {_trackedKind = "tank"};
if (_tracked isKindOf "Air") then {_trackedKind = "air"};
if (_tracked isKindOf "Ship") then {_trackedKind = "ship"};

_isHQ = _markerType == "Headquarters";

createMarkerLocal [_markerName, getPos _tracked];
if (_markerText != "") then {_markerName setMarkerTextLocal _markerText};
_markerName setMarkerTypeLocal _markerType;
_markerName setMarkerColorLocal _markerColor;
_markerName setMarkerSizeLocal _markerSize;

_tracked setVariable ["unitMarkerBlink", _markerName, false];
_tracked setVariable ["OriginalMarkerColor", _markerColor, false];

// Marty: Performance Audit active marker counter - now counts registry entries, same
// semantics as the old per-unit script counter (needed for the A/B proof).
if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
	if !(isNil "PerformanceAuditMarkerScripts") then {
		missionNamespace setVariable ["PerformanceAuditMarkerScripts", (missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0]) + 1];
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["markerupdate_start", 0, Format["markerType:%1;trackedKind:%2;trackedType:%3;refresh:%4;activeMarkers:%5;side:%6;trackDeath:%7", _markerType, _trackedKind, _trackedType, _refreshRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _side, _trackDeath], "CLIENT"] Call PerformanceAudit_Record;
	};
};

// Marty: Registry entry consumed by Common_MarkerLoop.sqf.
// [tracked, name, baseType, baseSize, baseText, refresh, trackDeath, deathType,
//  deathColor, deathSize, kind, isHQ, lastText, lastType, lastSize, nextDue, state, deadUntil]
if (isNil "WFBE_CL_UnitMarkerRegistry") then {WFBE_CL_UnitMarkerRegistry = []};
if (isNil "WFBE_CL_UnitMarkerLedger") then {WFBE_CL_UnitMarkerLedger = []};
_entry = [_tracked, _markerName, _markerType, _markerSize, _markerText, _refreshRate, _trackDeath, _deathMarkerType, _deathMarkerColor, _deathMarkerSize, _trackedKind, _isHQ, _markerText, _markerType, +_markerSize, time + _refreshRate, 0, 0];
WFBE_CL_UnitMarkerRegistry = WFBE_CL_UnitMarkerRegistry + [_entry];
WFBE_CL_UnitMarkerLedger = WFBE_CL_UnitMarkerLedger + [_markerName];

// Marty: First registration starts the consolidated loop; exactly one per client.
if (isNil "WFBE_CL_MarkerLoopHandle") then {
	WFBE_CL_MarkerLoopHandle = [] Spawn WFBE_CL_MarkerLoop;
};
