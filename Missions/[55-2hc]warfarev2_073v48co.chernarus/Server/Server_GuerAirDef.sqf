/*
	Server_GuerAirDef.sqf — GUER "Insurgents" AIR DEFENSE loop (SERVER-only). B61 (Ray 2026-06-21).

	GUER has NO AI commander (so no wildcard deck) — any GUER air must be a STANDALONE server loop.
	Shape/guards modelled on Server\Server_GuerStipend.sqf; self-clean modelled on the W13 GUNSHIP
	STRIKE block in Server\Functions\AI_Commander_Wildcard.sqf (~L871).

	Ray's spec:
	  - A Ka-137 is USUALLY present over an ACTIVE GUER-held town (each active GUER town gets one,
	    up to a global alive cap).
	  - ~20% of spawned Ka-137s use the EASA AT loadout (Konkurs/AT-5) instead of the recon MG.
	  - For a LARGE GUER town that is under attack (enemies present), a 25% roll fields a Mi-24_P
	    gunship instead of the Ka-137.

	MAINTAIN (not one-shot): every WFBE_C_GUER_AIRDEF_INTERVAL (~120s) it
	  1. prunes dead/destroyed defenders (decrementing the alive count),
	  2. despawns a town's air when the town is no longer GUER-held / no longer active /
	     no enemies for WFBE_C_GUER_AIRDEF_QUIET_DESPAWN seconds / lifetime exceeded,
	  3. spawns a fresh defender for any active GUER town that lacks a live one, while under
	     the global alive cap WFBE_C_GUER_AIRDEF_MAX.
	Every spawned airframe gets an immediate AIPatrol + COMBAT/RED order over its town (NEVER idle).
	Defenders are tagged wfbe_guer_airdef and carry their town; crew+hull+group are deleted on
	despawn (W13 pattern). Nothing is wfbe_persistent, so it can't accumulate.

	EASA AT method (resolved): EASA_Init.sqf runs CLIENT-ONLY (Client\Init\Init_Client.sqf), so
	WFBE_EASA_Loadouts / WFBE_EASA_Vehicles are NOT present in the server's missionNamespace and the
	client EASA_Equip path is unusable here. We therefore apply the AT loadout directly on the server
	using the EXACT classnames from the Ka-137 EASA AT entry (EASA_Init.sqf ~L678:
	[['AT5Launcher','57mmLauncher'],['5Rnd_AT5_BRDM2','64Rnd_57mm']]). The Ka-137 fires from its
	MainTurret, so — exactly like EASA_Equip.sqf's Ka137_MG_PMC special case — weapons/mags go on the
	turret (path [-1]); we first strip the default PKT MG so it is a true swap.

	A2 OA 1.64 safe: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/worldSize; typeName==,
	count, forEach, select floor(random count); getPos guarded behind !isNull.
*/
if !(isServer) exitWith {};
//--- B62 (Ray 2026-06-21): DROPPED the WFBE_C_GUER_PLAYERSIDE<1 self-guard. This loop keys
//--- entirely off town sideID==WFBE_C_GUER_ID(2)+wfbe_active, so GUER-as-AI-defender air must
//--- run regardless of whether GUER is the playable side. Keep only isServer + AIRDEF_ENABLE.
if ((missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_ENABLE", 1]) < 1) exitWith {};

private ["_interval","_maxAir","_atChance","_mi24Chance","_classKa","_classMi24","_lifetime","_quiet","_largeSV","_flyHeight","_pilotClass","_crewClass","_defenders"];

_interval   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_INTERVAL", 120];
_maxAir     = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MAX", 4];
_atChance   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_AT_CHANCE", 0.20];
_mi24Chance = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MI24_CHANCE", 0.25];
_classKa    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_KA", "Ka137_MG_PMC"];
_classMi24  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_MI24", "Mi24_P"];
_lifetime   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LIFETIME", 900];
_quiet      = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_QUIET_DESPAWN", 300];
_largeSV    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LARGE_SV", 2500];
_flyHeight  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_HEIGHT", 120];

//--- Wait for towns + the GUER side logic to exist, then let town ownership settle (mirror of GuerStipend).
waitUntil {
	(!isNil "towns") && {(count towns) > 0}
	&& {!isNil "WFBE_L_GUE"} && {!(isNull (missionNamespace getVariable ["WFBE_L_GUE", objNull]))}
};
sleep 45;

_pilotClass = missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"];
_crewClass  = missionNamespace getVariable ["WFBE_GUERRESCREW",  "GUE_Soldier_Crew"];

//--- Live registry of defenders. Each entry: [_town, _vehicle, _group, _spawnTime, _lastEnemyTime].
//--- Script-local (NOT wfbe_persistent) so it can't outlive a despawn / leak groups.
_defenders = [];

["INITIALIZATION", Format ["Server_GuerAirDef.sqf: GUER air defense started (interval=%1 cap=%2 atChance=%3 mi24Chance=%4).", _interval, _maxAir, _atChance, _mi24Chance]] Call WFBE_CO_FNC_LogContent;
diag_log format ["GUERAIRDEF|START|interval=%1|cap=%2|atChance=%3|mi24Chance=%4|ka=%5|mi24=%6", _interval, _maxAir, _atChance, _mi24Chance, _classKa, _classMi24];

while {!WFBE_GameOver} do {
	sleep _interval;

	private ["_now","_kept","_townsWithAir","_aliveCount"];
	_now = time;

	//=== (1) PRUNE + (2) SELF-CLEAN ==========================================================
	//--- Rebuild the registry, dropping anything that is dead/destroyed or should be despawned.
	_kept         = [];
	_townsWithAir = [];
	{
		private ["_entry","_eTown","_eVeh","_eGrp","_eSpawn","_eLastEnemy","_drop","_reason","_enemiesNow","_townSide","_townActive"];
		_entry      = _x;
		_eTown      = _entry select 0;
		_eVeh       = _entry select 1;
		_eGrp       = _entry select 2;
		_eSpawn     = _entry select 3;
		_eLastEnemy = _entry select 4;

		_drop   = false;
		_reason = "";

		//--- (1) Destroyed / despawned hull => prune (frees the slot).
		if (isNull _eVeh || {!(alive _eVeh)}) then { _drop = true; _reason = "destroyed"; };

		//--- (2) Town no longer GUER-held or no longer active => recall.
		if (!_drop) then {
			_townSide   = if (isNull _eTown) then {-1} else {_eTown getVariable ["sideID", -1]};
			_townActive = if (isNull _eTown) then {false} else {_eTown getVariable ["wfbe_active", false]};
			if (_townSide != WFBE_C_GUER_ID) then { _drop = true; _reason = "town_lost"; };
			if (!_drop && !_townActive) then { _drop = true; _reason = "town_inactive"; };
		};

		//--- Refresh last-enemy timestamp (enemies of GUER = west + east near the town).
		if (!_drop && !(isNull _eTown)) then {
			_enemiesNow = {alive _x && {((side _x) == west) || {(side _x) == east}} && {(_x distance _eTown) < ((_eTown getVariable ["range", 600]) max 600)}} count allUnits;
			if (_enemiesNow > 0) then { _eLastEnemy = _now; };
		};

		//--- (2) Quiet too long (no enemies for _quiet seconds) => recall.
		if (!_drop && {(_now - _eLastEnemy) > _quiet}) then { _drop = true; _reason = "quiet"; };

		//--- (2) Lifetime exceeded => forced recycle (anti-accumulation).
		if (!_drop && {(_now - _eSpawn) > _lifetime}) then { _drop = true; _reason = "lifetime"; };

		if (_drop) then {
			//--- W13 self-clean: crew + hull + group.
			if (!isNull _eVeh) then { {deleteVehicle _x} forEach (crew _eVeh); deleteVehicle _eVeh; };
			if (!isNull _eGrp) then { {deleteVehicle _x} forEach (units _eGrp); deleteGroup _eGrp; };
			diag_log format ["GUERAIRDEF|DESPAWN|town=%1|reason=%2|alive=%3", (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}), _reason, (count _kept)];
		} else {
			_kept         = _kept + [[_eTown, _eVeh, _eGrp, _eSpawn, _eLastEnemy]];
			_townsWithAir = _townsWithAir + [_eTown];
		};
	} forEach _defenders;
	_defenders  = _kept;
	_aliveCount = count _defenders;

	//=== (3) MAINTAIN: spawn one defender per active GUER town that lacks live air ============
	{
		private ["_town","_pos","_enemies","_isLarge","_townType","_maxSV","_useMi24","_class","_useAT","_grp","_veh","_pilot","_gunner","_spawnPos","_ang","_loadName"];
		_town = _x;

		if (_aliveCount < _maxAir
			&& {!(isNull _town)}
			&& {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}
			&& {_town getVariable ["wfbe_active", false]}
			&& {!(_town in _townsWithAir)}) then {

			_pos = getPos _town;

			//--- Enemies near the town (west + east, GUER's foes).
			_enemies = {alive _x && {((side _x) == west) || {(side _x) == east}} && {(_x distance _town) < ((_town getVariable ["range", 600]) max 600)}} count allUnits;

			//--- LARGE-town test: by maxSupplyValue threshold OR by town_type tier (Large/Huge).
			_maxSV    = _town getVariable ["maxSupplyValue", 0];
			_townType = _town getVariable ["wfbe_town_type", ""];
			_isLarge  = (_maxSV >= _largeSV)
				|| {(_townType == "LargeTown1") || {(_townType == "LargeTown2") || {(_townType == "HugeTown1") || {_townType == "HugeTown2"}}}};

			//--- Mi-24 only when the town is LARGE AND under attack AND the 25% roll passes.
			_useMi24 = false;
			if (_isLarge && {_enemies > 0} && {(random 1) < _mi24Chance}) then { _useMi24 = true; };

			_class = if (_useMi24) then {_classMi24} else {_classKa};

			//--- 20% AT loadout roll (Ka-137 only; the Mi-24 is already an AT gunship by config).
			_useAT = false;
			if (!_useMi24 && {(random 1) < _atChance}) then { _useAT = true; };

			//--- Spawn the airframe airborne, a short way off the town so it flies in (FLY special, like W13).
			_ang      = random 360;
			_spawnPos = [(_pos select 0) + 900 * (sin _ang), (_pos select 1) + 900 * (cos _ang), _flyHeight + 60];
			_veh = [_class, _spawnPos, resistance, _ang, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;

			if (!isNull _veh) then {
				_grp = [resistance, "guer-airdef"] Call WFBE_CO_FNC_CreateGroup;
				if (!isNull _grp) then {
					//--- Pilot (driver) always; gunner too for BOTH airframes (manned turret).
					//--- B62 (Ray 2026-06-21): the Ka-137 MainTurret is GUNNER-fired (recon MG or the
					//--- swapped AT-5 set), so a pilot-only Ka-137 flies but never engages. Add a gunner
					//--- for the Ka-137 path too, exactly like the Mi-24 path (WFBE_GUERRESCREW). Teardown
					//--- below already deletes ALL crew, so the extra crewman is cleaned on despawn.
					_pilot = [_pilotClass, _grp, _spawnPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
					if (!isNull _pilot) then {
						_pilot moveInDriver _veh;
						_gunner = [_crewClass, _grp, _spawnPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _gunner) then { _gunner moveInGunner _veh; };

						//--- Apply the EASA AT loadout to the Ka-137 (server-side turret swap; see header).
						//--- Strip the default recon MG (PKT/100Rnd_762x54_PKT) then add the AT-5 set, using the
						//--- SAME turret-path [-1] remove/add commands EASA_RemoveLoadout.sqf uses for Ka137_MG_PMC.
						_loadName = "default";
						if (_useAT) then {
							{_veh removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
							{_veh removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
							{_veh addMagazineTurret [_x, [-1]]} forEach ["5Rnd_AT5_BRDM2","64Rnd_57mm"];
							{_veh addWeaponTurret  [_x, [-1]]} forEach ["AT5Launcher","57mmLauncher"];
							_loadName = "AT5";
						};

						//--- Tag for the maintain/clean sweeps and live identification.
						_veh setVariable ["wfbe_guer_airdef", true, true];
						_veh setVariable ["wfbe_guer_airdef_town", _town];

						//--- NEVER idle: immediate patrol + COMBAT/RED over the town.
						_veh flyInHeight _flyHeight;
						_grp setBehaviour "COMBAT";
						_grp setCombatMode "RED";
						_grp setSpeedMode "NORMAL";
						[_grp, _pos, ((_town getVariable ["range", 600]) max 400)] Call AIPatrol;

						_defenders  = _defenders + [[_town, _veh, _grp, time, time]];
						_townsWithAir = _townsWithAir + [_town];
						_aliveCount = _aliveCount + 1;

						diag_log format ["GUERAIRDEF|SPAWN|town=%1|class=%2|load=%3|mi24=%4|enemies=%5|large=%6|alive=%7", (_town getVariable ["name","?"]), _class, _loadName, _useMi24, _enemies, _isLarge, _aliveCount];
					} else {
						//--- No pilot: tear down the empty hull + group so nothing leaks.
						deleteVehicle _veh;
						if (!isNull _grp) then {deleteGroup _grp};
						diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_pilot", (_town getVariable ["name","?"]), _class];
					};
				} else {
					deleteVehicle _veh;
					diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_group", (_town getVariable ["name","?"]), _class];
				};
			} else {
				diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=createVehicle_null", (_town getVariable ["name","?"]), _class];
			};
		};
	} forEach towns;
};
