/*
	AI Commander - MOBILE HQ RELOCATION worker. Ray 2026-06-21. Server-side, per side.
	Parameter: _this = side.  Called as:  _side Call WFBE_SE_FNC_AI_Com_MHQReloc

	When the AI commander's front (primary spearhead town = wfbe_aicom_targets[0]) has
	advanced FAR from its deployed HQ, MOBILIZE the static HQ into the MHQ vehicle, DRIVE it
	forward to a safe standoff BEHIND an owned front town, then DEPLOY it again. Real driving
	(an AI driver + doMove), default-ON.

	SAFETY RAILS (all hard):
	  - DISABLED guard: fully inert when WFBE_C_AICOM_MHQ_RELOCATE == 0.
	  - SINGLE-FLIGHT: wfbe_mhqreloc_active flag + the engine wfbe_hqinuse lock.
	  - ENEMY STANDOFF: never mobilize/deploy with an enemy within ENEMY_CLEAR of the current
	    HQ or the planned destination.
	  - STUCK TIMER: no >25m progress in STUCK_SECS -> deploy where it stands.
	  - ABSOLUTE DEADLINE: DEADLINE s -> player-safe teleport-step to the target then deploy
	    (never permanently stranded).
	  - NEVER A FROZEN/IDLE MHQ IN PLAYER VIEW: every drive-loop exit converges on re-deploy or
	    clean release; the teleport-step is gated on no player within DISBAND_SAFE_DIST.

	The drive monitor runs in a self-contained Spawn (mirrors the heading-feed Spawn in
	Common_RunCommanderTeam.sqf) so it never blocks the supervisor.
	A2-OA 1.64 ONLY: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/worldSize.
*/

private ["_side","_sideText","_logik","_enabled","_hq","_deployed","_targets","_front","_frontPos","_myID","_enemyID","_enemySideObj","_guerID","_hqPos","_frontDist","_standoff","_enemyClear","_arriveDist","_deadline","_stuckSecs","_destPos","_dx","_dy","_d","_back","_eNear","_busy","_townBuffer","_ringClear","_ownTowns","_t","_tD","_i","_j","_tmp","_cand","_clear","_etPos","_etD","_hfDist","_hNear"];  //--- cmdcon41-w2: +_hfDist,_hNear (human-front defer gate).

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- RAIL 0: hard disable -> fully inert.
_enabled = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_RELOCATE", 1];
if (_enabled <= 0) exitWith {};

//--- RAIL 1: single-flight.
_busy = _logik getVariable ["wfbe_mhqreloc_active", false];
if (_busy) exitWith {};
if (_logik getVariable ["wfbe_hqinuse", false]) exitWith {};

