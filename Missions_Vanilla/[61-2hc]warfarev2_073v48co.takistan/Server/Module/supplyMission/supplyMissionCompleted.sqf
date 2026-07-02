
"WFBE_Server_PV_SupplyMissionCompleted" addPublicVariableEventHandler {

    private ['_d', '_playerObject', '_namePlayer', '_associatedSupplyTruck', '_supplyAmount', '_sourceTown', '_sourceTownStr', '_sidePlayer', '_requestedSide', '_logMessage', '_byHeli', '_cashRun', '_comTeam', '_airLevel', '_supplyValue', '_upgradeLevel', '_supplyUpgradeModifier', '_expectedSupplyAmount', '_friendlyCommandCenterInProximity', '_vp', '_cp', '_dx', '_dy', '_ccSide', '_ccRange', '_badTown', '_supplySide'];

    _d = _this select 1;
    if (typeName _d != "ARRAY") exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected malformed WFBE_Server_PV_SupplyMissionCompleted payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };
    if (count _d < 3) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected short WFBE_Server_PV_SupplyMissionCompleted payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };

    _playerObject = _d select 0;
    _associatedSupplyTruck = _d select 1;
    _requestedSide = _d select 2;

    if ((typeName _playerObject != "OBJECT") || {typeName _associatedSupplyTruck != "OBJECT"} || {typeName _requestedSide != "SIDE"}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected invalid WFBE_Server_PV_SupplyMissionCompleted field types: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };
    if ((isNull _playerObject) || {isNull _associatedSupplyTruck} || {!alive _playerObject} || {!alive _associatedSupplyTruck} || {!isPlayer _playerObject} || {!(_requestedSide in [west, east])}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected invalid WFBE_Server_PV_SupplyMissionCompleted requester/vehicle: player=%1 vehicle=%2 side=%3", _playerObject, _associatedSupplyTruck, _requestedSide]] Call WFBE_CO_FNC_LogContent;
    };

    _sidePlayer = side _playerObject;
    if ((_sidePlayer != _requestedSide) || {!((typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_VEHICLE_TYPES)}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected invalid WFBE_Server_PV_SupplyMissionCompleted authority: playerSide=%1 requestedSide=%2 vehicle=%3", _sidePlayer, _requestedSide, _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
    };

    _supplySide = _associatedSupplyTruck getVariable ["wfbe_supply_side", _sidePlayer];
    if ((typeName _supplySide != "SIDE") || {_supplySide != _sidePlayer}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected mismatched WFBE_Server_PV_SupplyMissionCompleted supply side: vehicle=%1 stampedSide=%2 playerSide=%3", _associatedSupplyTruck, _supplySide, _sidePlayer]] Call WFBE_CO_FNC_LogContent;
    };

    _supplyAmount = _associatedSupplyTruck getVariable ["SupplyAmount", 0];
    _sourceTown = _associatedSupplyTruck getVariable ["SupplyFromTown", objNull];
    _byHeli = _associatedSupplyTruck getVariable ["SupplyByHeli", false];

    if ((typeName _supplyAmount != "SCALAR") || {typeName _sourceTown != "OBJECT"} || {typeName _byHeli != "BOOL"}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected invalid WFBE_Server_PV_SupplyMissionCompleted supply fields: amount=%1 source=%2 byHeli=%3 vehicle=%4", _supplyAmount, _sourceTown, _byHeli, _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
    };

    _badTown = false;
    if (!isNil "towns") then {
        if (!(_sourceTown in towns)) then {_badTown = true};
    };
    if (_badTown) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected invalid WFBE_Server_PV_SupplyMissionCompleted source town: %1", _sourceTown]] Call WFBE_CO_FNC_LogContent;
    };

    if ((isNull _sourceTown) || (_supplyAmount <= 0)) exitWith {
        ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Ignored completion for %1 (source:%2 amount:%3).", _associatedSupplyTruck, _sourceTown, _supplyAmount]] call WFBE_CO_FNC_LogContent;
    };

    if ((_sourceTown getVariable ["sideID", -99]) != (_sidePlayer Call WFBE_CO_FNC_GetSideID)) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected non-friendly WFBE_Server_PV_SupplyMissionCompleted source town %1 for %2.", _sourceTown, _sidePlayer]] Call WFBE_CO_FNC_LogContent;
    };

    _expectedSupplyAmount = _associatedSupplyTruck getVariable ["SupplyExpectedMax", -1];
    if ((typeName _expectedSupplyAmount != "SCALAR") || {_expectedSupplyAmount <= 0}) then {
        _supplyValue = _sourceTown getVariable ["supplyValue", -1];
        if (typeName _supplyValue == "SCALAR") then {
            _upgradeLevel = ((_sidePlayer) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE;
            _supplyUpgradeModifier = 1;
            if (_upgradeLevel >= 3) then { _supplyUpgradeModifier = 2; };
            if (_upgradeLevel == 2) then { _supplyUpgradeModifier = 1.5; };
            _expectedSupplyAmount = floor (_supplyValue * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _supplyUpgradeModifier);
        } else {
            _expectedSupplyAmount = -1;
        };
    };
    if ((typeName _expectedSupplyAmount != "SCALAR") || {_expectedSupplyAmount <= 0} || {_supplyAmount > _expectedSupplyAmount}) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected overfilled WFBE_Server_PV_SupplyMissionCompleted vehicle %1 amount=%2 max=%3 source=%4.", _associatedSupplyTruck, _supplyAmount, _expectedSupplyAmount, _sourceTown]] Call WFBE_CO_FNC_LogContent;
    };

    _friendlyCommandCenterInProximity = false;
    _ccRange = if (_byHeli) then {400} else {80};
    {
        if (_x isKindOf "Base_WarfareBUAVterminal") then {
            _ccSide = _x getVariable ["wfbe_side", sideLogic];
            _vp = getPos _associatedSupplyTruck;
            _cp = getPos _x;
            _dx = (_vp select 0) - (_cp select 0);
            _dy = (_vp select 1) - (_cp select 1);
            if ((_ccSide == _sidePlayer) && {(!_byHeli) || (((_dx * _dx) + (_dy * _dy)) < 6400)}) then {_friendlyCommandCenterInProximity = true};
        };
    } forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], _ccRange]);
    if (!_friendlyCommandCenterInProximity) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: rejected WFBE_Server_PV_SupplyMissionCompleted away from friendly Command Center: vehicle=%1 side=%2 byHeli=%3", _associatedSupplyTruck, _sidePlayer, _byHeli]] Call WFBE_CO_FNC_LogContent;
    };

    _namePlayer = name _playerObject;
    _sourceTownStr = str (_sourceTown);

    //--- B74.2: leaderboard supply-run credit to the delivering player (run count + delivered S value). Past the null/<=0 gate above.
    if (!isNull _playerObject) then {private "_supUid"; _supUid = getPlayerUID _playerObject; if (_supUid != "") then {[_supUid, WFBE_STAT_SUPPLY_RUNS, 1] call WFBE_SE_FNC_RecordStat; [_supUid, WFBE_STAT_SUPPLY_VALUE, _supplyAmount] call WFBE_SE_FNC_RecordStat}};

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
    _associatedSupplyTruck setVariable ["SupplyExpectedMax", 0, true];
    _associatedSupplyTruck setVariable ["wfbe_supply_side", sideLogic, true];

    _logMessage = format ["%1 has brought S %2 from %3 to base (SIDE: %4).", _namePlayer, _supplyAmount, _sourceTown, _sidePlayer];

    ["INFORMATION", _logMessage] call WFBE_CO_FNC_LogContent;
    ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Completion accepted (byHeli:%1 cashRun:%2 amount:%3 vehicle:%4).", _byHeli, _cashRun, _supplyAmount, _associatedSupplyTruck]] call WFBE_CO_FNC_LogContent;

    publicVariable "WFBE_Server_PV_SupplyMissionCompletedMessage";

};
