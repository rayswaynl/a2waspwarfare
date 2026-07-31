/*
	AI_Commander_AirStrike.sqf - AICOM v2 M7 AIRSTRIKE closer (owner directive 2026-07-25: "leave [the
	ENDGAME_FORCE taper] alone, instead make sure ai commander jets / helicopters may target factories").
	Server-side, per side. Runs AFTER the M6 AIRRESP closer each strategy tick (AI_Commander.sqf ~L631,
	inside the same _aiStrategy-gated block as DECAP/AIRRESP).

	WHY THIS EXISTS: two independent read-only investigations (council-0725/update2-verdicts/
	diag-air-vs-factories.md, diag-decap-idle.md) confirmed NO existing AICOM mechanism lets air target
	an enemy factory, and the ONE structure-targeting mechanism that exists at all (the BASE-ASSAULT fire
	phase, Common_RunCommanderTeam.sqf ~L1878-2004) is ground-only and HQ-anchored (only engages within
	WFBE_C_AICOM_ASSAULT_ENGAGE_RANGE of the enemy HQ) - so a factory sitting in a garrisoned town far
	from a now-dead enemy HQ (the exact 2026-07-25 9-hour-round scenario: EAST's HQ died at minute 281,
	its 9-10 held towns' factories were never touched, WEST's DECAP was HQ-dead-gated for the remaining
	330 ticks) is unreachable by any existing code, air OR ground. DECAP (M5) cannot be repurposed for
	this: it is explicitly ground-only (excludes any team with a live Air-hull unit,
	AI_Commander_Decapitate.sqf:105/228) and hard-gated on the ENEMY HQ being ALIVE (:137) - it
	structurally cannot help raze a survivor's factories once that HQ is already dead. This closer is
	new, additive code - not a flag flip of anything dormant (confirmed by both investigations: the only
	other factory-razing code in the tree, the B74.1 OVERRUN block at AI_Commander_Strategy.sqf:1070, is
	separately dead-wired to a retired `_strikeOn` variable DECAP never sets - an independent, unrelated
	bug this PR does NOT touch; see PR body "Discovered, not fixed").

	FLAG: WFBE_C_AICOM2_AIRSTRIKE_ENABLE, default 0 (shadow-first, same convention as DECAP) - the mission
	is behaviourally inert with the flag at 0 (no dispatch, no funds/unit spend, no team stamps; the
	per-tick diag_log line still fires, mirroring DECAP's own always-on IDLE telemetry - observability is
	not a gameplay side effect). Requires a soak before the owner arms it, per AIRRESP/DECAP's own
	"HIGH-RISK core-AICOM lane" precedent.

	TARGET SELECTION (precise, not the BASE-ASSAULT phase's looser "everything but the HQ"): reuses the
	SAME GetFactories/BARRACKS+LIGHT+HEAVY+AIRCRAFT kind list the win condition itself counts
	(server_victory_threeway.sqf:140-143, factories==0) - so a successful strike moves the actual
	win-condition number, not just "some building." No town/HQ-anchoring: pulls the enemy's WHOLE side
	structure list via WFBE_CO_FNC_GetSideStructures directly (the same accessor BASE-ASSAULT/OVERRUN/the
	win condition itself all use) and picks the nearest LIVE one to OUR OWN HQ as the strike objective -
	this is what fixes the geography gate identified in the diagnosis: no proximity to the ENEMY HQ is
	required at all, so a factory in a distant garrisoned town (this round's actual problem) is reachable.

	AIR-CAP HEADROOM (checked BEFORE committing to a strike; at/above the cap the cycle is SKIPPED
	cleanly this tick, never a silent no-op and never an over-cap spawn): reuses the EXACT alive-hull-
	counting idiom AI_Commander_Teams.sqf ~L611-632 / AI_Commander_AirResp.sqf ~L149-160 already use
	(count alive isKindOf "Air" side-resolved), against the SAME WFBE_C_AICOM_AIR_MAX_TOTAL /
	_AIR_MAX_LATE / _AIR_LATE_MINS constants already registered for the founding path - no new cap
	constant, no double-count (this closer's own dispatched hull is counted by that same scan on the
	NEXT tick like every other AICOM air unit, exactly as AIRRESP's flights already are).

	PER-STRIKE COST (own separate, smaller budget so a factory hunt never crowds out AIRRESP's player-
	response role or the regular air-founder): WFBE_C_AICOM2_AIRSTRIKE_MAX_AIR, default 1 - at most ONE
	concurrent strike flight per side. One flight = one airframe hull + one pilot (+ one gunner only if
	WFBE_C_AIR_ATTACK_GUNNER > 0 and the airframe has an empty gunner seat) = one group. This budget is
	ADDITIONALLY bounded by the side-wide AIR_MAX_TOTAL/AIR_MAX_LATE headroom check above, so it can never
	push the side over its overall air ceiling even if AIRRESP has already spent hulls this tick.

	COOLDOWN (cannot spam): per-side last-dispatch stamp + WFBE_C_AICOM2_AIRSTRIKE_COOLDOWN (default
	900s = 15min), same gate shape as AI_Commander_Paratroops.sqf's cooldown idiom (stamp written only on
	an actual successful dispatch, so a failed create/pilot/group attempt does not eat the cooldown).

	DISPATCH: reuses AIRRESP's exact createVehicle+pilot(+gunner) idiom byte-for-byte (same attack-
	airframe allowlist, same W13 Gunship Strike lineage, same gunner-mount fix, same FLY-vs-FORM special
	spawn fix for fixed-wing) - proven, no new spawn primitive invented.

	ENGAGEMENT - THE NON-OPTIONAL, EVIDENCE-DRIVEN PIECE (see PR body "what will actually happen in game
	vs what is aspirational"): AIRRESP's own AIPatrol+COMBAT/RED is a PASSIVE orbit and would very likely
	reproduce the exact silent-degrade failure class this repo has already hit five times today - an
	aircraft that "dispatches" but never fires at a static, non-returning-fire building. Two independent
	in-repo comments (B74.1 OVERRUN, cmdcon41 BASE-ASSAULT) already concluded from live testing that "A2
	AI won't reliably shoot empty buildings" even for GROUND troops at zero range - that is why
	BASE-ASSAULT needed a scripted repeating reveal/doTarget/doFire retry loop instead of a single order.
	This closer gives the dispatched flight the SAME scripted loop (mirrors Common_RunCommanderTeam.sqf
	~L1955-1988 in shape): every ~10s, re-resolve the enemy's live factory list, pick the nearest
	still-alive one, lay a live SAD waypoint under it (never idle) and reveal/doTarget/doFire it from
	every live crew seat. NO LIVE RUNG-4 ENGINE PROBE of an AI aircraft actually destroying a factory-
	class object was run this pass (no offline test rig stood up in this session) - the BI wiki doFire
	contract ("a unit or a vehicle, but not an object", rung 2) plus this codebase's own two independent
	ground-testing comments are the only evidence behind "this retry loop is what makes AI weapons fire
	actually connect with a building." That is a precedent-based inference, not an engine-verified fact -
	state this explicitly rather than claiming the strike is guaranteed-lethal (see PR body).

	Runs as an async spawn after dispatch (mirrors AIRRESP's watchdog) so the ~360s-bounded fire loop
	never blocks the per-side strategy tick (a bare inline while/sleep here would stall this side's ENTIRE
	AICOM strategy tick for up to 6 minutes - not acceptable). Self-despawns on: no live enemy factories
	remain (success - the actual win-relevant condition), all crew dead, hold-time elapsed, the target
	resolve fails, or THIS side's own AI Commander would itself be stopped (own-HQ-alive gate,
	AI_Commander.sqf:297-300, re-read fresh every poll so a mid-flight HQ loss retires the flight instead
	of leaving an orphaned loop with no commander left to own it).

	State on the side logic: wfbe_aicom2_airstrike_last (cooldown stamp), wfbe_aicom2_airstrike_flights
	(array of [grp, heli, t0], server-local, mirrors AIRRESP's _flights shape - no broadcast needed, the
	watchdog spawn runs server-side same as this script). Telemetry AICOM2|v1|AIRSTRIKE.

	Does NOT touch: server_victory_threeway.sqf's win condition (unchanged), WFBE_C_ENDGAME_FORCE_ENABLE
	(left at its owner-declined default), wfbe_aicom_decap/wfbe_aicom_targets/any ground team's
	wfbe_aicom_alloc_target (ground authority stays exactly as-is), and no HandleSpecial/PVF case reaches
	a headless client from this file - it is pure server-side createVehicle/createGroup/doFire logic, so
	the HC allowlist (Client/Functions/Client_HandlePVF.sqf) needs no new entry.

	A2-OA-safe: private string-array only; no inline private _x=; no GROUP 2-arg getVariable; no
	NSSETVAR3; no A3 commands; >0 numeric-flag guards; if/else booleans (no ==/!= on Bool); outer _x/_kind
	captured into a named local before every inner forEach/count block; 2-operand reveal only.
*/

