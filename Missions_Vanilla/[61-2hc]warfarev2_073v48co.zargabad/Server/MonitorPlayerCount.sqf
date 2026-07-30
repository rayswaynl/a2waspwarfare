private ["_playerCount", "_logMatchWinPlayerCountThreshold"];

_logMatchWinPlayerCountThreshold = _this select 0;

sleep 120;

while {true} do {

	_playerCount = count ([] Call WFBE_CO_FNC_RealPlayers);

	if (_playerCount >= _logMatchWinPlayerCountThreshold) then {
		WFBE_Server_LogMatchWin = true;
	};

	sleep 300;

};
