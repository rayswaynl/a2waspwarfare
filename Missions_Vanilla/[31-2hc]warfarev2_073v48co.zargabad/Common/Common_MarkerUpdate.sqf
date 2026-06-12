// Marty: Performance Audit locals.
Private ["_canMoveTracked","_cargoText","_cargoUnitsInVehicle","_crewText","_crewUnitsInVehicle","_currentPos","_deathMarkerColor","_deathMarkerSize","_deathMarkerType","_delete","_deletePrevious","_groupUnitsInVehicle","_initialPos","_isHQ","_lastMarkerPos","_lastMarkerSize","_lastMarkerText","_lastMarkerType","_markerColor","_markerName","_markerPosThreshold","_markerSize","_markerText","_markerType","_member","_memberVehicle","_perfStart","_positionWrites","_refreshRate","_roleUnit","_side","_sizeChanged","_skippedWrites","_sleepRate","_slowInfantry","_targetMarkerSize","_targetMarkerText","_targetMarkerType","_trackDeath","_tracked","_trackedKind","_trackedType","_trackedVehicle","_typeWrites","_unitText"];

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

// Marty: Performance Audit metadata lets us separate infantry, vehicles, HQ, and paratrooper marker loops.
_trackedType = typeOf _tracked;
_trackedKind = "object";
if (_tracked isKindOf "Man") then {_trackedKind = "man"};
if (_tracked isKindOf "Car") then {_trackedKind = "car"};
if (_tracked isKindOf "Tank") then {_trackedKind = "tank"};
if (_tracked isKindOf "Air") then {_trackedKind = "air"};
if (_tracked isKindOf "Ship") then {_trackedKind = "ship"};

// Marty: Cache marker state locally so repeated refreshes skip unchanged marker writes.
_initialPos = getPos _tracked;
_lastMarkerPos = _initialPos;
_lastMarkerType = _markerType;
_lastMarkerSize = +_markerSize;
_lastMarkerText = _markerText;
_positionWrites = 0;
_typeWrites = 0;
_skippedWrites = 0;
_isHQ = _markerType == "Headquarters";
_slowInfantry = false;
_markerPosThreshold = 5;
if (_trackedKind == "man") then {_markerPosThreshold = 2; _slowInfantry = group _tracked != group player};
if (_trackedKind == "air") then {_markerPosThreshold = 10};
if (_isHQ) then {_markerPosThreshold = 1};

createMarkerLocal [_markerName, _initialPos];
if (_markerText != "") then {_markerName setMarkerTextLocal _markerText};
_markerName setMarkerTypeLocal _markerType;
_markerName setMarkerColorLocal _markerColor;
_markerName setMarkerSizeLocal _markerSize;

_tracked setVariable ["unitMarkerBlink", _markerName, false];
_tracked setVariable ["OriginalMarkerColor", _markerColor, false];

// Marty: Performance Audit active marker script counter.
if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
	if !(isNil "PerformanceAuditMarkerScripts") then {
		missionNamespace setVariable ["PerformanceAuditMarkerScripts", (missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0]) + 1];
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["markerupdate_start", 0, Format["markerType:%1;trackedKind:%2;trackedType:%3;refresh:%4;activeMarkers:%5;positionWrites:%6;typeWrites:%7;skippedWrites:%8;side:%9;trackDeath:%10", _markerType, _trackedKind, _trackedType, _refreshRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _positionWrites, _typeWrites, _skippedWrites, _side, _trackDeath], "CLIENT"] Call PerformanceAudit_Record;
	};
};