//--- B74.2 (night-soak item 7, anti-thrash): EVALUATION back-off. A prior interval's abort
//--- (advance-below-min / no-buffer-clear-standoff) stamps wfbe_mhqreloc_abort_until; while that
//--- stamp is in the future, skip the whole own-town scan + ring-clear sweep + re-log instead of
//--- re-deriving the same dead result every interval (the 461 paired-abort thrash in the digest).
//--- Inert when WFBE_C_AICOM_MHQ_ABORT_COOLDOWN <= 0 (default), so behaviour is unchanged until tuned.
private "_abortUntil";
_abortUntil = _logik getVariable ["wfbe_mhqreloc_abort_until", 0];
if ((missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ABORT_COOLDOWN", 0]) > 0 && {time < _abortUntil}) exitWith {};

//--- Need a DEPLOYED static HQ to relocate.
_deployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
if (typeName _deployed != "BOOL") exitWith {};
if (!_deployed) exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _hq || {!alive _hq}) exitWith {};
_hqPos = getPos _hq;
if (typeName _hqPos != "ARRAY" || {count _hqPos < 2}) exitWith {};

//--- FRONT = primary spearhead town the strategy worker publishes.
_targets = _logik getVariable ["wfbe_aicom_targets", []];
if (typeName _targets != "ARRAY" || {count _targets == 0}) exitWith {};
_front = _targets select 0;
if (isNull _front) exitWith {};
_frontPos = getPos _front;
if (typeName _frontPos != "ARRAY" || {count _frontPos < 2}) exitWith {};

_myID         = (_side) Call WFBE_CO_FNC_GetSideID;
_enemySideObj = if (_side == west) then {east} else {west};
_enemyID      = (_enemySideObj) Call WFBE_CO_FNC_GetSideID;
//--- B67: resistance/GUER side id - towns held by GUER are HOSTILE for the relocation
//--- safety sweep too (the old west-vs-east-only enemy derivation made GUER-held towns
//--- invisible to the clear/buffer checks below). A2-OA-safe (helper returns WFBE_C_GUER_ID).
_guerID       = (resistance) Call WFBE_CO_FNC_GetSideID;

_frontDist  = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_FRONT_DIST",   2500];
_standoff   = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_STANDOFF",     800];
_enemyClear = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ENEMY_CLEAR",  700];
_arriveDist = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ARRIVE_DIST",  400];
_deadline   = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_DEADLINE",     600];
_stuckSecs  = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_STUCK_SECS",   210];

//--- TRIGGER: only relocate once the front has advanced > FRONT_DIST from the HQ.
if ((_hq distance _frontPos) <= _frontDist) exitWith {};

//--- B67: DESTINATION = a standoff position BEHIND the nearest OWN-SIDE-HELD town to the
//--- front (a town whose sideID == this commander's side id), NOT a raw geometric point on the
//--- front-to-HQ line (that point could fall inside an enemy/GUER town's activation ring).
//--- Build own-held towns, then walk them nearest-to-front first; for each, place a standoff
//--- point STANDOFF metres back from the town toward the current HQ (behind the town) and
//--- validate it sits clear of EVERY enemy-held AND resistance-held town's 600m activation ring
//--- by an extra WFBE_C_AICOM_MHQ_TOWN_BUFFER of margin. First town that yields a buffer-clear
//--- standoff wins. If none does, ABORT this interval (never deploy into a ring).
_townBuffer = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_TOWN_BUFFER", 1000];
_ringClear  = 600 + _townBuffer;   //--- B67: required clearance from every hostile town centre.

//--- Collect own-side-held towns (explicit forEach; no findIf/selectRandom - A2-OA-safe).
_ownTowns = [];
{ if ((_x getVariable "sideID") == _myID) then {_ownTowns set [count _ownTowns, _x]} } forEach towns;
if (count _ownTowns == 0) exitWith {};   //--- no friendly town to base behind - nothing to do.

//--- Insertion-sort own towns by distance to the front (nearest first). Plain index loops -
//--- A2-OA-safe (no sort-by-CODE which is A3-only).
for "_i" from 1 to ((count _ownTowns) - 1) do {
	_cand = _ownTowns select _i;
	_tD   = _cand distance _frontPos;
	_j    = _i - 1;
	while {_j >= 0 && {((_ownTowns select _j) distance _frontPos) > _tD}} do {
		_ownTowns set [_j + 1, (_ownTowns select _j)];
		_j = _j - 1;
	};
	_ownTowns set [_j + 1, _cand];
};

//--- cmdcon41-w3m (mhq-reloc-relaxation-ladder, HIGH): a LOSING side compressed to ~1 town ringed by
//--- hostile/GUER towns can NEVER satisfy the full-clearance standoff (live WEST logged 21/21 ABORT|
//--- no-buffer-clear-standoff|ringClear=1400 while holding 1 town) -> the MHQ never relocates -> the side
//--- stays collapsed (feedback loop). RELAXATION LADDER: when the full own-town walk yields no buffer-clear
//--- standoff, retry the SAME walk with progressively SMALLER required clearance and take the first hit.
//--- Ladder = [ 600+buffer (full, preferred) , 600 (raw activation ring) , WFBE_C_AICOM_MHQ_RELAX_FLOOR
//--- (default 350) ]. NEVER below the floor - a deploy INSIDE a hostile activation ring stays forbidden.
//--- If even the floor pass fails, fall through to the existing ABORT (+ abort-cooldown stamp) untouched.
//--- Gated by WFBE_C_AICOM_MHQ_RELAX (default 1); at 0 the ladder is just the single full-clearance ring,
//--- so behaviour is IDENTICAL to before this change. A2-OA-1.64-safe: plain array/forEach, no A3 ops; the
//--- walk body is byte-identical to the prior single-pass walk (it reads the free var _ringClear per pass).
private ["_relaxOn","_ringFloor","_ringLadder","_usedRing"];
_relaxOn   = (missionNamespace getVariable ["WFBE_C_AICOM_MHQ_RELAX", 1]) > 0;
_ringFloor = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_RELAX_FLOOR", 350];
//--- Build the descending ladder. Only append a rung that is STRICTLY smaller than the previous AND not
//--- below the floor (so 600 and the floor are skipped if the full ring is already <= them). The floor is
//--- always the last rung (never below it). Relaxation disabled -> ladder is just the full ring.
_ringLadder = [_ringClear];
if (_relaxOn) then {
	if (600 < _ringClear && {600 > _ringFloor}) then {_ringLadder set [count _ringLadder, 600]};
	if (_ringFloor < _ringClear) then {_ringLadder set [count _ringLadder, _ringFloor]};
};

//--- Walk friendly towns nearest-to-front first; first buffer-clear standoff wins. Repeated per ladder rung
//--- (descending clearance) until a candidate is found or the ladder is exhausted.
_destPos  = [];
_usedRing = _ringClear;
{
	if (count _destPos == 0) then {
		_ringClear = _x;   //--- the walk body below reads _ringClear as its required hostile-ring clearance.
		{
			_t = _x;
			//--- Standoff = STANDOFF metres from this town toward the current HQ (behind the town,
			//--- away from the front). If HQ and town coincide, skip - no usable direction.
			_dx = (_hqPos select 0) - (getPos _t select 0);
			_dy = (_hqPos select 1) - (getPos _t select 1);
			_d  = sqrt (_dx*_dx + _dy*_dy);
			if (_d >= 1 && {count _destPos == 0}) then {
				_back = _standoff min _d;
				_cand = [(getPos _t select 0) + (_dx / _d) * _back, (getPos _t select 1) + (_dy / _d) * _back, 0];
				//--- Validate: clear of EVERY enemy-held AND resistance-held town by _ringClear.
				_clear = true;
				{
					if (((_x getVariable "sideID") == _enemyID) || {(_x getVariable "sideID") == _guerID}) then {
						_etPos = getPos _x;
						_etD   = sqrt (((_cand select 0) - (_etPos select 0))^2 + ((_cand select 1) - (_etPos select 1))^2);
						if (_etD < _ringClear) then {_clear = false};
					};
				} forEach towns;
				if (_clear && {!surfaceIsWater _cand}) then {_destPos = _cand; _usedRing = _ringClear};
			};
		} forEach _ownTowns;
	};
} forEach _ringLadder;
//--- Pin _ringClear to the rung the winning candidate was validated against (_usedRing) so the DOWNSTREAM
//--- final-deploy revalidation inside the Spawn (which receives _ringClear at line ~233 and re-checks the
//--- deployed pos against every hostile ring) uses the SAME clearance the candidate passed - a relaxed
//--- candidate must not then be rejected by a stricter full-ring final check. Invariant already holds (the
//--- outer loop stops advancing once _destPos is set), this makes it explicit and stale-proof.
if (count _destPos > 0) then {_ringClear = _usedRing};
//--- If a RELAXED rung (below the full clearance) produced the standoff, surface it so a compressed side's
//--- salvaged relocation is visible in the RPT (once per successful relaxed pass, not per tick).
if (count _destPos > 0 && {_usedRing < (600 + _townBuffer)}) then {
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|RELAXED|ring=" + str (round _usedRing));
};

//--- B74 MIN-ADVANCE (Ray 2026-06-22): reject a relocation that is not a real forward leap - the new base
//--- must be at least MHQ_MIN_ADVANCE metres from the OLD HQ, else keep the current base. Ray saw the HQ
//--- move ~800m and stack on the old base; a relocation should only fire when the front has genuinely run away.
if (count _destPos > 0) then {
	private ["_minAdv","_advDX","_advDY","_advD"];
	_minAdv = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_MIN_ADVANCE", 3000];
	_advDX = (_destPos select 0) - (_hqPos select 0);
	_advDY = (_destPos select 1) - (_hqPos select 1);
	_advD  = sqrt (_advDX*_advDX + _advDY*_advDY);
	if (_advD < _minAdv) then {
		diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ABORT|advance-below-min|adv=" + str (round _advD) + "|min=" + str (round _minAdv));
		_logik setVariable ["wfbe_mhqreloc_abort_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ABORT_COOLDOWN", 0])]; //--- B74.2 anti-thrash: back off re-eval (no-op when cooldown=0).
		_destPos = [];
	};
};

