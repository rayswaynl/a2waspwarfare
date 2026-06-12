private ['_sourceTown', '_TownSupplyLastMission', '_associatedSupplyTruck', '_supplyAmount', '_supplyMissionAlreadyActiveInTown', '_cursorTarget', '_supplyUpgradeModifier'];

_sourceTown = call GetClosestFriendlyLocation;
WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK = objNull;

missionNamespace setVariable ["WFBE_Client_PV_IsSupplyMissionActiveInTown", [player, _sourceTown]];
publicVariableServer "WFBE_Client_PV_IsSupplyMissionActiveInTown";

_supplyMissionAlreadyActiveInTown = _sourceTown getVariable "supplyMissionCoolDownEnabled";

if (_supplyMissionAlreadyActiveInTown) exitWith {
    diag_log format ["ERROR: Supply mission happened already during the last 30 minutes in %1!", _sourceTown];
    format ["This town doesn't have enough supplies to be collected yet! You can start a supply mission in towns that have [+SUPPLY] added after their SV on map."] call GroupChatMessage;
};

_cursorTarget = cursorTarget;

if (typeOf _cursorTarget in ['WarfareSupplyTruck_RU', 'WarfareSupplyTruck_USMC', 'WarfareSupplyTruck_INS', 'WarfareSupplyTruck_Gue', 'WarfareSupplyTruck_CDF', 'UralSupply_TK_EP1', 'MtvrSupply_DES_EP1'] && (_cursorTarget distance player < 50)) then {
    WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK = _cursorTarget;
    WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyFromTown", _sourceTown, true];

    _supplyUpgradeModifier = 1;

    if ((((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE) >= 3) then {
        _supplyUpgradeModifier = 2;
    };

    if ((((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE) == 2) then {
        _supplyUpgradeModifier = 1.5;
    };

    _supplyAmount = floor ((_sourceTown getVariable "supplyValue") * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _supplyUpgradeModifier);
    
    WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyAmount", _supplyAmount, true];

    format ["You loaded S %1 to your truck from %2. Note that supplies from one town only fit in your truck at a time!", _supplyAmount, str (_sourceTown)] call GroupChatMessage;

    WFBE_Client_PV_SupplyMissionStarted = [player, WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK, _sourceTown, sideJoined];
    publicVariableServer "WFBE_Client_PV_SupplyMissionStarted";
    
} else {
    if (typeOf _cursorTarget in ['WarfareSupplyTruck_RU', 'WarfareSupplyTruck_USMC', 'WarfareSupplyTruck_INS', 'WarfareSupplyTruck_Gue', 'WarfareSupplyTruck_CDF', 'UralSupply_TK_EP1', 'MtvrSupply_DES_EP1'] && (_cursorTarget distance player >= 50)) then {
        format ["Your supply truck is too far away to collect the supply from this town!"] call GroupChatMessage;
    };
};

sleep 0.1;

publicVariableServer "WFBE_Client_PV_IsSupplyMissionActiveInTown";
