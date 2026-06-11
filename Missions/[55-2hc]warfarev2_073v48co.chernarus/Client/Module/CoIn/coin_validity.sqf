/*
	coin_validity.sqf — WFBE_CL_FNC_CoinValidity
	Client-side prediction of server-side RequestDefense rejection gates.
	Mirrors the logic in Server\PVFunctions\RequestDefense.sqf exactly.
	Returns [ok(bool), reason(string)] — reason is "" when ok.

	Call order (first failure wins — cheapest checks first):
	  1. Funds               — not enough supply / cash
	  2. Water               — surfaceIsWater
	  3. Slope               — isFlatEmpty (A2 OA); skips gracefully if unreliable
	  4. WDDM composition cap — anchor classes only, WFBE_C_WDDM_COMP_CAP
	  5. Threat gate         — STATICS/MINES near enemy-contested base
	  6. Defense budget      — per-category single-defense caps

	Parameters:
	  _this select 0 : classname (String)
	  _this select 1 : pos (Array [x,y,z])
	  _this select 2 : logic (Object) — the BIS_COIN logic object

	Returns: [Bool, String]

	Compiled into WFBE_CL_FNC_CoinValidity at the top of coin_interface.sqf.
*/

private [
	"_class","_pos","_logic",
	"_side","_sideStr",
	"_defenseGateOn",
	"_logicSide","_startPos","_baseAreas","_baseRange","_centers",
	"_nearestCenter","_nearestDist","_isInsideBase",
	"_upgrades","_barrackLvl",
	"_isAnchor","_templateVar","_factionSpecific","_tplName","_tplChildren","_clsToCheck",
	"_anyThreatGated","_cat",
	"_enemySide","_enemyCount","_threatMin",
	"_compCap","_allDefNamesComp","_compObjs","_seenIDs","_cid",
	"_pendingS","_pendingF","_pendingM",
	"_capS","_capF","_capM",
	"_catStatics","_catForts","_catMines","_allDefNames",
	"_countS","_countF","_countM",
	"_budgetRejected","_rejCat","_rejUsed","_rejCap",
	"_itemcash","_itemcost","_itemFunds","_funds",
	"_params","_flatResult","_earlyResult"
];

_class  = _this select 0;
_pos    = _this select 1;
_logic  = _this select 2;

//--- Guard: only validate defense classnames (structures use a different path)
if (isNil "_class" || {typeName _class != "STRING"}) exitWith {[true,""]};

_side = sideJoined;
_sideStr = str _side;

//==========================================================================
// 1. FUNDS CHECK
//    Mirror coin_interface.sqf ~459-469: _itemcash from params, pick supply or cash.
//==========================================================================
_itemcash = 0;
_itemcost = 0;
_params = _logic getVariable ["BIS_COIN_params",[]];
if (count _params > 2) then {
	_itemcost = _params select 2;
	if (typeName _itemcost == "ARRAY") then {
		_itemcash = _itemcost select 0;
		_itemcost = _itemcost select 1;
	};
};
if (isNil "_itemcost" || {typeName _itemcost != "SCALAR"}) then {_itemcost = 0};

if (_itemcash == 0) then {
	_itemFunds = (sideJoined) Call GetSideSupply;
} else {
	_itemFunds = Call GetPlayerFunds;
};
if (isNil "_itemFunds") then {_itemFunds = 0};

if ((_itemFunds - _itemcost) < 0) exitWith {
	[false, format ["Not enough %1: %2 / %3", if (_itemcash == 0) then {"supply"} else {"cash"}, round _itemFunds, _itemcost]]
};

//==========================================================================
// 2. WATER CHECK
//==========================================================================
if (surfaceIsWater _pos) exitWith {[false, "Cannot build in water"]};

