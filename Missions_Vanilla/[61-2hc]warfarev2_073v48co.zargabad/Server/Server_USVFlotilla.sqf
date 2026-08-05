//--- Server_USVFlotilla.sqf - GUER coastal USV flotilla (fable/usv-flotilla, owner 2026-07-08).
//--- Called once from Init_Server.sqf, guarded by WFBE_C_USV_FLOTILLA_ENABLE. ONE global
//--- maintain-loop (registry pattern, mirrors Server_GuerAirDef.sqf) - NOT one thread per boat,
//--- and NOT per-HVT sub-threads like Init_NavalHVT.sqf's CAP (that shape is for 3 independent
//--- carriers; this is ONE flotilla enforcing a single global WFBE_C_USV_FLOTILLA_COUNT cap).
//---
//--- WHAT THIS IS: a 3-boat GUER flotilla (PBX hull + one attachTo'd crew-served static per boat -
//--- AA=ZU23_Gue, ROCKET=SPG9_Gue, HMG=DSHKM_Gue, one of each by default) that roams a pre-placed
//--- coastal waypoint route, L-39-circuit style (Init_NavalHVT.sqf:683-865).
//---
//--- CRITICAL DEVIATION FROM THE SCUD PRECEDENT (Init_NavalHVT.sqf:341-393): the attached static is
//--- NEVER frozen (no enableSimulation false) and the boat is NEVER frozen either - the crew must be
//--- able to traverse/fire the weapon while the hull is under way (owner 2026-07-08, explicit). THIS
//--- IS THE ONE GENUINELY UNVERIFIED ENGINE BEHAVIOUR IN THE BUILD (FINAL-SPECS.md point 8: the only
//--- attachTo-a-live-object precedent, Zeta_Hook.sqf:33-35, requires crew=0 pre-attach and says
//--- nothing about firing after; the only attachTo-while-parent-moves precedent is the frozen SCUD).
//--- See USV-FLOTILLA-BUILD.md's SPIKE CHECKLIST before flipping WFBE_C_USV_FLOTILLA_ENABLE=1 live.
//---
//--- ACTIVATION GATE (owner 2026-07-08, modelled on server_town_camp.sqf's WFBE_C_TOWN_CAMP_ACTIVE_GATE
//--- idle-when-dormant shape): the flotilla only exists while EITHER
//---   (a) any town tagged wfbe_is_coastal has wfbe_active==true, OR
//---   (b) a player is within WFBE_C_USV_CARRIER_APPROACH_RADIUS of a naval-HVT carrier logic
//---       (WFBE_NAVAL_HVT_LOGICS, published by Init_NavalHVT.sqf:622, tagged wfbe_is_naval_hvt
//---       true at Init_NavalHVT.sqf:223,252,270).
//--- Gate false -> quiet-despawn on the same timer the naval CAP uses (Init_NavalHVT.sqf:882-907,
//--- WFBE_C_USV_FLOTILLA_QUIET_DESPAWN, default 120s, shared across the whole flotilla).
//---
//--- wfbe_is_coastal TAGGING: no coastline data exists in a text repo, and
//--- Common_GetRandomPosition.sqf's water-REJECTION loop (confirmed wrong tool for this domain,
//--- USV-DESIGN.md paragraph 4) proves the only cheap A2-OA-safe water test available is a bounded
//--- surfaceIsWater ring-probe. Done ONCE at boot below (~8 probes/town, zero per-tick cost) -
//--- see USV-FLOTILLA-BUILD.md SS2 for the full reasoning.
//---
//--- MAP GATE: piggybacks on the EXISTING IS_naval_map define (NOT a new IS_USV_MAP). Trigger (b)
//--- structurally requires WFBE_NAVAL_HVT_LOGICS, which only exists when IS_naval_map=true
//--- (Chernarus only, version.sqf.template:9) and WFBE_C_NAVAL_HVT=1. See USV-FLOTILLA-BUILD.md SS2
//--- for the TK/ZG tradeoff this accepts.
//---
//--- WAYPOINT SOURCE: pre-placed Game-Logic markers WFBE_USV_WP_CH_1.._N (owner-placed in the
//--- editor, Init Variable Name), collected below exactly like Init_NavalHVT.sqf:128-144's
//--- town-logic lookup. NOT Common_GetRandomPosition.sqf (rejects water, wrong domain). Hard
//--- prerequisite - see USV-FLOTILLA-BUILD.md SPIKE CHECKLIST item 1.
//---
//--- PERF SCOPE (owner-confirmed, task brief): boat-mounted statics are a roaming-unit spawn gated
//--- by WFBE_C_USV_FLOTILLA_COUNT (3), NOT a town-static-count entry - the 2026-06-16 GUER-statics
//--- perf directive (Defenses_GUE.sqf:17-21, town-defense PURCHASE ROSTER only) does not apply here.

