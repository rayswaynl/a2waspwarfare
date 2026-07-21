/* Description: Star Fortress Phase 1 (MVP) - commander build-request validator (6-gate chain).
   kimi/starfort-mvp, flag WFBE_C_STARFORT_ENABLE (default 0). WEST/EAST-only for v1
   (GUER already has the truck-deployed FOB forward-spawn).

   Sender: Client\Action\Action_StarFort.sqf (commander-only, one-shot map-click designation):
       ["RequestStarFort", [_side,_pos,_dir,_reqPlayer]] Call WFBE_CO_FNC_SendToServer;
   Handler: SRVFNCRequestStarFort via the generic server PVF loop (Common\Init\Init_PublicVariables.sqf).

   Gate chain (any failure = targeted reject message; NO supply is touched on reject - stage payments
   are debited server-side per construction stage, so a rejected request never charged anyone):
     0. WFBE_C_STARFORT_ENABLE master flag + WEST/EAST-only (a forged/leftover PV dies here).
     1. Barracks unlock at max tier (reuses the RequestDefense.sqf _barrackLvl idiom).
     2. One-per-side registry: no live WFBE_STARFORT_<side> keep AND no in-flight _PENDING reservation
        (Bank _PENDING idiom, RequestStructure.sqf). This is the binding single-instance gate.
        The WDDM_COMP_CAP pool is NOT duplicated: fort children carry the SAME WFBE_WDDMPositionAnchor /
        WFBE_WDDMAnchorClass stamps minted from the SAME WFBE_WDDMPlacementCounter that
        RequestDefense.sqf / Server_ConstructPosition.sqf already count - no parallel counter exists.
     3. GATE 1 - Common_ValidateCampPos (water/slope/building/tree/road) - its first real caller.
     4. GATE 2 - outside own base-area (> WFBE_C_BASE_AREA_RANGE from wfbe_startpos/wfbe_basearea,
        mirrors the RequestDefense.sqf nearest-base-center idiom).
     5. GATE 3 - > WFBE_C_STARFORT_MIN_ENEMY_HQ_DIST from the enemy HQ (repair-truck
        WFBE_C_BASE_HQ_BUILD_RANGE idiom, applied to the ENEMY HQ).
     6. GATE 4 - > WFBE_C_STARFORT_MIN_ENEMY_TOWN_DIST from every town NOT owned by the builder's side
        (enemy-held or neutral/contested) - the anti-shortcut floor.
     7. GATE 5 - < WFBE_C_STARFORT_MAX_FRONTLINE_DIST from the nearest friendly-held town (supply tether).
     8. GATE 6 - footprint-wide slope scan: every bastion corner + wall midpoint must pass
        WFBE_C_STARFORT_SLOPE_MAX (extends the single-point aircraft-spawn scan to the whole ring;
        any failing point rejects the whole placement - never a partial ring).

   On accept: stamp _PENDING (closes the two-simultaneous-requests race), debit Stage 1 (FOUNDATION)
   from side supply, Spawn the staged watcher (Server\Construction\Construction_StarFortSite.sqf).
   The debit calls the stock WFBE_SE_FNC_HandleSideSupplyChange handler DIRECTLY with the PVEH-shaped
   args - publicVariableServer fired from server-side code never triggers the server's own PVEH
   (repo trap list), so Call ChangeSideSupply from here would silently not apply.
*/
Private ["_side","_pos","_dir","_reqPlayer","_reject","_reason","_logik","_upgrades","_barrackLvl",
         "_regKey","_pendKey","_existing","_pendingTime","_pendingWindow","_costFoundation","_supply",
         "_radius","_slopeMax","_campOK","_startPos","_baseAreas","_baseRange","_centers","_nearestDist","_d",
         "_enemySide","_enemyHQ","_minHQDist","_mySID","_minEnemyTown","_minFriendTown","_minEnemyDist","_maxFront","_td",
         "_nB","_i","_a","_sx","_sy","_sn","_reqName"];

_side      = _this select 0;
_pos       = _this select 1;
_dir       = _this select 2;
_reqPlayer = if (count _this > 3) then {_this select 3} else {objNull};

_reject = false;
_reason = "";