//==========================================================================
// 3. SLOPE CHECK via isFlatEmpty
//    isFlatEmpty [radius, minSep, maxVehSize, maxLandSteepness, maxH2O?, excludeVeh]
//    Returns [] if terrain is too steep / not flat.
//    We use radius=3 (tight test around the cursor), maxVehSize=2, rest standard.
//    If it returns empty the ground is too steep.
//    Guard with isNil in case the command isn't available in this build.
//==========================================================================
private "_flatResult";
_flatResult = _pos isFlatEmpty [3, 0, 2, 10, 0, false, objNull];
if (!isNil "_flatResult" && {typeName _flatResult == "ARRAY"} && {count _flatResult == 0}) exitWith {
	[false, "Ground too steep"]
};

//==========================================================================
// 4–6. DEFENSE BUDGET / WDDM / THREAT GATE
//       Only active when WFBE_C_DEFENSE_BUDGET > 0
//==========================================================================
_defenseGateOn = missionNamespace getVariable ["WFBE_C_DEFENSE_BUDGET", 0];
if (_defenseGateOn == 0) exitWith {[true,""]};

//--- The classname must actually be a defense (known to the side) to go further.
_allDefNames = missionNamespace getVariable [format ["WFBE_%1DEFENSENAMES", _sideStr], []];
if (!(_class in _allDefNames)) exitWith {[true,""]};

//----------------------------------------------------------------------
// Locate nearest base-area center (mirrors RequestDefense.sqf A.)
//----------------------------------------------------------------------
_logicSide = _side Call WFBE_CO_FNC_GetSideLogic;
_startPos  = _logicSide getVariable ["wfbe_startpos", objNull];
_baseAreas = WFBE_Client_Logic getVariable ["wfbe_basearea", []];
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

//--- Outside base area: no gates apply.
if (!_isInsideBase) exitWith {[true,""]};

//----------------------------------------------------------------------
// Barracks level (mirrors RequestDefense.sqf B1.)
//----------------------------------------------------------------------
_upgrades   = _logicSide getVariable ["wfbe_upgrades", []];
_barrackLvl = 0;
if (count _upgrades > WFBE_UP_BARRACKS) then { _barrackLvl = _upgrades select WFBE_UP_BARRACKS };

//----------------------------------------------------------------------
// Anchor / single-defense detection + clsToCheck (mirrors B2.)
//----------------------------------------------------------------------
_isAnchor   = (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _class) != -1});
_clsToCheck = [];

