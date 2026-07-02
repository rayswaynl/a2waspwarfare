/*
	author: Net_2
	description: none
	returns: nothing
*/

private ["_timer","_timeLeftToKick","_sleep"];

_timer = 0;

while {!gameOver} do {
    if (WFBE_CO_VAR_NotAFK_update) then {
        _timer = 0;
        WFBE_CO_VAR_NotAFK_update = false;
    } else {
        _timer = _timer + 1;
    };

    if (_timer >= (WFBE_CO_VAR_AFKkickThreshold / 1.5)) then {
        _timeLeftToKick = WFBE_CO_VAR_AFKkickThreshold - _timer + 1;
        hint format ["If you don't move or open map in %1 minutes, you will be kicked for being AFK.",_timeLeftToKick];
    };

    if (_timer > WFBE_CO_VAR_AFKkickThreshold) then {
        publicVariableServer "AFKthresholdExceededName";
        //--- SG14: authority relocated to server; client only REPORTS — server validates and kicks.
        WFBE_PVF_RequestAFKKick = ["SRVFNCRequestAFKKick", [player]];
        publicVariableServer "WFBE_PVF_RequestAFKKick";
    };

    _sleep = 60 call GetSleepFPS;
    sleep _sleep;
};
