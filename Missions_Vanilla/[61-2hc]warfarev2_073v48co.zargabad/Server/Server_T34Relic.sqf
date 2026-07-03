//--- Server_T34Relic.sqf  (lane 183 — T-34 Relic contested vehicle)
//--- Spawned from Init_Server.sqf only when WFBE_C_T34_RELIC == 1.
//--- Locality: SERVER only.  Called once after commonInitComplete + townInit.
//---
//--- This feature is DISTINCT from the arty-cache objective (different file, different object).
//---
//--- Behaviour:
//---   One uncrewed T34_TK_GUE_EP1 is parked at a neutral town at match start.
//---   First side to put a player in the driver seat "claims" it:
//---     - The vehicle's wfbe_side_id is updated to the claiming side.
//---     - The vehicle's "killed" EH is re-wired to that side (bounty registration).
//---   A 15-second ownership scan loop runs for the life of the vehicle.
//---
//--- CH worldName gate: the town-pick logic reads the live "towns" array, which is
//---   map-agnostic.  The T34_TK_GUE_EP1 classname exists in Combined Ops on BOTH
//---   maps (confirmed: Units_CO_GUE.sqf:116; Groups_TKGUE.sqf:131).  No CH-only gate
//---   is needed.  If a host wants to disable it on Takistan the flag (WFBE_C_T34_RELIC)
//---   is the correct lever.

if (!isServer) exitWith {};

