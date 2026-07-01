// Marty: Crew placement uses explicit private locals because town AI may be created on server, client, or headless client.
Private ['_canCreate','_commander','_crewRole','_crewUnit','_crews','_driver','_firstDone','_global','_groupCountCiv','_groupCountEast','_groupCountGuer','_groupCountLogic','_groupCountSide','_groupCountWest','_groupCountUnknown','_groupMachine','_groupSide','_gunner','_list','_lockVehicles','_perfCrew','_perfInfantry','_perfScope','_perfSkipped','_perfStart','_perfVehicles','_position','_probability','_side','_sideID','_team','_type','_unit','_units','_vehicle','_vehicleCrews','_vehicles','_rearmor','_warnKey','_warnLast'];

_list = _this select 0;
_position = _this select 1;
_side = _this select 2;
_sideID = (_side) Call GetSideID;
_lockVehicles = _this select 3;
_team = _this select 4;
_global = if (count _this > 5) then {_this select 5} else {true};
_probability = if (count _this > 6) then {_this select 6} else {-1};
_units = [];
_vehicles = [];
_crews = [];
_firstDone = false;
// Marty: Performance Audit counters for team template creation and global init propagation.
_perfStart = diag_tickTime;
_perfInfantry = 0;
_perfVehicles = 0;
_perfCrew = 0;
_perfSkipped = 0;

if (typeName _list != "ARRAY") then { _list = [_list] };

if (isNull _team) then {_team = [_side, "misc"] Call WFBE_CO_FNC_CreateGroup}; //--- Create a group if none are given as a parameter.

// Marty: createGroup can return grpNull when the per-side group limit is reached; fail the whole template before creating empty vehicles.
if (isNull _team) exitWith {
	_perfSkipped = count _list;
	// Marty: Count groups on this machine when Arma refuses to create a group, to diagnose side group saturation.
	_groupCountWest = 0;
	_groupCountEast = 0;
	_groupCountGuer = 0;
	_groupCountCiv = 0;
	_groupCountLogic = 0;
	_groupCountUnknown = 0;
	{
		_groupSide = side _x;
		switch (_groupSide) do {
			case west: {_groupCountWest = _groupCountWest + 1};
			case east: {_groupCountEast = _groupCountEast + 1};
			case resistance: {_groupCountGuer = _groupCountGuer + 1};
			case civilian: {_groupCountCiv = _groupCountCiv + 1};
			case sideLogic: {_groupCountLogic = _groupCountLogic + 1};
			default {_groupCountUnknown = _groupCountUnknown + 1};
		};
	} forEach allGroups;
	_groupCountSide = switch (_side) do {
		case west: {_groupCountWest};
		case east: {_groupCountEast};
		case resistance: {_groupCountGuer};
		case civilian: {_groupCountCiv};
		case sideLogic: {_groupCountLogic};
		default {_groupCountUnknown};
	};
	_groupMachine = if (isServer) then {"SERVER"} else {if (hasInterface) then {"CLIENT"} else {"HC"}};
	_warnKey = "wfbe_createteam_null_warn_" + str _sideID + "_" + _groupMachine;
	_warnLast = missionNamespace getVariable [_warnKey, -9999];
	if ((time - _warnLast) >= 300) then {
		missionNamespace setVariable [_warnKey, time];
		["WARNING", Format ["TOWN_GROUP_COUNT create_failed machine:%1 side:%2 sideGroups:%3 total:%4 west:%5 east:%6 guer:%7 civ:%8 logic:%9 unknown:%10", _groupMachine, _side, _groupCountSide, count allGroups, _groupCountWest, _groupCountEast, _groupCountGuer, _groupCountCiv, _groupCountLogic, _groupCountUnknown]] Call WFBE_CO_FNC_LogContent;
		["WARNING", Format ["Common_CreateTeam.sqf: Team template for side [%1] at [%2] was skipped because no valid group could be created. Templates:%3", _side, _position, count _list]] Call WFBE_CO_FNC_LogContent;
	};
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
			["createteam", diag_tickTime - _perfStart, Format["side:%1;global:%2;templates:%3;infantry:0;vehicles:0;crews:0;skipped:%4;groupNull:true", _sideID, _global, count _list, _perfSkipped], _perfScope] Call PerformanceAudit_Record;
		};
	};
	[[], [], _team, []]
};

_rearmor = {
   				_ammo = _this select 4;
   				_result = 0;

   				switch (_ammo) do {
				    case "B_20mm_AA" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
					case "B_23mm_AA" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HE" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HEI" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
					case "B_30mm_AA" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
					case "B_30mm_HE" :{_dam=_this select 2; _p=20; _result=(_dam/100)*(100-_p);};
     				default {_result = _this select 2;};
    			};
   				_result
  			};

