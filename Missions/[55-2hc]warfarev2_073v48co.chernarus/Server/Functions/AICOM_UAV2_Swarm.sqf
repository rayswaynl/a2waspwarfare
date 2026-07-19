/*
	Dedicated low-frequency UAV2 swarm worker. _this = [mainSide].
	AI-commander treasury only; a human commander hard-disables every draw.
*/
private ["_side","_sideID","_sideText","_interval","_cmdTeam","_skip","_upgrades","_level","_hq","_cooldown","_lastKey","_last","_activeKey","_active","_maxActive","_slots","_enemySide","_enemyID","_enemyTowns","_targetTown","_scanRadius","_targets","_target","_bestWeight","_weight","_cost","_funds","_maxStrike","_swarmSize","_droneClass","_pilotClass","_ammoClass","_totalCost","_targetPos","_targetName","_launchGap","_hitRadius","_ttl","_diveRange","_i"];

if (!isServer) exitWith {};
_side = _this select 0;
if (_side != west && {_side != east}) exitWith {};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_interval = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_INTERVAL", 180];
if (_interval < 30) then {_interval = 30};
sleep _interval;

while {!gameOver} do {
	_skip = !((missionNamespace getVariable ["WFBE_C_UAV2_SWARM", 0]) > 0);
	if (!_skip && {!((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0)}) then {_skip = true};

	//--- Owner law: this tool disappears whenever the commander is human, regardless of any AI lock override.
	if (!_skip) then {
		_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (!isNull _cmdTeam && {isPlayer (leader _cmdTeam)}) then {_skip = true};
	};

	if (!_skip) then {
		_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
		_level = missionNamespace getVariable ["WFBE_C_UAV2_LEVEL", 2];
		if (typeName _upgrades != "ARRAY" || {count _upgrades <= WFBE_UP_UAV} || {(_upgrades select WFBE_UP_UAV) < _level}) then {_skip = true};
	};

	if (!_skip) then {
		_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
		if (isNull _hq || {!alive _hq}) then {_skip = true};
	};

	if (!_skip) then {
		_cooldown = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_COOLDOWN", 1200];
		_lastKey = Format ["wfbe_uav2_swarm_last_%1", _sideText];
		_last = missionNamespace getVariable [_lastKey, -99999];
		if ((time - _last) < _cooldown) then {_skip = true};
	};

	if (!_skip) then {
		_activeKey = Format ["wfbe_uav2_swarm_active_%1", _sideText];
		_active = missionNamespace getVariable [_activeKey, []];
		{if (isNull _x || {!alive _x}) then {_active = _active - [_x]}} forEach (+_active);
		missionNamespace setVariable [_activeKey, _active];
		_maxActive = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_MAX_ACTIVE", 3];
		_slots = _maxActive - count _active;
		if (_slots < 1) then {_skip = true};
	};

	if (!_skip) then {
		_enemySide = if (_side == west) then {east} else {west};
		_enemyID = (_enemySide) Call WFBE_CO_FNC_GetSideID;
		_enemyTowns = [];
		{if ((_x getVariable ["sideID", -1]) == _enemyID) then {_enemyTowns = _enemyTowns + [_x]}} forEach towns;
		_targetTown = [getPos _hq, _enemyTowns] Call WFBE_CO_FNC_GetClosestEntity;
		if (isNull _targetTown) then {_skip = true};
	};

	if (!_skip) then {
		_scanRadius = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_SCAN_RADIUS", 300];
		_targets = _targetTown nearEntities ["AllVehicles", _scanRadius];
		_target = objNull;
		_bestWeight = 0;
		{
			if (alive _x && {side _x == _enemySide} && {!(_x isKindOf "Air")}) then {
				_weight = 1;
				if (_x isKindOf "StaticWeapon") then {_weight = 5} else {if (_x isKindOf "Tank" || {_x isKindOf "Wheeled_APC"}) then {_weight = 4} else {if !(_x isKindOf "Man") then {_weight = 2}}};
				if (_weight > _bestWeight) then {_bestWeight = _weight; _target = _x};
			};
		} forEach _targets;
		if (isNull _target) then {_skip = true};
	};

	if (!_skip) then {
		_cost = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_COST", 5000];
		_funds = (_side) Call GetAICommanderFunds;
		_maxStrike = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_MAX_PER_STRIKE", 3];
		_swarmSize = _slots min _maxStrike;
		if (typeName _cost != "SCALAR" || {_cost <= 0}) then {_swarmSize = 0} else {_swarmSize = _swarmSize min (floor (_funds / _cost))};
		_droneClass = missionNamespace getVariable [Format ["WFBE_%1FPVDRONE", _sideText], ""];
		_pilotClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""];
		if (_swarmSize < 1 || {_droneClass == ""} || {_pilotClass == ""} || {!(isClass (configFile >> "CfgVehicles" >> _droneClass))} || {!(isClass (configFile >> "CfgVehicles" >> _pilotClass))}) then {_skip = true};
	};

	if (!_skip) then {
		_totalCost = _cost * _swarmSize;
		[_side, -_totalCost] Call ChangeAICommanderFunds;
		missionNamespace setVariable [_lastKey, time];
		_targetPos = getPos _target;
		_targetName = _targetTown getVariable ["name", "?"];
		_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];
		_launchGap = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_LAUNCH_GAP", 2];
		_hitRadius = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_HIT_RADIUS", 15];
		_ttl = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_TTL", 180];
		_diveRange = missionNamespace getVariable ["WFBE_C_UAV2_SWARM_DIVE_RANGE", 120];
		diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UAV2_SWARM_PURCHASE|size=" + str _swarmSize + "|cost=" + str _totalCost + "|target=" + _targetName);

		_i = 0;
		while {_i < _swarmSize} do {
			[_side, _sideID, _sideText, _hq, _droneClass, _pilotClass, _ammoClass, _targetPos, _targetName, _hitRadius, _ttl, _diveRange, _activeKey, _cost] Spawn {
				private ["_side","_sideID","_sideText","_hq","_droneClass","_pilotClass","_ammoClass","_targetPos","_targetName","_hitRadius","_ttl","_diveRange","_activeKey","_refund","_hqPos","_angle","_radius","_spawnPos","_drone","_group","_pilot","_active","_start","_done","_pos","_dx","_dy","_dist2","_dir"];
				_side = _this select 0; _sideID = _this select 1; _sideText = _this select 2; _hq = _this select 3;
				_droneClass = _this select 4; _pilotClass = _this select 5; _ammoClass = _this select 6; _targetPos = _this select 7; _targetName = _this select 8;
				_hitRadius = _this select 9; _ttl = _this select 10; _diveRange = _this select 11; _activeKey = _this select 12; _refund = _this select 13;
				_hqPos = getPos _hq; _angle = random 360; _radius = 20 + random 15;
				_spawnPos = [(_hqPos select 0) + _radius * sin _angle, (_hqPos select 1) + _radius * cos _angle, (_hqPos select 2) + 20];
				_drone = createVehicle [_droneClass, _spawnPos, [], 0, "FLY"];
				_group = [_side, "uav2-swarm"] Call WFBE_CO_FNC_CreateGroup;
				_pilot = objNull;
				if (!isNull _group && {!isNull _drone}) then {_pilot = [_pilotClass, _group, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit};
				if (isNull _drone || {isNull _group} || {isNull _pilot}) exitWith {
					if (!isNull _pilot) then {deleteVehicle _pilot}; if (!isNull _drone) then {deleteVehicle _drone}; if (!isNull _group) then {deleteGroup _group};
					[_side, _refund] Call ChangeAICommanderFunds;
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UAV2_SWARM_REFUND|cost=" + str _refund + "|reason=launch-failed");
				};
				_pilot moveInDriver _drone; _group setBehaviour "CARELESS"; _group setCombatMode "BLUE"; _drone flyInHeight 60; _pilot doMove _targetPos;
				_active = missionNamespace getVariable [_activeKey, []]; _active = _active + [_drone]; missionNamespace setVariable [_activeKey, _active];
				_start = time; _done = false;
				while {alive _drone && {alive _pilot} && {(time - _start) < _ttl}} do {
					_pos = getPos _drone; _dx = (_targetPos select 0) - (_pos select 0); _dy = (_targetPos select 1) - (_pos select 1); _dist2 = (_dx * _dx) + (_dy * _dy);
					if (_dist2 < (_hitRadius * _hitRadius)) exitWith {createVehicle [_ammoClass, _pos, [], 0, "NONE"]; _done = true};
					_pilot doMove _targetPos;
					if (_dist2 < (_diveRange * _diveRange)) then {_dir = if (_dx == 0 && {_dy == 0}) then {direction _drone} else {_dx atan2 _dy}; _drone flyInHeight 0; _drone setVelocity [20 * sin _dir, 20 * cos _dir, -8]};
					sleep 1;
				};
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UAV2_SWARM_END|target=" + _targetName + "|hit=" + str _done);
				if (alive _pilot) then {_pilot setDammage 1}; if (alive _drone) then {_drone setDammage 1}; sleep 5;
				{deleteVehicle _x} forEach (crew _drone + [_drone]); if (!isNull _group) then {deleteGroup _group};
				_active = missionNamespace getVariable [_activeKey, []]; _active = _active - [_drone]; missionNamespace setVariable [_activeKey, _active];
			};
			_i = _i + 1;
			if (_i < _swarmSize) then {sleep _launchGap};
		};
	};
	sleep _interval;
};
