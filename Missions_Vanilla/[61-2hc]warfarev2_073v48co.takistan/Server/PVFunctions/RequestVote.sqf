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
	  WFBE_SERVER_TIME    = time  (broadcast by persistent server loop + watcher)

	Threshold is locked at vote-open time (stored in state[2]) so
	join/leave mid-vote cannot shift the pass bar.

	Vote window:  missionNamespace getVariable ["WFBE_C_VOTE_WINDOW", 60]  (seconds)
	Cooldown:     missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300] (seconds)
*/

Private ["_side","_playerName","_voteType","_eligible","_needed",
         "_voters","_yesCount","_state","_cooldowns","_cooldownSec",
         "_onCooldown","_window","_endTime","_vSide","_alreadyVoted",
         "_rejected","_h","_activeType","_voteSide","_cmdTeam"];

_side       = _this select 0;
_playerName = _this select 1;
_voteType   = _this select 2;

//--- Validate type.
if (!(_voteType in ["skip-night","surrender","weather","mission-restart"])) exitWith {
	["WARNING", Format ["RequestVote: unknown type '%1' from %2", _voteType, _playerName]] Call WFBE_CO_FNC_LogContent;
};

//--- Fetch shared state arrays (init on first use).
if (isNil "WFBE_VOTE_STATE")     then {WFBE_VOTE_STATE     = []};
if (isNil "WFBE_VOTE_VOTERS")    then {WFBE_VOTE_VOTERS    = []};
if (isNil "WFBE_VOTE_COOLDOWNS") then {
	WFBE_VOTE_COOLDOWNS = [];
	publicVariable "WFBE_VOTE_COOLDOWNS"; //--- JIP: ensure clients see an empty list.
};

_state     = WFBE_VOTE_STATE;
_voters    = WFBE_VOTE_VOTERS;
_cooldowns = WFBE_VOTE_COOLDOWNS;
_window      = missionNamespace getVariable ["WFBE_C_VOTE_WINDOW", 60];
_cooldownSec = missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300];

//--- -----------------------------------------------------------------------
//--- BRANCH A: a vote is already active.
//--- -----------------------------------------------------------------------
if (count _state >= 5) then {
	_activeType = _state select 0;

	//--- Different vote type running — silently ignore.
	if (_activeType != _voteType) exitWith {};

	//--- For surrender: verify sender's side matches the stored vote side.
	//--- _state select 4 is a side value for surrender votes; objNull for global ones.
	//--- Use typeName to distinguish: "SIDE" = restricted; "OBJECT" = no restriction.
	if (_voteType == "surrender") then {
		_voteSide = _state select 4;
		if ((typeName _voteSide) == "SIDE" && {_side != _voteSide}) exitWith {};
	};

	//--- Read threshold locked at vote-open time (fix #1: never recompute mid-vote).
	_needed = _state select 2;

	//--- Record YES (no double-counting).
	_alreadyVoted = false;
	{if (_x == _playerName) then {_alreadyVoted = true}} forEach _voters;

	if (!_alreadyVoted) then {
		_voters = _voters + [_playerName];
		WFBE_VOTE_VOTERS = _voters;
		publicVariable "WFBE_VOTE_VOTERS";

		_yesCount = count _voters;

		//--- Update state broadcast (yes count only; threshold unchanged).
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
	//--- Spin-lock mutex to prevent two concurrent Spawns both seeing empty state.
	//--- -----------------------------------------------------------------------
	while {!(isNil "WFBE_VOTE_LOCK") && {WFBE_VOTE_LOCK}} do {sleep 0.01};
	WFBE_VOTE_LOCK = true;

	//--- Re-check state and cooldowns inside lock (freshest read after acquiring mutex).
	_state     = WFBE_VOTE_STATE;
	_cooldowns = WFBE_VOTE_COOLDOWNS;
	if (count _state >= 5) exitWith {
		WFBE_VOTE_LOCK = false;
		//--- A race winner already opened a vote; silently drop this request.
	};

	//--- Check cooldown (inside lock).
	_onCooldown = false;
	{
		if ((_x select 0) == _voteType) then {
			if ((_x select 1) > time) then {_onCooldown = true};
		};
	} forEach _cooldowns;

	if (_onCooldown) exitWith {
		WFBE_VOTE_LOCK = false;
		//--- Silently ignore; client already shows cooldown timer.
	};

	//--- skip-night only valid at night — flag and gate below to keep exitWith at script scope.
	_rejected = false;
	if (_voteType == "skip-night") then {
		_h = date select 3;
		if (!(_h >= 19 || _h < 5)) then {
			_rejected = true;
			[nil, "LocalizeMessage", ["VoteNotNight"]] Call WFBE_CO_FNC_SendToClients;
		};
	};

	//--- Surrender vote may only be STARTED by the side's commander (client UI mirrors
	//--- this; server check is authoritative). Name match against the commander team
	//--- leader — no commander = no surrender vote.
	if (_voteType == "surrender") then {
		_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _cmdTeam || {_playerName != name (leader _cmdTeam)}) then {
			_rejected = true;
			["INFORMATION", Format ["RequestVote: surrender start by non-commander '%1' rejected", _playerName]] Call WFBE_CO_FNC_LogContent;
		};
	};

	if (_rejected) exitWith {
		WFBE_VOTE_LOCK = false;
	};

	//--- Resolve which side's eligibility counts.
	//--- surrender = own team; skip-night/weather/mission-restart = all humans.
	_vSide = if (_voteType == "surrender") then {_side} else {objNull};

	//--- Count eligible voters at vote-start time (threshold locked here).
	//--- Headless clients sit in playable CIV slots and are isPlayer-true; exclude them
	//--- by requiring side west or east so 2 connected HCs cannot inflate every threshold.
	_eligible = 0;
	{
		if (isPlayer _x && {alive _x} && {(side _x) in [west, east]}) then {
			if (_voteType == "surrender") then {
				if (side _x == _vSide) then {_eligible = _eligible + 1};
			} else {
				_eligible = _eligible + 1;
			};
		};
	} forEach playableUnits;
	if (_eligible < 1) then {_eligible = 1}; //--- Solo-server guard.

	//--- Quorum threshold (locked for the life of this vote).
	_needed = if (_voteType in ["weather","mission-restart","surrender"]) then {
		_eligible
	} else {
		floor(_eligible / 2) + 1
	};

	//--- Open a new vote.
	_endTime = time + _window;
	WFBE_VOTE_STATE  = [_voteType, 1, _needed, _endTime, _vSide];
	WFBE_VOTE_VOTERS = [_playerName];
	WFBE_SERVER_TIME = time;
	publicVariable "WFBE_VOTE_STATE";
	publicVariable "WFBE_VOTE_VOTERS";
	publicVariable "WFBE_SERVER_TIME";

	WFBE_VOTE_LOCK = false; //--- Release lock before spawning watcher.

	//--- Announce start.
	[nil, "LocalizeMessage", ["VoteStarted", _playerName, Localize (Format ["STR_WF_VOTE_OPT_%1", _voteType])]] Call WFBE_CO_FNC_SendToClients;

	//--- Spawn watcher to close the window (passes needed so watcher never recomputes).
	[_voteType, _side, _endTime, _needed] Spawn WFBE_SE_FNC_VoteWatcher;
};
