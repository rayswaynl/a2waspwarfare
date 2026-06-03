//--- Support_DroneStrike.sqf — Mixed Saturation Strike orchestrator (server-authoritative). [HARDENED]
//--- Payload: ["DroneStrike", side, callPos, playerTeam]  (spawned server-side via KAT_DroneStrike).
//--- Reuses mission systems:
//---   WFBE_PRESENTSIDES          -> threeway-safe enemy sides
//---   WFBE_%1_Defenses_AA        -> real AA classnames (prioritise true AA, not "any static")
//---   WFBE_CO_FNC_SendToClients + the existing "uav-reveal" HandleSpecial case -> reveal-on-fire payoff
//---   IRS deflection technique   -> flare drones actually spoof incoming missiles
//--- Arma 2 OA SQF only (no pushBack / params / distance2D / setVelocityModelSpace / vector* A3 / code-select).

private ["_side","_destination","_playerTeam","_sideID","_enemySides","_aaTypes","_model","_alt","_speed","_lspeed",
        "_flareN","_total","_zoneR","_warhead","_scatter","_hp","_stagger","_loiterTime",
        "_bd","_corners","_spawnPos","_drones","_i","_role","_drone","_activeKey","_active","_x"];

_side        = _this select 1;
_destination = _this select 2;
_playerTeam  = _this select 3;
_sideID      = _side call GetSideID;

//--- (1) Threeway-safe enemy sides — reuse WFBE_PRESENTSIDES instead of a WEST/EAST hack.
_enemySides = WFBE_PRESENTSIDES - [_side];

//--- (2) Real AA classnames the mission registers per side (static AA) + mobile AA — reuse WFBE_%1_Defenses_AA.
_aaTypes = ["M6_EP1"];   //--- mobile AA (Avenger / Linebacker)
{ _aaTypes = _aaTypes + (missionNamespace getVariable [Format ["WFBE_%1_Defenses_AA", _x], []]) } forEach ["WEST","EAST","GUER"];

_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") then {_model = missionNamespace getVariable Format ["WFBE_%1UAV", str _side]};

_alt        = WFBE_C_DRONE_CRUISE_ALT;
_speed      = WFBE_C_DRONE_INGRESS_SPEED;
_lspeed     = WFBE_C_DRONE_LOITER_SPEED;
_flareN     = WFBE_C_DRONE_FLARE_COUNT;
_total      = WFBE_C_DRONE_FLARE_COUNT + WFBE_C_DRONE_MUNITION_COUNT;
_zoneR      = WFBE_C_DRONE_ZONE_RADIUS;
_warhead    = WFBE_C_DRONE_WARHEAD;
_scatter    = WFBE_C_DRONE_SCATTER;
_hp         = WFBE_C_DRONE_HP;
_stagger    = WFBE_C_DRONE_DIVE_STAGGER;
_loiterTime = WFBE_C_DRONE_LOITER_TIME;

["INFORMATION", Format ["Support_DroneStrike.sqf : [%1] Team [%2] strike at %3 (model %4, enemies %5).", str _side, _playerTeam, _destination, _model, _enemySides]] Call WFBE_CO_FNC_LogContent;

//--- Concurrent cap (per side).
_activeKey = Format ["WFBE_DRONE_ACTIVE_%1", str _side];
_active = missionNamespace getVariable [_activeKey, 0];
if (_active >= WFBE_C_DRONE_CONCURRENT_CAP) exitWith {
    ["INFORMATION","Support_DroneStrike.sqf : concurrent cap reached, ignoring request."] Call WFBE_CO_FNC_LogContent;
};
missionNamespace setVariable [_activeKey, _active + 1];

//--- Scripted survivability + (3) reveal-on-fire. Only >=.50-cal hits count; the shooter is pinged to the friendly team.
WFBE_DroneHandleDamage = {
    private ["_unit","_dmg","_src","_prev","_delta","_h","_dside","_last"];
    _unit = _this select 0;
    _dmg  = _this select 2;
    _src  = _this select 3;
    _prev = damage _unit;
    _delta = _dmg - _prev;
    if (_delta < WFBE_C_DRONE_MIN_HIT) exitWith {0};   //--- sub-.50 plink -> ignored, stays pristine

    //--- Engage-or-eat-it: reveal the shooter on the friendly team map (reuse uav-reveal), rate-limited.
    if (!isNull _src && {_src != _unit} && {typeName _src == "OBJECT"}) then {
        _last = _unit getVariable ["wfbe_reveal_t", -100];
        if (time - _last > 3) then {
            _dside = _unit getVariable ["wfbe_side", west];
            [_dside, "HandleSpecial", ["uav-reveal", _unit, _src]] Call WFBE_CO_FNC_SendToClients;
            _unit setVariable ["wfbe_reveal_t", time];
        };
    };

    _h = (_unit getVariable ["wfbe_drone_hp", WFBE_C_DRONE_HP]) - 1;
    _unit setVariable ["wfbe_drone_hp", _h, true];
    if (_h <= 0) exitWith {1};   //--- depleted -> destroy
    0
};

