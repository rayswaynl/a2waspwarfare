/*
	AI supply-truck logistics, d022 net-new implementation.

	This is deliberately an explicit server-local worker, not a revived FSM.  It
	owns one convoy per WEST/EAST side, keeps the truck in the side registry for
	the complete hull lifecycle, and raises only an owned town's supplyValue.
	The feature is double-gated by Init_Server and again here so a late flag/mode
	change cannot create or retain new gameplay state.
*/

private ["_side","_sideText","_sideId","_logic","_registry","_newRegistry","_hasTruck","_capTiers","_capTier","_capLast","_cap","_sideAI","_groupCount","_groupCap","_hq","_target","_bestDeficit","_bestDistance","_town","_townSideId","_sv","_maxSV","_deficit","_distance","_group","_truck","_truckType","_spawnPos","_templates","_templateTypes","_templateIndex","_template","_units","_unit","_unitClass","_i","_structures","_anchor","_anchorFound","_candidate","_cleanup","_cleanupOk","_occupied","_crew","_j","_phase","_contactUntil","_legStart","_tripToken","_delivered","_reseated","_driver","_seat","_routeTarget","_before","_after","_rates","_upgrades","_rateIndex","_truckRate","_activeContact","_done","_abort","_lastLog","_diagLog","_deleteUntil","_targetOccupied","_numericSV"];

_side = _this select 0;
if (!isServer) exitWith {};
if (_side != west && {_side != east}) exitWith {};

_sideText = str _side;
_sideId = _side Call WFBE_CO_FNC_GetSideID;

waitUntil {
	sleep 5;
	WFBE_GameOver || {townInit}
};
if (WFBE_GameOver) exitWith {};

