/*
	Server_GarrisonSortie.sqf -- garrison sortie patrol loop (SERVER-only).
	Lane 237 (docs/design/GARRISON-SORTIE-PATROL-DESIGN.md, GR-2026-07-03a). Flag-gated:
	WFBE_C_GARRISON_SORTIE, default 0.

	Sends a short-lived foot/light patrol sortie out from an OWNED, active town (WEST, EAST
	or GUER) when at least one human player is within WFBE_C_GARRISON_SORTIE_PLAYER_RANGE of
	that town. Reuses the existing primitives only: WFBE_CO_FNC_CreateGroup / CreateUnit for
	spawn, AIPatrol for the patrol order (same call idiom as Server_GuerAirDef.sqf's ground-QRF
	branch and Server_TownGarrisonDressing.sqf). Hard TTL, no "quiet" despawn (the sortie is
	deliberately short-lived, not a standing defender) and a small global active cap keep this
	from accumulating AI at empty map locations.

	Registry entry: [_town, _group, _spawnTime, _sideID]. Script-local (NOT wfbe_persistent),
	so it can never outlive the worker or leak groups.

	Eligibility per poll (mirrors the design doc):
	  1. towns must exist.
	  2. global active-sortie count < WFBE_C_GARRISON_SORTIE_MAX_ACTIVE.
	  3. town sideID is WEST, EAST or GUER AND wfbe_active == true.
	  4. at least one player within WFBE_C_GARRISON_SORTIE_PLAYER_RANGE of the town.
	  5. the town does not already have a live sortie.

	Cleanup: drop the entry when the group is null/wiped, the town is lost (current sideID no
	longer matches the sideID recorded at spawn), the town goes inactive, or the TTL expires.
	Player-safe teardown (delete only non-player units) mirrors Server_GuerAirDef.sqf /
	Server_TownGarrisonDressing.sqf, since GUER (and, on some configs, WEST/EAST) can be playable.

	A2 OA 1.64 safe: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/worldSize; Private
	[array] declarations, forEach + exitWith-on-the-if idiom (proven at
	server_side_patrols.sqf ~L285), explicit object-equality compares instead of `in` on an
	object array.
*/
if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE", 0]) < 1) exitWith {};

Private ["_interval","_ttl","_playerRange","_patrolMin","_patrolMax","_size","_maxActive","_sorties"];

_interval    = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_INTERVAL", 120];
_ttl         = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_TTL", 300];
_playerRange = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_PLAYER_RANGE", 1500];
_patrolMin   = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_PATROL_MIN", 300];
_patrolMax   = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_PATROL_MAX", 800];
if (_patrolMax < _patrolMin) then { _patrolMax = _patrolMin; }; //--- guard MAX>=MIN.
_size        = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_SIZE", 4];
_maxActive   = missionNamespace getVariable ["WFBE_C_GARRISON_SORTIE_MAX_ACTIVE", 4];

//--- Wait for towns to exist (mirrors GuerAirDef/GarrisonDressing startup gate).
waitUntil { (!isNil "towns") && {(count towns) > 0} };
sleep 45;

//--- Live registry. Script-local (NOT on missionNamespace, NOT wfbe_persistent) so it can't
//--- outlive a despawn or leak groups.
_sorties = [];

["INITIALIZATION", Format ["Server_GarrisonSortie.sqf: garrison sortie patrol started (interval=%1 ttl=%2 playerRange=%3 size=%4 cap=%5).", _interval, _ttl, _playerRange, _size, _maxActive]] Call WFBE_CO_FNC_LogContent;
diag_log format ["GARSORTIE|START|interval=%1|ttl=%2|playerRange=%3|patrolMin=%4|patrolMax=%5|size=%6|cap=%7", _interval, _ttl, _playerRange, _patrolMin, _patrolMax, _size, _maxActive];

