Private ["_lock","_vehicle"];

_vehicle = _this select 0;
//--- Fail-clean: action can race a deleted/dead hull (condition is not atomic with click).
if (typeName _vehicle != "OBJECT" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};

_lock = if (locked _vehicle) then {false} else {true};

_vehicle lock _lock;
