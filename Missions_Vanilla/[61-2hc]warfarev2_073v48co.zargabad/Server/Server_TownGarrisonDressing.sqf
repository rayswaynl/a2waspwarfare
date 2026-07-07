/*
    Server_TownGarrisonDressing.sqf -- GUER town-garrison dressing loop (SERVER-only).
    Lane 241 (GR-2026-07-03a). Flag-gated: WFBE_C_GARRISON_DRESSING, default 0.

    Dresses active GUER-held contested towns with a ZU23_Gue static gun +
    optional night SearchLight_RUS, crewed by one WFBE_GUERRESSOLDIER (GUE_Soldier_1).
    Self-cleans on town loss, town inactivity, quiet timeout, or lifetime expiry.
    Modelled on Server_GuerAirDef.sqf: script-local registry, player-safe teardown,
    no wfbe_persistent / wfbe_town_teams / HC delegation.

    Eligibility per tick (all must hold):
      - town sideID == WFBE_C_GUER_ID
      - wfbe_active == true
      - no existing registry entry owns that town
      - at least one WEST or EAST man within WFBE_C_GARRISON_DRESSING_RADIUS
      - global dressed-town count < WFBE_C_GARRISON_DRESSING_MAX

    Registry entry: [_town, _gun, _light, _group, _crew, _spawnTime, _lastEnemyTime]
      _light = objNull when searchlights are disabled or daytime.

    A2 OA 1.64 safe: no isEqualType/isEqualTo/findIf/selectRandom/pushBack/worldSize.
    private [array] style used throughout.
*/
if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING", 0]) < 1) exitWith {};

private ["_interval","_maxDressed","_radius","_lifetime","_quiet","_searchlightOn",
         "_gunClass","_lightClass","_soldierClass","_registry"];

_interval      = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_INTERVAL", 45];
_maxDressed    = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_MAX", 6];
_radius        = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_RADIUS", 900];
_lifetime      = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_LIFETIME", 900];
_quiet         = _radius; //--- initial quiet threshold = proximity radius; re-read each tick below.
_searchlightOn = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_SEARCHLIGHT", 1];
_gunClass      = "ZU23_Gue";
_lightClass    = "SearchLight_RUS";

//--- Wait for towns + GUER side data (mirrors GuerAirDef/GuerStipend startup gate).
waitUntil {
    (!isNil "towns") && {(count towns) > 0}
    && {!isNil "WFBE_L_GUE"} && {!(isNull (missionNamespace getVariable ["WFBE_L_GUE", objNull]))}
};
sleep 60;

//--- Resolve soldier class (fallback GUE_Soldier_1 matches design anchor).
_soldierClass = missionNamespace getVariable ["WFBE_GUERRESSOLDIER", "GUE_Soldier_1"];
if (_soldierClass == "") then { _soldierClass = "GUE_Soldier_1"; };

//--- Script-local registry. NOT on missionNamespace, NOT wfbe_persistent.
_registry = [];

["INITIALIZATION", "Server_TownGarrisonDressing.sqf: GARRISON DRESSING started."] Call WFBE_CO_FNC_LogContent;
diag_log format ["GARNDRESS|START|interval=%1|cap=%2|radius=%3|lifetime=%4|searchlight=%5",
    _interval, _maxDressed, _radius, _lifetime, _searchlightOn];

