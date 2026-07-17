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

Private ["_hcUnit", "_groups", "_positions", "_side", "_team", "_defence", "_moveInGunner", "_live", "_x", "_seedIdx", "_rr", "_hcCount", "_delegated"];

_side = _this select 0;
_groups = +(_this select 1);
_positions = +(_this select 2);
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;

//--- HC PICK HOIST (mirrors the shipped Server_DelegateAITownHeadless.sqf fix): the least-loaded
//--- picker does an O(allUnits) scan. Calling it once PER GROUP made the cost O(groups x allUnits)
//--- - the same class as the measured 614ms town-activation spike the town-AI sibling already fixed.
//--- Run the expensive scan ONCE to choose the lightest live HC, then distribute this defence's
//--- groups across all live HCs with a cheap LOCAL round-robin anchored at that lightest HC. Same
//--- groups delegated, same SendToClient payload/format, same live-HC filter, same no-live-HC skip.
_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

//--- Build the live-HC leader list locally (cheap: no allUnits scan; same liveness test the picker uses).
_live = [];
{
	if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [leader _x]};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_hcCount = count _live;
//--- Seed the round-robin at the picker's chosen (lightest) HC; fall back to index 0 if it isn't listed.
_seedIdx = _live find _hcUnit;
if (_seedIdx < 0) then {_seedIdx = 0};
_rr = 0;

_delegated = 0;
for '_i' from 0 to count(_groups) -1 do {
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