
//--- Malformed-payload guard: ensure _this is ARRAY with >= 5 elements (object, pos, side, town, area).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 5}) exitWith {};
(_this select 0) setPos (_this select 1);
(_this select 0)  setVariable ["avail",missionNamespace getVariable "WFBE_C_BASE_AV_STRUCTURES"];
(_this select 0)  setVariable ["side",(_this select 2) ];
(_this select 3) setVariable ["wfbe_basearea", (_this select 4)+ [(_this select 0)], true];