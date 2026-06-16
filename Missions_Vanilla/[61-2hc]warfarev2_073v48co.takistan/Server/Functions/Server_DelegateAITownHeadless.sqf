/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_hcUnit", "_delegated", "_groups", "_perfStart", "_positions", "_side", "_teams", "_town"];

_town = _this select 0;
_side = _this select 1;
_groups = +(_this select 2);
_positions = +(_this select 3);
_teams = +(_this select 4);
// Marty: Performance Audit counts town AI groups handed to headless clients.
_perfStart = diag_tickTime;
_delegated = 0;

//--- Delegate The groups to the headless clients. Each group is delegated INDEPENDENTLY to
//--- the currently LEAST-LOADED live HC (re-evaluated per group via the shared picker), so a
//--- multi-group town activation alternates HCs as units land instead of dumping the whole
//--- town on one HC. Each delegated group carries its own [group] payload (the HC builds it
//--- as its own local group), so locality / owner(leader) routing stays correct.
for '_i' from 0 to count(_groups) -1 do {
	//--- Picker returns the leader of the lightest live HC, or objNull if none are live
	//--- (a stale registry entry would otherwise route to a dead leader and the AI would
	//--- silently never spawn).
	_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

	if (!isNull _hcUnit) then {
		[_hcUnit, "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClient;
		_delegated = _delegated + 1;
	} else {
		["WARNING", Format["Server_DelegateAITownHeadless.sqf: No live headless client for town [%1] group %2 - delegation dropped.", _town getVariable "name", _i]] Call WFBE_CO_FNC_LogContent;
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["delegate_townai_headless", diag_tickTime - _perfStart, Format["town:%1;side:%2;groups:%3;delegated:%4;headless:%5", _town getVariable "name", _side, count _groups, _delegated, count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []])], "SERVER"] Call PerformanceAudit_Record;
	};
};
