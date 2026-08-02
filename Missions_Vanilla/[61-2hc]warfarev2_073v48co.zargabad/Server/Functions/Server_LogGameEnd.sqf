/*
	author: Net_2
	description: none
	returns: nothing
*/

private ["_winnerTeam","_loserTeam","_winnerWins","_loserWins"];

_winnerTeam = _this select 0;
_loserTeam = "";

if ((missionNamespace getVariable ["WFBE_C_CHAT_RELAY", 0]) > 0) then {
	["ROUND", "SERVER", Format ["winner=%1", str _winnerTeam]] Call WFBE_SE_FNC_ChatRelayEvent;
};

["INFORMATION", Format ["LogGameEnd.sqf: Team [%1] has won the match! Log match win? [%2]", _winnerTeam, WFBE_Server_LogMatchWin]] Call WFBE_CO_FNC_LogContent;

if (_winnerTeam == west) then {
    _loserTeam = east;
} else {
    _loserTeam = west;
};


//--- 185 (HQ repair scaling): persist this round's elapsed time for the next mission's avg.
private ["_rpavg185","_rpN185","_rpTotal185"];
_rpavg185   = profileNamespace getVariable ["WFBE_RPAVG", [0, 0]];
_rpN185     = _rpavg185 select 0;
_rpTotal185 = _rpavg185 select 1;
profileNamespace setVariable ["WFBE_RPAVG", [_rpN185 + 1, _rpTotal185 + (round time)]];
saveProfileNamespace;

if (WFBE_Server_LogMatchWin) then {
    //--- fix(matchstate-r88): key the persisted win tally by the ACTUAL terrain (toUpper worldName)
    //--- instead of a hardcoded CHERNARUS. On Takistan/Zargabad every win was written into the
    //--- Chernarus counters, contaminating the per-map record across server restarts and printing
    //--- "on Chernarus" in the RPT on all maps. On Chernarus the keys resolve to the SAME
    //--- "WEST_WIN_CHERNARUS"/"EAST_WIN_CHERNARUS" names, so the existing tally continues; TK/ZG
    //--- start their own correct per-map tallies. A2-OA-safe (worldName/toUpper in live use).
    private ["_mapKey"];
    _mapKey = toUpper worldName;
    _winnerWins = profileNamespace getVariable format ["%1_WIN_%2",_winnerTeam,_mapKey];
    _loserWins = profileNamespace getVariable format ["%1_WIN_%2", _loserTeam,_mapKey];

    if (isNil "_winnerWins") then {
        profileNamespace setVariable [format ["%1_WIN_%2",_winnerTeam,_mapKey], 1];

        if (isNil "_loserWins") then {
            profileNamespace setVariable [format ["%1_WIN_%2",_loserTeam,_mapKey], 0];
        };

        saveProfileNamespace;
    } else {
        profileNamespace setVariable [format ["%1_WIN_%2",_winnerTeam,_mapKey], (_winnerWins + 1)];

        if (isNil "_loserWins") then {
            profileNamespace setVariable [format ["%1_WIN_%2",_loserTeam,_mapKey], 0];
        };

        saveProfileNamespace;
    };

    ["INFORMATION", Format ["LogGameEnd.sqf: Team BLUFOR has %1 wins and team OPFOR has %2 wins on %3 since start of logging.", profileNamespace getVariable format ["WEST_WIN_%1",_mapKey], profileNamespace getVariable format ["EAST_WIN_%1",_mapKey], worldName]] Call WFBE_CO_FNC_LogContent;
};