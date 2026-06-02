
"WFBE_Server_PV_SupplyMissionCompletedMessage" addPublicVariableEventHandler {
    
    private ["_message", "_side"];

    _message = (_this select 1) select 0;
    _side = (_this select 1) select 1;
    _supplyAmount = (_this select 1) select 2;
    _playerObject = (_this select 1) select 3;
    
    if ((side player) == _side) then {
        if (_playerObject == player) then {
            (_supplyAmount) call ChangePlayerFunds;
            _message = format ["You have successfully completed a supply mission and earned $%1 as a reward.", _supplyAmount];
            _message call GroupChatMessage;
        } else {
            _message call CommandChatMessage;
        };
    };

    if (player == _playerObject) then {
        ["RequestChangeScore", [player, (score player + (round ((_supplyAmount / 100) * WFBE_SUPPLY_MISSION_SCORE_COEF)))]] Call WFBE_CO_FNC_SendToServer;
    };
};