//--- No friendly town yields a buffer-clear standoff even at the RELAXED floor -> ABORT (never deploy into a
//--- ring). cmdcon41-w3m: ringClear here is the SMALLEST rung tried (the floor when relaxation ran); the added
//--- |full=/floor= fields show the ladder was walked to the floor and still failed (topology too compressed).
if (count _destPos == 0) exitWith {
	_logik setVariable ["wfbe_mhqreloc_abort_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ABORT_COOLDOWN", 0])]; //--- B74.2 anti-thrash: back off re-eval (no-op when cooldown=0).
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ABORT|no-buffer-clear-standoff|ringClear=" + str (round _ringClear) + "|full=" + str (round (600 + _townBuffer)) + "|floor=" + str (round _ringFloor));
};

//--- RAIL 2 (ENEMY STANDOFF) + no-water destination.
if (surfaceIsWater _destPos) exitWith {};
_eNear = false;
{ if (side _x == _enemySideObj && {alive _x}) then {_eNear = true} } forEach (_destPos nearEntities [["Man","Car","Tank","Air"], _enemyClear]);
if (_eNear) exitWith {};
_eNear = false;
{ if (side _x == _enemySideObj && {alive _x}) then {_eNear = true} } forEach (_hqPos nearEntities [["Man","Car","Tank","Air"], _enemyClear]);
if (_eNear) exitWith {};

