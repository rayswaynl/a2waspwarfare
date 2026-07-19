/*
	Trigger a commander's vote.
	 Parameters:
		- Side.
*/

Private ["_logic", "_side", "_syncAicomState", "_voteTime"];

_side = _this;
_voteTime = (missionNamespace getVariable 'WFBE_C_GAMEPLAY_VOTE_TIME');
_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
_syncAicomState = (missionNamespace getVariable ["WFBE_C_AICOM_PUBLIC_STATE_SYNC", 0]) > 0;

//--- Vote countdown.
while {_voteTime > -1} do {_voteTime = _voteTime - 1;_logic setVariable ["wfbe_votetime", _voteTime, true];sleep 1};

//--- Get the most voted person.
Private ["_aiVotes","_count","_highest","_highestTeam","_tie","_teams","_vote","_votes"];
_aiVotes = 0;
_votes = [];
_teams = _logic getVariable "wfbe_teams";

//--- Get the votes from everyone.
for '_i' from 0 to (count _teams)-1 do {[_votes, 0] Call WFBE_CO_FNC_ArrayPush};
{
	if (isPlayer leader _x) then {
		_vote = _x getVariable "wfbe_vote";
		if (_vote == -1) then {_aiVotes = _aiVotes + 1} else {_votes set [_vote, (_votes select _vote) + 1]};
	};
} forEach _teams;

//--- Who was the most voted for?
_count = 0;_highest = 0;_highestTeam = -1;
_tie = false;
{
	if (_x == _highest && _x > 0) then {_tie = true};
	if (_x > _highest) then {_highestTeam = _count;_highest = _x;_tie = false};
	_count = _count + 1;
} forEach _votes;

_commander = objNull;

//--- Attempt to get a playable team.
if (!_tie && _highest >= _aiVotes && _highestTeam != -1) then {_commander = _teams select _highestTeam}; //--- player team wins only if its top votes >= AI/abstain votes (was a tautology: `>= || <=` is always true)

//--- Player voted for an ai...?
if !(isNull _commander) then {if !(isPlayer leader _commander) then {_commander = objNull}};

//--- AI COMMANDER LOCK: when lock=1 votes always resolve to AI (objNull) regardless of result.
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {
	_commander = objNull;
};

//--- Finally set the commander, null = ai, team = player.
//--- Review-fix (codex reject 2026-07-19, P1-1): with the lease enabled, an INELIGIBLE vote winner
//--- (CIV/cross-side/HC/AI-led - structurally rare here since :47 already forces a player-led own
//--- team, but fail closed uniformly) degrades to the AI commander (objNull) BEFORE publishing,
//--- so the seat can never be published to a team the lease would refuse. Flag-off: byte-identical.
if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
	if (!isNull _commander && {!([_side, _commander] Call WFBE_CO_FNC_CommanderLeaseEligible)}) then {
		["WARNING", Format ["Server_VoteForCommander.sqf: [%1] vote winner %2 ineligible under lease rules - degrading to AI commander.", _side, _commander]] Call WFBE_CO_FNC_LogContent;
		_commander = objNull;
	};
};
_logic setVariable ["wfbe_commander", _commander, true];

if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
	if (isNull _commander) then {[_side] Call WFBE_CO_FNC_InvalidateCommanderLease} else {[_side, _commander, "vote"] Call WFBE_CO_FNC_GrantCommanderLease};
};

//--- Notify the clients.
[_side, "HandleSpecial", ["commander-vote", _commander]] Call WFBE_CO_FNC_SendToClients;

//--- Process the AI Commander FSM if it's not running.
if !(isNull _commander) then {
	if (_logic getVariable "wfbe_aicom_running") then {_logic setVariable ["wfbe_aicom_running", false, _syncAicomState]};
};
