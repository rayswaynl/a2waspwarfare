/*
    AI commander HQ recovery after a genuine HQ destruction.
    The HQ-loss handler starts this worker only for a side that was under full AI command.
    After the configured grace, the nearest currently owned town centre to the wreck is used.
    The numeric price mirrors the human HQ deploy lobby parameter. Dual economy uses side
    supply, while single-currency economy uses the separate AI-commander treasury. No town or
    insufficient funds abandons recovery so the normal HQ-loss victory condition resumes.
*/
private ["_side","_logik","_destroyedAt","_delay","_hq","_origin","_sideID","_town","_nearest","_distance","_currency","_currencyName","_price","_dual","_recoveryEpoch"];

_side = _this select 0;
_recoveryEpoch = _this select 1;
if ((missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_ENABLE", 0]) <= 0) exitWith {};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};
if (!(_logik getVariable ["wfbe_aicom_hq_recovery_pending", false])) exitWith {};
if ((_logik getVariable ["wfbe_aicom_hq_recovery_epoch", -1]) != _recoveryEpoch) exitWith {};

_destroyedAt = _logik getVariable ["wfbe_aicom_hq_recovery_destroyed_at", -1];
if (_destroyedAt < 0) exitWith {_logik setVariable ["wfbe_aicom_hq_recovery_pending", false]};
_delay = missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_DELAY", 1200];
if (_delay < 0) then {_delay = 0};

while {!gameOver && {_logik getVariable ["wfbe_aicom_hq_recovery_pending", false]} && {(_logik getVariable ["wfbe_aicom_hq_recovery_epoch", -1]) == _recoveryEpoch} && {(time - _destroyedAt) < _delay}} do {sleep 5};

//--- A later HQ loss supersedes this worker. Leave its pending flag, delay, origin, and funds alone.
if ((_logik getVariable ["wfbe_aicom_hq_recovery_epoch", -1]) != _recoveryEpoch) exitWith {};
if (gameOver || {(missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_ENABLE", 0]) <= 0}) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
};
if (!(_logik getVariable ["wfbe_aicom_hq_recovery_pending", false])) exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _hq && {alive _hq}) exitWith {_logik setVariable ["wfbe_aicom_hq_recovery_pending", false]};
_origin = _logik getVariable ["wfbe_aicom_hq_recovery_origin", [0,0,0]];
//--- r53: when origin is missing/malformed, do NOT getPos a null/dead HQ (alive HQ already exited above).
if (typeName _origin != "ARRAY" || {count _origin < 2}) then {
	if (!isNull _hq) then {
		_origin = getPos _hq;
	} else {
		_origin = [];
	};
};
if (typeName _origin != "ARRAY" || {count _origin < 2}) exitWith {
	_logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
	["WARNING", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ recovery aborted - no origin and no HQ reference for nearest-town pick.", str _side]] Call WFBE_CO_FNC_LogContent;
};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_town = objNull;
_nearest = 1e9;
{
    if ((_x getVariable ["sideID", -1]) == _sideID) then {
        _distance = _x distance _origin;
        if (_distance < _nearest) then {_nearest = _distance; _town = _x};
    };
} forEach towns;

if (isNull _town) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ recovery expired after %2 seconds - no owned town centre.", str _side, _delay]] Call WFBE_CO_FNC_LogContent;
};

_price = missionNamespace getVariable ["WFBE_C_STRUCTURES_HQ_COST_DEPLOY", 500];
_dual = (missionNamespace getVariable ["WFBE_C_ECONOMY_CURRENCY_SYSTEM", 0]) == 0;
_currencyName = if (_dual) then {"side supply"} else {"AI treasury"};
_currency = if (_dual) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {(_side) Call GetAICommanderFunds};
if (_currency < _price) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ recovery expired - %2 has %3, needs %4.", str _side, _currencyName, _currency, _price]] Call WFBE_CO_FNC_LogContent;
};

if (_dual) then {
    [_side, -_price, "AI commander HQ recovery.", false] Call ChangeSideSupply;
} else {
    [_side, -_price] Call ChangeAICommanderFunds;
};
[_side, objNull, getPos _town] Call MHQRepair;
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _hq && {alive _hq}) then {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    _currency = if (_dual) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {(_side) Call GetAICommanderFunds};
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] AI repurchased HQ at town centre [%2] for %3 (%4 now %5).", str _side, _town getVariable ["name", "?"], _price, _currencyName, _currency]] Call WFBE_CO_FNC_LogContent;
} else {
    if (_dual) then {
        [_side, _price, "AI commander HQ recovery refund.", false] Call ChangeSideSupply;
    } else {
        [_side, _price] Call ChangeAICommanderFunds;
    };
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["WARNING", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ replacement failed at town centre [%2]; refunded %3 to %4.", str _side, _town getVariable ["name", "?"], _price, _currencyName]] Call WFBE_CO_FNC_LogContent;
};