//--- cmdcon41-w2 (mhq-reloc-avoid-human-front-overrun): HUMAN-FRONT DEFER. After the two enemy-clear
//--- gates pass but BEFORE single-flight is claimed, DEFER this interval if a friendly HUMAN player is in
//--- active COMBAT within WFBE_C_AICOM_MHQ_HUMAN_FRONT_DIST of the planned destination - don't creep the
//--- base into a human-contested front. Pure read-only scan (same nearEntities/forEach idiom used above);
//--- only ever skips the eval (exitWith), retries next interval - never touches the drive/deploy lifecycle.
//--- 0 disables. A2-OA-safe: behaviour == "COMBAT" is an exact-case string compare (no A3 commands).
//--- Compute _hNear at SCRIPT scope first (a then{} block has its own scope, so an exitWith inside it would
//--- only exit that block, not the script - the defer exitWith below MUST live at top level).
_hfDist = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_HUMAN_FRONT_DIST", 900];
_hNear = false;
if (_hfDist > 0) then {
	{
		if (isPlayer _x && {alive _x} && {side _x == _side} && {behaviour _x == "COMBAT"}) then {_hNear = true};
	} forEach (_destPos nearEntities [["Man"], _hfDist]);
};
if (_hNear) exitWith {
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|DEFER|human-front|dist=" + str (round _hfDist) + "|dest=" + str _destPos);
};

//--- All gates passed: claim single-flight + LAUNCH the lifecycle Spawn.
_logik setVariable ["wfbe_mhqreloc_active", true];
diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|TRIGGER|frontDist=" + str (round (_hq distance _frontPos)) + "|dest=" + str _destPos + "|back=" + str (round _back));
["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] relocation TRIGGERED - front %2m out, mobilizing toward %3.", _sideText, round (_hq distance _frontPos), _destPos]] Call WFBE_CO_FNC_AICOMLog;

