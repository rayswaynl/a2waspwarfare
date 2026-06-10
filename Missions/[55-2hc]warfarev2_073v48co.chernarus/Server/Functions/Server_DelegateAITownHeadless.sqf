/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_clients", "_clientsLive", "_delegated", "_groups", "_perfStart", "_positions", "_side", "_teams", "_town"];

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

	//--- Only LIVE HC groups: a stale registry entry (HC dropped between prunes) would send
	//--- the delegation to a null leader and the town AI would silently never spawn.
	_clientsLive = [];
	{
		if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_clientsLive = _clientsLive + [_x]};
	} forEach _clients;

	if (count _clientsLive > 0) then {
		[leader(_clientsLive select floor(random count _clientsLive)), "HandleSpecial", ['delegate-townai', _town, _side, [_groups select _i], [_positions select _i], [_teams select _i]]] Call WFBE_CO_FNC_SendToClient;
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
