/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_clients", "_delegated", "_groups", "_perfStart", "_positions", "_side", "_teams", "_town"];

_town = _this select 0;
_side = _this select 1;
_groups = +(_this select 2);
_positions = +(_this select 3);
_teams = +(_this select 4);
// Marty: Performance Audit counts town AI groups handed to headless clients.
_perfStart = diag_tickTime;
_delegated = 0;

//--- Delegate The groups to the miscelleanous headless clients.
for '_i' from 0 to count(_groups) -1 do {
	_clients = missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID";

	if (count _clients > 0) then {
		[leader(_clients select floor(random count _clients)), "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClient;
		_delegated = _delegated + 1;
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["delegate_townai_headless", diag_tickTime - _perfStart, Format["town:%1;side:%2;groups:%3;delegated:%4;headless:%5", _town getVariable "name", _side, count _groups, _delegated, count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []])], "SERVER"] Call PerformanceAudit_Record;
	};
};
