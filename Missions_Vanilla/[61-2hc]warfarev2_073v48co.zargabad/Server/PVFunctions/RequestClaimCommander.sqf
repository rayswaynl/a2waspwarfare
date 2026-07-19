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
//--- Round-3 review (P1-1/P1-3): with the lease enabled the writer ONLY ENQUEUES a grant
//--- request - the single per-side executor is now the sole writer of wfbe_commander/lease
//--- state AND the sole caller of AssignForCommander (which stops the AI FSM), so a claim can
//--- never publish/stand-AI-down synchronously here; eligibility (incl. the aicom-hc denial
//--- this path used to lack) is re-validated at executor time. The round-2 accepted-claim
//--- latch is gone: the flag-on branch enqueues unconditionally and never touches
//--- wfbe_aicom_running itself, so there is no "stopped the AI on a denied claim" fallthrough
//--- to guard against. Flag-off: legacy unconditional publish + immediate AI stand-down,
//--- byte-identical to HEAD.
if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
	[_side, _claimTeam, "claim"] Call WFBE_CO_FNC_CommanderLeaseRequestGrant;
} else {
	_logic setVariable ["wfbe_commander", _claimTeam, true];
	[_side, _claimTeam] Spawn WFBE_SE_FNC_AssignForCommander;
	if (_logic getVariable "wfbe_aicom_running") then {_logic setVariable ["wfbe_aicom_running", false, _syncAicomState]};
};
