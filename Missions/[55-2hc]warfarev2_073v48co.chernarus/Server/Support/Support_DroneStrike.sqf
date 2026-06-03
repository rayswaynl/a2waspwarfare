//--- Support_DroneStrike.sqf — Mixed Saturation Strike orchestrator. [AI-PILOT FLIGHT]
//--- The ENGINE flies the Ka-137s (a hidden AI pilot + doMove + flyInHeight) — no scripted setVelocity, so no
//--- crashes / sibling-collisions / jitter, and natural banking + descent. The script only: spawns over the sea,
//--- picks targets, and detonates. Payload: ["DroneStrike", side, callPos, playerTeam].

private ["_side","_destination","_playerTeam","_sideID","_enemySides","_aaTypes","_model","_pilotType","_alt",
        "_flareN","_total","_zoneR","_warhead","_warhead2","_scatter","_hp","_stagger","_loiterTime","_diveSound","_enhanced",
        "_coastDir","_coastDist","_a","_w","_r","_spawnDist","_spawnPos","_drones","_groups","_i","_role","_myAlt",
        "_grp","_drone","_pilot","_activeKey","_active","_x"];

_side        = _this select 1;
_destination = _this select 2;
_playerTeam  = _this select 3;
_sideID      = _side call GetSideID;

//--- Lobby toggle.
if ((missionNamespace getVariable ["WFBE_C_DRONE_ENABLED", 1]) != 1) exitWith {
    ["INFORMATION","Support_DroneStrike.sqf : disabled by lobby param (WFBE_C_DRONE_ENABLED), ignoring."] Call WFBE_CO_FNC_LogContent;
};

//--- Threeway-safe enemy sides + real AA classnames.
_enemySides = WFBE_PRESENTSIDES - [_side];
_aaTypes = ["M6_EP1"];
{ _aaTypes = _aaTypes + (missionNamespace getVariable [Format ["WFBE_%1_Defenses_AA", _x], []]) } forEach ["WEST","EAST","GUER"];

_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") then {_model = "Ka137_PMC"};
_pilotType = missionNamespace getVariable Format ["WFBE_%1PILOT", str _side];
if (isNil "_pilotType") then {_pilotType = missionNamespace getVariable Format ["WFBE_%1SOLDIER", str _side]};

_alt        = WFBE_C_DRONE_CRUISE_ALT;
_flareN     = WFBE_C_DRONE_FLARE_COUNT;
_total      = WFBE_C_DRONE_FLARE_COUNT + WFBE_C_DRONE_MUNITION_COUNT;
_zoneR      = WFBE_C_DRONE_ZONE_RADIUS;
_warhead    = WFBE_C_DRONE_WARHEAD;
_warhead2   = missionNamespace getVariable ["WFBE_C_DRONE_WARHEAD2", "Bo_GBU12_LGB"];
_scatter    = WFBE_C_DRONE_SCATTER;
_hp         = WFBE_C_DRONE_HP;
_stagger    = WFBE_C_DRONE_DIVE_STAGGER;
_loiterTime = WFBE_C_DRONE_LOITER_TIME;
_diveSound  = missionNamespace getVariable ["WFBE_C_DRONE_DIVE_SOUND", "inboundMissileGround_cont"];
_enhanced   = (missionNamespace getVariable ["WFBE_C_DRONE_ENHANCED", 1]) == 1;   //--- optional FX/orbit/reward layer.

["INFORMATION", Format ["Support_DroneStrike.sqf : [%1] Team [%2] strike at %3 (model %4, enemies %5).", str _side, _playerTeam, _destination, _model, _enemySides]] Call WFBE_CO_FNC_LogContent;

//--- Concurrent cap.
_activeKey = Format ["WFBE_DRONE_ACTIVE_%1", str _side];
_active = missionNamespace getVariable [_activeKey, 0];
if (_active >= WFBE_C_DRONE_CONCURRENT_CAP) exitWith {
    ["INFORMATION","Support_DroneStrike.sqf : concurrent cap reached, ignoring."] Call WFBE_CO_FNC_LogContent;
};
missionNamespace setVariable [_activeKey, _active + 1];

