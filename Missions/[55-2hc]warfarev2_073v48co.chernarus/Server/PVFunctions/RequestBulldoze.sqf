/*
	RequestBulldoze.sqf — Server-side validation and execution for engineer bulldozer.

	ENGINE NOTE (deferred): whether setDamage 1 actually fells A2 terrain trees, and whether
	fallen trunks sync to JIP, is DEFERRED to the integration smoke test.  Charge ordering
	guarantees benign worst-case: supply is only deducted AFTER confirming getDammage >= 1
	post-fell.  If the engine refuses (unknown object type) the tree silently stays standing
	and the team pays nothing.

	ANTI-GRIEF rationale: engineer-only + friendly-base-only + 10 supply/tree + 1.5 s
	rate-limit reduces griefing potential.  A determined troll could still burn ~400 S/min;
	a per-player session cap of 100 trees (wfbe_dozer_count on the player object) provides
	a hard ceiling and a polite stop message.  Acceptable for the experimental test branch.

	Parameters (from WFBE_SE_FNC_HandlePVF dispatch, mirrors RequestDefense pattern):
		_this select 0 : tree object
		_this select 1 : vehicle object
		_this select 2 : requesting player
*/

private ["_tree","_veh","_reqPlayer","_side","_logik","_startPos","_baseAreas","_centers",
         "_baseRange","_inBase","_currentSupply","_lastFell","_playerCount","_felled",
         "_upgrades","_barrackLvl"];

_tree      = _this select 0;
_veh       = _this select 1;
_reqPlayer = _this select 2;

// Gate 1: feature enabled.
if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) == 0) exitWith {
	["WARNING", "RequestBulldoze.sqf: Rejected — WFBE_C_UNITS_BULLDOZER gate is off."] Call WFBE_CO_FNC_LogContent;
};

// Gate 2: tree is a valid, still-standing object.
if (isNull _tree || {getDammage _tree >= 1}) exitWith {};

// Gate 3: vehicle and player alive.
if (isNull _veh || {isNull _reqPlayer} || {!(alive _reqPlayer)}) exitWith {};

// Determine requesting side from the player.
_side = side group _reqPlayer;

// Gate 4: Barracks level >= 1 (balance gate — prevents early-game supply drain).
// Pattern mirrors Server_CounterBattery.sqf's WFBE_UP_CBRADAR check:
//   side logic → wfbe_upgrades array → select WFBE_UP_BARRACKS (= index 0).
_logik = _side Call WFBE_CO_FNC_GetSideLogic;
_upgrades = _logik getVariable ["wfbe_upgrades", []];
_barrackLvl = 0;
if (count _upgrades > WFBE_UP_BARRACKS) then { _barrackLvl = _upgrades select WFBE_UP_BARRACKS };
if (_barrackLvl < 1) exitWith {
	[_reqPlayer, "LocalizeMessage", ["BulldozerNeedsBarracks1"]] Call WFBE_CO_FNC_SendToClient;
	["DEBUG", Format ["RequestBulldoze.sqf: [%1] bulldoze rejected — Barracks level %2 < 1.", str _side, _barrackLvl]] Call WFBE_CO_FNC_LogContent;
};

// Gate 5: server-side base-area check — tree must be inside a friendly base area.
// Mirrors the bank-placement check in RequestStructure.sqf:
//   logik → wfbe_startpos + wfbe_basearea[] + WFBE_C_BASE_AREA_RANGE 250 m
// (_logik already fetched above for the barracks check)
_startPos  = _logik getVariable ["wfbe_startpos", objNull];
_baseAreas = _logik getVariable ["wfbe_basearea", []];
_baseRange = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 250];

_centers = [];
if !(isNull _startPos) then { _centers = _centers + [getPos _startPos] };
{_centers = _centers + [getPos _x]} forEach _baseAreas;

_inBase = false;
{
	if ((getPos _tree) distance _x < _baseRange) exitWith { _inBase = true };
} forEach _centers;

if !(_inBase) exitWith {
	["DEBUG", Format ["RequestBulldoze.sqf: [%1] tree at %2 rejected — outside base area.", str _side, getPos _tree]] Call WFBE_CO_FNC_LogContent;
};

// Gate 6: sufficient supply (>= 10).
// GetSideSupply / ChangeSideSupply are compiled in Common\Init\Init_Common.sqf and available
// server-side.  Pattern mirrors upgradeQueue.sqf and Server_AI_Com_Upgrade.sqf.
_currentSupply = _side Call GetSideSupply;
if (isNil "_currentSupply") then { _currentSupply = 0 };
if (_currentSupply < 10) exitWith {
	["WARNING", Format ["RequestBulldoze.sqf: [%1] tree fell rejected — insufficient supply (%2 < 10).", str _side, _currentSupply]] Call WFBE_CO_FNC_LogContent;
};

// Rate limit: minimum 1.5 s between fells per vehicle.
_lastFell = _veh getVariable ["wfbe_dozer_last", -99];
if ((time - _lastFell) < 1.5) exitWith {};

// Per-player session cap: 100 trees maximum (anti-grief).
_playerCount = _reqPlayer getVariable ["wfbe_dozer_count", 0];
if (_playerCount >= 100) exitWith {
	// Only message once at exactly 100 so it doesn't spam after.
	if (_playerCount == 100) then {
		_reqPlayer setVariable ["wfbe_dozer_count", 101];
		// Use SendToClient (UID-targeted) not SendToClients: only the capped player sees this notice.
		[_reqPlayer, "LocalizeMessage", ["BulldozerSessionCapReached"]] Call WFBE_CO_FNC_SendToClient;
		["WARNING", Format ["RequestBulldoze.sqf: [%1] session cap reached (100 trees) — bulldozer halted for this player.", name _reqPlayer]] Call WFBE_CO_FNC_LogContent;
	};
};

// --- Execute fell ---
// CHARGE ORDERING: setDamage first, verify, then deduct.
_tree setDamage 1;

_felled = (getDammage _tree >= 1);

if (_felled) then {
	// Update rate-limit timestamp.
	_veh setVariable ["wfbe_dozer_last", time];

	// Increment per-player session counter.
	_reqPlayer setVariable ["wfbe_dozer_count", (_playerCount + 1)];

	// Deduct 10 supply.
	// Signature: [side, amount, reason, includeStagnation] Call ChangeSideSupply
	// Negative amount = deduction.  Mirrors Action_RepairMHQ.sqf / repair.sqf.
	[_side, -10, Format ["Engineer bulldozer: tree cleared by %1.", name _reqPlayer], false] Call ChangeSideSupply;

	["INFORMATION", Format ["RequestBulldoze.sqf: [%1] tree at %2 felled by %3. Supply deducted: 10. Session count: %4.",
		str _side, getPos _tree, name _reqPlayer, _playerCount + 1]] Call WFBE_CO_FNC_LogContent;

	// Notify the requesting client (chat line + running cost).
	// The client PVF "BulldozeFelled" handles the local hint/chat.
	[_reqPlayer, "BulldozeFelled", [_playerCount + 1]] Call WFBE_CO_FNC_SendToClient;
} else {
	["DEBUG", Format ["RequestBulldoze.sqf: setDamage call on tree at %1 had no effect — engine may not support it. No supply charged.", getPos _tree]] Call WFBE_CO_FNC_LogContent;
};
