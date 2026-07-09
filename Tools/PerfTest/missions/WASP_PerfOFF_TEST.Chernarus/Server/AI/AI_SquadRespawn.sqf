Private ["_availableSpawn","_autonomous","_buildings","_checks","_closestRespawn","_deathLoc","_enemySide","_hq","_isForcedRespawn","_leader","_loadout","_mobileRespawns","_moveMode","_pos","_ran","_range","_rcm","_rd","_respawn","_respawnLoc","_side","_sideID","_sideText","_team","_update","_upgrades"];
_side = _this select 0;
_team = _this select 1;
_sideText = str _side;
_deathLoc = objNull;
_respawnLoc = objNull;
_sideID = (_side) Call GetSideID;

_rd = missionNamespace getVariable "WFBE_C_RESPAWN_DELAY";
_rcm = missionNamespace getVariable "WFBE_C_RESPAWN_CAMPS_MODE";

sleep (random 0.5);

while {!gameOver} do {
	if (isPlayer leader _team) exitWith {};
	[str _side,'UnitsCreated',1] Call UpdateStatistics;
	waitUntil {!alive leader _team || isPlayer leader _team};
	_deathLoc = getPos (leader _team);
	["INFORMATION", Format ["AI_AdvancedRespawn.sqf: [%1] AI Team Leader [%2] [%3] has respawned.", _sideText, _team, leader _team]] Call WFBE_CO_FNC_LogContent;
	if (isPlayer leader _team) exitWith {};
	waitUntil {alive leader _team || isPlayer leader _team};
	if (isPlayer leader _team) exitWith {};

	_respawn = (_team) Call GetTeamRespawn;
	
	//--- Place the AI.
	_leader = leader _team;
	_leader removeAllEventHandlers "Killed";
	_leader addEventHandler ['Killed', Format["[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled", _sideID]];
	_leader setPos getMarkerPos Format["%1TempRespawnMarker",_sideText];

	//--- DEADSPAWN GUARD (fable/deadspawn-guard, Ray 2026-07-04): the leader is now parked on its side's
	//--- TempRespawnMarker for the respawn wait below. The three side markers sit 44-128m apart on one
	//--- Chernarus mountaintop, so an ARMED enemy-side leader parked here has line-of-fire onto a HUMAN
	//--- parked on an adjacent side's marker during join ("AI killed <player> in the deadspawn"). Enforce
	//--- Ray's rule - NO armed units in deadspawns - by making the parked body non-hostile + unkillable for
	//--- the hold: setCaptive true stops it firing on / being targeted by other sides, allowDamage false
	//--- stops stray fire killing it there. Restored before it leaves the marker (see release below). Same
	//--- allowDamage/setCaptive idiom as WFBE_HC_FNC_ParkDeadspawn (Init_HC.sqf). A2-OA-1.64 safe.
	if ((missionNamespace getVariable ["WFBE_C_DEADSPAWN_GUARD", 1]) > 0 && {alive _leader}) then {
		_leader setCaptive true;
		_leader allowDamage false;
		["INFORMATION", Format ["DEADSPAWN_GUARD|park|side=%1|unit=%2", _sideText, _leader]] Call WFBE_CO_FNC_LogContent;
	};

	_availableSpawn = [];
	_isForcedRespawn = false;
	if (typeName _respawn == 'STRING') then {if (_respawn == "forceRespawn") then {_isForcedRespawn = true}};
	
	//--- Towns.
	if (_rcm > 0 && !_isForcedRespawn) then {
		_availableSpawn = _availableSpawn + ([_deathLoc, _side] Call GetRespawnCamps);
	};
	
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	
	//--- Mobile Respawn.
	if ((missionNamespace getVariable "WFBE_C_RESPAWN_MOBILE") > 0 && !_isForcedRespawn) then {
		_mobileRespawns = missionNamespace getVariable Format ["WFBE_%1AMBULANCES",_sideText];
		_range = (missionNamespace getVariable "WFBE_C_RESPAWN_RANGES") select (_upgrades select WFBE_UP_RESPAWNRANGE);
		_checks = _deathLoc nearEntities[_mobileRespawns,_range];
		if (count _checks > 0) then {
			{if (alive _x) then {_availableSpawn = _availableSpawn + [_x]}} forEach _checks;
		};
	};
	
	sleep _rd;

	//--- Equip the AI.
	//--- Guard: _upgrades may be [] for civilian/unknown sides (Common_GetSideUpgrades default branch returns []).
	if (count _upgrades > 13) then {
		_loadout = missionNamespace getVariable Format["WFBE_%1_AI_Loadout_%2", _sideText, _upgrades select 13];
		if !(isNil '_loadout') then {
			if (count _loadout > 0) then {
				_loadout = _loadout select floor (random count _loadout);
				if (count _loadout <= 3) then {
					[_leader, _loadout select 0, _loadout select 1, _loadout select 2] Call WFBE_CO_FNC_EquipUnit;
				} else {
					[_leader, _loadout select 0, _loadout select 1, _loadout select 2, _loadout select 3, _loadout select 4] Call WFBE_CO_FNC_EquipUnit;
				};
			};
		};
	};
	_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
	_buildings = (_side) Call WFBE_CO_FNC_GetSideStructures;

	//--- Check whether AI has a spawn set or not.
	_update = false;
	switch (typeName _respawn) do {
		case "STRING": {
			_update = true;
			if (_isForcedRespawn) then {[_team,""] Call SetTeamRespawn};
		}; //--- Not defined.
		case "OBJECT": {
			_respawnLoc = _respawn;
			if (!alive _respawn || isNull _respawn) then {
				[_team, ""] Call SetTeamRespawn;
				_update = true;
			};	//--- Defined.
		};
	};
	
	//--- Default respawn.
	if (_update) then {
		_respawnLoc = _hq;
		if (count _buildings > 0) then {
			_respawnLoc = [_hq,_buildings] Call WFBE_CO_FNC_GetClosestEntity;
		};
	};
	
	//--- Alternative spawn location.
	if (count _availableSpawn > 0) then {
		_respawnLoc = _availableSpawn select floor (random count _availableSpawn);
	};

	["INFORMATION", Format ["AI_AdvancedRespawn.sqf: [%1] AI Team Leader [%2] [%3] has respawned at [%4].", _sideText, _team, leader _team, _respawnLoc]] Call WFBE_CO_FNC_LogContent;
	//--- DEADSPAWN GUARD release (fable/deadspawn-guard): the leader is about to leave the deadspawn marker
	//--- for its real respawn - restore its combat state (undo the park-time captive/allowDamage) so it
	//--- fights normally again. Idempotent (safe if the guard was off / never applied).
	if ((missionNamespace getVariable ["WFBE_C_DEADSPAWN_GUARD", 1]) > 0 && {alive _leader}) then {
		_leader setCaptive false;
		_leader allowDamage true;
	};
	_pos = [getPos _respawnLoc,20,30] Call GetRandomPosition;
	_pos set [2,0];
	_leader setPos _pos;
	
	//--- Assign fresh order (tbc).
	_autonomous = (_team) Call GetTeamAutonomous;
	if !(_autonomous) then {
		_moveMode = (_team) Call GetTeamMoveMode;
		if (_moveMode == "towns") then {_team setVariable ["wfbe_teamgoto", objNull, true]};
		if (_moveMode == "move") then {[_team,"resetMove"] Call SetTeamMoveMode};
		if (_moveMode == "patrol") then {[_team,"resetPatrol"] Call SetTeamMoveMode};
		if (_moveMode == "defense") then {[_team,"resetDefense"] Call SetTeamMoveMode};
	};
};