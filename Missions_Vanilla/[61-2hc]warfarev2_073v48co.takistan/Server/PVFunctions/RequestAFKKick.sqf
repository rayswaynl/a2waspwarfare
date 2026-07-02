/*
    SG14: Server-authoritative AFK kick handler.
    Author: fable/lane129
    Description:
        The client's monitorAFK.sqf detects AFK and REPORTS here via publicVariableServer.
        The server validates the player object and issues the actual kick so the action
        cannot be suppressed or forged by a client mod.
    Parameters (received via WFBE_SE_FNC_HandlePVF dispatch):
        _this select 0 : Object - the reporting player's player object
    Returns: nothing
*/

private ["_player", "_name"];

_player = _this select 0;

//--- Validate: must be a real, living, in-mission playable unit.
if (isNull _player) exitWith {
    ["WARNING", "RequestAFKKick.sqf: rejected - null player object."] Call WFBE_CO_FNC_LogContent;
};

if (!isPlayer _player) exitWith {
    ["WARNING", format ["RequestAFKKick.sqf: rejected - object [%1] is not a player.", _player]] Call WFBE_CO_FNC_LogContent;
};

if (!alive _player) exitWith {
    ["WARNING", format ["RequestAFKKick.sqf: rejected - player [%1] is already dead/disconnected.", name _player]] Call WFBE_CO_FNC_LogContent;
};

_name = name _player;

["INFORMATION", format ["RequestAFKKick.sqf: kicking player [%1] for AFK (server-authoritative).", _name]] Call WFBE_CO_FNC_LogContent;

//--- Issue the BattlEye kick (same mechanism used by updateclient.sqf / publicvariable.txt filter action 5).
kickAFK = format ["%1 Kicked for AFKing", _name];
publicVariable "kickAFK";
