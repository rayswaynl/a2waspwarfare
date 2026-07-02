"CLIENT_INIT_READY" addPublicVariableEventHandler {
    private ["_player"];

    if (count _this < 2) exitWith {};
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

	private ["_priceModifier", "_side", "_attackLength", "_attackLengthMinutes", "_priceModifierPercentage", "_payload"];

	_payload = _this select 1;
	if (!((typeName _payload) == "ARRAY") || {count _payload < 3}) exitWith {
		["WARNING","AttackWave.sqf: ATTACK_WAVE_DETAILS payload malformed, ignoring."] call WFBE_CO_FNC_LogContent;
	};

	_side = (_payload select 0);
	_priceModifier = (_payload select 1);
    _attackLength = (_payload select 2);

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