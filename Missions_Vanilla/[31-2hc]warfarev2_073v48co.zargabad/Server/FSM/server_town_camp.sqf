// Marty: Global camp capture manager; individual town calls only register their camps.
private["_town","_camps","_flags","_workers","_worker","_workerIndex","_lastRun","_delta","_legacyCycle","_captureScale","_scanDelay","_camp","_flag","_base","_objects","_inRange","_west","_east","_resistance","_skip","_protected","_captured","_sideID","_supplyValue","_town_starting_sv","_resistanceDominion","_westDominion","_eastDominion","_newSID","_newSide","_side","_force","_camp_cap_rate","_camp_range","_camp_range_players"];

_camps = _this select 0;
_town = _this select 1;
_flags = _this select 2;

// Marty: Register every town's camps, but keep only one global camp manager alive.
if (isNil "WFBE_SE_TownCampWorkers") then {WFBE_SE_TownCampWorkers = []};
WFBE_SE_TownCampWorkers set [count WFBE_SE_TownCampWorkers, [_town, _camps, _flags, time]];

if !(isNil "WFBE_SE_TownCampManagerRunning") exitWith {};
WFBE_SE_TownCampManagerRunning = true;

_newSID = -1;
_force = 0;

_camp_cap_rate = missionNamespace getVariable "WFBE_C_CAMPS_CAPTURE_RATE";
_camp_range = missionNamespace getVariable "WFBE_C_CAMPS_RANGE";
_camp_range_players = missionNamespace getVariable "WFBE_C_CAMPS_RANGE_PLAYERS";

// Marty: One second is responsive enough for capture while cutting camp scans by an order of magnitude.
_scanDelay = 1;

