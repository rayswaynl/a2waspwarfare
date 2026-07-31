Private ["_dir","_speed","_vehicle","_vel"];

//--- r74: player vehicle utility fail-clean — taxi reverse (twin of Action_Push).
//--- Condition requires near-zero speed + low altitude + driver; race with death/dismount/delete
//--- still leaves setVelocity unguarded.
_vehicle = _this select 0;
if (isNil "_vehicle") exitWith {};
if (typeName _vehicle != "OBJECT") exitWith {};
if (isNull _vehicle || {!alive _vehicle}) exitWith {};
if (isNil "player" || {isNull player}) exitWith {};
if (driver _vehicle != player) exitWith {};

_vel = velocity _vehicle;
_dir = direction _vehicle;
_speed = -5;
_vehicle setVelocity [(_vel select 0)+(sin _dir*_speed),(_vel select 1)+(cos _dir*_speed),(_vel select 2)];