Private['_bd','_built','_built_inf','_currentLevel','_currentUpgrades','_delay','_destination','_dropPos','_greenlight','_grp','_index','_isAI','_lvlOverride','_paratroopers','_playerTeam','_ran','_ranDir','_ranPos','_returnStart','_side','_sideID','_starttime','_units','_vehicle','_vehicle_cargo','_vehicle_count','_vehicle_model','_vehicle_pilot','_vehicles','_transporter'];

_side = _this select 1;
_destination = _this select 2;
_playerTeam = _this select 3;
_sideID = _side Call GetSideID;
_starttime = time;

//--- AICOM PARATROOPS (claude-gaming 2026-06-29): the AI commander reuses this SAME player-support function to call a
//--- reinforcement drop (see AI_Commander_Paratroops.sqf). When the requesting team's leader is NOT a player, _isAI is
//--- true and we keep ONLY the hard 500s transit timeout (drop the "player left -> abort" leg) and skip the per-trooper
//--- client marker-send. The human-called path (leader is a player) is byte-for-byte unchanged: _isAI is false there.
_isAI = !(isPlayer (leader _playerTeam));

//--- failure-signalling r38: refund human call-in fee + notify when setup aborts before a live drop.
//--- Mirrors GuerHeliDrop receipt refund. Cost matches GUI Paratroopers fee / AuthorizeSupportCallin (8500).
//--- AI commander drops (_isAI) are not charged this fee - skip refund.
_refundParaSetup = {
	Private ["_team","_cost","_leader","_reason","_msg","_cdKey"];
	_team = _this select 0;
	_cost = _this select 1;
	_reason = _this select 2;
	if (isNull _team) exitWith {};
	if (_cost <= 0) exitWith {};
	[_team, _cost] Call WFBE_CO_FNC_ChangeTeamFunds;
	//--- Clear server-auth cooldown stamp so a setup fail does not lock the team out for the full interval.
	_cdKey = "wfbe_support_callin_next_Paratroops";
	_team setVariable [_cdKey, 0];
	_leader = leader _team;
	if (!isNull _leader && {isPlayer _leader}) then {
		_msg = Format ["Paratroop call aborted (%1); $%2 refunded.", _reason, _cost];
		if (WF_A2_Vanilla) then {
			[getPlayerUID _leader, "HandleSpecial", ["support-callin-result", false, _msg]] Call WFBE_CO_FNC_SendToClients;
		} else {
			[_leader, "HandleSpecial", ["support-callin-result", false, _msg]] Call WFBE_CO_FNC_SendToClient;
		};
	};
	["WARNING", Format["Support_Paratroopers.sqf: setup abort refund $%1 to team %2 (%3).", _cost, _team, _reason]] Call WFBE_CO_FNC_LogContent;
};

//--- r127 AICOM cooldown release: the AI paratroop worker stamps wfbe_aicom_para_last BEFORE dispatch
//--- (AI_Commander_Paratroops.sqf) and AI drops pay no call-in fee, so a setup abort only needs to hand
//--- the cooldown back - otherwise the side is locked out of AI para for the full interval with no delivery.
_releaseParaAICOMCooldown = {
	if (_isAI) then {
		private "_ptLogik";
		_ptLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNil "_ptLogik" && {!isNull _ptLogik}) then {_ptLogik setVariable ["wfbe_aicom_para_last", -1e9]};
		["WARNING", Format["Support_Paratroopers.sqf: [%1] AI paratroop setup abort - AICOM cooldown released.", _side]] Call WFBE_CO_FNC_LogContent;
	};
};

["INFORMATION", Format["Support_Paratroopers.sqf : [%1] Team [%2] has requested paratroopers (ai:%3).", _side, _playerTeam, _isAI]] Call WFBE_CO_FNC_LogContent;

//--- Determine a random spawn location.
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

//--- Get the units and the air vehicle, exit if nil.
_currentUpgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_currentLevel = _currentUpgrades select WFBE_UP_PARATROOPERS;
//--- Optional explicit level override (5th argument; W4 AIRBORNE ASSAULT passes 3): the roster keys only exist
//--- for levels 1-3, and the upgrade-derived level is 0 while the tier is unresearched - callers granting a free
//--- drop must pass the level here instead of relying on the side's researched tier.
if (count _this > 4) then {
	_lvlOverride = _this select 4;
	if (!isNil "_lvlOverride") then {if ((typeName _lvlOverride) == "SCALAR" && {_lvlOverride > 0}) then {_currentLevel = _lvlOverride}};
};
_units = missionNamespace getVariable Format ["WFBE_%1PARACHUTELEVEL%2", str _side, _currentLevel];
_vehicle_model = missionNamespace getVariable Format ["WFBE_%1PARACARGO", str _side];