if (!isServer) exitWith {};
if !(missionNamespace getVariable ["IS_naval_map", false]) exitWith {["INFORMATION", Format ["Server_USVFlotilla.sqf : IS_naval_map=false (worldName=%1) - USV flotilla piggybacks on the naval-carrier map gate (see header), disabled here.", worldName]] Call WFBE_CO_FNC_LogContent};
if ((missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_ENABLE", 0]) != 1) exitWith {
	["INFORMATION", "Server_USVFlotilla.sqf : WFBE_C_USV_FLOTILLA_ENABLE=0 - feature is OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Server_USVFlotilla.sqf : USV flotilla feature ENABLED - waiting for townInit."] Call WFBE_CO_FNC_LogContent;

waitUntil { !isNil "townInit" && townInit };
waitUntil { !isNil "towns" && {count towns > 0} };

private ["_coastalRadius","_coastalSamples","_coastalCount","_tPos","_isCoastal","_s","_ang","_probe",
         "_wps","_wpIdx","_wpVar","_wpLogic","_route","_count","_side","_hull","_roles","_loadouts",
         "_mountOffset","_approachRadius","_quietDespawn","_unstuckMax","_arriveRadius","_tickInterval",
         "_flotilla","_gateInactiveTime","_gateWasActive","_rumorLast"];

//------------------------------------------------------------------------------------
//--- ONE-TIME: tag every town wfbe_is_coastal by ring-sampling surfaceIsWater around its position.
//------------------------------------------------------------------------------------
_coastalRadius  = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_COASTAL_CHECK_RADIUS", 400];
_coastalSamples = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_COASTAL_CHECK_SAMPLES", 8];
_coastalCount = 0;
{
	_tPos = getPos _x;
	_isCoastal = false;
	for "_s" from 0 to (_coastalSamples - 1) do {
		if (!_isCoastal) then {
			_ang = _s * (360 / _coastalSamples);
			_probe = [(_tPos select 0) + _coastalRadius * sin _ang, (_tPos select 1) + _coastalRadius * cos _ang, 0];
			if (surfaceIsWater _probe) then {_isCoastal = true};
		};
	};
	_x setVariable ["wfbe_is_coastal", _isCoastal];
	if (_isCoastal) then {_coastalCount = _coastalCount + 1};
} forEach towns;
diag_log format ["USVFLOTILLA|COASTAL-TAG|coastal=%1|total=%2|radius=%3|samples=%4", _coastalCount, count towns, _coastalRadius, _coastalSamples];

//------------------------------------------------------------------------------------
//--- ONE-TIME: collect pre-placed coastal waypoint logics WFBE_USV_WP_CH_1.._N. Warn (not
//--- hard-fail) on a marker not actually over water, matching Init_NavalHVT.sqf:151-157.
//------------------------------------------------------------------------------------
_wps = [];
_wpIdx = 1;
_wpVar = format ["WFBE_USV_WP_CH_%1", _wpIdx];
_wpLogic = missionNamespace getVariable [_wpVar, objNull];
while {!isNull _wpLogic} do {
	if (!(surfaceIsWater (getPos _wpLogic))) then {
		diag_log format ["USVFLOTILLA-WARN: waypoint [%1] is NOT over water at %2 - fix mission.sqm coord.", _wpVar, getPos _wpLogic];
	};
	_wps = _wps + [_wpLogic];
	_wpIdx = _wpIdx + 1;
	_wpVar = format ["WFBE_USV_WP_CH_%1", _wpIdx];
	_wpLogic = missionNamespace getVariable [_wpVar, objNull];
};

if (count _wps < 2) exitWith {
	["WARNING", Format ["Server_USVFlotilla.sqf : only %1 WFBE_USV_WP_CH_* waypoint(s) found (need >=2 for a route) - owner must place coastal Game-Logic markers before this feature can roam. Exiting.", count _wps]] Call WFBE_CO_FNC_LogContent;
};

_route = _wps;
diag_log format ["USVFLOTILLA|ROUTE|waypoints=%1", count _route];

//------------------------------------------------------------------------------------
//--- Loadout table: role -> attachTo static classname. All three config-proof present
//--- (Core_GUE.sqf:143,146,149, isClass-guarded loop at :154-159).
//------------------------------------------------------------------------------------
_loadouts = [
	["AA",     "ZU23_Gue"],
	["ROCKET", "SPG9_Gue"],
	["HMG",    "DSHKM_Gue"]
];

_side           = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_SIDE", "GUER"];
_hull           = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_HULL", "PBX"];
_roles          = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_ROLES", ["AA","ROCKET","HMG"]];
_count          = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_COUNT", 3];
_mountOffset    = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_MOUNT_OFFSET", [0, -0.8, 1.0]];
_approachRadius = missionNamespace getVariable ["WFBE_C_USV_CARRIER_APPROACH_RADIUS", 1800];
_quietDespawn   = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_QUIET_DESPAWN", 120];
_unstuckMax     = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_UNSTUCK_MAX", 5];
_arriveRadius   = missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_ARRIVE_RADIUS", 50];
_tickInterval   = 10; //--- matches Init_NavalHVT.sqf's CAP tick cadence (Init_NavalHVT.sqf:705).

["INITIALIZATION", Format ["Server_USVFlotilla.sqf: flotilla loop starting (count=%1 roles=%2 hull=%3 route=%4wp).", _count, _roles, _hull, count _route]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- Live registry, script-local (NOT wfbe_persistent) so it cannot outlive a despawn/leak groups.
//--- Each entry: [_role, _boat, _static, _gunner, _driver, _grp, _spawnTime, _routeI, _stuckTicks,
//---              _lastPos, _unstuckStreak].
//------------------------------------------------------------------------------------
_flotilla = [];
_gateInactiveTime = 0;
_gateWasActive = false;
_rumorLast = -1;

while {!WFBE_GameOver} do {
	sleep _tickInterval;

	private ["_now","_kept","_gateActive","_gateReason","_carrierLogics"];
	_now = time;

	//=== (1) EVALUATE ACTIVATION GATE ========================================================
	//--- (a) any wfbe_is_coastal town with wfbe_active==true.
	_gateActive = false;
	_gateReason = "";
	{
		private ["_gTown"];
		_gTown = _x;
		//--- fable/usv-player-gate (owner 2026-07-28: "USVs also seem active the entire time... Waste
		//--- of ai"): town activation is mostly AI-driven and on this coastline some coastal town is
		//--- active nearly all match - branch (a) alone held the flotilla (6 AI + 6 objects) up
		//--- permanently. The flotilla is coastal THEATER: without a player audience it is pure sim
		//--- load. When armed, this branch additionally requires a live non-HC player near the active
		//--- coastal town (same playableUnits + HC-name idiom as the carrier branch below, which
		//--- already required a player). 0 = legacy activation-only gate. _gTown is captured BEFORE
		//--- the count - count {} rebinds _x (A2 trap; the carrier branch below logs a post-count _x).
		if ((_gTown getVariable ["wfbe_is_coastal", false])
			&& {_gTown getVariable ["wfbe_active", false]}
			&& {((missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_PLAYER_GATE", 0]) <= 0)
				|| {({isPlayer _x && {alive _x} && {(side _x) != civilian} && {!((name _x) in WFBE_C_HC_NAMES)} && {(_x distance _gTown) < (missionNamespace getVariable ["WFBE_C_USV_FLOTILLA_PLAYER_RADIUS", 1500])}} count playableUnits) > 0}}) exitWith {
			_gateActive = true;
			_gateReason = format ["coastal_town:%1", _gTown getVariable ["name","?"]];
		};
	} forEach towns;

	//--- (b) any player within approach radius of a naval-HVT carrier logic. Lazily read:
	//--- Init_NavalHVT.sqf publishes this async (execVM, not blocking) - reading it fresh every
	//--- tick means no hard wait/race, self-heals the moment the carrier feature finishes booting.
	if (!_gateActive) then {
		_carrierLogics = missionNamespace getVariable ["WFBE_NAVAL_HVT_LOGICS", []];
		{
			private "_cPos";
			_cPos = getPos _x;
			//--- wasp-navalcap-playableunits: same HC hardening as the Init_NavalHVT.sqf CAP arm gate -
			//--- a sea-parked headless-client body (isPlayer TRUE, alive, CIV) inside the approach
			//--- radius would hold this flotilla gate open forever. Side + known-HC-name filter.
			if ({isPlayer _x && {alive _x} && {(side _x) != civilian} && {!((name _x) in WFBE_C_HC_NAMES)} && {(_x distance _cPos) < _approachRadius}} count playableUnits > 0) exitWith {
				_gateActive = true;
				_gateReason = format ["carrier_approach:%1", _x getVariable ["name","?"]];
			};
		} forEach _carrierLogics;
	};

	if (_gateActive && {!_gateWasActive}) then {
		diag_log format ["USVFLOTILLA|GATE|OPEN|reason=%1", _gateReason];
		if ((missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR", 0]) > 0) then {
			if ((time - _rumorLast) >= (missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL", 120])) then {
				[nil, "DashboardAnnounce", ["Hostile small craft are active on the coast."]] Call WFBE_CO_FNC_SendToClients;
				_rumorLast = time;
			};
		};
	};
	if (!_gateActive && _gateWasActive) then { diag_log "USVFLOTILLA|GATE|CLOSE"; };
	_gateWasActive = _gateActive;

	//--- Reset immediately on an open gate, before the terminal quiet-despawn prune can consume
	//--- stale elapsed time. An inactive tick advances the shared countdown toward the configured
	//--- quiet-despawn threshold.
	if (_gateActive) then { _gateInactiveTime = 0; } else { _gateInactiveTime = _gateInactiveTime + _tickInterval; };

	//=== (2) PRUNE + SELF-CLEAN + MOVEMENT TICK ================================================
	_kept = [];
	{
		private ["_entry","_eRole","_eBoat","_eStatic","_eGunner","_eDriver","_eGrp","_eSpawn","_eRouteI",
		         "_eStuck","_eLastPos","_eUnstuck","_drop","_reason","_curPos","_target","_dist","_boatHasPlayer","_staticHasPlayer"];
		_entry    = _x;
		_eRole    = _entry select 0;
		_eBoat    = _entry select 1;
		_eStatic  = _entry select 2;
		_eGunner  = _entry select 3;
		_eDriver  = _entry select 4;
		_eGrp     = _entry select 5;
		_eSpawn   = _entry select 6;
		_eRouteI  = _entry select 7;
		_eStuck   = _entry select 8;
		_eLastPos = _entry select 9;
		_eUnstuck = _entry select 10;

		_drop = false; _reason = "";

		//--- Hull destroyed -> prune.
		if (isNull _eBoat || {!(alive _eBoat)}) then { _drop = true; _reason = "hull_destroyed"; };
		//--- r76 boat-patrol lifecycle: living hull with dead/null driver never reaped before (only hull
		//--- destroyed). Driverless boats beach and hold the flotilla slot so coastal sites cannot repopulate.
		//--- Spawn-time driver fail is open #1687; this is mid-life driver death.
		if (!_drop && {(isNull _eDriver) || {!alive _eDriver}}) then { _drop = true; _reason = "driver_lost"; };

		//--- Gate closed -> count down the FLOTILLA-WIDE quiet-despawn timer (shared across all
		//--- boats, since the gate itself is a flotilla-wide condition, not per-boat).
		if (!_drop && !_gateActive) then {
			if (_gateInactiveTime >= _quietDespawn) then { _drop = true; _reason = "gate_closed_quiet"; };
		};

		if (_drop) then {
			//--- Player-safe teardown (W13/B66 idiom, Server_GuerAirDef.sqf:220-227): never
			//--- deleteVehicle a player-occupied hull or static.
			_boatHasPlayer   = if (isNull _eBoat) then {false} else {({isPlayer _x} count (crew _eBoat)) > 0};
			_staticHasPlayer = if (isNull _eStatic) then {false} else {({isPlayer _x} count (crew _eStatic)) > 0};
			if (!_boatHasPlayer && !_staticHasPlayer) then {
				//--- r77: delete alive mounts OR dead wrecks. Prior path only deleted alive hulls, so sunken/
				//--- destroyed boats left permanent wrecks while the slot freed - coastal repopulation still
				//--- collided with debris and attached statics never dismounted after hull death.
				if (!isNull _eStatic) then {
					if (alive _eStatic) then { {["usv-static-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _eStatic); };
					["usv-static-hull", _eStatic, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eStatic;
				};
				if (!isNull _eBoat) then {
					if (alive _eBoat) then { {["usv-boat-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _eBoat); };
					["usv-boat-hull", _eBoat, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eBoat;
				};
				//--- r70 empty-group lifecycle: wipe path only deleted crew when hulls still ALIVE; corpse-only
//--- groups made deleteGroup a silent no-op. Purge non-player group members first.
if (!isNull _eGrp) then {
{if (!isNull _x && {!isPlayer _x}) then {["usv-group-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach (units _eGrp);
if (({isPlayer _x} count (units _eGrp)) == 0) then { deleteGroup _eGrp; };
};
			};
			diag_log format ["USVFLOTILLA|DESPAWN|role=%1|reason=%2|playerAboard=%3", _eRole, _reason, (_boatHasPlayer || _staticHasPlayer)];
		} else {
			//--- Movement only while the gate is active - a despawn-pending boat just drifts.
			if (_gateActive && {count _route > 0} && {!isNull _eBoat} && {alive _eBoat}) then {
				_target = _route select _eRouteI;
				//--- r77: a deleted/null route GameLogic must not abort the maintain loop.
				if (isNull _target) then {
					_eRouteI = (_eRouteI + 1) mod (count _route);
					_target = _route select _eRouteI;
				};
				if (!isNull _target) then {
				_curPos = getPos _eBoat;
				_dist = _curPos distance (getPos _target);

				//--- Arrived -> advance, wrapping for CONTINUOUS roam (not a lap-counted circuit like
				//--- the L-39 CAP - owner asked for a roaming coastal presence, not a timed patrol;
				//--- the lap/airfield-leg logic is fixed-wing-specific and intentionally dropped).
				if (_dist < _arriveRadius) then {
					_eRouteI = (_eRouteI + 1) mod (count _route);
					_target = _route select _eRouteI;
				} else {
					//--- EN-ROUTE never-frozen guard, water-adapted from Common_RunSidePatrol.sqf:325-400
					//--- (USV-DESIGN.md SS8): a boat wedges on a shoreline exactly like a ground unit
					//--- wedges on a town approach. 3 consecutive <25m-progress ticks = wedged.
					if ((_curPos distance _eLastPos) < 25) then { _eStuck = _eStuck + 1; } else { _eStuck = 0; };
					_eLastPos = _curPos;
					if (_eStuck >= 3) then {
						_eStuck = 0;
						//--- wasp-navalcap-playableunits: alive was MISSING here (a dead body 100m away kept a
						//--- wedged boat on the gentle velocity-hop path forever), and the same HC edge case
						//--- applies - a sea-parked HC body near the route must not count as a player.
						if ({isPlayer _x && {alive _x} && {(side _x) != civilian} && {!((name _x) in WFBE_C_HC_NAMES)} && {(_x distance _eBoat) < 100}} count playableUnits > 0) then {
							//--- Player-near velocity hop (Common_RunSidePatrol.sqf:358-359), generalizes to water.
							_eBoat setVelocity [(velocity _eBoat) select 0, (velocity _eBoat) select 1, 4];
						} else {
							//--- No player near: setPos to a known-good WATER route point (prev first).
							//--- r76: if prev WP is dry (misplaced logic), scan route for water instead of beaching.
							private ["_uPos","_uTry","_uI","_uP","_uLogic"];
							_uLogic = _route select ((_eRouteI - 1 + (count _route)) mod (count _route));
							_uPos = if (isNull _uLogic) then {[0,0,0]} else {getPos _uLogic};
							if (isNull _uLogic || {!(surfaceIsWater _uPos)}) then {
								_uTry = 0;
								while {_uTry < (count _route) && {(isNull _uLogic) || {!(surfaceIsWater _uPos)}}} do {
									_uI = (_eRouteI + _uTry) mod (count _route);
									_uLogic = _route select _uI;
									if (!isNull _uLogic) then {
										_uP = getPos _uLogic;
										if (surfaceIsWater _uP) then {_uPos = _uP};
									};
									_uTry = _uTry + 1;
								};
							};
							if (surfaceIsWater _uPos) then {_eBoat setPos _uPos};
						};
						diag_log format ["USVFLOTILLA|UNSTUCK|role=%1|streak=%2", _eRole, _eUnstuck + 1];
						_eUnstuck = _eUnstuck + 1;
						if (_eUnstuck >= _unstuckMax) then {
							_eUnstuck = 0;
							_eRouteI = (_eRouteI + 1) mod (count _route); //--- skip the leg, matches L-39's 120s-timeout leg-skip.
							diag_log format ["USVFLOTILLA|SKIPLEG|role=%1", _eRole];
						};
					};
				};

				if (!isNull _target && {!isNull _eDriver} && {alive _eDriver}) then { _eDriver doMove (getPos _target); };
				}; //--- closes !isNull _target
			};

			_kept = _kept + [[_eRole, _eBoat, _eStatic, _eGunner, _eDriver, _eGrp, _eSpawn, _eRouteI, _eStuck, _eLastPos, _eUnstuck]];
		};
	} forEach _flotilla;
	_flotilla = _kept;

	//=== (3) MAINTAIN: spawn missing boats up to WFBE_C_USV_FLOTILLA_COUNT while gate is active =====
	if (_gateActive && {count _flotilla < _count} && {count _route > 0}) then {
		private ["_nextRole","_nextClass","_spawnPos","_spawnDir","_boat","_static","_grp","_driver","_gunner","_startI","_nextI","_nextWpPos","_toFirst","_candidateRole","_rolePresent"];

		//--- Refill the first missing configured role before normal round-robin selection. This keeps
		//--- the owner-default AA/ROCKET/HMG composition intact after a mid-cycle loss; once every
		//--- configured role is present, COUNT>3 still cycles roles by fleet size as before.
		_nextRole = "";
		{
			_candidateRole = _x;
			_rolePresent = false;
			{
				if ((_x select 0) == _candidateRole) then {_rolePresent = true};
			} forEach _flotilla;
			if (!_rolePresent && {_nextRole == ""}) then {_nextRole = _candidateRole};
		} forEach _roles;
		if (_nextRole == "") then {
			_nextRole = (_roles select ((count _flotilla) mod (count _roles)));
		};
		_nextClass = "";
		{ if ((_x select 0) == _nextRole) exitWith {_nextClass = _x select 1}; } forEach _loadouts;

		if (_nextClass != "") then {
			//--- Spread new boats along the route rather than clumping at waypoint 0.
			_startI = floor (((count _flotilla) * (count _route)) / (_count max 1)) mod (count _route);
			_nextI  = (_startI + 1) mod (count _route);
			//--- r77: never spawn on a dry/null route logic; scan for a water anchor and skip if none.
			private ["_spLogic","_spTry","_spI"];
			_spLogic = _route select _startI;
			_spawnPos = if (isNull _spLogic) then {[0,0,0]} else {getPos _spLogic};
			if (isNull _spLogic || {!(surfaceIsWater _spawnPos)}) then {
				_spTry = 0;
				while {_spTry < (count _route) && {(isNull _spLogic) || {!(surfaceIsWater _spawnPos)}}} do {
					_spI = (_startI + _spTry) mod (count _route);
					_spLogic = _route select _spI;
					if (!isNull _spLogic) then {
						_spawnPos = getPos _spLogic;
						if (surfaceIsWater _spawnPos) then {_startI = _spI; _nextI = (_startI + 1) mod (count _route);};
					};
					_spTry = _spTry + 1;
				};
			};
			_nextWpPos = if (isNull (_route select _nextI)) then {_spawnPos} else {getPos (_route select _nextI)};
			if (!(surfaceIsWater _nextWpPos)) then {_nextWpPos = _spawnPos};
			_spawnDir = random 360;

			//--- Boat, crewless first (createVehicle + CreateUnit/moveInDriver idiom, matches
			//--- Common_RunSidePatrol.sqf:100-117 / AI_Commander_Wildcard_GUER.sqf:348).
			_boat = objNull;
			if (surfaceIsWater _spawnPos) then {
				_boat = [_hull, _spawnPos, resistance, _spawnDir, false, true] Call WFBE_CO_FNC_CreateVehicle;
			} else {
				diag_log format ["USVFLOTILLA-WARN: no water spawn anchor on route (fleet=%1) - skip spawn tick.", count _flotilla];
			};

			if (!isNull _boat) then {
				//--- r38 fail-clean: group/driver create/seat fail must tear down hull (no permanent driverless boat).
				_grp = [resistance, "usv-flotilla"] Call WFBE_CO_FNC_CreateGroup;
				if (isNull _grp) then {
					["usv-boat-hull", _boat, ""] Call WFBE_CO_FNC_LogVehDelete;
					deleteVehicle _boat;
					["WARNING", Format ["Server_USVFlotilla.sqf: group create failed; hull deleted (role=%1).", _nextRole]] Call WFBE_CO_FNC_LogContent;
					diag_log format ["USVFLOTILLA|SPAWNFAIL|role=%1|reason=group_create", _nextRole];
				} else {
					_driver = [(missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"]), _grp, _spawnPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
					if (isNull _driver) then {
						["usv-boat-hull", _boat, ""] Call WFBE_CO_FNC_LogVehDelete;
						deleteVehicle _boat;
						deleteGroup _grp;
						["WARNING", Format ["Server_USVFlotilla.sqf: driver create failed; hull deleted (role=%1).", _nextRole]] Call WFBE_CO_FNC_LogContent;
						diag_log format ["USVFLOTILLA|SPAWNFAIL|role=%1|reason=driver_create", _nextRole];
					} else {
						_driver moveInDriver _boat;
						if (driver _boat != _driver) then {
							["usv-boat-unit", _driver, ""] Call WFBE_CO_FNC_LogVehDelete;
							deleteVehicle _driver;
							["usv-boat-hull", _boat, ""] Call WFBE_CO_FNC_LogVehDelete;
							deleteVehicle _boat;
							deleteGroup _grp;
							["WARNING", Format ["Server_USVFlotilla.sqf: driver seat failed; hull torn down (role=%1).", _nextRole]] Call WFBE_CO_FNC_LogContent;
							diag_log format ["USVFLOTILLA|SPAWNFAIL|role=%1|reason=driver_seat", _nextRole];
						} else {
							//--- Static weapon, crewless, attachTo idiom. Zeta_Hook.sqf:33-35 is the ONLY
							//--- attachTo-a-live-object precedent in this repo and REQUIRES crew count 0 before
							//--- attach - _static is created here with zero crew, matching that constraint.
							//--- CRITICAL: do NOT enableSimulation false on _static OR _boat (see header) - the
							//--- SCUD precedent freezes the child; this is a live, moving, crewed weapon mount.
							_static = createVehicle [_nextClass, _spawnPos, [], 0, "NONE"];
							if (!isNull _static && {count crew _static == 0}) then {
								_static attachTo [_boat, _mountOffset]; //--- PLACEHOLDER offset - hand-tune in-editor against the PBX model, same caveat as FINAL-SPECS.md's V3S bed offset [0,-1.2,1.1].
								_gunner = [(missionNamespace getVariable ["WFBE_GUERRESCREW", "GUE_Soldier_Crew"]), _grp, _spawnPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;
								if (isNull _gunner) then {
									//--- Gunner fail: drop static, keep driven bare boat (Scout Skiff hedge).
									detach _static;
									["usv-static-hull", _static, ""] Call WFBE_CO_FNC_LogVehDelete;
									deleteVehicle _static;
									_static = objNull;
									diag_log format ["USVFLOTILLA-WARN: gunner create failed for static [%1] - boat ships bare.", _nextClass];
									_boat setVariable ["wfbe_usv_flotilla", true, true];
									_boat setVariable ["wfbe_usv_role", _nextRole, true];
									_grp setBehaviour "AWARE";
									_grp setCombatMode "RED";
									_grp setSpeedMode "FULL";
									_toFirst = ((_nextWpPos select 0) - (_spawnPos select 0)) atan2 ((_nextWpPos select 1) - (_spawnPos select 1));
									_boat setVelocity [3 * sin _toFirst, 3 * cos _toFirst, 0];
									_driver doMove _nextWpPos;
									_flotilla = _flotilla + [[_nextRole, _boat, objNull, objNull, _driver, _grp, _now, _startI, 0, _spawnPos, 0]];
								} else {
									_gunner moveInGunner _static;
									if (gunner _static != _gunner) then {
										//--- Seat fail: drop static+gunner, keep driven bare boat.
										["usv-static-unit", _gunner, ""] Call WFBE_CO_FNC_LogVehDelete;
										deleteVehicle _gunner;
										_gunner = objNull;
										detach _static;
										["usv-static-hull", _static, ""] Call WFBE_CO_FNC_LogVehDelete;
										deleteVehicle _static;
										_static = objNull;
										diag_log format ["USVFLOTILLA-WARN: gunner seat failed for static [%1] - boat ships bare.", _nextClass];
										_boat setVariable ["wfbe_usv_flotilla", true, true];
										_boat setVariable ["wfbe_usv_role", _nextRole, true];
										_grp setBehaviour "AWARE";
										_grp setCombatMode "RED";
										_grp setSpeedMode "FULL";
										_toFirst = ((_nextWpPos select 0) - (_spawnPos select 0)) atan2 ((_nextWpPos select 1) - (_spawnPos select 1));
										_boat setVelocity [3 * sin _toFirst, 3 * cos _toFirst, 0];
										_driver doMove _nextWpPos;
										_flotilla = _flotilla + [[_nextRole, _boat, objNull, objNull, _driver, _grp, _now, _startI, 0, _spawnPos, 0]];
									} else {
										_boat   setVariable ["wfbe_usv_flotilla", true, true];
										_static setVariable ["wfbe_usv_flotilla", true, true];
										_boat   setVariable ["wfbe_usv_role", _nextRole, true];
										_grp setBehaviour "AWARE";
										_grp setCombatMode "RED";
										_grp setSpeedMode "FULL";
										//--- Belt-and-suspenders: small initial velocity toward the first leg + an immediate
										//--- doMove, so the boat is never inert-and-drifting between spawn and the first
										//--- while-loop tick (USV-DESIGN.md SS8's boat-specific spawn-drift note). Bearing
										//--- via atan2 (the same idiom FINAL-SPECS.md's Common_FindCampPos.sqf uses), NOT
										//--- getDir - getDir takes no second-position argument on A2 OA 1.64.
										_toFirst = ((_nextWpPos select 0) - (_spawnPos select 0)) atan2 ((_nextWpPos select 1) - (_spawnPos select 1));
										_boat setVelocity [3 * sin _toFirst, 3 * cos _toFirst, 0];
										_driver doMove _nextWpPos;
										_flotilla = _flotilla + [[_nextRole, _boat, _static, _gunner, _driver, _grp, _now, _nextI, 0, _spawnPos, 0]];
										["INFORMATION", Format ["Server_USVFlotilla.sqf: spawned %1 boat (%2 + %3) at wp#%4.", _nextRole, _hull, _nextClass, _startI]] Call WFBE_CO_FNC_LogContent;
										diag_log format ["USVFLOTILLA|SPAWN|role=%1|hull=%2|static=%3|wp=%4|fleet=%5/%6", _nextRole, _hull, _nextClass, _startI, count _flotilla, _count];
									};
								};
							} else {
								diag_log format ["USVFLOTILLA-WARN: static [%1] failed to create or spawned pre-crewed - this boat ships bare (no weapon mount).", _nextClass];
								//--- Boat itself still stands (bare hull, matching USV-FLOTILLA-VARIANTS.md #4's
								//--- "trivial" Scout Skiff hedge) rather than deleting a good hull over a bad static.
								_boat setVariable ["wfbe_usv_flotilla", true, true];
								_boat setVariable ["wfbe_usv_role", _nextRole, true];
								_grp setBehaviour "AWARE";
								_grp setCombatMode "RED";
								_grp setSpeedMode "FULL";
								_toFirst = ((_nextWpPos select 0) - (_spawnPos select 0)) atan2 ((_nextWpPos select 1) - (_spawnPos select 1));
								_boat setVelocity [3 * sin _toFirst, 3 * cos _toFirst, 0];
								_driver doMove _nextWpPos;
								_flotilla = _flotilla + [[_nextRole, _boat, objNull, objNull, _driver, _grp, _now, _startI, 0, _spawnPos, 0]];
							};
						};
					};
				};
			};
		};
	};
};
