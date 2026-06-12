// Marty: Performance Audit locals.
private ["_playerStats","_playerScore","_playerPrevStats","_playerPrevScoreTotal","_playerPrevTimePlayedTotal","_result","_oldScore","_playerScoreDiff","_playerNewScore","_playerNewScoreTotal","_sleep","_miniSleep","_hasConnectedAtLaunch","_flushSleep","_initialSleep","_perfStart","_perfPlayers","_perfAllUnits"];


_sleep = _this select 0;
_miniSleep = _this select 1;

// Marty: Keep this loop dormant if called while the AntiStack mission parameter is disabled.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", "UpdateScoreInternal.sqf: AntiStack is disabled; score sampling loop stopped before start."] Call WFBE_CO_FNC_LogContent;
};

while { true } do {
	uiSleep _sleep;
	// Marty: Performance Audit timing for AntiStack score sampling.
	_perfStart = diag_tickTime;
	_perfPlayers = 0;
	_perfAllUnits = count allUnits;

	{
		if (isPlayer _x) then {
			// Marty: Performance Audit player counter for AntiStack score sampling.
			_perfPlayers = _perfPlayers + 1;
			missionNamespace setVariable [format ["WFBE_CO_CURRENT_SCORE_PLAYER_%1", getPlayerUID _x], score _x];
		};
	} forEach allUnits;

	// Marty: Performance Audit record for AntiStack score sampling.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["antistack_update_score", diag_tickTime - _perfStart, Format["allUnits:%1;players:%2", _perfAllUnits, _perfPlayers], "SERVER"] Call PerformanceAudit_Record;
		};
	};
};
