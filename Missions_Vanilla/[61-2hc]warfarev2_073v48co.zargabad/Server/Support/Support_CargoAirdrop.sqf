/*
    AICOM CARGO AIRDROP Stage A + Stage B.
    Parameter: _this = ["CargoAirdrop", side, destination, infantryGroup, spawnEscort(optional, Stage B)].

    This is an AI-only composition: one existing side-configured paratroop
    transport plane, its infantry stick (optionally padded with extra tiered
    troops, Stage B), and up to two side-configured para-vehicles. The vehicle
    attach/detach/chute block follows the shipping Support_ParaVehicles.sqf
    mechanism. The vehicle releases are staggered by three seconds, derived
    from Support_ParaAmmo.sqf's multi-payload cadence.

    Stage B (all gated, default OFF - see Init_CommonConstants.sqf):
      - WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES: mount-on-landing crew for
        each delivered vehicle once it has demonstrably settled (near-ground,
        near-zero vertical speed) - never seats crew into a vehicle still
        under canopy, so a lost settle-check just leaves that hull empty
        (Stage A behaviour), instead of ever risking a mid-air crew loss.
      - WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA: extra troops cycling the
        same tiered roster classes, clamped to the plane's remaining
        transportSoldier capacity.
      - spawnEscort (5th call arg, decided + costed atomically by
        AI_Commander_CargoAirdrop.sqf before dispatch): one fixed-wing jet in
        its own group, so its COMBAT/RED posture cannot overwrite the cargo
        transport's CARELESS/BLUE flight posture.
*/

private ["_args","_bd","_cargoClass","_cargoVehicle","_cargoVehicles","_chuteClass","_currentLevel","_currentUpgrades","_destination","_dropReady","_i","_isAI","_offset","_origin","_paratroopers","_pilot","_pilotClass","_planeClass","_playerTeam","_ran","_ranDir","_ranPos","_releasedCargo","_returnStart","_side","_sideID","_starttime","_units","_unit","_vehicle","_vehicleCargo","_vehicleCount","_vehicleIndex","_vehicleCoord","_positionCoord","_builtInf","_transportGroup","_pendingCargo","_delay","_spawnEscort","_crewVehicles","_paratroopExtra","_extraCount","_escortGroup","_escortJet","_escortPilot","_escortGunner","_escortClasses","_escortAirList","_escortCandidates","_escortClass","_escortOrigin"];

