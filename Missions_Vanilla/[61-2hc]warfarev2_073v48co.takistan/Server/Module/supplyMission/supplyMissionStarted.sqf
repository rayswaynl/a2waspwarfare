"WFBE_Client_PV_SupplyMissionStarted" addPublicVariableEventHandler {
    private ['_d','_playerObject','_associatedSupplyTruck','_associatedSourceTown','_sidePlayer','_supplyAmount','_supplyValue','_upgradeLevel','_supplyUpgradeModifier','_expectedSupplyAmount','_townSide','_badTown'];

    _d = _this select 1;
    if (typeName _d != "ARRAY") exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected malformed WFBE_Client_PV_SupplyMissionStarted payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };
    if (count _d < 4) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected short WFBE_Client_PV_SupplyMissionStarted payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };

    _playerObject = _d select 0;
    _associatedSupplyTruck = _d select 1;
    _associatedSourceTown = _d select 2;
    _sidePlayer = _d select 3;

    if (
        (typeName _playerObject != "OBJECT") ||
        (typeName _associatedSupplyTruck != "OBJECT") ||
        (typeName _associatedSourceTown != "OBJECT") ||
        (typeName _sidePlayer != "SIDE")
    ) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected invalid WFBE_Client_PV_SupplyMissionStarted field types: %1", _d]] Call WFBE_CO_FNC_LogContent;
    };
    if (
        (isNull _playerObject) ||
        {isNull _associatedSupplyTruck} ||
        {isNull _associatedSourceTown} ||
        {!alive _playerObject} ||
        {!alive _associatedSupplyTruck} ||
        {!isPlayer _playerObject} ||
        {!(_sidePlayer in [west, east])} ||
        {side _playerObject != _sidePlayer} ||
        {!((typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_VEHICLE_TYPES)} ||
        {_associatedSupplyTruck distance _playerObject > 80}
    ) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected invalid WFBE_Client_PV_SupplyMissionStarted authority: player=%1 vehicle=%2 town=%3 side=%4", _playerObject, _associatedSupplyTruck, _associatedSourceTown, _sidePlayer]] Call WFBE_CO_FNC_LogContent;
    };
    _badTown = false;
    if (!isNil "towns") then {
        if (!(_associatedSourceTown in towns)) then {_badTown = true};
    };
    if (_badTown) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected invalid WFBE_Client_PV_SupplyMissionStarted town: %1", _associatedSourceTown]] Call WFBE_CO_FNC_LogContent;
    };

    _townSide = _associatedSourceTown getVariable ["sideID", -99];
    if (_townSide != (_sidePlayer Call WFBE_CO_FNC_GetSideID)) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected non-friendly WFBE_Client_PV_SupplyMissionStarted town %1 for %2.", _associatedSourceTown, _sidePlayer]] Call WFBE_CO_FNC_LogContent;
    };

    _supplyAmount = _associatedSupplyTruck getVariable ["SupplyAmount", 0];
    _supplyValue = _associatedSourceTown getVariable ["supplyValue", -1];
    if ((typeName _supplyAmount != "SCALAR") || {typeName _supplyValue != "SCALAR"} || {_supplyAmount <= 0} || {_supplyValue <= 0}) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected invalid WFBE_Client_PV_SupplyMissionStarted supply values: amount=%1 townSV=%2 vehicle=%3 town=%4", _supplyAmount, _supplyValue, _associatedSupplyTruck, _associatedSourceTown]] Call WFBE_CO_FNC_LogContent;
    };

    _upgradeLevel = ((_sidePlayer) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE;
    _supplyUpgradeModifier = 1;
    if (_upgradeLevel >= 3) then { _supplyUpgradeModifier = 2; };
    if (_upgradeLevel == 2) then { _supplyUpgradeModifier = 1.5; };
    _expectedSupplyAmount = floor (_supplyValue * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _supplyUpgradeModifier);
    if (_supplyAmount > _expectedSupplyAmount) exitWith {
        ["WARNING", Format ["SupplyMissionStarted.sqf: rejected overfilled WFBE_Client_PV_SupplyMissionStarted vehicle %1 amount=%2 max=%3 town=%4.", _associatedSupplyTruck, _supplyAmount, _expectedSupplyAmount, _associatedSourceTown]] Call WFBE_CO_FNC_LogContent;
    };

    _associatedSupplyTruck setVariable ["SupplyExpectedMax", _expectedSupplyAmount, true];
    _associatedSupplyTruck setVariable ["wfbe_supply_side", _sidePlayer, true];

    [_playerObject, _associatedSupplyTruck, _associatedSourceTown, _sidePlayer] spawn {
        private ['_associatedSupplyTruck', '_associatedSourceTown', '_sidePlayer','_iteratedObject','_friendlyCommandCenterInProximity','_playerObject','_match','_currentSupplyTruckDriverLeader','_playerIsDrivingSupplyTruck','_playerisInProximityOfSupplyTruck','_byHeli','_vp','_cp','_dx','_dy','_ccDwell','_heliCCSeen','_unloadNeed','_iteratedPlayerUID','_leaderGroupIteratedObject','_iteratedObjectDriver','_ccSide'];
        _playerObject = _this select 0;
        _associatedSupplyTruck = _this select 1;
        _associatedSourceTown = _this select 2;
        _sidePlayer = _this select 3;
        _byHeli = _associatedSupplyTruck getVariable "SupplyByHeli";
        if (isNil "_byHeli") then { _byHeli = false; };

        //--- Broadcast (3rd arg): the town-marker supply countdown reads this on CLIENTS —
        //--- without the broadcast every client saw the init value 0 and rendered 0:00 (task 43).
        _associatedSourceTown setVariable ['LastSupplyMissionRun', time, true];

        //--- Interdiction: if the loaded supply vehicle is destroyed, reward the killer's side a share of the cargo.
        if (isNil {_associatedSupplyTruck getVariable "wfbe_supply_killed_eh_set"}) then {
            _associatedSupplyTruck setVariable ["wfbe_supply_killed_eh_set", true, true];
            _associatedSupplyTruck addEventHandler ["Killed", {
            private ["_veh","_killer","_amt","_killerSide","_reward"];
            _veh = _this select 0;
            _killer = _this select 1;
            _amt = _veh getVariable "SupplyAmount";
            if (isNil "_amt") then { _amt = 0; };
            if ((_amt > 0) && {!isNull _killer}) then {
                _killerSide = side group _killer;
                //--- Only a genuine ENEMY kill pays interdiction. Guards friendly-fire / self-destruct from minting own-side supply.
                if ((_killerSide in WFBE_PRESENTSIDES) && {_killerSide != (_veh getVariable ["wfbe_supply_side", side _veh])}) then {
                    _reward = round (_amt * WFBE_C_SUPPLY_INTERDICTION_CUT);
                    [_killerSide, _reward, format ["Logistics interdiction: enemy supply vehicle destroyed (+S %1).", _reward], false] call ChangeSideSupply;
                };
                _veh setVariable ["SupplyAmount", 0, true];
            };
        }];
        };

        _friendlyCommandCenterInProximity = false;
        _playerisInProximityOfSupplyTruck = false;
        _playerIsDrivingSupplyTruck = false;
        
        _match = false;

        ["INFORMATION", Format ["SupplyMissionStarted.sqf: Player %1 started supply mission in town %2.",(name leader group _playerObject), _associatedSourceTown]] Call WFBE_CO_FNC_LogContent;

        [_associatedSourceTown] spawn WFBE_SE_FNC_SupplyMissionTimerForTown;

        _ccDwell = 0;
        _heliCCSeen = false;
        _unloadNeed = if (_byHeli) then { WFBE_C_SUPPLY_HELI_UNLOAD_TIME } else { 0 };

        while { alive _associatedSupplyTruck } do {
            sleep 1;
            if ((_associatedSupplyTruck getVariable ["SupplyAmount", 0]) <= 0) exitWith {};

            _friendlyCommandCenterInProximity = false;
            {
                if (_x isKindOf "Base_WarfareBUAVterminal") then {
                    _ccSide = _x getVariable ["wfbe_side", sideLogic];
                    //--- Helicopters fly high: qualify on HORIZONTAL (2D) distance to the CC, ignore altitude. Trucks unchanged.
                    _vp = getPos _associatedSupplyTruck; _cp = getPos _x;
                    _dx = (_vp select 0) - (_cp select 0); _dy = (_vp select 1) - (_cp select 1);
                    if ((_ccSide == _sidePlayer) && {(!_byHeli) || (((_dx*_dx)+(_dy*_dy)) < 6400)}) then { _friendlyCommandCenterInProximity = true; };
                };
            } forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]);

            if (_friendlyCommandCenterInProximity) then { _ccDwell = _ccDwell + 1; } else { _ccDwell = 0; };
            if (_byHeli && _friendlyCommandCenterInProximity && !_heliCCSeen) then {
                _heliCCSeen = true;
                ["INFORMATION", Format ["SupplyMissionStarted.sqf: Helicopter supply vehicle %1 reached Command Center area; waiting for manual UNLOAD SUPPLIES.", _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
            };

            if ((!_byHeli) && _friendlyCommandCenterInProximity && (_ccDwell >= _unloadNeed)) exitWith {
                {
                    _iteratedPlayerUID = _x select 1;
                    // diag_log format ["_associatedSupplyTruck: %1, leader group: %2, getPlayerUID leader group _associatedSupplyTruck: %3, _iteratedPlayerUID: %4, _playerObject: %5", _associatedSupplyTruck, leader group _associatedSupplyTruck, getPlayerUID leader group _associatedSupplyTruck, _iteratedPlayerUID, _playerObject];
                    
                    {
                        _iteratedObject = _x;
                        _leaderGroupIteratedObject = leader group _iteratedObject;

                        if ((isPlayer _leaderGroupIteratedObject) && (getPlayerUID (_leaderGroupIteratedObject) == _iteratedPlayerUID)) then {
                            _playerisInProximityOfSupplyTruck = true;
                            _playerObject = _leaderGroupIteratedObject;
                            // diag_log format ["_playerIsInProximityOfSupplyTruck, _iteratedObject: %1, _leaderGroupIteratedObject: %2", _iteratedObject, _leaderGroupIteratedObject];
                        };
                    } forEach (nearestObjects [(getPos _associatedSupplyTruck), [], 8]);


                    _playerIsDrivingSupplyTruck = ((getPlayerUID (leader group _associatedSupplyTruck)) == _iteratedPlayerUID);

                    if (_playerIsDrivingSupplyTruck && (isNull _playerObject)) then {
                        _iteratedObjectDriver = _x select 0;
                        if (!(isNull _iteratedObjectDriver)) then {
                            _playerObject = _iteratedObjectDriver;
                        };
                        // diag_log format ["_playerObject (_iteratedObjectDriver): %1", _playerObject];
                    };
                    
                } forEach (WFBE_SE_PLAYERLIST);

                // diag_log format ["_playerObject/_currentSupplyTruckDriverLeader: %1", _playerObject];

                _match = !(isNull _playerObject);

                if (_match) then {
				    WFBE_Server_PV_SupplyMissionCompleted = [_playerObject, _associatedSupplyTruck, side _playerObject];
				    publicVariableServer "WFBE_Server_PV_SupplyMissionCompleted";
                };
            };

        };

    };
};
