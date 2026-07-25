/*
    AICOM CARGO AIRDROP Stage A.
    Parameter: _this = ["CargoAirdrop", side, destination, infantryGroup].

    This is an AI-only composition: one existing side-configured paratroop
    transport plane, its infantry stick, and up to two empty side-configured
    para-vehicles. The vehicle attach/detach/chute block follows the shipping
    Support_ParaVehicles.sqf mechanism. The vehicle releases are staggered by
    three seconds, derived from Support_ParaAmmo.sqf's multi-payload cadence.
    There is intentionally no escort jet in Stage A.
*/

private ["_args","_bd","_cargoClass","_cargoVehicle","_cargoVehicles","_chuteClass","_currentLevel","_currentUpgrades","_destination","_dropReady","_i","_isAI","_offset","_origin","_paratroopers","_pilot","_pilotClass","_planeClass","_playerTeam","_ran","_ranDir","_ranPos","_releasedCargo","_returnStart","_side","_sideID","_starttime","_units","_unit","_vehicle","_vehicleCargo","_vehicleCount","_vehicleIndex","_vehicleCoord","_positionCoord","_builtInf","_transportGroup","_pendingCargo","_delay"];

_args = _this;
_side = _args select 1;
_destination = _args select 2;
_playerTeam = _args select 3;
_sideID = _side Call GetSideID;
_isAI = !(isPlayer (leader _playerTeam));
_starttime = time;

_bd = missionNamespace getVariable "WFBE_BOUNDARIESXY";
_ranPos = [];
_ranDir = [];
if !(isNil "_bd") then {
	_ranPos = [[0 + random(200), 0 + random(200), 400 + random(200)],[0 + random(200), _bd - random(200), 400 + random(200)],[_bd - random(200), _bd - random(200), 400 + random(200)],[_bd - random(200), 0 + random(200), 400 + random(200)]];
	_ranDir = [45,145,225,315];
} else {
	_ranPos = [[0 + random(200), 0 + random(200), 400 + random(200)],[15000 + random(200), 0 + random(200), 400 + random(200)]];
	_ranDir = [45,315];
};
_ran = floor(random count _ranPos);
_origin = _ranPos select _ran;

_currentUpgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_currentLevel = _currentUpgrades select WFBE_UP_PARATROOPERS;
_units = missionNamespace getVariable Format ["WFBE_%1PARACHUTELEVEL%2", str _side, _currentLevel];
_planeClass = missionNamespace getVariable Format ["WFBE_%1PARACARGO", str _side];
_cargoClass = missionNamespace getVariable Format ["WFBE_%1PARAVEHICARGO", str _side];
_pilotClass = missionNamespace getVariable Format ["WFBE_%1PILOT", str _side];
_chuteClass = missionNamespace getVariable Format ["WFBE_%1PARACHUTE", str _side];
_vehicleCount = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX", 2];
if (typeName _vehicleCount != "SCALAR") then {_vehicleCount = 2};
if (_vehicleCount < 0) then {_vehicleCount = 0};
if (_vehicleCount > 2) then {_vehicleCount = 2};

