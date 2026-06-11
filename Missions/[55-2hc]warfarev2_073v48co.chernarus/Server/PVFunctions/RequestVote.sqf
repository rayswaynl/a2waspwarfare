scriptName "Server\PVFunctions\RequestVote.sqf";

/*
	Server-side vote handler.
	Called via ["RequestVote", [sideJoined, playerName, voteType]] Call WFBE_CO_FNC_SendToServer.

	Behaviour:
	  - If no vote of this type is active: start one (if cooldown clear and eligible count >= 1).
	  - If a vote of this type IS active: record the player's YES (no double-counting).
	  - On pass threshold: execute immediately and clear state.
	  - On window timeout: check pass; if fail record cooldown and clear state.

	Shared public vars (updated on every change, polled by client dialog):
	  WFBE_VOTE_STATE     = [] or [type, yes, needed, serverEndTime, side]
	  WFBE_VOTE_VOTERS    = [playerName, ...]   — who already voted YES
	  WFBE_VOTE_COOLDOWNS = [[type, unlockServerTime], ...]
	  WFBE_SERVER_TIME    = time  (broadcast every loop tick so clients can compute countdowns)

	Vote window: missionNamespace getVariable ["WFBE_C_VOTE_WINDOW", 60]  (seconds)
	Cooldown:    missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300] (seconds)
*/

Private ["_side","_playerName","_voteType","_logik","_eligible","_needed",
         "_voters","_yesCount","_state","_cooldowns","_cooldownSec","_i",
         "_unlock","_onCooldown","_window","_endTime","_vSide"];

_side       = _this select 0;
_playerName = _this select 1;
_voteType   = _this select 2;

//--- Validate type.
if (!(_voteType in ["skip-night","surrender","weather","mission-restart"])) exitWith {
	["WARNING", Format ["RequestVote: unknown type '%1' from %2", _voteType, _playerName]] Call WFBE_CO_FNC_LogContent;
};

//--- Resolve which side's eligibility counts.
//--- surrender = own team; skip-night/weather/mission-restart = all humans.
_vSide = if (_voteType == "surrender") then {_side} else {objNull};

//--- Count eligible voters (exclude headless clients: isPlayer is false for HCs).
_eligible = 0;
{
	if (isPlayer _x && {alive _x}) then {
		if (_voteType == "surrender") then {
			if (side _x == _vSide) then {_eligible = _eligible + 1};
		} else {
			_eligible = _eligible + 1;
		};
	};
} forEach playableUnits;

if (_eligible < 1) then {_eligible = 1}; //--- Solo-server guard: votes still work.

//--- Quorum threshold.
_needed = if (_voteType in ["weather","mission-restart","surrender"]) then {
	_eligible
} else {
	//--- skip-night: simple majority.
	floor(_eligible / 2) + 1
};

//--- Fetch shared state arrays (init on first use).
if (isNil "WFBE_VOTE_STATE")     then {WFBE_VOTE_STATE     = []};
if (isNil "WFBE_VOTE_VOTERS")    then {WFBE_VOTE_VOTERS    = []};
if (isNil "WFBE_VOTE_COOLDOWNS") then {WFBE_VOTE_COOLDOWNS = []};

_state     = WFBE_VOTE_STATE;
_voters    = WFBE_VOTE_VOTERS;
_cooldowns = WFBE_VOTE_COOLDOWNS;
_window    = missionNamespace getVariable ["WFBE_C_VOTE_WINDOW", 60];
_cooldownSec = missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300];

//--- -----------------------------------------------------------------------
//--- BRANCH A: a vote is already active.
//--- -----------------------------------------------------------------------
if (count _state >= 5) then {
	Private ["_activeType"];
	_activeType = _state select 0;

	if (_activeType != _voteType) exitWith {
		//--- Different vote type is running — silently ignore (client dialog disables button).
	};

	//--- Record YES (no double-counting).
	Private ["_alreadyVoted"];
	_alreadyVoted = false;
	{if (_x == _playerName) then {_alreadyVoted = true}} forEach _voters;

	if (!_alreadyVoted) then {
		_voters = _voters + [_playerName];
		WFBE_VOTE_VOTERS = _voters;
		publicVariable "WFBE_VOTE_VOTERS";

		_yesCount = count _voters;

		//--- Update state broadcast.
		_state set [1, _yesCount];
		WFBE_VOTE_STATE = _state;
		publicVariable "WFBE_VOTE_STATE";

		//--- Check early pass.
		if (_yesCount >= _needed) then {
			[_voteType, _side] Spawn WFBE_SE_FNC_VotePassed;
		};
	};

} else {
	//--- -----------------------------------------------------------------------
	//--- BRANCH B: no active vote — try to start one.
	//--- -----------------------------------------------------------------------

	//--- Check cooldown.
	_onCooldown = false;
	{
		if ((_x select 0) == _voteType) then {
			if ((_x select 1) > time) then {_onCooldown = true};
		};
	} forEach _cooldowns;

	if (_onCooldown) exitWith {
		//--- Silently ignore; client already shows cooldown timer.
	};

	//--- skip-night only valid when it IS night.
	if (_voteType == "skip-night") then {
		Private ["_h"];
		_h = date select 3;
		if (!(_h >= 19 || _h < 5)) exitWith {
			[nil, "LocalizeMessage", ["VoteNotNight"]] Call WFBE_CO_FNC_SendToClients;
		};
	};

	//--- Open a new vote.
	_endTime = time + _window;
	WFBE_VOTE_STATE  = [_voteType, 1, _needed, _endTime, _vSide];
	WFBE_VOTE_VOTERS = [_playerName];
	WFBE_SERVER_TIME = time;
	publicVariable "WFBE_VOTE_STATE";
	publicVariable "WFBE_VOTE_VOTERS";
	publicVariable "WFBE_SERVER_TIME";

	//--- Announce start.
	[nil, "LocalizeMessage", ["VoteStarted", _playerName, Localize (Format ["STR_WF_VOTE_OPT_%1", _voteType])]] Call WFBE_CO_FNC_SendToClients;

	//--- Spawn watcher to close the window.
	[_voteType, _side, _endTime, _needed] Spawn WFBE_SE_FNC_VoteWatcher;
};
