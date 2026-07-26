// Marty: Performance Audit locals.
private ["_playerStats","_playerScore","_playerPrevStats","_playerPrevScoreTotal","_playerPrevTimePlayedTotal","_result","_oldScore","_playerScoreDiff","_playerNewScore","_playerNewScoreTotal","_sleep","_miniSleep","_hasConnectedAtLaunch","_flushSleep","_initialSleep","_perfStart","_perfPlayers","_perfAllUnits","_perfDbCalls","_perfActive","_perfSliceMax","_perfSliceDt","_sliceT0","_perfDbSec"];

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
	// perf-slice (2026-07-26): active-time accounting - the recorded elapsed now EXCLUDES every
	// uiSleep suspension (the old wall-clock number was dominated by the per-player pacing sleeps
	// rounding up to whole frames at low server fps: ~460ms logged for 3 players of ~0ms real work).
	_perfActive = 0;
	_perfSliceMax = 0;
	_perfSliceDt = 0;
	_perfDbSec = 0;
	_sliceT0 = _perfStart;

	_playersOnServer = [];
	{
		if (!isNull _x) then {
			// Marty: Performance Audit player counter for AntiStack player list flush.
			_perfPlayers = _perfPlayers + 1;
			_perfSliceDt = diag_tickTime - _sliceT0; _perfActive = _perfActive + _perfSliceDt; if (_perfSliceDt > _perfSliceMax) then {_perfSliceMax = _perfSliceDt};
			uiSleep _miniSleep;
			_sliceT0 = diag_tickTime;
			
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
	// Marty: PERF - helper returns only living human player slots, excluding headless-client bodies.
	} forEach ([] call WFBE_CO_FNC_RealPlayers);
	// ["TEST", format ["CountPlayerScores.sqf: DEBUG: Contents of _playersOnServer ('SEND_PLAYERLIST'): %1", _playersOnServer]] Call WFBE_CO_FNC_LogContent;
	// perf-slice (2026-07-26): yield before the synchronous DB callExtension so it starts on a fresh
	// scheduler slice, and time it separately (an atomic extension call cannot be chunked further).
	_perfSliceDt = diag_tickTime - _sliceT0; _perfActive = _perfActive + _perfSliceDt; if (_perfSliceDt > _perfSliceMax) then {_perfSliceMax = _perfSliceDt};
	uiSleep _miniSleep;
	_sliceT0 = diag_tickTime;
	["SEND_PLAYERLIST", _playersOnServer] call WFBE_SE_FNC_CallDatabaseSendPlayerList;
	_perfDbSec = diag_tickTime - _sliceT0;
	_perfDbCalls = _perfDbCalls + 1;

	// Marty: Performance Audit record for AntiStack player list flush.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfSliceDt = diag_tickTime - _sliceT0; _perfActive = _perfActive + _perfSliceDt; if (_perfSliceDt > _perfSliceMax) then {_perfSliceMax = _perfSliceDt};
			["antistack_flush", _perfActive, Format["allUnits:%1;players:%2;dbCalls:%3;sentPlayers:%4;sliceMaxMs:%5;dbMs:%6;wallMs:%7", _perfAllUnits, _perfPlayers, _perfDbCalls, count _playersOnServer, (_perfSliceMax * 1000) call PerformanceAudit_Round2, (_perfDbSec * 1000) call PerformanceAudit_Round2, ((diag_tickTime - _perfStart) * 1000) call PerformanceAudit_Round2], "SERVER"] Call PerformanceAudit_Record;
		};
	};

	uiSleep _flushSleep;

};
