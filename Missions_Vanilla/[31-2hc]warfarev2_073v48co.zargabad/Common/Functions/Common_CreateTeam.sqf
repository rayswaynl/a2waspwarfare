// Marty: Crew placement uses explicit private locals because town AI may be created on server, client, or headless client.
Private ['_canCreate','_commander','_crewRole','_crewUnit','_crews','_driver','_firstDone','_global','_gunner','_list','_lockVehicles','_perfCrew','_perfInfantry','_perfScope','_perfSkipped','_perfStart','_perfVehicles','_position','_probability','_side','_sideID','_team','_type','_unit','_units','_vehicle','_vehicles','_rearmor'];

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

if (isNull _team) then {_team = createGroup _side}; //--- Create a group if none are given as a parameter.

if (typeName _list != "ARRAY") then { _list = [_list] };

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
		if (_x isKindOf 'Man') then {
			// Marty: Forward the team global-init flag so town AI infantry can skip client marker/action setup.
			_unit = [_x,_team,_position,_sideID,_global] Call WFBE_CO_FNC_CreateUnit;
			_units = _units + [_unit];
			_perfInfantry = _perfInfantry + 1;
		} else {
			_vehicle = [_x, _position, _sideID, 0, _lockVehicles, true, _global, "FORM"] Call WFBE_CO_FNC_CreateVehicle;
			_perfVehicles = _perfVehicles + 1;
			_type = if (_vehicle isKindOf 'Man') then {missionNamespace getVariable Format ['WFBE_%1SOLDIER',_side]} else {if (_vehicle isKindOf 'Air') then {missionNamespace getVariable Format ['WFBE_%1PILOT',_side]} else {missionNamespace getVariable Format ['WFBE_%1CREW',_side]}};
			// Marty: Assign crew roles before moveIn so locked or delegated town vehicles keep their crews mounted.
			_vehicle allowCrewInImmobile true;
			_team addVehicle _vehicle;
			{
				_crewRole = _x;
				call {
					if ((_vehicle emptyPositions _crewRole) <= 0) exitWith {};
					_crewUnit = [_type,_team,_position,_sideID,_global] Call WFBE_CO_FNC_CreateUnit;
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
					_crews = _crews + [_crewUnit];
					_perfCrew = _perfCrew + 1;
				};
			} forEach ["driver","gunner","commander"];
			_vehicles = _vehicles + [_vehicle];
		};
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