//--- Create.
{
	_canCreate = true;
	if (_probability != -1) then {
		if (random 100 > _probability && _firstDone) then {_canCreate = false};
		_firstDone = true;
	};

	if (_canCreate) then {
		//--- claude-gaming 2026-06-14 (bug: "Cannot create non-ai vehicle Squad_2,"/"Squad_3,"):
		//--- Guard the create dispatch against any roster token that is NOT a real CfgVehicles class.
		//--- A leaked group-template KEY (e.g. "Squad_2"/"Squad_3", the suffixed WFBE_<side>_GROUPS_*
		//--- lookup keys) is not a class, so `isKindOf 'Man'` is false and it would fall through to
		//--- createVehicle -> the engine "Cannot create non-ai vehicle" RPT spam (7x per town activation).
		//--- isClass keeps real classnames untouched (gameplay-transparent) and turns a hard engine
		//--- error into one explicit WARNING. A2-safe: isClass + config path are 1.64 binaries.
		if !(isClass (configFile >> "CfgVehicles" >> _x)) then {
			_perfSkipped = _perfSkipped + 1;
			["WARNING", Format ["Common_CreateTeam.sqf: roster token [%1] for side [%2] is not a CfgVehicles class (leaked group-template key?); skipped to avoid createVehicle error.", _x, _side]] Call WFBE_CO_FNC_LogContent;
		} else {
		if (_x isKindOf 'Man') then {
			// Marty: Forward the team global-init flag so town AI infantry can skip client marker/action setup.
			_unit = [_x,_team,_position,_sideID,_global] Call WFBE_CO_FNC_CreateUnit;
			// Marty: Count and track only units the engine actually created.
			if (isNull _unit) then {
				_perfSkipped = _perfSkipped + 1;
			} else {
				_units = _units + [_unit];
				_perfInfantry = _perfInfantry + 1;
			};
		} else {
			_vehicle = [_x, _position, _sideID, 0, _lockVehicles, true, _global, "FORM"] Call WFBE_CO_FNC_CreateVehicle;
			call {
				// Marty: If the vehicle itself failed, skip this template entry without attempting crew work.
				if (isNull _vehicle) exitWith {
					_perfSkipped = _perfSkipped + 1;
				};

				_type = if (_vehicle isKindOf 'Man') then {missionNamespace getVariable Format ['WFBE_%1SOLDIER',_side]} else {if (_vehicle isKindOf 'Air') then {missionNamespace getVariable Format ['WFBE_%1PILOT',_side]} else {missionNamespace getVariable Format ['WFBE_%1CREW',_side]}};
				_vehicleCrews = [];
				// Marty: Assign crew roles before moveIn so locked or delegated town vehicles keep their crews mounted.
				_vehicle allowCrewInImmobile true;
				_team addVehicle _vehicle;
				{
					_crewRole = _x;
					call {
						if ((_vehicle emptyPositions _crewRole) <= 0) exitWith {};
						_crewUnit = [_type,_team,_position,_sideID,_global] Call WFBE_CO_FNC_CreateUnit;
						if (isNull _crewUnit) exitWith {};
						[_crewUnit] allowGetIn true;

						switch (_crewRole) do {
							case "driver": {
								_crewUnit assignAsDriver _vehicle;
								[_crewUnit] orderGetIn true;
								_crewUnit moveInDriver _vehicle;
							};
							case "gunner": {
								_crewUnit assignAsGunner _vehicle;
								[_crewUnit] orderGetIn true;
								_crewUnit moveInGunner _vehicle;
							};
							case "commander": {
								_crewUnit assignAsCommander _vehicle;
								[_crewUnit] orderGetIn true;
								_crewUnit moveInCommander _vehicle;
							};
						};

						_crewUnit addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
						_vehicleCrews = _vehicleCrews + [_crewUnit];
					};
				} forEach ["driver","gunner","commander"];

				// Marty: A town combat vehicle without any crew is worse than no vehicle; remove it immediately.
				if (count _vehicleCrews == 0) exitWith {
					["WARNING", Format ["Common_CreateTeam.sqf: Vehicle [%1] for side [%2] at [%3] had no crew and was removed to prevent empty town defenses.", typeOf _vehicle, _side, _position]] Call WFBE_CO_FNC_LogContent;
					deleteVehicle _vehicle;
					_perfSkipped = _perfSkipped + 1;
				};

				_crews = _crews + _vehicleCrews;
				_perfCrew = _perfCrew + count _vehicleCrews;
				_vehicles = _vehicles + [_vehicle];
				_perfVehicles = _perfVehicles + 1;
			};
		};
			}; //--- claude-gaming: close the isClass(CfgVehicles) guard added above.
	} else {
		_perfSkipped = _perfSkipped + 1;
	};
} forEach _list;

// Marty: Audit exposes that CreateUnit now receives the team global flag.
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["createteam", diag_tickTime - _perfStart, Format["side:%1;global:%2;templates:%3;infantry:%4;vehicles:%5;crews:%6;skipped:%7;unitGlobalForwarded:true", _sideID, _global, count _list, _perfInfantry, _perfVehicles, _perfCrew, _perfSkipped], _perfScope] Call PerformanceAudit_Record;
	};
};

[_units,_vehicles,_team,_crews]
