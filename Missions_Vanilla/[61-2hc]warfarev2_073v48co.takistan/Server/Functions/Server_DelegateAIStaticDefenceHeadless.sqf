/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Side
		- Groups
		- Spawn positions
		- Teams
		- Defence
		- Move In Gunner immidietly or not
*/

Private ["_hcUnit", "_groups", "_positions", "_side", "_team", "_defence", "_moveInGunner", "_live", "_x", "_seedIdx", "_rr", "_hcCount", "_delegated", "_fpsReg", "_hcKey", "_fidx", "_slot", "_fresh"];

//--- r80 fail-clean: short/malformed args or non-array groups/positions must not OOB select.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 6}) exitWith {
	["WARNING", "Server_DelegateAIStaticDefenceHeadless.sqf: short/malformed args - static HC delegation aborted."] Call WFBE_CO_FNC_LogContent;
	0
};

_side = _this select 0;
_groups = +(_this select 1);
_positions = +(_this select 2);
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;

if (isNil "_groups" || {typeName _groups != "ARRAY"} || {isNil "_positions"} || {typeName _positions != "ARRAY"}) exitWith {
	["WARNING", Format["Server_DelegateAIStaticDefenceHeadless.sqf: [%1] groups/positions not arrays - delegation aborted.", _side]] Call WFBE_CO_FNC_LogContent;
	0
};

//--- HC PICK HOIST (mirrors the shipped Server_DelegateAITownHeadless.sqf fix): the least-loaded
//--- picker does an O(allUnits) scan. Calling it once PER GROUP made the cost O(groups x allUnits)
//--- - the same class as the measured 614ms town-activation spike the town-AI sibling already fixed.
//--- Run the expensive scan ONCE to choose the lightest live HC, then distribute this defence's
//--- groups across all live HCs with a cheap LOCAL round-robin anchored at that lightest HC. Same
//--- groups delegated, same SendToClient payload/format, same live-HC filter, same no-live-HC skip.
_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

//--- Build the live-HC leader list locally (cheap: no allUnits scan; same liveness and HCSTAT
//--- freshness test the picker uses). A retained owner-positive group without a fresh heartbeat is
//--- not a routable endpoint; including it here would count a dropped dispatch and delay the caller's
//--- server fallback even though Server_PickLeastLoadedHC returned objNull.
_fpsReg = missionNamespace getVariable ["WFBE_HCFPS_REG", []];
_live = [];
{
	_fresh = false;
	if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 0}) then {
		_hcKey = Format ["HC-%1", netId (leader _x)];
		_fidx = -1;
		{ if ((_x select 0) == _hcKey) exitWith {_fidx = _forEachIndex} } forEach _fpsReg;
		if (_fidx >= 0) then {
			_slot = _fpsReg select _fidx;
			if ((time - (_slot select 2)) <= 150) then {_fresh = true};
		};
	};
	if (_fresh) then {_live = _live + [leader _x]};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_hcCount = count _live;
//--- Seed the round-robin at the picker's chosen (lightest) HC; fall back to index 0 if it isn't listed.
_seedIdx = _live find _hcUnit;
if (_seedIdx < 0) then {_seedIdx = 0};
_rr = 0;

_delegated = 0;
//--- r80: never select positions OOB (shorter positions array used to throw and abort remaining AA seats).
private ["_pairCount"];
_pairCount = (count _groups) min (count _positions);
if (_pairCount < (count _groups)) then {
	["WARNING", Format["Server_DelegateAIStaticDefenceHeadless.sqf: [%1] groups/positions mismatch (g=%2 p=%3) - clamping.", _side, count _groups, count _positions]] Call WFBE_CO_FNC_LogContent;
};
for '_i' from 0 to (_pairCount - 1) do {
	if (_hcCount > 0) then {
		//--- Cheap local round-robin across the live HCs, anchored at the lightest one (no per-group scan).
		_hcUnit = _live select ((_seedIdx + _rr) mod _hcCount);
		_rr = _rr + 1;
		[_hcUnit, "HandleSpecial", ['delegate-ai-static-defence', _side, [_groups select _i], [_positions select _i], _team, _defence, _moveInGunner]] Call WFBE_CO_FNC_SendToClient;
		_delegated = _delegated + 1;
	} else {
		//--- Silent-drop fix: this skip was wordless (the town sibling Server_DelegateAITownHeadless.sqf
		//--- logs its drop). The caller's live-HC check can go stale before our own rebuild above.
		["WARNING", Format["Server_DelegateAIStaticDefenceHeadless.sqf: No live headless client for [%1] static-defence group %2 - delegation dropped.", _side, _i]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Return the dispatched count so callers can fall back server-side instead of losing the gunner.
_delegated