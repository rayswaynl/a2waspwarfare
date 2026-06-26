/*
	EASA_Kit_Fire.sqf  (EASA_Kit_Fire)
	Scripted rocket-pod shot for a MOUNT kit. Called from the kit fire action, so it runs on the
	firer's machine. Spawns one vanilla projectile from the pod muzzle and decrements the public
	ammo counter (reload is handled by the rearm path restoring WFBE_KIT_Ammo).
	Input : action args -> _this select 0 = _target (the vehicle)
	Arma 2 OA only. No A3-only commands (createVehicle ammo + setVelocity is the OA technique).
*/
private ["_vehicle","_spec","_ammoLeft"];
_vehicle = _this select 0;
if (isNull _vehicle) exitWith {};

_spec = _vehicle getVariable ["WFBE_KIT_Spec", []];
if (count _spec == 0 || {(_spec select 0) != "MOUNT"}) exitWith {};

_ammoLeft = _vehicle getVariable ["WFBE_KIT_Ammo", 0];
if (_ammoLeft <= 0) exitWith {};

private ["_ammoClass","_mOff","_mDir","_spread","_speed","_spawn","_p0","_p1","_dir","_len","_yaw","_rkt"];
_ammoClass = _spec select 2;
_mOff      = _spec select 4;
_mDir      = _spec select 5;
_spread    = _spec select 6;
_speed     = _spec select 7;

//--- World muzzle position + world fire direction (model->world delta; vectorModelToWorld is A3-only).
_spawn = _vehicle modelToWorld _mOff;
_p0 = _vehicle modelToWorld [0,0,0];
_p1 = _vehicle modelToWorld _mDir;
_dir = [ (_p1 select 0)-(_p0 select 0), (_p1 select 1)-(_p0 select 1), (_p1 select 2)-(_p0 select 2) ];
_len = sqrt (((_dir select 0)*(_dir select 0)) + ((_dir select 1)*(_dir select 1)) + ((_dir select 2)*(_dir select 2)));
if (_len < 0.001) exitWith {};
//--- normalise + small random dispersion.
_dir = [
	((_dir select 0)/_len) + (((random (2*_spread)) - _spread)/100),
	((_dir select 1)/_len) + (((random (2*_spread)) - _spread)/100),
	((_dir select 2)/_len) + (((random (2*_spread)) - _spread)/100)
];

_rkt = createVehicle [_ammoClass, _spawn, [], 0, "CAN_COLLIDE"];
_rkt setPos _spawn;
_yaw = (_dir select 0) atan2 (_dir select 1);
_rkt setDir _yaw;
_rkt setVelocity [ (_dir select 0)*_speed, (_dir select 1)*_speed, (_dir select 2)*_speed ];

//--- Decrement ammo (authoritative on this machine; public so the action condition updates everywhere).
_vehicle setVariable ["WFBE_KIT_Ammo", (_ammoLeft - 1), true];
