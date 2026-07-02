Private['_args','_bd','_cargo','_cargoVehicle','_destination','_grp','_pilot','_playerTeam','_positionCoord','_ran','_ranDir','_ranPos','_requester','_side','_sideID','_timeStart','_vehicle','_vehicleCoord'];

_args = _this;
if ((typeName _args != "ARRAY") || {count _args < 5}) exitWith {["WARNING", Format ["Support_ParaVehicles.sqf : rejected malformed payload [%1].", _args]] Call WFBE_CO_FNC_LogContent};
_side = _args select 1;
_destination = _args select 2;
_playerTeam = _args select 3;
_requester = _args select 4;
if !(_side in [west,east]) exitWith {["WARNING", Format ["Support_ParaVehicles.sqf : rejected invalid side [%1].", _side]] Call WFBE_CO_FNC_LogContent};
if ((typeName _destination != "ARRAY") || {count _destination < 2} || {typeName (_destination select 0) != "SCALAR"} || {typeName (_destination select 1) != "SCALAR"}) exitWith {["WARNING", Format ["Support_ParaVehicles.sqf : rejected malformed destination [%1].", _destination]] Call WFBE_CO_FNC_LogContent};
if ((typeName _playerTeam != "GROUP") || {typeName _requester != "OBJECT"} || {isNull _playerTeam} || {isNull _requester} || {!alive _requester} || {!isPlayer _requester} || {group _requester != _playerTeam} || {side _playerTeam != _side} || {leader _playerTeam != _requester}) exitWith {["WARNING", Format ["Support_ParaVehicles.sqf : rejected requester/team mismatch requester=%1 team=%2 side=%3.", _requester, _playerTeam, _side]] Call WFBE_CO_FNC_LogContent};
_sideID = (_side) Call GetSideID;

["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in a Vehicle Paradrop.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;
_ranPos = [];
_ranDir = [];

_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
if !(isNil '_bd') then {
	_ranPos = [
		[0+random(200),0+random(200),400+random(200)],
		[0+random(200),_bd-random(200),400+random(200)],
		[_bd-random(200),_bd-random(200),400+random(200)],
		[_bd-random(200),0+random(200),400+random(200)]
	];
	_ranDir = [45,145,225,315];
} else {
	_ranPos = [[0+random(200),0+random(200),400+random(200)],[15000+random(200),0+random(200),400+random(200)]];
	_ranDir = [45,315];
};

_timeStart = time;
_ran = round(random((count _ranPos)-1));
_grp = [_side, "paradrop"] Call WFBE_CO_FNC_CreateGroup;
_vehicle = createVehicle [missionNamespace getVariable Format ["WFBE_%1PARAVEHI",str _side],(_ranPos select _ran), [], (_ranDir select _ran), "FLY"];
[str _side,'VehiclesCreated',1] Call UpdateStatistics;
[str _side,'UnitsCreated',1] Call UpdateStatistics;
_pilot = [missionNamespace getVariable Format ["WFBE_%1PILOT",str _side],_grp,[100,12000,0],_sideID] Call WFBE_CO_FNC_CreateUnit;
_pilot moveInDriver _vehicle;
_pilot doMove _destination;
_grp setBehaviour 'CARELESS';
_grp setCombatMode 'STEALTH';
_pilot disableAI 'AUTOTARGET';
_pilot disableAI 'TARGET';
[_grp,_destination,"MOVE",10] Call AIMoveTo;
Call Compile Format ["_vehicle addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",_sideID];
_vehicle setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';",_sideID];
processInitCommands;
_vehicle flyInHeight (300 + random(75));
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];
_cargoVehicle = [missionNamespace getVariable Format ["WFBE_%1PARAVEHICARGO", _side], [0,0,50] ,_sideID, 0, false] Call WFBE_CO_FNC_CreateVehicle;
_cargoVehicle attachTo [_vehicle,[0,0,-3]];

emptyQueu = emptyQueu + [_cargoVehicle];
[_cargoVehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;

while {true} do {
	sleep 1;
	if (!alive _pilot || !alive _vehicle || isNull _vehicle || isNull _pilot || !alive _cargoVehicle) exitWith {};
	if (!(isPlayer (leader _playerTeam)) || time - _timeStart > 500) exitWith {{_x setDammage 1} forEach (_cargo+[_pilot,_vehicle,_cargoVehicle]);deleteGroup _grp};
	_vehicleCoord = [getPos _pilot select 0,getpos _pilot select 1];
	_positionCoord = [_destination select 0,_destination select 1];
	if (_vehicleCoord distance _positionCoord < 100) exitWith {};
};

detach _cargoVehicle;

[_cargoVehicle,_side] Spawn {
	Private ['_chute','_side','_vehicle'];
	_vehicle = _this select 0;
	_side = _this select 1;
	sleep 2;
	if (!alive _vehicle) exitWith {};
	_chute = (missionNamespace getVariable Format['WFBE_%1PARACHUTE',str _side]) createVehicle [0,0,20];
	_chute setPos [getPos _vehicle select 0, getPos _vehicle select 1, (getPos _vehicle select 2) - 11];
	_chute setDir (getDir _vehicle);
	_vehicle attachTo [_chute,[0,0,0]];
	waitUntil {getPos _vehicle select 2 < 10 || !alive _vehicle};
	detach _vehicle;
	sleep 10;
	deleteVehicle _chute;
};

[_grp,(_ranPos select _ran),"MOVE",10] Call AIMoveTo;

while {true} do {
	sleep 1;
	if (!alive _pilot || !alive _vehicle || isNull _vehicle || isNull _pilot) exitWith {};
	_vehicleCoord = [getPos _pilot select 0,getpos _pilot select 1];
	_positionCoord = [(_ranPos select _ran) select 0,(_ranPos select _ran) select 1];
	if (_vehicleCoord distance _positionCoord < 200) exitWith {};
};

deleteVehicle _pilot;
deleteVehicle _vehicle;
deleteGroup _grp;
