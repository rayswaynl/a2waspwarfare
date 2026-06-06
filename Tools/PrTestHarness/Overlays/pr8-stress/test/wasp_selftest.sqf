/*
    WASP generic PR smoke observer - local test overlay.

    Server-side only. Read-only lifecycle and performance observer for live PR
    testing. It does not unlock upgrades, grant resources, change towns, or
    alter gameplay progression.
*/

if (!isServer) exitWith {};

WASP_ST_LOG = {
    private ["_cat","_msg"];
    _cat = _this select 0;
    _msg = "[WASP-SELFTEST] " + (_this select 1);
    diag_log _msg;
    if (!isNil "WFBE_CO_FNC_LogContent") then {[_cat, _msg] Call WFBE_CO_FNC_LogContent};
};

WASP_ST_GETNUM = {
    private ["_name"];
    _name = _this;
    if (isNil _name) then {-1} else {missionNamespace getVariable _name}
};

WASP_ST_GETSIDELOGIC = {
    private ["_logic","_side"];
    _side = _this;
    _logic = objNull;
    if (!isNil "WFBE_CO_FNC_GetSideLogic") then {_logic = _side Call WFBE_CO_FNC_GetSideLogic};
    _logic
};

["INITIALIZATION", "=== harness online (server) - PR8 smoke observer ==="] Call WASP_ST_LOG;

_gates = [
    ["params", "WFBE_Parameters_Ready"],
    ["sides", "WFBE_PRESENTSIDES"],
    ["common-init", "commonInitComplete"],
    ["town-init", "townInit"],
    ["server-full", "serverInitFull"]
];

_budget = 240;
_t = 0;
_reached = [];
_hung = "";

{
    if (_hung == "") then {
        private ["_done","_label","_var"];
        _label = _x select 0;
        _var = _x select 1;
        _done = false;

        while {!_done && (_t < _budget)} do {
            if !(isNil _var) then {
                if (_var == "WFBE_PRESENTSIDES") then {
                    _done = true;
                } else {
                    if (missionNamespace getVariable _var) then {_done = true};
                };
            };
            if (!_done) then {sleep 2; _t = _t + 2};
        };

        if (_done) then {
            _reached set [count _reached, _label];
            ["INITIALIZATION", Format ["gate reached: %1 (+%2s)", _label, _t]] Call WASP_ST_LOG;
        } else {
            _hung = _label;
            ["WARNING", Format ["INIT HANG - stalled before gate '%1'. Reached so far: %2", _label, _reached]] Call WASP_ST_LOG;
        };
    };
} forEach _gates;

if (_hung != "") exitWith {
    ["WARNING", Format ["RESULT: FAIL - init hang at '%1'. gatesReached=%2", _hung, _reached]] Call WASP_ST_LOG;
};

["INITIALIZATION", Format ["BOOT smoke PASS (+%1s) world=%2 mission=%3 sides=%4",
    _t, worldName, (if (isNil "WF_MISSIONNAME") then {"?"} else {WF_MISSIONNAME}),
    (if (isNil "WFBE_PRESENTSIDES") then {[]} else {WFBE_PRESENTSIDES})]] Call WASP_ST_LOG;

["INFORMATION", Format ["HYGIENE upgradeClearance=%1 debug=%2 aiCommander=%3 fundsW/E/G=%4/%5/%6 supplyW/E/G=%7/%8/%9",
    "WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE" Call WASP_ST_GETNUM,
    (if (isNil "WF_Debug") then {false} else {WF_Debug}),
    "WFBE_C_AI_COMMANDER_ENABLED" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_FUNDS_START_WEST" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_FUNDS_START_EAST" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_FUNDS_START_GUER" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_SUPPLY_START_WEST" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_SUPPLY_START_EAST" Call WASP_ST_GETNUM,
    "WFBE_C_ECONOMY_SUPPLY_START_GUER" Call WASP_ST_GETNUM]] Call WASP_ST_LOG;

_sides = if (isNil "WFBE_PRESENTSIDES") then {[west,east]} else {WFBE_PRESENTSIDES};
["INITIALIZATION", "=== PERFORMANCE TIMELINE begins - grep '[WASP-SELFTEST] PERF' ==="] Call WASP_ST_LOG;

_i = 0;
_min = 999;
_max = -1;
_sum = 0;
_done = false;
while {(_i < 20) && !_done} do {
    private ["_fps"];
    _i = _i + 1;
    _fps = diag_fps;
    if (_fps < _min) then {_min = _fps};
    if (_fps > _max) then {_max = _fps};
    _sum = _sum + _fps;

    ["INFORMATION", Format ["PERF #%1 t=%2s serverFPS=%3 allUnits=%4 vehicles=%5 allDead=%6 players=%7 groups=%8",
        _i, round time, (round (_fps * 10)) / 10, count allUnits, count vehicles, count allDead, count playableUnits, count allGroups]] Call WASP_ST_LOG;

    {
        private ["_logic","_s","_tech","_ups"];
        _s = _x;
        _logic = _s Call WASP_ST_GETSIDELOGIC;
        if (!isNull _logic) then {
            _ups = _logic getVariable ["wfbe_upgrades", []];
            _tech = 0;
            {_tech = _tech + _x} forEach _ups;
            ["INFORMATION", Format ["   SIDE side=%1 techSum=%2 upgrading=%3 id=%4 structures=%5",
                _s, _tech, _logic getVariable ["wfbe_upgrading", false],
                _logic getVariable ["wfbe_upgrading_id", -1],
                count (_logic getVariable ["wfbe_structures", []])]] Call WASP_ST_LOG;
        };
    } forEach _sides;

    if (!isNil "gameOver") then {if (gameOver) then {_done = true}};
    if (!_done) then {sleep 30};
};

_avg = if (_i > 0) then {(round ((_sum / _i) * 10)) / 10} else {-1};
["INITIALIZATION", Format ["=== TIMELINE complete: %1 samples (~%2 min) serverFPS min/avg/max = %3 / %4 / %5 ===",
    _i, round (_i * 30 / 60), (round (_min * 10)) / 10, _avg, (round (_max * 10)) / 10]] Call WASP_ST_LOG;

["INITIALIZATION", Format ["EVIDENCE schema=a2waspwarfare-agent-test-plan-v1 id=wasp-generic-pr-smoke result=observed gatesReached=%1 bootSeconds=%2 perfSamples=%3 serverFpsMinAvgMax=%4/%5/%6",
    _reached, _t, _i, (round (_min * 10)) / 10, _avg, (round (_max * 10)) / 10]] Call WASP_ST_LOG;

["INITIALIZATION", "=== harness window complete ==="] Call WASP_ST_LOG;
