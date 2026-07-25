
//--- fix(hunt): PVEH body extracted into WFBE_SE_FNC_HandleSupplyMissionCompleted so the server-side
//--- ground-truck completion detector (supplyMissionStarted.sqf) can call it directly. publicVariableServer
//--- executed ON the server never fires the server's own PVEH (engine trap; same extraction pattern as
//--- WFBE_SE_FNC_HandleAttackWaveDetails in AttackWave.sqf), so ground-truck deliveries died silently.
//--- Calling convention: _this IS the payload array [playerObject, supplyTruck, side]. The PVEH at the
//--- bottom still relays the client (helicopter) sender supplyMissionUnload.sqf.
WFBE_SE_FNC_HandleSupplyMissionCompleted = {

    private ['_namePlayer', '_associatedSupplyTruck', '_supplyAmount', '_sourceTown', '_sourceTownStr', '_sidePlayer', '_logMessage', '_byHeli', '_cashRun', '_comTeam', '_airLevel'];
    private ['_secHardened', '_hardenReject', '_hardenReason', '_regArr', '_regIdx', '_regEntry', '_i', '_consumed'];
    private ['_upgLvl', '_modAmt'];

    _playerObject = _this select 0;
    _namePlayer = name (_this select 0);
    _associatedSupplyTruck = (_this select 1);

    //--- SECURITY (harden-supplymission, DR-55/WFBE_C_SEC_HARDENING family, Finding 1) - split 2026-07-25
    //--- after the fold-collision review found the original flag-off fallback was byte-identical to the
    //--- unhardened hole (arbitrary client-stamped SupplyAmount -> unbounded funds mint). The finding is
    //--- now two independently-justified pieces:
    //---   (a) UNFLAGGED, always on, below: the payout amount is re-derived server-side from the source
    //---       town's own supplyValue (same formula supplyMissionStart.sqf/the registry path use) instead
    //---       of trusted off the client-stamped truck variable. An honest completion produces the exact
    //---       same number (provably a no-op for legitimate play), while a forged one is now bounded to a
    //---       real town's current (capped) supply value instead of an arbitrary attacker-chosen integer.
    //---       This does NOT close repeat/replay farming of the same real town via repeated forged
    //---       completions - only the registry below does that - but it closes the single-shot unbounded
    //---       mint unconditionally, which is the hole this file is named for.
    //---   (b) STILL FLAG-GATED below: the mission registry with atomic one-shot consumption is a genuine
    //---       behavioural change (a completion is only accepted if THIS server instance's
    //---       supplyMissionStarted.sqf registered it, and the row is consumed exactly once) with real
    //---       edge-case risk around multi-truck convoys and JIP timing, so it stays opt-in.
    //--- ON: the truck must be a mission THIS server instance started and is still watching
    //--- (supplyMissionStarted.sqf's registry), for a player whose current side matches the side that
    //--- mission was registered under; amount/town/byHeli come from the server-minted registry row, never
    //--- the client-stamped object variables. Atomic find+remove inside isNil (A2/OA runs isNil bodies
    //--- unscheduled) so a replayed/duplicated completion PV cannot consume the same row twice - same
    //--- one-shot compare-and-consume idiom as Support_FPV.sqf's capability handling.
    _secHardened = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;
    _hardenReject = false;
    _hardenReason = "";
    _consumed = false;
    _regEntry = [];

    if (_secHardened) then {
        isNil {
            _regArr = missionNamespace getVariable ["WFBE_SE_ACTIVE_SUPPLY_MISSIONS", []];
            if (typeName _regArr != "ARRAY") then { _regArr = []; };
            _regIdx = -1;
            _i = 0;
            {
                if (_regIdx < 0 && {(_x select 0) == _associatedSupplyTruck}) then { _regIdx = _i; };
                _i = _i + 1;
            } forEach _regArr;
            if (_regIdx >= 0) then {
                _regEntry = _regArr select _regIdx;
                _regArr = _regArr - [_regEntry];
                missionNamespace setVariable ["WFBE_SE_ACTIVE_SUPPLY_MISSIONS", _regArr];
                _consumed = true;
            };
        };
        if (!_consumed) then {
            _hardenReject = true;
            _hardenReason = "no matching active mission (replay, forged, or already consumed)";
        };
        //--- "for that player's side" (spec): the completing player's current side must match the side the
        //--- mission was registered under. This does NOT reject the normal driver-relay case (a teammate
        //--- other than the loader delivering the truck) because relay drivers are always the same side.
        if (!_hardenReject && {isNull _playerObject}) then {
            _hardenReject = true;
            _hardenReason = "null completing player";
        };
        if (!_hardenReject && {(side _playerObject) != (_regEntry select 2)}) then {
            _hardenReject = true;
            _hardenReason = "completing player side does not match the registered mission side";
        };
    };

    if (_hardenReject) exitWith {
        ["WARNING", Format ["SupplyMissionCompleted.sqf: hardening rejected completion for %1 (truck:%2): %3.", _playerObject, _associatedSupplyTruck, _hardenReason]] Call WFBE_CO_FNC_LogContent;
    };

    if (_secHardened) then {
        _supplyAmount = _regEntry select 3;
        _byHeli = _regEntry select 4;
        _sourceTown = _regEntry select 5;
        _sidePlayer = _regEntry select 2;
    } else {
        //--- (a) above: town/side/byHeli identity is still taken off the client-stamped truck variables
        //--- (unchanged trust level from before this fix - narrowing that further is the registry's job in
        //--- (b)), but the PAYOUT AMOUNT is no longer read off the truck at all. It is recomputed here from
        //--- the source town's own server-owned supplyValue, clamped the same way the hardened registry
        //--- entry is clamped at mission-start time (min against maxSupplyValue-derived ceiling, floor 0).
        _sourceTown = _associatedSupplyTruck getVariable "SupplyFromTown";
        _sidePlayer = (_this select 2);

        if (isNil "_sourceTown") then {
            _sourceTown = objNull;
        };

        _byHeli = _associatedSupplyTruck getVariable "SupplyByHeli";
        if (isNil "_byHeli") then { _byHeli = false; };

        if (isNull _sourceTown) then {
            _supplyAmount = 0;
        } else {
            _upgLvl = ((_sidePlayer) call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_SUPPLYRATE;
            _modAmt = 1;
            if (_upgLvl >= 3) then { _modAmt = 2; };
            if (_upgLvl == 2) then { _modAmt = 1.5; };
            _supplyAmount = floor ((_sourceTown getVariable ["supplyValue", 0]) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _modAmt);
            //--- Defence in depth: never exceed what the town's own registered max could ever produce
            //--- (identical ceiling formula to the hardened registry entry above).
            _supplyAmount = (_supplyAmount min (floor ((_sourceTown getVariable ["maxSupplyValue", _supplyAmount]) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * 2))) max 0;
        };
    };

    _sourceTownStr = str (_sourceTown);

    if ((isNull _sourceTown) || (_supplyAmount <= 0)) exitWith {
        ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Ignored completion for %1 (source:%2 amount:%3).", _associatedSupplyTruck, _sourceTown, _supplyAmount]] call WFBE_CO_FNC_LogContent;
    };

    //--- B74.2: leaderboard supply-run credit to the delivering player (run count + delivered S value). Past the null/<=0 gate above.
    if (!isNull _playerObject) then {private "_supUid"; _supUid = getPlayerUID _playerObject; if (_supUid != "") then {[_supUid, WFBE_STAT_SUPPLY_RUNS, 1] call WFBE_SE_FNC_RecordStat; [_supUid, WFBE_STAT_SUPPLY_VALUE, _supplyAmount] call WFBE_SE_FNC_RecordStat}};

    _airLevel = ((_sidePlayer) call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIR;
    _cashRun = (_byHeli && (_airLevel >= 4));

    WFBE_Server_PV_SupplyMissionCompletedMessage = [format ["%1 has transported S %2 to base from %3.", _namePlayer, _supplyAmount, _sourceTownStr], _sidePlayer, _supplyAmount, _playerObject, _byHeli, _cashRun];

    //--- J1 funds authority: pay the delivering player's team server-side (identical formula to the client
    //--- message line; WFBE_C_SUPPLY_HELI_REWARD_MULT is an unconditional Common constant). Unconditional wrt
    //--- _cashRun - the client paid the pilot in BOTH branches. The client handler no longer writes the wallet.
    if (!isNull _playerObject && {isPlayer _playerObject}) then {
        [group _playerObject, if (_byHeli) then {round (_supplyAmount * WFBE_C_SUPPLY_HELI_REWARD_MULT)} else {_supplyAmount}] Call WFBE_CO_FNC_ChangeTeamFunds;
    };

    if (_cashRun) then {
        //--- Cash run: pilot's team is paid server-side above (J1); commander gets a tithe minted on top. Pool gets nothing.
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
