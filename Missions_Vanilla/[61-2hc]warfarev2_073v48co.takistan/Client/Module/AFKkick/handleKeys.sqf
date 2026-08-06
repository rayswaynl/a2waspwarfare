/*
	author: Net_2
	description: none
	returns: nothing
*/

private ["_key","_handled","_moveButtons"];

_key = _this select 1;
_handled = false;
_moveButtons = actionKeys "MoveBack" + actionKeys "MoveDown" + actionKeys "MoveForward" + actionKeys "MoveFastForward" + actionKeys "MoveLeft" + actionKeys "MoveRight" + actionKeys "HideMap" + actionKeys "showMap";

//--- updateclient.sqf owns the sole AFK timeout. Any keyboard interaction, including map,
//--- chat, and terminal controls, is activity even when the player remains stationary.
if (!isNull player) then {player setVariable ["lastActionTime", time];};

if (_key in _moveButtons) then {
    WFBE_CO_VAR_NotAFK_update = true;
    _handled = false;
};

_handled;
