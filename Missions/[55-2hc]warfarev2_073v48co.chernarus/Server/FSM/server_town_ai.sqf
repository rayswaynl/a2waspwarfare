Private["_town","_range","_range_detect","_range_detect_active","_scanRange","_position","_groups","_town_camps","_town_camps_count","_town_teams","_airHeight","_unitsInactiveMax","_patrol_delay","_patrol_enabled","_ai_delegation_enabled","_town_defender_enabled","_town_occupation_enabled","_scanStart","_detectedFiltered","_defendersIgnored","_hostileSides","_detectedEnemyOnly","_currentEnemies","_activeTownsBudgetMax","_activeTownCount","_budgetDeferLast","_now","_guerGroupsMax","_guerGroupCount","_guerDeferLast","_popTier","_activeMaxByTier","_liveHCs","_townInitSleep","_doScan","_ctlLaneOn","_ctlSurviving"]; //--- B74.2: _popTier/_activeMaxByTier added for per-sweep pop-tier active-town budget; #252 _scanRange (AI scan-range override); #233 _townInitSleep (startup throttle)

_townInitSleep = missionNamespace getVariable ["WFBE_C_TOWNS_STARTUP_SLEEP", 0];
if (_townInitSleep <= 0) then {_townInitSleep = 0.01};

