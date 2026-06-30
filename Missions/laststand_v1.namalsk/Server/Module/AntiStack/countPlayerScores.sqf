private ["_playerStats","_playerScore","_playerPrevStats","_playerPrevScoreTotal","_playerPrevTimePlayedTotal","_result","_oldScore","_playerScoreDiff","_playerNewScore","_playerNewScoreTotal","_sleep","_mainsleep","_miniSleep","_hasConnectedAtLaunch","_flushSleep","_initialSleep"];

// Marty: Hard guard for direct execVM calls when the mission parameter disables AntiStack.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", "CountPlayerScores.sqf: AntiStack is disabled; score loops were not started."] Call WFBE_CO_FNC_LogContent;
};

// In seconds
_miniSleep = 0.15;
_mainSleep = 120;

["INFORMATION", "CountPlayerScores.sqf got execVMd!"] Call WFBE_CO_FNC_LogContent;

[_miniSleep, _mainSleep] execVM "Server\Module\AntiStack\mainLoop.sqf";
// In seconds
_sleep = 1;

[_sleep, _miniSleep] execVM "Server\Module\AntiStack\updateScoreInternal.sqf";

// In seconds
_flushSleep = 120;
_initialSleep = 10;

[_flushSleep, _initialSleep, _miniSleep] execVM "Server\Module\AntiStack\flushLoop.sqf";
