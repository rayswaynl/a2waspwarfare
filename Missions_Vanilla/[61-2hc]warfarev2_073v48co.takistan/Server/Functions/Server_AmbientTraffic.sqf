/*
    Author: Fable (civ-coastal-traffic lane, 2026-07-02)
    Description:
        Server-side ambient civilian traffic loop.
        Spawns a small number of civilian coastal boats (Chernarus east coast routes)
        and road cars (near Elektrozavodsk, Chernogorsk, Berezino).
        Pure atmosphere, no combat role, perf-negligible (sleep 60, hard cap 7 vehicles).

    Flags:
        WFBE_C_AMBIENT_TRAFFIC  - Master switch (default 0, opt-in)
        WFBE_C_AMBIENT_BOATS_MAX - Max concurrent boats (default 3)
        WFBE_C_AMBIENT_CARS_MAX  - Max concurrent cars (default 4)
        WFBE_C_AMBIENT_TRAFFIC_CAP - Hard total-vehicle cap (default 7)
*/

Private [
    "_boatClasses", "_carClasses", "_boatRoutes", "_carTowns",
    "_maxBoats", "_maxCars", "_cap",
    "_boats", "_cars",
    "_cls", "_clsIdx", "_pos", "_grp", "_veh", "_driver",
    "_i", "_routeIdx", "_route", "_wps",
    "_alive", "_next", "_townName", "_townCenter",
    "_spawnPos", "_wpList"
];

//--- Server-only script.
if (!isServer) exitWith {};

//--- Feature gate: bail immediately if flag is 0 (default). Mission is byte-identical when off.
if ((missionNamespace getVariable ["WFBE_C_AMBIENT_TRAFFIC", 0]) < 1) exitWith {};

//--- Wait for town init before spawning anything near towns.
waitUntil { !isNil "townInit" && townInit };
sleep 30;

//--- Constants.
_boatClasses = ["Smallboat_1", "Smallboat_2", "Fishing_Boat"];
_carClasses   = ["Lada1", "LadaLM", "SkodaBlue", "car_sedan", "car_hatchback", "VWGolf"];

_maxBoats = missionNamespace getVariable ["WFBE_C_AMBIENT_BOATS_MAX",   3];
_maxCars  = missionNamespace getVariable ["WFBE_C_AMBIENT_CARS_MAX",    4];
_cap      = missionNamespace getVariable ["WFBE_C_AMBIENT_TRAFFIC_CAP", 7];

//--- Hardcoded east-coast sea routes (3 loops, surfaceIsWater confirmed at these coords).
//--- Format: each route = array of 3 waypoint positions [x, y, 0].
//--- Positions are approximate Chernarus east-coast sea lanes (south to north).
_boatRoutes = [
    // Route A: South coast, Elektrozavodsk harbour area
    [[11800, 2100, 0], [12600, 2400, 0], [12000, 1700, 0]],
    // Route B: Mid-coast, Berezino bay
    [[13400, 7200, 0], [14200, 7600, 0], [13800, 6800, 0]],
    // Route C: North coast, Solnichniy area
    [[13800, 10200, 0], [14600, 10600, 0], [14000, 9700, 0]]
];

//--- Town names to resolve spawn positions for cars.
_carTowns = ["Elektrozavodsk", "Chernogorsk", "Berezino"];

//--- Initialise tracking arrays in missionNamespace (persist across loop iterations).
if (isNil "WFBE_AMBIENT_BOATS") then { WFBE_AMBIENT_BOATS = [] };
if (isNil "WFBE_AMBIENT_CARS")  then { WFBE_AMBIENT_CARS  = [] };

