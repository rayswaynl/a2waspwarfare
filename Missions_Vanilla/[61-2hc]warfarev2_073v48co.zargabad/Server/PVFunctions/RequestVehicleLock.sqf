Private["_actor","_challenge","_consumeResult","_locked","_minted","_rejected","_token","_vehicle"];

_vehicle = _this select 0;
_locked = _this select 1;

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- A2-OA's public-variable event handler carries no trusted remote sender. The honest caller
//--- therefore performs a two-phase exchange: this handler validates the claimed actor and scope,
//--- mints a private one-shot capability to that actor's owning client, then consumes it on the
//--- follow-up request. A claimed object alone is not an identity proof.
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	_actor = objNull;
	_token = "";
	_challenge = "";
	if (count _this > 2) then {_actor = _this select 2};
	if (typeName _actor != "OBJECT" || {isNull _actor} || {!isPlayer _actor} || {!alive _actor}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected - missing/invalid actor for vehicle [%1].", _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {typeName _locked != "BOOL"}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected malformed lock state for vehicle [%1].", _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	//--- Lockpick only ever UNLOCKS; a lock request can only be a forge.
	if (!_rejected && {_locked}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected forged LOCK request on [%1] by [%2].", _vehicle, _actor]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {typeName _vehicle != "OBJECT" || {isNull _vehicle}}) then {
		_rejected = true;
		["WARNING", "RequestVehicleLock.sqf: rejected - null vehicle."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {!alive _vehicle}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected - dead vehicle [%1].", _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	//--- Must be in lockpick reach (client gates at 5m; allow slack for replication lag).
	if (!_rejected && {(_actor distance _vehicle) > 12}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected out-of-range unlock on [%1] by [%2] (dist=%3).", _vehicle, _actor, _actor distance _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	if (count _this > 3) then {_token = _this select 3};
	if (count _this > 4) then {_challenge = _this select 4};
	if (!_rejected && {typeName _token != "STRING"}) then {
		_rejected = true;
		["WARNING", Format ["RequestVehicleLock.sqf: rejected malformed capability for [%1].", _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {_token == ""}) then {
		if (typeName _challenge != "STRING" || {_challenge == ""}) then {
			_rejected = true;
			["WARNING", Format ["RequestVehicleLock.sqf: rejected missing capability challenge for [%1] by [%2].", _vehicle, _actor]] Call WFBE_CO_FNC_LogContent;
		} else {
			_minted = false;
			if (!isNil "WFBE_SE_FNC_MintCapability") then {
				_minted = ["vehicle-lock", _actor, "vehicle-lock-capability", _challenge, 15, 1] Call WFBE_SE_FNC_MintCapability;
			};
			if (!_minted) then {
				_rejected = true;
				["WARNING", Format ["RequestVehicleLock.sqf: rejected capability mint for [%1] by [%2].", _vehicle, _actor]] Call WFBE_CO_FNC_LogContent;
			} else {
				//--- The mint reply is the only effect of phase one. Do not fall through to lock.
				_rejected = true;
			};
		};
	};
	if (!_rejected && {_token != ""}) then {
		_consumeResult = [false, "missing"];
		if (!isNil "WFBE_SE_FNC_ConsumeCapability") then {
			_consumeResult = ["vehicle-lock", _actor, _token] Call WFBE_SE_FNC_ConsumeCapability;
		};
		if (typeName _consumeResult != "ARRAY" || {count _consumeResult < 1} || {!(_consumeResult select 0)}) then {
			_rejected = true;
			["WARNING", Format ["RequestVehicleLock.sqf: rejected capability consume for [%1] by [%2].", _vehicle, _actor]] Call WFBE_CO_FNC_LogContent;
		};
	};
};
if (_rejected) exitWith {};

//--- r59 fail-clean: unhardened path still needs a live vehicle object before lock + broadcast.
if (isNil "_vehicle" || {typeName _vehicle != "OBJECT"} || {isNull _vehicle}) exitWith {
	["WARNING", "RequestVehicleLock.sqf: rejected - null vehicle (base path)."] Call WFBE_CO_FNC_LogContent;
};

_vehicle lock _locked;

[nil, "SetVehicleLock", [_vehicle,_locked]] Call WFBE_CO_FNC_SendToClients;
