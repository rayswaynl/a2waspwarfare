/* Enhanced Respawn Management via Multiplayer Event Handler - Experimental */
Private ['_autonomous','_availableSpawn','_buildings','_campBunker','_checks','_closestRespawn','_corpse','_deadspawnGuardApplied','_deathLoc','_hq','_i','_isForcedRespawn','_liveSpawn','_mobileRespawns','_moveMode','_penParked','_penPos','_pos','_ran','_range','_rcm','_rd','_respawn','_respawnLoc','_respawnedUnit','_side','_sideID','_sideText','_skip','_team','_update','_upgrades'];

_respawnedUnit = _this select 0;
_corpse = _this select 1;
_deadspawnGuardApplied = false;

_deathLoc = getPos _corpse;
_rd = missionNamespace getVariable "WFBE_C_RESPAWN_DELAY";
_rcm = missionNamespace getVariable "WFBE_C_RESPAWN_CAMPS_MODE";

_side = side _respawnedUnit;
_sideID = (_side) Call GetSideID;
//--- Ensure that the side is not civilian.
if (_side == civilian) then {
	_side = switch (getNumber(configFile >> "CfgVehicles" >> typeOf _respawnedUnit >> "side")) do {case 0: {east}; case 1: {west}; case 2: {resistance}; default {civilian}};
};
//--- The CfgVehicles fallback can replace civilian with a fighting side; keep the Killed EH's
//--- attribution ID aligned with that resolved side rather than retaining the initial CIV ID.
_sideID = (_side) Call GetSideID;
_sideText = str _side;
_team = group _respawnedUnit;
_respawn = (_team) Call GetTeamRespawn;
_respawnLoc = objNull;

["INFORMATION", Format ["AI_AdvancedRespawn.sqf: [%1] AI Team Leader [%2] [%3] has respawned.", _sideText, _team, _respawnedUnit]] Call WFBE_CO_FNC_LogContent;

//--- Remove previous EH.
_respawnedUnit removeAllEventHandlers "Killed";
_respawnedUnit addEventHandler ['Killed', Format["[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled", _sideID]];

