/* Server_ArtyCache.sqf — ARTY CACHE capturable neutral static-gun side-objective (Chernarus).
   Lane t34 (fable/arty-cache-objective, 2026-07-02).

   A D30_CDF (or configurable class) is spawned as a PROP (enableSimulation false,
   allowDamage false, no crew) at a configurable mid-map position. A presence scan
   loop checks each side; the FIRST side to clear the zone and hold it earns a
   one-time supply bonus (WFBE_C_ARTY_CACHE_BONUS, default 1500). Subsequent
   re-captures award no supply (the cache is stripped). The objective is announced
   via DashboardAnnounce on each capture.

   Optional: WFBE_C_ARTY_CACHE_GUN_TRANSFER = 1 enables the gun + crew to be
   transferred to the capturing side on first capture (adds AI units — group-budget
   risk — off by default).

   Map gate: Chernarus only (worldName check). Takistan has the Oilfields.
   Master gate: WFBE_C_ARTY_CACHE (default 0 — feature dark until server admin enables it).

   A2-OA 1.64 SAFE: no isEqualType/params/pushBack/findIf/selectRandom/apply/inline
   private _x=. Uses private ["_x"], count-loops, nearEntities, floor(random N).
*/

scriptName "Server\Server_ArtyCache.sqf";

if (!isServer) exitWith {};

//--- MAP GATE: Chernarus only (Takistan has Server_Oilfields for its equivalent).
if (toLower worldName != "chernarus") exitWith {
    ["INFORMATION", Format ["Server_ArtyCache.sqf: not Chernarus (worldName=%1) - ARTY CACHE is CH-only, skipping.", worldName]] Call WFBE_CO_FNC_LogContent;
};