private ["_side","_logik","_sideID","_sideText","_enemySide","_enemyID","_enemySideText",
	"_now","_cool","_last","_cooldownOK",
	"_myHQ","_airAlive","_airSideOK","_late","_airMaxTotal","_hasAirFactory","_afStructNames","_afStructIdx","_afStructClass","_afStructs","_upgrades","_airOK",
	"_minTowns","_myTowns","_townsOK",
	"_maxAir","_flightsIn","_flights","_f","_fg","_fh",
	"_eStructs","_eFactories","_kind","_flist","_tgt","_tgtPos",
	"_skipReason","_canDispatch","_dispatched",
	"_airList","_attackClasses","_pilotClass","_ang","_spawnPos","_class","_special","_heli","_grp","_pilot",
	"_elMin"];

_side  = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
if (isNull _logik) exitWith {};

_sideID    = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText  = str _side;
_enemySide = if (_side == west) then {east} else {west}; //--- W/E toggle only, mirrors AIRRESP's own simplification (AI_Commander_AirResp.sqf:62) - same precedent, no new risk class.
_enemyID   = (_enemySide) Call WFBE_CO_FNC_GetSideID;
_enemySideText = str _enemySide;

_now = time;

//--- COOLDOWN (Paratroops idiom): per-side last-dispatch stamp, only advanced on an actual successful
//--- dispatch below - a failed create/pilot/group attempt never eats the cooldown window.
_cool = missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_COOLDOWN", 900];
_last = _logik getVariable "wfbe_aicom2_airstrike_last";
if (isNil "_last") then {_last = -1e9};
_cooldownOK = (_now - _last) >= _cool;

