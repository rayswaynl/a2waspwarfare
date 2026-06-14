// Marty: PERF1 consolidated client marker loop. One scheduled script replaces the
// per-unit Common_MarkerUpdate VMs (150-400 concurrent at peak) and the per-aircraft
// Common_AARadarMarkerUpdate VMs. Registrars append entries; this loop walks the
// registries on a 0.2s tick and only services entries whose per-type refresh is due,
// preserving the original cadences: HQ 0.2s, player-group infantry 1s, other infantry
// 3s, vehicles 1s, AAR 5/3/1s by upgrade level.
//
// Concurrency note: registrars append with a single-statement array add; removals here
// tombstone the slot (set to 0) and compaction only rebuilds the array once enough
// tombstones accumulate, keeping the lost-append race window negligible. The marker
// name ledger sweep below heals any marker that would slip through regardless.
Private ["_aarEntry","_aarUpgradeCache","_actionPlayer","_dist","_ehHandle","_lowFpsSince","_mapWasClosed","_rebuildCooldownUntil","_rebuildFps","_activeEntries","_aircraftName","_altitude","_aarLevel","_budgetMax","_budgetServiced","_canMoveTracked","_cargoText","_cargoUnitsInVehicle","_compactNeeded","_crewText","_crewUnitsInVehicle","_currentDir","_currentPos","_deadDelay","_dirDiff","_entry","_forceRefresh","_groupUnitsInVehicle","_height","_kind","_knownNames","_lastDir","_lastPos","_lastSize","_lastText","_lastType","_lastVisible","_ledger","_mapVisible","_markerName","_markerText","_member","_memberVehicle","_now","_object","_oppositeSide","_perfStart","_perfTick","_refreshRate","_roleUnit","_sizeChanged","_sleepRate","_speed","_sweepNext","_targetMarkerSize","_targetMarkerText","_targetMarkerType","_tombstones","_tracked","_trackedVehicle","_typeOfObject","_unitText","_upgrades"];

if (isNil "WFBE_CL_UnitMarkerRegistry") then {WFBE_CL_UnitMarkerRegistry = []};
if (isNil "WFBE_CL_AARMarkerRegistry") then {WFBE_CL_AARMarkerRegistry = []};
if (isNil "WFBE_CL_UnitMarkerLedger") then {WFBE_CL_UnitMarkerLedger = []};

_sweepNext = time + 60;
_aarUpgradeCache = [sideUnknown, -1, -999]; // [side, level, lastCheck diag_tickTime]
_height = missionNamespace getVariable "WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION";

// Marty: PERF1 slice C - local refresh lever. Manual map-marker rebuild action plus an
// automatic rebuild when client FPS stays under the threshold for 60s (mitigation AND
// the branch-B accumulated-state experiment in one). Threshold 0 disables the auto path.
WFBE_CL_MarkerRebuildRequested = false;
_actionPlayer = player;
_actionPlayer addAction ["Rebuild Map Markers", "Common\Common_MarkerRebuildRequest.sqf", [], 0, false, true, "", "true"];
_lowFpsSince = -1;
_rebuildCooldownUntil = 0;
_rebuildFps = missionNamespace getVariable ["WFBE_C_MARKER_REBUILD_FPS", 15];

_mapWasClosed = false;