//--- GATE 0: master flag + WEST/EAST-only.
if ((missionNamespace getVariable ["WFBE_C_STARFORT_ENABLE", 0]) <= 0) then {
	_reject = true; _reason = "Star Fortress is disabled on this server.";
};
if (!_reject && {!(_side in [west, east])}) then {
	_reject = true; _reason = "Star Fortress is a conventional-army asset (WEST/EAST only).";
};
if (!_reject && {typeName _pos != "ARRAY" || {count _pos < 2}}) then {
	_reject = true; _reason = "Star Fortress: invalid build position.";
};
if (!_reject) then {_pos = [_pos select 0, _pos select 1, 0]};

//--- GATE 1 (unlock): max barracks tier - RequestDefense.sqf _barrackLvl idiom.
if (!_reject) then {
	_logik = _side Call WFBE_CO_FNC_GetSideLogic;
	_upgrades = _logik getVariable ["wfbe_upgrades", []];
	_barrackLvl = 0;
	if (count _upgrades > WFBE_UP_BARRACKS) then { _barrackLvl = _upgrades select WFBE_UP_BARRACKS };
	if (_barrackLvl < (missionNamespace getVariable ["WFBE_C_STARFORT_UNLOCK_BARRACKS_LVL", 3])) then {
		_reject = true;
		_reason = Format ["Star Fortress requires Barracks level %1.", missionNamespace getVariable ["WFBE_C_STARFORT_UNLOCK_BARRACKS_LVL", 3]];
	};
};

//--- GATE 2: one-per-side registry + pending race-close (Bank idiom).
if (!_reject) then {
	_regKey  = if (_side == west) then {"WFBE_STARFORT_WEST"} else {"WFBE_STARFORT_EAST"};
	_pendKey = _regKey + "_PENDING";
	_existing = missionNamespace getVariable [_regKey, objNull];
	if (!isNull _existing && {alive _existing}) then {
		_reject = true; _reason = "Your side's Star Fortress already stands.";
	};
	if (!_reject) then {
		_pendingWindow = missionNamespace getVariable ["WFBE_C_STARFORT_PENDING_WINDOW", 180];
		_pendingTime = missionNamespace getVariable [_pendKey, -1e11];
		if ((time - _pendingTime) < _pendingWindow) then {
			_reject = true; _reason = "A Star Fortress build is already underway.";
		};
	};
};

//--- Stage-1 funds pre-check (the debit itself happens at accept, below).
if (!_reject) then {
	_costFoundation = missionNamespace getVariable ["WFBE_C_STARFORT_COST_FOUNDATION", 6000];
	_supply = _side Call GetSideSupply;
	if (isNil "_supply") then {_supply = 0};
	if (_supply < _costFoundation) then {
		_reject = true;
		_reason = Format ["Star Fortress foundation costs %1 supply (have %2).", _costFoundation, _supply];
	};
};

//--- GATE 3: Common_ValidateCampPos (water/slope/building/tree/road) - first real caller.
if (!_reject) then {
	_radius = missionNamespace getVariable ["WFBE_C_STARFORT_RADIUS", 25];
	_slopeMax = missionNamespace getVariable ["WFBE_C_STARFORT_SLOPE_MAX", 0.97];
	_campOK = [_pos, [], 0, _radius + 10, _radius + 5, _slopeMax, _radius + 5] Call WFBE_CO_FNC_ValidateCampPos;
	if (!_campOK) then {_reject = true; _reason = "Site unsuitable (water/slope/building/road/trees)."};
};

//--- GATE 4: outside own base-area (RequestDefense nearest-center idiom).
if (!_reject) then {
	_startPos = _logik getVariable ["wfbe_startpos", [0,0,0]];
	_baseAreas = _logik getVariable ["wfbe_basearea", []];
	_baseRange = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 250];
	_centers = [_startPos];
	{ _centers = _centers + [getPos _x] } forEach _baseAreas;
	_nearestDist = 99999;
	{ _d = _pos distance _x; if (_d < _nearestDist) then {_nearestDist = _d}; } forEach _centers;
	if (_nearestDist < _baseRange) then {_reject = true; _reason = "Too close to your own base area."};
};

//--- GATE 5: min distance from the enemy HQ.
if (!_reject) then {
	_enemySide = ([west, east] - [_side]) select 0;
	_enemyHQ = (_enemySide) Call WFBE_CO_FNC_GetSideHQ;
	_minHQDist = missionNamespace getVariable ["WFBE_C_STARFORT_MIN_ENEMY_HQ_DIST", 1000];
	if (!isNull _enemyHQ && {alive _enemyHQ}) then {
		if ((_pos distance (getPos _enemyHQ)) < _minHQDist) then {_reject = true; _reason = "Too close to the enemy HQ."};
	};
};

