/*
	Server_An2SmugglerRun.sqf - dormant AN-2 cargo encounter (server-only, default OFF).

	Lane 11: a rare low-flying AN-2 crosses the map. If players shoot it down, a cargo
	crate marker appears and the killer side/team receives a small reward. This is a
	standalone a-life worker and intentionally does not share state with GUER air-def,
	naval HVT or AICOM wildcard loops.

	A2 OA 1.64 safe: no selectRandom/findIf/worldSize/binary getDir/A3 marker commands.
*/
if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_RUN", 0]) < 1) exitWith {};

private ["_activeVeh","_pickEdgePos"];

waitUntil {
	!isNil "WFBE_BOUNDARIESXY"
	&& {!isNil "towns"} && {(count towns) > 0}
};
sleep 90;

_pickEdgePos = {
	private ["_lo","_hi","_height","_edge","_span","_x","_y"];
	_lo = _this select 0;
	_hi = _this select 1;
	_height = _this select 2;
	_edge = _this select 3;
	_span = (_hi - _lo) max 1;
	_x = _lo;
	_y = _lo;

	switch (_edge) do {
		case 0: {_x = _lo; _y = _lo + random _span};
		case 1: {_x = _lo + random _span; _y = _hi};
		case 2: {_x = _hi; _y = _lo + random _span};
		default {_x = _lo + random _span; _y = _lo};
	};

	[_x, _y, _height]
};

_activeVeh = objNull;

["INITIALIZATION", Format ["Server_An2SmugglerRun.sqf: AN-2 smuggler run started (interval=%1 chance=%2).", missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_INTERVAL", 1800], missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CHANCE", 0.35]]] Call WFBE_CO_FNC_LogContent;
diag_log format ["AN2SMUGGLER|START|interval=%1|chance=%2", missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_INTERVAL", 1800], missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CHANCE", 0.35]];