if (_isAnchor) then {
	_templateVar    = "";
	_factionSpecific = false;
	{
		if ((_x select 0) == _class) exitWith {
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
	_clsToCheck = [_class];
};

//==========================================================================
// 4–6. Accumulate rejection via _earlyResult (first non-empty wins).
//      exitWith inside if/forEach only exits that block, not this script,
//      so we use an array flag pattern: count > 0 means rejected.
//==========================================================================
private ["_earlyResult"];
_earlyResult = [];

//==========================================================================
// 4. WDDM COMPOSITION CAP (anchors only, mirrors B3b.)
//==========================================================================
if (_isAnchor && {count _earlyResult == 0}) then {
	_compCap         = missionNamespace getVariable ["WFBE_C_WDDM_COMP_CAP", 3];
	_allDefNamesComp = missionNamespace getVariable [format ["WFBE_%1DEFENSENAMES", _sideStr], []];
	_compObjs        = nearestObjects [_nearestCenter, _allDefNamesComp, _baseRange];
	_seenIDs = [];
	{
		_cid = _x getVariable ["WFBE_WDDMPositionAnchor", ""];
		if (_cid != "" && {!(_cid in _seenIDs)}) then { _seenIDs = _seenIDs + [_cid] };
	} forEach _compObjs;
	if (count _seenIDs >= _compCap) then {
		_earlyResult = [false, format ["Composition cap reached (%1 / %2)", count _seenIDs, _compCap]];
	};
};

//==========================================================================
// 5. THREAT GATE (STATICS + MINES only, mirrors B3.)
//==========================================================================
if (count _earlyResult == 0) then {
	_anyThreatGated = false;
	{
		_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
		if (_cat == "STATICS" || {_cat == "MINES"}) then { _anyThreatGated = true };
	} forEach _clsToCheck;

	if (_anyThreatGated) then {
		_enemySide  = [west, east] - [_side];
		_enemyCount = 0;
		{
			_enemyCount = _enemyCount + (_x countSide (nearestObjects [_nearestCenter, ["Man","Car","Motorcycle","Tank"], _baseRange]));
		} forEach _enemySide;

		_threatMin = missionNamespace getVariable ["WFBE_C_DEFENSE_THREAT_MIN", 3];
		if (_enemyCount >= _threatMin) then {
			_earlyResult = [false, format ["Needs %1+ enemies near base to build (have %2)", _threatMin, _enemyCount]];
		};
	};
};

//==========================================================================
// 6. PER-CATEGORY DEFENSE BUDGET (single defenses only, mirrors B4.)
//==========================================================================
if (count _earlyResult == 0 && !_isAnchor) then {
	_pendingS = 0; _pendingF = 0; _pendingM = 0;
	{
		_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
		if (_cat == "STATICS")        then { _pendingS = _pendingS + 1 };
		if (_cat == "FORTIFICATIONS") then { _pendingF = _pendingF + 1 };
		if (_cat == "MINES")          then { _pendingM = _pendingM + 1 };
	} forEach _clsToCheck;

	//--- Caps: 6+2x / 20+10x / 10+5x  (x = barracks level)
	_capS = 6  + 2  * _barrackLvl;
	_capF = 20 + 10 * _barrackLvl;
	_capM = 10 + 5  * _barrackLvl;

	//--- Build per-category classname lists for nearestObjects calls.
	_allDefNames = missionNamespace getVariable [format ["WFBE_%1DEFENSENAMES", _sideStr], []];
	_catStatics = []; _catForts = []; _catMines = [];
	{
		_cat = [_x, _side] Call WFBE_CO_FNC_GetDefenseCategory;
		if (_cat == "STATICS")        then { _catStatics = _catStatics + [_x] };
		if (_cat == "FORTIFICATIONS") then { _catForts   = _catForts   + [_x] };
		if (_cat == "MINES")          then { _catMines   = _catMines   + [_x] };
	} forEach _allDefNames;

	_countS = 0; _countF = 0; _countM = 0;
	if (count _catStatics > 0 && {_pendingS > 0}) then {
		{
			if (alive _x && {!(_x getVariable ["WFBE_WDDMPositionChild", false])}) then {_countS = _countS + 1};
		} forEach (nearestObjects [_nearestCenter, _catStatics, _baseRange]);
	};
	if (count _catForts > 0 && {_pendingF > 0}) then {
		{
			if (alive _x && {!(_x getVariable ["WFBE_WDDMPositionChild", false])}) then {_countF = _countF + 1};
		} forEach (nearestObjects [_nearestCenter, _catForts, _baseRange]);
	};
	if (count _catMines > 0 && {_pendingM > 0}) then {
		{
			if (alive _x && {!(_x getVariable ["WFBE_WDDMPositionChild", false])}) then {_countM = _countM + 1};
		} forEach (nearestObjects [_nearestCenter, _catMines, _baseRange]);
	};

	_budgetRejected = false; _rejCat = ""; _rejUsed = 0; _rejCap = 0;
	if (_pendingS > 0 && {(_countS + _pendingS) > _capS}) then {
		_budgetRejected = true; _rejCat = "Statics"; _rejUsed = _countS; _rejCap = _capS;
	};
	if (!_budgetRejected && {_pendingF > 0} && {(_countF + _pendingF) > _capF}) then {
		_budgetRejected = true; _rejCat = "Fortifications"; _rejUsed = _countF; _rejCap = _capF;
	};
	if (!_budgetRejected && {_pendingM > 0} && {(_countM + _pendingM) > _capM}) then {
		_budgetRejected = true; _rejCat = "Mines"; _rejUsed = _countM; _rejCap = _capM;
	};

	if (_budgetRejected) then {
		_earlyResult = [false, format ["Defense budget full — %1: %2 / %3", _rejCat, _rejUsed, _rejCap]];
	};
};

//--- Return
if (count _earlyResult > 0) exitWith { _earlyResult };
[true, ""]