if (isNil '_units' || isNil '_vehicle_model') exitWith {
	["ERROR", Format["Support_Paratroopers.sqf : [%1] Paratrooping vehicle or units are not defined (level %2).", _side, _currentLevel]] Call WFBE_CO_FNC_LogContent;
	if (!_isAI) then {[_playerTeam, 8500, Format ["undefined roster/model L%1", _currentLevel]] Call _refundParaSetup};
	Call _releaseParaAICOMCooldown;
};

//--- Determine how many vehicles do we need.
_vehicle_cargo = getNumber(configFile >> 'CfgVehicles' >> _vehicle_model >> 'transportSoldier');
if (_vehicle_cargo == 0) exitWith {
	["ERROR", Format["Support_Paratroopers.sqf : [%1] Paratrooping vehicle [%2] has no cargo capacity.", _side, _vehicle_model]] Call WFBE_CO_FNC_LogContent;
	if (!_isAI) then {[_playerTeam, 8500, Format ["zero cargo %1", _vehicle_model]] Call _refundParaSetup};
	Call _releaseParaAICOMCooldown;
};
_vehicle_count = ceil((count _units) / _vehicle_cargo);

//--- Create the vehicles.
_vehicles = [];
_vehicle_pilot = missionNamespace getVariable Format ["WFBE_%1PILOT",str _side];
_ran = floor(random count _ranPos);
_grp = [_side, "paradrop"] Call WFBE_CO_FNC_CreateGroup;
//--- r89 fail-clean (bughunt group-cap/budget): at the 144/side group cap the wrapper
//--- returns grpNull. Continuing would run Common_CreateUnit's fresh-"misc"-group fallbacks
//--- (one leaked group per pilot), set behaviour/waypoints on grpNull, and fly the
//--- transports pilotless. Abort before the spawn loop instead; nothing exists yet to clean up.
if (isNull _grp) exitWith {
	["ERROR", Format["Support_Paratroopers.sqf : [%1] paratroop group create failed (side group cap); aborting drop.", _side]] Call WFBE_CO_FNC_LogContent;
	if (!_isAI) then {[_playerTeam, 8500, "group create failed (side cap)"] Call _refundParaSetup};
};
_built = 0;

