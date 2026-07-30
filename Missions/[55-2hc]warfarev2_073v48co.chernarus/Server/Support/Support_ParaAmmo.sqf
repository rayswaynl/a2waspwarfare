Private['_args','_bd','_cargo','_grp','_pilot','_playerTeam','_positionCoord','_ran','_ranDir','_ranPos','_returnStart','_side','_sideID','_timeStart','_vehicle','_vehicleCoord','_dropReady'];

_args = _this;
_side = _args select 1;
_sideID = _side Call GetSideID;

_playerTeam = (_args select 3);
[\"INFORMATION\", Format [\"Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in an Ammo Paradrop.\", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;
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
//--- Uniform index draw (parity with Support_GuerHeliDrop / floor-random convention).
_ran = floor (random (count _ranPos));
_grp = [_side, \"paradrop\"] Call WFBE_CO_FNC_CreateGroup;
//--- createVehicle/crew fail-clean (r34): group/hull/pilot can each return null under side group
//--- saturation or bad class. Previously: stats always +1, moveInDriver on null pilot, then
//--- pilotless transport flew until timeout and teardown deleteVehicle'd possibly-null refs.
if (isNull _grp) exitWith {
	[\"ERROR\", Format [\"Support_ParaAmmo.sqf: [%1] paradrop group create failed — abort ammo paradrop.\", str _side]] Call WFBE_CO_FNC_LogContent;
};
_vehicle = createVehicle [missionNamespace getVariable Format [\"WFBE_%1PARAVEHI\",str _side],(_ranPos select _ran), [], (_ranDir select _ran), \"FLY\"];
if (isNull _vehicle) exitWith {
	deleteGroup _grp;
	[\"ERROR\", Format [\"Support_ParaAmmo.sqf: [%1] transport createVehicle failed — abort ammo paradrop.\", str _side]] Call WFBE_CO_FNC_LogContent;
};
_pilot = [missionNamespace getVariable Format [\"WFBE_%1PILOT\",str _side],_grp,[100,12000,0],_sideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _pilot) exitWith {
	deleteVehicle _vehicle;
	deleteGroup _grp;
	[\"ERROR\", Format [\"Support_ParaAmmo.sqf: [%1] pilot CreateUnit failed — abort ammo paradrop.\", str _side]] Call WFBE_CO_FNC_LogContent;
};
_pilot moveInDriver _vehicle;
if (driver _vehicle != _pilot) exitWith {
	deleteVehicle _pilot;
	deleteVehicle _vehicle;
	deleteGroup _grp;
	[\"ERROR\", Format [\"Support_ParaAmmo.sqf: [%1] pilot moveInDriver failed — abort ammo paradrop.\", str _side]] Call WFBE_CO_FNC_LogContent;
};
//--- Stats only after a seated pilot exists (no phantom VehiclesCreated/UnitsCreated).
[str _side,'VehiclesCreated',1] Call UpdateStatistics;
[str _side,'UnitsCreated',1] Call UpdateStatistics;
_grp setBehaviour 'CARELESS';
_grp setCombatMode 'STEALTH';
_pilot disableAI 'AUTOTARGET';
_pilot disableAI 'TARGET';
[_grp,(_args select 2),\"MOVE\",10] Call AIMoveTo;
Call Compile Format [\"_vehicle addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]\",_sideID];
_vehicle setVehicleInit Format[\"[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';\",_sideID];
processInitCommands;
_vehicle flyInHeight (200 + random(20));
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];

_dropReady = false;
while {true} do {
	sleep 1;
	if (!alive _pilot || !alive _vehicle || isNull _vehicle || isNull _pilot) exitWith {};
	//--- Abort: player left or hard transit cap. Null-safe force-kill (setDammage on null is crash-class).
	if (!(isPlayer (leader _playerTeam)) || time - _timeStart > 500) exitWith {
		{
			if (!isNull _x) then {_x setDammage 1};
		} forEach (_cargo + [_pilot, _vehicle]);
		if (!isNull _grp) then {deleteGroup _grp};
	};
	_vehicleCoord = [getPos _pilot select 0,getpos _pilot select 1];
	_positionCoord = [(_args select 2) select 0,(_args select 2) select 1];
	if (_vehicleCoord distance _positionCoord < 100) exitWith {_dropReady = true};
};

if (_dropReady) then {
	[_vehicle,_side,_sideID] Spawn {
	Private ['_ammo','_ammos','_chopper','_chute','_side','_sideID'];
	_chopper = _this select 0;
	_side = _this select 1;
	_sideID = _this select 2;
	
	_ammos = missionNamespace getVariable Format[\"WFBE_%1PARAAMMO\",_side];
	if (typeName _ammos != 'ARRAY') exitWith {[\"WARNING\", Format [\"Server_HandleSpecial.sqf: Expected array, given [%1] for ammunitions\", typeName _ammos]] Call WFBE_CO_FNC_LogContent};
	
	{
		//--- Crate create can return null under bad classname / saturation.
		_ammo = _x createVehicle [0,0,0];
		if (isNull _ammo) then {
			[\"WARNING\", Format [\"Support_ParaAmmo.sqf: ammo crate createVehicle failed for class [%1].\", _x]] Call WFBE_CO_FNC_LogContent;
		} else {
		
		[_chopper,_ammo,_side,_sideID] Spawn {
			Private ['_ammo','_chopper','_chute','_dropStart','_pos','_side','_sideID','_type'];
			_chopper = _this select 0;
			_ammo = _this select 1;
			_side = _this select 2;
			_sideID = _this select 3;
			//--- TOCTOU: dropReady was true earlier; the transport may already be deleted/dead by the
			//--- time this spawn runs. getPos/getDir on a null hull is native-crash class.
			if (isNull _chopper || {!alive _chopper}) exitWith {if (!isNull _ammo) then {deleteVehicle _ammo}};
			
			_chute = (missionNamespace getVariable Format['WFBE_%1PARACHUTE',str _side]) createVehicle [0,0,20];
			if (isNull _chute) exitWith {
				if (!isNull _ammo) then {deleteVehicle _ammo};
				[\"WARNING\", \"Support_ParaAmmo.sqf: parachute createVehicle failed — crate discarded.\"] Call WFBE_CO_FNC_LogContent;
			};
			_chute setPos [getPos _chopper select 0, getPos _chopper select 1, (getPos _chopper select 2) - 11];
			_chute setDir (getDir _chopper);
			
			_ammo setPos getPos _chute;
			_ammo attachTo [_chute,[0,0,0]];
			_dropStart = time;
			while {!isNull _ammo && ((getPos _ammo select 2) >= 3) && ((time - _dropStart) < 120)} do {sleep 1};
			if (isNull _ammo) exitWith {if (!isNull _chute) then {deleteVehicle _chute}};
			detach _ammo;
			
			_type = typeOf _ammo;
			_pos = getPos _ammo;
			deleteVehicle _ammo;
			_ammo = _type createVehicle _pos;
			if (isNull _ammo) exitWith {
				if (!isNull _chute) then {deleteVehicle _chute};
				[\"WARNING\", Format [\"Support_ParaAmmo.sqf: grounded ammo recreate failed for [%1].\", _type]] Call WFBE_CO_FNC_LogContent;
			};
			
			Call Compile Format [\"_ammo addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]\",_sideID];
			
			sleep 5;
			
			if (!isNull _chute) then {deleteVehicle _chute};
		};
		
		}; //--- else ammo create ok
		sleep 0.8;
	} forEach _ammos;
	};

	[_grp,(_ranPos select _ran),\"MOVE\",10] Call AIMoveTo;

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

//--- Null-safe teardown (pilot/vehicle may already be engine-deleted on death paths).
if (!isNull _pilot) then {deleteVehicle _pilot};
if (!isNull _vehicle) then {deleteVehicle _vehicle};
if (!isNull _grp) then {deleteGroup _grp};
