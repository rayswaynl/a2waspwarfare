/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_hcUnit", "_delegated", "_groups", "_perfStart", "_positions", "_side", "_teams", "_town", "_live", "_x", "_seedIdx", "_rr", "_hcCount"];

_town = _this select 0;
_side = _this select 1;
_groups = +(_this select 2);
_positions = +(_this select 3);
_teams = +(_this select 4);
// Marty: Performance Audit counts town AI groups handed to headless clients.
_perfStart = diag_tickTime;
_delegated = 0;

//--- HC PICK HOIST: the least-loaded picker does an O(allUnits) scan. Calling it once PER GROUP
//--- made the cost O(groups x allUnits) - the measured 614ms town-activation spike. Instead we
//--- run the expensive scan ONCE here to choose the lightest live HC, then distribute this town's
//--- groups across all live HCs with a cheap LOCAL round-robin starting from that lightest HC.
//--- Groups STILL spread across both HCs (same anti-pile-up goal), but allUnits is walked once,
//--- not once per group. Same groups delegated, same SendToClient payload/format, same routing
//--- (owner(leader) per Common_SendToClient), and the same no-live-HC drop/log fallback.
_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

//--- Build the live-HC leader list locally (cheap: no allUnits scan, same liveness test the
//--- picker uses). The picker already told us the LIGHTEST leader; we round-robin starting from
//--- it so the heaviest distribution stays anchored on the lightest HC, exactly as before.
_live = [];
{
	//--- BUGFIX (2026-07-17, HC-founding zombie-picker): keep this liveness test identical to
	//--- Server_PickLeastLoadedHC.sqf's (owner<=0 = disconnected/locality-transferred zombie,
	//--- never a routable Common_SendToClient target) - this comment block already claimed "same
	//--- liveness test the picker uses"; it previously was not.
	if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 0}) then {_live = _live + [leader _x]};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_hcCount = count _live;
//--- Seed the round-robin at the picker's chosen (lightest) HC. If for any reason it isn't in
//--- the freshly-built list, fall back to index 0 (still a live HC).
_seedIdx = _live find _hcUnit;
if (_seedIdx < 0) then {_seedIdx = 0};
_rr = 0;

for '_i' from 0 to count(_groups) -1 do {
	//--- No live HC at all: preserve the exact original drop/log behaviour per group.
	if (_hcCount == 0) then {
		["WARNING", Format["Server_DelegateAITownHeadless.sqf: No live headless client for town [%1] group %2 - delegation dropped.", _town getVariable "name", _i]] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- Cheap local round-robin across the live HCs, anchored at the lightest one.
		_hcUnit = _live select ((_seedIdx + _rr) mod _hcCount);
		_rr = _rr + 1;
		[_hcUnit, "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClient;
		_delegated = _delegated + 1;
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["delegate_townai_headless", diag_tickTime - _perfStart, Format["town:%1;side:%2;groups:%3;delegated:%4;headless:%5", _town getVariable "name", _side, count _groups, _delegated, count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []])], "SERVER"] Call PerformanceAudit_Record;
	};
};
