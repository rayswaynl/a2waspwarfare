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
	  - CARGO/PARADROP variant (build83): when a GUER town is under GROUND attack (enemy infantry/
	    vehicles near, NOT just air), an 18% roll makes the Ka-137 (a DRONE, no cargo) fly toward the
	    town and then SCRIPT-spawn a stick of WFBE_C_GUER_AIRDEF_DROP_COUNT (5) GUER infantry under
	    parachutes near the town. Priority is AFTER the AA counter-air branch (air threats trump a
	    ground reinforcement drop). The dropped squad is tracked in a SEPARATE registry that obeys the
	    SAME alive-cap / lifetime / quiet-despawn / tag / marker rules as the air, so it can't be spammed.

	MAINTAIN (not one-shot): every WFBE_C_GUER_AIRDEF_INTERVAL (~120s) it
	  1. prunes dead/destroyed defenders (decrementing the alive count),
	  2. despawns a town's air when the town is no longer GUER-held / no longer active /
	     no enemies for WFBE_C_GUER_AIRDEF_QUIET_DESPAWN seconds / lifetime exceeded,
	  3. spawns a fresh defender for any active GUER town that lacks a live one, while under
	     the global alive cap WFBE_C_GUER_AIRDEF_MAX.
	Every spawned airframe gets an immediate AIPatrol + COMBAT/RED order over its town (NEVER idle).
	Defenders are tagged wfbe_guer_airdef and carry their town; crew+hull+group are deleted on
	despawn (W13 pattern). Nothing is wfbe_persistent, so it can't accumulate.

	Optional cmdcon43 Avenger SAM ambush: when WFBE_C_AVENGER_SAM_AMBUSH is enabled, the same
	maintain loop watches ACTIVE WEST-held towns for enemy EAST/GUER aircraft and spawns one
	crewed HMMWV_Avenger_DES_EP1 near the town for a short defensive window. It has its own
	registry/cap/quiet-despawn path and is default-OFF.

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

private ["_interval","_maxAir","_atChance","_mi24Chance","_aaChance","_classKa","_classMi24","_lifetime","_quiet","_largeSV","_flyHeight","_pilotClass","_crewClass","_defenders","_dropChance","_dropCount","_dropMax","_drops","_swarmOn","_swarmChance","_swarmChance3","_flareOn","_flareMin","_flareMax","_flareLauncher","_flareMag","_applyKaFlares","_samOn","_samChance","_samMax","_samLifetime","_samQuiet","_samRange","_samClass","_samCrewClass","_samAmbushes"];

_interval   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_INTERVAL", 120];
_maxAir     = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MAX", 4];
_atChance   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_AT_CHANCE", 0.20];
_mi24Chance = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MI24_CHANCE", 0.25];
_aaChance   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_AA_CHANCE", 0.75];
_classKa    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_KA", "Ka137_MG_PMC"];
_classMi24  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_MI24", "Mi24_P"];
_lifetime   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LIFETIME", 900];
_quiet      = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_QUIET_DESPAWN", 300];
_largeSV    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LARGE_SV", 2500];
_flyHeight  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_HEIGHT", 120];

//--- CARGO/PARADROP variant (build83). DROP_CHANCE: per-spawn roll for the Ka-137 to run a paradrop of
//--- infantry over a town under GROUND attack. DROP_COUNT: troopers per stick. DROP_MAX: global alive cap
//--- on dropped squads (a SEPARATE cap from the airframe cap so a paradrop can't crowd out the air, and so
//--- ground reinforcements themselves can't be spammed). All keyed off missionNamespace so the parent adds
//--- the Init_CommonConstants definitions; inline defaults ship a sane no-constant fallback.
_dropChance = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_DROP_CHANCE", 0.18];
_dropCount  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_DROP_COUNT", 5];
_dropMax    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_DROP_MAX", 2];

//--- KA-137 SWARM ROLL (cmdcon42, Ray 2026-07-02): when a COMBAT Ka-137 is fielded (recon-MG / AT / AA — NOT
//--- the paradrop delivery bird, NOT the Mi-24), roll for it to be MORE THAN ONE. Extras are created into the
//--- SAME group (the group slot is already paid) so they formation-fly as a drone flock and inherit the leader's
//--- patrol/engage orders. SWARM = master switch; CHANCE = roll for a 2nd drone; CHANCE3 = roll (only if the 2nd
//--- rolled) for a 3rd. Extras COUNT toward the global _maxAir alive-cap and each is registered as its own
//--- registry entry (own hull, shared group) so the prune/self-clean sweep tears each one down like the leader.
_swarmOn     = missionNamespace getVariable ["WFBE_C_GUER_KA137_SWARM", 1];
_swarmChance = missionNamespace getVariable ["WFBE_C_GUER_KA137_SWARM_CHANCE", 0.25];
_swarmChance3= missionNamespace getVariable ["WFBE_C_GUER_KA137_SWARM_CHANCE3", 0.15];