if (isNil "_units" || {isNil "_planeClass"} || {isNil "_pilotClass"} || {(_vehicleCount > 0) && {isNil "_cargoClass"}} || {(_vehicleCount > 0) && {isNil "_chuteClass"}}) exitWith {
	["ERROR", Format ["Support_CargoAirdrop.sqf: [%1] required cargo configuration is missing.", str _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _units != "ARRAY") exitWith {};
_vehicleCargo = getNumber(configFile >> "CfgVehicles" >> _planeClass >> "transportSoldier");
if (_vehicleCargo <= 0 || {_vehicleCargo < count _units}) exitWith {
	["ERROR", Format ["Support_CargoAirdrop.sqf: [%1] cargo plane [%2] cannot carry the infantry roster (%3/%4).", str _side, _planeClass, count _units, _vehicleCargo]] Call WFBE_CO_FNC_LogContent;
};

_transportGroup = [_side, "aicom_cargo_transport"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _transportGroup) exitWith {
	if (!isNull _playerTeam) then {deleteGroup _playerTeam};
};
_vehicle = createVehicle [_planeClass, _origin, [], (_ranDir select _ran), "FLY"];
if (isNull _vehicle) exitWith {
	if (!isNull _transportGroup) then {deleteGroup _transportGroup};
	if (!isNull _playerTeam) then {deleteGroup _playerTeam};
};
_pilot = [_pilotClass, _transportGroup, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _pilot) exitWith {
	if (!isNull _vehicle) then {deleteVehicle _vehicle};
	if (!isNull _transportGroup) then {deleteGroup _transportGroup};
	if (!isNull _playerTeam) then {deleteGroup _playerTeam};
};
_pilot moveInDriver _vehicle;
_vehicle flyInHeight (300 + random(75));
_transportGroup setBehaviour "CARELESS";
_transportGroup setCombatMode "STEALTH";
_pilot disableAI "AUTOTARGET";
_pilot disableAI "TARGET";
_pilot doMove _destination;
[_transportGroup, _destination, "MOVE", 10] Call AIMoveTo;
Call Compile Format ["_vehicle addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]", _sideID];
_vehicle setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];
processInitCommands;

_paratroopers = [];
_builtInf = 0;
{
	_unit = [_x, _playerTeam, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
	if (!isNull _unit) then {
		_unit moveInCargo _vehicle;
		_paratroopers set [count _paratroopers, _unit];
		_builtInf = _builtInf + 1;
	};
} forEach _units;
if (_builtInf <= 0) exitWith {
	{if (!isNull _x) then {deleteVehicle _x}} forEach _paratroopers;
	if (!isNull _playerTeam) then {deleteGroup _playerTeam};
	if (!isNull _pilot) then {deleteVehicle _pilot};
	if (!isNull _vehicle) then {deleteVehicle _vehicle};
	if (!isNull _transportGroup) then {deleteGroup _transportGroup};
};

_cargoVehicles = [];
_vehicleIndex = 0;
if (_vehicleCount > 0) then {
	for "_i" from 1 to _vehicleCount do {
		_cargoVehicle = [_cargoClass, [0,0,50], _sideID, 0, false] Call WFBE_CO_FNC_CreateVehicle;
		if (!isNull _cargoVehicle) then {
			if (_vehicleIndex == 0) then {_offset = [0,0,-3]} else {_offset = [-5,0,-3]};
			_cargoVehicle attachTo [_vehicle, _offset];
			emptyQueu = emptyQueu + [_cargoVehicle];
			[_cargoVehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_cargoVehicles set [count _cargoVehicles, _cargoVehicle];
			_vehicleIndex = _vehicleIndex + 1;
		};
	};
};
processInitCommands;
[_transportGroup, _destination, "MOVE", 10] Call AIMoveTo;

_dropReady = false;
while {true} do {
	sleep 1;
	if (!alive _pilot || {!alive _vehicle} || {isNull _vehicle} || {isNull _pilot}) exitWith {};
	if (_isAI && {time - _starttime > 500}) exitWith {};
	if (!_isAI && {!(isPlayer (leader _playerTeam))}) exitWith {};
	_vehicleCoord = [getPos _pilot select 0, getPos _pilot select 1];
	_positionCoord = [_destination select 0, _destination select 1];
	if (_vehicleCoord distance _positionCoord < 300) exitWith {_dropReady = true};
};

_releasedCargo = [];
if (_dropReady) then {
	_delay = if (_planeClass isKindOf "Plane") then {0.35} else {0.85};
	{
		_x action ["EJECT", _vehicle];
		sleep _delay;
	} forEach ((crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle]);

	if (_isAI && {count units _playerTeam > 0}) then {
		[_playerTeam, getPos (leader _playerTeam), 200] Call AIPatrol;
		_playerTeam setBehaviour "COMBAT";
		_playerTeam setCombatMode "RED";
	};

	//--- Release each vehicle only after the prior payload has had time to move downrange.
	if (!isNull _vehicle && {alive _vehicle}) then {
		{
			if (!isNull _x && {alive _x}) then {
				detach _x;
				_releasedCargo set [count _releasedCargo, _x];
				[_x, _side, _chuteClass] Spawn {
					private ["_cargo","_chute","_chuteClass","_dropStart","_side"];
					_cargo = _this select 0;
					_side = _this select 1;
					_chuteClass = _this select 2;
					sleep 2;
					if (isNull _cargo || {!alive _cargo}) exitWith {};
					_chute = _chuteClass createVehicle [0,0,20];
					_chute setPos [getPos _cargo select 0, getPos _cargo select 1, (getPos _cargo select 2) - 11];
					_chute setDir (getDir _cargo);
					_cargo attachTo [_chute, [0,0,0]];
					_dropStart = time;
					while {!isNull _cargo && {alive _cargo} && {(getPos _cargo select 2) >= 10} && {(time - _dropStart) < 120}} do {sleep 1};
					if (!isNull _cargo) then {detach _cargo};
					sleep 10;
					if (!isNull _chute) then {deleteVehicle _chute};
				};
				sleep 3;
			};
		} forEach _cargoVehicles;
	};

	[_transportGroup, _origin, "MOVE", 10] Call AIMoveTo;
	_returnStart = time;
	while {true} do {
		sleep 1;
		if (!alive _pilot || {!alive _vehicle} || {isNull _vehicle} || {isNull _pilot}) exitWith {};
		if (time - _returnStart > 500) exitWith {};
		_vehicleCoord = [getPos _pilot select 0, getPos _pilot select 1];
		_positionCoord = [_origin select 0, _origin select 1];
		if (_vehicleCoord distance _positionCoord < 300) exitWith {};
	};
};

//--- Failure cleanup: delete payload units before their groups. Released vehicles/infantry survive a lost return plane.
if (!_dropReady) then {
	{if (!isNull _x) then {deleteVehicle _x}} forEach _paratroopers;
	{if (!isNull _x) then {deleteVehicle _x}} forEach _cargoVehicles;
	if (!isNull _playerTeam) then {deleteGroup _playerTeam};
} else {
	_pendingCargo = _cargoVehicles - _releasedCargo;
	{if (!isNull _x) then {deleteVehicle _x}} forEach _pendingCargo;
};
if (!isNull _vehicle) then {
	{deleteVehicle _x} forEach crew _vehicle;
	deleteVehicle _vehicle;
};
if (!isNull _pilot) then {deleteVehicle _pilot};
if (!isNull _transportGroup) then {deleteGroup _transportGroup};