for '_i' from 1 to _vehicle_count do {
	//--- Spawn the vehicle.
	_vehicle = createVehicle [missionNamespace getVariable Format ["WFBE_%1PARACARGO",str _side],(_ranPos select _ran), [], (_ranDir select _ran), "FLY"];
	_vehicle addEventHandler ['killed', Format["[_this select 0, _this select 1, %1] Spawn WFBE_CO_FNC_OnUnitKilled",_sideID]];
	_vehicle setVehicleInit Format["[this, %1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];
	[_vehicles, _vehicle] Call WFBE_CO_FNC_ArrayPush;
	
	//--- Spawn the pilot.
	_pilot = [_vehicle_pilot, _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
	_pilot moveInDriver _vehicle;
	_pilot doMove _destination;
	_grp setBehaviour 'CARELESS';
	_grp setCombatMode 'STEALTH';
	{_pilot disableAI _x} forEach ["AUTOTARGET","TARGET"];
	_built = _built + 1;
	
	_vehicle flyInHeight (300 + random 15);
	_vehicle lockDriver true;
};

[str _side, 'VehiclesCreated', _built] Call UpdateStatistics;

//--- Global Init.
processInitCommands;

//--- failure-signalling r38: empty transport list after create loop (engine create failed for all slots).
_vehicles = _vehicles - [objNull];
if ((count _vehicles) == 0) exitWith {
	["ERROR", Format["Support_Paratroopers.sqf : [%1] no transport survived create; aborting.", _side]] Call WFBE_CO_FNC_LogContent;
	if (!isNull _grp) then {deleteGroup _grp};
	if (!_isAI) then {[_playerTeam, 8500, "transport create failed"] Call _refundParaSetup};
	Call _releaseParaAICOMCooldown;
};

//--- Create the units.
_built_inf = 0;
_index = 0;
_vehicle = _vehicles select _index;
_paratroopers = [];
{
	//--- Spawn the unit.
	//_unit = [_x, _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
	_unit = [_x, _playerTeam, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;	
	_unit moveInCargo _vehicle;
	_built_inf = _built_inf + 1;
	[_paratroopers, _unit] Call WFBE_CO_FNC_ArrayPush;
	//--- If the unit amount exceed the cargo cap, swap to the next vehicle then.
	if (_built_inf >= _vehicle_cargo && {_index < ((count _vehicles) - 1)}) then {_built = _built + _built_inf; _built_inf = 0; _index = _index + 1; _vehicle = _vehicles select _index};
} forEach _units;

[str _side,'UnitsCreated', _built] Call UpdateStatistics;

//--- Tell the group to move.
[_grp, _destination, "MOVE", 10] Call AIMoveTo;

//--- Loop until death or arrival.
_greenlight = false;
while {true} do {
	sleep 1;
	
	if (({alive _x} count _vehicles) == 0) exitWith {};//--- Vehicle destruction.
	if (({alive driver _x} count _vehicles) == 0) exitWith {};//--- Pilots are dead.
	if ((!_isAI && {!(isPlayer (leader _playerTeam))}) || time - _starttime > 500) exitWith {};//--- Timeout out AI Controlled. (AICOM: an AI drop is never aborted for "leader not a player"; only the 500s hard cap applies.)
	
	_vehicleCoord = [(getPos vehicle (leader _grp)) select 0, (getPos vehicle (leader _grp)) select 1];
	_positionCoord = [_destination select 0, _destination select 1];
	if (_vehicleCoord distance _positionCoord < 300) exitWith {_greenlight = true};//--- Destination reached.
};

//--- Units are ready to bail!
if (_greenlight) then {
	_delay = if (_vehicle_model isKindOf "Plane") then {0.35} else {0.85};
	
	{
		_vehicle = _x;
		{
			_x action ["EJECT", _vehicle];
			sleep _delay;
			//--- AICOM PARATROOPS: only ping a real player client's map with the drop marker. An AI drop has no
			//--- requesting client, so skip the SendToClient (sending to an AI body would be a wasted no-op).
			if (!_isAI) then {[leader _playerTeam, "HandleParatrooperMarkerCreation", [_x, _sideID]] Call WFBE_CO_FNC_SendToClient};
		} forEach ((crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle]);
	} forEach _vehicles;
	
	//--- AICOM PARATROOPS post-drop orders: an AI-commander-called drop hands
	//--- _playerTeam a FRESH group with no player leader (AI_Commander_Paratroops.sqf) - the ejected
	//--- stick previously got no waypoint/doMove/patrol at all and stood idle at the drop zone forever.
	//--- A human-called drop already has the player commanding _playerTeam, so only the AI path needs this.
	if (_isAI && {count units _playerTeam > 0}) then {
		//--- r70 tasking: re-home stick to the ORDERED objective (town centre), not the parachuting
		//--- leader mid-air pos (prior: AIPatrol around fall position, never the reinforce target).
		_dropPos = _destination;
		if (isNil "_dropPos" || {typeName _dropPos != "ARRAY"} || {count _dropPos < 2}) then {
			_dropPos = getPos (leader _playerTeam);
		};
		//--- AIPatrol resets behaviour to AWARE/YELLOW as its first act, so it MUST run BEFORE the engage
		//--- posture is set or COMBAT/RED gets clobbered (same idiom as Server_GuerAirDef.sqf).
		[_playerTeam, _dropPos, 200] Call AIPatrol;
		_playerTeam setBehaviour "COMBAT";
		_playerTeam setCombatMode "RED";
	};

	//--- Once done, the air units can fly back to their source.
	[_grp, (_ranPos select _ran), "MOVE", 10] Call AIMoveTo;
	
	//--- Loop until death or arrival.
	_returnStart = time;
	while {true} do {
		sleep 1;
		
		if (({alive _x} count _vehicles) == 0) exitWith {};//--- Vehicle destruction.
		if (({alive driver _x} count _vehicles) == 0) exitWith {};//--- Pilots are dead.
		if (time - _returnStart > 500) exitWith {};//--- Return leg timeout.
		
		_vehicleCoord = [(getPos vehicle (leader _grp)) select 0, (getPos vehicle (leader _grp)) select 1];
		_positionCoord = [(_ranPos select _ran) select 0, (_ranPos select _ran) select 1];
		if (_vehicleCoord distance _positionCoord < 300) exitWith {};//--- Destination reached.
	};
} else {
	//--- Everything failed, remove the paratroopers.
	{deleteVehicle _x} forEach _paratroopers;
};

//--- In any case, cleanup the transporters.
{
	_transporter = _x;
	{deleteVehicle _x; sleep 0} forEach crew _transporter;//--- Remove the crew. //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below; already-scheduled).
	deleteVehicle _transporter;//--- Remove the vehicle.
} forEach _vehicles;

//---- Clear the group.
deleteGroup _grp;
