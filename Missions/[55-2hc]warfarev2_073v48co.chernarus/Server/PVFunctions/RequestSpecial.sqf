if (typeName _this != "ARRAY" || {count _this == 0} || {typeName (_this select 0) != "STRING"}) exitWith {};
_this Spawn HandleSpecial;