//--- Scripted survivability + delayed kill-attribution. Crash/sibling/self/terrain ignored; a real shooter chips HP AND gets kill credit.
WFBE_DroneHandleDamage = {
    private ["_unit","_dmg","_src","_prev","_delta","_h"];
    _unit = _this select 0;
    _dmg  = _this select 2;
    _src  = _this select 3;
    if (isNull _src || {_src == _unit} || {!isNil {_src getVariable "wfbe_drone_role"}}) exitWith {0};   //--- ignore crash / sibling / self / terrain
    _prev = damage _unit;
    _delta = _dmg - _prev;
    if (_delta < WFBE_C_DRONE_MIN_HIT) exitWith {0};   //--- sub-.50 plink
    _unit setVariable ["wfbe_lasthitby", _src, true];  //--- reuse the mission's delayed kill-reward path.
    _unit setVariable ["wfbe_lasthittime", time, true];
    _h = (_unit getVariable ["wfbe_drone_hp", WFBE_C_DRONE_HP]) - 1;
    _unit setVariable ["wfbe_drone_hp", _h, true];
    if (_h <= 0) exitWith {1};   //--- depleted -> destroy
    0
};

//--- Real missile spoof for the flare drones (distilled from IRS).
WFBE_DroneSpoofMissile = {
    private ["_drone","_ammo","_shooter","_m","_cnt","_v"];
    _drone = _this select 0; _ammo = _this select 1; _shooter = _this select 2;
    _m = nearestObject [_shooter, _ammo];
    if (isNull _m) exitWith {};
    _cnt = 0;
    while {!isNull _m && alive _drone && (_m distance _drone) > 14 && _cnt < 60} do {
        if (random 1 < 0.30) then { _v = velocity _m; _m setVelocity [(_v select 0)+(random 36-18), (_v select 1)+(random 36-18), (_v select 2)+(random 10-5)] };
        _cnt = _cnt + 1; sleep 0.05;
    };
};

//--- Friendly map marker + inbound announcer (broadcast: friendly precise, enemy vague).
[nil, "HandleSpecial", ["drone-strike-fx", _destination, _side]] Call WFBE_CO_FNC_SendToClients;

//--- Naval spawn: over the SEA off the nearest OPEN coast to the target.
_coastDir = -1; _coastDist = 999999;
for "_a" from 0 to 345 step 15 do {
    _w = -1;
    for "_r" from 300 to 12000 step 300 do {
        if (surfaceIsWater [(_destination select 0) + _r * sin _a, (_destination select 1) + _r * cos _a]) exitWith {_w = _r};
    };
    if (_w > 0 && {surfaceIsWater [(_destination select 0) + (_w + 1500) * sin _a, (_destination select 1) + (_w + 1500) * cos _a]} && {_w < _coastDist}) then {
        _coastDist = _w; _coastDir = _a;
    };
};
if (_coastDir < 0) then { _coastDir = random 360; _coastDist = WFBE_C_DRONE_SPAWN_DIST; };
_spawnDist = _coastDist + WFBE_C_DRONE_OFFSHORE + random 400;
_spawnPos = [(_destination select 0) + _spawnDist * sin _coastDir, (_destination select 1) + _spawnDist * cos _coastDir, _alt];

