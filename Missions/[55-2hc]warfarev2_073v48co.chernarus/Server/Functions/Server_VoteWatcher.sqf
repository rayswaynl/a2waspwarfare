scriptName "Server\Functions\Server_VoteWatcher.sqf";

/*
	Spawned when a new vote is opened.
	Polls until the window closes, then tallies the result.
	Server broadcasts WFBE_SERVER_TIME each tick so clients can compute countdowns.

	Parameters: [voteType, side, endTime, needed]
*/

Private ["_voteType","_side","_endTime","_needed","_yesCount","_voters",
         "_cooldownSec","_cooldowns","_i","_found","_state"];

_voteType    = _this select 0;
_side        = _this select 1;
_endTime     = _this select 2;
_needed      = _this select 3;
_cooldownSec = missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300];

//--- Broadcast server time every 2 s so clients can compute countdown.
while {time < _endTime} do {
	_state = missionNamespace getVariable ["WFBE_VOTE_STATE", []];

	//--- State was already cleared by an early pass — exit.
	if (count _state == 0) exitWith {};

	//--- State type changed (shouldn't happen, but guard).
	if ((count _state >= 1) && {(_state select 0) != _voteType}) exitWith {};

	WFBE_SERVER_TIME = time;
	publicVariable "WFBE_SERVER_TIME";

	sleep 2;
};

//--- Re-check after loop — early pass may have already cleared state.
_state = missionNamespace getVariable ["WFBE_VOTE_STATE", []];
if (count _state == 0) exitWith {};
if ((count _state >= 1) && {(_state select 0) != _voteType}) exitWith {};

//--- Window expired — tally.
_voters   = missionNamespace getVariable ["WFBE_VOTE_VOTERS", []];
_yesCount = count _voters;

if (_yesCount >= _needed) then {
	//--- Passed at window close.
	[_voteType, _side] Spawn WFBE_SE_FNC_VotePassed;
} else {
	//--- Failed — record cooldown on this type, clear state, announce.
	_cooldowns = missionNamespace getVariable ["WFBE_VOTE_COOLDOWNS", []];

	_found = false;
	_i = 0;
	while {_i < count _cooldowns} do {
		if ((_cooldowns select _i select 0) == _voteType) then {
			_cooldowns set [_i, [_voteType, time + _cooldownSec]];
			_found = true;
		};
		_i = _i + 1;
	};
	if (!_found) then {
		_cooldowns = _cooldowns + [[_voteType, time + _cooldownSec]];
	};

	WFBE_VOTE_COOLDOWNS = _cooldowns;
	WFBE_VOTE_STATE     = [];
	WFBE_VOTE_VOTERS    = [];
	publicVariable "WFBE_VOTE_COOLDOWNS";
	publicVariable "WFBE_VOTE_STATE";
	publicVariable "WFBE_VOTE_VOTERS";

	[nil, "LocalizeMessage", ["VoteFailed", Localize (Format ["STR_WF_VOTE_OPT_%1", _voteType])]] Call WFBE_CO_FNC_SendToClients;
};
