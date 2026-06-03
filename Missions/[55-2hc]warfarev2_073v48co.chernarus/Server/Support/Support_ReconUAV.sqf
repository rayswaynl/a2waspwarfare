//--- Support_ReconUAV.sqf — AI-flown recon drone (remade UAV deploy). [SERVER-AUTHORITATIVE]
//--- Press the Tactical-menu "UAV" button (no map click): the server spawns ONE faction recon drone at the side
//--- HQ, the ENGINE flies it (hidden AI pilot + doMove + flyInHeight) to orbit the NEAREST CONTESTED TOWN, and a
//--- server-side spotting loop reveals nearby enemies to the deploying side (reusing the existing uav-reveal marker
//--- path). It persists until shot down, recalled, or the side loses its HQ — no timer, no enemy warning.
//--- Payload: ["ReconUAV", side, playerTeam].

private ["_side","_playerTeam","_sideID","_model","_pilotType","_alt","_orbitR","_speed","_hp",
        "_spotDelay","_spotRange","_spotDet","_activeKey","_active","_hq","_spawnPos","_town","_townPos",
        "_grp","_drone","_pilot","_uavKey"];

_side       = _this select 1;
_playerTeam = _this select 2;
_sideID     = _side call GetSideID;

//--- Lobby toggle.
if ((missionNamespace getVariable ["WFBE_C_RECON_ENABLED", 1]) != 1) exitWith {
    ["INFORMATION","Support_ReconUAV.sqf : disabled by lobby param (WFBE_C_RECON_ENABLED), ignoring."] Call WFBE_CO_FNC_LogContent;
};

//--- Airframe (Ka-137 per faction) + a soldier-pilot fallback. No classname -> faction has no recon UAV (parity with the old WFBE_{side}UAV gating).
_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") exitWith {
    ["WARNING", Format ["Support_ReconUAV.sqf : no WFBE_%1DRONE classname, ignoring.", str _side]] Call WFBE_CO_FNC_LogContent;
};
_pilotType = missionNamespace getVariable Format ["WFBE_%1PILOT", str _side];
if (isNil "_pilotType") then {_pilotType = missionNamespace getVariable Format ["WFBE_%1SOLDIER", str _side]};

_alt       = WFBE_C_RECON_ALT;
_orbitR    = WFBE_C_RECON_ORBIT_RADIUS;
_speed     = WFBE_C_RECON_SPEED;
_hp        = WFBE_C_RECON_HP;
_spotDelay = WFBE_C_PLAYERS_UAV_SPOTTING_DELAY;
_spotRange = WFBE_C_PLAYERS_UAV_SPOTTING_RANGE;
_spotDet   = WFBE_C_PLAYERS_UAV_SPOTTING_DETECTION;

//--- Concurrent cap (per side, server-authoritative). Broadcast so the Tactical menu can gate the button.
_activeKey = Format ["WFBE_RECON_ACTIVE_%1", str _side];
_active = missionNamespace getVariable [_activeKey, 0];
if (_active >= WFBE_C_RECON_CONCURRENT_CAP) exitWith {
    ["INFORMATION","Support_ReconUAV.sqf : concurrent cap reached, ignoring."] Call WFBE_CO_FNC_LogContent;
};

//--- Launch from the side HQ.
_hq = _side Call WFBE_CO_FNC_GetSideHQ;
if (isNull _hq) exitWith {
    ["WARNING","Support_ReconUAV.sqf : no HQ to launch from, ignoring."] Call WFBE_CO_FNC_LogContent;
};
_spawnPos = [(getPos _hq) select 0, (getPos _hq) select 1, _alt];

//--- Loiter target = nearest contested town (a town this side does not own). Fall back to the nearest town overall.
_town = [_spawnPos, _sideID] Call WFBE_CO_FNC_GetClosestEnemyLocation;
if (isNull _town) then {_town = [_spawnPos, towns] Call WFBE_CO_FNC_GetClosestEntity};
if (isNull _town) exitWith {
    ["WARNING","Support_ReconUAV.sqf : no town to scout, ignoring."] Call WFBE_CO_FNC_LogContent;
};
_townPos = getPos _town;

missionNamespace setVariable [_activeKey, _active + 1, true];

["INFORMATION", Format ["Support_ReconUAV.sqf : [%1] Team [%2] recon launched (model %3) toward %4.", str _side, _playerTeam, _model, _town getVariable "name"]] Call WFBE_CO_FNC_LogContent;

