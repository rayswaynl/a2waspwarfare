/*
	author: Net_2
	description: none
	returns: nothing
*/

private ["_timer","_timeLeftToKick","_sleep","_movementTimer","_afk","_afkShouldBe","_commandAndConquer","_commandAndConquerShouldBe","_lastMapCommandClickTime","_mapCommandWindow"];

_timer = 0;
_movementTimer = 0;

while {!gameOver} do {
    if (WFBE_CO_VAR_NotAFK_update) then {
        _timer = 0;
        WFBE_CO_VAR_NotAFK_update = false;
    } else {
        _timer = _timer + 1;
    };

    // Marty: Movement-AFK marker state is separate from anti-kick activity; map commands may reset kick timer without hiding AFK.
    if (WFBE_CO_VAR_NotAFK_MovementUpdate) then {
        _movementTimer = 0;
        WFBE_CO_VAR_NotAFK_MovementUpdate = false;
    } else {
        _movementTimer = _movementTimer + 1;
    };

    _afkShouldBe = _movementTimer >= (WFBE_CO_VAR_AFKkickThreshold / 1.5);
    _afk = player getVariable ["WASP_AFK", false];
    if (_afk != _afkShouldBe) then {
        player setVariable ["WASP_AFK", _afkShouldBe, true];
    };

    // Marty: Command & Conquer is only marker text for a movement-AFK player who recently issued a real map command.
    _lastMapCommandClickTime = missionNamespace getVariable ["WFBE_CLIENT_LAST_MAP_COMMAND_CLICK_TIME", -5000];
    _mapCommandWindow = missionNamespace getVariable ["WFBE_CLIENT_COMMAND_AND_CONQUER_WINDOW", 180];
    _commandAndConquerShouldBe = _afkShouldBe && ((time - _lastMapCommandClickTime) <= _mapCommandWindow);
    _commandAndConquer = player getVariable ["WASP_CommandAndConquer", false];
    if (_commandAndConquer != _commandAndConquerShouldBe) then {
        player setVariable ["WASP_CommandAndConquer", _commandAndConquerShouldBe, true];
    };

    if (_timer >= (WFBE_CO_VAR_AFKkickThreshold / 1.5)) then {
        _timeLeftToKick = WFBE_CO_VAR_AFKkickThreshold - _timer + 1;
        // Marty: Map opening alone is not activity; real map command clicks refresh the AFK timer elsewhere.
        hint format ["If you don't move or command on the map in %1 minutes, you will be kicked for being AFK.",_timeLeftToKick];
    };

    if (_timer > WFBE_CO_VAR_AFKkickThreshold) then {
        publicVariableServer "AFKthresholdExceededName";
        failMission "END1";
    };

    _sleep = 60 call GetSleepFPS;
    sleep _sleep;
};
