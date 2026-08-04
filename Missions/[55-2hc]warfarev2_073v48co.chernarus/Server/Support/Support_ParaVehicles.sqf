Private['_args','_bd','_cargo','_cargoVehicle','_grp','_isAI','_pilot','_playerTeam','_positionCoord','_ran','_ranDir','_ranPos','_returnStart','_side','_sideID','_timeStart','_vehicle','_vehicleCoord','_dropReady'];

_args = _this;
_side = _args select 1;
_sideID = (_side) Call GetSideID;

_playerTeam = (_args select 3);
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
//--- AICOM PARAVEHI: AI-owned groups have no player leader, so keep the 500s transit cap but do not abort immediately.
_isAI = !(isPlayer (leader _playerTeam));
//--- failure-signalling r38: refund human ParaVehi fee (3500) on setup abort.
_refundParaVehiSetup = {
	Private ["_team","_cost","_leader","_reason","_msg","_cdKey"];
	_team = _this select 0;
	_cost = _this select 1;
	_reason = _this select 2;
	if (isNull _team || {_cost <= 0}) exitWith {};
	[_team, _cost] Call WFBE_CO_FNC_ChangeTeamFunds;
	_team setVariable ["wfbe_support_callin_next_ParaVehi", 0];
	_leader = leader _team;
	if (!isNull _leader && {isPlayer _leader}) then {
		_msg = Format ["Vehicle paradrop aborted (%1); $%2 refunded.", _reason, _cost];
		if (WF_A2_Vanilla) then {
			[getPlayerUID _leader, "HandleSpecial", ["support-callin-result", false, _msg]] Call WFBE_CO_FNC_SendToClients;
		} else {
			[_leader, "HandleSpecial", ["support-callin-result", false, _msg]] Call WFBE_CO_FNC_SendToClient;
		};
	};
	["WARNING", Format ["Support_ParaVehicles.sqf: setup abort refund $%1 (%2).", _cost, _reason]] Call WFBE_CO_FNC_LogContent;
};
_ran = round(random((count _ranPos)-1));
_grp = [_side, "paradrop"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _grp) exitWith {
	["WARNING", Format ["Support_ParaVehicles.sqf: [%1] paradrop group create failed.", str _side]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["PARAVEHI|SPAWNFAIL|side=%1|reason=group_create", _side];
	if (!_isAI) then {[_playerTeam, 3500, "group create failed"] Call _refundParaVehiSetup};
};
_vehicle = createVehicle [missionNamespace getVariable Format ["WFBE_%1PARAVEHI",str _side],(_ranPos select _ran), [], (_ranDir select _ran), "FLY"];
if (isNull _vehicle) exitWith {
	["WARNING", Format ["Support_ParaVehicles.sqf: [%1] transport create failed.", str _side]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["PARAVEHI|SPAWNFAIL|side=%1|reason=transport_create", _side];
	if (!isNull _grp) then {deleteGroup _grp};
	if (!_isAI) then {[_playerTeam, 3500, "transport create failed"] Call _refundParaVehiSetup};
};
[str _side,'VehiclesCreated',1] Call UpdateStatistics;
[str _side,'UnitsCreated',1] Call UpdateStatistics;
_pilot = [missionNamespace getVariable Format ["WFBE_%1PILOT",str _side],_grp,[100,12000,0],_sideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _pilot) exitWith {
	["WARNING", Format ["Support_ParaVehicles.sqf: [%1] pilot create failed; transport deleted.", str _side]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["PARAVEHI|SPAWNFAIL|side=%1|reason=pilot_create", _side];
	deleteVehicle _vehicle;
	if (!isNull _grp) then {deleteGroup _grp};
	if (!_isAI) then {[_playerTeam, 3500, "pilot create failed"] Call _refundParaVehiSetup};
};
_pilot moveInDriver _vehicle;
if (driver _vehicle != _pilot) exitWith {
	["WARNING", Format ["Support_ParaVehicles.sqf: [%1] pilot seat failed; transport torn down.", str _side]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["PARAVEHI|SPAWNFAIL|side=%1|reason=pilot_seat", _side];
	deleteVehicle _pilot;
	deleteVehicle _vehicle;
	if (!isNull _grp) then {deleteGroup _grp};
	if (!_isAI) then {[_playerTeam, 3500, "pilot seat failed"] Call _refundParaVehiSetup};
};
_pilot doMove (_args select 2);
_grp setBehaviour 'CARELESS';
_grp setCombatMode 'STEALTH';
_pilot disableAI 'AUTOTARGET';
_pilot disableAI 'TARGET';
[_grp,(_args select 2),"MOVE",10] Call AIMoveTo;
Call Compile Format ["_vehicle addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",_sideID];
_vehicle setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';",_sideID];
processInitCommands;
_vehicle flyInHeight (300 + random(75));
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];
_cargoVehicle = [missionNamespace getVariable Format ["WFBE_%1PARAVEHICARGO", _side], [0,0,50] ,_sideID, 0, false] Call WFBE_CO_FNC_CreateVehicle;
if (isNull _cargoVehicle) exitWith {
	["WARNING", Format ["Support_ParaVehicles.sqf: [%1] cargo vehicle create failed; transport torn down.", str _side]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["PARAVEHI|SPAWNFAIL|side=%1|reason=cargo_create", _side];
	{if (!isNull _x) then {deleteVehicle _x}} forEach [_pilot, _vehicle];
	if (!isNull _grp) then {deleteGroup _grp};
	if (!_isAI) then {[_playerTeam, 3500, "cargo create failed"] Call _refundParaVehiSetup};
};
_cargoVehicle attachTo [_vehicle,[0,0,-3]];

emptyQueu = emptyQueu + [_cargoVehicle];
[_cargoVehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;

_dropReady = false;
while {true} do {
	sleep 1;
	if (!alive _pilot || !alive _vehicle || isNull _vehicle || isNull _pilot || !alive _cargoVehicle) exitWith {};
	if ((!_isAI && {!(isPlayer (leader _playerTeam))}) || time - _timeStart > 500) exitWith {{deleteVehicle _x} forEach (_cargo+[_pilot,_vehicle,_cargoVehicle]); if (!isNull _grp) then {deleteGroup _grp};};
	_vehicleCoord = [getPos _pilot select 0,getpos _pilot select 1];
	_positionCoord = [(_args select 2) select 0,(_args select 2) select 1];
	if (_vehicleCoord distance _positionCoord < 100) exitWith {_dropReady = true};
};

if (_dropReady) then {
	detach _cargoVehicle;

	[_cargoVehicle,_side] Spawn {
	Private ['_chute','_dropStart','_side','_vehicle'];
	_vehicle = _this select 0;
	_side = _this select 1;
	sleep 2;
	if (!alive _vehicle) exitWith {};
	_chute = (missionNamespace getVariable Format['WFBE_%1PARACHUTE',str _side]) createVehicle [0,0,20];
	if (isNull _chute) then {
		["WARNING", Format ["Support_ParaVehicles.sqf: [%1] drop chute create failed; cargo free-falls.", str _side]] Call WFBE_CO_FNC_LogContent;
		diag_log format ["PARAVEHI|CHUTEFAIL|side=%1|reason=chute_create", _side];
	} else {
		_chute setPos [getPos _vehicle select 0, getPos _vehicle select 1, (getPos _vehicle select 2) - 11];
		_chute setDir (getDir _vehicle);
		_vehicle attachTo [_chute,[0,0,0]];
		_dropStart = time;
		while {!isNull _vehicle && alive _vehicle && ((getPos _vehicle select 2) >= 10) && ((time - _dropStart) < 120)} do {sleep 1};
		if (!isNull _vehicle) then {detach _vehicle};
		sleep 10;
		deleteVehicle _chute;
	};
	};

	[_grp,(_ranPos select _ran),"MOVE",10] Call AIMoveTo;

_returnStart = time;
while {true} do {
	sleep 1;
	if (!alive _pilot || !alive _vehicle || isNull _vehicle || isNull _pilot) exitWith {};
	if (time - _returnStart > 500) exitWith {};
	_vehicleCoord = [getPos _pilot select 0,getpos _pilot select 1];
	_positionCoord = [(_ranPos select _ran) select 0,(_ranPos select _ran) select 1];
	if (_vehicleCoord distance _positionCoord < 200) exitWith {};
	};
};
if (!_dropReady && {!isNull _cargoVehicle}) then {deleteVehicle _cargoVehicle};

deleteVehicle _pilot;
deleteVehicle _vehicle;
deleteGroup _grp;
