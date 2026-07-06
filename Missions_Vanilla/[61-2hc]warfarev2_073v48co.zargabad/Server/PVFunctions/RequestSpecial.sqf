private ["_requestType"];

//--- Block E: RequestSpecial is a broad command bus, so keep the PVF guard to the shared envelope.
if (isNil "_this") exitWith {
	["WARNING", "RequestSpecial.sqf: rejected nil payload."] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _this) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected non-array payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 1) exitWith {
	["WARNING", "RequestSpecial.sqf: rejected empty payload."] Call WFBE_CO_FNC_LogContent;
};

_requestType = _this select 0;
if !((typeName _requestType) in ["STRING"]) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected non-string request type [%1].", typeName _requestType]] Call WFBE_CO_FNC_LogContent;
};

_this Spawn HandleSpecial;