while {!WFBE_GameOver} do {

	// Marty: Performance Audit timing for one global camp capture server cycle.
	_perfStart = diag_tickTime;
	_perfCamps = 0;
	_perfNearEntities = 0;
	_perfDetected = 0;
	_perfNetworkWrites = 0;
	_perfCaptures = 0;
	_perfActive = 0;

	_workers = +WFBE_SE_TownCampWorkers;

	for "_workerIndex" from 0 to ((count _workers) - 1) step 1 do {
		_worker = _workers select _workerIndex;
		_town = _worker select 0;
		_camps = _worker select 1;
		_flags = _worker select 2;
		_lastRun = _worker select 3;

		_delta = (time - _lastRun) max 0.01;
		_legacyCycle = 0.1 + ((count _camps) * 0.01);
		_captureScale = _delta / _legacyCycle;
		_town_starting_sv = _town getVariable "startingSupplyValue";

		for "_i" from 0 to ((count _camps) - 1) step 1 do {
			// Marty: Performance Audit active time excludes only the global cooperative sleep.
			_perfItemStart = diag_tickTime;

			_camp = _camps select _i;
			_perfCamps = _perfCamps + 1;
			_flag = _flags select _i;

			_base = _camp getVariable "wfbe_camp_bunker";
			if (alive _base) then {
				_objects = _camp nearEntities["Man", _camp_range];
				_perfNearEntities = _perfNearEntities + 1;
				_perfDetected = _perfDetected + count _objects;

				// Marty: Players must be closer than AI to contest a camp; keep the old rule.
				_inRange = +_objects;
				{
					if (isPlayer _x) then {
						if (_x distance _camp > _camp_range_players) then {_objects = _objects - [_x]};
					};
				} forEach _inRange;

				_west = west countSide _objects;
				_east = east countSide _objects;
				_resistance = resistance countSide _objects;

				if (_west > 0 || _east > 0 || _resistance > 0) then {
					_skip = false;
					_protected = false;
					_captured = false;
					_sideID = _camp getVariable "sideID";
					_supplyValue = _camp getVariable "supplyValue";

					_resistanceDominion = (_resistance > _east && _resistance > _west);
					_westDominion = (_west > _east && _west > _resistance);
					_eastDominion = (_east > _west && _east > _resistance);

					if (_sideID == WFBE_C_GUER_ID && _resistanceDominion) then {_force = _resistance; _protected = true; _skip = true};
					if (_sideID == WFBE_C_EAST_ID && _eastDominion) then {_force = _east; _protected = true; _skip = true};
					if (_sideID == WFBE_C_WEST_ID && _westDominion) then {_force = _west; _protected = true; _skip = true};

					switch (true) do {
						case _resistanceDominion: {_resistance = if (_east > _west) then {_resistance - _east} else {_resistance - _west}; _force = _resistance; _east = 0; _west = 0};
						case _westDominion: {_west = if (_east > _resistance) then {_west - _east} else {_west - _resistance}; _force = _west; _east = 0; _resistance = 0};
						case _eastDominion: {_east = if (_west > _resistance) then {_east - _west} else {_east - _resistance}; _force = _east; _west = 0; _resistance = 0};
					};

					if (!_resistanceDominion && !_westDominion && !_eastDominion) then {_west = 0; _east = 0; _resistance = 0};

					if !(_skip) then {
						_newSID = switch (true) do {case (_west > 0): {WFBE_C_WEST_ID}; case (_east > 0): {WFBE_C_EAST_ID}; case (_resistance > 0): {WFBE_C_GUER_ID}};
						_supplyValue = round(_supplyValue - (((_resistance + _east + _west) * _camp_cap_rate) * _captureScale));
						if (_supplyValue < 1) then {_supplyValue = _town_starting_sv; _captured = true};

						if (_supplyValue != (_camp getVariable "supplyValue")) then {
							_perfNetworkWrites = _perfNetworkWrites + 1;
							_camp setVariable ["supplyValue", _supplyValue, true];
						};
					};

					if (_protected) then {
						if (_supplyValue < _town_starting_sv) then {
							_supplyValue = _supplyValue + round((_force * _camp_cap_rate) * _captureScale);
							if (_supplyValue > _town_starting_sv) then {_supplyValue = _town_starting_sv};

							if (_supplyValue != (_camp getVariable "supplyValue")) then {
								_perfNetworkWrites = _perfNetworkWrites + 1;
								_camp setVariable ["supplyValue", _supplyValue, true];
							};
						};
					};

					if (_captured) then {
						_newSide = (_newSID) Call WFBE_CO_FNC_GetSideFromID;
						_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

						if (_sideID != WFBE_C_UNKNOWN_ID) then {
							if (missionNamespace getVariable Format ["WFBE_%1_PRESENT", _side]) then {[_side, "LostAt", ["Strongpoint", _town]] Spawn SideMessage};
						};

						if (missionNamespace getVariable Format ["WFBE_%1_PRESENT", _newSide]) then {[_newSide, "CapturedNear", ["Strongpoint", _town]] Spawn SideMessage};

						_camp setVariable ["sideID", _newSID, true];
						_perfNetworkWrites = _perfNetworkWrites + 1;
						_perfCaptures = _perfCaptures + 1;
						_flag setFlagTexture (missionNamespace getVariable Format["WFBE_%1FLAG", str _side]);

						[nil, "CampCaptured", [_camp, _newSID, _sideID]] Call WFBE_CO_FNC_SendToClients;
					};
				};
			};

			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		};

		_worker set [3, time];
	};

	WFBE_SE_TownCampWorkers = _workers;

	// Marty: Performance Audit record for one global camp capture server cycle.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["server_town_camp", _perfActive, Format["workers:%1;camps:%2;nearEntities:%3;detected:%4;networkWrites:%5;captures:%6;cycleMs:%7", count _workers, _perfCamps, _perfNearEntities, _perfDetected, _perfNetworkWrites, _perfCaptures, round ((diag_tickTime - _perfStart) * 1000)], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _scanDelay;
};

WFBE_SE_TownCampManagerRunning = nil;
