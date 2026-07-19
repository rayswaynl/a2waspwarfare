/*
	Claim an EMPTY (AI-run) commander seat mid-round.
	 Parameters:
		- Side.
		- Claiming team (group of the requesting player).

	Mirrors the elected path (RequestNewCommander.sqf + Server_VoteForCommander.sqf):
	promotes the claimer to wfbe_commander and stands the AI commander down. Unlike the
	vote, this is the mid-round "TAKE COMMAND" path: the round-start vote window is a
	one-shot (wfbe_votetime stays <=0 for JIP joiners), so there is no re-vote. Guards keep
	a player from stealing a seat that is locked, occupied by a human, or not theirs.
*/

Private ["_side","_claimTeam","_logic","_currentCommander","_syncAicomState"];

_side = _this select 0;
_claimTeam = _this select 1;
_syncAicomState = (missionNamespace getVariable ["WFBE_C_AICOM_PUBLIC_STATE_SYNC", 0]) > 0;

_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;

//--- Guard: side logic must exist (A2 OA: GetSideLogic can return objNull).
if (isNull _logic) exitWith {};

//--- Guard: respect the AI commander lock (when >0 the AI always commands; no claim).
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) exitWith {};

//--- Guard: the seat must be EMPTY - never let a player steal an existing human commander.
_currentCommander = _logic getVariable ["wfbe_commander", objNull];
if (!isNull _currentCommander) exitWith {};

//--- Guard: the claiming team must be a real, player-led team on the requesting side.
if (isNull _claimTeam) exitWith {};
if (!isPlayer (leader _claimTeam)) exitWith {};
if (side _claimTeam != _side) exitWith {};

//--- Promote EXACTLY like the elected path (RequestNewCommander.sqf:12-13).
//--- Review-fix (codex reject 2026-07-19, P1-1): flag-on validates eligibility (adds the aicom-hc
//--- denial this path lacked) BEFORE publishing; ineligible claim = no seat change AND the AI
//--- commander keeps running (fail closed). Latch pattern per cmdcon44-g: no exitWith inside the
//--- then-block (it would fall through to the AI stand-down below and stop the AI on a DENIED
//--- claim). Flag-off: legacy unconditional publish, byte-identical.
Private ["_claimAccepted"];
_claimAccepted = true;
if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
	if ([_side, _claimTeam] Call WFBE_CO_FNC_CommanderLeaseEligible) then {
		_logic setVariable ["wfbe_commander", _claimTeam, true];
		[_side, _claimTeam, "claim"] Call WFBE_CO_FNC_GrantCommanderLease;
		[_side, _claimTeam] Spawn WFBE_SE_FNC_AssignForCommander;
	} else {
		_claimAccepted = false;
		["WARNING", Format ["RequestClaimCommander.sqf: [%1] DENIED ineligible seat claim (CIV/cross-side/HC/AI-led team %2) - seat unchanged, AI keeps command.", _side, _claimTeam]] Call WFBE_CO_FNC_LogContent;
	};
} else {
	_logic setVariable ["wfbe_commander", _claimTeam, true];
	[_side, _claimTeam] Spawn WFBE_SE_FNC_AssignForCommander;
};

//--- Stand the AI down the SAME way Server_VoteForCommander.sqf:60-61 does (only for an ACCEPTED claim).
if (_claimAccepted && {!(isNull _claimTeam)}) then {
	if (_logic getVariable "wfbe_aicom_running") then {_logic setVariable ["wfbe_aicom_running", false, _syncAicomState]};
};
