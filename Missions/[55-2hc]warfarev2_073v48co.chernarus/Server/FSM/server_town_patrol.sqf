Private["_aliveTeam","_alertHold","_alertUntil","_contestedOnly","_currentSV","_defense_range","_dropArmsHold","_focus","_lastMode","_lastSV","_location","_mode","_patrol_range","_perfModeChange","_perfScope","_perfStart","_sideChanged","_sideID","_sideNow","_team","_townContested"];

_location = _this select 0;
_team = _this select 1;
_sideID = _this select 2;
_focus = if (count _this > 3) then {_this select 3} else {objNull};

// Marty: Town unit creation can fail under engine limits; do not keep a patrol script alive for a null group.
if (isNull _team) exitWith {};

//--- r35 alert-state: 2-arg nil-guards. Bare 1-arg getVariable returns nil when unset;
//--- `_currentSV < nil` / `_sideID in [nil]` can throw and kill this while-loop, freezing the
//--- group in lastMode (often permanent defense + combat pathing for the rest of the episode).
_lastSV = _location getVariable ["supplyValue", 0];
_mode = "patrol";
_lastMode = "nil";
//--- r35 alert-state hold/decay: defense lasts WFBE_C_TOWNS_PATROL_ALERT_HOLD seconds after a
//--- supply-drop escalate (refreshed on each drop), then DECAYS back to patrol. Replaces the
//--- legacy permanent `_currentSV < startingSupplyValue` latch which never decayed on GUER
//--- (server_town.sqf skips time-based SV regen for GUER_ID) and held every damaged town in
//--- SAD combat pathing for the rest of the activation episode.
_alertHold = missionNamespace getVariable ["WFBE_C_TOWNS_PATROL_ALERT_HOLD", 180];
if (_alertHold < 30) then {_alertHold = 30};
_alertUntil = 0;
_contestedOnly = (missionNamespace getVariable ["WFBE_C_TOWNS_PATROL_CONTESTED_ONLY", 0]) > 0;

_patrol_range = missionNamespace getVariable "WFBE_C_TOWNS_PATROL_RANGE";
_defense_range = missionNamespace getVariable "WFBE_C_TOWNS_DEFENSE_RANGE";
_aliveTeam = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