for "_j" from 0 to ((count towns) - 1) step 1 do
{
	_loc = towns select _j;
	["INITIALIZATION",Format ["server_town_ai.sqf : Initialized for [%1].", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
	sleep _townInitSleep;
};

_range = 600;
if ((missionNamespace getVariable ["WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE", 0]) > 0) then {
	_scanRange = missionNamespace getVariable ["WFBE_C_TOWNS_AI_SCAN_BASE_RANGE", 600];
	switch (typeName _scanRange) do {
		case "SCALAR": {
			_range = _scanRange;
			if (_range < 100) then {_range = 100};
		};
	};
};
_range_detect = _range * (missionNamespace getVariable "WFBE_C_TOWNS_DETECTION_RANGE_COEF");
_range_detect_active = _range * (missionNamespace getVariable "WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF");

_airHeight = missionNamespace getVariable "WFBE_C_TOWNS_DETECTION_RANGE_AIR";
_unitsInactiveMax = missionNamespace getVariable "WFBE_C_TOWNS_UNITS_INACTIVE";
_patrol_delay = missionNamespace getVariable "WFBE_C_PATROLS_DELAY_SPAWN";
_ai_delegation_enabled = missionNamespace getVariable "WFBE_C_AI_DELEGATION";
_town_defender_enabled = if ((missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER") > 0) then {true} else {false};
_town_occupation_enabled = if ((missionNamespace getVariable "WFBE_C_TOWNS_OCCUPATION") > 0) then {true} else {false};

//--- ACTIVE-TOWN BUDGET: cap on concurrently active towns (FPS lever).
//--- Tunable WFBE_C_TOWNS_ACTIVE_MAX; default 6. Set lower in params to cut spawn load.
//--- B74.2: this is only the initial seed/fallback now - the live budget is re-read per sweep
//--- from the pop-tier (WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER) inside the while loop below.
_activeTownsBudgetMax = missionNamespace getVariable "WFBE_C_TOWNS_ACTIVE_MAX";
if (isNil "_activeTownsBudgetMax") then { _activeTownsBudgetMax = 6 };
_budgetDeferLast = -9999; //--- Debounce timestamp for the "deferred" log line (1 per 5 min).

//--- GUER GROUP CAP: hard ceiling on total resistance groups (bounds runaway growth toward the ~144/side engine limit).
//--- Tunable WFBE_C_GUER_GROUPS_MAX; default 80. Recounted once per sweep (cheap) and used to defer resistance garrisons.
_guerGroupsMax = missionNamespace getVariable "WFBE_C_GUER_GROUPS_MAX";
if (isNil "_guerGroupsMax") then { _guerGroupsMax = 80 }; //--- keep in sync with WFBE_C_GUER_GROUPS_MAX (80)
_guerDeferLast = -9999; //--- Debounce timestamp for the GUER-cap "deferred" log line (1 per 5 min).
_guerGroupCount = 0;    //--- Live resistance group count; refreshed once per sweep below.

for "_k" from 0 to ((count towns) - 1) step 1 do
{
	_town = towns select _k;
	_town setVariable ["wfbe_active", false];
	_town setVariable ["wfbe_active_air", false];
	_town setVariable ["wfbe_inactivity", 0];
	_town setVariable ["wfbe_active_override", false];
	_town setVariable ['wfbe_active_vehicles', []];
	_town setVariable ['wfbe_town_teams', []];
	//--- Episode latch: true while this episode's units are live; cleared only after cleanup completes.
	//--- Prevents re-activation before the old complement is fully deleted.
	_town setVariable ["wfbe_episode_spawned", false];
	//--- cmdcon41-w3 GARRISON SORTIES: per-town sortie state seeded here so the manager never reads nil.
	//--- wfbe_sortie_grp = the ONE group currently out on patrol (grpNull = none); wfbe_sortie_started = its
	//--- launch time (drives the WFBE_C_TOWNS_SORTIE_MINS rotation). HARD bound: max 1 sortie per town (Ray).
	_town setVariable ["wfbe_sortie_grp", grpNull, true];
	_town setVariable ["wfbe_sortie_started", 0];
	sleep _townInitSleep;
};

//--- Perf phase jitter (2026-07-06): see server_town.sqf. Default 0 = V1.
if ((missionNamespace getVariable ["WFBE_C_LOOP_PHASE_JITTER", 0]) > 0) then {sleep (random 5)};
while {!WFBE_GameOver} do {

	//--- Count currently active towns once per sweep; publish for groupsGC audit line.
	_activeTownCount = 0;
	{
		if (_x getVariable ["wfbe_active", false]) then { _activeTownCount = _activeTownCount + 1 };
	} forEach towns;
	missionNamespace setVariable ["wfbe_active_town_count", _activeTownCount];

	//--- B74.2: re-read the active-town budget from the live pop-tier EVERY sweep (was cached once
	//--- at FSM start above). WFBE_PopTier is publicVariable'd by the server and shifts ~every 90s;
	//--- reading it here lets the active-town ceiling track LOW/MID/HIGH/FULL at runtime.
	//--- Keep the isNil seed/fallback: if the tiered array is unset, retain whatever was last cached.
	_popTier = missionNamespace getVariable ["WFBE_PopTier", 0]; if (_popTier < 0) then { _popTier = 0 };
	_activeMaxByTier = missionNamespace getVariable "WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER";
	if (!isNil "_activeMaxByTier") then {
		if (_popTier <= ((count _activeMaxByTier) - 1)) then { _activeTownsBudgetMax = _activeMaxByTier select _popTier };
	};

	//--- GDIR vehicle recovery: a prior server loop can only leave inflight after interruption.
	//--- The paid classes are ground hulls and their direct CreateTownUnits path does not suspend;
	//--- this single server loop cannot enter another sweep while that call is still live. Therefore
	//--- recover only here (never on a wall-clock lease): commit a tagged live hull idempotently, or
	//--- restore the SAME paid order to pending when no materialized hull survived the interruption.
	if ((missionNamespace getVariable ["AICOMV2_GDIR_VEHICLE", 0]) > 0) then {
		{
			private ["_gdirVehRecoveryCanRetry","_gdirVehRecoveryClass","_gdirVehRecoveryDriver","_gdirVehRecoveryHull","_gdirVehRecoveryHullOrderId","_gdirVehRecoveryOrder","_gdirVehRecoveryOrderId","_gdirVehRecoverySideId","_gdirVehRecoveryState","_gdirVehRecoveryTeam","_gdirVehRecoveryTeamOrderId","_gdirVehRecoveryTeams","_gdirVehRecoveryTier","_gdirVehRecoveryTown","_gdirVehRecoveryVehicles"];
			_gdirVehRecoveryTown = _x;
			_gdirVehRecoverySideId = _gdirVehRecoveryTown getVariable ["sideID", WFBE_C_UNKNOWN_ID];
			_gdirVehRecoveryOrder = _gdirVehRecoveryTown getVariable ["AICOMV2_GDIR_VEHICLE_ORDER", []];
			if (typeName _gdirVehRecoveryOrder == "ARRAY" && {count _gdirVehRecoveryOrder >= 3}) then {
				_gdirVehRecoveryOrderId = _gdirVehRecoveryOrder select 0;
				_gdirVehRecoveryTier = _gdirVehRecoveryOrder select 1;
				_gdirVehRecoveryState = _gdirVehRecoveryOrder select 2;
				if (typeName _gdirVehRecoveryOrderId == "SCALAR" && {typeName _gdirVehRecoveryTier == "SCALAR"} && {typeName _gdirVehRecoveryState == "STRING"} && {_gdirVehRecoveryTier > 0}) then {
					if (_gdirVehRecoveryState == "inflight") then {
						_gdirVehRecoveryClass = "";
						if (_gdirVehRecoveryTier == 1) then {_gdirVehRecoveryClass = "Offroad_DSHKM_Gue"};
						if (_gdirVehRecoveryTier == 2) then {_gdirVehRecoveryClass = "BMP2_GUE"};
						if (_gdirVehRecoveryTier >= 3) then {_gdirVehRecoveryClass = "T72_GUE"};
						_gdirVehRecoveryHull = _gdirVehRecoveryTown getVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
						_gdirVehRecoveryTeam = _gdirVehRecoveryTown getVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
						if (typeName _gdirVehRecoveryHull != "OBJECT") then {_gdirVehRecoveryHull = objNull};
						if (typeName _gdirVehRecoveryTeam != "GROUP") then {_gdirVehRecoveryTeam = grpNull};
						_gdirVehRecoveryHullOrderId = -1;
						if (!isNull _gdirVehRecoveryHull) then {_gdirVehRecoveryHullOrderId = _gdirVehRecoveryHull getVariable ["AICOMV2_GDIR_VEHICLE_ORDER_ID", -1]};
						_gdirVehRecoveryTeamOrderId = -1;
						if (!isNull _gdirVehRecoveryTeam) then {
							_gdirVehRecoveryTeamOrderId = _gdirVehRecoveryTeam getVariable "AICOMV2_GDIR_VEHICLE_ORDER_ID";
							if (isNil "_gdirVehRecoveryTeamOrderId") then {_gdirVehRecoveryTeamOrderId = -1};
						};
						_gdirVehRecoveryDriver = objNull;
						if (!isNull _gdirVehRecoveryHull) then {_gdirVehRecoveryDriver = driver _gdirVehRecoveryHull};
						if ((_gdirVehRecoverySideId == WFBE_C_GUER_ID || {_gdirVehRecoverySideId == WFBE_C_UNKNOWN_ID}) && {_gdirVehRecoveryClass != ""} && {!isNull _gdirVehRecoveryHull} && {!isNull _gdirVehRecoveryTeam} && {alive _gdirVehRecoveryHull} && {(typeOf _gdirVehRecoveryHull) == _gdirVehRecoveryClass} && {(_gdirVehRecoveryHull getVariable ["AICOMV2_GDIR_VEHICLE_ORDER_ID", -1]) == _gdirVehRecoveryOrderId} && {_gdirVehRecoveryTeamOrderId == _gdirVehRecoveryOrderId} && {!isNull _gdirVehRecoveryDriver} && {_gdirVehRecoveryDriver in (units _gdirVehRecoveryTeam)} && {(group _gdirVehRecoveryDriver) == _gdirVehRecoveryTeam} && {(vehicle _gdirVehRecoveryDriver) == _gdirVehRecoveryHull}) then {
							_gdirVehRecoveryTeams = _gdirVehRecoveryTown getVariable ["wfbe_town_teams", []];
							if (typeName _gdirVehRecoveryTeams != "ARRAY") then {_gdirVehRecoveryTeams = []};
							if !(_gdirVehRecoveryTeam in _gdirVehRecoveryTeams) then {_gdirVehRecoveryTeams = _gdirVehRecoveryTeams + [_gdirVehRecoveryTeam]};
							_gdirVehRecoveryVehicles = _gdirVehRecoveryTown getVariable ["wfbe_active_vehicles", []];
							if (typeName _gdirVehRecoveryVehicles != "ARRAY") then {_gdirVehRecoveryVehicles = []};
							if !(_gdirVehRecoveryHull in _gdirVehRecoveryVehicles) then {_gdirVehRecoveryVehicles = _gdirVehRecoveryVehicles + [_gdirVehRecoveryHull]};
							_gdirVehRecoveryTown setVariable ["wfbe_town_teams", _gdirVehRecoveryTeams];
							_gdirVehRecoveryTown setVariable ["wfbe_active_vehicles", _gdirVehRecoveryVehicles];
							_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", []];
							_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
							_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
							diag_log Format ["GDIR_VEHICLE_RECOVERED_COMMIT town:%1 tier:%2 order:%3", _gdirVehRecoveryTown getVariable "name", _gdirVehRecoveryTier, _gdirVehRecoveryOrderId];
						} else {
							//--- Recovery cannot retry while a tagged paid asset still survives.
							//--- A player or a nonlocal object is never torn down from the server; preserve
							//--- its inflight record for a later safe reconciliation rather than duplicate it.
							_gdirVehRecoveryCanRetry = true;
							if (!isNull _gdirVehRecoveryHull && {_gdirVehRecoveryHullOrderId == _gdirVehRecoveryOrderId || {_gdirVehRecoveryTeamOrderId == _gdirVehRecoveryOrderId}}) then {
								if (!local _gdirVehRecoveryHull || {({isPlayer _x} count (crew _gdirVehRecoveryHull)) > 0}) then {
									_gdirVehRecoveryCanRetry = false;
								} else {
									{if (!isPlayer _x && {local _x}) then {["gdir-recover-crew", _x, Format ["town=%1", _gdirVehRecoveryTown getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (crew _gdirVehRecoveryHull);
									["gdir-recover-hull", _gdirVehRecoveryHull, Format ["town=%1", _gdirVehRecoveryTown getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _gdirVehRecoveryHull;
								};
							};
							if (!isNull _gdirVehRecoveryTeam && {_gdirVehRecoveryTeamOrderId == _gdirVehRecoveryOrderId}) then {
								if (({isPlayer _x} count (units _gdirVehRecoveryTeam)) > 0) then {
									_gdirVehRecoveryCanRetry = false;
								} else {
									{if (local _x) then {["gdir-recover-team", _x, Format ["town=%1", _gdirVehRecoveryTown getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _gdirVehRecoveryTeam);
									if ((count (units _gdirVehRecoveryTeam)) == 0) then {deleteGroup _gdirVehRecoveryTeam} else {_gdirVehRecoveryCanRetry = false};
								};
							};
							if (_gdirVehRecoveryCanRetry) then {
								_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", [_gdirVehRecoveryOrderId, _gdirVehRecoveryTier, "pending"]];
								_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
								_gdirVehRecoveryTown setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
								diag_log Format ["GDIR_VEHICLE_RECOVERED_RETRY town:%1 tier:%2 order:%3 reason=invalid-hull-or-owner-changed", _gdirVehRecoveryTown getVariable "name", _gdirVehRecoveryTier, _gdirVehRecoveryOrderId];
							} else {
								diag_log Format ["GDIR_VEHICLE_RECOVERY_HELD town:%1 tier:%2 order:%3 reason=tagged-asset-not-safe-to-delete", _gdirVehRecoveryTown getVariable "name", _gdirVehRecoveryTier, _gdirVehRecoveryOrderId];
							};
						};
					};
				};
			};
		} forEach towns;
	};

	//--- GUER GROUP CAP: recount live resistance groups ONCE per sweep (not per town).
	//--- server_groupsGC.sqf computes a GUER group count only as a local (_cntGuer) and never
	//--- publishes a group count to missionNamespace, so use the allGroups fallback here,
	//--- hoisted out of the per-town loop so it stays cheap.
	_guerGroupCount = missionNamespace getVariable ["wfbe_grpcnt_guer", -1]; if (_guerGroupCount < 0) then { _guerGroupCount = {side _x == resistance} count allGroups; }; //--- B7: read groupsGC per-side count cache; live-scan fallback until the first GC sweep warms it
	for "_i" from 0 to ((count towns) - 1) step 1 do
	{
		_position = [];
		_groups = [];
		_currentEnemies = 0; //--- Initialised here so deactivation check is safe when side is disabled.
		_enemies = 0; //--- perf-dice fix (livetest 2026-07-06): must exist in TOWN-LOOP scope - assigned inside the _doScan block, and SQF inner-block assignments do not escape unless the var pre-exists in an outer scope (RPT: 'Undefined variable _enemies' at the deactivation check).

		_town = towns select _i;
		_town_teams = _town getVariable "wfbe_town_teams";
		//--- Patrols v2: town-based patrol gating retired (see Server\FSM\server_side_patrols.sqf).

		_sideID = _town getVariable "sideID";
		_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;


		if(_sideID != WFBE_C_UNKNOWN_ID ) then {
			_side_enabled = false;

			if (_side == WFBE_DEFENDER) then {
				if (_town_defender_enabled) then {_side_enabled = true};
			} else {
				if (_town_occupation_enabled) then {_side_enabled = true};
			};

			if(_side_enabled) then
			{
				//--- Perf dice (2026-07-06, Ray): dormant towns (not active, no air tier, no enemy seen within
				//--- DICE_GRACE) roll per side per sweep whether to run the 600 m nearEntities scan at all.
				//--- Active and recently-visited towns always scan. Worst case a dormant town notices an approach
				//--- one extra sweep late - in-theme: sentries are not always alert. Flag default 0 = exact V1.
				_doScan = true;
				if ((missionNamespace getVariable ["WFBE_C_TOWN_SCAN_DICE", 0]) > 0) then {
					if (isNil "WFBE_TownScanDiceAnnounced") then {
						WFBE_TownScanDiceAnnounced = true;
						["INFORMATION", "server_town_ai.sqf: dormant-town scan dice enabled (WFBE_C_TOWN_SCAN_DICE=1)."] Call WFBE_CO_FNC_AICOMLog;
					};
					if (!(_town getVariable "wfbe_active") && {!(_town getVariable "wfbe_active_air")} && {(time - (_town getVariable ["wfbe_inactivity", 0])) > (missionNamespace getVariable ["WFBE_C_TOWN_SCAN_DICE_GRACE", 30])}) then {
						if ((random 1) >= (missionNamespace getVariable ["WFBE_C_TOWN_SCAN_DICE_P", 0.5])) then {_doScan = false};
					};
				};
				if (_doScan) then {
				_dynRange = if (_town getVariable "wfbe_active" || _town getVariable "wfbe_active_air") then {_range_detect_active} else {_range_detect};
				_scanStart = diag_tickTime;
								//--- A2 air-tier (lane 800): scan includes all Air; split into ground vs high-air lists.
				private ["_detectedAll","_detectedGround","_detectedAir"];
				_detectedAll = (_town nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"],_dynRange]);
				_detectedGround = _detectedAll unitsBelowHeight 20;
				_detectedAir = [];
				if ((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0) then {
					{
						if ((_x isKindOf "Air") && {((getPos _x) select 2) > 20} && {({alive _x} count crew _x) > 0}) then {
							[_detectedAir, _x] call WFBE_CO_FNC_ArrayPush;
						};
					} forEach _detectedAll;
				};
				_detected = _detectedGround;


				//--- Defender classification: town/static defender AI must not wake towns (its own
				//--- OR a neighbouring enemy town it wandered near) - only players and bought AI count.
				_detectedFiltered = [];
				_defendersIgnored = 0;
				{
					if (_x getVariable ["WFBE_IsTownDefenderAI", false]) then {
						_defendersIgnored = _defendersIgnored + 1;
					} else {
						_detectedFiltered = _detectedFiltered + [_x];
					};
				} forEach _detected;

				//--- FINAL spec: for owned (non-resistance) towns, friendly passers-by must NOT trigger
				//--- activation — only units whose side is genuinely hostile to the owner count.
				//--- Resistance/neutral towns keep current behaviour (any non-friendly wakes them).
				if (_sideID != WFBE_C_GUER_ID && _sideID != WFBE_C_UNKNOWN_ID) then {
					//--- Build the set of sides that are enemies of the owning side.
					//--- Mirrors Common_GetAreaEnemiesCount.sqf: enemies = all sides minus owner minus ignored.
					_hostileSides = [west, east, resistance] - [_side];
					_detectedEnemyOnly = [];
					{
						if ((side _x) in _hostileSides) then {
							_detectedEnemyOnly = _detectedEnemyOnly + [_x];
						};
					} forEach _detectedFiltered;
					_detectedFiltered = _detectedEnemyOnly;
				};
				_currentEnemies = [_detectedFiltered, _side, (if (_sideID == WFBE_C_GUER_ID || _sideID == WFBE_C_UNKNOWN_ID) then {[resistance]} else {[]})] Call WFBE_CO_FNC_GetAreaEnemiesCount; //--- GUER condense (Ray): resistance only wakes WEST/EAST towns, never GUER/UNKNOWN
				_enemies = _currentEnemies;
				if (!isNil "PerformanceAudit_Record") then {
					if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
						["town_activation_scan", diag_tickTime - _scanStart, Format["town:%1;detected:%2;defendersIgnored:%3;enemies:%4", _town getVariable "name", count _detected, _defendersIgnored, _enemies], "SERVER"] Call PerformanceAudit_Record;
					};
				};
				} else {_currentEnemies = 0; _enemies = 0;};
				if(_enemies > 0)then{
					///
					//--- Keep the inactivity timer alive while enemies are present.
					_town setVariable ["wfbe_inactivity", time];

					if (_town getVariable "wfbe_active_override") then {
						_town setVariable ["wfbe_active_override", false];
						_town setVariable ["wfbe_active", false];
						//--- Also clear episode latch so the town re-garrisons on next tick.
						_town setVariable ["wfbe_episode_spawned", false];
					};

					//--- Episode latch: only spawn if this activation episode hasn't already
					//--- spawned units. wfbe_episode_spawned is cleared only when deactivation
					//--- cleanup fully completes, preventing double-spawn on the same episode.
					if(!(_town getVariable "wfbe_active") && !(_town getVariable ["wfbe_episode_spawned", false])) then {
						_below = 1;
						_enemies_ground = 1;
						//--- A2 air-contact check (lane 800 AICOMV2_LANE_GUER_DIRECTOR).
						//--- If only high-air contacts exist (no ground), gate with dice-roll ceiling.
						//--- Air below AIR_CEILING_MIN_M always activates; above AIR_CEILING_MAX_M never;
						//--- in between, roll per sweep to accumulate activation risk over loiter time.
						if ((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0 && {_enemies == 0} && {count _detectedAir > 0}) then {
							private ["_airMinM","_airMaxM","_airAlt","_airRoll","_airContact"];
							_airMinM = missionNamespace getVariable ["AICOMV2_GDIR_AIR_CEILING_MIN_M", 100];
							_airMaxM = missionNamespace getVariable ["AICOMV2_GDIR_AIR_CEILING_MAX_M", 600];
							//--- Take the lowest altitude of all detected high-air vehicles.
							_airAlt = 99999;
							{
								private ["_alt"];
								_alt = (getPos _x) select 2;
								if (_alt < _airAlt) then {_airAlt = _alt};
							} forEach _detectedAir;
							_airContact = false;
							if (_airAlt <= _airMinM) then {
								_airContact = true;
							} else {
								if (_airAlt < _airMaxM) then {
									//--- In the band: roll per sweep. Low alt = high probability.
									_airRoll = random 1;
									if (_airRoll < ((_airMaxM - _airAlt) / (_airMaxM - _airMinM))) then {_airContact = true};
								};
							};
							if (_airContact) then {
								//--- Air contact only: clear ground flag to route to AA-tier branch.
								_enemies_ground = 0;
								_enemies = count _detectedAir;
							};
						};

						//--- ACTIVE-TOWN BUDGET: skip activation if cap is reached.
						//--- B4: use the incremental _activeTownCount (seeded from the top-of-sweep
						//--- full count at L52-56 and +1 per town activated this sweep below) instead
						//--- of a full `forEach towns` recount on every activation decision. Behaviour
						//--- is identical: the only towns flipped to wfbe_active since the seed count
						//--- are the ones this sweep activated, each of which bumped _activeTownCount.
						if (_activeTownCount >= _activeTownsBudgetMax) then {
							//--- Debounced log: at most once per 5 minutes to avoid RPT spam.
							_now = time;
							if ((_now - _budgetDeferLast) >= 300) then {
								_budgetDeferLast = _now;
								["INFORMATION", Format ["server_town_ai.sqf: activation deferred for %1 - active-town budget %2/%3", _town getVariable "name", _activeTownCount, _activeTownsBudgetMax]] Call WFBE_CO_FNC_AICOMLog;
							};
							//--- Zero both flags to skip ground AND air activation branches below.
							_enemies_ground = 0;
							_enemies = 0;
						};

						//--- GUER GROUP CAP: skip activation if this is a resistance garrison and the
						//--- side is at its group budget. Mirrors the active-town deferral above so a
						//--- stalled WEST/EAST AI can't keep ratcheting GUER groups toward the ~144 ceiling.
						//--- _guerGroupCount is recounted once per sweep (top of loop); cheap here.
						if (_side == resistance && _guerGroupCount >= _guerGroupsMax) then {
							//--- Debounced log: at most once per 5 minutes to avoid RPT spam.
							_now = time;
							if ((_now - _guerDeferLast) >= 300) then {
								_guerDeferLast = _now;
								["INFORMATION", Format ["server_town_ai.sqf: GUER garrison deferred for %1 - resistance group budget %2/%3", _town getVariable "name", _guerGroupCount, _guerGroupsMax]] Call WFBE_CO_FNC_AICOMLog;
							};
							//--- Zero both flags to skip ground AND air activation branches below.
							_enemies_ground = 0;
							_enemies = 0;
						};

						if(_enemies_ground > 0) then {
							////
							_town setVariable ["wfbe_active", true];
							_town setVariable ["wfbe_episode_spawned", true];
							//--- B4: keep the incremental active-town counter in step with the
							//--- top-of-sweep seed (only wfbe_active towns are counted, matching
							//--- the old `forEach towns` recount and the top-of-sweep count above).
							_activeTownCount = _activeTownCount + 1;

							//--- Commander Town Ledger (fable/ctl-impl-v1) unit-count fix v2: tag this as a
							//--- GROUND wave so the post-creation contribution below (and the async
							//--- update-town-delegation report in Server_HandleSpecial.sqf) know whether to
							//--- add this wave real unit count into ledger field [3] - matching the
							//--- existing ground-only scope of the Server_GetTownGroups.sqf CTL blocks.
							//--- Flag-gated so flag-off leaves the mission byte-identical to HEAD.
							if ((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0) then {
								_town setVariable ["wfbe_ctl_ground_wave", true];
								//--- New-Bug-B fix (fable/ctl-survivor-bugs): snapshot the DEFENDING side at wave-creation
								//--- time so the async HC-delegation report (Server_HandleSpecial.sqf) can credit the side
								//--- that actually fielded this wave, not whichever side owns the town when the report
								//--- lands (a mid-episode capture can flip that). Flag-gated, same as the tag above.
								_town setVariable ["wfbe_ctl_wave_side", _side];
							};

							if (_side == WFBE_DEFENDER) then {
								_groups = [_town, _side] Call WFBE_SE_FNC_GetTownGroupsDefender
							} else {
								_groups = [_town, _side] Call WFBE_SE_FNC_GetTownGroups;
							};

							////
						};

						if(_enemies_ground == 0 && _enemies > 0) then {
							if(!(_town getVariable "wfbe_active_air")) then {
								_town setVariable ["wfbe_active_air", true];
								_town setVariable ["wfbe_episode_spawned", true];

								//--- Commander Town Ledger (fable/ctl-impl-v1) unit-count fix v2: air-only
								//--- waves stay OUT of ledger field [3] (matches the {!_aa_get} exclusion the
								//--- CTL overlay blocks in Server_GetTownGroups.sqf already apply).
								//--- Flag-gated so flag-off leaves the mission byte-identical to HEAD.
								if ((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0) then {
									_town setVariable ["wfbe_ctl_ground_wave", false];
									//--- New-Bug-B fix (fable/ctl-survivor-bugs): keep the side snapshot in sync for air-only
									//--- waves too (air-only waves never reach the HC-delegation credit block in
									//--- Server_HandleSpecial.sqf, gated on wfbe_ctl_ground_wave==true, but this avoids a
									//--- stale snapshot surviving from an earlier ground wave into this air-only one).
									_town setVariable ["wfbe_ctl_wave_side", _side];
								};

								if (_side == WFBE_DEFENDER) then {
									_groups = [_town, _side, true] Call WFBE_SE_FNC_GetTownGroupsDefender
								} else {
									_groups = [_town, _side, true] Call WFBE_SE_FNC_GetTownGroups;
								};
							};
						};
						//// start of creation
						["INFORMATION", Format ["server_town_ai.sqf: Town [%1] ACTIVATED for [%2] (episode_spawned latch set, groups=%3).", _town getVariable "name", _side, count _groups]] Call WFBE_CO_FNC_AICOMLog;
						//--- fix(tonight-20260717): mirror the _activeTownCount live-increment pattern above (~line 279)
						//--- for the GUER group-cap counter. _guerGroupCount was read once per sweep (top of loop) and
						//--- never bumped in-sweep, so resistance groups spawned earlier in THIS sweep were invisible to
						//--- the cap check (line ~260) for towns processed later in the same sweep - stale undercount that
						//--- let the group budget overshoot within a single sweep before the next sweep's recount caught up.
						if (_side == resistance) then { _guerGroupCount = _guerGroupCount + (count _groups) };

						if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side]) then {[_side,"HostilesDetectedNear",_town] Spawn SideMessage};



						//--- Get the positions and create the groups
						_camps = +(_town getVariable "camps");
						_positions = [];
						_teams = [];
						//--- fable/garrison-tonight (owner 2026-07-07): PERIMETER spread - ring the defenders around the
						//--- town EDGE by bearing instead of clustering at camps/center. WFBE_C_TOWNS_PERIMETER 0 = legacy.
						private ["_perimeterOn","_grpTotalP","_townRangeP","_townCenP","_bearingP","_distP","_ctlNewGrp"];
						_perimeterOn = (missionNamespace getVariable ["WFBE_C_TOWNS_PERIMETER", 0]) > 0;
						_grpTotalP   = count _groups; if (_grpTotalP < 1) then {_grpTotalP = 1};
						_townRangeP  = _town getVariable ["range", 300]; if (_townRangeP < 120) then {_townRangeP = 120};
						_townCenP    = getPos _town;
						for '_i' from 0 to count(_groups)-1 do {
							_position = [];
							if (_perimeterOn) then {
								_bearingP = (360 / _grpTotalP) * _i + (random 40) - 20;
								_distP    = _townRangeP * (0.70 + (random 0.25));
								_position = [(_townCenP select 0) + _distP * (sin _bearingP), (_townCenP select 1) + _distP * (cos _bearingP), 0];
							} else {
								if (count _camps > 0 && random 100 > 50) then {
									_camp = _camps select floor (random count _camps);
									_camps = _camps - [_camp];
									_position = ([getPos _camp, 10, 50] call WFBE_CO_FNC_GetRandomPosition);
								} else {
									_position = ([getPos _town, 50, 300] call WFBE_CO_FNC_GetRandomPosition);
								};
							};
							_position = [_position, 50] call WFBE_CO_FNC_GetEmptyPosition;
							[_positions, _position] call WFBE_CO_FNC_ArrayPush;
							_ctlNewGrp = ([_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup);
							//--- New-Bug-A fix (fable/ctl-survivor-bugs): stamp each freshly created group with the SAME
							//--- per-town wfbe_ctl_ground_wave state just set above for this wave (line ~287/~309), so
							//--- the survivor-tally numerator below (deactivation block) can tell ground-wave groups
							//--- from air-only-wave groups even after a later wave overwrites the per-town flag.
							//--- Group-local, non-public setVariable: both write (here) and read (the numerator loop)
							//--- run server-side in this same script, so no publicVariable sync is needed. Flag-gated:
							//--- byte-identical to HEAD when AICOMV2_LANE_CMD_TOWN_LEDGER=0.
							if ((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0) then {
								_ctlNewGrp setVariable ["wfbe_ctl_ground_wave", (_town getVariable ["wfbe_ctl_ground_wave", true])];
							};
							[_teams, _ctlNewGrp] call WFBE_CO_FNC_ArrayPush;
						};

						//--- Paid GDIR defensive vehicles are a server-owned supplement, never an item in
						//--- the normal group batch below. Client/HC delegation fans each ordinary group out
						//--- asynchronously, so it cannot safely provide exactly-once delivery for a paid order.
						//--- The server transitions the per-town record pending -> inflight without yielding,
						//--- runs one isolated Common_CreateTownUnits attempt, then commits or restores the
						//--- SAME order only from that synchronous receipt.
						private ["_gdirLegacyVehTier","_gdirVehClass","_gdirVehDelivery","_gdirVehOrder","_gdirVehOrderId","_gdirVehResult","_gdirVehSeq","_gdirVehState","_gdirVehTier"];
						_gdirVehOrder = [];
						if (_side == WFBE_DEFENDER && {(missionNamespace getVariable ["AICOMV2_GDIR_VEHICLE", 0]) > 0}) then {
							_gdirVehOrder = _town getVariable ["AICOMV2_GDIR_VEHICLE_ORDER", []];
							if (typeName _gdirVehOrder != "ARRAY") then {_gdirVehOrder = []};
							//--- Migrate one paid legacy scalar without dropping it. The scalar was public only
							//--- because the old materializer ran on clients/HCs; the new record stays server-local.
							if (count _gdirVehOrder < 2) then {
								_gdirLegacyVehTier = _town getVariable ["AICOMV2_GDIR_VEHICLE_TIER", 0];
								if (typeName _gdirLegacyVehTier != "SCALAR") then {_gdirLegacyVehTier = 0};
								if (_gdirLegacyVehTier > 0) then {
									_gdirVehSeq = (missionNamespace getVariable ["AICOMV2_GDIR_VEHICLE_ORDER_SEQ", 0]) + 1;
									missionNamespace setVariable ["AICOMV2_GDIR_VEHICLE_ORDER_SEQ", _gdirVehSeq];
									_gdirVehOrder = [_gdirVehSeq, _gdirLegacyVehTier, "pending"];
									_town setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", _gdirVehOrder];
									_town setVariable ["AICOMV2_GDIR_VEHICLE_TIER", 0, true];
									diag_log Format ["GDIR_VEHICLE_MIGRATED town:%1 tier:%2 order:%3", _town getVariable "name", _gdirLegacyVehTier, _gdirVehSeq];
								};
							};
							if (count _gdirVehOrder == 2) then {
								_gdirVehOrder = [_gdirVehOrder select 0, _gdirVehOrder select 1, "pending"];
								_town setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", _gdirVehOrder];
							};
							if (count _gdirVehOrder >= 3) then {
								_gdirVehOrderId = _gdirVehOrder select 0;
								_gdirVehTier = _gdirVehOrder select 1;
								_gdirVehState = _gdirVehOrder select 2;
								_gdirVehClass = "";
								if (_gdirVehTier == 1) then {_gdirVehClass = "Offroad_DSHKM_Gue"};
								if (_gdirVehTier == 2) then {_gdirVehClass = "BMP2_GUE"};
								if (_gdirVehTier >= 3) then {_gdirVehClass = "T72_GUE"};
								if (typeName _gdirVehOrderId == "SCALAR" && {typeName _gdirVehTier == "SCALAR"} && {typeName _gdirVehState == "STRING"} && {_gdirVehState == "pending"} && {_gdirVehTier > 0} && {_gdirVehClass != ""}) then {
									_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
									_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
									_town setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", [_gdirVehOrderId, _gdirVehTier, "inflight"]];
									_gdirVehResult = [_town, _side, [], [], [], [_gdirVehOrderId, _gdirVehTier, _gdirVehClass]] Call WFBE_CO_FNC_CreateTownUnits;
									_gdirVehDelivery = if (count _gdirVehResult > 2) then {_gdirVehResult select 2} else {[]};
									if (typeName _gdirVehDelivery == "ARRAY" && {count _gdirVehDelivery >= 2} && {(_gdirVehDelivery select 0) > 0} && {(_gdirVehDelivery select 1) == _gdirVehOrderId}) then {
										_town_teams = _town_teams + (_gdirVehResult select 0);
										_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + (_gdirVehResult select 1)];
										_town setVariable ['wfbe_town_teams', _town_teams];
										_guerGroupCount = _guerGroupCount + (count (_gdirVehResult select 0));
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", []];
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
										diag_log Format ["GDIR_VEHICLE_DELIVERED town:%1 tier:%2 order:%3", _town getVariable "name", _gdirVehTier, _gdirVehOrderId];
									} else {
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ORDER", [_gdirVehOrderId, _gdirVehTier, "pending"]];
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL", objNull];
										_town setVariable ["AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM", grpNull];
										diag_log Format ["GDIR_VEHICLE_RETRY town:%1 tier:%2 order:%3 reason=delivery-not-proven", _town getVariable "name", _gdirVehTier, _gdirVehOrderId];
									};
								};
							};
						};

						_use_server = true;

						switch (_ai_delegation_enabled) do {
							case 1: { //--- Client side delegation.
								_retVal = [_town, _side, _groups, _positions, _teams] Call WFBE_SE_FNC_DelegateAITown;
								// Marty: Only store server-created fallback groups; delegated clients report their own local groups back.
								_town_teams = _town_teams + (_retVal select 0);
								_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + (_retVal select 1)];
								_town setVariable ['wfbe_town_teams', _town_teams];
								_use_server = false;
							};
							case 2: { //--- Headless Client delegation.
								//--- Keep this preflight identical to Server_DelegateAITownHeadless: an alive leader
								//--- with owner 0 is a disconnected/locality-transferred zombie, so preserve the
								//--- existing server CreateTownUnits fallback instead of dispatching a dropped wave.
								_liveHCs = {!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 0}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
								if (_liveHCs > 0) then {
									[_town, _side, _groups, _positions, _teams] Call WFBE_CO_FNC_DelegateAITownHeadless;
									// Marty: HC-local groups are reported back by update-town-delegation after creation.
									//--- fable/townteams-queue-singlewriter: NO write-back here. This branch never modifies
									//--- _town_teams locally (unchanged since the read at wave start), so re-writing the stale
									//--- pre-dispatch snapshot only races the async update-town-delegation append in
									//--- Server_HandleSpecial.sqf - that lost update dropped the HC-reported delegated groups
									//--- from wfbe_town_teams, orphaning them past deactivation cleanup (historical zombies).
									//--- The HC-report handler is now the sole mutator of the delegated contribution (CTL single-writer doctrine, PR 1044).
									_use_server = false;
								};
							};
						};

						//--- Use Server AI.
						if (_use_server) then {
							_retVal = [_town, _side, _groups, _positions, _teams] Call WFBE_CO_FNC_CreateTownUnits;
							// Marty: Store the real groups returned by CreateTownUnits, not the preallocated input groups.
							_town_teams = _town_teams + (_retVal select 0);
							_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + (_retVal select 1)];
							_town setVariable ['wfbe_town_teams', _town_teams];

							//--- Commander Town Ledger (fable/ctl-impl-v1) unit-count fix v2 (PR #886 review:
							//--- crew undercounting): add this wave REAL Man-unit count (server-direct portion)
							//--- into ledger field [3]. (_retVal select 0) are the live groups CreateTownUnits
							//--- just created - `units _x` on them already includes auto-crew (driver/gunner/
							//--- commander), matching the survivor tally basis at deactivation below. Delegated
							//--- portions of this same wave (client/HC) report their real counts separately via
							//--- Server_HandleSpecial.sqf update-town-delegation once creation lands remotely.
							//--- Ground-only (wfbe_ctl_ground_wave), flag-gated: byte-identical to HEAD when off.
							if ((_side == west || {_side == east}) && {(_town getVariable ["wfbe_ctl_ground_wave", false])} && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
								private ["_ctlUnits6"];
								_ctlUnits6 = 0;
								{_ctlUnits6 = _ctlUnits6 + (count units _x)} forEach (_retVal select 0);
								//--- CTL single-writer (fable/ctl-readback-singlewriter): accumulate this wave real
								//--- Man-unit count into the per-town spawn scalar, not the shared ledger array.
								_town setVariable ["wfbe_ctl_lastspawn", (_town getVariable ["wfbe_ctl_lastspawn", 0]) + _ctlUnits6];
							};
						};

						//--- Man the defenses.
						[_town, _side, "spawn"] Call WFBE_SE_FNC_OperateTownDefensesUnits;

						//--- Cosmetic: faction smoke once per activation episode (guarded by the wfbe_episode_spawned latch above). Server-only, gated + capped + cooldown.
						[getPos _town, _side] Call WFBE_CO_FNC_SpawnFactionSmoke;

						//// end of creating
					};
					///
				};

			};//// end of side_enabled

			if((_town getVariable "wfbe_active") || (_town getVariable "wfbe_active_air")) then {

				//--- cmdcon41-w3 GARRISON SORTIES: the encounter-rate win. When a GROUND garrison is awake
				//--- (wfbe_active), rotate ONE 4-man-ish patrol element out of the EXISTING town groups on a
				//--- 300-800m ring around the town, then rotate it back after WFBE_C_TOWNS_SORTIE_MINS min so a
				//--- different group takes a turn. Reuses the town's own groups (wfbe_town_teams) so it NEVER
				//--- exceeds per-town AI caps and the sortie group stays a town defender: it is still in
				//--- wfbe_town_teams, so deactivation cleanup deletes it and it counts as a defender.
				//--- CRITICAL (wiki lesson): the moment the town is contested again (_currentEnemies>0) the
				//--- sortie is RECALLED so it returns for defense, and active-state/defender-origin semantics
				//--- below are untouched (this block only issues orders; it never flips wfbe_active or teams).
				//--- Ground-only (skip air-only activation), server-local groups only (delegated town AI is
				//--- HC/client-local; deleteGroup/waypoints must run where the group is local), max 1/town.
				//--- cmdcon41-w3m (ground-patrol-skip-naval-hvt): a naval-HVT carrier town (wfbe_is_naval_hvt / over-water)
				//--- must NEVER launch a garrison sortie - the 300-800m ring below is issued around the carrier's own pos,
				//--- which for an offshore carrier lies over OPEN WATER, sending the ground garrison swimming (the exact
				//--- ground-patrol-targets-naval failure). Skip the whole sortie block for naval towns; gated by
				//--- WFBE_C_PATROLS_SKIP_NAVAL (default 1). 2-arg getVariable + surfaceIsWater on the town logic: A2-OA-safe.
				private "_townIsNaval"; _townIsNaval = ((missionNamespace getVariable ["WFBE_C_PATROLS_SKIP_NAVAL", 1]) > 0) && {(_town getVariable ["wfbe_is_naval_hvt", false]) || {surfaceIsWater (getPos _town)}};
				if ((missionNamespace getVariable ["WFBE_C_TOWNS_SORTIES", 1]) > 0 && (_town getVariable "wfbe_active") && {!_townIsNaval}) then {
					_sortieMins = missionNamespace getVariable ["WFBE_C_TOWNS_SORTIE_MINS", 8]; if (_sortieMins < 1) then {_sortieMins = 8};
					_sortieGrp = _town getVariable ["wfbe_sortie_grp", grpNull];
					_sortieStarted = _town getVariable ["wfbe_sortie_started", 0];
					_townPos = getPos _town;
					//--- Only manage sorties over SERVER-LOCAL town groups (delegated AI lives elsewhere).
					_localTeams = [];
					{
						if (!isNil "_x") then {
							//--- cmdcon42 BUG-6: `local <group>` is A3-only (A2 `local` takes Objects; threw "Type Group,
							//--- expected Object" once per GUER town activation on live). A2-safe group locality = the
							//--- leader's locality; count-first so a leader exists before we test it.
							if (!isNull _x && {count units _x > 0} && {local (leader _x)}) then { _localTeams = _localTeams + [_x]; };
						};
					} forEach (_town getVariable ["wfbe_town_teams", []]);

					//--- Is the current sortie group still valid (alive, local, has men)?
					_sortieValid = false;
					if (!isNull _sortieGrp) then {
						//--- cmdcon42 BUG-6: same A2 `local`-on-group fix as above (count-first, then leader locality).
						if (count units _sortieGrp > 0 && {local (leader _sortieGrp)} && {_sortieGrp in _localTeams}) then { _sortieValid = true; };
					};

					if (_currentEnemies > 0) then {
						//--- CONTESTED: recall the sortie for defense immediately (tight move back onto the town),
						//--- then clear the slot so no new sortie launches while the town is under attack.
						if (_sortieValid) then {
							[_sortieGrp, _townPos, "MOVE", 40] Call AIMoveTo;
							["INFORMATION", Format ["server_town_ai.sqf: sortie RECALLED (contested) for %1.", _town getVariable "name"]] Call WFBE_CO_FNC_AICOMLog;
						};
						_town setVariable ["wfbe_sortie_grp", grpNull, true];
						_town setVariable ["wfbe_sortie_started", 0];
					} else {
						if (_sortieValid) then {
							//--- Rotation: after WFBE_C_TOWNS_SORTIE_MINS, bring this group home and free the slot
							//--- so a different group takes the next turn on the following eligible sweep.
							if ((time - _sortieStarted) >= (_sortieMins * 60)) then {
								[_sortieGrp, _townPos, "MOVE", 50] Call AIMoveTo;
								_town setVariable ["wfbe_sortie_grp", grpNull, true];
								_town setVariable ["wfbe_sortie_started", 0];
								["INFORMATION", Format ["server_town_ai.sqf: sortie rotated home for %1.", _town getVariable "name"]] Call WFBE_CO_FNC_AICOMLog;
							};
						} else {
							//--- No live sortie: pick the LEAST-ENGAGED local group (fewest units currently in
							//--- combat) and send it out on a 300-800m patrol ring. Bounded scan over the town's
							//--- own (typically <=6) groups; no allUnits, no per-frame work.
							if (count _localTeams > 0) then {
								_bestGrp = grpNull;
								_bestScore = 999999;
								{
									_g = _x;
									_inCombat = {behaviour _x == "COMBAT"} count (units _g);
									if (_inCombat < _bestScore) then { _bestScore = _inCombat; _bestGrp = _g; };
								} forEach _localTeams;
								if (!isNull _bestGrp) then {
									_ringR = 300 + (random 500); //--- 300-800m ring around the town.
									[_bestGrp, _townPos, _ringR] Call AIPatrol; //--- CYCLE waypoint ring (never idle).
									_town setVariable ["wfbe_sortie_grp", _bestGrp, true];
									_town setVariable ["wfbe_sortie_started", time];
									["INFORMATION", Format ["server_town_ai.sqf: sortie LAUNCHED for %1 (ring %2m).", _town getVariable "name", floor _ringR]] Call WFBE_CO_FNC_AICOMLog;
								};
							};
						};
					};
				};

				//--- Deactivation guard: only consider deactivating when enemies are genuinely absent
				//--- (_currentEnemies == 0). If enemies are present the inactivity timer was just
				//--- refreshed above, so the time-check would not fire anyway — but guarding here
				//--- explicitly prevents the rare race where detection misses enemies for one tick
				//--- while they are still physically in radius, which would stall the timer and let
				//--- the 90-s window expire mid-fight.
				if(_currentEnemies == 0 && time - (_town getVariable "wfbe_inactivity") > _unitsInactiveMax) then {
					//// inner block
					//--- B4: keep the incremental active-town counter exact. The old per-activation
					//--- `forEach towns` recount observed live state, so a town deactivated earlier in
					//--- THIS sweep reduced the count seen by later towns' activation decisions. Only
					//--- wfbe_active towns are counted (matching the seed), so decrement only when this
					//--- town was wfbe_active before we clear the flags.
					if (_town getVariable ["wfbe_active", false]) then { _activeTownCount = _activeTownCount - 1 };
					_town setVariable ["wfbe_active", false];
					_town setVariable ["wfbe_active_air", false];

					["INFORMATION", Format ["server_town_ai.sqf: Town [%1] DEACTIVATED for [%2] (inactivity, teams=%3).", _town getVariable "name", _side, count _town_teams]] Call WFBE_CO_FNC_AICOMLog;

					// Marty: Ask delegated clients/HCs to delete their local town AI groups where deleteGroup can actually work.
					if (isMultiplayer) then {
						[nil, "HandleSpecial", ["cleanup-townai", _town, _side]] Call WFBE_CO_FNC_SendToClients;
						if !(isNil {_town getVariable "wfbe_airfield_garrison_units"}) then {
							[nil, "HandleSpecial", ["cleanup-airfield-garrison", _town]] Call WFBE_CO_FNC_SendToClients;
						};
					};

					//--- Commander Town Ledger (fable/ctl-impl-v1) survivor tally (B3, fix ORDER+DIM): the
					//--- alive UNIT count is captured HERE, inside the deletion forEach below, BEFORE
					//--- deleteVehicle runs on each unit - counting it AFTER (as before) always read ~0
					//--- because the units were already gone. Unit count (not group count) per spec B3:
					//--- field [3] "lastSpawnUnits" is a per-unit denominator, so the ratio must be unit/unit.
					_ctlLaneOn = (_side == west || {_side == east}) && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0};
					_ctlSurviving = 0;

					//--- Teams Units.
					//--- Marty: delete only SERVER-LOCAL units here; HC-delegated units are deleted by the
					//--- cleanup-townai broadcast above on the machine where they are local. A server-side
					//--- deleteVehicle on HC-local units leaves ghost references in the HC group sync
					//--- (the Takistan 'Object not found' flood: ~17k/min per HC, 910k lines in one round).
					{
						if !(isNil '_x') then {
							if !(isNull _x) then {
								//--- New-Bug-A fix (fable/ctl-survivor-bugs, mirror of Bug 2): the denominator (the two
								//--- accumulation sites above + Server_GetTownGroups.sqf's CTL blocks) deliberately
								//--- excludes air-only-wave contributions via {!_aa_get} / wfbe_ctl_ground_wave==false.
								//--- This numerator tally used to sum ALL of _town_teams unconditionally - ground AND
								//--- air-only groups both - once a ground wave was followed by a separate air-only tail
								//--- wave within the same activation episode (the per-town flag gets overwritten by the
								//--- later wave, but both waves' groups stay in _town_teams until full deactivation).
								//--- Fix: check the PER-GROUP tag stamped at creation time (~line 355) instead of the
								//--- current, possibly-overwritten, per-town flag. Default true (count) for any untagged
								//--- group so pre-existing/edge-case groups keep the old behaviour - this only narrows
								//--- counting for groups explicitly tagged air-only.
								if (_ctlLaneOn && {([_x, "wfbe_ctl_ground_wave", true] Call WFBE_CO_FNC_GroupGetBool)}) then { //--- sweep-fix #936: _x is a GROUP; 2-arg getVariable returns nil-not-default on groups (G1 trap) - route through the group-safe wrapper.
									{if (alive _x) then {_ctlSurviving = _ctlSurviving + 1}} forEach units _x;
								};
								//--- B67 [wiki-wins]: never delete a player unit. The old loop deleted
								//--- every server-local unit; a player whose unit is server-local (e.g. a
								//--- JIP/HC-handoff edge) would be wiped on despawn. Guard with !isPlayer.
								{if (local _x && !(isPlayer _x)) then {["town-sweep-unit", _x, Format ["town=%1", _town getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach units _x;
								if (({!(local _x)} count units _x) == 0) then {deleteGroup _x};
							};
						};
					} forEach _town_teams;

					//--- Commander Town Ledger (fable/ctl-impl-v1) survivor read-back (B3).
					//--- Flag-off (AICOMV2_LANE_CMD_TOWN_LEDGER=0) => skipped, byte-identical to HEAD.
					//--- _ctlSurviving (alive UNIT count) was tallied above, in the SAME forEach that
					//--- deletes the units, BEFORE deleteVehicle ran - counting it here (after deletion)
					//--- would always read ~0 (fix: read-back ORDERING).
					if (_ctlLaneOn) then {
						//--- CTL single-writer (fable/ctl-readback-singlewriter): publish the survival RATIO to a
						//--- per-town scalar; the CTL tick applies it to strength [2] (the tick is the sole ledger
						//--- writer). _ctlSurviving was tallied above (the ORDER fix), before deleteVehicle ran.
						private ["_ctlLastSpawn","_ctlRatio"];
						_ctlLastSpawn = _town getVariable ["wfbe_ctl_lastspawn", 0];
						if (_ctlLastSpawn > 0) then {
							_ctlRatio = (_ctlSurviving / _ctlLastSpawn) max 0;
							if (_ctlRatio > 1) then {_ctlRatio = 1};
							_town setVariable ["wfbe_ctl_pending_ratio", _ctlRatio];
							diag_log Format ["CTLSTAT|v1|%1|READBACK|town=%2|ratio=%3", str _side, _town getVariable ["name", "?"], _ctlRatio];
						};
						_town setVariable ["wfbe_ctl_lastspawn", 0];
					};

					//--- Teams vehicles.
					//--- Marty: same locality rule as above - HC-local vehicles die via cleanup-townai.
					{
						if (alive _x && {local _x}) then {
							//--- B67 [wiki-wins]: the old check tested only the group leader; a player
							//--- riding as a non-leader passenger/gunner would have their vehicle deleted
							//--- out from under them. Scan the whole crew: delete only if zero players aboard.
							if (({isPlayer _x} count crew _x) == 0) then {["town-sweep-hull", _x, Format ["town=%1", _town getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x};
						};
					} forEach (_town getVariable 'wfbe_active_vehicles');

					_town_teams = [];
					_town setVariable ['wfbe_town_teams', []];
					_town setVariable ['wfbe_active_vehicles', []];

					//--- Despawn the town defenses unit.
					[_town, _side, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits;

					//--- Episode latch cleared AFTER cleanup completes: the next activation episode
					//--- is now permitted. Clearing before this point would allow a re-spawn during
					//--- the cleanup window (groups being deleted on HC while new ones are created).
					_town setVariable ["wfbe_episode_spawned", false];
					//--- cmdcon41-w3 GARRISON SORTIES: sorties END on deactivation. The sortie group was one of
					//--- wfbe_town_teams and is already deleted by the cleanup above; just clear the pointers so
					//--- no stale group reference survives into the next activation episode.
					_town setVariable ["wfbe_sortie_grp", grpNull, true];
					_town setVariable ["wfbe_sortie_started", 0];
					//// end of inner block
				};
			};
			//--- Patrols v2: the per-town spawn gate is retired (server_side_patrols.sqf drives patrols now).

		};

		sleep 0.05;
	};


	sleep 5;

};
