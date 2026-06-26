"ATTACK_WAVE_INIT" addPublicVariableEventHandler {

    private ["_side"];

    //--- Anti-cheat (Layer 6b / DR-41): NEVER trust the client-sent supply value. A forged
    //--- ATTACK_WAVE_INIT could drive the side-wide price modifier to zero/negative (free units).
    //--- Validate the side, then re-derive supply from authoritative server state and clamp.
    if (typeName (_this select 1) != "ARRAY" || {count (_this select 1) < 2}) exitWith {
        ["WARNING", "Server_AttackWave.sqf: rejected ATTACK_WAVE_INIT - malformed payload."] Call WFBE_CO_FNC_LogContent;
    };
    _side = _this select 1 select 1;
    if (!(_side in [west, east])) exitWith {
        ["WARNING", Format ["Server_AttackWave.sqf: rejected ATTACK_WAVE_INIT - invalid side [%1].", str _side]] Call WFBE_CO_FNC_LogContent;
    };

    [_side] spawn {

        _side = _this select 0;

        //--- Server-derived supply, not the client payload value.
        _supply = (_side) Call GetSideSupply;
        if (isNil "_supply") then {_supply = 0};

        _discountPercentage = 0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1/50000));
        _discountPercentage = 0.7 * _discountPercentage;

        //--- Clamp so the modifier can never make units free or negative-priced.
        if (_discountPercentage < 0.28) then {_discountPercentage = 0.28};
        if (_discountPercentage > 1) then {_discountPercentage = 1};

        ATTACK_WAVE_PRICE_MODIFIER = _discountPercentage;

        _attackWaveLength = (1 - _discountPercentage) * 1500;
        if (_attackWaveLength < 0) then {_attackWaveLength = 0};

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