Private ["_gunner","_lookPos","_vehicle"];

_vehicle = _this select 0;
// Common_FireArtillery can reach teardown after the hull or its gunner has
// disappeared.  Fail cleanly before dereferencing either object.
if (isNull _vehicle || {!alive _vehicle}) exitWith {};

// Lower gun/missile racks.
_lookPos = [(getPos _vehicle select 0) + sin(getDir _vehicle)*20, (getPos _vehicle select 1) + cos(getDir _vehicle)*20, (getPos _vehicle select 2) - 5];

if (alive (driver _vehicle)) then {
	{(driver _vehicle) enableAI _x} forEach ["MOVE","TARGET","AUTOTARGET"];
};
_gunner = gunner _vehicle;
if (!isNull _gunner && {alive _gunner}) then {
	_gunner lookAt _lookPos;
};
