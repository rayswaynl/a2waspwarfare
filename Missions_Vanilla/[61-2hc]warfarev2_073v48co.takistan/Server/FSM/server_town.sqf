

// "towns" use it to get all initiated towns on map

_timeAttacked = 0;
_activeEnemies = 0;
_contested = false;
_sidesPresent = 0;
_force = 0;
_lastUp = 0;
_skipTimeSupply = false;
_newSID = -1;
_newSide = civilian;
_town_camps_capture_rate = missionNamespace getVariable "WFBE_C_CAMPS_CAPTURE_RATE_MAX";
_town_capture_mode = missionNamespace getVariable "WFBE_C_TOWNS_CAPTURE_MODE";
_town_capture_range = switch (_town_capture_mode) do {
	case  0: {"WFBE_C_TOWNS_CAPTURE_RANGE"};
	case 1: {"WFBE_C_TOWNS_CAPTURE_THRESHOLD_RANGE"};
	default {"WFBE_C_TOWNS_CAPTURE_RANGE"};
};
_town_capture_range = missionNamespace getVariable _town_capture_range;
_town_capture_rate = missionNamespace getVariable 'WFBE_C_TOWNS_CAPTURE_RATE';
_town_supply_time_delay = missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY";
_town_supply_time = if ((missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM") == 1) then {true} else {false};

_town_defender_enabled = if ((missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER") > 0) then {true} else {false};
_town_occupation_enabled = if ((missionNamespace getVariable "WFBE_C_TOWNS_OCCUPATION") > 0) then {true} else {false};
_isTimeToUpdateSuppluys = false;
for "_j" from 0 to ((count towns) - 1) step 1 do
{
	_loc = towns select _j;
	["INITIALIZATION",Format ["server_town.sqf : Initialized for [%1].", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
	sleep 0.01;
};

while {!WFBE_GameOver} do {

	for "_i" from 0 to ((count towns) - 1) step 1 do
	{

		_location = towns select _i;
		_startingSupplyValue = _location getVariable "startingSupplyValue";
		_maxSupplyValue = _location getVariable "maxSupplyValue";

				_sideID = _location getVariable "sideID";
				_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;
				//--- PERF dedupe REVERTED (caused capture-detection wedges twice); back to the proven
				//--- direct scan. The server_town_ai cache-write remains but is simply unread now.
				_perfT0PA = diag_tickTime; //--- FPS PROFILING (claude-gaming): bracket the uncached per-town capture scan (suspected #1 server frametime sink)
				_objects = (_location nearEntities[["Man","Car","Motorcycle","Tank","Air","Ship"], _town_capture_range]) unitsBelowHeight 10;

				_west = west countSide _objects;
				_east = east countSide _objects;
				_resistance = resistance countSide _objects;
				["town_capture_scan", diag_tickTime - _perfT0PA] call PerformanceAudit_Record; //--- FPS PROFILING (claude-gaming): self-gated, server-side, ~0.01ms overhead

				_activeEnemies = switch (_sideID) do {
					case WFBE_C_WEST_ID: {_east + _resistance};
					case WFBE_C_EAST_ID: {_west + _resistance};
					case WFBE_C_GUER_ID: {_east + _west};
				};

				//--- CONTESTED stamp (wasp-dash-safe-telemetry, claude-gaming 2026-06-21): mark this town as
				//--- actively fought over, for the public /wasp dashboard's ANONYMIZED contested COUNT (read
				//--- once / 60s in server_groupsGC.sqf -> CONTESTED|v1). Mutual-knowledge only: no town
				//--- name/side/position is ever exported, just whether the town is in conflict. Reuses the
				//--- per-side presence counts already in hand above (no extra nearEntities scan). Definition:
				//---   owned town  -> enemies present eroding it (capture-in-progress / under attack)
				//---   neutral town -> 2+ sides physically clashing over it.
				_contested = false;
				if (_sideID == WFBE_C_UNKNOWN_ID) then {
					_sidesPresent = 0;
					if (_west > 0) then {_sidesPresent = _sidesPresent + 1};
					if (_east > 0) then {_sidesPresent = _sidesPresent + 1};
					if (_resistance > 0) then {_sidesPresent = _sidesPresent + 1};
					_contested = (_sidesPresent >= 2);
				} else {
					_contested = (_activeEnemies > 0);
				};
				_location setVariable ["wfbe_contested", _contested];

				_supplyValue = _location getVariable "supplyValue";

				if (!WFBE_ISTHREEWAY && _town_supply_time) then {
					//--- If we're running on 2 sides, skip the time based supply if the defender hold the town.
					_skipTimeSupply = if (_sideID == WFBE_DEFENDER_ID) then {true} else {false};
				};

				if(_town_supply_time && _sideID != WFBE_C_UNKNOWN_ID && !_skipTimeSupply) then
				{

					if (_activeEnemies == 0 && (_supplyValue < _maxSupplyValue) && _sideID != RESISTANCEID) then
					{

						if (_isTimeToUpdateSuppluys) then {
							//diag_log format ["town number: %1", _i];
							//_lastUp = time + _town_supply_time_delay;
							_increaseOf = 1;
							if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side]) then {

								_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
								_increaseOf = 2 * ((missionNamespace getVariable "WFBE_C_TOWNS_SUPPLY_LEVELS_TIME") select (_upgrades select WFBE_UP_SUPPLYRATE));
							};
							_supplyValue = _supplyValue + _increaseOf;
							if (_supplyValue > _maxSupplyValue) then {_supplyValue = _maxSupplyValue};
							_location setVariable ["supplyValue", _supplyValue, true];
						};
					};
				};

	if(_west > 0 || _east > 0 || _resistance > 0) then {
		_skip = false;
		_protected = false;
		_captured = false;

		if(_town_capture_mode == 1) then {
			_resistanceDominion = if (_resistance > _east && _resistance > _west) then {true} else {false};
			_westDominion = if (_west > _east && _west > _resistance) then {true} else {false};
			_eastDominion = if (_east > _west && _east > _resistance) then {true} else {false};

			if (_sideID == WFBE_C_GUER_ID && _resistanceDominion) then {_force = _resistance;_protected = true;_skip = true};
			if (_sideID == WFBE_C_EAST_ID && _eastDominion) then {_force = _east;_protected = true;_skip = true};
			if (_sideID == WFBE_C_WEST_ID && _westDominion) then {_force = _west;_protected = true;_skip = true};

			if (_resistanceDominion) then {
				_resistance = if (_east > _west) then {_resistance - _east} else {_resistance - _west};
				_force = _resistance;
				_east = 0;
				_west = 0;
			};
			if (_westDominion) then {
				_west = if (_east > _resistance) then {_west - _east} else {_west - _resistance};
				_force = _west;
				_east = 0;
				_resistance = 0;
			};
			if (_eastDominion) then {
				_east = if (_west > _resistance) then {_east - _west} else {_east - _resistance};
				_force = _east;
				_west = 0;
				_resistance = 0;
			};

			if (!_resistanceDominion && !_westDominion && !_eastDominion) then {_west = 0; _east = 0; _resistance = 0};
		};

		if(_town_capture_mode == 0) then {
			//--- Classic capture.
			if (_sideID == WFBE_C_GUER_ID && _resistance > 0) then {_force = _resistance;_protected = true;_skip = true};
			if (_sideID == WFBE_C_EAST_ID && _east > 0) then {_force = _east;_protected = true;_skip = true};
			if (_sideID == WFBE_C_WEST_ID && _west > 0) then {_force = _west;_protected = true;_skip = true};

			if (_east > 0 && _west > 0) then {_skip = true};
			if (_west > 0 && _resistance > 0) then {_skip = true};
			if (_resistance > 0 && _east > 0) then {_skip = true};
		};

		if(_town_capture_mode == 2) then {
			_resistanceDominion = if (_resistance > _east && _resistance > _west) then {true} else {false};
			_westDominion = if (_west > _east && _west > _resistance) then {true} else {false};
			_eastDominion = if (_east > _west && _east > _resistance) then {true} else {false};

			if (_sideID == RESISTANCEID && _resistanceDominion) then {_force = _resistance;_protected = true;_skip = true};
			if (_sideID == EASTID && _eastDominion) then {_force = _east;_protected = true;_skip = true};
			if (_sideID == WESTID && _westDominion) then {_force = _west;_protected = true;_skip = true};

			if (_resistanceDominion) then {
				_resistance = if (_east > _west) then {_resistance - _east} else {_resistance - _west};
				_force = _resistance;
				_east = 0;
				_west = 0;
			};
			if (_westDominion) then {
				_west = if (_east > _resistance) then {_west - _east} else {_west - _resistance};
				_force = _west;
				_east = 0;
				_resistance = 0;
			};
			if (_eastDominion) then {
				_east = if (_west > _resistance) then {_east - _west} else {_east - _resistance};
				_force = _east;
				_west = 0;
				_resistance = 0;
			};

			if (!_resistanceDominion && !_westDominion && !_eastDominion) then {_west = 0; _east = 0; _resistance = 0};

			_totalCamps = _location Call GetTotalCamps;

			if (_west > 0 && west in WFBE_PRESENTSIDES) then {
				if (_totalCamps != ([_location,west] Call GetTotalCampsOnSide)) then {_skip = true};
			};
			if (_east > 0 && east in WFBE_PRESENTSIDES) then {
				if (_totalCamps != ([_location,east] Call GetTotalCampsOnSide)) then {_skip = true};
			};
			if (_resistance > 0 && resistance in WFBE_PRESENTSIDES) then {
				if (_totalCamps != ([_location,resistance] Call GetTotalCampsOnSide)) then {_skip = true};
			};
		};

		if !(_skip) then {
			_newSID = switch (true) do {case (_west > 0): {WFBE_C_WEST_ID}; case (_east > 0): {WFBE_C_EAST_ID}; case (_resistance > 0): {WFBE_C_GUER_ID};};
			_newSide = (_newSID) Call WFBE_CO_FNC_GetSideFromID;
			_rate = _town_capture_rate * (([_location,_newSide] Call WFBE_CO_FNC_GetTotalCampsOnSide) / (_location Call WFBE_CO_FNC_GetTotalCamps)) * _town_camps_capture_rate;
			if (_rate < 1) then {_rate = 1};

			if (_sideID != WFBE_C_UNKNOWN_ID) then {
				if (_activeEnemies > 0 && time > _timeAttacked && (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side])) then {_timeAttacked = time + 60;[_side, "IsUnderAttack", ["Town", _location]] Spawn SideMessage};
			};

			_supplyValue = round(_supplyValue - (_resistance + _east + _west) * _rate);
			if (_supplyValue < 1) then {_supplyValue = _startingSupplyValue; _captured = true};
			_location setVariable ["supplyValue",_supplyValue,true];
		};

		if (_protected) then {
			if (_supplyValue < _startingSupplyValue) then {
				_supplyValue = _supplyValue + _force * _town_capture_rate;
				if (_supplyValue > _startingSupplyValue) then {_supplyValue = _startingSupplyValue};
				_location setVariable ["supplyValue",_supplyValue,true];
			};
		};

		if(_captured) then {
			["INFORMATION", Format ["server_town.sqf: Town [%1] was captured by [%2] From [%3].", _location, _newSide, _side]] Call WFBE_CO_FNC_LogContent;

			if (_sideID != WFBE_C_UNKNOWN_ID) then {
				if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side]) then {[_side, "Lost", _location] Spawn SideMessage};
			};

			if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_newSide]) then {[_newSide, "Captured", _location] Spawn SideMessage};

			_location setVariable ["sideID",_newSID,true];

			//--- B74.2: leaderboard TOWN-capture credit to each capturing player physically present on the new
			//--- owner's side at flip. _objects (the per-town capture scan above) holds the nearby entities; capture
			//--- the outer side into a private so the nested forEach's magic _x stays safe.
			private ["_capSide","_capUid"];
			_capSide = _newSide;
			{ if (isPlayer _x && {alive _x} && {side _x == _capSide}) then {_capUid = getPlayerUID _x; if (_capUid != "") then {[_capUid, WFBE_STAT_CAPTURES_TOWN, 1] call WFBE_SE_FNC_RecordStat}} } forEach _objects;

			// AICOMSTAT FIRST_TOWN metric: emit once per side per round on its first capture.
			// Plain logic getVariable with isNil guard (A2 OA safe; no == on Bool).
			Private ["_ftLogik","_ftFlag","_ftKey","_ftMin","_ftSec","_ftTownName"];
			_ftLogik = _newSide Call WFBE_CO_FNC_GetSideLogic;
			if (!isNil "_ftLogik" && {!isNull _ftLogik}) then {
				_ftKey  = "wfbe_first_town_captured";
				_ftFlag = _ftLogik getVariable _ftKey;
				if (isNil "_ftFlag") then { _ftFlag = false };
				if (!_ftFlag) then {
					_ftLogik setVariable [_ftKey, true];
					_ftMin     = round (time / 60);
					_ftSec     = round time;
					_ftTownName = _location getVariable ["name", "unknown"];
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _newSide) + "|" + str _ftMin + "|FIRST_TOWN|" + _ftTownName + "-t" + str _ftSec);
					["INFORMATION", Format ["server_town.sqf: [%1] FIRST_TOWN captured: %2 at %3 min (%4 s).", str _newSide, _ftTownName, _ftMin, _ftSec]] Call WFBE_CO_FNC_LogContent;
				};
			};
			// END AICOMSTAT FIRST_TOWN

			// WASPSTAT CAPTURE telemetry (Task 10). Gate: WFBE_C_STATLOG must be 1.
			// NOTE: Task 19 (captured-town gunner change) will also edit this block — keep changes below this comment.
			if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
				if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
				WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
				diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|CAPTURE|" + (_location getVariable ["name","unknown"]) + "|" + str _sideID + "|" + str _newSID);
			};
			// END WASPSTAT CAPTURE (Task 10)

			//--- AICOMSTAT TOWN_FLIP (claude-gaming 2026-06-15): the war-narrative capture line on the
			//--- AICOMSTAT war ledger - "at minute M, <newSide> took <town> from <oldSide>". Distinct from
			//--- WASPSTAT|CAPTURE above (that is gated on WFBE_C_STATLOG, lives on the player-stats seq
			//--- stream, and carries raw numeric sideIDs) and from FIRST_TOWN (once per side per round).
			//--- Ungated, readable side names + minute, on the same proven if(_captured) flip cadence.
			//--- Fires exactly once per real town/camp ownership flip - no loop, no PFH, no new scan.
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _newSide) + "|" + str (round (time / 60)) + "|TOWN_FLIP|town=" + (_location getVariable ["name","unknown"]) + "|from=" + (str _side) + "|to=" + (str _newSide) + "|fromID=" + str _sideID + "|toID=" + str _newSID);
			// END AICOMSTAT TOWN_FLIP

			//--- FM-5: clear the old garrison's active flags on capture so the new owner re-garrisons immediately (prevents an up-to-WFBE_C_TOWNS_UNITS_INACTIVE undefended window on rapid recapture).
			//--- Also clear episode latch so the new owner's activation episode is not blocked.
			_location setVariable ["wfbe_active", false];
			_location setVariable ["wfbe_active_air", false];
			_location setVariable ["wfbe_episode_spawned", false];

			[nil, "TownCaptured", [_location, _sideID, _newSID]] Call WFBE_CO_FNC_SendToClients;
			if ((missionNamespace getVariable "WFBE_C_CAMPS_CREATE") > 0) then {[_location, _sideID, _newSID] Spawn WFBE_SE_FNC_SetCampsToSide};

			//--- NAVAL HVT: post-capture actions for offshore assets (feat/naval-hvt-objectives).
			//--- Guard: only fires if the feature is ON and this location is tagged as a naval HVT.
			if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) == 1 && {_location getVariable ["wfbe_is_naval_hvt", false]}) then {
				private ["_hvtName","_hvtNewSide","_airLogicRef","_newHangar","_oldHangar","_navalMkr"];
				_hvtName    = _location getVariable ["name", "Naval HVT"];
				_hvtNewSide = _newSID Call WFBE_CO_FNC_GetSideFromID;

				//--- Announce capture to all players (no inbound warning; just the flip notification).
				[nil, "HandleSpecial", ["naval-hvt-captured", _location, _newSID, _hvtName]] Call WFBE_CO_FNC_SendToClients;
				["INFORMATION", Format ["server_town.sqf: Naval HVT [%1] captured by sideID %2.", _hvtName, _newSID]] Call WFBE_CO_FNC_LogContent;

				//--- Recolour the naval HVT map marker to the new owner.
				_navalMkr = _location getVariable ["wfbe_naval_marker", ""];
				if (_navalMkr != "") then {
					_navalMkr setMarkerColor (missionNamespace getVariable [Format ["WFBE_C_%1_COLOR", _hvtNewSide], "ColorGreen"]);
				};

				//--- If this is a carrier HVT (LHD), update the airfield hangar for the new owner
				//--- so the aircraft-sell block on next capture works correctly.
				if (_location getVariable ["wfbe_is_carrier_hvt", false]) then {
					_airLogicRef = _location getVariable ["wfbe_airfield_logic_ref", objNull];
					if !(isNull _airLogicRef) then {
						//--- Delete previous owner's hangar.
						_oldHangar = _location getVariable ["wfbe_airfield_hangar_obj", objNull];
						if !(isNull _oldHangar) then { deleteVehicle _oldHangar };

						//--- Spawn new hangar for the new owner (same pattern as ~line 492 airfield block).
						//--- B74.2: place at the carrier DECK height (deckZ), not sea level, so the re-captured
						//--- air-shop hangar stays on the deck; freeze + invuln to match the carrier props.
						private ["_navDeckZ","_navRefPos"];
						_navDeckZ  = _airLogicRef getVariable ["wfbe_naval_deckz", 16];
						_navRefPos = getPosASL _airLogicRef;
						_newHangar = (missionNamespace getVariable "WFBE_C_HANGAR") createVehicle [_navRefPos select 0, _navRefPos select 1, 0];
						_newHangar setPosASL [_navRefPos select 0, _navRefPos select 1, _navDeckZ];
						_newHangar setDir ((getDir _airLogicRef) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
						_newHangar enableSimulation false;
						_newHangar allowDamage false; _newHangar hideObjectGlobal true; //--- B754 (Ray 2026-06-25): carrier hangar = logic only (hidden building); kept alive for the airport gate. Mirror of the Init_NavalHVT spawn site.
						_newHangar setVariable ["wfbe_is_airfield_hangar", true, true];
						_airLogicRef setVariable ["wfbe_hangar", _newHangar, true];
						_airLogicRef setVariable ["wfbe_airfield_side", _hvtNewSide, true];
						_location setVariable ["wfbe_airfield_hangar_obj", _newHangar, true];
						["INFORMATION", Format ["server_town.sqf: Carrier [%1] hangar respawned for side %2.", _hvtName, str _hvtNewSide]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};

			//--- Task 32: old defenders linger for WFBE_C_TOWNS_DEFENDER_LINGER seconds before cleanup.
			//--- Fire-time guard: only clean up if the town has NOT flipped back to the old side.
			[_location, _side, _newSID] spawn {
				Private ["_loc","_oldSide","_newSIDAtCapture"];
				_loc              = _this select 0;
				_oldSide          = _this select 1;
				_newSIDAtCapture  = _this select 2;
				sleep (missionNamespace getVariable ["WFBE_C_TOWNS_DEFENDER_LINGER", 180]);
				//--- Abort cleanup if the town has flipped back to the old owner's side.
				if ((_loc getVariable ["sideID", -1]) == _newSIDAtCapture) then {
					{if (alive _x) then {deleteVehicle _x}} forEach (units (missionNamespace getVariable [format ["WFBE_%1_DefenseTeam", _oldSide], grpNull]));
					[_loc, _oldSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits;
				};
			};

			//--- FINAL spec (2026-06-12): lazy garrison on capture.
			//--- Resistance / neutral towns keep the existing defender path; owned (west/east) towns use the new lazy path.
			if (_newSide == WFBE_DEFENDER) then {
				//--- Resistance recapture: keep existing defender setup unchanged.
				if (_town_defender_enabled) then {
					[_location, _newSide, _sideID, _newSID] spawn {
						Private ["_loc","_side","_oldSID","_newSIDAtCapture"];
						_loc             = _this select 0;
						_side            = _this select 1;
						_oldSID          = _this select 2;
						_newSIDAtCapture = _this select 3;
						sleep (missionNamespace getVariable ["WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY", 300]);
						if ((_loc getVariable ["sideID", -1]) != _newSIDAtCapture) exitWith {};
						[_loc, _side, _oldSID] Call WFBE_SE_FNC_ManageTownDefenses;
						if (missionNamespace getVariable ["WFBE_C_TOWNS_GUNNERS_ON_CAPTURE", true]) then {
							[_loc, _side, "spawn"] Call WFBE_SE_FNC_OperateTownDefensesUnits;
						};
					};
				};
			} else {
				//--- B36 (Ray 2026-06-15): capturing a GUER town as WEST/EAST grants NO inherited statics -
				//--- delete the GUER-era emplacements so the captor cannot turtle behind them. GUER keeps its
				//--- statics (recapture re-spawns them via ManageTownDefenses; the WEST/EAST path never calls it).
				if (_sideID == WFBE_C_GUER_ID) then {
					{
						private "_def"; _def = _x getVariable "wfbe_defense";
						if (!isNil "_def" && {!isNull _def}) then {deleteVehicle _def};
						_x setVariable ["wfbe_defense", nil];
					} forEach (_location getVariable ["wfbe_town_defenses", []]);
				};
				//--- Owned (west/east) town: lazy garrison per FINAL spec.
				//--- Step 2: T+60s spawn exactly 1 owner-side infantry squad as mop-up detail.
				//--- Step 3: Squad auto-despawns when no GUER/resistance detected for 2 consecutive 30s scans.
				//--- Step 4: Full defenses spawn only when ENEMY enters radius (handled in server_town_ai.sqf).
				if (_town_occupation_enabled) then {
					[_location, _newSide, _newSID] spawn {
						Private ["_loc","_side","_newSIDAtCapture","_squadGrp","_squadUnits","_squadVehicles",
						         "_clearCount","_detected","_squadTeam","_upgLvl","_tplName","_spawnPos",
						         "_retVal","_scanActive","_townRange","_guerCount"];
						_loc             = _this select 0;
						_side            = _this select 1;
						_newSIDAtCapture = _this select 2;

						//--- Wait 60 s; abort if the town flipped again before the timer fires.
						sleep 60;
						if ((_loc getVariable ["sideID", -1]) != _newSIDAtCapture) exitWith {
							["INFORMATION", Format ["server_town.sqf: mop-up squad cancelled (town %1 flipped before T+60).", _loc getVariable ["name","unknown"]]] Call WFBE_CO_FNC_LogContent;
						};

						//--- Pick the smallest infantry template for the owning side (Squad at current barracks level).
						_upgLvl  = ((_side) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
						_tplName = Format ["Squad_%1", _upgLvl];

						//--- Spawn position near town centre.
						_spawnPos = [getPos _loc, 50, 200] call WFBE_CO_FNC_GetRandomPosition;
						_spawnPos = [_spawnPos, 50] call WFBE_CO_FNC_GetEmptyPosition;

						_squadTeam = [_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup;
						_retVal    = [_tplName, _spawnPos, _side, true, _squadTeam, true, 90] call WFBE_CO_FNC_CreateTeam;
						_squadUnits    = _retVal select 0;
						_squadVehicles = _retVal select 1;
						_squadGrp      = _retVal select 2;

						if (isNull _squadGrp || {(count _squadUnits + count _squadVehicles) == 0}) exitWith {
							["INFORMATION", Format ["server_town.sqf: mop-up squad for %1 (%2) failed to create - template %3 unavailable.", _loc getVariable ["name","unknown"], _side, _tplName]] Call WFBE_CO_FNC_LogContent;
						};

						//--- Tag squad units as town defender AI so they don't re-trigger activation scans.
						{if (!isNull _x) then {_x setVariable ["WFBE_IsTownDefenderAI", true, true]}} forEach (_squadUnits + _squadVehicles);
						_squadGrp allowFleeing 0;

						//--- Store reference on location so deactivation cleanup can hard-despawn it.
						_loc setVariable ["wfbe_mopup_group", _squadGrp, false];
						_loc setVariable ["wfbe_mopup_units", _squadUnits + _squadVehicles, false];

						["INFORMATION", Format ["server_town.sqf: mop-up squad spawned for %1 (side %2, template %3, %4 units).", _loc getVariable ["name","unknown"], _side, _tplName, count _squadUnits]] Call WFBE_CO_FNC_LogContent;

						//--- Scan loop: despawn when no GUER/resistance detected for 2 consecutive 30s checks.
						_clearCount  = 0;
						_scanActive  = true;
						//--- Use the town activation detection range (600m base) for the straggler scan.
						_townRange   = 600 * (missionNamespace getVariable ["WFBE_C_TOWNS_DETECTION_RANGE_COEF", 1]);

						while {_scanActive && !isNull _squadGrp && {count (units _squadGrp) > 0}} do {
							sleep 30;

							//--- Hard-despawn if town deactivated or flipped.
							if (!(_loc getVariable ["wfbe_active", false]) && !(_loc getVariable ["wfbe_active_air", false]) && _clearCount > 0) then {
								_scanActive = false;
							};
							if ((_loc getVariable ["sideID", -1]) != _newSIDAtCapture) then {_scanActive = false};

							if (_scanActive) then {
								_detected = (_loc nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], _townRange]) unitsBelowHeight 20;
								_guerCount = 0;
								{
									if (side _x == resistance) then {_guerCount = _guerCount + 1};
									//--- Count crew members of mounted vehicles too.
									if (!(_x isKindOf "Man")) then {
										{if (side _x == resistance) then {_guerCount = _guerCount + 1}} forEach (crew _x);
									};
								} forEach _detected;

								if (_guerCount == 0) then {
									_clearCount = _clearCount + 1;
								} else {
									_clearCount = 0;
								};

								if (_clearCount >= 2) then {_scanActive = false};
							};
						};

						//--- Despawn the mop-up squad.
						if !(isNull _squadGrp) then {
							{if (!isNull _x && alive _x) then {deleteVehicle _x}} forEach (units _squadGrp);
							{if (!isNull _x && alive _x) then {deleteVehicle _x}} forEach _squadVehicles;
							if !(isNull _squadGrp) then {deleteGroup _squadGrp};
						};
						_loc setVariable ["wfbe_mopup_group", grpNull, false];
						_loc setVariable ["wfbe_mopup_units", [], false];
						["INFORMATION", Format ["server_town.sqf: mop-up squad stood down for %1 (no GUER detected).", _loc getVariable ["name","unknown"]]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};

			//--- Task 12: Airfield capture — spawn repair point + exclusive hangar for the new owner.
			//--- Task 13: Airfield built-in Counter Battery Radar (2000 m, follows owner).
			if ((missionNamespace getVariable ["WFBE_C_AIRFIELDS", 0]) > 0 && (_location getVariable ["wfbe_is_airfield", false])) then {
				Private ["_airfieldLogic","_newHangar","_oldHangar","_oldSP","_logik","_sp","_spClass","_spPos",
				         "_oldRadar","_oldDressing","_radarClass","_radarPos","_radar","_cbrKey","_cbrReg","_dressTpl",
				         "_oldGarrison","_garUnit"];

				//--- ITEM 1: Airfield garrison despawn on capture.
				//--- Delete all surviving units/vehicles tagged wfbe_airfield_garrison = true by server_town_ai.sqf.
				//--- Units spawned on HCs are not local here; broadcast cleanup-townai to all machines so each
				//--- deletes its own local garrison units (mirrors existing deactivation cleanup pattern).
				_oldGarrison = _location getVariable "wfbe_airfield_garrison_units";
				if !(isNil "_oldGarrison") then {
					{
						_garUnit = _x;
						if !(isNull _garUnit) then {
							if (alive _garUnit) then {
								if (local _garUnit) then {
									deleteVehicle _garUnit;
								};
								//--- Non-local units are cleaned up by the broadcast below.
							};
						};
					} forEach _oldGarrison;
					_location setVariable ["wfbe_airfield_garrison_units", [], false];
				};
				//--- Broadcast to clients/HCs so they delete any garrison units local to them.
				if (isMultiplayer) then {
					[nil, "HandleSpecial", ["cleanup-airfield-garrison", _location]] Call WFBE_CO_FNC_SendToClients;
				};
				["INFORMATION", Format ["server_town.sqf: airfield garrison despawned on capture of %1 by %2.", _location getVariable ["name","unknown"], _newSide]] Call WFBE_CO_FNC_LogContent;

				//--- Determine side-specific ServicePoint classname (Chernarus variants).
				_spClass = switch (_newSide) do {
					case west:       { if (IS_chernarus_map_dependent) then {"USMC_WarfareBVehicleServicePoint"} else {"US_WarfareBVehicleServicePoint_EP1"} };
					case east:       { if (IS_chernarus_map_dependent) then {"INS_WarfareBVehicleServicePoint"} else {"TK_WarfareBVehicleServicePoint_EP1"} };
					default          { if (IS_chernarus_map_dependent) then {"Gue_WarfareBVehicleServicePoint"} else {"TK_GUE_WarfareBVehicleServicePoint_EP1"} };
				};

				//--- Find the nearest LocationLogicAirport (should be within 1500m of the depot logic).
				_airfieldLogic = ((getPos _location) nearEntities [["LocationLogicAirport"], 1500]) select 0;

				//--- Delete old repair point if present (side changed or recapture).
				//--- Also remove from old side's structures list to avoid dead-object references.
				_oldSP = _location getVariable ["wfbe_airfield_sp", objNull];
				if !(isNull _oldSP) then {
					{
						_oldStructures = _x getVariable ["wfbe_structures", []];
						if (_oldSP in _oldStructures) then {
							_x setVariable ["wfbe_structures", _oldStructures - [_oldSP], true];
						};
					} forEach [WFBE_L_BLU, WFBE_L_OPF, WFBE_L_GUE];
					deleteVehicle _oldSP;
				};

				//--- Create new repair point 80m north of the airfield logic position.
				_spPos = if !(isNull _airfieldLogic) then {
					[(getPos _airfieldLogic select 0), ((getPos _airfieldLogic select 1) + 80), 0]
				} else {
					[(getPos _location select 0), ((getPos _location select 1) + 80), 0]
				};
				_sp = _spClass createVehicle _spPos;
				_sp setPos _spPos;
				_sp setVariable ["WFBE_RepairTruckServicePoint", true, true];
				_sp setVariable ["wfbe_side", _newSide]; //--- A1 fix: airfield repair-point was missing wfbe_side ->
				//--- Server_BuildingDamaged/BuildingKilled read nil side and threw on hit. Mirror Construction_SmallSite:107.

				//--- Register in side logic structures list so clients can see it.
				_logik = (_newSide) Call WFBE_CO_FNC_GetSideLogic;
				_logik setVariable ["wfbe_structures", (_logik getVariable "wfbe_structures") + [_sp], true];

				//--- Trigger Init_BaseStructure on clients so a map marker is created.
				_sp setVehicleInit Format ["[this,false,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'", _newSID];
				processInitCommands;

				//--- Wire Hit/Killed EHs so destruction grants bounty and removes SP from wfbe_structures.
				//--- Mirrors the pattern in Construction_SmallSite.sqf (~line 141/147).
				_sp addEventHandler ["hit", {_this Spawn BuildingDamaged}];
				Call Compile Format ["_sp AddEventHandler ['killed',{[_this select 0,_this select 1,'%1'] Spawn BuildingKilled}];", "ServicePoint"];

				//--- Store on location for cleanup on next capture.
				_location setVariable ["wfbe_airfield_sp", _sp, true];

				//--- Delete old hangar (previous owner's) and its link on the airport logic.
				_oldHangar = _location getVariable ["wfbe_airfield_hangar_obj", objNull];
				if !(isNull _oldHangar) then {
					deleteVehicle _oldHangar;
					if !(isNull _airfieldLogic) then { _airfieldLogic setVariable ["wfbe_hangar", nil, true] };
				};

				//--- Spawn new hangar on the airport logic so GetClosestAirport can find it.
				if !(isNull _airfieldLogic) then {
					_newHangar = (missionNamespace getVariable "WFBE_C_HANGAR") createVehicle (getPos _airfieldLogic);
					_newHangar setDir ((getDir _airfieldLogic) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
					_newHangar setPos (getPos _airfieldLogic);
					_newHangar setVariable ["wfbe_is_airfield_hangar", true, true];
					_airfieldLogic setVariable ["wfbe_hangar", _newHangar, true]; _airfieldLogic setVariable ["wfbe_airfield_side", _newSide, true]; //--- C-1: GUER airfield ownership gate
					_location setVariable ["wfbe_airfield_hangar_obj", _newHangar, true];
				};

				//--- Task 13: Counter Battery Radar lifecycle.
				//--- Gate: CBR feature must be enabled. Resistance has no CBR registry — radar skipped.
				//--- Indestructible: HandleDamage-returns-0 (only established invincibility idiom in this codebase;
				//---   allowDamage has no usage precedent here). Placed 60 m east of airfield logic to avoid runway.
				if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0) then {

					//--- 1. CLEANUP: delete previous airfield radar if one exists.
					_oldRadar = _location getVariable ["wfbe_airfield_cbr", objNull];
					if !(isNull _oldRadar) then {
						//--- Remove from both side registries (indestructible means lazy prune never fires).
						missionNamespace setVariable ["WFBE_CBR_WEST", (missionNamespace getVariable ["WFBE_CBR_WEST", []]) - [_oldRadar]];
						missionNamespace setVariable ["WFBE_CBR_EAST", (missionNamespace getVariable ["WFBE_CBR_EAST", []]) - [_oldRadar]];
						//--- Delete dressing props explicitly (Killed EH won't fire on deleteVehicle).
						_oldDressing = _oldRadar getVariable ["wfbe_dressing", []];
						{if !(isNull _x) then {deleteVehicle _x}} forEach _oldDressing;
						deleteVehicle _oldRadar;
						["INFORMATION", Format ["server_town.sqf: [%1] airfield CBR removed on recapture.", str _side]] Call WFBE_CO_FNC_LogContent;
					};

					//--- 2. SPAWN new radar (only for WEST/EAST — resistance has no CBR registry).
					if (_newSide == west || _newSide == east) then {
						//--- Both sides use Land_Antenna (confirmed-present whip mast). Land_telek1 assessed
						//---   as likely absent at runtime for this content set — using Land_Antenna for both.
						//---   Visual distinctness is provided by the side-specific dressing template.
						_radarClass = "Land_Antenna";

						//--- Position: 60 m east of airfield logic (off the runway centerline).
						_radarPos = if !(isNull _airfieldLogic) then {
							[((getPos _airfieldLogic) select 0) + 60, (getPos _airfieldLogic) select 1, 0]
						} else {
							[((getPos _location) select 0) + 60, (getPos _location) select 1, 0]
						};

						_radar = _radarClass createVehicle _radarPos;
						_radar setPos _radarPos;
						//--- Radius override: 2000 m. Server_CounterBattery.sqf reads "wfbe_cbr_radius" getVariable.
						_radar setVariable ["wfbe_cbr_radius", 2000, true]; //--- AF2: broadcast so clients read the fixed 2000 (Init_BaseStructure uses it for BOTH the circle radius AND the "_fixed" flag; un-broadcast -> client drew the 750/1500 upgrade tier and live-resized it)
						//--- Indestructible: HandleDamage returning 0 prevents any damage being applied.
						_radar addEventHandler ["HandleDamage", {0}];

						//--- Spawn side-matched dressing for visual identity (reuses buildable CBRADAR templates).
						_dressTpl = Format ["WFBE_NEURODEF_CBRADAR_%1", if (_newSide == west) then {"WEST"} else {"EAST"}];
						[_radar, _dressTpl, 0] Call WFBE_SE_FNC_SpawnStructureDressing;

						//--- Task D: trigger Init_BaseStructure on clients so the CBR range circle is drawn.
						//--- Mirrors the SP pattern (server_town.sqf ~line 313) and Construction_SmallSite.sqf ~line 138.
						//--- Use a local _cbrSID (0=west,1=east) for the Init_BaseStructure call
						//--- rather than reusing the outer-scope _newSID, which tracks town ownership.
						Private "_cbrSID";
						_cbrSID = if (_newSide == west) then {0} else {1};
						_radar setVehicleInit Format ["[this,false,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'", _cbrSID];
						processInitCommands;

						//--- 3. REGISTER in the new owner's CBR registry.
						_cbrKey = if (_newSide == west) then {"WFBE_CBR_WEST"} else {"WFBE_CBR_EAST"};
						_cbrReg = missionNamespace getVariable [_cbrKey, []];
						missionNamespace setVariable [_cbrKey, _cbrReg + [_radar]];

						//--- Store on location for cleanup on next capture.
						_location setVariable ["wfbe_airfield_cbr", _radar, true];

						["INFORMATION", Format ["server_town.sqf: [%1] airfield CBR spawned (%2) at %3. Radius 2000 m. Registry [%4] size: %5.",
							str _newSide, _radarClass, _radarPos, _cbrKey,
							count (missionNamespace getVariable [_cbrKey, []])]] Call WFBE_CO_FNC_LogContent;
					} else {
						//--- Resistance capture: no CBR registry for GUER — radar skipped, mast not spawned.
						_location setVariable ["wfbe_airfield_cbr", objNull, true];
						["INFORMATION", Format ["server_town.sqf: airfield [%1] captured by resistance — CBR skipped (no GUER registry).", _location getVariable ["name","unknown"]]] Call WFBE_CO_FNC_LogContent;
					};
				};
				//--- End Task 13 CBR lifecycle.
			};
		};
		};
		sleep 0.05;
	};
	_isTimeToUpdateSuppluys = false;
	sleep 5;
	if (time >= _lastUp) then {
		_isTimeToUpdateSuppluys = true;
		_lastUp = time + _town_supply_time_delay;

	};
};
