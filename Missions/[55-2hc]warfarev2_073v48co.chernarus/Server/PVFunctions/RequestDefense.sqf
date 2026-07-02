Private ["_builtByRepairTruck","_defenseType","_dir","_index","_manned","_pos","_reqPlayer","_side","_structure","_guardSide","_guardReject","_guardReqPlayer"]; //--- DR-6: added guard locals

//--- DR-6: always-on authority guards for RequestDefense PVF.
//--- A2 PVEH gives no sender identity, so we validate what the server can know.
if (typeName _this != "ARRAY" || {count _this < 5}) exitWith {
	["WARNING", "RequestDefense.sqf: DR-6 rejected - malformed payload (not ARRAY or count < 5)."] Call WFBE_CO_FNC_LogContent;
};
_guardSide = _this select 0;
if (typeName _guardSide != "SIDE") exitWith {
	["WARNING", Format ["RequestDefense.sqf: DR-6 rejected - index 0 is not SIDE [%1].", typeName _guardSide]] Call WFBE_CO_FNC_LogContent;
};
if (_guardSide != west && {_guardSide != east} && {_guardSide != resistance}) exitWith {
	["WARNING", Format ["RequestDefense.sqf: DR-6 rejected - side [%1] not west/east/resistance.", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
if (typeName (_this select 1) != "STRING") exitWith {
	["WARNING", Format ["RequestDefense.sqf: DR-6 rejected - defenseType (index 1) is not STRING [%1].", typeName (_this select 1)]] Call WFBE_CO_FNC_LogContent;
};
//--- Optional requester-player check (index 6). Uses _reject-flag idiom because the checks are nested
//--- inside then{} blocks — exitWith inside then{} only exits the block, NOT the script (A2 rule).
//--- A null _guardReqPlayer MUST pass: EASA repair-truck and JIP paths legitimately send null.
//--- We only reject if a non-null, non-player object or cross-side object is present.
private ["_guardReject"]; _guardReject = false;
if (count _this > 6) then {
	_guardReqPlayer = _this select 6;
	if (!isNull _guardReqPlayer) then {
		if (!isPlayer _guardReqPlayer) then {
			_guardReject = true;
			["WARNING", Format ["RequestDefense.sqf: DR-6 rejected - non-player requester [%1].", _guardReqPlayer]] Call WFBE_CO_FNC_LogContent;
		};
		if (!_guardReject && {side _guardReqPlayer != _guardSide}) then {
			_guardReject = true;
			["WARNING", "RequestDefense.sqf: DR-6 rejected - requester side mismatch."] Call WFBE_CO_FNC_LogContent;
		};
	};
};
if (_guardReject) exitWith {};
//--- DR-6 guards passed.

_side            = _this select 0;
_defenseType     = _this select 1;
_pos             = _this select 2;
_dir             = _this select 3;
_manned          = _this select 4;
_builtByRepairTruck = if (count _this > 5) then {_this select 5} else {false};
_reqPlayer          = if (count _this > 6) then {_this select 6} else {objNull};
// Defense auto-manning defaults on client-side and Custom Action 16 can still toggle it off/on.

_index = (missionNamespace getVariable Format["WFBE_%1DEFENSENAMES",str _side]) find _defenseType;
if (_index != -1) then {
	//--- Position anchors spawn a whole WDDM composition; everything else is a single defense.
	//--- Release-merge (WDDM + engineer-EASA): the single-defense path keeps the EASA repair-truck tagging args
	//--- (manning range + builtByRepairTruck); the composition path is commander-built and does not need them.
	//--- NOTE: Land_Pneu (Site Clearance) is handled client-side in coin_interface.sqf via the dedicated
	//--- RequestSiteClearance PVF and never reaches this path.

	//==========================================================================
	// DEFENSE BUDGET + THREAT GATE (WFBE_C_DEFENSE_BUDGET = 1)
	// Both gates use the same base-area detection logic.  When the gate constant
	// is 0 behaviour is EXACTLY as before this change.
	//==========================================================================
	if ((missionNamespace getVariable ["WFBE_C_DEFENSE_BUDGET", 0]) > 0) then {

		//----------------------------------------------------------------------
		// Helpers
		//----------------------------------------------------------------------
		private ["_logik","_startPos","_baseAreas","_baseRange","_centers",
		         "_nearestCenter","_nearestDist","_isInsideBase",
		         "_upgrades","_barrackLvl",
		         "_isAnchor","_clsToCheck",
		         "_cat","_classesByCategory","_existingCount","_cap",
		         "_budgetRejected","_threatRejected","_enemySide","_enemyCount",
		         "_refundPrice","_templateVar","_tplEntry","_tplName","_factionSpecific",
		         "_tplChildren","_childCls","_childCat","_budgetChildCount",
		         "_compCap","_allDefNamesComp","_compObjs","_seenIDs","_cid"];

		//----------------------------------------------------------------------
		// A. Locate the nearest base-area center to the placement position.
		//    (mirrors RequestStructure.sqf bank-placement pattern)
		//----------------------------------------------------------------------
		_logik     = _side Call WFBE_CO_FNC_GetSideLogic;
		_startPos  = _logik getVariable ["wfbe_startpos", objNull];
		_baseAreas = _logik getVariable ["wfbe_basearea", []];
		_baseRange = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 250];

		_centers = [];
		if !(isNull _startPos) then { _centers = _centers + [getPos _startPos] };
		{ _centers = _centers + [getPos _x] } forEach _baseAreas;

		_nearestCenter = [];
		_nearestDist   = 99999;
		{
			private "_d";
			_d = _pos distance _x;
			if (_d < _nearestDist) then { _nearestDist = _d; _nearestCenter = _x };
		} forEach _centers;

		_isInsideBase = (_nearestDist < _baseRange);

		//----------------------------------------------------------------------
		// B. Only apply budget / threat gates when inside a base area.
		//----------------------------------------------------------------------
		if (_isInsideBase) then {

			//------------------------------------------------------------------
			// B1. Barracks level for cap calculation.
			//------------------------------------------------------------------
			_upgrades   = _logik getVariable ["wfbe_upgrades", []];
			_barrackLvl = 0;
			if (count _upgrades > WFBE_UP_BARRACKS) then { _barrackLvl = _upgrades select WFBE_UP_BARRACKS };

			//------------------------------------------------------------------
			// B2. Determine whether this is a WDDM composition anchor.
			//     For anchors: the classnames to count are ALL the template children.
			//     For single defenses: just _defenseType itself.
			//------------------------------------------------------------------
			_isAnchor  = (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1});
			_clsToCheck = [];

			if (_isAnchor) then {
				//--- Resolve the template just like Server_ConstructPosition does.
				_templateVar    = "";
				_factionSpecific = false;
				{
					if ((_x select 0) == _defenseType) exitWith {
						_templateVar     = _x select 1;
						_factionSpecific = _x select 2;
					};
				} forEach (if (isNil "WFBE_POSITION_TEMPLATE_MAP") then {[]} else {WFBE_POSITION_TEMPLATE_MAP});

				if (_templateVar != "") then {
					_tplName = if (_factionSpecific) then {
						_templateVar + (if (_side == west) then {"_WEST"} else {"_EAST"})
					} else {
						_templateVar
					};
					_tplChildren = missionNamespace getVariable _tplName;
					if !(isNil "_tplChildren") then {
						{
							_clsToCheck = _clsToCheck + [_x select 0];
						} forEach _tplChildren;
					};
				};
			} else {
				_clsToCheck = [_defenseType];
			};

			//------------------------------------------------------------------
			// B3. THREAT GATE — statics and mines are blocked while enemies
			//     are within WFBE_C_BASE_AREA_RANGE of the nearest base center.
			//     Fortifications and OTHER are NOT threat-gated.
			//     For an anchor: gate if ANY child classname is STATICS or MINES.
			//------------------------------------------------------------------
			_threatRejected = false;
			private "_anyThreatGated";
			_anyThreatGated = false;
			{
				_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
				if (_cat == "STATICS" || _cat == "MINES") then { _anyThreatGated = true };
			} forEach _clsToCheck;

			if (_anyThreatGated) then {
				//--- Count enemy GROUND units within base-area range of the nearest base center.
				//--- Live-tune (2026-06-10 play test): the original any-1-enemy/any-class gate blocked
				//--- placement near-permanently in a real round — ambient resistance AI from a
				//--- neighbouring town or a single aircraft overflight counted as a "raid".
				//--- Now: major-team opponents only (no ambient GUER), ground classes only (no Air),
				//--- and a minimum presence of WFBE_C_DEFENSE_THREAT_MIN (default 3) to fire the gate.
				_enemySide  = [west, east] - [_side];
				_enemyCount = 0;
				{
					_enemyCount = _enemyCount + (_x countSide (nearestObjects [_nearestCenter, ["Man","Car","Motorcycle","Tank"], _baseRange]));
				} forEach _enemySide;

				if (_enemyCount >= (missionNamespace getVariable ["WFBE_C_DEFENSE_THREAT_MIN", 3])) then {
					_threatRejected = true;
					["INFORMATION", Format ["RequestDefense.sqf: [%1] threat gate rejected [%2] (%3 enemies within %4 m of base).", str _side, _defenseType, _enemyCount, _baseRange]] Call WFBE_CO_FNC_LogContent;
				};
			};

			//------------------------------------------------------------------
			// B3b. COMPOSITION CAP — anchors only; max WFBE_C_WDDM_COMP_CAP
			//      distinct compositions per base area (size-independent).
			//      Counted by distinct WFBE_WDDMPositionAnchor placement-ID
			//      values found on defense objects near the base center.
			//------------------------------------------------------------------
			_budgetRejected = false;
			_rejCat = ""; _rejUsed = 0; _rejCap = 0;

			if (_isAnchor) then {
				_compCap      = missionNamespace getVariable ["WFBE_C_WDDM_COMP_CAP", 3];
				_allDefNamesComp = missionNamespace getVariable [format ["WFBE_%1DEFENSENAMES", str _side], []];
				_compObjs     = nearestObjects [_nearestCenter, _allDefNamesComp, _baseRange];
				_seenIDs      = [];
				{
					_cid = _x getVariable ["WFBE_WDDMPositionAnchor", ""];
					if (_cid != "" && {!(_cid in _seenIDs)}) then { _seenIDs = _seenIDs + [_cid] };
				} forEach _compObjs;
				if (count _seenIDs >= _compCap) then {
					_budgetRejected = true;
					_rejCat  = "WddmCompositionCapReached";
					_rejUsed = count _seenIDs;
					_rejCap  = _compCap;
					["INFORMATION", Format ["RequestDefense.sqf: [%1] WDDM composition cap rejected [%2] — %3/%4 compositions in base.", str _side, _defenseType, _rejUsed, _rejCap]] Call WFBE_CO_FNC_LogContent;
				};
			};

			//------------------------------------------------------------------
			// B4. BUDGET CHECK — per category against live-object count.
			//     Build a classname list for each category, then do ONE
			//     nearestObjects call per category that has items to count.
			//     Compositions are exempt (cap is B3b above); only single
			//     defenses hit per-category budget.
			//------------------------------------------------------------------
			private ["_catStatics","_catForts","_catMines","_pendingS","_pendingF","_pendingM","_capS","_capF","_capM","_countS","_countF","_countM","_allDefNames"];

			if (!_isAnchor) then {
				//--- Single defenses only: count pending objects against per-category caps.
				//--- Compositions are exempt here; their cap is enforced in B3b above.
				_pendingS = 0; _pendingF = 0; _pendingM = 0;
				{
					_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
					switch (_cat) do {
						case "STATICS":       { _pendingS = _pendingS + 1 };
						case "FORTIFICATIONS":{ _pendingF = _pendingF + 1 };
						case "MINES":         { _pendingM = _pendingM + 1 };
					};
				} forEach _clsToCheck;

				// Caps: STATICS = WFBE_C_BASE_DEFENSE_STATICS_CAP (flat); FORTS = 20+10x; MINES = 10+5x  (x = barracks level)
				_capS = missionNamespace getVariable ["WFBE_C_BASE_DEFENSE_STATICS_CAP", 25];
				_capF = 20 + 10 * _barrackLvl;
				_capM = 10 + 5  * _barrackLvl;

				// Count existing: build lists per category for nearestObjects calls.
				// Skip WDDM composition children so they don't consume single-defense budget slots.
				_allDefNames = missionNamespace getVariable Format["WFBE_%1DEFENSENAMES", str _side];
				_catStatics = []; _catForts = []; _catMines = [];
				{
					_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
					switch (_cat) do {
						case "STATICS":        { _catStatics = _catStatics + [_x] };
						case "FORTIFICATIONS": { _catForts   = _catForts   + [_x] };
						case "MINES":          { _catMines   = _catMines   + [_x] };
					};
				} forEach _allDefNames;

				_countS = 0; _countF = 0; _countM = 0;
				if (count _catStatics > 0 && _pendingS > 0) then {
					{
						if (alive _x && !(_x getVariable ["WFBE_WDDMPositionChild", false])) then {_countS = _countS + 1}
					} forEach (nearestObjects [_nearestCenter, _catStatics, _baseRange]);
				};
				if (count _catForts > 0 && _pendingF > 0) then {
					{
						if (alive _x && !(_x getVariable ["WFBE_WDDMPositionChild", false])) then {_countF = _countF + 1}
					} forEach (nearestObjects [_nearestCenter, _catForts, _baseRange]);
				};
				if (count _catMines > 0 && _pendingM > 0) then {
					{
						if (alive _x && !(_x getVariable ["WFBE_WDDMPositionChild", false])) then {_countM = _countM + 1}
					} forEach (nearestObjects [_nearestCenter, _catMines, _baseRange]);
				};

				if (_pendingS > 0 && (_countS + _pendingS) > _capS) then {
					_budgetRejected = true; _rejCat = "Statics"; _rejUsed = _countS; _rejCap = _capS;
				};
				if (!_budgetRejected && _pendingF > 0 && (_countF + _pendingF) > _capF) then {
					_budgetRejected = true; _rejCat = "Fortifications"; _rejUsed = _countF; _rejCap = _capF;
				};
				if (!_budgetRejected && _pendingM > 0 && (_countM + _pendingM) > _capM) then {
					_budgetRejected = true; _rejCat = "Mines"; _rejUsed = _countM; _rejCap = _capM;
				};

				if (_budgetRejected) then {
					["INFORMATION", Format ["RequestDefense.sqf: [%1] budget rejected [%2] — %3 used %4/%5.", str _side, _defenseType, _rejCat, _rejUsed, _rejCap]] Call WFBE_CO_FNC_LogContent;
				};
			};

			//------------------------------------------------------------------
			// B5. Reject + refund if either gate fired.
			//------------------------------------------------------------------
			if (_threatRejected || _budgetRejected) then {
				//--- Refund the player who placed it (charged optimistically on the client).
				if (!(isNull _reqPlayer) && alive _reqPlayer) then {
					private "_defPrice";
					_defPrice = 0;
					private "_globalEntry";
					_globalEntry = missionNamespace getVariable _defenseType;
					if !(isNil "_globalEntry") then { _defPrice = _globalEntry select QUERYUNITPRICE };

					if (_defPrice > 0) then {
						if (_threatRejected) then {
							[_reqPlayer, "LocalizeMessage", ["DefenseThreatGate", _defPrice]] Call WFBE_CO_FNC_SendToClient;
						} else {
							if (_rejCat == "WddmCompositionCapReached") then {
								[_reqPlayer, "LocalizeMessage", ["WddmCompositionCapReached", _rejUsed, _rejCap, _defenseType]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_reqPlayer, "LocalizeMessage", ["DefenseBudgetFull", _rejCat, _rejUsed, _rejCap, _defPrice]] Call WFBE_CO_FNC_SendToClient;
							};
						};
					} else {
						//--- Price not resolvable server-side (e.g. WDDM anchors): pass the CLASSNAME
						//--- so the client refunds via its own price lookup — exactly what it charged.
						//--- (Was: notify-only with 0 -> anchors LOST their 2,500-5,000 cash on threat reject.)
						if (_threatRejected) then {
							[_reqPlayer, "LocalizeMessage", ["DefenseThreatGate", _defenseType]] Call WFBE_CO_FNC_SendToClient;
						} else {
							if (_rejCat == "WddmCompositionCapReached") then {
								[_reqPlayer, "LocalizeMessage", ["WddmCompositionCapReached", _rejUsed, _rejCap, _defenseType]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_reqPlayer, "LocalizeMessage", ["DefenseBudgetFull", _rejCat, _rejUsed, _rejCap, _defenseType]] Call WFBE_CO_FNC_SendToClient;
							};
						};
					};
				};
				// Early exit — do not build anything.
			} else {
				//--- All gates passed: build as normal.
					//--- B74.2: leaderboard DEFENSE-built credit to the placing player (gates passed; player-only path).
					if (!isNull _reqPlayer && {isPlayer _reqPlayer}) then {private "_dUid"; _dUid = getPlayerUID _reqPlayer; if (_dUid != "") then {[_dUid, WFBE_STAT_DEFENSES_BUILT, 1] call WFBE_SE_FNC_RecordStat}};
				if (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1}) then {
					[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
				} else {
					[_defenseType,_side,_pos,_dir,_manned,false,missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",_builtByRepairTruck] Call ConstructDefense;
				};
			};

		} else {
			//--- Outside any base area: budget does not apply — build as normal.
			//--- B74.2: leaderboard DEFENSE-built credit to the placing player (outside base; player-only path).
			if (!isNull _reqPlayer && {isPlayer _reqPlayer}) then {private "_dUid"; _dUid = getPlayerUID _reqPlayer; if (_dUid != "") then {[_dUid, WFBE_STAT_DEFENSES_BUILT, 1] call WFBE_SE_FNC_RecordStat}};
			if (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1}) then {
				[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
			} else {
				[_defenseType,_side,_pos,_dir,_manned,false,missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",_builtByRepairTruck] Call ConstructDefense;
			};
		};

	} else {
		//--- Budget gate OFF (WFBE_C_DEFENSE_BUDGET = 0): behaviour exactly as before.
		//--- B74.2: leaderboard DEFENSE-built credit to the placing player (budget gate off; player-only path).
		if (!isNull _reqPlayer && {isPlayer _reqPlayer}) then {private "_dUid"; _dUid = getPlayerUID _reqPlayer; if (_dUid != "") then {[_dUid, WFBE_STAT_DEFENSES_BUILT, 1] call WFBE_SE_FNC_RecordStat}};
		if (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1}) then {
			[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
		} else {
			[_defenseType,_side,_pos,_dir,_manned,false,missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",_builtByRepairTruck] Call ConstructDefense;
		};
	};
};
