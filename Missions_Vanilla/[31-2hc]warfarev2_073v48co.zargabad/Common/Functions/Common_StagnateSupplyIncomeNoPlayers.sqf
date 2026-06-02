private ["_amount", "_side", "_sidePlayers", "_supplyDecreasePercentage", "_teamSkillWest", "_teamSkillEast"];

_amount = _this select 0; 
_side = _this select 1;

_sidePlayers = [];
_supplyDecreasePercentage = 0;

_teamSkillWest = ["REQUEST_SIDE_SKILL", west] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;
_teamSkillEast = ["REQUEST_SIDE_SKILL", east] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;

if (_side == west) then {
    if (_teamSkillWest > 0) exitWith {
        _amount;
    };
} else {
    if (_side == east) then {
        if (_teamSkillEast > 0) exitWith {
            _amount;
        };
    };
};

{
    if (isPlayer _x) then 
    {
        if (side _x == _side) then 
        {
            _sidePlayers = _sidePlayers + [_x];
        };
    };

} forEach allUnits;

if (_side == west) then {
    _teamWestPlayers = count _sidePlayers;
    if (_teamWestPlayers <= 0) then {
        TEAM_WEST_TICKS_NO_PLAYERS = TEAM_WEST_TICKS_NO_PLAYERS + 1;
        _supplyDecreasePercentage = TEAM_WEST_TICKS_NO_PLAYERS * SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER;
    } else {
        TEAM_WEST_TICKS_NO_PLAYERS = 0;
    };
} else {
    if (_side == east) then {
        _teamEastPlayers = count _sidePlayers;
        if (_teamEastPlayers <= 0) then {
            TEAM_EAST_TICKS_NO_PLAYERS = TEAM_EAST_TICKS_NO_PLAYERS + 1;
            _supplyDecreasePercentage = TEAM_EAST_TICKS_NO_PLAYERS * SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER;
        } else {
            TEAM_EAST_TICKS_NO_PLAYERS = 0;
        };
    };
};

publicVariable "TEAM_WEST_TICKS_NO_PLAYERS";
publicVariable "TEAM_EAST_TICKS_NO_PLAYERS";

if (_supplyDecreasePercentage > 1) then {
    _supplyDecreasePercentage = 1;
};

if (_supplyDecreasePercentage < 0) then {
    _supplyDecreasePercentage = 0;
};

if ((_supplyDecreasePercentage > 0) && (_supplyDecreasePercentage < 1)) then {
    _amount = round(_amount * (1 - _supplyDecreasePercentage));
    ["INFORMATION",Format ["StagnateSupplyIncomeNoPlayers.sqf: Decreasing supply income of team [%1] after %2 ticks with no players by %3 percent. Supply income is now S %4.", str _side, if (_side == west) then {TEAM_WEST_TICKS_NO_PLAYERS} else {TEAM_EAST_TICKS_NO_PLAYERS}, round(_supplyDecreasePercentage * 100), _amount]] Call WFBE_CO_FNC_LogContent;
};

_amount