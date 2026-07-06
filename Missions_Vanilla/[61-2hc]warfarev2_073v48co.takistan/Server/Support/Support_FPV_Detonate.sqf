//--- Support_FPV_Detonate.sqf - server-side warhead detonation for the FPV strike drone.
//--- Called via RequestSpecial "fpv-detonate" from the drone's Killed EH on the owning client.
//--- Pattern mirrors Support_ScudStrike.sqf: server-authoritative createVehicle ensures global
//--- damage propagation (client-created ammo is not authoritative for damage in A2 OA).
//--- Payload shape: ["fpv-detonate", [x, y, z]]
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0) exitWith {
	["INFORMATION", "Support_FPV_Detonate.sqf: WFBE_C_FPV_DRONE=0, ignoring detonation request."] Call WFBE_CO_FNC_LogContent;
};

private ["_args","_pos","_ammoClass"];
_args = _this;

if (count _args < 2) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
};

_pos = _args select 1;

if ((count _pos) < 3) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: malformed pos array, ignored."] Call WFBE_CO_FNC_LogContent;
};

_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];

createVehicle [_ammoClass, _pos, [], 0, "NONE"];

["INFORMATION", Format ["Support_FPV_Detonate.sqf: [%1] detonated at %2.", _ammoClass, _pos]] Call WFBE_CO_FNC_LogContent;