//--- (4) Real missile spoof — distilled from the IRS deflection. Perturbs the incoming missile while it closes.
WFBE_DroneSpoofMissile = {
    private ["_drone","_ammo","_shooter","_m","_cnt","_v"];
    _drone   = _this select 0;
    _ammo    = _this select 1;
    _shooter = _this select 2;
    _m = nearestObject [_shooter, _ammo];
    if (isNull _m) exitWith {};
    _cnt = 0;
    while {!isNull _m && alive _drone && (_m distance _drone) > 14 && _cnt < 60} do {
        if (random 1 < 0.30) then {
            _v = velocity _m;
            _m setVelocity [(_v select 0) + (random 36 - 18), (_v select 1) + (random 36 - 18), (_v select 2) + (random 10 - 5)];
        };
        _cnt = _cnt + 1;
        sleep 0.05;
    };
};

//--- Friendly map marker + "inbound" announcer (friendly: precise marker + chime; enemy: fairness warning). Reuses the broadcast infra.
[nil, "HandleSpecial", ["drone-strike-fx", _destination, _side]] Call WFBE_CO_FNC_SendToClients;

//--- Map-edge spawn (clone of Support_Paratroopers ingress origin).
_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
_corners = if (isNil "_bd") then {[[0,0,_alt]]} else {
    [[0+random 200,0+random 200,_alt],[0+random 200,_bd-random 200,_alt],[_bd-random 200,_bd-random 200,_alt],[_bd-random 200,0+random 200,_alt]]
};
_spawnPos = _corners select (floor random count _corners);

//--- Spawn the crewless package.
_drones = [];
for "_i" from 0 to (_total - 1) do {
    _role = if (_i < _flareN) then {"flare"} else {"munition"};
    _drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
    _drone setPosATL [(_spawnPos select 0) + (_i * 22), (_spawnPos select 1) + (_i * 16), _alt];
    _drone setVariable ["wfbe_drone_role", _role, true];
    _drone setVariable ["wfbe_drone_hp", _hp, true];
    _drone setVariable ["wfbe_phase", _i, true];
    _drone setVariable ["wfbe_sideID", _sideID, false];
    _drone setVariable ["wfbe_side", _side, false];
    _drone flyInHeight _alt;
    _drone addEventHandler ["HandleDamage", {_this call WFBE_DroneHandleDamage}];
    _drone addEventHandler ["Killed", {[_this select 0, _this select 1, (_this select 0) getVariable "wfbe_sideID"] Spawn WFBE_CO_FNC_OnUnitKilled}];
    _drones set [count _drones, _drone];
};
processInitCommands;

