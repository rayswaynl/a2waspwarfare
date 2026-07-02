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

Private ["_hcUnit", "_groups", "_positions", "_side", "_teams", "_live", "_seedIdx", "_rr", "_hcCount"];

_side = _this select 0;
_groups = +(_this select 1);
_positions = +(_this select 2);
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;

//--- HC PICK HOIST (mirrors Server_DelegateAITownHeadless.sqf): the least-loaded picker does an
//--- O(allUnits) scan. Calling it once PER GROUP made the cost O(groups x allUnits). Instead we
//--- run the expensive scan ONCE here to choose the lightest live HC, then distribute this batch's
//--- groups across all live HCs with a cheap LOCAL round-robin starting from that lightest HC.
//--- Same groups delegated, same SendToClient payload, same routing; the per-group re-pick is eliminated.
_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

//--- Build the live-HC leader list locally (cheap: no allUnits scan; same liveness test the picker uses).
_live = [];
{
	if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [leader _x]};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_hcCount = count _live;
//--- Seed the round-robin at the picker's chosen (lightest) HC.
_seedIdx = _live find _hcUnit;
if (_seedIdx < 0) then {_seedIdx = 0};
_rr = 0;

for '_i' from 0 to count(_groups) -1 do {
	if (_hcCount == 0) then {
		["WARNING", Format["Server_DelegateAIStaticDefenceHeadless.sqf: No live headless client for static-defence group %1 - delegation dropped.", _i]] Call WFBE_CO_FNC_LogContent;
	} else {
		_hcUnit = _live select ((_seedIdx + _rr) mod _hcCount);
		_rr = _rr + 1;
		[_hcUnit, "HandleSpecial", ['delegate-ai-static-defence', _side, [_groups select _i], [_positions select _i], _team, _defence, _moveInGunner]] Call WFBE_CO_FNC_SendToClient;
	};
};