//--- Scripted survivability + delayed kill-attribution (self-contained; mirrors the strike's model so downing it pays the standard bounty). Crash/self/terrain ignored.
WFBE_ReconHandleDamage = {
    private ["_unit","_dmg","_src","_prev","_delta","_h"];
    _unit = _this select 0;
    _dmg  = _this select 2;
    _src  = _this select 3;
    if (isNull _src || {_src == _unit}) exitWith {0};   //--- ignore crash / self / terrain
    _prev = damage _unit;
    _delta = _dmg - _prev;
    if (_delta < WFBE_C_RECON_MIN_HIT) exitWith {0};    //--- sub-.50 plink
    _unit setVariable ["wfbe_lasthitby", _src, true];   //--- reuse the mission's delayed kill-reward path.
    _unit setVariable ["wfbe_lasthittime", time, true];
    _h = (_unit getVariable ["wfbe_recon_hp", WFBE_C_RECON_HP]) - 1;
    _unit setVariable ["wfbe_recon_hp", _h, true];
    if (_h <= 0) exitWith {1};                          //--- depleted -> destroy
    0
};

//--- Spawn one drone + a hidden AI pilot; the ENGINE flies it. Eyes only: AWARE (sensors hot for knowsAbout) + never fire + no slewing.
_grp = createGroup _side;
_drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
_drone setPosATL _spawnPos;
_pilot = [_pilotType, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
_pilot moveInDriver _drone;
_grp setBehaviour "AWARE";
_grp setCombatMode "BLUE";                              //--- hold fire (it is unarmed anyway).
_grp setSpeedMode "LIMITED";
{_pilot disableAI _x} forEach ["TARGET","AUTOTARGET"]; //--- detect, don't engage.
_drone flyInHeight _alt;
_drone forceSpeed _speed;
_drone lockDriver true;
_drone setVariable ["wfbe_recon_hp", _hp, true];
_drone setVariable ["wfbe_sideID", _sideID, false];
_drone addEventHandler ["HandleDamage", {_this call WFBE_ReconHandleDamage}];
_drone addEventHandler ["Killed", {[_this select 0, _this select 1, (_this select 0) getVariable "wfbe_sideID"] Spawn WFBE_CO_FNC_OnUnitKilled}];
processInitCommands;

//--- Expose the live drone so the menu's Recall (Server_HandleSpecial "ReconUAVRecall") can find and despawn it.
_uavKey = Format ["WFBE_RECON_UAV_%1", str _side];
missionNamespace setVariable [_uavKey, _drone, false];

["INFORMATION", Format ["Support_ReconUAV.sqf : [%1] recon UAV airborne, orbiting %2 (alt %3, r %4).", str _side, _townPos, _alt, _orbitR]] Call WFBE_CO_FNC_LogContent;

//--- Orbit + reveal thread: re-aim the orbit point around the town (~5s -> smooth arc); scan + reveal every spotting interval.
[_drone, _pilot, _townPos, _orbitR, _spotDelay, _spotRange, _spotDet, _side] spawn {
    private ["_drone","_pilot","_townPos","_orbitR","_spotDelay","_spotRange","_spotDet","_side","_ang","_nextScan","_pt","_x"];
    _drone     = _this select 0;
    _pilot     = _this select 1;
    _townPos   = _this select 2;
    _orbitR    = _this select 3;
    _spotDelay = _this select 4;
    _spotRange = _this select 5;
    _spotDet   = _this select 6;
    _side      = _this select 7;
    _ang = 0;
    _nextScan = 0;
    while {alive _drone} do {
        //--- Advance the orbit point; the engine flies a smooth arc toward it.
        _ang = (_ang + 30) mod 360;
        _pt = [(_townPos select 0) + _orbitR * sin _ang, (_townPos select 1) + _orbitR * cos _ang, 0];
        if (!isNull _pilot) then {_pilot doMove _pt};

        //--- Reveal scan: anything the drone knows about over the threshold gets blipped for the friendly side only.
        if (time >= _nextScan) then {
            _nextScan = time + _spotDelay;
            {
                if (alive _x && {(_drone knowsAbout _x) > _spotDet} && {!((side _x) in [_side, civilian])}) then {
                    [_side, "HandleSpecial", ["uav-reveal", _drone, _x]] Call WFBE_CO_FNC_SendToClients;
                };
            } forEach (_drone nearEntities _spotRange);
        };

        sleep 5;
    };
};

//--- Lifecycle cleanup: on shot-down / recall, delete crew + group, clear the handle, free the side slot (broadcast).
[_drone, _grp, _activeKey, _uavKey] spawn {
    private ["_drone","_grp","_activeKey","_uavKey"];
    _drone     = _this select 0;
    _grp       = _this select 1;
    _activeKey = _this select 2;
    _uavKey    = _this select 3;
    waitUntil {sleep 2; !alive _drone};
    if (!isNull _drone) then { {deleteVehicle _x} forEach (crew _drone); deleteVehicle _drone };
    if (!isNull _grp) then {deleteGroup _grp};
    missionNamespace setVariable [_uavKey, objNull, false];
    missionNamespace setVariable [_activeKey, ((missionNamespace getVariable [_activeKey, 1]) - 1) max 0, true];
    ["INFORMATION","Support_ReconUAV.sqf : recon UAV ended (down/recalled); side slot freed."] Call WFBE_CO_FNC_LogContent;
};