//--- MASTER GATE (default 0 — dark by default).
if ((missionNamespace getVariable ["WFBE_C_ARTY_CACHE", 0]) != 1) exitWith {
    ["INFORMATION", "Server_ArtyCache.sqf: WFBE_C_ARTY_CACHE=0 - feature is OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Server_ArtyCache.sqf: ARTY CACHE feature ENABLED - starting."] Call WFBE_CO_FNC_LogContent;

//--- Wait for town init (mirrors Init_NavalHVT.sqf / Server_Oilfields.sqf gate).
waitUntil { sleep 1; !isNil "townInit" && townInit };

//--- ─────────────────────────────────────────────────────────────────────────
//--- READ TUNABLES
//--- ─────────────────────────────────────────────────────────────────────────
private ["_gunClass","_gunPos","_scanRadius","_scanInterval","_bonus","_mkrName"];
_gunClass    = missionNamespace getVariable ["WFBE_C_ARTY_CACHE_CLASS",         "D30_CDF"];
_gunPos      = missionNamespace getVariable ["WFBE_C_ARTY_CACHE_POS",           [7300, 7900, 0]];
_scanRadius  = missionNamespace getVariable ["WFBE_C_ARTY_CACHE_RADIUS",        80];
_scanInterval= missionNamespace getVariable ["WFBE_C_ARTY_CACHE_SCAN_INTERVAL", 15];
_bonus       = missionNamespace getVariable ["WFBE_C_ARTY_CACHE_BONUS",         1500];
_mkrName     = "WFBE_ARTY_CACHE";

if (_scanInterval < 5) then { _scanInterval = 5 };

//--- ─────────────────────────────────────────────────────────────────────────
//--- SPAWN THE STATIC GUN
//--- Prop pattern: enableSimulation false, allowDamage false, no crew.
//--- Ref: Init_NavalHVT.sqf WFBE_NavalHVT_SpawnProp idiom.
//--- ─────────────────────────────────────────────────────────────────────────
private ["_gun"];
_gun = createVehicle [_gunClass, [_gunPos select 0, _gunPos select 1, 0], [], 0, "NONE"];
if (isNull _gun) exitWith {
    diag_log Format ["ARTYCACHE|SPAWNFAIL: class '%1' failed to createVehicle at %2 - check classname.", _gunClass, _gunPos];
    ["WARNING", Format ["Server_ArtyCache.sqf: ARTY CACHE gun '%1' failed to spawn - feature aborted.", _gunClass]] Call WFBE_CO_FNC_LogContent;
};

_gun setPos _gunPos;
_gun enableSimulation false;
_gun allowDamage false;
missionNamespace setVariable ["WFBE_ARTY_CACHE_GUN", _gun, true];

["INITIALIZATION", Format ["Server_ArtyCache.sqf: ARTY CACHE gun '%1' spawned at %2.", _gunClass, _gunPos]] Call WFBE_CO_FNC_LogContent;

//--- ─────────────────────────────────────────────────────────────────────────
//--- MAP MARKER (server-created = globally visible on all clients incl. JIP).
//--- Initial colour: neutral yellow (no owner yet).
//--- ─────────────────────────────────────────────────────────────────────────
if (getMarkerColor _mkrName == "") then {
    createMarker [_mkrName, _gunPos];
    _mkrName setMarkerType "mil_box";
    _mkrName setMarkerColor "ColorYellow";
    _mkrName setMarkerText "ARTY CACHE";
    _mkrName setMarkerSize [1, 1];
};

//--- ─────────────────────────────────────────────────────────────────────────
//--- STATE VARIABLES
//--- ─────────────────────────────────────────────────────────────────────────
//--- Current owner (sideLogic = no owner / neutral).
missionNamespace setVariable ["WFBE_ARTY_CACHE_OWNER", sideLogic, true];
//--- First-capture bonus paid flag.
missionNamespace setVariable ["wfbe_arty_cache_paid", false];

//--- ─────────────────────────────────────────────────────────────────────────
//--- SIDE COLOUR HELPER (absolute; mirrors Server_Oilfields.sqf WFBE_FNC_OilfieldColor).
//--- ─────────────────────────────────────────────────────────────────────────
WFBE_FNC_ArtyCacheColor = {
    private ["_s"];
    _s = _this;
    switch (true) do {
        case (_s == west):       { "ColorBlue"   };
        case (_s == east):       { "ColorRed"    };
        case (_s == resistance): { "ColorGreen"  };
        default                  { "ColorYellow" };
    };
};

//--- Short display name (mirrors Server_Oilfields.sqf WFBE_FNC_OilfieldSideName).
WFBE_FNC_ArtyCacheSideName = {
    private ["_s"]; _s = _this;
    switch (_s) do {
        case west:       { "BLUFOR"   };
        case east:       { "OPFOR"    };
        case resistance: { "GUER"     };
        default          { "NEUTRAL"  };
    };
};

["INITIALIZATION", "Server_ArtyCache.sqf: ARTY CACHE marker created. Starting scan loop."] Call WFBE_CO_FNC_LogContent;

//--- ─────────────────────────────────────────────────────────────────────────
//--- SCAN LOOP
//--- A2-OA 1.64 idiom: nearEntities returns an array; side checks use count +
//--- forEach (NOT findIf/apply - those are A3-only). Mirrors server_town.sqf.
//--- ─────────────────────────────────────────────────────────────────────────
while { !(missionNamespace getVariable ["WFBE_GameOver", false]) } do {
    sleep _scanInterval;

    private ["_nearby","_westCount","_eastCount","_curOwner","_newSide","_sideStr","_mkrColor","_msg","_paid","_gunTransfer"];
    _curOwner = missionNamespace getVariable ["WFBE_ARTY_CACHE_OWNER", sideLogic];

    //--- Scan all alive man/vehicle types in the capture radius (A2-OA nearEntities syntax).
    _nearby = _gunPos nearEntities [["Man","Car","Tank","APC","Air"], _scanRadius];

    _westCount = 0;
    _eastCount = 0;
    {
        if (alive _x) then {
            if (side _x == west) then { _westCount = _westCount + 1 };
            if (side _x == east) then { _eastCount = _eastCount + 1 };
        };
    } forEach _nearby;

    //--- Determine capturing side: one side present + other absent = hold.
    //--- Contested (both > 0) or empty (both = 0) = no change.
    _newSide = sideLogic;
    if (_westCount > 0 && _eastCount == 0) then { _newSide = west };
    if (_eastCount > 0 && _westCount == 0) then { _newSide = east };

    //--- Flip only if a different real side is now in sole control.
    if (_newSide != sideLogic && _newSide != _curOwner) then {
        _sideStr  = _newSide Call WFBE_FNC_ArtyCacheSideName;
        _mkrColor = _newSide Call WFBE_FNC_ArtyCacheColor;

        //--- Recolour marker on capture.
        _mkrName setMarkerColor _mkrColor;
        _mkrName setMarkerText ("ARTY CACHE [" + _sideStr + "]");

        //--- Update owner in namespace (broadcast to JIP clients via true).
        missionNamespace setVariable ["WFBE_ARTY_CACHE_OWNER", _newSide, true];

        //--- One-time supply bonus on the FIRST EVER capture.
        _paid = missionNamespace getVariable ["wfbe_arty_cache_paid", false];
        if (!_paid) then {
            [_newSide, _bonus, "Arty cache captured - first-capture supply bonus.", false] Call ChangeSideSupply;
            missionNamespace setVariable ["wfbe_arty_cache_paid", true];
            diag_log Format ["ARTYCACHE|BONUS|side=%1|bonus=%2|t=%3", _sideStr, _bonus, round time];
            ["INFORMATION", Format ["Server_ArtyCache.sqf: First-capture bonus of %1 supply awarded to %2.", _bonus, _sideStr]] Call WFBE_CO_FNC_LogContent;
        };

        //--- Optional gun transfer (GUN_TRANSFER=1 only; adds AI crew — off by default).
        _gunTransfer = missionNamespace getVariable ["WFBE_C_ARTY_CACHE_GUN_TRANSFER", 0];
        if (_gunTransfer == 1 && (missionNamespace getVariable ["wfbe_arty_cache_paid", false])) then {
            //--- Transfer the gun to the capturing side by enabling simulation + setting a new crew.
            //--- Group-budget note: this spawns one group (1-2 crew). Spec: only at SUBSEQUENT recaptures
            //--- (after the first-capture bonus has been paid), so the bonus path stays simple.
            _gun enableSimulation true;
            _gun allowDamage true;
            private ["_crewGrp","_crewUnit"];
            _crewGrp = createGroup _newSide;
            _crewUnit = _crewGrp createUnit [_gunClass, _gunPos, [], 0, "NONE"];
            if (!isNull _crewUnit) then { _crewUnit moveInAny _gun };
            diag_log Format ["ARTYCACHE|GUNTRANSFER|side=%1|t=%2", _sideStr, round time];
        };

        //--- Announce to all clients.
        _msg = Format ["Arty cache captured by %1!", _sideStr];
        [nil, "DashboardAnnounce", [_msg]] Call WFBE_CO_FNC_SendToClients;

        diag_log Format ["ARTYCACHE|FLIP|newOwner=%1|west=%2|east=%3|t=%4", _sideStr, _westCount, _eastCount, round time];
        ["INFORMATION", Format ["Server_ArtyCache.sqf: ARTY CACHE captured by %1 (westCount=%2, eastCount=%3).", _sideStr, _westCount, _eastCount]] Call WFBE_CO_FNC_LogContent;
    };
};
