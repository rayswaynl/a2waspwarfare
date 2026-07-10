"ATTACK_WAVE_INIT" addPublicVariableEventHandler {

    private ["_supply", "_side"];

    _supply = _this select 1 select 0;
    _side = _this select 1 select 1;

    [_supply, _side] spawn {

        _supply = _this select 0;
        _side = _this select 1;

        _discountPercentage = 0;

        _discountPercentage = 0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1/50000));

        _discountPercentage = 0.7 * _discountPercentage;

        //--- AI4 (cmdcon41-w3f): do NOT stash the discount in the bare global ATTACK_WAVE_PRICE_MODIFIER here.
        //--- Two sides running concurrent waves each ran their OWN copy of this spawn and both wrote/read that
        //--- single global across the sleep below, so one side's wave clobbered the other's discount mid-flight.
        //--- The per-side truth is carried in the ATTACK_WAVE_DETAILS array (it already contains _side) and is
        //--- stored per-side downstream (ATTACK_WAVE_WEST/EAST_PRICE_MODIFIER in Server/PVFunctions/AttackWave.sqf,
        //--- sourced from the array - NOT this global). So we pass the spawn-local _discountPercentage straight
        //--- into the array; nothing on the server reads the bare global (client copies are set per-client per-side
        //--- via the "attack-wave" HandleSpecial). This removes the clobber at the root with no shared server state.
        _attackWaveLength = (1 - _discountPercentage) * 1500;

        //--- Fix: call handler directly; publicVariableServer from server never fires own PVEH.
        //--- No bare ATTACK_WAVE_DETAILS global needed: array is passed directly, per cmdcon41-w3f comment.
        diag_log [_side, _discountPercentage, _attackWaveLength];

        [_side, _discountPercentage, _attackWaveLength] Call WFBE_SE_FNC_HandleAttackWaveDetails;

        sleep _attackWaveLength;

        _attackWaveLength = 0;

        // Return to normal units' pricing after the wave (per-side value carried in the array; no shared global).
        //--- Fix: call handler directly; publicVariableServer from server never fires own PVEH.
        [_side, 1, _attackWaveLength] Call WFBE_SE_FNC_HandleAttackWaveDetails;
    };
};