// Marty: Stop the patrol monitor as soon as the team is gone; dead empty loops accumulate over long games.
while {!WFBE_GameOver && _aliveTeam} do {
	// Marty: Performance Audit for per-town-team patrol scripts spawned by town AI.
	_perfStart = diag_tickTime;
	_perfModeChange = 0;
	_aliveTeam = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	_currentSV = _location getVariable ["supplyValue", 0];
	//--- A2-safe sideID read (default -1 so a missing var does not permanently flip sideChanged).
	_sideNow = _location getVariable ["sideID", -1];
	_sideChanged = !(_sideID in [_sideNow]);
	//--- Escalate on a FRESH supply drop this tick only (not a permanent below-start latch).
	_dropArmsHold = (_currentSV < _lastSV);
	//--- wfbe_contested is public (server_town.sqf r35) so HC-local town_patrol can see it.
	_townContested = _location getVariable ["wfbe_contested", false];
	//--- CONTENDED_ONLY=1: only arm the hold when the town is contested (Lane 190). Legacy (0): any drop.
	if (_dropArmsHold && {!_contestedOnly || _townContested}) then {
		_alertUntil = time + _alertHold;
	};
	//--- Defense while: ownership flipped, (contested-only mode AND contested), or hold not yet expired.
	if (_sideChanged || {_contestedOnly && _townContested} || {time < _alertUntil}) then {
		_mode = "defense";
	} else {
		_mode = "patrol";
	};

	_lastSV = _currentSV;
	
	if(_aliveTeam && _mode != _lastMode && !WFBE_GameOver) then {
		_lastMode = _mode;
		_perfModeChange = 1;

		if (_mode == "patrol") then {
			if (isNull _focus) then {
				[_team,_location,_patrol_range] Spawn WFBE_CO_FNC_WaypointPatrolTown;
			} else {
				[_team,_focus,_patrol_range/4] Spawn WFBE_CO_FNC_WaypointPatrol;
			};
		} else {
			//--- Wakeup fidelity: defense mode must restore an aggressive posture after SAD is laid.
			[_team,getPos _location,'SAD',_defense_range] Call WFBE_CO_FNC_WaypointSimple;
			_team setBehaviour "AWARE";
			_team setCombatMode "RED";
		};
	};

	//--- TOWN-VEHICLE-SELFREPAIR: town garrisons create Motorized/Mechanized/Armored
	//--- templates through Common_CreateTownUnits, but unlike commander teams they never enter
	//--- Common_RunCommanderTeam's self-repair tick. A living crew in a wheel/track/engine-
	//--- damaged hull otherwise keeps receiving patrol waypoints while permanently unable to move.
	//--- Repair only a local, crewed, non-static LandVehicle after the established safe window;
	//--- reset each configured hitpoint because setDamage alone leaves broken parts immobile.
	private ["_tvDelay","_tvHp","_tvHpCfg","_tvHpName","_tvI","_tvSafe","_tvStamp","_tvThreat","_tvVeh"];
	_tvSafe = missionNamespace getVariable ["WFBE_C_AICOM_SELFREPAIR_SAFE_DIST", 250];
	_tvDelay = missionNamespace getVariable ["WFBE_C_AICOM_SELFREPAIR_DELAY", 30];
	{
		_tvVeh = vehicle _x;
		if (!isNull _tvVeh && {_tvVeh != _x} && {alive _tvVeh} && {local _tvVeh} && {_tvVeh isKindOf "LandVehicle"} && {!(_tvVeh isKindOf "StaticWeapon")} && {!(canMove _tvVeh)} && {({alive _x} count (crew _tvVeh)) > 0}) then {
			_tvThreat = {!isNull _x && {alive _x} && {((side _team) getFriend (side _x)) < 0.6}} count (_tvVeh nearEntities [["Man","LandVehicle"], _tvSafe]);
			if (_tvThreat == 0 && {behaviour (leader _team) != "COMBAT"}) then {
				_tvStamp = _tvVeh getVariable "wfbe_town_repair_at";
				if (isNil "_tvStamp") then {
					_tvVeh setVariable ["wfbe_town_repair_at", time];
				} else {
					if ((time - _tvStamp) >= _tvDelay) then {
						_tvVeh setDamage 0;
						_tvHp = configFile >> "CfgVehicles" >> (typeOf _tvVeh) >> "HitPoints";
						if (isClass _tvHp && {(count _tvHp) > 0}) then {
							for "_tvI" from 0 to ((count _tvHp) - 1) do {
								_tvHpCfg = _tvHp select _tvI;
								_tvHpName = getText (_tvHpCfg >> "name");
								if !(_tvHpName in [""]) then {_tvVeh setHit [_tvHpName, 0]};
							};
						};
						_tvVeh setVariable ["wfbe_town_repair_at", nil];
						["INFORMATION", Format ["TOWNVEHSELFREPAIR|town=%1|veh=%2", _location getVariable ["name","?"], typeOf _tvVeh]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			} else {
				_tvVeh setVariable ["wfbe_town_repair_at", nil];
			};
		} else {
			if (!isNull _tvVeh) then {_tvVeh setVariable ["wfbe_town_repair_at", nil]};
		};
	} forEach (units _team);
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
			["town_patrol", diag_tickTime - _perfStart, Format["town:%1;side:%2;alive:%3;units:%4;mode:%5;changed:%6;focus:%7;alertUntil:%8", _location getVariable "name", _sideID, _aliveTeam, count (units _team), _mode, _perfModeChange, !(isNull _focus), round _alertUntil], _perfScope] Call PerformanceAudit_Record;
		};
	};
	sleep 30;
};