/*
	DEBUG-ONLY -- mass-unit stresstest. Never enable outside a dedicated test deploy.

	Spawns WFBE_C_DEBUG_STRESS_SPAWN_GROUPS extra AI groups in staggered batches, alternating
	WEST/EAST/GUER, using the mission's own team-creation primitives (Common_CreateGroup.sqf +
	Common_CreateTeam.sqf -- the SAME calls Common_RunSidePatrol.sqf and AI_Commander_Teams.sqf
	use for real AI founding) so the extra load is realistic and participates in the mission's
	existing PerformanceAudit_Record("createteam", ...) instrumentation and the per-side 140-group
	cap + emergency-GC warning in Common_CreateGroup.sqf for free -- that cap is the natural,
	already-instrumented "cliff" signal for this tool; nothing extra is needed here to detect it.

	This file is deliberately isolated:
	  - The gate WFBE_C_DEBUG_STRESS_SPAWN_GROUPS is NOT registered in the live
	    Common/Init/Init_CommonConstants.sqf and is NOT exposed anywhere in Rsc/Parameters.hpp,
	    so it can never appear as a lobby toggle or be flipped on any normal deployment. See
	    Tools/Stresstest/patches/ for the two one-line snippets a stresstest branch applies.
	  - Nothing outside this file is touched. Revert = delete the 2 patch lines + this file, or
	    just never set the flag > 0 (its default read below is 0 = inert).

	Batch/interval/roster tuning lives as local constants below (not extra WFBE_C_* flags) to
	keep the footprint to exactly the "1 file + 2 lines" the design calls for -- edit this file
	directly to retune a future stresstest run.

	Logging: SPAWN_BATCH / SPAWN_COMPLETE / CAPPED use PLAIN diag_log (never
	WFBE_CO_FNC_LogContent), because WFBE_CO_FNC_LogContent is a no-op whenever WF_LOG_CONTENT is
	left commented out in version.sqf.template (the normal/release state) -- a stresstest run
	must never depend on that debug toggle to produce its own monitor signal.
*/

Private ["_want","_cap","_total","_batchSize","_intervalSec","_sides","_startTime",
         "_groupIdx","_cumulative","_batchStartCum","_side","_town","_nextTown","_pos",
         "_soldierCls","_truckPool","_roster","_team","_ret","_units"];

if (!isServer) exitWith {};

//--- Wait for the same readiness gate Init_Server.sqf itself blocks on (Server\Init\Init_Server.sqf,
//--- "waitUntil {commonInitComplete && townInit}") so `towns` is populated no matter how early this
//--- script is spawned from the init hook.
waitUntil {sleep 1; commonInitComplete && townInit};

_want = missionNamespace getVariable ["WFBE_C_DEBUG_STRESS_SPAWN_GROUPS", 0];
if (typeName _want != "SCALAR") then {
	diag_log format ["STRESSTEST|v1|WARNING|WFBE_C_DEBUG_STRESS_SPAWN_GROUPS is not a number (%1) - treating as 0.", _want];
	_want = 0;
};
if (_want <= 0) exitWith {}; //--- Flag off (default): byte-identical to not having this file at all.

//--- Hard cap regardless of configured value -- belt-and-suspenders so a mistyped huge number
//--- can never melt the box, independent of whatever WFBE_C_DEBUG_STRESS_SPAWN_GROUPS is set to.
_cap = 200;
_total = _want;
if (_total > _cap) then {
	diag_log format ["STRESSTEST|v1|CAPPED|requested=%1|cap=%2", _total, _cap];
	_total = _cap;
};

//--- Tuning (edit here, not via new flags -- keeps the live-mission diff to 2 lines).
_batchSize    = 10;  //--- groups created per batch before the stagger sleep.
_intervalSec  = 120; //--- seconds between batches (slow stagger -> a clean FPS-vs-count WASPSCALE curve, not one instant cliff-dive).

_sides = [west, east, resistance];

diag_log format ["STRESSTEST|v1|START|target=%1|batch=%2|intervalSec=%3", _total, _batchSize, _intervalSec];

_startTime = time;
_cumulative = 0;
_groupIdx = 0;

while {_groupIdx < _total} do {
	if (WFBE_GameOver) exitWith {
		diag_log format ["STRESSTEST|v1|ABORT|reason=WFBE_GameOver|cumulative=%1|target=%2", _cumulative, _total];
	};

	if (count towns == 0) exitWith {
		diag_log "STRESSTEST|v1|ABORT|reason=towns_empty";
	};

	_batchStartCum = _cumulative;
	while {_groupIdx < _total && {(_cumulative - _batchStartCum) < _batchSize}} do {
		_side     = _sides select (_groupIdx mod 3);
		_town     = towns select (_groupIdx mod (count towns));
		_nextTown = towns select ((_groupIdx + 1) mod (count towns));

		//--- Fixed-town position + small jitter so units don't stack on top of each other; towns
		//--- are the mission's own pre-placed AI-activity locations (same spots real town defense
		//--- and side patrols already operate at), not player HQs.
		_pos = [(getPos _town select 0) + ((random 100) - 50), (getPos _town select 1) + ((random 100) - 50), 0];

		//--- Small mixed roster: 4 infantry of the side's standard soldier class + (if the side has
		//--- one) its first supply-truck class, which Common_CreateTeam.sqf auto-crews with the
		//--- side's WFBE_%1CREW/PILOT class -- same dynamic per-side resolution Common_RunSidePatrol.sqf
		//--- uses for its convoy truck, so this works on every map/faction root without a hardcoded
		//--- classname. Roster size: 4 infantry + 0-1 vehicle(+1 crew) = 4-6 created units.
		_soldierCls = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
		_truckPool  = missionNamespace getVariable [Format ["WFBE_%1SUPPLYTRUCKS", str _side], []];
		_roster = [_soldierCls, _soldierCls, _soldierCls, _soldierCls];
		if (count _truckPool > 0) then {_roster = _roster + [_truckPool select 0]};

		_team = [_side, "stresstest"] Call WFBE_CO_FNC_CreateGroup;
		//--- global=true (6th arg), probability omitted -> Common_CreateTeam.sqf defaults it to -1
		//--- (always create every roster entry) so the group size is deterministic for load counting.
		_ret = [_roster, _pos, _side, true, _team, true] call WFBE_CO_FNC_CreateTeam;
		_units = _ret select 0;
		_team  = _ret select 2;

		//--- Move order via the mission's own simple-waypoint primitive (Common_WaypointSimple.sqf,
		//--- the same one Common_RunSidePatrol.sqf uses) so spawned groups actually path and tick,
		//--- not just idle -- realistic AI/pathfinding load, not a static unit count.
		if (!isNull _team && {count _units > 0}) then {
			[_team, getPos _nextTown, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple;
		};

		_cumulative = _cumulative + 1;
		_groupIdx = _groupIdx + 1;
	};

	diag_log format ["STRESSTEST|v1|SPAWN_BATCH|n=%1|target=%2|elapsedSec=%3", _cumulative, _total, round (time - _startTime)];

	if (_groupIdx < _total) then {sleep _intervalSec};
};

diag_log format ["STRESSTEST|v1|SPAWN_COMPLETE|n=%1|target=%2|elapsedSec=%3", _cumulative, _total, round (time - _startTime)];
