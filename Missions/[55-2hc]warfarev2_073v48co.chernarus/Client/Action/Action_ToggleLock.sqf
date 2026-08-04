Private ["_intent","_args","_vehicle"];

_vehicle = _this select 0;
_args = _this select 3;
//--- Fail-clean: action can race a deleted/dead hull (condition is not atomic with click).
if (typeName _vehicle != "OBJECT" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};

if (typeName _args != "ARRAY" || {count _args < 1}) exitWith {};
_intent = (_this select 3) select 0;
if (typeName _intent != "BOOL") exitWith {};

//--- The action label carries the requested state. Never derive it by flipping the current lock: a
//--- stale duplicate click must repeat Lock/Unlock idempotently, not undo the first activation.
_vehicle lock _intent;
