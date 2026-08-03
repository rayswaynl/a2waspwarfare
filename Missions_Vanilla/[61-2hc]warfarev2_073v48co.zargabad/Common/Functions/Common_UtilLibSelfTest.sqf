/*
	Common_UtilLibSelfTest.sqf
	WFBE_CO_FNC_UtilLibSelfTest

	Optional boot smoke-test for the SQF utility library (hash store, vector math, delayless
	dispatch - card #25, GR-2026-07-08a). Gated by WFBE_C_UTIL_LIB_SELFTEST (default 0) - inert
	unless explicitly armed; called once from Init_Common.sqf, server-only.

	This is a self-test, not a unit-test framework: each check logs one WARNING line to RPT via
	WFBE_CO_FNC_LogContent only on FAILURE, and the whole run logs one final summary line. It
	exists specifically because this PR's review pass could not complete a network engine-
	verification round (no network access in this session) for two specific claims:
		1. whether A2 OA 1.64 natively provides any of the vector primitives this library
		   reimplements as manual arithmetic (Common_VectDot/VectCross/VectMagnitude) - if it
		   does, nothing here breaks, but the reimplementation may be partially redundant; and
		2. whether an FSM's first state genuinely runs its `init` code in the SAME execution
		   frame `execFSM` is called, with execFSM's argument bound to `_this` inside that state
		   (the delayless-dispatch claim in Common_DelaylessCall.sqf) - this check measures it
		   empirically via a GLOBAL marker variable (locals do NOT cross the spawn/FSM scope
		   boundary back to this caller - only mission-namespace globals do) rather than
		   asserting it.

	Run this once on a real server (arm the flag, join, read the RPT) before relying on the
	delayless-dispatch same-frame claim in any follow-up PR that adopts it on a real hot path.

	Params: none.
	Returns: nothing meaningful.
*/

private ["_pass","_fail","_hash","_dot","_cross","_mag","_solveOk","_lead","_normal","_normMag","_markerFsm","_markerSpawn"];

_pass = 0;
_fail = 0;

["INITIALIZATION", "Common_UtilLibSelfTest.sqf: starting (WFBE_C_UTIL_LIB_SELFTEST armed)."] Call WFBE_CO_FNC_LogContent;

//--- 1. Hash store round-trip.
_hash = [] call WFBE_CO_FNC_HashCreate;
_hash = [_hash, "alpha", 1] call WFBE_CO_FNC_HashSet;
_hash = [_hash, "bravo", 2] call WFBE_CO_FNC_HashSet;
_hash = [_hash, "alpha", 99] call WFBE_CO_FNC_HashSet; //--- overwrite.

if (([_hash, "alpha", -1] call WFBE_CO_FNC_HashGet) == 99) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH overwrite FAILED"] Call WFBE_CO_FNC_LogContent};
if (([_hash, "bravo", -1] call WFBE_CO_FNC_HashGet) == 2) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH get FAILED"] Call WFBE_CO_FNC_LogContent};
if (([_hash, "charlie", -1] call WFBE_CO_FNC_HashGet) == -1) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH default-miss FAILED"] Call WFBE_CO_FNC_LogContent};
if ([_hash, "bravo"] call WFBE_CO_FNC_HashHasKey) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH haskey-present FAILED"] Call WFBE_CO_FNC_LogContent};

_hash = [_hash, "bravo"] call WFBE_CO_FNC_HashRem;

if !([_hash, "bravo"] call WFBE_CO_FNC_HashHasKey) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH rem FAILED (key still present)"] Call WFBE_CO_FNC_LogContent};
if (([_hash, "alpha", -1] call WFBE_CO_FNC_HashGet) == 99) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: HASH rem side-effect FAILED (alpha lost)"] Call WFBE_CO_FNC_LogContent};

//--- 2. Vector math (known-value checks).
_dot = [[1,0,0],[0,1,0]] call WFBE_CO_FNC_VectDot;
if (_dot == 0) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", Format ["UtilLibSelfTest: VECT dot FAILED (%1)", _dot]] Call WFBE_CO_FNC_LogContent};

_cross = [[1,0,0],[0,1,0]] call WFBE_CO_FNC_VectCross;
if ((_cross select 0) == 0 && {(_cross select 1) == 0} && {(_cross select 2) == 1}) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", Format ["UtilLibSelfTest: VECT cross FAILED (%1)", _cross]] Call WFBE_CO_FNC_LogContent};

_mag = [[3,4,0]] call WFBE_CO_FNC_VectMagnitude;
if (abs (_mag - 5) < 0.001) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", Format ["UtilLibSelfTest: VECT magnitude FAILED (%1)", _mag]] Call WFBE_CO_FNC_LogContent};

_solveOk = [100, 0, 50] call WFBE_CO_FNC_VectElevationSolve;
if (_solveOk > -1) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: VECT elevation-solve FAILED (in-range case returned sentinel)"] Call WFBE_CO_FNC_LogContent};

_lead = [[0,0,0], [100,0,0], [0,10,0], 50] call WFBE_CO_FNC_VectLeadAngle;
if (count _lead > 0) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: VECT lead-angle FAILED (solvable case returned empty)"] Call WFBE_CO_FNC_LogContent};

_normal = [[0,0]] call WFBE_CO_FNC_VectSurfaceNormal;
_normMag = [_normal] call WFBE_CO_FNC_VectMagnitude;
if (abs (_normMag - 1) < 0.01 && {(_normal select 2) >= 0}) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", Format ["UtilLibSelfTest: VECT surface-normal FAILED (%1, mag=%2)", _normal, _normMag]] Call WFBE_CO_FNC_LogContent};

//--- 3. Delayless dispatch vs spawn - same-frame measurement via GLOBAL markers (locals do
//--- NOT cross back out of a spawned/FSM scope to this caller).
WFBE_UTILSELFTEST_FSM_FLAG = false;
[[], {WFBE_UTILSELFTEST_FSM_FLAG = true}] call WFBE_CO_FNC_DelaylessCall;
_markerFsm = WFBE_UTILSELFTEST_FSM_FLAG;

WFBE_UTILSELFTEST_SPAWN_FLAG = false;
[] spawn {WFBE_UTILSELFTEST_SPAWN_FLAG = true};
_markerSpawn = WFBE_UTILSELFTEST_SPAWN_FLAG;

["INFORMATION", Format ["UtilLibSelfTest: DELAYLESS same-frame=%1 (expected true) | SPAWN same-frame=%2 (expected false, contrast only)", _markerFsm, _markerSpawn]] Call WFBE_CO_FNC_LogContent;

if (_markerFsm) then {_pass = _pass + 1} else {_fail = _fail + 1; ["WARNING", "UtilLibSelfTest: DELAYLESS dispatch did NOT run same-frame - the execFSM _this-binding/same-frame assumption in Common_DelaylessCall.sqf may not hold on this build. Do not adopt Common_DelaylessCall on a real hot path until this is investigated."] Call WFBE_CO_FNC_LogContent};

WFBE_UTILSELFTEST_FSM_FLAG = nil;
WFBE_UTILSELFTEST_SPAWN_FLAG = nil;

["INITIALIZATION", Format ["Common_UtilLibSelfTest.sqf: complete - %1 passed, %2 failed.", _pass, _fail]] Call WFBE_CO_FNC_LogContent;