[_side, _sideText, _logik, _myID, _destPos, _arriveDist, _deadline, _stuckSecs, _enemyClear, _enemySideObj, _enemyID, _guerID, _ringClear, _hqPos] Spawn {
	//--- cmdcon41-w2: +_enemyID,_guerID,_ringClear,_hqPos (final-deploy revalidate) + de-escalate/final-loop locals in private[] below.
	private ["_side","_sideText","_logik","_myID","_destPos","_arriveDist","_deadline","_stuckSecs","_enemyClear","_enemySide","_mhq","_drvGrp","_drv","_soldier","_dir","_t0","_lastClose","_lastImprove","_done","_reason","_cur","_curD","_pNear","_safeDist","_hq0","_finPos","_finDir","_finTry","_finAng","_structClass","_nudgeSecs","_nudgeTurn","_lastNudge","_enemyID","_guerID","_ringClear","_hqPos","_routeDeesc","_routeGrace","_inContact","_eOnRoute","_finStep","_finMax","_finBad","_finChkD","_finRawPos","_finDX","_finDY","_finD"];
	_side       = _this select 0;
	_sideText   = _this select 1;
	_logik      = _this select 2;
	_myID       = _this select 3;
	_destPos    = _this select 4;
	_arriveDist = _this select 5;
	_deadline   = _this select 6;
	_stuckSecs  = _this select 7;
	_enemyClear = _this select 8;
	_enemySide  = _this select 9;
	_enemyID    = _this select 10;   //--- cmdcon41-w2: hostile side ids + ring clearance for the final-deploy revalidate.
	_guerID     = _this select 11;
	_ringClear  = _this select 12;
	_hqPos      = _this select 13;   //--- cmdcon41-w2: origin HQ pos - the "toward own HQ" step-back vector for the final revalidate.
	_safeDist   = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];

	//--- 1) MOBILIZE: flip the static HQ into the MHQ vehicle via the canonical toggle.
	_hq0 = (_side) Call WFBE_CO_FNC_GetSideHQ;
	if (isNull _hq0) exitWith {_logik setVariable ["wfbe_mhqreloc_active", false]};
	_dir = getDir _hq0;
	[missionNamespace getVariable Format ["WFBE_%1MHQNAME", _side], _side, _hq0, _dir] ExecVM "Server\Construction\Construction_HQSite.sqf";
	_t0 = time + 30;
	waitUntil {sleep 1; time > _t0 || {!((_side) Call WFBE_CO_FNC_GetSideHQDeployStatus)}};
	//--- B66: ORPHAN GUARD. The mobilize ExecVM is fire-and-forget and holds wfbe_hqinuse until its last line.
	//--- If the 30s deadline fired while that lock is still held, the mobilize may complete AFTER we abort -
	//--- leaving an undeployed (mobilized) MHQ with no driver. Give the in-flight mobilize a brief grace to
	//--- finish (lock-release), bounded, then re-read deploy status so a late-completing mobilize is recognised
	//--- as success rather than orphaned. A2-OA-safe (WFBE_CO_FNC_GroupGetBool is for groups; this is a
	//--- side-logic bool set with a default so a plain getVariable[...,false] is reliable here).
	if (time > _t0) then {
		private ["_lockWait"];
		_lockWait = time + 8;
		waitUntil {sleep 1; time > _lockWait || {!(_logik getVariable ["wfbe_hqinuse", false])}};
	};
	if ((_side) Call WFBE_CO_FNC_GetSideHQDeployStatus) exitWith {
		//--- Still deployed after the grace -> mobilize genuinely failed. Release single-flight cleanly; the
		//--- HQ is left deployed (a valid resting state), so nothing is orphaned.
		_logik setVariable ["wfbe_mhqreloc_active", false];
		diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ABORT|mobilize-timeout");
		["WARNING", Format ["AI_Commander_MHQReloc.sqf: [%1] mobilize did not complete in time - aborting (HQ left deployed).", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	};
	_mhq = (_side) Call WFBE_CO_FNC_GetSideHQ;
	if (isNull _mhq || {!alive _mhq}) exitWith {
		//--- MHQ vehicle missing after mobilize: release; the Base worker re-deploys (its
		//--- first-deploy branch re-fires while wfbe_hq_deployed is false).
		_logik setVariable ["wfbe_mhqreloc_active", false];
		diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ABORT|no-mhq-vehicle");
		["WARNING", Format ["AI_Commander_MHQReloc.sqf: [%1] no MHQ vehicle after mobilize - aborting; Base worker will re-deploy.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	};
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|MOBILIZED|mhq=" + (typeOf _mhq));

	//--- 2) DRIVER: spawn an AI driver and seat him (W21 SVBIED idiom).
	_soldier = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""];
	_drv = objNull; _drvGrp = grpNull;
	if (typeName _soldier == "STRING" && {_soldier != ""}) then {
		_drvGrp = [_side, "aicom-mhqreloc"] Call WFBE_CO_FNC_CreateGroup;
		if (!isNull _drvGrp) then {
			_drv = [_soldier, _drvGrp, getPos _mhq, _myID] Call WFBE_CO_FNC_CreateUnit;
			if (!isNull _drv) then {
				_mhq lock false;
				_drv moveInDriver _mhq;
				_drvGrp setBehaviour "CARELESS";
				_drvGrp setCombatMode "BLUE";
				_drvGrp setSpeedMode "FULL";
				{_drv disableAI _x} forEach ["AUTOTARGET","TARGET"];
				_drv setVariable ["WFBE_Taxi_Prohib", true];
			};
		};
	};

	//--- 3) DRIVE + MONITOR.
	if (!isNull _drv && {alive _drv}) then {(driver _mhq) doMove _destPos};

	_t0          = time;
	_curD        = if (!isNull _mhq) then {_mhq distance _destPos} else {1e9};
	_lastClose   = _curD;
	_lastImprove = time;
	_done        = false;
	_reason      = "arrive";
	_nudgeSecs   = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_NUDGE_SECS", 45];
	_nudgeTurn   = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_NUDGE_TURN", 25];
	_lastNudge   = 0;   //--- last nudge time; 0 = none yet.
	//--- cmdcon41-w2 (mhq-route-contact-deescalate): sense enemies around the MOVING MHQ each tick; near
	//--- contact flip the careless transit driver to AWARE/NORMAL so it reacts/evades, and grant the
	//--- stuck/deadline clocks a short grace so a brief contact pause does not instantly trip a deploy.
	//--- Restore the careless transit profile when clear (never freeze). 0 = disable (stays careless).
	_routeDeesc  = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ROUTE_DEESC", 1];
	_routeGrace  = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_ROUTE_GRACE", 12];
	_inContact   = false;   //--- latched de-escalation state; restore transit profile exactly once on clear.

	while {!_done && !gameOver} do {
		sleep 5;
		if (isNull _mhq || {!alive _mhq}) exitWith {_done = true; _reason = "mhq-lost"};
		_cur  = getPos _mhq;
		_curD = _mhq distance _destPos;

		//--- cmdcon41-w3h (Ray): the relocating MHQ never runs dry mid-route (a fuel-stranded MHQ = a dead
		//--- relocation the abort logic reads as "stuck"). Server-local here (AICOM MHQ is server-owned).
		if ((missionNamespace getVariable ["WFBE_C_AICOM_AUTOFUEL", 1]) > 0 && {(fuel _mhq) < (missionNamespace getVariable ["WFBE_C_AICOM_AUTOFUEL_BELOW", 0.25])}) then {
			_mhq setFuel 1;
			diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|AUTOFUEL");
		};

		//--- cmdcon41-w2 (mhq-route-contact-deescalate): sample live enemies around the MOVING MHQ this tick.
		//--- On contact -> de-escalate the transit driver (AWARE/NORMAL) so it reacts/evades instead of
		//--- barrelling in CARELESS/BLUE with AUTOTARGET off, AND push the stuck/deadline clocks forward by
		//--- _routeGrace so a brief contact pause does not instantly trip a deploy. When contact clears,
		//--- restore the original careless transit profile exactly once (never freeze - keeps moving/re-wakes).
		//--- Guards a live _drvGrp; skipped entirely when _routeDeesc<=0. A2-OA-safe (nearEntities/forEach,
		//--- setBehaviour/setCombatMode/setSpeedMode, exact-case mode strings).
		if (_routeDeesc > 0 && {!isNull _drvGrp}) then {
			_eOnRoute = false;
			{ if (side _x == _enemySide && {alive _x}) then {_eOnRoute = true} } forEach (_cur nearEntities [["Man","Car","Tank","Air"], _enemyClear]);
			if (_eOnRoute) then {
				//--- CONTACT: grant the timers grace every contact tick so a pause never trips stuck/deadline.
				_lastImprove = _lastImprove + _routeGrace;
				_t0          = _t0 + _routeGrace;
				if (!_inContact) then {
					_inContact = true;
					_drvGrp setBehaviour "AWARE";
					_drvGrp setCombatMode "NORMAL";
					if (!isNull (driver _mhq)) then {{(driver _mhq) enableAI _x} forEach ["AUTOTARGET","TARGET"]};
					diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ROUTE_CONTACT|d=" + str (round _curD));
				};
			} else {
				if (_inContact) then {
					//--- CLEAR: restore the careless transit profile exactly once so the MHQ keeps moving.
					_inContact = false;
					_drvGrp setBehaviour "CARELESS";
					_drvGrp setCombatMode "BLUE";
					_drvGrp setSpeedMode "FULL";
					if (!isNull (driver _mhq)) then {{(driver _mhq) disableAI _x} forEach ["AUTOTARGET","TARGET"]; (driver _mhq) doMove _destPos};
					diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ROUTE_CLEAR|d=" + str (round _curD));
				};
			};
		};

		if (_curD <= _arriveDist) then {_done = true; _reason = "arrive"};

		if (!_done) then {
			if (_curD < (_lastClose - 25)) then {_lastClose = _curD; _lastImprove = time};

			//--- (a) Re-issue the move EVERY tick (idempotent re-path; guard a live driver).
			if (!isNull (driver _mhq)) then {(driver _mhq) doMove _destPos};

			//--- (b) Sub-window UNSTUCK NUDGE: no >25m progress for _nudgeSecs, still inside the
			//--- stuck rail, and not nudged within the last _nudgeSecs -> brief velocity-zero +
			//--- re-doMove (+ optional corner turn). Rate-limited so it does NOT fire every 5s tick.
			if ( (time - _lastImprove) > _nudgeSecs
			     && {(time - _lastImprove) <= _stuckSecs}
			     && {(time - _lastNudge)  > _nudgeSecs}
			     && {!isNull (driver _mhq)} ) then {
				_mhq setVelocity [0,0,0];
				if (_nudgeTurn > 0) then {_mhq setDir ((getDir _mhq) + _nudgeTurn)};
				(driver _mhq) doMove _destPos;
				_lastNudge = time;
				diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|NUDGE|stalled=" + str (round (time - _lastImprove)) + "|d=" + str (round _curD));
			};

			if ((time - _lastImprove) > _stuckSecs) then {
					//--- B74.1 (2026-06-23): a STUCK MHQ used to deploy WHERE IT STALLED - and on Chernarus it stalls almost
					//--- immediately, landing the new base back beside the OLD one (~0 advance), which nullified the forward
					//--- relocation AND #9's forward-factory rebuild (the b74 soak saw 14/14 relocations deploy stuck near base).
					//--- Teleport to _destPos instead (player-clear-gated, the same accepted step the deadline path uses) so a
					//--- stuck relocation still lands FORWARD. Falls back to deploy-in-place only if a player blocks the dest.
					_pNear = false;
					{ if (isPlayer _x && {alive _x} && {!isNull _mhq} && {(_x distance _mhq) < _safeDist}) then {_pNear = true} } forEach playableUnits;
					{ if (isPlayer _x && {alive _x} && {(_x distance _destPos) < _safeDist}) then {_pNear = true} } forEach playableUnits;
					if (!_pNear && {!surfaceIsWater _destPos}) then {
						_mhq setVelocity [0,0,0];
						_mhq setPos _destPos;
						diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|STUCK_TELEPORT|to=" + str _destPos);
						_reason = "stuck-teleport";
					} else {
						_reason = "stuck";
					};
					_done = true;
				};
		};

		if (!_done && {(time - _t0) > _deadline}) then {
			//--- B66: the teleport STEP lands the MHQ on _destPos, but the old gate only checked players near
			//--- the CURRENT _mhq (the source) - a player standing AT the destination would have an MHQ
			//--- materialise on top of them. Require BOTH the current MHQ and the destination clear of players.
			_pNear = false;
			{ if (isPlayer _x && {alive _x} && {!isNull _mhq} && {(_x distance _mhq) < _safeDist}) then {_pNear = true} } forEach playableUnits;
			{ if (isPlayer _x && {alive _x} && {(_x distance _destPos) < _safeDist}) then {_pNear = true} } forEach playableUnits; //--- B66: dest-clear too
			if (!_pNear && {!surfaceIsWater _destPos}) then {
				if (!isNull (driver _mhq)) then {(driver _mhq) doMove _destPos};
				_mhq setVelocity [0,0,0];
				_mhq setPos _destPos;
				diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|TELEPORT_STEP|to=" + str _destPos);
				["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] deadline reached - teleport-step to %2 (no player within %3m).", _sideText, _destPos, _safeDist]] Call WFBE_CO_FNC_AICOMLog;
				_done = true; _reason = "deadline-teleport";
			} else {
				if (!isNull (driver _mhq)) then {(driver _mhq) doMove _destPos};
				_t0 = time;
				diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|TELEPORT_BLOCKED|player-near");
			};
		};
	};

	//--- 4) RE-DEPLOY or clean release.
	if (_reason == "mhq-lost") exitWith {
		if (!isNull _drvGrp) then {{if (local _x) then {deleteVehicle _x}} forEach (units _drvGrp); deleteGroup _drvGrp};
		_logik setVariable ["wfbe_mhqreloc_active", false];
		diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|RELEASE|mhq-lost");
		["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] MHQ lost mid-drive - released (OnHQKilled rebuilds).", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	};

	//--- Dismount + delete the driver BEFORE deploy.
	if (!isNull _drv && {alive _drv}) then {unassignVehicle _drv; moveOut _drv};
	if (!isNull _mhq && {!isNull (driver _mhq)}) then {moveOut (driver _mhq)};
	if (!isNull _drvGrp) then {{if (local _x) then {deleteVehicle _x}} forEach (units _drvGrp); deleteGroup _drvGrp};

	if (isNull _mhq) exitWith {
		_logik setVariable ["wfbe_mhqreloc_active", false];
		diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|RELEASE|mhq-null-at-deploy");
	};
	_finPos = getPos _mhq;
	_finDir = getDir _mhq;
	if (surfaceIsWater _finPos) then {
		_finTry = 0;
		while {surfaceIsWater _finPos && {_finTry < 20}} do {
			_finAng = random 360;
			_finPos = [(getPos _mhq select 0) + (20 + random 30) * sin _finAng, (getPos _mhq select 1) + (20 + random 30) * cos _finAng, 0];
			_finTry = _finTry + 1;
		};
		if (surfaceIsWater _finPos) then {_finPos = getPos _mhq};
	};
	//--- cmdcon41-w2 (mhq-final-deploy-clearance-revalidate): the carefully-validated _destPos ring-clearance
	//--- is DISCARDED on a stuck/deadline/water-escape exit (the HQ deploys at getPos _mhq / a water random-walk
	//--- spot with NO enemy-ring and NO friendly-structure check). Re-validate _finPos here against (a) the same
	//--- hostile-ring test used for the candidate (every enemy/GUER town clear by _ringClear) AND (b) friendly-
	//--- structure spacing (WFBE_C_AICOM_STRUCT_SPACING, the Base worker's build-reject rule). If it fails, step
	//--- _finPos back TOWARD OWN HQ (_hqPos) by _finStep m, up to _finMax tries; deploy at the first clear spot.
	//--- Hard fallback: the already-ring-clear _destPos, then the raw _finPos - NEVER a deadlock. Only runs on the
	//--- stranded exits (arrive lands at/near the already-clear _destPos). A2-OA-safe (forEach towns ring test +
	//--- GetSideStructures spacing forEach - both idioms already live in this codebase; scalar geometry only).
	if ((_reason == "stuck") || {_reason == "stuck-teleport"} || {_reason == "deadline-teleport"} || {_reason == "deadline"}) then {
		_finStep = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_FINAL_STEPBACK", 120];
		_finMax  = missionNamespace getVariable ["WFBE_C_AICOM_MHQ_FINAL_MAXTRIES", 12];
		_finRawPos = _finPos;   //--- last-resort raw fallback (never deadlock).
		_finTry = 0;
		_finBad = true;
		while {_finBad && {_finTry <= _finMax}} do {
			_finBad = false;
			//--- (a) hostile-ring re-check: same forEach towns test as the candidate validation.
			{
				if (((_x getVariable "sideID") == _enemyID) || {(_x getVariable "sideID") == _guerID}) then {
					_finChkD = sqrt (((_finPos select 0) - (getPos _x select 0))^2 + ((_finPos select 1) - (getPos _x select 1))^2);
					if (_finChkD < _ringClear) then {_finBad = true};
				};
			} forEach towns;
			//--- (b) friendly-structure spacing re-check (Base worker's reject rule).
			if (!_finBad) then {
				{ if ((_finPos distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING", 45])) exitWith {_finBad = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
			};
			//--- (c) never deploy on water.
			if (!_finBad && {surfaceIsWater _finPos}) then {_finBad = true};
			//--- (d) cmdcon41-w3k (AICOM builds-on-roads backlog): the Base worker's _findBuildPos rejects on-road
			//--- placements, but this stranded-exit revalidation discarded that rule for the DEPLOYED MHQ position -
			//--- same road blind spot. Reject a _finPos within WFBE_C_AICOM_BUILD_ROAD_BUFFER (14m) of ANY road so
			//--- the re-deployed HQ site does not block a lane; the step-back-toward-HQ loop below then walks it off.
			//--- Gated by WFBE_C_AICOM_BUILD_ROADCLEAR (default 1). nearRoads idiom == the Base worker's road gate
			//--- (A2-OA-safe; no isOnRoad/getRoadInfo). Only the final ring-clear _destPos fallback can override.
			if (!_finBad && {(missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROADCLEAR", 1]) > 0}) then {
				private "_finRoadBuf";
				_finRoadBuf = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14];
				if (_finRoadBuf > 0 && {count (_finPos nearRoads _finRoadBuf) > 0}) then {_finBad = true};
			};
			if (_finBad) then {
				//--- Step back TOWARD OWN HQ. If _finPos coincides with _hqPos, fall straight to the ring-clear _destPos.
				_finDX = (_hqPos select 0) - (_finPos select 0);
				_finDY = (_hqPos select 1) - (_finPos select 1);
				_finD  = sqrt (_finDX*_finDX + _finDY*_finDY);
				if (_finD >= 1) then {
					_finPos = [(_finPos select 0) + (_finDX / _finD) * _finStep, (_finPos select 1) + (_finDY / _finD) * _finStep, 0];
				} else {
					_finPos = _destPos;
				};
				_finTry = _finTry + 1;
			};
		};
		if (_finBad) then {
			//--- Step budget exhausted -> hard-fall-back to the already-ring-clear _destPos (raw _finPos if dest is wet).
			if (!surfaceIsWater _destPos) then {
				_finPos = _destPos;
				diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|FINAL_REVALIDATE|FALLBACK_DESTPOS|tries=" + str _finTry);
				//--- cmdcon41-w3k: last-resort fallback dest may itself sit near a road (never deadlock the reloc);
				//--- surface it as BUILD_ROAD_LASTRESORT so a road-blocked reloc-deploy is visible in the RPT.
				if (((missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROADCLEAR", 1]) > 0) && {(missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14]) > 0} && {count (_finPos nearRoads (missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14])) > 0}) then {
					["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] BUILD_ROAD_LASTRESORT - reloc fell back to ring-clear dest %2 which is road-near; deploying anyway.", _sideText, _finPos]] Call WFBE_CO_FNC_AICOMLog;
				};
			} else {
				_finPos = _finRawPos;
				diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|FINAL_REVALIDATE|FALLBACK_RAW|tries=" + str _finTry);
			};
		} else {
			diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|FINAL_REVALIDATE|CLEAR|tries=" + str _finTry);
		};
	};
	_structClass = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText]) select 0;
	[_structClass, _side, _finPos, _finDir] ExecVM "Server\Construction\Construction_HQSite.sqf";
	_t0 = time + 30;
	waitUntil {sleep 1; time > _t0 || {(_side) Call WFBE_CO_FNC_GetSideHQDeployStatus}};

	_logik setVariable ["wfbe_mhqreloc_active", false];
	//--- WASPSCALE mhqrel counter (cmdcon42): bump the cumulative successful-MHQ-relocation counter the server-side WASPSCALE emit reads (mhqrel=). This DEPLOYED site fires once per successful AI relocation for BOTH AI sides (server-side supervisor). Monotonic.
	missionNamespace setVariable ["wfbe_waspscale_mhqrel", (missionNamespace getVariable ["wfbe_waspscale_mhqrel", 0]) + 1];
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|DEPLOYED|reason=" + _reason + "|pos=" + str _finPos);
	["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] HQ RE-DEPLOYED at %2 (reason: %3).", _sideText, _finPos, _reason]] Call WFBE_CO_FNC_AICOMLog;
};
