/*
	Server_SiteClearance.sqf — Commander build-menu Site Clearance: fell trees near a
	base-area placement position.  Called from RequestSiteClearance.sqf (the dedicated
	server PVF) which receives the real player identity from the client payload.
	NO object is ever built; coin_interface sends RequestSiteClearance instead of
	RequestDefense for Land_Pneu so this function is the only server-side entry point.

	ENGINE NOTE (deferred): whether setDamage 1 fells A2 terrain trees and whether fallen
	trunks sync to JIP is DEFERRED to the integration smoke test.  Charge ordering is safe
	by design: supply is deducted only AFTER counting actual fells (getDammage >= 1), so
	a tree that refuses to fall costs nothing.

	ANTI-GRIEF rationale: commander-only + friendly-base-only + barracks-1 + 15 s per-side
	rate-limit makes this a deliberate team action, not a griefable one.

	Parameters (array):
		_this select 0 : side
		_this select 1 : placement position [x, y, z]
		_this select 2 : requesting player
*/

private ["_side","_pos","_reqPlayer","_logik","_upgrades","_barrackLvl","_commanderTeam",
         "_startPos","_baseAreas","_centers","_baseRange","_inBase","_lastClear","_candidates",
         "_trees","_tree","_s","_isTree","_N","_cost","_currentSupply","_felled","_i","_matchAny"];

_side      = _this select 0;
_pos       = _this select 1;
_reqPlayer = _this select 2;

// Gate 1: feature enabled.
if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) == 0) exitWith {
	["WARNING", "Server_SiteClearance.sqf: Rejected — WFBE_C_UNITS_BULLDOZER gate is off."] Call WFBE_CO_FNC_LogContent;
};

// Gate 2: player alive.
if (isNull _reqPlayer || {!(alive _reqPlayer)}) exitWith {};

