Private["_town","_range","_range_detect","_range_detect_active","_position","_groups","_town_camps","_town_camps_count","_town_teams","_airHeight","_unitsInactiveMax","_patrol_delay","_patrol_enabled","_ai_delegation_enabled","_town_defender_enabled","_town_occupation_enabled","_scanStart","_detectedFiltered","_defendersIgnored","_hostileSides","_detectedEnemyOnly","_currentEnemies","_activeTownsBudgetMax","_activeTownCount","_budgetDeferLast","_now","_guerGroupsMax","_guerGroupCount","_guerDeferLast","_popTier","_activeMaxByTier"]; //--- B74.2: _popTier/_activeMaxByTier added for per-sweep pop-tier active-town budget

for "_j" from 0 to ((count towns) - 1) step 1 do
{
	_loc = towns select _j;
	["INITIALIZATION",Format ["server_town_ai.sqf : Initialized for [%1].", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
	sleep 0.01;
};

_range = 600;
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
	sleep 0.01;
};

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
				_dynRange = if (_town getVariable "wfbe_active" || _town getVariable "wfbe_active_air") then {_range_detect_active} else {_range_detect};
				_detected = (_town nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"],_dynRange]) unitsBelowHeight 20;

				//--- Defender classification: town/static defender AI must not wake towns (its own
				//--- OR a neighbouring enemy town it wandered near) - only players and bought AI count.
				_scanStart = diag_tickTime;
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

								if (_side == WFBE_DEFENDER) then {
									_groups = [_town, _side, true] Call WFBE_SE_FNC_GetTownGroupsDefender
								} else {
									_groups = [_town, _side, true] Call WFBE_SE_FNC_GetTownGroups;
								};
							};
						};
						//// start of creation
						["INFORMATION", Format ["server_town_ai.sqf: Town [%1] ACTIVATED for [%2] (episode_spawned latch set, groups=%3).", _town getVariable "name", _side, count _groups]] Call WFBE_CO_FNC_AICOMLog;

						if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side]) then {[_side,"HostilesDetectedNear",_town] Spawn SideMessage};



						//--- Get the positions and create the groups
						_camps = +(_town getVariable "camps");
						_positions = [];
						_teams = [];
						for '_i' from 0 to count(_groups)-1 do {
							_position = [];
							if (count _camps > 0 && random 100 > 50) then {
								_camp = _camps select floor (random count _camps);
								_camps = _camps - [_camp];
								_position = ([getPos _camp, 10, 50] call WFBE_CO_FNC_GetRandomPosition);
							} else {
								_position = ([getPos _town, 50, 300] call WFBE_CO_FNC_GetRandomPosition);
							};
							_position = [_position, 50] call WFBE_CO_FNC_GetEmptyPosition;
							[_positions, _position] call WFBE_CO_FNC_ArrayPush;
							[_teams, ([_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup)] call WFBE_CO_FNC_ArrayPush;
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
								if (count(missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID") > 0) then {
									[_town, _side, _groups, _positions, _teams] Call WFBE_CO_FNC_DelegateAITownHeadless;
									// Marty: HC-local groups are reported back by update-town-delegation after creation.
									_town setVariable ['wfbe_town_teams', _town_teams];
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
					if (isMultiplayer) then {[nil, "HandleSpecial", ["cleanup-townai", _town, _side]] Call WFBE_CO_FNC_SendToClients};

					//--- Teams Units.
					//--- Marty: delete only SERVER-LOCAL units here; HC-delegated units are deleted by the
					//--- cleanup-townai broadcast above on the machine where they are local. A server-side
					//--- deleteVehicle on HC-local units leaves ghost references in the HC group sync
					//--- (the Takistan 'Object not found' flood: ~17k/min per HC, 910k lines in one round).
					{
						if !(isNil '_x') then {
							if !(isNull _x) then {
								//--- B67 [wiki-wins]: never delete a player unit. The old loop deleted
								//--- every server-local unit; a player whose unit is server-local (e.g. a
								//--- JIP/HC-handoff edge) would be wiped on despawn. Guard with !isPlayer.
								{if (local _x && !(isPlayer _x)) then {deleteVehicle _x}} forEach units _x;
								if (({!(local _x)} count units _x) == 0) then {deleteGroup _x};
							};
						};
					} forEach _town_teams;

					//--- Teams vehicles.
					//--- Marty: same locality rule as above - HC-local vehicles die via cleanup-townai.
					{
						if (alive _x && {local _x}) then {
							//--- B67 [wiki-wins]: the old check tested only the group leader; a player
							//--- riding as a non-leader passenger/gunner would have their vehicle deleted
							//--- out from under them. Scan the whole crew: delete only if zero players aboard.
							if (({isPlayer _x} count crew _x) == 0) then {deleteVehicle _x};
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
					//// end of inner block
				};
			};
			//--- Patrols v2: the per-town spawn gate is retired (server_side_patrols.sqf drives patrols now).

		};

		sleep 0.05;
	};


	sleep 5;

};
