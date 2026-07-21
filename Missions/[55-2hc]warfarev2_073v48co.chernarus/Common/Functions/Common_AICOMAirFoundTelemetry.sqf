//--- ===================================================================
//--- Common_AICOMAirFoundTelemetry.sqf  (WFBE_CO_FNC_AICOMAirFoundTelemetry)
//--- P1.1 AIR-FOUNDING TELEMETRY (claude-main-builder-1, 2026-07-19; reworked 2026-07-19 per
//--- codex-main-sol-review-airpower-20260719 REJECT of PR #1160 head 86fb5ae71e).
//---
//--- Emits ONE reason-coded "AICOMAIR|v1|...|stage=found" line carrying the founding air-cap decision
//--- inputs, so the live "zero AICOM air / zero VEHLIFT" blocker can be identified from RPT BEFORE any air
//--- tuning (instrument-first, per the independent AICOM audit synthesis SHA256 2D50EA13...). The live
//--- default-ON AIRMOBILE/VEHLIFT path is NOT rebuilt - this only makes the founding decision observable.
//---
//--- DIAGNOSTIC ONLY: reads runtime state and writes a diag_log line. It changes NO founding, cap, bucket,
//--- or airlift behaviour. Gated by WFBE_C_AICOM_AIR_TELEMETRY (default 0): every call site is flag-guarded,
//--- so flag-off drops the call. Compile stays unconditional (Init_Common.sqf compiles this file like every
//--- other WFBE_CO_FNC_* there; only the call sites are gated - see Init_Common.sqf's own comment).
//--- The two declared-but-unread WFBE_C_AICOM_AIR_TELEMETRY* globals (Init_CommonConstants.sqf) and the
//--- one getVariable check per call site still execute - the SAME always-declare/always-check overhead
//--- every other default-0 WFBE_C_* flag in this codebase carries. That is "behaviour-equivalent", not a
//--- literal byte-for-byte no-op; no AI decision, RNG draw, position, or gameplay outcome differs.
//---
//--- Runs in the SERVER founding-worker context (AI_Commander_Teams.sqf is server-side, full-command mode).
//---
//--- ARGS: [_side, _reason, _founded, _pending, _target, _afN, _facN, _bucket, _eligAir, _vehs]
//---   _side    : founding side.
//---   _reason  : "at-target"     (founding early-exited at target BEFORE airfield discovery - throttled)
//---              | "founding"    (bucket resolved but overrides/gates/dispatch NOT yet run - NOT emitted
//---                               by the current callers; kept as a valid token for future callers)
//---              | "reject-funds"    (final pick resolved, commander cannot afford it this cycle)
//---              | "reject-factory"  (final pick resolved, side owns no matching factory - skipped)
//---              | "reject-no-spawn" (no spawn structure/HQ resolved - rare)
//---              | "founded"         (past every reject gate - the team WAS actually dispatched)
//---   _founded : founded team count (founding-gate numerator).
//---   _pending : pending team count.
//---   _target  : founding team target.
//---   _afN     : 1 = side holds an airfield, 0 = not, -1 = caller did not compute it -> probe read-only here.
//---   _facN    : 1 = side holds an Aircraft Factory, 0 = not, -1 = probe read-only here.
//---   _bucket  : founding bucket/type (0 inf, 1 light, 2 heavy, 3 air); -1 = not reached (at-target exit).
//---              Callers past the draw pass the FINAL post-override bucket (W7 Veteran / FORCED-ARTY / D4
//---              target-aware can re-pick outside the originally-drawn bucket) so this reflects reality.
//---   _eligAir : eligible AIR templates this cycle (= count of the air bucket); -1 = not reached.
//---   _vehs    : the caller's vehicles snapshot (reused to avoid a second world scan; nil -> re-read).
//---
//--- A2-OA-1.64 SAFE: string isKindOf on VEHICLE objects (never weapon/magazine classnames), getNumber config
//--- read, crew/side/isPlayer resolve, switch..do, 2-arg get/setVariable on the side-logic OBJECT (never a
//--- group, never the 3-arg missionNamespace public form). No params/pushBack/findIf; no forEach-exitWith to
//--- skip an iteration (exitWith is only a top-level early return and break-on-found, exactly as mainline).
//--- ===================================================================

private ["_side","_reason","_founded","_pending","_target","_afN","_facN","_bucket","_eligAir","_vehs"];
if (count _this < 10) exitWith {};
_side    = _this select 0;
_reason  = _this select 1;
_founded = _this select 2;
_pending = _this select 3;
_target  = _this select 4;
_afN     = _this select 5;
_facN    = _this select 6;
_bucket  = _this select 7;
_eligAir = _this select 8;
_vehs    = _this select 9;