//--- Place the leader on a 'safe' position.
//--- fable/deadspawn-ai-pen (owner 2026-08-01): same relocation as AI_SquadRespawn.sqf - park the
//--- waiting body at the shared in-bounds underwater pen (Common_DeadspawnPenPos.sqf) instead of
//--- the land TempRespawnMarker ring near the northern front. Resolver output passes the same
//--- WFBE_BOUNDARIESXY square Client_IsOnMap.sqf tests, so the offmap force-kill can never fire
//--- on the pen. isNil guard: resolver not yet registered (Init_Common.sqf execVM race) falls
//--- back to the legacy marker park.
_penParked = false;
_penPos = [];
if (((missionNamespace getVariable ["WFBE_C_DEADSPAWN_AI_PEN", 0]) > 0) && {!isNil "WFBE_CO_FNC_DeadspawnPenPos"}) then {
	_penPos = [] Call WFBE_CO_FNC_DeadspawnPenPos;
	//--- m0801h6 (Codex audit, owner live repro): ONE shared pen point parked BOTH sides together,
	//--- and on landlocked terrains the resolver's dry z=0 fallback put that mixed-side crowd on
	//--- open ground. Per-side positions ALWAYS: offset the confirmed-water pen per side ID and
	//--- re-verify water; a dry or unverified point routes this side to its OWN legacy marker.
	//--- ((_side) Call GetSideID) is deliberate - _sideID above is read pre-civilian-remap.
	_penPos set [0, (_penPos select 0) + (((_side) Call GetSideID) * 200)];
	if (((_penPos select 2) < 0) && {surfaceIsWater [(_penPos select 0), (_penPos select 1), 0]}) then {
		_respawnedUnit setPos _penPos;
		_penParked = true;
		["INFORMATION", Format ["DEADSPAWN_AI_PEN|park|side=%1|unit=%2|pos=%3", _sideText, _respawnedUnit, _penPos]] Call WFBE_CO_FNC_LogContent;
	} else {
		_respawnedUnit setPos getMarkerPos Format["%1TempRespawnMarker",_sideText];
	};
} else {
	_respawnedUnit setPos getMarkerPos Format["%1TempRespawnMarker",_sideText];
};

	//--- DEADSPAWN GUARD (fable/deadspawn-guard, Ray 2026-07-04): the leader is now parked on its side's
	//--- TempRespawnMarker for the respawn wait below. The three side markers sit 44-128m apart on one
	//--- Chernarus mountaintop, so an ARMED enemy-side leader parked here has line-of-fire onto a HUMAN
	//--- parked on an adjacent side's marker during join ("AI killed <player> in the deadspawn"). Enforce
	//--- Ray's rule - NO armed units in deadspawns - by making the parked body non-hostile + unkillable for
	//--- the hold: setCaptive true stops it firing on / being targeted by other sides, allowDamage false
	//--- stops stray fire killing it there. Restored before it leaves the marker (see release below). Same
	//--- allowDamage/setCaptive idiom as WFBE_HC_FNC_ParkDeadspawn (Init_HC.sqf). A2-OA-1.64 safe.
	//--- fable/deadspawn-ai-pen: a pen-parked body waits ~8m under water - the invulnerability hold
	//--- below is MANDATORY there (drowning is engine damage; allowDamage false blocks it), so the
	//--- pen path forces the hold regardless of the WFBE_C_DEADSPAWN_GUARD toggle (which keeps its
	//--- existing meaning for the legacy land park).
	if ((_penParked || {(missionNamespace getVariable ["WFBE_C_DEADSPAWN_GUARD", 1]) > 0}) && {alive _respawnedUnit}) then {
		_respawnedUnit setCaptive true;
		_respawnedUnit allowDamage false;
		//--- m0801h6 (Codex audit): NO ARMED UNITS IN DEADSPAWNS includes the weapon itself - store
		//--- the loadout on the unit and strip it for the hold; every release path restores it first.
		_respawnedUnit setVariable ["wfbe_penWeapons", weapons _respawnedUnit];
		_respawnedUnit setVariable ["wfbe_penMagazines", magazines _respawnedUnit];
		removeAllWeapons _respawnedUnit;
		_deadspawnGuardApplied = true;
		["INFORMATION", Format ["DEADSPAWN_GUARD|park|side=%1|unit=%2", _sideText, _respawnedUnit]] Call WFBE_CO_FNC_LogContent;
	};

_availableSpawn = [];
_isForcedRespawn = false;

//--- Ensure that the ai is not forced to respawn.
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
		{if (alive _x && {side _x == _side}) then {_availableSpawn = _availableSpawn + [_x]}} forEach _checks; //--- bughunt-20260730: friendly-side gate for mobile MEV
	};
};

//--- Wait.
_i = _rd;
_skip = false;
while {_i > 0} do {
	if (isPlayer(_respawnedUnit) || !(alive _respawnedUnit)) exitWith {_skip = true};
	
	_i = _i - 1;	
	sleep 1;
};

//--- A player/death transition can land during the final sleep, after the loop's last check.
if (isPlayer(_respawnedUnit) || !(alive _respawnedUnit)) then {_skip = true};

