/*
	Create a delegation request.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_groups", "_perfStart", "_positions", "_retVal", "_side", "_teams", "_town", "_town_vehicles"];

_town = _this select 0;
_side = _this select 1;
_groups = _this select 2;
_positions = _this select 3;
_teams = _this select 4;
// Marty: Performance Audit measures town AI creation delegated onto this client/HC.
_perfStart = diag_tickTime;

["INFORMATION", Format["Client_DelegateTownAI.sqf: Received a town delegation request from the server for [%1] [%2].", _side, _town]] Call WFBE_CO_FNC_LogContent;

sleep (random 1); //--- Delay a bit to prevent a bandwidth congestion.

// Marty: Delegated town AI should not start client marker/update scripts for every spawned unit.
_retVal = [_town, _side, _groups, _positions, _teams, false] call WFBE_CO_FNC_CreateTownUnits;
_town_vehicles = _retVal select 1;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["delegate_townai_client", diag_tickTime - _perfStart, Format["town:%1;side:%2;groups:%3;teams:%4;vehicles:%5", _town getVariable "name", _side, count _groups, count _teams, count _town_vehicles], "CLIENT"] Call PerformanceAudit_Record;
	};
};

if (count _town_vehicles > 0) then {["RequestSpecial", ["update-town-delegation", _town, _town_vehicles]] Call WFBE_CO_FNC_SendToServer}; //--- If there is any vehicles, we give them to the server.

{
	_x Spawn {
		Private ["_team"];
		_team = _this;
		
		while {count (units _team) > 0} do {sleep 1};
		deleteGroup _team;
	};
} forEach _teams; //--- Delete the group client-sided.
