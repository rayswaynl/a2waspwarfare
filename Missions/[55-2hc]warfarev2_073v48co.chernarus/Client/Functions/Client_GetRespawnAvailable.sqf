Private ["_availableSpawn","_base_respawn","_buildings","_checks","_deathLoc","_farps","_has_baserespawn","_hq","_mobileRespawns","_range","_redeployTrucks","_side","_sideText","_sideID","_upgrades"];

_side = _this select 0;
_deathLoc = _this select 1;
_sideText = str _side;

//--- Base.
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
_availableSpawn = [_hq];
_buildings = (_side) Call WFBE_CO_FNC_GetSideStructures;
_checks = [_side,missionNamespace getVariable Format["WFBE_%1BARRACKSTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks};
_checks = [_side,missionNamespace getVariable Format["WFBE_%1LIGHTTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks};
_checks = [_side,missionNamespace getVariable Format["WFBE_%1HEAVYTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks};
_checks = [_side,missionNamespace getVariable Format["WFBE_%1AIRCRAFTTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks};

_base_respawn = _availableSpawn - [_hq];
_has_baserespawn = if (alive _hq || count _base_respawn > 0) then {true} else {false};

/* _checks = [_side,missionNamespace getVariable Format["WFBE_%1COMMANDCENTERTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks};
_checks = [_side,missionNamespace getVariable Format["WFBE_%1SERVICEPOINTTYPE",_sideText],_buildings] Call GetFactories;
if (count _checks > 0) then {_availableSpawn = _availableSpawn + _checks}; */


//--- HQ is dead, but we can spawn at other buildings.
if (!alive _hq && count _availableSpawn > 1) then {_availableSpawn = _availableSpawn - [_hq]};

//--- Mobile respawn.
if ((missionNamespace getVariable "WFBE_C_RESPAWN_MOBILE") > 0) then {
	_mobileRespawns = missionNamespace getVariable Format["WFBE_%1AMBULANCES",_sideText];
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	_range = (missionNamespace getVariable "WFBE_C_RESPAWN_RANGES") select (_upgrades select WFBE_UP_RESPAWNRANGE);
	_checks = _deathLoc nearEntities[_mobileRespawns,_range];
	if (count _checks > 0) then {
		{
			if (_x emptyPositions "cargo" > 0) then {
				_availableSpawn = _availableSpawn + [_x];
			};
		} forEach _checks;
	};
};

//--- Medic redeployment truck (forward spawn).
//--- Stationary: speed < 1 AND engine off at evaluation time (menu re-evaluates every ~1s,
//--- so a moving truck drops off the list naturally; no 30s timer needed in v1).
//--- Medic-aboard: a medic client broadcasts itself via wfbe_medic_unit on the vehicle object
//--- (public setVariable — precedent: WFBE_StaticDefenseAssignedUnit in Common_CreateUnitForStaticDefence.sqf).
//--- Reader validates: object non-null, alive, AND still in crew — stale on dismount/disconnect, no clearing needed.
if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0) then {
	_redeployTrucks = missionNamespace getVariable [Format["WFBE_%1REDEPLOYTRUCKS",_sideText],[]];
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	_range = (missionNamespace getVariable "WFBE_C_RESPAWN_RANGES") select (_upgrades select WFBE_UP_RESPAWNRANGE);
	_checks = _deathLoc nearEntities[_redeployTrucks,_range];
	if (count _checks > 0) then {
		_sideID = (_side) Call GetSideID;
		{
			private ["_veh","_medic","_tooClose"];
			_veh = _x;
			_medic = _veh getVariable ["wfbe_medic_unit", objNull];
			//--- Cargo available, stationary, engine off, medic aboard and alive.
			if (_veh emptyPositions "cargo" > 0
				&& speed _veh < 1
				&& !(isEngineOn _veh)
				&& !(isNull _medic) && {alive _medic} && {_medic in (crew _veh)}) then {
				//--- Not within 300 m of an enemy-held or contested town.
				_tooClose = false;
				{
					private "_townSide";
					_townSide = _x getVariable ["sideID",-1];
					if (_townSide != _sideID && _veh distance _x < 300) then {_tooClose = true};
				} forEach towns;
				if !(_tooClose) then {
					_availableSpawn = _availableSpawn + [_veh];
				};
			};
		} forEach _checks;
	};
};

//--- Leader.
if ((missionNamespace getVariable "WFBE_C_RESPAWN_LEADER") > 0) then {
	if (group player != WFBE_Client_Team && (leader group player) != player) then {
		if (alive (leader group player) && _deathLoc distance vehicle(leader group player) <= (missionNamespace getVariable "WFBE_C_RESPAWN_RANGE_LEADER")) then {_availableSpawn = _availableSpawn + [leader group player]};
	};
};

//--- In a threeway, defender players are able to respawn in side-controlled towns as long as all camps are owned by the defender's side.
if (WFBE_ISTHREEWAY && _side == WFBE_DEFENDER) then {
	_availableSpawn = _availableSpawn + (_side Call GetRespawnThreeway);
	
	//--- Victory condition may allow random respawn on startup locations.
	if ((missionNamespace getVariable "WFBE_C_VICTORY_THREEWAY") in [0]) then {
		//--- Make sure that at least one base respawn is available.
		if !(_has_baserespawn) then {_availableSpawn = _availableSpawn - [_hq];_availableSpawn = _availableSpawn + [WFBE_Client_Logic getVariable "wfbe_startpos"]};
	};
};

//--- Camps.
if ((missionNamespace getVariable "WFBE_C_RESPAWN_CAMPS_MODE") > 0) then {
	_availableSpawn = _availableSpawn + ([_deathLoc, _side] Call GetRespawnCamps);
};

_availableSpawn