if (!isDedicated) exitWith {};

while {true} do
{
    // Get the fps variable from the server, insert to get from the missionNamespace as public variable
    SERVER_FPS_GUI = round(diag_fps);
    publicVariable "SERVER_FPS_GUI";

    sleep 8; // Update frequency
}
