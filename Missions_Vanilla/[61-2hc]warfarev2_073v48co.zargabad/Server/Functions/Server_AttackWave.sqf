"ATTACK_WAVE_INIT" addPublicVariableEventHandler {

    private ["_supply", "_side", "_requester"];

    _supply = _this select 1 select 0;
    _side = _this select 1 select 1;
    //--- fix(harden) [#1399]: carry the requester through so AttackWave.sqf's WFBE_SE_FNC_HandleAttackWaveDetails
    //--- can bind the activation to the requester's own side. objNull for legacy/forged 2-element
    //--- payloads - the requester-bind guard in AttackWave.sqf rejects those on the activation branch.
    _requester = if (count (_this select 1) > 2) then {(_this select 1) select 2} else {objNull};

    //--- Reserve the side before spawning: a second client activation can otherwise arrive before
    //--- the spawned worker marks the wave active, creating a second debit/timer that ends early. [#1350]
    //--- fix(aicom) [#1373]: the guard also expires after WFBE_C_ATTACK_WAVE_STALE_MINUTES even
    //--- while ATTACK_WAVE_ACTIVE_* is still true, so a worker that dies before reaching its own reset
    //--- below (exception, JIP/save-load edge, mission end) cannot latch the side forever and
    //--- permanently suppress future attack waves on that side.
    if (_side == west && {ATTACK_WAVE_ACTIVE_WEST} && {(time - ATTACK_WAVE_ACTIVE_WEST_SET_TIME) < (WFBE_C_ATTACK_WAVE_STALE_MINUTES * 60)}) exitWith {};
    if (_side == east && {ATTACK_WAVE_ACTIVE_EAST} && {(time - ATTACK_WAVE_ACTIVE_EAST_SET_TIME) < (WFBE_C_ATTACK_WAVE_STALE_MINUTES * 60)}) exitWith {};
    if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = true};
    if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = true};
    if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST_SET_TIME = time};
    if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST_SET_TIME = time};

    [_supply, _side, _requester] spawn {

        _supply = _this select 0;
        _side = _this select 1;
        _requester = _this select 2;

        //--- fix(harden) [#1401]: re-derive from server-authoritative supply state rather than trusting the
        //--- client-supplied _supply figure carried in ATTACK_WAVE_INIT (docs/design/ATTACK-WAVE-PRICE-
        //--- MODIFIER-AUDIT-2026-07-03.md flagged "forged supply input" as an open gap). GetSideSupply
        //--- reads the live missionNamespace wfbe_supply_<side> value - the same source AttackWave.sqf's
        //--- own full-supply debit already trusts (Server/PVFunctions/AttackWave.sqf) - so a forged
        //--- client _supply can no longer skew the wave's discount percentage or duration. Overwrites
        //--- the client-sent value in place; nothing downstream still reads the untrusted figure.
        _supply = _side call GetSideSupply;

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

        [_side, _discountPercentage, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;

        //--- fix(combine): the requester-bind guard [#1399] inside WFBE_SE_FNC_HandleAttackWaveDetails
        //--- rejects (exitWith) a forged/invalid-requester activation for this _side. As originally
        //--- combined, the "detection" below checked the flag the handler flips true on success - dead
        //--- code, because the reservation above had ALREADY forced that flag true before the spawn, so
        //--- a rejection latched the side for a full _attackWaveLength even though nothing was debited
        //--- or announced (a denial-of-service purely from combining the overlap guard [#1350/#1373]
        //--- with the requester-bind reject path [#1399]). The handler's reject branch now clears the
        //--- reservation itself; this check observes the cleared flag and exits the worker immediately
        //--- (skipping the sleep and a spurious wave-end announce), and stays as an idempotent
        //--- defense-in-depth re-clear.
        if ((_side == west && {!ATTACK_WAVE_ACTIVE_WEST}) || (_side == east && {!ATTACK_WAVE_ACTIVE_EAST})) exitWith {
            if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};
            if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};
        };

        sleep _attackWaveLength;

        _attackWaveLength = 0;

        // Return to normal units' pricing after the wave (per-side value carried in the array; no shared global).
        //--- Fix: call handler directly; publicVariableServer from server never fires own PVEH.
        [_side, 1, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;

        //--- fix(aicom) [#1373]: release the per-side overlap latch directly here (not only as a
        //--- side effect of HandleAttackWaveDetails above) so the guard's normal-completion reset is
        //--- visible and auditable right next to where the guard is set, above.
        if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};
        if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};
    };
};