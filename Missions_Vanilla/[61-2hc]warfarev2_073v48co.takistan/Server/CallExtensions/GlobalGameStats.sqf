Private ["_cSharpClassName","_scoreSideWest","_scoreSideEast","_currentMap","_uptime","_playerCount","_hcCount","_players"];
_cSharpClassName = "GLOBALGAMESTATS";
_currentMap = worldName;

while {true} do {
    _scoreSideWest = scoreSide west;
    _scoreSideEast = scoreSide east;
    _uptime = round(time);
    _playerCount = 0;

    ["INFORMATION", Format ["Running with old vars %1: %2 | %3 | %4 | %5 | %6",_cSharpClassName,_scoreSideWest,_scoreSideEast,_currentMap,_uptime,_playerCount]] Call WFBE_CO_FNC_LogContent;

    // Count the actual players, skip bots that are in the deadspawns.
    _players = call BIS_fnc_listPlayers;
    _playerCount = count _players;

    // Exclude connected headless clients. This mission runs multiple HCs, so subtract the
    // live HC count from the registry (mirrors the validity check in Server_HandleSpecial.sqf)
    // instead of a hardcoded 1. Floor at 0 so a transient over-subtract never reports negative.
    _hcCount = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
    _playerCount = (_playerCount - _hcCount) max 0;

    "a2waspwarfare_Extension" callExtension format ["%1,%2,%3,%4,%5,%6",_cSharpClassName,_scoreSideWest,_scoreSideEast,_currentMap,_uptime,_playerCount];
    ["INFORMATION", Format ["Done %1: %2 | %3 | %4 | %5 | %6",_cSharpClassName,_scoreSideWest,_scoreSideEast,_currentMap,_uptime,_playerCount]] Call WFBE_CO_FNC_LogContent;
    sleep 60;
};
