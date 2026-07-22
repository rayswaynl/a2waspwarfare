
//--- Malformed-payload guard: ensure _this is ARRAY with >= 2 elements (vehicle, lockState).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 2}) exitWith {};
(_this select 0) lock (_this select 1);