while {!WFBE_GameOver} do {
	//--- wave0721e live-burn guard (2026-07-21, see Server_GuerAirDef.sqf): a SERVER-only loop
	//--- can hit 'Undefined variable wfbe_co_fnc_logvehdelete' mid-match even though Init_Common.sqf
	//--- compiles it unconditionally. Re-stub per tick so cleanup NEVER depends on it being set.
	if (isNil "WFBE_CO_FNC_LogVehDelete") then { WFBE_CO_FNC_LogVehDelete = {}; };
	sleep _interval;

	Private ["_now","_kept","_townsWithSortie","_perfStart"];
	_perfStart = diag_tickTime;
	_now = time;

	//=== (1) PRUNE + SELF-CLEAN =================================================================
	_kept            = [];
	_townsWithSortie = [];
	{
		Private ["_entry","_eTown","_eGrp","_eSpawn","_eSideID","_drop","_reason","_liveN","_townSide","_townActive"];
		_entry   = _x;
		_eTown   = _entry select 0;
		_eGrp    = _entry select 1;
		_eSpawn  = _entry select 2;
		_eSideID = _entry select 3;

		_drop   = false;
		_reason = "";

		//--- Group wiped (null or no living members) => prune.
		_liveN = if (isNull _eGrp) then {0} else {{alive _x} count (units _eGrp)};
		if (isNull _eGrp || {_liveN == 0}) then { _drop = true; _reason = "wiped"; };

		//--- Town no longer owned by the spawning side, or no longer active => recall.
		if (!_drop) then {
			_townSide   = if (isNull _eTown) then {-1} else {_eTown getVariable ["sideID", -1]};
			_townActive = if (isNull _eTown) then {false} else {_eTown getVariable ["wfbe_active", false]};
			if (_townSide != _eSideID) then { _drop = true; _reason = "town_lost"; };
			if (!_drop && {!_townActive}) then { _drop = true; _reason = "town_inactive"; };
		};

		//--- TTL exceeded => forced recycle (this loop has no "quiet" despawn by design -
		//--- the sortie is deliberately short-lived, not a standing defender).
		if (!_drop && {(_now - _eSpawn) > _ttl}) then { _drop = true; _reason = "ttl"; };

		if (_drop) then {
			//--- Player-safe teardown: never deleteVehicle a player-occupied body.
			if (!isNull _eGrp) then {
				{ if (!(isPlayer _x)) then { ["garrisonsortie-cleanup", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; }; } forEach (units _eGrp);
				if (({isPlayer _x} count (units _eGrp)) == 0) then { deleteGroup _eGrp; };
			};
			diag_log format ["GARSORTIE|DESPAWN|town=%1|reason=%2|remaining=%3", (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}), _reason, (count _kept)];
		} else {
			_kept            = _kept + [_entry];
			_townsWithSortie = _townsWithSortie + [_eTown];
		};
	} forEach _sorties;
	_sorties = _kept;

	//=== (2) MAINTAIN: spawn one sortie per eligible town, under the global active cap =========
	{
		Private ["_town","_hasSortie","_hasPlayerNear","_sideID","_side","_radius","_ang","_townPos","_spawnPos","_fallbackClass","_soldierClass","_grp","_built","_i","_u"];
		_town = _x;

		if ((count _sorties) < _maxActive
			&& {!(isNull _town)}
			&& {((_town getVariable ["sideID", -1]) == WFBE_C_WEST_ID) || {(_town getVariable ["sideID", -1]) == WFBE_C_EAST_ID} || {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}}
			&& {_town getVariable ["wfbe_active", false]}) then {

			//--- One sortie per town at a time.
			_hasSortie = false;
			{ if (_x == _town) then { _hasSortie = true; }; } forEach _townsWithSortie;

			if (!_hasSortie) then {
				//--- Proximity gate: at least one human player within range of the town.
				_hasPlayerNear = false;
				{ if (isPlayer _x && {alive _x} && {(side _x) != civilian} && {!((name _x) in WFBE_C_HC_NAMES)} && {(_x distance _town) < _playerRange}) exitWith { _hasPlayerNear = true; }; } forEach playableUnits;

				if (_hasPlayerNear) then {
					_sideID = _town getVariable ["sideID", -1];
					_side   = _sideID Call WFBE_CO_FNC_GetSideFromID;

					_radius   = _patrolMin + random (_patrolMax - _patrolMin);
					_ang      = random 360;
					_townPos  = getPos _town;
					_spawnPos = [(_townPos select 0) + _radius * sin _ang, (_townPos select 1) + _radius * cos _ang, 0];
					//--- Coastal towns can resolve a sortie-ring offset over the sea. Re-roll the same
					//--- configured band, then skip this tick rather than creating infantry that immediately drowns.
					Private ["_waterTry","_waterRetryCap"];
					_waterTry = 0;
					_waterRetryCap = 20;
					while {surfaceIsWater _spawnPos && {_waterTry < _waterRetryCap}} do {
						_radius = _patrolMin + random (_patrolMax - _patrolMin);
						_ang = random 360;
						_spawnPos = [(_townPos select 0) + _radius * sin _ang, (_townPos select 1) + _radius * cos _ang, 0];
						_waterTry = _waterTry + 1;
					};

					if (!(surfaceIsWater _spawnPos)) then {
					_fallbackClass = switch (_sideID) do {
						case WFBE_C_WEST_ID: {"US_Soldier_EP1"};
						case WFBE_C_EAST_ID: {"RU_Soldier"};
						case WFBE_C_GUER_ID: {"GUE_Soldier_1"};
						default {"GUE_Soldier_1"};
					};
					_soldierClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", str _side], _fallbackClass];

					_grp = [_side, "garrison-sortie"] Call WFBE_CO_FNC_CreateGroup;
					if (isNull _grp) then {
						diag_log format ["GARSORTIE|SPAWNFAIL|town=%1|reason=group_null", (_town getVariable ["name","?"])];
					} else {
						_built = 0;
						for "_i" from 1 to _size do {
							_u = [_soldierClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _u) then { _built = _built + 1; };
						};

						if (_built > 0) then {
							//--- Tag for identification only (no client-side consumer yet -> local, not broadcast).
							_grp setVariable ["wfbe_garrison_sortie", true, false];

							//--- NEVER idle: immediate patrol order around the town (same call idiom as the
							//--- proven GUER ground-QRF branch in Server_GuerAirDef.sqf and
							//--- Server_TownGarrisonDressing.sqf's crew orders).
							[_grp, _townPos, _radius] Call AIPatrol;

							_sorties         = _sorties + [[_town, _grp, time, _sideID]];
							_townsWithSortie = _townsWithSortie + [_town];

							diag_log format ["GARSORTIE|SPAWN|town=%1|side=%2|built=%3|radius=%4|alive=%5", (_town getVariable ["name","?"]), _side, _built, round _radius, (count _sorties)];
						} else {
							//--- No units built: tear down the empty group so nothing leaks.
							deleteGroup _grp;
							diag_log format ["GARSORTIE|SPAWNFAIL|town=%1|reason=no_units", (_town getVariable ["name","?"])];
						};
					};
					} else {
						diag_log format ["GARSORTIE|SPAWNSKIP|town=%1|reason=water", (_town getVariable ["name","?"])];
					};
				};
			};
		};
	} forEach towns;

	if !(isNil "PerformanceAudit_Record") then {
		["garrison_sortie_cycle", diag_tickTime - _perfStart, Format["towns:%1;active:%2;cap:%3", count towns, count _sorties, _maxActive], "SERVER"] Call PerformanceAudit_Record;
	};
};