//--- Flag guard — must be first real line (flag-off inertness).
if ((missionNamespace getVariable ["WFBE_C_T34_RELIC", 0]) != 1) exitWith {
    ["INFORMATION", "Server_T34Relic.sqf: WFBE_C_T34_RELIC=0 -- feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

//--- Wait for town data.
waitUntil { !isNil "commonInitComplete" && { commonInitComplete } };
waitUntil { !isNil "townInit" && { townInit } };
waitUntil { !isNil "towns" && { count towns > 0 } };

["INITIALIZATION", "Server_T34Relic.sqf: T-34 Relic feature enabled -- selecting spawn town."] Call WFBE_CO_FNC_LogContent;

//--- ── TOWN SELECTION ──────────────────────────────────────────────────────
//--- Pick a town that is neutral at match start (sideID not WESTID/EASTID).
//--- Falls back to the map-centre town if every town is already pre-assigned.
//--- A2-OA-safe: explicit count-loop (no 'select {CODE}' A3-only filter).
private ["_neutralTowns","_pickTown","_pickPos","_midX","_midY","_bestDist","_tw","_sid","_d"];

_neutralTowns = [];
{
    _tw  = _x;
    _sid = _tw getVariable ["sideID", -1];
    //--- sideID -1 = unset (neutral); 0=WEST 1=EAST 2=RES  Accept -1 and 2 (GUER-held neutral).
    if ((_sid != WESTID) && (_sid != EASTID)) then {
        _neutralTowns set [count _neutralTowns, _tw];
    };
} forEach towns;

//--- If all towns are pre-owned, fall back to a midfield town (nearest map centre).
_pickTown = objNull;
if (count _neutralTowns > 0) then {
    //--- Pick a random neutral town.  A2-OA random() is fine here (town pick variety is low-stakes).
    _pickTown = _neutralTowns select (floor (random (count _neutralTowns)));
} else {
    //--- Fallback: town nearest map centre. Derive centre from WFBE_BOUNDARIESXY so
    //--- ZG (8192m map, centre ~4096) and TK (12800m, centre ~6400) are correct too.
    _midX = (missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360]) / 2;
    _midY = _midX;
    _bestDist = 1e9;
    {
        _d = (getPos _x) distance [_midX, _midY, 0];
        if (_d < _bestDist) then { _bestDist = _d; _pickTown = _x };
    } forEach towns;
    ["WARNING", "Server_T34Relic.sqf: no neutral town found -- falling back to map-centre town."] Call WFBE_CO_FNC_LogContent;
};

if (isNull _pickTown) exitWith {
    ["WARNING", "Server_T34Relic.sqf: town pick failed (towns array empty?) -- aborting relic spawn."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", Format ["Server_T34Relic.sqf: relic will spawn near town '%1' at %2.", _pickTown getVariable ["name","?"], getPos _pickTown]] Call WFBE_CO_FNC_LogContent;

//--- ── SPAWN POSITION ─────────────────────────────────────────────────────
//--- Offset from town centre + isFlatEmpty check; try multiple bearings.
//--- isFlatEmpty args: [radius, height, gradient, objDist, wantRoads, ignore, exclude]
//--- A2-OA 1.64-safe (isFlatEmpty returns [] when not flat).
private ["_basePos","_relicPos","_flat","_tries","_bear","_offset","_cand"];

_basePos   = getPos _pickTown;
_relicPos  = _basePos;
_flat      = [];
_tries     = 0;

while { (count _flat == 0) && { _tries < 24 } } do {
    _bear   = _tries * 15;                          //--- 15-degree steps all around
    _offset = 60 + (_tries * 5);                    //--- walk out 60..175 m
    _cand   = [
        (_basePos select 0) + (_offset * (sin _bear)),
        (_basePos select 1) + (_offset * (cos _bear)),
        0
    ];
    //--- Reject water.
    if (!(surfaceIsWater _cand)) then {
        _flat = _cand isFlatEmpty [5, 0, 2, 8, 0, false, objNull];
        if (count _flat > 0) then { _relicPos = _cand };
    };
    _tries = _tries + 1;
};

if (count _flat == 0) then {
    //--- Last-resort: use the raw town centre.
    _relicPos = _basePos;
    ["WARNING", "Server_T34Relic.sqf: isFlatEmpty found no flat spot -- using raw town centre."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", Format ["Server_T34Relic.sqf: relic spawn position resolved at %1 after %2 tries.", _relicPos, _tries]] Call WFBE_CO_FNC_LogContent;

//--- ── CREATE VEHICLE ─────────────────────────────────────────────────────
//--- createVehicle direct (not Common_CreateVehicle): we want NO initial side ownership,
//--- no team EH, no texture pass.  We wire the kill bounty manually below.
//--- RESISTANCEID (2) is used as the initial side stamp (GUE-faction hull).
private ["_relic","_relicDir"];
_relicDir = floor (random 360);
_relic    = createVehicle ["T34_TK_GUE_EP1", _relicPos, [], 0, "NONE"];
_relic setDir _relicDir;
_relic setVelocity [0, 0, -1];                      //--- settle to ground

if (isNull _relic) exitWith {
    ["WARNING", "Server_T34Relic.sqf: createVehicle T34_TK_GUE_EP1 returned null -- aborting."] Call WFBE_CO_FNC_LogContent;
};

//--- Stamp as GUER (side 2) so salvage / kill-path reads a neutral hull.
_relic setVariable ["wfbe_side_id", RESISTANCEID, true];
//--- Tag for the ownership loop.
_relic setVariable ["wfbe_t34relic", true, true];

//--- Global init so all clients see it on the map.
_relic setVehicleInit Format ["[this, %1] ExecVM 'Common\Init\Init_Unit.sqf'", RESISTANCEID];
processInitCommands;

//--- ── KILL-BOUNTY REGISTRATION ──────────────────────────────────────────
//--- Wire the standard bounty EH (identical pattern to Common_CreateVehicle.sqf:67
//--- and Support_Paratroopers.sqf:57).  Initial side = RESISTANCEID.
//--- The ownership loop below re-wires this EH when a side claims the tank.
private ["_relicKillEH"];
_relicKillEH = _relic addEventHandler ["killed", Format ['[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled', RESISTANCEID]];

//--- Store so the ownership loop can remove + re-add on claim.
_relic setVariable ["wfbe_relic_kill_eh", _relicKillEH];

diag_log Format ["WFBE|T34RELIC|spawned|class=T34_TK_GUE_EP1|pos=%1|dir=%2|town=%3", _relicPos, _relicDir, _pickTown getVariable ["name","?"]];

//--- ── OWNERSHIP SCAN LOOP ───────────────────────────────────────────────
//--- Every 15 s: check who is in the driver seat.  If a PLAYER drives, claim for their side.
//--- Side-switch:  update wfbe_side_id + re-wire the kill bounty EH to the new side.
//--- Runs until the relic is destroyed or no longer alive.
[] spawn {
    private ["_t","_claimedSide","_driver","_driverSide","_oldEH","_newSideID"];

    //--- Recover the relic reference from missionNamespace (spawned block has no closure).
    _t = missionNamespace getVariable ["WFBE_T34_RELIC_OBJ", objNull];

    if (isNull _t) exitWith {
        ["WARNING", "Server_T34Relic.sqf: ownership loop could not find WFBE_T34_RELIC_OBJ -- loop aborted."] Call WFBE_CO_FNC_LogContent;
    };

    _claimedSide = -1;     //--- -1 = unclaimed

    while { alive _t } do {
        sleep 15;

        if (!alive _t) exitWith {};

        _driver = objNull;

        //--- Find the driver slot.  'driver _t' is A2-OA-safe (returns objNull if empty).
        _driver = driver _t;

        if (!isNull _driver && { isPlayer _driver } && { alive _driver }) then {
            _driverSide = side group _driver;
            //--- Convert SIDE -> numeric sideID (GetSideID takes a SIDE, returns a number).
            _newSideID = _driverSide Call WFBE_CO_FNC_GetSideID;

            if (_newSideID != _claimedSide) then {
                //--- Claim for the new side.
                _claimedSide = _newSideID;
                _t setVariable ["wfbe_side_id", _newSideID, true];

                //--- Re-wire kill bounty EH.
                _oldEH = _t getVariable ["wfbe_relic_kill_eh", -1];
                if (_oldEH >= 0) then {
                    _t removeEventHandler ["killed", _oldEH];
                };
                private ["_newEH"];
                _newEH = _t addEventHandler ["killed", Format ['[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled', _newSideID]];
                _t setVariable ["wfbe_relic_kill_eh", _newEH];

                //--- Re-broadcast init so JIP clients see the updated owner side (not the baked RESISTANCEID).
                _t setVehicleInit Format ["[this, %1] ExecVM 'Common\Init\Init_Unit.sqf'", _newSideID];
                processInitCommands;

                diag_log Format ["WFBE|T34RELIC|claimed|sideID=%1|driver=%2", _newSideID, name _driver];
                ["INFORMATION", Format ["Server_T34Relic.sqf: T-34 relic claimed by sideID=%1 (driver: %2).", _newSideID, name _driver]] Call WFBE_CO_FNC_LogContent;
            };
        };
    };

    diag_log "WFBE|T34RELIC|destroyed";
    ["INFORMATION", "Server_T34Relic.sqf: T-34 relic destroyed."] Call WFBE_CO_FNC_LogContent;
};

//--- Store reference for the spawned ownership loop above.
missionNamespace setVariable ["WFBE_T34_RELIC_OBJ", _relic];

["INITIALIZATION", "Server_T34Relic.sqf: T-34 relic spawned and ownership loop started."] Call WFBE_CO_FNC_LogContent;