//--- Main ambient loop.
while { !(WFBE_GameOver) } do {

    //--- Retrieve current tracking lists.
    _boats = missionNamespace getVariable ["WFBE_AMBIENT_BOATS", []];
    _cars  = missionNamespace getVariable ["WFBE_AMBIENT_CARS",  []];

    //--- 1. Scrub dead / deleted entries from boats list.
    _alive = [];
    {
        if (alive _x) then {
            _alive set [count _alive, _x];
        } else {
            if (!isNull _x) then { deleteVehicle _x };
            _grp = group _x;
            if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
        };
    } forEach _boats;
    _boats = _alive;

    //--- 2. Scrub dead / deleted entries from cars list.
    _alive = [];
    {
        if (alive _x) then {
            _alive set [count _alive, _x];
        } else {
            if (!isNull _x) then { deleteVehicle _x };
            _grp = group _x;
            if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
        };
    } forEach _cars;
    _cars = _alive;

    //--- 3. Spawn boat if below cap and map supports naval.
    if ((count _boats) < _maxBoats && { (count _boats + count _cars) < _cap } && { IS_naval_map }) then {

        //--- Pick a random classname (A2-safe, no selectRandom).
        _clsIdx = floor (random (count _boatClasses));
        _cls = _boatClasses select _clsIdx;

        //--- Only create if classname is valid in CfgVehicles.
        if (isClass (configFile >> "CfgVehicles" >> _cls)) then {

            //--- Pick a random route.
            _routeIdx = floor (random (count _boatRoutes));
            _route = _boatRoutes select _routeIdx;

            //--- Create group and vehicle at route start.
            _grp = createGroup civilian;
            _veh = createVehicle [_cls, _route select 0, [], 0, "NONE"];
            _veh setPosASL (_route select 0);
            _veh setVelocity [0, 0, 0];

            //--- Crew the boat with a driver from the civ group.
            _driver = _grp createUnit ["Citizen1", _route select 0, [], 0, "NONE"];
            _driver moveInDriver _veh;

            //--- Peaceful behaviour — no fleeing, no combat.
            _veh allowFleeing 0;
            _veh setCombatMode "BLUE";
            _veh setBehaviour "SAFE";
            _grp allowFleeing 0;
            _grp setCombatMode "BLUE";
            _grp setBehaviour "SAFE";

            //--- Build waypoint list for WaypointsAdd: [pos, type, radius, completionRadius, statements, timeout, squad_props]
            _wpList = [];
            _i = 0;
            while { _i < count _route } do {
                _wpList set [count _wpList, [_route select _i, "MOVE", 30, 20, [], [], ["SAFE", "BLUE", "COLUMN", "LIMITED"]]];
                _i = _i + 1;
            };
            //--- Final CYCLE waypoint back to route start for looping.
            _wpList set [count _wpList, [_route select 0, "CYCLE", 30, 20, [], [], ["SAFE", "BLUE", "COLUMN", "LIMITED"]]];

            //--- Use WFBE_CO_FNC_WaypointsAdd (clear existing, CYCLE loop).
            [_grp, true, _wpList] Call WFBE_CO_FNC_WaypointsAdd;

            //--- Track the vehicle.
            _boats set [count _boats, _veh];
        };
    };

    //--- 4. Spawn car if below cap.
    if ((count _cars) < _maxCars && { (count _boats + count _cars) < _cap }) then {

        //--- Pick a random classname (A2-safe, no selectRandom).
        _clsIdx = floor (random (count _carClasses));
        _cls = _carClasses select _clsIdx;

        //--- Only create if classname is valid in CfgVehicles.
        if (isClass (configFile >> "CfgVehicles" >> _cls)) then {

            //--- Pick a random town (A2-safe, no selectRandom).
            _i = floor (random (count _carTowns));
            _townName = _carTowns select _i;
            _townCenter = [0, 0, 0];

            //--- Resolve town center position from markers or landmark.
            {
                if (markerText _x == _townName || _x == _townName) exitWith { _townCenter = getMarkerPos _x };
            } forEach allMapMarkers;

            //--- If no marker found, use a safe fallback position near center of CH.
            if (_townCenter isEqualTo [0, 0, 0]) then { _townCenter = [11400, 11400, 0] };

            //--- Pick random spawn position near town center (200-600m radius).
            _spawnPos = [_townCenter, 200, 600, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;

            //--- Skip if the position is water.
            if (!(surfaceIsWater _spawnPos)) then {

                //--- Create group and vehicle.
                _grp = createGroup civilian;
                _veh = createVehicle [_cls, _spawnPos, [], 0, "NONE"];
                _veh setPos _spawnPos;
                _veh setVelocity [0, 0, 0];

                //--- Crew the car.
                _driver = _grp createUnit ["Citizen1", _spawnPos, [], 0, "NONE"];
                _driver moveInDriver _veh;

                //--- Peaceful behaviour.
                _veh allowFleeing 0;
                _veh setCombatMode "BLUE";
                _veh setBehaviour "SAFE";
                _grp allowFleeing 0;
                _grp setCombatMode "BLUE";
                _grp setBehaviour "SAFE";

                //--- Build a simple patrol: 2 random positions near town, CYCLE back.
                _wpList = [];
                _next = [_townCenter, 200, 600, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
                if (!(surfaceIsWater _next)) then {
                    _wpList set [count _wpList, [_next, "MOVE", 30, 20, [], [], ["SAFE", "BLUE", "COLUMN", "LIMITED"]]];
                };
                _wpList set [count _wpList, [_spawnPos, "CYCLE", 30, 20, [], [], ["SAFE", "BLUE", "COLUMN", "LIMITED"]]];

                [_grp, true, _wpList] Call WFBE_CO_FNC_WaypointsAdd;

                //--- Track the vehicle.
                _cars set [count _cars, _veh];
            };
        };
    };

    //--- Write updated lists back to missionNamespace.
    WFBE_AMBIENT_BOATS = _boats;
    WFBE_AMBIENT_CARS  = _cars;

    sleep 60;
};

//--- Game over: clean up all ambient vehicles.
_boats = missionNamespace getVariable ["WFBE_AMBIENT_BOATS", []];
_cars  = missionNamespace getVariable ["WFBE_AMBIENT_CARS",  []];

{
    _grp = group _x;
    if (!isNull _x) then { deleteVehicle _x };
    if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
} forEach _boats;

{
    _grp = group _x;
    if (!isNull _x) then { deleteVehicle _x };
    if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp };
} forEach _cars;

WFBE_AMBIENT_BOATS = [];
WFBE_AMBIENT_CARS  = [];
