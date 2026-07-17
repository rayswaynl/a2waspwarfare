private ['_sourceTown', '_associatedSupplyTruck', '_supplyAmount', '_supplyMissionAlreadyActiveInTown', '_cursorTarget', '_supplyUpgradeModifier', '_type', '_upgradeLevel', '_isTruck', '_isHeli', '_isHeliType', '_eligible', '_byHeli', '_airLevel', '_loadOk', '_t', '_loadedAmount', '_loadLock', '_cancelReason'];

_sourceTown = call GetClosestFriendlyLocation;
if (isNull _sourceTown) exitWith {
	format ["No friendly town is available for a supply mission."] call GroupChatMessage;
};
WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK = objNull;

missionNamespace setVariable ["WFBE_Client_PV_IsSupplyMissionActiveInTown", [player, _sourceTown]];
publicVariableServer "WFBE_Client_PV_IsSupplyMissionActiveInTown";

_supplyMissionAlreadyActiveInTown = _sourceTown getVariable ["supplyMissionCoolDownEnabled", false];

if (_supplyMissionAlreadyActiveInTown) exitWith {
    diag_log format ["ERROR: Supply mission happened already during the last 30 minutes in %1!", _sourceTown];
    format ["This town doesn't have enough supplies to be collected yet! You can start a supply mission in towns that have [+SUPPLY] added after their SV on map."] call GroupChatMessage;
};

_cursorTarget = cursorTarget;
if (isNull _cursorTarget) exitWith {
    format ["Aim at an empty supply truck, or at an empty supply helicopter once Aircraft Factory is level 3."] call GroupChatMessage;
};

_type = typeOf _cursorTarget;
_isTruck = _type in WFBE_C_SUPPLY_TRUCK_TYPES;
_isHeliType = _type in WFBE_C_SUPPLY_HELI_TYPES;
if (!_isTruck && !_isHeliType) exitWith {
    format ["%1 is not a supply vehicle.", if (_type == "") then {"That target"} else {_type}] call GroupChatMessage;
};

_upgradeLevel = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE;
_airLevel = ((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIR;
_loadedAmount = _cursorTarget getVariable ["SupplyAmount", 0];
if (_loadedAmount > 0) exitWith {
    format ["This supply vehicle is already loaded with S %1. Deliver it to your Command Center before loading again.", _loadedAmount] call GroupChatMessage;
};
_loadLock = _cursorTarget getVariable ["SupplyLoading", false];
if (_loadLock) exitWith {
    format ["This supply vehicle is already loading supplies. Wait for the current load to finish or cancel."] call GroupChatMessage;
};

//--- Eligibility: trucks always; the supply helicopter needs Aircraft Factory upgrade level 3.
_isHeli = _isHeliType && (_airLevel >= 3);
_eligible = _isTruck || _isHeli;
_byHeli   = _isHeli;

//--- Locked helo? Explain the requirement instead of silently doing nothing.
if (!_eligible && _isHeliType) exitWith {
    format ["Supply helicopters need the Aircraft Factory upgraded to level 3."] call GroupChatMessage;
};

if (_byHeli && (vehicle player != player)) exitWith {
    format ["Exit the helicopter and stay outside for %1 seconds while supplies are loaded.", WFBE_C_SUPPLY_HELI_LOAD_TIME] call GroupChatMessage;
};

if (_eligible && (_cursorTarget distance player < 50)) then {
    WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK = _cursorTarget;
    WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyLoading", true, true];
    if (_byHeli) then {_sourceTown setVariable ["supplyMissionCoolDownEnabled", true, true]};

    _supplyUpgradeModifier = 1;
    if (_upgradeLevel >= 3) then { _supplyUpgradeModifier = 2; };
    if (_upgradeLevel == 2) then { _supplyUpgradeModifier = 1.5; };
    _supplyAmount = floor ((_sourceTown getVariable "supplyValue") * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _supplyUpgradeModifier);

    //--- Helicopters take time to load: channel the load while you stay next to the aircraft.
    _loadOk = true;
    _cancelReason = "you must stay next to the helicopter while it loads.";
    if (_byHeli) then {
        _t = 0;
        while {_t < WFBE_C_SUPPLY_HELI_LOAD_TIME} do {
            if (!alive _cursorTarget) exitWith { _loadOk = false; _cancelReason = "the helicopter was destroyed."; };
            if (vehicle player != player) exitWith { _loadOk = false; _cancelReason = "you entered a vehicle before loading finished."; };
            if (player distance _cursorTarget > 15) exitWith { _loadOk = false; _cancelReason = "you moved too far away from the helicopter."; };
            titleText [format ["Loading supplies into the helicopter...  %1 / %2 s", floor _t, WFBE_C_SUPPLY_HELI_LOAD_TIME], "PLAIN DOWN", 0.05];
            sleep 1;
            _t = _t + 1;
        };
    };

    if (_loadOk) then {
        WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyFromTown", _sourceTown, true];
        WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyByHeli", _byHeli, true];
        WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyAmount", _supplyAmount, true];
        WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyLoading", false, true];
        _sourceTown setVariable ["supplyMissionCoolDownEnabled", true, true];

        format ["You loaded S %1 to your vehicle from %2. Note that supplies from one town only fit in your vehicle at a time!", _supplyAmount, str (_sourceTown)] call GroupChatMessage;
        ["INFORMATION", Format ["SupplyMissionStart.sqf: Player %1 loaded S %2 from %3 into %4 (byHeli:%5).", name player, _supplyAmount, _sourceTown, WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK, _byHeli]] Call WFBE_CO_FNC_LogContent;

        WFBE_Client_PV_SupplyMissionStarted = [player, WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK, _sourceTown, sideJoined];
        publicVariableServer "WFBE_Client_PV_SupplyMissionStarted";
    } else {
        WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyLoading", false, true];
        if (_byHeli) then {_sourceTown setVariable ["supplyMissionCoolDownEnabled", false, true]};
        titleText ["Loading cancelled.", "PLAIN DOWN", 0.05];
        format ["Loading cancelled - %1", _cancelReason] call GroupChatMessage;
        ["INFORMATION", Format ["supplyMissionStart.sqf: Helicopter loading cancelled for [%1], reason [%2].", player, _cancelReason]] Call WFBE_CO_FNC_LogContent;
    };

} else {
    if (_eligible && (_cursorTarget distance player >= 50)) then {
        format ["Your supply vehicle is too far away to collect the supply from this town!"] call GroupChatMessage;
    };
};

sleep 0.1;

publicVariableServer "WFBE_Client_PV_IsSupplyMissionActiveInTown";
