//--- Support_DroneStrike.sqf — SPIKE (Task 1).
//--- Proves crewless, AI-free scripted flight for ONE drone before the full orchestrator is built.
//--- Payload: ["DroneStrike", side, callPos, playerTeam]  (spawned server-side via KAT_DroneStrike).
//--- All commands here are Arma 2 OA compatible (no setVelocityModelSpace / distance2D / getDir-target / BIS_fnc_relPos).

Private ["_side","_destination","_model","_bd","_corners","_spawnPos","_drone","_alt","_speed","_t","_hdg","_tgt","_ang","_pt","_dx","_dy","_p"];

_side = _this select 1;
_destination = _this select 2;
_model = missionNamespace getVariable Format ["WFBE_%1DRONE", str _side];
if (isNil "_model") then {_model = missionNamespace getVariable Format ["WFBE_%1UAV", str _side]};
_alt = WFBE_C_DRONE_CRUISE_ALT;
_speed = WFBE_C_DRONE_INGRESS_SPEED;

["INFORMATION", Format ["Support_DroneStrike.sqf SPIKE : [%1] strike at %2, model %3.", str _side, _destination, _model]] Call WFBE_CO_FNC_LogContent;

//--- Map-edge spawn (clone of Support_Paratroopers).
_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
_corners = if (isNil "_bd") then {[[0,0,_alt]]} else {[[0,0,_alt],[0,_bd,_alt],[_bd,_bd,_alt],[_bd,0,_alt]]};
_spawnPos = _corners select (floor random count _corners);

_drone = createVehicle [_model, _spawnPos, [], 0, "FLY"];
_drone setPosATL _spawnPos;
_drone allowDamage false;     //--- SPIKE ONLY: isolate flight quality from being shot.
_drone flyInHeight _alt;

//--- METHOD A (no AI): scripted thrust + heading steer toward the painted point.
_tgt = [_destination select 0, _destination select 1, _alt];
while {alive _drone && ((_drone distance _tgt) > 70)} do {
	_p = getPosATL _drone;
	_dx = (_tgt select 0) - (_p select 0);
	_dy = (_tgt select 1) - (_p select 1);
	_hdg = _dx atan2 _dy;
	_drone setDir _hdg;
	_drone setVectorDirAndUp [[sin _hdg, cos _hdg, 0],[0,0,1]];
	_drone setVelocity [sin _hdg * _speed, cos _hdg * _speed, 0];
	_drone setPosATL [_p select 0, _p select 1, _alt];   //--- altitude lock
	sleep 0.08;
};

//--- Loiter a circle around the point for 30s, then despawn.
_t = time;
while {alive _drone && (time - _t < 30)} do {
	_ang = (time - _t) * 60;   //--- deg/s sweep
	_pt = [(_destination select 0) + WFBE_C_DRONE_ZONE_RADIUS * sin _ang, (_destination select 1) + WFBE_C_DRONE_ZONE_RADIUS * cos _ang, _alt];
	_p = getPosATL _drone;
	_dx = (_pt select 0) - (_p select 0);
	_dy = (_pt select 1) - (_p select 1);
	_hdg = _dx atan2 _dy;
	_drone setDir _hdg;
	_drone setVectorDirAndUp [[sin _hdg, cos _hdg, -0.05],[0,0,1]];
	_drone setVelocity [sin _hdg * WFBE_C_DRONE_LOITER_SPEED, cos _hdg * WFBE_C_DRONE_LOITER_SPEED, 0];
	_drone setPosATL [_p select 0, _p select 1, _alt];
	sleep 0.08;
};

if (!isNull _drone) then {deleteVehicle _drone};
["INFORMATION", "Support_DroneStrike.sqf SPIKE : complete."] Call WFBE_CO_FNC_LogContent;