//--- Master gate (defense-in-depth; mainline also flag-guards every call site, so flag-off = no call at all).
//--- FLAGGATE form (Tools/Lint/check_sqf.py): the guard must be a positive >/!=/== comparison the linter's
//--- regex recognises - a "<= 0 exitWith" early-return does NOT match, which is what tripped 3 FLAGGATE
//--- findings (one per CH/TK/ZG mirror) on the prior submission. Wrap the whole body in the SAME
//--- "> 0) then {...}" idiom every other flag-gated block in this codebase already uses instead.
if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TELEMETRY", 0]) > 0) then {
if (isNil "_vehs" || {typeName _vehs != "ARRAY"}) then {_vehs = vehicles};

private ["_sideText","_sideID","_logik"];
_sideText = str _side;
_sideID   = (_side) Call WFBE_CO_FNC_GetSideID;
_logik    = (_side) Call WFBE_CO_FNC_GetSideLogic;

//--- THROTTLE only the periodic "at-target" snapshot: the founding worker runs every cycle and, at steady
//--- state, sits at target, so an unthrottled snapshot would flood the RPT. Every OTHER reason is a rare,
//--- at-most-once-per-cycle terminal event (reject-funds/reject-factory/reject-no-spawn/founded) and is
//--- NEVER throttled. A2-OA: 2-arg get/setVariable on the side-logic OBJECT is reliable (mainline throttles
//--- wfbe_aicom_groupcap_warn_t on _logik the same way).
private ["_emit"];
_emit = true;
if (_reason == "at-target" && {!isNil "_logik"}) then {
	private ["_last","_sec"];
	_sec  = missionNamespace getVariable ["WFBE_C_AICOM_AIR_TELEMETRY_SEC", 30];
	_last = _logik getVariable ["wfbe_aicom_airtelem_t", -99999];
	if ((time - _last) < _sec) then {_emit = false} else {_logik setVariable ["wfbe_aicom_airtelem_t", time]};
};

