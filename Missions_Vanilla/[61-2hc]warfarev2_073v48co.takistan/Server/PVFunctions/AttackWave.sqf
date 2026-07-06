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
};


"ATTACK_WAVE_DETAILS" addPublicVariableEventHandler {

	private ["_payload", "_priceModifier", "_side", "_attackLength", "_attackLengthMinutes", "_priceModifierPercentage"];

    if (typeName _this != "ARRAY") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected malformed ATTACK_WAVE_DETAILS event type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
    };

    if (count _this < 2) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected short ATTACK_WAVE_DETAILS event [%1].", _this]] Call WFBE_CO_FNC_LogContent;
    };

    _payload = _this select 1;
    if (typeName _payload != "ARRAY") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected malformed ATTACK_WAVE_DETAILS payload type [%1].", typeName _payload]] Call WFBE_CO_FNC_LogContent;
    };

    if (count _payload < 3) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected short ATTACK_WAVE_DETAILS payload [%1].", _payload]] Call WFBE_CO_FNC_LogContent;
    };

	_side = _payload select 0;
	_priceModifier = _payload select 1;
    _attackLength = _payload select 2;

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

        if (_side == west) then {
            ATTACK_WAVE_ACTIVE_WEST = true;
            ATTACK_WAVE_WEST_PRICE_MODIFIER = _priceModifier;
        } else {
            ATTACK_WAVE_ACTIVE_EAST = true;
            ATTACK_WAVE_EAST_PRICE_MODIFIER = _priceModifier;
        };

        [_side, -(_side call GetSideSupply),"Heavy attack mode activated."] Call ChangeSideSupply;

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
