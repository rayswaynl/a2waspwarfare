Private ["_aarUpgradeLevel","_aircraftName","_altitude","_currentDir","_currentPos","_dirDiff","_dirThreshold","_forceMarkerRefresh","_height","_lastMarkerDir","_lastMarkerPos","_lastMarkerText","_lastUpgradeCheck","_lastVisible","_mapVisible","_markerName","_markerText","_object","_oppositeSide","_perfDirWrites","_perfPosWrites","_perfSkippedWrites","_perfStart","_perfTextUpdates","_perfVisible","_posThreshold","_radarInRange","_side","_sideID","_speed","_typeOfObject","_updateDir","_updateFrequency","_updatePos","_updateText","_upgradeCacheTime","_upgrades"];

_object = _this select 0;
_side = _this select 1;
_sideID = _this select 2;

unitMarker = unitMarker + 1;
_markerName = Format ["unitMarker%1",unitMarker];

createMarkerLocal [_markerName,[0,0,0]];
//_markerName setMarkerTypeLocal "Vehicle";
_markerName setMarkerTypeLocal "mil_arrow2"; 	//Marty : draw marker as a filled arrow
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerSizeLocal [0.5, 0.5]; // Made the marker a bit smaller still, might need adjustmenets
_markerName setMarkerAlphaLocal 0;
_height = missionNamespace getVariable "WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION";

// Marty: Cache local marker state so AAR does no useful work while the Arma 2 map screen is hidden and skips repeated marker writes.
_lastVisible = false;
_lastMarkerText = "";
_lastMarkerPos = [0,0,0];
_lastMarkerDir = -1;
_forceMarkerRefresh = true;
_aarUpgradeLevel = -1;
_lastUpgradeCheck = -999;
_upgradeCacheTime = 5;
_posThreshold = 25;
_dirThreshold = 7;

// Marty: Performance Audit active AAR marker script counter.
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

// Place any aircraft warning logic here before the loop (done once)?