//--- A skipped player handoff bypasses normal AI movement, so restore the state here.
if (_skip && _deadspawnGuardApplied && {alive _respawnedUnit}) then {
	//--- fable/deadspawn-ai-pen: surface the body BEFORE damage returns - releasing it 8m under
	//--- water would let the engine drown the bot (or the just-joined player) at the pen.
	if (_penParked && {(count _penPos) > 1}) then {_respawnedUnit setPos [_penPos select 0, _penPos select 1, 0]};
	//--- m0801h6 (Codex audit): hand the stored loadout back before the player takes the body.
	{_respawnedUnit addWeapon _x} forEach (_respawnedUnit getVariable ["wfbe_penWeapons", []]);
	{_respawnedUnit addMagazine _x} forEach (_respawnedUnit getVariable ["wfbe_penMagazines", []]);
	if ((primaryWeapon _respawnedUnit) != "") then {_respawnedUnit selectWeapon (primaryWeapon _respawnedUnit)};
	_respawnedUnit setVariable ["wfbe_penWeapons", []];
	_respawnedUnit setVariable ["wfbe_penMagazines", []];
	_respawnedUnit setCaptive false;
	_respawnedUnit allowDamage true;
	["INFORMATION", Format ["DEADSPAWN_GUARD|release|side=%1|unit=%2|skip=%3", _sideText, _respawnedUnit, _skip]] Call WFBE_CO_FNC_LogContent;
};