while {!WFBE_GameOver} do {
	private ["_interval"];
	_interval = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_INTERVAL", 1800];
	if (typeName _interval != "SCALAR") then {_interval = 1800};
	if (_interval < 120) then {_interval = 120};
	sleep _interval;

	if ((missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_RUN", 0]) > 0) then {
		private ["_canSpawn","_minPlayers","_playerCount","_chance"];

		_canSpawn = true;
		if (!isNull _activeVeh && {alive _activeVeh}) then {_canSpawn = false};

		_minPlayers = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_MIN_PLAYERS", 1];
		if (typeName _minPlayers != "SCALAR") then {_minPlayers = 1};
		if (_minPlayers > 0) then {
			_playerCount = {isPlayer _x && {((side _x) == west) || {((side _x) == east) || {(side _x) == resistance}}}} count playableUnits;
			if (_playerCount < _minPlayers) then {_canSpawn = false};
		};

		_chance = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CHANCE", 0.35];
		if (typeName _chance != "SCALAR") then {_chance = 0.35};
		if (_chance < 0) then {_chance = 0};
		if (_chance > 1) then {_chance = 1};

		if (_canSpawn && {(random 1) < _chance}) then {
			private ["_classes","_class","_mapSize","_edgePad","_lo","_hi","_height","_startEdge","_endEdge","_start","_end","_dx","_dy","_dir","_grp","_veh","_pilotClass","_pilot","_wp","_timeout"];

			_classes = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CLASSES", ["An2_1_TK_CIV_EP1","An2_2_TK_CIV_EP1","An2_TK_EP1"]];
			if (typeName _classes != "ARRAY") then {_classes = ["An2_1_TK_CIV_EP1"]};
			if ((count _classes) < 1) then {_classes = ["An2_1_TK_CIV_EP1"]};
			_class = _classes select (floor (random (count _classes)));
			if (typeName _class != "STRING") then {_class = "An2_1_TK_CIV_EP1"};

			if (isClass (configFile >> "CfgVehicles" >> _class)) then {
				_mapSize = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
				if (typeName _mapSize != "SCALAR") then {_mapSize = 15360};
				if (_mapSize < 1000) then {_mapSize = 15360};

				_edgePad = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_EDGE_PAD", 250];
				if (typeName _edgePad != "SCALAR") then {_edgePad = 250};
				if (_edgePad < 50) then {_edgePad = 50};

				_lo = _edgePad;
				_hi = _mapSize - _edgePad;
				if (_hi <= _lo) then {_lo = 100; _hi = _mapSize - 100};

				_height = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_HEIGHT", 140];
				if (typeName _height != "SCALAR") then {_height = 140};
				if (_height < 60) then {_height = 60};

				_startEdge = floor (random 4);
				_endEdge = (_startEdge + 2) % 4;
				_start = [_lo, _hi, _height, _startEdge] Call _pickEdgePos;
				_end = [_lo, _hi, _height, _endEdge] Call _pickEdgePos;
				_dx = (_end select 0) - (_start select 0);
				_dy = (_end select 1) - (_start select 1);
				_dir = if (abs _dx < 0.01 && {abs _dy < 0.01}) then {random 360} else {_dx atan2 _dy};

				_grp = [resistance, "an2-smuggler"] Call WFBE_CO_FNC_CreateGroup;
				if (isNull _grp) then {
					["WARNING", "Server_An2SmugglerRun.sqf: CreateGroup returned grpNull; smuggler spawn skipped."] Call WFBE_CO_FNC_LogContent;
				} else {
					_veh = [_class, _start, resistance, _dir, false, false, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
					if (isNull _veh) then {
						deleteGroup _grp;
						["WARNING", Format ["Server_An2SmugglerRun.sqf: failed to create AN-2 class %1.", _class]] Call WFBE_CO_FNC_LogContent;
					} else {
						_pilotClass = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_PILOT", "GUE_Soldier_Pilot"];
						if (typeName _pilotClass != "STRING") then {_pilotClass = "GUE_Soldier_Pilot"};
						if !(isClass (configFile >> "CfgVehicles" >> _pilotClass)) then {_pilotClass = "GUE_Soldier_Pilot"};
						_pilot = [_pilotClass, _grp, _start, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;

						if (isNull _pilot) then {
							deleteVehicle _veh;
							deleteGroup _grp;
							["WARNING", Format ["Server_An2SmugglerRun.sqf: failed to create pilot class %1.", _pilotClass]] Call WFBE_CO_FNC_LogContent;
						} else {
							_pilot assignAsDriver _veh;
							_pilot moveInDriver _veh;
							_grp setBehaviour "CARELESS";
							_grp setCombatMode "BLUE";
							_grp setSpeedMode "LIMITED";
							{_x allowFleeing 0} forEach (units _grp);

							_veh flyInHeight _height;
							_veh setVariable ["wfbe_an2_smuggler", true, true];
							_veh setVariable ["wfbe_an2_smuggler_rewarded", false, false];

							_wp = _grp addWaypoint [_end, 0];
							_wp setWaypointType "MOVE";
							_wp setWaypointBehaviour "CARELESS";
							_wp setWaypointCombatMode "BLUE";
							_wp setWaypointSpeed "LIMITED";
							_wp setWaypointCompletionRadius 800;

							_veh addEventHandler ["Killed", {
								private ["_veh","_killer","_pos","_rewardSupply","_rewardFunds","_crateType","_crate","_kSide","_kGroup","_marker","_ttl","_txt"];
								_veh = _this select 0;
								_killer = _this select 1;

								if (_veh getVariable ["wfbe_an2_smuggler_rewarded", false]) exitWith {};
								_veh setVariable ["wfbe_an2_smuggler_rewarded", true, false];

								_pos = getPos _veh;
								_rewardSupply = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_REWARD_SUPPLY", 2500];
								_rewardFunds = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_REWARD_FUNDS", 1000];
								_crateType = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CRATE", "USBasicAmmunitionBox_EP1"];
								_ttl = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_CRATE_TTL", 900];
								if (typeName _rewardSupply != "SCALAR") then {_rewardSupply = 2500};
								if (typeName _rewardFunds != "SCALAR") then {_rewardFunds = 1000};
								if (typeName _crateType != "STRING") then {_crateType = "USBasicAmmunitionBox_EP1"};
								if (typeName _ttl != "SCALAR") then {_ttl = 900};
								if (_ttl < 60) then {_ttl = 60};

								_crate = objNull;
								if (isClass (configFile >> "CfgVehicles" >> _crateType)) then {
									_crate = createVehicle [_crateType, _pos, [], 0, "NONE"];
									if (!isNull _crate) then {
										_crate setPos [(_pos select 0), (_pos select 1), 0];
										_crate setVariable ["wfbe_an2_smuggler_crate", true, true];
										_crate setVariable ["wfbe_an2_smuggler_supply", _rewardSupply, true];
										_crate setVariable ["wfbe_an2_smuggler_funds", _rewardFunds, true];
									};
								};

								_kSide = civilian;
								_kGroup = grpNull;
								if (!isNull _killer) then {
									_kSide = side _killer;
									_kGroup = group _killer;
									if (!(_kSide in [west, east, resistance]) && {!isNull _kGroup}) then {_kSide = side _kGroup};
								};

								if (_kSide in [west, east, resistance]) then {
									if (_rewardSupply > 0) then {[_kSide, _rewardSupply, Format ["AN-2 smuggler cargo recovered (+S %1).", _rewardSupply], false] Call ChangeSideSupply};
									if (_rewardFunds > 0 && {!isNull _kGroup}) then {[_kGroup, _rewardFunds] Call WFBE_CO_FNC_ChangeTeamFunds};
								};

								_marker = Format ["wfbe_an2_smuggler_drop_%1", round time];
								createMarker [_marker, [(_pos select 0), (_pos select 1), 0]];
								_marker setMarkerType "mil_dot";
								_marker setMarkerColor "ColorYellow";
								_txt = if (_rewardSupply > 0) then {Format ["AN-2 cargo +S%1", _rewardSupply]} else {"AN-2 cargo"};
								_marker setMarkerText _txt;

								[_crate, _marker, _ttl] Spawn {
									private ["_crate","_marker","_ttl"];
									_crate = _this select 0;
									_marker = _this select 1;
									_ttl = _this select 2;
									sleep _ttl;
									if (!isNull _crate) then {deleteVehicle _crate};
									deleteMarker _marker;
								};

								diag_log format ["AN2SMUGGLER|DROP|killerSide=%1|supply=%2|funds=%3|pos=%4|crate=%5", _kSide, _rewardSupply, _rewardFunds, _pos, _crateType];
							}];

							_timeout = missionNamespace getVariable ["WFBE_C_AN2_SMUGGLER_TIMEOUT", 900];
							if (typeName _timeout != "SCALAR") then {_timeout = 900};
							if (_timeout < 120) then {_timeout = 120};

							_activeVeh = _veh;
							[_veh, _grp, _end, _timeout] Spawn {
								private ["_veh","_grp","_end","_timeout","_born","_escaped"];
								_veh = _this select 0;
								_grp = _this select 1;
								_end = _this select 2;
								_timeout = _this select 3;
								_born = time;
								_escaped = false;

								waitUntil {
									sleep 10;
									isNull _veh
									|| {!(alive _veh)}
									|| {(_veh distance _end) < 800}
									|| {(time - _born) > _timeout}
									|| {WFBE_GameOver}
								};

								if (!isNull _veh && {alive _veh}) then {
									_escaped = true;
									diag_log format ["AN2SMUGGLER|ESCAPE|pos=%1|timeout=%2", getPos _veh, (time - _born)];
								} else {
									sleep 45;
								};

								if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then {{deleteVehicle _x} forEach (crew _veh); deleteVehicle _veh};
								if (!isNull _grp) then {{if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _grp); deleteGroup _grp};
							};

							["INFORMATION", Format ["Server_An2SmugglerRun.sqf: spawned %1 from %2 to %3.", _class, _start, _end]] Call WFBE_CO_FNC_LogContent;
							diag_log format ["AN2SMUGGLER|SPAWN|class=%1|from=%2|to=%3|height=%4", _class, _start, _end, _height];
						};
					};
				};
			} else {
				["WARNING", Format ["Server_An2SmugglerRun.sqf: configured AN-2 class %1 is missing; spawn skipped.", _class]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};
};
