// Marty: Performance Audit locals.
private ["_playerStats","_playerScore","_playerPrevStats","_playerPrevScoreTotal","_playerPrevTimePlayedTotal","_result","_oldScore","_playerScoreDiff","_playerNewScore","_playerNewScoreTotal","_sleep","_miniSleep","_hasConnectedAtLaunch","_flushSleep","_initialSleep","_perfStart","_perfPlayers","_perfAllUnits","_perfDbCalls"];


_miniSleep = _this select 0;
_mainSleep = _this select 1;

// Marty: Keep this loop dormant if called while the AntiStack mission parameter is disabled.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", "MainLoop.sqf: AntiStack is disabled; database score flush loop stopped before start."] Call WFBE_CO_FNC_LogContent;
};

["INFORMATION", "MainLoop.sqf: Starting main loop..."] Call WFBE_CO_FNC_LogContent;

while { !WFBE_GameOver } do {
	uiSleep _mainSleep;
	// Marty: Performance Audit timing for AntiStack database score flush.
	_perfStart = diag_tickTime;
	_perfPlayers = 0;
	_perfDbCalls = 0;
	_perfAllUnits = count allUnits;

	{
		if (isPlayer _x) then {
			// Marty: Performance Audit counters for AntiStack database score flush.
			_perfPlayers = _perfPlayers + 1;
			_playerScore = score _x;
			_playerPrevStats = ["RETRIEVE", getPlayerUID _x] call WFBE_SE_FNC_CallDatabaseRetrieve;
			_perfDbCalls = _perfDbCalls + 1;
			_playerPrevScoreTotal = _playerPrevStats select 0;
			_playerPrevTimePlayedTotal = _playerPrevStats select 1;
			_oldScore = missionNamespace getVariable format ["WFBE_CO_OLD_SCORE_PLAYER_%1", getPlayerUID _x];
			if (isNil "_oldScore") then {
				_oldScore = 0;
			};
			missionNamespace setVariable [format["WFBE_CO_OLD_SCORE_PLAYER_%1", getPlayerUID _x], _playerScore];
			_playerScoreDiff = _playerScore - _oldScore;
			_playerNewScore = _playerPrevScoreTotal + _playerScoreDiff;
			uiSleep _miniSleep;
			_result = ["STORE", [getPlayerUID _x, _playerScoreDiff]] call WFBE_SE_FNC_CallDatabaseStore;
			_perfDbCalls = _perfDbCalls + 1;
		};
	} forEach allUnits;

	// Marty: Performance Audit record for AntiStack database score flush.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["antistack_main", diag_tickTime - _perfStart, Format["allUnits:%1;players:%2;dbCalls:%3", _perfAllUnits, _perfPlayers, _perfDbCalls], "SERVER"] Call PerformanceAudit_Record;
		};
	};
};
