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

private ["_side","_sideText","_logik","_enabled","_hq","_deployed","_targets","_front","_frontPos","_myID","_enemyID","_enemySideObj","_guerID","_hqPos","_frontDist","_standoff","_enemyClear","_arriveDist","_deadline","_stuckSecs","_destPos","_dx","_dy","_d","_back","_eNear","_busy","_townBuffer","_ringClear","_ownTowns","_t","_tD","_i","_j","_tmp","_cand","_clear","_etPos","_etD"];

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

//--- Walk friendly towns nearest-to-front first; first buffer-clear standoff wins.
_destPos = [];
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
		if (_clear && {!surfaceIsWater _cand}) then {_destPos = _cand};
	};
} forEach _ownTowns;

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
		_destPos = [];
	};
};

//--- No friendly town yields a buffer-clear standoff -> ABORT (never deploy into a ring).
if (count _destPos == 0) exitWith {
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|ABORT|no-buffer-clear-standoff|ringClear=" + str (round _ringClear));
};

//--- RAIL 2 (ENEMY STANDOFF) + no-water destination.
if (surfaceIsWater _destPos) exitWith {};
_eNear = false;
{ if (side _x == _enemySideObj && {alive _x}) then {_eNear = true} } forEach (_destPos nearEntities [["Man","Car","Tank","Air"], _enemyClear]);
if (_eNear) exitWith {};
_eNear = false;
{ if (side _x == _enemySideObj && {alive _x}) then {_eNear = true} } forEach (_hqPos nearEntities [["Man","Car","Tank","Air"], _enemyClear]);
if (_eNear) exitWith {};

//--- All gates passed: claim single-flight + LAUNCH the lifecycle Spawn.
_logik setVariable ["wfbe_mhqreloc_active", true];
diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|TRIGGER|frontDist=" + str (round (_hq distance _frontPos)) + "|dest=" + str _destPos + "|back=" + str (round _back));
["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] relocation TRIGGERED - front %2m out, mobilizing toward %3.", _sideText, round (_hq distance _frontPos), _destPos]] Call WFBE_CO_FNC_AICOMLog;

[_side, _sideText, _logik, _myID, _destPos, _arriveDist, _deadline, _stuckSecs, _enemyClear, _enemySideObj] Spawn {
	private ["_side","_sideText","_logik","_myID","_destPos","_arriveDist","_deadline","_stuckSecs","_enemyClear","_enemySide","_mhq","_drvGrp","_drv","_soldier","_dir","_t0","_lastClose","_lastImprove","_done","_reason","_cur","_curD","_pNear","_safeDist","_hq0","_finPos","_finDir","_finTry","_finAng","_structClass","_nudgeSecs","_nudgeTurn","_lastNudge"];
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

	while {!_done && !gameOver} do {
		sleep 5;
		if (isNull _mhq || {!alive _mhq}) exitWith {_done = true; _reason = "mhq-lost"};
		_cur  = getPos _mhq;
		_curD = _mhq distance _destPos;

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
	_structClass = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText]) select 0;
	[_structClass, _side, _finPos, _finDir] ExecVM "Server\Construction\Construction_HQSite.sqf";
	_t0 = time + 30;
	waitUntil {sleep 1; time > _t0 || {(_side) Call WFBE_CO_FNC_GetSideHQDeployStatus}};

	_logik setVariable ["wfbe_mhqreloc_active", false];
	diag_log ("AICOMSTAT|v1|MHQRELOC|" + _sideText + "|" + str (round (time / 60)) + "|DEPLOYED|reason=" + _reason + "|pos=" + str _finPos);
	["INFORMATION", Format ["AI_Commander_MHQReloc.sqf: [%1] HQ RE-DEPLOYED at %2 (reason: %3).", _sideText, _finPos, _reason]] Call WFBE_CO_FNC_AICOMLog;
};