// Marty: AAR marker updates are only useful when the player can see Arma 2 map markers.
while {!(isNull _object) && alive _object} do {
	_perfStart = diag_tickTime;
	_perfVisible = 0;
	_perfTextUpdates = 0;
	_perfPosWrites = 0;
	_perfDirWrites = 0;
	_perfSkippedWrites = 0;
	_updateFrequency = 5; // AAR0: 5, AAR1: 3, AAR2: 1
	_radarInRange = antiAirRadarInRange;
	_mapVisible = visibleMap;

	call {
		if !(_mapVisible) exitWith {
			_updateFrequency = 0.25;
			_forceMarkerRefresh = true;
			if (_lastVisible) then {
				_markerName setMarkerAlphaLocal 0;
				_lastVisible = false;
			} else {
				_perfSkippedWrites = _perfSkippedWrites + 1;
			};
			waitUntil {sleep 2; visibleMap || isNull _object || !(alive _object)};
		};

		if !(_radarInRange) exitWith {
			_forceMarkerRefresh = true;
			if (_lastVisible) then {
				_markerName setMarkerAlphaLocal 0;
				_lastVisible = false;
			} else {
				_perfSkippedWrites = _perfSkippedWrites + 1;
			};
		};

		_currentPos = getPos _object;
		if ((_currentPos select 2) <= _height) exitWith {
			_forceMarkerRefresh = true;
			if (_lastVisible) then {
				_markerName setMarkerAlphaLocal 0;
				_lastVisible = false;
			} else {
				_perfSkippedWrites = _perfSkippedWrites + 1;
			};
		};

		if ((diag_tickTime - _lastUpgradeCheck) > _upgradeCacheTime) then {
			_upgrades = (_oppositeSide) Call WFBE_CO_FNC_GetSideUpgrades;
			_aarUpgradeLevel = _upgrades select WFBE_UP_AAR;
			_lastUpgradeCheck = diag_tickTime;
		};

		if (_aarUpgradeLevel > 0) then {_updateFrequency = 3};
		if (_aarUpgradeLevel > 1) then {_updateFrequency = 1};

		_speed = str(round(speed _object)) + "km/h"; // Get the speed (AAR0)
		_altitude = " "; // Defined empty (AAR1)
		_aircraftName = " "; // Defined empty (AAR2)

		if (_aarUpgradeLevel > 0) then {
			_altitude = str(round(getPosATL _object select 2)) + "m";
		};

		if (_aarUpgradeLevel > 1) then {
			_typeOfObject = typeOf _object;
			_aircraftName = [_typeOfObject] call WFBE_CL_FNC_ReturnAircraftNameFromItsType;
		};

		if !(_lastVisible) then {
			_markerName setMarkerAlphaLocal 1;
			_lastVisible = true;
			_forceMarkerRefresh = true;
		} else {
			_perfSkippedWrites = _perfSkippedWrites + 1;
		};

		_markerText = format ["%1 %2 %3", _speed, _altitude, _aircraftName];
		_updateText = _forceMarkerRefresh;
		if (_markerText != _lastMarkerText) then {_updateText = true};
		if (_updateText) then {
			_markerName setMarkerTextLocal _markerText;
			_lastMarkerText = _markerText;
			_perfTextUpdates = _perfTextUpdates + 1;
		} else {
			_perfSkippedWrites = _perfSkippedWrites + 1;
		};

		_updatePos = _forceMarkerRefresh;
		if ((_currentPos distance _lastMarkerPos) > _posThreshold) then {_updatePos = true};
		if (_updatePos) then {
			_markerName setMarkerPosLocal _currentPos;
			_lastMarkerPos = _currentPos;
			_perfPosWrites = _perfPosWrites + 1;
		} else {
			_perfSkippedWrites = _perfSkippedWrites + 1;
		};

		_currentDir = getDir _object;
		_dirDiff = abs (_currentDir - _lastMarkerDir);
		if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
		_updateDir = _forceMarkerRefresh;
		if (_dirDiff > _dirThreshold) then {_updateDir = true};
		if (_updateDir) then {
			_markerName setMarkerDirLocal _currentDir;
			_lastMarkerDir = _currentDir;
			_perfDirWrites = _perfDirWrites + 1;
		} else {
			_perfSkippedWrites = _perfSkippedWrites + 1;
		};

		_forceMarkerRefresh = false;
		_perfVisible = 1;
	};

	if !(_lastVisible) then {
		_perfVisible = 0;
	};

	if (isNull _object || !(alive _object)) then {
		if (_lastVisible) then {
			_markerName setMarkerAlphaLocal 0;
			_lastVisible = false;
		};
	};

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["aar_marker_update", diag_tickTime - _perfStart, Format["type:%1;activeAAR:%2;visible:%3;textUpdates:%4;posWrites:%5;dirWrites:%6;skippedWrites:%7;upgrade:%8;refresh:%9;radarInRange:%10", typeOf _object, missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0], _perfVisible, _perfTextUpdates, _perfPosWrites, _perfDirWrites, _perfSkippedWrites, _aarUpgradeLevel, _updateFrequency, _radarInRange], "CLIENT"] Call PerformanceAudit_Record;
		};
	};

	sleep _updateFrequency; //Marty : refresh frequency is same as the updateTeamMarker in order to refresh faster on map. (May be we should increase this value in case of performances issues !)
};

if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
	if !(isNil "PerformanceAuditAARMarkerScripts") then {
		missionNamespace setVariable ["PerformanceAuditAARMarkerScripts", ((missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 1]) - 1) max 0];
	};
};
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["aar_marker_end", 0, Format["type:%1;side:%2;activeAAR:%3", typeOf _object, _sideID, missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0]], "CLIENT"] Call PerformanceAudit_Record;
	};
};

deleteMarkerLocal _markerName;