//--- KA-137 FLARE STOCK (cmdcon42 item2, Ray 2026-07-02; retuned same day): give each AI-spawned Ka-137 (leader +
//--- swarm extras) a CHANCE-BASED countermeasure budget of FLARES_MIN..FLARES_MAX (default 5-20 — a deliberate
//--- variance-NERF vs the flat CM_Set default of 32). Build86 flipped WFBE_C_MODULE_AUTO_CM_OA ON: the auto-CM
//--- module (Client\Module\CM\CM_AutoCM_OA.sqf) fires on the "incomingMissile" EH and consumes an INTEGER budget
//--- stored as the vehicle variable "FlareCount" (createVehicleLocal "FlareCountermeasure" per shot; NOT a magazine
//--- burn), so a partial budget like 13 is expressed EXACTLY as setVariable ["FlareCount", 13] — no magazine
//--- rounding. WFBE_CO_FNC_CreateVehicle already broadcasts Init_Unit.sqf (global=true) which adds the auto-CM EH
//--- and a DEFAULT FlareCount via CM_Set.sqf, so here we OVERRIDE that default with the rolled stock (public
//--- setVariable so it is authoritative on whichever machine owns the hull/EH). We ALSO mount the manual OA flare
//--- launcher + one flare magazine (same CMFlareLauncher / 60Rnd_CMFlareMagazine idiom as the player Ka-137 in
//--- Client_BuildUnit.sqf) so the hull additionally has native manual flares. CM_Set.sqf does waitUntil
//--- commonInitComplete + sleep 2 before writing its default, so we stamp the rolled budget from a short deferred
//--- spawn (sleep 3) to deterministically WIN that race. FLARES = master switch (default 1); MIN/MAX = roll bounds
//--- so future retunes are config-only (MAX is clamped up to MIN so a bad config can never make random negative).
_flareOn       = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARES", 1];
_flareMin      = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARES_MIN", 5];
_flareMax      = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARES_MAX", 20];
if (_flareMax < _flareMin) then { _flareMax = _flareMin; }; //--- guard MAX>=MIN (degenerates to a fixed MIN stock).
_flareLauncher = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_LAUNCHER", "CMFlareLauncher"];
_flareMag      = "60Rnd_CMFlareMagazine"; //--- smallest OA flare mag (A2-OA has no 30Rnd); manual-flare backing for the launcher. The MIN-MAX AUTO budget is the FlareCount integer, independent of this mag's round count.

//--- AVENGER SAM AMBUSH (cmdcon43, default OFF). WEST-owned town mirror of the GUER counter-air branch:
//--- enemy EAST/GUER aircraft near an active WEST town can pull one scripted Avenger for a short window.
_samOn       = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH", 0];
_samChance   = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_CHANCE", 1];
_samMax      = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_MAX", 2];
_samLifetime = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_LIFETIME", 600];
_samQuiet    = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_QUIET_DESPAWN", 180];
_samRange    = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_RANGE", 900];
_samClass    = missionNamespace getVariable ["WFBE_C_AVENGER_SAM_AMBUSH_CLASS", "HMMWV_Avenger_DES_EP1"];
if (_samChance < 0) then {_samChance = 0};
if (_samChance > 1) then {_samChance = 1};
if (_samMax < 0) then {_samMax = 0};

//--- Wait for towns + the GUER side logic to exist, then let town ownership settle (mirror of GuerStipend).
waitUntil {
	(!isNil "towns") && {(count towns) > 0}
	&& {!isNil "WFBE_L_GUE"} && {!(isNull (missionNamespace getVariable ["WFBE_L_GUE", objNull]))}
};
sleep 45;

_pilotClass = missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"];
_crewClass  = missionNamespace getVariable ["WFBE_GUERRESCREW",  "GUE_Soldier_Crew"];
_samCrewClass = missionNamespace getVariable ["WFBE_WESTCREW", "US_Soldier_Crew_EP1"];

//--- FLARE-STOCK applicator (shared by the leader + each swarm extra). _this = [_vehicle]. Rolls a flare budget
//--- of _flareMin.._flareMax (default 5-20), mounts the manual OA launcher + a flare mag on the turret (path [-1],
//--- same idiom the player Ka-137 uses in Client_BuildUnit.sqf), and stamps the rolled budget as the PUBLIC
//--- "FlareCount" integer that the auto-CM module consumes. Returns the rolled count (0 = disabled). Runs on the
//--- server, where these AI hulls are local. The FlareCount write is deferred (sleep 3) so it lands AFTER
//--- CM_Set.sqf's default write.
_applyKaFlares = {
	private ["_v","_n"];
	_v = _this select 0;
	_n = 0;
	if (_flareOn >= 1 && {!isNull _v}) then {
		_n = _flareMin + floor(random (_flareMax - _flareMin + 1)); //--- MIN..MAX inclusive (MAX>=MIN guarded above).
		//--- Mount the manual OA launcher + one flare mag (turret path [-1], as the Ka-137 fires from MainTurret).
		{_v addMagazineTurret [_x, [-1]]} forEach [_flareMag];
		{_v addWeaponTurret  [_x, [-1]]} forEach [_flareLauncher];
		//--- Public FlareCount = the AUTO-CM budget the module decrements. Deferred so it beats CM_Set's default.
		[_v, _n] Spawn {
			private ["_veh","_cnt"];
			_veh = _this select 0; _cnt = _this select 1;
			sleep 3;
			if (!isNull _veh) then { _veh setVariable ["FlareCount", _cnt, true]; };
		};
	};
	_n
};

//--- Live registry of defenders. Each entry: [_town, _vehicle, _group, _spawnTime, _lastEnemyTime].
//--- Script-local (NOT wfbe_persistent) so it can't outlive a despawn / leak groups.
_defenders = [];

//--- Live registry of PARADROPPED squads (build83). Each entry: [_town, _group, _spawnTime, _lastEnemyTime].
//--- Same shape/rules as _defenders but for the infantry stick from the CARGO/PARADROP variant. Script-local
//--- (NOT wfbe_persistent) so a dropped squad can never leak groups or outlive its despawn. Separate cap
//--- (_dropMax) and separate prune pass below keep it from being spammed exactly like the air branches.
_drops = [];

//--- Live registry of optional WEST Avenger SAM ambushes. Each entry:
//--- [_town, _vehicle, _group, _spawnTime, _lastEnemyAirTime].
_samAmbushes = [];

