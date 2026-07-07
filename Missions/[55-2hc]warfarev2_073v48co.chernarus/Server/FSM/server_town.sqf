

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
_town_camps_capture_rate = missionNamespace getVariable ["WFBE_C_CAMPS_CAPTURE_RATE_MAX", 25]; //--- MUST default: a nil read here (constants race at FSM start) undefines the local and every capture-rate calc below errors for the whole match (ZG 2026-07-03).
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

//--- Perf phase jitter (2026-07-06, Ray): the 5 s town sweeps, 60 s groupsGC and 5 s dead collector all
//--- fire on aligned multiples, so several heavy passes land on the same server frames. A one-time random
//--- startup offset per loop de-correlates them (same pattern as WFBE_C_AICOM_SUPERVISOR_JITTER). Default 0 = V1.
if ((missionNamespace getVariable ["WFBE_C_LOOP_PHASE_JITTER", 0]) > 0) then {
	private "_phaseJitter";
	_phaseJitter = random 5;
	["INFORMATION", Format ["server_town.sqf: startup phase jitter %1s (WFBE_C_LOOP_PHASE_JITTER=1).", _phaseJitter]] Call WFBE_CO_FNC_AICOMLog;
	sleep _phaseJitter;
};
while {!WFBE_GameOver} do {

	for "_i" from 0 to ((count towns) - 1) step 1 do
	{

		_location = towns select _i;
		//--- cmdcon44-d (claude-gaming 2026-07-03) NIL-SAFE SV READS: a transplanted map (Zargabad) can leave a
		//--- town's supply/camp vars unset for a window (Init_Town server-block race), and an OLDER server_town.sqf
		//--- shipped in the live ZG pbo read these 1-arg -> the locals came up Undefined and the capture-drain block
		//--- threw every scan (server RPT: "Undefined variable _supplyvalue"/"_rate" at server_town.sqf) so no town's
		//--- supplyValue ever drained -> ZERO flips. 2-arg getVariable defaults keep the locals numeric so the drain
		//--- math (and the GetTotalCamps division below) can never be poisoned by a nil town var. A2-OA-safe (plain
		//--- 2-arg getVariable; no == on Bool). Fallbacks mirror Init_Town: start/max default to a sane 30.
		_startingSupplyValue = _location getVariable ["startingSupplyValue", 30];
		_maxSupplyValue = _location getVariable ["maxSupplyValue", 30];

				_sideID = _location getVariable "sideID";
				_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;
				//--- PERF dedupe REVERTED (caused capture-detection wedges twice); back to the proven
				//--- direct scan. The server_town_ai cache-write remains but is simply unread now.
				_perfT0PA = diag_tickTime; //--- FPS PROFILING (claude-gaming): bracket the uncached per-town capture scan (suspected #1 server frametime sink)
				private "_capH"; _capH = 10; if (_location getVariable ["wfbe_is_naval_hvt", false]) then {_capH = (_location getVariable ["wfbe_naval_deckz", 22]) + 12}; //--- B755 (Ray 2026-06-25): carrier decks sit ~16-22m ASL, so on-deck attackers were EXCLUDED by the flat 10m height filter - the carrier town could never be captured by units standing on its deck (now relevant with the b754 deck-spawn). Naval-HVT towns scan up to deckZ+12; normal towns keep 10.
				_objects = (_location nearEntities[["Man","Car","Motorcycle","Tank","Air","Ship"], _town_capture_range]) unitsBelowHeight _capH;

				_west = west countSide _objects;
				_east = east countSide _objects;
				_resistance = resistance countSide _objects;
				["town_capture_scan", diag_tickTime - _perfT0PA] call PerformanceAudit_Record; //--- FPS PROFILING (claude-gaming): self-gated, server-side, ~0.01ms overhead

				_activeEnemies = switch (_sideID) do {
					case WFBE_C_WEST_ID: {_east + _resistance};
					case WFBE_C_EAST_ID: {_west + _resistance};
					case WFBE_C_GUER_ID: {_east + _west};
					//--- FIX (cmdcon44-e, claude-gaming 2026-07-03): neutral towns (WFBE_C_UNKNOWN_ID) have
					//--- no owner so none of the three named cases matched -> _activeEnemies stayed undefined
					//--- -> every downstream read ('_supplyValue', '_rate'...) threw Undefined. Live evidence:
					//--- 391x/_supplyValue + 319x/_rate errors in the 66-min ZG soak (0 flips). ZG simply
					//--- starts with ALL towns neutral (WFBE_C_TOWNS_STARTING_MODE=0 default) so the nil fired
					//--- on every town every 5s from tick 1. The same nil fires on CH/TK mode-0 neutral towns
					//--- too -- this fix is beneficial on all maps; ZG just has far more neutral towns from
					//--- match start. Default = all combatants present (correct count for a neutral contested town).
					default {_west + _east + _resistance};
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
				//--- cmdcon41-w3c WRITE-ON-CHANGE (claude-gaming 2026-07-02): only stamp wfbe_contested when the
				//--- value actually FLIPS, not every 5s x every town. VERIFIED this write is LOCAL (no ,true
				//--- broadcast flag) and the sole reader (server_groupsGC.sqf:353) uses a default-false 2-arg get,
				//--- so unchanged/never-written towns read false safely - the task's "per-tick global broadcast x40
				//--- towns = network churn" suspicion is DISPROVEN (there is no broadcast). This is a pure local
				//--- setVariable-count trim (~40 no-op writes/5s -> only real transitions). A2-OA-safe: plain 2-arg
				//--- getVariable, == on Bools avoided (compares two booleans via if-guard, not ==).
				private "_prevContested"; _prevContested = _location getVariable ["wfbe_contested", false];
				if (_contested && !_prevContested) then {_location setVariable ["wfbe_contested", true]};
				if (!_contested && _prevContested) then {_location setVariable ["wfbe_contested", false]};

				//--- cmdcon44-d: nil-safe (see SV-reads note above). A town mid-init (or from a stale transplant)
				//--- may not yet have "supplyValue" set; default to startingSupplyValue so this scan drains from
				//--- full instead of throwing Undefined at the first "_supplyValue < _maxSupplyValue" test.
				_supplyValue = _location getVariable ["supplyValue", _startingSupplyValue];
				//--- CAPDBG (cmdcon44d diagnostic): the live 44b/44c boots report _supplyValue/_rate Undefined at the
				//--- consumers with no upstream error; log exactly WHICH input is nil, then self-heal so the drain runs.
				if (isNil "_supplyValue") then {
					diag_log ("CAPDBG|SV|" + (_location getVariable ["name","?"]) + "|poisoned-town-var (set-nil, XWT45-P5)");
				};
				//--- heal MUST be a top-level assignment: assigning inside then{} to an undefined outer local
				//--- creates a block-local that dies at the brace (the 44d heal was inert for this reason).
				_supplyValue = if (isNil "_supplyValue") then {_startingSupplyValue} else {_supplyValue};
				//--- cleanse the set-nil poison on the town var itself (2-arg defaults never apply to set-nil vars).
				if (isNil {_location getVariable "supplyValue"}) then {_location setVariable ["supplyValue", _supplyValue, true]};

				if (!WFBE_ISTHREEWAY && _town_supply_time) then {
					//--- If we're running on 2 sides, skip the time based supply if the defender hold the town.
					_skipTimeSupply = if (_sideID == WFBE_DEFENDER_ID) then {true} else {false};
				};

				if(_town_supply_time && _sideID != WFBE_C_UNKNOWN_ID && !_skipTimeSupply) then
				{

					if (_activeEnemies == 0 && (_supplyValue < _maxSupplyValue) && _sideID != WFBE_C_GUER_ID) then
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
			_totalCamps = _location Call WFBE_CO_FNC_GetTotalCamps;
			//--- ROOT FIX (cmdcon44e, rig-verified XWT45): a no-match default-less switch returns the switch
			//--- VALUE (boolean true) - the tie case (dominion logic zeroes all three counts) fed boolean into
			//--- _newSID -> GetTotalCampsOnSide aborted on number==bool -> _rate Voided -> towncenters could
			//--- never flip while contested (systemic on 3-way urban ZG). Tie = no dominant attacker = owner keeps.
			_newSID = switch (true) do {case (_west > 0): {WFBE_C_WEST_ID}; case (_east > 0): {WFBE_C_EAST_ID}; case (_resistance > 0): {WFBE_C_GUER_ID}; default {_sideID};};
			_newSide = (_newSID) Call WFBE_CO_FNC_GetSideFromID;
			_rate = 1;
			if (_totalCamps > 0) then {
				_rate = _town_capture_rate * (([_location,_newSide] Call WFBE_CO_FNC_GetTotalCampsOnSide) / _totalCamps) * _town_camps_capture_rate;
			} else {
				_rate = _town_capture_rate * _town_camps_capture_rate;
			};
			if (isNil "_rate") then {
				diag_log ("CAPDBG|RATE|" + (_location getVariable ["name","?"]) + "|newSID=" + str(_newSID) + "|residual (should be silent post-44e)");
			};
			_rate = if (isNil "_rate") then {1} else {_rate};
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
			//--- Commander Town Ledger (fable/ctl-impl-v1) capture seed (fix: capture-race). Publish
			//--- wfbe_ctl_str immediately at the capture hook so a freshly captured W/E town reads its
			//--- 0.25 seed on the very next materialization, instead of the getVariable default (1.0)
			//--- for up to one CTL brain tick (AICOMV2_CTL_TICK_SEC, 30s). The brain's own seed pass
			//--- (Server_CmdTownLedger.sqf) still creates the ledger RECORD and re-publishes the same
			//--- value on its next tick - this hook only closes the race window. Flag-off => skipped,
			//--- byte-identical to HEAD.
			if ((_newSID == WFBE_C_WEST_ID || {_newSID == WFBE_C_EAST_ID}) && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
				_location setVariable ["wfbe_ctl_str", missionNamespace getVariable ["AICOMV2_CTL_CAPTURE_SEED", 0.25]];
			};
			//--- cmdcon45 (owner: "Rogovo captured but camps still GUER"): capturing the TOWN flips its
			//--- remaining camps to the new owner. Camps flip individually during the fight (that IS the
			//--- capture-rate mechanic), but once the town falls, leftover old-side camps are stale enemy
			//--- spawn points inside the captured town. Mirrors the individual-flip effects (sideID +
			//--- JIP-safe flag texture + CampCaptured broadcast); no per-player capture credit for bulk flips.
			if ((missionNamespace getVariable ["WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS", 1]) > 0) then {
				private ["_ccCamps","_ccCamp","_ccOldSID","_ccFlag","_ccFlags","_ccNewSide","_ccFlipped"];
				_ccNewSide = (_newSID) Call WFBE_CO_FNC_GetSideFromID;
				_ccCamps = _location getVariable ["camps", []];
				_ccFlipped = 0;
				{
					_ccCamp = _x;
					if (!isNull _ccCamp) then {
						_ccOldSID = _ccCamp getVariable ["sideID", WFBE_C_UNKNOWN_ID];
						if (_ccOldSID != _newSID) then {
							_ccCamp setVariable ["sideID", _newSID, true];
							_ccFlag = _ccCamp getVariable ["wfbe_flag", objNull];
							if (!isNull _ccFlag) then {
								_ccFlag setFlagTexture (missionNamespace getVariable Format ["WFBE_%1FLAG", str _ccNewSide]);
								_ccFlag setVehicleInit (Format ["this setFlagTexture '%1'", missionNamespace getVariable Format ["WFBE_%1FLAG", str _ccNewSide]]);
							};
							[nil, "CampCaptured", [_ccCamp, _newSID, _ccOldSID]] Call WFBE_CO_FNC_SendToClients;
							_ccFlipped = _ccFlipped + 1;
						};
					};
				} forEach _ccCamps;
				if (_ccFlipped > 0) then {
					processInitCommands; //--- one bake for all flipped flags (JIP-safe texture replay).
					diag_log Format ["AICOMSTAT|v3|TOWN|CAPTURE|%1|campsFlipped=%2|to=%3", _location getVariable ["name","?"], _ccFlipped, _newSID];
				};
			};

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
					//--- MATCH|v1|MILESTONE|FIRST_TOWN|: narrative beat for the after-match report.
					//--- One-shot per side (same _ftFlag gate as the AICOMSTAT line above).
					if ((missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0) then {
						diag_log ("MATCH|v1|MILESTONE|FIRST_TOWN|side=" + str _newSide + "|town=" + _ftTownName + "|tMin=" + str _ftMin);
					};
				};
			};
			// END AICOMSTAT FIRST_TOWN

			// WASPSTAT CAPTURE telemetry (Task 10). Gate: WFBE_C_STATLOG must be 1.
			// NOTE: Task 19 (captured-town gunner change) will also edit this block — keep changes below this comment.
			if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
				if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
				WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
				diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|CAPTURE|" + (_location getVariable ["name","unknown"]) + "|" + str _sideID + "|" + str _newSID + "|t=" + str (round time));
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
			if ((missionNamespace getVariable "WFBE_C_CAMPS_CREATE") > 0 && {!(((missionNamespace getVariable ["WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS", 1]) > 0) && {(missionNamespace getVariable ["WFBE_C_CAMPS_LEGACY_SKIP_ON_PERCAMP_FLIP", 0]) > 0})}) then {[_location, _sideID, _newSID] Spawn WFBE_SE_FNC_SetCampsToSide};

			//--- NAVAL HVT: post-capture actions for offshore assets (feat/naval-hvt-objectives).
			//--- Guard: only fires if the feature is ON and this location is tagged as a naval HVT.
			if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) == 1 && {_location getVariable ["wfbe_is_naval_hvt", false]}) then {
				private ["_hvtName","_hvtNewSide","_airLogicRef","_newHangar","_oldHangar","_navalMkr"];
				_hvtName    = _location getVariable ["name", "Naval HVT"];
				_hvtNewSide = _newSID Call WFBE_CO_FNC_GetSideFromID;

				//--- Announce capture to all players (no inbound warning; just the flip notification).
				[nil, "HandleSpecial", ["naval-hvt-captured", _location, _newSID, _hvtName]] Call WFBE_CO_FNC_SendToClients;
				["INFORMATION", Format ["server_town.sqf: Naval HVT [%1] captured by sideID %2.", _hvtName, _newSID]] Call WFBE_CO_FNC_LogContent;
				//--- MATCH|v1|MILESTONE|CARRIER_CAP|: narrative beat for carrier captures.
				if ((missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0) then {
					diag_log ("MATCH|v1|MILESTONE|CARRIER_CAP|carrier=" + _hvtName + "|newSideID=" + str _newSID + "|tMin=" + str (round (time / 60)));
				};

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
						_newHangar = "HeliHEmpty" createVehicle [_navRefPos select 0, _navRefPos select 1, 0]; //--- B754b (Ray 2026-06-25): invisible-but-alive HeliHEmpty instead of the hangar building (A2-OA has no hideObjectGlobal). Mirror of the Init_NavalHVT spawn site.
						_newHangar setPosASL [_navRefPos select 0, _navRefPos select 1, _navDeckZ];
						_newHangar setDir ((getDir _airLogicRef) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
						_newHangar enableSimulation false;
						_newHangar allowDamage false; //--- B754b: hangar suppressed via invisible HeliHEmpty above (no hideObjectGlobal in A2-OA).
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
						         "_retVal","_scanActive","_townRange","_guerCount","_mopupEnd"];
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
						_mopupEnd   = time + (missionNamespace getVariable ["WFBE_C_TOWNS_MOPUP_TTL", 600]);

						while {_scanActive && !isNull _squadGrp && {count (units _squadGrp) > 0} && {time < _mopupEnd}} do {
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
						["INFORMATION", Format ["server_town.sqf: mop-up squad stood down for %1.", _loc getVariable ["name","unknown"]]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};

			//--- Task 12: Airfield capture — spawn repair point + exclusive hangar for the new owner.
			//--- Task 13: Airfield built-in Counter Battery Radar (2000 m, follows owner).
			if ((missionNamespace getVariable ["WFBE_C_AIRFIELDS", 0]) > 0 && (_location getVariable ["wfbe_is_airfield", false])) then {
				Private ["_airfieldLogic","_airfieldLogicChecks","_newHangar","_oldHangar","_oldSP","_logik","_sp","_spClass","_spPos",
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

				//--- Cache the nearest LocationLogicAirport on the town logic; recaptures reuse the same anchor.
				_airfieldLogic = _location getVariable ["wfbe_airfield_logic_ref", objNull];
				if (isNull _airfieldLogic) then {
					_airfieldLogicChecks = (getPos _location) nearEntities [["LocationLogicAirport"], 1500];
					if (count _airfieldLogicChecks > 0) then {
						_airfieldLogic = _airfieldLogicChecks select 0;
						_location setVariable ["wfbe_airfield_logic_ref", _airfieldLogic, false];
					};
				};

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
						//--- b760: airfield CBR radar model is now the GUER game-file artillery radar (was a Land_Antenna placeholder).
						//---   as likely absent at runtime for this content set — using Land_Antenna for both.
						//---   Visual distinctness is provided by the side-specific dressing template.
						_radarClass = if (IS_chernarus_map_dependent) then {"Gue_WarfareBArtilleryRadar"} else {"TK_GUE_WarfareBArtilleryRadar_EP1"}; //--- Ray 2026-06-26: airfield CBR uses the GUER game-file artillery radar for BOTH sides (owning-side identity is carried by the WFBE_NEURODEF_CBRADAR_<SIDE> dressing below).

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
						//--- cmdcon45 (owner report): the GUER-classed radar building is a valid AI TARGET hostile to
						//--- BOTH sides, so W/E AI dumped ammo into an indestructible object forever. Captive = treated
						//--- as civilian by AI target selection; nobody engages it (it cannot be destroyed anyway).
						_radar setCaptive true;

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
