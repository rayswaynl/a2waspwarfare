"WFBE_Client_PV_SupplyMissionStarted" addPublicVariableEventHandler {
    (_this select 1) spawn {
        private ['_associatedSupplyTruck', '_associatedSourceTown', '_sidePlayer','_iteratedObject','_friendlyCommandCenterInProximity','_playerObject','_match','_currentSupplyTruckDriverLeader','_playerIsDrivingSupplyTruck','_playerisInProximityOfSupplyTruck','_byHeli','_vp','_cp','_dx','_dy','_ccDwell','_heliCCSeen','_unloadNeed'];
        _playerObject = _this select 0;
        _associatedSupplyTruck = _this select 1;
        _associatedSourceTown = _this select 2;
        _byHeli = _associatedSupplyTruck getVariable "SupplyByHeli";
        if (isNil "_byHeli") then { _byHeli = false; };

        //--- Broadcast (3rd arg): the town-marker supply countdown reads this on CLIENTS —
        //--- without the broadcast every client saw the init value 0 and rendered 0:00 (task 43).
        _associatedSourceTown setVariable ['LastSupplyMissionRun', time, true];

        //--- Interdiction: if the loaded supply vehicle is destroyed, reward the killer's side a share of the cargo.
        if (isNil {_associatedSupplyTruck getVariable "wfbe_supply_killed_eh_set"}) then {
            _associatedSupplyTruck setVariable ["wfbe_supply_killed_eh_set", true, true];
            _associatedSupplyTruck addEventHandler ["Killed", {
            private ["_veh","_killer","_amt","_killerSide","_ownerSideID","_reward"];
            _veh = _this select 0;
            _killer = _this select 1;
            _amt = _veh getVariable "SupplyAmount";
            if (isNil "_amt") then { _amt = 0; };
            if ((_amt > 0) && {!isNull _killer}) then {
                _killerSide = side group _killer;
                //--- Only a genuine ENEMY kill pays interdiction. Guards friendly-fire / self-destruct from minting own-side supply.
                //--- fix(hunt): a loaded truck is typically EMPTY/dead-crewed at kill time, so raw (side _veh) resolves
                //--- CIVILIAN and a SAME-side kill passed this guard (friendly satchel = own-side supply minting).
                //--- Resolve the owner via the authoritative wfbe_side_id stamp (Common_CreateVehicle.sqf:28), engine side fallback.
                _ownerSideID = _veh getVariable ["wfbe_side_id", -1];
                if (_ownerSideID < 0) then { _ownerSideID = (side _veh) Call WFBE_CO_FNC_GetSideID; };
                if ((_killerSide in WFBE_PRESENTSIDES) && {((_killerSide) Call WFBE_CO_FNC_GetSideID) != _ownerSideID}) then {
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
                    //--- Helicopters fly high: qualify on HORIZONTAL (2D) distance to the CC, ignore altitude. Trucks unchanged.
                    _vp = getPos _associatedSupplyTruck; _cp = getPos _x;
                    _dx = (_vp select 0) - (_cp select 0); _dy = (_vp select 1) - (_cp select 1);
                    if ((!_byHeli) || (((_dx*_dx)+(_dy*_dy)) < 6400)) then { _friendlyCommandCenterInProximity = true; };
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
				    //--- fix(hunt): this detector runs ON the server; publicVariableServer here never fires the server's own
				    //--- PVEH (engine trap - see AttackWave.sqf), so ground-truck deliveries were never credited (no supply,
				    //--- no cash, no message). Call the extracted completion handler directly; the heli path (client sender,
				    //--- supplyMissionUnload.sqf) is unchanged.
				    [_playerObject, _associatedSupplyTruck, side _playerObject] Call WFBE_SE_FNC_HandleSupplyMissionCompleted;
                };
            };

        };

    };
};
