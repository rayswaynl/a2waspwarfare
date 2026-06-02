private ["_teamSkillWest", "_teamSkillEast", "_teamWestSkillTicksTriggerThresholdExceeded0", "_teamEastSkillTicksTriggerThresholdExceeded", "_teamWestSkillTicksEndTriggerThresholdExceeded", "_teamEastSkillTicksEndTriggerThresholdExceeded", "_skillDiff", "_teamWestSupplyIncome", "_teamEastSupplyIncome", "_skillTicksDifference", "_supplyCompensationPercentage", "_supplyCompensationAmount", "_includeStagnation"];

// Marty: Hard guard for direct execVM calls when the mission parameter disables AntiStack.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
    ["INFORMATION", "SkillDiffCompensation.sqf: AntiStack is disabled; skill compensation loop was not started."] Call WFBE_CO_FNC_LogContent;
};

while {!WFBE_GameOver} do {

    sleep 120;

    _teamSkillWest = ["REQUEST_SIDE_SKILL", west] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;
    _teamSkillEast = ["REQUEST_SIDE_SKILL", east] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;

    TEAM_SKILL_TICKS_WEST = TEAM_SKILL_TICKS_WEST + _teamSkillWest;
    TEAM_SKILL_TICKS_EAST = TEAM_SKILL_TICKS_EAST + _teamSkillEast;

    _teamWestSkillTicksTriggerThresholdExceeded = TEAM_SKILL_TICKS_WEST > TEAM_SKILL_TICKS_EAST + TEAM_SKILL_TICKS_DIFF_THRESHOLD;
    _teamEastSkillTicksTriggerThresholdExceeded = TEAM_SKILL_TICKS_EAST > TEAM_SKILL_TICKS_WEST + TEAM_SKILL_TICKS_DIFF_THRESHOLD;
    
    _teamWestSkillTicksEndTriggerThresholdExceeded = TEAM_SKILL_TICKS_EAST > TEAM_SKILL_TICKS_WEST + TEAM_SKILL_TICKS_END_THRESHOLD;
    _teamEastSkillTicksEndTriggerThresholdExceeded = TEAM_SKILL_TICKS_WEST > TEAM_SKILL_TICKS_EAST + TEAM_SKILL_TICKS_END_THRESHOLD;

    TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE = 0;
    TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE = 0;

    _includeStagnation = false;

    if (_teamWestSkillTicksTriggerThresholdExceeded) then {

            while {!_teamWestSkillTicksEndTriggerThresholdExceeded} do {

                _teamSkillWest = ["REQUEST_SIDE_SKILL", west] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;
                _teamSkillEast = ["REQUEST_SIDE_SKILL", east] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;

                _skillDiff = _teamSkillEast - _teamSkillWest;

                if (_skillDiff < 0) then {
                    _skillDiff = 0;
                };

                TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE = TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE + _skillDiff;

                if (TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE < 0) then {
                    TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE = 0;
                };

                if (TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE > TEAM_SKILL_TICKS_END_THRESHOLD) then {
                    _teamWestSkillTicksEndTriggerThresholdExceeded = true;
                } else {
                    _teamWestSkillTicksEndTriggerThresholdExceeded = false;
                };

                _teamWestSupplyIncome = (west) call WFBE_CO_FNC_GetTownsSupply;
            
                _skillTicksDifference = _teamSkillWest - _teamSkillEast;
                _supplyCompensationPercentage = _skillTicksDifference * TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER * 100;
            
                if (_supplyCompensationPercentage > 100) then {
                    _supplyCompensationPercentage = 100;
                } else {
                    if (_supplyCompensationPercentage < 0) then {
                        _supplyCompensationPercentage = 0;
                    };
                };

                _supplyCompensationAmount = round(_teamWestSupplyIncome * (_supplyCompensationPercentage / 100));

                if (_supplyCompensationAmount > 0) then {
                    [east, _supplyCompensationAmount, format ["Anti-stack skill difference compensation applied: Supply compensation percentage: %1/100. Extra S %2 for team [%3].", _supplyCompensationPercentage, _supplyCompensationAmount, str east], _includeStagnation] Call ChangeSideSupply;
                };

                SUPPLY_COMPENSATION_AMOUNT_EAST = _supplyCompensationAmount;

                publicVariable "SUPPLY_COMPENSATION_AMOUNT_EAST";

                sleep 60;
            };

            ["INFORMATION",Format ["SkillDiffCompensation.sqf : Ended skill diff compensation for team [%1].", str east]] Call WFBE_CO_FNC_LogContent;

            TEAM_SKILL_TICKS_WEST = 0;
            TEAM_SKILL_TICKS_EAST = 0;

        } else {

            if (_teamEastSkillTicksTriggerThresholdExceeded) then {

                while {!_teamEastSkillTicksEndTriggerThresholdExceeded} do {

                    _teamSkillWest = ["REQUEST_SIDE_SKILL", west] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;
                    _teamSkillEast = ["REQUEST_SIDE_SKILL", east] call WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill;

                    _skillDiff = _teamSkillWest - _teamSkillEast;

                    if (_skillDiff < 0) then {
                        _skillDiff = 0;
                    };

                    TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE = TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE + _skillDiff;

                    if (TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE < 0) then {
                        TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE = 0;
                    };

                    if (TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE > TEAM_SKILL_TICKS_END_THRESHOLD) then {
                        _teamEastSkillTicksEndTriggerThresholdExceeded = true;
                    } else {
                        _teamEastSkillTicksEndTriggerThresholdExceeded = false;
                    };

                    _teamEastSupplyIncome = (east) call WFBE_CO_FNC_GetTownsSupply;
            
                    _skillTicksDifference = _teamSkillEast - _teamSkillWest;
                    _supplyCompensationPercentage = _skillTicksDifference * TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER * 100;
            
                    if (_supplyCompensationPercentage > 100) then {
                        _supplyCompensationPercentage = 100;
                    } else {
                        if (_supplyCompensationPercentage < 0) then {
                            _supplyCompensationPercentage = 0;
                        };
                    };

                    _supplyCompensationAmount = round(_teamEastSupplyIncome * (_supplyCompensationPercentage / 100));

                    if (_supplyCompensationAmount > 0) then {
                        [west, _supplyCompensationAmount, format ["Anti-stack skill difference compensation applied: Supply compensation percentage: %1/100. Extra S %2 for team [%3].", _supplyCompensationPercentage, _supplyCompensationAmount, str west], _includeStagnation] Call ChangeSideSupply;
                    };

                    SUPPLY_COMPENSATION_AMOUNT_WEST = _supplyCompensationAmount;

                    publicVariable "SUPPLY_COMPENSATION_AMOUNT_WEST";

                    sleep 60;
                };

                ["INFORMATION",Format ["SkillDiffCompensation.sqf : Ended skill diff compensation for team [%1].", str west]] Call WFBE_CO_FNC_LogContent;

                TEAM_SKILL_TICKS_WEST = 0;
                TEAM_SKILL_TICKS_EAST = 0;

        };

    };

};
