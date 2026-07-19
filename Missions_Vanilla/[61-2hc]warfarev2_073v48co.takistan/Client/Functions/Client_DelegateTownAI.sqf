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

//--- fable/hc-deleg-throttle (owner rig-test 2026-07-09): cap CONCURRENT unit-creation batches per HC.
//--- Root cause of "AI freezes soon after match start": ~12 towns activate near-simultaneously at start,
//--- each fanning 2-8 delegate-townai messages onto 2 HCs; each spawns a heavy CreateTownUnits batch
//--- (createUnit/setSkill/addWeapon per unit). Dozens running at once starve the HC's SQF scheduler and it
//--- freezes its whole owned AI population. The old `sleep (random 1)` only jittered START time, it did NOT
//--- cap concurrency. Acquire an in-flight slot (max 3 concurrent batches/HC, ~10s safety timeout) before the
//--- heavy body; released at end-of-file. Counter is per-HC (missionNamespace is machine-local).
private "_qWait"; _qWait = 0;
while {((missionNamespace getVariable ["WFBE_HC_DELEG_INFLIGHT", 0]) >= 3) && {_qWait < 100}} do {sleep 0.1; _qWait = _qWait + 1};
missionNamespace setVariable ["WFBE_HC_DELEG_INFLIGHT", ((missionNamespace getVariable ["WFBE_HC_DELEG_INFLIGHT", 0]) + 1)];

for "_i" from 0 to ((count _teams) - 1) do {
	_team = _teams select _i;
	if (isNull _team || {(count units _team) == 0}) then {_team = [_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup};
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
		Private ["_team","_remaining"];
		_team = _this;
		
		if (isNull _team) exitWith {};
		private "_wDeadline"; _wDeadline = time + 600; //--- wiki-wins: cap the watcher (was unbounded; a zombified/never-emptied group leaked this spawned thread for the rest of the mission)
			while {count (units _team) > 0 && time < _wDeadline} do {sleep 1};
		if (!isNull _team) then {
			_remaining = +units _team;
			{["hc-townai-watch-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x} forEach _remaining;
			deleteGroup _team;
		};
	};
} forEach _town_teams; //--- Delete the group client-sided once it naturally becomes empty.

//--- fable/hc-deleg-throttle: release the in-flight slot now this heavy creation batch has been dispatched.
missionNamespace setVariable ["WFBE_HC_DELEG_INFLIGHT", (((missionNamespace getVariable ["WFBE_HC_DELEG_INFLIGHT", 0]) - 1) max 0)];