//--- Spawn the package: each Ka-137 + a hidden AI pilot in its own group; the ENGINE flies them.
_drones = []; _groups = [];
for "_i" from 0 to (_total - 1) do {
    _role = if (_i < _flareN) then {"flare"} else {"munition"};
    _myAlt = _alt + (_i * 22);   //--- altitude tiers so they never share airspace.
    _grp = createGroup _side;
    _drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
    _drone setPosATL [(_spawnPos select 0) + (_i * 30), (_spawnPos select 1) + (_i * 22), _myAlt];
    _pilot = [_pilotType, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
    _pilot moveInDriver _drone;
    _grp setBehaviour "CARELESS";
    _grp setCombatMode "BLUE";   //--- never fire.
    {_pilot disableAI _x} forEach ["TARGET","AUTOTARGET"];
    _drone flyInHeight _myAlt;
    _drone lockDriver true;
    _drone setVariable ["wfbe_drone_role", _role, true];
    _drone setVariable ["wfbe_drone_hp", _hp, true];
    _drone setVariable ["wfbe_phase", _i, true];
    _drone setVariable ["wfbe_sideID", _sideID, false];
    _drone addEventHandler ["HandleDamage", {_this call WFBE_DroneHandleDamage}];
    _drone addEventHandler ["Killed", {[_this select 0, _this select 1, (_this select 0) getVariable "wfbe_sideID"] Spawn WFBE_CO_FNC_OnUnitKilled}];
    if (_enhanced) then {[nil, "HandleSpecial", ["drone-fx", "trail", _drone]] Call WFBE_CO_FNC_SendToClients};   //--- client-side smoke contrail.
    _drones set [count _drones, _drone];
    _groups set [count _groups, _grp];
};
processInitCommands;
["INFORMATION", Format ["Support_DroneStrike.sqf : spawned %1 drones (%2 flare / %3 munition, AI-flown) at %4, target %5.", count _drones, _flareN, (_total - _flareN), _spawnPos, _destination]] Call WFBE_CO_FNC_LogContent;
if (_enhanced && {!isNil "UpdateStatistics"}) then {[str _side, 'VehiclesCreated', count _drones] Call UpdateStatistics};

//--- Drive each drone: AI flies it; the script picks targets + detonates.
{
    private "_d"; _d = _x;
    [_d, _destination, _zoneR, _loiterTime, _warhead, _warhead2, _scatter, _stagger, _enemySides, _aaTypes, _diveSound] spawn {
        private ["_d","_dest","_zoneR","_loiterTime","_warhead","_warhead2","_scatter","_stagger","_enemySides","_aaTypes","_diveSound","_enhanced","_ms",
                "_role","_phase","_pilot","_loiterPt","_loiterAng","_endT","_idl","_target","_cands","_valid","_aa","_aimObj","_aimPos","_t0","_imp","_ang","_x"];
        _d          = _this select 0;
        _dest       = _this select 1;
        _zoneR      = _this select 2;
        _loiterTime = _this select 3;
        _warhead    = _this select 4;
        _warhead2   = _this select 5;
        _scatter    = _this select 6;
        _stagger    = _this select 7;
        _enemySides = _this select 8;
        _aaTypes    = _this select 9;
        _diveSound  = _this select 10;
        _enhanced   = _this select 11;
        _ms         = _this select 12;
        _role  = _d getVariable "wfbe_drone_role";
        _phase = _d getVariable "wfbe_phase";
        _pilot = driver _d;
        //--- a distinct holding point around the target per drone (spread; no pile-up).
        _loiterPt = [(_dest select 0) + (_zoneR * 0.7) * sin (_phase * 72), (_dest select 1) + (_zoneR * 0.7) * cos (_phase * 72), 0];
        _loiterAng = _phase * 72;

        //--- INGRESS: AI flies to the zone.
        _pilot doMove _loiterPt;
        _idl = time + 150;
        waitUntil { sleep 1; !alive _d || ((_d distance [_dest select 0, _dest select 1, (getPosATL _d) select 2]) < (_zoneR + 150)) || time > _idl };
        if (!alive _d) exitWith {};

        _endT = time + _loiterTime;

        if (_role == "flare") then {
            _d addEventHandler ["incomingMissile", {
                private "_fd"; _fd = _this select 0;
                if (alive _fd) then {
                    "F_40mm_White" createVehicle (getPosATL _fd);
                    [_this select 0, _this select 1, _this select 2] spawn WFBE_DroneSpoofMissile;
                };
            }];
            while {alive _d && time < (_endT + 25)} do {
                if (_enhanced) then { _loiterAng = _loiterAng + 28; _pilot doMove [(_dest select 0) + _zoneR * sin _loiterAng, (_dest select 1) + _zoneR * cos _loiterAng, 0]; } else { _pilot doMove _loiterPt; };
                "F_40mm_White" createVehicle (getPosATL _d);   //--- conspicuous flare pop.
                if (_enhanced) then {[nil, "HandleSpecial", ["drone-fx", "flarepop", _d]] Call WFBE_CO_FNC_SendToClients};
                sleep 8;
            };
            if (alive _d) then { {deleteVehicle _x} forEach (crew _d); deleteVehicle _d };
        } else {
            //--- MUNITION: search an enemy ground vehicle (AA first), then dive + detonate.
            _target = objNull;
            while {alive _d && isNull _target && time < _endT} do {
                _cands = nearestObjects [_dest, ["LandVehicle","StaticWeapon"], _zoneR];
                _valid = []; _aa = [];
                {
                    if (alive _x && {(side _x) in _enemySides} && {!(_x isKindOf "Air")}) then {
                        _valid set [count _valid, _x];
                        if ((typeOf _x) in _aaTypes || {_x isKindOf "StaticWeapon"}) then {_aa set [count _aa, _x]};
                    };
                } forEach _cands;
                if (count _aa > 0) then {_target = _aa select 0} else {if (count _valid > 0) then {_target = _valid select 0}};
                if (isNull _target) then { if (_enhanced) then { _loiterAng = _loiterAng + 28; _pilot doMove [(_dest select 0) + _zoneR * sin _loiterAng, (_dest select 1) + _zoneR * cos _loiterAng, 0]; } else { _pilot doMove _loiterPt; } };
                sleep 2;
            };

            sleep (_phase * _stagger);   //--- chain the dives.
            if (!alive _d) exitWith {};
            _aimObj = _target;
            _aimPos = if (!isNull _target && {alive _target}) then {getPos _target} else {_dest};
            _d say3D _diveSound;          //--- dive siren.
            if (_enhanced) then {[nil, "HandleSpecial", ["drone-fx", "flame", _d]] Call WFBE_CO_FNC_SendToClients};
            _d flyInHeight 16;            //--- descend onto it.
            _pilot doMove _aimPos;
            _t0 = time;
            waitUntil { sleep 0.3; !alive _d || ((_d distance _aimPos) < 45) || (time - _t0 > 16) };
            if (alive _d) then {
                if (!isNull _aimObj && {alive _aimObj}) then {_aimPos = getPos _aimObj};   //--- re-aim if it moved.
                _ang = random 360;
                _imp = [(_aimPos select 0) + (random _scatter) * sin _ang, (_aimPos select 1) + (random _scatter) * cos _ang, 0];
                //--- 50/50 warhead: even munition = direct HE at ground; odd = a top-attack drop (bomb/SADARM) from altitude.
                if (_phase mod 2 == 0) then {
                    _warhead createVehicle _imp;
                } else {
                    _warhead2 createVehicle [_imp select 0, _imp select 1, 130];
                };
                ["INFORMATION", Format ["Support_DroneStrike.sqf : munition phase %1 struck %2 (warhead %3).", _phase, _imp, (if (_phase mod 2 == 0) then {_warhead} else {_warhead2})]] Call WFBE_CO_FNC_LogContent;
                if (_enhanced && {!isNull _aimObj}) then {
                    [_aimObj, _ms] spawn {
                        private ["_tg","_sd"]; _tg = _this select 0; _sd = _this select 1;
                        sleep 5;
                        if (!alive _tg && {!isNil "ChangeSideSupply"}) then {
                            [_sd, WFBE_C_DRONE_KILL_REWARD, "Drone strike interdiction", false] call ChangeSideSupply;
                            if (!isNil "UpdateStatistics") then {[str _sd, 'VehiclesDestroyed', 1] Call UpdateStatistics};
                        };
                    };
                };
                {deleteVehicle _x} forEach (crew _d); deleteVehicle _d;
            };
        };
    };
} forEach _drones;

//--- Lifecycle cleanup: delete drones + their pilots + groups, decrement the cap.
[_drones, _groups, _activeKey] spawn {
    private ["_drones","_groups","_activeKey","_hardLife","_x"];
    _drones    = _this select 0;
    _groups    = _this select 1;
    _activeKey = _this select 2;
    _hardLife  = time + WFBE_C_DRONE_LOITER_TIME + 120;
    waitUntil {sleep 2; (({alive _x} count _drones) == 0) || time > _hardLife};
    { if (!isNull _x) then { {deleteVehicle _x} forEach (crew _x); deleteVehicle _x } } forEach _drones;
    { if (!isNull _x) then {deleteGroup _x} } forEach _groups;
    missionNamespace setVariable [_activeKey, ((missionNamespace getVariable [_activeKey, 1]) - 1) max 0];
};
