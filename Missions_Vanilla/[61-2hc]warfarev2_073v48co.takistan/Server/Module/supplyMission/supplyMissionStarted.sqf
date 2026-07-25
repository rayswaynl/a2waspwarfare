"WFBE_Client_PV_SupplyMissionStarted" addPublicVariableEventHandler {
    (_this select 1) spawn {
        private ['_associatedSupplyTruck', '_associatedSourceTown', '_sidePlayer','_iteratedObject','_friendlyCommandCenterInProximity','_playerObject','_match','_currentSupplyTruckDriverLeader','_playerIsDrivingSupplyTruck','_playerisInProximityOfSupplyTruck','_byHeli','_vp','_cp','_dx','_dy','_ccDwell','_heliCCSeen','_unloadNeed'];
        private ['_secHardened','_hardenReject','_hardenReason','_uidStart','_regArr','_activeCount','_capMax','_upgLvl','_modAmt','_realAmount','_regEntry'];
        _playerObject = _this select 0;
        _associatedSupplyTruck = _this select 1;
        _associatedSourceTown = _this select 2;
        _byHeli = _associatedSupplyTruck getVariable "SupplyByHeli";
        if (isNil "_byHeli") then { _byHeli = false; };

        //--- SECURITY (harden-supplymission, DR-55/WFBE_C_SEC_HARDENING family, Findings 1+2): flagged.
        //--- OFF (default) = byte-identical legacy behaviour below. ON = the server registers THIS instance
        //--- of the mission as its own source of truth (truck/uid/side/amount/byHeli/town) before spawning
        //--- the watcher, so supplyMissionCompleted.sqf can pay out from server state instead of the
        //--- client-stamped truck variables, and so a forged/duplicate/flooded start never spawns a thread.
        //--- Amount is re-derived here with the SAME formula supplyMissionStart.sqf uses, off server-owned
        //--- supplyValue/upgrade state (never trusted from the client), then clamped to the town's own
        //--- registered max as defence in depth.
        _secHardened = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;
        _hardenReject = false;
        _hardenReason = "";
        if (_secHardened) then {
            if (isNull _associatedSupplyTruck) then { _hardenReject = true; _hardenReason = "null truck"; };
            if (!_hardenReject && {isNull _playerObject}) then { _hardenReject = true; _hardenReason = "null player"; };
            if (!_hardenReject && {!isPlayer _playerObject}) then { _hardenReject = true; _hardenReason = "player object is not a player"; };
            if (!_hardenReject && {!alive _playerObject}) then { _hardenReject = true; _hardenReason = "player is not alive"; };
            if (!_hardenReject && {!alive _associatedSupplyTruck}) then { _hardenReject = true; _hardenReason = "truck is not alive"; };
            if (!_hardenReject && {!((typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_VEHICLE_TYPES)}) then { _hardenReject = true; _hardenReason = "truck type is not a supply vehicle"; };
            if (!_hardenReject && {typeName _associatedSourceTown != "OBJECT" || {isNull _associatedSourceTown}}) then { _hardenReject = true; _hardenReason = "invalid source town"; };
            if (!_hardenReject && {isNil {_associatedSourceTown getVariable "supplyValue"}}) then { _hardenReject = true; _hardenReason = "source town has no supplyValue"; };

            _regArr = [];
            if (!_hardenReject) then {
                _regArr = missionNamespace getVariable ["WFBE_SE_ACTIVE_SUPPLY_MISSIONS", []];
                if (typeName _regArr != "ARRAY") then { _regArr = []; };
                //--- Dedup: this exact truck must not already be an active registered mission.
                {
                    if (!_hardenReject && {(_x select 0) == _associatedSupplyTruck}) then { _hardenReject = true; _hardenReason = "truck already has an active registered mission"; };
                } forEach _regArr;
            };

            _uidStart = "";
            if (!_hardenReject) then {
                //--- Finding 2: per-player concurrent-watcher cap. Identity is derived from the object
                //--- (mirrors the Finding 3 fix in playerObjectsList.sqf), never trusted from the client.
                _uidStart = getPlayerUID _playerObject;
                _activeCount = 0;
                { if ((_x select 1) == _uidStart) then { _activeCount = _activeCount + 1; }; } forEach _regArr;
                _capMax = missionNamespace getVariable ["WFBE_C_SUPPLY_MAX_ACTIVE_PER_PLAYER", 3];
                if (_activeCount >= _capMax) then { _hardenReject = true; _hardenReason = format ["per-player active-mission cap reached (%1)", _capMax]; };
            };

            if (!_hardenReject) then {
                _upgLvl = ((side _playerObject) call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE;
                _modAmt = 1;
                if (_upgLvl >= 3) then { _modAmt = 2; };
                if (_upgLvl == 2) then { _modAmt = 1.5; };
                _realAmount = floor ((_associatedSourceTown getVariable ["supplyValue", 0]) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _modAmt);
                //--- Defence in depth: never exceed what the town's own registered max could ever produce.
                _realAmount = (_realAmount min (floor ((_associatedSourceTown getVariable ["maxSupplyValue", _realAmount]) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * 2))) max 0;

                _regEntry = [_associatedSupplyTruck, _uidStart, (side _playerObject), _realAmount, _byHeli, _associatedSourceTown];
                _regArr set [count _regArr, _regEntry];
                missionNamespace setVariable ["WFBE_SE_ACTIVE_SUPPLY_MISSIONS", _regArr];
            };

            if (_hardenReject) then {
                ["WARNING", Format ["SupplyMissionStarted.sqf: hardening rejected start for %1 (truck:%2): %3.", _playerObject, _associatedSupplyTruck, _hardenReason]] Call WFBE_CO_FNC_LogContent;
            };
        };
        if (_hardenReject) exitWith {};

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
                //--- perf: the supply-truck position is fixed for this whole exitWith pass (no sleep between
                //--- iterations), so the identical nearestObjects 8m sphere was being rescanned once per
                //--- player in WFBE_SE_PLAYERLIST. Hoist it once and reuse - behaviour-identical (same objects),
                //--- N scans -> 1 scan.
                private "_nearTruck";
                _nearTruck = nearestObjects [(getPos _associatedSupplyTruck), [], 8];
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
                    } forEach _nearTruck;


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