//--- Make sure that the AI didn't die or that a player hasn't replaced him before going any further.
if !(_skip) then {
	//--- m0801h6 (Codex audit): give the stored pen loadout back FIRST - EquipUnit below strips and
	//--- re-equips when a side loadout table exists, so this restore decides the no-table case (and
	//--- the null-respawnLoc route further down must never move an unarmed unit out of the hold).
	if (_deadspawnGuardApplied && {alive _respawnedUnit}) then {
		{_respawnedUnit addWeapon _x} forEach (_respawnedUnit getVariable ["wfbe_penWeapons", []]);
		{_respawnedUnit addMagazine _x} forEach (_respawnedUnit getVariable ["wfbe_penMagazines", []]);
		if ((primaryWeapon _respawnedUnit) != "") then {_respawnedUnit selectWeapon (primaryWeapon _respawnedUnit)};
		_respawnedUnit setVariable ["wfbe_penWeapons", []];
		_respawnedUnit setVariable ["wfbe_penMagazines", []];
	};
	//--- Equip the AI.
	//--- Guard: _upgrades may be [] for civilian/unknown sides (Common_GetSideUpgrades default branch returns []).
	if (count _upgrades > 13) then {
		_loadout = missionNamespace getVariable Format["WFBE_%1_AI_Loadout_%2", _sideText, _upgrades select 13];
		if !(isNil '_loadout') then {
			if (count _loadout > 0) then {
				_loadout = _loadout select floor (random count _loadout);
				if (count _loadout <= 3) then {
					[_respawnedUnit, _loadout select 0, _loadout select 1, _loadout select 2] Call WFBE_CO_FNC_EquipUnit;
				} else {
					[_respawnedUnit, _loadout select 0, _loadout select 1, _loadout select 2, _loadout select 3, _loadout select 4] Call WFBE_CO_FNC_EquipUnit;
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
			//--- Not defined.
			_update = true;
			if (_isForcedRespawn) then {[_team,""] Call SetTeamRespawn};
		};
		case "OBJECT": {
			//--- Defined.
			_respawnLoc = _respawn;
			if (!alive _respawn || isNull _respawn) then {
				[_team, ""] Call SetTeamRespawn;
				_update = true;
			};
		};
	};
	
	//--- Default respawn.
	if (_update) then {
		_respawnLoc = _hq;
		if (count _buildings > 0) then {
			_respawnLoc = [_hq,_buildings] Call WFBE_CO_FNC_GetClosestEntity;
		};
	};
	
	//--- r106 (kimi/bughunt-aicom-medevac): the spawn snapshot above predates the respawn wait (_rd).
	//--- An ambulance can be destroyed and a camp can flip or be torn down while the leader waits,
	//--- and the pick below would then respawn it onto a burning wreck or an enemy-held camp.
	//--- Re-validate each entry the same way it was admitted: camps must still be ours with a live
	//--- bunker; plain vehicles (the ambulances) must still be alive hulls. The OBJECT-form _respawn
	//--- above already gets the same alive/isNull re-check - the snapshot list did not.
	if (count _availableSpawn > 0) then {
		_liveSpawn = [];
		{
			if (!isNull _x) then {
				_campBunker = _x getVariable "wfbe_camp_bunker";
				if (!isNil "_campBunker") then {
					if (!isNull _campBunker && {alive _campBunker} && {(_x getVariable ["sideID", -1]) == _sideID}) then {_liveSpawn = _liveSpawn + [_x]};
				} else {
					if (alive _x) then {_liveSpawn = _liveSpawn + [_x]};
				};
			};
		} forEach _availableSpawn;
		if (count _liveSpawn < count _availableSpawn) then {
			["INFORMATION", Format ["AI_AdvancedRespawn.sqf: [%1] dropped %2 stale respawn point(s) (wrecked ambulance / flipped camp) captured before the respawn wait.", _sideText, (count _availableSpawn) - (count _liveSpawn)]] Call WFBE_CO_FNC_LogContent;
		};
		_availableSpawn = _liveSpawn;
	};

	//--- Alternative spawn location.
	if (count _availableSpawn > 0) then {
		_respawnLoc = _availableSpawn select floor (random count _availableSpawn);
	};

	["INFORMATION", Format ["AI_AdvancedRespawn.sqf: [%1] AI Team Leader [%2] [%3] has respawned at [%4].", _sideText, _team, _respawnedUnit, _respawnLoc]] Call WFBE_CO_FNC_LogContent;
	
	//--- Normal AI remains guarded until immediately before it leaves the temp marker.
	if (_deadspawnGuardApplied && {alive _respawnedUnit}) then {
		//--- fable/deadspawn-ai-pen: surface first - the null-respawnLoc branch below keeps the park,
		//--- and an armed-again body must never be left 8m under water. The normal branch setPos to
		//--- _respawnLoc right after makes this a harmless double move.
		if (_penParked && {(count _penPos) > 1}) then {_respawnedUnit setPos [_penPos select 0, _penPos select 1, 0]};
		_respawnedUnit setCaptive false;
		_respawnedUnit allowDamage true;
		["INFORMATION", Format ["DEADSPAWN_GUARD|release|side=%1|unit=%2|skip=%3", _sideText, _respawnedUnit, _skip]] Call WFBE_CO_FNC_LogContent;
	};
	//--- fail-clean r48: null HQ + no buildings + empty availableSpawn => getPos throws, unit stuck on temp marker.
	if (isNull _respawnLoc) then {
		//--- m0801h6 (Codex audit): the guard released above - NEVER leave a re-armed, vulnerable
		//--- unit standing at the shared pen. Route it to its OWN side's legacy marker (pre-pen r48
		//--- behaviour, per-side by construction) so no mixed-side crowd can form anywhere.
		_respawnedUnit setPos getMarkerPos Format["%1TempRespawnMarker",_sideText];
		["WARNING", Format ["AI_AdvancedRespawn.sqf: [%1] AI unit [%2] null respawnLoc - routed to side temp marker.", _sideText, _respawnedUnit]] Call WFBE_CO_FNC_LogContent;
	} else {
	_pos = [getPos _respawnLoc,20,30] Call GetRandomPosition;
	_pos set [2,0];
	_respawnedUnit setPos _pos;
	};
	
	//--- Assign fresh order if the AI is not on autonomous mode.
	_autonomous = (_team) Call GetTeamAutonomous;
	if !(_autonomous) then {
		_moveMode = (_team) Call GetTeamMoveMode;
		if (_moveMode == "towns") then {_team setVariable ["wfbe_teamgoto", objNull, true]};
		if (_moveMode == "move") then {[_team,"resetMove"] Call SetTeamMoveMode};
		if (_moveMode == "patrol") then {[_team,"resetPatrol"] Call SetTeamMoveMode};
		if (_moveMode == "defense") then {[_team,"resetDefense"] Call SetTeamMoveMode};
	};
};
