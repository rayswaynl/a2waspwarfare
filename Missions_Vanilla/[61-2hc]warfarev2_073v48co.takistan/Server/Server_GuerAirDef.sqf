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

	FLY-AWAY DESPAWN (WFBE_C_GUER_AIRDEF_FLYAWAY, Grok idea #12, default 0): when armed, a "quiet"
	recall (no enemies near the town for WFBE_C_GUER_AIRDEF_QUIET_DESPAWN seconds) no longer deletes
	the live, unengaged hull in place mid-skyline. Instead a bounded background thread gives it a
	move-away waypoint (~2km outward from the town) plus a climb, waits <=WFBE_C_GUER_AIRDEF_FLYAWAY_
	TIMEOUT seconds (default 60, hard-clamped to <=60) or until it clears 1500m from the town —
	whichever first — then despawns it with the same player-safe teardown. Registry slot frees THIS
	tick either way. Off by default; destroyed/crew-dead/town-lost/lifetime recalls are unaffected.

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

private ["_interval","_maxAir","_atChance","_mi24Chance","_aaChance","_classKa","_classMi24","_lifetime","_quiet","_destroyedCooldown","_largeSV","_flyHeight","_pilotClass","_crewClass","_defenders","_dropChance","_dropCount","_dropMax","_drops","_groundQrfTTL","_groundQrfMax","_groundQrfs","_swarmOn","_swarmChance","_swarmChance3","_flareOn","_flareMin","_flareMax","_flareLauncher","_flareMag","_applyKaFlares","_sliceCut","_sliceYield"];

_interval   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_INTERVAL", 120];
_maxAir     = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MAX", 4];
_atChance   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_AT_CHANCE", 0.20];
_mi24Chance = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_MI24_CHANCE", 0.25];
_aaChance   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_AA_CHANCE", 0.75];
_classKa    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_KA", "Ka137_MG_PMC"];
_classMi24  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_CLASS_MI24", "Mi24_P"];
_lifetime   = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LIFETIME", 900];
_quiet      = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_QUIET_DESPAWN", 300];
_destroyedCooldown = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_DESTROYED_COOLDOWN", 240]; //--- fix0807b (churn): per-town no-spawn window armed after a COMBAT loss (reason=destroyed or crew_dead) so a fresh defender does not fly straight back into the force that just killed the last one. See PR measurement table.
_largeSV    = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_LARGE_SV", 2500];
_flyHeight  = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_HEIGHT", 120];
//--- Reserve one maintain-sweep interval so the next poll cannot extend a QRF past 600s from spawn.
_groundQrfTTL = 600 - _interval;
if (_groundQrfTTL < 1) then {_groundQrfTTL = 1};
_groundQrfMax = 2;

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

//--- Wait for towns + the GUER side logic to exist, then let town ownership settle (mirror of GuerStipend).
waitUntil {
	(!isNil "towns") && {(count towns) > 0}
	&& {!isNil "WFBE_L_GUE"} && {!(isNull (missionNamespace getVariable ["WFBE_L_GUE", objNull]))}
};
sleep 45;

_pilotClass = missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"];
_crewClass  = missionNamespace getVariable ["WFBE_GUERRESCREW",  "GUE_Soldier_Crew"];

//--- FLARE-STOCK applicator (shared by the leader + each swarm extra). _this = [_vehicle]. Rolls a flare budget
//--- of _flareMin.._flareMax (default 5-20), mounts the manual OA launcher + a flare mag on the turret (path [-1],
//--- same idiom the player Ka-137 uses in Client_BuildUnit.sqf), and stamps the rolled budget as the PUBLIC
//--- "FlareCount" integer that the auto-CM module consumes. Returns the rolled count (0 = disabled). Runs on the
//--- server, where these AI hulls are local. The FlareCount write is deferred (sleep 3) so it lands AFTER
//--- CM_Set.sqf's default write.
_applyKaFlares = {
	private ["_v","_n","_eMin","_eMax","_tier","_tmin","_tmax"];
	_v = _this select 0;
	_n = 0;
	if (_flareOn >= 1 && {!isNull _v}) then {
		_eMin = _flareMin; _eMax = _flareMax;
		if ((missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_TIER_SCALE", 0]) > 0) then {
			_tier = floor (missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0]);
			if (_tier < 0) then { _tier = 0 };
			if (_tier > 3) then { _tier = 3 };
			_tmin = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_TIERMIN", [5,30,60,60]];
			_tmax = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_TIERMAX", [20,120,240,240]];
			if ((count _tmin) > _tier && {(count _tmax) > _tier}) then {
				_eMin = _tmin select _tier;
				_eMax = _tmax select _tier;
				if (_eMax < _eMin) then { _eMax = _eMin };
			};
		};
		_n = _eMin + floor(random (_eMax - _eMin + 1)); //--- MIN..MAX inclusive; tier-scaled when WFBE_C_GUER_KA137_FLARE_TIER_SCALE>0.
		//--- Mount the manual OA launcher + one flare mag (turret path [-1], as the Ka-137 fires from MainTurret).
		{_v addWeaponTurret  [_x, [-1]]} forEach [_flareLauncher];
		{_v addMagazineTurret [_x, [-1]]} forEach [_flareMag];
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

//--- Live registry of defenders. Each entry: [_town, _vehicle, _group, _pilot, _gunner, _spawnTime, _lastEnemyTime].
//--- Script-local (NOT wfbe_persistent) so it can't outlive a despawn / leak groups.
_defenders = [];

//--- Live registry of PARADROPPED squads (build83). Each entry: [_town, _group, _spawnTime, _lastEnemyTime].
//--- Same shape/rules as _defenders but for the infantry stick from the CARGO/PARADROP variant. Script-local
//--- (NOT wfbe_persistent) so a dropped squad can never leak groups or outlive its despawn. Separate cap
//--- (_dropMax) and separate prune pass below keep it from being spammed exactly like the air branches.
_drops = [];

//--- E3 GUER GROUND QRF registry. Each entry: [_town, _group, _spawnTime]. It is script-local,
//--- capped independently from air/paradrop assets, and never marked persistent.
_groundQrfs = [];

["INITIALIZATION", Format ["Server_GuerAirDef.sqf: GUER air defense started (interval=%1 cap=%2 atChance=%3 mi24Chance=%4).", _interval, _maxAir, _atChance, _mi24Chance]] Call WFBE_CO_FNC_LogContent;
diag_log format ["GUERAIRDEF|START|interval=%1|cap=%2|atChance=%3|mi24Chance=%4|aaChance=%5|ka=%6|mi24=%7|dropChance=%8|dropCount=%9|dropMax=%10|destroyedCooldown=%11", _interval, _maxAir, _atChance, _mi24Chance, _aaChance, _classKa, _classMi24, _dropChance, _dropCount, _dropMax, _destroyedCooldown];

//--- B67 (Ray 2026-06-21): publish the GUER-air list for the client map-marker loop (updatepatrolmarkers.sqf
//--- reads WFBE_ACTIVE_GUER_AIR = [[vehicle, sideID], ...]). Init empty + broadcast so a JIP client never sees
//--- nil; rebuilt + re-broadcast every interval below; targeted JIP catch-up in Server_OnPlayerConnected.sqf.
WFBE_ACTIVE_GUER_AIR = [];
publicVariable "WFBE_ACTIVE_GUER_AIR";

//--- perf-slice (2026-07-26): slice accounting for the maintain sweep. guer_airdef_cycle used to be
//--- one wall-clock block per sweep; the sweep now yields between work items (per pruned registry
//--- entry, after the enemy-air cache build, and per town - the towns yield replaces the inline
//--- WFBE_C_AIRDEF_CHUNKED block, same switch + same WFBE_C_AIRDEF_CHUNK_SLEEP pacing) and the cycle
//--- record reports MEASURED active ms: every suspension is excluded, where the old number subtracted
//--- only the INTENDED chunk sleep, not actual suspension time. _sliceCut closes the current active
//--- segment into the per-pass totals; _sliceYield additionally emits one guer_airdef_slice audit
//--- sample and (CHUNKED>0 only) sleeps. With WFBE_C_AIRDEF_CHUNKED at 0 nothing sleeps (pre-chunking
//--- scheduling) and slice records still accrue. Accounting locals are pass-scope and resolve
//--- dynamically at Call time.
_sliceCut = {
	_sliceDt = diag_tickTime - _sliceT0;
	_perfActive = _perfActive + _sliceDt;
	if (_sliceDt > _perfSliceMax) then { _perfSliceMax = _sliceDt; };
	_sliceT0 = diag_tickTime;
};
_sliceYield = {
	Call _sliceCut;
	_perfSlices = _perfSlices + 1;
	if (!isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["guer_airdef_slice", _sliceDt, "", "SERVER"] Call PerformanceAudit_Record;
		};
	};
	if ((missionNamespace getVariable ["WFBE_C_AIRDEF_CHUNKED", 1]) > 0) then {
		_chunkSleepTotal = _chunkSleepTotal + (missionNamespace getVariable ["WFBE_C_AIRDEF_CHUNK_SLEEP", 0.4]);
		sleep (missionNamespace getVariable ["WFBE_C_AIRDEF_CHUNK_SLEEP", 0.4]);
	};
	_sliceT0 = diag_tickTime;
};

while {!WFBE_GameOver} do {
	//--- wave0721e live-burn guard (2026-07-21): this SERVER-only loop hit 'Undefined variable
	//--- wfbe_co_fnc_logvehdelete' MID-MATCH even though Init_Common.sqf compiles the probe
	//--- unconditionally and server_groupsGC used it successfully in the same session. The probe
	//--- call and deleteVehicle share statements below, so the abort LEAKED whole despawns
	//--- (hull+crew never deleted). Until the nil-er is found: re-stub per tick so cleanup NEVER
	//--- depends on telemetry, and log each occurrence (latched) as root-cause data.
	if (isNil "WFBE_CO_FNC_LogVehDelete") then {
		WFBE_CO_FNC_LogVehDelete = {};
		if (isNil "wfbe_guerairdef_probestub_logged") then {
			wfbe_guerairdef_probestub_logged = true;
			diag_log "GUERAIRDEF|PROBE-STUBBED|LogVehDelete was nil at maintain tick - despawn probe stubbed, cleanup preserved";
		};
	};
	sleep _interval;

	private ["_now","_kept","_townsWithAir","_aliveCount","_perfStart","_perfAirBefore","_perfDropsBefore","_prunedGroups","_flyAwayGroups","_perfActive","_perfSliceMax","_perfSlices","_sliceDt","_sliceT0","_chunkSleepTotal","_enemyAirScanBudget","_enemyAirScanCount","_enemyAirScanned"];
	_perfStart = diag_tickTime;
	_perfAirBefore = count _defenders;
	_perfDropsBefore = count _drops;
	_now = time;
	_perfActive = 0;
	_perfSliceMax = 0;
	_perfSlices = 0;
	_sliceDt = 0;
	_chunkSleepTotal = 0;
	_sliceT0 = _perfStart;

	//=== (1) PRUNE + (2) SELF-CLEAN ==========================================================
	//--- Rebuild the registry, dropping anything that is dead/destroyed or should be despawned.
	_kept         = [];
	_townsWithAir = [];
	_prunedGroups = [];
	_flyAwayGroups = [];
	{
		private ["_entry","_eTown","_eVeh","_eGrp","_ePilot","_eGunner","_eSpawn","_eLastEnemy","_drop","_reason","_enemiesNow","_townSide","_townActive","_flyAway"];
		_entry      = _x;
		_eTown      = _entry select 0;
		_eVeh       = _entry select 1;
		_eGrp       = _entry select 2;
		_ePilot     = _entry select 3;
		_eGunner    = _entry select 4;
		_eSpawn     = _entry select 5;
		_eLastEnemy = _entry select 6;

		_drop   = false;
		_reason = "";

		//--- (1) Destroyed / despawned hull => prune (frees the slot).
		if (isNull _eVeh || {!(alive _eVeh)}) then { _drop = true; _reason = "destroyed"; };

		//--- A living hull is not a valid defender without its registered pilot and gunner in place.
		if (!_drop && {isNull _ePilot || {!(alive _ePilot)} || {isNull _eGunner} || {!(alive _eGunner)}}) then {
			_drop = true;
			_reason = "crew_dead";
		};
		if (!_drop && {((driver _eVeh) != _ePilot) || {((gunner _eVeh) != _eGunner)}}) then {
			_drop = true;
			_reason = "crew_seat";
		};

		//--- (2) Town no longer GUER-held or no longer active => recall.
		if (!_drop) then {
			_townSide   = if (isNull _eTown) then {-1} else {_eTown getVariable ["sideID", -1]};
			_townActive = if (isNull _eTown) then {false} else {_eTown getVariable ["wfbe_active", false]};
			if (_townSide != WFBE_C_GUER_ID) then { _drop = true; _reason = "town_lost"; };
			if (!_drop && !_townActive) then { _drop = true; _reason = "town_inactive"; };
		};

		//--- Refresh last-enemy timestamp (enemies of GUER = west + east near the town).
		if (!_drop && !(isNull _eTown)) then {
			//--- fix(hunt): nearEntities "Man" returns only DISMOUNTED infantry - fully mounted assaults were invisible (defenders recalled as "quiet" mid-attack, paradrop/Mi-24 response never triggered). Include vehicle hulls: a crewed hull carries its crew's side; empty hulls resolve CIVILIAN and stay filtered by the side check.
			_enemiesNow = {alive _x && {((side _x) == west) || {(side _x) == east}}} count ((getPos _eTown) nearEntities [["Man","LandVehicle","Air","Ship"], ((_eTown getVariable ["range", 600]) max 600)]);
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
			//--- stops tracking it).
			//--- fix(swarm): W13 self-clean only tears down THIS entry's own crew+hull here. Ka-137
			//--- swarm extras register under the LEADER's shared _grp (see the SWARM ROLL block below),
			//--- so blanket-deleting units _eGrp here used to wipe every sibling drone's crew too on
			//--- ANY single prune - derelict hulls then sat in the registry (alive, crewless) for up to
			//--- _lifetime (900s). Group teardown is deferred to the post-pass below, which only frees
			//--- a group once no KEPT entry still references it.

			//--- FLY-AWAY DESPAWN (WFBE_C_GUER_AIRDEF_FLYAWAY, Grok idea #12, default 0): only for a
			//--- "quiet" recall on a LIVE, non-player-crewed hull (never re-route a destroyed/crew-dead
			//--- hull or a player's air). Instead of an instant delete, hand the whole detach off to a
			//--- self-contained background thread (below) that gives it a move-away waypoint + a climb,
			//--- waits a BOUNDED time, then tears itself down with the SAME player-safe teardown idiom
			//--- used here. The registry slot is freed THIS tick regardless (identical to the immediate
			//--- path), so a replacement can spawn while the old hull is still flying off-screen.
			_flyAway = (_reason == "quiet")
				&& {(missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_FLYAWAY", 0]) > 0}
				&& {!isNull _eVeh} && {alive _eVeh}
				&& {({isPlayer _x} count (crew _eVeh)) == 0};

			if (_flyAway) then {
				//--- fix(airdef) AIRDEFGC v1: the comment this replaces claimed _eGrp deliberately staying
				//--- OUT of _prunedGroups meant this path "never races the deferred group-teardown post-pass"
				//--- - that was false. The post-pass frees any pruned group no longer referenced by a KEPT
				//--- registry entry, and a flyaway-dropped entry is ALSO absent from _kept (dropped either
				//--- way, same as immediate despawn). With WFBE_C_GUER_KA137_SWARM sharing one group across
				//--- a leader + extras, if a SIBLING in the group prunes via the immediate path in the SAME
				//--- tick this entry takes the flyaway path, the post-pass deleted the WHOLE shared group -
				//--- including this thread's still-alive, still-flying pilot+gunner - out from under it,
				//--- leaving the hull a crewless derelict (visibly "not despawning") until this thread's own
				//--- bounded wait eventually notices the empty crew and tears the hull down itself. Register
				//--- the group as flyaway-owned so the post-pass leaves it strictly to this thread, which
				//--- already only frees the group once it holds no living unit (see below) - restoring the
				//--- "never touch a group another live claim still needs" idiom (mirrors #1862's ambient-air
				//--- group-first teardown).
				_flyAwayGroups = _flyAwayGroups + [_eGrp];
				[_eTown, _eVeh, _eGrp, _ePilot, _eGunner, _flyHeight] Spawn {
					private ["_t","_v","_g","_p","_gu","_h","_tPos","_vPos","_dx","_dy","_ang","_flyPos","_climbH","_timeout","_tick","_done","_finalDist"];
					_t = _this select 0;
					_v = _this select 1;
					_g = _this select 2;
					_p = _this select 3;
					_gu = _this select 4;
					_h = _this select 5;
					//--- fix(codex-hold 2026-07-25): the registry slot for this hull was already freed THIS
					//--- tick by the caller (identical to the immediate-delete path), so if the hull died
					//--- between being scheduled and this thread actually starting, bailing out with a bare
					//--- exitWith left crew+group untracked by BOTH this thread and the maintain sweep -
					//--- untracked survivors / an empty-group leak. Run the SAME player-safe teardown the
					//--- full path uses below (pilot/gunner by direct reference, hull crew + hull if no
					//--- player aboard, group only once it holds no living unit), THEN exit.
					if (isNull _v || {!(alive _v)}) exitWith {
						if (!isNull _p && {!(isPlayer _p)}) then { ["guerairdef-flyaway-pilot-earlydead", _p, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _p; };
						if (!isNull _gu && {!(isPlayer _gu)}) then { ["guerairdef-flyaway-gunner-earlydead", _gu, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _gu; };
						if (!isNull _v && {({isPlayer _x} count (crew _v)) == 0}) then { {["guerairdef-flyaway-unit-earlydead", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _v); ["guerairdef-flyaway-hull-earlydead", _v, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _v; }; //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below; already-scheduled).
						if (!isNull _g && {({alive _x} count (units _g)) == 0}) then { deleteGroup _g; };
						diag_log format ["GUERAIRDEF|FLYAWAYDESPAWN-EARLYDEAD|town=%1", (if (isNull _t) then {"?"} else {_t getVariable ["name","?"]})];
					};

					//--- Bearing AWAY from the town = the hull's current bearing FROM the town center,
					//--- extended ~2km outward (a stable outward heading, not a moving target). Falls
					//--- back to a random heading in the (practically unreachable) case the hull spawned
					//--- exactly on the town center.
					_vPos = getPos _v;
					_tPos = if (isNull _t) then {_vPos} else {getPos _t};
					_dx = (_vPos select 0) - (_tPos select 0);
					_dy = (_vPos select 1) - (_tPos select 1);
					_ang = if (abs _dx < 1 && {abs _dy < 1}) then {random 360} else {_dx atan2 _dy};
					_flyPos = [(_tPos select 0) + 2000 * sin _ang, (_tPos select 1) + 2000 * cos _ang, 0];

					if (!isNull _g) then {
						_g move _flyPos;
						_g setBehaviour "AWARE";
						_g setSpeedMode "FULL";
					};
					_climbH = _h + 150;
					if (!isNull _v && {alive _v}) then { _v flyInHeight _climbH; };

					//--- Bounded wait: <=WFBE_C_GUER_AIRDEF_FLYAWAY_TIMEOUT seconds (hard-clamped to
					//--- <=60 here regardless of config), OR until the hull clears 1500m from the town,
					//--- whichever comes first. If the move fails/stalls the timeout still fires, so this
					//--- can never hang.
					_timeout = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_FLYAWAY_TIMEOUT", 60];
					if (_timeout > 60) then { _timeout = 60; };
					if (_timeout < 5) then { _timeout = 5; };
					_tick = 0;
					_done = false;
					waitUntil {
						sleep 1;
						_tick = _tick + 1;
						_done = (isNull _v) || {!(alive _v)} || {(_v distance _tPos) > 1500} || {_tick >= _timeout};
						_done
					};

					_finalDist = if (isNull _v) then {-1} else {_v distance _tPos};

					//--- Despawn now: SAME player-safe teardown idiom as the immediate path (re-checked
					//--- here since a player could have boarded during the wait).
					if (!isNull _p && {!(isPlayer _p)}) then { ["guerairdef-flyaway-pilot", _p, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _p; };
					if (!isNull _gu && {!(isPlayer _gu)}) then { ["guerairdef-flyaway-gunner", _gu, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _gu; };
					if (!isNull _v && {({isPlayer _x} count (crew _v)) == 0}) then { {["guerairdef-flyaway-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _v); ["guerairdef-flyaway-hull", _v, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _v; }; //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below; already-scheduled).
					if (!isNull _g && {({alive _x} count (units _g)) == 0}) then { deleteGroup _g; };
					diag_log format ["GUERAIRDEF|FLYAWAYDESPAWN|town=%1|dist=%2|ticks=%3", (if (isNull _t) then {"?"} else {_t getVariable ["name","?"]}), _finalDist, _tick];
				};
				diag_log format ["GUERAIRDEF|DESPAWN|town=%1|reason=%2|alive=%3|flyaway=1", (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}), _reason, (count _kept)];
			} else {
				if (!isNull _ePilot && {!(isPlayer _ePilot)}) then { ["guerairdef-pilot", _ePilot, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _ePilot; };
				if (!isNull _eGunner && {!(isPlayer _eGunner)}) then { ["guerairdef-gunner", _eGunner, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eGunner; };
				if (!isNull _eVeh && {({isPlayer _x} count (crew _eVeh)) == 0}) then { {["guerairdef-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _eVeh); ["guerairdef-hull", _eVeh, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eVeh; }; //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below; already-scheduled).
				if (!isNull _eGrp) then { _prunedGroups = _prunedGroups + [_eGrp]; };
				//--- fix0807b (churn): a COMBAT loss (hull destroyed, or crew killed while the hull survived)
				//--- arms a per-town cooldown so the next maintain sweep cannot refill this town while the same
				//--- attacking force is still on it (measured: 23/23 combat losses in a 61-minute live window
				//--- died with enemyAir=0 - ground fire only - and most were replaced in the SAME sweep that
				//--- noticed the death). Quiet/lifetime/town_lost/town_inactive recalls are not combat losses
				//--- and do not arm the cooldown.
				if (!isNull _eTown && {(_reason == "destroyed") || (_reason == "crew_dead")}) then {
					_eTown setVariable ["wfbe_guer_airdef_cooldown_until", _now + _destroyedCooldown];
				};
				diag_log format ["GUERAIRDEF|DESPAWN|town=%1|reason=%2|alive=%3", (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}), _reason, (count _kept)];
			};
		} else {
			_kept         = _kept + [[_eTown, _eVeh, _eGrp, _ePilot, _eGunner, _eSpawn, _eLastEnemy]];
			_townsWithAir = _townsWithAir + [_eTown];
		};
		Call _sliceYield;
	} forEach _defenders;
	_defenders  = _kept;
	_aliveCount = count _defenders;

	//--- fix(swarm): finalize deferred group teardown. A group is only freed once no KEPT
	//--- registry entry still references it (leader + every swarm extra that shared it have
	//--- ALL been pruned). Any pruned group still shared by a surviving sibling is left alone -
	//--- its crew/hull were untouched above, so the sibling keeps its group and orders intact.
	//--- fix(airdef) AIRDEFGC v1: a group still owned by an in-flight flyaway thread (_flyAwayGroups,
	//--- populated above) must never be torn down here - see that block for why a swarm-shared group
	//--- raced this sweep otherwise. One always-on diag_log line marks every time this guard actually
	//--- has to hold a group back, so a soak can grep AIRDEFGC to confirm the race is closed.
	private ["_keptGroups"];
	_keptGroups = [];
	{ _keptGroups = _keptGroups + [(_x select 2)]; } forEach _defenders;
	{
		private ["_pg"];
		_pg = _x;
		if (!isNull _pg && {_pg in _flyAwayGroups}) then {
			diag_log format ["AIRDEFGC|v1|flyaway-group-protect|grp=%1", _pg];
		};
		if (!isNull _pg && {!(_pg in _keptGroups)} && {!(_pg in _flyAwayGroups)}) then {
			{if (!(isPlayer _x)) then {["guerairdef-L254", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _pg);
			deleteGroup _pg;
		};
	} forEach _prunedGroups;

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
			//--- fix(hunt): nearEntities "Man" returns only DISMOUNTED infantry - fully mounted assaults were invisible (defenders recalled as "quiet" mid-attack, paradrop/Mi-24 response never triggered). Include vehicle hulls: a crewed hull carries its crew's side; empty hulls resolve CIVILIAN and stay filtered by the side check.
			_dEnemiesNow = {alive _x && {((side _x) == west) || {(side _x) == east}}} count ((getPos _dTown) nearEntities [["Man","LandVehicle","Air","Ship"], ((_dTown getVariable ["range", 600]) max 600)]);
			if (_dEnemiesNow > 0) then { _dLastEnemy = _now; };
		};

		//--- Quiet too long / lifetime exceeded => recall (anti-accumulation).
		if (!_dDrop && {(_now - _dLastEnemy) > _quiet}) then { _dDrop = true; _dReason = "quiet"; };
		if (!_dDrop && {(_now - _dSpawn) > _lifetime}) then { _dDrop = true; _dReason = "lifetime"; };

		if (_dDrop) then {
			//--- Player-safe teardown: only delete non-player bodies; then drop the group.
			if (!isNull _dGrp) then { {if (!(isPlayer _x)) then {["guerairdef-L302", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _dGrp); deleteGroup _dGrp; };
			diag_log format ["GUERAIRDEF|DROPDESPAWN|town=%1|reason=%2|dropsAlive=%3", (if (isNull _dTown) then {"?"} else {_dTown getVariable ["name","?"]}), _dReason, (count _keptDrops)];
		} else {
			_keptDrops = _keptDrops + [[_dTown, _dGrp, _dSpawn, _dLastEnemy]];
		};
		Call _sliceYield;
	} forEach _drops;
	_drops     = _keptDrops;
	_dropAlive = count _drops;

	//=== (1c) PRUNE + SELF-CLEAN GUER GROUND QRFs (E3) ======================================
	//--- One group per town, two groups globally, and a hard 600s lifetime. This follows the
	//--- W13/G-card player-safe teardown idiom, while leaving the existing air/drop registries alone.
	if ((missionNamespace getVariable ["WFBE_C_GUER_GROUND_QRF", 0]) > 0) then {
		private ["_keptGroundQrfs","_qrfEntry","_qrfTown","_qrfGrp","_qrfSpawn","_qrfDrop","_qrfReason","_qrfTownSide","_qrfTownActive"];
		_keptGroundQrfs = [];
		{
			_qrfEntry = _x;
			_qrfTown = _qrfEntry select 0;
			_qrfGrp = _qrfEntry select 1;
			_qrfSpawn = _qrfEntry select 2;
			_qrfDrop = false;
			_qrfReason = "";
			if (isNull _qrfGrp || {({alive _x} count (units _qrfGrp)) == 0}) then { _qrfDrop = true; _qrfReason = "wiped"; };
			if (!_qrfDrop && {(time - _qrfSpawn) >= _groundQrfTTL}) then { _qrfDrop = true; _qrfReason = "lifetime"; };
			if (!_qrfDrop) then {
				_qrfTownSide = if (isNull _qrfTown) then {-1} else {_qrfTown getVariable ["sideID", -1]};
				_qrfTownActive = if (isNull _qrfTown) then {false} else {_qrfTown getVariable ["wfbe_active", false]};
				if (_qrfTownSide != WFBE_C_GUER_ID) then { _qrfDrop = true; _qrfReason = "town_lost"; };
				if (!_qrfDrop && {!_qrfTownActive}) then { _qrfDrop = true; _qrfReason = "town_inactive"; };
			};
			if (_qrfDrop) then {
				if (!isNull _qrfGrp) then {
					{if (!(isPlayer _x)) then {["guerairdef-qrf-cleanup", _x, Format ["town=%1", (if (isNull _qrfTown) then {"?"} else {_qrfTown getVariable ["name","?"]})]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _qrfGrp);
					if (({isPlayer _x} count (units _qrfGrp)) == 0) then {deleteGroup _qrfGrp};
				};
				diag_log format ["GUERAIRDEF|GROUNDDESPAWN|town=%1|reason=%2|alive=%3", (if (isNull _qrfTown) then {"?"} else {_qrfTown getVariable ["name","?"]}), _qrfReason, count _keptGroundQrfs];
			} else {
				_keptGroundQrfs = _keptGroundQrfs + [[_qrfTown, _qrfGrp, _qrfSpawn]];
			};
		} forEach _groundQrfs;
		_groundQrfs = _keptGroundQrfs;
	};

	private ["_enemyAirVehicles"];
	_enemyAirVehicles = [];
	//--- A match-long wreck list makes `vehicles` an unbounded input after #1471 deliberately
	//--- retained shot-down hulls. Preserve the exact live west/east-air candidate semantics, but
	//--- close a scheduler slice every bounded number of registry entries so dead wreck growth cannot
	//--- create a single multi-frame hitch. The cache is then reused by every town below.
	//--- A2's isKindOf lookup is costly on the large, long-lived Chernarus vehicle registry. Four
	//--- entries target a sub-second air-scan slice on the armed Chernarus run.
	_enemyAirScanBudget = 4;
	_enemyAirScanCount = 0;
	_enemyAirScanned = 0;
	{
		_enemyAirScanned = _enemyAirScanned + 1;
		if (alive _x && {_x isKindOf "Air"} && {((side _x) == west) || {(side _x) == east}}) then {
			_enemyAirVehicles set [count _enemyAirVehicles, _x];
		};
		_enemyAirScanCount = _enemyAirScanCount + 1;
		if (_enemyAirScanCount >= _enemyAirScanBudget) then {
			_enemyAirScanCount = 0;
			Call _sliceYield;
		};
	} forEach vehicles;
	Call _sliceYield;

	//=== (3) MAINTAIN: spawn one defender per active GUER town that lacks live air ============
	{
		private ["_town","_pos","_enemies","_enemyAir","_isLarge","_townType","_maxSV","_useMi24","_useAA","_class","_useAT","_useDrop","_townHasDrop","_grp","_veh","_pilot","_gunner","_airCrewReady","_spawnPos","_ang","_loadName","_swarmN","_swarmI","_swarmMade","_eAng","_ePos","_eVeh2","_ePilot","_eGunner","_swarmCrewReady","_flareN","_eFlareN","_qrfEnemies","_qrfTownHas","_qrfPool","_qrfTemplate","_qrfGroup","_qrfBuilt","_qrfUnit","_qrfAng","_qrfPos","_qrfRadius","_diag"];
		_town = _x;

		//--- E3: a GUER-held town under a genuine ground attack gets one edge-of-town defender
		//--- group from the native dead-team pool. Defender tags keep it out of wake-up scans.
		if ((missionNamespace getVariable ["WFBE_C_GUER_GROUND_QRF", 0]) > 0
			&& {!(isNull _town)}
			&& {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}
			&& {_town getVariable ["wfbe_active", false]}
			&& {(count _groundQrfs) < _groundQrfMax}) then {
			_qrfTownHas = false;
			{if ((_x select 0) == _town) then {_qrfTownHas = true}} forEach _groundQrfs;
			if (!_qrfTownHas) then {
				_qrfEnemies = {alive _x && {((side _x) == west) || {(side _x) == east}} && {!(_x isKindOf "Air")}} count ((getPos _town) nearEntities [["Man","LandVehicle","Air","Ship"], ((_town getVariable ["range", 600]) max 600)]);
				if (_qrfEnemies > 0) then {
					_qrfPool = missionNamespace getVariable ["WFBE_GUERRESTEAMTEMPLATES", []];
					if (typeName _qrfPool == "ARRAY" && {(count _qrfPool) > 0}) then {
						_qrfTemplate = _qrfPool select floor (random count _qrfPool);
						if (typeName _qrfTemplate == "ARRAY" && {(count _qrfTemplate) > 0}) then {
							_qrfRadius = (_town getVariable ["range", 600]) max 300;
							_qrfAng = random 360;
							_qrfPos = [((getPos _town) select 0) + (_qrfRadius * sin _qrfAng), ((getPos _town) select 1) + (_qrfRadius * cos _qrfAng), 0];
							_qrfGroup = [resistance, "guer-ground-qrf"] Call WFBE_CO_FNC_CreateGroup;
							_qrfBuilt = 0;
							if (!isNull _qrfGroup) then {
								{if (!isNil "_x" && {typeName _x == "STRING"}) then {
									_qrfUnit = [_x, _qrfGroup, _qrfPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _qrfUnit) then {
										_qrfUnit setVariable ["WFBE_IsTownDefenderAI", true, true];
										_qrfBuilt = _qrfBuilt + 1;
									};
								}} forEach _qrfTemplate;
								if (_qrfBuilt > 0) then {
									[_qrfGroup, getPos _town, ((_town getVariable ["range", 600]) max 300)] Call AIPatrol;
									_qrfGroup setBehaviour "COMBAT";
									_qrfGroup setCombatMode "RED";
									_qrfGroup setSpeedMode "NORMAL";
									_groundQrfs = _groundQrfs + [[_town, _qrfGroup, time]];
									_diag = format ["GUERAIRDEF|GROUNDQRF|town=%1|units=%2|alive=%3", _town getVariable ["name","?"], _qrfBuilt, count _groundQrfs];
									diag_log _diag;
								} else {
									{if (!(isPlayer _x)) then {["guerairdef-qrf-buildfail", _x, Format ["town=%1", _town getVariable ["name","?"]]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _qrfGroup);
									deleteGroup _qrfGroup;
								};
							};
						};
					};
				};
			};
		};

		if (_aliveCount < _maxAir
			&& {!(isNull _town)}
			&& {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}
			&& {_town getVariable ["wfbe_active", false]}
			&& {!(_town in _townsWithAir)}
			//--- fix0807b (churn): post-combat-loss cooldown gate. Skip a town whose last defender was a
			//--- combat loss (destroyed/crew_dead) until WFBE_C_GUER_AIRDEF_DESTROYED_COOLDOWN seconds have
			//--- passed (armed in the prune pass above). getVariable default 0 means an untouched town is
			//--- never gated; quiet/lifetime/town_lost/town_inactive recalls never set this variable.
			&& {_now >= (_town getVariable ["wfbe_guer_airdef_cooldown_until", 0])}
			//--- fable/guer-air-tune (owner 2026-07-28: "make the Ka-137 appear less ... every town
			//--- activation gets a bunch in the air"): THREAT-ONLY spawn gate. The old gate had no enemy
			//--- requirement - every active GUER town summoned a defender on the next sweep, so idle towns
			//--- burned the WFBE_C_GUER_AIRDEF_MAX slots on recon-MG orbits (spawn churn = lag) and the
			//--- threat-keyed interesting variants (AA/Mi-24/paradrop/swarm) rarely saw a free slot. Now a
			//--- defender spawns only when a live W/E foe is actually near the town (same scan shape as the
			//--- loadout selector below; only would-spawn towns pay it). Quiet-recall already despawns when
			//--- the threat ends - this is the symmetric spawn half. 0 = legacy always-spawn.
			&& {((missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_THREAT_ONLY", 0]) <= 0)
				|| {
					_enemies = {alive _x && {((side _x) == west) || {(side _x) == east}}} count ((getPos _town) nearEntities [["Man","LandVehicle","Air","Ship"], ((_town getVariable ["range", 600]) max 600)]);
					_enemies > 0
				}}) then {

			_pos = getPos _town;

			//--- Enemies near the town (west + east, GUER's foes).
			//--- fix(hunt): nearEntities "Man" returns only DISMOUNTED infantry - fully mounted assaults were invisible (defenders recalled as "quiet" mid-attack, paradrop/Mi-24 response never triggered). Include vehicle hulls: a crewed hull carries its crew's side; empty hulls resolve CIVILIAN and stay filtered by the side check.
			if (!((missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_THREAT_ONLY", 0]) > 0)) then {
				_enemies = {alive _x && {((side _x) == west) || {(side _x) == east}}} count ((getPos _town) nearEntities [["Man","LandVehicle","Air","Ship"], ((_town getVariable ["range", 600]) max 600)]);
			};

			//--- Enemy AIR near the town (crewed west/east aircraft) - use the one bounded live-air
			//--- cache built above. Empty parked hulls still read CIVILIAN and are excluded at cache build.
			//--- COORD-SPACE (r25 bughunt): 3D distance(_air,town) folds altitude into the radius, so a
			//--- gunship loitering at 150-200m AGL near the town rim can fail a 600m ground radius that
			//--- 2D XY would pass - AA loadout branch never arms. Use squared XY distance (A2 has no distance2D).
			private ["_airR","_airR2","_txy"];
			_airR = (_town getVariable ["range", 600]) max 600;
			_airR2 = _airR * _airR;
			_txy = getPos _town;
			_enemyAir = {
				private ["_p","_dx","_dy"];
				_p = getPos _x;
				_dx = (_p select 0) - (_txy select 0);
				_dy = (_p select 1) - (_txy select 1);
				((_dx * _dx) + (_dy * _dy)) < _airR2
			} count _enemyAirVehicles;

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
			//--- Ground attack = at least one non-air foe near the town. _enemies uses a bounded nearby-man
			//--- scan, so _enemies > _enemyAir means a genuine GROUND threat
			//--- (not merely aircraft overhead). Require that so a pure air raid never pulls an infantry drop.
			if (!_useAA
				&& {_enemies > 0}
				&& {(_enemies - _enemyAir) > 0}
				&& {!_townHasDrop}
				&& {_dropAlive < _dropMax}
				&& {(random 1) < _dropChance}) then { _useDrop = true; };
			if (!_useAA && {!_useDrop} && {_isLarge} && {_enemies > 0} && {(random 1) < _mi24Chance}) then { _useMi24 = true; };
			if (!_useAA && {!_useDrop} && {!_useMi24} && {(random 1) < _atChance}) then { _useAT = true; };

			//--- The paradrop variant normally uses the DEFAULT Ka-137 (drone recon-MG airframe).
			//--- E5: once late-game air scaling begins, the dark-gated delivery bird is the registered
			//--- crewed UH-1H; the existing pilot/gunner seat receipt and airdef lifecycle remain in force.
			_class = if (_useMi24) then {_classMi24} else {_classKa};
			if (_useDrop && {(missionNamespace getVariable ["WFBE_C_GUER_HUEY_QRF", 0]) > 0} && {(time / 60) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_LATE_MINS", 45])}) then {_class = "UH1H_TK_GUE_EP1"};

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
						_gunner = objNull;
						_gunner = [_crewClass, _grp, _spawnPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _gunner) then { _gunner moveInGunner _veh; };
						_airCrewReady = (!isNull _pilot) && {!isNull _gunner} && {((driver _veh) == _pilot)} && {((gunner _veh) == _gunner)};
						if (!_airCrewReady) then {
							Call _sliceCut; sleep 1; _sliceT0 = diag_tickTime;
							if ((driver _veh) != _pilot) then { _pilot moveInDriver _veh; };
							if (!isNull _gunner && {(gunner _veh) != _gunner}) then { _gunner moveInGunner _veh; };
							_airCrewReady = (!isNull _pilot) && {!isNull _gunner} && {((driver _veh) == _pilot)} && {((gunner _veh) == _gunner)};
						};
						if (!_airCrewReady) then {
							if (!isNull _pilot && {!(isPlayer _pilot)}) then { ["guerairdef-spawn-pilot", _pilot, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _pilot; };
							if (!isNull _gunner && {!(isPlayer _gunner)}) then { ["guerairdef-spawn-gunner", _gunner, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _gunner; };
							if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then { ["guerairdef-spawn-hull", _veh, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _veh; };
							if (!isNull _grp) then { deleteGroup _grp; };
							diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=crew_seat", (_town getVariable ["name","?"]), _class];
						};
						if (_airCrewReady) then {

							//--- Apply the EASA AT loadout to the Ka-137 (server-side turret swap; see header).
						//--- Strip the default recon MG (PKT/100Rnd_762x54_PKT) then add the AT-5 set, using the
						//--- SAME turret-path [-1] remove/add commands EASA_RemoveLoadout.sqf uses for Ka137_MG_PMC.
						_loadName = "default";
						if (_useAT) then {
							{_veh removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
							{_veh removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
							{_veh addWeaponTurret  [_x, [-1]]} forEach ["AT5Launcher","57mmLauncher"];
							{_veh addMagazineTurret [_x, [-1]]} forEach ["5Rnd_AT5_BRDM2","64Rnd_57mm"];
							_loadName = "AT5";
						};
						//--- Apply the EASA Igla AA loadout (counter-air): strip the recon MG, mount the Igla SAM set.
						//--- EXACT classnames from the Ka-137 EASA AA entry (EASA_Init.sqf ~L679: [['Igla_twice'],['2Rnd_Igla','2Rnd_Igla']]).
						//--- Same turret-path [-1] swap idiom as the AT branch above; _useAA is mutually exclusive with _useAT.
						if (_useAA) then {
							{_veh removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
							{_veh removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
							{_veh addWeaponTurret  [_x, [-1]]} forEach ["Igla_twice"];
							{_veh addMagazineTurret [_x, [-1]]} forEach ["2Rnd_Igla","2Rnd_Igla"];
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

						_defenders  = _defenders + [[_town, _veh, _grp, _pilot, _gunner, time, time]];
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
										_eGunner = objNull;
										_eGunner = [_crewClass, _grp, _ePos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _eGunner) then { _eGunner moveInGunner _eVeh2; };
										_swarmCrewReady = (!isNull _ePilot) && {!isNull _eGunner} && {((driver _eVeh2) == _ePilot)} && {((gunner _eVeh2) == _eGunner)};
										if (!_swarmCrewReady) then {
											Call _sliceCut; sleep 1; _sliceT0 = diag_tickTime;
											if ((driver _eVeh2) != _ePilot) then { _ePilot moveInDriver _eVeh2; };
											if (!isNull _eGunner && {(gunner _eVeh2) != _eGunner}) then { _eGunner moveInGunner _eVeh2; };
											_swarmCrewReady = (!isNull _ePilot) && {!isNull _eGunner} && {((driver _eVeh2) == _ePilot)} && {((gunner _eVeh2) == _eGunner)};
										};
										if (!_swarmCrewReady) then {
											if (!isNull _ePilot && {!(isPlayer _ePilot)}) then { ["guerairdef-swarm-pilot", _ePilot, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _ePilot; };
											if (!isNull _eGunner && {!(isPlayer _eGunner)}) then { ["guerairdef-swarm-gunner", _eGunner, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eGunner; };
											if (!isNull _eVeh2 && {({isPlayer _x} count (crew _eVeh2)) == 0}) then { ["guerairdef-swarm-hull", _eVeh2, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eVeh2; };
											diag_log format ["GUERAIRDEF|SWARMFAIL|town=%1|class=%2|reason=crew_seat", (_town getVariable ["name","?"]), _class];
										};
										if (_swarmCrewReady) then {

											//--- Same loadout swap the leader got (kit parity): AT-5 set, or Igla AA set,
										//--- else the default recon MG. SAME turret-path [-1] remove/add idiom as above.
										if (_useAT) then {
											{_eVeh2 removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
											{_eVeh2 removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
											{_eVeh2 addWeaponTurret  [_x, [-1]]} forEach ["AT5Launcher","57mmLauncher"];
											{_eVeh2 addMagazineTurret [_x, [-1]]} forEach ["5Rnd_AT5_BRDM2","64Rnd_57mm"];
										};
										if (_useAA) then {
											{_eVeh2 removeMagazineTurret [_x, [-1]]} forEach ["100Rnd_762x54_PKT"];
											{_eVeh2 removeWeaponTurret  [_x, [-1]]} forEach ["PKT"];
											{_eVeh2 addWeaponTurret  [_x, [-1]]} forEach ["Igla_twice"];
											{_eVeh2 addMagazineTurret [_x, [-1]]} forEach ["2Rnd_Igla","2Rnd_Igla"];
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
										_defenders  = _defenders + [[_town, _eVeh2, _grp, _ePilot, _eGunner, time, time]];
										_aliveCount = _aliveCount + 1;
										_swarmMade  = _swarmMade + 1;
										};
									} else {
										//--- No pilot for the extra: tear down the empty hull so nothing leaks (freshly
										//--- created, no player possible). Group is shared/leader-owned — do NOT delete it.
										if (!isNull _eVeh2 && {({isPlayer _x} count (crew _eVeh2)) == 0}) then {["guerairdef-L521", _eVeh2, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eVeh2};
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

						//--- fix0807b (perf): close the slice HERE, between the swarm roll (up to 3 hulls +
						//--- crews + loadout swaps) and the paradrop build below. Live measurement (61-minute
						//--- window, wave0807a3) showed guer_airdef_cycle spikes up to ~593ms of unyielded active
						//--- CPU in a single maintain sweep, correlated with sweeps that spawned/respawned more
						//--- than one defender; this yield gives the scheduler a bounded WFBE_C_AIRDEF_CHUNK_SLEEP
						//--- breather mid-spawn instead of doing the whole swarm+paradrop build unbroken.
						Call _sliceYield;

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
									//--- Round ended while the drop was inbound: do not land a fresh squad after teardown -
									//--- every reaper has already stood down, so these troops would never be cleaned up.
									if (WFBE_GameOver) exitWith {};
									//--- The request captured _t/_tPos before the 20s approach delay. A capture or
									//--- region deactivation during that delay must cancel this still-empty group; otherwise
									//--- fresh troops land for a town that no longer admits a GUER defender. _drops is
									//--- pruned on the next maintain pass after this group becomes null.
									if (isNull _t || {(_t getVariable ["sideID", -1]) != WFBE_C_GUER_ID} || {!(_t getVariable ["wfbe_active", false])}) exitWith {
										deleteGroup _g;
										diag_log "GUERAIRDEF|DROPFAIL|reason=stale_town";
									};

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
											//--- r37 fail-clean: null chute must not setPos/moveInDriver; trooper free-falls.
											_chute = _chuteModel createVehicle [0,0,20];
											if (isNull _chute) then {
												_u setPos [_ux, _uy, _uz];
												diag_log format ["GUERAIRDEF|CHUTEFAIL|town=%1|class=%2|reason=chute_create", (_t getVariable ["name","?"]), _type];
												["WARNING", Format ["Server_GuerAirDef.sqf: drop chute create failed model [%1]; trooper free-falls.", _chuteModel]] Call WFBE_CO_FNC_LogContent;
												_chutes = _chutes + [[_u, objNull]];
												_built = _built + 1;
											} else {
												_chute setPos [_ux, _uy, _uz];
												_u moveInDriver _chute;
												if (driver _chute != _u) then {
													//--- seat fail: leave unit at altitude without broken chute attach
													_u setPos [_ux, _uy, _uz];
													["guerairdef-chute-seatfail", _chute, ""] Call WFBE_CO_FNC_LogVehDelete;
													deleteVehicle _chute;
													_chute = objNull;
													diag_log format ["GUERAIRDEF|CHUTEFAIL|town=%1|class=%2|reason=chute_seat", (_t getVariable ["name","?"]), _type];
												};
												_chutes = _chutes + [[_u, _chute]];
												_built = _built + 1;
											};
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
										if (!isNull _cc) then { ["guerairdef-L621", _cc, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _cc; };
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
						};
					} else {
						//--- No pilot: tear down the empty hull + group so nothing leaks.
						//--- B66: player-safe teardown (hull is freshly created with no moveIn yet,
						//--- but guard anyway to never delete a player that somehow boarded).
						if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then {["guerairdef-L647", _veh, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _veh};
						if (!isNull _grp) then {deleteGroup _grp};
						diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_pilot", (_town getVariable ["name","?"]), _class];
					};
				} else {
					//--- B66: player-safe teardown (freshly created empty hull).
					if (!isNull _veh && {({isPlayer _x} count (crew _veh)) == 0}) then {["guerairdef-L653", _veh, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _veh};
					diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=no_group", (_town getVariable ["name","?"]), _class];
				};
			} else {
				diag_log format ["GUERAIRDEF|SPAWNFAIL|town=%1|class=%2|reason=createVehicle_null", (_town getVariable ["name","?"]), _class];
			};
		};
		Call _sliceYield;
	} forEach towns;

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
	Call _sliceCut;
	if !(isNil "PerformanceAudit_Record") then {
		["guer_airdef_cycle", _perfActive, Format["towns:%1;airBefore:%2;airAfter:%3;dropsBefore:%4;dropsAfter:%5;markers:%6;cap:%7;dropCap:%8;chunkSleep:%9;slices:%10;sliceMaxMs:%11;wallMs:%12;airScan:%13;enemyAir:%14", count towns, _perfAirBefore, count _defenders, _perfDropsBefore, count _drops, count _airList, _maxAir, _dropMax, _chunkSleepTotal, _perfSlices, (_perfSliceMax * 1000) call PerformanceAudit_Round2, ((diag_tickTime - _perfStart) * 1000) call PerformanceAudit_Round2, _enemyAirScanned, count _enemyAirVehicles], "SERVER"] Call PerformanceAudit_Record;
	};
};