_args = _this;
_side = _args select 1;
_destination = _args select 2;
_playerTeam = _args select 3;
_spawnEscort = if (count _args > 4) then {_args select 4} else {false};
if (typeName _spawnEscort != "BOOL") then {_spawnEscort = false};
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
_crewVehicles = (missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES", 0]) > 0;
_paratroopExtra = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA", 0];
if (typeName _paratroopExtra != "SCALAR") then {_paratroopExtra = 0};
if (_paratroopExtra < 0) then {_paratroopExtra = 0};

if (isNil "_units" || {isNil "_planeClass"} || {isNil "_pilotClass"} || {(_vehicleCount > 0) && {isNil "_cargoClass"}} || {(_vehicleCount > 0) && {isNil "_chuteClass"}}) exitWith {
	["ERROR", Format ["Support_CargoAirdrop.sqf: [%1] required cargo configuration is missing.", str _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _units != "ARRAY") exitWith {};
_vehicleCargo = getNumber(configFile >> "CfgVehicles" >> _planeClass >> "transportSoldier");
if (_vehicleCargo <= 0) exitWith {
	["ERROR", Format ["Support_CargoAirdrop.sqf: [%1] cargo plane [%2] cannot carry the infantry roster (%3/%4).", str _side, _planeClass, count _units, _vehicleCargo]] Call WFBE_CO_FNC_LogContent;
};
//--- Stage B: extra paratroopers beyond the tiered stick, cycling the SAME tiered classes (no new
//--- config surface). Clamped to whatever headroom the plane's own transportSoldier capacity leaves -
//--- this never aborts a call solely because the extra-troop setting is too generous.
if (_paratroopExtra > 0 && {count _units > 0}) then {
	_extraCount = _vehicleCargo - count _units;
	if (_extraCount > _paratroopExtra) then {_extraCount = _paratroopExtra};
	if (_extraCount > 0) then {
		for "_i" from 1 to _extraCount do {
			_units set [count _units, (_units select ((_i - 1) mod (count _units)))];
		};
	};
};
if (_vehicleCargo < count _units) exitWith {
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
_transportGroup setCombatMode "BLUE";
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

//--- Stage B fighter escort: single fixed-wing jet in a SEPARATE group. Autotarget is left ON (the
//--- transport pilot two blocks above explicitly disables it; the escort never gets that call) so it
//--- actually fights without changing the transport's CARELESS/BLUE posture. Side-safe: only
//--- WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES entries that are ALSO in this side's own registered
//--- WFBE_<SIDE>AIRCRAFTUNITS roster are eligible (same idiom AI_Commander_AirResp.sqf uses), so the
//--- pick is never hardcoded to one faction. _spawnEscort was already decided (and its cost already
//--- debited) atomically by AI_Commander_CargoAirdrop.sqf before this worker was dispatched - this
//--- block only ever ATTEMPTS the spawn; any failure here just means no escort this call, the cargo
//--- delivery itself is unaffected.
_escortJet = objNull;
_escortPilot = objNull;
_escortGunner = objNull;
_escortGroup = grpNull;
if (_spawnEscort) then {
	_escortAirList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", str _side], []];
	_escortClasses = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES", []];
	_escortCandidates = [];
	{ if (_x in _escortClasses) then {_escortCandidates set [count _escortCandidates, _x]} } forEach _escortAirList;
	if (count _escortCandidates > 0) then {
		_escortClass = _escortCandidates select floor (random count _escortCandidates);
		//--- Offset spawn point so the escort never materialises exactly on top of the transport plane.
		_escortOrigin = [(_origin select 0) + 100, (_origin select 1) + 100, _origin select 2];
		_escortJet = createVehicle [_escortClass, _escortOrigin, [], (_ranDir select _ran), "FLY"];
		if (!isNull _escortJet) then {
			_escortGroup = [_side, "aicom_cargo_escort"] Call WFBE_CO_FNC_CreateGroup;
			if (!isNull _escortGroup) then {
				_escortPilot = [_pilotClass, _escortGroup, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
			};
			if (!isNull _escortPilot) then {
				_escortPilot moveInDriver _escortJet;
				_escortGroup setBehaviour "COMBAT";
				_escortGroup setCombatMode "RED";
				_escortPilot doMove _destination;
				if ((missionNamespace getVariable ["WFBE_C_AIR_ATTACK_GUNNER", 0]) > 0 && {(_escortJet emptyPositions "gunner") > 0}) then {
					_escortGunner = [_pilotClass, _escortGroup, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
					if (!isNull _escortGunner) then {_escortGunner moveInGunner _escortJet};
				};
				_escortJet flyInHeight (300 + random(75));
				Call Compile Format ["_escortJet addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]", _sideID];
				_escortJet setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];
				processInitCommands;
				["INFORMATION", Format ["Support_CargoAirdrop.sqf: [%1] cargo drop escort [%2] launched.", str _side, _escortClass]] Call WFBE_CO_FNC_LogContent;
			} else {
				deleteVehicle _escortJet;
				_escortJet = objNull;
				if (!isNull _escortGroup) then {deleteGroup _escortGroup};
			};
		};
	} else {
		["INFORMATION", Format ["Support_CargoAirdrop.sqf: [%1] cargo drop escort requested but no configured jet class is registered on this side's aircraft roster.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
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
				[_x, _side, _chuteClass, _crewVehicles, _cargoClass, _playerTeam] Spawn {
					private ["_cargo","_chute","_chuteClass","_dropStart","_side","_crewVehicles","_cargoClass","_team","_settled","_settleTries","_crewClass","_driver","_gunner","_commander","_sideID2"];
					_cargo = _this select 0;
					_side = _this select 1;
					_chuteClass = _this select 2;
					_crewVehicles = _this select 3;
					_cargoClass = _this select 4;
					_team = _this select 5;
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
					//--- Stage B mount-on-landing: never crew a vehicle that has not demonstrably settled. Poll
					//--- (bounded) until it is near-ground with near-zero vertical speed; if it never settles,
					//--- leave it EMPTY (Stage A behaviour) rather than risk seating crew mid-air/mid-descent.
					if (_crewVehicles && {!isNull _cargo} && {alive _cargo}) then {
						_settled = false;
						_settleTries = 0;
						while {!_settled && {_settleTries < 15} && {!isNull _cargo} && {alive _cargo}} do {
							if (((getPosATL _cargo) select 2) < 2 && {abs ((velocity _cargo) select 2) < 0.5}) then {
								_settled = true;
							} else {
								sleep 1;
								_settleTries = _settleTries + 1;
							};
						};
						if (_settled && {!isNull _cargo} && {alive _cargo} && {!isNull _team}) then {
							_sideID2 = _side Call GetSideID;
							_crewClass = missionNamespace getVariable Format ["WFBE_%1SOLDIER", str _side];
							if (_cargo isKindOf "Tank") then {_crewClass = missionNamespace getVariable Format ["WFBE_%1CREW", str _side]};
							if (!isNil "_crewClass") then {
								if ((_cargo emptyPositions "driver") > 0) then {
									_driver = [_crewClass, _team, [100,12000,0], _sideID2] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _driver) then {_driver moveInDriver _cargo};
								};
								if ((_cargo emptyPositions "gunner") > 0) then {
									_gunner = [_crewClass, _team, [100,12000,0], _sideID2] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _gunner) then {_gunner moveInGunner _cargo};
								};
								if ((_cargo emptyPositions "commander") > 0) then {
									_commander = [_crewClass, _team, [100,12000,0], _sideID2] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _commander) then {_commander moveInCommander _cargo};
								};
								["INFORMATION", Format ["Support_CargoAirdrop.sqf: [%1] cargo drop mounted crew into landed vehicle [%2].", str _side, typeOf _cargo]] Call WFBE_CO_FNC_LogContent;
							};
						} else {
							["INFORMATION", Format ["Support_CargoAirdrop.sqf: [%1] cargo drop vehicle [%2] never settled; delivered empty (Stage A behaviour).", str _side, typeOf _cargo]] Call WFBE_CO_FNC_LogContent;
						};
					};
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
//--- Stage B escort cleanup: members deleted BEFORE the shared group (deleteGroup silently no-ops
//--- on a non-empty group - the same trap already fixed in Support_ParaVehicles.sqf).
if (!isNull _escortJet) then {
	{deleteVehicle _x} forEach crew _escortJet;
	deleteVehicle _escortJet;
};
if (!isNull _escortPilot) then {deleteVehicle _escortPilot};
if (!isNull _escortGunner) then {deleteVehicle _escortGunner};
if (!isNull _escortGroup) then {deleteGroup _escortGroup};
if (!isNull _transportGroup) then {deleteGroup _transportGroup};
