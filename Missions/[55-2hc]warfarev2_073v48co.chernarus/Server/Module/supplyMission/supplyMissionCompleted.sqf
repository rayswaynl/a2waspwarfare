
//--- fix(hunt): PVEH body extracted into WFBE_SE_FNC_HandleSupplyMissionCompleted so the server-side
//--- ground-truck completion detector (supplyMissionStarted.sqf) can call it directly. publicVariableServer
//--- executed ON the server never fires the server's own PVEH (engine trap; same extraction pattern as
//--- WFBE_SE_FNC_HandleAttackWaveDetails in AttackWave.sqf), so ground-truck deliveries died silently.
//--- Calling convention: _this IS the payload array [playerObject, supplyTruck, side]. The PVEH at the
//--- bottom still relays the client (helicopter) sender supplyMissionUnload.sqf.
//--- d022: server-local WEST/EAST registry membership is the authority boundary. The broadcast
//--- wfbe_ai_supplytruck object stamp is client UX only and must never authorize a server decision.
WFBE_SE_FNC_IsAISupplyTruck = {
    private ["_candidate", "_found", "_logic", "_registry"];

    _candidate = _this;
    _found = false;
    if (typeName _candidate != "OBJECT") exitWith {false};
    if (isNull _candidate) exitWith {false};

    {
        _logic = _x Call WFBE_CO_FNC_GetSideLogic;
        if (!isNull _logic) then {
            _registry = _logic getVariable "wfbe_ai_supplytrucks";
            if (isNil "_registry") then {_registry = []};
            if (typeName _registry == "ARRAY" && {_candidate in _registry}) then {_found = true};
        };
    } forEach [west,east];

    _found
};

WFBE_SE_FNC_HandleSupplyMissionCompleted = {

    private ['_namePlayer', '_associatedSupplyTruck', '_supplyAmount', '_sourceTown', '_sourceTownStr', '_sidePlayer', '_logMessage', '_byHeli', '_cashRun', '_comTeam', '_airLevel', '_playerObject'];

    _playerObject = _this select 0;
    _associatedSupplyTruck = _this select 1;
    if (_associatedSupplyTruck Call WFBE_SE_FNC_IsAISupplyTruck) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: Rejected AI logistics truck [%1] before player completion side effects.", _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
    };
    _namePlayer = name _playerObject;
    _supplyAmount = _associatedSupplyTruck getVariable "SupplyAmount";
    _sourceTown = _associatedSupplyTruck getVariable "SupplyFromTown";
    _sourceTownStr = str (_sourceTown);
    _sidePlayer = (_this select 2);

    if (isNil "_supplyAmount") then {
        _supplyAmount = 0;
    };

    if (isNil "_sourceTown") then {
        _sourceTown = objNull;
    };

    if ((isNull _sourceTown) || (_supplyAmount <= 0)) exitWith {
        ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Ignored completion for %1 (source:%2 amount:%3).", _associatedSupplyTruck, _sourceTown, _supplyAmount]] call WFBE_CO_FNC_LogContent;
    };

    //--- B74.2: leaderboard supply-run credit to the delivering player (run count + delivered S value). Past the null/<=0 gate above.
    if (!isNull _playerObject) then {private "_supUid"; _supUid = getPlayerUID _playerObject; if (_supUid != "") then {[_supUid, WFBE_STAT_SUPPLY_RUNS, 1] call WFBE_SE_FNC_RecordStat; [_supUid, WFBE_STAT_SUPPLY_VALUE, _supplyAmount] call WFBE_SE_FNC_RecordStat}};

    _byHeli = _associatedSupplyTruck getVariable "SupplyByHeli";
    if (isNil "_byHeli") then { _byHeli = false; };
    _airLevel = ((_sidePlayer) call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIR;
    _cashRun = (_byHeli && (_airLevel >= 4));

    WFBE_Server_PV_SupplyMissionCompletedMessage = [format ["%1 has transported S %2 to base from %3.", _namePlayer, _supplyAmount, _sourceTownStr], _sidePlayer, _supplyAmount, _playerObject, _byHeli, _cashRun];

    if (_cashRun) then {
        //--- Cash run: pilot is paid client-side; commander gets a tithe minted on top. Pool gets nothing.
        _comTeam = (_sidePlayer) call WFBE_CO_FNC_GetCommanderTeam;
        if (!isNull _comTeam) then {
            [_comTeam, round (_supplyAmount * WFBE_C_SUPPLY_HELI_REWARD_MULT * WFBE_C_SUPPLY_CASHRUN_COMMANDER_CUT)] Call WFBE_CO_FNC_ChangeTeamFunds;
        } else {
            //--- B66: no commander to receive the tithe — route the supply to the side pool instead of silently losing it.
            [_sidePlayer, _supplyAmount, format ["Cash-run supply (no commander) by %1. S %2 from %3 routed to pool for team %4.", _namePlayer, _supplyAmount, _sourceTown, _sidePlayer], false] Call ChangeSideSupply;
        };
    } else {
        [_sidePlayer, _supplyAmount, format ["Supply mission completed by %1. S %2 brought from %3 for team %4. ",_namePlayer, _supplyAmount, _sourceTown, _sidePlayer], false] Call ChangeSideSupply;
    };
    _associatedSupplyTruck setVariable ["SupplyAmount", 0, true];
    _associatedSupplyTruck setVariable ["SupplyFromTown", objNull, true];
    _associatedSupplyTruck setVariable ["SupplyByHeli", false, true]; //--- XR3: clear the heli flag too, so a reused vehicle's next run isn't mis-classified as a cash-run.
    _associatedSupplyTruck setVariable ["SupplyLoading", false, true];

    _logMessage = format ["%1 has brought S %2 from %3 to base (SIDE: %4).", _namePlayer, _supplyAmount, _sourceTown, _sidePlayer];

    ["INFORMATION", _logMessage] call WFBE_CO_FNC_LogContent;
    ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Completion accepted (byHeli:%1 cashRun:%2 amount:%3 vehicle:%4).", _byHeli, _cashRun, _supplyAmount, _associatedSupplyTruck]] call WFBE_CO_FNC_LogContent;

    publicVariable "WFBE_Server_PV_SupplyMissionCompletedMessage";

};

"WFBE_Server_PV_SupplyMissionCompleted" addPublicVariableEventHandler {
    //--- Relay the client (helicopter) sender through the extracted handler.
    (_this select 1) Call WFBE_SE_FNC_HandleSupplyMissionCompleted;
};