if (_emit) then {
	//--- AIRFIELD / AIRCRAFT-FACTORY presence. When the caller passed -1 (its call site is BEFORE the mainline
	//--- airfield/factory discovery - the at-target exit), re-derive it READ-ONLY here, mirroring the mainline
	//--- scans in AI_Commander_Teams.sqf (~L302-348). exitWith below is break-on-found, exactly as mainline.
	private ["_hasAf","_hasFac"];
	_hasAf  = (_afN > 0);
	_hasFac = (_facN > 0);
	if (_afN < 0) then {
		_hasAf = false;
		private ["_afNames"];
		_afNames = ["NWAF","NEAF","Balota","Rasman AF"];
		{ if (!((_x select 1) in _afNames)) then {_afNames = _afNames + [_x select 1]} } forEach (missionNamespace getVariable [Format ["WFBE_%1_CAPTURE_UNLOCKS", _sideText], []]);
		{
			if (((_x getVariable ["sideID", -1]) == _sideID) && {(_x getVariable ["wfbe_is_airfield", false]) || {(_x getVariable ["name",""]) in _afNames} || {!(isNull (_x getVariable ["wfbe_airfield_hangar_obj", objNull]))}}) exitWith {_hasAf = true};
		} forEach towns;
	};
	if (_facN < 0) then {
		_hasFac = false;
		private ["_facStructNames","_facIdx2","_facClass2","_facStructs2"];
		_facStructNames = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
		if (!isNil "_facStructNames") then {
			_facIdx2 = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText]) find "Aircraft";
			if (_facIdx2 >= 0) then {
				_facClass2   = _facStructNames select _facIdx2;
				_facStructs2 = (_side) Call WFBE_CO_FNC_GetSideStructures;
				{ if (typeOf _x == _facClass2 && {alive _x}) exitWith {_hasFac = true} } forEach _facStructs2;
			};
		};
	};

	//--- ALIVE AIR by OWNER x TYPE over the snapshot. "sideAir" reproduces the founding flat-cap census
	//--- (crew side == _side OR, crewless, wfbe_side == _side) so _airAlive here EQUALS the number the cap gate
	//--- counts - that conflation (current crew side, not true ownership) is INTENTIONAL for _airAlive so the
	//--- audit sees exactly what the cap gate sees, warts included.
	//---
	//--- The sub-counts below fix the P1.1 rejection point "owner/type counts conflate current player aboard
	//--- with ownership and ignore retained-transport tag": _airAiOnly/_airPlayer are now a clean PARTITION of
	//--- _airAlive (a hull is in exactly one), instead of _airPlayer being an ambiguous side-note that leaves the
	//--- AI-only fraction implicit; and _airRetained separately counts hulls carrying the ONE explicit "this hull
	//--- is AICOM inventory" marker this codebase actually sets - wfbe_aicom_transport (Common_RunCommanderTeam.sqf
	//--- ~L591 at founding air-insert, ~L675 on WFBE_C_AICOM_AIR_RETAIN persistence) - so the audit can see how
	//--- many of the counted transports are TRUE retained AICOM assets vs merely same-side-crewed hulls (a
	//--- player's own aircraft, or an AI having hopped into a non-AICOM hull, both still pass the cap's crew-side
	//--- test). TYPE: plane (isKindOf "Plane") vs transport-heli (transportSoldier > 0) vs attack-heli
	//--- (transportSoldier 0), the codebase's own transport/attack split. Outer _x captured into _veh before the
	//--- inner isPlayer count rebinds _x (the documented inner-loop _x gotcha).
	private ["_airAlive","_airAtk","_airTrans","_airPlane","_airPlayer","_airAiOnly","_airRetained"];
	_airAlive = 0; _airAtk = 0; _airTrans = 0; _airPlane = 0; _airPlayer = 0; _airAiOnly = 0; _airRetained = 0;
	{
		private ["_veh"];
		_veh = _x;
		if (!isNull _veh && {alive _veh} && {_veh isKindOf "Air"}) then {
			private ["_sideOK","_isPlayerAir","_crew"];
			_sideOK = false; _isPlayerAir = false;
			_crew = crew _veh;
			if ((count _crew) > 0) then {
				if (side (_crew select 0) == _side) then {_sideOK = true};
				if (({isPlayer _x} count _crew) > 0) then {_isPlayerAir = true};
			} else {
				if ((_veh getVariable ["wfbe_side", sideUnknown]) == _side) then {_sideOK = true};
			};
			if (_sideOK) then {
				_airAlive = _airAlive + 1;
				//--- Ownership vs current-crew, kept as a clean partition (never both/neither).
				if (_isPlayerAir) then {_airPlayer = _airPlayer + 1} else {_airAiOnly = _airAiOnly + 1};
				//--- Explicit AICOM-owned retained-transport marker (independent of current crew).
				if (_veh getVariable ["wfbe_aicom_transport", false]) then {_airRetained = _airRetained + 1};
				if (_veh isKindOf "Plane") then {
					_airPlane = _airPlane + 1;
				} else {
					if ((getNumber (configFile >> "CfgVehicles" >> (typeOf _veh) >> "transportSoldier")) > 0) then {_airTrans = _airTrans + 1} else {_airAtk = _airAtk + 1};
				};
			};
		};
	} forEach _vehs;

	//--- Caps + own-town context (all read-only; the same consts/census the founding gate uses).
	private ["_min","_late","_airMax","_minTowns","_ownTowns","_bText"];
	_min      = round (time / 60);
	_late     = (time / 60) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_LATE_MINS", 45]);
	_airMax   = if (_late) then {missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_LATE", 7]} else {missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_TOTAL", 3]};
	_minTowns = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3];
	_ownTowns = 0;
	{ if ((_x getVariable ["sideID", -1]) == _sideID) then {_ownTowns = _ownTowns + 1} } forEach towns;
	_bText = switch (_bucket) do { case 0: {"inf"}; case 1: {"light"}; case 2: {"heavy"}; case 3: {"air"}; default {"n/a"} };

	//--- ONE reason-coded raw diag_log token (greppable; mirrors the AICOMSTAT|v2| convention). Server RPT.
	diag_log ("AICOMAIR|v1|" + _sideText + "|" + str _min + "|stage=found|reason=" + _reason + "|founded=" + str _founded + "|pending=" + str _pending + "|target=" + str _target + "|airfield=" + (if (_hasAf) then {"1"} else {"0"}) + "|airfactory=" + (if (_hasFac) then {"1"} else {"0"}) + "|airAlive=" + str _airAlive + "|airAtk=" + str _airAtk + "|airTrans=" + str _airTrans + "|airPlane=" + str _airPlane + "|airPlayer=" + str _airPlayer + "|airAiOnly=" + str _airAiOnly + "|airRetained=" + str _airRetained + "|airMax=" + str _airMax + "|late=" + (if (_late) then {"1"} else {"0"}) + "|minTowns=" + str _minTowns + "|ownTowns=" + str _ownTowns + "|eligAir=" + str _eligAir + "|bucket=" + _bText);
};
};
