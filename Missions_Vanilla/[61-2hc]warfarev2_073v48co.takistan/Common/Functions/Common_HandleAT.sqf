private ["_unit","_weapon","_limit","_ammo","_rocket","_speed","_at","_vec","_vecnorm"];

_ammo = _this select 4;
_at=["R_MEEWS_HEAT","R_MEEWS_HEDP","R_SMAW_HEDP","R_SMAW_HEAA"];

if (_ammo in _at) then { 
_unit = _this select 0;
_weapon = currentWeapon _unit;
_rocket = nearestObject [_unit,_ammo];
if (isNull _rocket) exitWith {};

     
        _vec = velocity _rocket;
		_vecnorm = _vec distance [0,0,0];
		//--- The Fired handler can race projectile initialization. Leave the engine trajectory
		//--- untouched for a zero/near-zero vector instead of normalizing through a zero divisor.
		if (_vecnorm <= 0.001) exitWith {};

       _speed = 480;
      _rocket setVelocity [
	   _speed*(_vec select 0)/_vecnorm,
	   _speed*(_vec select 1)/_vecnorm,
	   _speed*(_vec select 2)/_vecnorm
	   ];
    };







