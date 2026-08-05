Private["_secHardening","_commanderTeam","_logik","_name","_reqPlayer","_side","_team"];

_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;
if (_secHardening && {!((typeName _this) in ["ARRAY"])}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: malformed payload type [%1] - rejected.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((count _this) > 1)}) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: short payload [%1] - rejected.", _this]] Call WFBE_CO_FNC_LogContent;
};

if !((typeName _this) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - expected array payload, got %1.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};

if ((count _this) < 2) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - expected [side,name], got %1 element(s).", count _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_name = _this select 1;

if !((typeName _side) in ["SIDE"]) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - side field type was %1.", typeName _side]] Call WFBE_CO_FNC_LogContent;
};

if !(_side in WFBE_PRESENTSIDES) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - side %1 is not present in this mission.", _side]] Call WFBE_CO_FNC_LogContent;
};

if !((typeName _name) in ["STRING"]) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - name field type was %1.", typeName _name]] Call WFBE_CO_FNC_LogContent;
};

//--- Caller authority bind (mirrors RequestMHQRepair.sqf / RequestSiteClearance.sqf): the client appends the
//--- acting player so the server re-derives the requester ACTUAL side and refuses a forged / cross-side payload.
//--- Without it any client could pass an ENEMY _side and force a fresh side-wide commander election on the other
//--- team whenever no vote is running (unauthenticated, cross-side, repeatable). Client-supplied identity is
//--- acceptable because the gate compares (side group _reqPlayer) against the claimed _side - a WEST client
//--- cannot forge a payload that passes for EAST.
if ((count _this) < 3) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected - missing acting player in payload %1.", _this]] Call WFBE_CO_FNC_LogContent;
};
_reqPlayer = _this select 2;
if !((typeName _reqPlayer) in ["OBJECT"]) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected requester type [%1].", typeName _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if (isNull _reqPlayer) exitWith {
	["WARNING", "RequestCommanderVote.sqf: rejected null requester."] Call WFBE_CO_FNC_LogContent;
};
if !(isPlayer _reqPlayer) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected non-player requester [%1].", _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if !((side group _reqPlayer) in [_side]) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected requester side mismatch [%1] for [%2].", side group _reqPlayer, _side]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	["WARNING", Format ["RequestCommanderVote.sqf: rejected malformed request - side logic for %1 is null.", _side]] Call WFBE_CO_FNC_LogContent;
};

if ((_logik getVariable "wfbe_votetime") <= 0) then {
	//--- Latch votetime IMMEDIATELY (before any Spawn) so a second concurrent
	//--- RequestCommanderVote on the same side cannot also pass votetime<=0 and
	//--- double-spawn WFBE_SE_FNC_VoteForCommander. VoteForCommander rewrites the
	//--- countdown on its first loop tick; this only closes the TOCTOU window.
	_logik setVariable ["wfbe_votetime", (missionNamespace getVariable "WFBE_C_GAMEPLAY_VOTE_TIME"), true];

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
