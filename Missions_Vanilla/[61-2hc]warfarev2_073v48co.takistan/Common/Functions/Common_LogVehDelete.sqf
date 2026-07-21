//--- Common_LogVehDelete.sqf
//--- Compat shim until PR 1157's full probe rebases; intentionally does not duplicate its richer logic.
//--- Call signature: [reason, object, extra]. Keep this side-effect-only so cleanup continues to
//--- the caller's deleteVehicle even when the object is null or the optional fields are malformed.
Private ["_extraText", "_obj", "_reasonText", "_typeText"];

_reasonText = "unknown";
if (count _this > 0) then {
	if (!isNil {_this select 0}) then {
		if (typeName (_this select 0) == "STRING") then {_reasonText = _this select 0};
	};
};

_obj = objNull;
if (count _this > 1) then {
	if (!isNil {_this select 1}) then {_obj = _this select 1};
};

_extraText = "";
if (count _this > 2) then {
	if (!isNil {_this select 2}) then {
		if (typeName (_this select 2) == "STRING") then {_extraText = _this select 2};
	};
};

_typeText = "NULL";
if (typeName _obj == "OBJECT") then {
	if (!isNull _obj) then {_typeText = typeOf _obj};
};

diag_log ("VEHDEL|v1|" + _reasonText + "|" + _typeText + "|" + _extraText);
