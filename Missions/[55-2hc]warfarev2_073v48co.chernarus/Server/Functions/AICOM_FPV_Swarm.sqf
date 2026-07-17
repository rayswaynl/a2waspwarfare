/*
	AICOM FPV Drone Swarm - AI commander purchases a squad (1-5) of scripted-guidance kamikaze FPV
	drones and crashes them into a picked target.
	feat/aicom-fpv-swarm-20260717 (owner order 2026-07-17).
	Server-side; one instance spawned per side from Init_Server.
	Parameter: _this = side.

	Distinct from Support_FPV.sqf (player-purchased, player-piloted-via-camera kamikaze drone bought
	from the Tactical Center). This is an AUTONOMOUS AI-commander purchase: no player seat, no player
	wallet - the AI commander spends its own wfbe_aicom_funds, same pattern as
	AI_Commander_Wildcard.sqf's WFBE_C_AI_COMMANDER_WILDCARD_COST purchase gate. AI-commanded sides
	only (mirrors the wildcard purchase-model rule: a human-commanded side has no buy path here yet).
	Does NOT touch Support_FPV.sqf, Support_FPV_Detonate.sqf, fpv.sqf/fpv_interface.sqf, or
	Rsc/Parameters.hpp - this is a fully independent detonation + purchase path (own createVehicle
	call, own funds gate, own cooldown/registry keys) to stay collision-free from the parallel
	player-FPV fix-wave lane.

	GATE: WFBE_C_AICOM_FPV_SWARM (default 0). Flag-off = worker never spawns (see Init_Server.sqf
	dispatch), byte-identical to HEAD.

	FLOW per draw:
	  1. AI-commanded side only, HQ alive, per-side cooldown elapsed, concurrent-active cap not hit.
	  2. Target selection: scan enemy-owned towns (mirrors AI_Commander_Wildcard.sqf's W13 gunship
	     strike pattern), score each town's WFBE_C_AICOM_FPV_SWARM_SCAN_RADIUS-m cluster by
	     target-category weight (static defense > armor > HVT-class infantry > rank-and-file), pick
	     the highest-scoring town, aim at the single best-weighted object inside its cluster.
	  3. Afford check: per-drone cost = WFBE_C_FPV_DRONE_COST * WFBE_C_AICOM_FPV_SWARM_COST_MULT.
	     Swarm size 1..WFBE_C_AICOM_FPV_SWARM_MAX, scaled down to what's affordable. Charged BEFORE
	     dispatch (no double-fire race), cooldown stamped at the same time.
	  4. Launch anchor: side HQ. Staggered spawn - spatial offset (mirrors Server_GuerAirDef.sqf's
	     KA-137 swarm-roll block: random bearing + radial/vertical offset) PLUS a small sleep gap
	     between each drone (WFBE_C_AICOM_FPV_SWARM_LAUNCH_GAP) so up to 5 don't spawn stacked.
	  5. Each drone: AI pilot puppet in its own isolated single-unit group, doMove + flyInHeight
	     toward the fixed target position (re-issued every poll tick - doMove is a one-shot AI order
	     on A2 OA). Inside a 120m horizontal run-in it drops to deck level and receives a short
	     forward/downward velocity vector; the proximity poll uses an explicit horizontal calculation
	     (A2 OA has no distance2D). On WFBE_C_AICOM_FPV_SWARM_HIT_RADIUS approach (or TTL
	     timeout / shootdown) it detonates - createVehicle WFBE_C_FPV_DRONE_AMMO at its own current
	     position, a NEW independent detonation path that does NOT touch Support_FPV_Detonate.sqf's
	     player-purchase token registry - and scuttles.

	COUNTERPLAY / BALANCE (see PR body): drones are ordinary flyable hulls (the SAME per-side
	WFBE_<side>FPVDRONE airframe the player FPV purchase uses) - not invulnerable, not stealthed, and
	set CARELESS/BLUE so they never return fire. They are shootable by any AA/AT/small-arms during
	their flight-in, fly a FIXED course locked at launch (a re-check every 1s only re-issues doMove
	to the same locked-in point - there is no live re-targeting if the target dies or the player
	repositions, so the swarm can be baited off or simply outrun a moved target), fly at low but not
	NOE altitude (flyInHeight 60), and cost real AI-commander funds that could otherwise buy
	teams/upgrades. Concurrency is capped (WFBE_C_AICOM_FPV_SWARM_MAX_ACTIVE) and the default 15-min
	cooldown keeps this an occasional strike tool rather than a spammable barrage.
*/

