// Release fix (#7): only publish server FPS on a true dedicated server.
// Previously the `sleep 8` lived INSIDE the `if (isDedicated)` branch, so on a listen/SP host
// (isServer true, isDedicated false) this `while {true}` spun every frame with no yield = a CPU busy-loop.
if (!isDedicated) exitWith {};

while {true} do
{
    // Publish the current server FPS; the client HUD (Client_UpdateRHUD.sqf) reads SERVER_FPS_GUI.
    SERVER_FPS_GUI = round(diag_fps);
    publicVariable "SERVER_FPS_GUI";

    sleep 8; // Update frequency
};
