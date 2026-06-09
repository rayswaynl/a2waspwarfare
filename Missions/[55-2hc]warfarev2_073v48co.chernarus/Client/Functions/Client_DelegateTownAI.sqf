/*
	Create a delegation request.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_groups", "_i", "_perfStart", "_positions", "_registry", "_retVal", "_side", "_team", "_teams", "_town", "_town_teams", "_town_vehicles"];

_town = _this select 0;
_side = _this select 1;
_groups = _this select 2;
_positions = _this select 3;
_teams = _this select 4;

["INFORMATION", Format["Client_DelegateTownAI.sqf: Received a town delegation request from the server for [%1] [%2].", _side, _town]] Call WFBE_CO_FNC_LogContent;

sleep (random 1); //--- Delay a bit to prevent a bandwidth congestion.

for "_i" from 0 to ((count _teams) - 1) do {
	_team = _teams select _i;
	if (isNull _team || {(count units _team) == 0}) then {_team = createGroup _side};
	_teams set [_i, _team];
};

_retVal = [_town, _side, _groups, _positions, _teams] call WFBE_CO_FNC_CreateTownUnits;
// Marty: Register the actual local groups created by the HC/client so cleanup runs where deleteGroup is effective.
_town_teams = _retVal select 0;
_town_vehicles = _retVal select 1;
_registry = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []];
{
	_team = _x;
	if !(isNull _team) then {
		_registry set [count _registry, [_town, _side, _team]];
	};
} forEach _town_teams;
missionNamespace setVariable ["WFBE_CL_TownAI_Groups", _registry];
["INFORMATION", Format ["TOWN_AI_HC_CLEANUP registered town:%1 side:%2 groups:%3 vehicles:%4 registry:%5", _town getVariable "name", _side, count _town_teams, count _town_vehicles, count _registry]] Call WFBE_CO_FNC_LogContent;

// Marty: Send both local groups and vehicles back so the server can track delegated town assets.
if ((count _town_teams) > 0 || (count _town_vehicles) > 0) then {["RequestSpecial", ["update-town-delegation", _town, _town_teams, _town_vehicles]] Call WFBE_CO_FNC_SendToServer};

{
	_x Spawn {
		Private ["_team"];
		_team = _this;
		
		if (isNull _team) exitWith {};
		while {count (units _team) > 0} do {sleep 1};
		deleteGroup _team;
	};
} forEach _town_teams; //--- Delete the group client-sided once it naturally becomes empty.