private ["_side","_sideID","_interval","_enabled","_cmdTeam","_hq","_sideText",
         "_jitter","_humanCmd","_skipAI","_swCool","_swKey","_swLast",
         "_maxActive","_activeKey","_activeArr",
         "_enemySide","_enemyID","_cands","_scanR","_bestTown","_bestScore","_bestDist","_bestObj",
         "_hqPos","_enemyScan","_targetPos","_targetName",
         "_perDroneCost","_swFunds","_swarmSize","_swarmMax","_totalCost"];

_side    = _this;
_sideID   = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;

_enabled = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM", 0];
if (!(_enabled > 0)) exitWith {
	["INFORMATION", Format ["AICOM_FPV_Swarm.sqf: worker exit for %1 - WFBE_C_AICOM_FPV_SWARM disabled", _sideText]] Call WFBE_CO_FNC_AICOMLog;
};

_interval = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_INTERVAL", 120];

["INITIALIZATION", Format ["AICOM_FPV_Swarm.sqf: worker started for %1 (interval=%2s).", _sideText, _interval]] Call WFBE_CO_FNC_AICOMLog;

//--- First draw attempt fires after one full interval.
sleep _interval;

while {!gameOver} do {

	//--- DE-CORRELATION: per-side jitter before computing state or rolling.
	_jitter = random 20;
	sleep _jitter;

	_enabled = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM", 0];
	_skipAI  = !(_enabled > 0);

	if (!_skipAI) then {
		_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		_humanCmd = false;
		if (!isNull _cmdTeam) then {
			if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
		};
		if (_humanCmd) then {
			//--- AI-commander tool only, no player buy path yet (mirrors AI_Commander_Wildcard.sqf's purchase-model rule).
			_skipAI = true;
		};
	};

	if (!_skipAI) then {
		_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
		if (isNull _hq || {!alive _hq}) then {
			_skipAI = true;
		};
	};

	if (!_skipAI) then {
		_swCool = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_COOLDOWN", 900];
		_swKey  = Format ["WFBE_AICOM_FPVSWARM_LASTFIRE_%1", _sideText];
		_swLast = missionNamespace getVariable [_swKey, -99999];
		if ((time - _swLast) < _swCool) then {
			_skipAI = true;
		};
	};

	if (!_skipAI) then {
		_maxActive = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_MAX_ACTIVE", 5];
		_activeKey = Format ["wfbe_aicom_fpvswarm_active_%1", _sideText];
		_activeArr = missionNamespace getVariable [_activeKey, []];
		//--- prune dead/null/nil entries before counting so a stale array can never wedge the cap shut.
		{
			if (isNil "_x" || {isNull _x} || {!alive _x}) then {_activeArr = _activeArr - [_x]};
		} forEach (+_activeArr);
		missionNamespace setVariable [_activeKey, _activeArr];
		if (count _activeArr >= _maxActive) then {
			_skipAI = true;
		};
	};

	if (!_skipAI) then {
		//--- -----------------------------------------------------------------------
		//--- TARGET SELECTION (mirrors AI_Commander_Wildcard.sqf W13 gunship strike: largest
		//--- weighted enemy cluster near an enemy-owned town, tie-break nearest own HQ).
		//--- -----------------------------------------------------------------------
		_enemySide = if (_side == west) then {east} else {west};
		_enemyID   = (_enemySide) Call WFBE_CO_FNC_GetSideID;
		_cands = [];
		{ if ((_x getVariable ["sideID","?"]) == _enemyID) then {_cands = _cands + [_x]} } forEach towns;

		_scanR    = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_SCAN_RADIUS", 300];
		_bestTown = objNull; _bestScore = 0; _bestDist = 1e9; _bestObj = objNull;
		_hqPos    = getPos _hq;
		_enemyScan = allUnits + vehicles; //--- snapshot once per draw, reused across every candidate town below

		{
			private ["_town","_score","_nearObj","_nearBestW"];
			_town = _x;
			_score = 0; _nearObj = objNull; _nearBestW = 0;
			{
				if (alive _x && {(side _x) == _enemySide} && {(_x distance _town) < _scanR}) then {
					private "_w";
					_w = 1; //--- baseline rank-and-file infantry weight
					if (_x isKindOf "Man") then {
						//--- HVT flavour: officer/L3-class infantry score higher than rank-and-file.
						if ((typeOf _x) == (missionNamespace getVariable [Format ["WFBE_%1_HVT_CLASS", str _enemySide], ""])) then {_w = 6};
					} else {
						if (_x isKindOf "StaticWeapon") then {_w = 5}
						else {
							if (_x isKindOf "Tank" || {_x isKindOf "Wheeled_APC"}) then {_w = 4}
							else {_w = 2}; //--- other crewed vehicle
						};
					};
					_score = _score + _w;
					if (_w > _nearBestW) then {_nearBestW = _w; _nearObj = _x};
				};
			} forEach _enemyScan;
			if (_score > _bestScore || {_score == _bestScore && {_score > 0} && {(_town distance _hqPos) < _bestDist}}) then {
				_bestScore = _score; _bestTown = _town; _bestDist = _town distance _hqPos; _bestObj = _nearObj;
			};
		} forEach _cands;

		if (isNull _bestTown || {_bestScore <= 0}) then {
			_skipAI = true;
			["INFORMATION", Format ["AICOM_FPV_Swarm.sqf: draw skipped for %1 - no eligible target cluster.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	if (!_skipAI) then {
		_targetPos  = if (!isNull _bestObj) then {getPos _bestObj} else {getPos _bestTown};
		_targetName = _bestTown getVariable ["name","?"];

		//--- -----------------------------------------------------------------------
		//--- AFFORD CHECK + SWARM SIZE (scale down to what's affordable, min 1 drone).
		//--- -----------------------------------------------------------------------
		_swarmMax     = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_MAX", 5];
		_perDroneCost = (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST", 2500]) * (missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_COST_MULT", 2]);
		_swFunds      = (_side) Call GetAICommanderFunds;
		_swarmSize    = 0;
		if (_perDroneCost > 0) then {
			_swarmSize = floor (_swFunds / _perDroneCost);
			if (_swarmSize > _swarmMax) then {_swarmSize = _swarmMax};
		} else {
			["WARNING", Format ["AICOM_FPV_Swarm.sqf: draw skipped for %1 - invalid per-drone cost %2.", _sideText, _perDroneCost]] Call WFBE_CO_FNC_AICOMLog;
		};

		if (_swarmSize < 1) then {
			["INFORMATION", Format ["AICOM_FPV_Swarm.sqf: draw skipped for %1 - cannot afford even 1 drone (have %2, need %3).", _sideText, round _swFunds, round _perDroneCost]] Call WFBE_CO_FNC_AICOMLog;
		} else {
			_totalCost = _perDroneCost * _swarmSize;
			[_side, -_totalCost] Call ChangeAICommanderFunds;
			missionNamespace setVariable [_swKey, time];
			["INFORMATION", Format ["AICOM_FPV_Swarm.sqf: %1 purchased a %2-drone FPV swarm for %3 (funds %4 -> %5), target=%6 score=%7.", _sideText, _swarmSize, _totalCost, round _swFunds, round (_swFunds - _totalCost), _targetName, _bestScore]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FPVSWARM_PURCHASE|size=" + str _swarmSize + "|cost=" + str _totalCost + "|target=" + _targetName);

			[_side, _sideText, _sideID, _hq, _targetPos, _targetName, _swarmSize, _activeKey] spawn {
				private ["_side","_sideText","_sideID","_hq","_targetPos","_targetName","_swarmSize","_activeKey",
				         "_droneClass","_pilotClass","_launchGap","_hitRadius","_ttl","_i","_ang","_off","_hqp","_spawnPos",
				         "_drone","_grp","_pilot","_activeArr2"];
				_side      = _this select 0; _sideText  = _this select 1; _sideID    = _this select 2;
				_hq        = _this select 3; _targetPos = _this select 4; _targetName = _this select 5;
				_swarmSize = _this select 6; _activeKey = _this select 7;

				_droneClass = missionNamespace getVariable [Format ["WFBE_%1FPVDRONE", _sideText], ""];
				_pilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
				_launchGap  = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_LAUNCH_GAP", 1.5];
				_hitRadius  = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_HIT_RADIUS", 15];
				_ttl        = missionNamespace getVariable ["WFBE_C_AICOM_FPV_SWARM_TTL", 180];

				if (_droneClass == "" || {_pilotClass == ""} || {isNull _hq} || {!(isClass (configFile >> "CfgVehicles" >> _droneClass))}) exitWith {
					["WARNING", Format ["AICOM_FPV_Swarm.sqf: %1 swarm launch aborted - drone/pilot class unresolved (drone=%2 pilot=%3).", _sideText, _droneClass, _pilotClass]] Call WFBE_CO_FNC_AICOMLog;
				};

				_hqp = getPos _hq;
				_i = 0;
				while {_i < _swarmSize} do {
					//--- swarm-roll spatial offset (mirrors Server_GuerAirDef.sqf's KA-137 swarm block):
					//--- random bearing + 20-35m radial spread + a per-index vertical stagger.
					_ang      = random 360;
					_off      = 20 + random 15;
					_spawnPos = [(_hqp select 0) + _off * sin _ang, (_hqp select 1) + _off * cos _ang, (_hqp select 2) + 10 + 5 * _i];

					_drone = [_droneClass, _spawnPos, _side, random 360, false, false, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
					if (!isNull _drone) then {
						_grp = [_side, "aicom-fpvswarm"] Call WFBE_CO_FNC_CreateGroup;
						if (!isNull _grp) then {
							_pilot = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _pilot) then {
								_pilot moveInDriver _drone;
								_drone flyInHeight 60;
								_grp setBehaviour "CARELESS"; //--- ignore incidental contacts; stay on the guidance course (also the counterplay tradeoff - it never fights back).
								_grp setCombatMode "BLUE";

								_activeArr2 = missionNamespace getVariable [_activeKey, []];
								_activeArr2 = _activeArr2 + [_drone];
								missionNamespace setVariable [_activeKey, _activeArr2];

								[_drone, _grp, _pilot, _targetPos, _targetName, _sideText, _hitRadius, _ttl, _activeKey] spawn {
									private ["_drone","_grp","_pilot","_targetPos","_targetName","_sideText","_hitRadius","_ttl","_activeKey",
									         "_startT","_detonated","_curPos","_d","_dx","_dy","_horizontalD2","_diveRange","_diveRange2","_dir","_ammoClass","_activeArr3"];
									_drone     = _this select 0; _grp       = _this select 1; _pilot     = _this select 2;
									_targetPos = _this select 3; _targetName = _this select 4; _sideText  = _this select 5;
									_hitRadius = _this select 6; _ttl       = _this select 7; _activeKey = _this select 8;

									_pilot doMove _targetPos;
									_startT    = time;
									_detonated = false;
									_diveRange = 120;
									_diveRange2 = _diveRange * _diveRange;

									while {alive _drone && {alive _pilot} && {(time - _startT) < _ttl}} do {
										_curPos = getPos _drone;
										_dx = (_targetPos select 0) - (_curPos select 0);
										_dy = (_targetPos select 1) - (_curPos select 1);
										_horizontalD2 = (_dx * _dx) + (_dy * _dy); //--- A2 OA-safe 2D-equivalent; distance is 3D.
										_d = sqrt _horizontalD2;
										if (_horizontalD2 < (_hitRadius * _hitRadius)) exitWith {
											_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];
											createVehicle [_ammoClass, _curPos, [], 0, "NONE"];
											_detonated = true;
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FPVSWARM_HIT|target=" + _targetName + "|horizontalDist=" + str (round _d));
										};
										//--- doMove is a one-shot AI order on A2 OA - re-issue it to the pilot every poll tick.
										//--- The terminal vector forces an actual low run rather than holding at the 60m cruise floor.
										if (!_detonated) then {
											_pilot doMove _targetPos;
											if (_horizontalD2 < _diveRange2) then {
												_dir = if (_dx == 0 && {_dy == 0}) then {direction _drone} else {_dx atan2 _dy};
												_drone flyInHeight 0;
												_drone setDir _dir;
												_drone setVelocity [20 * sin _dir, 20 * cos _dir, -8];
											};
										};
										sleep 1;
									};

									if (!_detonated) then {
										diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FPVSWARM_SCUTTLE|target=" + _targetName + "|reason=" + (if (!alive _drone) then {"downed"} else {"ttl"}));
									};

									if (alive _pilot) then {_pilot setDammage 1};
									if (alive _drone) then {_drone setDammage 1};
									sleep 5; //--- let the wreck/hit EHs settle before deleting.
									{deleteVehicle _x} forEach (crew _drone + [_drone]);
									if (!isNull _grp) then {deleteGroup _grp};

									_activeArr3 = missionNamespace getVariable [_activeKey, []];
									_activeArr3 = _activeArr3 - [_drone];
									missionNamespace setVariable [_activeKey, _activeArr3];
								};
							} else {
								deleteVehicle _drone; deleteGroup _grp;
							};
						} else {
							deleteVehicle _drone;
						};
					};

					_i = _i + 1;
					if (_i < _swarmSize) then {sleep _launchGap};
				};
			};
		};
	};

	sleep _interval;
};
