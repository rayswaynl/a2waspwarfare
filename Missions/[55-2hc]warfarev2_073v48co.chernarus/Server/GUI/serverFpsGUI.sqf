// Release fix (#7): only publish server FPS on a true dedicated server.
// Previously the `sleep 8` lived INSIDE the `if (isDedicated)` branch, so on a listen/SP host
// (isServer true, isDedicated false) this `while {true}` spun every frame with no yield = a CPU busy-loop.
if (!isDedicated) exitWith {};

Private ["_activePlayersOnly","_hasHuman"];

while {true} do
{
    _activePlayersOnly = missionNamespace getVariable ["WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY", 0];
    _hasHuman = true;

    if (_activePlayersOnly > 0) then {
        _hasHuman = false;
        {
            if ([_x] Call WFBE_CO_FNC_IsRealPlayer) exitWith {_hasHuman = true};
        } forEach (call BIS_fnc_listPlayers);
    };

    if (_hasHuman) then {
        // Publish the current server FPS; the client HUD (Client_UpdateRHUD.sqf) reads SERVER_FPS_GUI.
        SERVER_FPS_GUI = round(diag_fps);
        publicVariable "SERVER_FPS_GUI";
    };

    sleep 8; // Update frequency
};
