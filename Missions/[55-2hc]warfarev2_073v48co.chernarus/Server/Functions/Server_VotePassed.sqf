scriptName "Server\Functions\Server_VotePassed.sqf";

/*
	Executes a vote that has reached its threshold (called by RequestVote on early pass
	or by Server_VoteWatcher on window-end pass).

	Parameters: [voteType, requestingSide]

	Design notes:
	  - skip-night:     Server advances date to 05:30 and publicVariable's it.
	                    Clients do NOT automatically setDate on WFBE_DAYNIGHT_DATE
	                    broadcasts (that PVEH only flags WFBE_DAYNIGHT_PENDING_SYNC).
	                    So we ALSO broadcast HandleSpecial "vote-skip-night" which
	                    calls setDate on every client.
	  - commander:      Short-circuits on the client; never reaches here.
	  - surrender:      Triggering side loses. We pass its side ID to HandleSpecial
	                    "endgame" — Client_EndGame.sqf treats the argument as the LOSER
	                    and cameras the winner.
	  - weather:        Cycles clear→overcast→rain→clear.  Server sets overcast/rain
	                    (engine does NOT auto-sync weather to clients), then broadcasts
	                    HandleSpecial "vote-weather-apply" so clients do the same.
	  - mission-restart: No winner.  We pass WFBE_PRESENTSIDES select 0 as the dummy
	                    "loser"; the end screen will show the other side as winner.
	                    This is cosmetically imperfect but functionally correct — the
	                    mission ends cleanly and the server can restart.
*/

Private ["_voteType","_side","_h","_d","_newHour","_overcast","_rain",
         "_weatherIdx","_weatherPresets","_loserSide","_loserID"];

_voteType = _this select 0;
_side     = _this select 1;

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
		//--- Advance to 05:30.
		_d = date;
		_d set [3, 5];
		_d set [4, 30];
		setDate _d;
		WFBE_DAYNIGHT_DATE = date;
		publicVariable "WFBE_DAYNIGHT_DATE";
		//--- Also push an explicit setDate to all clients (PVEH only flags PENDING_SYNC; skip time is cosmetic).
		[nil, "HandleSpecial", ["vote-skip-night", date]] Call WFBE_CO_FNC_SendToClients;
	};

	case "surrender": {
		//--- Surrendering side (_side) loses.
		_loserSide = _side;
		_loserID   = _loserSide Call WFBE_CO_FNC_GetSideID;
		[nil, "HandleSpecial", ["endgame", _loserID]] Call WFBE_CO_FNC_SendToClients;
		["SET_MAP", 0] call WFBE_SE_FNC_CallDatabaseSetMap;
		WFBE_GameOver = true;
		sleep 5;
		failMission "END1";
	};

	case "weather": {
		//--- Cycle: clear → overcast → rain → clear.
		//--- Read current state from a tracking variable (0=clear,1=overcast,2=rain).
		_weatherIdx     = missionNamespace getVariable ["WFBE_VOTE_WEATHER_IDX", 0];
		_weatherPresets = [[0, 0], [0.7, 0], [0.9, 0.8]]; //--- [overcast, rain]
		_weatherIdx     = (_weatherIdx + 1) mod 3;
		missionNamespace setVariable ["WFBE_VOTE_WEATHER_IDX", _weatherIdx];
		_overcast = (_weatherPresets select _weatherIdx) select 0;
		_rain     = (_weatherPresets select _weatherIdx) select 1;
		//--- Apply on server (server is authoritative for weather start; does not auto-sync).
		60 setOvercast _overcast;
		60 setRain     _rain;
		//--- Push to all clients.
		[nil, "HandleSpecial", ["vote-weather-apply", _overcast, _rain]] Call WFBE_CO_FNC_SendToClients;
	};

	case "mission-restart": {
		//--- Use the first present side as the dummy loser (cosmetic only; mission will end).
		_loserSide = WFBE_PRESENTSIDES select 0;
		_loserID   = _loserSide Call WFBE_CO_FNC_GetSideID;
		[nil, "HandleSpecial", ["endgame", _loserID]] Call WFBE_CO_FNC_SendToClients;
		["SET_MAP", 0] call WFBE_SE_FNC_CallDatabaseSetMap;
		WFBE_GameOver = true;
		sleep 5;
		failMission "END1";
	};
};
