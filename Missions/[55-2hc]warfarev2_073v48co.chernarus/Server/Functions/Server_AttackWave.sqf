"ATTACK_WAVE_INIT" addPublicVariableEventHandler {

    private ["_badFields", "_d", "_serverSupply", "_supply", "_side"];

    _d = _this select 1;
    if (typeName _d != "ARRAY") exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected malformed ATTACK_WAVE_INIT payload type [%1].", typeName _d]] Call WFBE_CO_FNC_LogContent;
    };
    if (count _d < 2) exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected short ATTACK_WAVE_INIT payload [%1].", _d]] Call WFBE_CO_FNC_LogContent;
    };

    _supply = _d select 0;
    _side = _d select 1;
    _badFields = false;
    if (typeName _supply != "SCALAR") then {_badFields = true};
    if (!(_side in [west, east])) then {_badFields = true};
    if (_badFields) exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected invalid ATTACK_WAVE_INIT fields supply=%1 side=%2.", typeName _supply, _side]] Call WFBE_CO_FNC_LogContent;
    };

    _serverSupply = _side Call GetSideSupply;
    if (typeName _serverSupply != "SCALAR") exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected ATTACK_WAVE_INIT for side [%1], server supply type [%2].", _side, typeName _serverSupply]] Call WFBE_CO_FNC_LogContent;
    };
    if (_serverSupply < 25000) exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected ATTACK_WAVE_INIT for side [%1], server supply [%2] is below activation cost.", _side, _serverSupply]] Call WFBE_CO_FNC_LogContent;
    };

    [_serverSupply, _side] spawn {

        private ["_attackWaveLength", "_discountPercentage", "_side", "_supply"];

        _supply = _this select 0;
        _side = _this select 1;

        _discountPercentage = 0;

        _discountPercentage = 0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1/50000));

        _discountPercentage = 0.7 * _discountPercentage;

        ATTACK_WAVE_PRICE_MODIFIER = _discountPercentage;

        _attackWaveLength = (1 - _discountPercentage) * 1500;

        ATTACK_WAVE_DETAILS = [_side, ATTACK_WAVE_PRICE_MODIFIER, _attackWaveLength];

        diag_log ATTACK_WAVE_DETAILS;

        publicVariableServer "ATTACK_WAVE_DETAILS";

        sleep _attackWaveLength;

        _attackWaveLength = 0;

        // Return to normal units' pricing after the wave
        ATTACK_WAVE_PRICE_MODIFIER = 1;

        ATTACK_WAVE_DETAILS = [_side, ATTACK_WAVE_PRICE_MODIFIER, _attackWaveLength];

        publicVariableServer "ATTACK_WAVE_DETAILS";
    };
};
