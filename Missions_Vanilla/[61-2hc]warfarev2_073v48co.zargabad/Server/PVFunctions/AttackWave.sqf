"CLIENT_INIT_READY" addPublicVariableEventHandler {
    private ["_player"];

    _player = _this select 1;

    //--- Set attack mode status properly.
    if (side (_player) == west && ATTACK_WAVE_ACTIVE_WEST) then {
        [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_WEST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
        [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
    } else {
        if (side (_player) == east && ATTACK_WAVE_ACTIVE_EAST) then {
            [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_EAST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
            [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
        };
    };

    //--- FOB-JIP replay (moved from Server_OnPlayerConnected.sqf, sqf-fn-binding r122): replay ACTIVE GUER
    //--- FOB markers to a GUER joiner (#846 known gap). Fired from CLIENT_INIT_READY - published by the
    //--- client at the END of Init_Client, after commonInitComplete (WFBE_PVF_* PVEHs installed) and the
    //--- WFBE_CL_FNC_HandlePVF compile - so the joiner can actually consume the push; the old connect-time
    //--- fire raced that init and was silently dropped. Targeted publicVariableClient (only the joiner
    //--- re-receives, no side-wide re-create), ledger copied (+) against concurrent clears, client handler
    //--- idempotent (delete-then-create), sleep keeps successive writes to the same PV name from coalescing.
    //--- NOTE: the var-write + publicVariableClient pair is not atomic across overlapping joiner threads,
    //--- but every GUER replay iterates the same ledger, so a crossover still delivers a valid FOB payload
    //--- (same worst case as the original connect-time design).
    if ((side _player) == resistance) then {
        [_player] Spawn {
            private ["_fobOwner","_fobPlayer","_fobReplay"];
            _fobPlayer = _this select 0;
            _fobReplay = + (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
            if ((count _fobReplay) > 0) then {
                _fobOwner = owner _fobPlayer;
                if (_fobOwner > 0) then {
                    diag_log Format ["[WFBE][FOB-JIP] replaying %1 active FOB marker(s) to ready joiner %2", count _fobReplay, name _fobPlayer];
                    {
                        WFBE_PVF_WildcardMarker = [resistance, "CLTFNCWildcardMarker", ["create", _x select 0, _x select 1, "ColorGreen", "mil_objective", Format ["FOB %1", _x select 2], "forward base active - spawn and resupply here"]];
                        _fobOwner publicVariableClient "WFBE_PVF_WildcardMarker";
                        sleep 0.5;
                    } forEach _fobReplay;
                };
            };
        };
    };

    //--- AICOM-WILDCARD-JIP: WildcardMarker creates a local marker, so the original side broadcast cannot
    //--- reach a player whose client was not ready when the draw happened. Replay from CLIENT_INIT_READY,
    //--- after the joiner's PVF receiver exists, and target the player directly. The snapshot is copied before
    //--- the loop; each record is re-checked against the joiner's side and absolute expiry before sending.
    //--- The final false payload element suppresses the historical chat line for a replay; the live create path
    //--- still uses its default notification behavior.
    [_player] Spawn {
        private ["_jipPlayer","_jipSide","_wildReplay"];
        _jipPlayer = _this select 0;
        if (isNull _jipPlayer) exitWith {};
        _jipSide = side _jipPlayer;
        _wildReplay = + (missionNamespace getVariable ["WFBE_AICOM_WILDCARD_ACTIVE", []]);
        {
            if ((_x select 0) == _jipSide && {(_x select 7) > time}) then {
                [_jipPlayer, "WildcardMarker", ["create", _x select 1, _x select 2, _x select 3, _x select 4, _x select 5, _x select 6, false]] Call WFBE_CO_FNC_SendToClient;
                sleep 0.5;
            };
        } forEach _wildReplay;
    };
};


//--- Fix: extracted PVEH body into WFBE_SE_FNC_HandleAttackWaveDetails so Server_AttackWave.sqf
//--- can call it directly. publicVariableServer from the server never fires the server's own PVEH,
//--- so the handler was dead for both wave-start and wave-end. The PVEH below still calls this
//--- function so any future client->server ATTACK_WAVE_DETAILS publish also works.
//--- Calling convention: _this IS the payload array [side, priceModifier, attackLength].
//--- (Server_AttackWave.sqf calls directly; PVEH relay strips the varname with (_this select 1) Call.)
WFBE_SE_FNC_HandleAttackWaveDetails = {
	private ["_priceModifier", "_side", "_attackLength", "_attackLengthMinutes", "_priceModifierPercentage", "_requester"];

    if (typeName _this != "ARRAY") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected malformed ATTACK_WAVE_DETAILS payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
    };

    if (count _this < 3) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected short ATTACK_WAVE_DETAILS payload [%1] element(s).", count _this]] Call WFBE_CO_FNC_LogContent;
    };

	_side = _this select 0;
	_priceModifier = _this select 1;
    _attackLength = _this select 2;
    //--- fix(harden) [#1399]: optional 4th element - the acting player, threaded by Server_AttackWave.sqf
    //--- from Common_AttackWaveActivate.sqf. objNull when absent (legacy/forged short payload); the
    //--- requester-bind guard below rejects the activation branch for any non-side-matched requester.
    _requester = if (count _this > 3) then {_this select 3} else {objNull};

    if (typeName _side != "SIDE") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid side type [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
    };

    if (!(_side in [west, east])) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS for unsupported side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
    };

    if (typeName _priceModifier != "SCALAR") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid modifier type [%1].", typeName _priceModifier]] Call WFBE_CO_FNC_LogContent;
    };

    if (typeName _attackLength != "SCALAR") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid length type [%1].", typeName _attackLength]] Call WFBE_CO_FNC_LogContent;
    };

    _priceModifierPercentage = round (_priceModifier * 100);

    if (_attackLength > 0) then {
        _attackLengthMinutes = floor (_attackLength / 60);

        //--- fix(harden) [#1399]: requester-bind (ALWAYS-ON, C4/C2 ruling - same idiom as
        //--- RequestAIComDonate.sqf and the aicom-team-disband/rally/refit/hold binds, PR #1364).
        //--- This branch is the ONLY economy mutation in this handler (the full-supply debit a few
        //--- lines below), so only this branch is gated - a forged ATTACK_WAVE_INIT/ATTACK_WAVE_DETAILS
        //--- payload could otherwise assert any _side and wipe that side's entire supply as "activation
        //--- cost" regardless of the forger's own side. The sole honest caller is Server_AttackWave.sqf,
        //--- itself fed only by Common_AttackWaveActivate.sqf's addAction, which always threads the
        //--- clicking player's own live `player` object - no honest activation can trip this. The
        //--- wave-END/reset branch below performs no mutation and stays UNGATED so it composes cleanly
        //--- with the latch-release/staleness rework [#1373] in Server_AttackWave.sqf: that reset call
        //--- must keep landing even if the original requester later disconnects, dies, or changes side
        //--- mid-wave, or the side would latch ATTACK_WAVE_ACTIVE_* permanently active.
        if (isNull _requester || {!isPlayer _requester} || {!alive _requester} || {side _requester != _side}) exitWith {
            //--- fix(reject-release): clear the overlap-guard reservation Server_AttackWave.sqf took
            //--- unconditionally BEFORE spawning its worker - the worker detects this rejection by
            //--- reading the flag after the Call, so the clear must happen here, inside the reject
            //--- branch, or a forged/invalid requester latches the side's heavy attack for a full
            //--- wave-length sleep. Idempotent on the (BE-kicked) direct-publish path, where no
            //--- reservation exists.
            if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};
            if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};
            ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS activation for side [%1] - requester [%2] invalid, dead, not a player, or side-mismatched.", _side, _requester]] Call WFBE_CO_FNC_LogContent;
        };

        if (_side == west) then {
            ATTACK_WAVE_ACTIVE_WEST = true;
            ATTACK_WAVE_WEST_PRICE_MODIFIER = _priceModifier;
        } else {
            ATTACK_WAVE_ACTIVE_EAST = true;
            ATTACK_WAVE_EAST_PRICE_MODIFIER = _priceModifier;
        };

        //--- fix(hunt): ChangeSideSupply delivers via publicVariableServer - a silent no-op ON the server (the
        //--- exact trap the header of this file documents for the wave channel itself) - so the advertised
        //--- full-supply sacrifice was never charged and HEAVY ATTACK re-armed for free every wave. Route the
        //--- debit straight through the server-side supply handler instead.
        [[format ["wfbe_supply_temp_%1", _side], [_side, -(_side call GetSideSupply), "Heavy attack mode activated."]], _side, true] Call WFBE_SE_FNC_HandleSideSupplyChange;

        [_side, "HandleSpecial", ["attack-wave", _priceModifier]] Call WFBE_CO_FNC_SendToClients;

    	["INFORMATION", Format["AttackWave.sqf: Team [%1] has activated heavy attack mode with price modifier: [%2].", _side, _priceModifier]] Call WFBE_CO_FNC_LogContent;

        [_side, "LocalizeMessage", ["AttackModeActivated", _priceModifierPercentage, _attackLengthMinutes]] call WFBE_CO_FNC_SendToClients;
    } else {
        ["INFORMATION", Format["AttackWave.sqf: Team [%1] heavy attack mode ending.", _side]] Call WFBE_CO_FNC_LogContent;

        if (_side == west) then {
            ATTACK_WAVE_ACTIVE_WEST = false;
            ATTACK_WAVE_WEST_PRICE_MODIFIER = 1;
        } else {
            ATTACK_WAVE_ACTIVE_EAST = false;
            ATTACK_WAVE_EAST_PRICE_MODIFIER = 1;
        };

        [_side, "HandleSpecial", ["attack-wave", 1]] Call WFBE_CO_FNC_SendToClients;

        [_side, "LocalizeMessage", ["AttackModeEnd"]] call WFBE_CO_FNC_SendToClients;
    };
};

"ATTACK_WAVE_DETAILS" addPublicVariableEventHandler {
    //--- Relay any client->server ATTACK_WAVE_DETAILS publish through the extracted function.
    //--- No in-tree caller currently publishes this variable (Server_AttackWave.sqf calls
    //--- WFBE_SE_FNC_HandleAttackWaveDetails directly, and the name is not in the BE-allowlist
    //--- at BattlEyeFilter/publicvariable.txt), so a raw publish here still lands on the same
    //--- requester-bind guard above and cannot bypass it.
    (_this select 1) Call WFBE_SE_FNC_HandleAttackWaveDetails;
};