//--- GATE 6 + 7: enemy/neutral town floor (anti-shortcut) + friendly-town tether, one towns pass.
//--- Inactive towns (naval carriers) are skipped - a moving carrier must not drag an exclusion zone.
if (!_reject) then {
	_mySID = _side Call WFBE_CO_FNC_GetSideID;
	_minEnemyTown = 99999;
	_minFriendTown = 99999;
	{
		if (!isNil "_x") then {
			if !(_x getVariable ["wfbe_inactive", false]) then {
				_td = _pos distance (getPos _x);
				if ((_x getVariable ["sideID", -1]) == _mySID) then {
					if (_td < _minFriendTown) then {_minFriendTown = _td};
				} else {
					if (_td < _minEnemyTown) then {_minEnemyTown = _td};
				};
			};
		};
	} forEach towns;
	_minEnemyDist = missionNamespace getVariable ["WFBE_C_STARFORT_MIN_ENEMY_TOWN_DIST", 800];
	_maxFront = missionNamespace getVariable ["WFBE_C_STARFORT_MAX_FRONTLINE_DIST", 1500];
	if (_minEnemyTown < _minEnemyDist) then {_reject = true; _reason = Format ["Too close (%1m) to a town your side does not hold.", round _minEnemyTown];};
	if (!_reject && {_minFriendTown > _maxFront}) then {_reject = true; _reason = Format ["Too far (%1m) from the nearest friendly-held town.", round _minFriendTown];};
};

//--- GATE 8: footprint-wide slope scan (bastion corners + wall midpoints, same diamond trace the
//--- builder uses - so a pass here means the real ring fits the ground).
if (!_reject) then {
	_nB = missionNamespace getVariable ["WFBE_C_STARFORT_BASTIONS", 4];
	for "_i" from 0 to (_nB - 1) do {
		if (!_reject) then {
			_a = _dir + (180 / _nB) + _i * (360 / _nB);
			_sx = (_pos select 0) + _radius * (sin _a);
			_sy = (_pos select 1) + _radius * (cos _a);
			_sn = surfaceNormal [_sx, _sy];
			if ((_sn select 2) < _slopeMax) then {_reject = true; _reason = "Ring footprint is too steep (bastion corner).";};
		};
		if (!_reject) then {
			_a = _dir + _i * (360 / _nB);
			_sx = (_pos select 0) + _radius * (sin _a);
			_sy = (_pos select 1) + _radius * (cos _a);
			_sn = surfaceNormal [_sx, _sy];
			if ((_sn select 2) < _slopeMax) then {_reject = true; _reason = "Ring footprint is too steep (wall midpoint).";};
		};
	};
};

//--- Verdict. Rejects cost nothing (nothing was charged).
if (_reject) exitWith {
	["WARNING", Format ["RequestStarFort.sqf: [%1] build rejected at %2 - %3", str _side, _pos, _reason]] Call WFBE_CO_FNC_LogContent;
	if (!isNull _reqPlayer && {alive _reqPlayer}) then {
		[_reqPlayer, "LocalizeMessage", ["Wildcard", Format ["STAR FORTRESS rejected: %1", _reason]]] Call WFBE_CO_FNC_SendToClient;
	};
};

//--- Accept: stamp the pending reservation FIRST (closes the duplicate-request race), then debit
//--- Stage 1 (FOUNDATION) via the stock side-supply handler (direct call - see header note).
_reqName = if (isNull _reqPlayer) then {"commander"} else {name _reqPlayer};
missionNamespace setVariable [_pendKey, time];
[[Format ["wfbe_supply_temp_%1", str _side], [_side, -_costFoundation, Format ["Star Fortress foundation by commander %1.", _reqName]]], _side] Call WFBE_SE_FNC_HandleSideSupplyChange;
["INFORMATION", Format ["RequestStarFort.sqf: [%1] Star Fortress accepted at %2 (dir %3). Stage 1 charged: %4 supply.", str _side, _pos, _dir, _costFoundation]] Call WFBE_CO_FNC_LogContent;
[_side, _pos, _dir, _reqPlayer] Spawn WFBE_SE_FNC_StarFortSite;