while {!WFBE_GameOver} do {
	if (!((missionNamespace getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]) > 0)) exitWith {};
	if ((missionNamespace getVariable ["WFBE_C_ECONOMY_SUPPLY_SYSTEM", 1]) != 0) exitWith {};
	if (!((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0)) exitWith {};

	_logic = _side Call WFBE_CO_FNC_GetSideLogic;
	if (isNull _logic) exitWith {};
	_registry = _logic getVariable ["wfbe_ai_supplytrucks", []];
	_newRegistry = [];
	{
		if (!isNull _x) then {_newRegistry = _newRegistry + [_x]};
	} forEach _registry;
	if (count _newRegistry != count _registry) then {
		_logic setVariable ["wfbe_ai_supplytrucks", _newRegistry];
		_registry = _newRegistry;
	};

	_hasTruck = count _registry > 0;
	if (!_hasTruck) then {
		_hq = _side Call WFBE_CO_FNC_GetSideHQ;
		if (!(_side Call WFBE_CO_FNC_GetSideHQDeployStatus) || {isNull _hq} || {!alive _hq}) then {
			_hasTruck = true;
		};
	};

	if (!_hasTruck) then {
		_capTiers = missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", [140,130,100,80]];
		if (count _capTiers < 1) then {_capTiers = [missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", 140]]};
		_capTier = (missionNamespace getVariable ["WFBE_PopTier", 0]) max 0;
		_capLast = (count _capTiers) - 1;
		if (_capTier > _capLast) then {_capTier = _capLast};
		_cap = _capTiers select _capTier;
		_sideAI = {side _x == _side && {!isPlayer _x}} count allUnits;
		_groupCount = {side _x == _side} count allGroups;
		_groupCap = missionNamespace getVariable ["WFBE_C_AICOM_GROUP_CAP", 110];
		if (_sideAI + 8 >= _cap || {_groupCount + 1 >= _groupCap}) then {
			_hasTruck = true;
		};
	};

	if (!_hasTruck) then {
		_target = objNull;
		_bestDeficit = 0;
		_bestDistance = 1e10;
		{
			_town = _x;
			_townSideId = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
			_sv = _town getVariable ["supplyValue", -1];
			_maxSV = _town getVariable ["maxSupplyValue", -1];
			if (typeName _sv == "SCALAR" && {typeName _maxSV == "SCALAR"}) then {
				_deficit = _maxSV - _sv;
				_distance = _town distance _hq;
				if (_townSideId == _sideId && {!(_town getVariable ["wfbe_contested", false])} && {!(_town getVariable ["wfbe_is_naval_hvt", false])} && {!(_town getVariable ["wfbe_inactive", false])} && {_sv >= 0} && {_maxSV > 0} && {_deficit > 0} && {(_deficit > _bestDeficit) || {_deficit == _bestDeficit && {_distance < _bestDistance}}}) then {
					_target = _town;
					_bestDeficit = _deficit;
					_bestDistance = _distance;
				};
			};
		} forEach towns;
		if (isNull _target) then {_hasTruck = true};
	};

	if (!_hasTruck) then {
		_spawnPos = getPos _hq;
		_group = [_side, "ai-supply-truck"] Call WFBE_CO_FNC_CreateGroup;
		if (isNull _group) then {
			_hasTruck = true;
		} else {
			_truckType = missionNamespace getVariable [Format ["WFBE_%1SUPPLYTRUCK", _sideText], ""];
			_truck = [_truckType, _spawnPos, _side, getDir _hq, true, true, true, "NONE"] Call WFBE_CO_FNC_CreateVehicle;
			if (isNull _truck) then {
				deleteGroup _group;
				_hasTruck = true;
			} else {
				_templates = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
				_templateTypes = missionNamespace getVariable [Format ["WFBE_%1AITEAMTYPES", _sideText], []];
				_templateIndex = -1;
				for "_i" from 0 to ((count _templates) - 1) do {
					if (_templateIndex < 0 && {_i < count _templateTypes} && {(_templateTypes select _i) == 0} && {count (_templates select _i) >= 8}) then {_templateIndex = _i};
				};
				_units = [];
				if (_templateIndex >= 0) then {
					_template = _templates select _templateIndex;
					for "_i" from 0 to 7 do {
						_unitClass = _template select _i;
						_unit = [_unitClass, _group, _spawnPos, _side, true, "FORM"] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _unit) then {_units = _units + [_unit]};
					};
				};
				if (count _units < 8) then {
					{if (!isNull _x) then {deleteVehicle _x}} forEach _units;
					deleteVehicle _truck;
					deleteGroup _group;
					_hasTruck = true;
				} else {
					_driver = _units select 0;
					_driver moveInDriver _truck;
					for "_i" from 1 to 7 do {(_units select _i) moveInCargo _truck};
					_group setVariable ["wfbe_persistent", true];
					_group setVariable ["wfbe_ai_supply_group", true];
					_truck setVariable ["wfbe_trashable", false];
					_truck setVariable ["wfbe_ai_supply_side", _side];
					_registry = _registry + [_truck];
					_logic setVariable ["wfbe_ai_supplytrucks", _registry];
					_truck setVariable ["wfbe_ai_supplytruck", true, true];
					_truck addEventHandler ["FiredNear", {
						private ["_vehicle","_source","_ownSide"];
						_vehicle = _this select 0;
						_source = _this select 1;
						_ownSide = _vehicle getVariable ["wfbe_ai_supply_side", sideEmpty];
						if (!isNull _source && {alive _source} && {side _source != _ownSide} && {side _source in [west,east,resistance]}) then {_vehicle setVariable ["wfbe_ai_supply_contact", true]};
					}];
					_truck addEventHandler ["Hit", {
						private ["_vehicle","_source","_ownSide"];
						_vehicle = _this select 0;
						_source = _this select 1;
						_ownSide = _vehicle getVariable ["wfbe_ai_supply_side", sideEmpty];
						if (!isNull _source && {alive _source} && {side _source != _ownSide} && {side _source in [west,east,resistance]}) then {_vehicle setVariable ["wfbe_ai_supply_contact", true]};
					}];
					_diagLog = Format ["AISUPPLY|v1|%1|%2|SPAWN|crew=8|town=%3", _sideText, round (time / 60), _target getVariable ["name", "town"]];
					diag_log _diagLog;

					_cleanup = {
						private ["_blocked","_currentRegistry","_remaining"];
						_blocked = false;
						_crew = crew _truck;
						{if (isPlayer _x) then {_blocked = true}} forEach _crew;
						if (_blocked) exitWith {
							_lastLog = _logic getVariable ["wfbe_ai_supply_abort_t", -9999];
							if (time - _lastLog >= 300) then {
								_logic setVariable ["wfbe_ai_supply_abort_t", time];
								diag_log Format ["AISUPPLY|v1|%1|%2|ABORT|reason=player-occupancy", _sideText, round (time / 60)];
							};
							false
						};
						if (!local _truck) exitWith {diag_log Format ["AISUPPLY|v1|%1|%2|ABORT|reason=non-local-hull", _sideText, round (time / 60)]; false};
						_group setVariable ["wfbe_persistent", false];
						_truck setVariable ["wfbe_trashable", false];
						_truck removeAllEventHandlers "FiredNear";
						_truck removeAllEventHandlers "Hit";
						_truck removeAllEventHandlers "Killed";
						{if (!isNull _x) then {deleteVehicle _x}} forEach _units;
						deleteVehicle _truck;
						_deleteUntil = time + 5;
						while {!isNull _truck && {time < _deleteUntil}} do {sleep 0.1};
						if (!isNull _truck) exitWith {diag_log Format ["AISUPPLY|v1|%1|%2|ABORT|reason=hull-delete-unconfirmed", _sideText, round (time / 60)]; false};
						_remaining = _logic getVariable ["wfbe_ai_supplytrucks", []];
						_currentRegistry = [];
						{if (!isNull _x && {_x != _truck}) then {_currentRegistry = _currentRegistry + [_x]}} forEach _remaining;
						_logic setVariable ["wfbe_ai_supplytrucks", _currentRegistry];
						deleteGroup _group;
						diag_log Format ["AISUPPLY|v1|%1|%2|CLEANUP|crew=0|vehicle=0|group=0", _sideText, round (time / 60)];
						true
					};

					_anchor = _hq;
					_structures = _side Call WFBE_CO_FNC_GetSideStructures;
					_anchorFound = false;
					for "_i" from 0 to ((count _structures) - 1) do {
						_candidate = _structures select _i;
						if (!_anchorFound && {!isNull _candidate} && {alive _candidate} && {_candidate isKindOf "Base_WarfareBVehicleServicePoint"} && {_candidate getVariable ["WFBE_RepairTruckServicePoint", false]}) then {
							_anchor = _candidate;
							_anchorFound = true;
						};
					};

					_phase = "OUTBOUND";
					_tripToken = 1;
					_delivered = false;
					_reseated = false;
					_done = false;
					_abort = false;
					while {!_done} do {
						if (WFBE_GameOver || {!((missionNamespace getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]) > 0)} || {(missionNamespace getVariable ["WFBE_C_ECONOMY_SUPPLY_SYSTEM", 1]) != 0} || {!((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0)} || {!alive _hq} || {!(_side Call WFBE_CO_FNC_GetSideHQDeployStatus)}) then {_abort = true};
						if (_abort) then {
							_cleanupOk = call _cleanup;
							if (_cleanupOk) then {_done = true} else {sleep 30};
						} else {
							if (_phase == "RETURN" && {isNull _anchor || {!alive _anchor}}) then {_anchor = _side Call WFBE_CO_FNC_GetSideHQ};
							if (_phase == "RETURN" && {isNull _anchor || {!alive _anchor}}) then {_abort = true};
							_routeTarget = if (_phase == "OUTBOUND") then {_target} else {_anchor};
							[_group, true, [[getPos _routeTarget, "MOVE", 100, 80, "", []]]] Call AIWPAdd;
							_legStart = time;
							_contactUntil = 0;
							while {alive _truck && {!_abort}} do {
								sleep 2;
								if (WFBE_GameOver || {!((missionNamespace getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]) > 0)} || {!((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0)}) then {_abort = true};
								_driver = driver _truck;
								if (isNull _driver || {!alive _driver}) then {
									if (!_reseated) then {
										_seat = objNull;
										for "_j" from 0 to ((count _units) - 1) do {if (isNull _seat && {alive (_units select _j)} && {(_units select _j) != _driver}) then {_seat = _units select _j}};
										if (!isNull _seat) then {_seat moveInDriver _truck; _reseated = true; diag_log Format ["AISUPPLY|v1|%1|%2|DISPATCH|driver-reseated", _sideText, round (time / 60)]} else {_abort = true};
									} else {_abort = true};
								};
								_activeContact = _truck getVariable ["wfbe_ai_supply_contact", false];
								if (_activeContact) then {
									_truck setVariable ["wfbe_ai_supply_contact", false];
									if (_contactUntil <= time) then {
										_group setBehaviour "AWARE";
										_group setCombatMode "RED";
										_group setSpeedMode "FULL";
										for "_j" from 0 to ((count _units) - 1) do {
											if (alive (_units select _j) && {(_units select _j) != driver _truck}) then {unassignVehicle (_units select _j); (_units select _j) action ["EJECT", _truck]};
										};
										diag_log Format ["AISUPPLY|v1|%1|%2|CONTACT|escalated", _sideText, round (time / 60)];
									};
									_contactUntil = time + 60;
								};
								if (_contactUntil > 0 && {time > _contactUntil}) then {
									_contactUntil = 0;
									_group setBehaviour "SAFE";
									_group setCombatMode "YELLOW";
									_group setSpeedMode "NORMAL";
									for "_j" from 0 to ((count _units) - 1) do {
										if (alive (_units select _j) && {(_units select _j) != driver _truck} && {!isPlayer (_units select _j)}) then {(_units select _j) moveInCargo _truck};
									};
									diag_log Format ["AISUPPLY|v1|%1|%2|CLEAR|transit-restored", _sideText, round (time / 60)];
									[_group, true, [[getPos _routeTarget, "MOVE", 100, 80, "", []]]] Call AIWPAdd;
								};
								if (_truck distance _routeTarget < 100) exitWith {};
								if (time - _legStart > 900) then {_abort = true};
							};
							if (_abort || {!alive _truck}) then {
								_cleanupOk = call _cleanup;
								if (_cleanupOk) then {_done = true} else {sleep 30};
							} else {
								if (_phase == "OUTBOUND") then {
									_sv = _target getVariable ["supplyValue", -1];
									_maxSV = _target getVariable ["maxSupplyValue", -1];
									_crew = crew _truck;
									_targetOccupied = false;
									{if (isPlayer _x) then {_targetOccupied = true}} forEach _crew;
									_numericSV = typeName _sv == "SCALAR" && {typeName _maxSV == "SCALAR"};
									if (_targetOccupied || {!_numericSV} || {surfaceIsWater (getPos _target)}) then {
										_abort = true;
									} else {
									if ((_target getVariable ["sideID", WFBE_C_UNKNOWN_ID]) != _sideId || {_target getVariable ["wfbe_contested", false]} || {_target getVariable ["wfbe_is_naval_hvt", false]} || {_sv < 0} || {_maxSV <= _sv} || {!alive _driver}) then {
										_phase = "RETURN";
									} else {
										_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades;
										_rates = missionNamespace getVariable ["WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK", [5,6,7,8,10]];
										_rateIndex = 0;
										if (count _upgrades > WFBE_UP_SUPPLYRATE) then {_rateIndex = _upgrades select WFBE_UP_SUPPLYRATE};
										if (_rateIndex < 0) then {_rateIndex = 0};
										if (_rateIndex >= count _rates) then {_rateIndex = (count _rates) - 1};
										_truckRate = _rates select _rateIndex;
										_before = _sv;
										_after = (_before + _truckRate) min _maxSV;
										if (!_delivered) then {
											_delivered = true;
											_target setVariable ["supplyValue", _after, true];
											diag_log Format ["AISUPPLY|v1|%1|%2|DELIVER|town=%3|before=%4|after=%5|max=%6|rate=%7|trip=%8", _sideText, round (time / 60), _target getVariable ["name", "town"], _before, _after, _maxSV, _truckRate, _tripToken];
										};
										_phase = "RETURN";
									};
								};
								} else {
									_delivered = false;
									_tripToken = _tripToken + 1;
									_phase = "RELOAD";
									diag_log Format ["AISUPPLY|v1|%1|%2|RETURN|anchor=%3|trip=%4", _sideText, round (time / 60), str _anchor, _tripToken];
									sleep 30;
									if (!alive _anchor) then {_anchor = _side Call WFBE_CO_FNC_GetSideHQ};
									if (isNull _anchor || {!alive _anchor}) then {
										_abort = true;
									} else {
										_target = objNull;
										_bestDeficit = 0;
										_bestDistance = 1e10;
										{
											_town = _x;
											_townSideId = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
											_sv = _town getVariable ["supplyValue", -1];
											_maxSV = _town getVariable ["maxSupplyValue", -1];
											if (typeName _sv == "SCALAR" && {typeName _maxSV == "SCALAR"}) then {
												_deficit = _maxSV - _sv;
												_distance = _town distance _hq;
												if (_townSideId == _sideId && {!(_town getVariable ["wfbe_contested", false])} && {!(_town getVariable ["wfbe_is_naval_hvt", false])} && {!(_town getVariable ["wfbe_inactive", false])} && {_sv >= 0} && {_maxSV > 0} && {_deficit > 0} && {(_deficit > _bestDeficit) || {_deficit == _bestDeficit && {_distance < _bestDistance}}}) then {
													_target = _town;
													_bestDeficit = _deficit;
													_bestDistance = _distance;
												};
											};
										} forEach towns;
										if (isNull _target) then {_abort = true} else {_phase = "OUTBOUND"};
									};
								};
							};
						};
					};
					if (!_done) then {
						_cleanupOk = call _cleanup;
						if (!_cleanupOk) then {sleep 30};
					};
				};
			};
		};
	};
	sleep 30;
};
