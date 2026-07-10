Private["_client","_locked","_side","_vehicle","_actor"];

_vehicle = _this select 0;
_locked = _this select 1;

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The PVEH carries no trusted sender; the only honest caller is the spec-ops lockpick
//--- (Skill_SpecOps.sqf), which UNLOCKS a currently-locked vehicle the player is standing on
//--- top of. It now sends the acting player as element 2. A forger could otherwise lock/unlock
//--- ANY vehicle (e.g. unlock an enemy tank to steal it). Bind the request to a real, living,
//--- nearby actor and to an UNLOCK action; reject everything else.
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	_actor = objNull;
	if (count _this > 2) then {_actor = _this select 2};
	if (isNull _actor || {!isPlayer _actor} || {!alive _actor}) exitWith {
		["WARNING", Format ["RequestVehicleLock.sqf: rejected - missing/invalid actor for vehicle [%1].", _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	//--- Lockpick only ever UNLOCKS; a lock request can only be a forge.
	if (_locked) exitWith {
		["WARNING", Format ["RequestVehicleLock.sqf: rejected forged LOCK request on [%1] by [%2].", _vehicle, _actor]] Call WFBE_CO_FNC_LogContent;
	};
	if (isNull _vehicle) exitWith {
		["WARNING", "RequestVehicleLock.sqf: rejected - null vehicle."] Call WFBE_CO_FNC_LogContent;
	};
	//--- Must be in lockpick reach (client gates at 5m; allow slack for replication lag).
	if ((_actor distance _vehicle) > 12) exitWith {
		["WARNING", Format ["RequestVehicleLock.sqf: rejected out-of-range unlock on [%1] by [%2] (dist=%3).", _vehicle, _actor, _actor distance _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
};

_vehicle lock _locked;

[nil, "SetVehicleLock", [_vehicle,_locked]] Call WFBE_CO_FNC_SendToClients;