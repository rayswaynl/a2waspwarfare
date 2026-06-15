scriptName "Server\Functions\Server_VotePassed.sqf";

/*
	Executes a vote that has reached its threshold (called by RequestVote on early pass
	or by Server_VoteWatcher on window-end pass).

	Parameters: [voteType, requestingSide]

	Design notes:
	  - skip-night:     Server advances date to 05:30 using a deep copy of date (+date)
	                    to avoid mutating the engine array in place.  WFBE_DAYNIGHT_DATE
	                    is publicVariable'd for JIP.  An explicit HandleSpecial
	                    "vote-skip-night" is also broadcast because the PVEH for
	                    WFBE_DAYNIGHT_DATE only flags WFBE_DAYNIGHT_PENDING_SYNC, not
	                    setDate.
	  - commander:      Short-circuits on the client; never reaches here.
	  - surrender:      Triggering side (_side) loses.  We pass its side ID to
	                    HandleSpecial "endgame" — Client_EndGame.sqf treats the argument
	                    as the LOSER.  gameOver and WFBE_GameOver are both set (the
	                    victory FSM checks the bare global).  WFBE_CO_FNC_LogGameEnd is
	                    called with the winning side, matching server_victory_threeway.sqf.
	  - weather:        Cycles clear→overcast→rain→clear.  Server sets overcast/rain;
	                    engine does not auto-sync weather to clients, so we broadcast
	                    HandleSpecial "vote-weather-apply".
	  - mission-restart: No real winner.  WFBE_PRESENTSIDES select 0 is the dummy loser
	                    (cosmetically imperfect but functionally correct — mission ends
	                    cleanly for admin restart).  WFBE_CO_FNC_LogGameEnd is called
	                    with select 1 as the nominal "winner".  Stat logging (WASPSTAT
	                    ROUNDEND) is intentionally skipped for vote-driven ends because
	                    neither side earned a win.
*/

Private ["_voteType","_side","_d","_overcast","_rain",
         "_weatherIdx","_weatherPresets","_loserSide","_loserID","_winnerSide",
         "_presentSides"];

_voteType = _this select 0;
_side     = _this select 1;

//--- G9: fire-once guard. RequestVote (early pass) and Server_VoteWatcher (window end) both Spawn this,
//--- and Spawn defers execution, so a 2nd passing-YES or the watcher could double-fire the round-ending
//--- action. The first instance clears WFBE_VOTE_STATE synchronously below (before its sleep), so any
//--- later instance sees empty state and bails. State-based (no separate latch that could leak on throw).
if (isNil "WFBE_VOTE_STATE" || {count WFBE_VOTE_STATE == 0}) exitWith {};

//--- Clear vote state immediately (prevents watcher from double-firing).
WFBE_VOTE_STATE  = [];
WFBE_VOTE_VOTERS = [];
publicVariable "WFBE_VOTE_STATE";
publicVariable "WFBE_VOTE_VOTERS";

//--- Announce pass.
[nil, "LocalizeMessage", ["VotePassed", Localize (Format ["STR_WF_VOTE_OPT_%1", _voteType])]] Call WFBE_CO_FNC_SendToClients;

sleep 2; //--- Let the announcement reach clients before acting.

switch (_voteType) do {

	case "skip-night": {
		//--- Advance to 05:30.  +date = deep copy; avoids mutating engine array in place.
		_d = +date;
		_d set [3, 5];
		_d set [4, 30];
		setDate _d;
		WFBE_DAYNIGHT_DATE = date;
		publicVariable "WFBE_DAYNIGHT_DATE";
		//--- Explicit client setDate (PVEH only flags PENDING_SYNC, not a direct setDate).
		[nil, "HandleSpecial", ["vote-skip-night", date]] Call WFBE_CO_FNC_SendToClients;
	};

	case "surrender": {
		//--- Surrendering side (_side) loses.
		_loserSide  = _side;
		_loserID    = _loserSide Call WFBE_CO_FNC_GetSideID;
		_winnerSide = (WFBE_PRESENTSIDES - [_loserSide]);
		if (count _winnerSide > 0) then {_winnerSide = _winnerSide select 0} else {_winnerSide = _loserSide};
		[nil, "HandleSpecial", ["endgame", _loserID]] Call WFBE_CO_FNC_SendToClients;
		["SET_MAP", 0] call WFBE_SE_FNC_CallDatabaseSetMap;
		WF_Logic setVariable ["WF_Winner", _winnerSide];
		gameOver      = true;
		WFBE_GameOver = true;
		[_winnerSide] call WFBE_CO_FNC_LogGameEnd;
		sleep 5;
		failMission "END1";
	};

	case "weather": {
		//--- Cycle: clear → overcast → rain → clear.
		_weatherIdx     = missionNamespace getVariable ["WFBE_VOTE_WEATHER_IDX", 0];
		_weatherPresets = [[0, 0], [0.7, 0], [0.9, 0.8]]; //--- [overcast, rain]
		_weatherIdx     = (_weatherIdx + 1) mod 3;
		missionNamespace setVariable ["WFBE_VOTE_WEATHER_IDX", _weatherIdx];
		_overcast = (_weatherPresets select _weatherIdx) select 0;
		_rain     = (_weatherPresets select _weatherIdx) select 1;
		//--- Apply on server (engine does not auto-sync weather to clients).
		60 setOvercast _overcast;
		60 setRain     _rain;
		//--- Push to all clients.
		[nil, "HandleSpecial", ["vote-weather-apply", _overcast, _rain]] Call WFBE_CO_FNC_SendToClients;
	};

	case "mission-restart": {
		//--- Guard: need at least 1 side present.
		if (count WFBE_PRESENTSIDES < 1) exitWith {
			["WARNING", "VotePassed mission-restart: WFBE_PRESENTSIDES is empty, cannot trigger endgame."] Call WFBE_CO_FNC_LogContent;
		};
		//--- Dummy loser = first present side (cosmetic; mission ends cleanly for restart).
		_loserSide  = WFBE_PRESENTSIDES select 0;
		_loserID    = _loserSide Call WFBE_CO_FNC_GetSideID;
		_winnerSide = (WFBE_PRESENTSIDES - [_loserSide]);
		if (count _winnerSide > 0) then {_winnerSide = _winnerSide select 0} else {_winnerSide = _loserSide};
		[nil, "HandleSpecial", ["endgame", _loserID]] Call WFBE_CO_FNC_SendToClients;
		["SET_MAP", 0] call WFBE_SE_FNC_CallDatabaseSetMap;
		WF_Logic setVariable ["WF_Winner", _winnerSide];
		gameOver      = true;
		WFBE_GameOver = true;
		//--- WASPSTAT ROUNDEND intentionally skipped: neither side earned a competitive win.
		[_winnerSide] call WFBE_CO_FNC_LogGameEnd;
		sleep 5;
		failMission "END1";
	};
};