//--- ESTABLISHED-GATE (reuses AIRRESP's exact idiom, AI_Commander_AirResp.sqf:146-171): AICOM air
//--- founding already waives the AIR research tier once a side holds a live Aircraft Factory; reuse the
//--- same durable capability signal here rather than inventing a second one.
_airAlive = 0;
{
	if (alive _x && {_x isKindOf "Air"}) then {
		_airSideOK = false;
		if ((count crew _x) > 0) then {
			if (side ((crew _x) select 0) == _side) then {_airSideOK = true};
		} else {
			if ((_x getVariable ["wfbe_side", sideUnknown]) == _side) then {_airSideOK = true};
		};
		if (_airSideOK) then {_airAlive = _airAlive + 1};
	};
} forEach vehicles;
_hasAirFactory = false;
_afStructNames = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", _sideText], []];
_afStructIdx = (missionNamespace getVariable [Format ["WFBE_%1STRUCTURES", _sideText], []]) find "Aircraft";
if (_afStructIdx >= 0 && {_afStructIdx < count _afStructNames}) then {
	_afStructClass = _afStructNames select _afStructIdx;
	_afStructs = (_side) Call WFBE_CO_FNC_GetSideStructures;
	{ if (typeOf _x == _afStructClass && {alive _x}) exitWith {_hasAirFactory = true} } forEach _afStructs;
};
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_airOK = _hasAirFactory || {!isNil "_upgrades" && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0}};