while {true} do {

	sleep 0.2;
	_perfTick = diag_tickTime;
	_now = time;
	_mapVisible = visibleMap;
	// Marty: PERF3 token-bucket - cap visual-refresh work per tick to avoid map-FPS halving
	// under large AI wars. Default 30 = 150 markers/sec at 5 Hz; override via missionNamespace.
	_budgetMax = missionNamespace getVariable ["WFBE_C_MARKER_BUDGET_PER_TICK", 30];
	_budgetServiced = 0;

	// Marty: PERF2 map-open dirty pass - when map transitions from closed to open, reset
	// every unit-marker nextDue to 0 so they all re-service immediately on this tick,
	// giving the player a fully up-to-date picture the moment the map opens.
	if (!_mapVisible) then {
		_mapWasClosed = true;
	} else {
		if (_mapWasClosed) then {
			{
				if (typeName _x == "ARRAY") then {
					(_x) set [15, 0];
				};
			} forEach WFBE_CL_UnitMarkerRegistry;
			_mapWasClosed = false;
		};
	};

	// Marty: PERF1 follow-up - the player object changes on respawn, which silently
	// drops the manual rebuild action. Re-attach when the object changes (alive check
	// skips the brief objNull/corpse window so we attach once per life, not per tick).
	if ((player != _actionPlayer) && {alive player}) then {
		_actionPlayer = player;
		_actionPlayer addAction ["Rebuild Map Markers", "Common\Common_MarkerRebuildRequest.sqf", [], 0, false, true, "", "true"];
	};

	// ---------------------------------------------------------------- refresh lever
	if (_rebuildFps > 0) then {
		if (diag_fps < _rebuildFps) then {
			if (_lowFpsSince < 0) then {_lowFpsSince = _now};
		} else {
			_lowFpsSince = -1;
		};
		if (_lowFpsSince >= 0 && {(_now - _lowFpsSince) > 60} && {_now >= _rebuildCooldownUntil}) then {
			WFBE_CL_MarkerRebuildRequested = true;
			diag_log Format ["STATE-AUDIT: auto marker rebuild triggered at fps:%1 time:%2", diag_fps, round _now];
		};
	};

	if (WFBE_CL_MarkerRebuildRequested) then {
		WFBE_CL_MarkerRebuildRequested = false;
		_rebuildCooldownUntil = _now + 300;
		_lowFpsSince = -1;
		_perfStart = diag_tickTime;
		{
			if (typeName _x == "ARRAY") then {
				_entry = _x;
				_markerName = _entry select 1;
				_tracked = _entry select 0;
				deleteMarkerLocal _markerName;
				if (isNull _tracked) then {
					WFBE_CL_UnitMarkerRegistry set [_forEachIndex, 0];
				} else {
					createMarkerLocal [_markerName, getPos _tracked];
					// PERF4 - rebuild re-creates the marker at the live position, so resync the
					// position-delta cache (slot 18) to match what was just drawn; otherwise a stale
					// lastPos could suppress the next legitimate move-write for a unit sitting near it.
					_entry set [18, getPos _tracked];
					if ((_entry select 16) == 1) then {
						_markerName setMarkerTypeLocal (_entry select 7);
						_markerName setMarkerColorLocal (_entry select 8);
						_markerName setMarkerSizeLocal (_entry select 9);
					} else {
						if ((_entry select 12) != "") then {_markerName setMarkerTextLocal (_entry select 12)};
						_markerName setMarkerTypeLocal (_entry select 13);
						_markerName setMarkerColorLocal (_tracked getVariable ["OriginalMarkerColor", "ColorWhite"]);
						_markerName setMarkerSizeLocal (_entry select 14);
					};
				};
			};
		} forEach WFBE_CL_UnitMarkerRegistry;
		{
			if (typeName _x == "ARRAY") then {
				_aarEntry = _x;
				_markerName = _aarEntry select 1;
				deleteMarkerLocal _markerName;
				if (isNull (_aarEntry select 0)) then {
					WFBE_CL_AARMarkerRegistry set [_forEachIndex, 0];
				} else {
					createMarkerLocal [_markerName, [0,0,0]];
					_markerName setMarkerTypeLocal "mil_arrow2";
					_markerName setMarkerColorLocal "ColorRed";
					_markerName setMarkerSizeLocal [0.5, 0.5];
					_markerName setMarkerAlphaLocal 0;
					_aarEntry set [4, false];
					_aarEntry set [8, true];
				};
			};
		} forEach WFBE_CL_AARMarkerRegistry;
		diag_log Format ["STATE-AUDIT: marker rebuild done in %1s; entries:%2;aarEntries:%3;allMapMarkers:%4", diag_tickTime - _perfStart, count WFBE_CL_UnitMarkerRegistry, count WFBE_CL_AARMarkerRegistry, count allMapMarkers];
	};
	_tombstones = 0;
	_activeEntries = 0;

	// ---------------------------------------------------------------- unit markers
	{
		if (typeName _x == "ARRAY") then {
			_entry = _x;
			_activeEntries = _activeEntries + 1;

			call {

				// Marty: Dead-marker display window elapsed - drop the marker.
				if ((_entry select 16) == 1) exitWith {
					if (_now >= (_entry select 17)) then {
						deleteMarkerLocal (_entry select 1);
						WFBE_CL_UnitMarkerRegistry set [_forEachIndex, 0];
						if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
							if !(isNil "PerformanceAuditMarkerScripts") then {
								missionNamespace setVariable ["PerformanceAuditMarkerScripts", ((missionNamespace getVariable ["PerformanceAuditMarkerScripts", 1]) - 1) max 0];
							};
						};
					};
				};

				_tracked = _entry select 0;

				// Marty: Unit gone - either show the death marker for the configured delay or drop now.
				if (isNull _tracked || !(alive _tracked)) exitWith {
					_markerName = _entry select 1;
					// Marty: EH hygiene - dead bodies keep their Fired EHs until GC deletion; drop ours now.
					if !(isNull _tracked) then {
						_ehHandle = _tracked getVariable "WFBE_BlinkFiredEH";
						if !(isNil "_ehHandle") then {
							_tracked removeEventHandler ["Fired", _ehHandle];
							_tracked setVariable ["WFBE_BlinkFiredEH", nil, false];
						};
						_ehHandle = _tracked getVariable "WFBE_MissileTerrainMaskingEH";
						if !(isNil "_ehHandle") then {
							_tracked removeEventHandler ["Fired", _ehHandle];
							_tracked setVariable ["WFBE_MissileTerrainMaskingEH", nil, false];
						};
					};
					if ((_entry select 6) && !(isNull _tracked)) then {
						_markerName setMarkerTypeLocal (_entry select 7);
						_markerName setMarkerColorLocal (_entry select 8);
						_markerName setMarkerSizeLocal (_entry select 9);
						_deadDelay = missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_DEAD_DELAY";
						_entry set [16, 1];
						_entry set [17, _now + _deadDelay];
					} else {
						deleteMarkerLocal _markerName;
						WFBE_CL_UnitMarkerRegistry set [_forEachIndex, 0];
						if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
							if !(isNil "PerformanceAuditMarkerScripts") then {
								missionNamespace setVariable ["PerformanceAuditMarkerScripts", ((missionNamespace getVariable ["PerformanceAuditMarkerScripts", 1]) - 1) max 0];
							};
						};
					};
				};

				if (_now < (_entry select 15)) exitWith {};

				// Marty: PERF2 map-closed suspend - death-window expiry and dead-unit detection
				// above still run while the map is closed; only visual refresh work is skipped.
				// nextDue is NOT advanced here so the entry re-services immediately on map open.
				if (!_mapVisible) exitWith {};

				// Marty: PERF3 token-bucket - budget gate. nextDue is NOT advanced so the entry
				// is re-tried next tick (rolling stagger, no starvation). Only fires when map is
				// open (map-closed entries already exited above), so the budget is shared across
				// the visible-refresh path only.
				if (_budgetServiced >= _budgetMax) exitWith {};
				_budgetServiced = _budgetServiced + 1;

				_perfStart = diag_tickTime;
				_markerName = _entry select 1;
				_kind = _entry select 10;

				// Marty: Keep player-group infantry at one-second refresh; other infantry uses a stable three-second refresh.
				_sleepRate = _entry select 5;
				if (_kind == "man" && {group _tracked != group player}) then {_sleepRate = _sleepRate max 3};
				// Marty: PERF2 distance-tiered refresh - far markers update less often; position
				// snaps current on map-open dirty pass (nextDue reset to 0 on map open above).
				if !(_entry select 11) then {
					_dist = player distance _tracked;
					if (_dist > 2000) then {_sleepRate = _sleepRate max 5} else {if (_dist > 500) then {_sleepRate = _sleepRate max 2}};
				};
				_entry set [15, _now + _sleepRate];

				// Marty: Keep position refresh independent from type/size bookkeeping so marker caching cannot freeze units.
				// PERF4 position-delta gate - only re-write the marker position when the unit actually moved
				// more than a small threshold, mirroring the AAR path's 25m gate (line ~457). The large pool of
				// idle garrison/defensive friendly infantry and parked vehicles otherwise pay a setMarkerPosLocal
				// every service for zero visible change; this kills that redundant write volume without removing,
				// hiding, or delaying any marker (a unit that moves is still snapped on its very next due tick).
				// lastPos lives in entry slot 18 (appended here on first service; nil-safe init below).
				_currentPos = getPos _tracked;
				_lastPos = _entry select 18;
				if (isNil "_lastPos") then {
					_markerName setMarkerPosLocal _currentPos;
					_entry set [18, _currentPos];
				} else {
					if ((_currentPos distance _lastPos) > 3) then {
						_markerName setMarkerPosLocal _currentPos;
						_entry set [18, _currentPos];
					};
				};

				if (_entry select 11) exitWith { // --- HQ: position only, 0.2s cadence.
					if !(isNil "PerformanceAudit_Record") then {
						if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
							["markerupdate_hq", diag_tickTime - _perfStart, Format["trackedKind:%1;refresh:%2;activeMarkers:%3", _kind, _entry select 5, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0]], "CLIENT"] Call PerformanceAudit_Record;
						};
					};
				};

				// Marty: When player-group infantry share one vehicle, show readable crew-first text like 2/4/3 | 5/6.
				_targetMarkerText = _entry select 4;
				call {
					if ((_entry select 4) == "") exitWith {};
					if (_kind != "man") exitWith {};
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

				if (_targetMarkerText != (_entry select 12)) then {
					_markerName setMarkerTextLocal _targetMarkerText;
					_entry set [12, _targetMarkerText];
				};

				_canMoveTracked = true;
				if (_kind != "man") then {_canMoveTracked = canMove _tracked};
				if (!_canMoveTracked) then {
					_targetMarkerType = "mil_objective";
					_targetMarkerSize = [0.5,0.5];
				} else {
					_targetMarkerType = _entry select 2;
					_targetMarkerSize = _entry select 3;
				};

				if (_targetMarkerType != (_entry select 13)) then {
					_markerName setMarkerTypeLocal _targetMarkerType;
					_entry set [13, _targetMarkerType];
				};

				_lastSize = _entry select 14;
				_sizeChanged = ((_targetMarkerSize select 0) != (_lastSize select 0)) || ((_targetMarkerSize select 1) != (_lastSize select 1));
				if (_sizeChanged) then {
					_markerName setMarkerSizeLocal _targetMarkerSize;
					_entry set [14, +_targetMarkerSize];
				};

				if !(isNil "PerformanceAudit_Record") then {
					if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
						["markerupdate_unit", diag_tickTime - _perfStart, Format["trackedKind:%1;refresh:%2;activeMarkers:%3", _kind, _sleepRate, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0]], "CLIENT"] Call PerformanceAudit_Record;
					};
				};
			};
		} else {
			_tombstones = _tombstones + 1;
		};
	} forEach WFBE_CL_UnitMarkerRegistry;

	// Marty: Compact rarely - the rebuild is the only registry reassignment, so the
	// lost-append window stays tiny and the ledger sweep heals any slip-through.
	if (_tombstones > 64) then {
		_compactNeeded = [];
		{
			if (typeName _x == "ARRAY") then {_compactNeeded = _compactNeeded + [_x]};
		} forEach WFBE_CL_UnitMarkerRegistry;
		WFBE_CL_UnitMarkerRegistry = _compactNeeded;
	};

	// ---------------------------------------------------------------- AAR markers
	{
		if (typeName _x == "ARRAY") then {
			_aarEntry = _x;

			call {

				_object = _aarEntry select 0;
				_markerName = _aarEntry select 1;

				// Marty: Aircraft gone - hide and drop the AAR marker.
				if (isNull _object || !(alive _object)) exitWith {
					deleteMarkerLocal _markerName;
					WFBE_CL_AARMarkerRegistry set [_forEachIndex, 0];
					if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
						if !(isNil "PerformanceAuditAARMarkerScripts") then {
							missionNamespace setVariable ["PerformanceAuditAARMarkerScripts", ((missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 1]) - 1) max 0];
						};
					};
					if !(isNil "PerformanceAudit_Record") then {
						if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
							["aar_marker_end", 0, Format["type:%1;side:%2;activeAAR:%3", typeOf _object, _aarEntry select 2, missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0]], "CLIENT"] Call PerformanceAudit_Record;
						};
					};
				};

				if (_now < (_aarEntry select 11)) exitWith {};

				// Marty: PERF3 token-bucket - shared budget counter with unit markers.
				// nextDue NOT advanced; entry re-tried next tick.
				if (_budgetServiced >= _budgetMax) exitWith {};
				_budgetServiced = _budgetServiced + 1;

				_perfStart = diag_tickTime;

				// Marty: AAR markers are only useful while the Arma 2 map screen is open.
				if !(_mapVisible) exitWith {
					_aarEntry set [8, true];
					if (_aarEntry select 4) then {
						_markerName setMarkerAlphaLocal 0;
						_aarEntry set [4, false];
					};
					_aarEntry set [11, _now + 2];
				};

				if !(antiAirRadarInRange) exitWith {
					_aarEntry set [8, true];
					if (_aarEntry select 4) then {
						_markerName setMarkerAlphaLocal 0;
						_aarEntry set [4, false];
					};
					_aarEntry set [11, _now + 5];
				};

				_currentPos = getPos _object;
				if ((_currentPos select 2) <= _height) exitWith {
					_aarEntry set [8, true];
					if (_aarEntry select 4) then {
						_markerName setMarkerAlphaLocal 0;
						_aarEntry set [4, false];
					};
					_aarEntry set [11, _now + 5];
				};

				// Marty: One shared 5s upgrade-level cache per tick replaces the per-script caches.
				_oppositeSide = _aarEntry select 3;
				// Marty: PR31 review caveat - key the cache by side so three-way AAR entries never read another side's level.
				if ((_aarUpgradeCache select 0) != _oppositeSide || {(diag_tickTime - (_aarUpgradeCache select 2)) > 5}) then {
					_upgrades = (_oppositeSide) Call WFBE_CO_FNC_GetSideUpgrades;
					_aarUpgradeCache set [0, _oppositeSide];
					_aarUpgradeCache set [1, _upgrades select WFBE_UP_AAR];
					_aarUpgradeCache set [2, diag_tickTime];
				};
				_aarLevel = _aarUpgradeCache select 1;

				_refreshRate = 5; // AAR0: 5, AAR1: 3, AAR2: 1
				if (_aarLevel > 0) then {_refreshRate = 3};
				if (_aarLevel > 1) then {_refreshRate = 1};
				_aarEntry set [11, _now + _refreshRate];

				_speed = str(round(speed _object)) + "km/h"; // Get the speed (AAR0)
				_altitude = " "; // Defined empty (AAR1)
				_aircraftName = " "; // Defined empty (AAR2)

				if (_aarLevel > 0) then {
					_altitude = str(round(getPosATL _object select 2)) + "m";
				};

				if (_aarLevel > 1) then {
					_typeOfObject = typeOf _object;
					_aircraftName = [_typeOfObject] call WFBE_CL_FNC_ReturnAircraftNameFromItsType;
				};

				_forceRefresh = _aarEntry select 8;
				if !(_aarEntry select 4) then {
					_markerName setMarkerAlphaLocal 1;
					_aarEntry set [4, true];
					_forceRefresh = true;
				};

				_markerText = format ["%1 %2 %3", _speed, _altitude, _aircraftName];
				if (_forceRefresh || _markerText != (_aarEntry select 5)) then {
					_markerName setMarkerTextLocal _markerText;
					_aarEntry set [5, _markerText];
				};

				_lastPos = _aarEntry select 6;
				if (_forceRefresh || (_currentPos distance _lastPos) > 25) then {
					_markerName setMarkerPosLocal _currentPos;
					_aarEntry set [6, _currentPos];
				};

				_currentDir = getDir _object;
				_lastDir = _aarEntry select 7;
				_dirDiff = abs (_currentDir - _lastDir);
				if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
				if (_forceRefresh || _dirDiff > 7) then {
					_markerName setMarkerDirLocal _currentDir;
					_aarEntry set [7, _currentDir];
				};

				_aarEntry set [8, false];

				if !(isNil "PerformanceAudit_Record") then {
					if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
						["aar_marker_update", diag_tickTime - _perfStart, Format["type:%1;activeAAR:%2;upgrade:%3;refresh:%4", typeOf _object, missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0], _aarLevel, _refreshRate], "CLIENT"] Call PerformanceAudit_Record;
					};
				};
			};
		};
	} forEach WFBE_CL_AARMarkerRegistry;

	// ------------------------------------------------- ledger sweep (state hygiene)
	// Marty: The registries double as the owner index for every unitMarker* this client
	// created; any ledgered name no longer owned by a live entry is an orphan - delete it.
	if (_now >= _sweepNext) then {
		_sweepNext = _now + 60;
		_knownNames = [];
		{
			if (typeName _x == "ARRAY") then {_knownNames = _knownNames + [_x select 1]};
		} forEach WFBE_CL_UnitMarkerRegistry;
		{
			if (typeName _x == "ARRAY") then {_knownNames = _knownNames + [_x select 1]};
		} forEach WFBE_CL_AARMarkerRegistry;
		_ledger = [];
		{
			if (_x in _knownNames) then {
				_ledger = _ledger + [_x];
			} else {
				deleteMarkerLocal _x;
			};
		} forEach WFBE_CL_UnitMarkerLedger;
		WFBE_CL_UnitMarkerLedger = _ledger;
	};

	// Marty: PERF3 publish serviced count so Client_StateAudit can read it cheaply.
	WFBE_CL_MarkerBudgetLastServiced = _budgetServiced;

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["markerloop_tick", diag_tickTime - _perfTick, Format["entries:%1;aarEntries:%2;tombstones:%3;activeMarkers:%4;budgetServiced:%5;budgetMax:%6", _activeEntries, count WFBE_CL_AARMarkerRegistry, _tombstones, missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0], _budgetServiced, _budgetMax], "CLIENT"] Call PerformanceAudit_Record;
		};
	};
};