if (_isHQ) then {
	
	while {!(isNull _tracked) && alive _tracked} do {

		sleep _refreshRate;

		// Marty: Performance Audit timing for one HQ marker update.
		_perfStart = diag_tickTime;

		_currentPos = getPos _tracked;
		_markerName setMarkerPosLocal _currentPos;
		_lastMarkerPos = _currentPos;
		_positionWrites = _positionWrites + 1;

		// Marty: Performance Audit record for one HQ marker update.
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["markerupdate_hq", diag_tickTime - _perfStart, Format["trackedKind:%1;trackedType:%2;refresh:%3;activeMarkers:%4;positionWrites:%5;typeWrites:%6;skippedWrites:%7;side:%8", _trackedKind, _trackedType, _refreshRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _positionWrites, _typeWrites, _skippedWrites, _side], "CLIENT"] Call PerformanceAudit_Record;
			};
		};
	};

} else {

	while {!(isNull _tracked) && alive _tracked} do {

			// Marty: Keep player-group infantry at one-second refresh; other infantry uses a stable three-second refresh.
			_sleepRate = _refreshRate;
			if (_slowInfantry) then {_sleepRate = _sleepRate max 3};
			sleep _sleepRate;

			// Marty: Performance Audit timing for one unit/vehicle marker update.
			_perfStart = diag_tickTime;

			// Marty: Keep position refresh independent from type/size bookkeeping so marker caching cannot freeze units.
			_currentPos = getPos _tracked;
			_markerName setMarkerPosLocal _currentPos;
			_lastMarkerPos = _currentPos;
			_positionWrites = _positionWrites + 1;

			// Marty: When player-group infantry share one vehicle, show readable crew-first text like 2/4/3 | 5/6.
			_targetMarkerText = _markerText;
			call {
				if (_markerText == "") exitWith {};
				if (_trackedKind != "man") exitWith {};
				if (group _tracked != group player) exitWith {};

				_trackedVehicle = vehicle _tracked;
				if (_trackedVehicle == _tracked) exitWith {};

				_groupUnitsInVehicle = [];
				{
					_member = _x;
					_memberVehicle = vehicle _member;
					if ((alive _member) && (_memberVehicle == _trackedVehicle)) then {
						_groupUnitsInVehicle = _groupUnitsInVehicle + [_member];
					};
				} forEach (units group player);

				if (count _groupUnitsInVehicle < 2) exitWith {};
				if ((_groupUnitsInVehicle select 0) != _tracked) exitWith {_targetMarkerText = ""};

				_crewUnitsInVehicle = [];
				{
					_roleUnit = _x;
					call {
						if (isNull _roleUnit) exitWith {};
						if !(_roleUnit in _groupUnitsInVehicle) exitWith {};
						if (_roleUnit in _crewUnitsInVehicle) exitWith {};
						_crewUnitsInVehicle = _crewUnitsInVehicle + [_roleUnit];
					};
				} forEach [driver _trackedVehicle, gunner _trackedVehicle, commander _trackedVehicle];

				_cargoUnitsInVehicle = [];
				{
					_member = _x;
					if !(_member in _crewUnitsInVehicle) then {
						_cargoUnitsInVehicle = _cargoUnitsInVehicle + [_member];
					};
				} forEach _groupUnitsInVehicle;

				_crewText = "";
				{
					_unitText = _x Call GetAIDigit;
					if (_crewText == "") then {
						_crewText = _unitText;
					} else {
						_crewText = Format["%1/%2", _crewText, _unitText];
					};
				} forEach _crewUnitsInVehicle;

				_cargoText = "";
				{
					_unitText = _x Call GetAIDigit;
					if (_cargoText == "") then {
						_cargoText = _unitText;
					} else {
						_cargoText = Format["%1/%2", _cargoText, _unitText];
					};
				} forEach _cargoUnitsInVehicle;

				_targetMarkerText = _crewText;
				if (_cargoText != "") then {
					if (_targetMarkerText == "") then {
						_targetMarkerText = _cargoText;
					} else {
						_targetMarkerText = Format["%1 | %2", _targetMarkerText, _cargoText];
					};
				};
			};

			if (_targetMarkerText != _lastMarkerText) then {
				_markerName setMarkerTextLocal _targetMarkerText;
				_lastMarkerText = _targetMarkerText;
			} else {
				_skippedWrites = _skippedWrites + 1;
			};

			_canMoveTracked = true;
			if (_trackedKind != "man") then {_canMoveTracked = canMove _tracked};
			if (!_canMoveTracked) then {
				_targetMarkerType = "mil_objective";
				_targetMarkerSize = [0.5,0.5];
			} else {
				_targetMarkerType = _markerType;
				_targetMarkerSize = _markerSize;
			};

			if (_targetMarkerType != _lastMarkerType) then {
				_markerName setMarkerTypeLocal _targetMarkerType;
				_lastMarkerType = _targetMarkerType;
				_typeWrites = _typeWrites + 1;
			} else {
				_skippedWrites = _skippedWrites + 1;
			};

			_sizeChanged = ((_targetMarkerSize select 0) != (_lastMarkerSize select 0)) || ((_targetMarkerSize select 1) != (_lastMarkerSize select 1));
			if (_sizeChanged) then {
				_markerName setMarkerSizeLocal _targetMarkerSize;
				_lastMarkerSize = +_targetMarkerSize;
			} else {
				_skippedWrites = _skippedWrites + 1;
			};

			// Marty: Performance Audit record for one unit/vehicle marker update.
			if !(isNil "PerformanceAudit_Record") then {
				if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
					["markerupdate_unit", diag_tickTime - _perfStart, Format["trackedKind:%1;trackedType:%2;refresh:%3;activeMarkers:%4;positionWrites:%5;typeWrites:%6;skippedWrites:%7;side:%8", _trackedKind, _trackedType, _sleepRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _positionWrites, _typeWrites, _skippedWrites, _side], "CLIENT"] Call PerformanceAudit_Record;
				};
			};
	};
};

if (_trackDeath && !isNull _tracked) then {
	_markerName setMarkerTypeLocal _deathMarkerType;
	_markerName setMarkerColorLocal _deathMarkerColor;
	_markerName setMarkerSizeLocal _deathMarkerSize;
	_typeWrites = _typeWrites + 1;
	sleep (missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_DEAD_DELAY");
};

// Marty: Performance Audit active marker script counter.
if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
	if !(isNil "PerformanceAuditMarkerScripts") then {
		missionNamespace setVariable ["PerformanceAuditMarkerScripts", ((missionNamespace getVariable ["PerformanceAuditMarkerScripts", 1]) - 1) max 0];
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["markerupdate_end", 0, Format["markerType:%1;trackedKind:%2;trackedType:%3;refresh:%4;activeMarkers:%5;positionWrites:%6;typeWrites:%7;skippedWrites:%8;side:%9", _markerType, _trackedKind, _trackedType, _refreshRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _positionWrites, _typeWrites, _skippedWrites, _side], "CLIENT"] Call PerformanceAudit_Record;
	};
};

deleteMarkerLocal _markerName;
