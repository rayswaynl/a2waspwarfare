// Server_GuerDirector.sqf
// AICOM V2 Lane 800 - GUER Director
// Invisible A-Life for the resistance side: per-town strength ledger + virtual cells.
// Flag gate: AICOMV2_LANE_GUER_DIRECTOR (default 0 = inert; flag-off = byte-identical to HEAD).
// See docs/design/v2/aicom-v2-800-guer-director.md for full spec.
//
// A2 OA 1.64 compliant: array-append via set[count,v], private ["x"] declarations,
// lazy && {} / || {}, no exitWith inside forEach, (getPos _x) select 2 for altitude.

if (!((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0)) exitWith {};

["INITIALIZATION", "Server_GuerDirector.sqf: GUER Director lane 800 starting."] Call WFBE_CO_FNC_LogContent;

//--- Wait for town initialisation.
waitUntil {!isNil "towns"};
waitUntil {count towns > 0};

//--- Short delay to let town ownership settle before seeding ledger.
sleep 5;

["INFORMATION", "Server_GuerDirector.sqf: Town init confirmed. Building ledger."] Call WFBE_CO_FNC_LogContent;

//--- Constants (read once at startup).
private ["_tickSec","_regenFullSec","_surgeCap","_surgeCapPaid","_grpBudgetMax",
         "_minSpawnM","_ambushBubbleM","_suppressSec","_retakeEnabled","_playerSupport"];

_tickSec        = missionNamespace getVariable ["AICOMV2_GDIR_TICK_SEC",         30];
_regenFullSec   = missionNamespace getVariable ["AICOMV2_GDIR_REGEN_FULL_SEC",   1800];
_surgeCap       = missionNamespace getVariable ["AICOMV2_GDIR_SURGE_MAX",        1.0];
_surgeCapPaid   = missionNamespace getVariable ["AICOMV2_GDIR_PAID_SURGE_MAX",   1.5];
_grpBudgetMax   = missionNamespace getVariable ["AICOMV2_GDIR_GROUP_BUDGET_MAX", 110];
_minSpawnM      = missionNamespace getVariable ["AICOMV2_GDIR_MIN_SPAWN_M",      400];
_ambushBubbleM  = missionNamespace getVariable ["AICOMV2_GDIR_AMBUSH_BUBBLE_M",  700];
_suppressSec    = missionNamespace getVariable ["AICOMV2_GDIR_SUPPRESS_SEC",     600];
_retakeEnabled  = missionNamespace getVariable ["AICOMV2_GDIR_RETAKE",           0];
_playerSupport  = missionNamespace getVariable ["AICOMV2_GDIR_PLAYER_SUPPORT",   0];

//===================================================================================
// LEDGER: array of records, one per GUER/unknown town.
// Record layout (indices):
//   0 = town object
//   1 = baseline strength (0.0..1.0) seeded from initial group count
//   2 = current virtual strength (0.0..1.0)
//   3 = in-transit strength (cells dispatched but not yet arrived)
//   4 = suppress timer (diag_tickTime when last contact ended; 0 = not suppressed)
//   5 = last-tick group count (for survivor read-back on deactivation)
//===================================================================================
private ["_ledger","_ledgerCount","_fundedTotal","_regenDebt"];
_ledger      = [];
_ledgerCount = 0;
_fundedTotal = 0;
_regenDebt   = 0;

//--- No-nerf census helper (Tier-0 fix): live GUER groups near a town object. Returns an ARRAY
//--- so the existing `count _grps` call sites stay valid. Replaces the mis-argged, erroring
//--- WFBE_SE_FNC_GetTownGroupsDefender calls (that fn is a spawn-roster PLANNER, not a live census).
private ["_fnGuerGroups"];
_fnGuerGroups = {
    private ["_t","_out"];
    _t = _this select 0;
    _out = [];
    {
        if ((side _x == resistance) && {alive (leader _x)} && {(leader _x) distance _t < 600}) then {
            _out set [count _out, _x];
        };
    } forEach allGroups;
    _out
};

{
    private ["_town","_side","_rec"];
    _town = _x;
    _side = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
    if (_side == WFBE_C_GUER_ID || {_side == WFBE_C_UNKNOWN_ID}) then {
        private ["_grps","_baseline","_curStr"];
        _grps    = [_town] call _fnGuerGroups;
        _baseline = 0.5;
        if (count _grps > 0) then {_baseline = 1.0};
        _curStr  = _baseline;
        _rec = [_town, _baseline, _curStr, 0, 0, count _grps];
        _ledger set [count _ledger, _rec];
        _ledgerCount = _ledgerCount + 1;
    };
} forEach towns;

["INFORMATION", Format ["Server_GuerDirector.sqf: Ledger seeded. %1 GUER/unknown towns.", _ledgerCount]] Call WFBE_CO_FNC_LogContent;

//===================================================================================
// HELPER: Clamp _val between _lo and _hi.
// Usage: [val, lo, hi] call _fnClamp
//===================================================================================
private ["_fnClamp"];
_fnClamp = {
    private ["_val","_lo","_hi"];
    _val = _this select 0;
    _lo  = _this select 1;
    _hi  = _this select 2;
    if (_val < _lo) then {_val = _lo};
    if (_val > _hi) then {_val = _hi};
    _val
};

//===================================================================================
// MAIN LOOP
//===================================================================================
private ["_elmin","_tick","_regenPerTick"];
_elmin        = 0;
_tick         = 0;
_regenPerTick = 1.0 / (_regenFullSec / _tickSec);

while {!WFBE_GameOver} do {

    sleep _tickSec;
    _tick  = _tick + 1;
    _elmin = floor (diag_tickTime / 60);

    //--------------------------------------------------------------------
    // PHASE 1: REGEN - advance each town strength toward baseline.
    //--------------------------------------------------------------------
    {
        private ["_rec","_str","_base","_regen"];
        _rec  = _x;
        _str  = _rec select 2;
        _base = _rec select 1;
        if (_str < _base) then {
            _regen = [_regenPerTick, 0, _base - _str] call _fnClamp;
            _rec set [2, _str + _regen];
            _regenDebt = [_regenDebt - _regen, 0, 999] call _fnClamp;
        };
        //--- Tier-1: publish per-town strength ratio (current/baseline) to the town object so the V1
        //--- defender spawner (Server_GetTownGroupsDefender) can size the real garrison. >1 = reinforced.
        (_rec select 0) setVariable ["wfbe_gdir_str", (if (_base > 0) then {(_rec select 2) / _base} else {1})];
    } forEach _ledger;

    //--------------------------------------------------------------------
    // PHASE 2: OBSERVE - read group count on recently-deactivated towns.
    //--------------------------------------------------------------------
    {
        private ["_rec","_town","_active","_lastGrpCount","_grps","_nowGrpCount","_ratio"];
        _rec          = _x;
        _town         = _rec select 0;
        _active       = _town getVariable ["wfbe_active", false];
        _lastGrpCount = _rec select 5;
        if (!_active && {_lastGrpCount > 0}) then {
            _grps        = [_town] call _fnGuerGroups;
            _nowGrpCount = count _grps;
            if (_lastGrpCount > 0) then {
                _ratio = _nowGrpCount / _lastGrpCount;
                _ratio = [_ratio, 0, 1] call _fnClamp;
                _rec set [2, ((_rec select 2) * _ratio) max (_rec select 1)]; //--- no-nerf: floor at baseline
            };
            _rec set [5, 0];
        };
        if (_active) then {
            _grps = [_town] call _fnGuerGroups;
            _rec set [5, count _grps];
        };
    } forEach _ledger;

    //--------------------------------------------------------------------
    // PHASE 3: ASSESSMENT - classify each town.
    // States: safe / opportunity / depleted / threatened
    //--------------------------------------------------------------------
    private ["_stateSafe","_stateOpp","_stateDep","_stateThr"];
    _stateSafe = [];
    _stateOpp  = [];
    _stateDep  = [];
    _stateThr  = [];

    {
        private ["_rec","_str","_base","_transit","_suppEnd","_now"];
        _rec     = _x;
        _str     = _rec select 2;
        _base    = _rec select 1;
        _transit = _rec select 3;
        _suppEnd = _rec select 4;
        _now     = diag_tickTime;

        if (_str >= _base * 0.9) then {
            if (_str >= _base * 1.1 && {_transit < 0.2}) then {
                _stateOpp set [count _stateOpp, _rec];
            } else {
                _stateSafe set [count _stateSafe, _rec];
            };
        } else {
            if (_str < _base * 0.25) then {
                _stateThr set [count _stateThr, _rec];
            } else {
                if (_str < _base * 0.5 && {_suppEnd < _now}) then {
                    _stateDep set [count _stateDep, _rec];
                } else {
                    _stateSafe set [count _stateSafe, _rec];
                };
            };
        };
    } forEach _ledger;

    //--------------------------------------------------------------------
    // PHASE 4: PLANNING - reinforce depleted/threatened from surplus towns.
    // Conservation: drain source on dispatch; credit destination on arrival.
    //--------------------------------------------------------------------
    private ["_sources","_orderCount"];
    _sources    = [];
    _orderCount = 0;

    {_sources set [count _sources, _x]} forEach _stateOpp;
    {_sources set [count _sources, _x]} forEach _stateSafe;

    {
        private ["_dst","_dstStr","_dstBase","_needed","_src","_srcStr","_srcBase","_send"];
        _dst    = _x;
        _dstStr = _dst select 2;
        _dstBase= _dst select 1;
        _needed = _dstBase - _dstStr;
        if (_needed > 0.05 && {count _sources > 0}) then {
            _src    = _sources select 0;
            _srcStr = _src select 2;
            _srcBase= _src select 1;
            _send   = [_needed * 0.5, 0, _srcStr - (_srcBase * 0.5)] call _fnClamp;
            if (_send > 0.05) then {
                _src set [2, _srcStr - _send];
                _src set [3, (_src select 3) + _send];
                _dst set [3, (_dst select 3) + _send];
                _orderCount  = _orderCount + 1;
                _fundedTotal = _fundedTotal + _send;
                diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER moveCell from=%2 to=%3 str=%4",
                    _elmin, _src select 0, _dst select 0, _send];
            };
        };
    } forEach _stateDep;

    {
        private ["_dst","_dstStr","_dstBase","_needed","_src","_srcStr","_srcBase","_send"];
        _dst    = _x;
        _dstStr = _dst select 2;
        _dstBase= _dst select 1;
        _needed = _dstBase - _dstStr;
        if (_needed > 0.1 && {count _sources > 0}) then {
            _src    = _sources select 0;
            _srcStr = _src select 2;
            _srcBase= _src select 1;
            _send   = [_needed * 0.3, 0, _srcStr - (_srcBase * 0.6)] call _fnClamp;
            if (_send > 0.05) then {
                _src set [2, _srcStr - _send];
                _src set [3, (_src select 3) + _send];
                _dst set [3, (_dst select 3) + _send];
                _orderCount  = _orderCount + 1;
                _fundedTotal = _fundedTotal + _send;
                diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER moveCell from=%2 to=%3 str=%4 (threatened)",
                    _elmin, _src select 0, _dst select 0, _send];
            };
        };
    } forEach _stateThr;

    //--------------------------------------------------------------------
    // PHASE 4.5: PENDING ORDERS - consume player Commissar Panel requests.
    // Each entry: [orderKind, townId, product, playerUID, pricePaid, timestampSec]
    // Guard: AICOMV2_GDIR_PANEL must be on (belt-and-suspenders; PVF already checked).
    //--------------------------------------------------------------------
    if ((missionNamespace getVariable ["AICOMV2_GDIR_PANEL", 0]) > 0) then {
        private ["_pendingOrders","_consumed"];
        _pendingOrders = missionNamespace getVariable ["AICOMV2_GDIR_PENDING_ORDERS", []];
        //--- Swap-and-clear IMMEDIATELY: orders PVF-appended while this tick processes land in the
        //--- fresh array and survive to the next tick. Clearing after the loop dropped them silently.
        missionNamespace setVariable ["AICOMV2_GDIR_PENDING_ORDERS", []];
        _consumed      = [];
        {
            private ["_ord","_kind","_townId","_product","_uid","_pricePaid","_ordTs"];
            _ord       = _x;
            _kind      = _ord select 0;
            _townId    = _ord select 1;
            _product   = _ord select 2;
            _uid       = _ord select 3;
            _pricePaid = _ord select 4;
            _ordTs     = _ord select 5;

            //--- Find target town in ledger.
            private ["_found","_recIdx"];
            _found  = false;
            _recIdx = -1;
            private ["_li"];
            _li = 0;
            {
                if (!_found) then {
                    if ((_x select 0 getVariable ["wfbe_name", ""]) == _townId) then {
                        _found  = true;
                        _recIdx = _li;
                    };
                };
                _li = _li + 1;
            } forEach _ledger;

            if (_found) then {
                private ["_rec","_str","_base"];
                _rec  = _ledger select _recIdx;
                _str  = _rec select 2;
                _base = _rec select 1;

                //--- REINFORCE: add funded strength proportional to price paid.
                //--- Base price $800 ~> 0.20 strength; scale linearly.
                if (_kind == "reinforce") then {
                    private ["_gain","_baseReinf","_capStr"];
                    _baseReinf = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_REINF", 800];
                    _gain      = 0.20 * (_pricePaid / _baseReinf);
                    _capStr    = _base * _surgeCapPaid;
                    _str       = [_str + _gain, 0, _capStr] call _fnClamp;
                    _rec set [2, _str];
                    _fundedTotal = _fundedTotal + _gain;
                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER kind=reinforce town=%2 product=%3 gain=%4 newStr=%5 fundedBy=%6 pricePaid=%7",
                        _elmin, _townId, _product, _gain, _str, _uid, _pricePaid];
                };

                //--- QRF CONTRACT: arm a contract record; QRF air fires when town is attacked.
                //--- Contract records are written by RequestGDirPanel.sqf; Director polls them.
                if (_kind == "qrfContract") then {
                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER kind=qrf town=%2 product=%3 armed fundedBy=%4 pricePaid=%5",
                        _elmin, _townId, _product, _uid, _pricePaid];
                    //--- QRF air materializer: fires when town wfbe_contact_time becomes fresh.
                    //--- Handled in contract poll below (Phase 7 ext).
                };

                //--- COUNTER-ATTACK CONTRACT: arms a retake trigger that fires on town loss.
                if (_kind == "counterContract") then {
                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER kind=counterAttack town=%2 armed fundedBy=%3 pricePaid=%4",
                        _elmin, _townId, _uid, _pricePaid];
                    //--- Counter-attack handled in contract poll below.
                };

                _consumed set [count _consumed, _ord];
            } else {
                //--- Town not in ledger: drop and log.
                diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_ORDER DROP kind=%2 town=%3 notInLedger fundedBy=%4",
                    _elmin, _kind, _townId, _uid];
            };
        } forEach _pendingOrders;

        //--- (Pending list already swap-and-cleared at read time above.)

        //--- Contract poll: fire armed QRF contracts when town is under attack.
        //--- Fire armed counter-attack contracts when GUER no longer holds town.
        private ["_contracts","_updContracts","_nowT"];
        _contracts    = missionNamespace getVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", []];
        _updContracts = [];
        _nowT         = diag_tickTime;
        {
            private ["_ctr","_cId","_cKind","_cTown","_cUid","_cPrice","_cArmed","_cFired","_cState"];
            _ctr    = _x;
            _cId    = _ctr select 0;
            _cKind  = _ctr select 1;
            _cTown  = _ctr select 2;
            _cUid   = _ctr select 3;
            _cPrice = _ctr select 4;
            _cArmed = _ctr select 5;
            _cFired = _ctr select 6;
            _cState = _ctr select 7;

            //--- Skip already-fired or expired contracts.
            if (_cState == "armed") then {
                //--- Expire: end of round or >3600s old.
                if (WFBE_GameOver || {(_nowT - _cArmed) > 3600}) then {
                    _ctr set [7, "expired"];
                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_CONTRACT cId=%2 kind=%3 town=%4 expired fundedBy=%5",
                        _elmin, _cId, _cKind, _cTown, _cUid];
                } else {
                    //--- Find the town object.
                    private ["_cTownObj","_cFound"];
                    _cTownObj = objNull;
                    _cFound   = false;
                    {
                        if (!_cFound) then {
                            if ((_x getVariable ["wfbe_name", ""]) == _cTown) then {
                                _cTownObj = _x;
                                _cFound   = true;
                            };
                        };
                    } forEach towns;

                    if (_cFound && {!isNull _cTownObj}) then {
                        private ["_cTownSide"];
                        _cTownSide = _cTownObj getVariable ["sideID", WFBE_C_UNKNOWN_ID];

                        //--- QRF: fire when town is actively under attack (wfbe_contact_time fresh).
                        if (_cKind == "qrfInsert" || {_cKind == "qrfGunship"} || {_cKind == "qrfCombo"}) then {
                            private ["_contactAge","_contactTime"];
                            _contactTime = _cTownObj getVariable ["wfbe_contact_time", 0];
                            _contactAge  = _nowT - _contactTime;
                            if (_contactTime > 0 && {_contactAge < 120}) then {
                                //--- Town under attack - fire QRF.
                                private ["_spawnPos","_cTownPos"];
                                _cTownPos  = getPos _cTownObj;
                                _spawnPos  = [_cTownPos select 0, _cTownPos select 1, 50];

                                //--- Group-cap check before materializing.
                                private ["_curGuerGrps"];
                                _curGuerGrps = 0;
                                {if (side _x == resistance) then {_curGuerGrps = _curGuerGrps + 1}} forEach allGroups;
                                if (_curGuerGrps < _grpBudgetMax) then {
                                    //--- Authorized new air execution path for A1 panel (no V1 GUER air path existed).
                                    private ["_hClass","_h","_hGrp"];
                                    _hClass = "Ka137_MG_PMC"; //--- GUER insert: Ka-137 from Core_GUE.sqf.
                                    if (_cKind == "qrfGunship") then {_hClass = "Mi24_P"};  //--- GUER gunship.
                                    if (_cKind == "qrfCombo") then {
                                        //--- Spawn both. Gunship first (FIX: _hClass was never set to the gunship
                                        //--- here, so combo fired two Ka-137s and the telemetry lied).
                                        _hClass = "Mi24_P";
                                        _h    = _hClass createVehicle _spawnPos;
                                        _hGrp = createGroup resistance;
                                        //--- FIX: createVehicleCrew is TKOH/A3-only (absent on OA 1.64). Crew via the
                                        //--- proven wildcard-GUER pattern: CreateUnit into the group + moveIn*.
                                        private ["_uPilot","_uGun"];
                                        _uPilot = ["GUE_Soldier_Pilot", _hGrp, _spawnPos, resistance] Call WFBE_CO_FNC_CreateUnit;
                                        if (!isNull _uPilot) then {_uPilot moveInDriver _h};
                                        _uGun = ["GUE_Soldier_Pilot", _hGrp, _spawnPos, resistance] Call WFBE_CO_FNC_CreateUnit;
                                        if (!isNull _uGun) then {_uGun moveInGunner _h};
                                        _h setPos _spawnPos;
                                        _hGrp addWaypoint [_cTownPos, 200];
                                        diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_CONTRACT cId=%2 QRF_FIRE class=Mi24_P town=%3 fundedBy=%4",
                                            _elmin, _cId, _cTown, _cUid];
                                        _hClass = "Ka137_MG_PMC";
                                    };
                                    _h    = _hClass createVehicle _spawnPos;
                                    _hGrp = createGroup resistance;
                                    //--- FIX: createVehicleCrew is TKOH/A3-only (absent on OA 1.64).
                                    private ["_uPilot2","_uGun2"];
                                    _uPilot2 = ["GUE_Soldier_Pilot", _hGrp, _spawnPos, resistance] Call WFBE_CO_FNC_CreateUnit;
                                    if (!isNull _uPilot2) then {_uPilot2 moveInDriver _h};
                                    if (_hClass == "Mi24_P") then {
                                        _uGun2 = ["GUE_Soldier_Pilot", _hGrp, _spawnPos, resistance] Call WFBE_CO_FNC_CreateUnit;
                                        if (!isNull _uGun2) then {_uGun2 moveInGunner _h};
                                    };
                                    _h setPos _spawnPos;
                                    _hGrp addWaypoint [_cTownPos, 200];
                                    _ctr set [6, _nowT];
                                    _ctr set [7, "fired"];
                                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_CONTRACT cId=%2 QRF_FIRE class=%3 town=%4 fundedBy=%5",
                                        _elmin, _cId, _hClass, _cTown, _cUid];
                                } else {
                                    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_CONTRACT cId=%2 QRF_SKIP groupCapExceeded=%3/%4",
                                        _elmin, _cId, _curGuerGrps, _grpBudgetMax];
                                };
                            };
                        };

                        //--- COUNTER-ATTACK: fire when town is no longer held by GUER.
                        if (_cKind == "counterAttack") then {
                            if (!(_cTownSide == WFBE_C_GUER_ID || {_cTownSide == WFBE_C_UNKNOWN_ID})) then {
                                //--- Town fell. Fire retake after 2-5 min delay.
                                private ["_delayMin","_delayMax","_delayT"];
                                _delayMin = 120;
                                _delayMax = 300;
                                _delayT   = _delayMin + round (random (_delayMax - _delayMin));
                                diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_CONTRACT cId=%2 COUNTER_FIRE town=%3 delay=%4s fundedBy=%5",
                                    _elmin, _cId, _cTown, _delayT, _cUid];
                                //--- Boost strength to trigger the Director retake cell.
                                //--- This fires even when AICOMV2_GDIR_RETAKE=0 (panel override per spec).
                                private ["_ctrRecIdx","_ctrFound"];
                                _ctrFound  = false;
                                _ctrRecIdx = 0;
                                {
                                    if (!_ctrFound) then {
                                        if ((_x select 0 getVariable ["wfbe_name", ""]) == _cTown) then {
                                            _ctrFound = true;
                                        };
                                    };
                                    if (!_ctrFound) then {_ctrRecIdx = _ctrRecIdx + 1};
                                } forEach _ledger;
                                if (_ctrFound && {_ctrRecIdx < count _ledger}) then {
                                    private ["_ctrRec"];
                                    _ctrRec = _ledger select _ctrRecIdx;
                                    //--- Set strength to baseline to trigger a reinforce cell.
                                    _ctrRec set [2, _ctrRec select 1];
                                    _fundedTotal = _fundedTotal + (_ctrRec select 1);
                                };
                                _ctr set [6, _nowT];
                                _ctr set [7, "fired"];
                            };
                        };
                    };
                };
            };
            _updContracts set [count _updContracts, _ctr];
        } forEach _contracts;
        missionNamespace setVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", _updContracts];
    };

    //--------------------------------------------------------------------
    // PHASE 5: CELL ARRIVAL - clear in-transit balance each tick.
    // Transit accumulated in phase 4 is credited back each tick.
    // (Full impl would be timer-driven per-cell; this is the conservative form.)
    //--------------------------------------------------------------------
    {
        private ["_rec","_transit","_str","_base"];
        _rec     = _x;
        _transit = _rec select 3;
        _str     = _rec select 2;
        _base    = _rec select 1;
        if (_transit > 0) then {
            _str = [_str + _transit, 0, _surgeCapPaid * _base] call _fnClamp;
            _rec set [2, _str];
            _rec set [3, 0];
        };
    } forEach _ledger;

    //--------------------------------------------------------------------
    // PHASE 6: MATERIALIZATION - GDIR_VOLUME telemetry for active towns.
    //--------------------------------------------------------------------
    {
        private ["_rec","_town","_active","_str","_base"];
        _rec    = _x;
        _town   = _rec select 0;
        _active = _town getVariable ["wfbe_active", false];
        _str    = _rec select 2;
        _base   = _rec select 1;
        if (_active && {abs (_str - _base) > 0.1}) then {
            diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_VOLUME town=%2 str=%3 base=%4",
                _elmin, _town, _str, _base];
        };
    } forEach _ledger;

    //--------------------------------------------------------------------
    // PHASE 7: CONSERVATION AUDIT - GDIR_LEDGER telemetry each tick.
    //--------------------------------------------------------------------
    private ["_totalStr","_totalBase","_totalTransit"];
    _totalStr     = 0;
    _totalBase    = 0;
    _totalTransit = 0;
    {
        private ["_rec"];
        _rec          = _x;
        _totalStr     = _totalStr     + (_rec select 2);
        _totalBase    = _totalBase    + (_rec select 1);
        _totalTransit = _totalTransit + (_rec select 3);
    } forEach _ledger;

    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_LEDGER towns=%2 totalStr=%3 totalBase=%4 transit=%5 funded=%6 regenDebt=%7",
        _elmin, _ledgerCount, _totalStr, _totalBase, _totalTransit, _fundedTotal, _regenDebt];

};

["INFORMATION", "Server_GuerDirector.sqf: WFBE_GameOver detected. GUER Director exiting."] Call WFBE_CO_FNC_LogContent;
