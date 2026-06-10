/*
	AI Commander - found new AI combat teams up to the side's target.
	feat/ai-commander V0.2. Server-side worker, full-command mode only.
	Parameter: _this = side.

	wfbe_teams is otherwise fixed at init from the editor's playable slots; an
	AI-only side may start with zero (or only player-claimed) teams, leaving the
	Produce worker nothing to feed. We found fresh empty groups with the same
	variable set Init_Server gives editor teams - AssignTypes then templates them
	and Produce builds their members at the factories (AIBuyUnit handles empty
	teams). One team founded per call.
*/

private ["_side","_sideText","_logik","_teams","_target","_aiTeams","_g"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") then {_teams = []};

//--- Count live-able AI-led teams (no player leader). Dead-empty founded teams are reused by Produce.
_aiTeams = 0;
{
	if (!isNull _x) then {
		if (!isPlayer (leader _x)) then {_aiTeams = _aiTeams + 1};
	};
} forEach _teams;

_target = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_TARGET", 4];
if (_aiTeams >= _target) exitWith {};

//--- Found one team with the canonical Init_Server variable set.
_g = createGroup _side;
if (isNull _g) exitWith {
	["WARNING", Format ["AI_Commander_Teams.sqf: [%1] createGroup returned grpNull (group limit?).", _sideText]] Call WFBE_CO_FNC_LogContent;
};
_g setVariable ["wfbe_funds", 0, true];
_g setVariable ["wfbe_side", _side];
_g setVariable ["wfbe_persistent", true];
_g setVariable ["wfbe_queue", []];
_g setVariable ["wfbe_vote", -1, true];
[_g, false] Call SetTeamAutonomous;
[_g, ""] Call SetTeamRespawn;
[_g, -1] Call SetTeamType;
[_g, "towns"] Call SetTeamMoveMode;
[_g, [0,0,0]] Call SetTeamMovePos;

_logik setVariable ["wfbe_teams", _teams + [_g], true];

["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] founded AI team %2/%3 [%4].", _sideText, _aiTeams + 1, _target, _g]] Call WFBE_CO_FNC_LogContent;
