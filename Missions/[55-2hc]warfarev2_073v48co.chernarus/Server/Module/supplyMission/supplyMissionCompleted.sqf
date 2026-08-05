
//--- fix(hunt): PVEH body extracted into WFBE_SE_FNC_HandleSupplyMissionCompleted so the server-side
//--- ground-truck completion detector (supplyMissionStarted.sqf) can call it directly. publicVariableServer
//--- executed ON the server never fires the server's own PVEH (engine trap; same extraction pattern as
//--- WFBE_SE_FNC_HandleAttackWaveDetails in AttackWave.sqf), so ground-truck deliveries died silently.
//--- Calling convention: _this IS the payload array [playerObject, supplyTruck, side]. The PVEH at the
//--- bottom still relays the client (helicopter) sender supplyMissionUnload.sqf.
WFBE_SE_FNC_HandleSupplyMissionCompleted = {

    private ['_namePlayer', '_associatedSupplyTruck', '_supplyAmount', '_sourceTown', '_sourceTownStr', '_sidePlayer', '_logMessage', '_byHeli', '_cashRun', '_comTeam', '_airLevel', '_cc', '_cp', '_dx', '_dy', '_nearCommandCenter', '_playerObject', '_rejected', '_rejectReason', '_vehType', '_sideStructures', '_ccSide', '_friendlyCC', '_supUid'];

    //--- This handler is also called directly by the server-side ground-truck detector.
    //--- The PV relay is only used for helicopter unloads, so reject malformed/unrelated
    //--- client payloads here while preserving the server-originated ground path.
    if ((typeName _this) != "ARRAY") exitWith {};
    if (count _this < 3) exitWith {};

    _playerObject = _this select 0;
    _associatedSupplyTruck = _this select 1;
    if ((typeName _playerObject) != "OBJECT" || {(typeName _associatedSupplyTruck) != "OBJECT"}) exitWith {};
    if (isNull _playerObject || {isNull _associatedSupplyTruck} || {!isPlayer _playerObject}) exitWith {};

    _namePlayer = name _playerObject;
    _supplyAmount = _associatedSupplyTruck getVariable "SupplyAmount";
    _sourceTown = _associatedSupplyTruck getVariable "SupplyFromTown";
    //--- Never trust the client-provided side slot: derive it from the credited player.
    //--- side group is more stable than bare `side unit` when the unit is mid-state-change.
    _sidePlayer = side group _playerObject;

    if (isNil "_supplyAmount") then {
        _supplyAmount = 0;
    };

    if (isNil "_sourceTown") then {
        _sourceTown = objNull;
    };

    if ((isNull _sourceTown) || (_supplyAmount <= 0)) exitWith {
        ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Ignored completion for %1 (source:%2 amount:%3).", _associatedSupplyTruck, _sourceTown, _supplyAmount]] call WFBE_CO_FNC_LogContent;
    };

    //--- fix(bughunt supply-cargo 20260730): world revalidation uses a _rejected latch, NOT exitWith
    //--- inside if/then. On A2 OA 1.64, exitWith inside then{} only leaves that block and FALLS THROUGH
    //--- to the pay path (same engine trap fixed in RequestChangeScore.sqf / RequestVehicleLock.sqf).
    //--- The prior #1345 heli type/driver/CC exitWith gates were therefore non-rejecting for payment.
    _rejected = false;
    _rejectReason = "";

    //--- BUG: ground forged PV accepted ANY object with SupplyAmount/FromTown (no type check).
    _vehType = typeOf _associatedSupplyTruck;
    if !(_vehType in WFBE_C_SUPPLY_VEHICLE_TYPES) then {
        _rejected = true;
        _rejectReason = format ["non-supply vehicle type %1", _vehType];
    };

    //--- byHeli from vehicle class (server truth), not client-stamped SupplyByHeli (cash-run class).
    _byHeli = _vehType in WFBE_C_SUPPLY_HELI_TYPES;

    //--- BUG: "friendly" CC scan accepted ANY side's Base_WarfareBUAVterminal. Require own-side CC
    //--- via wfbe_side stamp (Construction_SmallSite/MediumSite) or membership in side structures list.
    //--- Also: ground path previously skipped ALL world revalidation (heli-only block) so a forged
    //--- completion PV paid without proximity to any Command Center.
    if (!_rejected) then {
        _nearCommandCenter = false;
        _sideStructures = _sidePlayer Call WFBE_CO_FNC_GetSideStructures;
        {
            _cc = _x;
            if (_cc isKindOf "Base_WarfareBUAVterminal") then {
                _ccSide = _cc getVariable ["wfbe_side", sideUnknown];
                _friendlyCC = false;
                if (_ccSide == _sidePlayer) then { _friendlyCC = true; };
                if (!_friendlyCC) then {
                    if (_cc in _sideStructures) then { _friendlyCC = true; };
                };
                if (_friendlyCC) then {
                    _cp = getPos _cc;
                    _dx = ((getPos _associatedSupplyTruck) select 0) - (_cp select 0);
                    _dy = ((getPos _associatedSupplyTruck) select 1) - (_cp select 1);
                    //--- 80 m horizontal (2D) for truck and heli; altitude handled separately for heli.
                    if (((_dx * _dx) + (_dy * _dy)) < 6400) then { _nearCommandCenter = true; };
                };
            };
        } forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 400]);
        if (!_nearCommandCenter) then {
            _rejected = true;
            _rejectReason = "no friendly Command Center within 80m horizontal";
        };
    };

    //--- Heli-only: driver must be the credited player; altitude must stay low (client channel uses 35 m;
    //--- server allows 40 m slack for network/tick jitter). Client timer then PV is a TOCTOU without this.
    if (!_rejected && _byHeli) then {
        if (driver _associatedSupplyTruck != _playerObject) then {
            _rejected = true;
            _rejectReason = "heli driver is not the completing player";
        };
    };
    if (!_rejected && _byHeli) then {
        if (((getPos _associatedSupplyTruck) select 2) > 40) then {
            _rejected = true;
            _rejectReason = "heli altitude above unload limit";
        };
    };

    if (_rejected) exitWith {
        ["INFORMATION", Format ["SupplyMissionCompleted.sqf: Rejected completion for %1 (%2).", _associatedSupplyTruck, _rejectReason]] call WFBE_CO_FNC_LogContent;
    };

    //--- B74.2: leaderboard supply-run credit AFTER final accept only.
    //--- BUG: stats were previously written before heli revalidation, so failed forgeries still inflated
    //--- WFBE_STAT_SUPPLY_RUNS / WFBE_STAT_SUPPLY_VALUE (and with the exitWith fall-through, pay also ran).
    _sourceTownStr = str (_sourceTown);
    if (!isNull _playerObject) then {
        _supUid = getPlayerUID _playerObject;
        if (_supUid != "") then {
            [_supUid, WFBE_STAT_SUPPLY_RUNS, 1] call WFBE_SE_FNC_RecordStat;
            [_supUid, WFBE_STAT_SUPPLY_VALUE, _supplyAmount] call WFBE_SE_FNC_RecordStat;
        };
    };

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
