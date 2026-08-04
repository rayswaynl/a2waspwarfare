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
_rpavg185Changed = false;
if (typeName _rpavg185 != "ARRAY") then {_rpavg185 = [0, 0]; _rpavg185Changed = true};
if (count _rpavg185 != 2) then {_rpavg185 = [0, 0]; _rpavg185Changed = true};
_rpN185     = _rpavg185 select 0;
_rpTotal185 = _rpavg185 select 1;
if (typeName _rpN185 != "SCALAR" || {typeName _rpTotal185 != "SCALAR"} || {_rpN185 < 0} || {_rpTotal185 < 0}) then {_rpavg185 = [0, 0]; _rpN185 = 0; _rpTotal185 = 0; _rpavg185Changed = true};
if (_rpavg185Changed) then {profileNamespace setVariable ["WFBE_RPAVG", _rpavg185]; saveProfileNamespace};
profileNamespace setVariable ["WFBE_RPAVG", [_rpN185 + 1, _rpTotal185 + (round time)]];
saveProfileNamespace;

if (WFBE_Server_LogMatchWin) then {
    _winnerWins = profileNamespace getVariable format ["%1_WIN_CHERNARUS",_winnerTeam];
    _loserWins = profileNamespace getVariable format ["%1_WIN_CHERNARUS", _loserTeam];

    if (isNil "_winnerWins") then {
        profileNamespace setVariable [format ["%1_WIN_CHERNARUS",_winnerTeam], 1];

        if (isNil "_loserWins") then {
            profileNamespace setVariable [format ["%1_WIN_CHERNARUS",_loserTeam], 0];
        };

        saveProfileNamespace;
    } else {
        profileNamespace setVariable [format ["%1_WIN_CHERNARUS",_winnerTeam], (_winnerWins + 1)];

        if (isNil "_loserWins") then {
            profileNamespace setVariable [format ["%1_WIN_CHERNARUS",_loserTeam], 0];
        };

        saveProfileNamespace;
    };

    ["INFORMATION", Format ["LogGameEnd.sqf: Team BLUFOR has %1 wins and team OPFOR has %2 wins on Chernarus since start of logging.", profileNamespace getVariable "WEST_WIN_CHERNARUS", profileNamespace getVariable "EAST_WIN_CHERNARUS"]] Call WFBE_CO_FNC_LogContent;
};