_minTowns = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3]; //--- already registered (Init_CommonConstants.sqf:402), shared with W6/W13 + AIRRESP - reused as-is, no re-registration.
_myTowns = 0;
{ if ((_x getVariable ["sideID", -1]) == _sideID) then {_myTowns = _myTowns + 1} } forEach towns;
_townsOK = _myTowns >= _minTowns;

//--- AIR-CAP HEADROOM (checked BEFORE committing - owner requirement): same late-game ramp AI_Commander_
//--- Teams.sqf/Common_AICOMAirFoundTelemetry.sqf already use, same constants, no re-registration.
_late = (time / 60) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_LATE_MINS", 45]);
_airMaxTotal = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_TOTAL", 3];
if (_late) then {_airMaxTotal = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_LATE", 8]};

//--- OWN SMALL BUDGET: prune the tracked-flights array (drop any entry whose group/heli died since last
//--- tick - the watchdog self-cleans on hold-expiry/no-target, this just keeps our own count accurate).
_flightsIn = _logik getVariable ["wfbe_aicom2_airstrike_flights", []];
_flights = [];
{
	_f = _x;
	if (typeName _f == "ARRAY" && {count _f >= 2}) then {
		_fg = _f select 0; _fh = _f select 1;
		if (!isNull _fg && {({alive _x} count (units _fg)) > 0} && {!isNull _fh} && {alive _fh}) then {
			_flights = _flights + [_f];
		};
	};
} forEach _flightsIn;
_maxAir = missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_MAX_AIR", 1];

//--- TARGET SELECTION: the enemy's WHOLE structure list, filtered to the SAME BARRACKS/LIGHT/HEAVY/
//--- AIRCRAFT factory kinds the win condition counts (server_victory_threeway.sqf:140-143) - GetFactories
//--- already alive-filters and type-matches, so the HQ (a different CfgVehicles type) is never included
//--- without any manual exclusion needed. No town/HQ-proximity gate anywhere in this selection.
_myHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
_eStructs = (_enemySide) Call WFBE_CO_FNC_GetSideStructures;
if (isNil "_eStructs" || {typeName _eStructs != "ARRAY"}) then {_eStructs = []};
_eFactories = [];
{
	_kind = _x;
	_flist = [_enemySide, (missionNamespace getVariable Format ["WFBE_%1%2TYPE", _enemySideText, _kind]), _eStructs] Call GetFactories; //--- 1-arg getVariable, no default - matches server_victory_threeway.sqf:142 exactly (the win-condition itself relies on this var always being defined for a playable side; a "" default would only turn an already-impossible nil into a WORSE select-type error inside GetFactories, so omit it to mirror the proven idiom precisely).
	_eFactories = _eFactories + _flist;
} forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT"];

_tgt = objNull;
if (!isNull _myHQ && {count _eFactories > 0}) then {
	_tgt = [_myHQ, _eFactories] Call WFBE_CO_FNC_GetClosestEntity;
};

//--- Liveness telemetry: report the FIRST gate that would prevent a flight, not merely dispatched=0 -
//--- same shape as AIRRESP/DECAP so RPT windowing (rpt-triage) can grade this closer the same way.
_skipReason = "ready";
if ((missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_ENABLE", 0]) <= 0) then {_skipReason = "disabled"} else {
	if (!_cooldownOK) then {_skipReason = "cooldown"} else {
		if (!_airOK) then {_skipReason = "air-unavailable"} else {
			if (!_townsOK) then {_skipReason = "not-established"} else {
				if (_airAlive >= _airMaxTotal) then {_skipReason = "air-cap"} else {
					if ((count _flights) >= _maxAir) then {_skipReason = "own-budget"} else {
						if (isNull _myHQ) then {_skipReason = "no-hq-ref"} else {
							if (count _eFactories <= 0) then {_skipReason = "no-target"} else {
								if (isNull _tgt) then {_skipReason = "no-target"};
							};
						};
					};
				};
			};
		};
	};
};
_canDispatch = (_skipReason == "ready");

_dispatched = 0;
if (_canDispatch) then {
	_airList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
	_attackClasses = [];
	{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Ka52","Ka52Black","Mi24_D","Mi24_D_TK_EP1","Mi24_V","Mi24_P","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su25_TK_EP1","Su34","Su39"]) then {_attackClasses = _attackClasses + [_x]} } forEach _airList;
	_pilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
	if (count _attackClasses > 0 && {_pilotClass != ""}) then {
		_tgtPos = getPos _tgt;
		_ang = random 360;
		_spawnPos = [(_tgtPos select 0) + 2500 * sin _ang, (_tgtPos select 1) + 2500 * cos _ang, 300];
		_class = _attackClasses select floor(random count _attackClasses);
		//--- FIXED-WING FLY SPAWN (mirrors AI_Commander_AirResp.sqf:209-213 / Server_GuerAirDef.sqf): a
		//--- drawn plane spawns near-stalled at 300m under the default FORM special; helis are unaffected.
		_special = if (_class isKindOf "Plane") then {"FLY"} else {"FORM"};
		_heli = [_class, _spawnPos, _side, random 360, true, true, true, _special] Call WFBE_CO_FNC_CreateVehicle;
		if (!isNull _heli) then {
			_grp = [_side, "aicom-airstrike"] Call WFBE_CO_FNC_CreateGroup;
			if (!isNull _grp) then {
				_pilot = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _pilot) then {
					_pilot moveInDriver _heli;
					//--- ATTACK-HELI GUNNER (flag WFBE_C_AIR_ATTACK_GUNNER, default 0/byte-identical, already
					//--- registered): mirrors AI_Commander_AirResp.sqf:221-228 / Server_GuerAirDef.sqf:378-387.
					if ((missionNamespace getVariable ["WFBE_C_AIR_ATTACK_GUNNER", 0]) > 0 && {(_heli emptyPositions "gunner") > 0}) then {
						private "_gunner"; _gunner = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _gunner) then { _gunner moveInGunner _heli; };
					};
					_heli flyInHeight 200;
					_grp setBehaviour "COMBAT"; _grp setCombatMode "RED";
					_flights = _flights + [[_grp, _heli, _now]];
					_dispatched = 1;
					_skipReason = "fired";
					_logik setVariable ["wfbe_aicom2_airstrike_last", _now];

					["INFORMATION", Format ["AI_Commander_AirStrike.sqf: [%1] AIRSTRIKE dispatched vs %2 factory-class structure (%3 live enemy factories); no live engine test of AI-aircraft-vs-building destruction backs this dispatch - see PR body.", _side, _enemySide, count _eFactories]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (_now / 60)) + "|AIRSTRIKE_DISPATCH|vs=" + str _enemySide + "|liveFactories=" + str (count _eFactories));

					//--- WATCHDOG + SCRIPTED FIRE LOOP (async - never blocks this side's strategy tick).
					//--- Mirrors AIRRESP's watchdog shape for lifecycle, but replaces the passive AIPatrol
					//--- with the BASE-ASSAULT fire phase's reveal/doTarget/doFire retry loop (the ONLY
					//--- evidence-backed idiom in this codebase for getting AI weapons fire to connect with
					//--- a static structure) - see file header "ENGAGEMENT" section for the evidence caveat.
					[_grp, _heli, _side, _enemySide] spawn {
						private ["_g","_h","_sd","_esd","_elapsed","_hold","_sadR","_poll","_hot","_myHQw","_eStructsW","_eFactoriesW","_kindW","_flistW","_tgtW"];
						_g = _this select 0; _h = _this select 1; _sd = _this select 2; _esd = _this select 3;
						_hold = missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_HOLD", 360];
						_sadR = missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_SAD", 150];
						_poll = 10; _elapsed = 0; _hot = true;
						while {_hot && {_elapsed < _hold} && {!isNull _g} && {({alive _x} count (units _g)) > 0} && {!isNull _h} && {alive _h}} do {
							//--- Own-HQ-alive re-check (AI_Commander.sqf:297-300): if this side's own AI
							//--- Commander would itself be stopped, retire the flight - no commander is left
							//--- to own an orphaned strike loop.
							_myHQw = _sd Call WFBE_CO_FNC_GetSideHQ;
							if (isNull _myHQw || {!(alive _myHQw)}) exitWith {_hot = false};

							_eStructsW = _esd Call WFBE_CO_FNC_GetSideStructures;
							if (isNil "_eStructsW" || {typeName _eStructsW != "ARRAY"}) then {_eStructsW = []};
							_eFactoriesW = [];
							{
								_kindW = _x;
								_flistW = [_esd, (missionNamespace getVariable Format ["WFBE_%1%2TYPE", str _esd, _kindW]), _eStructsW] Call GetFactories; //--- same 1-arg form, see main-body comment above.
								_eFactoriesW = _eFactoriesW + _flistW;
							} forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT"];

							if (count _eFactoriesW <= 0) exitWith {_hot = false}; //--- win-relevant success: no live enemy factories left to strike.

							_tgtW = [_myHQw, _eFactoriesW] Call WFBE_CO_FNC_GetClosestEntity;
							if (isNull _tgtW) exitWith {_hot = false};

							[_g, true, [[getPos _tgtW, 'SAD', _sadR, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
							{
								if (alive _x) then {
									_x reveal _tgtW; //--- A2: 2-operand reveal only (array form is A3-only).
									_x doTarget _tgtW;
									_x doFire _tgtW;
								};
							} forEach (crew _h);

							sleep _poll;
							_elapsed = _elapsed + _poll;
						};
						//--- r70 empty-group lifecycle: purge ALL group members (not only current crew). Dead/dismounted
						//--- stay in units _g after the alive-count while-exit; crew-only delete left corpse husks.
						{if (!isNull _x && {!isPlayer _x}) then {deleteVehicle _x}} forEach (units _g);
						if (!isNull _h && {({isPlayer _x} count (crew _h)) == 0}) then {deleteVehicle _h};
						if (!isNull _g && {({isPlayer _x} count (units _g)) == 0}) then {deleteGroup _g};
					};
				} else {
					_skipReason = "pilot-create-failed";
					deleteVehicle _heli; deleteGroup _grp;
				};
			} else {
				_skipReason = "group-create-failed";
				deleteVehicle _heli;
			};
		} else {_skipReason = "vehicle-create-failed"};
	} else {
		if (count _attackClasses <= 0) then {_skipReason = "no-attack-class"} else {_skipReason = "no-pilot-class"};
	};
};

_logik setVariable ["wfbe_aicom2_airstrike_flights", _flights];

_elMin = round (time / 60);
diag_log ("AICOM2|v1|AIRSTRIKE|" + _sideText + "|" + str _elMin
	+ "|enemyFactories=" + str (count _eFactories)
	+ "|airAlive=" + str _airAlive
	+ "|airMax=" + str _airMaxTotal
	+ "|flights=" + str (count _flights)
	+ "|dispatched=" + str _dispatched
	+ "|myTowns=" + str _myTowns
	+ "|airOK=" + (if (_airOK) then {"1"} else {"0"})
	+ "|skip=" + _skipReason
	+ "|flag=" + str (missionNamespace getVariable ["WFBE_C_AICOM2_AIRSTRIKE_ENABLE", 0]));