["INITIALIZATION", Format ["Server_GuerAirDef.sqf: GUER air defense started (interval=%1 cap=%2 atChance=%3 mi24Chance=%4).", _interval, _maxAir, _atChance, _mi24Chance]] Call WFBE_CO_FNC_LogContent;
diag_log format ["GUERAIRDEF|START|interval=%1|cap=%2|atChance=%3|mi24Chance=%4|aaChance=%5|ka=%6|mi24=%7|dropChance=%8|dropCount=%9|dropMax=%10", _interval, _maxAir, _atChance, _mi24Chance, _aaChance, _classKa, _classMi24, _dropChance, _dropCount, _dropMax];
if (_samOn >= 1) then {
	["INITIALIZATION", Format ["Server_GuerAirDef.sqf: Avenger SAM ambush enabled (class=%1 cap=%2 chance=%3 range=%4).", _samClass, _samMax, _samChance, _samRange]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["AVENGERSAM|START|class=%1|cap=%2|chance=%3|range=%4|lifetime=%5|quiet=%6|crew=%7", _samClass, _samMax, _samChance, _samRange, _samLifetime, _samQuiet, _samCrewClass];
};

//--- B67 (Ray 2026-06-21): publish the GUER-air list for the client map-marker loop (updatepatrolmarkers.sqf
//--- reads WFBE_ACTIVE_GUER_AIR = [[vehicle, sideID], ...]). Init empty + broadcast so a JIP client never sees
//--- nil; rebuilt + re-broadcast every interval below; targeted JIP catch-up in Server_OnPlayerConnected.sqf.
WFBE_ACTIVE_GUER_AIR = [];
publicVariable "WFBE_ACTIVE_GUER_AIR";

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
			//--- B66: isPlayer despawn guard. GUER is playable now, so a player could be
			//--- crewing/occupying a defender hull or its group. NEVER deleteVehicle a player.
			//--- If ANY crew member is a player, skip the hull teardown entirely (leave the air
			//--- for the player; the registry entry is dropped either way so the maintain sweep
			//--- stops tracking it). Group teardown only deletes non-player units.
			//--- W13 self-clean: crew + hull + group (player-safe).
			if (!isNull _eVeh && {({isPlayer _x} count (crew _eVeh)) == 0}) then { {deleteVehicle _x} forEach (crew _eVeh); deleteVehicle _eVeh; };
			if (!isNull _eGrp) then { {if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _eGrp); deleteGroup _eGrp; };
			diag_log format ["GUERAIRDEF|DESPAWN|town=%1|reason=%2|alive=%3", (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}), _reason, (count _kept)];
		} else {
			_kept         = _kept + [[_eTown, _eVeh, _eGrp, _eSpawn, _eLastEnemy]];
			_townsWithAir = _townsWithAir + [_eTown];
		};
	} forEach _defenders;
	_defenders  = _kept;
	_aliveCount = count _defenders;

	//=== (1b) PRUNE + SELF-CLEAN the PARADROPPED squads (build83) =============================
	//--- Same lifecycle as the air: drop a squad when it is wiped out, its town is lost/inactive,
	//--- it has been quiet too long, or it has outlived _lifetime. Player-safe teardown: never
	//--- deleteVehicle a player-occupied body (GUER is playable). Keeps the ground drop from
	//--- accumulating exactly like the air alive-cap keeps the air from accumulating.
	private ["_keptDrops","_dropAlive"];
	_keptDrops = [];
	{
		private ["_dEntry","_dTown","_dGrp","_dSpawn","_dLastEnemy","_dDrop","_dReason","_dLiving","_dEnemiesNow","_dTownSide","_dTownActive"];
		_dEntry     = _x;
		_dTown      = _dEntry select 0;
		_dGrp       = _dEntry select 1;
		_dSpawn     = _dEntry select 2;
		_dLastEnemy = _dEntry select 3;

		_dDrop   = false;
		_dReason = "";

		//--- Squad wiped out (no living units left in the group) => prune.
		_dLiving = if (isNull _dGrp) then {0} else {{alive _x} count (units _dGrp)};
		if (isNull _dGrp || {_dLiving == 0}) then { _dDrop = true; _dReason = "wiped"; };

		//--- Town no longer GUER-held or no longer active => recall.
		if (!_dDrop) then {
			_dTownSide   = if (isNull _dTown) then {-1} else {_dTown getVariable ["sideID", -1]};
			_dTownActive = if (isNull _dTown) then {false} else {_dTown getVariable ["wfbe_active", false]};
			if (_dTownSide != WFBE_C_GUER_ID) then { _dDrop = true; _dReason = "town_lost"; };
			if (!_dDrop && !_dTownActive) then { _dDrop = true; _dReason = "town_inactive"; };
		};

		//--- Refresh last-enemy timestamp (west + east near the town).
		if (!_dDrop && !(isNull _dTown)) then {
			_dEnemiesNow = {alive _x && {((side _x) == west) || {(side _x) == east}} && {(_x distance _dTown) < ((_dTown getVariable ["range", 600]) max 600)}} count allUnits;
			if (_dEnemiesNow > 0) then { _dLastEnemy = _now; };
		};

		//--- Quiet too long / lifetime exceeded => recall (anti-accumulation).
		if (!_dDrop && {(_now - _dLastEnemy) > _quiet}) then { _dDrop = true; _dReason = "quiet"; };
		if (!_dDrop && {(_now - _dSpawn) > _lifetime}) then { _dDrop = true; _dReason = "lifetime"; };

		if (_dDrop) then {
			//--- Player-safe teardown: only delete non-player bodies; then drop the group.
			if (!isNull _dGrp) then { {if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _dGrp); deleteGroup _dGrp; };
			diag_log format ["GUERAIRDEF|DROPDESPAWN|town=%1|reason=%2|dropsAlive=%3", (if (isNull _dTown) then {"?"} else {_dTown getVariable ["name","?"]}), _dReason, (count _keptDrops)];
		} else {
			_keptDrops = _keptDrops + [[_dTown, _dGrp, _dSpawn, _dLastEnemy]];
		};
	} forEach _drops;
	_drops     = _keptDrops;
	_dropAlive = count _drops;

	//=== (1c) PRUNE + SELF-CLEAN optional WEST Avenger SAM ambushes ============================
	private ["_samKept","_samAlive","_samTowns"];
	_samKept = [];
	_samTowns = [];
	{
		private ["_sEntry","_sTown","_sVeh","_sGrp","_sSpawn","_sLastEnemy","_sDrop","_sReason","_sTownSide","_sTownActive","_sEnemyAirNow","_sScanRange"];
		_sEntry     = _x;
		_sTown      = _sEntry select 0;
		_sVeh       = _sEntry select 1;
		_sGrp       = _sEntry select 2;
		_sSpawn     = _sEntry select 3;
		_sLastEnemy = _sEntry select 4;

		_sDrop   = false;
		_sReason = "";

		if (isNull _sVeh || {!(alive _sVeh)}) then { _sDrop = true; _sReason = "destroyed"; };

		if (!_sDrop) then {
			_sTownSide   = if (isNull _sTown) then {-1} else {_sTown getVariable ["sideID", -1]};
			_sTownActive = if (isNull _sTown) then {false} else {_sTown getVariable ["wfbe_active", false]};
			if (_sTownSide != WFBE_C_WEST_ID) then { _sDrop = true; _sReason = "town_lost"; };
			if (!_sDrop && !_sTownActive) then { _sDrop = true; _sReason = "town_inactive"; };
		};

		//--- Refresh last-air timestamp. WEST's air foes here are EAST and GUER/resistance aircraft.
		if (!_sDrop && !(isNull _sTown)) then {
			_sScanRange = ((_sTown getVariable ["range", 600]) max _samRange);
			_sEnemyAirNow = {alive _x && {_x isKindOf "Air"} && {((side _x) == east) || {(side _x) == resistance}} && {(_x distance _sTown) < _sScanRange}} count vehicles;
			if (_sEnemyAirNow > 0) then { _sLastEnemy = _now; };
		};

		if (!_sDrop && {(_now - _sLastEnemy) > _samQuiet}) then { _sDrop = true; _sReason = "quiet"; };
		if (!_sDrop && {(_now - _sSpawn) > _samLifetime}) then { _sDrop = true; _sReason = "lifetime"; };

		if (_sDrop) then {
			//--- Player-safe teardown: a player who steals/boards the Avenger keeps it; the registry just lets go.
			if (!isNull _sVeh && {({isPlayer _x} count (crew _sVeh)) == 0}) then { {deleteVehicle _x} forEach (crew _sVeh); deleteVehicle _sVeh; };
			if (!isNull _sGrp) then { {if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _sGrp); deleteGroup _sGrp; };
			diag_log format ["AVENGERSAM|DESPAWN|town=%1|reason=%2|alive=%3", (if (isNull _sTown) then {"?"} else {_sTown getVariable ["name","?"]}), _sReason, (count _samKept)];
		} else {
			_samKept = _samKept + [[_sTown, _sVeh, _sGrp, _sSpawn, _sLastEnemy]];
			_samTowns = _samTowns + [_sTown];
		};
	} forEach _samAmbushes;
	_samAmbushes = _samKept;
	_samAlive = count _samAmbushes;

	//=== (3) MAINTAIN: spawn one defender per active GUER town that lacks live air ============
	{
		private ["_town","_pos","_enemies","_enemyAir","_isLarge","_townType","_maxSV","_useMi24","_useAA","_class","_useAT","_useDrop","_townHasDrop","_grp","_veh","_pilot","_gunner","_spawnPos","_ang","_loadName","_swarmN","_swarmI","_swarmMade","_eAng","_ePos","_eVeh2","_ePilot","_eGunner","_flareN","_eFlareN"];
		_town = _x;

		if (_aliveCount < _maxAir
			&& {!(isNull _town)}
			&& {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}
			&& {_town getVariable ["wfbe_active", false]}
			&& {!(_town in _townsWithAir)}) then {

			_pos = getPos _town;

			//--- Enemies near the town (west + east, GUER's foes).
			_enemies = {alive _x && {((side _x) == west) || {(side _x) == east}} && {(_x distance _town) < ((_town getVariable ["range", 600]) max 600)}} count allUnits;

			//--- Enemy AIR near the town (crewed west/east aircraft) - the counter-air trigger. Scanned over
			//--- `vehicles` (hull objects); side comes from the crewed hull, so an empty parked heli reads CIV
			//--- and is ignored (only manned attackers pull a SAM-heli response).
			_enemyAir = {alive _x && {_x isKindOf "Air"} && {((side _x) == west) || {(side _x) == east}} && {(_x distance _town) < ((_town getVariable ["range", 600]) max 600)}} count vehicles;

			//--- LARGE-town test: by maxSupplyValue threshold OR by town_type tier (Large/Huge).
			_maxSV    = _town getVariable ["maxSupplyValue", 0];
			_townType = _town getVariable ["wfbe_town_type", ""];
			_isLarge  = (_maxSV >= _largeSV)
				|| {(_townType == "LargeTown1") || {(_townType == "LargeTown2") || {(_townType == "HugeTown1") || {_townType == "HugeTown2"}}}};

			//--- Is there already a live paradropped squad on THIS town? (one drop per town at a time.)
			_townHasDrop = false;
			{ if ((_x select 0) == _town) then { _townHasDrop = true; } } forEach _drops;

			//--- LOADOUT/AIRFRAME SELECTION (priority order):
			//---   1. ENEMY AIR present -> Ka-137 with the EASA Igla AA set (counter-air). Beats everything so
			//---      GUER actually contests hostile air instead of orbiting with an MG it cannot elevate.
			//---   2. else GROUND attack (enemy infantry/vehicles near, NOT air) -> CARGO/PARADROP variant
			//---      (build83): the recon-MG Ka-137 (a DRONE) flies in and SCRIPT-drops a GUER infantry stick
			//---      under parachutes. Gated by _dropChance, the global _dropMax alive-cap and one-per-town so
			//---      it cannot be spammed. Priority AFTER the AA branch as specified.
			//---   3. else LARGE town under ground attack -> Mi-24 gunship (25% roll).
			//---   4. else 20% AT (Konkurs/AT-5) swap on the Ka-137.
			//---   5. else recon MG (default).
			_useMi24 = false; _useAA = false; _useAT = false; _useDrop = false;
			if (_enemyAir > 0 && {(random 1) < _aaChance}) then { _useAA = true; };
			//--- Ground attack = at least one non-air foe near the town. _enemies counts allUnits (infantry +
			//--- crewed vehicle occupants) within range, so _enemies > _enemyAir means a genuine GROUND threat
			//--- (not merely aircraft overhead). Require that so a pure air raid never pulls an infantry drop.
			if (!_useAA
				&& {_enemies > 0}
				&& {(_enemies - _enemyAir) > 0}
				&& {!_townHasDrop}
				&& {_dropAlive < _dropMax}
				&& {(random 1) < _dropChance}) then { _useDrop = true; };
			if (!_useAA && {!_useDrop} && {_isLarge} && {_enemies > 0} && {(random 1) < _mi24Chance}) then { _useMi24 = true; };
			if (!_useAA && {!_useDrop} && {!_useMi24} && {(random 1) < _atChance}) then { _useAT = true; };

			//--- The paradrop variant uses the DEFAULT Ka-137 (drone recon-MG airframe) as the delivery bird.
			_class = if (_useMi24) then {_classMi24} else {_classKa};

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
						//--- Apply the EASA Igla AA loadout (counter-air): strip the recon MG, mount the Igla SAM set.
						//--- EXACT classnames from the Ka-137 EASA AA entry (EASA_Init.sqf ~L679: [['Igla_twice'],['2Rnd_Igla','2Rnd_Igla']]).
						//--- Same turret-path [-1] swap idiom as the AT branch above; _useAA is mutually exclusive with _useAT.
						if (_useAA) then {
							{_veh removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
							{_veh removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
							{_veh addMagazineTurret [_x, [-1]]} forEach ["2Rnd_Igla","2Rnd_Igla"];
							{_veh addWeaponTurret  [_x, [-1]]} forEach ["Igla_twice"];
							_loadName = "IglaAA";
						};
						//--- CARGO/PARADROP variant keeps the DEFAULT recon-MG airframe (drone delivery bird);
						//--- only the log tag changes so the drop is distinguishable in the RPT.
						if (_useDrop) then { _loadName = "cargoDrop"; };

						//--- Tag for the maintain/clean sweeps and live identification.
						_veh setVariable ["wfbe_guer_airdef", true, true];
						_veh setVariable ["wfbe_guer_airdef_town", _town];

						//--- FLARE STOCK (cmdcon42 item2): chance-based MIN-MAX (default 5-20) auto-CM budget on the
						//--- Ka-137 leader (all Ka-137 variants: recon-MG / AT / AA / drop bird). Mi-24 excluded
						//--- (Ka-137-only per spec).
						_flareN = 0;
						if (_class == _classKa) then {
							_flareN = [_veh] Call _applyKaFlares;
							if (_flareN > 0) then {
								["INFORMATION", Format ["Server_GuerAirDef.sqf: KA137_FLARES|n=%1|town=%2|load=%3", _flareN, (_town getVariable ["name","?"]), _loadName]] Call WFBE_CO_FNC_LogContent;
								diag_log format ["GUERAIRDEF|KA137_FLARES|n=%1|town=%2|load=%3", _flareN, (_town getVariable ["name","?"]), _loadName];
							};
						};

						//--- NEVER idle: immediate patrol + COMBAT/RED over the town.
						//--- B66: order fixed. AIPatrol internally re-sets behaviour to AWARE/YELLOW,
						//--- so it MUST run BEFORE the engage posture or it clobbers COMBAT/RED and the
						//--- air just orbits passively. Patrol first, then stamp the engage posture last
						//--- so the defender actually presses attacks.
						_veh flyInHeight _flyHeight;
						[_grp, _pos, ((_town getVariable ["range", 600]) max 400)] Call AIPatrol;
						_grp setBehaviour "COMBAT";
						_grp setCombatMode "RED";
						_grp setSpeedMode "NORMAL";

						_defenders  = _defenders + [[_town, _veh, _grp, time, time]];
						_townsWithAir = _townsWithAir + [_town];
						_aliveCount = _aliveCount + 1;

						//=== KA-137 SWARM ROLL (cmdcon42, Ray 2026-07-02) ===================================
						//--- After the FIRST combat Ka-137 is created + crewed + registered, roll for extra drones
						//--- INTO THE SAME GROUP (_grp) so they formation-fly and inherit the leader's patrol/engage
						//--- orders (set below on the group). Extras are the SAME airframe + crew idiom as the leader
						//--- (copy verbatim: CreateVehicle FLY + pilot + gunner + the SAME loadout swap so extras carry
						//--- the same kit), spawned ~30-50m off the leader (setPos + matching flyInHeight) so they do
						//--- not collide on spawn. SCOPE: combat Ka-137 only (_class == _classKa) and NOT the paradrop
						//--- delivery bird (_useDrop) — the drop bird is a single mission asset whose stick is already
						//--- capped by _dropMax/_dropCount. GUARD: each extra COUNTS toward the global _maxAir alive-cap;
						//--- roll each extra only while _aliveCount < _maxAir so a swarm can never exceed the air budget.
						//--- Each extra is registered as its OWN _defenders entry (own hull, SHARED group) so the
						//--- prune/self-clean sweep tears each hull down exactly like the leader; NO new group is created.
						if (_swarmOn >= 1
							&& {_class == _classKa}
							&& {!_useDrop}
							&& {_aliveCount < _maxAir}
							&& {(random 1) < _swarmChance}) then {

							//--- Decide the flock size up-front: always at least the 2nd (chance already passed); the
							//--- 3rd only if _swarmChance3 also passes AND there is still room under the cap.
							_swarmN = 2;
							if ((_aliveCount + 1) < _maxAir && {(random 1) < _swarmChance3}) then { _swarmN = 3; };

							_swarmMade = 0;
							_swarmI = 2;
							while {_swarmI <= _swarmN && {_aliveCount < _maxAir}} do {
								//--- Same airborne-spawn idiom as the leader, but a short offset off the leader hull so
								//--- the extras do not overlap on spawn (30-50m radial + a little height stagger).
								_eAng = random 360;
								_ePos = [(_spawnPos select 0) + (30 + random 20) * (sin _eAng),
								         (_spawnPos select 1) + (30 + random 20) * (cos _eAng),
								         (_spawnPos select 2) + 15 * _swarmI];
								_eVeh2 = [_class, _ePos, resistance, _ang, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
								if (!isNull _eVeh2) then {
									_ePilot = [_pilotClass, _grp, _ePos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _ePilot) then {
										_ePilot moveInDriver _eVeh2;
										_eGunner = [_crewClass, _grp, _ePos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _eGunner) then { _eGunner moveInGunner _eVeh2; };

										//--- Same loadout swap the leader got (kit parity): AT-5 set, or Igla AA set,
										//--- else the default recon MG. SAME turret-path [-1] remove/add idiom as above.
										if (_useAT) then {
											{_eVeh2 removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
											{_eVeh2 removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
											{_eVeh2 addMagazineTurret [_x, [-1]]} forEach ["5Rnd_AT5_BRDM2","64Rnd_57mm"];
											{_eVeh2 addWeaponTurret  [_x, [-1]]} forEach ["AT5Launcher","57mmLauncher"];
										};
										if (_useAA) then {
											{_eVeh2 removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
											{_eVeh2 removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
											{_eVeh2 addMagazineTurret [_x, [-1]]} forEach ["2Rnd_Igla","2Rnd_Igla"];
											{_eVeh2 addWeaponTurret  [_x, [-1]]} forEach ["Igla_twice"];
										};

										//--- Tag + flyInHeight to match the leader; the group already carries the
										//--- patrol + COMBAT/RED orders (set above), which the extra inherits as a member.
										_eVeh2 setVariable ["wfbe_guer_airdef", true, true];
										_eVeh2 setVariable ["wfbe_guer_airdef_town", _town];
										_eVeh2 flyInHeight _flyHeight;

										//--- FLARE STOCK (cmdcon42 item2): same chance-based MIN-MAX (default 5-20) auto-CM budget
										//--- on each extra (extras are always _classKa). One log line per extra that rolls a stock.
										_eFlareN = [_eVeh2] Call _applyKaFlares;
										if (_eFlareN > 0) then {
											["INFORMATION", Format ["Server_GuerAirDef.sqf: KA137_FLARES|n=%1|town=%2|load=%3|swarmExtra=1", _eFlareN, (_town getVariable ["name","?"]), _loadName]] Call WFBE_CO_FNC_LogContent;
											diag_log format ["GUERAIRDEF|KA137_FLARES|n=%1|town=%2|load=%3|swarmExtra=1", _eFlareN, (_town getVariable ["name","?"]), _loadName];
										};

										//--- Own registry entry (shared group) so prune/self-clean handles each hull.
										_defenders  = _defenders + [[_town, _eVeh2, _grp, time, time]];
										_aliveCount = _aliveCount + 1;
										_swarmMade  = _swarmMade + 1;
									} else {
										//--- No pilot for the extra: tear down the empty hull so nothing leaks (freshly
										//--- created, no player possible). Group is shared/leader-owned — do NOT delete it.
										if (!isNull _eVeh2 && {({isPlayer _x} count (crew _eVeh2)) == 0}) then {deleteVehicle _eVeh2};
									};
								};
								_swarmI = _swarmI + 1;
							};

							//--- One AICOMSTAT/INFORMATION line per swarm that actually fielded extras (n = TOTAL drones
							//--- in the flock incl. leader = 1 + _swarmMade). Only emit when >=1 extra was built (a cap
							//--- edge or create failure can leave _swarmMade at 0 despite the roll passing).
							if (_swarmMade > 0) then {
								["INFORMATION", Format ["Server_GuerAirDef.sqf: KA137_SWARM|n=%1|town=%2|load=%3", (1 + _swarmMade), (_town getVariable ["name","?"]), _loadName]] Call WFBE_CO_FNC_LogContent;
								diag_log format ["GUERAIRDEF|KA137_SWARM|n=%1|town=%2|load=%3|alive=%4", (1 + _swarmMade), (_town getVariable ["name","?"]), _loadName, _aliveCount];
							};
						};

						//=== CARGO/PARADROP variant (build83) ===============================================
						//--- The Ka-137 is a DRONE (no cargo), so we SCRIPT-spawn the reinforcement stick rather
						//--- than eject from cargo. Build the squad group HERE (synchronously) and register it in
						//--- _drops NOW so the alive-cap/lifetime/quiet/one-per-town gates are honoured deterministically;
						//--- the chute-descent + defend orders run in a sub-thread (createUnit + a per-unit chute like
						//--- Support_ParaAmmo.sqf / Support_ParaVehicles.sqf, but moveInDriver the man INTO the chute).
						//--- Reuse the side's already-defined WFBE_GUERPARACHUTELEVEL1 roster + WFBE_GUERPARACHUTE model
						//--- (Root_GUE.sqf: ParachuteC / GUE_* soldiers; TK mirror: ParachuteMediumEast_EP1 / TK_GUE_*),
						//--- so the classnames are guaranteed to exist on BOTH maps.
						if (_useDrop) then {
							private ["_dropGrp","_dropRoster","_dropChute","_registered"];
							_dropGrp    = [resistance, "guer-airdrop"] Call WFBE_CO_FNC_CreateGroup;
							_dropRoster = missionNamespace getVariable ["WFBE_GUERPARACHUTELEVEL1", ["GUE_Soldier_1","GUE_Soldier_AT","GUE_Soldier_2","GUE_Soldier_3","GUE_Soldier_MG","GUE_Soldier_Medic"]];
							_dropChute  = missionNamespace getVariable ["WFBE_GUERPARACHUTE", "ParachuteC"];
							_registered = false;
							if (!isNull _dropGrp && {typeName _dropRoster == "ARRAY"} && {(count _dropRoster) > 0} && {typeName _dropChute == "STRING"} && {_dropChute != ""}) then {
								//--- Register the (still-empty) group immediately so the cap accounts for it this tick;
								//--- the sub-thread fills + drops it. Prune keeps it only while it has living units.
								_drops     = _drops + [[_town, _dropGrp, time, time]];
								_dropAlive = _dropAlive + 1;
								_registered = true;

								[_town, _pos, _dropGrp, _dropRoster, _dropCount, _dropChute, _flyHeight] Spawn {
									private ["_t","_tPos","_g","_roster","_count","_chuteModel","_baseH","_type","_ux","_uy","_uz","_uPos","_u","_chute","_wtr","_built","_ctr","_chutes","_pair","_cu","_cc"];
									_t          = _this select 0;
									_tPos       = _this select 1;
									_g          = _this select 2;
									_roster     = _this select 3;
									_count      = _this select 4;
									_chuteModel = _this select 5;
									_baseH      = _this select 6;

									//--- Let the delivery bird approach the town before troops appear overhead.
									sleep 20;
									if (isNull _g) exitWith {};

									//--- Phase 1: create the whole stick at altitude over the town + chute each man, quickly
									//--- (0.3s apart, like the supply-drop cadence) so the stick descends TOGETHER, not serially.
									//--- Each entry: [unit, chute].
									_chutes = [];
									_built  = 0;
									_ctr    = 0;
									while {_ctr < _count} do {
										//--- Cycle the roster; spawn each trooper a little offset + high over the town so it
										//--- descends under a chute onto the town (A2-OA: createUnit via the mission helper, then
										//--- moveInDriver the man into a freshly-created parachute vehicle at altitude).
										_type = _roster select (_ctr mod (count _roster));
										_ux = (_tPos select 0) + (60 - random 120);
										_uy = (_tPos select 1) + (60 - random 120);
										_uz = _baseH + 40 + random 30;
										_uPos = [_ux, _uy, _uz];

										_u = [_type, _g, _uPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _u) then {
											//--- Per-unit parachute (same createVehicle idiom as Support_ParaAmmo.sqf L71-72),
											//--- but a MAN goes in as DRIVER of the chute (engine-standard for a chuted soldier).
											_chute = _chuteModel createVehicle [0,0,20];
											_chute setPos [_ux, _uy, _uz];
											_u moveInDriver _chute;
											_chutes = _chutes + [[_u, _chute]];
											_built = _built + 1;
										};
										_ctr = _ctr + 1;
										sleep 0.3;
									};

									//--- Phase 2: single combined descent wait. Bail after ~75s (a chute may snag), so the
									//--- thread can never hang. Cleared each tick: once every man is down (or dead) we stop.
									_wtr = 0;
									waitUntil {
										sleep 1;
										_wtr = _wtr + 1;
										private ["_stillUp"];
										_stillUp = 0;
										{
											_cu = _x select 0; _cc = _x select 1;
											if (!isNull _cu && {alive _cu} && {!isNull _cc} && {(getPos _cu select 2) >= 3}) then { _stillUp = _stillUp + 1; };
										} forEach _chutes;
										(_stillUp == 0) || {_wtr > 75}
									};

									//--- Phase 3: dismount + clean every chute (leave the troopers on the ground).
									{
										_cu = _x select 0; _cc = _x select 1;
										if (!isNull _cu && {alive _cu} && {!isNull _cc}) then { _cu action ["getOut", _cc]; };
										if (!isNull _cc) then { deleteVehicle _cc; };
									} forEach _chutes;

									//--- Order the landed squad to hold/defend the town: patrol first (it re-sets AWARE/YELLOW),
									//--- then stamp COMBAT/RED last so they actually engage the attackers (same order fix as the air).
									if (!isNull _g && {({alive _x} count (units _g)) > 0}) then {
										[_g, _tPos, ((_t getVariable ["range", 600]) max 300)] Call AIPatrol;
										_g setBehaviour "COMBAT";
										_g setCombatMode "RED";
										_g setSpeedMode "NORMAL";
									};

									diag_log format ["GUERAIRDEF|DROP|town=%1|dropped=%2|alive=%3", (_t getVariable ["name","?"]), _built, ({alive _x} count (units _g))];
								};
							} else {
								//--- Could not stand up the squad group/roster/chute -> abandon the drop cleanly.
								if (!isNull _dropGrp) then { deleteGroup _dropGrp; };
								diag_log format ["GUERAIRDEF|DROPFAIL|town=%1|reason=no_group_or_roster", (_town getVariable ["name","?"])];
							};
						};

						diag_log format ["GUERAIRDEF|SPAWN|town=%1|class=%2|load=%3|mi24=%4|drop=%5|enemies=%6|enemyAir=%7|large=%8|alive=%9|dropsAlive=%10", (_town getVariable ["name","?"]), _class, _loadName, _useMi24, _useDrop, _enemies, _enemyAir, _isLarge, _aliveCount, _dropAlive];
					} else {
						//--- No pilot: tear down the empty hull + group so nothing leaks.
						//--- B66: player-safe teardown (hull is freshly created with no moveIn yet,
						//--- but guard anyway to never delete a player that somehow boarded).
						if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then {deleteVehicle _veh};
						if (!isNull _grp) then {deleteGroup _grp};
						diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_pilot", (_town getVariable ["name","?"]), _class];
					};
				} else {
					//--- B66: player-safe teardown (freshly created empty hull).
					if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then {deleteVehicle _veh};
					diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_group", (_town getVariable ["name","?"]), _class];
				};
			} else {
				diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=createVehicle_null", (_town getVariable ["name","?"]), _class];
			};
		};
	} forEach towns;

	//=== (3b) MAINTAIN: optional WEST Avenger SAM ambush ==============================
	if (_samOn >= 1
		&& {_samMax > 0}
		&& {_samChance > 0}
		&& {typeName _samClass == "STRING"}
		&& {_samClass != ""}
		&& {isClass (configFile >> "CfgVehicles" >> _samClass)}) then {
		{
			private ["_samTown","_samPos","_samScanRange","_samTarget","_samBestD","_samD","_samEnemyAir","_samTry","_samSpawnPos","_samFlat","_samFound","_samAng","_samDist","_samVeh","_samGrp","_samDriver","_samGunner"];
			_samTown = _x;

			if (_samAlive < _samMax
				&& {!(isNull _samTown)}
				&& {(_samTown getVariable ["sideID", -1]) == WFBE_C_WEST_ID}
				&& {_samTown getVariable ["wfbe_active", false]}
				&& {!(_samTown in _samTowns)}) then {

				_samPos = getPos _samTown;
				_samScanRange = ((_samTown getVariable ["range", 600]) max _samRange);
				_samTarget = objNull;
				_samBestD = 1e9;
				_samEnemyAir = 0;

				{
					if (alive _x
						&& {_x isKindOf "Air"}
						&& {((side _x) == east) || {(side _x) == resistance}}
						&& {(_x distance _samTown) < _samScanRange}) then {
						_samEnemyAir = _samEnemyAir + 1;
						_samD = _x distance _samTown;
						if (_samD < _samBestD) then { _samBestD = _samD; _samTarget = _x; };
					};
				} forEach vehicles;

				if (_samEnemyAir > 0 && {(random 1) < _samChance}) then {
					_samSpawnPos = _samPos;
					_samFound = false;
					_samTry = 0;
					_samAng = random 360;
					while {!_samFound && {_samTry < 8}} do {
						_samAng = random 360;
						_samDist = 140 + random 120;
						_samSpawnPos = [(_samPos select 0) + _samDist * (sin _samAng), (_samPos select 1) + _samDist * (cos _samAng), 0];
						if (!(surfaceIsWater _samSpawnPos)) then {
							_samFlat = _samSpawnPos isFlatEmpty [8, 0, 2, 8, 0, false, objNull];
							if ((count _samFlat) > 0) then { _samSpawnPos = _samFlat; _samFound = true; };
						};
						_samTry = _samTry + 1;
					};
					if (!_samFound) then {
						_samAng = random 360;
						_samDist = 160;
						_samSpawnPos = [(_samPos select 0) + _samDist * (sin _samAng), (_samPos select 1) + _samDist * (cos _samAng), 0];
					};

					_samVeh = [_samClass, _samSpawnPos, west, _samAng, false, true, true, "NONE"] Call WFBE_CO_FNC_CreateVehicle;
					if (!isNull _samVeh) then {
						_samGrp = [west, "avenger-sam"] Call WFBE_CO_FNC_CreateGroup;
						if (!isNull _samGrp) then {
							_samDriver = [_samCrewClass, _samGrp, _samSpawnPos, WFBE_C_WEST_ID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _samDriver) then {
								_samDriver moveInDriver _samVeh;
								_samGunner = [_samCrewClass, _samGrp, _samSpawnPos, WFBE_C_WEST_ID] Call WFBE_CO_FNC_CreateUnit;
								if (!isNull _samGunner) then {
									_samGunner moveInGunner _samVeh;

									_samVeh setVariable ["wfbe_avenger_sam_ambush", true, true];
									_samVeh setVariable ["wfbe_avenger_sam_town", _samTown];

									[_samGrp, _samSpawnPos, 120] Call AIPatrol;
									_samGrp setBehaviour "COMBAT";
									_samGrp setCombatMode "RED";
									_samGrp setSpeedMode "LIMITED";

									if (!isNull _samTarget) then {
										_samVeh reveal _samTarget;
										_samDriver reveal _samTarget;
										_samGunner reveal _samTarget;
										_samGunner doTarget _samTarget;
										_samGunner doFire _samTarget;
									};

									_samAmbushes = _samAmbushes + [[_samTown, _samVeh, _samGrp, time, time]];
									_samTowns = _samTowns + [_samTown];
									_samAlive = _samAlive + 1;
									diag_log format ["AVENGERSAM|SPAWN|town=%1|class=%2|enemyAir=%3|target=%4|alive=%5", (_samTown getVariable ["name","?"]), _samClass, _samEnemyAir, (if (isNull _samTarget) then {"?"} else {typeOf _samTarget}), _samAlive];
								} else {
									if (!isNull _samVeh && {({isPlayer _x} count (crew _samVeh)) == 0}) then { {deleteVehicle _x} forEach (crew _samVeh); deleteVehicle _samVeh; };
									if (!isNull _samGrp) then { {deleteVehicle _x} forEach (units _samGrp); deleteGroup _samGrp; };
									diag_log format ["AVENGERSAM|SPAWNFAIL|town=%1|class=%2|reason=no_gunner", (_samTown getVariable ["name","?"]), _samClass];
								};
							} else {
								if (!isNull _samVeh && {({isPlayer _x} count (crew _samVeh)) == 0}) then { {deleteVehicle _x} forEach (crew _samVeh); deleteVehicle _samVeh; };
								if (!isNull _samGrp) then { {deleteVehicle _x} forEach (units _samGrp); deleteGroup _samGrp; };
								diag_log format ["AVENGERSAM|SPAWNFAIL|town=%1|class=%2|reason=no_driver", (_samTown getVariable ["name","?"]), _samClass];
							};
						} else {
							if (!isNull _samVeh && {({isPlayer _x} count (crew _samVeh)) == 0}) then {deleteVehicle _samVeh};
							diag_log format ["AVENGERSAM|SPAWNFAIL|town=%1|class=%2|reason=no_group", (_samTown getVariable ["name","?"]), _samClass];
						};
					} else {
						diag_log format ["AVENGERSAM|SPAWNFAIL|town=%1|class=%2|reason=createVehicle_null", (_samTown getVariable ["name","?"]), _samClass];
					};
				};
			};
		} forEach towns;
	};

	//--- B67 (Ray 2026-06-21): rebuild + broadcast the GUER-air marker feed from the live registry (alive hulls
	//--- only). Runs AFTER both the prune and the maintain passes, so it self-heals on despawn/spawn. The
	//--- publicVariable each interval also serves as the JIP re-broadcast safety net (publicVariable is NOT
	//--- JIP-replayed in A2-OA). sideID is always the GUER id; updatepatrolmarkers.sqf side-gates on
	//--- WFBE_Client_SideID so only GUER players see these arrows.
	private ["_airList"];
	_airList = [];
	{ if (!isNull (_x select 1) && {alive (_x select 1)}) then { _airList = _airList + [[(_x select 1), WFBE_C_GUER_ID]] } } forEach _defenders;
	WFBE_ACTIVE_GUER_AIR = _airList;
	publicVariable "WFBE_ACTIVE_GUER_AIR";
};
