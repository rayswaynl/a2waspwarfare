"CLIENT_INIT_READY" addPublicVariableEventHandler {
    private ["_player", "_playerSide"];

    _player = _this select 1;
    if (typeName _player != "OBJECT") exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected malformed CLIENT_INIT_READY payload type [%1].", typeName _player]] Call WFBE_CO_FNC_LogContent;
    };
    if (isNull _player) exitWith {
        ["WARNING", "AttackWave.sqf: rejected CLIENT_INIT_READY payload for null player object."] Call WFBE_CO_FNC_LogContent;
    };
    if (!isPlayer _player) exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected CLIENT_INIT_READY payload for non-player object [%1].", _player]] Call WFBE_CO_FNC_LogContent;
    };
    _playerSide = side _player;
    if (!(_playerSide in [west, east])) exitWith {};

    //--- Set attack mode status properly.
    if (_playerSide == west && ATTACK_WAVE_ACTIVE_WEST) then {
        [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_WEST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
        [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
    } else {
        if (_playerSide == east && ATTACK_WAVE_ACTIVE_EAST) then {
            [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_EAST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
            [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
        };
    };
};


WFBE_SE_FNC_ApplyAttackWaveDetails = {

	private ["_badFields", "_d", "_priceModifier", "_side", "_attackLength", "_attackLengthMinutes", "_priceModifierPercentage"];

	_d = _this;
    if (typeName _d != "ARRAY") exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected malformed ATTACK_WAVE_DETAILS payload type [%1].", typeName _d]] Call WFBE_CO_FNC_LogContent;
    };
    if (count _d < 3) exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected short ATTACK_WAVE_DETAILS payload [%1].", _d]] Call WFBE_CO_FNC_LogContent;
    };
	_side = _d select 0;
	_priceModifier = _d select 1;
    _attackLength = _d select 2;
    _badFields = false;
    if (!(_side in [west, east])) then {_badFields = true};
    if (typeName _priceModifier != "SCALAR") then {_badFields = true};
    if (typeName _attackLength != "SCALAR") then {_badFields = true};
    if (_badFields) exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected invalid ATTACK_WAVE_DETAILS fields side=%1 price=%2 length=%3.", _side, typeName _priceModifier, typeName _attackLength]] Call WFBE_CO_FNC_LogContent;
    };
    if (_priceModifier <= 0) exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with non-positive price modifier [%1].", _priceModifier]] Call WFBE_CO_FNC_LogContent;
    };
    if (_attackLength < 0) exitWith {
        ["WARNING", Format ["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with negative attack length [%1].", _attackLength]] Call WFBE_CO_FNC_LogContent;
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