//--- Drive each drone in its own loop: ingress -> role behaviour -> despawn.
{
    private "_d"; _d = _x;
    [_d, _destination, _alt, _speed, _lspeed, _zoneR, _loiterTime, _warhead, _scatter, _stagger, _enemySides, _aaTypes] spawn {
        private ["_d","_dest","_alt","_speed","_lspeed","_zoneR","_loiterTime","_warhead","_scatter","_stagger","_enemySides","_aaTypes",
                "_role","_phase","_tgt","_idl","_p","_dx","_dy","_hdg","_ang","_pt","_endT","_t0","_target","_cands","_valid","_aa",
                "_aim","_dur","_imp","_vx","_vy","_vz","_mag","_x"];
        _d          = _this select 0;
        _dest       = _this select 1;
        _alt        = _this select 2;
        _speed      = _this select 3;
        _lspeed     = _this select 4;
        _zoneR      = _this select 5;
        _loiterTime = _this select 6;
        _warhead    = _this select 7;
        _scatter    = _this select 8;
        _stagger    = _this select 9;
        _enemySides = _this select 10;
        _aaTypes    = _this select 11;
        _role  = _d getVariable "wfbe_drone_role";
        _phase = _d getVariable "wfbe_phase";

        //--- INGRESS to the zone (safety deadline so a stuck drone can't loop forever).
        _tgt = [_dest select 0, _dest select 1, _alt];
        _idl = time + 70;
        while {alive _d && ((_d distance _tgt) > 110) && time < _idl} do {
            _p = getPosATL _d;
            _dx = (_tgt select 0) - (_p select 0);
            _dy = (_tgt select 1) - (_p select 1);
            _hdg = _dx atan2 _dy;
            _d setDir _hdg;
            _d setVectorDirAndUp [[sin _hdg, cos _hdg, 0],[0,0,1]];
            _d setVelocity [sin _hdg * _speed, cos _hdg * _speed, 0];
            _d setPosATL [_p select 0, _p select 1, _alt];
            sleep 0.08;
        };

        _endT = time + _loiterTime;
        _t0 = time;

        if (_role == "flare") then {
            //--- FLARE DRONE: conspicuous orbiting screen, pops flares + spoofs incoming missiles, soaks fire.
            _d addEventHandler ["incomingMissile", {
                private "_fd"; _fd = _this select 0;
                if (alive _fd) then {
                    "F_40mm_White" createVehicle (getPosATL _fd);
                    "F_40mm_White" createVehicle [(getPosATL _fd select 0)+10, (getPosATL _fd select 1)+10, (getPosATL _fd select 2)];
                    [_this select 0, _this select 1, _this select 2] spawn WFBE_DroneSpoofMissile;
                };
            }];
            while {alive _d && time < (_endT + 25)} do {
                _ang = (_phase * 70) + ((time - _t0) * 70);
                _pt = [(_dest select 0) + _zoneR * sin _ang, (_dest select 1) + _zoneR * cos _ang, _alt];
                _p = getPosATL _d;
                _dx = (_pt select 0) - (_p select 0);
                _dy = (_pt select 1) - (_p select 1);
                _hdg = _dx atan2 _dy;
                _d setDir _hdg;
                _d setVectorDirAndUp [[sin _hdg, cos _hdg, -0.05],[0,0,1]];
                _d setVelocity [sin _hdg * _lspeed, cos _hdg * _lspeed, 0];
                _d setPosATL [_p select 0, _p select 1, _alt];
                if ((round ((time - _t0) * 10)) mod 80 == 0) then {"F_40mm_White" createVehicle (getPosATL _d)};
                sleep 0.1;
            };
            if (alive _d) then {deleteVehicle _d};
        } else {
            //--- LOITERING MUNITION: orbit-search for an enemy ground vehicle (AA first), then top-attack dive.
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
                if (isNull _target) then {
                    _ang = (_phase * 55) + ((time - _t0) * 70);
                    _pt = [(_dest select 0) + _zoneR * sin _ang, (_dest select 1) + _zoneR * cos _ang, _alt];
                    _p = getPosATL _d;
                    _dx = (_pt select 0) - (_p select 0);
                    _dy = (_pt select 1) - (_p select 1);
                    _hdg = _dx atan2 _dy;
                    _d setDir _hdg;
                    _d setVectorDirAndUp [[sin _hdg, cos _hdg, -0.05],[0,0,1]];
                    _d setVelocity [sin _hdg * _lspeed, cos _hdg * _lspeed, 0];
                    _d setPosATL [_p select 0, _p select 1, _alt];
                };
                sleep 0.4;
            };

            //--- Stagger, then COMMIT to a captured aim point (fixed — robust to the target dying mid-dive).
            sleep (_phase * _stagger);
            if (!alive _d) exitWith {};
            _aim = if (!isNull _target && {alive _target}) then {getPosATL _target} else {[_dest select 0, _dest select 1, 12]};
            _d say3D "drone_stuka";   //--- Ju-87 dive siren (global; silent until the .ogg lands).

            _dur = 0;
            while {alive _d && ((getPosATL _d) select 2 > 6) && _dur < 9} do {
                _p = getPosATL _d;
                _vx = (_aim select 0) - (_p select 0);
                _vy = (_aim select 1) - (_p select 1);
                _vz = (_aim select 2) - (_p select 2);
                _mag = sqrt (_vx*_vx + _vy*_vy + _vz*_vz);
                if (_mag < 1) then {_mag = 1};
                _hdg = _vx atan2 _vy;
                _d setDir _hdg;
                _d setVectorDirAndUp [[_vx/_mag, _vy/_mag, _vz/_mag],[0,0,1]];
                _d setVelocity [(_vx/_mag)*_speed, (_vy/_mag)*_speed, (_vz/_mag)*_speed];
                _dur = _dur + 0.06;
                sleep 0.06;
            };

            //--- Impact at the committed point +/- scatter (package-lethal, never a per-drone one-shot).
            _ang = random 360;
            _imp = [(_aim select 0) + (random _scatter) * sin _ang, (_aim select 1) + (random _scatter) * cos _ang, 0];
            _warhead createVehicle _imp;
            if (alive _d) then {deleteVehicle _d};
        };
    };
} forEach _drones;

//--- Lifecycle cleanup: remove marker, delete any survivors past hard lifetime, decrement the cap.
[_drones, _activeKey] spawn {
    private ["_drones","_activeKey","_hardLife"];
    _drones    = _this select 0;
    _activeKey = _this select 1;
    _hardLife  = time + WFBE_C_DRONE_LOITER_TIME + 90;
    waitUntil {sleep 2; (({alive _x} count _drones) == 0) || time > _hardLife};
    {if (!isNull _x) then {deleteVehicle _x}} forEach _drones;
    missionNamespace setVariable [_activeKey, ((missionNamespace getVariable [_activeKey, 1]) - 1) max 0];
};
