Private["_town","_range","_range_detect","_range_detect_active","_position","_groups","_town_camps","_town_camps_count","_town_teams","_airHeight","_unitsInactiveMax","_patrol_delay","_patrol_enabled","_ai_delegation_enabled","_town_defender_enabled","_town_occupation_enabled","_scanStart","_detectedFiltered","_defendersIgnored","_hostileSides","_detectedEnemyOnly","_currentEnemies"];

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
				_currentEnemies = [_detectedFiltered, _side] Call WFBE_CO_FNC_GetAreaEnemiesCount;
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

						if(_enemies_ground > 0) then {
							////
							_town setVariable ["wfbe_active", true];
							_town setVariable ["wfbe_episode_spawned", true];

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
						["INFORMATION", Format ["server_town_ai.sqf: Town [%1] ACTIVATED for [%2] (episode_spawned latch set, groups=%3).", _town getVariable "name", _side, count _groups]] Call WFBE_CO_FNC_LogContent;

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
					_town setVariable ["wfbe_active", false];
					_town setVariable ["wfbe_active_air", false];

					["INFORMATION", Format ["server_town_ai.sqf: Town [%1] DEACTIVATED for [%2] (inactivity, teams=%3).", _town getVariable "name", _side, count _town_teams]] Call WFBE_CO_FNC_LogContent;

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
								{if (local _x) then {deleteVehicle _x}} forEach units _x;
								if (({!(local _x)} count units _x) == 0) then {deleteGroup _x};
							};
						};
					} forEach _town_teams;

					//--- Teams vehicles.
					//--- Marty: same locality rule as above - HC-local vehicles die via cleanup-townai.
					{
						if (alive _x && {local _x}) then {
							if (!(isPlayer leader group _x)) then {deleteVehicle _x};
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
