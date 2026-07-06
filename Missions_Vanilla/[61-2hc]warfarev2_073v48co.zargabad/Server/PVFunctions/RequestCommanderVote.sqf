Private["_secHardening","_commanderTeam","_logik","_name","_side","_team"];

_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;
if (_secHardening && {!((typeName _this) in ["ARRAY"])}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: malformed payload type [%1] - rejected.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((count _this) > 1)}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: short payload [%1] - rejected.", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_name = _this select 1;

if (_secHardening && {!(_side in [east, west, resistance])}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: invalid vote side [%1] - rejected.", _side]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((typeName _name) in ["STRING"])}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: invalid caller name [%1] - rejected.", _name]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

if ((_logik getVariable "wfbe_votetime") <= 0) then {
	_team = -1;
	_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;

	if (!isNull _commanderTeam) then {
		_team = (_logik getVariable "wfbe_teams") find _commanderTeam;
	};

	//--- Set the commander votes.
	[_side, _team] Call SetCommanderVotes;
	
	(_side) Spawn WFBE_SE_FNC_VoteForCommander;
	[_side,"VotingForNewCommander"] Spawn SideMessage;
	
	[_side, "HandleSpecial", ["commander-vote-start", _name]] Call WFBE_CO_FNC_SendToClients;
};
