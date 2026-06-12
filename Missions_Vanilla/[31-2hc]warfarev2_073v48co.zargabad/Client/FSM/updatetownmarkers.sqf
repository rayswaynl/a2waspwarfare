// Marty: Added local caches and audit counters for town marker refresh.
private["_activeSideIDs","_attackerSideIDs","_canCollectSupply","_closedPollDelay","_closedRefreshDelay","_displayVisible","_gpsVisible","_i","_lastTownTexts","_lastText","_mapVisible","_marker","_markerText","_maxSupplyValue","_nextClosedRefresh","_perfChangedSupplyText","_perfDistanceChecks","_perfSkippedTextWrites","_perfStart","_perfTextWrites","_perfTowns","_perfUnits","_perfVisible","_range","_refreshDelay","_shouldRefresh","_skillType","_sleepDelay","_startingSupplyValue","_suffix","_supplyValue","_tcarm","_town","_townActiveForSide","_townAttacked","_townAttackedForSide","_townMarkers","_townSideID","_townSupplyMissionCoolDownEnabled","_units","_visible"];

_tcarm = missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_TOWN_RANGE";

// Marty: Cache marker names once; town list is static for the local client marker FSM.
_townMarkers = [];
_lastTownTexts = [];
{
	_townMarkers set [count _townMarkers, Format ["WFBE_%1_CityMarker", str _x]];
	_lastTownTexts set [count _lastTownTexts, ""];
} forEach towns;

// Marty: Keep visible map/GPS updates at the old cadence, but defer heavy closed-map passes.
_refreshDelay = 5;
_closedPollDelay = 0.5;
_closedRefreshDelay = 15;
_nextClosedRefresh = 0;

while {!gameOver} do {
	// Marty: Poll map/GPS state cheaply so opening either display forces the next full marker refresh quickly.
	_mapVisible = visibleMap;
	_gpsVisible = shownGPS;
	_displayVisible = _mapVisible || _gpsVisible;
	_shouldRefresh = true;
	if (!_displayVisible) then {_shouldRefresh = diag_tickTime >= _nextClosedRefresh};

	if (!_shouldRefresh) then {
		sleep _closedPollDelay;
	} else {
		// Marty: Performance Audit timing for local town marker visibility and text refresh.
		_perfStart = diag_tickTime;
		_perfTowns = 0;
		_perfVisible = 0;
		_perfTextWrites = 0;
		_perfSkippedTextWrites = 0;
		_perfChangedSupplyText = 0;
		_perfDistanceChecks = 0;
		_units = (Units Group player) Call GetLiveUnits;
		_perfUnits = count _units;
		// Marty: Resolve skill and display state once per pass; nil skill falls back until Skill_Init completes.
		_skillType = "";
		if !(isNil "WFBE_SK_V_Type") then {_skillType = WFBE_SK_V_Type};
		_i = 0;

		{
		
			_town = _x;
			_perfTowns = _perfTowns + 1;
			_range = (_town getVariable "range") * _tcarm;
			_townSideID = _town getVariable "sideID";
			_visible = false;
			
			// Marty: Base town SV visibility stays local to friendly ownership or this player's live group proximity.
			// Marty: Keep the same visibility rules, but stop distance checks as soon as one live unit reveals the town.
			if (_townSideID == sideID) then {_visible = true} else {
				{
					_perfDistanceChecks = _perfDistanceChecks + 1;
					if (_town distance _x < _range) exitWith {_visible = true};
				} forEach _units;
			};

			// Marty: Active/attacked state is networked, so only reveal remote SV to sides involved in that state.
			_townActiveForSide = false;
			_activeSideIDs = [];
			if !(isNil {_town getVariable "wfbe_active_sideIDs"}) then {_activeSideIDs = _town getVariable "wfbe_active_sideIDs"};
			if (sideID in _activeSideIDs) then {_townActiveForSide = true};

			_townAttackedForSide = false;
			_attackerSideIDs = [];
			if !(isNil {_town getVariable "wfbe_attacker_sideIDs"}) then {_attackerSideIDs = _town getVariable "wfbe_attacker_sideIDs"};
			if (sideID in _attackerSideIDs) then {_townAttackedForSide = true};

			_townAttacked = call {
				if (!_townAttackedForSide) exitWith {false};
				if (isNil {_town getVariable "supplyValue"}) exitWith {false};
				if (isNil {_town getVariable "startingSupplyValue"}) exitWith {false};
				_supplyValue = _town getVariable "supplyValue";
				_startingSupplyValue = _town getVariable "startingSupplyValue";
				_supplyValue < _startingSupplyValue
			};

			if (!_visible && (_townActiveForSide || _townAttacked)) then {_visible = true};

			_marker = _townMarkers select _i;
			_markerText = "";
			
			if (_visible) then {
				_perfVisible = _perfVisible + 1;

				_townSupplyMissionCoolDownEnabled = _town getVariable "supplyMissionCoolDownEnabled";
				_supplyValue = _town getVariable "supplyValue";
				_maxSupplyValue = _town getVariable "maxSupplyValue";
				_canCollectSupply = !_townSupplyMissionCoolDownEnabled;
				_suffix = "";

				if (_canCollectSupply) then {_suffix = "  [+]"};
				if (_canCollectSupply && (_skillType == "SpecOps")) then {_suffix = "  [+SUPPLY]"};

				_markerText = Format["  SV: %1/%2%3", _supplyValue, _maxSupplyValue, _suffix];
			};

			// Marty: Only touch local marker text when the desired text really changed.
			_lastText = _lastTownTexts select _i;
			if (_markerText != _lastText) then {
				_marker setMarkerTextLocal _markerText;
				_lastTownTexts set [_i, _markerText];
				_perfTextWrites = _perfTextWrites + 1;
				if (_visible) then {_perfChangedSupplyText = _perfChangedSupplyText + 1};
			} else {
				_perfSkippedTextWrites = _perfSkippedTextWrites + 1;
			};

			_i = _i + 1;
		
		} forEach towns;

		// Marty: Include cache efficiency and display state in the existing audit payload.
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["updatetownmarkers", diag_tickTime - _perfStart, Format["towns:%1;groupUnits:%2;visible:%3;textWrites:%4;skippedTextWrites:%5;distanceChecks:%6;map:%7;gps:%8;changedSupplyText:%9", _perfTowns, _perfUnits, _perfVisible, _perfTextWrites, _perfSkippedTextWrites, _perfDistanceChecks, _mapVisible, _gpsVisible, _perfChangedSupplyText], "CLIENT"] Call PerformanceAudit_Record;
			};
		};
		
		// Marty: Closed map/GPS state keeps polling fast, but schedules the next heavy pass farther out.
		_sleepDelay = _refreshDelay;
		if (!_displayVisible) then {
			_nextClosedRefresh = diag_tickTime + _closedRefreshDelay;
			_sleepDelay = _closedPollDelay;
		} else {
			_nextClosedRefresh = 0;
		};

		sleep _sleepDelay;
	};
};
