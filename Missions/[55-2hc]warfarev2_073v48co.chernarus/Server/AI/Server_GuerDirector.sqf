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
waitUntil {!isNil "WFBE_SE_Towns"};
waitUntil {count WFBE_SE_Towns > 0};

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

{
    private ["_town","_side","_rec"];
    _town = _x;
    _side = _town getVariable ["wfbe_side", "UNKNOWN"];
    if (_side == "GUER" || {_side == "UNKNOWN"}) then {
        private ["_grps","_baseline","_curStr"];
        _grps    = [_town, true, "EAST", false] call WFBE_SE_FNC_GetTownGroupsDefender;
        _baseline = 0.5;
        if (count _grps > 0) then {_baseline = 1.0};
        _curStr  = _baseline;
        _rec = [_town, _baseline, _curStr, 0, 0, count _grps];
        _ledger set [count _ledger, _rec];
        _ledgerCount = _ledgerCount + 1;
    };
} forEach WFBE_SE_Towns;

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
            _grps        = [_town, true, "EAST", false] call WFBE_SE_FNC_GetTownGroupsDefender;
            _nowGrpCount = count _grps;
            if (_lastGrpCount > 0) then {
                _ratio = _nowGrpCount / _lastGrpCount;
                _ratio = [_ratio, 0, 1] call _fnClamp;
                _rec set [2, (_rec select 2) * _ratio];
            };
            _rec set [5, 0];
        };
        if (_active) then {
            _grps = [_town, true, "EAST", false] call WFBE_SE_FNC_GetTownGroupsDefender;
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
