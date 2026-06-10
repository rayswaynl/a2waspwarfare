
"WFBE_Server_PV_SupplyMissionCompletedMessage" addPublicVariableEventHandler {
    
    private ["_message", "_side", "_byHeli", "_cashRun", "_reward", "_scoreGain"];

    _message = (_this select 1) select 0;
    _side = (_this select 1) select 1;
    _supplyAmount = (_this select 1) select 2;
    _playerObject = (_this select 1) select 3;
    _byHeli = (_this select 1) select 4;
    _cashRun = (_this select 1) select 5;
    if (isNil "_byHeli") then { _byHeli = false; };
    if (isNil "_cashRun") then { _cashRun = false; };

    //--- #5: air delivery pays the pilot 25% more.
    _reward = _supplyAmount;
    if (_byHeli) then { _reward = round (_supplyAmount * WFBE_C_SUPPLY_HELI_REWARD_MULT); };
    
    if ((side player) == _side) then {
        if (_playerObject == player) then {
            (_reward) call ChangePlayerFunds;
            _message = format ["You completed a %1 supply run and earned $%2%3.", (if (_byHeli) then {"HELI"} else {"truck"}), _reward, (if (_cashRun) then {" (cash run)"} else {""})];
            _message call GroupChatMessage;
        } else {
            _message call CommandChatMessage;
        };
    };

    if (player == _playerObject) then {
        _scoreGain = round ((_supplyAmount / 100) * WFBE_SUPPLY_MISSION_SCORE_COEF);
        if (_byHeli) then { _scoreGain = round (_scoreGain * WFBE_C_SUPPLY_HELI_REWARD_MULT); };
        ["RequestChangeScore", [player, (score player + _scoreGain)]] Call WFBE_CO_FNC_SendToServer;
    };
};