// Marty: Performance Audit locals.
private ["_playerStats","_playerScore","_playerPrevStats","_playerPrevScoreTotal","_playerPrevTimePlayedTotal","_result","_oldScore","_playerScoreDiff","_playerNewScore","_playerNewScoreTotal","_sleep","_miniSleep","_hasConnectedAtLaunch","_flushSleep","_initialSleep","_perfStart","_perfPlayers","_perfAllUnits","_perfDbCalls"];

_flushSleep = _this select 0;
_initialSleep = _this select 1;
_miniSleep = _this select 2;

_playersOnServer = [];

// Marty: Keep this loop dormant if called while the AntiStack mission parameter is disabled.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", "FlushLoop.sqf: AntiStack is disabled; player list flush loop stopped before start."] Call WFBE_CO_FNC_LogContent;
};

uiSleep _initialSleep;

while { !WFBE_GameOver } do {
	
	// Marty: Performance Audit timing for AntiStack player list flush.
	_perfStart = diag_tickTime;
	_perfPlayers = 0;
	_perfDbCalls = 0;
	_perfAllUnits = count allUnits;

	_playersOnServer = [];
	{
		if (isPlayer _x) then {
			// Marty: Performance Audit player counter for AntiStack player list flush.
			_perfPlayers = _perfPlayers + 1;
			uiSleep _miniSleep;
			
			_confirmedSide = missionNamespace getVariable Format["WFBE_JIP_USER%1_TEAM_JOINED", getPlayerUID _x];
			if (!(isNil "_confirmedSide")) then {
				_playersOnServer set [count _playersOnServer, [getPlayerUID _x, _confirmedSide]];
			} else {
				_hasConnectedAtLaunch = missionNamespace getVariable format ["WFBE_PLAYER_%1_CONNECTED_AT_LAUNCH", getPlayerUID _x];
				if (!(isNil "_hasConnectedAtLaunch")) then {
					// diag_log format ["UID: %1 _hasConnectedAtLaunch: %2", getPlayerUID _x, _hasConnectedAtLaunch];
					_playersOnServer set [count _playersOnServer, [getPlayerUID _x, side _x]];
				};
			};
		};
	} forEach allUnits;
	// ["TEST", format ["CountPlayerScores.sqf: DEBUG: Contents of _playersOnServer ('SEND_PLAYERLIST'): %1", _playersOnServer]] Call WFBE_CO_FNC_LogContent;
	["SEND_PLAYERLIST", _playersOnServer] call WFBE_SE_FNC_CallDatabaseSendPlayerList;
	_perfDbCalls = _perfDbCalls + 1;

	// Marty: Performance Audit record for AntiStack player list flush.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["antistack_flush", diag_tickTime - _perfStart, Format["allUnits:%1;players:%2;dbCalls:%3;sentPlayers:%4", _perfAllUnits, _perfPlayers, _perfDbCalls, count _playersOnServer], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	uiSleep _flushSleep;

};
