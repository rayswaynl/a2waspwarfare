Private ["_dir","_speed","_vehicle","_vel"];

//--- r74: player vehicle utility fail-clean — push.
//--- addAction condition (driver + alive + speed) is not atomic with the click: hull can delete,
//--- die, or change driver between menu paint and setVelocity. Bare setVelocity/velocity on
//--- null/dead then throws and aborts the action script (RPT spam; no push applied).
_vehicle = _this select 0;
if (isNil "_vehicle") exitWith {};
if (typeName _vehicle != "OBJECT") exitWith {};
if (isNull _vehicle || {!alive _vehicle}) exitWith {};
if (isNil "player" || {isNull player}) exitWith {};
if (driver _vehicle != player) exitWith {};

_vel = velocity _vehicle;
_dir = direction _vehicle;
_speed = 10;
_vehicle setVelocity [(_vel select 0)+(sin _dir*_speed),(_vel select 1)+(cos _dir*_speed),(_vel select 2)];