while {!WFBE_GameOver} do {
    sleep _interval;

    private ["_now","_kept","_townsWithGun","_dressedCount","_perfStart"];
    _perfStart     = diag_tickTime;
    _now           = time;
    _kept          = [];
    _townsWithGun  = [];

    //=== (1) PRUNE + SELF-CLEAN ===============================================================
    {
        private ["_entry","_eTown","_eGun","_eLight","_eGrp","_eCrew",
                 "_eSpawn","_eLastEnemy","_drop","_reason",
                 "_townSide","_townActive","_enemiesNow"];
        _entry      = _x;
        _eTown      = _entry select 0;
        _eGun       = _entry select 1;
        _eLight     = _entry select 2;
        _eGrp       = _entry select 3;
        _eCrew      = _entry select 4;
        _eSpawn     = _entry select 5;
        _eLastEnemy = _entry select 6;

        _drop   = false;
        _reason = "";

        //--- Gun destroyed or null.
        if (isNull _eGun || {!(alive _eGun)}) then { _drop = true; _reason = "gun_dead"; };

        //--- Town side changed or no longer active.
        if (!_drop) then {
            _townSide   = if (isNull _eTown) then {-1} else {_eTown getVariable ["sideID", -1]};
            _townActive = if (isNull _eTown) then {false} else {_eTown getVariable ["wfbe_active", false]};
            if (_townSide != WFBE_C_GUER_ID) then { _drop = true; _reason = "town_lost"; };
            if (!_drop && {!_townActive}) then { _drop = true; _reason = "town_inactive"; };
        };

        //--- Refresh last-enemy timestamp.
        if (!_drop && {!(isNull _eTown)}) then {
            _enemiesNow = {alive _x && {((side _x) == west) || {(side _x) == east}}}
                count ((getPos _eTown) nearEntities [["Man"], _radius]);
            if (_enemiesNow > 0) then { _eLastEnemy = _now; };
        };

        //--- Quiet too long.
        if (!_drop && {(_now - _eLastEnemy) > _quiet}) then { _drop = true; _reason = "quiet"; };

        //--- Lifetime exceeded.
        if (!_drop && {(_now - _eSpawn) > _lifetime}) then { _drop = true; _reason = "lifetime"; };

        if (_drop) then {
            //--- Player-safe teardown (GUER is playable): never delete a player-occupied hull.
            if (!isNull _eCrew && {alive _eCrew} && {!(isPlayer _eCrew)}) then { deleteVehicle _eCrew; };
            if (!isNull _eGrp) then {
                { if (!(isPlayer _x)) then { deleteVehicle _x; }; } forEach (units _eGrp);
                deleteGroup _eGrp;
            };
            if (!isNull _eLight && {alive _eLight}) then { deleteVehicle _eLight; };
            if (!isNull _eGun && {alive _eGun} && {({isPlayer _x} count (crew _eGun)) == 0}) then {
                deleteVehicle _eGun;
            };
            diag_log format ["GARNDRESS|REMOVE|town=%1|reason=%2|remaining=%3",
                (if (isNull _eTown) then {"?"} else {_eTown getVariable ["name","?"]}),
                _reason, (count _kept)];
        } else {
            _kept         = _kept + [[_eTown, _eGun, _eLight, _eGrp, _eCrew, _eSpawn, _eLastEnemy]];
            _townsWithGun = _townsWithGun + [_eTown];
        };
    } forEach _registry;
    _registry     = _kept;
    _dressedCount = count _registry;

    //=== (2) MAINTAIN: dress one eligible active GUER town per cycle =========================
    {
        private ["_town","_pos","_tRange","_enemies","_bear","_gunPos",
                 "_tNameHash","_tIdx","_gun","_grp","_crew","_light","_isNight"];
        _town = _x;

        if (_dressedCount < _maxDressed
            && {!(isNull _town)}
            && {(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID}
            && {_town getVariable ["wfbe_active", false]}
            && {!(_town in _townsWithGun)}) then {

            //--- Proximity gate: at least one WEST or EAST man near the town.
            _tRange  = (_town getVariable ["range", 600]) max 300;
            _enemies = {alive _x && {((side _x) == west) || {(side _x) == east}}}
                count ((getPos _town) nearEntities [["Man"], _radius]);

            if (_enemies > 0) then {
                _pos = getPos _town;

                //--- Deterministic bearing from town name to keep placement stable across ticks.
                //--- Sum foreachIndex over name chars as a cheap stable hash.
                _tNameHash = 0;
                { _tNameHash = _tNameHash + _foreachIndex; } forEach (toArray (_town getVariable ["name", ""]));  //--- HOTFIX 2026-07-07: forEach over a String throws "Type String, expected Array" on A2 OA (live-burn RC12 #771). toArray converts the name to a char-code array so the deterministic name-length hash actually computes.
                _bear = (_tNameHash * 73 + 17) mod 360;

                //--- Place on ring between 40%-70% of town range (perimeter, clear of centre).
                _tIdx   = (_tNameHash mod 3) + 1;
                _gunPos = [
                    (_pos select 0) + ((_tRange * 0.4) + (_tRange * 0.1 * _tIdx)) * (sin _bear),
                    (_pos select 1) + ((_tRange * 0.4) + (_tRange * 0.1 * _tIdx)) * (cos _bear),
                    0
                ];

                //--- Create the ZU-23 server-side.
                _gun = _gunClass createVehicle _gunPos;

                if (!isNull _gun) then {
                    _gun setPos _gunPos;
                    _gun setDir (_bear + 180); //--- face toward town centre from the perimeter.
                    _gun setVariable ["wfbe_garrison_dressing", true, false];

                    //--- Create the GUER group (server-local).
                    _grp  = [resistance, "town-garrison-dressing"] Call WFBE_CO_FNC_CreateGroup;
                    _crew  = objNull;
                    _light = objNull;

                    if (!isNull _grp) then {
                        _crew = [_soldierClass, _grp, _gunPos, WFBE_C_GUER_ID] Call WFBE_CO_FNC_CreateUnit;

                        if (!isNull _crew) then {
                            //--- Move in as gunner; retry once (Common_CreateUnitForStaticDefence idiom).
                            _crew moveInGunner _gun;
                            if ((gunner _gun) != _crew) then {
                                sleep 1;
                                if ((gunner _gun) != _crew) then { _crew moveInGunner _gun; };
                            };
                            if ((gunner _gun) == _crew) then {
                                _crew disableAI "MOVE";
                                _crew allowFleeing 0;
                            };

                            //--- Optional night searchlight.
                            _isNight = ((date select 3) < 6) || {(date select 3) >= 20};
                            if (_searchlightOn >= 1 && {_isNight}) then {
                                _light = _lightClass createVehicle
                                    [(_gunPos select 0) + 10 * (sin (_bear + 90)),
                                     (_gunPos select 1) + 10 * (cos (_bear + 90)),
                                     0];
                                _light setDir (_bear + 180);
                            };

                            _registry     = _registry + [[_town, _gun, _light, _grp, _crew, time, time]];
                            _townsWithGun = _townsWithGun + [_town];
                            _dressedCount = _dressedCount + 1;

                            diag_log format ["GARNDRESS|PLACE|town=%1|bear=%2|enemies=%3|night=%4|count=%5",
                                (_town getVariable ["name","?"]), _bear, _enemies, _isNight, _dressedCount];
                        } else {
                            //--- Crew failed: clean gun + group.
                            if (!isNull _gun && {({isPlayer _x} count (crew _gun)) == 0}) then { deleteVehicle _gun; };
                            deleteGroup _grp;
                            diag_log format ["GARNDRESS|FAIL|town=%1|reason=crew_null", (_town getVariable ["name","?"])];
                        };
                    } else {
                        //--- Group failed: clean gun.
                        if (!isNull _gun && {({isPlayer _x} count (crew _gun)) == 0}) then { deleteVehicle _gun; };
                        diag_log format ["GARNDRESS|FAIL|town=%1|reason=group_null", (_town getVariable ["name","?"])];
                    };
                };
            };
        };
    } forEach towns;

    //--- Re-read quiet window each cycle (allows host tuning without restart).
    _quiet = missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING_RADIUS", 900];

    diag_log format ["GARNDRESS|TICK|dressed=%1|towns=%2|tickMs=%3",
        _dressedCount, (count towns), round((diag_tickTime - _perfStart) * 1000)];
};