// Gate 3: Commander-only.
// WFBE_CO_FNC_GetCommanderTeam returns the commander group stored as wfbe_commander
// on the side logic (see Common\Functions\Common_GetCommanderTeam.sqf).
// Validation precedent: Server_ChangeSideSupply.sqf references leader of the commander
// team; RequestEnqueue.sqf checks GetCommanderTeam is not null as a side-level guard.
// For a per-player check: the requester must BE the leader of the commander group.
_commanderTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _commanderTeam || {_reqPlayer != leader _commanderTeam}) exitWith {
	[_reqPlayer, "LocalizeMessage", ["SiteClearanceCommanderOnly"]] Call WFBE_CO_FNC_SendToClient;
	["DEBUG", Format ["Server_SiteClearance.sqf: [%1] rejected — requester %2 is not the commander.", str _side, name _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};

// Gate 4: Barracks >= 1 (balance gate).
// Mirrors Server_CounterBattery.sqf's WFBE_UP_CBRADAR check.
_logik = _side Call WFBE_CO_FNC_GetSideLogic;
_upgrades = _logik getVariable ["wfbe_upgrades", []];
_barrackLvl = 0;
if (count _upgrades > WFBE_UP_BARRACKS) then { _barrackLvl = _upgrades select WFBE_UP_BARRACKS };
if (_barrackLvl < 1) exitWith {
	[_reqPlayer, "LocalizeMessage", ["SiteClearanceNeedsBarracks1"]] Call WFBE_CO_FNC_SendToClient;
	["DEBUG", Format ["Server_SiteClearance.sqf: [%1] rejected — Barracks level %2 < 1.", str _side, _barrackLvl]] Call WFBE_CO_FNC_LogContent;
};

// Gate 5: Placement position inside a friendly base area.
// Mirrors the bank-placement check in RequestStructure.sqf.
// (_logik already fetched above.)
_startPos  = _logik getVariable ["wfbe_startpos", objNull];
_baseAreas = _logik getVariable ["wfbe_basearea", []];
_baseRange = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 250];

_centers = [];
if !(isNull _startPos) then { _centers = _centers + [getPos _startPos] };
{_centers = _centers + [getPos _x]} forEach _baseAreas;

_inBase = false;
{
	if (_pos distance _x < _baseRange) exitWith { _inBase = true };
} forEach _centers;

if !(_inBase) exitWith {
	[_reqPlayer, "LocalizeMessage", ["SiteClearanceOutsideBase"]] Call WFBE_CO_FNC_SendToClient;
	["DEBUG", Format ["Server_SiteClearance.sqf: [%1] pos %2 rejected — outside base area.", str _side, _pos]] Call WFBE_CO_FNC_LogContent;
};

// Gate 6: Per-side rate limit — one clearance per side per 15 s.
// Stored as server-local variable on the side logic object.
_lastClear = _logik getVariable ["wfbe_siteclear_last", -99];
if ((time - _lastClear) < 15) exitWith {
	["DEBUG", Format ["Server_SiteClearance.sqf: [%1] rate-limited (last clear %2 s ago).", str _side, round (time - _lastClear)]] Call WFBE_CO_FNC_LogContent;
};

// A2-safe substring matcher (string find is A3-only and throws on A2 OA).
// _this = [haystackLower (String), [needle1, needle2, ...]] -> Bool
_matchAny = {
	private ["_hayA","_needles","_found","_nA","_hl","_nl","_i","_j","_ok"];
	_hayA = toArray (_this select 0);
	_needles = _this select 1;
	_hl = count _hayA;
	_found = false;
	{
		if (!_found) then {
			_nA = toArray _x;
			_nl = count _nA;
			if (_nl > 0 && _nl <= _hl) then {
				for "_i" from 0 to (_hl - _nl) do {
					if (!_found) then {
						_ok = true;
						for "_j" from 0 to (_nl - 1) do {
							if ((_hayA select (_i + _j)) != (_nA select _j)) exitWith {_ok = false};
						};
						if (_ok) then {_found = true};
					};
				};
			};
		};
	} forEach _needles;
	_found
};

// Tree scan: nearestObjects within 25 m of placement position.
// Filter: getDammage < 1 AND str contains ": t_" (Chernarus tree prefix) or ": str_" (legacy).
// NOTE: string find is A3-only; use _matchAny (toArray sliding-window). Bushes (b_ prefix) excluded in v1.
_candidates = nearestObjects [_pos, [], 25];
_trees = [];
{
	_tree = _x;
	if (getDammage _tree < 1) then {
		_s = toLower (str _tree);
		if ([_s, [": t_", ": str_"]] call _matchAny) then {
			_trees = _trees + [_tree];
		};
	};
} forEach _candidates;

_N = count _trees;

// Gate 7: at least one tree.
if (_N == 0) exitWith {
	[_reqPlayer, "LocalizeMessage", ["SiteClearanceNoTrees"]] Call WFBE_CO_FNC_SendToClient;
	["DEBUG", Format ["Server_SiteClearance.sqf: [%1] no trees in 25 m of %2.", str _side, _pos]] Call WFBE_CO_FNC_LogContent;
};

// Gate 8: side supply >= cost (10 per tree).
_cost = _N * 10;
_currentSupply = _side Call GetSideSupply;
if (isNil "_currentSupply") then { _currentSupply = 0 };
if (_currentSupply < _cost) exitWith {
	[_reqPlayer, "LocalizeMessage", ["SiteClearanceNoSupply", _cost]] Call WFBE_CO_FNC_SendToClient;
	["WARNING", Format ["Server_SiteClearance.sqf: [%1] supply check failed — need %2, have %3.", str _side, _cost, _currentSupply]] Call WFBE_CO_FNC_LogContent;
};

// Stamp rate-limit timestamp BEFORE the fell loop so re-entrant calls while felling are blocked.
_logik setVariable ["wfbe_siteclear_last", time];

// Fell all trees.  CHARGE ORDERING: setDamage first, count actual fells, then charge.
{_x setDamage 1} forEach _trees;

// Count confirmed fells.
_felled = 0;
{if (getDammage _x >= 1) then {_felled = _felled + 1}} forEach _trees;

// Charge only for confirmed fells (benign if engine refuses: no cost for standing trees).
if (_felled > 0) then {
	[_side, -(_felled * 10), Format ["Site clearance by commander %1: %2 trees felled.", name _reqPlayer, _felled], false] Call ChangeSideSupply;
	["INFORMATION", Format ["Server_SiteClearance.sqf: [%1] %2/%3 trees felled at %4 by %5. Supply charged: %6.",
		str _side, _felled, _N, _pos, name _reqPlayer, _felled * 10]] Call WFBE_CO_FNC_LogContent;
};

// Side-wide feedback (commander action is team-visible by design).
[_side, "LocalizeMessage", ["SiteClearanceDone", _felled, _felled * 10]] Call WFBE_CO_FNC_SendToClients;
