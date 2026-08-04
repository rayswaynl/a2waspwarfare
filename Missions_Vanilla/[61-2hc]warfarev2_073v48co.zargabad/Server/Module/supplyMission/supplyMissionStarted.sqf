"WFBE_Client_PV_SupplyMissionStarted" addPublicVariableEventHandler {
    (_this select 1) spawn {
        private ['_associatedSupplyTruck', '_associatedSourceTown', '_sidePlayer','_iteratedObject','_friendlyCommandCenterInProximity','_playerObject','_match','_currentSupplyTruckDriverLeader','_playerIsDrivingSupplyTruck','_playerisInProximityOfSupplyTruck','_byHeli','_vp','_cp','_dx','_dy','_ccDwell','_heliCCSeen','_unloadNeed','_loaderSide','_sideStructures','_ccSide','_friendlyCC','_creditPlayer','_iteratedPlayerUID','_leaderGroupIteratedObject','_truckDriver','_deliveryDone','_nearTruck'];
        _playerObject = _this select 0;
        _associatedSupplyTruck = _this select 1;
        _associatedSourceTown = _this select 2;
        //--- byHeli from vehicle class (server truth). Client-stamped SupplyByHeli can desync unload vs auto-complete path.
        _byHeli = (typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_HELI_TYPES;
        //--- Mission side captured from the starter for CC ownership checks (not re-read after credit reassignment).
        _loaderSide = if (isNull _playerObject) then { sideUnknown } else { side group _playerObject };

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
        _deliveryDone = false;

        ["INFORMATION", Format ["SupplyMissionStarted.sqf: Player %1 started supply mission in town %2.",(name leader group _playerObject), _associatedSourceTown]] Call WFBE_CO_FNC_LogContent;

        [_associatedSourceTown] spawn WFBE_SE_FNC_SupplyMissionTimerForTown;

        _ccDwell = 0;
        _heliCCSeen = false;
        _unloadNeed = if (_byHeli) then { WFBE_C_SUPPLY_HELI_UNLOAD_TIME } else { 0 };
        _sideStructures = _loaderSide Call WFBE_CO_FNC_GetSideStructures;

        //--- _deliveryDone flag (not exitWith on the CC branch): if the truck is near a friendly CC but no
        //--- delivering player is present yet, keep polling until a driver/nearby player shows up or cargo clears.
        while { alive _associatedSupplyTruck && {!_deliveryDone} } do {
            sleep 1;
            //--- Post-sleep null/deleted guard: the truck can be deleted during the 1s yield (empty-vehicle
            //--- reaper, combat, admin cleanup). A2OA 2-arg getVariable on null ignores the default, and
            //--- getPos/nearestObjects on a deleted handle is native-crash class (same family as TrashObject
            //--- post-sleep / AICOM supply TOCTOU drafts — this is the PLAYER supply mission loop, not those).
            if (isNull _associatedSupplyTruck) exitWith {};
            if ((_associatedSupplyTruck getVariable ["SupplyAmount", 0]) <= 0) exitWith {};

            _friendlyCommandCenterInProximity = false;
            {
                if (_x isKindOf "Base_WarfareBUAVterminal") then {
                    //--- BUG fix: only OWN-side Command Centers count (name claimed "friendly"; code accepted any side).
                    _ccSide = _x getVariable ["wfbe_side", sideUnknown];
                    _friendlyCC = false;
                    if (_ccSide == _loaderSide) then { _friendlyCC = true; };
                    if (!_friendlyCC) then {
                        if (_x in _sideStructures) then { _friendlyCC = true; };
                    };
                    if (_friendlyCC) then {
                        //--- Helicopters fly high: qualify on HORIZONTAL (2D) distance to the CC, ignore altitude. Trucks unchanged.
                        _vp = getPos _associatedSupplyTruck; _cp = getPos _x;
                        _dx = (_vp select 0) - (_cp select 0); _dy = (_vp select 1) - (_cp select 1);
                        if ((!_byHeli) || (((_dx*_dx)+(_dy*_dy)) < 6400)) then { _friendlyCommandCenterInProximity = true; };
                    };
                };
            } forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]);

            if (_friendlyCommandCenterInProximity) then { _ccDwell = _ccDwell + 1; } else { _ccDwell = 0; };
            if (_byHeli && _friendlyCommandCenterInProximity && !_heliCCSeen) then {
                _heliCCSeen = true;
                ["INFORMATION", Format ["SupplyMissionStarted.sqf: Helicopter supply vehicle %1 reached Command Center area; waiting for manual UNLOAD SUPPLIES.", _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
            };

            if ((!_byHeli) && _friendlyCommandCenterInProximity && (_ccDwell >= _unloadNeed)) then {
                //--- perf: the supply-truck position is fixed for this whole pass (no sleep between
                //--- iterations), so the identical nearestObjects 8m sphere was being rescanned once per
                //--- player in WFBE_SE_PLAYERLIST. Hoist it once and reuse - behaviour-identical (same objects),
                //--- N scans -> 1 scan.
                _nearTruck = nearestObjects [(getPos _associatedSupplyTruck), [], 8];

                //--- BUG fix: do NOT default credit to the start-PV player. Require a living deliverer who is
                //--- driving the truck or standing next to it (teammate relay still works; remote starter does not).
                _creditPlayer = objNull;
                _playerisInProximityOfSupplyTruck = false;
                _playerIsDrivingSupplyTruck = false;
                _truckDriver = driver _associatedSupplyTruck;
                {
                    _iteratedPlayerUID = _x select 1;

                    {
                        _iteratedObject = _x;
                        //--- Prefer the near unit itself when it is a player (not only its group leader who may be remote).
                        if ((isPlayer _iteratedObject) && {(getPlayerUID _iteratedObject) == _iteratedPlayerUID}) then {
                            _playerisInProximityOfSupplyTruck = true;
                            _creditPlayer = _iteratedObject;
                        } else {
                            _leaderGroupIteratedObject = leader group _iteratedObject;
                            if ((isPlayer _leaderGroupIteratedObject) && {(getPlayerUID _leaderGroupIteratedObject) == _iteratedPlayerUID}) then {
                                //--- Squad member near truck, leader is the list row: only credit leader if THEY are also near.
                                if ((_leaderGroupIteratedObject distance _associatedSupplyTruck) <= 8) then {
                                    _playerisInProximityOfSupplyTruck = true;
                                    _creditPlayer = _leaderGroupIteratedObject;
                                };
                            };
                        };
                    } forEach _nearTruck;

                    if (!(isNull _truckDriver) && {isPlayer _truckDriver} && {(getPlayerUID _truckDriver) == _iteratedPlayerUID}) then {
                        _playerIsDrivingSupplyTruck = true;
                        _creditPlayer = _truckDriver;
                    };

                } forEach (WFBE_SE_PLAYERLIST);

                _match = (_playerIsDrivingSupplyTruck || _playerisInProximityOfSupplyTruck) && {!isNull _creditPlayer} && {isPlayer _creditPlayer};

                if (_match) then {
				    //--- fix(hunt): this detector runs ON the server; publicVariableServer here never fires the server's own
				    //--- PVEH (engine trap - see AttackWave.sqf), so ground-truck deliveries were never credited (no supply,
				    //--- no cash, no message). Call the extracted completion handler directly; the heli path (client sender,
				    //--- supplyMissionUnload.sqf) is unchanged.
				    [_creditPlayer, _associatedSupplyTruck, side group _creditPlayer] Call WFBE_SE_FNC_HandleSupplyMissionCompleted;
                    _deliveryDone = true;
                };
            };

        };

    };
};
