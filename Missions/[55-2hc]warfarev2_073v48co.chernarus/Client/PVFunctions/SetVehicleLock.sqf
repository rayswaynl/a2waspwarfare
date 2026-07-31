//--- Malformed-payload guard: ensure _this is ARRAY with >= 2 elements (vehicle, lockState).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 2}) exitWith {};
//--- Fail-clean: deleted vehicle mid-PV or non-bool lock state must not throw on clients.
if (typeName (_this select 0) != "OBJECT" || {isNull (_this select 0)}) exitWith {};
if (typeName (_this select 1) != "BOOL") exitWith {};
(_this select 0) lock (_this select 1);
